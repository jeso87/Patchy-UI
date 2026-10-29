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
        case .working: String(localized: "Patchy: working", comment: "VoiceOver label for the menu bar item.")
        case .stopped: String(localized: "Patchy: server stopped", comment: "VoiceOver label for the menu bar item.")
        case .attention: String(localized: "Patchy: needs attention", comment: "VoiceOver label for the menu bar item.")
        case .running: String(localized: "Patchy: server running", comment: "VoiceOver label for the menu bar item.")
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

/// The menu bar panel: server status and controls, a search field, every site, and the app's
/// commands. Type a few letters and press Return to open a site.
struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var highlighted: String?
    @State private var hovered: String?
    @State private var window: NSWindow?
    @State private var arrowKeys: Any?
    @FocusState private var searchFocused: Bool

    static let width: CGFloat = 400
    private static let rowHeight: CGFloat = 26
    private static let headerHeight: CGFloat = 24
    private static let listMaxHeight: CGFloat = 340

    private var list: MenuPanelList {
        MenuPanelList(rows: model.menuPanelRows, groups: model.groups, query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.phase == .ready {
                header
                search
                siteList
                sharing
            } else {
                Text(model.phase == .checking ? "Checking your Mac…" : "Patchy isn’t installed yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            Divider()
            footer
        }
        .frame(width: Self.width)
        .background(WindowReader(window: $window))
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            // Each time the panel opens: a fresh search, ready to type into.
            guard let window, note.object as? NSWindow === window else { return }
            query = ""
            highlighted = nil
            searchFocused = true
        }
        .onAppear {
            searchFocused = true
            // The search field takes the up and down arrows for itself, so they are caught first.
            arrowKeys = arrowKeys ?? NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard let window, event.window === window else { return event }
                switch event.keyCode {
                case 125: highlighted = list.highlight(after: highlighted, by: 1)
                case 126: highlighted = list.highlight(after: highlighted, by: -1)
                default: return event
                }
                return nil
            }
        }
    }

    // MARK: Parts

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.isBusy ? Theme.accent : model.serverRunning ? Theme.green : Theme.grey)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.isBusy ? (model.busy?.text ?? String(localized: "Working…")) : model.serverRunning ? String(localized: "Server running") : String(localized: "Server stopped"))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(verbatim: "\(Phrases.siteCount(model.sites.count)) · \(model.phpLabel)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if model.serverRunning {
                Button(model.unroutedCount > 0 ? "Repair" : "Restart") { model.restart() }
                Button("Stop") { model.stop() }
            } else {
                Button("Start Server") { model.start() }
            }
        }
        .controlSize(.small)
        .disabled(model.isBusy)
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var search: some View {
        TextField("Find a site", text: $query)
            .textFieldStyle(.roundedBorder)
            .focused($searchFocused)
            .onChange(of: query) { highlighted = nil }
            .onSubmit { open(list.target(highlighted: highlighted)) }
            .onExitCommand { close() }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
    }

    @ViewBuilder private var siteList: some View {
        let list = list
        if list.rows.isEmpty {
            Text(model.sites.isEmpty ? String(localized: "No sites yet") : String(localized: "No sites match", comment: "Menu bar panel: nothing matches the search."))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        } else {
            let current = list.target(highlighted: highlighted)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(list.sections) { section in
                            if let title = section.title {
                                Text(verbatim: title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .frame(height: Self.headerHeight, alignment: .bottomLeading)
                                    .padding(.horizontal, 8)
                            }
                            ForEach(section.rows, id: \.address) { row in
                                siteRow(row, isCurrent: row.address == current)
                                    .id(row.address)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
                .frame(height: min(Self.listMaxHeight, height(of: list)))
                .onChange(of: highlighted) { if let highlighted { proxy.scrollTo(highlighted) } }
            }
        }
    }

    private func siteRow(_ row: MenuPanelList.Row, isCurrent: Bool) -> some View {
        let lit = isCurrent || hovered == row.address
        return HStack(spacing: 9) {
            Glyph(severity: row.severity, size: 14)
            Text(verbatim: row.address)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            if !row.note.isEmpty {
                Text(verbatim: row.note)
                    .font(.system(size: 11))
                    .foregroundStyle(lit ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
            }
            if hovered == row.address {
                Button {
                    close()
                    model.showSite(row.address)
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(lit ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.secondary))
                .help(String(localized: "Show in Patchy UI", comment: "Tooltip on a site in the menu bar panel."))
            }
        }
        .foregroundStyle(lit ? Theme.onAccent : .primary)
        .padding(.horizontal, 8)
        .frame(height: Self.rowHeight)
        .background(RoundedRectangle(cornerRadius: 5).fill(lit ? Theme.accent : .clear))
        .contentShape(Rectangle())
        .onHover { inside in hovered = inside ? row.address : (hovered == row.address ? nil : hovered) }
        .onTapGesture { open(row.address) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.note.isEmpty ? row.address : "\(row.address), \(row.note)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open(row.address) }
    }

    @ViewBuilder private var sharing: some View {
        let shared = model.sharedAddresses
        if !shared.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("Sharing")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
                ForEach(shared, id: \.self) { address in
                    HStack(spacing: 8) {
                        Image(systemName: "link").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(verbatim: address).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 6)
                        Button("Copy Link") { model.copyShareLink(address) }
                        Button("Stop Sharing") { model.stopSharing(address) }
                    }
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            if model.phase == .ready {
                footerButton("Add Site…", systemImage: "plus") { model.openAdd() }
                    .disabled(model.isBusy)
            }
            Button {
                close()
                model.openMainWindow?()
            } label: {
                Label("Open Patchy UI", systemImage: "macwindow")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 13))
                    .padding(.horizontal, 4)
                    .frame(height: 22)
                    .contentShape(Rectangle())
            }
            Spacer()
            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }
            .simultaneousGesture(TapGesture().onEnded { close(); NSApp.activate(ignoringOtherApps: true) })
            .help(String(localized: "Settings…"))
            footerButton("Quit Patchy UI", systemImage: "power") { NSApp.terminate(nil) }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func footerButton(_ title: LocalizedStringResource, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            close()
            action()
        } label: {
            Label(String(localized: title), systemImage: systemImage)
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .help(String(localized: title))
    }

    // MARK: Actions

    private func height(of list: MenuPanelList) -> CGFloat {
        let titles = list.sections.filter { $0.title != nil }.count
        return CGFloat(list.rows.count) * Self.rowHeight + CGFloat(titles) * Self.headerHeight + 6
    }

    /// A healthy site opens in the browser. With the server stopped there is nothing to open,
    /// so the main window shows the site instead.
    private func open(_ address: String?) {
        guard let address, let site = model.site(address) else { return }
        close()
        if model.serverRunning {
            model.openInBrowser(site)
        } else {
            model.showSite(address)
        }
    }

    private func close() {
        window?.close()
    }
}

/// Hands back the window a view sits in; the menu bar panel uses it to close itself and to
/// know when it opens.
private struct WindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    final class Probe: NSView {
        var onWindow: (NSWindow?) -> Void = { _ in }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow(window)
        }
    }

    func makeNSView(context: Context) -> Probe {
        let view = Probe()
        view.onWindow = { window in DispatchQueue.main.async { self.window = window } }
        return view
    }

    func updateNSView(_ view: Probe, context: Context) {}
}
