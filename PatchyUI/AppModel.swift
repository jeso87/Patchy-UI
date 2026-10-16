import AppKit
import Observation
import PatchyKit

enum DetailTab: String, CaseIterable, Identifiable {
    case overview, errors, visits

    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: String(localized: "Overview", comment: "Tab in a site's details.")
        case .errors: String(localized: "Errors", comment: "Tab in a site's details showing its error log.")
        case .visits: String(localized: "Visits", comment: "Tab in a site's details showing its access log.")
        }
    }
}

struct Busy: Equatable {
    var steps: [String]
    var index = 0

    var text: String { steps[min(index, steps.count - 1)] }
}

struct Banner: Equatable {
    var severity: Severity
    var text: String
    /// Address to offer "Open in Browser" for.
    var openAddress: String?
}

struct ErrorInfo: Equatable {
    enum Recovery: Equatable {
        case none, stopThenStart, startServer
    }

    var title: String
    var message: String
    var details: String
    var recovery: Recovery = .none
}

enum PendingAction: Equatable {
    case start, stop, restart, add
    case remove(String)
    case folder(address: String, path: String)
    case php(String)
}

enum Sheet: Equatable {
    case add
    case remove(String)
    case folder(String)
    case trust
    case refreshCertificates
    case error(ErrorInfo)
    case installCloudflared(String, mode: ShareMode)
}

enum TrustStep: Equatable {
    case explain, password, working, done
}

/// What the group-name dialog is for.
enum GroupNamePrompt: Equatable {
    /// A new group, optionally starting with one site in it.
    case new(assigning: String?)
    case rename(UUID)
}

struct PasswordPrompt: Equatable {
    var error: String?
    var checking = false
}

struct AddDraft: Equatable {
    enum Phase: Equatable {
        case form, progress, error
    }

    var name = ""
    var folder: URL?
    /// The group the new site joins, if any.
    var groupID: UUID?
    var includeWWW = true
    var confirmedReal = false
    var phase: Phase = .form
    var steps: [String] = []
    var failedIndex = 0
    var errorMessage = ""
    var errorDetails = ""

    var finalAddress: String { AddressRules.finalAddress(from: name) }
    var suffix: String { AddressRules.usesDefaultSuffix(name) ? ".test" : "" }

    func problemText(existing: [String]) -> String? {
        switch AddressRules.problem(with: name, existing: existing) {
        case .invalidCharacters: String(localized: "Use only letters, numbers, hyphens (-), and dots (.).")
        case .unfinished: String(localized: "That address looks unfinished. It can’t start or end with a dot or hyphen.")
        case .alreadyExists(let address): String(localized: "\(address) already exists. Pick a different address.")
        case nil: nil
        }
    }

    func isValidAddress(existing: [String]) -> Bool {
        !finalAddress.isEmpty && problemText(existing: existing) == nil
    }

    var isReal: Bool { AddressRules.isRealAddress(finalAddress) }
    var offersWWW: Bool { AddressRules.offersWWW(finalAddress) }

    func canSubmit(existing: [String]) -> Bool {
        isValidAddress(existing: existing) && folder != nil && (!isReal || confirmedReal)
    }
}

@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case checking
        case notInstalled(homebrewMissing: Bool)
        case ready
    }

    var phase: Phase = .checking
    var snapshot = PatchySnapshot()
    var selection: String?
    var filter = ""
    var tab: DetailTab = .overview
    var busy: Busy?
    var sheet: Sheet?
    var banner: Banner?
    var add = AddDraft()
    var folderDraft: URL?
    var trustStep: TrustStep = .explain
    var trustError: String?
    var passwordPrompt: PasswordPrompt?
    var recheckInProgress = false

    /// Sites being shared, by address. A failed share stays until it's dismissed.
    var shares: [String: ShareState] = [:]
    /// Shares asked to stop that haven't finished stopping.
    var stoppingShares: Set<String> = []
    @ObservationIgnored private var shareSessions: [String: ShareSession] = [:]
    /// Whether the previous read found the server stopped; see `sharesToStop`.
    @ObservationIgnored private var serverSeenDown = false

    var compatibilityDismissed = false

    /// Sidebar groups. They live only in this app; Patchy knows nothing about them.
    var groups = SiteGroups() {
        didSet { if groups != oldValue, !groupSavingDisabled { groupStore.save(groups) } }
    }
    /// Debug layouts try out groups without writing them to the real file.
    @ObservationIgnored private var groupSavingDisabled = false
    /// What the name dialog will do when confirmed. Kept apart from `groupNameDialogShown`
    /// because SwiftUI closes an alert before it runs the button that was clicked; if closing
    /// cleared this, the button would find nothing to do.
    @ObservationIgnored private var groupNamePrompt: GroupNamePrompt?
    var groupNameDialogShown = false
    var groupNameDialogIsRename = false
    var groupNameDraft = ""
    @ObservationIgnored private let groupStore = SiteGroupStore.standard

    /// Created on first use so `--dump-state` never starts Sparkle.
    @ObservationIgnored lazy var updater = AppUpdater()

    /// Set by the app so the model can bring the main window forward when it needs the user.
    @ObservationIgnored var openMainWindow: (() -> Void)?

    @ObservationIgnored private var client: PatchyClient?
    @ObservationIgnored private var pendingAction: PendingAction?
    /// Set when someone picks Not Now: for the rest of this session, changes go ahead and macOS
    /// asks for the Mac password instead of the app offering password-free mode each time.
    @ObservationIgnored private var trustDeclined = false
    @ObservationIgnored private var sessionPassword: String?
    @ObservationIgnored private var passwordContinuation: CheckedContinuation<String?, Never>?
    @ObservationIgnored private var taskOutput = ""
    @ObservationIgnored private var markers: [(text: String, step: Int)] = []
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    /// How far the most recent task's steps got, for showing where a failure happened.
    @ObservationIgnored private var lastTaskIndex = 0
    #if DEBUG
    @ObservationIgnored fileprivate var pauseRefreshForDebug = false
    #endif

    // MARK: Derived state

    var sites: [Site] { snapshot.sites }
    var serverRunning: Bool { snapshot.serverRunning }
    var isBusy: Bool { busy != nil }
    var trustEnabled: Bool { snapshot.trust == .enabled }
    var selectedSite: Site? { sites.first { $0.address == selection } }
    var addresses: [String] { sites.map(\.address) }

    var isFiltering: Bool { !filter.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Sites matching the filter by address, folder, or the name of their group.
    var visibleSites: [Site] {
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return sites }
        return sites.filter {
            $0.address.contains(query) || $0.folder.lowercased().contains(query)
                || (groups.group(of: $0.address)?.name.lowercased().contains(query) ?? false)
        }
    }

    func site(_ address: String) -> Site? { sites.first { $0.address == address } }

    // MARK: Groups

    var sidebarSections: SiteGroups.Sections { groups.sections(for: visibleSites.map(\.address)) }
    var sortedGroups: [SiteGroup] { groups.sections(for: []).groups.map(\.group) }
    var groupSuggestion: SiteGroups.Suggestion? { groups.suggestions(for: addresses).first }

    func moveSite(_ address: String, to groupID: UUID?) {
        groups.assign(address, to: groupID)
    }

    /// Sites dragged onto a group, or onto Other Sites when `groupID` is nil. Anything that isn't
    /// a site's address (text dragged in from another app) is ignored.
    @discardableResult
    func dropSites(_ addresses: [String], on groupID: UUID?) -> Bool {
        let moving = addresses.filter { site($0) != nil && groups.group(of: $0)?.id != groupID }
        moving.forEach { moveSite($0, to: groupID) }
        return !moving.isEmpty
    }

    func promptNewGroup(assigning address: String? = nil) {
        showGroupNameDialog(.new(assigning: address), draft: "")
    }

    func promptRenameGroup(_ group: SiteGroup) {
        showGroupNameDialog(.rename(group.id), draft: group.name)
    }

    private func showGroupNameDialog(_ prompt: GroupNamePrompt, draft: String) {
        groupNamePrompt = prompt
        groupNameDraft = draft
        if case .rename = prompt { groupNameDialogIsRename = true } else { groupNameDialogIsRename = false }
        // Shown a moment after the draft is set; an alert's text field ignores text set in the
        // same update that presents it, and a rename would open with an empty field.
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            groupNameDialogShown = true
        }
    }

    func commitGroupName() {
        let trimmed = groupNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupName = trimmed.isEmpty ? String(localized: "Untitled Group", comment: "Name given to a sidebar group left unnamed.") : trimmed
        switch groupNamePrompt {
        case .new(let address):
            groups.createGroup(named: groupName, sites: address.map { [$0] } ?? [])
        case .rename(let id):
            groups.rename(id, to: groupName)
        case nil:
            break
        }
        groupNamePrompt = nil
    }

    func cancelGroupName() {
        groupNamePrompt = nil
    }

    func deleteGroup(_ group: SiteGroup) {
        groups.delete(group.id)
    }

    func setGroup(_ group: SiteGroup, expanded: Bool) {
        groups.setCollapsed(!expanded, for: group.id)
    }

    func applyGroupSuggestion(_ suggestion: SiteGroups.Suggestion) {
        groups.createGroup(named: suggestion.name, sites: suggestion.sites)
    }

    func dismissGroupSuggestion(_ suggestion: SiteGroups.Suggestion) {
        groups.dismiss(suggestion)
    }

    func status(of site: Site) -> SiteStatus {
        SiteStatus(site: site, serverRunning: serverRunning)
    }

    var unroutedCount: Int { serverRunning ? sites.filter { !$0.isRouted }.count : 0 }
    var problemSites: [Site] { sites.filter { status(of: $0).hasProblem } }
    var phpLabel: String { snapshot.activePHP.map { "PHP \($0)" } ?? "PHP" }

    var serverTitle: String {
        if isBusy { return String(localized: "Working…") }
        if !serverRunning { return String(localized: "Stopped") }
        return unroutedCount > 0 ? String(localized: "Needs repair") : String(localized: "Running")
    }

    var serverPillText: String {
        if let busy { return busy.text }
        if !serverRunning { return String(localized: "Stopped") }
        return unroutedCount > 0 ? String(localized: "Running · needs repair") : String(localized: "Running · \(phpLabel)", comment: "Server status in the toolbar. The placeholder is “PHP 8.4”.")
    }

    var footerText: String {
        guard !sites.isEmpty else { return "" }
        return Phrases.footer(siteCount: sites.count, problems: problemSites.count)
    }

    // MARK: Version match

    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    /// The app's version names the Patchy release it was made for; anything else may misbehave.
    var compatibility: PatchyCompatibility {
        PatchyCompatibility.check(appVersion: Self.appVersion, patchyVersion: snapshot.patchyVersion)
    }

    static let patchyUpgradeCommand = "brew upgrade joeworkman/patchy/patchy"

    func copyPatchyUpgradeCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.patchyUpgradeCommand, forType: .string)
    }

    // MARK: Loading

    /// True inside the unit-test host. The app then stays idle: no polling and no Sparkle.
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil

    func launch() {
        guard pollTask == nil, !Self.isRunningTests else { return }
        _ = updater
        groups = groupStore.load()
        // Links shouldn't outlive the app. Patchy stops cloudflared when asked.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.stopAllSharing() }
        }
        pollTask = Task { [weak self] in
            await self?.detect()
            #if DEBUG
            self?.applyDebugLaunchState()
            #endif
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard let self else { return }
                tick += 1
                if self.phase == .ready, !self.isBusy {
                    await self.refresh(checkTrust: tick % 5 == 0)
                }
            }
        }
    }

    func detect() async {
        switch PatchyEnvironment.detect() {
        case .ready(var environment):
            #if DEBUG
            if let path = UserDefaults.standard.string(forKey: "PatchyDebugPatchyPath") {
                environment.patchyOverride = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            }
            #endif
            client = PatchyClient(environment: environment)
            await refresh(checkTrust: true)
            phase = .ready
        case .missingPatchy:
            client = nil
            phase = .notInstalled(homebrewMissing: false)
        case .missingHomebrew:
            client = nil
            phase = .notInstalled(homebrewMissing: true)
        }
    }

    func checkAgain() {
        guard !recheckInProgress else { return }
        recheckInProgress = true
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await detect()
            recheckInProgress = false
        }
    }

    func refresh(checkTrust: Bool) async {
        guard let client else { return }
        #if DEBUG
        if pauseRefreshForDebug { return }
        #endif
        let previousTrust = snapshot.trust
        let fresh = await Task.detached(priority: .utility) {
            client.snapshot(checkTrust: checkTrust, previousTrust: previousTrust)
        }.value
        if fresh != snapshot { snapshot = fresh }
        let serverWasDown = serverSeenDown
        serverSeenDown = !snapshot.serverRunning
        for address in Self.sharesToStop(Array(shareSessions.keys), snapshot: snapshot, serverWasDown: serverWasDown) {
            stopSharing(address)
        }
        for address in shares.keys where shareSessions[address] == nil && site(address) == nil { shares[address] = nil }
        if selection == nil || !sites.contains(where: { $0.address == selection }) {
            selection = sites.first?.address
        }
    }

    var environment: PatchyEnvironment? { client?.environment }

    // MARK: Running commands

    private typealias CommandBody = @Sendable (PatchyClient, AskpassServer?, @escaping PatchyClient.Output) async -> CommandResult

    /// Runs one changing command at a time, showing its progress and re-reading state when it ends.
    private func runTask(steps: [String], markers: [(text: String, step: Int)] = [], password: String? = nil,
                         _ body: @escaping CommandBody) async -> CommandResult {
        guard let client, busy == nil else { return CommandResult(exitCode: -1, output: "") }
        busy = Busy(steps: steps)
        banner = nil
        taskOutput = ""
        self.markers = markers
        sessionPassword = password

        let askpass = try? AskpassServer { [weak self] _ in
            await self?.passwordForSudo() ?? nil
        }
        let output: PatchyClient.Output = { [weak self] chunk in
            Task { @MainActor in self?.noteOutput(chunk) }
        }
        let result = await body(client, askpass, output)
        // Output arrives through the main actor; let the last progress update land.
        try? await Task.sleep(for: .milliseconds(100))
        lastTaskIndex = busy?.index ?? 0
        askpass?.stop()
        sessionPassword = nil
        if passwordPrompt != nil { cancelPasswordPrompt() }
        await refresh(checkTrust: true)
        busy = nil
        return result
    }

    private func noteOutput(_ chunk: String) {
        taskOutput += chunk
        guard var current = busy else { return }
        for marker in markers where marker.step > current.index && taskOutput.contains(marker.text) {
            current.index = marker.step
        }
        if current != busy { busy = current }
    }

    // MARK: Passwords

    private func passwordForSudo() async -> String? {
        if let sessionPassword { return sessionPassword }
        openMainWindow?()
        return await withCheckedContinuation { continuation in
            passwordContinuation = continuation
            passwordPrompt = PasswordPrompt()
        }
    }

    func submitPassword(_ password: String) {
        guard passwordPrompt != nil, passwordPrompt?.checking == false else { return }
        passwordPrompt?.checking = true
        passwordPrompt?.error = nil
        Task {
            switch await PasswordCheck.validate(password) {
            case .valid:
                sessionPassword = password
                passwordPrompt = nil
                passwordContinuation?.resume(returning: password)
                passwordContinuation = nil
            case .wrong:
                passwordPrompt = PasswordPrompt(error: String(localized: "That doesn’t match your Mac password. Try again.", comment: "Shown under a password field."))
            case .notAllowed:
                passwordPrompt = PasswordPrompt(error: String(localized: "This Mac account isn’t allowed to make this change. Use an administrator account.", comment: "Shown under a password field."))
            }
        }
    }

    func cancelPasswordPrompt() {
        passwordPrompt = nil
        passwordContinuation?.resume(returning: nil)
        passwordContinuation = nil
    }

    // MARK: Password-free mode

    /// Changes that touch routing are offered password-free setup first, as the design asks.
    private func requireTrust(for action: PendingAction) -> Bool {
        if trustEnabled || trustDeclined { return true }
        pendingAction = action
        trustStep = .explain
        trustError = nil
        sheet = .trust
        openMainWindow?()
        return false
    }

    func openTrustSetup() {
        pendingAction = nil
        trustStep = .explain
        trustError = nil
        sheet = .trust
        openMainWindow?()
    }

    var trustIsUpdate: Bool { snapshot.trust == .outdated }
    var trustHasPendingAction: Bool { pendingAction != nil }

    /// Not Now on the offer that came before a change carries on with that change; macOS then
    /// asks for the Mac password.
    func dismissTrust() {
        let pending = pendingAction
        pendingAction = nil
        sheet = pending == .add ? .add : nil
        guard let pending else { return }
        trustDeclined = true
        run(pending)
    }

    func submitTrustPassword(_ password: String) {
        guard trustStep == .password else { return }
        trustStep = .working
        trustError = nil
        Task {
            switch await PasswordCheck.validate(password) {
            case .wrong:
                trustError = String(localized: "That doesn’t match your Mac password. Try again.", comment: "Shown under a password field.")
                trustStep = .password
                return
            case .notAllowed:
                trustError = String(localized: "This Mac account isn’t allowed to set this up. Use an administrator account.", comment: "Shown under a password field.")
                trustStep = .password
                return
            case .valid:
                break
            }
            let result = await runTask(steps: [String(localized: "Setting up password-free mode…", comment: "Progress step shown while a change runs.")], password: password) { client, askpass, output in
                guard let askpass else { return CommandResult(exitCode: -1, output: "Could not prepare the password helper.") }
                return await client.setUpTrust(askpass: askpass, onOutput: output)
            }
            guard trustEnabled else {
                pendingAction = nil
                let message: String
                if result.output.contains(PatchyOutput.trustUnsafe) || result.output.contains(PatchyOutput.trustUnsafeShort) {
                    message = String(localized: "Patchy can’t set this up safely on this Mac, so nothing was changed. You can keep using the app; it will ask for your Mac password when a change needs it.", comment: "Message in an error sheet.")
                } else if result.output.contains(PatchyOutput.terminalRequired) {
                    // sudo wouldn't take the password from the app. Terminal always works.
                    message = String(localized: "Your Mac wouldn’t let the app pass your password along. You can turn on password-free mode yourself instead: open Terminal (in Applications > Utilities), type patchy trust, press Return and enter your Mac password. Then come back here.", comment: "Message in an error sheet.")
                } else {
                    message = String(localized: "Nothing was changed. Show Details has the exact message from Patchy.", comment: "Message in an error sheet.")
                }
                sheet = .error(ErrorInfo(title: String(localized: "Couldn’t set up password-free mode", comment: "Title of an error sheet."), message: message, details: result.output))
                return
            }
            trustStep = .done
            try? await Task.sleep(for: .milliseconds(900))
            let pending = pendingAction
            pendingAction = nil
            sheet = pending == .add ? .add : nil
            if let pending { run(pending) }
        }
    }

    private func run(_ action: PendingAction) {
        switch action {
        case .start: start()
        case .stop: stop()
        case .restart: restart()
        case .add: submitAdd()
        case .remove(let address): confirmRemove(address)
        case .folder(let address, let path): saveFolder(for: address, path: path)
        case .php(let version): switchPHP(to: version)
        }
    }

    // MARK: Server

    func start() {
        guard !isBusy, requireTrust(for: .start) else { return }
        Task {
            let result = await runTask(steps: [String(localized: "Starting the server…", comment: "Progress step shown while a change runs."), String(localized: "Pointing your addresses at this Mac…", comment: "Progress step shown while a change runs.")],
                                       markers: [(PatchyOutput.started, 1)]) { client, askpass, output in
                await client.start(askpass: askpass, onOutput: output)
            }
            if !serverRunning { sheet = .error(Self.startFailure(output: result.output)) }
        }
    }

    func stop() {
        guard !isBusy, requireTrust(for: .stop) else { return }
        let real = sites.filter(\.isRealAddress).map(\.address)
        Task {
            stopAllSharing()
            let result = await runTask(steps: [String(localized: "Stopping the server…", comment: "Progress step shown while a change runs."), String(localized: "Handing addresses back to the internet…", comment: "Progress step shown while a change runs.")],
                                       markers: [(PatchyOutput.stopped, 1)]) { client, askpass, output in
                await client.stop(askpass: askpass, onOutput: output)
            }
            if serverRunning {
                sheet = .error(ErrorInfo(title: String(localized: "The server didn’t stop", comment: "Title of an error sheet."),
                                         message: String(localized: "It’s still running and your sites still open. Try again, or look at Show Details.", comment: "Message in an error sheet."),
                                         details: result.output))
            } else if !real.isEmpty {
                banner = Banner(severity: .info, text: Phrases.liveAgain(real))
            }
        }
    }

    func restart() {
        guard !isBusy, requireTrust(for: .restart) else { return }
        let neededRepair = unroutedCount > 0
        Task {
            let result = await runTask(steps: [String(localized: "Restarting the server…", comment: "Progress step shown while a change runs."), String(localized: "Checking every address points here…", comment: "Progress step shown while a change runs.")],
                                       markers: [(PatchyOutput.started, 1)]) { client, askpass, output in
                await client.restart(askpass: askpass, onOutput: output)
            }
            if !serverRunning {
                sheet = .error(Self.startFailure(output: result.output))
            } else if neededRepair, unroutedCount == 0 {
                banner = Banner(severity: .ok, text: String(localized: "Repaired. Every address points at this Mac again.", comment: "Banner under the toolbar."))
            } else if unroutedCount > 0 {
                sheet = .error(ErrorInfo(title: String(localized: "Some addresses still aren’t pointing at this Mac", comment: "Title of an error sheet."),
                                         message: String(localized: "The server restarted, but it couldn’t update where your addresses point. Try Repair again.", comment: "Message in an error sheet."),
                                         details: result.output))
            }
        }
    }

    func stopThenStart() {
        guard !isBusy else { return }
        sheet = nil
        Task {
            let result = await runTask(steps: [String(localized: "Stopping the server…", comment: "Progress step shown while a change runs."), String(localized: "Starting the server…", comment: "Progress step shown while a change runs.")],
                                       markers: [(PatchyOutput.startingApache, 1)]) { client, askpass, output in
                let stopped = await client.stop(askpass: askpass, onOutput: output)
                let started = await client.start(askpass: askpass, onOutput: output)
                return CommandResult(exitCode: started.exitCode, output: stopped.output + started.output)
            }
            if !serverRunning { sheet = .error(Self.startFailure(output: result.output, offerReset: false)) }
        }
    }

    static func startFailure(output: String, offerReset: Bool = true) -> ErrorInfo {
        if output.contains(PatchyOutput.serviceStuck), offerReset {
            return ErrorInfo(title: String(localized: "The server is stuck", comment: "Title of an error sheet."),
                             message: String(localized: "The background service that runs the server didn’t respond. Stopping and starting it again resets it.", comment: "Message in an error sheet."),
                             details: output, recovery: .stopThenStart)
        }
        if output.contains(PatchyOutput.addressInUse) {
            var holders: [String] = []
            if let range = output.range(of: PatchyOutput.portHolders) {
                for line in output[range.upperBound...].split(whereSeparator: \.isNewline).dropFirst() {
                    guard line.hasPrefix("  "), let name = line.split(whereSeparator: \.isWhitespace).first else { break }
                    if !holders.contains(String(name)) { holders.append(String(name)) }
                }
            }
            return ErrorInfo(title: String(localized: "Another app is using the web ports", comment: "Title of an error sheet."),
                             message: Phrases.portsInUse(holders: holders),
                             details: output)
        }
        return ErrorInfo(title: String(localized: "The server didn’t start", comment: "Title of an error sheet."),
                         message: String(localized: "Your sites won’t open until it’s running. Show Details has the exact message from Patchy.", comment: "Message in an error sheet."),
                         details: output)
    }

    // MARK: Sites

    func openAdd(name: String = "", folder: URL? = nil) {
        guard !isBusy, phase == .ready else { return }
        add = AddDraft(name: name, folder: folder)
        sheet = .add
        openMainWindow?()
    }

    func submitAdd() {
        guard !isBusy, add.canSubmit(existing: addresses), let folder = add.folder else { return }
        guard requireTrust(for: .add) else { return }
        let address = add.finalAddress
        let includeWWW = add.offersWWW && add.includeWWW
        let groupID = add.groupID
        let steps = [String(localized: "Pointing \(address) at this Mac", comment: "Progress step shown while a change runs."), String(localized: "Creating a secure certificate", comment: "Progress step shown while a change runs."), String(localized: "Setting up the site", comment: "Progress step shown while a change runs."),
                     String(localized: "Checking the setup", comment: "Progress step shown while a change runs."), String(localized: "Restarting the server", comment: "Progress step shown while a change runs.")]
        add.steps = steps
        add.phase = .progress
        sheet = .add
        Task {
            let result = await runTask(steps: steps, markers: [
                (PatchyOutput.creatingCertificates, 1), (PatchyOutput.creatingConfig, 2),
                (PatchyOutput.syntaxOK, 3), (PatchyOutput.restartingApache, 4),
            ]) { client, askpass, output in
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "PatchyDebugFakeAdd") {
                    try? await Task.sleep(for: .seconds(3))
                    return CommandResult(exitCode: 0, output: "")
                }
                #endif
                return await client.addSite(address: address, folder: folder.path, includeWWW: includeWWW,
                                            askpass: askpass, onOutput: output)
            }
            let lastIndex = lastTaskIndex
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "PatchyDebugFakeAdd"), var fake = snapshot.sites.first {
                // Pretend the site now exists, so the real success path runs without touching Patchy.
                pauseRefreshForDebug = true
                fake.address = address
                snapshot.sites = (snapshot.sites + [fake]).sorted { $0.address < $1.address }
            }
            #endif
            if sites.contains(where: { $0.address == address }) {
                if let groupID { groups.assign(address, to: groupID) }
                selection = address
                tab = .overview
                filter = ""
                add = AddDraft()
                if serverRunning {
                    sheet = nil
                    banner = Banner(severity: .ok, text: String(localized: "\(address) is ready. Its folder is \(folder.displayPath).", comment: "Banner under the toolbar."), openAddress: address)
                } else {
                    var failure = Self.startFailure(output: result.output)
                    failure.title = String(localized: "\(address) was added, but the server isn’t running", comment: "Title of an error sheet.")
                    sheet = .error(failure)
                }
            } else {
                add.failedIndex = lastIndex
                add.errorDetails = "$ patchy add \(address) \(folder.path)\n" + result.output
                add.errorMessage = Self.addFailureMessage(output: result.output)
                add.phase = .error
                sheet = .add
            }
        }
    }

    static func addFailureMessage(output: String) -> String {
        if output.contains(PatchyOutput.rollingBack) {
            return String(localized: "The setup check found a problem, so Patchy undid every step. Nothing was added and your other sites are fine.")
        }
        if output.contains(PatchyOutput.siteExists) {
            return String(localized: "A site with this address already exists, so nothing was changed.")
        }
        if !output.contains(PatchyOutput.creatingCertificates) {
            return String(localized: "Patchy couldn’t point the address at this Mac, so nothing was created. Your other sites are fine.")
        }
        return String(localized: "Something stopped the setup partway. Your other sites are fine; Show Details has the exact message from Patchy.")
    }

    func askRemove(_ address: String? = nil) {
        guard !isBusy, phase == .ready, let target = address ?? selection else { return }
        sheet = .remove(target)
    }

    func confirmRemove(_ address: String) {
        guard !isBusy, requireTrust(for: .remove(address)) else { return }
        stopSharing(address)
        sheet = nil
        let index = sites.firstIndex { $0.address == address } ?? 0
        Task {
            let result = await runTask(steps: [String(localized: "Removing \(address)…", comment: "Progress step shown while a change runs."), String(localized: "Restarting the server…", comment: "Progress step shown while a change runs.")],
                                       markers: [(PatchyOutput.restartingApache, 1)]) { client, askpass, output in
                await client.removeSites([address], askpass: askpass, onOutput: output)
            }
            if sites.contains(where: { $0.address == address }) {
                sheet = .error(ErrorInfo(title: String(localized: "Couldn’t remove \(address)", comment: "Title of an error sheet."),
                                         message: String(localized: "The site is still set up exactly as it was. Show Details has the exact message from Patchy.", comment: "Message in an error sheet."),
                                         details: result.output))
            } else {
                groups.remove(address)
                selection = sites.isEmpty ? nil : sites[min(index, sites.count - 1)].address
                tab = .overview
                banner = Banner(severity: .ok, text: String(localized: "\(address) was removed. Its folder is still in place.", comment: "Banner under the toolbar."))
            }
        }
    }

    func openFolderEdit() {
        guard !isBusy, let selection else { return }
        folderDraft = nil
        sheet = .folder(selection)
    }

    func saveFolder(for address: String, path: String) {
        guard !isBusy else { return }
        // Only a running server is restarted, and only the restart touches routing.
        let restart = serverRunning
        if restart, !requireTrust(for: .folder(address: address, path: path)) { return }
        sheet = nil
        Task {
            let result = await runTask(steps: [String(localized: "Pointing \(address) at the new folder…", comment: "Progress step shown while a change runs."), String(localized: "Checking the setup…", comment: "Progress step shown while a change runs."), String(localized: "Restarting the server…", comment: "Progress step shown while a change runs.")],
                                       markers: [(PatchyOutput.syntaxOK, 1), (PatchyOutput.restartingApache, 2)]) { client, askpass, output in
                await client.changeFolder(of: address, to: path, restart: restart, askpass: askpass, onOutput: output)
            }
            let display = (path as NSString).abbreviatingWithTildeInPath
            if sites.first(where: { $0.address == address })?.folder == path {
                if restart, !serverRunning {
                    var failure = Self.startFailure(output: result.output)
                    failure.title = String(localized: "The folder changed, but the server isn’t running", comment: "Title of an error sheet.")
                    sheet = .error(failure)
                } else {
                    banner = Banner(severity: .ok, text: String(localized: "\(address) now serves files from \(display).", comment: "Banner under the toolbar."))
                }
            } else {
                sheet = .error(ErrorInfo(title: String(localized: "Couldn’t change the folder for \(address)", comment: "Title of an error sheet."),
                                         message: String(localized: "The setup check found a problem, so the site still uses its previous folder. Nothing else changed.", comment: "Message in an error sheet."),
                                         details: result.output))
            }
        }
    }

    // MARK: Certificates and PHP

    func askRefreshCertificates() {
        guard !isBusy else { return }
        sheet = .refreshCertificates
        openMainWindow?()
    }

    func refreshCertificates() {
        guard !isBusy else { return }
        sheet = nil
        let restart = serverRunning
        let count = sites.count
        Task {
            let result = await runTask(steps: [Phrases.makingCertificates(siteCount: count), String(localized: "Restarting the server…", comment: "Progress step shown while a change runs.")],
                                       markers: [(PatchyOutput.restartingApache, 1)]) { client, askpass, output in
                await client.refreshCertificates(restart: restart, askpass: askpass, onOutput: output)
            }
            if sites.contains(where: { status(of: $0).certificateNeedsRefresh }) || !result.succeeded {
                sheet = .error(ErrorInfo(title: String(localized: "Couldn’t refresh certificates", comment: "Title of an error sheet."),
                                         message: String(localized: "Some sites may still show a browser warning. If you cancelled a password prompt, try again and enter your Mac password.", comment: "Message in an error sheet."),
                                         details: result.output))
            } else {
                banner = Banner(severity: .ok, text: String(localized: "Certificates refreshed. If a browser still shows a warning, quit and reopen it.", comment: "Banner under the toolbar."))
            }
        }
    }

    func switchPHP(to version: String) {
        guard !isBusy, version != snapshot.activePHP else { return }
        Task {
            let result = await runTask(steps: [String(localized: "Switching every site to PHP \(version)…", comment: "Progress step shown while a change runs."), String(localized: "Restarting the server…", comment: "Progress step shown while a change runs.")],
                                       markers: [(PatchyOutput.restartingApache, 1)]) { client, askpass, output in
                await client.switchPHP(to: version, askpass: askpass, onOutput: output)
            }
            if snapshot.activePHP == version, serverRunning {
                banner = Banner(severity: .ok, text: String(localized: "Every site now runs on PHP \(version).", comment: "Banner under the toolbar."))
            } else {
                openMainWindow?()
                sheet = .error(ErrorInfo(title: String(localized: "Couldn’t switch to PHP \(version)", comment: "Title of an error sheet."),
                                         message: snapshot.activePHP.map { String(localized: "Your sites are running on PHP \($0).") } ?? String(localized: "Show Details has the exact message from Patchy."),
                                         details: result.output))
            }
        }
    }

    // MARK: Sharing

    enum ShareDecision: Equatable { case start, install, ignore }

    /// Whether a click on Share starts a share, asks to install cloudflared first, or does nothing.
    static func shareDecision(canShare: Bool, serverRunning: Bool, alreadySharing: Bool, cloudflaredInstalled: Bool) -> ShareDecision {
        guard canShare, serverRunning, !alreadySharing else { return .ignore }
        return cloudflaredInstalled ? .start : .install
    }

    /// Shares to end: all of them once the server has been seen stopped twice in a row, otherwise
    /// those whose site is gone. A restart takes the server down for a moment, and one read in that
    /// moment mustn't end shares; the tunnel waits it out.
    static func sharesToStop(_ shared: [String], snapshot: PatchySnapshot, serverWasDown: Bool) -> [String] {
        guard snapshot.serverRunning else { return serverWasDown ? shared.sorted() : [] }
        let present = Set(snapshot.sites.map(\.address))
        return shared.filter { !present.contains($0) }.sorted()
    }

    var canShare: Bool { snapshot.supportsSharing }

    /// The domain Patchy shares at, if one is connected. In Debug, `-PatchyDebugShareDomain` stands in for one.
    var sharingDomain: String? {
        #if DEBUG
        if let domain = UserDefaults.standard.string(forKey: "PatchyDebugShareDomain") { return domain }
        #endif
        return snapshot.sharingDomain
    }

    func isSharing(_ address: String) -> Bool {
        switch shares[address] {
        case .starting?, .sharing?: true
        default: false
        }
    }

    /// Shared sites with a working link, for the menu bar.
    var sharedAddresses: [String] {
        shares.compactMap { address, state in if case .sharing = state { address } else { nil } }.sorted()
    }

    func share(_ site: Site, mode: ShareMode = .standard) {
        guard let client else { return }
        let decision = Self.shareDecision(canShare: canShare, serverRunning: serverRunning,
                                          alreadySharing: shareSessions[site.address] != nil,
                                          cloudflaredInstalled: ServerReader.cloudflaredInstalled(client.environment))
        switch decision {
        case .ignore:
            return
        case .install:
            sheet = .installCloudflared(site.address, mode: mode)
            openMainWindow?()
        case .start:
            let address = site.address
            let session = ShareSession(environment: client.environment, address: address, mode: mode) { [weak self] state in
                MainActor.assumeIsolated { self?.shareChanged(address, state) }
            }
            shareSessions[address] = session
            shares[address] = .starting
            session.start()
        }
    }

    private func shareChanged(_ address: String, _ state: ShareState) {
        switch state {
        case .stopped:
            shareSessions[address] = nil
            stoppingShares.remove(address)
            shares[address] = nil
        case .failed(let output, _):
            let mode = shareSessions[address]?.mode ?? .standard
            shareSessions[address] = nil
            stoppingShares.remove(address)
            if output.contains(PatchyOutput.cloudflaredRequired) {
                shares[address] = nil
                sheet = .installCloudflared(address, mode: mode)
                openMainWindow?()
            } else {
                shares[address] = state
            }
        case .starting, .sharing:
            if shareSessions[address] != nil { shares[address] = state }
        }
    }

    func stopSharing(_ address: String) {
        guard let session = shareSessions[address] else { return }
        stoppingShares.insert(address)
        session.stop()
    }

    func stopAllSharing() {
        for address in shareSessions.keys { stopSharing(address) }
    }

    func retryShare(_ address: String) {
        shares[address] = nil
        if let site = site(address) { share(site) }
    }

    func dismissShareProblem(_ address: String) {
        if case .failed? = shares[address] { shares[address] = nil }
    }

    func showShareProblem(_ address: String) {
        guard case .failed(let output, let wasSharing)? = shares[address] else { return }
        sheet = .error(ErrorInfo(title: String(localized: "Couldn’t share \(address)", comment: "Title of an error sheet."),
                                 message: ShareCopy.problem(output: output, wasSharing: wasSharing),
                                 details: output))
    }

    private func access(_ address: String) -> ShareAccess? {
        if case .sharing(let access)? = shares[address] { access } else { nil }
    }

    func copyShareLink(_ address: String) {
        guard let access = access(address) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(access.url.absoluteString, forType: .string)
    }

    func copyShareDetails(_ address: String) {
        guard let access = access(address) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ShareCopy.clientMessage(for: access), forType: .string)
    }

    func installCloudflared(thenShare address: String, mode: ShareMode) {
        guard !isBusy else { return }
        Task {
            let result = await runTask(steps: [String(localized: "Installing cloudflared…", comment: "Progress step shown while a change runs.")]) { client, _, output in
                await client.installCloudflared(onOutput: output)
            }
            guard let environment, ServerReader.cloudflaredInstalled(environment) else {
                sheet = .error(ErrorInfo(title: String(localized: "Couldn’t install cloudflared", comment: "Title of an error sheet."),
                                         message: String(localized: "Nothing was changed. Show Details has the exact message from Homebrew.", comment: "Message in an error sheet."),
                                         details: result.output))
                return
            }
            sheet = nil
            if let site = site(address) { share(site, mode: mode) }
        }
    }

    // MARK: Site shortcuts

    func openInBrowser(_ site: Site) {
        NSWorkspace.shared.open(site.url)
    }

    func copyAddress(_ site: Site) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(site.url.absoluteString, forType: .string)
    }

    func revealFolder(_ site: Site) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: site.folder)
    }

    func showAttention() {
        if let first = problemSites.first {
            selection = first.address
            tab = .overview
            filter = ""
        }
        openMainWindow?()
    }

    func closeSheet() {
        if sheet == .add, add.phase == .progress { return }
        if sheet == .add { add = AddDraft() }
        sheet = nil
        pendingAction = nil
    }
}

#if DEBUG
extension AppModel {
    /// Made-up sites and groups for screenshots, so nothing real is shown. Nothing is read from or
    /// written to Patchy or the groups file while this is on.
    fileprivate func loadDemoData() {
        pauseRefreshForDebug = true
        groupSavingDisabled = true
        let day: TimeInterval = 86_400
        func site(_ address: String, _ folder: String, www: Bool = false, days: Double = 700) -> Site {
            Site(address: address, aliases: www ? ["www.\(address)"] : [],
                 folder: NSHomeDirectory() + "/" + folder, folderExists: true,
                 certificate: .valid(expires: Date().addingTimeInterval(days * day + 3600)), isRouted: true)
        }
        var demo = PatchySnapshot()
        demo.sites = [
            site("bakery-demo.test", "Websites/bakery-demo.test", www: true, days: 701),
            site("blog.test", "Sites/blog", www: true, days: 655),
            site("brightside-dental.test", "Developer/Clients/Brightside Dental/website/public", www: true, days: 512),
            site("docs.harbor-yoga.test", "Developer/Clients/Harbor Yoga/docs", days: 402),
            site("harbor-yoga.test", "Developer/Clients/Harbor Yoga/public_html", www: true, days: 402),
            site("members.northwind.test", "Developer/Clients/Northwind/members/public", days: 233),
            site("northwind.test", "Developer/Clients/Northwind/site/public", www: true, days: 233),
            site("pet-rescue.test", "Websites/pet-rescue.test", www: true, days: 705),
            site("recipes.test", "Sites/recipes", www: true, days: 12),
            site("shop.northwind.test", "Developer/Clients/Northwind/shop/public", days: 233),
            site("summer-camp.test", "Websites/summer-camp.test", www: true, days: 544),
            site("wordpress-sandbox.test", "Developer/Sandbox/wordpress", www: true, days: 620),
        ].sorted { $0.address < $1.address }
        demo.serverRunning = true
        demo.activePHP = snapshot.activePHP ?? "8.4"
        demo.installedPHP = snapshot.installedPHP
        demo.trust = .enabled
        demo.patchyVersion = snapshot.patchyVersion
        demo.supportsSharing = snapshot.supportsSharing
        demo.sharingDomain = snapshot.sharingDomain
        snapshot = demo
        var demoGroups = SiteGroups()
        demoGroups.createGroup(named: "Northwind", sites: ["northwind.test", "members.northwind.test", "shop.northwind.test"])
        demoGroups.createGroup(named: "Harbor Yoga", sites: ["harbor-yoga.test", "docs.harbor-yoga.test"])
        groups = demoGroups
        selection = "northwind.test"
    }

    /// Opens the app in a given state for checking layouts, e.g.
    /// `-PatchyDebugSheet add -PatchyDebugName harborcafe.com -PatchyDebugTab errors -PatchyDebugSite mysite.test`.
    /// Nothing here runs a command.
    func applyDebugLaunchState() {
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "PatchyDebugAppearance") {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        if defaults.bool(forKey: "PatchyDebugDemo") { loadDemoData() }
        if let site = defaults.string(forKey: "PatchyDebugSite"), addresses.contains(site) { selection = site }
        if let tab = defaults.string(forKey: "PatchyDebugTab").flatMap(DetailTab.init(rawValue:)) { self.tab = tab }
        if defaults.string(forKey: "PatchyDebugPhase") == "notinstalled" { phase = .notInstalled(homebrewMissing: false) }
        if defaults.string(forKey: "PatchyDebugPhase") == "empty" { snapshot.sites = []; selection = nil; pauseRefreshForDebug = true }
        if defaults.bool(forKey: "PatchyDebugGroups") {
            // Turn the first two suggestions into groups, in memory only.
            groupSavingDisabled = true
            for suggestion in groups.suggestions(for: addresses).prefix(2) { applyGroupSuggestion(suggestion) }
        }
        if let address = defaults.string(forKey: "PatchyDebugShare"), addresses.contains(address) {
            // Shows a site as shared without starting anything.
            let name = address.split(separator: ".").first.map(String.init) ?? address
            switch defaults.string(forKey: "PatchyDebugShareState") {
            case "starting": shares[address] = .starting
            case "stable": shares[address] = .sharing(ShareAccess(url: URL(string: "https://\(name).example.com")!, username: "preview", password: "k7Rm-4vQx-92Ld"))
            case "failed": shares[address] = .failed(output: "cloudflared stopped before the link was ready:\nERR failed to request quick Tunnel", wasSharing: false)
            default: shares[address] = .sharing(ShareAccess(url: URL(string: "https://quiet-river-banana.trycloudflare.com")!))
            }
        }
        switch defaults.string(forKey: "PatchyDebugSheet") {
        case "add":
            let name = defaults.string(forKey: "PatchyDebugName") ?? ""
            add = AddDraft(name: name, folder: URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Websites/\(AddressRules.finalAddress(from: name))"))
            sheet = .add
        case "addprogress":
            add = AddDraft(name: "harbor-cafe", phase: .progress,
                           steps: ["Pointing harbor-cafe.test at this Mac", "Creating a secure certificate", "Setting up the site", "Checking the setup", "Restarting the server"])
            sheet = .add
        case "adderror":
            add = AddDraft(name: "harbor-cafe", phase: .error, errorMessage: Self.addFailureMessage(output: "Rolling back"), errorDetails: "$ patchy add harbor-cafe.test\nApache configuration is invalid.\nRolling back site creation...")
            sheet = .add
        case "addsuccess":
            // Replays what the window does when an add finishes, without adding anything.
            add = AddDraft(name: "harbor-cafe", folder: URL(fileURLWithPath: NSHomeDirectory()))
            sheet = .add
            Task {
                // Start on the form so the address field takes keyboard focus, as it does for a person.
                try? await Task.sleep(for: .seconds(2))
                add.steps = ["Pointing harbor-cafe.test at this Mac", "Restarting the server"]
                add.phase = .progress
                busy = Busy(steps: add.steps)
                try? await Task.sleep(for: .seconds(1))
                busy?.index = 1
                try? await Task.sleep(for: .seconds(1))
                // A new row arrives in the same update as the selection change, as in a real add.
                pauseRefreshForDebug = true
                var fake = snapshot.sites[0]
                fake.address = "patchyui-fake.test"
                snapshot.sites = (snapshot.sites + [fake]).sorted { $0.address < $1.address }
                busy = nil
                selection = defaults.string(forKey: "PatchyDebugSelectAfter") ?? fake.address
                tab = .overview
                filter = ""
                add = AddDraft()
                sheet = nil
                banner = Banner(severity: .ok, text: "harbor-cafe.test is ready.", openAddress: selection)
            }
        case "remove": if let selection { sheet = .remove(selection) }
        case "folder": if let selection { sheet = .folder(selection) }
        case "trust": openTrustSetup()
        case "trustpassword": openTrustSetup(); trustStep = .password
        case "password": passwordPrompt = PasswordPrompt()
        case "certs": sheet = .refreshCertificates
        case "cloudflared": if let selection { sheet = .installCloudflared(selection, mode: .standard) }
        case "error": sheet = .error(Self.startFailure(output: "Apache's startup error:\n  (48)Address already in use: AH00072: make_sock: could not bind to address [::]:80\nSomething else is listening on port 80/443:\n  COMMAND PID USER\n  nginx 412 joe"))
        default: break
        }
    }
}
#endif
