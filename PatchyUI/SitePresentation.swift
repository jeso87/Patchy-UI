import Foundation
import PatchyKit

/// A site's health in plain language, as the list, detail pane and menu show it.
struct SiteStatus {
    struct Issue {
        var severity: Severity
        var text: String
    }

    struct Line {
        var severity: Severity
        var label: String
        var detail: String
    }

    var severity: Severity
    var summary: String
    var issues: [Issue]
    var certificate: Line
    var certificateNeedsRefresh: Bool
    var reachable: Line

    var hasProblem: Bool { !issues.isEmpty }

    init(site: Site, serverRunning: Bool, now: Date = Date()) {
        let certShort: String
        switch site.certificate {
        case .missing:
            certificate = Line(severity: .error, label: String(localized: "No certificate"),
                               detail: String(localized: "https:// won’t work for this site until certificates are refreshed."))
            certShort = String(localized: "No certificate")
        case .invalid:
            certificate = Line(severity: .error, label: String(localized: "Certificate can’t be read"),
                               detail: String(localized: "The certificate file is damaged. Refreshing certificates replaces it."))
            certShort = String(localized: "Certificate unreadable")
        case .valid(let expires):
            let days = site.certificate.daysLeft(now: now) ?? 0
            let date = expires.formatted(date: .abbreviated, time: .omitted)
            if days < 0 {
                certificate = Line(severity: .error, label: String(localized: "Certificate expired"),
                                   detail: String(localized: "Expired on \(date). Browsers will warn that this site isn’t secure.", comment: "Certificate detail. The placeholder is a date."))
                certShort = String(localized: "Certificate expired")
            } else if days <= 30 {
                certificate = Line(severity: .warning, label: Phrases.expiresIn(days: days),
                                   detail: String(localized: "Valid until \(date). Refresh before then to avoid browser warnings.", comment: "Certificate detail. The placeholder is a date."))
                certShort = Phrases.certificateExpiresIn(days: days)
            } else {
                certificate = Line(severity: .ok, label: String(localized: "Secure · \(days) days left", comment: "Certificate status in a site's details. Always more than 30 days."), detail: String(localized: "Valid until \(date).", comment: "Certificate detail. The placeholder is a date."))
                certShort = String(localized: "Secure · \(days) days", comment: "Short status in the sidebar for a healthy site: days until its certificate expires. Always more than 30.")
            }
        }
        certificateNeedsRefresh = certificate.severity != .ok

        var found: [Issue] = []
        if !site.folderExists { found.append(Issue(severity: .error, text: String(localized: "Folder missing", comment: "A site's problem, shown in the sidebar list and the menu bar menu."))) }
        if certificate.severity != .ok { found.append(Issue(severity: certificate.severity, text: certShort)) }
        if serverRunning && !site.isRouted { found.append(Issue(severity: .warning, text: String(localized: "Not pointing at this Mac", comment: "A site's problem, shown in the sidebar list and the menu bar menu."))) }
        issues = found.filter { $0.severity == .error } + found.filter { $0.severity != .error }

        if let first = issues.first {
            severity = first.severity
            summary = Phrases.statusSummary(first.text, more: issues.count - 1)
        } else if serverRunning {
            severity = .ok
            summary = certShort
        } else {
            severity = .off
            summary = String(localized: "Offline while the server is stopped")
        }

        if !serverRunning {
            reachable = Line(severity: .off, label: String(localized: "Not right now"), detail: String(localized: "The server is stopped."))
        } else if !site.isRouted {
            reachable = Line(severity: .warning, label: String(localized: "Not right now"),
                             detail: String(localized: "This address isn’t pointing at this Mac. Repair fixes it."))
        } else if !site.folderExists {
            reachable = Line(severity: .error, label: String(localized: "Opens, but shows an error"),
                             detail: String(localized: "There’s no folder to serve files from."))
        } else {
            reachable = Line(severity: .ok, label: String(localized: "Yes", comment: "Answer to “Reachable”: the site opens in a browser."), detail: String(localized: "Opens in any browser on this Mac."))
        }
    }
}

extension Site {
    /// The folder with the home directory shortened to ~.
    var displayFolder: String { (folder as NSString).abbreviatingWithTildeInPath }
}

extension URL {
    var displayPath: String { (path as NSString).abbreviatingWithTildeInPath }
}
