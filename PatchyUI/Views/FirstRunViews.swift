import AppKit
import PatchyKit
import SwiftUI

/// No sites yet: name the first site and choose its folder right here.
struct FirstSiteView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = AddDraft()

    var body: some View {
        let problem = draft.problemText(existing: model.addresses)
        let valid = draft.isValidAddress(existing: model.addresses)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RackLogo(size: 60)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your first site")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.link)
                    Text("What should we call it?")
                        .font(.system(size: 24, weight: .semibold))
                    Text("Pick a short name. It becomes the address you type in your browser. Then choose the folder that holds the site’s files, and Patchy serves whatever is in it.")
                        .foregroundStyle(Theme.bodyText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AddressField(name: $draft.name, suffix: draft.suffix, hasError: problem != nil,
                             fontSize: 20, height: 46, emphasized: true)
                if let problem {
                    Text(problem)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.redText)
                }

                FolderCard(folder: $draft.folder)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Opens at").foregroundStyle(Theme.secondaryText)
                        Text(verbatim: "https://\(valid ? draft.finalAddress : "mysite.test")")
                            .fontWeight(.medium)
                            .opacity(valid ? 1 : 0.5)
                    }
                    GridRow {
                        Text("Files in").foregroundStyle(Theme.secondaryText)
                        Text(draft.folder?.displayPath ?? String(localized: "The folder you choose"))
                            .opacity(draft.folder == nil ? 0.5 : 1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.system(size: 12.5))

                if !model.snapshot.certificateAuthorityInstalled {
                    FirstCertificateNote()
                }

                HStack(spacing: 14) {
                    Button("Create Site", action: create)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!valid || draft.folder == nil || model.isBusy)
                    Text("Addresses ending in .test only exist on your Mac, so they never clash with real websites.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: 470, alignment: .leading)
            .padding(40)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func create() {
        model.add = draft
        if draft.isReal {
            // A real address needs the warning and an explicit confirmation, which live in the sheet.
            model.sheet = .add
        } else {
            model.submitAdd()
        }
    }
}

struct NotInstalledView: View {
    @Environment(AppModel.self) private var model
    var homebrewMissing: Bool
    @State private var copied = false

    private let command = "brew install joeworkman/patchy/patchy"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RackLogo(size: 52)
                Text("Patchy isn’t on this Mac yet")
                    .font(.system(size: 22, weight: .semibold))
                Text("Patchy UI runs on Patchy, a free tool by Joe Workman. You install it once with Homebrew, and this app takes care of the rest.")
                    .foregroundStyle(Theme.bodyText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    if homebrewMissing {
                        step(1, "Install Homebrew first. It’s the free installer Patchy comes through.") {
                            Link("Get Homebrew at brew.sh", destination: URL(string: "https://brew.sh")!)
                                .foregroundStyle(Theme.link)
                        }
                    }
                    step(homebrewMissing ? 2 : 1, "Open Terminal. It’s in Applications › Utilities.") {
                        Button("Open Terminal") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
                        }
                        .controlSize(.small)
                    }
                    step(homebrewMissing ? 3 : 2, "Paste this command and press Return:") {
                        HStack(spacing: 8) {
                            Text(command)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(copied ? "Copied" : "Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(command, forType: .string)
                                copied = true
                            }
                            .controlSize(.small)
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                        .padding(.vertical, 8)
                        .background(Theme.wellBackground, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.sheetCardBorder, lineWidth: 0.5))
                    }
                    step(homebrewMissing ? 4 : 3, "When it finishes, come back and click Check Again.") { EmptyView() }
                }

                HStack(spacing: 16) {
                    Button {
                        model.checkAgain()
                    } label: {
                        HStack(spacing: 8) {
                            if model.recheckInProgress { ProgressView().controlSize(.small) }
                            Text(model.recheckInProgress ? "Checking your Mac…" : "Check Again")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.recheckInProgress)

                    if !homebrewMissing {
                        Link("No Homebrew yet? Get it here", destination: URL(string: "https://brew.sh")!)
                            .foregroundStyle(Theme.link)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: 480, alignment: .leading)
            .padding(40)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func step<Extra: View>(_ number: Int, _ text: LocalizedStringKey, @ViewBuilder extra: () -> Extra) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 18, alignment: .trailing)
            VStack(alignment: .leading, spacing: 8) {
                Text(text).fixedSize(horizontal: false, vertical: true)
                extra()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
