import Foundation
import PatchyKit

/// What the menu bar panel lists. With no search: sites with a problem first, then each group,
/// then everything else. A search is one list, sites whose name starts with it first.
struct MenuPanelList {
    struct Row: Hashable {
        var address: String
        var severity: Severity
        /// The problem in a few words; empty for a healthy site.
        var note: String
    }

    struct Section: Identifiable {
        var title: String?
        var rows: [Row]
        var id: String { title ?? "" }
    }

    let sections: [Section]

    /// Every row, in the order shown; the arrow keys move through this.
    var rows: [Row] { sections.flatMap(\.rows) }

    init(rows: [Row], groups: SiteGroups, query: String) {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard query.isEmpty else {
            // The address itself starting with the search, then any part of it, then anywhere.
            func rank(_ row: Row) -> Int {
                if row.address.range(of: query, options: [.caseInsensitive, .anchored]) != nil { return 0 }
                if row.address.split(separator: ".").contains(where: { $0.range(of: query, options: [.caseInsensitive, .anchored]) != nil }) { return 1 }
                return 2
            }
            let matches = rows.filter { $0.address.localizedCaseInsensitiveContains(query) }
            let ordered = (0...2).flatMap { level in matches.filter { rank($0) == level } }
            sections = ordered.isEmpty ? [] : [Section(title: nil, rows: ordered)]
            return
        }

        let problems = rows.filter { $0.severity == .error } + rows.filter { $0.severity == .warning }
        let rest = rows.filter { !problems.contains($0) }
        let byAddress = Dictionary(rest.map { ($0.address, $0) }, uniquingKeysWith: { first, _ in first })
        let layout = groups.sections(for: rest.map(\.address))

        var result: [Section] = []
        if !problems.isEmpty {
            result.append(Section(title: String(localized: "Needs Attention", comment: "Heading in the menu bar panel over sites that have a problem."), rows: problems))
        }
        for entry in layout.groups where !entry.sites.isEmpty {
            result.append(Section(title: entry.group.name, rows: entry.sites.compactMap { byAddress[$0] }))
        }
        if !layout.ungrouped.isEmpty {
            let rows = layout.ungrouped.compactMap { byAddress[$0] }
            result.append(Section(title: result.isEmpty ? nil : String(localized: "Other Sites"), rows: rows))
        }
        sections = result
    }

    /// The row the highlight lands on after an arrow key; it stops at either end. With no
    /// highlight, the first row counts as highlighted, since that is what Return opens.
    func highlight(after current: String?, by step: Int) -> String? {
        let addresses = rows.map(\.address)
        guard !addresses.isEmpty else { return nil }
        let index = current.flatMap { addresses.firstIndex(of: $0) } ?? 0
        return addresses[min(max(index + step, 0), addresses.count - 1)]
    }

    /// What Return opens: the highlighted row, or the first one.
    func target(highlighted: String?) -> String? {
        if let highlighted, rows.contains(where: { $0.address == highlighted }) { return highlighted }
        return rows.first?.address
    }
}
