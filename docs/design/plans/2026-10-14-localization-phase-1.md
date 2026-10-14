# Localization Phase 1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put every piece of Patchy UI's on-screen copy into a String Catalog and
remove every place where English grammar is compiled into Swift, with no change
to what an English user sees.

**Architecture:** A hosted `PatchyUITests` target pins today's English before
anything moves. Count- and list-dependent copy is gathered into one `Phrases`
enum. Copy held in `String` values is written with `String(localized:)` at the
point it is created, so `SWIFT_EMIT_LOC_STRINGS` extracts it and it resolves
through `PatchyUI/Localizable.xcstrings`. Shrinker Pro's `sync-catalog.py` is
ported to merge build-extracted keys into the catalog, because `xcodebuild`
does not. Patchy's own output, which the app matches, moves into a
`PatchyOutput` enum that a test keeps out of the catalog.

**Tech Stack:** Swift 6.4 (language mode 5), SwiftUI, macOS 14+, Xcode 27.1,
XcodeGen 2.46, Swift Testing and XCTest, String Catalogs, Python 3.

**Spec:** `docs/design/specs/2026-10-14-localization-design.md`

## Global Constraints

- **English output must not change**, with one exception: the group header's
  VoiceOver label changes from "1 need attention" to "1 needs attention"
  (Task 2). The copy tests written in Task 2 pass **unmodified** from Task 3 on.
  If one needs its expectation changed, stop and look; do not edit the test.
- **No translations in this phase.** Only `en` in the catalog.
- **Only the `Patchy UI` target** gets `DEVELOPMENT_LANGUAGE`,
  `SWIFT_EMIT_LOC_STRINGS` and `KNOWN_REGIONS`. Never the test target, never
  `PatchyKit`.
- **Patchy's output stays English.** Never wrap a string the app *matches*
  against Patchy's output in `String(localized:)`. Raw command output, the
  `$ patchy add …` details line, `--dump-state` and everything under
  `#if DEBUG` stay plain English.
- **Text containing a site address** is shown with `Text(verbatim:)` or as a
  `String` passed to `Text(_:)`, never as a `LocalizedStringKey` literal that
  is new in this phase (SwiftUI would turn the address into a link). Where such
  text was already `Text(verbatim: "…")`, it becomes
  `Text(verbatim: String(localized: "…"))`.
- **Never put `.fixedSize(horizontal: false, vertical: true)`** on text outside
  a scroll view in the main window (CLAUDE.md). Use `.lineLimit`.
- **`UserDefaults` keys and `groups.json` are compatibility surfaces.** Never
  rename one.
- **Shell prefix for every Xcode command:**
  `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- **Run the app tests with:**
  `xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -20`
- **Run the PatchyKit tests with:** `cd PatchyKit && swift test`
- **After editing `project.yml` or adding/removing a Swift file, run
  `xcodegen generate` before building.**
- **After any change to copy:** build, then
  `python3 scripts/sync-catalog.py --prune`, then the tests. Commit the catalog
  with the code that changed it.
- **Commit messages** describe the change in plain sentences (see `git log`)
  and end with the attribution lines from the session's system reminder.

## Review Focus

- **A ternary that mixes a literal with a `String`** (`copied ? "Copied" : title`)
  types the literal as `String`, which silently stops it localizing. Tasks 2 and
  7 wrap such literals explicitly; Task 10's doubled-strings sweep is the check
  for any that slip through.
- **A plural `one` form without the number** ("Refresh certificates for your
  site?") is wrong in languages whose `one` category covers 21, 31… (Russian,
  Ukrainian, Croatian). Task 5 puts that warning in the entry's comment so
  Phase 2's translators include the number there.
- **A Patchy marker wrapped in `String(localized:)`** would break progress and
  error diagnosis in every non-English language while every English test stays
  green. Task 8's guard test pins it.
- **The test host running the real app** (polling Patchy every 3 seconds,
  starting Sparkle) would make tests slow, flaky and network-dependent. Task 1
  pins that the host stays idle.
- **A test machine not running in English** would fail the copy tests for a
  reason that isn't a defect. Task 1 pins the scheme's English test language.

---

### Task 1: An app test target that stays idle and runs in English

Patchy UI has no app tests; all tests are in `PatchyKit`. This task adds a
hosted unit-test target so later tasks can test `AppModel`, `SiteStatus` and
the catalog. The host app must not start polling Patchy or start Sparkle while
tests run.

**Files:**
- Modify: `project.yml` (add a target and an explicit scheme)
- Modify: `PatchyUI/AppModel.swift:309-311` (`launch()`)
- Create: `PatchyUITests/TestHostTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: test target `PatchyUITests` (module imports the app as
  `@testable import Patchy_UI`); `AppModel.isRunningTests: Bool` (static).

- [ ] **Step 1: Make sure `build/` is writable**

A previous build left `build/` in a state where `xcodebuild` could not write
`Sparkle.framework`. `build/` is generated output (it is in `.gitignore`).

Run: `touch "build/Build/Products/Debug/Patchy UI.app/Contents/Frameworks/.probe" && rm "build/Build/Products/Debug/Patchy UI.app/Contents/Frameworks/.probe"`
If that fails with "Permission denied", run `rm -rf build` (prefix with `sudo`
only if plain `rm` is refused, and say so in your report).

- [ ] **Step 2: Add the test target and scheme to `project.yml`**

Append under `targets:` (after the `Patchy UI` target's `settings` block, same
indentation as `Patchy UI:`):

```yaml
  PatchyUITests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - PatchyUITests
    dependencies:
      - target: Patchy UI
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.87dash.PatchyUITests
        # xcodegen's unit-test template generates no Info.plist; without one, signing fails.
        GENERATE_INFOPLIST_FILE: YES
        SWIFT_VERSION: "5.0"
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: LY424U3HLD
        # Hosted, so tests can `@testable import Patchy_UI` and resolve strings through the
        # app's own catalog (Bundle.main is the app).
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Patchy UI.app/Contents/MacOS/Patchy UI"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

Append at the end of the file, at column 0:

```yaml
schemes:
  Patchy UI:
    build:
      targets:
        Patchy UI: all
        PatchyUITests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets: [PatchyUITests]
      # The copy tests pin English. Run them in English whatever this Mac is set to.
      commandLineArguments:
        "-AppleLanguages (en)": true
        "-AppleLocale en_US": true
    profile:
      config: Release
    analyze:
      config: Debug
    archive:
      config: Release
```

`scripts/release.sh` archives with `-scheme "Patchy UI" -configuration Release`;
the explicit `archive: config: Release` keeps that unchanged.

- [ ] **Step 3: Write the failing tests**

Create `PatchyUITests/TestHostTests.swift`:

```swift
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
```

- [ ] **Step 4: Run them to verify they fail**

Run: `xcodegen generate && xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -20`
Expected: compile error `type 'AppModel' has no member 'isRunningTests'`.

- [ ] **Step 5: Add `isRunningTests` and keep `launch()` idle under test**

In `PatchyUI/AppModel.swift`, add above `func launch()` (in `// MARK: Loading`):

```swift
    /// True inside the unit-test host. The app then stays idle: no polling and no Sparkle.
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
```

Change the first line of `launch()` from:

```swift
        guard pollTask == nil else { return }
```

to:

```swift
        guard pollTask == nil, !Self.isRunningTests else { return }
```

(`launch()` is the only place that touches `updater` or starts polling; both
`RootView` and `MenuBarLabel` call it.)

- [ ] **Step 6: Run the tests to verify they pass**

Run: `xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, 2 tests passed.

If `theHostRunsInEnglish` fails on `Locale.current.identifier`, Xcode passed
each `commandLineArguments` key as one argv element instead of splitting it.
Replace the two keys with four, in this order, and regenerate:
`"-AppleLanguages": true`, `"(en)": true`, `"-AppleLocale": true`,
`"en_US": true`. Check the generated
`Patchy UI.xcodeproj/xcshareddata/xcschemes/Patchy UI.xcscheme` lists them in
that order.

- [ ] **Step 7: Confirm the app itself still builds and runs normally**

Run: `xcodebuild -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -configuration Debug -derivedDataPath build build 2>&1 | tail -3 && "build/Build/Products/Debug/Patchy UI.app/Contents/MacOS/Patchy UI" --dump-state | head -5`
Expected: `** BUILD SUCCEEDED **`, then lines starting `patchy 1.2.1 at /opt/homebrew`.

- [ ] **Step 8: Commit**

```bash
git add project.yml PatchyUI/AppModel.swift PatchyUITests/TestHostTests.swift
git commit -m "Give the app a test target that stays idle and runs in English"
```

---

### Task 2: Pin today's English

Before any copy moves, record exactly what the app says now. Count- and
list-dependent copy is pulled out of views and closures into a new `Phrases`
enum **with its current logic unchanged**, so it can be tested. The copy tests
written here are the proof for every later task: they must pass unmodified
from now on.

**Files:**
- Create: `PatchyUI/Phrases.swift`
- Modify: `PatchyUI/SitePresentation.swift:44-48, 60-62`
- Modify: `PatchyUI/AppModel.swift` (`footerText`, `stop()`, `startFailure`, `refreshCertificates()`)
- Modify: `PatchyUI/Views/MainView.swift` (`navigationSubtitle`, `GroupHeader`, `BannerStack`)
- Modify: `PatchyUI/Views/MenuBar.swift:80, 113`
- Modify: `PatchyUI/Views/SettingsView.swift:138-139`
- Modify: `PatchyUI/Views/LogView.swift:162`
- Modify: `PatchyUI/Views/Sheets.swift` (`RefreshCertificatesSheet` title)
- Create: `PatchyUITests/PhrasesTests.swift`
- Create: `PatchyUITests/SiteStatusCopyTests.swift`
- Create: `PatchyUITests/AppModelCopyTests.swift`

**Interfaces:**
- Consumes: `AppModel.isRunningTests` (Task 1).
- Produces: `enum Phrases` with these static functions, all returning `String`:
  `siteCount(_:)`, `needAttention(_:)`, `footer(siteCount:problems:)`,
  `sitesNeedAttention(_:)`, `sitesInGroupNeedAttention(_:)`,
  `groupAccessibilityLabel(name:sites:problems:)`,
  `sitesNeedNewCertificate(_:)`, `copyLines(_:)`, `expiresIn(days:)`,
  `certificateExpiresIn(days:)`, `makingCertificates(siteCount:)`,
  `refreshCertificatesTitle(siteCount:)`, `unrouted(_:)`, `liveAgain(_:)`,
  `portsInUse(holders:)`, `certificateList(_:)`, `statusSummary(_:more:)`.
  Later tasks change their bodies, never their signatures.

- [ ] **Step 1: Create `PatchyUI/Phrases.swift` with today's logic**

```swift
import Foundation

/// Copy that changes with a count or a list. Kept in one place so tests can pin the English,
/// and so the string catalog can give each language its own plural forms and word order.
enum Phrases {
    /// "1 site", "12 sites".
    static func siteCount(_ count: Int) -> String {
        pluralized(count, "site")
    }

    /// "1 needs attention", "3 need attention".
    static func needAttention(_ count: Int) -> String {
        "\(count) need\(count == 1 ? "s" : "") attention"
    }

    /// The sidebar footer: "12 sites", or "12 sites · 1 needs attention".
    static func footer(siteCount count: Int, problems: Int) -> String {
        problems == 0 ? siteCount(count) : siteCount(count) + " · " + needAttention(problems)
    }

    /// The menu bar item that jumps to the first site with a problem.
    static func sitesNeedAttention(_ count: Int) -> String {
        "\(pluralized(count, "site")) need\(count == 1 ? "s" : "") attention…"
    }

    /// Tooltip on a sidebar group's warning mark.
    static func sitesInGroupNeedAttention(_ count: Int) -> String {
        "\(pluralized(count, "site")) in this group need\(count == 1 ? "s" : "") attention"
    }

    /// VoiceOver label for a sidebar group header: "Northwind, 3 sites, 1 needs attention".
    static func groupAccessibilityLabel(name: String, sites: Int, problems: Int) -> String {
        var parts = [name, siteCount(sites)]
        if problems > 0 { parts.append(needAttention(problems)) }
        return parts.joined(separator: ", ")
    }

    /// Settings › Certificates headline.
    static func sitesNeedNewCertificate(_ count: Int) -> String {
        "\(pluralized(count, "site")) need\(count == 1 ? "s" : "") a new certificate"
    }

    /// The log view's copy button with lines selected.
    static func copyLines(_ count: Int) -> String {
        "Copy \(pluralized(count, "Line"))"
    }

    /// The detail pane's certificate line when it expires within 30 days.
    static func expiresIn(days: Int) -> String {
        "Expires in \(pluralized(days, "day"))"
    }

    /// The same, as the short status shown in the sidebar.
    static func certificateExpiresIn(days: Int) -> String {
        "Certificate expires in \(pluralized(days, "day"))"
    }

    /// First progress step of refreshing certificates.
    static func makingCertificates(siteCount count: Int) -> String {
        "Making new certificates for \(pluralized(count, "site"))…"
    }

    /// Title of the Refresh Certificates sheet.
    static func refreshCertificatesTitle(siteCount count: Int) -> String {
        "Refresh certificates for \(count == 1 ? "your site" : "all \(count) sites")?"
    }

    /// The banner shown while sites aren't routed to this Mac.
    static func unrouted(_ count: Int) -> String {
        "\(count) site\(count == 1 ? " isn’t" : "s aren’t") pointing at this Mac right now, so \(count == 1 ? "it won’t" : "they won’t") open. Repair fixes this by restarting the server."
    }

    /// After stopping the server: which real addresses reach the internet again.
    static func liveAgain(_ addresses: [String]) -> String {
        let names = addresses.prefix(2).joined(separator: " and ") + (addresses.count > 2 ? " and \(addresses.count - 2) more" : "")
        return "\(names) now reach\(addresses.count > 1 ? "" : "es") the live website\(addresses.count > 1 ? "s" : "") again."
    }

    /// The server couldn't start because other apps hold ports 80 and 443.
    static func portsInUse(holders: [String]) -> String {
        let who = holders.isEmpty ? "Another app" : holders.joined(separator: ", ")
        return "\(who) \(holders.count > 1 ? "are" : "is") already using the ports this server needs (80 and 443). Quit \(holders.count > 1 ? "them" : "it"), then start the server again."
    }

    /// Settings › Certificates: the first four addresses, then how many more.
    static func certificateList(_ addresses: [String]) -> String {
        addresses.prefix(4).joined(separator: ", ") + (addresses.count > 4 ? " and \(addresses.count - 4) more" : "")
    }

    /// A site's one-line status: its worst issue, then how many others.
    static func statusSummary(_ first: String, more: Int) -> String {
        first + (more > 0 ? " · \(more) more" : "")
    }
}
```

Note `groupAccessibilityLabel` uses `needAttention`, which agrees the verb.
The old inline label said "1 need attention"; this is the one deliberate English
change (Global Constraints).

- [ ] **Step 2: Route the call sites through `Phrases`**

Each replacement below must produce the same English as the line it replaces.

`PatchyUI/SitePresentation.swift`, in the `days <= 30` branch:

```swift
                certificate = Line(severity: .warning, label: Phrases.expiresIn(days: days),
                                   detail: "Valid until \(date). Refresh before then to avoid browser warnings.")
                certShort = Phrases.certificateExpiresIn(days: days)
```

and the summary:

```swift
            summary = Phrases.statusSummary(first.text, more: issues.count - 1)
```

`PatchyUI/AppModel.swift`:

```swift
    var footerText: String {
        guard !sites.isEmpty else { return "" }
        return Phrases.footer(siteCount: sites.count, problems: problemSites.count)
    }
```

In `stop()`, replace the two lines building `names` and the banner with:

```swift
                banner = Banner(severity: .info, text: Phrases.liveAgain(real))
```

In `startFailure`, replace the `let who = …` line and the `message:` argument:

```swift
            return ErrorInfo(title: "Another app is using the web ports",
                             message: Phrases.portsInUse(holders: holders),
                             details: output)
```

In `refreshCertificates()`:

```swift
            let result = await runTask(steps: [Phrases.makingCertificates(siteCount: count), "Restarting the server…"],
```

`PatchyUI/Views/MainView.swift`:

```swift
        .navigationSubtitle(Phrases.siteCount(model.sites.count))
```

In `GroupHeader`, the warning glyph's help and the accessibility label:

```swift
                    .help(Phrases.sitesInGroupNeedAttention(problems))
```

```swift
            .accessibilityLabel(Phrases.groupAccessibilityLabel(name: group.name, sites: sites.count, problems: problems))
```

In `BannerStack`, the unrouted banner:

```swift
                BannerRow(severity: .warning,
                          text: Phrases.unrouted(model.unroutedCount),
                          actionTitle: "Repair", action: { model.restart() })
```

(delete the now-unused `let count = model.unroutedCount`).

`PatchyUI/Views/MenuBar.swift`:

```swift
            Text(verbatim: "\(Phrases.siteCount(model.sites.count)) · \(model.phpLabel)")
```

```swift
                Button(Phrases.sitesNeedAttention(problems)) { model.showAttention() }
```

`PatchyUI/Views/SettingsView.swift`, in `CertificateSettings`:

```swift
                            Text(Phrases.sitesNeedNewCertificate(needing.count)).fontWeight(.medium)
                            SettingsNote(text: Phrases.certificateList(needing.map(\.address)))
```

`PatchyUI/Views/LogView.swift`: the copy button mixes literals with a `String`,
which would type the literals as `String` and stop them localizing. Give it a
computed title. Replace `Button(copied ? "Copied" : log.selected.isEmpty ? "Copy" : "Copy \(pluralized(log.selected.count, "Line"))") {`
with `Button(copyTitle) {`, and add to `LogView`:

```swift
    private var copyTitle: String {
        if copied { return String(localized: "Copied") }
        if log.selected.isEmpty { return String(localized: "Copy") }
        return Phrases.copyLines(log.selected.count)
    }
```

`PatchyUI/Views/Sheets.swift`, `RefreshCertificatesSheet`:

```swift
        SheetTitle(title: Phrases.refreshCertificatesTitle(siteCount: model.sites.count),
```

- [ ] **Step 3: Build**

Run: `xcodegen generate && xcodebuild -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -configuration Debug -derivedDataPath build build 2>&1 | grep -E "error|BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Write the `Phrases` copy tests**

Create `PatchyUITests/PhrasesTests.swift`:

```swift
import Testing
@testable import Patchy_UI

/// Pins the exact English of every count- and list-dependent phrase. From Task 3 on these
/// strings come from the catalog; these tests must keep passing unmodified.
@Suite struct PhrasesTests {
    @Test func siteCount() {
        #expect(Phrases.siteCount(0) == "0 sites")
        #expect(Phrases.siteCount(1) == "1 site")
        #expect(Phrases.siteCount(2) == "2 sites")
    }

    @Test func needAttention() {
        #expect(Phrases.needAttention(1) == "1 needs attention")
        #expect(Phrases.needAttention(3) == "3 need attention")
    }

    @Test func footer() {
        #expect(Phrases.footer(siteCount: 12, problems: 0) == "12 sites")
        #expect(Phrases.footer(siteCount: 12, problems: 1) == "12 sites · 1 needs attention")
        #expect(Phrases.footer(siteCount: 1, problems: 3) == "1 site · 3 need attention")
    }

    @Test func menuAttentionItem() {
        #expect(Phrases.sitesNeedAttention(1) == "1 site needs attention…")
        #expect(Phrases.sitesNeedAttention(2) == "2 sites need attention…")
    }

    @Test func groupAttentionTooltip() {
        #expect(Phrases.sitesInGroupNeedAttention(1) == "1 site in this group needs attention")
        #expect(Phrases.sitesInGroupNeedAttention(2) == "2 sites in this group need attention")
    }

    @Test func groupAccessibilityLabel() {
        #expect(Phrases.groupAccessibilityLabel(name: "Northwind", sites: 3, problems: 0) == "Northwind, 3 sites")
        #expect(Phrases.groupAccessibilityLabel(name: "Northwind", sites: 1, problems: 1) == "Northwind, 1 site, 1 needs attention")
        #expect(Phrases.groupAccessibilityLabel(name: "Northwind", sites: 3, problems: 2) == "Northwind, 3 sites, 2 need attention")
    }

    @Test func certificateHeadline() {
        #expect(Phrases.sitesNeedNewCertificate(1) == "1 site needs a new certificate")
        #expect(Phrases.sitesNeedNewCertificate(3) == "3 sites need a new certificate")
    }

    @Test func copyLines() {
        #expect(Phrases.copyLines(1) == "Copy 1 Line")
        #expect(Phrases.copyLines(2) == "Copy 2 Lines")
    }

    @Test func expiry() {
        #expect(Phrases.expiresIn(days: 1) == "Expires in 1 day")
        #expect(Phrases.expiresIn(days: 12) == "Expires in 12 days")
        #expect(Phrases.certificateExpiresIn(days: 1) == "Certificate expires in 1 day")
        #expect(Phrases.certificateExpiresIn(days: 30) == "Certificate expires in 30 days")
    }

    @Test func refreshCertificates() {
        #expect(Phrases.makingCertificates(siteCount: 1) == "Making new certificates for 1 site…")
        #expect(Phrases.makingCertificates(siteCount: 26) == "Making new certificates for 26 sites…")
        #expect(Phrases.refreshCertificatesTitle(siteCount: 1) == "Refresh certificates for your site?")
        #expect(Phrases.refreshCertificatesTitle(siteCount: 5) == "Refresh certificates for all 5 sites?")
    }

    @Test func unroutedBanner() {
        #expect(Phrases.unrouted(1) == "1 site isn’t pointing at this Mac right now, so it won’t open. Repair fixes this by restarting the server.")
        #expect(Phrases.unrouted(2) == "2 sites aren’t pointing at this Mac right now, so they won’t open. Repair fixes this by restarting the server.")
    }

    @Test func liveAgain() {
        #expect(Phrases.liveAgain(["a.com"]) == "a.com now reaches the live website again.")
        #expect(Phrases.liveAgain(["a.com", "b.com"]) == "a.com and b.com now reach the live websites again.")
        #expect(Phrases.liveAgain(["a.com", "b.com", "c.com"]) == "a.com and b.com and 1 more now reach the live websites again.")
        #expect(Phrases.liveAgain(["a.com", "b.com", "c.com", "d.com"]) == "a.com and b.com and 2 more now reach the live websites again.")
    }

    @Test func portsInUse() {
        #expect(Phrases.portsInUse(holders: []) == "Another app is already using the ports this server needs (80 and 443). Quit it, then start the server again.")
        #expect(Phrases.portsInUse(holders: ["nginx"]) == "nginx is already using the ports this server needs (80 and 443). Quit it, then start the server again.")
        #expect(Phrases.portsInUse(holders: ["nginx", "httpd"]) == "nginx, httpd are already using the ports this server needs (80 and 443). Quit them, then start the server again.")
    }

    @Test func certificateList() {
        #expect(Phrases.certificateList(["a.test", "b.test"]) == "a.test, b.test")
        #expect(Phrases.certificateList(["a", "b", "c", "d"]) == "a, b, c, d")
        #expect(Phrases.certificateList(["a", "b", "c", "d", "e", "f"]) == "a, b, c, d and 2 more")
    }

    @Test func statusSummary() {
        #expect(Phrases.statusSummary("Folder missing", more: 0) == "Folder missing")
        #expect(Phrases.statusSummary("Folder missing", more: 2) == "Folder missing · 2 more")
    }
}
```

- [ ] **Step 5: Write the `SiteStatus` copy tests**

Create `PatchyUITests/SiteStatusCopyTests.swift`:

```swift
import Foundation
import PatchyKit
import Testing
@testable import Patchy_UI

/// Pins every label, detail and summary SiteStatus produces.
@Suite struct SiteStatusCopyTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// A certificate expiring `days` whole days from `now`, as Patchy rounds it.
    func site(days: Int? = 400, folderExists: Bool = true, routed: Bool = true,
              certificate: CertificateStatus? = nil) -> Site {
        let cert = certificate ?? .valid(expires: now.addingTimeInterval(Double(days ?? 0) * 86_400 + 3_600))
        return Site(address: "blog.test", folder: "/tmp/blog", folderExists: folderExists,
                    certificate: cert, isRouted: routed)
    }

    func formatted(daysFromNow days: Int) -> String {
        now.addingTimeInterval(Double(days) * 86_400 + 3_600).formatted(date: .abbreviated, time: .omitted)
    }

    @Test func healthy() {
        let status = SiteStatus(site: site(days: 400), serverRunning: true, now: now)
        #expect(status.summary == "Secure · 400 days")
        #expect(status.certificate.label == "Secure · 400 days left")
        #expect(status.certificate.detail == "Valid until \(formatted(daysFromNow: 400)).")
        #expect(status.reachable.label == "Yes")
        #expect(status.reachable.detail == "Opens in any browser on this Mac.")
        #expect(status.issues.isEmpty)
    }

    @Test func expiringSoon() {
        let one = SiteStatus(site: site(days: 1), serverRunning: true, now: now)
        #expect(one.certificate.label == "Expires in 1 day")
        #expect(one.certificate.detail == "Valid until \(formatted(daysFromNow: 1)). Refresh before then to avoid browser warnings.")
        #expect(one.summary == "Certificate expires in 1 day")
        let thirty = SiteStatus(site: site(days: 30), serverRunning: true, now: now)
        #expect(thirty.certificate.label == "Expires in 30 days")
        let thirtyOne = SiteStatus(site: site(days: 31), serverRunning: true, now: now)
        #expect(thirtyOne.certificate.label == "Secure · 31 days left")
    }

    @Test func expired() {
        let status = SiteStatus(site: site(days: -3), serverRunning: true, now: now)
        #expect(status.certificate.label == "Certificate expired")
        #expect(status.certificate.detail == "Expired on \(formatted(daysFromNow: -3)). Browsers will warn that this site isn’t secure.")
        #expect(status.summary == "Certificate expired")
    }

    @Test func missingAndUnreadableCertificates() {
        let missing = SiteStatus(site: site(certificate: .missing), serverRunning: true, now: now)
        #expect(missing.certificate.label == "No certificate")
        #expect(missing.certificate.detail == "https:// won’t work for this site until certificates are refreshed.")
        #expect(missing.summary == "No certificate")
        let invalid = SiteStatus(site: site(certificate: .invalid), serverRunning: true, now: now)
        #expect(invalid.certificate.label == "Certificate can’t be read")
        #expect(invalid.certificate.detail == "The certificate file is damaged. Refreshing certificates replaces it.")
        #expect(invalid.summary == "Certificate unreadable")
    }

    @Test func folderMissingWithAnotherProblem() {
        let status = SiteStatus(site: site(folderExists: false, certificate: .missing), serverRunning: true, now: now)
        #expect(status.summary == "Folder missing · 1 more")
        #expect(status.issues.map(\.text) == ["Folder missing", "No certificate"])
        #expect(status.reachable.label == "Opens, but shows an error")
        #expect(status.reachable.detail == "There’s no folder to serve files from.")
    }

    @Test func serverStopped() {
        let status = SiteStatus(site: site(days: 400), serverRunning: false, now: now)
        #expect(status.summary == "Offline while the server is stopped")
        #expect(status.reachable.label == "Not right now")
        #expect(status.reachable.detail == "The server is stopped.")
    }

    @Test func notRouted() {
        let status = SiteStatus(site: site(days: 400, routed: false), serverRunning: true, now: now)
        #expect(status.issues.map(\.text) == ["Not pointing at this Mac"])
        #expect(status.summary == "Not pointing at this Mac")
        #expect(status.reachable.label == "Not right now")
        #expect(status.reachable.detail == "This address isn’t pointing at this Mac. Repair fixes it.")
    }
}
```

- [ ] **Step 6: Write the `AppModel` copy tests**

Create `PatchyUITests/AppModelCopyTests.swift`:

```swift
import Foundation
import PatchyKit
import Testing
@testable import Patchy_UI

/// Pins the copy AppModel builds: the server pill, the footer, tab titles, the add form's
/// problems and every error message derived from Patchy's output.
@MainActor
@Suite struct AppModelCopyTests {
    func model(running: Bool, sites: [Site] = [], php: String? = "8.4") -> AppModel {
        let model = AppModel()
        var snapshot = PatchySnapshot()
        snapshot.serverRunning = running
        snapshot.sites = sites
        snapshot.activePHP = php
        model.snapshot = snapshot
        return model
    }

    func healthySite(_ address: String, routed: Bool = true) -> Site {
        Site(address: address, folder: "/tmp/\(address)",
             certificate: .valid(expires: Date().addingTimeInterval(400 * 86_400)), isRouted: routed)
    }

    @Test func serverPillAndTitle() {
        #expect(model(running: false).serverPillText == "Stopped")
        #expect(model(running: false).serverTitle == "Stopped")
        #expect(model(running: true, sites: [healthySite("a.test")]).serverPillText == "Running · PHP 8.4")
        #expect(model(running: true, sites: [healthySite("a.test")]).serverTitle == "Running")
        #expect(model(running: true, sites: [healthySite("a.test", routed: false)]).serverPillText == "Running · needs repair")
        #expect(model(running: true, sites: [healthySite("a.test", routed: false)]).serverTitle == "Needs repair")
        #expect(model(running: true, php: nil).phpLabel == "PHP")
    }

    @Test func footer() {
        #expect(model(running: true).footerText == "")
        #expect(model(running: true, sites: [healthySite("a.test"), healthySite("b.test")]).footerText == "2 sites")
        #expect(model(running: true, sites: [healthySite("a.test", routed: false)]).footerText == "1 site · 1 needs attention")
    }

    @Test func tabTitles() {
        #expect(DetailTab.allCases.map(\.title) == ["Overview", "Errors", "Visits"])
    }

    @Test func addressProblems() {
        #expect(AddDraft(name: "my site").problemText(existing: []) == "Use only letters, numbers, hyphens (-), and dots (.).")
        #expect(AddDraft(name: "mysite.").problemText(existing: []) == "That address looks unfinished. It can’t start or end with a dot or hyphen.")
        #expect(AddDraft(name: "mysite").problemText(existing: ["mysite.test"]) == "mysite.test already exists. Pick a different address.")
        #expect(AddDraft(name: "mysite").problemText(existing: []) == nil)
    }

    @Test func startFailures() {
        let stuck = AppModel.startFailure(output: "Error: launchd service is stuck")
        #expect(stuck.title == "The server is stuck")
        #expect(stuck.message == "The background service that runs the server didn’t respond. Stopping and starting it again resets it.")
        #expect(stuck.recovery == .stopThenStart)

        let stuckNoReset = AppModel.startFailure(output: "Error: launchd service is stuck", offerReset: false)
        #expect(stuckNoReset.title == "The server didn’t start")

        let ports = AppModel.startFailure(output: "Apache's startup error:\n  (48)Address already in use: AH00072\nSomething else is listening on port 80/443:\n  COMMAND PID USER\n  nginx 412 joe")
        #expect(ports.title == "Another app is using the web ports")
        #expect(ports.message == "nginx is already using the ports this server needs (80 and 443). Quit it, then start the server again.")

        let generic = AppModel.startFailure(output: "something else")
        #expect(generic.title == "The server didn’t start")
        #expect(generic.message == "Your sites won’t open until it’s running. Show Details has the exact message from Patchy.")
        #expect(generic.details == "something else")
    }

    @Test func addFailures() {
        #expect(AppModel.addFailureMessage(output: "Rolling back site creation") == "The setup check found a problem, so Patchy undid every step. Nothing was added and your other sites are fine.")
        #expect(AppModel.addFailureMessage(output: "Site already exists") == "A site with this address already exists, so nothing was changed.")
        #expect(AppModel.addFailureMessage(output: "sudo: no password") == "Patchy couldn’t point the address at this Mac, so nothing was created. Your other sites are fine.")
        #expect(AppModel.addFailureMessage(output: "Creating SSL certificates\nboom") == "Something stopped the setup partway. Your other sites are fine; Show Details has the exact message from Patchy.")
    }
}
```

- [ ] **Step 7: Run all tests**

Run: `xcodegen generate && xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`. These tests describe the code as it is, so they
pass immediately; a failure means the extraction in Step 2 changed English (fix
the code, not the test), or the expectation was copied wrong from the source
(compare with `git show HEAD:<file>` and fix the test, saying so in the
commit message).

- [ ] **Step 8: Run the PatchyKit tests**

Run: `cd PatchyKit && swift test 2>&1 | tail -3`
Expected: all pass (nothing in PatchyKit changed).

- [ ] **Step 9: Commit**

```bash
git add PatchyUI PatchyUITests
git commit -m "Pin the app's English before any of it moves"
```

---

### Task 3: A catalog, and the tooling that fills it

`SWIFT_EMIT_LOC_STRINGS` makes the compiler list every localizable literal in
`.stringsdata` files, but `xcodebuild` never merges them into the catalog (that
is an Xcode IDE feature). Shrinker Pro's `sync-catalog.py` does the merge; this
task ports it and adds the guard tests.

**Files:**
- Create: `PatchyUI/Localizable.xcstrings`
- Modify: `project.yml` (`options:` and the `Patchy UI` target's `settings.base`)
- Create: `scripts/catalog_format.py` (copied from Shrinker Pro, then edited)
- Create: `scripts/sync-catalog.py` (copied from Shrinker Pro, then edited)
- Modify: `.gitignore`
- Create: `PatchyUITests/LocalizationGuardTests.swift`

**Interfaces:**
- Consumes: the `PatchyUITests` target (Task 1).
- Produces: `PatchyUI/Localizable.xcstrings`;
  `python3 scripts/sync-catalog.py [--prune] [--check]` with exit codes 0 ok,
  1 orphans, 2 no build found, 3 keys missing (with `--check`), 4 internal
  error; `LocalizationGuardTests.catalogURL() -> URL` and
  `LocalizationGuardTests.repoRoot() -> URL` (static), used by Tasks 4 and 8.

- [ ] **Step 1: Create the empty catalog**

`PatchyUI/Localizable.xcstrings` (exactly this, including the blank line):

```json
{
  "sourceLanguage" : "en",
  "strings" : {

  },
  "version" : "1.0"
}
```

`PatchyUI/` is the target's source folder, so XcodeGen picks it up as a
resource with no `sources:` change.

- [ ] **Step 2: Declare the language settings in `project.yml`**

Under `options:` add:

```yaml
  developmentLanguage: en
```

In the `Patchy UI` target's `settings: base:` (not the test target's), add:

```yaml
        # Localization. Only this target: PatchyKit and the tests stay English.
        DEVELOPMENT_LANGUAGE: en
        SWIFT_EMIT_LOC_STRINGS: YES
        # Sparkle's 36 languages, so the app and its update dialog never disagree.
        KNOWN_REGIONS: [en, ar, ca, cs, da, de, el, es, fa, fi, fr, he, hr,
                        hu, is, it, ja, ko, nb, nl, nn, pl, pt-BR, pt-PT, ro,
                        ru, sk, sl, sv, th, tr, uk, vi, zh-Hans, zh-Hant,
                        zh-HK]
```

- [ ] **Step 3: Copy the two scripts from Shrinker Pro**

```bash
cp ~/Developer/Apps/"Shrinker Pro"/scripts/catalog_format.py scripts/
cp ~/Developer/Apps/"Shrinker Pro"/scripts/sync-catalog.py scripts/
chmod +x scripts/sync-catalog.py
```

Read both files in full before editing them.

- [ ] **Step 4: Point `catalog_format.py` at this catalog**

Replace the `CATALOG_PATH` line with:

```python
CATALOG_PATH = REPO_ROOT / "PatchyUI" / "Localizable.xcstrings"
```

and change the path in the module docstring's first lines to
`PatchyUI/Localizable.xcstrings`. Change nothing else.

- [ ] **Step 5: Adapt `sync-catalog.py`**

(a) Replace every remaining mention of `Sources/ShrinkerPro/Resources/Localizable.xcstrings`,
`ShrinkerPro` and `-scheme ShrinkerPro` in docstrings and messages with
`PatchyUI/Localizable.xcstrings`, `Patchy UI` and `-scheme "Patchy UI"`.
In the module docstring, change "36 languages" wording only where it names
Shrinker Pro.

(b) Replace `STRINGSDATA_GLOB` with:

```python
STRINGSDATA_GLOB = (
    "Build/Intermediates.noindex/Patchy UI.build/*/Patchy UI.build/"
    "Objects-normal/*/*.stringsdata"
)
```

(c) Replace `default_stringsdata_dir()` with this version, which also looks in
the repo's own `build/` (where CLAUDE.md's commands and `release.sh` build):

```python
def default_stringsdata_dir() -> Path:
    """Find the most recently built Patchy UI target's .stringsdata directory,
    in this repo's build/ (the -derivedDataPath every documented command uses)
    or in Xcode's own DerivedData."""
    roots: list[Path] = [REPO_ROOT / "build"]
    dd_root = Path.home() / "Library" / "Developer" / "Xcode" / "DerivedData"
    if dd_root.is_dir():
        roots += [dd_root / name for name in os.listdir(dd_root) if name.startswith("Patchy_UI-")]

    # Ranked by the newest .stringsdata file each directory holds, not by
    # the directory's own mtime: an incremental rebuild rewrites files in
    # place without touching the directory, so directory mtime can point
    # at a stale build.
    newest: dict[Path, float] = {}
    for root in roots:
        for match in root.glob(STRINGSDATA_GLOB):
            directory = match.parent
            mtime = match.stat().st_mtime
            if mtime > newest.get(directory, 0.0):
                newest[directory] = mtime

    if not newest:
        print(
            "No Patchy UI build with .stringsdata files found in build/ or "
            f"{dd_root}. Build the app first, or pass a path explicitly.",
            file=sys.stderr,
        )
        sys.exit(NO_BUILD_FOUND)

    return max(newest, key=lambda directory: newest[directory])
```

(d) Shrinker Pro's catalog was never empty when this script first ran, and
`insert_entries` refuses an empty `strings` object. In `insert_entries`,
replace:

```python
    before = text[:idx]
    if not before.endswith("    }"):
        die_internal("unexpected formatting immediately before the closing brace -- refusing to guess.")

    new_blocks = ",\n".join(format_entry(key, found[key]) for key in to_add)
    return before + ",\n" + new_blocks + text[idx:]
```

with:

```python
    before = text[:idx]
    new_blocks = ",\n".join(format_entry(key, found[key]) for key in to_add)

    # An empty catalog: the first entry follows the opening brace, with no comma.
    if before.rstrip().endswith('"strings" : {'):
        return before.rstrip() + "\n" + new_blocks + text[idx:]

    if not before.endswith("    }"):
        die_internal("unexpected formatting immediately before the closing brace -- refusing to guess.")

    return before + ",\n" + new_blocks + text[idx:]
```

(e) In the `argparse` help for the positional argument, say
"Defaults to the most recently built Patchy UI target in build/ or DerivedData."

- [ ] **Step 6: Ignore Python's bytecode**

Append to `.gitignore`:

```
# Python bytecode from scripts/
__pycache__/
```

- [ ] **Step 7: Build and fill the catalog**

Run:
```bash
xcodegen generate
xcodebuild -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -configuration Debug -derivedDataPath build build 2>&1 | grep -E "error|BUILD"
python3 scripts/sync-catalog.py
python3 scripts/sync-catalog.py --check; echo "exit $?"
python3 -c "import json; print(len(json.load(open('PatchyUI/Localizable.xcstrings'))['strings']))"
```
Expected: BUILD SUCCEEDED; the first run reports keys added; `--check` prints
`exit 0`; the count is between 140 and 170 (about 150 literal keys exist today;
the exact number depends on Task 2's edits).

Confirm that `PatchyKit` emitted nothing (it must not have
`SWIFT_EMIT_LOC_STRINGS`):
Run: `find build -path "*PatchyKit*" -name "*.stringsdata" | wc -l`
Expected: `0`.

- [ ] **Step 8: Write the guard tests**

Create `PatchyUITests/LocalizationGuardTests.swift`. These use XCTest, not Swift
Testing, because they need `XCTSkip` for an environment that has no build to
compare against.

```swift
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
}
```

- [ ] **Step 9: Prove the build-agreement guard fails when it should**

Temporarily add `Text("Catalog guard probe")` inside `DetailColumn`'s `VStack`
in `PatchyUI/Views/MainView.swift`. Build (do **not** run sync-catalog), then:

Run: `xcodegen generate && xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | grep -E "MISSING|missing|TEST"`
Expected: `testCatalogMatchesTheBuildsExtractedKeys` FAILS naming
`Catalog guard probe`.

Remove the probe line, rebuild, run the tests again.
Expected: `** TEST SUCCEEDED **`. (`xcodebuild test` builds first, so the
`.stringsdata` the script reads always match the source being tested.)

- [ ] **Step 10: Commit**

```bash
git add project.yml .gitignore PatchyUI/Localizable.xcstrings scripts/catalog_format.py scripts/sync-catalog.py PatchyUITests/LocalizationGuardTests.swift
git commit -m "Give the app a string catalog and the script that fills it"
```

---

### Task 4: Walking skeleton — one real plural

Prove the whole mechanism on the smallest plural before nine more depend on it:
`String(localized:)` with an `Int` is extracted as `%lld`, the catalog's plural
variations choose the form, and the English test passes through the catalog.

**Files:**
- Modify: `PatchyUI/Phrases.swift` (`siteCount`)
- Modify: `PatchyUI/Localizable.xcstrings` (the `%lld sites` entry)
- Modify: `PatchyUITests/LocalizationGuardTests.swift`

**Interfaces:**
- Consumes: `Phrases.siteCount(_:)` (Task 2), `scripts/sync-catalog.py` and
  `LocalizationGuardTests.catalog()` (Task 3).
- Produces: the catalog plural shape every later plural copies.

- [ ] **Step 1: Write the failing guard test**

Add to `LocalizationGuardTests`:

```swift
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
```

- [ ] **Step 2: Move `siteCount` into the catalog**

In `PatchyUI/Phrases.swift`:

```swift
    /// "1 site", "12 sites".
    static func siteCount(_ count: Int) -> String {
        String(localized: "\(count) sites", comment: "A number of websites, e.g. in the window subtitle and the sidebar footer.")
    }
```

- [ ] **Step 3: Build, sync, and watch English break**

Run:
```bash
xcodebuild -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -configuration Debug -derivedDataPath build build 2>&1 | grep -E "error|BUILD"
python3 scripts/sync-catalog.py --prune
xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | grep -E "1 sites|failed|TEST"
```
Expected: TEST FAILED. `PhrasesTests.siteCount` reports `"1 sites"` (the
catalog has `%lld sites` as a plain string, so there is no singular), and
`testEnglishPluralEntriesHaveBothCategories` fails on the anchor.

- [ ] **Step 4: Author the plural variations**

In `PatchyUI/Localizable.xcstrings`, find the entry `"%lld sites" : {` that the
script added and replace that whole entry (from its key to its closing `}`,
keeping the comma that follows it, if any) with:

```json
    "%lld sites" : {
      "comment" : "A number of websites, e.g. in the window subtitle and the sidebar footer.",
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : { "state" : "translated", "value" : "%lld site" }
              },
              "other" : {
                "stringUnit" : { "state" : "translated", "value" : "%lld sites" }
              }
            }
          }
        }
      }
    }
```

Check the file is still valid JSON:
Run: `python3 -m json.tool PatchyUI/Localizable.xcstrings > /dev/null && echo ok`
Expected: `ok`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`. If `siteCount(1)` still reads "1 sites", the
built app has a stale catalog: check `build/Build/Products/Debug/Patchy UI.app/Contents/Resources/en.lproj/Localizable.stringsdict`
exists and contains `%lld site`. If it does not, stop: the mechanism this whole
plan depends on is not working, and later tasks would pile on top of it.

- [ ] **Step 6: Commit**

```bash
git add PatchyUI/Phrases.swift PatchyUI/Localizable.xcstrings PatchyUITests/LocalizationGuardTests.swift
git commit -m "Move the site count into the catalog as its first plural"
```

---

### Task 5: Every other plural and agreement

Replace each remaining hand-built plural with one catalog entry whose whole
phrase varies with the count, so surrounding words can inflect. Then delete
`pluralized`.

**Files:**
- Modify: `PatchyUI/Phrases.swift`
- Modify: `PatchyUI/Theme.swift:155-157` (delete `pluralized`)
- Modify: `PatchyUI/Localizable.xcstrings`

**Interfaces:**
- Consumes: Task 4's catalog shape.
- Produces: no new names. `pluralized` no longer exists.

- [ ] **Step 1: Rewrite the plural phrases in `Phrases.swift`**

Replace these function bodies (signatures and doc comments unchanged):

```swift
    static func needAttention(_ count: Int) -> String {
        String(localized: "\(count) need attention", comment: "How many websites have a problem, after a site count, e.g. “12 sites · 1 needs attention”.")
    }

    static func sitesNeedAttention(_ count: Int) -> String {
        String(localized: "\(count) sites need attention…", comment: "Menu bar item that shows the first website with a problem.")
    }

    static func sitesInGroupNeedAttention(_ count: Int) -> String {
        String(localized: "\(count) sites in this group need attention", comment: "Tooltip on a sidebar group's warning mark.")
    }

    static func sitesNeedNewCertificate(_ count: Int) -> String {
        String(localized: "\(count) sites need a new certificate", comment: "Settings › Certificates headline.")
    }

    static func copyLines(_ count: Int) -> String {
        String(localized: "Copy \(count) Lines", comment: "Button that copies the selected log lines. Title case, like other buttons.")
    }

    static func expiresIn(days: Int) -> String {
        String(localized: "Expires in \(days) days", comment: "Certificate status in a site's details when it expires within 30 days.")
    }

    static func certificateExpiresIn(days: Int) -> String {
        String(localized: "Certificate expires in \(days) days", comment: "Short status in the sidebar when a site's certificate expires within 30 days.")
    }

    static func makingCertificates(siteCount count: Int) -> String {
        String(localized: "Making new certificates for \(count) sites…", comment: "Progress step while refreshing every site's certificate.")
    }

    static func refreshCertificatesTitle(siteCount count: Int) -> String {
        String(localized: "Refresh certificates for all \(count) sites?",
               comment: "Sheet title. English's 'one' form says “your site” with no number; in languages whose 'one' category also covers 21, 31… the 'one' form must include the number.")
    }

    static func unrouted(_ count: Int) -> String {
        String(localized: "\(count) sites aren’t pointing at this Mac right now, so they won’t open. Repair fixes this by restarting the server.",
               comment: "Banner while some sites' addresses don't lead to this Mac. Repair is the name of a toolbar button.")
    }
```

- [ ] **Step 2: Delete `pluralized`**

Delete the `pluralized(_:_:_:)` function at the end of `PatchyUI/Theme.swift`.
Run: `grep -rn "pluralized" PatchyUI`
Expected: no output. If a call site remains, route it through `Phrases`.

- [ ] **Step 3: Build, sync, and watch English break**

Run:
```bash
xcodebuild -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -configuration Debug -derivedDataPath build build 2>&1 | grep -E "error|BUILD"
python3 scripts/sync-catalog.py --prune
xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | grep -E "failed|TEST"
```
Expected: TEST FAILED, with `PhrasesTests` reporting the singular cases
("1 need attention", "Copy 1 Lines", "Expires in 1 days", …). `--prune` also
removes the orphaned garbage keys Task 2's code used to emit, such as
`%@ need%@ attention…`.

- [ ] **Step 4: Author the ten plural entries**

For each row, replace the entry the script added with the block shape from
Task 4 Step 4: same `comment` as in the Swift source, `"extractionState" : "manual"`,
and English `one` / `other` values as below. Keep `other` identical to the key.

| Key | `one` | `other` |
|---|---|---|
| `%lld need attention` | `%lld needs attention` | `%lld need attention` |
| `%lld sites need attention…` | `%lld site needs attention…` | `%lld sites need attention…` |
| `%lld sites in this group need attention` | `%lld site in this group needs attention` | `%lld sites in this group need attention` |
| `%lld sites need a new certificate` | `%lld site needs a new certificate` | `%lld sites need a new certificate` |
| `Copy %lld Lines` | `Copy %lld Line` | `Copy %lld Lines` |
| `Expires in %lld days` | `Expires in %lld day` | `Expires in %lld days` |
| `Certificate expires in %lld days` | `Certificate expires in %lld day` | `Certificate expires in %lld days` |
| `Making new certificates for %lld sites…` | `Making new certificates for %lld site…` | `Making new certificates for %lld sites…` |
| `Refresh certificates for all %lld sites?` | `Refresh certificates for your site?` | `Refresh certificates for all %lld sites?` |
| `%lld sites aren’t pointing at this Mac right now, so they won’t open. Repair fixes this by restarting the server.` | `%lld site isn’t pointing at this Mac right now, so it won’t open. Repair fixes this by restarting the server.` | (the key) |

The apostrophes are U+2019 (’), as in the Swift source. Copy keys from the
catalog, don't retype them.

Run: `python3 -m json.tool PatchyUI/Localizable.xcstrings > /dev/null && echo ok`
Expected: `ok`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`, with `PhrasesTests` unmodified.

- [ ] **Step 6: Commit**

```bash
git add PatchyUI/Phrases.swift PatchyUI/Theme.swift PatchyUI/Localizable.xcstrings
git commit -m "Let the catalog choose every plural, and retire pluralized"
```

---

### Task 6: Lists and sentences built from parts

Three lists are joined with English `", "` and `" and "`, and two sentences
agree a verb with a list's length. Each becomes whole sentences chosen by the
list's shape, with the separator in the catalog. As in Shrinker Pro, these are
truncated enumerations, not grammatical lists: `ListFormatter` would add an
"and" English doesn't have today, so it is not used.

**Files:**
- Modify: `PatchyUI/Phrases.swift`
- Modify: `PatchyUI/Views/MainView.swift` (`GroupSuggestionCard`)
- Modify: `PatchyUI/Localizable.xcstrings` (the `list separator` entry)
- Modify: `PatchyUITests/PhrasesTests.swift` (one new test only)

**Interfaces:**
- Consumes: `Phrases` (Tasks 2, 5).
- Produces: `Phrases.listSeparator: String`, `Phrases.more(_ count: Int) -> String`,
  `Phrases.relatedSites(_ addresses: [String]) -> String`.

- [ ] **Step 1: Write the failing test for the suggestion card**

The group suggestion card builds its sentence inline today. Add to
`PatchyUITests/PhrasesTests.swift`:

```swift
    @Test func relatedSites() {
        #expect(Phrases.relatedSites(["acme.test", "shop.acme.test"]) == "2 sites look related: acme.test, shop.acme.test")
    }
```

Run the tests. Expected: compile error, `Phrases` has no member `relatedSites`.

- [ ] **Step 2: Rewrite the list phrases**

In `PatchyUI/Phrases.swift`, add:

```swift
    /// Between names in a list. English ", "; CJK languages use "、".
    static var listSeparator: String {
        String(localized: "list separator", defaultValue: ", ",
               comment: "Separates names in a list of websites or apps. English uses a comma and a space; CJK languages use 、")
    }

    /// The tail of a shortened list: "2 more".
    static func more(_ count: Int) -> String {
        String(localized: "\(count) more", comment: "How many names a shortened list left out, e.g. “a.com and b.com and 2 more”.")
    }

    /// The group suggestion card: "2 sites look related: acme.test, shop.acme.test".
    static func relatedSites(_ addresses: [String]) -> String {
        String(localized: "\(addresses.count) sites look related: \(addresses.joined(separator: listSeparator))",
               comment: "Sidebar suggestion to group websites with similar names. Always two or more. The list is the addresses.")
    }
```

Replace these bodies:

```swift
    static func footer(siteCount count: Int, problems: Int) -> String {
        // " · " joins two separate facts, as the sidebar and menu do elsewhere; it is not grammar.
        problems == 0 ? siteCount(count) : siteCount(count) + " · " + needAttention(problems)
    }

    static func groupAccessibilityLabel(name: String, sites: Int, problems: Int) -> String {
        var parts = [name, siteCount(sites)]
        if problems > 0 { parts.append(needAttention(problems)) }
        return parts.joined(separator: listSeparator)
    }

    static func liveAgain(_ addresses: [String]) -> String {
        switch addresses.count {
        case 0:
            return ""
        case 1:
            return String(localized: "\(addresses[0]) now reaches the live website again.",
                          comment: "Banner after stopping the server. The placeholder is a real web address that this Mac no longer serves locally.")
        case 2:
            return String(localized: "\(addresses[0]) and \(addresses[1]) now reach the live websites again.",
                          comment: "Banner after stopping the server. Both placeholders are real web addresses.")
        default:
            return String(localized: "\(addresses[0]) and \(addresses[1]) and \(more(addresses.count - 2)) now reach the live websites again.",
                          comment: "Banner after stopping the server. Two real web addresses, then “N more”.")
        }
    }

    static func portsInUse(holders: [String]) -> String {
        switch holders.count {
        case 0:
            return String(localized: "Another app is already using the ports this server needs (80 and 443). Quit it, then start the server again.",
                          comment: "Why the web server couldn't start.")
        case 1:
            return String(localized: "\(holders[0]) is already using the ports this server needs (80 and 443). Quit it, then start the server again.",
                          comment: "Why the web server couldn't start. The placeholder is a program name, e.g. nginx.")
        default:
            return String(localized: "\(holders.joined(separator: listSeparator)) are already using the ports this server needs (80 and 443). Quit them, then start the server again.",
                          comment: "Why the web server couldn't start. The placeholder is a list of two or more program names.")
        }
    }

    static func certificateList(_ addresses: [String]) -> String {
        let listed = addresses.prefix(4).joined(separator: listSeparator)
        guard addresses.count > 4 else { return listed }
        return String(localized: "\(listed) and \(more(addresses.count - 4))",
                      comment: "A shortened list of web addresses: the first four, then “N more”.")
    }

    static func statusSummary(_ first: String, more count: Int) -> String {
        guard count > 0 else { return first }
        return String(localized: "\(first) · \(more(count))",
                      comment: "A site's status: its worst problem, then how many other problems it has.")
    }
```

Note the parameter rename inside `statusSummary` (`more count:`): the label
`more` is unchanged for callers, and the body can now call `more(_:)`.

In `PatchyUI/Views/MainView.swift`, `GroupSuggestionCard`:

```swift
            Text(verbatim: Phrases.relatedSites(suggestion.sites))
```

- [ ] **Step 3: Build, sync, and watch the separator break**

Run:
```bash
xcodebuild -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -configuration Debug -derivedDataPath build build 2>&1 | grep -E "error|BUILD"
python3 scripts/sync-catalog.py --prune
xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | grep -E "list separator|failed|TEST"
```
Expected: TEST FAILED. The script wrote the entry `list separator` with the
English value `"list separator"` (it uses the key as the value), so lists read
`a.testlist separatorb.test`.

- [ ] **Step 4: Author the separator entry**

Replace the `list separator` entry with:

```json
    "list separator" : {
      "comment" : "Separates names in a list of websites or apps. English uses a comma and a space; CJK languages use 、",
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : { "state" : "translated", "value" : ", " }
        }
      }
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`, with every pre-existing `PhrasesTests` test
unmodified.

- [ ] **Step 6: Commit**

```bash
git add PatchyUI/Phrases.swift PatchyUI/Views/MainView.swift PatchyUI/Localizable.xcstrings PatchyUITests/PhrasesTests.swift
git commit -m "Give each list-shaped sentence to the catalog whole"
```

---

### Task 7: Copy that travels as a String

Most of the app's plain-language copy is created as a `String` (in `AppModel`,
`SiteStatus` and view helpers) and shown with `Text(_: String)`, which never
localizes and is invisible to extraction. Each such literal is now written with
`String(localized:)` where it is created, or the helper that receives it takes
a `LocalizedStringKey`.

**Files:**
- Modify: `PatchyUI/AppModel.swift`
- Modify: `PatchyUI/SitePresentation.swift`
- Modify: `PatchyUI/Views/Sheets.swift`
- Modify: `PatchyUI/Views/SettingsView.swift`
- Modify: `PatchyUI/Views/MenuBar.swift`
- Modify: `PatchyUI/Views/FirstRunViews.swift`
- Modify: `PatchyUI/Views/SiteDetailView.swift`
- Modify: `PatchyUI/Views/LogView.swift`
- Modify: `PatchyUI/Views/MainView.swift`
- Modify: `PatchyUI/Localizable.xcstrings` (by the script only)
- Modify: `PatchyUITests/LocalizationGuardTests.swift`

**Interfaces:**
- Consumes: everything above.
- Produces: `SettingsNote.init(_: LocalizedStringKey)` and
  `SettingsNote.init(verbatim: String)` replace `SettingsNote(text:)`;
  `BannerRow.actionTitle` becomes `LocalizedStringKey?`; `InfoRow.label`
  becomes `LocalizedStringKey`.

The rule for every edit in this task:

- A literal assigned to, returned as, or passed as a `String` →
  `String(localized: "…", comment: "…")`. Write a comment when the string alone
  doesn't say where it appears or what a placeholder is; skip it for obvious
  button titles.
- A literal inside `Text(verbatim: "…")` that is copy, not just an address →
  `Text(verbatim: String(localized: "…"))`.
- A private helper whose text parameter only ever receives literals → change
  the parameter to `LocalizedStringKey`; its `Text(text)` then localizes and
  the literals at its call sites are extracted.
- A ternary or `??` that mixes a literal with a `String` value types the
  literal as `String`: wrap the literal.
- **Never** wrap anything listed in Task 8 (strings matched against Patchy's
  output), the `$ patchy add …` details line, `"PHP \($0)"`, command-line
  strings shown to copy (`brew install …`), `--dump-state`, or code under
  `#if DEBUG`.

- [ ] **Step 1: Write the failing extraction test**

Add to `LocalizationGuardTests`:

```swift
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
```

Run the tests. Expected: FAIL, listing every sample as missing.

- [ ] **Step 2: `AppModel.swift`**

- `DetailTab.title`:

```swift
    var title: String {
        switch self {
        case .overview: String(localized: "Overview", comment: "Tab in a site's details.")
        case .errors: String(localized: "Errors", comment: "Tab in a site's details showing its error log.")
        case .visits: String(localized: "Visits", comment: "Tab in a site's details showing its access log.")
        }
    }
```

- `AddDraft.problemText`: wrap the three strings, e.g.
  `case .alreadyExists(let address): String(localized: "\(address) already exists. Pick a different address.")`.
- `serverTitle` and `serverPillText`: wrap every literal, including
  `String(localized: "Running · \(phpLabel)", comment: "Server status in the toolbar. The placeholder is “PHP 8.4”.")`.
  Leave `phpLabel` as it is.
- `submitPassword` and `submitTrustPassword`: wrap the four error strings.
- The three `message =` strings in `submitTrustPassword`, and the title
  `"Couldn’t set up password-free mode"`. Leave `"Could not prepare the password helper."`
  (it is command output for Show Details).
- Every `steps:` array in `runTask` calls and in `submitAdd` (about ten, not
  counting `#if DEBUG` code). For
  example: `["Pointing \(address) at this Mac", …]` becomes
  `[String(localized: "Pointing \(address) at this Mac", comment: "Progress step while adding a site."), …]`.
  `Phrases.makingCertificates` is already localized.
- Every `ErrorInfo(title:message:)` literal and every `Banner(text:)` literal,
  and the two `failure.title =` overrides.
- `addFailureMessage`: the four returned strings.
- `startFailure`: the titles and messages not already from `Phrases`.
- `commitGroupName`: give a blank name a localized default before PatchyKit
  sees it:

```swift
        case .new(let address):
            groups.createGroup(named: groupName, sites: address.map { [$0] } ?? [])
        case .rename(let id):
            groups.rename(id, to: groupName)
```

  with, above the `switch`:

```swift
        let trimmed = groupNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupName = trimmed.isEmpty ? String(localized: "Untitled Group", comment: "Name given to a sidebar group left unnamed.") : trimmed
```

- [ ] **Step 3: `SitePresentation.swift`**

Wrap every label, detail and issue text, `certShort` values, and
`"Offline while the server is stopped"`. Interpolated dates stay interpolated:
`String(localized: "Valid until \(date).", comment: "Certificate detail. The placeholder is a date.")`.

- [ ] **Step 4: `Sheets.swift`**

- `FolderPicker.choose`: default `prompt: String = String(localized: "Choose")`,
  and wrap `panel.message`.
- Every `SheetTitle(title:message:)` call with literal arguments, including the
  `TrustSheet` ternaries (wrap each branch).
- `AddSiteSheet.form`: `Text(problem ?? String(localized: "Type a name and Patchy adds .test. Or type a full address, like mysite.local."))`.
- `Text(verbatim: "Also answer at www.\(draft.finalAddress)")` →
  `Text(verbatim: String(localized: "Also answer at www.\(draft.finalAddress)", comment: "Checkbox. Keep “www.” as is."))`;
  same treatment for `"\(draft.finalAddress) might be a real website."` and
  `RemoveSheet`'s `"\(address) will reach the live website again."`.
- `DetailsDisclosure`: `Text(details.isEmpty ? String(localized: "Patchy didn’t report anything.") : details)`.
- `FolderSheet`: `Text(draft?.displayPath ?? String(localized: "No folder chosen yet"))`.
- `RefreshCertificatesSheet.bullet(_ text: LocalizedStringKey)` and
  `TrustSheet.check(_ text: LocalizedStringKey)`.

- [ ] **Step 5: `SettingsView.swift`**

Replace `SettingsNote` with:

```swift
private struct SettingsNote: View {
    private let text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(verbatim string: String) { text = Text(verbatim: string) }

    var body: some View {
        text
            .font(.system(size: 12))
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

Then change every `SettingsNote(text: "…")` with a literal (including
interpolated and ternary literals) to `SettingsNote("…")`, and the three with
runtime values to `SettingsNote(verbatim: …)`: `loginError`,
`Phrases.certificateList(…)`, and none other. Wrap
`loginError = String(localized: "macOS didn’t allow that: \(error.localizedDescription)")`.
`LabeledContent("Patchy", value: model.snapshot.patchyVersion ?? String(localized: "Not installed"))`.

- [ ] **Step 6: `MenuBar.swift`**

- `MenuBarLabel.description`: wrap the four strings (they are accessibility
  labels).
- `Text(model.isBusy ? (model.busy?.text ?? "Working…") : model.serverRunning ? "Server running" : "Server stopped")`:
  wrap `"Working…"`, `"Server running"` and `"Server stopped"`.

- [ ] **Step 7: `FirstRunViews.swift`, `SiteDetailView.swift`, `LogView.swift`, `MainView.swift`**

- `FirstSiteView`: `Text(draft.folder?.displayPath ?? String(localized: "The folder you choose"))`.
- `NotInstalledView.step(_:_:extra:)`: `_ text: LocalizedStringKey`.
- `SiteDetailView`: `Text(verbatim: "Also answers at \(www)")` →
  `Text(verbatim: String(localized: "Also answers at \(www)"))`, and the same
  for the real-address warning in `OverviewView`.
  `Text(model.groups.group(of: site.address)?.name ?? String(localized: "None"))`.
  `InfoRow.label: LocalizedStringKey`.
- `LogView.emptyTitle` and `emptyText`: wrap each literal. `emptyText`
  interpolates `kind.rawValue`, an English word; split it so each log kind is
  its own sentence:

```swift
    private var emptyText: String {
        if !log.lines.isEmpty {
            return kind == .errors
                ? String(localized: "Nothing in the errors log contains “\(log.filter)”.")
                : String(localized: "Nothing in the visits log contains “\(log.filter)”.")
        }
        return kind == .errors
            ? String(localized: "When PHP or the server reports a problem with this site, it shows up here.")
            : String(localized: "Open the site in your browser and each page request will show up here.")
    }
```

- `MainView`: `SidebarView.emptyNote(_ text: LocalizedStringKey)`.
  `BannerRow.actionTitle: LocalizedStringKey?` (its `Button(actionTitle, …)`
  then localizes). Wrap the literal `text:` arguments in `BannerStack` (the two
  compatibility banners and the stopped banner).

- [ ] **Step 8: Build, sync, test**

Run:
```bash
xcodebuild -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -configuration Debug -derivedDataPath build build 2>&1 | grep -E "error|BUILD"
python3 scripts/sync-catalog.py --prune
xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`. `testCopyHeldInStringsIsInTheCatalog` now
passes and every copy test passes unmodified. A copy test failure here means a
wrapped literal's text changed; restore it.

- [ ] **Step 9: Look for plain-String copy left behind**

Run:
```bash
grep -nE '(title|message|text|label|detail|summary|prompt|error)[A-Za-z]* *[:=] *"[A-Z][a-z]' PatchyUI --include=*.swift -r | grep -v "String(localized" | grep -v "#if DEBUG"
```
Expected: only lines that are not copy (debug-only code below `#if DEBUG` in
`AppModel.swift`, technical output). For each remaining line that is copy,
apply the rule above, then repeat Step 8.

- [ ] **Step 10: Commit**

```bash
git add PatchyUI PatchyUITests/LocalizationGuardTests.swift
git commit -m "Route the copy that travels as a String through the catalog"
```

---

### Task 8: Keep Patchy's output out of the catalog

The app follows progress and explains failures by matching phrases in Patchy's
and Apache's English output. Those phrases are inputs, not copy. They move into
one enum that says so, and a test keeps them from ever being localized.

**Files:**
- Create: `PatchyUI/PatchyOutput.swift`
- Modify: `PatchyUI/AppModel.swift` (every matched literal)
- Modify: `PatchyUI/Views/LogView.swift:17` (`LogLine.isBad`)
- Modify: `PatchyUITests/LocalizationGuardTests.swift`

**Interfaces:**
- Consumes: `LocalizationGuardTests.catalog()` and `repoRoot()` (Task 3).
- Produces: `enum PatchyOutput` with `static let` strings and `static let all: [String]`.

- [ ] **Step 1: Write the failing test**

Add to `LocalizationGuardTests`:

```swift
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
```

Run the tests. Expected: compile error, `PatchyOutput` not found.

- [ ] **Step 2: Create `PatchyUI/PatchyOutput.swift`**

```swift
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

    // Log lines.
    static let fatal = "Fatal"

    static let all = [
        started, stopped, startingApache, creatingCertificates, creatingConfig, syntaxOK, restartingApache,
        rollingBack, siteExists, serviceStuck, addressInUse, portHolders, trustUnsafe, trustUnsafeShort,
        terminalRequired, fatal,
    ]
}
```

- [ ] **Step 3: Use it everywhere the app matches output**

In `PatchyUI/AppModel.swift`, replace each literal with its constant, e.g.
`markers: [("Successfully started", 1)]` → `markers: [(PatchyOutput.started, 1)]`,
`output.contains("Rolling back")` → `output.contains(PatchyOutput.rollingBack)`,
`output.range(of: "Something else is listening on port 80/443:")` →
`output.range(of: PatchyOutput.portHolders)`. Leave `#if DEBUG` code as it is.

In `PatchyUI/Views/LogView.swift`:
`var isBad: Bool { text.contains(PatchyOutput.fatal) || … }`.

Run: `grep -nE 'contains\("|range\(of: "|markers: \[\("' PatchyUI -r`
Expected: no output outside `#if DEBUG` blocks.

- [ ] **Step 4: Build, sync, test**

Run:
```bash
xcodegen generate
xcodebuild -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -configuration Debug -derivedDataPath build build 2>&1 | grep -E "error|BUILD"
python3 scripts/sync-catalog.py --prune
xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`, copy tests unmodified (`startFailures` and
`addFailures` exercise the moved phrases).

- [ ] **Step 5: Commit**

```bash
git add PatchyUI/PatchyOutput.swift PatchyUI/AppModel.swift PatchyUI/Views/LogView.swift PatchyUITests/LocalizationGuardTests.swift
git commit -m "Keep the phrases matched in Patchy's output out of the catalog"
```

---

### Task 9: Say that Show Details is in English

Show Details reveals Patchy's and Apache's raw output, which is English in
every language. When the app runs in another language, the expanded area says
so first. English users see no change.

**Files:**
- Modify: `PatchyUI/Views/Sheets.swift` (`DetailsDisclosure`)
- Create: `PatchyUITests/DetailsDisclosureTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `DetailsDisclosure.showsEnglishNote(appLanguage: String?) -> Bool` (static).

- [ ] **Step 1: Write the failing test**

Create `PatchyUITests/DetailsDisclosureTests.swift`:

```swift
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
```

Run the tests. Expected: compile error, no member `showsEnglishNote`.

- [ ] **Step 2: Add the note**

In `DetailsDisclosure`, add:

```swift
    /// Patchy's output is English in every language. Say so when the app isn't showing English,
    /// or the raw text looks like a translation that went wrong.
    static func showsEnglishNote(appLanguage: String?) -> Bool {
        guard let appLanguage else { return false }
        return !appLanguage.hasPrefix("en")
    }
```

In `body`, inside `if expanded {`, before the `ScrollView`:

```swift
                if Self.showsEnglishNote(appLanguage: Bundle.main.preferredLocalizations.first) {
                    Text("Technical details from Patchy, in English.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondaryText)
                }
```

- [ ] **Step 3: Build, sync, test**

Run:
```bash
xcodegen generate
xcodebuild -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -configuration Debug -derivedDataPath build build 2>&1 | grep -E "error|BUILD"
python3 scripts/sync-catalog.py --prune
xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`; the catalog gained
`Technical details from Patchy, in English.`.

- [ ] **Step 4: Commit**

```bash
git add PatchyUI/Views/Sheets.swift PatchyUI/Localizable.xcstrings PatchyUITests/DetailsDisclosureTests.swift
git commit -m "Say that Show Details is in English when the app isn't"
```

---

### Task 10: Sweep, right-to-left, and the release gate

Prove nothing was missed by looking at the running app with every localized
string doubled, check right-to-left layout, make releases run the app tests,
and record what Phase 1 found but did not fix.

**Files:**
- Modify: whichever view files the sweep finds misses in
- Modify: `PatchyUI/Views/LogView.swift`, `PatchyUI/Views/Sheets.swift`,
  `PatchyUI/Views/FirstRunViews.swift`, `PatchyUI/Views/SettingsView.swift`
  (left-to-right pinning)
- Modify: `scripts/release.sh`
- Modify: `CLAUDE.md`
- Modify: `docs/design/specs/2026-10-14-localization-design.md`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing new for code.

- [ ] **Step 1: Doubled-strings sweep**

`-NSDoubleLocalizedStrings YES` repeats every string that went through the
catalog ("Add Site Add Site"). Copy that bypassed the catalog appears once,
which is exactly what to look for. Launch each state below, look at (or
screenshot) the window, sheets, menu bar menu and Settings, and list every
piece of copy that is **not** doubled. Addresses, paths, version numbers,
Patchy's output and log lines are expected to be single.

```bash
APP="build/Build/Products/Debug/Patchy UI.app/Contents/MacOS/Patchy UI"
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES -PatchyDebugSheet add -PatchyDebugName harbor.com
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES -PatchyDebugSheet addprogress
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES -PatchyDebugSheet adderror
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES -PatchyDebugSheet remove
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES -PatchyDebugSheet folder
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES -PatchyDebugSheet trust
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES -PatchyDebugSheet trustpassword
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES -PatchyDebugSheet password
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES -PatchyDebugSheet certs
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES -PatchyDebugSheet error
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugDemo YES -PatchyDebugTab errors
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugPhase empty
"$APP" -NSDoubleLocalizedStrings YES -PatchyDebugPhase notinstalled
```

Run one at a time; quit each before the next (`⌘Q`). Debug launch states never
run a Patchy command; `-PatchyDebugDemo YES` never writes the groups file.
Also open Settings (⌘,) in the first state and click through all five tabs.

Note what clips: the server pill (`maxWidth: 300`, one line), the sidebar
footer, the toolbar buttons, the Add Site sheet, the detail pane's action
buttons, the `InfoRow` label column (fixed 150 points). Don't fix clipping in
this phase; record it in Step 6.

- [ ] **Step 2: Fix every miss**

Apply Task 7's rule to each piece of copy the sweep found single. Then build,
`python3 scripts/sync-catalog.py --prune`, and run the tests.
Expected: `** TEST SUCCEEDED **`. Repeat Step 1 for the states that had misses
until there are none.

- [ ] **Step 3: Keep technical text left-to-right**

Under right-to-left languages SwiftUI mirrors the layout. Log lines, Patchy's
raw output and commands to paste are English and must stay left-to-right. Add
`.environment(\.layoutDirection, .leftToRight)` to:

- `LogView.lineList`'s `ScrollView`;
- `DetailsDisclosure`'s `ScrollView` (the raw details, not the note above it);
- the command `HStack` in `NotInstalledView` (the `brew install` well);
- the `HStack` holding `installCommand` in `PHPSettings`.

Check with forced right-to-left:

```bash
"$APP" -AppleTextDirection YES -NSForceRightToLeftWritingDirection YES -PatchyDebugDemo YES -PatchyDebugTab errors
"$APP" -AppleTextDirection YES -NSForceRightToLeftWritingDirection YES -PatchyDebugDemo YES -PatchyDebugSheet error
"$APP" -AppleTextDirection YES -NSForceRightToLeftWritingDirection YES -PatchyDebugPhase notinstalled
```

Expected: the window mirrors (sidebar on the right), while log lines, the
details text and the command read left to right. Also look at the Add Site
sheet (`-PatchyDebugSheet add -PatchyDebugName harbor`): the address field with
its grey `.test` suffix should read `harbor.test`, not `.testharbor`. If it
doesn't, pin that `HStack` in `AddressField` to `.leftToRight` too (an address
is always left-to-right).

- [ ] **Step 4: Make releases run the app tests**

In `scripts/release.sh`, after the `xcodegen generate` line and before
`==> archiving`, add:

```bash
echo "==> testing the app (copy, catalog and localization guards)"
xcodebuild test \
  -project "Patchy UI.xcodeproj" \
  -scheme "Patchy UI" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  | tail -3
```

`set -euo pipefail` at the top makes a failing test stop the release.

Run: `bash -n scripts/release.sh && echo ok`
Expected: `ok`. Do not run the release script.

- [ ] **Step 5: Tell CLAUDE.md how the app is localized**

In `CLAUDE.md`, under `## Commands`, add after the PatchyKit test lines:

```bash
# Test the app: copy, catalog and localization guards (hosted; runs in English)
xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build

# After changing any on-screen text: build, then merge new strings into the catalog
python3 scripts/sync-catalog.py --prune
```

Under `**PatchyUI/ (app target…)**` in `## Architecture`, add:

```markdown
- Copy is localized through `PatchyUI/Localizable.xcstrings` (36 languages planned; see `docs/design/specs/2026-10-14-localization-design.md`). Copy created as a `String` is written with `String(localized:)`; copy that depends on a count or a list lives in `Phrases`, and its plural forms live in the catalog, never in Swift. Phrases the app matches in Patchy's output live in `PatchyOutput` and are never localized.
```

- [ ] **Step 6: Final verification**

Run:
```bash
xcodegen generate
xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -5
python3 scripts/sync-catalog.py --check; echo "exit $?"
(cd PatchyKit && swift test 2>&1 | tail -2)
git diff main --stat -- PatchyUITests/PhrasesTests.swift PatchyUITests/SiteStatusCopyTests.swift PatchyUITests/AppModelCopyTests.swift
```
Expected: `** TEST SUCCEEDED **`; `exit 0`; PatchyKit passes; the copy-test
diff since Task 2's commit shows only the `relatedSites` test added in Task 6.
(Compare against Task 2's commit with
`git diff <task-2-commit> -- PatchyUITests/PhrasesTests.swift …` to confirm.)

Launch the app normally (no debug arguments) and check the main window, the
menu bar menu and Settings read exactly as before.

- [ ] **Step 7: Record what Phase 1 found and did not fix**

Append a section `## Carried out of Phase 1` to
`docs/design/specs/2026-10-14-localization-design.md` listing, in plain
sentences: each control that clipped in Step 1 (where, at what window width,
with which state), any right-to-left problem left for Phase 3, and any
string the guards or sweep showed that Phase 2's translators need warning
about. If a list is empty, say so.

- [ ] **Step 8: Commit**

```bash
git add PatchyUI scripts/release.sh CLAUDE.md docs/design/specs/2026-10-14-localization-design.md PatchyUI/Localizable.xcstrings
git commit -m "Finish Phase 1: sweep for missed copy, keep technical text left-to-right, test before releasing"
```

---

## Done when

- `xcodebuild test` passes with Task 2's copy tests unmodified (apart from
  Task 6's added test).
- `python3 scripts/sync-catalog.py --check` exits 0.
- The doubled-strings sweep shows no single copy.
- `pluralized` is gone, and no English plural, verb agreement or list joining
  is computed in Swift.
- The app, run normally in English, looks and reads exactly as before.

## Not in this phase

Translations, the glossary, `merge-translations.py`, per-language plural guard
tests, fixing clipped controls, localized release notes and appcast entries.
Those are Phases 2 and 3 of the spec.
