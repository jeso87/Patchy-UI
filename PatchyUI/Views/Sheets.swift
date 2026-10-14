import AppKit
import PatchyKit
import SwiftUI

enum FolderPicker {
    /// The standard folder chooser. New folders can be made from inside it.
    @MainActor static func choose(startingAt start: URL? = nil, prompt: String = "Choose") -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        panel.message = "Choose the folder that holds this site’s files."
        panel.directoryURL = start
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// One sheet at a time. A password request takes over whatever is showing until it is answered.
struct SheetHost: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.passwordPrompt != nil {
                PasswordSheet()
            } else {
                switch model.sheet {
                case .add: AddSiteSheet()
                case .remove(let address): RemoveSheet(address: address)
                case .folder(let address): FolderSheet(address: address)
                case .trust: TrustSheet()
                case .refreshCertificates: RefreshCertificatesSheet()
                case .error(let info): ErrorSheet(info: info)
                case nil: EmptyView()
                }
            }
        }
        .padding(20)
        .frame(width: width)
        .interactiveDismissDisabled(model.isBusy)
    }

    private var width: CGFloat {
        if model.passwordPrompt != nil { return 420 }
        switch model.sheet {
        case .remove: return 380
        case .trust, .folder, .refreshCertificates: return 420
        default: return 500
        }
    }
}

struct SheetTitle: View {
    var title: String
    var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 15, weight: .semibold))
            if let message {
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.bodyText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Add Site

/// The large address field: a bare name gets `.test` shown after it.
struct AddressField: View {
    @Binding var name: String
    var suffix: String
    var hasError: Bool
    var fontSize: CGFloat = 22
    var height: CGFloat = 48
    var emphasized = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            TextField("mysite", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: fontSize, weight: .medium))
                .focused($focused)
                .autocorrectionDisabled()
                .accessibilityLabel("Address")
            Text(suffix)
                .font(.system(size: fontSize))
                .foregroundStyle(Theme.grey)
        }
        .padding(.horizontal, 14)
        .frame(height: height)
        .background(Theme.fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(hasError ? Theme.red : (emphasized || focused ? Theme.accent : Theme.fieldBorder), lineWidth: 1))
        .background {
            if emphasized {
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Theme.focusRing).padding(-3)
            }
        }
        .onAppear { focused = true }
    }
}

/// The folder as a card. A folder always has to be chosen; the app never picks one.
struct FolderCard: View {
    @Binding var folder: URL?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Files live in")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                if let folder {
                    Text(folder.lastPathComponent)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(folder.displayPath)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .help(folder.displayPath)
                } else {
                    Text("No folder chosen yet")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.secondaryText)
                    Text("Choose the folder that holds this site’s files, or make a new one.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(folder == nil ? "Choose Folder…" : "Change…") {
                if let chosen = FolderPicker.choose(startingAt: folder) { folder = chosen }
            }
        }
        .padding(14)
        .background(Theme.dashedCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Theme.fieldBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
    }
}

struct AddSiteSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.add.phase {
        case .form: form
        case .progress: progress
        case .error: failure
        }
    }

    @ViewBuilder private var form: some View {
        @Bindable var model = model
        let draft = model.add
        let problem = draft.problemText(existing: model.addresses)
        let valid = draft.isValidAddress(existing: model.addresses)

        Text("New Site")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.link)

        VStack(alignment: .leading, spacing: 8) {
            AddressField(name: $model.add.name, suffix: draft.suffix, hasError: problem != nil)
            Text(problem ?? "Type a name and Patchy adds .test. Or type a full address, like mysite.local.")
                .font(.system(size: 12))
                .foregroundStyle(problem == nil ? Theme.secondaryText : Theme.redText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: model.add.name) { model.add.confirmedReal = false }

        FolderCard(folder: $model.add.folder)

        if !model.sortedGroups.isEmpty {
            Picker("Group", selection: $model.add.groupID) {
                Text("No Group").tag(UUID?.none)
                ForEach(model.sortedGroups) { group in
                    Text(group.name).tag(UUID?.some(group.id))
                }
            }
            .fixedSize()
        }

        if valid, draft.offersWWW {
            Toggle(isOn: $model.add.includeWWW) { Text(verbatim: "Also answer at www.\(draft.finalAddress)") }
                .toggleStyle(.checkbox)
        }

        if valid, draft.isReal {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Glyph(severity: .warning)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "\(draft.finalAddress) might be a real website.").fontWeight(.semibold)
                        Text("While the server runs, this Mac shows your local copy and can’t reach the live site. Everyone else still sees the real one.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Toggle("I understand. Use this address.", isOn: $model.add.confirmedReal)
                    .toggleStyle(.checkbox)
                    .padding(.leading, 26)
            }
            .font(.system(size: 12.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.warningBox, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.warningBoxBorder, lineWidth: 0.5))
        }

        if !model.snapshot.certificateAuthorityInstalled {
            FirstCertificateNote()
        }

        HStack(spacing: 8) {
            Text(valid ? "Opens at https://\(draft.finalAddress)" : "Opens at https://mysite.test")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .opacity(valid ? 1 : 0.5)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Cancel", role: .cancel) { model.closeSheet() }
                .keyboardShortcut(.cancelAction)
            Button("Add Site") { model.submitAdd() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.canSubmit(existing: model.addresses) || model.isBusy)
        }
        .controlSize(.large)
    }

    @ViewBuilder private var progress: some View {
        let steps = model.busy?.steps ?? model.add.steps
        let current = model.busy?.index ?? steps.count
        SheetTitle(title: "Adding \(model.add.finalAddress)", message: "This takes a few seconds.")
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 10) {
                    if index == current {
                        ProgressView().controlSize(.small).scaleEffect(0.8).frame(width: 14, height: 14)
                    } else if index < current {
                        Glyph(severity: .ok, size: 14)
                    } else {
                        Circle().strokeBorder(Theme.grey, lineWidth: 1.5).frame(width: 14, height: 14)
                    }
                    Text(step)
                        .foregroundStyle(index <= current ? Color.primary : Theme.secondaryText)
                }
            }
        }
    }

    @ViewBuilder private var failure: some View {
        HStack(alignment: .top, spacing: 12) {
            Glyph(severity: .error, size: 22)
            SheetTitle(title: "Couldn’t add \(model.add.finalAddress)", message: model.add.errorMessage)
        }
        DetailsDisclosure(details: model.add.errorDetails)
        HStack(spacing: 8) {
            Spacer()
            Button("Close") { model.add.phase = .form; model.closeSheet() }
                .keyboardShortcut(.cancelAction)
            Button("Edit and Try Again") { model.add.phase = .form }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
    }
}

struct FirstCertificateNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Glyph(severity: .info)
            Text("Since this is your first site, macOS will ask for your Mac password once while Patchy sets up secure connections. That’s expected.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.bodyText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Patchy's exact output, available but never shown by default.
struct DetailsDisclosure: View {
    var details: String
    @State private var expanded = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(expanded ? "Hide Details" : "Show Details") { expanded.toggle() }
                .buttonStyle(.patchyLink)
                .font(.system(size: 12))
            if expanded {
                ScrollView {
                    Text(details.isEmpty ? "Patchy didn’t report anything." : details)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .frame(maxHeight: 200)
                .background(Theme.fieldBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.sheetCardBorder, lineWidth: 0.5))
                Button(copied ? "Copied" : "Copy Details") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(details, forType: .string)
                    copied = true
                }
                .buttonStyle(.patchyLink)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: - Remove, folder, certificates

struct RemoveSheet: View {
    @Environment(AppModel.self) private var model
    var address: String

    var body: some View {
        let site = model.sites.first { $0.address == address }
        VStack(alignment: .leading, spacing: 8) {
            SheetTitle(title: "Remove \(address)?",
                       message: "The address will stop working on this Mac. The folder and everything in it stay right where they are.")
            if AddressRules.isRealAddress(address) {
                Text(verbatim: "\(address) will reach the live website again.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.bodyText)
            }
            if let site {
                Text(site.displayFolder)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        HStack(spacing: 8) {
            Spacer()
            Button("Cancel", role: .cancel) { model.closeSheet() }
                .keyboardShortcut(.cancelAction)
            Button("Remove Site", role: .destructive) { model.confirmRemove(address) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.red)
        }
        .controlSize(.large)
    }
}

struct FolderSheet: View {
    @Environment(AppModel.self) private var model
    var address: String

    var body: some View {
        let site = model.sites.first { $0.address == address }
        let draft = model.folderDraft
        let isSame = draft?.path == site?.folder
        SheetTitle(title: "Change folder for \(address)",
                   message: "The address stays the same. Patchy serves files from the new folder instead. Nothing is moved or deleted.")
        Card(background: Theme.sheetCard, border: Theme.sheetCardBorder) {
            HStack(alignment: .top, spacing: 12) {
                Text("Current").foregroundStyle(Theme.secondaryText).frame(width: 70, alignment: .leading)
                Text(site?.displayFolder ?? "")
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            Divider()
            HStack(alignment: .center, spacing: 12) {
                Text("New").foregroundStyle(Theme.secondaryText).frame(width: 70, alignment: .leading)
                Text(draft?.displayPath ?? "No folder chosen yet")
                    .fontWeight(draft == nil ? .regular : .medium)
                    .opacity(draft == nil ? 0.55 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Choose…") {
                    let start = draft ?? site.flatMap { $0.folderExists ? URL(fileURLWithPath: $0.folder) : nil }
                    if let chosen = FolderPicker.choose(startingAt: start) { model.folderDraft = chosen }
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        if isSame {
            Text("That’s the folder this site already uses.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.bodyText)
        } else if site?.folderExists == false {
            Text("The current folder is missing, so pointing the site at the right one fixes it.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.bodyText)
                .fixedSize(horizontal: false, vertical: true)
        }
        HStack(spacing: 8) {
            Spacer()
            Button("Cancel", role: .cancel) { model.closeSheet() }
                .keyboardShortcut(.cancelAction)
            Button("Use This Folder") {
                if let draft { model.saveFolder(for: address, path: draft.path) }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(draft == nil || isSame || model.isBusy)
        }
        .controlSize(.large)
    }
}

struct RefreshCertificatesSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SheetTitle(title: Phrases.refreshCertificatesTitle(siteCount: model.sites.count),
                   message: "Patchy makes a new certificate for every site at once, so https:// keeps working without browser warnings. This can take up to a minute.")
        VStack(alignment: .leading, spacing: 8) {
            bullet("macOS will ask for your Mac password.")
            if model.serverRunning { bullet("The server restarts when it’s done.") }
            bullet("If a browser still shows a warning afterwards, quit and reopen it.")
        }
        .font(.system(size: 12.5))
        HStack(spacing: 8) {
            Spacer()
            Button("Cancel", role: .cancel) { model.closeSheet() }
                .keyboardShortcut(.cancelAction)
            Button("Refresh Certificates") { model.refreshCertificates() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("•").foregroundStyle(Theme.secondaryText)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Passwords

struct TrustSheet: View {
    @Environment(AppModel.self) private var model
    @State private var password = ""
    @FocusState private var passwordFocused: Bool

    var body: some View {
        switch model.trustStep {
        case .explain: explain
        case .password: passwordStep
        case .working, .done: working
        }
    }

    @ViewBuilder private var explain: some View {
        SheetTitle(title: model.trustIsUpdate ? "Refresh password-free mode" : "Skip the password prompts",
                   message: model.trustIsUpdate
                       ? "Patchy was updated, so its permission to update your addresses needs to be refreshed once. Until then, macOS asks for your Mac password on every change."
                       : "Starting and stopping the server, and adding or removing sites, all tell your Mac where each address lives. Normally macOS asks for your Mac password every time.")
        Card(background: Theme.sheetCard, border: Theme.sheetCardBorder) {
            VStack(alignment: .leading, spacing: 8) {
                check("Patchy can update your addresses without asking each time.")
                check("That’s the only thing it’s allowed to do on its own.")
                check("You enter your Mac password once, now.")
            }
            .font(.system(size: 12.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        HStack(spacing: 8) {
            Spacer()
            Button("Not Now") { model.dismissTrust() }
                .keyboardShortcut(.cancelAction)
            Button(model.trustIsUpdate ? "Update…" : "Set Up…") {
                password = ""
                model.trustStep = .password
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
    }

    private func check(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.green)
                .padding(.top, 2)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var passwordStep: some View {
        SheetTitle(title: "Enter your Mac password",
                   message: "The one you use to log in to this Mac. Patchy passes it straight to macOS and doesn’t keep it.")
        SecureField("Mac password", text: $password)
            .textFieldStyle(.roundedBorder)
            .controlSize(.large)
            .focused($passwordFocused)
            .onSubmit(submit)
            .onAppear { passwordFocused = true }
            .accessibilityLabel("Mac password")
        if let error = model.trustError {
            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(Theme.redText)
                .fixedSize(horizontal: false, vertical: true)
        }
        HStack(spacing: 8) {
            Spacer()
            Button("Back") {
                model.trustError = nil
                model.trustStep = .explain
            }
            .keyboardShortcut(.cancelAction)
            Button("Set Up", action: submit)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
        }
        .controlSize(.large)
    }

    private func submit() {
        guard !password.isEmpty else { return }
        let entered = password
        password = ""
        model.submitTrustPassword(entered)
    }

    private var working: some View {
        HStack(spacing: 12) {
            if model.trustStep == .done {
                Glyph(severity: .ok, size: 14)
            } else {
                ProgressView().controlSize(.small)
            }
            Text(model.trustStep == .done
                 ? (model.trustHasPendingAction ? "Password-free mode is on. Continuing…" : "Password-free mode is on.")
                 : "Setting up password-free mode…")
        }
        .padding(.vertical, 8)
    }
}

/// Shown when a running task needs the Mac password (making or refreshing certificates).
struct PasswordSheet: View {
    @Environment(AppModel.self) private var model
    @State private var password = ""
    @FocusState private var focused: Bool

    var body: some View {
        let prompt = model.passwordPrompt
        SheetTitle(title: "Enter your Mac password",
                   message: "macOS needs it to finish this change. It’s the one you use to log in to this Mac. Patchy passes it straight to macOS and doesn’t keep it.")
        SecureField("Mac password", text: $password)
            .textFieldStyle(.roundedBorder)
            .controlSize(.large)
            .focused($focused)
            .onSubmit(submit)
            .onAppear { focused = true }
            .disabled(prompt?.checking == true)
            .accessibilityLabel("Mac password")
        if let error = prompt?.error {
            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(Theme.redText)
                .fixedSize(horizontal: false, vertical: true)
        }
        HStack(spacing: 8) {
            if prompt?.checking == true { ProgressView().controlSize(.small) }
            Spacer()
            Button("Cancel", role: .cancel) { model.cancelPasswordPrompt() }
                .keyboardShortcut(.cancelAction)
            Button("Continue", action: submit)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty || prompt?.checking == true)
        }
        .controlSize(.large)
    }

    private func submit() {
        guard !password.isEmpty else { return }
        let entered = password
        password = ""
        model.submitPassword(entered)
    }
}

// MARK: - Errors

struct ErrorSheet: View {
    @Environment(AppModel.self) private var model
    var info: ErrorInfo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Glyph(severity: .error, size: 22)
            SheetTitle(title: info.title, message: info.message)
        }
        DetailsDisclosure(details: info.details)
        HStack(spacing: 8) {
            Spacer()
            Button("Close") { model.closeSheet() }
                .keyboardShortcut(.cancelAction)
            switch info.recovery {
            case .none:
                EmptyView()
            case .stopThenStart:
                Button("Stop, Then Start") { model.stopThenStart() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            case .startServer:
                Button("Start Server") {
                    model.closeSheet()
                    model.start()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
    }
}
