import PatchyKit
import SwiftUI

struct MainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 252, max: 360)
        } detail: {
            DetailColumn()
        }
        .navigationTitle("Patchy")
        .navigationSubtitle(pluralized(model.sites.count, "site"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ServerPill()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if !model.isBusy {
                    if model.serverRunning {
                        Button(model.unroutedCount > 0 ? "Repair" : "Restart") { model.restart() }
                            .help("Restart the server (also repairs addresses)")
                        Button("Stop") { model.stop() }
                            .help("Stop the server and release your addresses")
                    } else {
                        Button("Start Server") { model.start() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                Button {
                    model.openAdd()
                } label: {
                    Label("Add Site", systemImage: "plus")
                }
                .help("Add Site (⌘N)")
                .disabled(model.isBusy)
            }
        }
    }
}

/// Always-visible server status. Shows the current step while a task runs.
struct ServerPill: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 7) {
            if model.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.75)
                    .frame(width: 12, height: 12)
            } else {
                ServerDot(size: 9)
            }
            Text(model.serverPillText)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: 300)
        .modifier(PillBackground())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Server: \(model.serverPillText)")
    }
}

/// Filled when running, outlined when stopped, so the state reads without colour.
struct ServerDot: View {
    @Environment(AppModel.self) private var model
    var size: CGFloat

    var body: some View {
        Group {
            if model.serverRunning {
                Circle().fill(model.unroutedCount > 0 ? Theme.warning : Theme.green)
            } else {
                Circle().strokeBorder(Theme.grey, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selection) {
            ForEach(model.visibleSites) { site in
                SiteRow(site: site)
                    .tag(site.address)
            }
        }
        .onDeleteCommand { model.askRemove() }
        .overlay(alignment: .top) {
            if model.sites.isEmpty {
                emptyNote("No sites yet.")
            } else if model.visibleSites.isEmpty {
                emptyNote("No sites match “\(model.filter)”.")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            TextField("Filter sites", text: $model.filter)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .background(.bar)
                .accessibilityLabel("Filter sites")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
    }

    @ViewBuilder private var footer: some View {
        if !model.footerText.isEmpty || !model.trustEnabled {
            VStack(alignment: .leading, spacing: 8) {
                if !model.trustEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.trustIsUpdate
                             ? "Patchy was updated, so password-free mode needs refreshing once."
                             : "Patchy asks for your Mac password on every change.")
                        Button(model.trustIsUpdate ? "Update password-free mode…" : "Set up password-free mode…") {
                            model.openTrustSetup()
                        }
                        .buttonStyle(.patchyLink)
                        .fontWeight(.medium)
                    }
                }
                if !model.footerText.isEmpty {
                    Text(model.footerText)
                }
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
    }
}

struct SiteRow: View {
    @Environment(AppModel.self) private var model
    var site: Site

    var body: some View {
        let status = model.status(of: site)
        HStack(spacing: 9) {
            Glyph(severity: status.severity)
            VStack(alignment: .leading, spacing: 1) {
                Text(site.address)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(status.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(site.address), \(status.summary)")
        .contextMenu {
            Button("Open in Browser") { model.openInBrowser(site) }
                .disabled(!model.serverRunning)
            Button("Copy Address") { model.copyAddress(site) }
            Button("Reveal in Finder") { model.revealFolder(site) }
                .disabled(!site.folderExists)
            Divider()
            Button("Remove…") { model.askRemove(site.address) }
                .disabled(model.isBusy)
        }
    }
}

struct DetailColumn: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            BannerStack()
            if model.sites.isEmpty {
                FirstSiteView()
            } else if let site = model.selectedSite {
                SiteDetailView(site: site)
            } else {
                Text("Select a site to see its details.")
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

/// Status strips under the toolbar: repair needed, server stopped, and the result of the last action.
struct BannerStack: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if !model.compatibilityDismissed {
                switch model.compatibility {
                case .patchyNewer(let installed, let supported):
                    BannerRow(severity: .warning,
                              text: "Patchy \(installed) is installed, but this Patchy UI was made for Patchy \(supported). Some things may not work until Patchy UI is updated to match.",
                              actionTitle: "Check for Updates…", action: { model.updater.checkForUpdates() },
                              onClose: { model.compatibilityDismissed = true })
                case .patchyOlder(let installed, let supported):
                    BannerRow(severity: .warning,
                              text: "This Patchy UI was made for Patchy \(supported), but Patchy \(installed) is installed. Update Patchy to avoid problems: paste the command into Terminal.",
                              actionTitle: "Copy Update Command", action: { model.copyPatchyUpgradeCommand() },
                              onClose: { model.compatibilityDismissed = true })
                case .matched, .unknown:
                    EmptyView()
                }
            }
            if !model.isBusy, model.unroutedCount > 0 {
                let count = model.unroutedCount
                BannerRow(severity: .warning,
                          text: "\(count) site\(count == 1 ? " isn’t" : "s aren’t") pointing at this Mac right now, so \(count == 1 ? "it won’t" : "they won’t") open. Repair fixes this by restarting the server.",
                          actionTitle: "Repair", action: { model.restart() })
            }
            if !model.isBusy, !model.sites.isEmpty, !model.serverRunning {
                BannerRow(severity: .off, text: "The server is stopped, so none of your sites will open right now.",
                          actionTitle: "Start Server", action: { model.start() })
            }
            if let banner = model.banner {
                let site = banner.openAddress.flatMap { address in model.sites.first { $0.address == address } }
                BannerRow(severity: banner.severity, text: banner.text,
                          actionTitle: site == nil ? nil : "Open in Browser",
                          action: { if let site { model.openInBrowser(site) } },
                          onClose: { model.banner = nil })
            }
        }
    }
}

struct BannerRow: View {
    var severity: Severity
    var text: String
    var actionTitle: String?
    var action: () -> Void = {}
    var onClose: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Glyph(severity: severity)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .controlSize(.small)
            }
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.secondaryText)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 9)
        .background(Theme.bannerBackground)
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// macOS 26 and later draw their own capsule around toolbar items; earlier systems need one drawn.
private struct PillBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
        } else {
            content
                .padding(.horizontal, 5)
                .frame(height: 26)
                .background(.quaternary.opacity(0.6), in: Capsule())
        }
    }
}
