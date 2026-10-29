import Foundation

/// The rules Patchy applies to site addresses, mirrored so the app can explain them before adding a site.
public enum AddressRules {
    public enum Problem: Error, Equatable, Sendable {
        case invalidCharacters
        case unfinished
        case alreadyExists(String)
    }

    /// What the user typed, turned into the address Patchy will create.
    /// A bare name gets `.test`; anything with a dot is used as typed.
    public static func finalAddress(from input: String) -> String {
        let raw = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !raw.isEmpty else { return "" }
        return raw.contains(".") ? raw : raw + ".test"
    }

    public static func usesDefaultSuffix(_ input: String) -> Bool {
        !input.contains(".")
    }

    public static func problem(with input: String, existing: some Collection<String>) -> Problem? {
        let raw = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !raw.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        if raw.unicodeScalars.contains(where: { !allowed.contains($0) }) { return .invalidCharacters }
        if raw.hasPrefix(".") || raw.hasPrefix("-") || raw.hasSuffix(".") || raw.hasSuffix("-") || raw.contains("..") {
            return .unfinished
        }
        let final = finalAddress(from: raw)
        if existing.contains(final) { return .alreadyExists(final) }
        return nil
    }

    /// Patchy offers a www alias only for two-label addresses that don't already start with www.
    public static func offersWWW(_ address: String) -> Bool {
        !address.hasPrefix("www.") && address.split(separator: ".", omittingEmptySubsequences: false).count == 2
    }

    /// Anything outside .test and .local may be a real website.
    public static func isRealAddress(_ address: String) -> Bool {
        guard let tld = address.split(separator: ".").last else { return false }
        return tld != "test" && tld != "local"
    }

}
