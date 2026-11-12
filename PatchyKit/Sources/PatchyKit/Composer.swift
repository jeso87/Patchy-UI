import Foundation

/// The choices Total CMS 3's `composer create-project` asks about, passed as environment variables
/// so the install never prompts.
public struct TotalCMSOptions: Sendable, Equatable {
    public enum Layout: String, Sendable, CaseIterable {
        /// Total CMS owns the whole site; its front controller is `public/index.php`.
        case root
        /// Total CMS lives at `/tcms/`; its front controller is `public/tcms/index.php`.
        case subpath
    }

    public enum Starter: String, Sendable, CaseIterable {
        case none, minimal, blog, business, portfolio
    }

    public var layout: Layout = .root
    public var starter: Starter = .none
    public var frontend = false
    public var gitTemplates = true

    public init() {}

    /// The starter and frontend apply to the root layout only.
    public var environment: [String: String] {
        let root = layout == .root
        return [
            "TCMS_LAYOUT": layout.rawValue,
            "TCMS_STARTER": root ? starter.rawValue : Starter.none.rawValue,
            "TCMS_FRONTEND": root && frontend ? "1" : "0",
            "TCMS_GIT_TEMPLATES": gitTemplates ? "1" : "0",
        ]
    }

    /// Judged by the front controller existing, not by Composer's exit code.
    public func isInstalled(in project: URL) -> Bool {
        let path = layout == .root ? "public/index.php" : "public/tcms/index.php"
        return FileManager.default.fileExists(atPath: project.appending(path: path).path)
    }
}

public enum TotalCMS {
    /// Total CMS 3 needs PHP 8.2 or newer. `php` is major.minor, as `status --json` reports it.
    public static func supports(php: String?) -> Bool {
        guard let php else { return false }
        let parts = php.split(separator: ".").compactMap { Int($0) }
        guard let major = parts.first else { return false }
        let minor = parts.count > 1 ? parts[1] : 0
        return (major, minor) >= (8, 2)
    }

    /// The folder Patchy serves for a Composer-installed Total CMS project.
    public static func docroot(for project: URL) -> URL {
        project.appending(path: "public")
    }
}

public enum ProjectFolder {
    private static let finderLeftovers: Set<String> = [".DS_Store"]

    /// `composer create-project` needs an empty folder. Finder's `.DS_Store` doesn't count.
    public static func isEmpty(_ url: URL) -> Bool {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return false }
        return names.allSatisfy { finderLeftovers.contains($0) }
    }

    public static func removeFinderLeftovers(_ url: URL) {
        for name in finderLeftovers {
            try? FileManager.default.removeItem(at: url.appending(path: name))
        }
    }
}

/// A site's Composer project: `composer.json` in the site's folder, or in the folder above when
/// the site's folder is `public` (how Total CMS lays out a project). Never further up.
public struct ComposerProject: Sendable, Equatable {
    public let folder: URL
    public let usesTotalCMS: Bool

    public init(folder: URL, usesTotalCMS: Bool) {
        self.folder = folder
        self.usesTotalCMS = usesTotalCMS
    }

    public static func find(siteFolder: URL) -> ComposerProject? {
        var candidates = [siteFolder]
        if siteFolder.lastPathComponent == "public" { candidates.append(siteFolder.deletingLastPathComponent()) }
        for folder in candidates {
            let manifest = folder.appending(path: "composer.json")
            guard let data = FileManager.default.contents(atPath: manifest.path) else { continue }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let require = json?["require"] as? [String: Any]
            return ComposerProject(folder: folder, usesTotalCMS: require?["totalcms/cms"] != nil)
        }
        return nil
    }
}

/// A Composer command, run under the server's PHP so packages match the PHP that serves the site.
public struct ComposerCommand: Sendable, Equatable {
    public let executable: URL
    public let arguments: [String]
    public let environment: [String: String]
    /// Variables worth showing in Show Details (the install options).
    private let shownVariables: [String: String]

    private init(php: String, in env: PatchyEnvironment, _ composerArguments: [String], variables: [String: String] = [:]) {
        executable = env.phpBinary(version: php)
        arguments = [env.composerBinary.path] + composerArguments
        environment = env.processEnvironment(extra: variables.merging(["COMPOSER_NO_INTERACTION": "1"]) { a, _ in a })
        shownVariables = variables
    }

    public static func createProject(folder: URL, options: TotalCMSOptions, php: String, in env: PatchyEnvironment) -> ComposerCommand {
        ComposerCommand(php: php, in: env, ["create-project", "totalcms/totalcms", folder.path, "--no-interaction"],
                        variables: options.environment)
    }

    public static func update(project: URL, php: String, in env: PatchyEnvironment) -> ComposerCommand {
        ComposerCommand(php: php, in: env, ["update", "--no-interaction", "--working-dir=\(project.path)"])
    }

    /// The command as someone would type it, for Show Details.
    public var displayLine: String {
        let variables = shownVariables.keys.sorted { a, b in
            // TCMS_LAYOUT first, then the rest alphabetically, matching how the docs write it.
            a == "TCMS_LAYOUT" || (b != "TCMS_LAYOUT" && a < b)
        }.map { "\($0)=\(shownVariables[$0]!)" }
        return "$ " + (variables + ["composer"] + arguments.dropFirst()).joined(separator: " ")
    }
}
