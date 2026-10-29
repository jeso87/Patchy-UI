import Foundation
import PatchyKit
import Testing
@testable import Patchy_UI

@MainActor
@Suite struct ShareTests {
    let quick = ShareAccess(url: URL(string: "https://quiet-river-banana.trycloudflare.com")!, isTemporary: true)
    let stable = ShareAccess(url: URL(string: "https://harbor.example.com")!, username: "preview", password: "k7Rm-4vQx-92Ld")
    let open = ShareAccess(url: URL(string: "https://harbor.example.com")!)

    @Test func notices() {
        #expect(ShareCopy.notice(for: quick) == "Anyone with this link can see this site until you stop sharing.")
        #expect(ShareCopy.notice(for: stable) == "Anyone with this address and password can see this site until you stop sharing.")
        #expect(ShareCopy.notice(for: open) == "Anyone with this address can see this site until you stop sharing.")
    }

    /// With a domain connected, Share asks which link to make; without one, it makes a temporary link.
    @Test func shareChoices() {
        #expect(ShareCopy.choices(sharingDomain: nil).isEmpty)
        let choices = ShareCopy.choices(sharingDomain: "87dash.com")
        #expect(choices.map(\.title) == ["Share at 87dash.com", "Share at 87dash.com, No Password", "Share with a Temporary Link"])
        #expect(choices.map(\.mode) == [.domainWithPassword, .domainWithoutPassword, .temporary])
    }

    func failure(_ code: String?, wasSharing: Bool = false) -> ShareFailure {
        ShareFailure(code: code, details: "", wasSharing: wasSharing)
    }

    @Test func problems() {
        #expect(ShareCopy.problem(failure("apache_not_running")) == "The server isn’t running. Start it, then share again.")
        #expect(ShareCopy.problem(failure("tunnel_stopped", wasSharing: true)) == "Sharing stopped on its own, so the link no longer works.")
        #expect(ShareCopy.problem(failure("tunnel_failed")) == "Couldn’t get a public link. Check your internet connection and try again.")
        #expect(ShareCopy.problem(failure("cloudflare_error")) == "Couldn’t get a public link. Check your internet connection and try again.")
    }

    /// Patchy's code says what's wrong for problems that aren't the network; the app passes that on.
    @Test func problemsThatAreNotTheNetwork() {
        #expect(ShareCopy.problem(failure("cloudflare_login_expired"))
                == "Your Cloudflare login has expired. To connect your domain again, run patchy share setup in Terminal.")
        #expect(ShareCopy.problem(failure("certificate_missing")) == "This site has no secure certificate yet. Refresh certificates, then share again.")
        #expect(ShareCopy.problem(failure("tunnel_deleted")) == "This site’s tunnel was deleted in Cloudflare. Share again to set up a new one.")
        #expect(ShareCopy.problem(failure("config_invalid")) == "Couldn’t share this site. Show Details has the exact message from Patchy.")
        #expect(ShareCopy.problem(failure("name_taken")) == "Couldn’t share this site. Show Details has the exact message from Patchy.")
        #expect(ShareCopy.problem(failure(nil)) == "Couldn’t share this site. Show Details has the exact message from Patchy.")
    }

    @Test func clientMessage() {
        #expect(ShareCopy.clientMessage(for: stable) == "https://harbor.example.com\nUsername: preview\nPassword: k7Rm-4vQx-92Ld")
        #expect(ShareCopy.clientMessage(for: quick) == "https://quiet-river-banana.trycloudflare.com")
    }

    @Test func shareDecisionStartsInstallsOrIgnores() {
        #expect(AppModel.shareDecision(canShare: true, serverRunning: true, alreadySharing: false, cloudflaredInstalled: true) == .start)
        #expect(AppModel.shareDecision(canShare: true, serverRunning: true, alreadySharing: false, cloudflaredInstalled: false) == .install)
        #expect(AppModel.shareDecision(canShare: false, serverRunning: true, alreadySharing: false, cloudflaredInstalled: true) == .ignore)
        #expect(AppModel.shareDecision(canShare: true, serverRunning: false, alreadySharing: false, cloudflaredInstalled: true) == .ignore)
    }

    @Test func shareDecisionIgnoresASiteAlreadySharing() {
        #expect(AppModel.shareDecision(canShare: true, serverRunning: true, alreadySharing: true, cloudflaredInstalled: true) == .ignore)
    }

    func snapshot(running: Bool, sites: [String]) -> PatchySnapshot {
        var snapshot = PatchySnapshot()
        snapshot.serverRunning = running
        snapshot.sites = sites.map { Site(address: $0, folder: "/tmp/\($0)") }
        return snapshot
    }

    @Test func sharesStopWhenTheServerStops() {
        #expect(AppModel.sharesToStop(["b.test", "a.test"], snapshot: snapshot(running: false, sites: ["a.test", "b.test"]),
                                      serverWasDown: true) == ["a.test", "b.test"])
    }

    /// A restart takes the server down for a moment; one read in that moment must not end shares.
    @Test func oneDownReadDuringARestartStopsNothing() {
        #expect(AppModel.sharesToStop(["a.test"], snapshot: snapshot(running: false, sites: ["a.test"]), serverWasDown: false) == [])
    }

    @Test func sharesStopWhenTheirSiteIsGone() {
        #expect(AppModel.sharesToStop(["a.test", "gone.test"], snapshot: snapshot(running: true, sites: ["a.test"]), serverWasDown: false) == ["gone.test"])
        #expect(AppModel.sharesToStop(["a.test"], snapshot: snapshot(running: true, sites: ["a.test"]), serverWasDown: true) == [])
    }
}
