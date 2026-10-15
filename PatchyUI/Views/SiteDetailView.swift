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
                header
                actions
                Picker("View", selection: $model.tab) {
                    ForEach(DetailTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)

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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(site.address)
                    .font(.system(size: 22, weight: .semibold))
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
            if let www = site.wwwAlias {
                Text(verbatim: String(localized: "Also answers at \(www)", comment: "Under a site's address in its details. The placeholder is the www. address."))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    /// When the labels don't fit (a narrow window in a language with long words), Copy Address
    /// and Reveal in Finder show only their icons; their names stay as tooltips and for VoiceOver.
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            actionRow(compact: false)
            actionRow(compact: true)
        }
        .controlSize(.large)
    }

    private func actionRow(compact: Bool) -> some View {
        HStack(spacing: 8) {
            Button(flash == "open" ? "Opening…" : "Open in Browser") {
                model.openInBrowser(site)
                showFlash("open")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.serverRunning)
            .help(model.serverRunning ? "Open \(site.url.absoluteString)" : "Start the server to open this site")

            Button {
                model.copyAddress(site)
                showFlash("copy")
            } label: {
                Label(flash == "copy" ? "Copied" : "Copy Address", systemImage: flash == "copy" ? "checkmark" : "doc.on.doc")
            }
            .labelStyle(compact ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleOnly))
            .help(compact ? "Copy Address" : "")

            Button { model.revealFolder(site) } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            .labelStyle(compact ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleOnly))
            .help(compact ? "Reveal in Finder" : "")
            .disabled(!site.folderExists)

            Spacer(minLength: 8)

            Button("Remove…", role: .destructive) { model.askRemove(site.address) }
                .foregroundStyle(Theme.redText)
                .disabled(model.isBusy)
                .help("Remove Site (Delete)")
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
                    InfoRow(label: "Address") {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.url.absoluteString)
                                .textSelection(.enabled)
                            if let www = site.wwwAlias {
                                Text(verbatim: "https://\(www)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                    Divider()
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

/// Picks a label style at run time.
private struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView

    init(_ style: some LabelStyle) { make = { AnyView(style.makeBody(configuration: $0)) } }

    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
