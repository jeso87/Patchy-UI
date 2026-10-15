import AppKit
import PatchyKit

/// The About Patchy UI window: the standard panel (icon, name, version) with credits
/// that name the author and Patchy, and say which Patchy, Apache and PHP this Mac runs.
@MainActor
enum AboutPanel {
    static let authorURL = URL(string: "https://joshuaomilian.ca")!
    static let appRepositoryURL = URL(string: "https://github.com/jeso87/Patchy-UI")!
    static let patchyRepositoryURL = URL(string: "https://github.com/joeworkman/patchy")!

    static func show(_ model: AppModel) {
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits(for: model)])
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Paragraph breaks come from `paragraphSpacing`, not blank lines: the panel's credits
    /// area is a fixed-height scroll view, and blank lines push the last paragraph out of sight.
    static func credits(for model: AppModel) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 12
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]
        let credits = NSMutableAttributedString()
        func add(_ string: String) {
            credits.append(NSAttributedString(string: string, attributes: base))
        }
        func link(_ string: String, _ url: URL) {
            var attributes = base
            attributes[.link] = url
            attributes[.foregroundColor] = NSColor.linkColor
            credits.append(NSAttributedString(string: string, attributes: attributes))
        }

        // Three groups, one paragraph each; U+2028 breaks a line without the paragraph gap.
        add(String(localized: "Patchy UI is free and open source, made by Joshua Omilian.") + "\u{2028}")
        link("joshuaomilian.ca", authorURL)
        add(" · ")
        link(String(localized: "Patchy UI on GitHub"), appRepositoryURL)
        add("\n" + versions(model) + "\n")
        if let note = compatibilityNote(model.compatibility) { add(note + "\n") }
        add(String(localized: "Patchy is made by Joe Workman.") + "\u{2028}")
        link(String(localized: "Patchy on GitHub"), patchyRepositoryURL)
        return credits
    }

    private static func versions(_ model: AppModel) -> String {
        let activePHP = model.snapshot.installedPHP.first { $0.version == model.snapshot.activePHP }
        // All Latin letters and numbers, so in a right-to-left language each item needs a
        // right-to-left mark to keep its version beside its name and the items in order.
        let mark = Locale.Language(identifier: Bundle.main.preferredLocalizations.first ?? "en")
            .characterDirection == .rightToLeft ? "\u{200F}" : ""
        return mark + [
            "Patchy \(model.snapshot.patchyVersion ?? "–")",
            String(localized: "Server (Apache)") + " " + (serverVersion(model) ?? "–"),
            "PHP \(activePHP?.fullVersion ?? model.snapshot.activePHP ?? "–")",
        ].joined(separator: mark + " · " + mark)
    }

    /// Only a mismatch is worth the room: the credits area is short, and the Patchy
    /// paragraph below would otherwise scroll out of sight.
    private static func compatibilityNote(_ compatibility: PatchyCompatibility) -> String? {
        switch compatibility {
        case .matched, .unknown:
            nil
        case .patchyNewer(_, let supported):
            String(localized: "This Patchy UI was made for Patchy \(supported). Patchy is newer, so some things may not work until Patchy UI is updated.")
        case .patchyOlder(_, let supported):
            String(localized: "This Patchy UI was made for Patchy \(supported). Patchy is older; update it in Terminal with: \(AppModel.patchyUpgradeCommand)")
        }
    }

    /// Homebrew keeps each formula under a folder named for its version.
    private static func serverVersion(_ model: AppModel) -> String? {
        guard let environment = model.environment else { return nil }
        let link = environment.optDir.appending(path: "httpd")
        guard FileManager.default.fileExists(atPath: link.path) else { return nil }
        return link.resolvingSymlinksInPath().lastPathComponent.split(separator: "_").first.map(String.init)
    }
}
