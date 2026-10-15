import Foundation
import Testing
@testable import PatchyKit

@Suite struct ShareOutputTests {
    let quick = """
    Requesting a public link for harbor.test...
    Sharing harbor.test at https://quiet-river-banana.trycloudflare.com
    Anyone with this link can see the site. Press Ctrl-C to stop sharing.

    """

    @Test func quickLink() {
        let access = ShareOutput.access(in: quick, address: "harbor.test")
        #expect(access == ShareAccess(url: URL(string: "https://quiet-river-banana.trycloudflare.com")!))
    }

    @Test func stableAddressWithPassword() {
        let text = """
        Setting up harbor.example.com (first share only)...
        Requesting a public link for harbor.test...
        Sharing harbor.test at https://harbor.example.com
        Username: preview   Password: k7Rm-4vQx-92Ld
        Anyone with the address and password can see the site. Press Ctrl-C to stop sharing.

        """
        let access = ShareOutput.access(in: text, address: "harbor.test")
        #expect(access == ShareAccess(url: URL(string: "https://harbor.example.com")!, username: "preview", password: "k7Rm-4vQx-92Ld"))
    }

    @Test func accessNeedsTheReadyLine() {
        let partial = "Sharing harbor.test at https://harbor.example.com\nUsername: preview   Password: k7Rm-4vQx-92Ld\n"
        #expect(ShareOutput.access(in: partial, address: "harbor.test") == nil)
    }

    @Test func linkSplitAcrossReadsIsWhole() {
        let unfinished = "Sharing harbor.test at https://quiet-ri"
        #expect(ShareOutput.access(in: unfinished, address: "harbor.test") == nil)
        #expect(ShareOutput.access(in: quick, address: "harbor.test")?.url.host == "quiet-river-banana.trycloudflare.com")
    }

    @Test func anotherSitesLineIsIgnored() {
        #expect(ShareOutput.access(in: quick, address: "other.test") == nil)
    }
}

/// Collects a session's states, delivered on a private queue.
final class StateLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [ShareState] = []
    func add(_ state: ShareState) { lock.lock(); items.append(state); lock.unlock() }
    var states: [ShareState] { lock.lock(); defer { lock.unlock() }; return items }

    func wait(until condition: ([ShareState]) -> Bool, seconds: Double = 8) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition(states) { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition(states)
    }
}

@Suite(.serialized) struct ShareSessionTests {
    /// Stands in for `patchy share`: prints the given lines, then waits for a signal like Patchy.
    static func script(printing body: String, onInt: String = "echo \"Stopped sharing $2.\"; exit 0") -> String {
        """
        #!/bin/zsh
        trap '\(onInt)' INT
        trap 'echo "Stopped sharing $2."; exit 0' TERM
        echo "args: $*"
        \(body)
        while true; do sleep 0.1; done
        """
    }

    static let quickBody = """
    echo "Requesting a public link for $2..."
    echo "Sharing $2 at https://quiet-river-banana.trycloudflare.com"
    echo "Anyone with this link can see the site. Press Ctrl-C to stop sharing."
    """

    func session(_ prefix: FakePrefix, quick: Bool = false, log: StateLog) -> ShareSession {
        ShareSession(environment: prefix.environment, address: "harbor.test", quick: quick,
                     callbackQueue: DispatchQueue(label: "ShareSessionTests")) { log.add($0) }
    }

    func isSharing(_ states: [ShareState]) -> Bool { states.contains { if case .sharing = $0 { true } else { false } } }

    @Test func reportsTheLinkThenStops() async throws {
        let prefix = try FakePrefix(patchyScript: Self.script(printing: Self.quickBody))
        defer { prefix.remove() }
        let log = StateLog()
        let s = session(prefix, log: log)
        s.start()
        #expect(await log.wait { isSharing($0) })
        #expect(log.states.first == .starting)
        s.stop()
        #expect(await log.wait { $0.last == .stopped })
    }

    @Test func passesShareAndQuick() async throws {
        let prefix = try FakePrefix(patchyScript: "#!/bin/zsh\necho \"args: $*\"\nexit 1\n")
        defer { prefix.remove() }
        let log = StateLog()
        session(prefix, quick: true, log: log).start()
        #expect(await log.wait { if case .failed = $0.last { true } else { false } })
        guard case .failed(let output, let wasSharing) = log.states.last else { return }
        #expect(output.contains("args: share harbor.test --quick"))
        #expect(!wasSharing)
    }

    @Test func linkSplitAcrossWritesIsWhole() async throws {
        let body = """
        printf "Sharing $2 at https://quiet-ri"
        sleep 0.4
        printf "ver-banana.trycloudflare.com\\nAnyone with this link can see the site. Press Ctrl-C to stop sharing.\\n"
        """
        let prefix = try FakePrefix(patchyScript: Self.script(printing: body))
        defer { prefix.remove() }
        let log = StateLog()
        let s = session(prefix, log: log)
        s.start()
        #expect(await log.wait { isSharing($0) })
        #expect(log.states.contains(.sharing(ShareAccess(url: URL(string: "https://quiet-river-banana.trycloudflare.com")!))))
        s.stop()
        _ = await log.wait { $0.last == .stopped }
    }

    @Test func missingCloudflaredFails() async throws {
        let prefix = try FakePrefix(patchyScript: "#!/bin/zsh\necho \"cloudflared is required: brew install cloudflared\"\nexit 1\n")
        defer { prefix.remove() }
        let log = StateLog()
        session(prefix, log: log).start()
        #expect(await log.wait { if case .failed = $0.last { true } else { false } })
        guard case .failed(let output, false) = log.states.last else { Issue.record("expected failure before sharing"); return }
        #expect(output.contains("cloudflared is required"))
    }

    @Test func dyingAfterTheLinkIsReportedAsWasSharing() async throws {
        let body = Self.quickBody + "\nsleep 0.5\necho \"The link stopped working because cloudflared quit:\"\nexit 1"
        let prefix = try FakePrefix(patchyScript: Self.script(printing: body))
        defer { prefix.remove() }
        let log = StateLog()
        session(prefix, log: log).start()
        #expect(await log.wait { if case .failed = $0.last { true } else { false } })
        guard case .failed(_, true) = log.states.last else { Issue.record("expected failure after sharing"); return }
    }

    @Test func stopEscalatesToTermWhenIntIsIgnored() async throws {
        let prefix = try FakePrefix(patchyScript: Self.script(printing: Self.quickBody, onInt: "echo got-int"))
        defer { prefix.remove() }
        let log = StateLog()
        let s = session(prefix, log: log)
        s.start()
        #expect(await log.wait { isSharing($0) })
        s.stop()
        #expect(await log.wait(until: { $0.last == .stopped }, seconds: 8))
    }
}
