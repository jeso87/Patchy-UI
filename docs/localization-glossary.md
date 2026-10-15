# Localization glossary

This glossary fixes the vocabulary every one of Patchy UI's 35 translations
must keep consistent. It is written before any translation exists, so it
governs the work rather than describing it afterwards.

A translator working string by string has no way to notice that "site" has
arrived three different ways inside one language's catalog: each string was
translated alone and nothing connected them. The terms below are that
connection.

Patchy UI's audience is people who aren't comfortable in a terminal. Every
string was written in plain words on purpose (CLAUDE.md: "site, address,
folder, server, password-free mode"). Keep that register: everyday words a
non-technical person uses, never the technical term the English avoided.

## Terms

- **site** — one local website the app runs. The app's central noun. Use one everyday word for "website" throughout; not "vhost", not "project", not "domain".
- **address** — what a person types in the browser to open a site, like `harbor.test`. Not "domain", "hostname" or "URL", which the English deliberately avoids.
- **folder** — where a site's files live on the Mac. Use the word Finder uses for a folder.
- **server** — the thing that runs every site at once, which people start, stop and restart. Not "Apache" (a name shown only in Settings › About) and not "service".
- **password-free mode** — the one-time setup that stops macOS asking for a password on every change. A fixed name: render it the same way every time it appears, in sheets, Settings and the sidebar footer.
- **Mac password** — the password someone uses to log in to this Mac. Not "administrator password" or "sudo", and not the word for an Apple Account password.
- **certificate** — what makes `https://` work without a browser warning. Use the word browsers use in that language for a site's security certificate.
- **secure connection** — the detail pane's label for the certificate row. Plain words, not "SSL" or "TLS".
- **Repair** — a toolbar button that restarts the server to fix addresses that stopped pointing at this Mac. A short verb; other strings refer to it by name ("Repair fixes it"), so the button and those mentions must match exactly.
- **pointing at this Mac** — whether an address leads to this Mac or to the real internet. Plain words, the same phrase wherever it appears.
- **live website** — the real site on the internet, as opposed to the local copy. Used with "real web address", the warning that a name like `harbor.com` may be a real website.
- **group** — a set of related sites in the sidebar, chosen by the person. **Other Sites** is the sidebar heading for sites in no group.
- **Show Details** — the link that reveals Patchy's raw output, with **Hide Details** as its opposite. Other strings refer to it by name ("Show Details has the exact message from Patchy"), so the link and those mentions must match exactly.
- **sharing** (and **Share**) — putting a site on a public link so someone else can open it from anywhere. Use the everyday verb people use for sharing a link, not "publish" or "deploy". **Stop Sharing** is its opposite and is referred to by name ("until you stop sharing"), so the button and those sentences must match.
- **public link** — the address someone else opens to see a shared site. "Link" in the everyday sense, as in "Copy Link".

## Never translate

- **Patchy** and **Patchy UI**. Product names. Keep them in Latin script in every language, including Arabic, Persian, Hebrew, Thai and the CJK languages, as Apple does with its own product names.
- **PHP**, **Apache**, **Homebrew**, **mkcert**, **Cloudflare**, **cloudflared**, **WordPress**. Product names.
- **.test** and **.local**, every address (`mysite.test`, `harbor.com`), every path, URL and command (`brew install …`, `patchy trust`). They are typed, not read.
- **https://** wherever it appears.
- Placeholders: `%@`, `%lld` and their numbered forms. See the rules below.

## Platform conventions

Where a string names something macOS already names, use macOS's own word in
that language, not a translation of the English. A German Mac user expects
"Im Finder zeigen", not a literal "Im Finder aufdecken", because that is what
Finder says.

Read the system's own localized resources on this Mac rather than guessing:
AppKit's `.loctable` files, Finder's strings, and Sparkle's bundled `.lproj`
inside the built app. These apply here:

- **Reveal in Finder**, **Open in Browser**, **Copy**, **Cancel**, **Close**, **Back**, **Continue**, **Not Now**
- **Settings…** and **Check for Updates…** (Sparkle ships its own translation of the latter; match it)
- **Quit Patchy UI** (the system's word for Quit, then the product name)
- **Choose…**, **Choose Folder…**, **Change…** (keep the ellipsis convention the language's macOS uses; German puts a no-break space before it)
- **Terminal**, and the folders **Applications › Utilities** on the not-installed screen. macOS shows these folders under translated names in Finder ("Programme › Dienstprogramme" in German); use those names, or people won't find Terminal.
- **Open Patchy UI when I log in** in Settings › General follows the system's own Login Items wording.

**Match the term, not the sentence it came from.** Apple's string was written
for Apple's noun; copying it whole can carry grammar that doesn't agree with
ours. Keep Apple's word and fix the agreement to our noun.

**Register follows Sparkle's translation in the same language.** Sparkle's
update dialog ships inside Patchy UI already translated. If it addresses the
reader informally (German "du"), so does Patchy UI; if formally, so does Patchy
UI. A change of register halfway through the app's own update dialog reads as
two different products.

Exception, by decision: where Sparkle disagrees with the developer's other app,
Shrinker Pro, Patchy UI matches Shrinker Pro, so the two apps speak to the
reader the same way. That is Catalan (*tu*), Romanian (*dvs.*), Croatian (*Vi*),
and Simplified and Traditional (Taiwan) Chinese (你). Sparkle's update dialog
keeps its own wording.

## Placeholders

- A key with **one** placeholder: keep it, as `%@` or `%lld`, anywhere in the sentence.
- A key with **two or more** placeholders: always use numbered placeholders in the translation, `%1$@`, `%2$@`, `%3$lld`, one for each of English's in English's order, each exactly once, even if the order doesn't change. The number says which value goes where; the guard tests check it.
- In a **plural** entry, a variant may leave the number out where it reads naturally ("Refresh certificates for your site?"), but the language's other variants must still carry it.
