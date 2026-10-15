import PatchyKit
import SwiftUI

/// A shared site's link, under its actions. Sits outside the scroll view, so text uses
/// lineLimit, never fixedSize (see CLAUDE.md).
struct SharePanel: View {
    @Environment(AppModel.self) private var model
    var address: String
    var state: ShareState
    @State private var copied: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch state {
            case .starting:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Getting a public link…")
                }
            case .sharing(let access):
                sharing(access)
            case .failed(let output, let wasSharing):
                HStack(alignment: .center, spacing: 8) {
                    Glyph(severity: .error, size: 14)
                    Text(ShareCopy.problem(output: output, wasSharing: wasSharing))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Show Details") { model.showShareProblem(address) }
                        .buttonStyle(.patchyLink)
                    Button("Try Again") { model.retryShare(address) }
                    Button("Dismiss") { model.dismissShareProblem(address) }
                }
            case .stopped:
                EmptyView()
            }
        }
        .font(.system(size: 12.5))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.sheetCardBorder, lineWidth: 0.5))
    }

    @ViewBuilder private func sharing(_ access: ShareAccess) -> some View {
        // The link and its buttons share a line when they fit; in a narrow window
        // (or a language with long words) the buttons move under the link.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                link(access)
                buttons(access)
            }
            VStack(alignment: .leading, spacing: 8) {
                link(access)
                HStack(spacing: 8) { buttons(access) }
            }
        }
        if let username = access.username, let password = access.password {
            HStack(spacing: 6) {
                Text("Username").foregroundStyle(Theme.secondaryText)
                Text(verbatim: username).monospaced().textSelection(.enabled)
                Text("Password").foregroundStyle(Theme.secondaryText).padding(.leading, 12)
                Text(verbatim: password).monospaced().textSelection(.enabled)
            }
            // Patchy's own output reads left to right in every language; so does a password.
            .environment(\.layoutDirection, .leftToRight)
        }
        Text(ShareCopy.notice(for: access))
            .foregroundStyle(Theme.secondaryText)
            .lineLimit(2)
        if ShareCopy.isTemporary(access) {
            Text("Sites with a fixed web address, like WordPress, may send visitors to the local address instead.")
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
        }
        Text("New links can take a few seconds to start working.")
            .foregroundStyle(Theme.secondaryText)
            .lineLimit(1)
    }

    private func link(_ access: ShareAccess) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "link").foregroundStyle(Theme.secondaryText)
            Text(verbatim: access.url.absoluteString)
                .fontWeight(.medium)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func buttons(_ access: ShareAccess) -> some View {
        Button(copied == "link" ? "Copied" : "Copy Link") { model.copyShareLink(address); flash("link") }
        if access.password != nil {
            Button(copied == "all" ? "Copied" : "Copy Address and Password") { model.copyShareDetails(address); flash("all") }
        }
        Button(model.stoppingShares.contains(address) ? "Stopping…" : "Stop Sharing") { model.stopSharing(address) }
            .disabled(model.stoppingShares.contains(address))
    }

    private func flash(_ key: String) {
        copied = key
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            if copied == key { copied = nil }
        }
    }
}
