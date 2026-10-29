import AppKit
import SwiftUI

/// The menu bar item and its panel. Built on AppKit rather than `MenuBarExtra` because SwiftUI
/// offers no way to open its panel from code, and the global shortcut has to.
@MainActor
final class StatusItemController: NSObject {
    static var shared: StatusItemController?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: MenuPanelWindow
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        let controller = NSHostingController(rootView: MenuPanelChrome().environment(model))
        controller.sizingOptions = .preferredContentSize
        panel = MenuPanelWindow(contentViewController: controller)
        super.init()

        if let button = statusItem.button {
            // The SwiftUI label draws the icon and starts the app, as it did inside MenuBarExtra.
            let label = ClickThroughHostingView(rootView: MenuBarLabel().environment(model))
            label.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                button.widthAnchor.constraint(equalTo: label.widthAnchor, constant: 10),
            ])
        }
        if #available(macOS 27, *) {
            // Clicks arrive as the menu bar's own sessions, so the panel joins its keyboard
            // navigation and click tracking.
            statusItem.expandedInterfaceDelegate = self
        } else if let button = statusItem.button {
            button.target = self
            button.action = #selector(toggle)
            button.sendAction(on: .leftMouseDown)
        }

        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.place() }
        }
        // The panel doesn't bring the app forward, so it doesn't always lose key when someone
        // moves on. A click in another app, or another app coming forward, closes it too.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.clickedOutside() }
        }
    }

    private func clickedOutside() {
        guard iconFrame?.contains(NSEvent.mouseLocation) ?? false else { return close() }
        // On macOS 27 the system draws the menu bar, so a click on our own icon lands here too.
        // A second click doesn't end the menu bar's session, so end it here; without a session
        // (the shortcut's panel), the click begins one and the delegate closes the panel.
        if #available(macOS 27, *), statusItem.expandedInterfaceSession != nil { close() }
    }

    /// The icon on macOS 14–26, and the shortcut everywhere: macOS has no public way to start a
    /// session from code, so the shortcut shows the panel itself.
    @objc func toggle() {
        panel.isVisible ? close() : show()
    }

    /// Closes the panel, ending the menu bar's session first when there is one.
    func close() {
        if #available(macOS 27, *), let session = statusItem.expandedInterfaceSession {
            session.cancel() // AppKit answers with statusItemDidEndExpandedInterfaceSession.
        } else {
            hide()
        }
    }

    /// Whether the menu bar's session is showing the panel, and so lights the icon itself.
    private var sessionOpen: Bool {
        if #available(macOS 27, *) { return statusItem.expandedInterfaceSession != nil }
        return false
    }

    private func show() {
        place()
        panel.makeKeyAndOrderFront(nil)
        if !sessionOpen { statusItem.button?.highlight(true) }
        model.panelVisible = true
    }

    private func hide() {
        panel.orderOut(nil)
        model.panelVisible = false
        statusItem.button?.highlight(false)
    }

    /// Where the icon is on screen.
    private var iconFrame: NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// Hangs the panel from the icon, kept on the icon's screen; the top stays put as it resizes.
    private func place() {
        guard let icon = iconFrame, let window = statusItem.button?.window else { return }
        let size = panel.frame.size
        var x = icon.midX - size.width / 2
        if let screen = window.screen?.visibleFrame {
            x = min(max(x, screen.minX + 8), screen.maxX - size.width - 8)
        }
        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: (icon.minY - 6 - size.height).rounded()))
    }
}

@available(macOS 27, *)
extension StatusItemController: @MainActor NSStatusItemExpandedInterfaceDelegate {
    func statusItem(_ statusItem: NSStatusItem, didBegin session: NSStatusItemExpandedInterfaceSession) {
        // A click on the icon while the shortcut's panel is showing closes it, as it would
        // close a panel the icon opened.
        if panel.isVisible {
            session.cancel()
            hide()
        } else {
            show()
        }
    }

    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) {
        hide()
    }
}

/// A borderless panel that takes typing without bringing Patchy UI to the front, like Spotlight.
final class MenuPanelWindow: NSPanel {
    init(contentViewController: NSViewController) {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        self.contentViewController = contentViewController
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }

    // The panel's own close button (Escape, choosing a site) only hides it.
    override func close() {
        StatusItemController.shared?.close() ?? orderOut(nil)
    }
}

/// The menu material and rounded corners the panel draws itself, since it has no frame.
private struct MenuPanelChrome: View {
    var body: some View {
        MenuBarContent()
            .background(VisualEffect())
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
    }
}

private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.state = .active
        view.blendingMode = .behindWindow
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// Hosts the icon without taking the click, so the status button underneath gets it.
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
