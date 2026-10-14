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
        .navigationSubtitle(Phrases.siteCount(model.sites.count))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ServerPill()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                // The buttons stay in place while a task runs, disabled, so the toolbar doesn't jump.
                if model.serverRunning {
                    Button(model.unroutedCount > 0 ? "Repair" : "Restart") { model.restart() }
                        .help("Restart the server (also repairs addresses)")
                        .disabled(model.isBusy)
                    Button("Stop") { model.stop() }
                        .help("Stop the server and release your addresses")
                        .disabled(model.isBusy)
                } else {
                    Button("Start Server") { model.start() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isBusy)
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
        let sections = model.sidebarSections
        // The footer is stacked under the list, not laid over it as a safe-area inset. As an inset
        // it covered the last row when the list was scrolled to the end.
        VStack(spacing: 0) {
        ScrollViewReader { proxy in
        List(selection: $model.selection) {
            ForEach(sections.groups, id: \.group.id) { entry in
                // While filtering, groups with no match are hidden and the rest are held open.
                if !model.isFiltering || !entry.sites.isEmpty {
                    Section(isExpanded: Binding(
                        get: { model.isFiltering || !entry.group.isCollapsed },
                        set: { model.setGroup(entry.group, expanded: $0) })) {
                        ForEach(entry.sites, id: \.self) { address in
                            if let site = model.site(address) {
                                SiteRow(site: site).tag(address).id(address)
                            }
                        }
                        // Dropping anywhere among a group's sites moves the dragged site into it.
                        .dropDestination(for: String.self) { addresses, _ in
                            model.dropSites(addresses, on: entry.group.id)
                        }
                    } header: {
                        GroupHeader(group: entry.group, sites: entry.sites)
                    }
                }
            }
            if sections.groups.isEmpty {
                ungroupedRows(sections.ungrouped)
            } else if !sections.ungrouped.isEmpty || !model.isFiltering {
                // Kept even when every site is in a group, so there is somewhere to drag a site
                // out of its group.
                Section {
                    ungroupedRows(sections.ungrouped)
                        .dropDestination(for: String.self) { addresses, _ in
                            model.dropSites(addresses, on: nil)
                        }
                } header: {
                    DropHeader(groupID: nil) {
                        Text("Other Sites")
                    }
                }
            }
        }
        .onDeleteCommand { model.askRemove() }
        // Bring a selection made elsewhere into view: a site that was just added, or one picked
        // from the menu bar.
        .onChange(of: model.selection) { _, selected in
            guard let selected else { return }
            // A row that was only just added isn't laid out yet in this update, and the list
            // estimates the position of rows it hasn't drawn, so one jump can land short.
            Task {
                for delay in [200, 350] {
                    try? await Task.sleep(for: .milliseconds(delay))
                    guard model.selection == selected else { return }
                    proxy.scrollTo(selected, anchor: .center)
                }
            }
        }
        }
        .alert(model.groupNameDialogIsRename ? "Rename Group" : "New Group", isPresented: $model.groupNameDialogShown) {
            TextField("Group name", text: $model.groupNameDraft)
            Button("Cancel", role: .cancel) { model.cancelGroupName() }
            Button(model.groupNameDialogIsRename ? "Rename" : "Create") { model.commitGroupName() }
        } message: {
            Text("A group keeps related sites together in the sidebar and the menu bar, such as one customer’s sites. It doesn’t change the sites themselves.")
        }
        .overlay(alignment: .top) {
            if model.sites.isEmpty, model.groups.groups.isEmpty {
                emptyNote("No sites yet.")
            } else if model.visibleSites.isEmpty {
                emptyNote("No sites match “\(model.filter)”.")
            }
        }
        footer
        }
        .searchable(text: $model.filter, placement: .sidebar, prompt: "Filter sites")
    }

    @ViewBuilder private func ungroupedRows(_ addresses: [String]) -> some View {
        ForEach(addresses, id: \.self) { address in
            if let site = model.site(address) {
                SiteRow(site: site).tag(address).id(address)
            }
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
        if !model.footerText.isEmpty || !model.trustEnabled || model.groupSuggestion != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let suggestion = model.groupSuggestion {
                    GroupSuggestionCard(suggestion: suggestion)
                }
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
        // The whole width of the row, not just its text, picks the site up.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(site.address), \(status.summary)")
        .draggable(site.address)
        .contextMenu {
            Button("Open in Browser") { model.openInBrowser(site) }
                .disabled(!model.serverRunning)
            Button("Copy Address") { model.copyAddress(site) }
            Button("Reveal in Finder") { model.revealFolder(site) }
                .disabled(!site.folderExists)
            Divider()
            Menu("Move to Group") { GroupChoices(address: site.address) }
            Divider()
            Button("Remove…") { model.askRemove(site.address) }
                .disabled(model.isBusy)
        }
    }
}

/// The choices for which group a site is in. Used by the row's menu and the detail pane.
struct GroupChoices: View {
    @Environment(AppModel.self) private var model
    var address: String

    var body: some View {
        let current = model.groups.group(of: address)
        ForEach(model.sortedGroups) { group in
            Toggle(group.name, isOn: Binding(
                get: { current?.id == group.id },
                set: { model.moveSite(address, to: $0 ? group.id : nil) }))
        }
        if !model.sortedGroups.isEmpty { Divider() }
        Button("New Group…") { model.promptNewGroup(assigning: address) }
        if current != nil {
            Button("Remove from Group") { model.moveSite(address, to: nil) }
        }
    }
}

struct GroupHeader: View {
    @Environment(AppModel.self) private var model
    var group: SiteGroup
    var sites: [String]

    var body: some View {
        let problems = sites.compactMap(model.site).filter { model.status(of: $0).hasProblem }.count
        DropHeader(groupID: group.id) {
            HStack(spacing: 6) {
                Text(group.name)
                    .lineLimit(1)
                Text("\(sites.count)")
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                if problems > 0 {
                    Glyph(severity: .warning, size: 12)
                        .help(Phrases.sitesInGroupNeedAttention(problems))
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Phrases.groupAccessibilityLabel(name: group.name, sites: sites.count, problems: problems))
        }
        .contextMenu {
            Button("Rename…") { model.promptRenameGroup(group) }
            Button("Delete Group") { model.deleteGroup(group) }
        }
    }
}

/// A section header that sites can be dropped on, the only target for a collapsed or empty group.
/// Highlighted while a site is held over it.
struct DropHeader<Content: View>: View {
    @Environment(AppModel.self) private var model
    var groupID: UUID?
    @ViewBuilder var content: Content
    @State private var isTargeted = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(isTargeted ? Color.accentColor.opacity(0.2) : .clear,
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
            .padding(.horizontal, -6)
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { addresses, _ in
                model.dropSites(addresses, on: groupID)
            } isTargeted: { isTargeted = $0 }
    }
}

/// Offers to group sites that look related. Never groups anything by itself.
struct GroupSuggestionCard: View {
    @Environment(AppModel.self) private var model
    var suggestion: SiteGroups.Suggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "\(suggestion.sites.count) sites look related: \(suggestion.sites.joined(separator: ", "))")
                .lineLimit(3)
                .foregroundStyle(.primary)
            HStack(spacing: 12) {
                Button("Group as “\(suggestion.name)”") { model.applyGroupSuggestion(suggestion) }
                    .buttonStyle(.patchyLink)
                    .fontWeight(.medium)
                Button("Not Now") { model.dismissGroupSuggestion(suggestion) }
                    .buttonStyle(.plain)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DetailColumn: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            BannerStack()
                .layoutPriority(1)
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
                BannerRow(severity: .warning,
                          text: Phrases.unrouted(model.unroutedCount),
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
            // No vertical fixedSize here. This row sits outside any scroll view, so its height counts
            // toward the window's minimum height, and a fixed-height text measured at the narrowest
            // width reports many lines. That pushed the minimum past the window's height and left the
            // whole window's content taller than the window.
            Text(text)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
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
