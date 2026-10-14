import Foundation

/// Copy that changes with a count or a list. Kept in one place so tests can pin the English,
/// and so the string catalog can give each language its own plural forms and word order.
enum Phrases {
    /// Between names in a list. English ", "; CJK languages use "、".
    static var listSeparator: String {
        String(localized: "list separator", defaultValue: ", ",
               comment: "Separates names in a list of websites or apps. English uses a comma and a space; CJK languages use 、")
    }

    /// The tail of a shortened list: "2 more".
    static func more(_ count: Int) -> String {
        String(localized: "\(count) more", comment: "How many names a shortened list left out, e.g. “a.com and b.com and 2 more”. Always 1 or more; give it your language's plural forms.")
    }

    /// The group suggestion card: "2 sites look related: acme.test, shop.acme.test".
    static func relatedSites(_ addresses: [String]) -> String {
        String(localized: "\(addresses.count) sites look related: \(addresses.joined(separator: listSeparator))",
               comment: "Sidebar suggestion to group websites with similar names. The count is always 2 or more, but give it your language's plural forms (in Russian, 21 takes the singular). The list is the addresses.")
    }

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
        // " · " joins two separate facts, as the sidebar and menu do elsewhere; it is not grammar.
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
        return parts.joined(separator: listSeparator)
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
        switch addresses.count {
        case 0:
            return ""
        case 1:
            return String(localized: "\(addresses[0]) now reaches the live website again.",
                          comment: "Banner after stopping the server. The placeholder is a real web address that this Mac no longer serves locally.")
        case 2:
            return String(localized: "\(addresses[0]) and \(addresses[1]) now reach the live websites again.",
                          comment: "Banner after stopping the server. Both placeholders are real web addresses.")
        default:
            return String(localized: "\(addresses[0]) and \(addresses[1]) and \(more(addresses.count - 2)) now reach the live websites again.",
                          comment: "Banner after stopping the server. Two real web addresses, then “N more”.")
        }
    }

    /// The server couldn't start because other apps hold ports 80 and 443.
    static func portsInUse(holders: [String]) -> String {
        switch holders.count {
        case 0:
            return String(localized: "Another app is already using the ports this server needs (80 and 443). Quit it, then start the server again.",
                          comment: "Why the web server couldn't start.")
        case 1:
            return String(localized: "\(holders[0]) is already using the ports this server needs (80 and 443). Quit it, then start the server again.",
                          comment: "Why the web server couldn't start. The placeholder is a program name, e.g. nginx.")
        default:
            return String(localized: "\(holders.joined(separator: listSeparator)) are already using the ports this server needs (80 and 443). Quit them, then start the server again.",
                          comment: "Why the web server couldn't start. The placeholder is a list of two or more program names.")
        }
    }

    /// Settings › Certificates: the first four addresses, then how many more.
    static func certificateList(_ addresses: [String]) -> String {
        let listed = addresses.prefix(4).joined(separator: listSeparator)
        guard addresses.count > 4 else { return listed }
        return String(localized: "\(listed) and \(more(addresses.count - 4))",
                      comment: "A shortened list of web addresses: the first four, then “N more”.")
    }

    /// A site's one-line status: its worst issue, then how many others.
    static func statusSummary(_ first: String, more count: Int) -> String {
        guard count > 0 else { return first }
        return String(localized: "\(first) · \(more(count))",
                      comment: "A site's status: its worst problem, then how many other problems it has.")
    }
}
