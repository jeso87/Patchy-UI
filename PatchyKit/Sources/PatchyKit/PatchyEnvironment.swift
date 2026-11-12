import Foundation

/// Where Homebrew and the `patchy` command are on this Mac. Patchy's own files are internal to it,
/// so the app asks the command rather than reading them.
public struct PatchyEnvironment: Sendable, Equatable {
    public let brewPrefix: URL
    /// Debug builds can run a Patchy from elsewhere, such as a clone with unreleased commands.
    public var patchyOverride: URL?

    public init(brewPrefix: URL) {
        self.brewPrefix = brewPrefix
    }

    public enum Detection: Sendable, Equatable {
        case ready(PatchyEnvironment)
        case missingPatchy
        case missingHomebrew
    }

    public static let defaultPrefixes = [
        URL(fileURLWithPath: "/opt/homebrew"),
        URL(fileURLWithPath: "/usr/local"),
    ]

    public static func detect(prefixes: [URL] = defaultPrefixes) -> Detection {
        let fm = FileManager.default
        var foundBrew = false
        for prefix in prefixes {
            guard fm.isExecutableFile(atPath: prefix.appending(path: "bin/brew").path) else { continue }
            foundBrew = true
            let env = PatchyEnvironment(brewPrefix: prefix)
            if fm.isExecutableFile(atPath: env.patchyBinary.path) {
                return .ready(env)
            }
        }
        return foundBrew ? .missingPatchy : .missingHomebrew
    }

    public var patchyBinary: URL { patchyOverride ?? brewPrefix.appending(path: "bin/patchy") }
    public var optDir: URL { brewPrefix.appending(path: "opt") }

    /// Homebrew's Composer, a PHP script the app runs under a chosen PHP.
    public var composerBinary: URL { brewPrefix.appending(path: "bin/composer") }
    public var composerInstalled: Bool { FileManager.default.isExecutableFile(atPath: composerBinary.path) }
    /// Total CMS's frontend pipeline builds during the install only when Node is present.
    public var nodeInstalled: Bool { FileManager.default.isExecutableFile(atPath: brewPrefix.appending(path: "bin/node").path) }

    /// The PHP binary for a major.minor version. Homebrew keeps an `opt/php@X.Y` link for the
    /// unversioned `php` formula too, so this works whichever formula provides it.
    public func phpBinary(version: String) -> URL {
        optDir.appending(path: "php@\(version)/bin/php")
    }

    /// Environment for child processes. An app launched from Finder has no shell PATH,
    /// and patchy shells out to brew, jq, mkcert, apachectl and php.
    public func processEnvironment(extra: [String: String] = [:]) -> [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var env: [String: String] = [
            "PATH": "\(brewPrefix.path)/bin:\(brewPrefix.path)/sbin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": NSHomeDirectory(),
            "USER": NSUserName(),
            "LOGNAME": NSUserName(),
            "LANG": "en_US.UTF-8",
            "HOMEBREW_NO_AUTO_UPDATE": "1",
            "HOMEBREW_NO_ENV_HINTS": "1",
        ]
        if let tmp = inherited["TMPDIR"] { env["TMPDIR"] = tmp }
        env.merge(extra) { _, new in new }
        return env
    }
}
