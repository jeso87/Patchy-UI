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

    @Test func problems() {
        #expect(ShareCopy.problem(output: "Apache isn't running. Start it with: patchy start", wasSharing: false)
                == "The server isn’t running. Start it, then share again.")
        #expect(ShareCopy.problem(output: "The link stopped working because cloudflared quit:", wasSharing: true)
                == "Sharing stopped on its own, so the link no longer works.")
        #expect(ShareCopy.problem(output: "cloudflared stopped before the link was ready:", wasSharing: false)
                == "Couldn’t get a public link. Check your internet connection and try again.")
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
        #expect(AppModel.sharesToStop(["b.test", "a.test"], snapshot: snapshot(running: false, sites: ["a.test", "b.test"])) == ["a.test", "b.test"])
    }

    @Test func sharesStopWhenTheirSiteIsGone() {
        #expect(AppModel.sharesToStop(["a.test", "gone.test"], snapshot: snapshot(running: true, sites: ["a.test"])) == ["gone.test"])
        #expect(AppModel.sharesToStop(["a.test"], snapshot: snapshot(running: true, sites: ["a.test"])) == [])
    }

    @Test func sharingPhrasesAreMatchedNotLocalized() {
        for phrase in [ShareOutput.sharing, ShareOutput.username, ShareOutput.password, ShareOutput.ready,
                       PatchyOutput.apacheNotRunning, PatchyOutput.cloudflaredRequired] {
            #expect(PatchyOutput.all.contains(phrase))
        }
    }
}
