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
        String(localized: "\(count) need attention", comment: "How many websites have a problem, after a site count, e.g. “12 sites · 1 needs attention”.")
    }

    /// The sidebar footer: "12 sites", or "12 sites · 1 needs attention".
    static func footer(siteCount count: Int, problems: Int) -> String {
        problems == 0 ? siteCount(count) : siteCount(count) + " · " + needAttention(problems)
    }

    /// The menu bar item that jumps to the first site with a problem.
    static func sitesNeedAttention(_ count: Int) -> String {
        String(localized: "\(count) sites need attention…", comment: "Menu bar item that shows the first website with a problem.")
    }

    /// Tooltip on a sidebar group's warning mark.
    static func sitesInGroupNeedAttention(_ count: Int) -> String {
        String(localized: "\(count) sites in this group need attention", comment: "Tooltip on a sidebar group's warning mark.")
    }

    /// VoiceOver label for a sidebar group header: "Northwind, 3 sites, 1 needs attention".
    static func groupAccessibilityLabel(name: String, sites: Int, problems: Int) -> String {
        var parts = [name, siteCount(sites)]
        if problems > 0 { parts.append(needAttention(problems)) }
        return parts.joined(separator: ", ")
    }

    /// Settings › Certificates headline.
    static func sitesNeedNewCertificate(_ count: Int) -> String {
        String(localized: "\(count) sites need a new certificate", comment: "Settings › Certificates headline.")
    }

    /// The log view's copy button with lines selected.
    static func copyLines(_ count: Int) -> String {
        String(localized: "Copy \(count) Lines", comment: "Button that copies the selected log lines. Title case, like other buttons.")
    }

    /// The detail pane's certificate line when it expires within 30 days.
    static func expiresIn(days: Int) -> String {
        String(localized: "Expires in \(days) days", comment: "Certificate status in a site's details when it expires within 30 days.")
    }

    /// The same, as the short status shown in the sidebar.
    static func certificateExpiresIn(days: Int) -> String {
        String(localized: "Certificate expires in \(days) days", comment: "Short status in the sidebar when a site's certificate expires within 30 days.")
    }

    /// First progress step of refreshing certificates.
    static func makingCertificates(siteCount count: Int) -> String {
        String(localized: "Making new certificates for \(count) sites…", comment: "Progress step while refreshing every site's certificate.")
    }

    /// Title of the Refresh Certificates sheet.
    static func refreshCertificatesTitle(siteCount count: Int) -> String {
        String(localized: "Refresh certificates for all \(count) sites?",
               comment: "Sheet title. English's 'one' form says “your site” with no number; in languages whose 'one' category also covers 21, 31… the 'one' form must include the number.")
    }

    /// The banner shown while sites aren't routed to this Mac.
    static func unrouted(_ count: Int) -> String {
        String(localized: "\(count) sites aren’t pointing at this Mac right now, so they won’t open. Repair fixes this by restarting the server.",
               comment: "Banner while some sites' addresses don't lead to this Mac. Repair is the name of a toolbar button.")
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
