import AppKit
import Observation
import PatchyKit

enum DetailTab: String, CaseIterable, Identifiable {
    case overview, errors, visits

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
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
        case .invalidCharacters: "Use only letters, numbers, hyphens (-), and dots (.)."
        case .unfinished: "That address looks unfinished. It can’t start or end with a dot or hyphen."
        case .alreadyExists(let address): "\(address) already exists. Pick a different address."
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
        switch groupNamePrompt {
        case .new(let address):
            groups.createGroup(named: groupNameDraft, sites: address.map { [$0] } ?? [])
        case .rename(let id):
            groups.rename(id, to: groupNameDraft)
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
        if isBusy { return "Working…" }
        if !serverRunning { return "Stopped" }
        return unroutedCount > 0 ? "Needs repair" : "Running"
    }

    var serverPillText: String {
        if let busy { return busy.text }
        if !serverRunning { return "Stopped" }
        return unroutedCount > 0 ? "Running · needs repair" : "Running · \(phpLabel)"
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
        case .ready(let environment):
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
                passwordPrompt = PasswordPrompt(error: "That doesn’t match your Mac password. Try again.")
            case .notAllowed:
                passwordPrompt = PasswordPrompt(error: "This Mac account isn’t allowed to make this change. Use an administrator account.")
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
        if trustEnabled { return true }
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

    func dismissTrust() {
        sheet = pendingAction == .add ? .add : nil
        pendingAction = nil
    }

    func submitTrustPassword(_ password: String) {
        guard trustStep == .password else { return }
        trustStep = .working
        trustError = nil
        Task {
            switch await PasswordCheck.validate(password) {
            case .wrong:
                trustError = "That doesn’t match your Mac password. Try again."
                trustStep = .password
                return
            case .notAllowed:
                trustError = "This Mac account isn’t allowed to set this up. Use an administrator account."
                trustStep = .password
                return
            case .valid:
                break
            }
            let result = await runTask(steps: ["Setting up password-free mode…"], password: password) { client, askpass, output in
                guard let askpass else { return CommandResult(exitCode: -1, output: "Could not prepare the password helper.") }
                return await client.setUpTrust(askpass: askpass, onOutput: output)
            }
            guard trustEnabled else {
                pendingAction = nil
                let message: String
                if result.output.contains("cannot be safely installed") || result.output.contains("trust cannot be safely") {
                    message = "Patchy can’t set this up safely on this Mac, so nothing was changed. You can keep using the app; it will ask for your Mac password when a change needs it."
                } else if result.output.contains("a terminal is required to read the password") {
                    // sudo wouldn't take the password from the app. Terminal always works.
                    message = "Your Mac wouldn’t let the app pass your password along. You can turn on password-free mode yourself instead: open Terminal (in Applications > Utilities), type patchy trust, press Return and enter your Mac password. Then come back here."
                } else {
                    message = "Nothing was changed. Show Details has the exact message from Patchy."
                }
                sheet = .error(ErrorInfo(title: "Couldn’t set up password-free mode", message: message, details: result.output))
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
            let result = await runTask(steps: ["Starting the server…", "Pointing your addresses at this Mac…"],
                                       markers: [("Successfully started", 1)]) { client, askpass, output in
                await client.start(askpass: askpass, onOutput: output)
            }
            if !serverRunning { sheet = .error(Self.startFailure(output: result.output)) }
        }
    }

    func stop() {
        guard !isBusy, requireTrust(for: .stop) else { return }
        let real = sites.filter(\.isRealAddress).map(\.address)
        Task {
            let result = await runTask(steps: ["Stopping the server…", "Handing addresses back to the internet…"],
                                       markers: [("Successfully stopped", 1)]) { client, askpass, output in
                await client.stop(askpass: askpass, onOutput: output)
            }
            if serverRunning {
                sheet = .error(ErrorInfo(title: "The server didn’t stop",
                                         message: "It’s still running and your sites still open. Try again, or look at Show Details.",
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
            let result = await runTask(steps: ["Restarting the server…", "Checking every address points here…"],
                                       markers: [("Successfully started", 1)]) { client, askpass, output in
                await client.restart(askpass: askpass, onOutput: output)
            }
            if !serverRunning {
                sheet = .error(Self.startFailure(output: result.output))
            } else if neededRepair, unroutedCount == 0 {
                banner = Banner(severity: .ok, text: "Repaired. Every address points at this Mac again.")
            } else if unroutedCount > 0 {
                sheet = .error(ErrorInfo(title: "Some addresses still aren’t pointing at this Mac",
                                         message: "The server restarted, but it couldn’t update where your addresses point. Try Repair again.",
                                         details: result.output))
            }
        }
    }

    func stopThenStart() {
        guard !isBusy else { return }
        sheet = nil
        Task {
            let result = await runTask(steps: ["Stopping the server…", "Starting the server…"],
                                       markers: [("Starting Apache", 1)]) { client, askpass, output in
                let stopped = await client.stop(askpass: askpass, onOutput: output)
                let started = await client.start(askpass: askpass, onOutput: output)
                return CommandResult(exitCode: started.exitCode, output: stopped.output + started.output)
            }
            if !serverRunning { sheet = .error(Self.startFailure(output: result.output, offerReset: false)) }
        }
    }

    static func startFailure(output: String, offerReset: Bool = true) -> ErrorInfo {
        if output.contains("launchd service is stuck"), offerReset {
            return ErrorInfo(title: "The server is stuck",
                             message: "The background service that runs the server didn’t respond. Stopping and starting it again resets it.",
                             details: output, recovery: .stopThenStart)
        }
        if output.contains("Address already in use") {
            var holders: [String] = []
            if let range = output.range(of: "Something else is listening on port 80/443:") {
                for line in output[range.upperBound...].split(whereSeparator: \.isNewline).dropFirst() {
                    guard line.hasPrefix("  "), let name = line.split(whereSeparator: \.isWhitespace).first else { break }
                    if !holders.contains(String(name)) { holders.append(String(name)) }
                }
            }
            return ErrorInfo(title: "Another app is using the web ports",
                             message: Phrases.portsInUse(holders: holders),
                             details: output)
        }
        return ErrorInfo(title: "The server didn’t start",
                         message: "Your sites won’t open until it’s running. Show Details has the exact message from Patchy.",
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
        let steps = ["Pointing \(address) at this Mac", "Creating a secure certificate", "Setting up the site",
                     "Checking the setup", "Restarting the server"]
        add.steps = steps
        add.phase = .progress
        sheet = .add
        Task {
            let result = await runTask(steps: steps, markers: [
                ("Creating SSL certificates", 1), ("Creating Apache config file", 2),
                ("Syntax OK", 3), ("Restarting Apache", 4),
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
                    banner = Banner(severity: .ok, text: "\(address) is ready. Its folder is \(folder.displayPath).", openAddress: address)
                } else {
                    var failure = Self.startFailure(output: result.output)
                    failure.title = "\(address) was added, but the server isn’t running"
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
        if output.contains("Rolling back") {
            return "The setup check found a problem, so Patchy undid every step. Nothing was added and your other sites are fine."
        }
        if output.contains("Site already exists") {
            return "A site with this address already exists, so nothing was changed."
        }
        if !output.contains("Creating SSL certificates") {
            return "Patchy couldn’t point the address at this Mac, so nothing was created. Your other sites are fine."
        }
        return "Something stopped the setup partway. Your other sites are fine; Show Details has the exact message from Patchy."
    }

    func askRemove(_ address: String? = nil) {
        guard !isBusy, phase == .ready, let target = address ?? selection else { return }
        sheet = .remove(target)
    }

    func confirmRemove(_ address: String) {
        guard !isBusy, requireTrust(for: .remove(address)) else { return }
        sheet = nil
        let index = sites.firstIndex { $0.address == address } ?? 0
        Task {
            let result = await runTask(steps: ["Removing \(address)…", "Restarting the server…"],
                                       markers: [("Restarting Apache", 1)]) { client, askpass, output in
                await client.removeSites([address], askpass: askpass, onOutput: output)
            }
            if sites.contains(where: { $0.address == address }) {
                sheet = .error(ErrorInfo(title: "Couldn’t remove \(address)",
                                         message: "The site is still set up exactly as it was. Show Details has the exact message from Patchy.",
                                         details: result.output))
            } else {
                groups.remove(address)
                selection = sites.isEmpty ? nil : sites[min(index, sites.count - 1)].address
                tab = .overview
                banner = Banner(severity: .ok, text: "\(address) was removed. Its folder is still in place.")
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
            let result = await runTask(steps: ["Pointing \(address) at the new folder…", "Checking the setup…", "Restarting the server…"],
                                       markers: [("Syntax OK", 1), ("Restarting Apache", 2)]) { client, askpass, output in
                await client.changeFolder(of: address, to: path, restart: restart, askpass: askpass, onOutput: output)
            }
            let display = (path as NSString).abbreviatingWithTildeInPath
            if sites.first(where: { $0.address == address })?.folder == path {
                if restart, !serverRunning {
                    var failure = Self.startFailure(output: result.output)
                    failure.title = "The folder changed, but the server isn’t running"
                    sheet = .error(failure)
                } else {
                    banner = Banner(severity: .ok, text: "\(address) now serves files from \(display).")
                }
            } else {
                sheet = .error(ErrorInfo(title: "Couldn’t change the folder for \(address)",
                                         message: "The setup check found a problem, so the site still uses its previous folder. Nothing else changed.",
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
            let result = await runTask(steps: [Phrases.makingCertificates(siteCount: count), "Restarting the server…"],
                                       markers: [("Restarting Apache", 1)]) { client, askpass, output in
                await client.refreshCertificates(restart: restart, askpass: askpass, onOutput: output)
            }
            if sites.contains(where: { status(of: $0).certificateNeedsRefresh }) || !result.succeeded {
                sheet = .error(ErrorInfo(title: "Couldn’t refresh certificates",
                                         message: "Some sites may still show a browser warning. If you cancelled a password prompt, try again and enter your Mac password.",
                                         details: result.output))
            } else {
                banner = Banner(severity: .ok, text: "Certificates refreshed. If a browser still shows a warning, quit and reopen it.")
            }
        }
    }

    func switchPHP(to version: String) {
        guard !isBusy, version != snapshot.activePHP else { return }
        Task {
            let result = await runTask(steps: ["Switching every site to PHP \(version)…", "Restarting the server…"],
                                       markers: [("Restarting Apache", 1)]) { client, askpass, output in
                await client.switchPHP(to: version, askpass: askpass, onOutput: output)
            }
            if snapshot.activePHP == version, serverRunning {
                banner = Banner(severity: .ok, text: "Every site now runs on PHP \(version).")
            } else {
                openMainWindow?()
                sheet = .error(ErrorInfo(title: "Couldn’t switch to PHP \(version)",
                                         message: snapshot.activePHP.map { "Your sites are running on PHP \($0)." } ?? "Show Details has the exact message from Patchy.",
                                         details: result.output))
            }
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
        case "error": sheet = .error(Self.startFailure(output: "Apache's startup error:\n  (48)Address already in use: AH00072: make_sock: could not bind to address [::]:80\nSomething else is listening on port 80/443:\n  COMMAND PID USER\n  nginx 412 joe"))
        default: break
        }
    }
}
#endif
