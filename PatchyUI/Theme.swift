import AppKit
import SwiftUI

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Colours from the Patchy UI design: native macOS with one warm amber accent.
enum Theme {
    static let accent = Color(light: 0xB85207, dark: 0xE38231)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x1D1206)
    static let link = Color(light: 0xAA4600, dark: 0xF19A4B)
    static let accentSoft = Color(light: 0xFFE6D0, dark: 0x4D2C15)
    static let focusRing = Color(light: 0xFEDEC4, dark: 0x593215)

    static let green = Color(light: 0x2D8949, dark: 0x4EB068)
    static let warning = Color(light: 0xF0BB3B, dark: 0xF0BB3B)
    static let onWarning = Color(light: 0x2A2000, dark: 0x2A2000)
    static let red = Color(light: 0xC9302D, dark: 0xEC5B57)
    static let redText = Color(light: 0xB32322, dark: 0xFA8880)
    static let grey = Color(light: 0xB3ADA6, dark: 0x5F5953)

    static let secondaryText = Color(light: 0x6F6A64, dark: 0xA39D96)
    static let bodyText = Color(light: 0x5F5A54, dark: 0xB3ADA6)

    static let bannerBackground = Color(light: 0xF7F5F2, dark: 0x24211F)
    static let cardBackground = Color(light: 0xF8F6F4, dark: 0x252220)
    static let cardBorder = Color(light: 0xE6E2DD, dark: 0x36322E)
    static let fieldBackground = Color(light: 0xFFFFFF, dark: 0x24211E)
    static let fieldBorder = Color(light: 0xD6D1CB, dark: 0x4A4540)
    static let wellBackground = Color(light: 0xF3F1EE, dark: 0x2B2825)
    static let sheetCard = Color(light: 0xFFFFFF, dark: 0x33302C)
    static let sheetCardBorder = Color(light: 0xE2DDD7, dark: 0x413C37)
    static let dashedCard = Color(light: 0xFBFAF8, dark: 0x2E2B28)
    static let logBackground = Color(light: 0xFBFAF8, dark: 0x181614)

    static let realTagBackground = Color(light: 0xFEEDC9, dark: 0x48340E)
    static let realTagText = Color(light: 0x6C4302, dark: 0xF6D389)
    static let warningBox = Color(light: 0xFEF4DF, dark: 0x31240E)
    static let warningBoxBorder = Color(light: 0xEDD5A3, dark: 0x59441F)
}

enum Severity: Sendable {
    case ok, warning, error, off, info
}

/// The small round status mark. Shape and character differ per state, so it reads without colour.
struct Glyph: View {
    var severity: Severity
    var size: CGFloat = 16

    private var fill: Color {
        switch severity {
        case .ok: Theme.green
        case .warning: Theme.warning
        case .error: Theme.red
        case .off: Theme.grey
        case .info: Theme.accent
        }
    }

    private var foreground: Color {
        switch severity {
        case .warning: Theme.onWarning
        case .info: Theme.onAccent
        default: .white
        }
    }

    private var symbol: String {
        switch severity {
        case .ok: "checkmark"
        case .warning: "exclamationmark"
        case .error: "xmark"
        case .off: "minus"
        case .info: "info"
        }
    }

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.52, weight: .heavy))
                    .foregroundStyle(foreground)
            }
            .accessibilityHidden(true)
    }
}

/// The app's mark: a server rack with one stitched-on amber patch, filling the whole icon shape.
/// Dark on light backgrounds, light on dark ones, so it never disappears into the window.
struct RackLogo: View {
    var size: CGFloat = 60

    private let plate = Color(light: 0x2B2622, dark: 0xF5EFE6)
    private let unitColor = Color(light: 0x3E3732, dark: 0xDDD3C6)
    private let patch = Color(light: 0xDC701C, dark: 0xDC701C)

    var body: some View {
        let unit = size * 0.19
        VStack(spacing: size * 0.075) {
            RoundedRectangle(cornerRadius: size * 0.045).fill(unitColor).frame(height: unit)
            RoundedRectangle(cornerRadius: size * 0.045).fill(patch).frame(height: unit)
            RoundedRectangle(cornerRadius: size * 0.045).fill(unitColor).frame(height: unit)
        }
        .padding(.horizontal, size * 0.14)
        .frame(width: size, height: size)
        .background(plate, in: RoundedRectangle(cornerRadius: size * 0.233, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
        .accessibilityHidden(true)
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.link)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == LinkButtonStyle {
    static var patchyLink: LinkButtonStyle { LinkButtonStyle() }
}

/// A rounded, bordered container used for grouped rows.
struct Card<Content: View>: View {
    var background: Color = Theme.cardBackground
    var border: Color = Theme.cardBorder
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(border, lineWidth: 0.5))
    }
}
