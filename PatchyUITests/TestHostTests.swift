import Foundation
import Testing
@testable import Patchy_UI

/// The app is the test host. These pin that it stays out of the way while tests run.
@Suite struct TestHostTests {
    /// Without this the host polls Patchy every 3 seconds and starts Sparkle, which checks the
    /// network for updates, all while tests run.
    @Test func theHostKnowsItIsUnderTest() {
        #expect(AppModel.isRunningTests)
    }

    /// The copy tests compare against English. The scheme passes -AppleLanguages and
    /// -AppleLocale so a Mac set to another language still runs them in English.
    @Test func theHostRunsInEnglish() {
        #expect(Bundle.main.preferredLocalizations.first == "en")
        #expect(Locale.current.identifier == "en_US")
    }
}
