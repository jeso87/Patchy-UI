import Darwin
import Foundation

public enum TrustState: Sendable, Equatable {
    /// Patchy can update /etc/hosts without a password.
    case enabled
    /// The helper is installed but predates this Patchy version; `patchy trust` must run again.
    case outdated
    case notInstalled
}

public struct PHPInstall: Sendable, Hashable, Identifiable {
    /// Major.minor, the form `patchy php` takes (for example "8.4").
    public let version: String
    /// Full Homebrew version (for example "8.4.11").
    public let fullVersion: String

    public var id: String { version }

    public init(version: String, fullVersion: String) {
        self.version = version
        self.fullVersion = fullVersion
    }
}

public struct PatchySnapshot: Sendable, Equatable {
    public var sites: [Site] = []
    public var serverRunning = false
    public var activePHP: String?
    public var installedPHP: [PHPInstall] = []
    public var trust: TrustState = .notInstalled
    public var patchyVersion: String?
    /// False until the first certificate has been made; creating it asks for the Mac password.
    public var certificateAuthorityInstalled = true

    public init() {}
}

public enum ServerReader {
    public static let trustHelper = URL(fileURLWithPath: "/usr/local/libexec/patchy-hosts")

    public static func isRunning(_ environment: PatchyEnvironment) -> Bool {
        if let text = try? String(contentsOf: environment.pidFile, encoding: .utf8),
           let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 0 {
            return kill(pid, 0) == 0 || errno == EPERM
        }
        return false
    }

    // MARK: PHP

    /// "8.4.11_1" → ("8.4", "8.4.11")
    static func phpVersion(fromCellarName name: String) -> PHPInstall? {
        let full = name.split(separator: "_").first.map(String.init) ?? name
        let parts = full.split(separator: ".")
        guard parts.count >= 2, parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) else { return nil }
        return PHPInstall(version: "\(parts[0]).\(parts[1])", fullVersion: full)
    }

    private static func install(forFormula formula: String, in environment: PatchyEnvironment) -> PHPInstall? {
        let link = environment.optDir.appending(path: formula)
        guard FileManager.default.fileExists(atPath: link.path) else { return nil }
        return phpVersion(fromCellarName: link.resolvingSymlinksInPath().lastPathComponent)
    }

    public static func installedPHP(_ environment: PatchyEnvironment) -> [PHPInstall] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: environment.optDir.path)) ?? []
        var byVersion: [String: PHPInstall] = [:]
        for name in names where name == "php" || name.hasPrefix("php@") {
            if let found = install(forFormula: name, in: environment) { byVersion[found.version] = found }
        }
        return byVersion.values.sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    /// The formula named in patchy.conf's `LoadModule php…` line.
    static func phpFormula(inPatchyConf text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) where line.hasPrefix("LoadModule php") {
            let components = line.split(separator: "/").map(String.init)
            // The prefix itself may be /opt/homebrew, so the formula follows the last "opt".
            if let opt = components.lastIndex(of: "opt"), opt + 1 < components.count {
                return components[opt + 1]
            }
        }
        return nil
    }

    public static func activePHP(_ environment: PatchyEnvironment) -> String? {
        guard let text = try? String(contentsOf: environment.patchyConf, encoding: .utf8),
              let formula = phpFormula(inPatchyConf: text) else { return nil }
        return install(forFormula: formula, in: environment)?.version
    }

    // MARK: Trust

    /// The helper version this Patchy expects, read from the script itself.
    static func expectedHelperVersion(inScript text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) where line.hasPrefix("HELPER_VERSION=") {
            return line.dropFirst("HELPER_VERSION=".count).trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        }
        return nil
    }

    public static func trust(_ environment: PatchyEnvironment, helper: URL = trustHelper) -> TrustState {
        guard FileManager.default.isExecutableFile(atPath: helper.path) else { return .notInstalled }
        let result = ProcessRunner.runBlocking(URL(fileURLWithPath: "/usr/bin/sudo"), ["-n", helper.path, "check"],
                                               environment: environment.processEnvironment())
        guard result.succeeded else { return .notInstalled }
        let script = (try? String(contentsOf: environment.patchyBinary, encoding: .utf8)) ?? ""
        guard let expected = expectedHelperVersion(inScript: script) else { return .enabled }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines) == expected ? .enabled : .outdated
    }

    // MARK: Versions

    /// Homebrew installs run from a versioned Cellar path, which is where Patchy reads its own version.
    public static func patchyVersion(_ environment: PatchyEnvironment) -> String? {
        let components = environment.patchyBinary.resolvingSymlinksInPath().pathComponents
        guard let cellar = components.firstIndex(of: "Cellar"), cellar + 2 < components.count,
              components[cellar + 1] == "patchy" else { return nil }
        return components[cellar + 2]
    }

    public static func certificateAuthorityInstalled() -> Bool {
        let root = URL(fileURLWithPath: NSHomeDirectory())
            .appending(path: "Library/Application Support/mkcert/rootCA.pem")
        return FileManager.default.fileExists(atPath: root.path)
    }
}
