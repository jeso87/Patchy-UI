import Darwin
import Foundation

public struct CommandResult: Sendable, Equatable {
    public let exitCode: Int32
    public let output: String

    public var succeeded: Bool { exitCode == 0 }

    /// The result line a command run with `--json` ends with.
    public var result: PatchyResult? { PatchyResult.parse(output) }

    /// The stable code for why it failed, when Patchy gave one.
    public var errorCode: String? { result?.error }

    /// What Show Details shows: Patchy's explanation and any extra lines, or the raw output
    /// when there was no result line.
    public var details: String {
        guard let result else { return output }
        var lines = [result.message, result.details].compactMap { $0 }.filter { !$0.isEmpty }
        lines += result.warnings.map(\.message)
        return lines.isEmpty ? output : lines.joined(separator: "\n")
    }

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

        var inPipe: Pipe?
        switch input {
        case .none:
            process.standardInput = FileHandle.nullDevice
        case .pipe:
            let pipe = Pipe()
            inPipe = pipe
            process.standardInput = pipe
        }

        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: -1, output: "Could not run \(executable.path): \(error.localizedDescription)")
        }

        try? outPipe.fileHandleForWriting.close()

        switch input {
        case .none:
            break
        case .pipe(let data):
            let handle = inPipe!.fileHandleForWriting
            try? handle.write(contentsOf: data)
            try? handle.close()
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
