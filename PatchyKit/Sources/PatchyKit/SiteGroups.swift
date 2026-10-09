import Foundation

/// A named set of sites, such as one customer's domain and subdomains.
/// Groups exist only in Patchy UI; Patchy itself knows nothing about them.
public struct SiteGroup: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var sites: [String]
    public var isCollapsed: Bool

    public init(id: UUID = UUID(), name: String, sites: [String] = [], isCollapsed: Bool = false) {
        self.id = id
        self.name = name
        self.sites = sites
        self.isCollapsed = isCollapsed
    }
}

public struct SiteGroups: Codable, Equatable, Sendable {
    public struct Suggestion: Equatable, Identifiable, Sendable {
        /// The shared name the sites were matched on; also what a dismissal is remembered by.
        public var key: String
        public var name: String
        public var sites: [String]
        public var id: String { key }
    }

    public struct Sections: Equatable, Sendable {
        public var groups: [(group: SiteGroup, sites: [String])]
        public var ungrouped: [String]

        public static func == (lhs: Sections, rhs: Sections) -> Bool {
            lhs.ungrouped == rhs.ungrouped && lhs.groups.count == rhs.groups.count
                && zip(lhs.groups, rhs.groups).allSatisfy { $0.group == $1.group && $0.sites == $1.sites }
        }
    }

    public var groups: [SiteGroup] = []
    public var dismissedSuggestions: [String] = []

    public init() {}

    public func group(of address: String) -> SiteGroup? {
        groups.first { $0.sites.contains(address) }
    }

    @discardableResult
    public mutating func createGroup(named name: String, sites: [String] = []) -> UUID {
        for address in sites { remove(address) }
        let group = SiteGroup(name: Self.cleaned(name), sites: sites)
        groups.append(group)
        return group.id
    }

    public mutating func rename(_ id: UUID, to name: String) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[index].name = Self.cleaned(name)
    }

    /// Deleting a group only forgets the grouping; its sites become ungrouped.
    public mutating func delete(_ id: UUID) {
        groups.removeAll { $0.id == id }
    }

    /// A site is in at most one group. Passing nil removes it from its group.
    public mutating func assign(_ address: String, to id: UUID?) {
        remove(address)
        guard let id, let index = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[index].sites.append(address)
    }

    public mutating func setCollapsed(_ collapsed: Bool, for id: UUID) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[index].isCollapsed = collapsed
    }

    /// Forget a site that was removed from Patchy.
    public mutating func remove(_ address: String) {
        for index in groups.indices { groups[index].sites.removeAll { $0 == address } }
    }

    public mutating func dismiss(_ suggestion: Suggestion) {
        if !dismissedSuggestions.contains(suggestion.key) { dismissedSuggestions.append(suggestion.key) }
    }

    /// The sidebar's layout: groups by name, each with its sites that still exist, then everything else.
    /// `addresses` is the list to lay out, in display order.
    public func sections(for addresses: [String]) -> Sections {
        let sorted = groups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        var claimed = Set<String>()
        var result: [(group: SiteGroup, sites: [String])] = []
        for group in sorted {
            let members = addresses.filter { group.sites.contains($0) && !claimed.contains($0) }
            claimed.formUnion(members)
            result.append((group, members))
        }
        return Sections(groups: result, ungrouped: addresses.filter { !claimed.contains($0) })
    }

    // MARK: Suggestions

    /// The part of an address a customer is usually known by: `acme` in `shop.acme.test`.
    static func familyName(of address: String) -> String {
        let labels = address.split(separator: ".")
        return labels.count >= 2 ? String(labels[labels.count - 2]) : address
    }

    /// Ungrouped sites that look related: the same name under different subdomains or endings
    /// (`acme.test`, `shop.acme.test`, `acme.com`), or names that extend a shared one of four or more
    /// letters (`topbonn.test`, `topbonnportal.test`). Only ever offered, never applied.
    public func suggestions(for addresses: [String]) -> [Suggestion] {
        let ungrouped = addresses.filter { group(of: $0) == nil }
        let names = Set(ungrouped.map(Self.familyName)).sorted { ($0.count, $0) < ($1.count, $1) }
        var roots: [String] = []
        for name in names where !roots.contains(where: { $0.count >= 4 && name.hasPrefix($0) }) {
            roots.append(name)
        }
        return roots.compactMap { root -> Suggestion? in
            let members = ungrouped.filter {
                let name = Self.familyName(of: $0)
                return name == root || (root.count >= 4 && name.hasPrefix(root))
            }
            guard members.count >= 2, !dismissedSuggestions.contains(root) else { return nil }
            return Suggestion(key: root, name: root.prefix(1).uppercased() + root.dropFirst(), sites: members.sorted())
        }
        .sorted { $0.key < $1.key }
    }

    private static func cleaned(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Group" : trimmed
    }
}

/// Keeps groups in a small JSON file in Application Support.
public struct SiteGroupStore: Sendable {
    public let file: URL

    public init(file: URL) {
        self.file = file
    }

    public static var standard: SiteGroupStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support")
        return SiteGroupStore(file: support.appending(path: "Patchy UI/groups.json"))
    }

    public func load() -> SiteGroups {
        guard let data = try? Data(contentsOf: file),
              let groups = try? JSONDecoder().decode(SiteGroups.self, from: data) else { return SiteGroups() }
        return groups
    }

    public func save(_ groups: SiteGroups) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(groups) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }
}
