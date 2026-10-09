import Foundation
import Testing
@testable import PatchyKit

@Suite struct SiteGroupsTests {
    @Test func aSiteBelongsToAtMostOneGroup() {
        var groups = SiteGroups()
        let acme = groups.createGroup(named: "Acme", sites: ["acme.test"])
        let other = groups.createGroup(named: "Other")
        groups.assign("shop.acme.test", to: acme)
        groups.assign("acme.test", to: other)
        #expect(groups.group(of: "acme.test")?.id == other)
        #expect(groups.group(of: "shop.acme.test")?.id == acme)
        groups.assign("acme.test", to: nil)
        #expect(groups.group(of: "acme.test") == nil)
    }

    @Test func deletingAGroupOnlyUngroupsItsSites() {
        var groups = SiteGroups()
        let acme = groups.createGroup(named: "Acme", sites: ["acme.test", "shop.acme.test"])
        groups.delete(acme)
        let sections = groups.sections(for: ["acme.test", "shop.acme.test"])
        #expect(sections.groups.isEmpty)
        #expect(sections.ungrouped == ["acme.test", "shop.acme.test"])
    }

    @Test func sectionsAreSortedByNameAndSkipSitesThatNoLongerExist() {
        var groups = SiteGroups()
        groups.createGroup(named: "zeta", sites: ["z.test", "gone.test"])
        groups.createGroup(named: "Alpha", sites: ["b.test", "a.test"])
        let sections = groups.sections(for: ["a.test", "b.test", "loose.test", "z.test"])
        #expect(sections.groups.map(\.group.name) == ["Alpha", "zeta"])
        #expect(sections.groups.map(\.sites) == [["a.test", "b.test"], ["z.test"]])
        #expect(sections.ungrouped == ["loose.test"])
    }

    @Test func blankNamesGetAPlaceholder() {
        var groups = SiteGroups()
        let id = groups.createGroup(named: "   ")
        #expect(groups.groups.first?.name == "Untitled Group")
        groups.rename(id, to: "  Acme  ")
        #expect(groups.groups.first?.name == "Acme")
    }

    @Test func suggestsSitesThatShareAName() {
        let groups = SiteGroups()
        let found = groups.suggestions(for: [
            "acme.test", "shop.acme.test", "acme.com", "topbonn.test", "topbonnportal.test", "lonely.test", "abc.test", "abcd.test",
        ])
        #expect(found.map(\.key) == ["acme", "topbonn"])
        #expect(found[0].name == "Acme")
        #expect(found[0].sites == ["acme.com", "acme.test", "shop.acme.test"])
        #expect(found[1].sites == ["topbonn.test", "topbonnportal.test"])
    }

    @Test func suggestionsIgnoreGroupedAndDismissedSites() {
        var groups = SiteGroups()
        let all = ["acme.test", "shop.acme.test", "topbonn.test", "topbonnportal.test"]
        groups.createGroup(named: "Acme", sites: ["acme.test"])
        // Only one ungrouped acme site is left, which isn't a group.
        #expect(groups.suggestions(for: all).map(\.key) == ["topbonn"])
        groups.dismiss(groups.suggestions(for: all)[0])
        #expect(groups.suggestions(for: all).isEmpty)
    }

    @Test func storeRoundTrips() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "PatchyKitTests-\(UUID().uuidString)/groups.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = SiteGroupStore(file: file)
        #expect(store.load() == SiteGroups())
        var groups = SiteGroups()
        groups.createGroup(named: "Acme", sites: ["acme.test"])
        groups.setCollapsed(true, for: groups.groups[0].id)
        store.save(groups)
        #expect(store.load() == groups)
    }
}
