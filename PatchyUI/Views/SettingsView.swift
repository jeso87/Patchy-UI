import AppKit
import PatchyKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            PHPSettings()
                .tabItem { Label("PHP", systemImage: "chevron.left.forwardslash.chevron.right") }
            CertificateSettings()
                .tabItem { Label("Certificates", systemImage: "lock") }
            TrustSettings()
                .tabItem { Label("Password-Free", systemImage: "key") }
        }
        .frame(width: 500)
    }
}

private struct SettingsNote: View {
    private let text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(verbatim string: String) { text = Text(verbatim: string) }

    var body: some View {
        text
            .font(.system(size: 12))
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct BusyRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let busy = model.busy {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(busy.text).foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @AppStorage(AppDelegate.showDockIconKey) private var showDockIcon = true
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Toggle("Open Patchy UI when I log in", isOn: $openAtLogin)
                .onChange(of: openAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                    } catch {
                        loginError = String(localized: "macOS didn’t allow that: \(error.localizedDescription)", comment: "Shown when turning Open at Login on or off fails. The placeholder is macOS’s own reason.")
                        openAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if let loginError { SettingsNote(verbatim: loginError) }

            Toggle("Show Patchy UI in the Dock", isOn: $showDockIcon)
                .onChange(of: showDockIcon) { AppDelegate.applyDockIconPreference() }
            SettingsNote("The menu bar item stays either way. With the Dock icon off, open the window from the menu bar item.")

            Section {
                Button("Check for Updates…") { model.updater.checkForUpdates() }
            }
        }
        .formStyle(.grouped)
    }
}

struct PHPSettings: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false

    private let installCommand = "brew install php@8.3"

    var body: some View {
        let installed = model.snapshot.installedPHP
        Form {
            Section {
                if installed.isEmpty {
                    Text("Patchy UI couldn’t find PHP on this Mac.")
                } else {
                    Picker("Version", selection: Binding(
                        get: { model.snapshot.activePHP ?? "" },
                        set: { model.switchPHP(to: $0) })) {
                        ForEach(installed) { php in
                            Text("PHP \(php.version)  (\(php.fullVersion))").tag(php.version)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .disabled(model.isBusy || model.phase != .ready)
                }
                BusyRow()
                SettingsNote("Every site runs on the same PHP version. Switching takes up to half a minute and restarts the server.")
            }
            Section("More versions") {
                SettingsNote(installed.count <= 1
                    ? "Only one PHP version is installed. You can add others with Homebrew; they show up here when they’re ready. For example, in Terminal:"
                    : "You can add other versions with Homebrew; they show up here when they’re ready. For example, in Terminal:")
                HStack {
                    Text(installCommand)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button(copied ? "Copied" : "Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(installCommand, forType: .string)
                        copied = true
                    }
                    .controlSize(.small)
                }
                // A command to paste reads left to right in every language.
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .formStyle(.grouped)
    }
}

struct CertificateSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let needing = model.sites.filter { model.status(of: $0).certificateNeedsRefresh }
        Form {
            Section {
                HStack(alignment: .top, spacing: 9) {
                    Glyph(severity: model.sites.isEmpty ? .off : needing.isEmpty ? .ok : .warning)
                    VStack(alignment: .leading, spacing: 2) {
                        if model.sites.isEmpty {
                            Text("No sites yet").fontWeight(.medium)
                        } else if needing.isEmpty {
                            Text("Every site has a healthy certificate").fontWeight(.medium)
                        } else {
                            Text(Phrases.sitesNeedNewCertificate(needing.count)).fontWeight(.medium)
                            SettingsNote(verbatim: Phrases.certificateList(needing.map(\.address)))
                        }
                    }
                }
                Button("Refresh Certificates…") { model.askRefreshCertificates() }
                    .disabled(model.isBusy || model.sites.isEmpty || model.phase != .ready)
                BusyRow()
                SettingsNote("A certificate is what lets https:// work without a browser warning. They last a little over two years. Refreshing makes new ones for every site at once and asks for your Mac password.")
            }
        }
        .formStyle(.grouped)
    }
}

struct TrustSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 9) {
                    Glyph(severity: model.trustEnabled ? .ok : .warning)
                    VStack(alignment: .leading, spacing: 2) {
                        switch model.snapshot.trust {
                        case .enabled:
                            Text("Password-free mode is on").fontWeight(.medium)
                            SettingsNote("Patchy updates where your addresses point without asking for your Mac password. That is the only thing it can do on its own.")
                        case .outdated:
                            Text("Password-free mode needs refreshing").fontWeight(.medium)
                            SettingsNote("Patchy was updated. Refresh this once and the password prompts stop again.")
                        case .notInstalled:
                            Text("Password-free mode is off").fontWeight(.medium)
                            SettingsNote("macOS asks for your Mac password every time you start or stop the server, or add or remove a site.")
                        }
                    }
                }
                if !model.trustEnabled {
                    Button(model.trustIsUpdate ? "Update…" : "Set Up…") { model.openTrustSetup() }
                        .disabled(model.isBusy || model.phase != .ready)
                }
            }
        }
        .formStyle(.grouped)
    }
}
