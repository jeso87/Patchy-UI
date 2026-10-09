import Foundation

/// Follows a log file: delivers the tail that already exists, then new lines as they are written.
public final class LogTailer: @unchecked Sendable {
    private let file: URL
    private let initialBytes: UInt64
    private let queue = DispatchQueue(label: "PatchyUI.LogTailer")
    private var timer: DispatchSourceTimer?
    private var offset: UInt64 = 0
    private var partial = ""
    private var started = false

    public init(file: URL, initialBytes: UInt64 = 128 * 1024) {
        self.file = file
        self.initialBytes = initialBytes
    }

    public func start(interval: TimeInterval = 1, onLines: @escaping @Sendable ([String]) -> Void) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let lines = self.readNewLines()
            if !lines.isEmpty { onLines(lines) }
        }
        self.timer = timer
        timer.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit {
        timer?.cancel()
    }

    /// Reads whatever was appended since the last call. Exposed for tests.
    func readNewLines() -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return [] }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0

        var skipFirstFragment = false
        if !started {
            started = true
            if size > initialBytes {
                offset = size - initialBytes
                skipFirstFragment = true
            }
        } else if size < offset {
            // The file was truncated or rotated; start over from the top.
            offset = 0
            partial = ""
        }
        guard size > offset else { return [] }

        try? handle.seek(toOffset: offset)
        let data = (try? handle.readToEnd()) ?? Data()
        offset += UInt64(data.count)

        var pieces = (partial + String(decoding: data, as: UTF8.self)).components(separatedBy: "\n")
        partial = pieces.removeLast()
        if skipFirstFragment, !pieces.isEmpty { pieces.removeFirst() }
        return pieces.filter { !$0.isEmpty }
    }
}
