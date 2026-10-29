import Foundation

public enum CertificateStatus: Sendable, Hashable {
    case valid(expires: Date)
    case invalid
    case missing

    /// Whole days until expiry, rounded the way Patchy does (negative once expired).
    public func daysLeft(now: Date = Date()) -> Int? {
        guard case .valid(let expires) = self else { return nil }
        let seconds = expires.timeIntervalSince(now)
        return Int((seconds < 0 ? seconds - 86399 : seconds) / 86400)
    }
}

public struct Site: Identifiable, Hashable, Sendable {
    public var address: String
    public var aliases: [String]
    public var folder: String
    public var folderExists: Bool
    public var certificate: CertificateStatus
    /// True when the address and every alias point at this Mac in /etc/hosts.
    public var isRouted: Bool
    /// The log files Apache writes for the site, as Patchy reports them.
    public var errorLog: String?
    public var accessLog: String?
    /// The site's stable address on the person's own domain, once it has been shared there.
    public var shareAddress: String?

    public var id: String { address }
    public var url: URL { URL(string: "https://\(address)")! }
    public var wwwAlias: String? { aliases.first { $0 == "www.\(address)" } }
    public var isRealAddress: Bool { AddressRules.isRealAddress(address) }
    public var hostNames: [String] { [address] + aliases }

    public init(address: String, aliases: [String] = [], folder: String, folderExists: Bool = true,
                certificate: CertificateStatus = .missing, isRouted: Bool = true,
                errorLog: String? = nil, accessLog: String? = nil, shareAddress: String? = nil) {
        self.address = address
        self.aliases = aliases
        self.folder = folder
        self.folderExists = folderExists
        self.certificate = certificate
        self.isRouted = isRouted
        self.errorLog = errorLog
        self.accessLog = accessLog
        self.shareAddress = shareAddress
    }
}
