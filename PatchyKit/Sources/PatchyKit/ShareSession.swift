import Darwin
import Foundation

/// Where a shared site can be reached, as `patchy share` printed it.
public struct ShareAccess: Sendable, Equatable {
    public var url: URL
    /// Set when the site is shared on the person's own domain with a password.
    public var username: String?
    public var password: String?

    public init(url: URL, username: String? = nil, password: String? = nil) {
        self.url = url
        self.username = username
        self.password = password
    }
}

public enum ShareState: Sendable, Equatable {
    case starting
    case sharing(ShareAccess)
    /// Patchy's output. `wasSharing` is true when the link had been working.
    case failed(output: String, wasSharing: Bool)
    case stopped
}

/// The lines `patchy share` prints in a fixed format. This is Patchy's English, matched by the app,
/// never localized.
public enum ShareOutput {
    public static let sharing = "Sharing "
    public static let username = "Username: "
    public static let password = "   Password: "
    /// The last line Patchy prints once the link works; everything before it is complete.
    public static let ready = "Press Ctrl-C to stop sharing."

    /// The link, and the password when there is one, once Patchy has printed them all.
    /// Only whole lines count, so a link that arrives in two reads is never cut short.
    public static func access(in text: String, address: String) -> ShareAccess? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).dropLast()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard lines.contains(where: { $0.hasSuffix(ready) }) else { return nil }
        let prefix = sharing + address + " at "
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }),
              let url = URL(string: String(line.dropFirst(prefix.count))),
              url.scheme == "https", url.host != nil else { return nil }
        var access = ShareAccess(url: url)
        if let credentials = lines.first(where: { $0.hasPrefix(username) }),
           let split = credentials.range(of: password) {
            access.username = String(credentials[credentials.index(credentials.startIndex, offsetBy: username.count)..<split.lowerBound])
            access.password = String(credentials[split.upperBound...])
        }
        return access
    }
}

/// Runs `patchy share <address>` for as long as the site is shared, and reports its state.
/// Patchy forwards a stop signal to cloudflared itself, so signalling this one process is enough.
public final class ShareSession: @unchecked Sendable {
    public let address: String
    private let environment: PatchyEnvironment
    public let quick: Bool
    private let callbackQueue: DispatchQueue
    private let onChange: @Sendable (ShareState) -> Void
    private let process = Process()
    private let lock = NSLock()
    private var output = ""
    private var access: ShareAccess?
    private var stopRequested = false
    /// The app's end of Patchy's standard input. Closing it, or the app dying, stops the share.
    private var lifeline: FileHandle?

    /// Runs `patchy share` and stops it (TERM, which Patchy forwards to cloudflared) when its
    /// standard input reaches end of file: when the app closes it on Stop, or when the app is gone
    /// for any reason, a crash and Force Quit included. TERM rather than INT, because a background
    /// job in a script starts with INT ignored. Arguments: the Patchy binary, then its arguments.
    static let watcherScript = """
    exec 3<&0
    "$1" "${@:2}" </dev/null &
    p=$!
    trap 'kill -TERM $p 2>/dev/null' INT TERM HUP
    { read -r _ <&3; kill -TERM $p 2>/dev/null } &
    w=$!
    exec 3<&-
    while kill -0 $p 2>/dev/null; do wait $p 2>/dev/null; done
    kill $w 2>/dev/null
    """

    public init(environment: PatchyEnvironment, address: String, quick: Bool = false,
                callbackQueue: DispatchQueue = .main, onChange: @escaping @Sendable (ShareState) -> Void) {
        self.environment = environment
        self.address = address
        self.quick = quick
        self.callbackQueue = callbackQueue
        self.onChange = onChange
    }

    public func start() {
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", Self.watcherScript, "patchy-share", environment.patchyBinary.path,
                             "share", address] + (quick ? ["--quick"] : [])
        process.environment = environment.processEnvironment()
        let input = Pipe()
        process.standardInput = input
        lifeline = input.fileHandleForWriting
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // The session keeps itself alive until Patchy exits, so the end is always reported;
        // finished() lets go of the handler again.
        let readerDone = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            // Let the last of the output land before reporting the end.
            _ = readerDone.wait(timeout: .now() + 2)
            self.finished()
        }
        report(.starting)
        do {
            try process.run()
        } catch {
            report(.failed(output: "Could not run \(environment.patchyBinary.path): \(error.localizedDescription)", wasSharing: false))
            return
        }
        try? pipe.fileHandleForWriting.close()
        try? input.fileHandleForReading.close()

        let handle = pipe.fileHandleForReading
        Thread {
            let fd = handle.fileDescriptor
            var buffer = [UInt8](repeating: 0, count: 8192)
            while true {
                let count = read(fd, &buffer, buffer.count)
                if count > 0 {
                    self.received(String(decoding: buffer[0..<count], as: UTF8.self))
                } else if count == 0 || errno != EINTR {
                    break
                }
            }
            readerDone.signal()
        }.start()
    }

    /// Asks Patchy to stop sharing, then insists if it hasn't after 3 seconds; a second TERM
    /// makes cloudflared skip its grace period.
    public func stop() {
        lock.lock()
        let alreadyStopping = stopRequested
        stopRequested = true
        let lifeline = lifeline
        self.lifeline = nil
        lock.unlock()
        guard !alreadyStopping, process.isRunning else { return }
        try? lifeline?.close()
        let pid = process.processIdentifier
        let process = process
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if process.isRunning { kill(pid, SIGTERM) }
        }
    }

    private func received(_ chunk: String) {
        lock.lock()
        output += chunk
        var found: ShareAccess?
        if access == nil, let parsed = ShareOutput.access(in: output, address: address) {
            access = parsed
            found = parsed
        }
        lock.unlock()
        if let found { report(.sharing(found)) }
    }

    private func finished() {
        process.terminationHandler = nil
        lock.lock()
        try? lifeline?.close()
        lifeline = nil
        let state: ShareState = stopRequested ? .stopped : .failed(output: output, wasSharing: access != nil)
        lock.unlock()
        report(state)
    }

    private func report(_ state: ShareState) {
        let onChange = onChange
        callbackQueue.async { onChange(state) }
    }
}
