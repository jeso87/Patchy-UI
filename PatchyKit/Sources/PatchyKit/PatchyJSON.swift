import Foundation

/// What `patchy … --json` prints. It is Patchy's supported interface: its config files and
/// folders are internal and change between releases, so the app reads state only through these.
enum PatchyJSON {
    struct Version: Decodable {
        var version: String
        var features: [String]
    }

    struct Status: Decodable {
        struct Apache: Decodable { var running: Bool }
        struct PHP: Decodable {
            struct Install: Decodable { var full: String; var version: String }
            var active: String?
            var installed: [Install]
        }
        struct Authority: Decodable { var exists: Bool }
        struct Share: Decodable { var domain: String?; var cloudflared: Bool }
        struct Paths: Decodable { var error_log: String }

        var apache: Apache
        var php: PHP
        var trust: String
        var certificate_authority: Authority
        var share: Share
        var paths: Paths
    }

    struct List: Decodable {
        struct Entry: Decodable {
            struct Certificate: Decodable { var state: String; var expires: String? }
            struct Logs: Decodable { var error: String?; var access: String? }
            struct Share: Decodable { var address: String? }

            var domain: String
            var docroot: String
            var docroot_exists: Bool
            var aliases: [String]
            var certificate: Certificate
            var routed: Bool
            var logs: Logs
            var share: Share
        }

        var sites: [Entry]
    }

    /// One line of `share --json`.
    struct ShareEvent: Decodable {
        struct Auth: Decodable { var username: String; var password: String }

        var event: String
        var url: String?
        var mode: String?
        var auth: Auth?
        var error: String?
        var message: String?
        var details: String?
    }

    /// The JSON document in a command's output. Standard error is merged in, so anything around
    /// the document is skipped.
    static func document<T: Decodable>(_ type: T.Type, in output: String) -> T? {
        guard let start = output.firstIndex(of: "{"), let end = output.lastIndex(of: "}"), start < end else { return nil }
        return try? JSONDecoder().decode(type, from: Data(output[start...end].utf8))
    }

    /// The last line of output that decodes as `T`.
    static func lastLine<T: Decodable>(_ type: T.Type, in output: String) -> T? {
        for line in output.split(whereSeparator: \.isNewline).reversed() where line.hasPrefix("{") {
            if let value = try? JSONDecoder().decode(type, from: Data(line.utf8)) { return value }
        }
        return nil
    }
}

extension Site {
    init(_ entry: PatchyJSON.List.Entry) {
        let certificate: CertificateStatus
        switch entry.certificate.state {
        case "none": certificate = .missing
        case "ok", "expiring", "expired":
            if let expires = entry.certificate.expires.flatMap({ try? Date($0, strategy: .iso8601) }) {
                certificate = .valid(expires: expires)
            } else {
                certificate = .invalid
            }
        default: certificate = .invalid
        }
        self.init(address: entry.domain, aliases: entry.aliases.sorted(), folder: entry.docroot,
                  folderExists: entry.docroot_exists, certificate: certificate, isRouted: entry.routed,
                  errorLog: entry.logs.error, accessLog: entry.logs.access, shareAddress: entry.share.address)
    }
}

extension PatchySnapshot {
    init(status: PatchyJSON.Status, list: PatchyJSON.List, version: PatchyVersion?) {
        self.init()
        sites = list.sites.map(Site.init).sorted { $0.address < $1.address }
        serverRunning = status.apache.running
        activePHP = status.php.active
        installedPHP = status.php.installed
            .map { PHPInstall(version: $0.version, fullVersion: $0.full) }
            .sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
        switch status.trust {
        case "enabled": trust = .enabled
        case "outdated": trust = .outdated
        default: trust = .notInstalled
        }
        patchyVersion = version?.version
        certificateAuthorityInstalled = status.certificate_authority.exists
        supportsSharing = version?.features.contains("share") ?? false
        sharingDomain = status.share.domain
        cloudflaredInstalled = status.share.cloudflared
        serverErrorLog = status.paths.error_log
    }
}

/// The installed Patchy's version and what it can do.
public struct PatchyVersion: Sendable, Equatable {
    public var version: String
    public var features: [String]

    /// `version --json`, or the plain `patchy 1.2.1` an older Patchy prints instead.
    static func parse(_ output: String) -> PatchyVersion? {
        if let json = PatchyJSON.document(PatchyJSON.Version.self, in: output) {
            return PatchyVersion(version: json.version, features: json.features)
        }
        let words = output.split(whereSeparator: \.isWhitespace)
        guard let index = words.firstIndex(of: "patchy"), index + 1 < words.count else { return nil }
        return PatchyVersion(version: String(words[index + 1]), features: [])
    }
}

/// The one line a changing command prints with `--json`.
public struct PatchyResult: Sendable, Equatable, Decodable {
    public struct Warning: Sendable, Equatable, Decodable {
        public var code: String
        public var message: String
        public var site: String?
    }

    public var ok: Bool
    /// A code that stays the same between Patchy releases, such as `site_exists`. See `PatchyError`.
    public var error: String?
    public var message: String?
    public var details: String?
    public var warnings: [Warning]

    static func parse(_ output: String) -> PatchyResult? {
        PatchyJSON.lastLine(PatchyResult.self, in: output)
    }
}

/// The error codes Patchy's `--json` output carries. They stay the same between releases, unlike
/// its messages, so the app matches these and never Patchy's English.
public enum PatchyError {
    public static let siteExists = "site_exists"
    public static let sudoRequired = "sudo_required"
    public static let hostsUpdateFailed = "hosts_update_failed"
    public static let cancelled = "cancelled"
    public static let configInvalid = "config_invalid"
    public static let portInUse = "port_in_use"
    public static let serviceStuck = "service_stuck"
    public static let unsafePath = "unsafe_path"
    public static let terminalRequired = "terminal_required"
    public static let apacheNotRunning = "apache_not_running"
    public static let cloudflaredMissing = "cloudflared_missing"
    public static let cloudflareLoginExpired = "cloudflare_login_expired"
    public static let certificateMissing = "certificate_missing"
    public static let tunnelDeleted = "tunnel_deleted"
    public static let tunnelFailed = "tunnel_failed"
    public static let tunnelStopped = "tunnel_stopped"
    public static let cloudflareError = "cloudflare_error"
}
