# Installing Total CMS 3 when adding a site, and updating Composer sites

Date: 2026-11-12
Status: design, awaiting approval

## Why

Most Patchy users come from the Total CMS 3 community. Starting a new Total CMS site today means opening a terminal, running `composer create-project` with the right environment variables, then adding the site in Patchy UI and pointing it at the new `public/` folder. The developer does this for every new client site. Patchy UI can do the whole thing from the Add Site sheet, which fits its goal of hiding the terminal from people who aren't comfortable in one.

Keeping those sites up to date is the same story: `composer update` in a terminal. A button in the site's details removes that too.

## Goals

1. An opt-in setting that adds an "Install Total CMS 3" checkbox to the Add Site sheet.
2. Ticking it installs Total CMS 3 with Composer into the folder the user chose, then adds the site in Patchy with that folder's `public/` as the site's folder.
3. Composer is installed through Homebrew when it's missing, the same way `cloudflared` is for sharing.
4. A button in the site's details runs `composer update` for any site that uses Composer. It reads "Update Total CMS" when the project requires Total CMS, and "Update Packages" otherwise.

## Non-goals

- Installing Node. Total CMS's frontend pipeline builds only when Node is present; without it the install still succeeds (see below).
- The Total CMS zip install, other CMSs, or a general "starter template" system.
- Running Total CMS's setup wizard, creating its admin account, or entering a license. Total CMS does all of that in the browser.
- Updating only `totalcms/cms`. The update deliberately runs a plain `composer update` so plugins update too (the developer's decision).

## Anti-goals

- The checkbox is unticked by default, so nobody installs Total CMS by accident. The setting is on by default (changed from off after the first build, by the developer's request) and can be turned off.
- Nothing about Total CMS may leak into how Patchy itself is driven. Patchy stays the source of truth for sites; the app still talks to Patchy only through its CLI and `--json`.
- A failed Total CMS install must never leave a half-added site in Patchy.
- No raw Composer output outside Show Details.

## Part 1: the setting

Settings › General gains a toggle, on by default:

> **Offer to install Total CMS 3 when adding a site**
> Note under it: "Adds a checkbox to New Site that sets up a Total CMS 3 project in the folder you choose. Needs Composer, which Patchy UI installs for you if it's missing."

(Wording is a starting point; final copy is the builder's, in the app's plain style.) Stored with `@AppStorage`/`UserDefaults`. It only controls whether the Add Site sheet shows the checkbox; it does not affect the update button (Part 4).

## Part 2: the Add Site sheet

When the setting is on, the sheet shows an **Install Total CMS 3** checkbox, unticked each time the sheet opens. Ticking it reveals the install options, preset to the developer's defaults:

| Option | Control | Choices | Default | Environment variable |
|---|---|---|---|---|
| Layout | pop-up | Whole site (`root`), Under /tcms/ (`subpath`) | root | `TCMS_LAYOUT` |
| Starter | pop-up | None, Minimal, Blog, Business, Portfolio | None | `TCMS_STARTER` (`none`, `minimal`, `blog`, `business`, `portfolio`) |
| Frontend tools (Vite) | checkbox | on/off | off | `TCMS_FRONTEND` (`1`/`0`) |
| Templates in Git | checkbox | on/off | on | `TCMS_GIT_TEMPLATES` (`1`/`0`) |

- Starter and Frontend apply to the root layout only (per Total CMS's installation docs); they are disabled when Layout is `subpath`. Pass `TCMS_STARTER=none TCMS_FRONTEND=0` in that case.
- Labels and a one-line explanation per option are the builder's to write; keep the raw values (`root`, `subpath`) behind Show Details or out of sight.
- `TCMS_GIT_TEMPLATES` is real (confirmed by the developer with screenshots of the `totalcms/totalcms` post-install prompts) but not yet in the docs. The installer's prompt is "Manage Site Builder templates with git?": it keeps templates in a `builder/` folder at the project root, edited in an IDE and deployed with git, and makes the dashboard template editor read-only; the installer's own default is no. The app always passes `0` or `1` explicitly. The live test should still confirm `builder/` appears with `1` and not with `0`.
- Starter descriptions, from the installer's prompt, for the option's help text: none (empty install, set everything up yourself), blog (post listing, single post, about page), business (service pages and contact form), minimal (a single page and clean layout), portfolio (project pages and contact info).
- When the box is ticked, show a small note: addresses ending in `.test` get every Total CMS Pro feature with no license (from Total CMS's license docs; `.local` does not). Show it only when the address doesn't already end in `.test`. (Builder's call on exact placement.)

### The folder

With the box ticked, the folder the user picks is the **project folder**, and it must be **empty** (`composer create-project` refuses a non-empty folder). The folder card should say so ("Choose an empty folder for the project"); the open panel already lets people create a new folder. If the chosen folder isn't empty, the sheet says so under the card and Add Site stays disabled. A folder containing only `.DS_Store` counts as empty (builder: delete `.DS_Store` before running Composer, or confirm Composer tolerates it).

The app still never chooses or names the folder itself (existing product rule).

The "Opens at https://…" line is unchanged. After the add, the site's folder in Patchy is `<project folder>/public`.

## Part 3: what Add Site does

Steps, shown in the sheet's existing step list (`AddDraft.steps`), each with one plain line:

1. **Installing Composer** — only if `composer` isn't found under the Homebrew prefix. Runs `brew install composer`, without asking first (unlike the cloudflared sheet, the user already asked for this by ticking the box).
2. **Installing Total CMS 3** — runs, in the project folder's parent:
   `TCMS_LAYOUT=… TCMS_STARTER=… TCMS_FRONTEND=… TCMS_GIT_TEMPLATES=… composer create-project totalcms/totalcms <folder> --no-interaction`
   with the PATH from `PatchyEnvironment.processEnvironment()`, but Composer is run **under the server's PHP**, the version `status --json` reports as active (`php.active`): `<prefix>/opt/<php formula>/bin/php <prefix>/bin/composer …`, not whatever `php` happens to be linked. Composer picks package versions for the PHP running it and Total CMS's post-install script runs under it, so this keeps the project matched to the PHP Apache serves it with. (Developer's decision.) The same applies to Part 4's update.
3. **Setting up the site** — the existing `patchy add <address> <folder>/public …` path, unchanged, including password-free setup (`requireTrust`), the password prompt, and Finish Setup.

Then, on success: the existing success path (select the site, banner), plus the app **opens the site in the browser** so Total CMS's setup wizard is the first thing the user sees. (The developer's call was not made explicitly; this is the agreed guess.)

### Frontend without Node

If Frontend is on and Node isn't present, Total CMS installs the files without building. The install still counts as success. The success banner (or a second line under it) says the frontend tools are installed but not built yet, and can be built later; the command (`tcms builder:frontend`, or `npm run build` in the project — builder to confirm from the installed project) goes behind Show Details or in the banner's details. How to detect it: check for `node` on the app's PATH before running, rather than parsing Composer's output.

### Failure

- If step 1 or 2 fails, no site is added. The sheet's existing error phase shows a plain message ("Composer couldn't install …" / "Total CMS couldn't be installed …"), with the command and Composer's output behind Show Details. Error explanations are chosen by step, never by matching Composer's English output.
- The folder is left as Composer left it, so the user can look at it. The message says so. Since it's no longer empty, "Edit and Try Again" returns to the form, where the non-empty-folder check asks for an empty folder.
- If step 3 fails (Patchy), the existing add-failure handling applies. **Finish Setup and any retry must not run Composer again**: once Total CMS installed successfully, the retry only runs `patchy add` with `<folder>/public`. Keep that state in `AddDraft`.
- Success of step 2 is judged by `public/index.php` existing in the folder afterwards (root layout) or `public/tcms/index.php` (subpath), not only by Composer's exit code — same principle as re-reading state for Patchy.

## Part 4: Update button in the site's details

For every site, the app checks for `composer.json` in the site's folder. If there is none **and the site's folder is named `public`**, it checks the folder above (Total CMS keeps it there). It never looks further up, so an unrelated `composer.json` in, say, `~/Sites` is never updated. Show Details on the result names the folder that was updated. This is the site's own folder, not one of Patchy's internal files, so reading it is allowed.

- `composer.json` whose `require` includes `totalcms/cms` → button **Update Total CMS**.
- Any other `composer.json` → button **Update Packages**.
- No `composer.json` → no button.

Shown regardless of the Part 1 setting. Placement is the builder's call; the natural spot is the Overview's folder row or the action row beside Reveal in Finder in `SiteDetailView`.

Clicking it runs `composer update --no-interaction` in the folder that holds `composer.json`, through `runTask` (one change at a time, progress shown), installing Composer through Homebrew first if it's missing. On success, a banner: "Total CMS and its plugins are up to date" / "Packages updated" (builder's wording). On failure, an error sheet with a plain message and Composer's output behind Show Details. No Patchy command runs and no restart is needed.

Detection runs when a site is selected (or with the snapshot; builder's call), off the main thread, and must stay cheap: two file reads per site, no Composer invocation.

## Constraints and risks for the builder

- **Homebrew's composer formula depends on the `php` formula.** On a Mac where Patchy runs a versioned PHP (`php@8.3`), `brew install composer` may install and link the latest `php`. Check, on a test install, whether that changes which PHP Patchy's Apache uses (it should not, since Patchy points Apache at a specific module path, but verify) and whether it disturbs `patchy php`. If it does, stop and raise it before shipping.
- Total CMS needs PHP 8.2+. The app knows the server's PHP before running anything, so with the box ticked and the active PHP below 8.2, the sheet says so in plain words (and that PHP can be switched in Settings/the site's PHP control, wherever the app already offers it) and Add Site stays disabled. (My call, following the developer's decision to use the server's PHP.)
- Composer needs network access and can take a minute or more. The step's progress line should say this can take a minute.
- `composer update` on a project with private plugin repositories may need credentials Composer already has in `~/.composer/auth.json`. The app passes the user's `HOME` so Composer finds it; it never asks for or stores those credentials.
- Composer runs without a terminal: `--no-interaction`, stdin closed (`ProcessRunner` already does this), and `COMPOSER_NO_INTERACTION=1` for safety.
- Keep non-UI logic in `PatchyKit` (Composer location, `composer.json` detection, building the create-project command and environment), with Swift Testing coverage, as the architecture asks. `installComposer` sits beside `installCloudflared` and its comment there ("the one place the app runs Homebrew") needs updating.
- All new on-screen text goes through the localization workflow in CLAUDE.md: all 36 languages, RTL marks where needed. "Total CMS" and "Composer" are product names and are not translated.
- README: describe the new network use (Composer downloads packages from Packagist and Total CMS's servers) and the opt-in setting.
- Debug launch arguments, following existing ones: e.g. `-PatchyDebugTCMS YES` (setting on), and a fake install like `-PatchyDebugFakeAdd` so the layout can be checked without running Composer.
- Live testing on this Mac must use a throwaway address (`patchyui-test.test`) and a scratch folder, cleaned up afterwards, per CLAUDE.md.

## Decided by the developer

- A setting in Settings (not a hidden keyboard shortcut), on by default; first built off, switched on at the developer's request.
- Missing Composer is installed through Homebrew, like cloudflared.
- The four options above, with defaults `root`, `none`, frontend off, Git templates on.
- Frontend without Node: install without building and say it can be built later.
- Composer runs under the server's active PHP, for both install and update.
- The user picks or creates an empty folder; `public/` inside it becomes the site's folder.
- An update button for Composer sites, running plain `composer update`; "Update Total CMS" when Total CMS is detected, "Update Packages" otherwise.

## Calls made in this document (not explicitly decided)

- Composer is installed without a confirmation sheet during Add Site.
- The site opens in the browser after a successful Total CMS add.
- The `.test` licensing note.
- `composer.json` is looked for in the site folder, and in its parent only when the site folder is `public`; the update button ignores the setting.
- The Add Site sheet blocks a Total CMS install when the server's PHP is below 8.2.
- A failed install leaves the folder in place.
- Success of the install is judged by `public/index.php` existing.
