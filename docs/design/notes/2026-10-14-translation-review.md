# The 34 translations: review notes

**Status:** Machine-translated and machine-reviewed. **Awaiting native readers.**
**Follows:** `2026-10-14-german-review.md` (German, the pilot).

Each language was written by one translator working from the catalog's
English, comments and source lines, the glossary, macOS's own words in that
language (AppKit, Finder's folder names, Dock, Terminal), Sparkle's
translation inside the app, and Shrinker Pro's reviewed file in the same
language. A second, separate reviewer then read the file against the English
and fixed it in place. Both passed a structural check of every key, plural
form and placeholder before the merge, and the app's guard tests passed after
it.

This is the list a native reader should start from: the decisions that were
judgement calls, and the wordings each reviewer still wasn't sure of.

## Decisions that cut across languages

**Register follows Sparkle, and in four languages that disagrees with
something else.** The glossary rule is that Patchy UI addresses the reader the
way Sparkle's update dialog (which ships inside the app) does. In:

- **Catalan** Sparkle says *vós*; macOS and Shrinker Pro say *tu*. Sparkle's
  Catalan also has typos.
- **Romanian** Sparkle says *tu* (inconsistently); macOS and Shrinker Pro say
  *dvs.*
- **Simplified and Traditional (Taiwan) Chinese** Sparkle says 您; Shrinker
  Pro says 你.
- **Croatian** Sparkle says *ti*; Shrinker Pro says *Vi*.

Each first followed Sparkle. On 2026-10-15 the developer decided these five
match Shrinker Pro instead (Catalan *tu*, Romanian *dvs.*, Croatian *Vi*,
Chinese 你), and the files were rewritten; the glossary records the exception.
Romanian's buttons became formal imperatives too, as in Shrinker Pro
(„Reparați”, „Afișați detaliile”).

Hong Kong Chinese is the exception the other way: Sparkle's zh_HK is
colloquial Cantonese, so the file uses 你 like Sparkle but standard written
Chinese like macOS and Shrinker Pro.

**Right-to-left (Arabic, Hebrew, Persian).** SwiftUI decides a paragraph's
direction from its first letter, so a sentence that starts with "Patchy", an
address or a number came out left to right and scrambled. Those strings now
begin with an invisible right-to-left mark; folder paths get a left-to-right
mark so `~/Sites/x` isn't reversed; the list separator carries a
right-to-left mark so lists of addresses run right to left; and a bare
`https://` followed by text gets a left-to-right mark so `://` stays with
`https`. Checked on screen in all three languages with the layout mirrored.
Persian has no macOS localization, so Finder, Terminal, "Applications ›
Utilities" and the key names stay in English there, as a Persian user's Mac
shows them.

**Finder's folder names are this Mac's.** Several languages' Finder now says
"Apps" rather than "Applications" (Danish *Apps › Hjælpeapps*, Dutch *Apps ›
Hulpprogramma's*, Catalan *Apps › Utilitats*, Finnish *Apit › Lisäapit*,
Swedish *Appar › Verktyg*, Norwegian *Apper › Verktøy*). Each file uses the
names from `SystemFolderLocalizations` on this Mac. German's
*Programme › Dienstprogramme* still matches.

**"Set Up" vs "Settings…".** In Korean, Simplified and Traditional Chinese,
the plain word for Set Up is the same as macOS's Settings…, and the Set Up
button sits inside Settings. Those files use a different verb (설정하기,
开启, 開始設定).

**Patchy UI's grammatical gender** follows Sparkle's update dialog where the
language needs one (Italian feminine, Polish masculine); elsewhere sentences
add "the app" or "this version of" to avoid it.

## Watch in the layout (Phase 3)

Labels longer than German's in the tight spots:

- Greek **Open in Browser**, about 31 characters against German's 17 (it's
  AppKit's own wording).
- Finnish **Restart** (*Käynnistä uudelleen*), 19 against 11.
- The **About** Settings tab in Slovak and Slovenian (*O aplikácii*,
  *O aplikaciji*) against German's *Über*.
- The **Password-Free** Settings tab in French (*Sans mot de passe*) and
  Korean (암호 없는 모드).

French and Slovak shortened the Refresh Certificates sheet button and the
Copy Update Command banner button, since the surrounding text already says
what they do.

## Each language

Register, Finder's folder names, what the reviewer changed, and what is still
worth a native reader's eye.

| | Register | Applications › Utilities | Reviewer changed |
|---|---|---|---|
| ar | masculine imperatives, as Sparkle | التطبيقات › الأدوات المساعدة | 41 (37 right-to-left) |
| ca | tu (Shrinker Pro) | Apps › Utilitats | 10 |
| cs | vy | Aplikace › Utility | 11 |
| da | du | Apps › Hjælpeapps | 7 |
| el | εσείς | Εφαρμογές › Βοηθήματα | 19 |
| es | tú (Spain) | Aplicaciones › Utilidades | 6 |
| fa | شما | Applications › Utilities | 47 (40 right-to-left) |
| fi | sinä | Apit › Lisäapit | 6 |
| fr | vous | Applications › Utilitaires | 5 |
| he | gender-neutral noun forms | יישומים › כלי עזר | 38 (about 32 right-to-left) |
| hr | Vi (Shrinker Pro) | Aplikacije › Uslužni programi | 33 |
| hu | Ön | Alkalmazások › Segédprogramok | 5 |
| is | þú | Applications › Utilities | 6 |
| it | tu | Applicazioni › Utility | 18 |
| ja | です/ます | アプリケーション › ユーティリティ | 6 |
| ko | 합쇼체 | 응용 프로그램 › 유틸리티 | 14 |
| nb | du | Apper › Verktøy | 17 |
| nl | je | Apps › Hulpprogramma's | 13 |
| nn | du | Apper › Verktøy | 29 |
| pl | ty | Aplikacje › Narzędzia | 16 |
| pt-BR | você | Aplicativos › Utilitários | 31 |
| pt-PT | formal third person | Aplicações › Utilitários | 6 |
| ro | dvs. (Shrinker Pro) | Aplicații › Utilitare | 14 |
| ru | вы | Программы › Утилиты | 7 |
| sk | vy | Aplikácie › Utility | 14 |
| sl | vi | Aplikacije › Pripomočki | 15 |
| sv | du | Appar › Verktyg | 27 |
| th | คุณ | แอปพลิเคชัน › ยูทิลิตี้ | 6 |
| tr | siz | Uygulamalar › İzlenceler | 7 |
| uk | ви | Програми › Утиліти | 11 |
| vi | bạn | Ứng dụng › Tiện ích | 14 |
| zh-Hans | 你 (Shrinker Pro) | “应用程序” › “实用工具” | 7 |
| zh-Hant | 你 (Shrinker Pro) | 「應用程式」›「工具程式」 | 14 |
| zh-HK | 你 | 應用程式 › 工具程式 | 16 |

### Worth a native reader's eye

The name of the ⌫ key in "Remove Site (Delete)" and of Return is unconfirmed
in almost every language: macOS's resources rarely name them, so most files
follow Apple's help-page wording from memory. It isn't repeated below.

- **ar** — the `zero` plural forms use a singular noun; "الفتح أيضًا على www.%@" is stiff; check the right-to-left marks on a real Arabic Mac, especially "PHP %1$@  (%2$@)".
- **ca** — the register (above); "portar" for "reach the live website"; "Treballant…" for Working, against the "S'està…" style elsewhere.
- **cs** — "stojí na Patchy" for "runs on Patchy"; "Dostupný" for Reachable; *přesměrovat* (folder) vs *směrovat* (address).
- **da** — "det rigtige websted" can read as "the correct website"; "%lld mere"; "Sæt op" vs Apple's "Konfigurer".
- **el** — "Open in Browser" length (above); Απόρριψη for Dismiss; προβάλλει for "serves files".
- **es** — "Eliminar sitio (tecla Eliminar)" repeats itself; "Disponible" for Reachable; the sheet title "Evita las peticiones de contraseña".
- **fa** — اکنون نه vs حالا نه for Not Now; ساختن vs the more formal ایجاد for Create.
- **fi** — Restart length (above); "Salasanaton" as a bare-adjective tab name; "kumosit" echoes the Cancel button.
- **fr** — "Redirection de %@ vers ce Mac…" vs "pointe vers ce Mac" elsewhere; "installateur" vs Apple's "programme d'installation".
- **he** — האתר החי for live website (האתר באינטרנט is plainer); מציג for "serves files".
- **hr** — feminine agreement when an address is the subject ("harbor.test je dodana"); "povezano" in the group suggestion.
- **hu** — "élő webhely" (vs *éles* or *valódi*); "Elérhető itt" vs "Elérhető"; "a(z)" before a number.
- **is** — "lykilorðslaus hamur" as the fixed name; "Aðgengilegur" as a row label; first-person progress lines ("Set upp…") could read as commands.
- **it** — feminine Patchy UI; "A capo" vs "Invio" for Return; "collegato" may read as a network connection.
- **ja** — 件 for counting sites; full-width ： against Sparkle's half-width; 表示 for "serves files".
- **ko** — 무제 그룹 vs 이름 없는 그룹; 암호 묻기 건너뛰기 is stiff; 실제 사이트 next to 사이트.
- **nb** — "trenger tilsyn" is Apple's phrase but can sound medical; "Lar %@ peke til"; the tab "Uten passord" vs "passordfri modus".
- **nl** — "Pauzeer/Hervat live bijwerken"; "Kan … niet" vs "Kon … niet" in error titles.
- **nn** — "Denne Patchy UI vart laga" (vs "Denne versjonen av"); "Fråkopla" for Offline; "Lag gruppa «%@»".
- **pl** — "Restart" as a noun on the toolbar; "Ukryj" for Dismiss; the 5+ form of the not-pointing banner mixes verb numbers.
- **pt-BR** — "voltou a abrir o site na internet"; "Pular os pedidos de senha".
- **pt-PT** — "Verificar novamente" (a shorter "de novo" would need a matching mention changed); "A pasta é %@"; "repõe-no".
- **ro** — the register (above); "Scapă de cererile de parolă" may be too colloquial.
- **ru** — "сайт ведёт на этот Mac" (strictly the address points); "Обновляется" as the Live label.
- **sk** — "podrobnosti" vs AppKit's "detaily"; the 5+ verb mix; About tab width (above).
- **sl** — the 5+ verb mix; "Dosegljivo tudi na" reads as a status on the checkbox; *uporablja* vs *prikazuje* for "serves files".
- **sv** — Dismiss and Close are both "Stäng"; "Offline" and "Live" stay as loanwords.
- **th** — the Settings tab ไม่ใช้รหัสผ่าน vs the mode name; commas in lists; สด for Live.
- **tr** — "Onarılmalı" vs "Onarım gerekiyor"; "gidiyor" is colloquial; the two titles of the password-free sheet use different verb forms.
- **uk** — "Доступний" as a row label; macOS treated as feminine.
- **vi** — only Repair and Show Details are quoted in sentences; "Bỏ qua" for Dismiss also means "skip".
- **zh-Hans** — "另外 N 个" is shared between address lists and the status line; 提供 for "serves files"; 更改为 next to 当前 in the Change Folder sheet.
- **zh-Hant** — 檢查更新項目⋯ (Sparkle's words) now differs from Shrinker Pro's 檢查更新⋯; terse labels 網址, 目前 / 新的; 過濾 vs 篩選.
- **zh-HK** — 到訪 for Visits; 瀏覽網址 beside the address; 證書 vs 憑證.

## Fixed in the English source

The Polish reviewer found the comment on "Secure · %lld days" claimed that 31
takes the singular in Polish; it doesn't (31 is Polish's "many"). The comment
now names Russian and Ukrainian, where 21 and 31 do.
