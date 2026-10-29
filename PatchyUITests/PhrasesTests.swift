import Testing
@testable import Patchy_UI

/// Pins the exact English of every count- and list-dependent phrase. From Task 3 on these
/// strings come from the catalog; these tests must keep passing unmodified.
@Suite struct PhrasesTests {
    @Test func todayCounts() {
        #expect(Phrases.errorsToday(0) == "None")
        #expect(Phrases.errorsToday(1) == "1 error")
        #expect(Phrases.errorsToday(4) == "4 errors")
        #expect(Phrases.visitsToday(0) == "None")
        #expect(Phrases.visitsToday(1) == "1 visit")
        #expect(Phrases.visitsToday(196) == "196 visits")
    }

    @Test func siteCount() {
        #expect(Phrases.siteCount(0) == "0 sites")
        #expect(Phrases.siteCount(1) == "1 site")
        #expect(Phrases.siteCount(2) == "2 sites")
    }

    @Test func needAttention() {
        #expect(Phrases.needAttention(1) == "1 needs attention")
        #expect(Phrases.needAttention(3) == "3 need attention")
    }

    @Test func footer() {
        #expect(Phrases.footer(siteCount: 12, problems: 0) == "12 sites")
        #expect(Phrases.footer(siteCount: 12, problems: 1) == "12 sites · 1 needs attention")
        #expect(Phrases.footer(siteCount: 1, problems: 3) == "1 site · 3 need attention")
    }

    @Test func menuAttentionItem() {
        #expect(Phrases.sitesNeedAttention(1) == "1 site needs attention…")
        #expect(Phrases.sitesNeedAttention(2) == "2 sites need attention…")
    }

    @Test func groupAttentionTooltip() {
        #expect(Phrases.sitesInGroupNeedAttention(1) == "1 site in this group needs attention")
        #expect(Phrases.sitesInGroupNeedAttention(2) == "2 sites in this group need attention")
    }

    @Test func groupAccessibilityLabel() {
        #expect(Phrases.groupAccessibilityLabel(name: "Northwind", sites: 3, problems: 0) == "Northwind, 3 sites")
        #expect(Phrases.groupAccessibilityLabel(name: "Northwind", sites: 1, problems: 1) == "Northwind, 1 site, 1 needs attention")
        #expect(Phrases.groupAccessibilityLabel(name: "Northwind", sites: 3, problems: 2) == "Northwind, 3 sites, 2 need attention")
    }

    @Test func certificateHeadline() {
        #expect(Phrases.sitesNeedNewCertificate(1) == "1 site needs a new certificate")
        #expect(Phrases.sitesNeedNewCertificate(3) == "3 sites need a new certificate")
    }

    @Test func copyLines() {
        #expect(Phrases.copyLines(1) == "Copy 1 Line")
        #expect(Phrases.copyLines(2) == "Copy 2 Lines")
    }

    @Test func expiry() {
        #expect(Phrases.expiresIn(days: 1) == "Expires in 1 day")
        #expect(Phrases.expiresIn(days: 12) == "Expires in 12 days")
        #expect(Phrases.certificateExpiresIn(days: 1) == "Certificate expires in 1 day")
        #expect(Phrases.certificateExpiresIn(days: 30) == "Certificate expires in 30 days")
    }

    @Test func refreshCertificates() {
        #expect(Phrases.makingCertificates(siteCount: 1) == "Making new certificates for 1 site…")
        #expect(Phrases.makingCertificates(siteCount: 26) == "Making new certificates for 26 sites…")
        #expect(Phrases.refreshCertificatesTitle(siteCount: 1) == "Refresh certificates for your site?")
        #expect(Phrases.refreshCertificatesTitle(siteCount: 5) == "Refresh certificates for all 5 sites?")
    }

    @Test func unroutedBanner() {
        #expect(Phrases.unrouted(1) == "1 site isn’t pointing at this Mac right now, so it won’t open. Repair fixes this by restarting the server.")
        #expect(Phrases.unrouted(2) == "2 sites aren’t pointing at this Mac right now, so they won’t open. Repair fixes this by restarting the server.")
    }

    @Test func liveAgain() {
        #expect(Phrases.liveAgain(["a.com"]) == "a.com now reaches the live website again.")
        #expect(Phrases.liveAgain(["a.com", "b.com"]) == "a.com and b.com now reach the live websites again.")
        #expect(Phrases.liveAgain(["a.com", "b.com", "c.com"]) == "a.com and b.com and 1 more now reach the live websites again.")
        #expect(Phrases.liveAgain(["a.com", "b.com", "c.com", "d.com"]) == "a.com and b.com and 2 more now reach the live websites again.")
    }

    @Test func portsInUse() {
        #expect(Phrases.portsInUse(holders: []) == "Another app is already using the ports this server needs (80 and 443). Quit it, then start the server again.")
        #expect(Phrases.portsInUse(holders: ["nginx"]) == "nginx is already using the ports this server needs (80 and 443). Quit it, then start the server again.")
        #expect(Phrases.portsInUse(holders: ["nginx", "httpd"]) == "nginx, httpd are already using the ports this server needs (80 and 443). Quit them, then start the server again.")
    }

    @Test func certificateList() {
        #expect(Phrases.certificateList(["a.test", "b.test"]) == "a.test, b.test")
        #expect(Phrases.certificateList(["a", "b", "c", "d"]) == "a, b, c, d")
        #expect(Phrases.certificateList(["a", "b", "c", "d", "e", "f"]) == "a, b, c, d and 2 more")
    }

    @Test func relatedSites() {
        #expect(Phrases.relatedSites(["acme.test", "shop.acme.test"]) == "2 sites look related: acme.test, shop.acme.test")
    }

    @Test func statusSummary() {
        #expect(Phrases.statusSummary("Folder missing", more: 0) == "Folder missing")
        #expect(Phrases.statusSummary("Folder missing", more: 2) == "Folder missing · 2 more")
    }
}
