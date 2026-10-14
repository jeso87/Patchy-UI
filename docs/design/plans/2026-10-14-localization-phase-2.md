# Localization Phase 2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill Patchy UI's 328-entry String Catalog with 35 more languages,
checked structurally and editorially, without changing a line of English.

**Architecture:** No translator touches the catalog. Each language is written
as `translations/<lang>.json` and spliced in by `scripts/merge-translations.py`,
ported from Shrinker Pro. Guard tests take each language's plural categories
from the platform at test time, count and order-check every placeholder, and
confirm each language compiles into the built app. A context script gives
translators each key's English, comment and source location.

**Tech Stack:** Swift 6.4 (language mode 5), XCTest and Swift Testing, Python 3
(standard library only), String Catalogs, XcodeGen 2.46, Xcode 27.1.

**Spec:** `docs/design/specs/2026-10-14-localization-phase-2-design.md`
(and Phase 1's `docs/design/specs/2026-10-14-localization-design.md`).
**Glossary:** `docs/localization-glossary.md`, written with this plan.

## Global Constraints

- **English must not change.** Not one `"en"` value, key or comment. Every
  existing test passes unmodified.
- **Never edit `PatchyUI/Localizable.xcstrings` by hand** in this phase. Write
  `translations/<lang>.json` and run `python3 scripts/merge-translations.py`.
  All catalog writes splice text; none re-serialize the document.
- **The 35 languages:** ar ca cs da de el es fa fi fr he hr hu is it ja ko nb nl
  nn pl pt-BR pt-PT ro ru sk sl sv th tr uk vi zh-Hans zh-Hant zh-HK. No
  `en.json`.
- **Never translated:** Patchy, Patchy UI, PHP, Apache, Homebrew, mkcert,
  `.test`, `.local`, `https://`, every address, path, URL and command, and
  everything in `PatchyOutput`.
- **Placeholders:** a key with one placeholder keeps it (`%@` or `%lld`); a key
  with two or more uses numbered placeholders in every translation (`%1$@`,
  `%2$lld`), one per English placeholder in English's order, each exactly once.
- **Plural entries** carry the probe's categories for the language plus
  `other`. Arabic also supplies `zero` (the probe can't require it).
- **Shell prefix:** `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- **App tests:** `xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -20`
- **PatchyKit tests:** `cd PatchyKit && swift test`
- **After adding a Swift file:** `xcodegen generate`.
- **Commit messages** describe the change in plain sentences and end with the
  attribution lines from the session's system reminder.
- **Phase 2 base:** before Task 1, record `git rev-parse HEAD` in the ledger as
  `<phase-2-base>`; Task 8 diffs against it.

## Review Focus

- **A translation that swaps two values of the same kind** ("made for Patchy
  1.2.0, but 1.2.1 is installed" reversed) passes every type check. Task 5's
  numbered-placeholder rule makes the order explicit; the editorial review in
  Tasks 6 and 7 reads those twelve keys deliberately.
- **A plural entry with two arguments** (`%lld sites look related: %@`) formats
  through the catalog's plural variations with numbered placeholders. Task 5's
  `testTwoArgumentPluralsRenderInEveryLanguage` formats it in each language's
  compiled bundle, not only in the JSON.
- **The not-installed screen sends people to Applications › Utilities ›
  Terminal.** A literal translation of those folder names leaves people unable
  to find Terminal. The glossary and the editorial review cover it.
- **Show Details' English note** finally appears in this phase. Task 6 checks it
  shows in German and stays hidden in English.
- **A future English change** must fail loudly in every language until it's
  translated: `merge-translations.py --check` and the completeness test, Task 3.

---

### Task 1: The glossary, guarded

The glossary is written (`docs/localization-glossary.md`). This task adds the
test that keeps it true: every term it names must still occur in the catalog,
or it is guidance about a string that no longer exists.

**Files:**
- Modify: `PatchyUITests/LocalizationGuardTests.swift`

**Interfaces:**
- Consumes: `LocalizationGuardTests.catalog()`, `repoRoot()` (Phase 1).
- Produces: `testEveryGlossaryTermStillAppearsInTheCatalog`.

- [ ] **Step 1: Write the test**

Add to `LocalizationGuardTests`, above `// MARK: - Helpers`:

```swift
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
```

- [ ] **Step 2: Watch it fail on a bogus term**

Temporarily append `- **frobnicate** — test only.` to the glossary's Terms
list. Run the app tests.
Expected: FAIL, `glossary term “frobnicate” appears in no catalog key`.
Remove the line and run again. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add PatchyUITests/LocalizationGuardTests.swift
git commit -m "Keep the glossary's terms tied to the catalog"
```

---

### Task 2: Context for translators

225 of the 328 entries have no comment. This script prints, for every key, its
English, its comment and the source lines the build extracted it from, so a
translator can read the code around a word like "New" or "Current".

**Files:**
- Create: `scripts/catalog-context.py`

**Interfaces:**
- Consumes: the `.stringsdata` a build writes (Phase 1's `sync-catalog.py`
  finds them; reuse its `default_stringsdata_dir()`).
- Produces: `python3 scripts/catalog-context.py [--missing LANG]` printing one
  block per key; with `--missing LANG`, only keys `translations/LANG.json`
  lacks.

- [ ] **Step 1: Write the script**

```python
#!/usr/bin/env python3
"""Print every catalog key with what a translator needs to translate it well:
its English (each plural form), its comment, and where in the source the build
found it. Run after a build, so the .stringsdata files exist.

Usage:
    python3 scripts/catalog-context.py              # every key
    python3 scripts/catalog-context.py --missing de # only keys translations/de.json lacks
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from catalog_format import CATALOG_PATH, REPO_ROOT

# sync-catalog.py has a hyphen in its name, so load it by path for its build finder.
spec = importlib.util.spec_from_file_location("sync_catalog", HERE / "sync-catalog.py")
sync_catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync_catalog)


def locations() -> dict[str, list[str]]:
    found: dict[str, list[str]] = {}
    for path in sorted(sync_catalog.default_stringsdata_dir().glob("*.stringsdata")):
        data = json.loads(subprocess.run(["plutil", "-convert", "json", "-o", "-", str(path)],
                                         capture_output=True, text=True, check=True).stdout)
        source = data.get("source", path.stem)
        for entry in data.get("tables", {}).get("Localizable", []):
            line = entry.get("location", {}).get("startingLine")
            found.setdefault(entry["key"], []).append(f"{Path(source).name}:{line}")
    return found


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--missing", metavar="LANG", help="only keys translations/LANG.json lacks")
    args = parser.parse_args()

    strings = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))["strings"]
    skip: set[str] = set()
    if args.missing:
        path = REPO_ROOT / "translations" / f"{args.missing}.json"
        if path.exists():
            skip = set(json.loads(path.read_text(encoding="utf-8")))
    where = locations()

    for key in sorted(strings):
        if key in skip:
            continue
        entry = strings[key]
        english = entry["localizations"]["en"]
        print(json.dumps(key, ensure_ascii=False))
        if "variations" in english:
            for category, unit in english["variations"]["plural"].items():
                print(f"   {category}: {json.dumps(unit['stringUnit']['value'], ensure_ascii=False)}")
        else:
            value = english["stringUnit"]["value"]
            if value != key:
                print(f"   value: {json.dumps(value, ensure_ascii=False)}")
        if entry.get("comment"):
            print(f"   comment: {entry['comment']}")
        print(f"   source: {', '.join(where.get(key, ['(not found in this build)']))}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it**

Run:
```bash
xcodebuild -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -configuration Debug -derivedDataPath build build 2>&1 | grep -E "error|BUILD"
chmod +x scripts/catalog-context.py
python3 scripts/catalog-context.py | head -20
python3 scripts/catalog-context.py | grep -c "^   source: (not found"
python3 scripts/catalog-context.py | grep -A3 '^"Current"'
```
Expected: blocks of key, English, comment, source; `0` keys not found; and
`"Current"` lists `Sheets.swift:<line>`.

- [ ] **Step 3: Commit**

```bash
git add scripts/catalog-context.py
git commit -m "Give translators each key's source location as well as its English"
```

---

### Task 3: `scripts/merge-translations.py`

Port Shrinker Pro's merge script. It is the only thing that writes translations
into the catalog.

**Files:**
- Create: `scripts/merge-translations.py` (copied, then edited)
- Create: `translations/.gitkeep`
- Modify: `PatchyUITests/LocalizationGuardTests.swift`

**Interfaces:**
- Consumes: `scripts/catalog_format.py` (Phase 1; it already has
  `load_catalog_text`, `write_catalog_text`, `find_matching_brace`).
- Produces: `python3 scripts/merge-translations.py [--check]`, exit 0 clean,
  1 a language file has keys the catalog lacks, 3 a language lacks catalog keys
  (with `--check`), 4 internal error;
  `testMergingALanguageLeavesEnglishUntouched`,
  `testEveryLanguagePresentIsComplete`.

- [ ] **Step 1: Copy and point it at this repo**

```bash
cp ~/Developer/Apps/"Shrinker Pro"/scripts/merge-translations.py scripts/
chmod +x scripts/merge-translations.py
mkdir -p translations && touch translations/.gitkeep
```

Read the whole script. Replace `Sources/ShrinkerPro/Resources/Localizable.xcstrings`
with `PatchyUI/Localizable.xcstrings` in its docstring, and any worked example
that names Shrinker Pro strings (`"Reveal"`, `"%lld images shrunk"`) with
Patchy UI ones (`"Repair"`, `"%lld sites"`). Change no logic.

Run: `python3 scripts/merge-translations.py --check; echo "exit $?"`
Expected: `exit 0` (no languages yet).

- [ ] **Step 2: Write the two tests**

Add to `LocalizationGuardTests`:

```swift
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
```

and to the helpers:

```swift
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
```

- [ ] **Step 3: Run the tests**

Run the app tests.
Expected: `** TEST SUCCEEDED **`; `testEveryLanguagePresentIsComplete` skipped,
`testMergingALanguageLeavesEnglishUntouched` passed.
Run: `git status --short PatchyUI translations`
Expected: only `translations/.gitkeep` new. The catalog is unchanged.

Prove the merge test can fail: temporarily comment out the line
`let (status, output) = try Self.runScript("merge-translations.py")` and the
`XCTAssertEqual(status, 0, output)` after it. Run the tests.
Expected: FAIL, "the flat translation was not merged". Restore and rerun.
Expected: green.

- [ ] **Step 4: Commit**

```bash
git add scripts/merge-translations.py translations/.gitkeep PatchyUITests/LocalizationGuardTests.swift
git commit -m "Let each language arrive as its own file"
```

---

### Task 4: Plural categories, asked of the platform

**Files:**
- Modify: `PatchyUITests/LocalizationGuardTests.swift`

**Interfaces:**
- Produces: `static func pluralCategories(for language: String) throws -> Set<String>`,
  `testThePluralProbeAgreesWithTwoLanguagesWeCanCheck`,
  `testThePluralProbeFindsArabicsFiveCategories`,
  `testPluralEntriesCarryTheCategoriesTheirLanguageNeeds`.

- [ ] **Step 1: Port the probe and its tests**

Copy, unchanged except for the catalog lookup, from
`~/Developer/Apps/Shrinker Pro/Tests/ShrinkerProTests/LocalizationGuardTests.swift`:
`pluralCategories(for:)` with its whole doc comment (including the note on
`zero` and Arabic), `testThePluralProbeAgreesWithTwoLanguagesWeCanCheck`,
`testThePluralProbeFindsArabicsFiveCategories`, and
`testPluralEntriesCarryTheCategoriesTheirLanguageNeeds`. In the last, replace
`Data(contentsOf: Self.catalogURL(named: "Localizable"))` and the following two
lines with `let strings = try XCTUnwrap(Self.catalog()["strings"] as? [String: Any])`.

`testPluralEntriesCarryTheCategoriesTheirLanguageNeeds` asserts
`checked > 0`; English's own 15 plural entries satisfy it before any language
lands.

- [ ] **Step 2: Run the tests**

Expected: `** TEST SUCCEEDED **`; the probe returns `["one", "other"]` for
English, `["other"]` for Japanese, five categories for Arabic.

- [ ] **Step 3: Prove the completeness check fails**

Temporarily copy one plural entry's `"en"` block in the catalog to a `"ru"`
block with only `one` and `other` (a scratch edit, reverted with
`git checkout PatchyUI/Localizable.xcstrings`). Run the tests.
Expected: FAIL naming the key, `ru`, and the missing `few`, `many`.
Revert and rerun. Expected: green.

- [ ] **Step 4: Commit**

```bash
git add PatchyUITests/LocalizationGuardTests.swift
git commit -m "Ask the system which plural forms each language needs"
```

---

### Task 5: Placeholders counted and ordered, and every language built in

**Files:**
- Modify: `PatchyUITests/LocalizationGuardTests.swift`

**Interfaces:**
- Produces: `static func placeholders(in: String) -> [Placeholder]`,
  `testEveryTranslationKeepsItsPlaceholders`,
  `testEveryTranslatedLanguageIsBuiltIntoTheApp`,
  `testTwoArgumentPluralsRenderInEveryLanguage`.

- [ ] **Step 1: Write the placeholder model and its unit test**

Add to `LocalizationGuardTests`:

```swift
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
```

Run the app tests. Expected: `testPlaceholderParsing` passes.

- [ ] **Step 2: Write the placeholder guard**

```swift
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
```

- [ ] **Step 3: Write the two-argument plural test**

Add to `LocalizationGuardTests`:

```swift
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
```

`a.test, b.test` is passed whole, as `Phrases.relatedSites` does, so the
language's list separator isn't involved. A language whose numerals aren't
Latin digits (Arabic, Persian) may render "2" differently, so the test checks
the list and the absence of leftover placeholders rather than the digit.

- [ ] **Step 4: Watch the guards work on a scratch language**

Add a `"de"` block to the catalog entry `"Patchy %@ is installed, but this Patchy UI was made for Patchy %@. Some things may not work until Patchy UI is updated to match."`
whose value uses `%@` twice (unnumbered), and create an empty-object
`translations/de.json` (`{}`) so the guard doesn't skip. Run the tests.
Expected: `testEveryTranslationKeepsItsPlaceholders` FAILS with "every one must
be numbered", and `testEveryTranslatedLanguageIsBuiltIntoTheApp` and
`testTwoArgumentPluralsRenderInEveryLanguage` fail for German (it has one key,
so "Show Details" and the plural are untranslated). Revert both
(`git checkout PatchyUI/Localizable.xcstrings`, `rm translations/de.json`) and
rerun. Expected: green, the new language tests skipped.

- [ ] **Step 5: Commit**

```bash
git add PatchyUITests/LocalizationGuardTests.swift
git commit -m "Count and order every placeholder, and check each language is built in"
```

---

### Task 6: German, the pilot

The first language, alone, all the way through. If anything about the format,
the merge or the guards is wrong, it is wrong here once rather than 35 times.

**Files:**
- Create: `translations/de.json`
- Modify: `PatchyUI/Localizable.xcstrings` (by the merge script only)
- Create: `docs/design/notes/2026-10-14-german-review.md`

**Interfaces:**
- Consumes: the glossary, `catalog-context.py`, `merge-translations.py`,
  `pluralCategories(for:)`.
- Produces: `translations/de.json`, the worked example Task 7 copies.

- [ ] **Step 1: Read the source and the glossary**

Run: `python3 scripts/catalog-context.py > /tmp/patchy-context.txt` and read it
whole, then `docs/localization-glossary.md`. Translate against the glossary and
the comments, not string by string. Where a key's meaning isn't clear from its
English and comment, read the source line it lists.

- [ ] **Step 2: Read macOS's and Sparkle's German**

Find the platform terms named in the glossary in macOS's own German: AppKit's
`.loctable` files under `/System/Library/Frameworks/AppKit.framework/Resources/`,
Finder's strings, and Sparkle's
`build/Build/Products/Debug/Patchy UI.app/Contents/Frameworks/Sparkle.framework/Resources/de.lproj/`.
Record what you used in the review note (Step 7). Sparkle's German sets the
register.

- [ ] **Step 3: Get German's plural categories from the probe**

Run the app tests filtered to the probe, or add a temporary print. German needs
the probe's set plus `other`; don't take that from this sentence.

- [ ] **Step 4: Write `translations/de.json`**

All 328 keys. A flat key maps to a string, a plural key to an object of
categories. The rules that matter more than fluency:

- Every placeholder kept under the glossary's rules; the twelve keys with two
  or more placeholders use `%1$@`, `%2$@`… in English's order, even where German
  keeps the order.
- Nothing in the glossary's "Never translate" list is translated.
- Platform terms are macOS's, from Step 2.
- Bare keys like `"%lld"`, `"%lld."` and `"%@ · %@"` stay as they are unless
  German writes them differently.
- Prefer the shorter of two equally correct words for buttons, toolbar items
  and the Settings tabs: the Refresh Certificates button and the Settings
  toolbar already clip at double length.

- [ ] **Step 5: Merge, build, test**

```bash
python3 scripts/merge-translations.py
xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | grep -E "error:|Executed|Test run with|TEST SUCC|TEST FAIL"
python3 scripts/sync-catalog.py --check; echo "sync exit $?"
python3 scripts/merge-translations.py --check; echo "merge exit $?"
ls "build/Build/Products/Debug/Patchy UI.app/Contents/Resources/" | grep lproj
git diff PatchyUI/Localizable.xcstrings | grep '^-' | grep -v '^---' | head
```
Expected: TEST SUCCEEDED with the placeholder, plural, completeness and
built-in tests now running (not skipped) for German; both scripts exit 0;
`de.lproj` and `en.lproj` present; the catalog diff removes nothing (every
`-` line would be a changed English value or a moved comma; only `+` lines and
comma moves are acceptable).

- [ ] **Step 6: Look at it**

Launch in German with demo data and check, by screenshot:

```bash
APP="build/Build/Products/Debug/Patchy UI.app/Contents/MacOS/Patchy UI"
"$APP" -AppleLanguages "(de)" -PatchyDebugDemo YES
"$APP" -AppleLanguages "(de)" -PatchyDebugDemo YES -PatchyDebugSheet error
"$APP" -AppleLanguages "(de)" -PatchyDebugDemo YES -PatchyDebugSheet certs
"$APP" -AppleLanguages "(de)" -PatchyDebugPhase notinstalled
```

Check: the window and menu bar menu are German; the status lines read
naturally ("Sicher · 233 Tage"); the sidebar footer's count agrees ("1 Website
braucht Aufmerksamkeit" or whatever form was chosen); in the error sheet, Show
Details expands to the "Technical details from Patchy, in English." note in
German above the English output; the not-installed screen's Applications ›
Utilities names match Finder's German folder names. Settings: all five tabs.
(The two-argument plural is checked by `testTwoArgumentPluralsRenderInEveryLanguage`;
demo mode has no ungrouped related sites to show its card.) Note every clip: these feed
Phase 3.

- [ ] **Step 7: Write the review note**

`docs/design/notes/2026-10-14-german-review.md`: how to read it; the register
and why (Sparkle's German); a table of platform terms with where in macOS each
came from; a table of glossary terms with the German chosen; then every key,
English above German, with its comment. Mark it **Awaiting review** by a German
reader. List the clips Step 6 found.

- [ ] **Step 8: Commit**

```bash
git add translations/de.json PatchyUI/Localizable.xcstrings docs/design/notes/2026-10-14-german-review.md
git commit -m "Translate the app into German"
```

---

### Task 7: The other 34 languages

Run **once per language** after German is reviewed and accepted, one language
per agent so each sees the whole catalog and stays consistent with itself, each
followed by an editorial review. The 34: ar ca cs da el es fa fi fr he hr hu is
it ja ko nb nl nn pl pt-BR pt-PT ro ru sk sl sv th tr uk vi zh-Hans zh-Hant
zh-HK.

Agents writing language files can run in parallel; only the merge touches the
catalog, so merges run one at a time.

**Files:**
- Create: `translations/<lang>.json`
- Modify: `PatchyUI/Localizable.xcstrings` (by the merge script only)

**Interfaces:**
- Consumes: everything above; `translations/de.json` as the worked example.
- Produces: `translations/<lang>.json`.

- [ ] **Step 1: Read the source, the glossary and German**

As Task 6 Step 1, then `translations/de.json` for the file's shape.

- [ ] **Step 2: Read macOS's and Sparkle's words in this language**

As Task 6 Step 2, for `<lang>`. Note that macOS and Sparkle name the Chinese
variants `zh_CN`/`zh_TW`/`zh_HK` in some resource folders.

- [ ] **Step 3: Get this language's plural categories from the probe**

Author the probe's set plus `other`. Arabic: also `zero`.

- [ ] **Step 4: Write `translations/<lang>.json`**

All 328 keys, under Task 6 Step 4's rules. For `ar`, `he` and `fa`: the
` · ` separators and `›` in "Applications › Utilities" read right to left in
the sentence; keep the folder names macOS uses, joined the way the language's
Finder path bar would show them.

- [ ] **Step 5: Merge, build and guard**

As Task 6 Step 5, with `<lang>.lproj` expected in the bundle.

- [ ] **Step 6: Editorial review**

A separate reviewer reads the file against the English, the comments and the
glossary: glossary terms consistent; platform terms are macOS's; register
matches Sparkle's in that language; the twelve multi-placeholder keys put each
value where the sentence means it (installed vs supported version, address vs
folder); no button or tab label far longer than German's. Findings come back as
a revised file, re-merged, re-tested.

- [ ] **Step 7: Commit**

```bash
git add translations/<lang>.json PatchyUI/Localizable.xcstrings
git commit -m "Translate the app into <language name in English>"
```

---

### Task 8: Close Phase 2

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `docs/design/specs/2026-10-14-localization-phase-2-design.md`

- [ ] **Step 1: Final verification**

```bash
xcodegen generate
xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | grep -E "Executed|Test run with|TEST SUCC|TEST FAIL"
python3 scripts/sync-catalog.py --check; echo "sync exit $?"
python3 scripts/merge-translations.py --check; echo "merge exit $?"
ls translations/*.json | wc -l
ls "build/Build/Products/Debug/Patchy UI.app/Contents/Resources/" | grep -c lproj
(cd PatchyKit && swift test 2>&1 | tail -1)
git diff <phase-2-base> -- PatchyUI/Localizable.xcstrings | grep '^-' | grep -v '^---' | grep -v '^-\s*},\?$' | head
```
Expected: tests pass with no localization guard skipped; both scripts exit 0;
`35` files; `36` lproj directories, one per language in the Global
Constraints list plus `en`; PatchyKit passes; no English line removed from the
catalog.

- [ ] **Step 2: Tell CLAUDE.md what a text change now costs**

Under `## Product decisions`, add:

```markdown
- The app ships in 36 languages (`translations/<lang>.json`, merged into the catalog by `scripts/merge-translations.py`; glossary at `docs/localization-glossary.md`). Adding or rewording on-screen text means updating every language file: build, `python3 scripts/sync-catalog.py --prune`, add the key to all 35 files, `python3 scripts/merge-translations.py`. The app tests fail until every language has it.
```

- [ ] **Step 3: Tell the README**

Add one sentence where the README describes the app: Patchy UI is available in
36 languages and follows the language set for it in System Settings › General ›
Language & Region; Patchy's own messages, shown under Show Details, are in
English. Translations are machine-made; corrections are welcome as pull
requests to `translations/<lang>.json`.

- [ ] **Step 4: Record what Phase 2 found**

Append `## Carried out of Phase 2` to the Phase 2 spec: clips seen in German
(and any language reviewed visually), keys any reviewer flagged as uncertain,
and anything for Phase 3 (release notes and appcast per language, the layout
fixes).

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md README.md docs/design/specs/2026-10-14-localization-phase-2-design.md
git commit -m "Finish Phase 2: 36 languages"
```

---

## Done when

- `translations/` holds 35 files and no `en.json`.
- Every catalog entry has 36 localizations.
- Every plural entry carries its language's probe-derived categories plus
  `other`; Arabic's also carry `zero`.
- Every placeholder survives under the counted-and-numbered rules.
- The built app has an `.lproj` for all 36 languages, each translating "Show
  Details".
- The full suite passes; `sync-catalog.py --check` and
  `merge-translations.py --check` exit 0.
- English is unchanged: no `"en"` value altered across the phase.

## Not in this phase

Layout fixes (Phase 3), localized release notes and appcast (Phase 3), the
README beyond one paragraph, Patchy's output.
