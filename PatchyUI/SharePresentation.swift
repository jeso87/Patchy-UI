import Foundation
import PatchyKit

/// Plain-language text about a site's public link.
enum ShareCopy {
    struct Choice: Hashable {
        let title: String
        let mode: ShareMode
    }

    /// What Share offers once a domain is connected. Empty without one: Share then makes a temporary link.
    /// The temporary link comes last; the menus put a divider before it.
    static func choices(sharingDomain: String?) -> [Choice] {
        guard let domain = sharingDomain else { return [] }
        return [
            Choice(title: String(localized: "Share at \(domain)", comment: "Share menu item: a stable address on the person's own domain, with a password. The placeholder is a domain like example.com."), mode: .domainWithPassword),
            Choice(title: String(localized: "Share at \(domain), No Password", comment: "Share menu item: a stable address on the person's own domain that anyone can open. The placeholder is a domain like example.com."), mode: .domainWithoutPassword),
            Choice(title: String(localized: "Share with a Temporary Link", comment: "Share menu item: a random link that works until sharing stops."), mode: .temporary),
        ]
    }

    static func notice(for access: ShareAccess) -> String {
        if access.password != nil {
            return String(localized: "Anyone with this address and password can see this site until you stop sharing.", comment: "Under a shared site's address and password.")
        }
        if access.isTemporary {
            return String(localized: "Anyone with this link can see this site until you stop sharing.", comment: "Under a shared site's temporary link.")
        }
        return String(localized: "Anyone with this address can see this site until you stop sharing.", comment: "Under a shared site's address when it needs no password.")
    }

    static func problem(_ failure: ShareFailure) -> String {
        if failure.code == PatchyError.apacheNotRunning {
            return String(localized: "The server isn’t running. Start it, then share again.", comment: "Shown when sharing a site failed.")
        }
        if failure.wasSharing {
            return String(localized: "Sharing stopped on its own, so the link no longer works.", comment: "Shown when a shared site's link stopped working.")
        }
        switch failure.code {
        case PatchyError.cloudflareLoginExpired:
            return String(localized: "Your Cloudflare login has expired. To connect your domain again, run patchy share setup in Terminal.", comment: "Shown when sharing a site failed. “patchy share setup” is a command; don't translate it.")
        case PatchyError.certificateMissing:
            return String(localized: "This site has no secure certificate yet. Refresh certificates, then share again.", comment: "Shown when sharing a site failed.")
        case PatchyError.tunnelDeleted:
            return String(localized: "This site’s tunnel was deleted in Cloudflare. Share again to set up a new one.", comment: "Shown when sharing a site failed. A tunnel is what Cloudflare calls the connection that carries a shared site.")
        case PatchyError.tunnelFailed, PatchyError.cloudflareError:
            return String(localized: "Couldn’t get a public link. Check your internet connection and try again.", comment: "Shown when sharing a site failed.")
        default:
            return String(localized: "Couldn’t share this site. Show Details has the exact message from Patchy.", comment: "Shown when sharing a site failed.")
        }
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
