import Testing
@testable import Patchy_UI

/// The sidebar scrolls a site into view only when the app picks it (the menu bar, a new site),
/// never when the person clicked the row, which is already in view.
@MainActor
@Suite struct SidebarRevealTests {
    @Test func clickingARowDoesNotAskToReveal() {
        let model = AppModel()
        let before = model.revealSelection
        model.selection = "blog.test"
        #expect(model.revealSelection == before)
    }

    @Test func showingASiteFromElsewhereAsksToReveal() {
        let model = AppModel()
        let before = model.revealSelection
        model.showSite("blog.test")
        #expect(model.selection == "blog.test")
        #expect(model.revealSelection != before)
    }
}
