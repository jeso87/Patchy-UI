import Foundation

/// Reads Patchy's state and makes changes, all through the `patchy` command and its `--json` output.
public struct PatchyClient: Sendable {
    public typealias Output = @Sendable (String) -> Void

    public let environment: PatchyEnvironment

    public init(environment: PatchyEnvironment) {
        self.environment = environment
    }

    // MARK: Reading

    /// Everything the app shows, read fresh from `status`, `list` and `version`. Nil when Patchy
    /// couldn't say, such as an older Patchy without `--json`; `version()` still answers then.
    public func snapshot() async -> PatchySnapshot? {
        async let status = patchy(["status", "--json"])
        async let list = patchy(["list", "--json"])
        async let version = version()
        guard let status = PatchyJSON.document(PatchyJSON.Status.self, in: await status.output),
              let list = PatchyJSON.document(PatchyJSON.List.self, in: await list.output) else { return nil }
        return PatchySnapshot(status: status, list: list, version: await version)
    }

    public func version() async -> PatchyVersion? {
        PatchyVersion.parse(await patchy(["version", "--json"]).output)
    }

    // MARK: Commands

    /// Runs `patchy`. With `--json` nothing prompts; sudo asks through `askpass` when given.
    public func patchy(_ arguments: [String], askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await ProcessRunner.run(environment.patchyBinary, arguments,
                                environment: environment.processEnvironment(extra: askpass?.environment ?? [:]),
                                onOutput: onOutput)
    }

    /// A changing command, with `--json` so it reports a result line with a stable error code.
    private func change(_ arguments: [String], askpass: AskpassServer?, onOutput: Output?) async -> CommandResult {
        await patchy(arguments + ["--json"], askpass: askpass, onOutput: onOutput)
    }

    public func start(askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await change(["start"], askpass: askpass, onOutput: onOutput)
    }

    public func stop(askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await change(["stop"], askpass: askpass, onOutput: onOutput)
    }

    public func restart(askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await change(["restart"], askpass: askpass, onOutput: onOutput)
    }

    /// The app shows its own warning before a real address, so `--yes` answers Patchy's.
    public func addSite(address: String, folder: String, includeWWW: Bool,
                        askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await change(["add", address, folder, "--yes", includeWWW ? "--www" : "--no-www"], askpass: askpass, onOutput: onOutput)
    }

    public func removeSites(_ addresses: [String], askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await change(["rm"] + addresses, askpass: askpass, onOutput: onOutput)
    }

    /// Points a site at another folder. Patchy checks the change, puts the site back if Apache
    /// rejects it, and restarts a running server.
    public func changeFolder(of address: String, to folder: String,
                             askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await change(["folder", address, folder], askpass: askpass, onOutput: onOutput)
    }

    public func switchPHP(to version: String, askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await change(["php", version], askpass: askpass, onOutput: onOutput)
    }

    /// Regenerates every certificate, then restarts a running server so it uses them.
    public func refreshCertificates(askpass: AskpassServer? = nil, onOutput: Output? = nil) async -> CommandResult {
        await change(["refresh-certs"], askpass: askpass, onOutput: onOutput)
    }

    /// With `SUDO_ASKPASS` set, `patchy trust` needs no terminal.
    public func setUpTrust(askpass: AskpassServer, onOutput: Output? = nil) async -> CommandResult {
        await change(["trust"], askpass: askpass, onOutput: onOutput)
    }

    /// Installs cloudflared, which `patchy share` needs. Patchy's formula depends on it, so this
    /// is only for a Patchy installed some other way; it is the one place the app runs Homebrew.
    public func installCloudflared(onOutput: Output? = nil) async -> CommandResult {
        await ProcessRunner.run(environment.brewPrefix.appending(path: "bin/brew"), ["install", "cloudflared"],
                                environment: environment.processEnvironment(), onOutput: onOutput)
    }
}
