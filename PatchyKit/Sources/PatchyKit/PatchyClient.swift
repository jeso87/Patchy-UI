import Foundation

/// Reads Patchy's state from disk and makes changes through the `patchy` command.
public struct PatchyClient: Sendable {
    public typealias Output = @Sendable (String) -> Void

    public let environment: PatchyEnvironment
    public var hostsFile = URL(fileURLWithPath: "/etc/hosts")

    public init(environment: PatchyEnvironment) {
        self.environment = environment
    }

    // MARK: Reading

    /// Everything the app shows, read fresh. `checkTrust` spawns sudo, so callers may skip it on fast polls.
    public func snapshot(checkTrust: Bool = true, previousTrust: TrustState = .notInstalled) -> PatchySnapshot {
        var snapshot = PatchySnapshot()
        let hosts = (try? String(contentsOf: hostsFile, encoding: .utf8)) ?? ""
        snapshot.sites = SiteReader.sites(in: environment, hostsText: hosts)
        snapshot.serverRunning = ServerReader.isRunning(environment)
        snapshot.activePHP = ServerReader.activePHP(environment)
        snapshot.installedPHP = ServerReader.installedPHP(environment)
        snapshot.trust = checkTrust ? ServerReader.trust(environment) : previousTrust
        snapshot.patchyVersion = ServerReader.patchyVersion(environment)
        snapshot.certificateAuthorityInstalled = ServerReader.certificateAuthorityInstalled()
        snapshot.supportsSharing = ServerReader.supportsSharing(environment)
        snapshot.sharingDomain = ServerReader.sharingDomain(environment)
        return snapshot
    }

    // MARK: Commands

    /// Runs `patchy` with a terminal for standard input, which `trust` requires and `add` uses for its questions.
    public func patchy(_ arguments: [String], answers: [String] = [], askpass: AskpassServer? = nil,
                       onOutput: Output? = nil) async -> CommandResult {
        await ProcessRunner.run(environment.patchyBinary, arguments,
                                environment: environment.processEnvironment(extra: askpass?.environment ?? [:]),
                                input: .terminal(lines: answers), onOutput: onOutput)
    }

    public func start(askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await patchy(["start"], askpass: askpass, onOutput: onOutput)
    }

    public func stop(askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await patchy(["stop"], askpass: askpass, onOutput: onOutput)
    }

    public func restart(askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await patchy(["restart"], askpass: askpass, onOutput: onOutput)
    }

    public func addSite(address: String, folder: String, includeWWW: Bool,
                        askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await patchy(["add", address, folder],
                     answers: AddressRules.addPromptAnswers(address: address, includeWWW: includeWWW),
                     askpass: askpass, onOutput: onOutput)
    }

    public func removeSites(_ addresses: [String], askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await patchy(["rm"] + addresses, askpass: askpass, onOutput: onOutput)
    }

    public func switchPHP(to version: String, askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await patchy(["php", version], askpass: askpass, onOutput: onOutput)
    }

    /// Regenerates every certificate. Apache only picks them up after a restart, which Patchy leaves to the caller.
    public func refreshCertificates(restart: Bool, askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        let refreshed = await patchy(["refresh-certs"], askpass: askpass, onOutput: onOutput)
        guard refreshed.succeeded, restart else { return refreshed }
        let restarted = await self.restart(askpass: askpass, onOutput: onOutput)
        return CommandResult(exitCode: restarted.exitCode, output: refreshed.output + restarted.output)
    }

    public func setUpTrust(askpass: AskpassServer, onOutput: Output? = nil) async -> CommandResult {
        await patchy(["trust"], askpass: askpass, onOutput: onOutput)
    }

    /// Installs cloudflared, which `patchy share` needs. Patchy leaves installing it to the person,
    /// so this is the one place the app runs Homebrew itself.
    public func installCloudflared(onOutput: Output? = nil) async -> CommandResult {
        await ProcessRunner.run(environment.brewPrefix.appending(path: "bin/brew"), ["install", "cloudflared"],
                                environment: environment.processEnvironment(), onOutput: onOutput)
    }

    /// Points a site at a different folder. Patchy has no command for this, so the site's config is
    /// edited in place, checked with `patchy check`, and put back exactly as it was if the check fails.
    public func changeFolder(of address: String, to newFolder: String, restart: Bool,
                             askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        let file = environment.vhostFile(for: address)
        guard let original = try? String(contentsOf: file, encoding: .utf8) else {
            return CommandResult(exitCode: 1, output: "Could not read \(file.path).")
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: newFolder, isDirectory: &isDirectory), isDirectory.boolValue else {
            return CommandResult(exitCode: 1, output: "\(newFolder) is not a folder.")
        }
        guard let updated = Vhost.replacingFolder(in: original, with: newFolder) else {
            return CommandResult(exitCode: 1, output: "Could not find the folder setting in \(file.path), or the new folder's name can't be used.")
        }
        do {
            try updated.write(to: file, atomically: true, encoding: .utf8)
        } catch {
            return CommandResult(exitCode: 1, output: "Could not write \(file.path): \(error.localizedDescription)")
        }
        let check = await patchy(["check"], onOutput: onOutput)
        guard check.succeeded else {
            try? original.write(to: file, atomically: true, encoding: .utf8)
            return CommandResult(exitCode: check.exitCode, output: check.output + "\nRestored the previous folder.")
        }
        guard restart else { return check }
        let restarted = await self.restart(askpass: askpass, onOutput: onOutput)
        return CommandResult(exitCode: restarted.exitCode, output: check.output + restarted.output)
    }
}
