import PatchyKit
import Testing
@testable import Patchy_UI

/// What the menu bar panel lists, in what order, and what a search finds.
@Suite struct MenuPanelTests {
    func row(_ address: String, _ severity: Severity = .ok, _ note: String = "") -> MenuPanelList.Row {
        MenuPanelList.Row(address: address, severity: severity, note: note)
    }

    func addresses(_ list: MenuPanelList) -> [[String]] {
        list.sections.map { $0.rows.map(\.address) }
    }

    @Test func noGroupsAndNoProblemsIsOneUntitledList() {
        let list = MenuPanelList(rows: [row("acme.test"), row("blog.test")], groups: SiteGroups(), query: "")
        #expect(addresses(list) == [["acme.test", "blog.test"]])
        #expect(list.sections.map(\.title) == [nil])
    }

    @Test func problemsComeFirstErrorsBeforeWarnings() {
        let rows = [row("acme.test"), row("blog.test", .warning, "12 days"), row("cafe.test", .error, "Expired"), row("dog.test")]
        let list = MenuPanelList(rows: rows, groups: SiteGroups(), query: "")
        #expect(addresses(list) == [["cafe.test", "blog.test"], ["acme.test", "dog.test"]])
        #expect(list.sections.map(\.title) == ["Needs Attention", "Other Sites"])
    }

    @Test func groupsAreTitledAndProblemSitesAreNotListedTwice() {
        var groups = SiteGroups()
        _ = groups.createGroup(named: "Acme", sites: ["acme.test", "shop.acme.test"])
        let rows = [row("acme.test"), row("blog.test"), row("shop.acme.test", .error, "Folder missing")]
        let list = MenuPanelList(rows: rows, groups: groups, query: "")
        #expect(addresses(list) == [["shop.acme.test"], ["acme.test"], ["blog.test"]])
        #expect(list.sections.map(\.title) == ["Needs Attention", "Acme", "Other Sites"])
    }

    @Test func searchIsOneListWithNameStartsFirst() {
        let rows = [row("myshop.test"), row("blog.test"), row("shop.acme.test"), row("Shopfront.test", .error, "Expired")]
        let list = MenuPanelList(rows: rows, groups: SiteGroups(), query: " SHOP ")
        #expect(addresses(list) == [["shop.acme.test", "Shopfront.test", "myshop.test"]])
        #expect(list.sections.map(\.title) == [nil])
    }

    @Test func searchPutsTheAddressThatStartsWithItFirst() {
        let rows = [row("members.northwind.test"), row("northwind.test"), row("shop.northwind.test")]
        let list = MenuPanelList(rows: rows, groups: SiteGroups(), query: "north")
        #expect(list.rows.map(\.address) == ["northwind.test", "members.northwind.test", "shop.northwind.test"])
    }

    @Test func searchMatchesAnyPartOfTheAddress() {
        let list = MenuPanelList(rows: [row("blog.acme.test"), row("blog.test")], groups: SiteGroups(), query: "acme")
        #expect(list.rows.map(\.address) == ["blog.acme.test"])
    }

    @Test func noMatchesLeavesNoSections() {
        let list = MenuPanelList(rows: [row("blog.test")], groups: SiteGroups(), query: "zzz")
        #expect(list.sections.isEmpty)
        #expect(list.rows.isEmpty)
    }

    @Test func rowsFollowTheOrderShown() {
        let rows = [row("acme.test"), row("cafe.test", .error, "Expired")]
        let list = MenuPanelList(rows: rows, groups: SiteGroups(), query: "")
        #expect(list.rows.map(\.address) == ["cafe.test", "acme.test"])
    }

    @Test func movingTheHighlightStopsAtTheEnds() {
        let list = MenuPanelList(rows: [row("a.test"), row("b.test"), row("c.test")], groups: SiteGroups(), query: "")
        #expect(list.highlight(after: nil, by: 1) == "b.test")
        #expect(list.highlight(after: "c.test", by: 1) == "c.test")
        #expect(list.highlight(after: "a.test", by: -1) == "a.test")
        #expect(list.highlight(after: "gone.test", by: 1) == "b.test")
        #expect(list.target(highlighted: nil) == "a.test")
        #expect(list.target(highlighted: "b.test") == "b.test")
        #expect(list.target(highlighted: "gone.test") == "a.test")
    }
}
