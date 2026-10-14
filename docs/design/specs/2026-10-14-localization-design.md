# Localization — Design

**Date:** 2026-10-14
**Status:** Approved for planning
**Scope:** The `Patchy UI` app target. `PatchyKit`, `--dump-state` and everything
Patchy itself prints stay English.
**Reference:** Shrinker Pro's localization (`~/Developer/Apps/Shrinker Pro`,
`docs/design/specs/2026-09-20-localization-design.md` and the Phase 2 spec).
This design follows it wherever the two apps are alike and says so where they
are not.

## Summary

Patchy UI ships in English only: no string catalog, no `.lproj`, not one
`String(localized:)` in about 3,550 lines of app Swift. This design takes it to
the same **36 languages** as Shrinker Pro, in the same three phases, reusing
Shrinker Pro's catalog scripts and guard tests.

The difference from Shrinker Pro is where the text lives. Shrinker Pro's UI was
mostly bare `Text("…")` literals, which localize the moment a catalog exists.
Patchy UI routes most of its plain-language copy through `String` values built
in `AppModel` and `SiteStatus` — status summaries, the server pill, the footer,
progress steps, every error sheet's title and message — and hands them to
`Text(_: String)`, the overload that does **not** localize and is invisible to
`SWIFT_EMIT_LOC_STRINGS`. A catalog alone would translate the chrome and leave
the parts users actually read in English. Phase 1 is mostly about that.

## Goals

- The 36 languages Sparkle ships, identical to Shrinker Pro's set, so the app
  and its update dialog never disagree:

      ar  ca  cs  da  de  el  en  es  fa  fi  fr  he  hr  hu  is
      it  ja  ko  nb  nl  nn  pl  pt-BR  pt-PT  ro  ru  sk  sl
      sv  th  tr  uk  vi  zh-Hans  zh-Hant  zh-HK

- No English grammar left in Swift: plurals, verb agreement, list joining and
  sentence fragments move into the catalog.
- English output unchanged by Phase 1, and provably so.
- Everything that is matched, parsed or shown as "the exact message from Patchy"
  stays byte-identical English.

## Non-goals

- An in-app language picker. macOS's per-app language setting (System Settings ›
  General › Language & Region › Applications) works once `KNOWN_REGIONS` is set.
- Translating Patchy's output. It is English-only, and the app shows it only
  behind Show Details.
- Localizing the README, website or announcement. Release notes and the appcast
  are Phase 3, as in Shrinker Pro.

## Mechanism

`Localizable.xcstrings` in `PatchyUI/`, with, on the `Patchy UI` target in
`project.yml` only:

    DEVELOPMENT_LANGUAGE: en
    SWIFT_EMIT_LOC_STRINGS: YES
    KNOWN_REGIONS: [en, ar, ca, cs, … zh-HK]

Reused from Shrinker Pro, adapted for paths: `sync-catalog.py` (merges
build-emitted keys into the catalog and reports orphans — `xcodebuild` does not
do this outside the Xcode IDE), `catalog_format.py`, `merge-translations.py`
(per-language `translations/<lang>.json` files spliced in as raw text), and
`localize-appcast.py`.

## What stays English, and why it matters here

- **Patchy's output and the markers matched against it.** `runTask` advances
  progress by matching strings like `"Successfully stopped"`, and
  `startFailure` reads `"Address already in use"` and port-holder lines. Those
  literals are inputs, not copy. They must never enter the catalog; a
  translated marker would silently break progress and error diagnosis. Phase 1
  separates them visibly from display text.
- **`PatchyKit`.** Its strings are command output (`"Could not read …"`) shown
  only behind Show Details, alongside Patchy's own English. It has no SwiftUI
  and no bundle, and gains neither. The one exception is `"Untitled Group"`,
  a default group name that gets saved; the app should pass in a localized
  default rather than PatchyKit choosing one.
- **`--dump-state`.** A diagnostic dump for the developer, like Shrinker Pro's
  CLI. English, unconditionally.
- **Product and technical names:** Patchy, Patchy UI, PHP, Apache, Homebrew,
  site addresses, file paths, `brew install …` commands shown to copy.
- **Stored data:** group names the user typed, `UserDefaults` keys, `groups.json`.
- **Info.plist.** It holds only the product name and the copyright line, so
  there is no `InfoPlist.xcstrings` (Shrinker Pro has one, empty).
- **Pre-existing grammar slip.** The group header's VoiceOver label reads
  "1 need attention" today. Phase 1 corrects it to "1 needs attention"; this is
  the one deliberate change to English.

## Phase 1 work, by kind

### String-typed copy (the bulk)

Every `String` that reaches the screen becomes localizable at the point it is
written. Two routes, chosen per call site:

- Where the value is only displayed, change the type to `LocalizedStringResource`
  (or build it with `String(localized:)`), so the literal is extracted and
  resolved.
- Where views take `title: String` / `text: String` parameters (`Sheets.swift`
  `title`, `message`, `step`; `SettingsNote`; `MainView.emptyNote`;
  `FirstRunViews`), change the parameter to `LocalizedStringKey` or
  `LocalizedStringResource` so literals at the call site are extracted.

Known sources: `SiteStatus` (all labels, details, summaries, issues),
`AppModel` (`serverTitle`, `serverPillText`, `footerText`, `phpLabel`, every
`runTask` step list — 13 of them — every `ErrorInfo` and `Banner`),
`LogView.emptyTitle`/`emptyText`, `MenuBar.description`, `DetailTab.title`
(currently `rawValue.capitalized`, which ties the label to an identifier).

A source-level guard against new `Text(someString)` copy was considered and
dropped: no pattern separates display copy from addresses, paths and log lines
without a long allowlist that would rot. The pseudolocalization sweep (below)
catches the same mistake visually, because copy that bypasses the catalog is
the copy that does not double.

### Plurals and agreement

`pluralized(_:_:)` in `Theme.swift` is English's plural rule compiled into
Swift (`count == 1 ? singular : singular + "s"`), and is used 11 times. Several
call sites also hand-agree a verb: `"need\(n == 1 ? "s" : "")"`. Each becomes one
catalog entry with `%lld` and plural variations, covering the whole phrase so
surrounding words can inflect: "%lld sites", "%lld sites need attention",
"Expires in %lld days", "Copy %lld Lines", "Making new certificates for %lld
sites…". `pluralized` is then deleted.

The worst case is the stop banner in `AppModel.stop()`:

    "\(names) now reach\(real.count > 1 ? "" : "es") the live website\(real.count > 1 ? "s" : "") again."

It inflects a verb and a noun by hand around an English-joined list. It becomes
one plural entry over the count, with the names as a separate argument.

### Lists

Three hand-joined lists: the stop banner's `" and "` / `" and N more"`, the
port holders in `startFailure` (`", "` plus `is`/`are`, `it`/`them`), and the
certificate list in Settings (`", "` plus a more-tail). As in Shrinker Pro,
these are truncated enumerations, not grammatical lists, so `ListFormatter`
would change English; the separator and the "and N more" tail become catalog
entries and English stays as it is. `startFailure`'s is/are and it/them become
plural variations on the holder count.

### Show Details says it is English

Show Details reveals Patchy's and Apache's own output, which is English in
every language. In a translated app that looks like a bug unless it is
labelled. Wherever the details disclosure appears (error sheets, the add and
task progress views), the expanded area carries one localized line above the
raw text: "Technical details from Patchy, in English." The line is shown only
when the app is running in a language other than English
(`Bundle.main.preferredLocalizations.first != "en"`), so English users see no
change.

### Dates and numbers

`expires.formatted(date: .abbreviated, …)` already follows the locale.
Interpolated `Int`s become `%lld` and are formatted per locale by the catalog.

### Right-to-left

SwiftUI mirrors the layout for `ar`, `he` and `fa`. Items to check rather than
assume: the `·` separators in composed status lines (fine if each line is one
catalog entry), the address field in the Add Site sheet with its `.test`
suffix (an LTR address inside an RTL sentence), and the log view, which must
stay LTR because it shows Apache's English output.

## Verification

Patchy UI has no app test target today — the 3 test files are all in
`PatchyKit`. Shrinker Pro's Phase 1 leaned on existing copy tests to prove
English was unchanged; here those tests have to be written first.

- Add a `PatchyUITests` unit-test target in `project.yml`.
- **Before** touching any copy, record the English: tests over `SiteStatus`
  (every certificate state and day count around 1, 30, 31), the server pill and
  footer across counts 0/1/2, every `ErrorInfo` `startFailure` produces, and
  the stop banner for 1, 2 and 3+ sites. These must pass unmodified after
  Phase 1.
- `LocalizationGuardTests`, ported from Shrinker Pro: catalog keys match what
  the build emits in both directions; after Phase 2, every key in all 36
  languages, none `needs_review`, and plural categories checked against the
  platform's CLDR data at test time rather than a hand-written table.
- A guard that `runTask` markers and `startFailure`'s matched strings are not
  catalog keys.
- Pseudolocalization (`-NSDoubleLocalizedStrings YES`) over the debug launch
  states CLAUDE.md lists, looking for clipping. The server pill (`maxWidth:
  300`, one line), sidebar footer, toolbar buttons and the Add Site sheet are
  the likely spots. Keep the CLAUDE.md rule in mind: fixes outside scroll views
  use `.lineLimit`, never `.fixedSize(horizontal: false, vertical: true)`.

## Phasing

**Phase 1 — infrastructure and restructuring.** App test target and English
copy tests first; catalogs and build settings; String-typed copy converted;
plurals, lists and fragments moved into the catalog; marker separation;
`sync-catalog.py` wired up. English only, no behavior change.

**Phase 2 — translation.** A Patchy UI glossary (site, address, folder, server,
password-free mode, Repair, certificate, "pointing at this Mac" — the plain
terms CLAUDE.md fixes for English need fixed renderings too), then the 35
languages as `translations/<lang>.json`, then the full guard tests.

**Phase 3 — proving it.** Pseudolocalization fixes, German/Japanese/Arabic
screenshots, localized release notes and appcast entries.

## Costs

Every future UI text change becomes 36 translations, every release. Patchy UI's
copy is longer and more explanatory than Shrinker Pro's (error sheets,
password-free setup, first run), so the catalog will be larger and that cost
higher. The 35 translations are LLM-produced without native review; the
glossary, the plural guard and the screenshot pass reduce that risk without
removing it.

## Carried out of Phase 1

Phase 1 is done. A doubled-strings sweep (`-NSDoubleLocalizedStrings YES`, and
`-NSAccentuateLocalizedStrings YES` for Settings) found no copy that bypasses the
catalog: the main window, every sheet, the log view, the empty and not-installed
states, all five Settings tabs and the menu bar menu. These are what it found and
did not fix.

**For Phase 3 — controls that clip at double length.**

- The Refresh Certificates sheet's default button truncates ("Refresh Certific…").
- The Change Folder sheet's label column is a fixed 70 points; "Current" and
  "New" wrap onto two lines.
- The Settings toolbar overflows: with longer tab names, Password-Free and About
  move behind the » menu. The Settings window is a fixed 500 points wide.
- The Add Site sheet's "Opens at https://…" line truncates in the middle, by
  design, but a longer phrase leaves less of the address visible.

Everything else wrapped or reflowed: banners, sheet messages, Settings notes and
the first-site view.

**For Phase 3 — right-to-left.** Under forced right-to-left the window mirrors
correctly. Log lines, Show Details' raw output, the commands to paste and the
Add Site address field are pinned left-to-right. Folder paths shown as plain
text (the detail pane's Folder row, the Change Folder sheet, the folder card) are
not pinned and render with their slashes reordered; they should get the same
treatment, along with any other place a path or address sits alone in a `Text`.

**For Phase 2 — notes for translators.**

- The debug-only launch states show hard-coded English progress steps; that is
  debug code, not a missed string.
- The step numbers on the not-installed screen are a catalog key (`%lld.`).
  Translators should leave it as is unless their language writes ordinals
  differently.
- Keys with several placeholders (`%@ and %@ and %@ now reach the live websites
  again.`) need positional placeholders (`%1$@`) wherever a language reorders
  them.

**Not localization, noticed along the way.** With groups present and no sites
(`-PatchyDebugPhase empty`), the sidebar shows "No sites match “”." over an empty
Other Sites header. The empty header comes from the drag-and-drop change that
keeps Other Sites visible whenever groups exist; the message comes from the
overlay checking `visibleSites` rather than whether a filter is set.
