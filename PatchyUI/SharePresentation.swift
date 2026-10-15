import Foundation
import PatchyKit

/// Plain-language text about a site's public link.
enum ShareCopy {
    /// Temporary links come from Cloudflare's trycloudflare.com; anything else is the person's own domain.
    static func isTemporary(_ access: ShareAccess) -> Bool {
        access.url.host?.hasSuffix(".trycloudflare.com") ?? false
    }

    static func notice(for access: ShareAccess) -> String {
        if access.password != nil {
            return String(localized: "Anyone with this address and password can see this site until you stop sharing.", comment: "Under a shared site's address and password.")
        }
        if isTemporary(access) {
            return String(localized: "Anyone with this link can see this site until you stop sharing.", comment: "Under a shared site's temporary link.")
        }
        return String(localized: "Anyone with this address can see this site until you stop sharing.", comment: "Under a shared site's address when it needs no password.")
    }

    static func problem(output: String, wasSharing: Bool) -> String {
        if output.contains(PatchyOutput.apacheNotRunning) {
            return String(localized: "The server isn’t running. Start it, then share again.", comment: "Shown when sharing a site failed.")
        }
        if wasSharing {
            return String(localized: "Sharing stopped on its own, so the link no longer works.", comment: "Shown when a shared site's link stopped working.")
        }
        return String(localized: "Couldn’t get a public link. Check your internet connection and try again.", comment: "Shown when sharing a site failed.")
    }

    /// What Copy Address and Password puts on the clipboard, ready to paste into a message.
    /// The labels are copy; the address and password are not.
    static func clientMessage(for access: ShareAccess) -> String {
        guard let username = access.username, let password = access.password else { return access.url.absoluteString }
        let usernameLabel = String(localized: "Username", comment: "Label for a shared site's username.")
        let passwordLabel = String(localized: "Password", comment: "Label for a shared site's password.")
        return "\(access.url.absoluteString)\n\(usernameLabel): \(username)\n\(passwordLabel): \(password)"
    }
}
