import Foundation
import PatchyKit
import Testing
@testable import Patchy_UI

/// Pins how the Add Site form treats a Total CMS install: what blocks it, which folder Patchy gets,
/// and that a retry after the install never runs Composer again.
@MainActor
@Suite struct TotalCMSAddTests {
    func folder(empty: Bool) -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "TotalCMSAddTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        if !empty { try! "x".write(to: url.appending(path: "a.txt"), atomically: true, encoding: .utf8) }
        return url
    }

    func draft(_ folder: URL, ticked: Bool = true) -> AddDraft {
        var draft = AddDraft()
        draft.name = "example"
        draft.folder = folder
        draft.installTotalCMS = ticked
        return draft
    }

    @Test func untickedIgnoresTotalCMS() {
        let url = folder(empty: false); defer { try? FileManager.default.removeItem(at: url) }
        let draft = draft(url, ticked: false)
        #expect(draft.totalCMSProblem(activePHP: "7.4") == nil)
        #expect(draft.siteFolder == url)
        #expect(draft.canSubmit(existing: [], activePHP: "7.4"))
    }

    @Test func needsEmptyFolder() {
        let url = folder(empty: false); defer { try? FileManager.default.removeItem(at: url) }
        let draft = draft(url)
        #expect(draft.totalCMSProblem(activePHP: "8.4") == "Choose an empty folder. Total CMS installs into a new, empty folder.")
        #expect(!draft.canSubmit(existing: [], activePHP: "8.4"))
    }

    @Test func needsKnownPHP() {
        let url = folder(empty: true); defer { try? FileManager.default.removeItem(at: url) }
        #expect(draft(url).totalCMSProblem(activePHP: nil)
                == "Patchy UI can’t tell which PHP your server runs, so it can’t install Total CMS. Start the server and try again.")
    }

    @Test func needsPHP82() {
        let url = folder(empty: true); defer { try? FileManager.default.removeItem(at: url) }
        #expect(draft(url).totalCMSProblem(activePHP: "8.1")
                == "Total CMS needs PHP 8.2 or newer. Your server runs PHP 8.1. Switch PHP from the toolbar, then try again.")
    }

    @Test func readyWhenEmptyAndPHPIsNewEnough() {
        let url = folder(empty: true); defer { try? FileManager.default.removeItem(at: url) }
        #expect(draft(url).totalCMSProblem(activePHP: "8.4") == nil)
        #expect(draft(url).canSubmit(existing: [], activePHP: "8.4"))
    }

    @Test func siteFolderIsPublic() {
        let url = folder(empty: true); defer { try? FileManager.default.removeItem(at: url) }
        #expect(draft(url).siteFolder == url.appending(path: "public"))
    }

    @Test func installedProjectNeedsNoEmptyFolder() {
        // After Total CMS installed, the folder is full; a retry must still be allowed.
        let url = folder(empty: false); defer { try? FileManager.default.removeItem(at: url) }
        var draft = draft(url)
        draft.totalCMSInstalled = true
        #expect(draft.totalCMSProblem(activePHP: "8.4") == nil)
    }

    @Test func folderWithTotalCMSSkipsInstall() {
        // After Close, a reopened sheet pointed at the installed project must only add the site.
        let url = folder(empty: true); defer { try? FileManager.default.removeItem(at: url) }
        try! #"{"require":{"totalcms/cms":"^3"}}"#.write(to: url.appending(path: "composer.json"), atomically: true, encoding: .utf8)
        try! FileManager.default.createDirectory(at: url.appending(path: "public"), withIntermediateDirectories: true)
        try! "<?php".write(to: url.appending(path: "public/index.php"), atomically: true, encoding: .utf8)
        let draft = draft(url)
        #expect(draft.skipsInstall)
        #expect(draft.totalCMSProblem(activePHP: "8.4") == nil)
        #expect(draft.steps(composerMissing: true) == ["Setting up the site"])
        #expect(draft.siteFolder == url.appending(path: "public"))
    }

    @Test func untickingAfterInstallStillServesPublic() {
        let url = folder(empty: false); defer { try? FileManager.default.removeItem(at: url) }
        var draft = draft(url)
        draft.totalCMSInstalled = true
        draft.installTotalCMS = false
        #expect(draft.siteFolder == url.appending(path: "public"))
    }

    @Test func changingFolderForgetsInstall() {
        let url = folder(empty: true); defer { try? FileManager.default.removeItem(at: url) }
        var draft = draft(url)
        draft.totalCMSInstalled = true
        draft.folder = url
        #expect(draft.totalCMSInstalled)
        draft.folder = url.appending(path: "other")
        #expect(!draft.totalCMSInstalled)
    }

    @Test func steps() {
        let url = folder(empty: true); defer { try? FileManager.default.removeItem(at: url) }
        var draft = draft(url)
        #expect(draft.steps(composerMissing: true) == ["Installing Composer", "Installing Total CMS 3 (this can take a minute)", "Setting up the site"])
        #expect(draft.steps(composerMissing: false) == ["Installing Total CMS 3 (this can take a minute)", "Setting up the site"])
        draft.totalCMSInstalled = true
        #expect(draft.steps(composerMissing: true) == ["Setting up the site"])
        draft.installTotalCMS = false
        draft.totalCMSInstalled = false
        #expect(draft.steps(composerMissing: true) == ["Setting up the site"])
    }

    @Test func newSiteStartsFromSavedDefaults() {
        let suite = "TotalCMSAddTests-\(UUID().uuidString)"
        let settings = UserDefaults(suiteName: suite)!
        defer { settings.removePersistentDomain(forName: suite) }
        var saved = TotalCMSOptions()
        saved.starter = .blog
        saved.gitTemplates = true
        saved.save(to: settings)

        let model = AppModel()
        model.settings = settings
        model.phase = .ready
        model.openAdd(name: "example")
        #expect(model.add.tcms == saved)
        #expect(!model.add.installTotalCMS)
    }

    @Test func updateButtonTitles() {
        let folder = URL(fileURLWithPath: "/tmp/p")
        #expect(AppModel.updateButtonTitle(ComposerProject(folder: folder, usesTotalCMS: true)) == "Update Total CMS")
        #expect(AppModel.updateButtonTitle(ComposerProject(folder: folder, usesTotalCMS: false)) == "Update Packages")
    }
}
