import XCTest
@testable import Patchy_UI

/// Guards the localization contract in `docs/design/specs/2026-10-14-localization-design.md`.
/// These assert facts about the checked-in catalog and project, not about one function.
final class LocalizationGuardTests: XCTestCase {

    /// Sparkle's 36 languages, so the app and its update dialog never disagree.
    static let expectedRegions: Set<String> = [
        "en", "ar", "ca", "cs", "da", "de", "el", "es", "fa", "fi", "fr",
        "he", "hr", "hu", "is", "it", "ja", "ko", "nb", "nl", "nn", "pl",
        "pt-BR", "pt-PT", "ro", "ru", "sk", "sl", "sv", "th", "tr", "uk",
        "vi", "zh-Hans", "zh-Hant", "zh-HK",
    ]

    func testDeclaresAllThirtySixRegions() throws {
        let yaml = try String(contentsOf: Self.repoRoot().appendingPathComponent("project.yml"), encoding: .utf8)
        guard let range = yaml.range(of: #"KNOWN_REGIONS:\s*\[[^\]]*\]"#, options: .regularExpression) else {
            return XCTFail("project.yml has no KNOWN_REGIONS")
        }
        let declared = Set(
            yaml[range]
                .replacingOccurrences(of: "KNOWN_REGIONS:", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " \n[]"))
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        XCTAssertEqual(declared, Self.expectedRegions)
        XCTAssertEqual(yaml.components(separatedBy: "SWIFT_EMIT_LOC_STRINGS").count - 1, 1,
                       "only the Patchy UI target may extract strings — never the tests or PatchyKit")
    }

    func testCatalogDeclaresEnglishAsSource() throws {
        let json = try Self.catalog()
        XCTAssertEqual(json["sourceLanguage"] as? String, "en")
        XCTAssertNotNil(json["strings"], "the catalog has no strings object")
    }

    /// Nothing may ship without English, and nothing may be stale.
    func testNoEntryIsLeftNeedingReview() throws {
        let strings = try XCTUnwrap(Self.catalog()["strings"] as? [String: Any])
        XCTAssertFalse(strings.isEmpty, "the catalog is empty — run scripts/sync-catalog.py")
        for (key, entry) in strings {
            guard let entry = entry as? [String: Any] else { continue }
            if let state = entry["extractionState"] as? String {
                XCTAssertNotEqual(state, "stale", "\(key) is stale — in the catalog but no longer in the source")
            }
            let localizations = entry["localizations"] as? [String: Any]
            XCTAssertNotNil(localizations?["en"], "\(key) has no English")
        }
    }

    /// The catalog and the build must agree in both directions. An orphan is a string someone
    /// would pay to translate 35 times for nothing; a missing key ships untranslated in all 35.
    /// Drives the real script with --check, which never writes the catalog.
    func testCatalogMatchesTheBuildsExtractedKeys() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", Self.repoRoot().appendingPathComponent("scripts/sync-catalog.py").path, "--check"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let report = "\n" + String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        switch process.terminationStatus {
        case 0:
            break
        case 1:
            XCTFail("Orphaned catalog entries — the build no longer produces them. Run `python3 scripts/sync-catalog.py --prune`.\(report)")
        case 2:
            throw XCTSkip("No Patchy UI build found to compare against. Build the app first.\(report)")
        case 3:
            XCTFail("The build emits keys missing from Localizable.xcstrings. Run `python3 scripts/sync-catalog.py`.\(report)")
        case 4:
            XCTFail("sync-catalog.py itself failed; the catalog is unchecked.\(report)")
        default:
            XCTFail("sync-catalog.py could not run (exit \(process.terminationStatus)); is python3 on PATH?\(report)")
        }
    }

    /// Every English plural entry has both `one` and `other`. Anchored on the first plural by
    /// name, so a catalog that lost its plurals can't pass by having none to check.
    ///
    /// Phase 2 extends this to every language's own categories, read from the platform's CLDR
    /// data at test time, never from a hand-written table.
    func testEnglishPluralEntriesHaveBothCategories() throws {
        let strings = try XCTUnwrap(Self.catalog()["strings"] as? [String: Any])
        func plural(_ key: String) -> [String: Any]? {
            (((strings[key] as? [String: Any])?["localizations"] as? [String: Any])?["en"] as? [String: Any])
                .flatMap { ($0["variations"] as? [String: Any])?["plural"] as? [String: Any] }
        }
        let anchor = try XCTUnwrap(plural("%lld sites"), "'%lld sites' has no English plural variations")
        XCTAssertNotNil(anchor["one"])
        XCTAssertNotNil(anchor["other"])

        var examined = 0
        for key in strings.keys {
            guard let forms = plural(key) else { continue }
            examined += 1
            XCTAssertNotNil(forms["one"], "\(key) has no 'one' form for English")
            XCTAssertNotNil(forms["other"], "\(key) has no 'other' form for English")
        }
        XCTAssertGreaterThan(examined, 0, "no plural entries examined — the test would pass vacuously")
    }

    /// A sample of copy that is created as a String. Before Task 7 none of it is extracted,
    /// because `Text(_: String)` never localizes.
    func testCopyHeldInStringsIsInTheCatalog() throws {
        let strings = try XCTUnwrap(Self.catalog()["strings"] as? [String: Any])
        let samples = [
            "Offline while the server is stopped",       // SiteStatus
            "Opens in any browser on this Mac.",         // SiteStatus
            "Overview",                                  // DetailTab
            "Running · %@",                              // AppModel.serverPillText
            "Stopping the server…",                      // a progress step
            "Pointing %@ at this Mac",                   // the add flow's first step
            "The server didn’t start",                   // ErrorInfo
            "%@ was removed. Its folder is still in place.", // a banner
            "Remove %@?",                                // SheetTitle
            "Patchy didn’t report anything.",            // DetailsDisclosure
            "Untitled Group",                            // default group name
            "Patchy: server running",                    // menu bar accessibility
        ]
        for key in samples {
            XCTAssertNotNil(strings[key], "“\(key)” is copy but isn't in the catalog — it is still a plain String")
        }
    }

    /// The phrases the app matches in Patchy's output are Patchy's English, not copy. If one were
    /// localized, progress and error diagnosis would silently stop working in every other language
    /// while every English test stayed green.
    func testPatchyOutputIsNeverLocalized() throws {
        XCTAssertFalse(PatchyOutput.all.isEmpty)
        let strings = try XCTUnwrap(Self.catalog()["strings"] as? [String: Any])
        for phrase in PatchyOutput.all {
            XCTAssertNil(strings[phrase], "“\(phrase)” is matched against Patchy's output and must not be in the catalog")
        }
        let source = try String(contentsOf: Self.repoRoot().appendingPathComponent("PatchyUI/PatchyOutput.swift"), encoding: .utf8)
        XCTAssertFalse(source.contains("localized"), "PatchyOutput.swift must hold plain English only")

        // Every phrase the app matches lives in PatchyOutput, not inline.
        let model = try String(contentsOf: Self.repoRoot().appendingPathComponent("PatchyUI/AppModel.swift"), encoding: .utf8)
        for inline in [".contains(\"", "range(of: \"", "markers: [(\""] {
            XCTAssertFalse(model.contains(inline), "AppModel matches Patchy output inline (\(inline)…) — use PatchyOutput")
        }
    }

    /// Every phrase that shows a count carries plural forms, even where English never needs `one`
    /// ("Secure · 400 days left" is always over 30). In Russian or Polish 31 takes the singular and
    /// 32 another form, so a plain entry would give those languages nowhere to put them.
    /// Bare numbers ("%lld", "%lld.") have no words to inflect and are exempt.
    func testEveryCountedPhraseHasPluralForms() throws {
        let strings = try XCTUnwrap(Self.catalog()["strings"] as? [String: Any])
        var counted = 0
        for (key, entry) in strings {
            let words = key.replacingOccurrences(of: "%lld", with: "")
            guard key.contains("%lld"), words.rangeOfCharacter(from: .letters) != nil else { continue }
            counted += 1
            let english = (((entry as? [String: Any])?["localizations"] as? [String: Any])?["en"] as? [String: Any])
            let plural = (english?["variations"] as? [String: Any])?["plural"]
            XCTAssertNotNil(plural, "“\(key)” shows a count but has no plural forms")
        }
        XCTAssertGreaterThan(counted, 0, "no counted phrases examined — the test would pass vacuously")
    }

    /// The glossary names terms every language must render consistently. A term that no longer
    /// occurs in any catalog key is guidance about a string that no longer exists, which is how a
    /// glossary rots into being wrong rather than merely stale. Terms are the bold text at the
    /// start of each "- **…**" line.
    func testEveryGlossaryTermStillAppearsInTheCatalog() throws {
        let glossary = try String(contentsOf: Self.repoRoot().appendingPathComponent("docs/localization-glossary.md"),
                                  encoding: .utf8)
        let terms = glossary.split(separator: "\n").compactMap { line -> String? in
            guard line.hasPrefix("- **"),
                  let close = line.range(of: "**", range: line.index(line.startIndex, offsetBy: 4)..<line.endIndex)
            else { return nil }
            return String(line[line.index(line.startIndex, offsetBy: 4)..<close.lowerBound])
        }
        XCTAssertGreaterThan(terms.count, 10, "parsed too few terms; has the glossary's format changed?")

        let keys = try XCTUnwrap(Self.catalog()["strings"] as? [String: Any]).keys.joined(separator: "\n").lowercased()
        for term in terms {
            XCTAssertTrue(keys.contains(term.lowercased()), "glossary term “\(term)” appears in no catalog key")
        }
    }

    /// The merge script is the only thing that writes translations into the catalog, so it must
    /// round-trip without disturbing English. Driven through a throwaway language so the test needs
    /// no real translations and leaves nothing behind.
    func testMergingALanguageLeavesEnglishUntouched() throws {
        let root = Self.repoRoot()
        let catalog = Self.catalogURL()
        let before = try String(contentsOf: catalog, encoding: .utf8)
        let probe = root.appendingPathComponent("translations/zz.json")
        defer {
            try? FileManager.default.removeItem(at: probe)
            try? before.write(to: catalog, atomically: true, encoding: .utf8)
        }
        try #"{ "Repair" : "ZZ-REPAIR", "%lld sites" : { "one" : "ZZ %lld", "other" : "ZZ %lld" } }"#
            .write(to: probe, atomically: true, encoding: .utf8)

        let (status, output) = try Self.runScript("merge-translations.py")
        XCTAssertEqual(status, 0, output)

        let after = try String(contentsOf: catalog, encoding: .utf8)
        XCTAssertTrue(after.contains("ZZ-REPAIR"), "the flat translation was not merged")
        XCTAssertTrue(after.contains("ZZ %lld"), "the plural translation was not merged")

        // Every English value is exactly what it was.
        func englishValues(_ text: String) throws -> [String: String] {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
            let strings = try XCTUnwrap(json["strings"] as? [String: Any])
            var out: [String: String] = [:]
            for (key, entry) in strings {
                let en = (((entry as? [String: Any])?["localizations"] as? [String: Any])?["en"] as? [String: Any]) ?? [:]
                out[key] = Self.values(of: en).sorted().joined(separator: "|")
            }
            return out
        }
        XCTAssertEqual(try englishValues(after), try englishValues(before), "English must survive the merge byte for byte")
    }

    /// Every language that exists must carry every key. One merged half-written would sit in the
    /// catalog looking finished and fall back to English for whatever it lacks.
    /// A correction made to `translations/<lang>.json` and never merged would
    /// pass every other guard and ship the old wording. `--check` must see
    /// that the catalog no longer matches the language files.
    func testCheckFailsWhenALanguageFileWasNotMerged() throws {
        let file = Self.repoRoot().appendingPathComponent("translations/fr.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: file.path), "French hasn't landed")
        let before = try String(contentsOf: file, encoding: .utf8)
        defer { try? before.write(to: file, atomically: true, encoding: .utf8) }
        let original = try XCTUnwrap((try JSONSerialization.jsonObject(with: Data(before.utf8)) as? [String: Any])?["Repair"] as? String)
        try before.replacingOccurrences(of: "\"Repair\": \"\(original)\"", with: "\"Repair\": \"UNMERGED\"")
            .write(to: file, atomically: true, encoding: .utf8)
        XCTAssertNotEqual(try String(contentsOf: file, encoding: .utf8), before, "the probe edit didn't apply")

        let (status, output) = try Self.runScript("merge-translations.py", "--check")
        XCTAssertEqual(status, 5, "an unmerged edit must fail --check with 'catalog out of date':\n\(output)")
    }

    func testEveryLanguagePresentIsComplete() throws {
        try XCTSkipIf(Self.translatedLanguages().isEmpty, "no languages have landed yet")
        let (status, output) = try Self.runScript("merge-translations.py", "--check")
        XCTAssertEqual(status, 0, "merge-translations.py --check reported an incomplete or stale language:\n\(output)")
    }

    /// Which plural categories a language actually reaches for whole numbers,
    /// asked of the platform rather than read from a table.
    ///
    /// Phase 1's spec demoted its own hand-written CLDR table to
    /// "illustrative" after a reviewer disputed a row nobody could settle.
    /// This is the replacement: it cannot go stale, because it is measured.
    ///
    /// `zero` is deliberately absent from the categories offered below.
    /// Apple's stringsdict honours a `zero` override for a literal 0 in
    /// *every* language, English and Japanese included — it is an Apple
    /// extension layered on top of CLDR, not something CLDR itself grants
    /// only to some languages. Offering it here would make all 36
    /// languages appear to reach it, which measures nothing. The cost of
    /// that omission is real, not just theoretical: CLDR *does* define
    /// `zero` as a genuine plural category for Arabic, and this probe
    /// cannot tell that apart from the universal Apple override — there is
    /// no observation that separates the two. So `pluralCategories` can
    /// never report `zero`, and the completeness guard below therefore
    /// treats `zero` as always optional for every language, Arabic
    /// included. An Arabic plural entry missing its `zero` variant will
    /// not be caught here; Apple falls back to `other` at runtime, which
    /// is grammatically wrong for a count of zero in Arabic. Whoever
    /// authors the Arabic translation must supply `zero` themselves — this
    /// guard cannot verify it.
    static func pluralCategories(for language: String) throws -> Set<String> {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("plural-\(language)-\(UUID().uuidString)")
            .appendingPathComponent("\(language).lproj")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }

        let dict: [String: Any] = [
            "probe": [
                "NSStringLocalizedFormatKey": "%#@n@",
                "n": [
                    "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                    "NSStringFormatValueTypeKey": "lld",
                    "one": "one", "two": "two", "few": "few", "many": "many", "other": "other",
                ],
            ],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: dir.appendingPathComponent("Localizable.stringsdict"))

        let bundle = try XCTUnwrap(Bundle(path: dir.path), "could not load the probe bundle for \(language)")
        let format = bundle.localizedString(forKey: "probe", value: nil, table: "Localizable")
        var seen: Set<String> = []
        for n in 0...220 {
            seen.insert(String(format: format, locale: Locale(identifier: language), n))
        }
        return seen
    }

    /// Guards the probe itself. English must come back as exactly one/other;
    /// Japanese inflects no nouns for number and must come back as other
    /// alone. If the probe ever returns the raw category names for these, it
    /// has stopped selecting and is reporting its own input.
    func testThePluralProbeAgreesWithTwoLanguagesWeCanCheck() throws {
        XCTAssertEqual(try Self.pluralCategories(for: "en"), ["one", "other"])
        XCTAssertEqual(try Self.pluralCategories(for: "ja"), ["other"])
    }

    /// Arabic is the one language here that reaches five categories for whole
    /// numbers. If this ever returns two, the probe is resolving against the
    /// wrong bundle and every per-language assertion built on it is worthless.
    func testThePluralProbeFindsArabicsFiveCategories() throws {
        XCTAssertEqual(try Self.pluralCategories(for: "ar"), ["one", "two", "few", "many", "other"])
    }

    /// Every plural entry must carry the categories its language actually
    /// reaches, plus `other` as the format's universal fallback. Languages
    /// with no translations yet are skipped, so this tightens on its own as
    /// Phase 2 lands each one.
    func testPluralEntriesCarryTheCategoriesTheirLanguageNeeds() throws {
        let strings = try XCTUnwrap(Self.catalog()["strings"] as? [String: Any])

        var checked = 0
        for (key, entry) in strings {
            guard let entry = entry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else { continue }

            for (language, body) in localizations {
                guard let body = body as? [String: Any],
                      let variations = body["variations"] as? [String: Any],
                      let plural = variations["plural"] as? [String: Any] else { continue }

                // `required` never contains "zero" — see the note on
                // `pluralCategories` above for why not, and what that
                // costs for Arabic. So `supplied` needs no corresponding
                // subtraction: `isSubset(of:)` already ignores any extra
                // keys `plural` supplies, "zero" included.
                let required = try Self.pluralCategories(for: language).union(["other"])
                let supplied = Set(plural.keys)
                XCTAssertTrue(
                    required.isSubset(of: supplied),
                    "\(key) in \(language) is missing \(required.subtracting(supplied).sorted())"
                )
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 0, "no plural entries examined — this would have passed vacuously")
    }

    struct Placeholder: Hashable {
        /// 1-based position for a numbered placeholder (`%2$@`), nil for a plain one (`%@`).
        var position: Int?
        /// "@" or "lld".
        var kind: String
    }

    static let placeholderRegex = try! NSRegularExpression(pattern: #"%(?:(\d+)\$)?(lld|@)"#)

    /// The placeholders in a string, in the order they appear. "%%" is not a placeholder.
    static func placeholders(in text: String) -> [Placeholder] {
        let cleaned = text.replacingOccurrences(of: "%%", with: "")
        let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        return placeholderRegex.matches(in: cleaned, range: range).map { match in
            let position = Range(match.range(at: 1), in: cleaned).flatMap { Int(cleaned[$0]) }
            let kind = String(cleaned[Range(match.range(at: 2), in: cleaned)!])
            return Placeholder(position: position, kind: kind)
        }
    }

    func testPlaceholderParsing() {
        XCTAssertEqual(Self.placeholders(in: "%lld sites look related: %@"),
                       [Placeholder(position: nil, kind: "lld"), Placeholder(position: nil, kind: "@")])
        XCTAssertEqual(Self.placeholders(in: "%2$@ und %1$lld"),
                       [Placeholder(position: 2, kind: "@"), Placeholder(position: 1, kind: "lld")])
        XCTAssertEqual(Self.placeholders(in: "100%% sure"), [])
    }

    /// A dropped placeholder is a crash or a corrupted sentence; a swapped one silently says the
    /// wrong thing. Both are invisible to anyone who can't read the language. The rules (glossary,
    /// "Placeholders"):
    ///
    /// - English has none: the translation has none.
    /// - English has one: the translation has exactly one, of the same kind, plain or numbered `%1$`.
    /// - English has two or more: every placeholder in the translation is numbered, and together
    ///   they are exactly positions 1…n, each once, each the kind English has at that position.
    ///
    /// Plural entries apply the rule per variant with one licence: a variant may leave a
    /// placeholder out (English's own "Refresh certificates for your site?" does), but none may
    /// invent or repeat one, and across the language's variants every position must appear.
    func testEveryTranslationKeepsItsPlaceholders() throws {
        try XCTSkipIf(Self.translatedLanguages().isEmpty, "no languages have landed yet")
        let strings = try XCTUnwrap(Self.catalog()["strings"] as? [String: Any])

        var compared = 0
        var languagesSeen: Set<String> = []
        for (key, entry) in strings {
            guard let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any],
                  let english = localizations["en"] as? [String: Any] else { continue }
            let isPlural = english["variations"] != nil
            // English's fullest form: the flat value, or the plural's `other`.
            let englishText = isPlural
                ? ((((english["variations"] as? [String: Any])?["plural"] as? [String: Any])?["other"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String ?? ""
                : Self.values(of: english).first ?? ""
            let expected = Self.placeholders(in: englishText).map(\.kind)

            for (language, body) in localizations where language != "en" {
                guard let body = body as? [String: Any] else { continue }
                languagesSeen.insert(language)
                var covered: Set<Int> = []
                for value in Self.values(of: body) {
                    compared += 1
                    let found = Self.placeholders(in: value)
                    let context = "“\(key)” in \(language): \(value)"
                    switch expected.count {
                    case 0:
                        XCTAssertTrue(found.isEmpty, "\(context) — invents a placeholder")
                    case 1:
                        XCTAssertLessThanOrEqual(found.count, 1, "\(context) — repeats or invents a placeholder")
                        if let only = found.first {
                            XCTAssertEqual(only.kind, expected[0], "\(context) — wrong kind")
                            XCTAssertTrue(only.position == nil || only.position == 1, "\(context) — numbered past 1")
                            covered.insert(1)
                        }
                        if !isPlural { XCTAssertEqual(found.count, 1, "\(context) — drops its placeholder") }
                    default:
                        XCTAssertTrue(found.allSatisfy { $0.position != nil },
                                      "\(context) — English has \(expected.count) placeholders, so every one must be numbered (%1$@)")
                        let positions = found.compactMap(\.position)
                        XCTAssertEqual(positions.count, Set(positions).count, "\(context) — repeats a position")
                        for placeholder in found {
                            guard let position = placeholder.position else { continue }
                            XCTAssertTrue((1...expected.count).contains(position), "\(context) — %\(position)$ doesn't exist in English")
                            if (1...expected.count).contains(position) {
                                XCTAssertEqual(placeholder.kind, expected[position - 1], "\(context) — %\(position)$ is the wrong kind")
                            }
                            covered.insert(position)
                        }
                        if !isPlural {
                            XCTAssertEqual(Set(positions), Set(1...expected.count), "\(context) — drops a placeholder")
                        }
                    }
                }
                if isPlural, !expected.isEmpty {
                    XCTAssertEqual(covered, Set(1...expected.count),
                                   "“\(key)” in \(language): no variant keeps position(s) \(Set(1...expected.count).subtracting(covered).sorted())")
                }
            }
        }
        XCTAssertGreaterThan(compared, 0, "no translated values compared")
        XCTAssertEqual(languagesSeen, Set(Self.translatedLanguages()), "the guard didn't reach every translated language")
    }

    /// A language in translations/ that the build didn't compile into the app would silently show
    /// English. Checks the app bundle itself, and that a sample string resolves to something other
    /// than English there.
    func testEveryTranslatedLanguageIsBuiltIntoTheApp() throws {
        let languages = Self.translatedLanguages()
        try XCTSkipIf(languages.isEmpty, "no languages have landed yet")
        for language in languages {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"),
                                     "the app has no \(language).lproj — did the build compile the catalog?")
            let bundle = try XCTUnwrap(Bundle(path: path))
            let shown = bundle.localizedString(forKey: "Show Details", value: nil, table: "Localizable")
            XCTAssertNotEqual(shown, "Show Details", "\(language).lproj doesn't translate “Show Details”")
        }
    }

    /// A plural entry with two arguments (`%lld sites look related: %@`) is formatted through the
    /// compiled plural rules with numbered placeholders. Checked by formatting it in each language's
    /// own compiled bundle, which is what the app does, rather than trusting the JSON.
    func testTwoArgumentPluralsRenderInEveryLanguage() throws {
        let languages = Self.translatedLanguages()
        try XCTSkipIf(languages.isEmpty, "no languages have landed yet")
        let key = "%lld sites look related: %@"
        for language in languages {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            let format = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
            XCTAssertNotEqual(format, key, "\(language) has no translation of “\(key)”")
            let rendered = String(format: format, locale: Locale(identifier: language), 2, "a.test, b.test")
            XCTAssertTrue(rendered.contains("a.test, b.test") || rendered.contains("a.test"),
                          "\(language) lost the list: \(rendered)")
            XCTAssertFalse(rendered.contains("%"), "\(language) left a placeholder unformatted: \(rendered)")
        }
    }

    // MARK: - Helpers

    static func catalog() throws -> [String: Any] {
        let data = try Data(contentsOf: catalogURL())
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func catalogURL() -> URL {
        repoRoot().appendingPathComponent("PatchyUI/Localizable.xcstrings")
    }

    /// From this file's own location: the test bundle lives under DerivedData, which never
    /// contains project.yml, so walking up from the bundle would never find the repo.
    static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PatchyUITests
            .deletingLastPathComponent()  // repo root
    }

    /// Languages with a file in translations/.
    static func translatedLanguages() -> [String] {
        let dir = repoRoot().appendingPathComponent("translations")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return files.filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.filter { $0 != "zz" }.sorted()
    }

    /// Runs a script in scripts/ with python3 and returns its exit status and combined output.
    static func runScript(_ name: String, _ arguments: String...) throws -> (Int32, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", repoRoot().appendingPathComponent("scripts/\(name)").path] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
    }

    /// Every stringUnit value in a localization, flat or plural.
    static func values(of localization: [String: Any]) -> [String] {
        if let value = (localization["stringUnit"] as? [String: Any])?["value"] as? String { return [value] }
        guard let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: Any] else { return [] }
        return plural.values.compactMap { (($0 as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String }
    }
}
