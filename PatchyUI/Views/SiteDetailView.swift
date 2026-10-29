import PatchyKit
import SwiftUI

struct SiteDetailView: View {
    @Environment(AppModel.self) private var model
    var site: Site
    @State private var flash: String?

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        header
                        Spacer(minLength: 0)
                        actions
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        actions
                    }
                }
                if let state = model.shares[site.address], state != .stopped {
                    SharePanel(address: site.address, state: state)
                }
                Picker("View", selection: $model.tab) {
                    ForEach(DetailTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                // Neutral, so Open in Browser stays the one orange control on the page.
                .tint(Color.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            // The tab content below scrolls, so it gives up height before the header does.
            .layoutPriority(1)

            switch model.tab {
            case .overview:
                OverviewView(site: site)
            case .errors:
                LogView(site: site, kind: .errors)
            case .visits:
                LogView(site: site, kind: .visits)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Text(site.address)
                    .font(.system(size: 22, weight: .semibold))
                    .lineLimit(1)
                    .textSelection(.enabled)
                if site.isRealAddress {
                    Text("Real web address")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.realTagBackground, in: RoundedRectangle(cornerRadius: 5))
                        .foregroundStyle(Theme.realTagText)
                }
            }
            addressLine
        }
    }

    /// The address as a link, a small Copy, and the www. address when there is one.
    private var addressLine: some View {
        HStack(spacing: 12) {
            Button {
                model.openInBrowser(site)
            } label: {
                Text(verbatim: site.url.absoluteString)
            }
            .buttonStyle(.patchyLink)
            .disabled(!model.serverRunning)
            .help(model.serverRunning ? "Open \(site.url.absoluteString)" : "Start the server to open this site")

            Button {
                model.copyAddress(site)
                showFlash("copy")
            } label: {
                Label(flash == "copy" ? "Copied" : "Copy", systemImage: flash == "copy" ? "checkmark" : "doc.on.doc")
                    .labelStyle(SmallIconLabelStyle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.secondaryText)
            .help("Copy Address")

            if let www = site.wwwAlias {
                Text(verbatim: String(localized: "Also answers at \(www)", comment: "Under a site's address in its details. The placeholder is the www. address."))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .font(.system(size: 12))
    }

    /// Open in Browser, Share as an icon, and the rest in a “…” menu.
    private var actions: some View {
        HStack(spacing: 8) {
            Button(flash == "open" ? "Opening…" : "Open in Browser") {
                model.openInBrowser(site)
                showFlash("open")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.serverRunning)
            .help(model.serverRunning ? "Open \(site.url.absoluteString)" : "Start the server to open this site")

            if model.canShare {
                if model.isSharing(site.address) {
                    Button { model.stopSharing(site.address) } label: {
                        Label("Stop Sharing", systemImage: "stop.circle")
                    }
                    .labelStyle(.iconOnly)
                    .help("Stop Sharing")
                    .disabled(model.stoppingShares.contains(site.address))
                } else {
                    shareButton
                        .labelStyle(.iconOnly)
                        .help(model.serverRunning ? "Share this site at a public link" : "Start the server to share this site")
                        .disabled(!model.serverRunning)
                }
            }

            Menu {
                Button("Reveal in Finder") { model.revealFolder(site) }
                    .disabled(!site.folderExists)
                Divider()
                Button("Remove Site…", role: .destructive) { model.askRemove(site.address) }
                    .disabled(model.isBusy)
            } label: {
                Label("More", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
                    .frame(height: 20)
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
        }
        .controlSize(.large)
        .fixedSize()
    }

    /// With a domain connected, Share asks which link to make; otherwise it makes an anonymous link.
    @ViewBuilder private var shareButton: some View {
        if model.sharingDomain == nil {
            Button { model.share(site) } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } else {
            Menu {
                ShareMenuItems(site: site)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func showFlash(_ key: String) {
        flash = key
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            if flash == key { flash = nil }
        }
    }
}

struct OverviewView: View {
    @Environment(AppModel.self) private var model
    var site: Site

    var body: some View {
        let status = model.status(of: site)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    InfoRow(label: "Folder") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                Text(site.displayFolder)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button("Change…") { model.openFolderEdit() }
                                    .controlSize(.small)
                                    .disabled(model.isBusy)
                            }
                            if !site.folderExists {
                                HStack(alignment: .top, spacing: 8) {
                                    Glyph(severity: .error, size: 14)
                                    Text("This folder isn’t there anymore. Put it back, or click Change… to point the site at the right folder.")
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.redText)
                            }
                        }
                    }
                    Divider()
                    InfoRow(label: "Group") {
                        Menu {
                            GroupChoices(address: site.address)
                        } label: {
                            Text(model.groups.group(of: site.address)?.name ?? String(localized: "None", comment: "The site is in no sidebar group."))
                        }
                        .menuStyle(.button)
                        .controlSize(.small)
                        .fixedSize()
                    }
                    Divider()
                    InfoRow(label: "Secure connection") {
                        HStack(alignment: .top, spacing: 9) {
                            Glyph(severity: status.certificate.severity)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(status.certificate.label).fontWeight(.medium)
                                Text(status.certificate.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                if status.certificateNeedsRefresh {
                                    Button("Refresh Certificates…") { model.askRefreshCertificates() }
                                        .disabled(model.isBusy)
                                        .padding(.top, 8)
                                }
                            }
                        }
                    }
                    Divider()
                    InfoRow(label: "Reachable") {
                        HStack(alignment: .top, spacing: 9) {
                            Glyph(severity: status.reachable.severity)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(status.reachable.label).fontWeight(.medium)
                                Text(status.reachable.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                }

                TodayCard(site: site)

                if site.isRealAddress {
                    HStack(alignment: .top, spacing: 10) {
                        Glyph(severity: .warning)
                        Text(verbatim: String(localized: "\(site.address) is a real web address. While the server runs, this Mac opens your local copy and can’t reach the live website. Stop the server to see the live site again."))
                            .font(.system(size: 12.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.warningBox, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.warningBoxBorder, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
    }
}

/// Today's error and visit counts from the site's logs. Each row opens its tab.
struct TodayCard: View {
    @Environment(AppModel.self) private var model
    var site: Site
    @State private var counts: LogCounts?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today", comment: "Heading over a site's error and visit counts for today.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .padding(.leading, 4)
            Card {
                row("Errors", value: counts.map { Phrases.errorsToday($0.errors) }, alarming: (counts?.errors ?? 0) > 0, tab: .errors)
                Divider()
                row("Visits", value: counts.map { Phrases.visitsToday($0.visits) }, alarming: false, tab: .visits)
            }
        }
        .task(id: site.address) {
            counts = nil
            // Logs grow while the page is open; recount every few seconds. Reading stops at
            // yesterday's lines, so this stays cheap however long the log is.
            while !Task.isCancelled {
                counts = await Self.count(site)
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private static func count(_ site: Site) async -> LogCounts {
        await Task.detached(priority: .utility) {
            LogCounts.today(errorLog: site.errorLog, accessLog: site.accessLog)
        }.value
    }

    private func row(_ label: LocalizedStringKey, value: String?, alarming: Bool, tab: DetailTab) -> some View {
        Button {
            model.tab = tab
        } label: {
            InfoRow(label: label) {
                HStack {
                    Text(value ?? " ")
                        .foregroundStyle(alarming ? Theme.redText : Color.primary)
                        .fontWeight(alarming ? .medium : .regular)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct InfoRow<Content: View>: View {
    var label: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 150, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// A small icon beside its title, for the Copy link under a site's name.
private struct SmallIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.font(.system(size: 10.5))
            configuration.title
        }
    }
}
