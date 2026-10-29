import Foundation
import PatchyKit

/// Plain-language text about a site's public link.
enum ShareCopy {
    struct Choice: Hashable {
        let title: String
        /// What sharing runs. Nil for Change Address…, which asks for a name first.
        let mode: ShareMode?
        /// Menus put a divider between sections.
        let section: Int
    }

    /// The host a site is shared at on the domain: the address it was last shared at, or the one
    /// Patchy would give it (harbor.test → harbor.example.com).
    static func host(for site: Site, sharingDomain domain: String) -> String {
        if let address = site.shareAddress, let host = URL(string: address)?.host, host.hasSuffix(".\(domain)") {
            return host
        }
        return "\(ShareMode.defaultName(for: site.address)).\(domain)"
    }

    /// What Share offers once a domain is connected: the site's own address with or without a
    /// password, a random address on the domain with or without one, and an anonymous link.
    /// Empty without a domain: Share then makes an anonymous link.
    static func choices(for site: Site, sharingDomain: String?) -> [Choice] {
        guard let domain = sharingDomain else { return [] }
        let host = host(for: site, sharingDomain: domain)
        return [
            Choice(title: String(localized: "Share at \(host)", comment: "Share menu item: the site's own address on the person's domain, with a password. The placeholder is an address like harbor.example.com."), mode: .domainWithPassword, section: 0),
            Choice(title: String(localized: "Share at \(host), No Password", comment: "Share menu item: the site's own address on the person's domain, open to anyone. The placeholder is an address like harbor.example.com."), mode: .domainWithoutPassword, section: 0),
            Choice(title: String(localized: "Change Address…", comment: "Share menu item: choose the name before the domain in the site's shared address."), mode: nil, section: 0),
            Choice(title: String(localized: "Share at a Random \(domain) Address", comment: "Share menu item: a random address on the person's domain, new each time, open to anyone. The placeholder is a domain like example.com."), mode: .temporary, section: 1),
            Choice(title: String(localized: "Share at a Random \(domain) Address, with Password", comment: "Share menu item: a random address on the person's domain, new each time, with a password. The placeholder is a domain like example.com."), mode: .temporaryWithPassword, section: 1),
            Choice(title: String(localized: "Share with a Public Link (trycloudflare.com)", comment: "Share menu item: an anonymous link on trycloudflare.com that works until sharing stops. Keep “trycloudflare.com” as it is."), mode: .anonymous, section: 2),
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
        case PatchyError.nameTaken:
            return String(localized: "That address is already used on your domain. Use Change Address… to choose another.", comment: "Shown when sharing a site failed. “Change Address…” is a menu item.")
        case PatchyError.invalidName:
            return String(localized: "That name can’t be used in a web address. Use lowercase letters, numbers and hyphens.", comment: "Shown when sharing a site failed.")
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
