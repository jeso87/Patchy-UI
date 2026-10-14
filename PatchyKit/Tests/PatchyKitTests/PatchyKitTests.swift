import Foundation
import Testing
@testable import PatchyKit

private let sampleVhost = """
<Directory "/Users/joe/Sites/My Site/public">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

<VirtualHost *:80>
    DocumentRoot "/Users/joe/Sites/My Site/public"
    ServerName mysite.test
    ServerAlias www.mysite.test
    ErrorLog "/opt/homebrew/var/log/httpd/mysite.test-error_log"
</VirtualHost>

<VirtualHost *:443>
    DocumentRoot "/Users/joe/Sites/My Site/public"
    ServerName mysite.test
    ServerAlias www.mysite.test
    SSLEngine on
    SSLCertificateFile "/opt/homebrew/etc/httpd/certs/mysite.test.pem"
</VirtualHost>

"""

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

    @Test func promptAnswersFollowPatchysOrder() {
        #expect(AddressRules.addPromptAnswers(address: "mysite.test", includeWWW: true) == ["y"])
        #expect(AddressRules.addPromptAnswers(address: "mysite.test", includeWWW: false) == ["n"])
        #expect(AddressRules.addPromptAnswers(address: "example.com", includeWWW: false) == ["n", "y"])
        #expect(AddressRules.addPromptAnswers(address: "shop.example.com", includeWWW: true) == ["y"])
        #expect(AddressRules.addPromptAnswers(address: "a.b.test", includeWWW: true) == [])
    }
}

@Suite struct VhostTests {
    @Test func parsesFolderAndAliases() {
        let parsed = Vhost.parse(sampleVhost)
        #expect(parsed.folder == "/Users/joe/Sites/My Site/public")
        #expect(parsed.aliases == ["www.mysite.test"])
    }

    @Test func replacesEveryFolderReference() throws {
        let updated = try #require(Vhost.replacingFolder(in: sampleVhost, with: "/Users/joe/New Place"))
        #expect(Vhost.parse(updated).folder == "/Users/joe/New Place")
        #expect(!updated.contains("My Site"))
        #expect(updated.components(separatedBy: "/Users/joe/New Place").count == 4)
        #expect(updated.contains("    DocumentRoot \"/Users/joe/New Place\""))
        // Everything else is untouched, line for line.
        #expect(updated.components(separatedBy: "\n").count == sampleVhost.components(separatedBy: "\n").count)
        #expect(updated.contains("ServerAlias www.mysite.test"))
    }

    @Test func refusesFoldersThatCannotBeQuoted() {
        #expect(Vhost.replacingFolder(in: sampleVhost, with: "/Users/joe/bad\"name") == nil)
        #expect(Vhost.replacingFolder(in: sampleVhost, with: "") == nil)
        #expect(Vhost.replacingFolder(in: "ServerName x.test\n", with: "/tmp") == nil)
    }
}

@Suite struct HostsFileTests {
    @Test func routedNamesNeedBothLines() {
        let hosts = """
        127.0.0.1 localhost
        127.0.0.1 a.test # patchy
        ::1 a.test # patchy
        127.0.0.1 b.test # patchy
        127.0.0.1 c.test
        ::1 c.test
        """
        #expect(HostsFile.routedNames(in: hosts) == ["a.test"])
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

@Suite struct ServerReaderTests {
    @Test func phpVersions() {
        #expect(ServerReader.phpVersion(fromCellarName: "8.5.11_1") == PHPInstall(version: "8.5", fullVersion: "8.5.11"))
        #expect(ServerReader.phpVersion(fromCellarName: "7.4.33") == PHPInstall(version: "7.4", fullVersion: "7.4.33"))
        #expect(ServerReader.phpVersion(fromCellarName: "HEAD-abc") == nil)
    }

    @Test func phpFormulaFromPatchyConf() {
        let conf = """
        LoadModule ssl_module lib/httpd/modules/mod_ssl.so
        LoadModule php_module /opt/homebrew/opt/php@8.3/lib/httpd/modules/libphp.so
        """
        #expect(ServerReader.phpFormula(inPatchyConf: conf) == "php@8.3")
    }

    @Test func helperVersion() {
        #expect(ServerReader.expectedHelperVersion(inScript: "#!/bin/zsh\nHELPER_VERSION=\"2\"\n") == "2")
        #expect(ServerReader.expectedHelperVersion(inScript: "#!/bin/zsh\n") == nil)
    }
}

/// A throwaway Homebrew prefix with a fake `patchy` so commands can run without touching the real one.
private struct FakePrefix {
    let root: URL
    let environment: PatchyEnvironment

    init(patchyScript: String) throws {
        root = FileManager.default.temporaryDirectory.appending(path: "PatchyKitTests-\(UUID().uuidString)")
        environment = PatchyEnvironment(brewPrefix: root)
        let fm = FileManager.default
        for dir in ["bin", "etc/httpd/sites", "etc/httpd/certs", "var/log/httpd", "var/run/httpd", "opt"] {
            try fm.createDirectory(at: root.appending(path: dir), withIntermediateDirectories: true)
        }
        try patchyScript.write(to: environment.patchyBinary, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: environment.patchyBinary.path)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

@Suite struct CommandTests {
    /// Asks the same two questions as `patchy add`, with the same terminal test.
    static let promptingScript = """
    #!/bin/zsh
    if [ ! -t 0 ]; then echo "no terminal"; exit 3; fi
    printf "Also serve www.%s? [Y/n] " "$2" >&2
    read -r www
    printf "Continue? [y/N] "
    read -r go
    echo "www=$www go=$go folder=$3"
    read -r extra || echo "no more input"
    """

    @Test func addAnswersPromptsThroughATerminal() async throws {
        let prefix = try FakePrefix(patchyScript: Self.promptingScript)
        defer { prefix.remove() }
        let client = PatchyClient(environment: prefix.environment)
        let result = await client.addSite(address: "example.com", folder: "/tmp/site folder", includeWWW: false)
        #expect(result.succeeded)
        #expect(result.output.contains("www=n go=y folder=/tmp/site folder"))
        #expect(result.output.contains("no more input"))
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

    @Test func changeFolderRewritesConfigWhenCheckPasses() async throws {
        let prefix = try FakePrefix(patchyScript: "#!/bin/zsh\necho \"ran $1\"\n")
        defer { prefix.remove() }
        let file = prefix.environment.vhostFile(for: "mysite.test")
        try sampleVhost.write(to: file, atomically: true, encoding: .utf8)
        let newFolder = prefix.root.appending(path: "new folder")
        try FileManager.default.createDirectory(at: newFolder, withIntermediateDirectories: true)

        let result = await PatchyClient(environment: prefix.environment)
            .changeFolder(of: "mysite.test", to: newFolder.path, restart: true)
        #expect(result.succeeded)
        #expect(result.output.contains("ran check") && result.output.contains("ran restart"))
        #expect(Vhost.parse(try String(contentsOf: file, encoding: .utf8)).folder == newFolder.path)
    }

    @Test func changeFolderRestoresConfigWhenCheckFails() async throws {
        let prefix = try FakePrefix(patchyScript: "#!/bin/zsh\necho \"Apache configuration is invalid.\"\nexit 1\n")
        defer { prefix.remove() }
        let file = prefix.environment.vhostFile(for: "mysite.test")
        try sampleVhost.write(to: file, atomically: true, encoding: .utf8)

        let result = await PatchyClient(environment: prefix.environment)
            .changeFolder(of: "mysite.test", to: prefix.root.path, restart: true)
        #expect(!result.succeeded)
        #expect(try String(contentsOf: file, encoding: .utf8) == sampleVhost)
    }

    @Test func changeFolderRejectsMissingFolder() async throws {
        let prefix = try FakePrefix(patchyScript: "#!/bin/zsh\nexit 0\n")
        defer { prefix.remove() }
        let file = prefix.environment.vhostFile(for: "mysite.test")
        try sampleVhost.write(to: file, atomically: true, encoding: .utf8)
        let result = await PatchyClient(environment: prefix.environment)
            .changeFolder(of: "mysite.test", to: "/nonexistent/patchy-ui", restart: false)
        #expect(!result.succeeded)
        #expect(try String(contentsOf: file, encoding: .utf8) == sampleVhost)
    }

    @Test func snapshotReadsSitesFromDisk() throws {
        let prefix = try FakePrefix(patchyScript: "#!/bin/zsh\nHELPER_VERSION=\"2\"\n")
        defer { prefix.remove() }
        try sampleVhost.write(to: prefix.environment.vhostFile(for: "mysite.test"), atomically: true, encoding: .utf8)
        let hosts = prefix.root.appending(path: "hosts")
        try "127.0.0.1 mysite.test # patchy\n::1 mysite.test # patchy\n".write(to: hosts, atomically: true, encoding: .utf8)

        var client = PatchyClient(environment: prefix.environment)
        client.hostsFile = hosts
        let snapshot = client.snapshot(checkTrust: false)
        #expect(snapshot.sites.count == 1)
        let site = try #require(snapshot.sites.first)
        #expect(site.address == "mysite.test")
        #expect(site.wwwAlias == "www.mysite.test")
        #expect(site.certificate == .missing)
        #expect(!site.folderExists)
        // www.mysite.test has no hosts line, so the site is only partly routed.
        #expect(!site.isRouted)
        #expect(!snapshot.serverRunning)

        // Apache records its process ID here; a live process means the server is running.
        try "\(ProcessInfo.processInfo.processIdentifier)\n".write(to: prefix.environment.pidFile, atomically: true, encoding: .utf8)
        #expect(client.snapshot(checkTrust: false).serverRunning)
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

private final class Collected: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""
    func add(_ chunk: String) { lock.lock(); buffer += chunk; lock.unlock() }
    var text: String { lock.lock(); defer { lock.unlock() }; return buffer }
}
