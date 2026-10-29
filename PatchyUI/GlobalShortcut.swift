import AppKit
import Carbon.HIToolbox

/// A key combination that opens the menu bar panel from any app. It must use Command, Option
/// or Control, so it never takes over ordinary typing.
struct KeyShortcut: Codable, Equatable {
    var keyCode: UInt32
    /// Device-independent `NSEvent.ModifierFlags`, limited to the four that matter.
    var modifiers: UInt
    /// What the key types, for showing the shortcut.
    var key: String

    private static let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    init?(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, key: String) {
        let flags = modifiers.intersection(Self.relevant)
        guard !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        self.keyCode = UInt32(keyCode)
        self.modifiers = flags.rawValue
        self.key = key
    }

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    /// As the Mac writes shortcuts in menus: ⌃⌥⇧⌘ then the key.
    var display: String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + keyName
    }

    private var keyName: String {
        let named: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        return named[Int(keyCode)] ?? key.uppercased()
    }

    var carbonModifiers: UInt32 {
        var carbon = 0
        if flags.contains(.command) { carbon |= cmdKey }
        if flags.contains(.option) { carbon |= optionKey }
        if flags.contains(.control) { carbon |= controlKey }
        if flags.contains(.shift) { carbon |= shiftKey }
        return UInt32(carbon)
    }
}

/// The one global shortcut the app has: it opens the menu bar panel. Uses the system's hot key
/// registration, which needs no Accessibility permission.
@MainActor
final class PanelShortcut {
    static let shared = PanelShortcut()
    static let defaultsKey = "panelShortcut"

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    var current: KeyShortcut? {
        get {
            UserDefaults.standard.data(forKey: Self.defaultsKey).flatMap { try? JSONDecoder().decode(KeyShortcut.self, from: $0) }
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Self.defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
            }
            register()
        }
    }

    /// Registers the saved shortcut, replacing any earlier one. Returns false when macOS
    /// refuses it, usually because another app already uses that combination.
    @discardableResult
    func register() -> Bool {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        guard let shortcut = current else { return true }
        installHandler()
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x5054_4348), id: 1) // "PTCH"
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &ref)
        hotKey = ref
        return status == noErr
    }

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { StatusItemController.shared?.toggle() } }
            return noErr
        }, 1, &spec, nil, &handler)
    }
}
