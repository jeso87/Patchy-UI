import AppKit
import PatchyKit
import Testing
@testable import Patchy_UI

/// Pins what the About Patchy UI window says beneath the app's name and version.
@MainActor
@Suite struct AboutPanelTests {
    func credits(patchy: String?) -> NSAttributedString {
        let model = AppModel()
        var snapshot = PatchySnapshot()
        snapshot.patchyVersion = patchy
        snapshot.activePHP = "8.4"
        model.snapshot = snapshot
        return AboutPanel.credits(for: model)
    }

    func links(in text: NSAttributedString) -> [URL] {
        var urls: [URL] = []
        text.enumerateAttribute(.link, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            if let url = value as? URL { urls.append(url) }
        }
        return urls
    }

    @Test func namesTheAuthorAndPatchy() {
        let text = credits(patchy: "1.2.1").string
        #expect(text.contains("Patchy UI is free and open source, made by Joshua Omilian."))
        #expect(text.contains("made by Joe Workman"))
    }

    @Test func showsWhatThisMacRuns() {
        #expect(credits(patchy: "1.2.1").string.contains("Patchy 1.2.1 · Server (Apache) – · PHP 8.4"))
        #expect(credits(patchy: nil).string.contains("Patchy – ·"))
    }

    @Test func explainsTheVersionsOnlyWhenTheyDontMatch() {
        #expect(!credits(patchy: "1.2.1").string.contains("made for Patchy"))
        #expect(credits(patchy: "1.1.0").string.contains("This Patchy UI was made for Patchy 1.2.1. Patchy is older"))
    }

    @Test func linksAreClickable() {
        #expect(links(in: credits(patchy: "1.2.1")) == [
            URL(string: "https://joshuaomilian.ca")!,
            URL(string: "https://github.com/jeso87/Patchy-UI")!,
            URL(string: "https://github.com/joeworkman/patchy")!,
        ])
    }
}
