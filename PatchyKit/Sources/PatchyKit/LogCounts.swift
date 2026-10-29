import Foundation

/// How many errors and visits a site's logs recorded today, for the Overview's Today card.
public struct LogCounts: Sendable, Equatable {
    public var errors: Int
    public var visits: Int

    public init(errors: Int, visits: Int) {
        self.errors = errors
        self.visits = visits
    }

    /// Reads the logs `list --json` names. A missing log counts as nothing logged.
    public static func today(errorLog: String?, accessLog: String?, now: Date = Date(), calendar: Calendar = .current) -> LogCounts {
        let day = calendar.dateComponents([.year, .month, .day], from: now)
        func count(_ path: String?, _ kind: Kind) -> Int {
            guard let path else { return 0 }
            return countLines(in: URL(fileURLWithPath: path), kind: kind, day: day)
        }
        return LogCounts(errors: count(errorLog, .errors), visits: count(accessLog, .visits))
    }

    enum Kind {
        case errors, visits
    }

    /// Reads the file backwards until it reaches a line from an earlier day, so a long log costs
    /// only today's share of it. Stops after `maxBytes` and counts what it read.
    static func countLines(in file: URL, kind: Kind, day: DateComponents, maxBytes: UInt64 = 16 * 1024 * 1024) -> Int {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return 0 }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return 0 }

        let chunk: UInt64 = 64 * 1024
        var end = size
        var carry = Data()
        var count = 0
        while end > 0, size - end < maxBytes {
            let start = end > chunk ? end - chunk : 0
            try? handle.seek(toOffset: start)
            guard let data = try? handle.read(upToCount: Int(end - start)) else { break }
            var lines = (data + carry).split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)
            // The first piece may be the end of a line that started in the previous chunk.
            carry = start > 0 ? Data(lines.removeFirst()) : Data()
            for line in lines.reversed() {
                let text = String(decoding: line, as: UTF8.self)
                guard let logged = Self.day(of: text) else { continue }
                guard logged == day else { return count }
                if kind == .errors || !isInternal(text) { count += 1 }
            }
            end = start
        }
        return count
    }

    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    // Access log: ::1 - - [29/Oct/2026:16:15:56 -0400] "GET / HTTP/1.1" 200 25023
    private static let accessDate = #/\[(\d{1,2})/([A-Z][a-z]{2})/(\d{4}):/#
    // Error log: [Mon Oct 12 20:05:12.497454 2026] [ssl:error] ...
    private static let errorDate = #/^\[[A-Z][a-z]{2} ([A-Z][a-z]{2}) +(\d{1,2}) [\d:.]+ (\d{4})\]/#

    /// The calendar day a log line was written, or nil for lines that carry no date (stack traces).
    static func day(of line: String) -> DateComponents? {
        if let match = line.firstMatch(of: errorDate) {
            return components(year: match.3, month: match.1, day: match.2)
        }
        if let match = line.firstMatch(of: accessDate) {
            return components(year: match.3, month: match.2, day: match.1)
        }
        return nil
    }

    private static func components(year: Substring, month: Substring, day: Substring) -> DateComponents? {
        guard let year = Int(year), let day = Int(day), let month = months.firstIndex(of: String(month)) else { return nil }
        return DateComponents(year: year, month: month + 1, day: day)
    }

    /// Apache pings its own workers with `OPTIONS *`; those aren't visits.
    private static func isInternal(_ line: String) -> Bool {
        line.contains("\"OPTIONS * ")
    }
}
