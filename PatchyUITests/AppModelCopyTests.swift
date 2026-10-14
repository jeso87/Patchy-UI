import Foundation
import PatchyKit
import Testing
@testable import Patchy_UI

/// Pins the copy AppModel builds: the server pill, the footer, tab titles, the add form's
/// problems and every error message derived from Patchy's output.
@MainActor
@Suite struct AppModelCopyTests {
    func model(running: Bool, sites: [Site] = [], php: String? = "8.4") -> AppModel {
        let model = AppModel()
        var snapshot = PatchySnapshot()
        snapshot.serverRunning = running
        snapshot.sites = sites
        snapshot.activePHP = php
        model.snapshot = snapshot
        return model
    }

    func healthySite(_ address: String, routed: Bool = true) -> Site {
        Site(address: address, folder: "/tmp/\(address)",
             certificate: .valid(expires: Date().addingTimeInterval(400 * 86_400)), isRouted: routed)
    }

    @Test func serverPillAndTitle() {
        #expect(model(running: false).serverPillText == "Stopped")
        #expect(model(running: false).serverTitle == "Stopped")
        #expect(model(running: true, sites: [healthySite("a.test")]).serverPillText == "Running · PHP 8.4")
        #expect(model(running: true, sites: [healthySite("a.test")]).serverTitle == "Running")
        #expect(model(running: true, sites: [healthySite("a.test", routed: false)]).serverPillText == "Running · needs repair")
        #expect(model(running: true, sites: [healthySite("a.test", routed: false)]).serverTitle == "Needs repair")
        #expect(model(running: true, php: nil).phpLabel == "PHP")
    }

    @Test func footer() {
        #expect(model(running: true).footerText == "")
        #expect(model(running: true, sites: [healthySite("a.test"), healthySite("b.test")]).footerText == "2 sites")
        #expect(model(running: true, sites: [healthySite("a.test", routed: false)]).footerText == "1 site · 1 needs attention")
    }

    @Test func tabTitles() {
        #expect(DetailTab.allCases.map(\.title) == ["Overview", "Errors", "Visits"])
    }

    @Test func addressProblems() {
        #expect(AddDraft(name: "my site").problemText(existing: []) == "Use only letters, numbers, hyphens (-), and dots (.).")
        #expect(AddDraft(name: "mysite.").problemText(existing: []) == "That address looks unfinished. It can’t start or end with a dot or hyphen.")
        #expect(AddDraft(name: "mysite").problemText(existing: ["mysite.test"]) == "mysite.test already exists. Pick a different address.")
        #expect(AddDraft(name: "mysite").problemText(existing: []) == nil)
    }

    @Test func startFailures() {
        let stuck = AppModel.startFailure(output: "Error: launchd service is stuck")
        #expect(stuck.title == "The server is stuck")
        #expect(stuck.message == "The background service that runs the server didn’t respond. Stopping and starting it again resets it.")
        #expect(stuck.recovery == .stopThenStart)

        let stuckNoReset = AppModel.startFailure(output: "Error: launchd service is stuck", offerReset: false)
        #expect(stuckNoReset.title == "The server didn’t start")

        let ports = AppModel.startFailure(output: "Apache's startup error:\n  (48)Address already in use: AH00072\nSomething else is listening on port 80/443:\n  COMMAND PID USER\n  nginx 412 joe")
        #expect(ports.title == "Another app is using the web ports")
        #expect(ports.message == "nginx is already using the ports this server needs (80 and 443). Quit it, then start the server again.")

        let generic = AppModel.startFailure(output: "something else")
        #expect(generic.title == "The server didn’t start")
        #expect(generic.message == "Your sites won’t open until it’s running. Show Details has the exact message from Patchy.")
        #expect(generic.details == "something else")
    }

    @Test func addFailures() {
        #expect(AppModel.addFailureMessage(output: "Rolling back site creation") == "The setup check found a problem, so Patchy undid every step. Nothing was added and your other sites are fine.")
        #expect(AppModel.addFailureMessage(output: "Site already exists") == "A site with this address already exists, so nothing was changed.")
        #expect(AppModel.addFailureMessage(output: "sudo: no password") == "Patchy couldn’t point the address at this Mac, so nothing was created. Your other sites are fine.")
        #expect(AppModel.addFailureMessage(output: "Creating SSL certificates\nboom") == "Something stopped the setup partway. Your other sites are fine; Show Details has the exact message from Patchy.")
    }
}
