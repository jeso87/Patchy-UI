import Foundation
import PatchyKit
import Testing
@testable import Patchy_UI

/// Declining password-free mode must still let the change go ahead, with macOS asking for
/// the Mac password instead.
@MainActor
@Suite struct TrustOfferTests {
    func untrustedModel() -> AppModel {
        let model = AppModel()
        var snapshot = PatchySnapshot()
        snapshot.serverRunning = true
        snapshot.trust = .notInstalled
        model.snapshot = snapshot
        return model
    }

    @Test func aChangeOffersPasswordFreeModeFirst() {
        let model = untrustedModel()
        model.restart()
        #expect(model.sheet == .trust)
    }

    @Test func notNowCarriesOnWithTheAdd() {
        let model = untrustedModel()
        model.add = AddDraft(name: "patchyui-test", folder: FileManager.default.temporaryDirectory)
        model.sheet = .add
        model.submitAdd()
        #expect(model.sheet == .trust)

        model.dismissTrust()
        #expect(model.sheet == .add)
        #expect(model.add.phase == .progress)
    }

    @Test func afterNotNowTheOfferDoesntReturnThisSession() {
        let model = untrustedModel()
        model.restart()
        model.dismissTrust()
        model.stop()
        #expect(model.sheet != .trust)
    }
}
