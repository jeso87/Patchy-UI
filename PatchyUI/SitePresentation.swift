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
            certificate = Line(severity: .error, label: "No certificate",
                               detail: "https:// won’t work for this site until certificates are refreshed.")
            certShort = "No certificate"
        case .invalid:
            certificate = Line(severity: .error, label: "Certificate can’t be read",
                               detail: "The certificate file is damaged. Refreshing certificates replaces it.")
            certShort = "Certificate unreadable"
        case .valid(let expires):
            let days = site.certificate.daysLeft(now: now) ?? 0
            let date = expires.formatted(date: .abbreviated, time: .omitted)
            if days < 0 {
                certificate = Line(severity: .error, label: "Certificate expired",
                                   detail: "Expired on \(date). Browsers will warn that this site isn’t secure.")
                certShort = "Certificate expired"
            } else if days <= 30 {
                certificate = Line(severity: .warning, label: "Expires in \(pluralized(days, "day"))",
                                   detail: "Valid until \(date). Refresh before then to avoid browser warnings.")
                certShort = "Certificate expires in \(pluralized(days, "day"))"
            } else {
                certificate = Line(severity: .ok, label: "Secure · \(days) days left", detail: "Valid until \(date).")
                certShort = "Secure · \(days) days"
            }
        }
        certificateNeedsRefresh = certificate.severity != .ok

        var found: [Issue] = []
        if !site.folderExists { found.append(Issue(severity: .error, text: "Folder missing")) }
        if certificate.severity != .ok { found.append(Issue(severity: certificate.severity, text: certShort)) }
        if serverRunning && !site.isRouted { found.append(Issue(severity: .warning, text: "Not pointing at this Mac")) }
        issues = found.filter { $0.severity == .error } + found.filter { $0.severity != .error }

        if let first = issues.first {
            severity = first.severity
            summary = first.text + (issues.count > 1 ? " · \(issues.count - 1) more" : "")
        } else if serverRunning {
            severity = .ok
            summary = certShort
        } else {
            severity = .off
            summary = "Offline while the server is stopped"
        }

        if !serverRunning {
            reachable = Line(severity: .off, label: "Not right now", detail: "The server is stopped.")
        } else if !site.isRouted {
            reachable = Line(severity: .warning, label: "Not right now",
                             detail: "This address isn’t pointing at this Mac. Repair fixes it.")
        } else if !site.folderExists {
            reachable = Line(severity: .error, label: "Opens, but shows an error",
                             detail: "There’s no folder to serve files from.")
        } else {
            reachable = Line(severity: .ok, label: "Yes", detail: "Also from phones and other devices on your network.")
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
