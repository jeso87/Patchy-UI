import Foundation
import Testing
@testable import PatchyKit

@Suite struct AddressRulesTests {
    @Test func bareNameGetsTestSuffix() {
        #expect(AddressRules.finalAddress(from: " MySite ") == "mysite.test")
        #expect(AddressRules.finalAddress(from: "mysite.local") == "mysite.local")
        #expect(AddressRules.finalAddress(from: "") == "")
    }

    @Test func problems() {
        #expect(AddressRules.problem(with: "my site", existing: []) == .invalidCharacters)
        #expect(AddressRules.problem(with: "mysite.", existing: []) == .unfinished)
        #expect(AddressRules.problem(with: "-mysite", existing: []) == .unfinished)
        #expect(AddressRules.problem(with: "my..site", existing: []) == .unfinished)
        #expect(AddressRules.problem(with: "mysite", existing: ["mysite.test"]) == .alreadyExists("mysite.test"))
        #expect(AddressRules.problem(with: "mysite", existing: ["other.test"]) == nil)
    }

    @Test func wwwIsOfferedOnlyForTwoLabelAddresses() {
        #expect(AddressRules.offersWWW("mysite.test"))
        #expect(AddressRules.offersWWW("example.com"))
        #expect(!AddressRules.offersWWW("shop.example.com"))
        #expect(!AddressRules.offersWWW("www.test"))
    }

    @Test func realAddresses() {
        #expect(!AddressRules.isRealAddress("mysite.test"))
        #expect(!AddressRules.isRealAddress("intranet.local"))
        #expect(AddressRules.isRealAddress("example.com"))
    }
}

@Suite struct CompatibilityTests {
    @Test func appVersionNamesThePatchyReleaseItSupports() {
        #expect(PatchyCompatibility.supportedPatchyVersion(appVersion: "1.2.1") == "1.2.1")
        #expect(PatchyCompatibility.supportedPatchyVersion(appVersion: "1.2.1.3") == "1.2.1")
    }

    @Test func comparesInstalledPatchyWithTheSupportedRelease() {
        #expect(PatchyCompatibility.check(appVersion: "1.2.1", patchyVersion: "1.2.1") == .matched)
        #expect(PatchyCompatibility.check(appVersion: "1.2.1.2", patchyVersion: "1.2.1") == .matched)
        #expect(PatchyCompatibility.check(appVersion: "1.2.1", patchyVersion: "1.3.0") == .patchyNewer(installed: "1.3.0", supported: "1.2.1"))
        #expect(PatchyCompatibility.check(appVersion: "1.2.1", patchyVersion: "1.10.0") == .patchyNewer(installed: "1.10.0", supported: "1.2.1"))
        #expect(PatchyCompatibility.check(appVersion: "1.2.1", patchyVersion: "1.2.0") == .patchyOlder(installed: "1.2.0", supported: "1.2.1"))
        #expect(PatchyCompatibility.check(appVersion: "1.2.1", patchyVersion: "dev") == .unknown)
        #expect(PatchyCompatibility.check(appVersion: "1.2.1", patchyVersion: nil) == .unknown)
    }
}

/// A throwaway Homebrew prefix with a fake `patchy` so commands can run without touching the real one.
struct FakePrefix {
    let root: URL
    let environment: PatchyEnvironment

    init(patchyScript: String) throws {
        root = FileManager.default.temporaryDirectory.appending(path: "PatchyKitTests-\(UUID().uuidString)")
        environment = PatchyEnvironment(brewPrefix: root)
        let fm = FileManager.default
        for dir in ["bin", "opt"] {
            try fm.createDirectory(at: root.appending(path: dir), withIntermediateDirectories: true)
        }
        try patchyScript.write(to: environment.patchyBinary, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: environment.patchyBinary.path)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

/// What a fake `patchy` prints for `status`, `list` and `version` with `--json`, shaped like 1.3.0's.
enum SampleJSON {
    static let status = """
    {"schema": 1, "apache": {"running": true},
     "php": {"active": "8.4", "installed": [{"formula": "php", "full": "8.5.12", "version": "8.5"},
                                            {"formula": "php@8.4", "full": "8.4.27", "version": "8.4"}]},
     "hosts": {"names": 3, "routed": 3, "missing": []},
     "trust": "outdated", "certificate_authority": {"exists": true, "trusted": true},
     "share": {"domain": "example.com", "cloudflared": true},
     "paths": {"error_log": "/opt/homebrew/var/log/httpd/error_log",
               "httpd_conf": "/opt/homebrew/etc/httpd/httpd.conf",
               "php_ini": "/opt/homebrew/etc/php/8.4/php.ini"}}
    """

    static let list = """
    {"schema": 1, "sites": [
      {"domain": "mysite.test", "docroot": "/Users/joe/Sites/My Site/public", "docroot_exists": false,
       "aliases": ["www.mysite.test"],
       "certificate": {"state": "expired", "days_left": -3, "expires": "2026-10-26T12:00:00Z"},
       "routed": false,
       "logs": {"error": "/opt/homebrew/var/log/httpd/mysite.test-error_log",
                "access": "/opt/homebrew/var/log/httpd/mysite.test-access_log"},
       "share": {"address": "https://mysite.example.com", "running": null}},
      {"domain": "harbor.test", "docroot": "/tmp", "docroot_exists": true, "aliases": [],
       "certificate": {"state": "none", "days_left": null, "expires": null},
       "routed": true, "logs": {"error": null, "access": null},
       "share": {"address": null, "running": null}}]}
    """

    static let version = """
    {"schema": 1, "version": "1.3.0", "features": ["json", "add_yes", "folder", "share", "share_auth"]}
    """

    /// A fake `patchy` answering the three, and echoing anything else.
    static let script = """
    #!/bin/zsh
    case "$1" in
        status) cat <<'JSON'
    \(status)
    JSON
        ;;
        list) cat <<'JSON'
    \(list)
    JSON
        ;;
        version) echo '\(version)' ;;
        *) echo "args: $*" ;;
    esac
    """
}

@Suite struct ReadingTests {
    @Test func snapshotComesFromStatusListAndVersion() async throws {
        let prefix = try FakePrefix(patchyScript: SampleJSON.script)
        defer { prefix.remove() }
        let snapshot = try #require(await PatchyClient(environment: prefix.environment).snapshot())
        #expect(snapshot.serverRunning)
        #expect(snapshot.activePHP == "8.4")
        #expect(snapshot.installedPHP == [PHPInstall(version: "8.5", fullVersion: "8.5.12"), PHPInstall(version: "8.4", fullVersion: "8.4.27")])
        #expect(snapshot.trust == .outdated)
        #expect(snapshot.patchyVersion == "1.3.0")
        #expect(snapshot.supportsSharing)
        #expect(snapshot.sharingDomain == "example.com")
        #expect(snapshot.cloudflaredInstalled)
        #expect(snapshot.certificateAuthorityInstalled)
        #expect(snapshot.serverErrorLog == "/opt/homebrew/var/log/httpd/error_log")

        #expect(snapshot.sites.map(\.address) == ["harbor.test", "mysite.test"])
        let site = try #require(snapshot.sites.last)
        #expect(site.folder == "/Users/joe/Sites/My Site/public")
        #expect(!site.folderExists)
        #expect(site.wwwAlias == "www.mysite.test")
        #expect(!site.isRouted)
        #expect(site.certificate == .valid(expires: try Date("2026-10-26T12:00:00Z", strategy: .iso8601)))
        #expect(site.errorLog == "/opt/homebrew/var/log/httpd/mysite.test-error_log")
        #expect(site.shareAddress == "https://mysite.example.com")
        #expect(snapshot.sites.first?.certificate == .missing)
    }

    @Test func noJSONMeansNoSnapshotButAVersion() async throws {
        let prefix = try FakePrefix(patchyScript: "#!/bin/zsh\necho \"patchy 1.2.1\"\n")
        defer { prefix.remove() }
        let client = PatchyClient(environment: prefix.environment)
        #expect(await client.snapshot() == nil)
        #expect(await client.version() == PatchyVersion(version: "1.2.1", features: []))
    }

    @Test func unreadableCertificatesAreInvalid() throws {
        let json = #"{"sites": [{"domain": "a.test", "docroot": "/tmp", "docroot_exists": true, "aliases": [], "certificate": {"state": "invalid", "expires": null}, "routed": true, "logs": {}, "share": {}}]}"#
        let list = try #require(PatchyJSON.document(PatchyJSON.List.self, in: json))
        #expect(Site(list.sites[0]).certificate == .invalid)
    }
}

@Suite struct CommandTests {
    @Test(arguments: [
        ("example.com", true, "args: add example.com /tmp/site folder --yes --www --json"),
        ("mysite.test", false, "args: add mysite.test /tmp/site folder --yes --no-www --json"),
    ])
    func addAnswersPatchysQuestionsWithFlags(address: String, www: Bool, expected: String) async throws {
        let prefix = try FakePrefix(patchyScript: SampleJSON.script)
        defer { prefix.remove() }
        let result = await PatchyClient(environment: prefix.environment).addSite(address: address, folder: "/tmp/site folder", includeWWW: www)
        #expect(result.output.trimmingCharacters(in: .newlines) == expected)
    }

    @Test func changesRunWithJSON() async throws {
        let prefix = try FakePrefix(patchyScript: SampleJSON.script)
        defer { prefix.remove() }
        let client = PatchyClient(environment: prefix.environment)
        #expect(await client.changeFolder(of: "a.test", to: "/tmp/x").output.contains("args: folder a.test /tmp/x --json"))
        #expect(await client.refreshCertificates().output.contains("args: refresh-certs --json"))
        #expect(await client.removeSites(["a.test", "b.test"]).output.contains("args: rm a.test b.test --json"))
        #expect(await client.switchPHP(to: "8.4").output.contains("args: php 8.4 --json"))
    }

    @Test func outputIsStreamedAndExitCodeReported() async throws {
        let prefix = try FakePrefix(patchyScript: "#!/bin/zsh\necho one\necho two >&2\nexit 7\n")
        defer { prefix.remove() }
        let seen = Collected()
        let result = await PatchyClient(environment: prefix.environment).start { seen.add($0) }
        #expect(result.exitCode == 7)
        #expect(result.output.contains("one") && result.output.contains("two"))
        #expect(seen.text == result.output)
    }

    @Test func resultLineGivesTheCodeAndDetails() {
        let failed = CommandResult(exitCode: 1, output: """
        brew noise on stderr
        {"schema":1,"ok":false,"error":"port_in_use","message":"Apache didn't start","details":"line one\\nline two","warnings":[{"code":"sudo_required","message":"Couldn't update /etc/hosts"}]}

        """)
        #expect(failed.errorCode == PatchyError.portInUse)
        #expect(failed.details == "Apache didn't start\nline one\nline two\nCouldn't update /etc/hosts")

        let fine = CommandResult(exitCode: 0, output: #"{"schema":1,"ok":true,"warnings":[]}"#)
        #expect(fine.result?.ok == true)
        #expect(fine.errorCode == nil)

        let plain = CommandResult(exitCode: 1, output: "Could not run patchy")
        #expect(plain.result == nil)
        #expect(plain.details == "Could not run patchy")
    }
}

@Suite struct AskpassTests {
    @Test func scriptReturnsThePasswordEachTimeItIsAsked() async throws {
        let server = try AskpassServer { attempt in "secret-\(attempt)" }
        defer { server.stop() }
        let script = URL(fileURLWithPath: try #require(server.environment["SUDO_ASKPASS"]))
        let first = await ProcessRunner.run(script, environment: [:])
        #expect(first.output == "secret-1\n")
        let second = await ProcessRunner.run(script, environment: [:])
        #expect(second.output == "secret-2\n")
    }

    /// sudo with no terminal ignores `SUDO_ASKPASS` unless `DISPLAY` is set too.
    @Test func environmentLetsSudoUseTheScriptWithoutATerminal() throws {
        let server = try AskpassServer { _ in nil }
        defer { server.stop() }
        #expect(server.environment["SUDO_ASKPASS"] != nil)
        #expect(server.environment["DISPLAY"]?.isEmpty == false)
    }

    @Test func noPasswordMeansEmptyOutput() async throws {
        let server = try AskpassServer { _ in nil }
        defer { server.stop() }
        let script = URL(fileURLWithPath: try #require(server.environment["SUDO_ASKPASS"]))
        let result = await ProcessRunner.run(script, environment: [:])
        #expect(result.output.isEmpty)
    }
}

@Suite struct LogTailerTests {
    @Test func deliversExistingThenAppendedLines() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "PatchyKitTests-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: file) }
        try "one\ntwo\npart".write(to: file, atomically: true, encoding: .utf8)
        let tailer = LogTailer(file: file)
        #expect(tailer.readNewLines() == ["one", "two"])

        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("ial\nthree\n".utf8))
        try handle.close()
        #expect(tailer.readNewLines() == ["partial", "three"])
        #expect(tailer.readNewLines() == [])

        try "fresh\n".write(to: file, atomically: true, encoding: .utf8)
        #expect(tailer.readNewLines() == ["fresh"])
    }
}

@Suite struct LogCountsTests {
    private let today = DateComponents(year: 2026, month: 10, day: 29)

    private func write(_ text: String) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appending(path: "PatchyKitTests-\(UUID().uuidString).log")
        try text.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test func readsBothDateFormats() {
        #expect(LogCounts.day(of: #"::1 - - [29/Oct/2026:16:15:56 -0400] "GET / HTTP/1.1" 200 25023"#) == today)
        #expect(LogCounts.day(of: "[Thu Oct 29 09:05:12.497454 2026] [php:error] [pid 1] PHP Fatal error") == today)
        #expect(LogCounts.day(of: "[Mon Oct  5 20:05:12.497454 2026] [ssl:error]") == DateComponents(year: 2026, month: 10, day: 5))
        #expect(LogCounts.day(of: "Stack trace:") == nil)
    }

    @Test func countsTodaysVisitsButNotApachePings() throws {
        let file = try write("""
            ::1 - - [28/Oct/2026:23:59:59 -0400] "GET / HTTP/1.1" 200 10
            ::1 - - [29/Oct/2026:08:00:00 -0400] "GET / HTTP/1.1" 200 10
            ::1 - - [29/Oct/2026:08:00:01 -0400] "OPTIONS * HTTP/1.0" 200 -
            ::1 - - [29/Oct/2026:08:00:02 -0400] "GET /style.css HTTP/1.1" 200 10

            """)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(LogCounts.countLines(in: file, kind: .visits, day: today) == 2)
    }

    @Test func countsErrorsWithoutTheirContinuationLines() throws {
        let file = try write("""
            [Wed Oct 28 10:00:00.000000 2026] [php:error] old
            [Thu Oct 29 10:00:00.000000 2026] [php:error] PHP Fatal error: boom
            Stack trace:
            #0 {main}
            [Thu Oct 29 11:00:00.000000 2026] [php:warn] PHP Warning: hmm
            """)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(LogCounts.countLines(in: file, kind: .errors, day: today) == 2)
    }

    @Test func readsAcrossChunks() throws {
        let line = #"::1 - - [29/Oct/2026:08:00:00 -0400] "GET /a-page-with-a-long-name HTTP/1.1" 200 10"#
        let file = try write(Array(repeating: line, count: 3000).joined(separator: "\n") + "\n")
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(LogCounts.countLines(in: file, kind: .visits, day: today) == 3000)
    }

    @Test func missingLogCountsNothing() {
        #expect(LogCounts.today(errorLog: "/nonexistent/error_log", accessLog: nil) == LogCounts(errors: 0, visits: 0))
    }
}

final class Collected: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""
    func add(_ chunk: String) { lock.lock(); buffer += chunk; lock.unlock() }
    var text: String { lock.lock(); defer { lock.unlock() }; return buffer }
}
