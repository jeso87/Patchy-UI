import Foundation
import Testing
@testable import PatchyKit

@Suite struct ComposerTests {
    /// A fresh temporary folder, removed by the caller with `cleanUp`.
    func scratch() -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "ComposerTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func write(_ text: String, to url: URL) {
        try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! text.write(to: url, atomically: true, encoding: .utf8)
    }

    func cleanUp(_ url: URL) { try? FileManager.default.removeItem(at: url) }

    // MARK: Options

    @Test func defaultEnvironment() {
        #expect(TotalCMSOptions().environment == [
            "TCMS_LAYOUT": "root", "TCMS_STARTER": "none", "TCMS_FRONTEND": "0", "TCMS_GIT_TEMPLATES": "1",
        ])
    }

    @Test func subpathForcesNoStarterOrFrontend() {
        var options = TotalCMSOptions()
        options.layout = .subpath
        options.starter = .blog
        options.frontend = true
        let env = options.environment
        #expect(env["TCMS_LAYOUT"] == "subpath")
        #expect(env["TCMS_STARTER"] == "none")
        #expect(env["TCMS_FRONTEND"] == "0")
    }

    @Test func phpFloor() {
        #expect(TotalCMS.supports(php: "8.2"))
        #expect(TotalCMS.supports(php: "8.5"))
        #expect(TotalCMS.supports(php: "10.0"))
        #expect(!TotalCMS.supports(php: "8.1"))
        #expect(!TotalCMS.supports(php: "7.4"))
        #expect(!TotalCMS.supports(php: nil))
    }

    // MARK: Folders

    @Test func emptyFolder() {
        let root = scratch(); defer { cleanUp(root) }
        let empty = root.appending(path: "empty")
        try! FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        #expect(ProjectFolder.isEmpty(empty))

        let finder = root.appending(path: "finder")
        write("", to: finder.appending(path: ".DS_Store"))
        #expect(ProjectFolder.isEmpty(finder))

        let full = root.appending(path: "full")
        write("<?php", to: full.appending(path: "index.php"))
        #expect(!ProjectFolder.isEmpty(full))

        #expect(!ProjectFolder.isEmpty(root.appending(path: "missing")))
    }

    @Test func removeFinderLeftovers() {
        let root = scratch(); defer { cleanUp(root) }
        write("", to: root.appending(path: ".DS_Store"))
        ProjectFolder.removeFinderLeftovers(root)
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: ".DS_Store").path))
        #expect(FileManager.default.fileExists(atPath: root.path))
    }

    @Test func installedCheck() {
        let root = scratch(); defer { cleanUp(root) }
        var options = TotalCMSOptions()
        #expect(!options.isInstalled(in: root))
        write("<?php", to: root.appending(path: "public/index.php"))
        #expect(options.isInstalled(in: root))

        options.layout = .subpath
        #expect(!options.isInstalled(in: root))
        write("<?php", to: root.appending(path: "public/tcms/index.php"))
        #expect(options.isInstalled(in: root))
    }

    @Test func docrootIsPublic() {
        #expect(TotalCMS.docroot(for: URL(fileURLWithPath: "/tmp/site")).path == "/tmp/site/public")
    }

    // MARK: Finding Composer projects

    @Test func findInSiteFolder() {
        let site = scratch(); defer { cleanUp(site) }
        write(#"{"require":{"totalcms/cms":"^3"}}"#, to: site.appending(path: "composer.json"))
        let project = ComposerProject.find(siteFolder: site)
        #expect(project?.folder.standardizedFileURL == site.standardizedFileURL)
        #expect(project?.usesTotalCMS == true)
    }

    @Test func findInParentOfPublic() {
        let project = scratch(); defer { cleanUp(project) }
        write(#"{"require":{"totalcms/cms":"^3"}}"#, to: project.appending(path: "composer.json"))
        let site = project.appending(path: "public")
        try! FileManager.default.createDirectory(at: site, withIntermediateDirectories: true)
        let found = ComposerProject.find(siteFolder: site)
        #expect(found?.folder.standardizedFileURL == project.standardizedFileURL)
        #expect(found?.usesTotalCMS == true)
    }

    @Test func parentIgnoredUnlessPublic() {
        let parent = scratch(); defer { cleanUp(parent) }
        write(#"{"require":{"totalcms/cms":"^3"}}"#, to: parent.appending(path: "composer.json"))
        let site = parent.appending(path: "web")
        try! FileManager.default.createDirectory(at: site, withIntermediateDirectories: true)
        #expect(ComposerProject.find(siteFolder: site) == nil)
    }

    @Test func plainComposer() {
        let site = scratch(); defer { cleanUp(site) }
        write(#"{"require":{"slim/slim":"^4"}}"#, to: site.appending(path: "composer.json"))
        #expect(ComposerProject.find(siteFolder: site)?.usesTotalCMS == false)
    }

    @Test func brokenJSON() {
        let site = scratch(); defer { cleanUp(site) }
        write("{not json", to: site.appending(path: "composer.json"))
        let project = ComposerProject.find(siteFolder: site)
        #expect(project != nil)
        #expect(project?.usesTotalCMS == false)
    }

    @Test func noComposer() {
        let site = scratch(); defer { cleanUp(site) }
        #expect(ComposerProject.find(siteFolder: site) == nil)
    }
}
