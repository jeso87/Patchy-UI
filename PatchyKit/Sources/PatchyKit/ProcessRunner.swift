import Darwin
import Foundation

public struct CommandResult: Sendable, Equatable {
    public let exitCode: Int32
    public let output: String

    public var succeeded: Bool { exitCode == 0 }

    public init(exitCode: Int32, output: String) {
        self.exitCode = exitCode
        self.output = output
    }
}

public enum ProcessRunner {
    public enum Input: Sendable {
        /// No input; reads see end-of-file immediately.
        case none
        /// Bytes piped to standard input.
        case pipe(Data)
        /// Standard input is a terminal. Each line is typed in advance, then end-of-input is sent,
        /// so a prompt the caller didn't predict gets no answer instead of waiting forever.
        case terminal(lines: [String])
    }

    public static func run(_ executable: URL, _ arguments: [String] = [], environment: [String: String],
                           input: Input = .none, onOutput: (@Sendable (String) -> Void)? = nil) async -> CommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runBlocking(executable, arguments, environment: environment,
                                                           input: input, onOutput: onOutput))
            }
        }
    }

    /// Runs to completion on the calling thread. Standard output and error are merged.
    public static func runBlocking(_ executable: URL, _ arguments: [String] = [], environment: [String: String],
                                   input: Input = .none, onOutput: (@Sendable (String) -> Void)? = nil) -> CommandResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment

        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = outPipe

        var master: Int32 = -1
        var slave: Int32 = -1
        var inPipe: Pipe?
        switch input {
        case .none:
            process.standardInput = FileHandle.nullDevice
        case .pipe:
            let pipe = Pipe()
            inPipe = pipe
            process.standardInput = pipe
        case .terminal:
            guard openpty(&master, &slave, nil, nil, nil) == 0 else {
                return CommandResult(exitCode: -1, output: "Could not open a terminal for \(executable.lastPathComponent).")
            }
            process.standardInput = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        }

        do {
            try process.run()
        } catch {
            if master >= 0 { close(master); close(slave) }
            return CommandResult(exitCode: -1, output: "Could not run \(executable.path): \(error.localizedDescription)")
        }

        try? outPipe.fileHandleForWriting.close()
        if slave >= 0 { close(slave) }

        switch input {
        case .none:
            break
        case .pipe(let data):
            let handle = inPipe!.fileHandleForWriting
            try? handle.write(contentsOf: data)
            try? handle.close()
        case .terminal(let lines):
            let typed = lines.map { $0 + "\n" }.joined() + "\u{04}"
            _ = typed.withCString { write(master, $0, strlen($0)) }
        }

        let collector = OutputCollector()
        let readHandle = outPipe.fileHandleForReading
        let reader = Thread {
            let fd = readHandle.fileDescriptor
            var buffer = [UInt8](repeating: 0, count: 8192)
            while true {
                let count = read(fd, &buffer, buffer.count)
                if count > 0 {
                    let chunk = String(decoding: buffer[0..<count], as: UTF8.self)
                    collector.append(chunk)
                    onOutput?(chunk)
                } else if count == 0 || errno != EINTR {
                    break
                }
            }
            collector.finished.signal()
        }
        reader.start()

        process.waitUntilExit()
        // A grandchild that outlives the command can keep the pipe open; don't wait on it forever.
        _ = collector.finished.wait(timeout: .now() + 2)
        if master >= 0 { close(master) }

        return CommandResult(exitCode: process.terminationStatus, output: collector.text)
    }
}

private final class OutputCollector: @unchecked Sendable {
    let finished = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var buffer = ""

    func append(_ chunk: String) {
        lock.lock()
        buffer += chunk
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
