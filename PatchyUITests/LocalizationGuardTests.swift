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
    func testEveryLanguagePresentIsComplete() throws {
        try XCTSkipIf(Self.translatedLanguages().isEmpty, "no languages have landed yet")
        let (status, output) = try Self.runScript("merge-translations.py", "--check")
        XCTAssertEqual(status, 0, "merge-translations.py --check reported an incomplete or stale language:\n\(output)")
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
