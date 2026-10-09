import AppKit
import PatchyKit
import SwiftUI

@main
struct PatchyUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    init() {
        // `Patchy UI --dump-state` prints what the app reads from this Mac, then exits.
        if CommandLine.arguments.contains("--dump-state") {
            Self.dumpState()
            exit(0)
        }
    }

    var body: some Scene {
        Window("Patchy", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 540)
        }
        .defaultSize(width: 1060, height: 720)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { model.updater.checkForUpdates() }
            }
            CommandGroup(replacing: .newItem) {
                Button("Add Site…") { model.openAdd() }
                    .keyboardShortcut("n")
            }
            CommandMenu("Server") {
                if model.serverRunning {
                    Button(model.unroutedCount > 0 ? "Repair" : "Restart Server") { model.restart() }
                        .keyboardShortcut("r")
                    Button("Stop Server") { model.stop() }
                } else {
                    Button("Start Server") { model.start() }
                        .keyboardShortcut("r")
                }
                Divider()
                Button("Refresh Certificates…") { model.askRefreshCertificates() }
            }
        }

        MenuBarExtra {
            MenuBarContent()
                .environment(model)
        } label: {
            MenuBarLabel()
                .environment(model)
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }

    private static func dumpState() {
        switch PatchyEnvironment.detect() {
        case .missingHomebrew: print("Homebrew not found")
        case .missingPatchy: print("Patchy not found")
        case .ready(let environment):
            let snapshot = PatchyClient(environment: environment).snapshot()
            print("patchy \(snapshot.patchyVersion ?? "?") at \(environment.brewPrefix.path)")
            print("server running: \(snapshot.serverRunning)")
            print("php: active \(snapshot.activePHP ?? "?"), installed \(snapshot.installedPHP.map(\.fullVersion))")
            print("trust: \(snapshot.trust)")
            print("certificate authority installed: \(snapshot.certificateAuthorityInstalled)")
            print("sites: \(snapshot.sites.count)")
            for site in snapshot.sites {
                let status = SiteStatus(site: site, serverRunning: snapshot.serverRunning)
                print("  \(site.address)  aliases=\(site.aliases)  routed=\(site.isRouted)  folderExists=\(site.folderExists)  \(status.summary)  \(site.displayFolder)")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let showDockIconKey = "showDockIcon"

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.showDockIconKey: true])
        Self.applyDockIconPreference()
    }

    /// Closing the window leaves the menu bar item running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    static func applyDockIconPreference() {
        let show = UserDefaults.standard.bool(forKey: showDockIconKey)
        NSApp.setActivationPolicy(show ? .regular : .accessory)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            switch model.phase {
            case .checking:
                ProgressView("Checking your Mac…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .notInstalled(let homebrewMissing):
                NotInstalledView(homebrewMissing: homebrewMissing)
            case .ready:
                MainView()
            }
        }
        .sheet(isPresented: sheetIsPresented) {
            SheetHost()
                .environment(model)
        }
        .onAppear {
            model.connectWindowOpener(openWindow)
            model.launch()
        }
    }

    private var sheetIsPresented: Binding<Bool> {
        Binding(
            get: { model.sheet != nil || model.passwordPrompt != nil },
            set: { presented in
                guard !presented else { return }
                if model.passwordPrompt != nil { model.cancelPasswordPrompt() }
                model.closeSheet()
            })
    }
}

extension AppModel {
    func connectWindowOpener(_ openWindow: OpenWindowAction) {
        openMainWindow = {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
