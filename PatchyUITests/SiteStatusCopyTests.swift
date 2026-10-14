import Foundation
import PatchyKit
import Testing
@testable import Patchy_UI

/// Pins every label, detail and summary SiteStatus produces.
@Suite struct SiteStatusCopyTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// A certificate expiring `days` whole days from `now`, as Patchy rounds it.
    func site(days: Int? = 400, folderExists: Bool = true, routed: Bool = true,
              certificate: CertificateStatus? = nil) -> Site {
        let cert = certificate ?? .valid(expires: now.addingTimeInterval(Double(days ?? 0) * 86_400 + 3_600))
        return Site(address: "blog.test", folder: "/tmp/blog", folderExists: folderExists,
                    certificate: cert, isRouted: routed)
    }

    func formatted(daysFromNow days: Int) -> String {
        now.addingTimeInterval(Double(days) * 86_400 + 3_600).formatted(date: .abbreviated, time: .omitted)
    }

    @Test func healthy() {
        let status = SiteStatus(site: site(days: 400), serverRunning: true, now: now)
        #expect(status.summary == "Secure · 400 days")
        #expect(status.certificate.label == "Secure · 400 days left")
        #expect(status.certificate.detail == "Valid until \(formatted(daysFromNow: 400)).")
        #expect(status.reachable.label == "Yes")
        #expect(status.reachable.detail == "Opens in any browser on this Mac.")
        #expect(status.issues.isEmpty)
    }

    @Test func expiringSoon() {
        let one = SiteStatus(site: site(days: 1), serverRunning: true, now: now)
        #expect(one.certificate.label == "Expires in 1 day")
        #expect(one.certificate.detail == "Valid until \(formatted(daysFromNow: 1)). Refresh before then to avoid browser warnings.")
        #expect(one.summary == "Certificate expires in 1 day")
        let thirty = SiteStatus(site: site(days: 30), serverRunning: true, now: now)
        #expect(thirty.certificate.label == "Expires in 30 days")
        let thirtyOne = SiteStatus(site: site(days: 31), serverRunning: true, now: now)
        #expect(thirtyOne.certificate.label == "Secure · 31 days left")
    }

    @Test func expired() {
        let status = SiteStatus(site: site(days: -3), serverRunning: true, now: now)
        #expect(status.certificate.label == "Certificate expired")
        #expect(status.certificate.detail == "Expired on \(formatted(daysFromNow: -3)). Browsers will warn that this site isn’t secure.")
        #expect(status.summary == "Certificate expired")
    }

    @Test func missingAndUnreadableCertificates() {
        let missing = SiteStatus(site: site(certificate: .missing), serverRunning: true, now: now)
        #expect(missing.certificate.label == "No certificate")
        #expect(missing.certificate.detail == "https:// won’t work for this site until certificates are refreshed.")
        #expect(missing.summary == "No certificate")
        let invalid = SiteStatus(site: site(certificate: .invalid), serverRunning: true, now: now)
        #expect(invalid.certificate.label == "Certificate can’t be read")
        #expect(invalid.certificate.detail == "The certificate file is damaged. Refreshing certificates replaces it.")
        #expect(invalid.summary == "Certificate unreadable")
    }

    @Test func folderMissingWithAnotherProblem() {
        let status = SiteStatus(site: site(folderExists: false, certificate: .missing), serverRunning: true, now: now)
        #expect(status.summary == "Folder missing · 1 more")
        #expect(status.issues.map(\.text) == ["Folder missing", "No certificate"])
        #expect(status.reachable.label == "Opens, but shows an error")
        #expect(status.reachable.detail == "There’s no folder to serve files from.")
    }

    @Test func serverStopped() {
        let status = SiteStatus(site: site(days: 400), serverRunning: false, now: now)
        #expect(status.summary == "Offline while the server is stopped")
        #expect(status.reachable.label == "Not right now")
        #expect(status.reachable.detail == "The server is stopped.")
    }

    @Test func notRouted() {
        let status = SiteStatus(site: site(days: 400, routed: false), serverRunning: true, now: now)
        #expect(status.issues.map(\.text) == ["Not pointing at this Mac"])
        #expect(status.summary == "Not pointing at this Mac")
        #expect(status.reachable.label == "Not right now")
        #expect(status.reachable.detail == "This address isn’t pointing at this Mac. Repair fixes it.")
    }
}
