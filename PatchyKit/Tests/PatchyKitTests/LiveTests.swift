import Foundation
import Testing
@testable import PatchyKit

/// Runs against the real Patchy install on this Mac. Adds one throwaway site, changes its folder and
/// removes it; each step restarts Apache. Off unless asked for: `PATCHY_LIVE_TEST=1 swift test --filter LiveTests`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["PATCHY_LIVE_TEST"] == "1"))
struct LiveTests {
    static let address = "patchyui-test.test"

    @Test func addChangeFolderAndRemove() async throws {
        guard case .ready(let environment) = PatchyEnvironment.detect() else {
            Issue.record("Patchy is not installed")
            return
        }
        let client = PatchyClient(environment: environment)
        let before = client.snapshot()
        try #require(before.trust == .enabled, "Password-free mode must be on for the live test")
        try #require(!before.sites.contains { $0.address == Self.address }, "\(Self.address) already exists")

        let root = URL(fileURLWithPath: NSHomeDirectory()).appending(path: "PatchyUI Live Test \(UUID().uuidString.prefix(6))")
        let first = root.appending(path: "first folder"), second = root.appending(path: "second folder")
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        try "first".write(to: first.appending(path: "index.html"), atomically: true, encoding: .utf8)
        try "second".write(to: second.appending(path: "index.html"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        // Add, declining the www alias — only possible because the command runs on a terminal.
        let added = await client.addSite(address: Self.address, folder: first.path, includeWWW: false)
        print("--- add ---\n\(added.output)")
        var site = try #require(client.snapshot().sites.first { $0.address == Self.address })
        #expect(site.folder == first.path)
        #expect(site.aliases.isEmpty)
        #expect(site.isRouted)
        #expect((site.certificate.daysLeft() ?? 0) > 30)
        #expect(client.snapshot().serverRunning)
        #expect(await fetch() == "first")

        let changed = await client.changeFolder(of: Self.address, to: second.path, restart: true)
        print("--- change folder ---\n\(changed.output)")
        #expect(changed.succeeded)
        site = try #require(client.snapshot().sites.first { $0.address == Self.address })
        #expect(site.folder == second.path)
        #expect(await fetch() == "second")

        let removed = await client.removeSites([Self.address])
        print("--- remove ---\n\(removed.output)")
        let after = client.snapshot()
        #expect(!after.sites.contains { $0.address == Self.address })
        #expect(after.serverRunning)
        #expect(after.sites.map(\.address) == before.sites.map(\.address))
        let allRouted = after.sites.allSatisfy { $0.isRouted }
        #expect(allRouted)
        #expect(!FileManager.default.fileExists(atPath: environment.certificateFile(for: Self.address).path))
    }

    /// What the site serves over https, straight from this Mac.
    private func fetch() async -> String {
        try? await Task.sleep(for: .seconds(1))
        let result = await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/curl"),
                                             ["-s", "--max-time", "10", "https://\(Self.address)/"], environment: [:])
        return result.output
    }
}
