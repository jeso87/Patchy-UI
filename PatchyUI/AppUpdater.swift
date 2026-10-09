import Foundation
import Sparkle

/// Owns Sparkle's updater for the app's lifetime. Sparkle handles the feed, the update dialog,
/// the download and the install; this only starts it and exposes "Check for Updates…".
///
/// Checking is automatic and daily, with no setting to turn it off: Patchy UI is only reliable when
/// it matches the installed Patchy release, so an install that never hears about updates is the
/// failure case. Installing is never automatic; the user is always asked.
@MainActor
final class AppUpdater {
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.automaticallyChecksForUpdates = true
        controller.updater.updateCheckInterval = 86_400
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
