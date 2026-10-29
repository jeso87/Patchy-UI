import Darwin
import Foundation

/// Where a shared site can be reached, as `patchy share` reported it.
public struct ShareAccess: Sendable, Equatable {
    public var url: URL
    /// A random link, new each share, rather than the site's own address on the person's domain.
    public var isTemporary: Bool
    /// Set when the share asks for a password.
    public var username: String?
    public var password: String?

    public init(url: URL, isTemporary: Bool = false, username: String? = nil, password: String? = nil) {
        self.url = url
        self.isTemporary = isTemporary
        self.username = username
        self.password = password
    }
}

/// Why a share ended without being asked to.
public struct ShareFailure: Sendable, Equatable {
    /// Patchy's stable error code (see `PatchyError`); nil when Patchy didn't give one.
    public var code: String?
    /// Patchy's explanation and any extra lines, for Show Details.
    public var details: String
    /// True when the link had been working.
    public var wasSharing: Bool

    public init(code: String?, details: String, wasSharing: Bool) {
        self.code = code
        self.details = details
        self.wasSharing = wasSharing
    }
}

public enum ShareState: Sendable, Equatable {
    case starting
    case sharing(ShareAccess)
    case failed(ShareFailure)
    case stopped
}

/// The events `patchy share --json` prints, one JSON object per line.
enum ShareEvents {
    /// The link once Patchy reports it ready. Only whole lines count, so a line that arrives in
    /// two reads is never read early.
    static func access(in text: String) -> ShareAccess? {
        guard let event = events(in: text).first(where: { $0.event == "ready" }),
              let url = event.url.flatMap(URL.init(string:)), url.scheme == "https", url.host != nil else { return nil }
        return ShareAccess(url: url, isTemporary: event.mode != "stable",
                           username: event.auth?.username, password: event.auth?.password)
    }

    /// The `error` event, if Patchy sent one.
    static func error(in text: String) -> PatchyJSON.ShareEvent? {
        events(in: text).last { $0.event == "error" }
    }

    private static func events(in text: String) -> [PatchyJSON.ShareEvent] {
        text.split(separator: "\n", omittingEmptySubsequences: false).dropLast()
            .compactMap { try? JSONDecoder().decode(PatchyJSON.ShareEvent.self, from: Data($0.utf8)) }
    }
}

/// Which link `patchy share` makes.
public enum ShareMode: Sendable, Hashable {
    /// No options: the site's address on the connected domain, or an anonymous link without one.
    case standard
    /// A random address on the connected domain, new each share.
    case temporary
    /// A random address on the connected domain, asking for a new password each share.
    case temporaryWithPassword
    /// The site's address on the connected domain, asking for a new password each share.
    case domainWithPassword
    /// The site's address on the connected domain, open to anyone with it.
    case domainWithoutPassword
    /// The site's address under a name of the person's choosing, which Patchy remembers for the site.
    case named(String, password: Bool)
    /// An anonymous trycloudflare.com link, even with a domain connected.
    case anonymous

    var arguments: [String] {
        switch self {
        case .standard, .domainWithoutPassword: []
        case .temporary: ["--temp"]
        case .temporaryWithPassword: ["--temp", "--auth"]
        case .domainWithPassword: ["--auth"]
        case .named(let name, let password): ["--name", name] + (password ? ["--auth"] : [])
        case .anonymous: ["--anonymous"]
        }
    }

    /// The name Patchy gives a site's address when none was chosen: the local address without
    /// its last part, dots as hyphens (harbor.test → harbor, shop.harbor.test → shop-harbor).
    public static func defaultName(for address: String) -> String {
        var parts = address.split(separator: ".")
        if parts.count > 1 { parts.removeLast() }
        return parts.joined(separator: "-")
    }

    /// One DNS label, as Patchy accepts it: Cloudflare's free certificates cover one level.
    public static func isValidName(_ name: String) -> Bool {
        name.wholeMatch(of: #/[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?/#) != nil
    }
}

/// Runs `patchy share <address> --json` for as long as the site is shared, and reports its state.
/// Patchy stops cloudflared itself when signalled, so signalling this one process is enough.
public final class ShareSession: @unchecked Sendable {
    public let address: String
    private let environment: PatchyEnvironment
    public let mode: ShareMode
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

    public init(environment: PatchyEnvironment, address: String, mode: ShareMode = .standard,
                callbackQueue: DispatchQueue = .main, onChange: @escaping @Sendable (ShareState) -> Void) {
        self.environment = environment
        self.address = address
        self.mode = mode
        self.callbackQueue = callbackQueue
        self.onChange = onChange
    }

    public func start() {
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", Self.watcherScript, "patchy-share", environment.patchyBinary.path,
                             "share", address] + mode.arguments + ["--json"]
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
            report(.failed(ShareFailure(code: nil, details: "Could not run \(environment.patchyBinary.path): \(error.localizedDescription)", wasSharing: false)))
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
        if access == nil, let parsed = ShareEvents.access(in: output) {
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
        let state: ShareState = stopRequested ? .stopped : .failed(Self.failure(in: output, wasSharing: access != nil))
        lock.unlock()
        report(state)
    }

    static func failure(in output: String, wasSharing: Bool) -> ShareFailure {
        guard let error = ShareEvents.error(in: output + "\n") else {
            return ShareFailure(code: nil, details: output, wasSharing: wasSharing)
        }
        let details = [error.message, error.details].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        return ShareFailure(code: error.error, details: details, wasSharing: wasSharing)
    }

    private func report(_ state: ShareState) {
        let onChange = onChange
        callbackQueue.async { onChange(state) }
    }
}
