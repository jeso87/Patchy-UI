# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Patchy UI is a native macOS app (Swift, built with Xcode) that puts a GUI on top of [Patchy](https://github.com/joeworkman/patchy), Joe Workman's Homebrew CLI for running local Apache + mod_php sites with HTTPS and friendly hostnames.

The product goal is to be the easiest possible on-ramp to Patchy and local web hosting. The audience is people who are not comfortable in a terminal, so every feature should hide the CLI, sudo, Apache and `/etc/hosts` concepts behind plain language, and failures should explain what to do next rather than surface raw shell output.

Patchy UI wraps Patchy; it does not replace or fork it. Patchy stays the source of truth for vhosts, certificates and hosts routing.

## Commands

`xcode-select` on this Mac points at the Command Line Tools, so a bare `xcodebuild` or `swift test` fails. Xcode is at `/Applications/Xcode.app`; prefix commands rather than changing the global setting:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Build the app (output: build/Build/Products/Debug/Patchy UI.app)
xcodebuild -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -configuration Debug -derivedDataPath build build

# Test the core library (Swift Testing, no app launch needed)
cd PatchyKit && swift test
swift test --filter ReadingTests               # one suite
swift test --filter resultLineGivesTheCode     # one test, by name substring

# Test the app: copy, catalog and localization guards (hosted; runs in English)
xcodebuild test -project "Patchy UI.xcodeproj" -scheme "Patchy UI" -destination 'platform=macOS' -derivedDataPath build

# After changing any on-screen text: build, then merge new strings into the catalog
python3 scripts/sync-catalog.py --prune

# Print what the app reads from this Mac, without opening a window
"build/Build/Products/Debug/Patchy UI.app/Contents/MacOS/Patchy UI" --dump-state

# Regenerate the Xcode project after adding/removing files or changing build settings
xcodegen generate

# Redraw the app icon PNGs
swift Tools/make-icon.swift PatchyUI/Assets.xcassets/AppIcon.appiconset
```

`Patchy UI.xcodeproj` is generated from `project.yml` by XcodeGen. It is not committed (same convention as Shrinker Pro); run `xcodegen generate` after cloning. Change build settings in `project.yml`, not in Xcode, or they are lost on the next generate.

Debug builds accept launch arguments that open the app in a given state for checking layouts without running any command, e.g. `-PatchyDebugSheet add -PatchyDebugName example.com`, `-PatchyDebugSheet folder`, `-PatchyDebugTab errors -PatchyDebugSite <address>`, `-PatchyDebugPhase empty|notinstalled`, `-PatchyDebugDetails YES` (Show Details starts expanded). `-PatchyDebugPatchyPath <path>` runs another Patchy, such as a clone at `~/Developer/Apps/patchy/bin/patchy`; `-PatchyDebugShare <address>` with `-PatchyDebugShareState starting|sharing|stable|failed` shows a site as shared without starting anything; `-PatchyDebugShareDomain <domain>` makes Share offer that domain's choices, as when one is connected; `-PatchyDebugSheet cloudflared` opens the install sheet. `-PatchyDebugDemo YES` replaces everything shown with made-up sites and groups, and `-PatchyDebugAppearance light|dark` forces the appearance; the README screenshots in `docs/screenshots/` were taken that way and must never show the developer's real sites. See `applyDebugLaunchState` in `AppModel.swift` for the full list. If a Debug build launches with no window, add `-ApplePersistenceIgnoreState YES`: it shares saved window state with the installed app, and a closed window stays closed.

## Architecture

Two layers. Keep anything that isn't UI in the package so it stays testable.

**`PatchyKit/` (local Swift package)** — no SwiftUI.
- `PatchyEnvironment` finds the Homebrew prefix and the `patchy` binary; `processEnvironment()` builds the PATH child processes need.
- The app talks to Patchy only through the CLI and its `--json` output (Patchy 1.3.0+); it never reads Patchy's files, which Joe treats as internal and changes between releases. `PatchyJSON` decodes the documents. `PatchyClient.snapshot()` runs `status --json`, `list --json` and `version --json` concurrently and builds a `PatchySnapshot`; it returns nil when Patchy can't answer (an older Patchy), and `version()` still parses the plain `patchy 1.2.1` so the version banner can explain.
- `PatchyClient` makes every change with `--json`: `add <site> <dir> --yes --www|--no-www`, `rm`, `folder`, `start`, `stop`, `restart`, `php`, `refresh-certs` (restarts a running server itself), `trust`. Each ends with one result line; `CommandResult.result`/`errorCode`/`details` read it. `PatchyError` holds the stable error codes the app matches; never match Patchy's English messages. With `--json` Patchy prints no progress, so each change shows a single progress step.
- `installCloudflared` is the one exception to running only `patchy`: the app runs `brew install cloudflared` itself when sharing finds it missing (Patchy's formula depends on it, so that's rare).
- `ShareSession` runs `patchy share <site> --json` for as long as a site is shared, outside `runTask`, and reads its JSON events (`ShareEvents`): `ready` gives the URL, mode and any username/password; `error` gives a code (`ShareFailure`). Stopping closes the watcher's stdin (TERM), then TERM again after 3 s; Patchy stops `cloudflared` itself. Sharing shows when `version --json` lists the `share` feature. With a domain from `patchy share setup` (`status` reports it), Share is a menu (`ShareCopy.choices`): the site's address open (the default) or with a password (`--auth`, a new password each share), Change Address… (`--name`, remembered per site), a random address on the domain with or without a password (`--temp`), or an anonymous trycloudflare link (`--anonymous`). Without a domain, Patchy makes an anonymous trycloudflare link.
- `ProcessRunner` runs commands with stdin closed and stdout/stderr merged; `PatchyJSON` skips anything around the JSON.
- `AskpassServer` is how sudo gets a password with no terminal: it sets `SUDO_ASKPASS` to a script that reads a private named pipe, and the app writes the password into the pipe on demand. Patchy then runs `sudo -A`, which also lets `patchy trust` run without a terminal. The password is never stored, logged or put in the environment.

**`PatchyUI/` (app target, SwiftUI, macOS 14+)**
- `AppModel` (`@Observable`, main actor) owns all state. `runTask` is the single path for changing commands: one at a time, one progress step, then a fresh snapshot. Success is judged by re-reading state; the error code only picks the explanation. A snapshot costs a few seconds of CPU, so the poll runs every 3 s while the app is active or the menu bar panel is open, and every 30 s otherwise; a read that finishes after a newer one is dropped.
- One sheet at a time, driven by `AppModel.sheet`; `SheetHost` renders it. A sudo password request (`passwordPrompt`) takes over whatever sheet is showing.
- Changes that touch routing go through `requireTrust`, which offers password-free setup first and then resumes the pending action.
- Sidebar groups (`SiteGroups` in PatchyKit) exist only in this app, stored in `~/Library/Application Support/Patchy UI/groups.json`. A site is in at most one group; deleting a group only ungroups its sites. Suggestions are offered, never applied. `-PatchyDebugGroups YES` shows demo groups in memory without writing that file.
- Shares (`AppModel.shares`) stop when the server is stopped, when a shared site disappears, or when the app quits; never on restart, since every add, remove, PHP switch and folder change restarts Apache and a tunnel survives that.
- `SiteStatus` turns a site into the plain-language health text used by the list, detail pane and menu.
- Copy is localized through `PatchyUI/Localizable.xcstrings` (36 languages; see `docs/design/specs/2026-10-14-localization-design.md` and the Phase 2 spec beside it). Copy created as a `String` is written with `String(localized:)`; copy that depends on a count or a list lives in `Phrases`, and its plural forms live in the catalog, never in Swift. The few phrases still matched as text (log lines) live in `PatchyOutput` and are never localized.
- Scenes: the main `Window` and `Settings`. The menu bar item is AppKit, not `MenuBarExtra`: `StatusItemController` owns an `NSStatusItem` and a borderless non-activating `NSPanel` hosting `MenuBarContent`, because SwiftUI has no way to open a `MenuBarExtra` from code and the global shortcut (`PanelShortcut`, Carbon `RegisterEventHotKey`, set in Settings › General) must. The panel takes typing without bringing the app forward. On macOS 27 icon clicks arrive through `expandedInterfaceDelegate` sessions; on 14–26 through the button's action; the shortcut shows the panel directly, since starting a session isn't public. On macOS 27 a click on our own icon also reaches the global click monitor, so `clickedOutside` ignores it unless a session needs ending. `MenuPanelList` decides what the panel lists. Closing the window leaves the menu bar item running.

## Versioning, updates and releases

- **The app's version is the Patchy release it supports.** `MARKETING_VERSION` in `project.yml` must equal the Patchy version the build was tested against (currently 1.4.0). An app-only fix adds a fourth part (1.3.0.1). `PatchyCompatibility` compares the first three parts with the installed Patchy and the app shows a warning banner on a mismatch. When Patchy releases a new version: upgrade Patchy, read `patchy docs` (the README's "Scripts and AI agents" and "JSON output" sections, and the error code table) for changes to the `--json` shapes, `schema` and error codes, run the live test, then bump the version.
- **`CURRENT_PROJECT_VERSION` must rise with every release.** Sparkle compares it, not the marketing version.
- **Sparkle** comes in as a Swift package. The feed is `appcast.xml` at the repo root, served by GitHub Pages at the `SUFeedURL` in `project.yml` (`jeso87/Patchy-UI`). The EdDSA public key in `project.yml` is the same one Shrinker Pro uses; the private key lives in the developer's login keychain. Update checks are daily and not optional, by decision.
- **`scripts/release.sh`** tests, archives, exports with Developer ID, notarizes, builds the DMG and regenerates `appcast.xml`. It publishes nothing and fails if the installed Patchy doesn't match the version being released. It needs release notes at `docs/release-notes/<version>.md`. It mirrors the release script in `~/Developer/Apps/Shrinker Pro`, the developer's other MIT-licensed app, which is the reference for conventions here.
- Licensed MIT; the README is the public description of behaviour (network use, password handling). Keep it true when behaviour changes.

## Product decisions

- The design source is the Claude Design project "Patchy UI"; the brief it was built from is `docs/patchy-ui-product-brief.md`. Chosen variants: toolbar server controls (1a), name-your-first-site empty state (1d), big-address Add Site sheet (1f), menu bar panel with search (1h, at 400 points wide so the footer fits; it replaced the standard menu, 1g), rack icon filling the whole icon shape with no light border.
- The user always chooses a site's folder. The app never assigns `~/Websites/<address>` by default.
- UI copy uses plain terms (site, address, folder, server, password-free mode). Technical terms and raw Patchy output appear only behind "Show Details".
- Never put `.fixedSize(horizontal: false, vertical: true)` on text that sits outside a scroll view in the main window (banners, headers, footers). Its height then counts toward the window's minimum height, measured at the narrowest width, where it wraps to many lines. That once made the window's content 200 points taller than the window, pushing the top under the toolbar. Use `.lineLimit` there. It is fine inside scroll views and sheets.
- To check a layout change against the add flow without touching Patchy, launch a Debug build with `-PatchyDebugSheet add -PatchyDebugName <name> -PatchyDebugFakeAdd YES`, click Add Site, and compare the split view's size with the window's (System Events: `size of splitter group 1 of group 1 of window 1`).
- Text that contains a site address must use `Text(verbatim:)`; otherwise SwiftUI turns the address into a link.
- The app ships in 36 languages (`translations/<lang>.json`, merged into the catalog by `scripts/merge-translations.py`; glossary at `docs/localization-glossary.md`). Adding or rewording on-screen text means updating every language file: build, `python3 scripts/sync-catalog.py --prune`, add the key to all 35 files (`python3 scripts/catalog-context.py --missing <lang>` lists what a language lacks), `python3 scripts/merge-translations.py`. Rewording an existing string changes its key, so also remove the old key from all 35 files, or the merge fails on it. The app tests fail until every language matches the catalog, including a language file that was edited but not merged.
- Arabic, Hebrew and Persian strings that start with a name, an address or a placeholder begin with an invisible right-to-left mark (U+200F), and folder-path placeholders there are preceded by a left-to-right mark (U+200E). Keep them when editing those files; without them SwiftUI lays the sentence out left to right. To see the mirrored layout from the command line, add `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES` (setting `-AppleLanguages` alone doesn't mirror the window).

## How Patchy works (what the GUI has to drive)

Patchy is a zsh script, `/opt/homebrew/bin/patchy`, with its commands in `libexec/*.zsh` beside it (v1.4.0 installed; source clone at `~/Developer/Apps/patchy`). `patchy docs` prints its README, which is the spec for scripts and apps: read its "Scripts and AI agents" and "JSON output" sections and the error code table before changing an integration.

Joe's rules for callers, which the app follows:

- Add `--json` to every command that takes it. Output is then only JSON, nothing prompts, and failures carry a stable `error` code. `message` is for people and may change.
- Read state through `status --json` and `list --json`, never Patchy's files (vhosts, certs, `patchy.conf`, the share folder). They are internal and change between releases (1.3.0 moved the share login to `~/.config/patchy/share`).
- `add` takes `--yes` (real domains) and `--www`/`--no-www` instead of prompts.
- `sudo_required` means a password is needed and there was no `SUDO_ASKPASS`; the app always provides one through `AskpassServer`.
- `share` runs until stopped: read lines until `ready`, stop with SIGTERM. Don't run `logs` or `errors -f`; the app tails the log files `list --json` names (`logs.error`/`logs.access`).
- Every top-level object has `"schema": 1`; the number goes up only when a change could break a caller.

### Constraints that shape the app

- **PATH.** Patchy runs `brew --prefix` on its first line and shells out to `brew`, `jq`, `mkcert`, `apachectl`, `php`, `openssl`, `cloudflared`. An app launched from Finder does not inherit the shell's PATH, so child processes need `/opt/homebrew/bin` (Apple silicon) or `/usr/local/bin` (Intel) added explicitly.
- **No App Sandbox.** The app has to spawn Homebrew binaries and read log files under the Homebrew prefix, which rules out sandboxing (and therefore the Mac App Store).
- **sudo with no terminal.** Editing `/etc/hosts` needs root. Without `patchy trust`, Patchy needs sudo for every routing change; with `SUDO_ASKPASS` set it runs `sudo -A`. mkcert's first `-install` is the exception: macOS shows its own password dialog for that.
- **Editor commands are useless in a GUI.** `config` and `ini` open `$VISUAL`/`$EDITOR`/`nano`.
- **Slow commands.** `status --json` and `list --json` take 2–3 s each (they shell out per site); `start`/`restart` poll for up to 3 s; `add`, `rm` and `folder` end with a restart; `php` relinks Homebrew formulae; `pecl` compiles extensions. All run off the main thread.
- **Exit codes and `brew services` can mislead.** Confirm outcomes by re-reading state.
- **PHP switching** only works for versions already installed via Homebrew (`php`, `php@8.3`, …); Patchy fails with `php_not_installed` otherwise.
- **The Homebrew formula runs `patchy setup` after every install or upgrade.** Its `/etc/hosts` step needs sudo and fails when run without a terminal; that's harmless when routing is already set up.

## This Mac is a live Patchy install

The developer's machine has a working Patchy setup with about 26 real client sites, Apache running, and trust enabled. `patchy stop`, `rm`, `refresh-certs`, `php`, `setup` and `untrust` all change that live environment. When testing, use a throwaway domain such as `patchyui-test.test` with a scratch docroot, clean it up afterwards, and ask before running anything that affects the existing sites or the server as a whole.
