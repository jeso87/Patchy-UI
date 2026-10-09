import Foundation

/// Patchy UI's version follows the Patchy release it was built and tested against: Patchy UI 1.2.1
/// supports Patchy 1.2.1. A fourth component (1.2.1.1) is an app-only fix for the same Patchy release.
public enum PatchyCompatibility: Equatable, Sendable {
    case matched
    /// Patchy was upgraded past what this app was tested with.
    case patchyNewer(installed: String, supported: String)
    /// The app expects a newer Patchy than the one installed.
    case patchyOlder(installed: String, supported: String)
    case unknown

    /// The Patchy release an app version was made for: its first three components.
    public static func supportedPatchyVersion(appVersion: String) -> String {
        appVersion.split(separator: ".").prefix(3).joined(separator: ".")
    }

    public static func check(appVersion: String, patchyVersion: String?) -> PatchyCompatibility {
        let supported = supportedPatchyVersion(appVersion: appVersion)
        guard let patchyVersion, let installed = numbers(patchyVersion), let expected = numbers(supported) else {
            return .unknown
        }
        if installed == expected { return .matched }
        return installed.lexicographicallyPrecedes(expected)
            ? .patchyOlder(installed: patchyVersion, supported: supported)
            : .patchyNewer(installed: patchyVersion, supported: supported)
    }

    /// "1.2.1" → [1, 2, 1], padded so 1.2 and 1.2.0 compare equal. Nil for source installs ("dev", git describe output).
    private static func numbers(_ version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.count <= 3, !parts.contains(nil) else { return nil }
        return (parts.compactMap { $0 } + [0, 0, 0]).prefix(3).map { $0 }
    }
}
