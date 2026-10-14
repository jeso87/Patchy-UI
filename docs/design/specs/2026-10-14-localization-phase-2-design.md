# Localization Phase 2 — Design

**Date:** 2026-10-14
**Status:** Draft, for approval
**Follows:** `docs/design/specs/2026-10-14-localization-design.md` (Phase 1, merged)
**Reference:** Shrinker Pro's Phase 2 (`~/Developer/Apps/Shrinker Pro`,
`docs/design/specs/2026-09-21-localization-phase-2-design.md`), followed except
where this document says otherwise.
**Scope:** The 35 translations, the glossary, and the checks that keep them honest.

## Summary

Phase 1 left Patchy UI English-only by design: 328 catalog entries, 15 of them
plural, no grammar left in Swift, Patchy's own output kept out of the catalog,
and guard tests that fail when the catalog and the code drift apart. Phase 2
fills the catalog in: 35 more languages, about 11,500 strings.

Nothing about the app's behaviour changes. Every line of this phase is data and
the machinery to check it.

## Goals

- 35 languages beside English, Sparkle's set exactly.
- Each language its own file, reviewable, revertible and re-runnable without
  touching another language or English.
- Every placeholder preserved, and preserved in order: a dropped `%@` is a
  crash or a corrupted sentence, and a swapped one silently says the wrong
  thing, both invisible to anyone who can't read the language.
- Plural forms per language taken from the platform at test time, never from a
  table written by hand.

## Non-goals

- Changing any English string. Phase 1's copy tests still govern.
- Translating Patchy's output, `--dump-state`, the README, the website or the
  release notes. Release notes and the appcast are Phase 3.
- Layout work. The four controls that clip at double length (Refresh
  Certificates button, Change Folder labels, Settings toolbar, the Add Site
  "Opens at" line) and the unpinned folder paths under right-to-left stay
  Phase 3. German, arriving first, shows how much real translations need, which
  is better evidence than doubled English.

## The mechanism, taken from Shrinker Pro

**No translator edits the catalog.** Each language is written as
`translations/<lang>.json`: a flat key maps to a string, a plural key to an
object of plural categories. `scripts/merge-translations.py`, ported from
Shrinker Pro, splices each file into `PatchyUI/Localizable.xcstrings` as text,
so English and its comments survive byte for byte. A bad language is one file
to delete; re-running one language disturbs no other.

**Plural categories come from the platform.** A probe in the guard tests
builds a tiny `.stringsdict` per language and records which categories whole
numbers actually reach. Every plural entry must carry that set plus `other`.
Shrinker Pro measured the shape of it (Arabic five, Slovenian four, Polish,
Russian and Ukrainian `one`/`few`/`many`, the CJK languages `other` alone);
the test, not that table, is the authority. `zero` is never required, and
Arabic's translator must supply it by hand, as in Shrinker Pro.

## Where Patchy UI differs

**Placeholders are counted, and numbered when there are several.** Shrinker
Pro compared each translation's placeholders as a set. Twelve Patchy UI keys
carry two or more placeholders, several of the same kind:

    Patchy %@ is installed, but this Patchy UI was made for Patchy %@. …
    %@ is ready. Its folder is %@.
    %@ and %@ and %@ now reach the live websites again.

A set check passes a translation that drops one `%@` of two, and nothing can
tell whether a language swapped the installed and supported versions. So for
a key with two or more placeholders, every translation must use numbered
placeholders (`%1$@`, `%2$@`) covering exactly English's positions and types,
each once. The translator then states the order instead of the test guessing
it. Keys with one placeholder keep the plain form and are checked by count and
type.

**Translators get the code, not just the comment.** 225 of the 328 entries
have no comment; many are button titles whose meaning is obvious only on
screen ("Repair", "New", "Current", "Back"). Rather than write 225 comments, a
script prints every key with its English, its comment and the source file and
line the build extracted it from. A translator unsure of a word reads the code
around it. Comments still win where they exist.

**The glossary names product and technical words to leave alone.** Patchy,
Patchy UI, PHP, Apache, Homebrew and the `.test` and `.local` endings stay as
they are, as do URLs and commands. The glossary also fixes the app's plain
vocabulary (site, address, folder, server, password-free mode, certificate,
group, "pointing at this Mac") and tells translators to take macOS's own words
for standard actions and places: Reveal in Finder, Settings, Check for
Updates, Quit, Choose, and the Applications and Utilities folders, which the
not-installed screen sends people to and which macOS itself translates
("Programme › Dienstprogramme" in German).

## Verification

Two gates per language, both required.

**Structural**, as guard tests:

- Every language present in the catalog carries every key
  (`merge-translations.py --check`).
- Every plural entry carries its language's probe-derived categories plus
  `other`.
- Placeholders as above: flat entries with one placeholder keep its count and
  type; entries with several use numbered placeholders covering English's
  exactly; plural variants may drop the count where English's `one` does
  ("Refresh certificates for your site?"), but no variant invents one and the
  entry as a whole keeps them all.
- Merging leaves every English value untouched.
- Every glossary term still occurs in the catalog, so the glossary can't
  quietly describe strings that no longer exist.
- The built app contains an `.lproj` for every language.

**Editorial**, one reviewer per language: glossary terms render consistently,
standard actions use macOS's words, the register is consistent and matches
Sparkle's own translation in that language (Sparkle's update dialog ships
inside the app), and no string is so much longer than English that it worsens
a known clip.

## Order

German first, alone, all the way through: write it, merge it, build, launch the
app in German and look, run the guards, and write a side-by-side note for a
person to read. German has the longest compounds, so it is the language most
likely to expose a layout problem, and it is the one pass where the pattern
gets a human check before it is repeated 34 times.

Then the other 34, one language per agent so each sees the whole catalog and
stays consistent with itself, each followed by its editorial review.

## Unchanged

Patchy, Patchy UI, PHP, Apache, Homebrew, `.test`, `.local`, every web address,
path, URL and command shown to copy, Patchy's output (`PatchyOutput`),
`UserDefaults` keys, `groups.json`, SF Symbol names.

## Costs

**This is the expensive phase.** About 11,500 strings plus an editorial review
per language, roughly three times Shrinker Pro's Phase 2 because Patchy UI
explains more: error sheets, password-free setup, the first-run screens.

**Quality is unverifiable for most of the 35.** The structural gate catches
everything that would crash, corrupt or drop text. It can't catch a
translation that is merely wrong or sounds foreign. The editorial gate narrows
that; it doesn't close it. Patchy UI's audience is people who aren't
comfortable in a terminal, so a stilted error message costs more here than in
most apps. The mitigation is the same as Shrinker Pro's: the repo is public,
and a correction is a one-line change to one language's file.

**Every future text change costs 35 translations.** From the first merged
language on, adding or rewording a string means updating every
`translations/<lang>.json`; `merge-translations.py --check` fails until they
are. That is the price of the feature, paid on every release.
