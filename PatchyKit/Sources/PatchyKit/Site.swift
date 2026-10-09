import Foundation
import Security

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

    public var id: String { address }
    public var url: URL { URL(string: "https://\(address)")! }
    public var wwwAlias: String? { aliases.first { $0 == "www.\(address)" } }
    public var isRealAddress: Bool { AddressRules.isRealAddress(address) }
    public var hostNames: [String] { [address] + aliases }

    public init(address: String, aliases: [String] = [], folder: String, folderExists: Bool = true,
                certificate: CertificateStatus = .missing, isRouted: Bool = true) {
        self.address = address
        self.aliases = aliases
        self.folder = folder
        self.folderExists = folderExists
        self.certificate = certificate
        self.isRouted = isRouted
    }
}

/// Reads and rewrites the per-site Apache config Patchy generates.
public enum Vhost {
    public struct Parsed: Equatable, Sendable {
        public var folder: String?
        public var aliases: [String]
    }

    public static func parse(_ text: String) -> Parsed {
        var folder: String?
        var aliases: [String] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if folder == nil, let value = quotedValue(of: "DocumentRoot", in: trimmed) {
                folder = value
            } else if trimmed.hasPrefix("ServerAlias") {
                let names = trimmed.split(whereSeparator: \.isWhitespace).dropFirst().map(String.init)
                for name in names where !aliases.contains(name) { aliases.append(name) }
            }
        }
        return Parsed(folder: folder, aliases: aliases.sorted())
    }

    /// Points every `DocumentRoot` and the matching `<Directory>` block at a new folder.
    /// Returns nil when the config has no folder to replace or the new path can't be quoted safely.
    public static func replacingFolder(in text: String, with newFolder: String) -> String? {
        guard let current = parse(text).folder,
              !newFolder.isEmpty,
              !newFolder.contains("\""), !newFolder.contains("\n"), !newFolder.contains("\r") else { return nil }
        var changed = false
        let lines = text.components(separatedBy: "\n").map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            if quotedValue(of: "DocumentRoot", in: trimmed) == current {
                changed = true
                return "\(indent)DocumentRoot \"\(newFolder)\""
            }
            if trimmed == "<Directory \"\(current)\">" {
                changed = true
                return "\(indent)<Directory \"\(newFolder)\">"
            }
            return line
        }
        return changed ? lines.joined(separator: "\n") : nil
    }

    private static func quotedValue(of directive: String, in trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix(directive) else { return nil }
        let rest = trimmedLine.dropFirst(directive.count)
        guard let first = rest.first, first.isWhitespace else { return nil }
        guard let open = rest.firstIndex(of: "\""), let close = rest.lastIndex(of: "\""), open < close else { return nil }
        return String(rest[rest.index(after: open)..<close])
    }
}

/// Patchy marks each of its /etc/hosts lines with a trailing "# patchy".
public enum HostsFile {
    /// Names that have both the IPv4 and IPv6 line Patchy writes.
    public static func routedNames(in text: String) -> Set<String> {
        var v4 = Set<String>(), v6 = Set<String>()
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasSuffix("# patchy") else { continue }
            let parts = trimmed.dropLast("# patchy".count).split(whereSeparator: \.isWhitespace)
            guard parts.count == 2 else { continue }
            if parts[0] == "127.0.0.1" { v4.insert(String(parts[1])) }
            if parts[0] == "::1" { v6.insert(String(parts[1])) }
        }
        return v4.intersection(v6)
    }
}

public enum CertificateReader {
    public static func status(of pemFile: URL) -> CertificateStatus {
        guard let text = try? String(contentsOf: pemFile, encoding: .utf8) else {
            return FileManager.default.fileExists(atPath: pemFile.path) ? .invalid : .missing
        }
        guard let expires = expiry(pem: text) else { return .invalid }
        return .valid(expires: expires)
    }

    public static func expiry(pem: String) -> Date? {
        guard let begin = pem.range(of: "-----BEGIN CERTIFICATE-----"),
              let end = pem.range(of: "-----END CERTIFICATE-----"), begin.upperBound < end.lowerBound else { return nil }
        let base64 = pem[begin.upperBound..<end.lowerBound].filter { !$0.isWhitespace }
        guard let der = Data(base64Encoded: String(base64)),
              let certificate = SecCertificateCreateWithData(nil, der as CFData) else { return nil }
        let keys = [kSecOIDX509V1ValidityNotAfter] as CFArray
        guard let values = SecCertificateCopyValues(certificate, keys, nil) as? [CFString: Any],
              let entry = values[kSecOIDX509V1ValidityNotAfter] as? [CFString: Any],
              let seconds = entry[kSecPropertyKeyValue] as? Double else { return nil }
        return Date(timeIntervalSinceReferenceDate: seconds)
    }
}

public enum SiteReader {
    public static func sites(in environment: PatchyEnvironment, hostsText: String) -> [Site] {
        let fm = FileManager.default
        let routed = HostsFile.routedNames(in: hostsText)
        let files = (try? fm.contentsOfDirectory(at: environment.sitesDir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "conf" }
            .compactMap { file -> Site? in
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
                let address = file.deletingPathExtension().lastPathComponent
                let parsed = Vhost.parse(text)
                let folder = parsed.folder ?? ""
                var isDirectory: ObjCBool = false
                let exists = fm.fileExists(atPath: folder, isDirectory: &isDirectory) && isDirectory.boolValue
                let names = [address] + parsed.aliases
                return Site(address: address, aliases: parsed.aliases, folder: folder, folderExists: exists,
                            certificate: CertificateReader.status(of: environment.certificateFile(for: address)),
                            isRouted: names.allSatisfy(routed.contains))
            }
            .sorted { $0.address < $1.address }
    }
}
