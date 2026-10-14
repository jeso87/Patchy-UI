import AppKit
import PatchyKit
import SwiftUI

/// The menu bar glyph: three rack units. The shape changes per state, so it reads without colour.
enum MenuBarIcon {
    enum State {
        case running, stopped, working, attention
    }

    static func image(_ state: State) -> NSImage {
        let image = NSImage(size: NSSize(width: 19, height: 16), flipped: false) { _ in
            let width: CGFloat = 17, height: CGFloat = 3.4
            // Drawn bottom to top; the top unit is the last one.
            let rows: [CGFloat] = [1, 6.3, 11.6]
            let alphas: [CGFloat] = state == .working ? [0.25, 0.5, 1] : [1, 1, 1]
            for (y, alpha) in zip(rows, alphas) {
                let rect = NSRect(x: 0, y: y, width: width, height: height)
                NSColor.black.withAlphaComponent(alpha).set()
                if state == .stopped {
                    let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.6, dy: 0.6), xRadius: 1.2, yRadius: 1.2)
                    path.lineWidth = 1.2
                    path.stroke()
                } else {
                    NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
                }
            }
            if state == .attention {
                // Knock a ring out of the top unit, then set the dot inside it.
                let center = NSPoint(x: 16, y: 13.2)
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: NSRect(x: center.x - 4.2, y: center.y - 4.2, width: 8.4, height: 8.4)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                NSColor.black.set()
                NSBezierPath(ovalIn: NSRect(x: center.x - 2.8, y: center.y - 2.8, width: 5.6, height: 5.6)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    private var state: MenuBarIcon.State {
        if model.isBusy { return .working }
        guard model.phase == .ready, model.serverRunning else { return .stopped }
        return model.problemSites.isEmpty ? .running : .attention
    }

    private var description: String {
        switch state {
        case .working: "Patchy: working"
        case .stopped: "Patchy: server stopped"
        case .attention: "Patchy: needs attention"
        case .running: "Patchy: server running"
        }
    }

    var body: some View {
        Image(nsImage: MenuBarIcon.image(state))
            .accessibilityLabel(description)
            .onAppear {
                // The label exists from launch, even when the main window doesn't.
                model.connectWindowOpener(openWindow)
                model.launch()
            }
    }
}

struct MenuBarContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.phase == .ready {
            Text(model.isBusy ? (model.busy?.text ?? "Working…") : model.serverRunning ? "Server running" : "Server stopped")
            Text(verbatim: "\(Phrases.siteCount(model.sites.count)) · \(model.phpLabel)")

            if model.serverRunning {
                Button(model.unroutedCount > 0 ? "Repair" : "Restart Server") { model.restart() }
                    .keyboardShortcut("r")
                    .disabled(model.isBusy)
                Button("Stop Server") { model.stop() }
                    .disabled(model.isBusy)
            } else {
                Button("Start Server") { model.start() }
                    .keyboardShortcut("r")
                    .disabled(model.isBusy)
            }

            Divider()

            Menu("Open Site") {
                // Groups become submenus; sites outside any group are listed directly.
                let sections = model.groups.sections(for: model.addresses)
                ForEach(sections.groups, id: \.group.id) { entry in
                    if !entry.sites.isEmpty {
                        Menu(entry.group.name) {
                            ForEach(entry.sites, id: \.self) { address in siteButton(address) }
                        }
                    }
                }
                if sections.groups.contains(where: { !$0.sites.isEmpty }), !sections.ungrouped.isEmpty { Divider() }
                ForEach(sections.ungrouped, id: \.self) { address in siteButton(address) }
            }
            .disabled(model.sites.isEmpty || !model.serverRunning)

            let problems = model.problemSites.count
            if problems > 0 {
                Button(Phrases.sitesNeedAttention(problems)) { model.showAttention() }
            }

            Divider()

            Button("Add Site…") { model.openAdd() }
                .keyboardShortcut("n")
                .disabled(model.isBusy)
        } else {
            Text(model.phase == .checking ? "Checking your Mac…" : "Patchy isn’t installed yet")
            Divider()
        }

        Button("Open Patchy UI") { model.openMainWindow?() }
            .keyboardShortcut("o")
        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")
        Button("Check for Updates…") {
            NSApp.activate(ignoringOtherApps: true)
            model.updater.checkForUpdates()
        }

        Divider()

        Button("Quit Patchy UI") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder private func siteButton(_ address: String) -> some View {
        if let site = model.site(address) {
            Button {
                model.openInBrowser(site)
            } label: {
                Label(site.address, systemImage: symbol(for: model.status(of: site).severity))
            }
        }
    }

    private func symbol(for severity: Severity) -> String {
        switch severity {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .error: "xmark.circle.fill"
        case .off: "minus.circle"
        case .info: "info.circle"
        }
    }
}
