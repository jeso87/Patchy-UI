import Foundation

/// Copy that changes with a count or a list. Kept in one place so tests can pin the English,
/// and so the string catalog can give each language its own plural forms and word order.
enum Phrases {
    /// "1 site", "12 sites".
    static func siteCount(_ count: Int) -> String {
        String(localized: "\(count) sites", comment: "A number of websites, e.g. in the window subtitle and the sidebar footer.")
    }

    /// "1 needs attention", "3 need attention".
    static func needAttention(_ count: Int) -> String {
        "\(count) need\(count == 1 ? "s" : "") attention"
    }

    /// The sidebar footer: "12 sites", or "12 sites · 1 needs attention".
    static func footer(siteCount count: Int, problems: Int) -> String {
        problems == 0 ? siteCount(count) : siteCount(count) + " · " + needAttention(problems)
    }

    /// The menu bar item that jumps to the first site with a problem.
    static func sitesNeedAttention(_ count: Int) -> String {
        "\(pluralized(count, "site")) need\(count == 1 ? "s" : "") attention…"
    }

    /// Tooltip on a sidebar group's warning mark.
    static func sitesInGroupNeedAttention(_ count: Int) -> String {
        "\(pluralized(count, "site")) in this group need\(count == 1 ? "s" : "") attention"
    }

    /// VoiceOver label for a sidebar group header: "Northwind, 3 sites, 1 needs attention".
    static func groupAccessibilityLabel(name: String, sites: Int, problems: Int) -> String {
        var parts = [name, siteCount(sites)]
        if problems > 0 { parts.append(needAttention(problems)) }
        return parts.joined(separator: ", ")
    }

    /// Settings › Certificates headline.
    static func sitesNeedNewCertificate(_ count: Int) -> String {
        "\(pluralized(count, "site")) need\(count == 1 ? "s" : "") a new certificate"
    }

    /// The log view's copy button with lines selected.
    static func copyLines(_ count: Int) -> String {
        "Copy \(pluralized(count, "Line"))"
    }

    /// The detail pane's certificate line when it expires within 30 days.
    static func expiresIn(days: Int) -> String {
        "Expires in \(pluralized(days, "day"))"
    }

    /// The same, as the short status shown in the sidebar.
    static func certificateExpiresIn(days: Int) -> String {
        "Certificate expires in \(pluralized(days, "day"))"
    }

    /// First progress step of refreshing certificates.
    static func makingCertificates(siteCount count: Int) -> String {
        "Making new certificates for \(pluralized(count, "site"))…"
    }

    /// Title of the Refresh Certificates sheet.
    static func refreshCertificatesTitle(siteCount count: Int) -> String {
        "Refresh certificates for \(count == 1 ? "your site" : "all \(count) sites")?"
    }

    /// The banner shown while sites aren't routed to this Mac.
    static func unrouted(_ count: Int) -> String {
        "\(count) site\(count == 1 ? " isn’t" : "s aren’t") pointing at this Mac right now, so \(count == 1 ? "it won’t" : "they won’t") open. Repair fixes this by restarting the server."
    }

    /// After stopping the server: which real addresses reach the internet again.
    static func liveAgain(_ addresses: [String]) -> String {
        let names = addresses.prefix(2).joined(separator: " and ") + (addresses.count > 2 ? " and \(addresses.count - 2) more" : "")
        return "\(names) now reach\(addresses.count > 1 ? "" : "es") the live website\(addresses.count > 1 ? "s" : "") again."
    }

    /// The server couldn't start because other apps hold ports 80 and 443.
    static func portsInUse(holders: [String]) -> String {
        let who = holders.isEmpty ? "Another app" : holders.joined(separator: ", ")
        return "\(who) \(holders.count > 1 ? "are" : "is") already using the ports this server needs (80 and 443). Quit \(holders.count > 1 ? "them" : "it"), then start the server again."
    }

    /// Settings › Certificates: the first four addresses, then how many more.
    static func certificateList(_ addresses: [String]) -> String {
        addresses.prefix(4).joined(separator: ", ") + (addresses.count > 4 ? " and \(addresses.count - 4) more" : "")
    }

    /// A site's one-line status: its worst issue, then how many others.
    static func statusSummary(_ first: String, more: Int) -> String {
        first + (more > 0 ? " · \(more) more" : "")
    }
}
