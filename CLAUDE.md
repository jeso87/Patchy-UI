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
swift test --filter VhostTests                 # one suite
swift test --filter changeFolderRestores       # one test, by name substring

# Print what the app reads from this Mac, without opening a window
"build/Build/Products/Debug/Patchy UI.app/Contents/MacOS/Patchy UI" --dump-state

# Regenerate the Xcode project after adding/removing files or changing build settings
xcodegen generate

# Redraw the app icon PNGs
swift Tools/make-icon.swift PatchyUI/Assets.xcassets/AppIcon.appiconset
```

`Patchy UI.xcodeproj` is generated from `project.yml` by XcodeGen. It is not committed (same convention as Shrinker Pro); run `xcodegen generate` after cloning. Change build settings in `project.yml`, not in Xcode, or they are lost on the next generate.

Debug builds accept launch arguments that open the app in a given state for checking layouts without running any command, e.g. `-PatchyDebugSheet add -PatchyDebugName example.com`, `-PatchyDebugSheet folder`, `-PatchyDebugTab errors -PatchyDebugSite <address>`, `-PatchyDebugPhase empty|notinstalled`. `-PatchyDebugDemo YES` replaces everything shown with made-up sites and groups, and `-PatchyDebugAppearance light|dark` forces the appearance; the README screenshots in `docs/screenshots/` were taken that way and must never show the developer's real sites. See `applyDebugLaunchState` in `AppModel.swift` for the full list.

## Architecture

Two layers. Keep anything that isn't UI in the package so it stays testable.

**`PatchyKit/` (local Swift package)** — no SwiftUI.
- `PatchyEnvironment` finds the Homebrew prefix and derives every path; `processEnvironment()` builds the PATH child processes need.
- Readers (`SiteReader`, `Vhost`, `HostsFile`, `CertificateReader`, `ServerReader`) build a `PatchySnapshot` straight from disk. Nothing parses `patchy list`/`status` output.
- `PatchyClient` is the only thing that changes anything. Every change runs the real `patchy` CLI, except `changeFolder`, which Patchy has no command for: it rewrites the site's vhost file, runs `patchy check`, restores the original on failure, then `patchy restart`.
- `ProcessRunner` gives `patchy` a pseudo-terminal for stdin (`patchy trust` refuses to run without one, and `patchy add` only asks the www question on one). Answers to `add`'s prompts are typed in advance in the order Patchy asks, followed by end-of-input; `AddressRules.addPromptAnswers` must stay in step with `prompt_www_alias` and `confirm_real_domain` in the patchy script.
- `AskpassServer` is how sudo gets a password with no terminal: it sets `SUDO_ASKPASS` to a script that reads a private named pipe, and the app writes the password into the pipe on demand. The password is never stored, logged or put in the environment.

**`PatchyUI/` (app target, SwiftUI, macOS 14+)**
- `AppModel` (`@Observable`, main actor) owns all state. `runTask` is the single path for changing commands: one at a time, progress steps advanced by matching markers in Patchy's output, then a fresh snapshot. Success is always judged by re-reading state, never by exit code.
- One sheet at a time, driven by `AppModel.sheet`; `SheetHost` renders it. A sudo password request (`passwordPrompt`) takes over whatever sheet is showing.
- Changes that touch routing go through `requireTrust`, which offers password-free setup first and then resumes the pending action.
- Sidebar groups (`SiteGroups` in PatchyKit) exist only in this app, stored in `~/Library/Application Support/Patchy UI/groups.json`. A site is in at most one group; deleting a group only ungroups its sites. Suggestions are offered, never applied. `-PatchyDebugGroups YES` shows demo groups in memory without writing that file.
- `SiteStatus` turns a site into the plain-language health text used by the list, detail pane and menu.
- Scenes: the main `Window`, a `MenuBarExtra` (standard menu), and `Settings`. Closing the window leaves the menu bar item running.

## Versioning, updates and releases

- **The app's version is the Patchy release it supports.** `MARKETING_VERSION` in `project.yml` must equal the Patchy version the build was tested against (currently 1.2.1). An app-only fix adds a fourth part (1.2.1.1). `PatchyCompatibility` compares the first three parts with the installed Patchy and the app shows a warning banner on a mismatch. When Patchy releases a new version: upgrade Patchy, re-read the script for changes to prompts and file layout, run the live test, then bump the version.
- **`CURRENT_PROJECT_VERSION` must rise with every release.** Sparkle compares it, not the marketing version.
- **Sparkle** comes in as a Swift package. The feed is `appcast.xml` at the repo root, served by GitHub Pages at the `SUFeedURL` in `project.yml` (`jeso87/Patchy-UI`). The EdDSA public key in `project.yml` is the same one Shrinker Pro uses; the private key lives in the developer's login keychain. Update checks are daily and not optional, by decision.
- **`scripts/release.sh`** tests, archives, exports with Developer ID, notarizes, builds the DMG and regenerates `appcast.xml`. It publishes nothing and fails if the installed Patchy doesn't match the version being released. It needs release notes at `docs/release-notes/<version>.md`. It mirrors the release script in `~/Developer/Apps/Shrinker Pro`, the developer's other MIT-licensed app, which is the reference for conventions here.
- Licensed MIT; the README is the public description of behaviour (network use, password handling). Keep it true when behaviour changes.

## Product decisions

- The design source is the Claude Design project "Patchy UI"; the brief it was built from is `docs/patchy-ui-product-brief.md`. Chosen variants: toolbar server controls (1a), name-your-first-site empty state (1d), big-address Add Site sheet (1f), standard menu bar menu (1g), rack icon filling the whole icon shape with no light border.
- The user always chooses a site's folder. The app never assigns `~/Websites/<address>` by default.
- UI copy uses plain terms (site, address, folder, server, password-free mode). Technical terms and raw Patchy output appear only behind "Show Details".
- Never put `.fixedSize(horizontal: false, vertical: true)` on text that sits outside a scroll view in the main window (banners, headers, footers). Its height then counts toward the window's minimum height, measured at the narrowest width, where it wraps to many lines. That once made the window's content 200 points taller than the window, pushing the top under the toolbar. Use `.lineLimit` there. It is fine inside scroll views and sheets.
- To check a layout change against the add flow without touching Patchy, launch a Debug build with `-PatchyDebugSheet add -PatchyDebugName <name> -PatchyDebugFakeAdd YES`, click Add Site, and compare the split view's size with the window's (System Events: `size of splitter group 1 of group 1 of window 1`).
- Text that contains a site address must use `Text(verbatim:)`; otherwise SwiftUI turns the address into a link.

## How Patchy works (what the GUI has to drive)

Patchy is a single ~1400-line zsh script at `/opt/homebrew/bin/patchy` (v1.2.1 installed; its README is at `/opt/homebrew/opt/patchy/README.md`). Read the script before designing any integration — it is the only spec. It has no JSON or machine-readable output mode.

Commands: `list`, `add <domain> [dir]`, `rm <domain>...`, `status`, `start`, `stop`, `restart`, `check`, `info`, `version`, `php <version>`, `pecl`, `refresh-certs`, `setup`, `trust`, `untrust`, `config`, `ini`, `errors [lines|-f]`, `logs`.

### State lives on disk, not in the CLI

Everything Patchy knows is derived from files, so the app can read state directly instead of parsing human-formatted CLI output (`$BREW` = `brew --prefix`, `/opt/homebrew` here):

| What | Where |
|---|---|
| Sites | one `$BREW/etc/httpd/sites/<domain>.conf` per site — the file's existence *is* the site |
| Docroot / www alias | `DocumentRoot "..."` and `ServerAlias` lines inside that conf |
| Certificates | `$BREW/etc/httpd/certs/<domain>.pem` and `<domain>-key.pem` (mkcert) |
| Logs | `$BREW/var/log/httpd/<domain>-{access,error}_log`, plus global `error_log` |
| Apache running | live process ID in `$BREW/var/run/httpd/httpd.pid` (Patchy itself asks `brew services`, which is too slow to poll) |
| Routing active | lines ending in `# patchy` in `/etc/hosts` (one `127.0.0.1` and one `::1` line per name) |
| Active PHP | the `LoadModule php…` line in `$BREW/etc/httpd/patchy.conf` (file is rewritten in full by Patchy — never edit it) |
| Trust enabled | `/usr/local/libexec/patchy-hosts` + `/etc/sudoers.d/patchy`; verify with `sudo -n /usr/local/libexec/patchy-hosts check` |

Mutations (`add`, `rm`, `start`, `stop`, `php`, `refresh-certs`) should still go through the `patchy` CLI so its ordering, rollback and hosts-sync logic is preserved.

### Constraints that shape the app

- **PATH.** Patchy runs `brew --prefix` on its first line and shells out to `brew`, `jq`, `mkcert`, `apachectl`, `php`, `openssl`. An app launched from Finder does not inherit the shell's PATH, so child processes need `/opt/homebrew/bin` (Apple silicon) or `/usr/local/bin` (Intel) added explicitly.
- **No App Sandbox.** The app has to spawn Homebrew binaries and read under the Homebrew prefix and `/etc/hosts`, which rules out sandboxing (and therefore the Mac App Store).
- **sudo with no terminal.** Editing `/etc/hosts` needs root. Without `patchy trust`, Patchy calls plain `sudo`, which has no TTY to prompt on when spawned from a GUI. `patchy trust` itself and the hosts step of `patchy setup` refuse to run unless stdin is a TTY. Getting a non-terminal user through first-run trust is the central onboarding problem.
- **Interactive prompts in `add`.** Two prompts behave differently when stdin is not a TTY:
  - The `Also serve www.<domain>? [Y/n]` prompt is skipped and defaults to yes, so every two-label domain (`foo.test`, `example.com`) silently gets a `www.` alias. There is no flag to decline.
  - The real-domain confirmation (any TLD other than `.test`/`.local`) always reads stdin and aborts on anything but `y`, so the app must write `y\n` to the process's stdin for real TLDs — after showing its own warning that the live site becomes unreachable on this Mac.
- **Editor commands are useless in a GUI.** `config` and `ini` open `$VISUAL`/`$EDITOR`/`nano`. Open the underlying files directly instead (`$BREW/etc/httpd/httpd.conf`; php.ini path from `php --ini`).
- **Streaming commands never exit.** `logs` and `errors -f` are `tail -f`; read the log files directly or manage the process lifetime.
- **Slow, blocking commands.** `start`/`restart` poll for up to 3 seconds; `add` and `rm` end with a restart; `php` relinks Homebrew formulae; `pecl` compiles extensions. All must run off the main thread with progress shown.
- **Exit codes are coarse.** Failures are mostly reported as text on stdout/stderr, and `brew services` can return 0 when Apache did not actually come up — confirm outcomes by re-reading state.
- **PHP switching** only works for versions already installed via Homebrew (`php`, `php@8.3`, …); Patchy prints the `brew install` command otherwise.

## This Mac is a live Patchy install

The developer's machine has a working Patchy setup with about 26 real client sites, Apache running, and trust enabled. `patchy stop`, `rm`, `refresh-certs`, `php`, `setup` and `untrust` all change that live environment. When testing, use a throwaway domain such as `patchyui-test.test` with a scratch docroot, clean it up afterwards, and ask before running anything that affects the existing sites or the server as a whole.
