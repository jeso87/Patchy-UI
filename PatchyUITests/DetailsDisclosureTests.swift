import Testing
@testable import Patchy_UI

@Suite struct DetailsDisclosureTests {
    /// The note appears only when the app is showing a language other than English.
    @Test func englishNoteFollowsTheAppLanguage() {
        #expect(!DetailsDisclosure.showsEnglishNote(appLanguage: "en"))
        #expect(!DetailsDisclosure.showsEnglishNote(appLanguage: "en-GB"))
        #expect(!DetailsDisclosure.showsEnglishNote(appLanguage: nil))
        #expect(DetailsDisclosure.showsEnglishNote(appLanguage: "de"))
        #expect(DetailsDisclosure.showsEnglishNote(appLanguage: "zh-Hans"))
    }
}
