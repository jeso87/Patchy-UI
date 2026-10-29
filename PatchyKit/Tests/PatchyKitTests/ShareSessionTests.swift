import Foundation
import Testing
@testable import PatchyKit

@Suite struct ShareEventTests {
    let anonymous = """
    {"schema":1,"event":"starting","site":"harbor.test"}
    {"schema":1,"event":"ready","site":"harbor.test","url":"https://quiet-river-banana.trycloudflare.com","mode":"anonymous","auth":null}

    """

    @Test func anonymousLinkIsTemporary() {
        let access = ShareEvents.access(in: anonymous)
        #expect(access == ShareAccess(url: URL(string: "https://quiet-river-banana.trycloudflare.com")!, isTemporary: true))
    }

    @Test func stableAddressWithPassword() {
        let text = """
        {"schema":1,"event":"starting","site":"harbor.test"}
        {"schema":1,"event":"ready","site":"harbor.test","url":"https://harbor.example.com","mode":"stable","auth":{"username":"preview","password":"k7Rm-4vQx-92Ld"}}

        """
        let access = ShareEvents.access(in: text)
        #expect(access == ShareAccess(url: URL(string: "https://harbor.example.com")!, username: "preview", password: "k7Rm-4vQx-92Ld"))
    }

    @Test func lineSplitAcrossReadsIsWhole() {
        let unfinished = #"{"schema":1,"event":"ready","site":"harbor.test","url":"https://quiet-ri"#
        #expect(ShareEvents.access(in: unfinished) == nil)
        #expect(ShareEvents.access(in: anonymous)?.url.host == "quiet-river-banana.trycloudflare.com")
    }

    @Test func errorEventGivesTheCode() {
        let text = #"{"schema":1,"event":"error","site":"harbor.test","error":"tunnel_failed","message":"cloudflared stopped before the link was ready:","details":"ERR one"}"#
        #expect(ShareSession.failure(in: text, wasSharing: false) == ShareFailure(code: PatchyError.tunnelFailed, details: "cloudflared stopped before the link was ready:\nERR one", wasSharing: false))
        #expect(ShareSession.failure(in: "zsh: no such file", wasSharing: true) == ShareFailure(code: nil, details: "zsh: no such file", wasSharing: true))
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
    static let stopped = "stopped"

    /// Stands in for `patchy share --json`: prints the given lines, then waits for a signal like Patchy.
    static func script(printing body: String, onInt: String = stopped) -> String {
        """
        #!/bin/zsh
        stopped() { echo '{"schema":1,"event":"stopped","site":"harbor.test"}'; exit 0 }
        trap '\(onInt)' INT
        trap '\(stopped)' TERM
        echo "args: $*"
        \(body)
        while true; do sleep 0.1; done
        """
    }

    static let quickBody = #"""
    echo '{"schema":1,"event":"starting","site":"'$2'"}'
    echo '{"schema":1,"event":"ready","site":"'$2'","url":"https://quiet-river-banana.trycloudflare.com","mode":"anonymous","auth":null}'
    """#

    func session(_ prefix: FakePrefix, mode: ShareMode = .standard, log: StateLog) -> ShareSession {
        ShareSession(environment: prefix.environment, address: "harbor.test", mode: mode,
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

    @Test(arguments: [(ShareMode.standard, "share harbor.test --json"),
                      (.temporary, "share harbor.test --temp --json"),
                      (.domainWithPassword, "share harbor.test --auth --json"),
                      (.domainWithoutPassword, "share harbor.test --json"),
                      (.temporaryWithPassword, "share harbor.test --temp --auth --json"),
                      (.anonymous, "share harbor.test --anonymous --json"),
                      (.named("harbor-preview", password: false), "share harbor.test --name harbor-preview --json"),
                      (.named("harbor-preview", password: true), "share harbor.test --name harbor-preview --auth --json")])
    func passesTheModesOptions(mode: ShareMode, expected: String) async throws {
        let prefix = try FakePrefix(patchyScript: "#!/bin/zsh\necho \"args: $* end\"\nexit 1\n")
        defer { prefix.remove() }
        let log = StateLog()
        session(prefix, mode: mode, log: log).start()
        #expect(await log.wait { if case .failed = $0.last { true } else { false } })
        guard case .failed(let failure) = log.states.last else { return }
        #expect(failure.details.contains("args: \(expected) end"))
        #expect(!failure.wasSharing)
    }

    @Test func linkSplitAcrossWritesIsWhole() async throws {
        let body = #"""
        printf '{"schema":1,"event":"ready","site":"harbor.test","url":"https://quiet-ri'
        sleep 0.4
        printf 'ver-banana.trycloudflare.com","mode":"anonymous","auth":null}\n'
        """#
        let prefix = try FakePrefix(patchyScript: Self.script(printing: body))
        defer { prefix.remove() }
        let log = StateLog()
        let s = session(prefix, log: log)
        s.start()
        #expect(await log.wait { isSharing($0) })
        #expect(log.states.contains(.sharing(ShareAccess(url: URL(string: "https://quiet-river-banana.trycloudflare.com")!, isTemporary: true))))
        s.stop()
        _ = await log.wait { $0.last == .stopped }
    }

    @Test func missingCloudflaredFails() async throws {
        let prefix = try FakePrefix(patchyScript: #"#!/bin/zsh\#necho '{"schema":1,"event":"error","site":"harbor.test","error":"cloudflared_missing","message":"cloudflared is required","details":null}'\#nexit 1\#n"#)
        defer { prefix.remove() }
        let log = StateLog()
        session(prefix, log: log).start()
        #expect(await log.wait { if case .failed = $0.last { true } else { false } })
        guard case .failed(let failure) = log.states.last, !failure.wasSharing else { Issue.record("expected failure before sharing"); return }
        #expect(failure.code == PatchyError.cloudflaredMissing)
        #expect(failure.details == "cloudflared is required")
    }

    @Test func dyingAfterTheLinkIsReportedAsWasSharing() async throws {
        let body = Self.quickBody + #"\#nsleep 0.5\#necho '{"schema":1,"event":"error","site":"harbor.test","error":"tunnel_stopped","message":"The link stopped working","details":null}'\#nexit 1"#
        let prefix = try FakePrefix(patchyScript: Self.script(printing: body))
        defer { prefix.remove() }
        let log = StateLog()
        session(prefix, log: log).start()
        #expect(await log.wait { if case .failed = $0.last { true } else { false } })
        guard case .failed(let failure) = log.states.last, failure.wasSharing else { Issue.record("expected failure after sharing"); return }
        #expect(failure.code == PatchyError.tunnelStopped)
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

@Suite struct EnvironmentTests {
    @Test func installRunsHomebrew() async throws {
        let prefix = try FakePrefix(patchyScript: "#!/bin/zsh\n")
        defer { prefix.remove() }
        let brew = prefix.root.appending(path: "bin/brew")
        try "#!/bin/zsh\necho \"brew $*\"\n".write(to: brew, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: brew.path)
        let result = await PatchyClient(environment: prefix.environment).installCloudflared()
        #expect(result.succeeded)
        #expect(result.output.contains("brew install cloudflared"))
    }

    @Test func overrideReplacesOnlyThePatchyBinary() {
        var environment = PatchyEnvironment(brewPrefix: URL(fileURLWithPath: "/opt/homebrew"))
        environment.patchyOverride = URL(fileURLWithPath: "/Users/me/patchy/bin/patchy")
        #expect(environment.patchyBinary.path == "/Users/me/patchy/bin/patchy")
        #expect(environment.optDir.path == "/opt/homebrew/opt")
    }
}

@Suite(.serialized) struct ShareWatcherTests {
    /// The app holds the write end of Patchy's standard input. If the app dies without stopping a
    /// share (a crash, Force Quit), that end closes, and the share must stop on its own.
    @Test func closingStandardInputStopsTheShare() async throws {
        let prefix = try FakePrefix(patchyScript: ShareSessionTests.script(printing: ShareSessionTests.quickBody))
        defer { prefix.remove() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", ShareSession.watcherScript, "patchy-share", prefix.environment.patchyBinary.path, "share", "harbor.test"]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output
        let collected = Collected()
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { collected.add(String(decoding: data, as: UTF8.self)) }
        }
        try process.run()

        var ready = false
        for _ in 0..<100 where !ready {
            ready = collected.text.contains(#""event":"ready""#)
            if !ready { try await Task.sleep(for: .milliseconds(50)) }
        }
        #expect(ready)

        try input.fileHandleForWriting.close()   // what the kernel does when the app dies
        var exited = false
        for _ in 0..<100 where !exited {
            exited = !process.isRunning
            if !exited { try await Task.sleep(for: .milliseconds(50)) }
        }
        #expect(exited)
        try await Task.sleep(for: .milliseconds(200))
        #expect(collected.text.contains(#""event":"stopped""#))
        output.fileHandleForReading.readabilityHandler = nil
        if process.isRunning { process.terminate() }
    }
}
