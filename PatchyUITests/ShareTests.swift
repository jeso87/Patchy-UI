import Foundation
import PatchyKit
import Testing
@testable import Patchy_UI

@MainActor
@Suite struct ShareTests {
    let quick = ShareAccess(url: URL(string: "https://quiet-river-banana.trycloudflare.com")!)
    let stable = ShareAccess(url: URL(string: "https://harbor.example.com")!, username: "preview", password: "k7Rm-4vQx-92Ld")
    let open = ShareAccess(url: URL(string: "https://harbor.example.com")!)

    @Test func notices() {
        #expect(ShareCopy.notice(for: quick) == "Anyone with this link can see this site until you stop sharing.")
        #expect(ShareCopy.notice(for: stable) == "Anyone with this address and password can see this site until you stop sharing.")
        #expect(ShareCopy.notice(for: open) == "Anyone with this address can see this site until you stop sharing.")
        #expect(ShareCopy.isTemporary(quick))
        #expect(!ShareCopy.isTemporary(stable))
    }

    /// With a domain connected, Share asks which link to make; without one, it makes a temporary link.
    @Test func shareChoices() {
        #expect(ShareCopy.choices(sharingDomain: nil).isEmpty)
        let choices = ShareCopy.choices(sharingDomain: "87dash.com")
        #expect(choices.map(\.title) == ["Share at 87dash.com", "Share at 87dash.com, No Password", "Share with a Temporary Link"])
        #expect(choices.map(\.mode) == [.domainWithPassword, .domainWithoutPassword, .temporary])
    }

    @Test func problems() {
        #expect(ShareCopy.problem(output: "Apache isn't running. Start it with: patchy start", wasSharing: false)
                == "The server isn’t running. Start it, then share again.")
        #expect(ShareCopy.problem(output: "The link stopped working because cloudflared quit:", wasSharing: true)
                == "Sharing stopped on its own, so the link no longer works.")
        #expect(ShareCopy.problem(output: "cloudflared stopped before the link was ready:", wasSharing: false)
                == "Couldn’t get a public link. Check your internet connection and try again.")
    }

    /// Patchy says what's wrong for problems that aren't the network; the app passes that on.
    @Test func problemsThatAreNotTheNetwork() {
        #expect(ShareCopy.problem(output: "Your Cloudflare login has expired. Run 'patchy share setup example.com' again.", wasSharing: false)
                == "Your Cloudflare login has expired. To connect your domain again, run patchy share setup in Terminal.")
        #expect(ShareCopy.problem(output: "harbor.test has no certificate yet. Run 'patchy refresh-certs' first.", wasSharing: false)
                == "This site has no secure certificate yet. Refresh certificates, then share again.")
        #expect(ShareCopy.problem(output: "harbor.example.com still points at the deleted tunnel. Delete its DNS record in the Cloudflare dashboard (DNS), then share again.", wasSharing: false)
                == "This site’s address still points at a tunnel that was deleted in Cloudflare. Delete its DNS record in the Cloudflare dashboard, then share again.")
        #expect(ShareCopy.problem(output: "Apache's configuration check failed, so nothing was set up for harbor.test:", wasSharing: false)
                == "Couldn’t share this site. Show Details has the exact message from Patchy.")
        #expect(ShareCopy.problem(output: "harbor.example.com is already used on example.com. Choose another name with --name.", wasSharing: false)
                == "Couldn’t share this site. Show Details has the exact message from Patchy.")
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

    @Test func sharingPhrasesAreMatchedNotLocalized() {
        for phrase in [ShareOutput.sharing, ShareOutput.username, ShareOutput.password, ShareOutput.ready,
                       PatchyOutput.apacheNotRunning, PatchyOutput.cloudflaredRequired,
                       PatchyOutput.shareLoginExpired, PatchyOutput.shareNoCertificate,
                       PatchyOutput.shareDeletedTunnel, PatchyOutput.shareTunnelFailed] {
            #expect(PatchyOutput.all.contains(phrase))
        }
    }
}
