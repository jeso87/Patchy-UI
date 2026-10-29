import AppKit
import Foundation
import Testing
@testable import Patchy_UI

/// Which key combinations can open the menu bar panel, and how they read in Settings.
@Suite struct KeyShortcutTests {
    @Test func needsCommandOptionOrControl() {
        #expect(KeyShortcut(keyCode: 35, modifiers: [], key: "p") == nil)
        #expect(KeyShortcut(keyCode: 35, modifiers: [.shift], key: "p") == nil)
        #expect(KeyShortcut(keyCode: 35, modifiers: [.option], key: "p") != nil)
        #expect(KeyShortcut(keyCode: 35, modifiers: [.control], key: "p") != nil)
        #expect(KeyShortcut(keyCode: 35, modifiers: [.command], key: "p") != nil)
    }

    @Test func readsInTheMacsOrder() {
        let shortcut = KeyShortcut(keyCode: 35, modifiers: [.command, .shift, .option, .control], key: "p")
        #expect(shortcut?.display == "⌃⌥⇧⌘P")
        #expect(KeyShortcut(keyCode: 49, modifiers: [.option], key: " ")?.display == "⌥Space")
        #expect(KeyShortcut(keyCode: 122, modifiers: [.command], key: "\u{F704}")?.display == "⌘F1")
    }

    @Test func ignoresCapsLockAndOtherFlags() {
        let shortcut = KeyShortcut(keyCode: 35, modifiers: [.command, .capsLock, .numericPad], key: "p")
        #expect(shortcut?.modifiers == NSEvent.ModifierFlags.command.rawValue)
    }

    @Test func survivesSaving() throws {
        let shortcut = try #require(KeyShortcut(keyCode: 35, modifiers: [.option, .command], key: "p"))
        let data = try JSONEncoder().encode(shortcut)
        #expect(try JSONDecoder().decode(KeyShortcut.self, from: data) == shortcut)
    }
}
