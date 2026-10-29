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
    /// The installed Patchy has `patchy share` (added after 1.2.1).
    public var supportsSharing = false
    /// The domain `patchy share setup` connected, if any. Share then offers the domain or a temporary link.
    public var sharingDomain: String?
    /// `patchy share` needs Cloudflare's cloudflared.
    public var cloudflaredInstalled = false
    /// Apache's own error log.
    public var serverErrorLog: String?

    public init() {}
}
