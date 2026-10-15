import PatchyKit

/// Phrases that Patchy and Apache print, which the app matches to follow progress and explain
/// failures. This is Patchy's own English output, not copy: never localize it, or matching
/// silently stops working in every other language. Patchy has no machine-readable output, so if
/// a Patchy release rewords one of these, update it here after reading the new script.
enum PatchyOutput {
    // Progress markers.
    static let started = "Successfully started"
    static let stopped = "Successfully stopped"
    static let startingApache = "Starting Apache"
    static let creatingCertificates = "Creating SSL certificates"
    static let creatingConfig = "Creating Apache config file"
    static let syntaxOK = "Syntax OK"
    static let restartingApache = "Restarting Apache"

    // Failures.
    static let rollingBack = "Rolling back"
    static let siteExists = "Site already exists"
    static let serviceStuck = "launchd service is stuck"
    static let addressInUse = "Address already in use"
    static let portHolders = "Something else is listening on port 80/443:"
    static let trustUnsafe = "cannot be safely installed"
    static let trustUnsafeShort = "trust cannot be safely"
    static let terminalRequired = "a terminal is required to read the password"
    static let apacheNotRunning = "Apache isn't running"
    static let cloudflaredRequired = "cloudflared is required"
    static let shareLoginExpired = "Your Cloudflare login has expired"
    static let shareNoCertificate = "has no certificate yet"
    static let shareDeletedTunnel = "still points at the deleted tunnel"
    static let shareTunnelFailed = "cloudflared stopped before the link was ready"

    // Log lines.
    static let fatal = "Fatal"

    static let all = [
        started, stopped, startingApache, creatingCertificates, creatingConfig, syntaxOK, restartingApache,
        rollingBack, siteExists, serviceStuck, addressInUse, portHolders, trustUnsafe, trustUnsafeShort,
        terminalRequired, fatal, apacheNotRunning, cloudflaredRequired,
        shareLoginExpired, shareNoCertificate, shareDeletedTunnel, shareTunnelFailed,
        ShareOutput.sharing, ShareOutput.username, ShareOutput.password, ShareOutput.ready,
    ]
}
