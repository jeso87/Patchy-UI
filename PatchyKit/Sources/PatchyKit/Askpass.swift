import Darwin
import Foundation

/// Answers sudo's password requests for commands the app runs.
///
/// sudo has no terminal to prompt on when it is spawned by an app, so it runs the program named in
/// `SUDO_ASKPASS` and reads the password from its output. That program is a two-line script that reads
/// a private named pipe; this class writes the password into the pipe each time something opens it.
/// The password is never written to disk or placed in the environment.
public final class AskpassServer: @unchecked Sendable {
    /// Called each time sudo asks. `attempt` starts at 1. Return nil to give no password.
    public typealias Provider = @Sendable (_ attempt: Int) async -> String?

    private let directory: URL
    private let fifo: URL
    private let script: URL
    private let provider: Provider
    private let lock = NSLock()
    private var stopped = false

    public init(provider: @escaping Provider) throws {
        self.provider = provider
        directory = FileManager.default.temporaryDirectory.appending(path: "PatchyUI-\(UUID().uuidString)")
        fifo = directory.appending(path: "password")
        script = directory.appending(path: "askpass.sh")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        guard mkfifo(fifo.path, 0o600) == 0 else {
            try? FileManager.default.removeItem(at: directory)
            throw CocoaError(.fileWriteUnknown)
        }
        try "#!/bin/sh\nexec /bin/cat '\(fifo.path)'\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)

        let thread = Thread { [self] in serve() }
        thread.name = "PatchyUI askpass"
        thread.start()
    }

    /// Merge into the environment of any command that may call sudo.
    public var environment: [String: String] { ["SUDO_ASKPASS": script.path] }

    public func stop() {
        lock.lock()
        let alreadyStopped = stopped
        stopped = true
        lock.unlock()
        guard !alreadyStopped else { return }
        // Opening the read end releases the serving thread if it is waiting for a reader.
        let fd = open(fifo.path, O_RDONLY | O_NONBLOCK)
        if fd >= 0 {
            usleep(50_000)
            close(fd)
        }
        try? FileManager.default.removeItem(at: directory)
    }

    private var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    private func serve() {
        var attempt = 0
        while !isStopped {
            // Blocks until the askpass script opens the pipe for reading.
            let fd = open(fifo.path, O_WRONLY)
            guard fd >= 0 else { break }
            if isStopped {
                close(fd)
                break
            }
            attempt += 1
            let password = waitForPassword(attempt: attempt)
            if let password {
                _ = (password + "\n").withCString { write(fd, $0, strlen($0)) }
            }
            close(fd)
            // Let the script see end-of-file and exit before listening again,
            // otherwise the same reader would be answered twice.
            usleep(300_000)
        }
    }

    private func waitForPassword(attempt: Int) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = PasswordBox()
        let provider = self.provider
        Task.detached {
            box.value = await provider(attempt)
            semaphore.signal()
        }
        semaphore.wait()
        return box.value
    }
}

private final class PasswordBox: @unchecked Sendable {
    var value: String?
}

public enum PasswordCheck: Sendable, Equatable {
    case valid
    case wrong
    /// The account isn't allowed to administer this Mac.
    case notAllowed

    /// Asks sudo to verify the password without using or leaving any cached approval.
    public static func validate(_ password: String) async -> PasswordCheck {
        let result = await ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/sudo"), ["-S", "-k", "-p", "", "/usr/bin/true"],
            environment: ["PATH": "/usr/bin:/bin", "LANG": "en_US.UTF-8"],
            input: .pipe(Data((password + "\n").utf8)))
        if result.succeeded { return .valid }
        if result.output.contains("not in the sudoers") || result.output.contains("not allowed") { return .notAllowed }
        return .wrong
    }
}
