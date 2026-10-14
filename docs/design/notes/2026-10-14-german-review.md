# German review — screenshots and every string, English beside German

The German pilot for Patchy UI's translation (Phase 2, Task 6). German is the
first of 35 languages and the one a person checks before the pattern is
repeated 34 times. This note and the screenshots beside it are meant to be read
without running anything.

**Awaiting review.** Nothing here has been read by a German speaker yet.

Source: `translations/de.json` (328 keys, 15 plural). Merged into
`PatchyUI/Localizable.xcstrings` by `scripts/merge-translations.py`, never by
hand.

## Screenshots

Each image shows the same screen in English (left) and German (right), with the
same made-up demo sites, in light appearance. Nothing in them is real data.

| File | Screen |
| --- | --- |
| `01-main.jpg` | Main window: sidebar, site details, toolbar |
| `02-add-site.jpg` | Add Site sheet, with the "might be a real website" warning |
| `03-add-failed.jpg` | Adding a site failed |
| `04-remove-site.jpg` | Remove a site |
| `05-change-folder.jpg` | Change a site's folder |
| `06-password-free-setup.jpg` | Password-free setup, first step |
| `07-password-free-password.jpg` | Password-free setup, password step |
| `08-password-prompt.jpg` | The password prompt during a change |
| `09-refresh-certificates.jpg` | Refresh Certificates sheet |
| `10-error-with-details.jpg` | An error with Show Details open. In German only, a line says the technical details are in English. |
| `11-errors-log.jpg` | A site's error log tab (empty) |
| `12-first-site.jpg` | First-run screen: name your first site |
| `13-patchy-not-installed.jpg` | Patchy isn't installed yet |
| `14`–`18-settings-*.jpg` | Settings: General, PHP, Certificates, Password-Free, About |

The menu bar menu isn't pictured; its strings are in the list below.

Things a reviewer can't see in the screenshots: the progress steps shown while
a change runs, banners after an action, and most error messages. Those are all
in the list below.

## Conventions this translation follows

**Register: informal "du".** Sparkle's own German translation ships inside the
app ("Möchtest du die neue Version jetzt laden?", "Du bist auf dem neuesten
Stand!"), and German macOS addresses the user informally. "Sie" here would
change register inside the app's own update dialog.

**`⍽` marks a no-break space** (U+00A0) before an ellipsis, as German macOS
writes it ("Einstellungen⍽…").

**Platform words, taken from macOS on this Mac**, not translated:

| English | German | Where macOS says it |
| --- | --- | --- |
| Settings… | Einstellungen⍽… | AppKit `MenuCommands.loctable` |
| Choose… | Wählen⍽… | AppKit `Common.loctable` |
| Rename… | Umbenennen⍽… | AppKit `Document.loctable` |
| Cancel | Abbrechen | AppKit `Common.loctable` |
| Close | Schließen | AppKit `Document.loctable` |
| Copy | Kopieren | AppKit `MenuCommands.loctable` |
| Not Now | Später | AppKit `Document.loctable` |
| Check for Updates… | Nach Updates suchen⍽… | Sparkle `de.lproj/Sparkle.strings` |
| Applications › Utilities | Programme › Dienstprogramme | `SystemFolderLocalizations/de.lproj` |
| Reveal in Finder | Im Finder zeigen | Finder's own wording |

**Glossary terms** (`docs/localization-glossary.md`), fixed once:

| Term | German |
| --- | --- |
| site | Website (die) |
| address | Adresse |
| folder | Ordner |
| server | Server |
| password-free mode | passwortfreier Modus; the Settings tab is "Ohne Passwort" |
| Mac password | Mac-Passwort |
| certificate | Zertifikat |
| secure connection | Sichere Verbindung |
| Repair | Reparieren |
| pointing at this Mac | zeigt auf diesen Mac |
| live website | Live-Website |
| real web address | echte Webadresse |
| group / Other Sites | Gruppe / Weitere Websites |
| Show Details / Hide Details | Details einblenden / Details ausblenden |

Never translated: Patchy, Patchy UI, PHP, Apache, Homebrew, `.test`, `.local`,
addresses, paths, commands.

## Worth a native speaker's eye

- **"Remove Site (Delete)"** is the tooltip on the Remove button and names the
  Delete key. German keyboards label it ⌫ and Apple's German help calls it
  "Rückschritttaste"; this uses that. A German Mac user may expect a different
  name.
- **"Reparieren"** as a toolbar button and in sentences that refer to it
  ("„Reparieren“ behebt das"). Check it reads naturally both ways.
- **"Gerade nicht"** for "Not right now" as the answer to "Erreichbar"
  (reachable). Short, but maybe too casual.
- **"Live-Website"** for the real site on the internet, as opposed to the local
  copy.
- **"Zeilenschalter"** for the Return key ("drücke den Zeilenschalter"). Apple's
  German documentation uses it; many people just say "Eingabetaste".

## Layout

No German string clipped in any screenshot: the Settings toolbar holds all five
tabs, the Refresh Certificates button fits, and the Change Folder labels fit.
The four controls that clipped when English was doubled (Phase 1's sweep) all
held with real German.

## Every string

Key in English, then German. Plural entries list each form. `%@` and `%lld`
are values filled in at run time; `%1$@`, `%2$@` are the same, numbered so
German can place them freely. The grey line is the context the translation was
made against.


**%@ already exists. Pick a different address.**  
→ %@ gibt es schon. Wähle eine andere Adresse.  

**%@ and %@**  
→ %1$@ und %2$@  
<sub>A shortened list of web addresses: the first four, then “N more”.</sub>

**%@ and %@ and %@ now reach the live websites again.**  
→ %1$@, %2$@ und %3$@ führen jetzt wieder zu den Live-Websites.  
<sub>Banner after stopping the server. Two real web addresses, then “N more”.</sub>

**%@ and %@ now reach the live websites again.**  
→ %1$@ und %2$@ führen jetzt wieder zu den Live-Websites.  
<sub>Banner after stopping the server. Both placeholders are real web addresses.</sub>

**%@ are already using the ports this server needs (80 and 443). Quit them, then start the server again.**  
→ %@ belegen bereits die Ports, die dieser Server braucht (80 und 443). Beende sie und starte den Server dann erneut.  
<sub>Why the web server couldn't start. The placeholder is a list of two or more program names.</sub>

**%@ is a real web address. While the server runs, this Mac opens your local copy and can’t reach the live website. Stop the server to see the live site again.**  
→ %@ ist eine echte Webadresse. Solange der Server läuft, öffnet dieser Mac deine lokale Kopie und erreicht die Live-Website nicht. Stoppe den Server, um die Live-Website wieder zu sehen.  

**%@ is already using the ports this server needs (80 and 443). Quit it, then start the server again.**  
→ %@ belegt bereits die Ports, die dieser Server braucht (80 und 443). Beende das Programm und starte den Server dann erneut.  
<sub>Why the web server couldn't start. The placeholder is a program name, e.g. nginx.</sub>

**%@ is ready. Its folder is %@.**  
→ %1$@ ist bereit. Der Ordner ist %2$@.  
<sub>Banner under the toolbar.</sub>

**%@ might be a real website.**  
→ %@ könnte eine echte Website sein.  

**%@ now reaches the live website again.**  
→ %@ führt jetzt wieder zur Live-Website.  
<sub>Banner after stopping the server. The placeholder is a real web address that this Mac no longer serves locally.</sub>

**%@ now serves files from %@.**  
→ %1$@ liefert jetzt Dateien aus %2$@.  
<sub>Banner under the toolbar.</sub>

**%@ was added, but the server isn’t running**  
→ %@ wurde hinzugefügt, aber der Server läuft nicht  
<sub>Title of an error sheet.</sub>

**%@ was removed. Its folder is still in place.**  
→ %@ wurde entfernt. Der Ordner ist noch da.  
<sub>Banner under the toolbar.</sub>

**%@ will reach the live website again.**  
→ %@ führt dann wieder zur Live-Website.  

**%@ · %@**  
→ %1$@ · %2$@  
<sub>A site's status: its worst problem, then how many other problems it has.</sub>

**%@, %@**  
→ %1$@, %2$@  

**%lld**  
→ %lld  

**%lld more**  
one: %lld more → %lld weitere  
other: %lld more → %lld weitere  
<sub>How many names a shortened list left out, e.g. “a.com and b.com and 2 more”. Always 1 or more; give it your language's plural forms.</sub>

**%lld need attention**  
one: %lld needs attention → %lld braucht Aufmerksamkeit  
other: %lld need attention → %lld brauchen Aufmerksamkeit  
<sub>How many websites have a problem, after a site count, e.g. “12 sites · 1 needs attention”.</sub>

**%lld sites**  
one: %lld site → %lld Website  
other: %lld sites → %lld Websites  
<sub>A number of websites, e.g. in the window subtitle and the sidebar footer.</sub>

**%lld sites aren’t pointing at this Mac right now, so they won’t open. Repair fixes this by restarting the server.**  
one: %lld site isn’t pointing at this Mac right now, so it won’t open. Repair fixes this by restarting the server. → %lld Website zeigt gerade nicht auf diesen Mac und öffnet sich deshalb nicht. „Reparieren“ behebt das, indem der Server neu gestartet wird.  
other: %lld sites aren’t pointing at this Mac right now, so they won’t open. Repair fixes this by restarting the server. → %lld Websites zeigen gerade nicht auf diesen Mac und öffnen sich deshalb nicht. „Reparieren“ behebt das, indem der Server neu gestartet wird.  
<sub>Banner while some sites' addresses don't lead to this Mac. Repair is the name of a toolbar button.</sub>

**%lld sites in this group need attention**  
one: %lld site in this group needs attention → %lld Website in dieser Gruppe braucht Aufmerksamkeit  
other: %lld sites in this group need attention → %lld Websites in dieser Gruppe brauchen Aufmerksamkeit  
<sub>Tooltip on a sidebar group's warning mark.</sub>

**%lld sites look related: %@**  
one: %lld site looks related: %@ → %1$lld Website scheint zusammenzugehören: %2$@  
other: %lld sites look related: %@ → %1$lld Websites scheinen zusammenzugehören: %2$@  
<sub>Sidebar suggestion to group websites with similar names. The count is always 2 or more, but give it your language's plural forms (in Russian, 21 takes the singular). The list is the addresses.</sub>

**%lld sites need a new certificate**  
one: %lld site needs a new certificate → %lld Website braucht ein neues Zertifikat  
other: %lld sites need a new certificate → %lld Websites brauchen ein neues Zertifikat  
<sub>Settings › Certificates headline.</sub>

**%lld sites need attention…**  
one: %lld site needs attention… → %lld Website braucht Aufmerksamkeit⍽…  
other: %lld sites need attention… → %lld Websites brauchen Aufmerksamkeit⍽…  
<sub>Menu bar item that shows the first website with a problem.</sub>

**%lld.**  
→ %lld.  

**A certificate is what lets https:// work without a browser warning. They last a little over two years. Refreshing makes new ones for every site at once and asks for your Mac password.**  
→ Ein Zertifikat sorgt dafür, dass https:// ohne Browserwarnung funktioniert. Es gilt etwas über zwei Jahre. Beim Erneuern entstehen neue Zertifikate für alle Websites auf einmal, und dein Mac-Passwort wird abgefragt.  

**A group keeps related sites together in the sidebar and the menu bar, such as one customer’s sites. It doesn’t change the sites themselves.**  
→ Eine Gruppe hält zusammengehörige Websites in der Seitenleiste und in der Menüleiste beisammen, etwa die Websites eines Kunden. An den Websites selbst ändert sie nichts.  

**A site with this address already exists, so nothing was changed.**  
→ Eine Website mit dieser Adresse gibt es schon, daher wurde nichts geändert.  

**About**  
→ Über  

**Add Site**  
→ Website hinzufügen  

**Add Site (⌘N)**  
→ Website hinzufügen (⌘N)  

**Add Site…**  
→ Website hinzufügen⍽…  

**Adding %@**  
→ %@ wird hinzugefügt  
<sub>Sheet title.</sub>

**Address**  
→ Adresse  

**Addresses ending in .test only exist on your Mac, so they never clash with real websites.**  
→ Adressen auf .test gibt es nur auf deinem Mac, sie kommen echten Websites also nie in die Quere.  

**Also answer at www.%@**  
→ Auch unter www.%@ erreichbar  
<sub>Checkbox in the Add Site sheet. Keep “www.” as is; the placeholder is the address.</sub>

**Also answers at %@**  
→ Auch erreichbar unter %@  
<sub>Under a site's address in its details. The placeholder is the www. address.</sub>

**Another app is already using the ports this server needs (80 and 443). Quit it, then start the server again.**  
→ Ein anderes Programm belegt bereits die Ports, die dieser Server braucht (80 und 443). Beende es und starte den Server dann erneut.  
<sub>Why the web server couldn't start.</sub>

**Another app is using the web ports**  
→ Ein anderes Programm belegt die Web-Ports  
<sub>Title of an error sheet.</sub>

**Back**  
→ Zurück  

**Cancel**  
→ Abbrechen  

**Certificate can’t be read**  
→ Zertifikat kann nicht gelesen werden  

**Certificate expired**  
→ Zertifikat abgelaufen  

**Certificate expires in %lld days**  
one: Certificate expires in %lld day → Zertifikat läuft in %lld Tag ab  
other: Certificate expires in %lld days → Zertifikat läuft in %lld Tagen ab  
<sub>Short status in the sidebar when a site's certificate expires within 30 days.</sub>

**Certificate unreadable**  
→ Zertifikat unlesbar  

**Certificates**  
→ Zertifikate  

**Certificates refreshed. If a browser still shows a warning, quit and reopen it.**  
→ Zertifikate erneuert. Wenn ein Browser noch eine Warnung zeigt, beende ihn und öffne ihn erneut.  
<sub>Banner under the toolbar.</sub>

**Change folder for %@**  
→ Ordner für %@ ändern  
<sub>Sheet title.</sub>

**Change…**  
→ Ändern⍽…  

**Check Again**  
→ Erneut prüfen  

**Check for Updates…**  
→ Nach Updates suchen⍽…  

**Checking every address points here…**  
→ Es wird geprüft, ob jede Adresse hierher zeigt⍽…  
<sub>Progress step shown while a change runs.</sub>

**Checking the setup**  
→ Einrichtung wird geprüft  
<sub>Progress step shown while a change runs.</sub>

**Checking the setup…**  
→ Einrichtung wird geprüft⍽…  
<sub>Progress step shown while a change runs.</sub>

**Checking your Mac…**  
→ Dein Mac wird geprüft⍽…  

**Choose**  
→ Wählen  

**Choose Folder…**  
→ Ordner wählen⍽…  

**Choose the folder that holds this site’s files, or make a new one.**  
→ Wähle den Ordner mit den Dateien dieser Website oder erstelle einen neuen.  

**Choose the folder that holds this site’s files.**  
→ Wähle den Ordner mit den Dateien dieser Website.  
<sub>Message in the folder chooser.</sub>

**Choose…**  
→ Wählen⍽…  

**Clear**  
→ Leeren  

**Clear what’s shown here. The log file isn’t changed.**  
→ Leert die Anzeige hier. Die Protokolldatei bleibt unverändert.  

**Click lines to select them, then copy**  
→ Klicke auf Zeilen, um sie auszuwählen, und kopiere sie dann  

**Close**  
→ Schließen  

**Continue**  
→ Fortfahren  

**Copied**  
→ Kopiert  

**Copy**  
→ Kopieren  

**Copy %lld Lines**  
one: Copy %lld Line → %lld Zeile kopieren  
other: Copy %lld Lines → %lld Zeilen kopieren  
<sub>Button that copies the selected log lines. Title case, like other buttons.</sub>

**Copy Address**  
→ Adresse kopieren  

**Copy Details**  
→ Details kopieren  

**Copy Update Command**  
→ Update-Befehl kopieren  

**Couldn’t add %@**  
→ %@ konnte nicht hinzugefügt werden  
<sub>Sheet title.</sub>

**Couldn’t change the folder for %@**  
→ Der Ordner für %@ konnte nicht geändert werden  
<sub>Title of an error sheet.</sub>

**Couldn’t refresh certificates**  
→ Zertifikate konnten nicht erneuert werden  
<sub>Title of an error sheet.</sub>

**Couldn’t remove %@**  
→ %@ konnte nicht entfernt werden  
<sub>Title of an error sheet.</sub>

**Couldn’t set up password-free mode**  
→ Passwortfreier Modus konnte nicht eingerichtet werden  
<sub>Title of an error sheet.</sub>

**Couldn’t switch to PHP %@**  
→ Wechsel zu PHP %@ nicht möglich  
<sub>Title of an error sheet.</sub>

**Create**  
→ Erstellen  

**Create Site**  
→ Website erstellen  

**Creating a secure certificate**  
→ Sicheres Zertifikat wird erstellt  
<sub>Progress step shown while a change runs.</sub>

**Current**  
→ Aktuell  

**Delete Group**  
→ Gruppe löschen  

**Dismiss**  
→ Schließen  

**Edit and Try Again**  
→ Bearbeiten und erneut versuchen  

**Enter your Mac password**  
→ Gib dein Mac-Passwort ein  
<sub>Sheet title.</sub>

**Errors**  
→ Fehler  
<sub>Tab in a site's details showing its error log.</sub>

**Every site has a healthy certificate**  
→ Alle Websites haben ein gültiges Zertifikat  

**Every site now runs on PHP %@.**  
→ Alle Websites laufen jetzt mit PHP %@.  
<sub>Banner under the toolbar.</sub>

**Every site runs on the same PHP version. Switching takes up to half a minute and restarts the server.**  
→ Alle Websites laufen mit derselben PHP-Version. Der Wechsel dauert bis zu einer halben Minute und startet den Server neu.  

**Expired on %@. Browsers will warn that this site isn’t secure.**  
→ Abgelaufen am %@. Browser warnen, dass diese Website nicht sicher ist.  
<sub>Certificate detail. The placeholder is a date.</sub>

**Expires in %lld days**  
one: Expires in %lld day → Läuft in %lld Tag ab  
other: Expires in %lld days → Läuft in %lld Tagen ab  
<sub>Certificate status in a site's details when it expires within 30 days.</sub>

**Files in**  
→ Dateien in  

**Files live in**  
→ Dateien liegen in  

**Filter lines**  
→ Zeilen filtern  

**Filter log lines**  
→ Protokollzeilen filtern  

**Filter sites**  
→ Websites filtern  

**Folder**  
→ Ordner  

**Folder missing**  
→ Ordner fehlt  
<sub>A site's problem, shown in the sidebar list and the menu bar menu.</sub>

**General**  
→ Allgemein  

**Get Homebrew at brew.sh**  
→ Homebrew auf brew.sh laden  

**Group**  
→ Gruppe  

**Group as “%@”**  
→ Als „%@“ gruppieren  

**Group name**  
→ Gruppenname  

**Handing addresses back to the internet…**  
→ Adressen werden ans Internet zurückgegeben⍽…  
<sub>Progress step shown while a change runs.</sub>

**Hide Details**  
→ Details ausblenden  

**https:// won’t work for this site until certificates are refreshed.**  
→ https:// funktioniert für diese Website erst, wenn die Zertifikate erneuert sind.  

**I understand. Use this address.**  
→ Verstanden. Diese Adresse verwenden.  

**If a browser still shows a warning afterwards, quit and reopen it.**  
→ Wenn ein Browser danach noch eine Warnung zeigt, beende ihn und öffne ihn erneut.  

**Install Homebrew first. It’s the free installer Patchy comes through.**  
→ Installiere zuerst Homebrew. Über dieses kostenlose Installationsprogramm kommt Patchy auf deinen Mac.  

**It’s still running and your sites still open. Try again, or look at Show Details.**  
→ Er läuft noch, und deine Websites öffnen sich weiterhin. Versuche es erneut oder sieh unter „Details einblenden“ nach.  
<sub>Message in an error sheet.</sub>

**joshuaomilian.ca**  
→ joshuaomilian.ca  

**list separator**  
→ ,   
<sub>Separates names in a list of websites or apps. English uses a comma and a space; CJK languages use 、</sub>

**Live**  
→ Live  

**Mac password**  
→ Mac-Passwort  

**macOS asks for your Mac password every time you start or stop the server, or add or remove a site.**  
→ macOS fragt jedes Mal nach deinem Mac-Passwort, wenn du den Server startest oder stoppst oder eine Website hinzufügst oder entfernst.  

**macOS didn’t allow that: %@**  
→ macOS hat das nicht erlaubt: %@  
<sub>Shown when turning Open at Login on or off fails. The placeholder is macOS’s own reason.</sub>

**macOS needs it to finish this change. It’s the one you use to log in to this Mac. Patchy passes it straight to macOS and doesn’t keep it.**  
→ macOS braucht es, um diese Änderung abzuschließen. Es ist das Passwort, mit dem du dich an diesem Mac anmeldest. Patchy gibt es direkt an macOS weiter und speichert es nicht.  
<sub>Sheet message.</sub>

**macOS will ask for your Mac password.**  
→ macOS fragt nach deinem Mac-Passwort.  

**Making new certificates for %lld sites…**  
one: Making new certificates for %lld site… → Neue Zertifikate für %lld Website werden erstellt⍽…  
other: Making new certificates for %lld sites… → Neue Zertifikate für %lld Websites werden erstellt⍽…  
<sub>Progress step while refreshing every site's certificate.</sub>

**More versions**  
→ Weitere Versionen  

**Move to Group**  
→ In Gruppe bewegen  

**mysite**  
→ mysite  

**Needs repair**  
→ Reparatur nötig  

**New**  
→ Neu  

**New Group**  
→ Neue Gruppe  

**New Group…**  
→ Neue Gruppe⍽…  

**New Site**  
→ Neue Website  

**No certificate**  
→ Kein Zertifikat  

**No errors yet**  
→ Noch keine Fehler  

**No folder chosen yet**  
→ Noch kein Ordner gewählt  

**No Group**  
→ Keine Gruppe  

**No Homebrew yet? Get it here**  
→ Noch kein Homebrew? Hier laden  

**No matching lines**  
→ Keine passenden Zeilen  

**No sites match “%@”.**  
→ Keine Website passt zu „%@“.  

**No sites yet**  
→ Noch keine Websites  

**No sites yet.**  
→ Noch keine Websites.  

**No visits yet**  
→ Noch keine Besuche  

**None**  
→ Keine  
<sub>The site is in no sidebar group.</sub>

**Not installed**  
→ Nicht installiert  

**Not Now**  
→ Später  

**Not pointing at this Mac**  
→ Zeigt nicht auf diesen Mac  
<sub>A site's problem, shown in the sidebar list and the menu bar menu.</sub>

**Not right now**  
→ Gerade nicht  

**Nothing in the errors log contains “%@”.**  
→ Nichts im Fehlerprotokoll enthält „%@“.  

**Nothing in the visits log contains “%@”.**  
→ Nichts im Besuchsprotokoll enthält „%@“.  

**Nothing was changed. Show Details has the exact message from Patchy.**  
→ Es wurde nichts geändert. Unter „Details einblenden“ steht die genaue Meldung von Patchy.  
<sub>Message in an error sheet.</sub>

**Offline while the server is stopped**  
→ Offline, solange der Server gestoppt ist  

**Only one PHP version is installed. You can add others with Homebrew; they show up here when they’re ready. For example, in Terminal:**  
→ Es ist nur eine PHP-Version installiert. Weitere kannst du mit Homebrew hinzufügen; sie erscheinen hier, sobald sie bereit sind. Zum Beispiel im Terminal:  

**Open %@**  
→ %@ öffnen  

**Open in Browser**  
→ Im Browser öffnen  

**Open Patchy UI**  
→ Patchy UI öffnen  

**Open Patchy UI when I log in**  
→ Patchy UI beim Anmelden öffnen  

**Open Site**  
→ Website öffnen  

**Open Terminal**  
→ Terminal öffnen  

**Open Terminal. It’s in Applications › Utilities.**  
→ Öffne das Terminal. Es liegt unter Programme › Dienstprogramme.  

**Open the site in your browser and each page request will show up here.**  
→ Öffne die Website im Browser, dann erscheint hier jeder Seitenaufruf.  

**Opening…**  
→ Wird geöffnet⍽…  

**Opens at**  
→ Öffnet unter  

**Opens at https://%@**  
→ Öffnet unter https://%@  

**Opens at https://mysite.test**  
→ Öffnet unter https://mysite.test  

**Opens in any browser on this Mac.**  
→ Öffnet sich in jedem Browser auf diesem Mac.  

**Opens, but shows an error**  
→ Öffnet sich, zeigt aber einen Fehler  

**Other Sites**  
→ Weitere Websites  

**Overview**  
→ Übersicht  
<sub>Tab in a site's details.</sub>

**Password-Free**  
→ Ohne Passwort  

**Password-free mode is off**  
→ Passwortfreier Modus ist aus  

**Password-free mode is on**  
→ Passwortfreier Modus ist an  

**Password-free mode is on.**  
→ Passwortfreier Modus ist an.  

**Password-free mode is on. Continuing…**  
→ Passwortfreier Modus ist an. Es geht weiter⍽…  

**Password-free mode needs refreshing**  
→ Passwortfreier Modus muss erneuert werden  

**Paste this command and press Return:**  
→ Füge diesen Befehl ein und drücke den Zeilenschalter:  

**Patchy**  
→ Patchy  

**Patchy %@ is installed, but this Patchy UI was made for Patchy %@. Some things may not work until Patchy UI is updated to match.**  
→ Patchy %1$@ ist installiert, aber dieses Patchy UI wurde für Patchy %2$@ gemacht. Manches funktioniert vielleicht erst, wenn Patchy UI passend aktualisiert ist.  
<sub>Banner. The placeholders are version numbers.</sub>

**Patchy asks for your Mac password on every change.**  
→ Patchy fragt bei jeder Änderung nach deinem Mac-Passwort.  

**Patchy can update your addresses without asking each time.**  
→ Patchy kann deine Adressen aktualisieren, ohne jedes Mal zu fragen.  

**Patchy can’t set this up safely on this Mac, so nothing was changed. You can keep using the app; it will ask for your Mac password when a change needs it.**  
→ Patchy kann das auf diesem Mac nicht sicher einrichten, daher wurde nichts geändert. Du kannst die App weiter verwenden; sie fragt nach deinem Mac-Passwort, wenn eine Änderung es braucht.  
<sub>Message in an error sheet.</sub>

**Patchy couldn’t point the address at this Mac, so nothing was created. Your other sites are fine.**  
→ Patchy konnte die Adresse nicht auf diesen Mac lenken, daher wurde nichts erstellt. Deine anderen Websites sind in Ordnung.  

**Patchy didn’t report anything.**  
→ Patchy hat nichts gemeldet.  

**Patchy isn’t installed yet**  
→ Patchy ist noch nicht installiert  

**Patchy isn’t on this Mac yet**  
→ Patchy ist noch nicht auf diesem Mac  

**Patchy makes a new certificate for every site at once, so https:// keeps working without browser warnings. This can take up to a minute.**  
→ Patchy erstellt für alle Websites auf einmal ein neues Zertifikat, damit https:// weiter ohne Browserwarnung funktioniert. Das kann bis zu einer Minute dauern.  
<sub>Sheet message.</sub>

**Patchy on GitHub**  
→ Patchy auf GitHub  

**Patchy UI**  
→ Patchy UI  

**Patchy UI and Patchy match. Patchy UI’s version number is always the Patchy release it was made for.**  
→ Patchy UI und Patchy passen zusammen. Die Versionsnummer von Patchy UI ist immer die Patchy-Version, für die es gemacht wurde.  

**Patchy UI couldn’t find PHP on this Mac.**  
→ Patchy UI hat auf diesem Mac kein PHP gefunden.  

**Patchy UI is a window onto Patchy, the local web server tool made by Joe Workman. Patchy does the real work.**  
→ Patchy UI ist ein Fenster zu Patchy, dem Werkzeug für lokale Webserver von Joe Workman. Die eigentliche Arbeit macht Patchy.  

**Patchy UI is free and open source, made by Joshua Omilian.**  
→ Patchy UI ist kostenlos und Open Source, gemacht von Joshua Omilian.  

**Patchy UI on GitHub**  
→ Patchy UI auf GitHub  

**Patchy UI runs on Patchy, a free tool by Joe Workman. You install it once with Homebrew, and this app takes care of the rest.**  
→ Patchy UI baut auf Patchy auf, einem kostenlosen Werkzeug von Joe Workman. Du installierst es einmal mit Homebrew, um den Rest kümmert sich diese App.  

**Patchy UI’s version number is always the Patchy release it was made for.**  
→ Die Versionsnummer von Patchy UI ist immer die Patchy-Version, für die es gemacht wurde.  

**Patchy updates where your addresses point without asking for your Mac password. That is the only thing it can do on its own.**  
→ Patchy aktualisiert, wohin deine Adressen zeigen, ohne nach deinem Mac-Passwort zu fragen. Das ist das Einzige, was es selbstständig tun kann.  

**Patchy was updated, so its permission to update your addresses needs to be refreshed once. Until then, macOS asks for your Mac password on every change.**  
→ Patchy wurde aktualisiert, daher muss seine Erlaubnis, deine Adressen zu aktualisieren, einmal erneuert werden. Bis dahin fragt macOS bei jeder Änderung nach deinem Mac-Passwort.  

**Patchy was updated, so password-free mode needs refreshing once.**  
→ Patchy wurde aktualisiert, daher muss der passwortfreie Modus einmal erneuert werden.  

**Patchy was updated. Refresh this once and the password prompts stop again.**  
→ Patchy wurde aktualisiert. Erneuere das einmal, dann hören die Passwortabfragen wieder auf.  

**Patchy: needs attention**  
→ Patchy: braucht Aufmerksamkeit  
<sub>VoiceOver label for the menu bar item.</sub>

**Patchy: server running**  
→ Patchy: Server läuft  
<sub>VoiceOver label for the menu bar item.</sub>

**Patchy: server stopped**  
→ Patchy: Server gestoppt  
<sub>VoiceOver label for the menu bar item.</sub>

**Patchy: working**  
→ Patchy: arbeitet  
<sub>VoiceOver label for the menu bar item.</sub>

**Pause live updates**  
→ Live-Aktualisierung anhalten  

**Paused**  
→ Angehalten  

**PHP**  
→ PHP  

**PHP %@  (%@)**  
→ PHP %1$@  (%2$@)  

**Pick a short name. It becomes the address you type in your browser. Then choose the folder that holds the site’s files, and Patchy serves whatever is in it.**  
→ Such dir einen kurzen Namen aus. Er wird zur Adresse, die du im Browser eingibst. Wähle dann den Ordner mit den Dateien der Website, und Patchy liefert aus, was darin liegt.  

**Pointing %@ at the new folder…**  
→ %@ wird auf den neuen Ordner umgestellt⍽…  
<sub>Progress step shown while a change runs.</sub>

**Pointing %@ at this Mac**  
→ %@ wird auf diesen Mac gelenkt  
<sub>Progress step shown while a change runs.</sub>

**Pointing your addresses at this Mac…**  
→ Deine Adressen werden auf diesen Mac gelenkt⍽…  
<sub>Progress step shown while a change runs.</sub>

**Quit Patchy UI**  
→ Patchy UI beenden  

**Reachable**  
→ Erreichbar  

**Real web address**  
→ Echte Webadresse  

**Refresh Certificates**  
→ Zertifikate erneuern  

**Refresh certificates for all %lld sites?**  
one: Refresh certificates for your site? → Zertifikat für deine Website erneuern?  
other: Refresh certificates for all %lld sites? → Zertifikate für alle %lld Websites erneuern?  
<sub>Sheet title. English's 'one' form says “your site” with no number; in languages whose 'one' category also covers 21, 31… the 'one' form must include the number.</sub>

**Refresh Certificates…**  
→ Zertifikate erneuern⍽…  

**Refresh password-free mode**  
→ Passwortfreien Modus erneuern  

**Remove %@?**  
→ %@ entfernen?  
<sub>Sheet title.</sub>

**Remove from Group**  
→ Aus Gruppe entfernen  

**Remove Site**  
→ Website entfernen  

**Remove Site (Delete)**  
→ Website entfernen (Rückschritttaste)  

**Remove…**  
→ Entfernen⍽…  

**Removing %@…**  
→ %@ wird entfernt⍽…  
<sub>Progress step shown while a change runs.</sub>

**Rename**  
→ Umbenennen  

**Rename Group**  
→ Gruppe umbenennen  

**Rename…**  
→ Umbenennen⍽…  

**Repair**  
→ Reparieren  

**Repaired. Every address points at this Mac again.**  
→ Repariert. Alle Adressen zeigen wieder auf diesen Mac.  
<sub>Banner under the toolbar.</sub>

**Restart**  
→ Neu starten  

**Restart Server**  
→ Server neu starten  

**Restart the server (also repairs addresses)**  
→ Server neu starten (repariert auch Adressen)  

**Restarting the server**  
→ Server wird neu gestartet  
<sub>Progress step shown while a change runs.</sub>

**Restarting the server…**  
→ Server wird neu gestartet⍽…  
<sub>Progress step shown while a change runs.</sub>

**Resume live updates**  
→ Live-Aktualisierung fortsetzen  

**Reveal in Finder**  
→ Im Finder zeigen  

**Reveal Log File**  
→ Protokolldatei zeigen  

**Reveal Server Error Log in Finder**  
→ Fehlerprotokoll des Servers im Finder zeigen  

**Running**  
→ Läuft  

**Running · %@**  
→ Läuft · %@  
<sub>Server status in the toolbar. The placeholder is “PHP 8.4”.</sub>

**Running · needs repair**  
→ Läuft · Reparatur nötig  

**Secure connection**  
→ Sichere Verbindung  

**Secure · %lld days**  
one: Secure · %lld day → Sicher · %lld Tag  
other: Secure · %lld days → Sicher · %lld Tage  
<sub>Short status in the sidebar for a healthy site: days until its certificate expires. English never shows 1 here (it's always over 30), but give it your language's plural forms: in Russian or Polish, 31 takes the singular.</sub>

**Secure · %lld days left**  
one: Secure · %lld day left → Sicher · noch %lld Tag  
other: Secure · %lld days left → Sicher · noch %lld Tage  
<sub>Certificate status in a site's details. English never shows 1 here (it's always over 30), but give it your language's plural forms: in Russian or Polish, 31 takes the singular.</sub>

**Select a site to see its details.**  
→ Wähle eine Website aus, um ihre Details zu sehen.  

**Server**  
→ Server  

**Server (Apache)**  
→ Server (Apache)  

**Server running**  
→ Server läuft  

**Server stopped**  
→ Server gestoppt  

**Server: %@**  
→ Server: %@  

**Set Up**  
→ Einrichten  

**Set up password-free mode…**  
→ Passwortfreien Modus einrichten⍽…  

**Set Up…**  
→ Einrichten⍽…  

**Setting up password-free mode…**  
→ Passwortfreier Modus wird eingerichtet⍽…  

**Setting up the site**  
→ Website wird eingerichtet  
<sub>Progress step shown while a change runs.</sub>

**Settings…**  
→ Einstellungen⍽…  

**Show Details**  
→ Details einblenden  

**Show Details has the exact message from Patchy.**  
→ Unter „Details einblenden“ steht die genaue Meldung von Patchy.  

**Show Patchy UI in the Dock**  
→ Patchy UI im Dock anzeigen  

**Since this is your first site, macOS will ask for your Mac password once while Patchy sets up secure connections. That’s expected.**  
→ Da das deine erste Website ist, fragt macOS einmal nach deinem Mac-Passwort, während Patchy sichere Verbindungen einrichtet. Das ist so vorgesehen.  

**Skip the password prompts**  
→ Passwortabfragen überspringen  

**Some addresses still aren’t pointing at this Mac**  
→ Manche Adressen zeigen noch nicht auf diesen Mac  
<sub>Title of an error sheet.</sub>

**Some sites may still show a browser warning. If you cancelled a password prompt, try again and enter your Mac password.**  
→ Manche Websites zeigen vielleicht noch eine Browserwarnung. Wenn du eine Passwortabfrage abgebrochen hast, versuche es erneut und gib dein Mac-Passwort ein.  
<sub>Message in an error sheet.</sub>

**Something stopped the setup partway. Your other sites are fine; Show Details has the exact message from Patchy.**  
→ Etwas hat die Einrichtung unterbrochen. Deine anderen Websites sind in Ordnung; unter „Details einblenden“ steht die genaue Meldung von Patchy.  

**Start Server**  
→ Server starten  

**Start the server to open this site**  
→ Starte den Server, um diese Website zu öffnen  

**Starting and stopping the server, and adding or removing sites, all tell your Mac where each address lives. Normally macOS asks for your Mac password every time.**  
→ Wenn du den Server startest oder stoppst und Websites hinzufügst oder entfernst, wird deinem Mac jedes Mal mitgeteilt, wohin welche Adresse führt. Normalerweise fragt macOS dafür jedes Mal nach deinem Mac-Passwort.  

**Starting the server…**  
→ Server wird gestartet⍽…  
<sub>Progress step shown while a change runs.</sub>

**Stop**  
→ Stoppen  

**Stop Server**  
→ Server stoppen  

**Stop the server and release your addresses**  
→ Server stoppen und deine Adressen freigeben  

**Stop, Then Start**  
→ Stoppen, dann starten  

**Stopped**  
→ Gestoppt  

**Stopping the server…**  
→ Server wird gestoppt⍽…  
<sub>Progress step shown while a change runs.</sub>

**Switching every site to PHP %@…**  
→ Alle Websites werden auf PHP %@ umgestellt⍽…  
<sub>Progress step shown while a change runs.</sub>

**Technical details from Patchy, in English.**  
→ Technische Details von Patchy, auf Englisch.  

**That address looks unfinished. It can’t start or end with a dot or hyphen.**  
→ Diese Adresse sieht unvollständig aus. Sie darf nicht mit einem Punkt oder Bindestrich beginnen oder enden.  

**That doesn’t match your Mac password. Try again.**  
→ Das stimmt nicht mit deinem Mac-Passwort überein. Versuche es erneut.  
<sub>Shown under a password field.</sub>

**That’s the folder this site already uses.**  
→ Diesen Ordner verwendet die Website bereits.  

**That’s the only thing it’s allowed to do on its own.**  
→ Das ist das Einzige, was es selbstständig tun darf.  

**The address stays the same. Patchy serves files from the new folder instead. Nothing is moved or deleted.**  
→ Die Adresse bleibt gleich. Patchy liefert stattdessen die Dateien aus dem neuen Ordner aus. Nichts wird bewegt oder gelöscht.  
<sub>Sheet message.</sub>

**The address will stop working on this Mac. The folder and everything in it stay right where they are.**  
→ Die Adresse funktioniert auf diesem Mac nicht mehr. Der Ordner und alles darin bleiben, wo sie sind.  
<sub>Sheet message.</sub>

**The background service that runs the server didn’t respond. Stopping and starting it again resets it.**  
→ Der Hintergrunddienst, der den Server betreibt, hat nicht reagiert. Stoppen und erneutes Starten setzt ihn zurück.  
<sub>Message in an error sheet.</sub>

**The certificate file is damaged. Refreshing certificates replaces it.**  
→ Die Zertifikatsdatei ist beschädigt. Beim Erneuern der Zertifikate wird sie ersetzt.  

**The current folder is missing, so pointing the site at the right one fixes it.**  
→ Der aktuelle Ordner fehlt. Wenn du die Website auf den richtigen Ordner umstellst, ist das behoben.  

**The folder changed, but the server isn’t running**  
→ Der Ordner wurde geändert, aber der Server läuft nicht  
<sub>Title of an error sheet.</sub>

**The folder you choose**  
→ Der Ordner, den du wählst  

**The menu bar item stays either way. With the Dock icon off, open the window from the menu bar item.**  
→ Das Symbol in der Menüleiste bleibt in jedem Fall. Ohne Dock-Symbol öffnest du das Fenster über die Menüleiste.  

**The one you use to log in to this Mac. Patchy passes it straight to macOS and doesn’t keep it.**  
→ Das Passwort, mit dem du dich an diesem Mac anmeldest. Patchy gibt es direkt an macOS weiter und speichert es nicht.  
<sub>Sheet message.</sub>

**The server didn’t start**  
→ Der Server ist nicht gestartet  
<sub>Title of an error sheet.</sub>

**The server didn’t stop**  
→ Der Server wurde nicht gestoppt  
<sub>Title of an error sheet.</sub>

**The server is stopped, so none of your sites will open right now.**  
→ Der Server ist gestoppt, deshalb öffnet sich gerade keine deiner Websites.  

**The server is stopped.**  
→ Der Server ist gestoppt.  

**The server is stopped. New lines will appear once it’s running again.**  
→ Der Server ist gestoppt. Neue Zeilen erscheinen, sobald er wieder läuft.  

**The server is stuck**  
→ Der Server hängt  
<sub>Title of an error sheet.</sub>

**The server restarted, but it couldn’t update where your addresses point. Try Repair again.**  
→ Der Server wurde neu gestartet, konnte aber nicht aktualisieren, wohin deine Adressen zeigen. Versuche erneut „Reparieren“.  
<sub>Message in an error sheet.</sub>

**The server restarts when it’s done.**  
→ Danach startet der Server neu.  

**The setup check found a problem, so Patchy undid every step. Nothing was added and your other sites are fine.**  
→ Die Prüfung der Einrichtung hat ein Problem gefunden, daher hat Patchy jeden Schritt rückgängig gemacht. Es wurde nichts hinzugefügt, und deine anderen Websites sind in Ordnung.  

**The setup check found a problem, so the site still uses its previous folder. Nothing else changed.**  
→ Die Prüfung der Einrichtung hat ein Problem gefunden, daher verwendet die Website weiterhin ihren bisherigen Ordner. Sonst hat sich nichts geändert.  
<sub>Message in an error sheet.</sub>

**The site is still set up exactly as it was. Show Details has the exact message from Patchy.**  
→ Die Website ist noch genau so eingerichtet wie vorher. Unter „Details einblenden“ steht die genaue Meldung von Patchy.  
<sub>Message in an error sheet.</sub>

**There’s no folder to serve files from.**  
→ Es gibt keinen Ordner, aus dem Dateien ausgeliefert werden können.  

**This address isn’t pointing at this Mac. Repair fixes it.**  
→ Diese Adresse zeigt nicht auf diesen Mac. „Reparieren“ behebt das.  

**This folder isn’t there anymore. Put it back, or click Change… to point the site at the right folder.**  
→ Dieser Ordner ist nicht mehr da. Lege ihn zurück oder klicke auf „Ändern⍽…“, um die Website auf den richtigen Ordner umzustellen.  

**This Mac account isn’t allowed to make this change. Use an administrator account.**  
→ Dieser Mac-Account darf diese Änderung nicht vornehmen. Verwende einen Administrator-Account.  
<sub>Shown under a password field.</sub>

**This Mac account isn’t allowed to set this up. Use an administrator account.**  
→ Dieser Mac-Account darf das nicht einrichten. Verwende einen Administrator-Account.  
<sub>Shown under a password field.</sub>

**This Patchy UI was made for Patchy %@, but Patchy %@ is installed. Update Patchy to avoid problems: paste the command into Terminal.**  
→ Dieses Patchy UI wurde für Patchy %1$@ gemacht, installiert ist aber Patchy %2$@. Aktualisiere Patchy, um Probleme zu vermeiden: Füge den Befehl im Terminal ein.  
<sub>Banner. The placeholders are version numbers.</sub>

**This Patchy UI was made for Patchy %@. Patchy is newer, so some things may not work until Patchy UI is updated.**  
→ Dieses Patchy UI wurde für Patchy %@ gemacht. Patchy ist neuer, daher funktioniert manches vielleicht erst, wenn Patchy UI aktualisiert ist.  

**This Patchy UI was made for Patchy %@. Patchy is older; update it in Terminal with: %@**  
→ Dieses Patchy UI wurde für Patchy %1$@ gemacht. Patchy ist älter; aktualisiere es im Terminal mit: %2$@  

**This takes a few seconds.**  
→ Das dauert ein paar Sekunden.  
<sub>Sheet message.</sub>

**Type a name and Patchy adds .test. Or type a full address, like mysite.local.**  
→ Gib einen Namen ein, und Patchy hängt .test an. Oder gib eine vollständige Adresse ein, etwa mysite.local.  

**Untitled Group**  
→ Gruppe ohne Namen  
<sub>Name given to a sidebar group left unnamed.</sub>

**Update password-free mode…**  
→ Passwortfreien Modus aktualisieren⍽…  

**Update…**  
→ Aktualisieren⍽…  

**Use only letters, numbers, hyphens (-), and dots (.).**  
→ Verwende nur Buchstaben, Ziffern, Bindestriche (-) und Punkte (.).  

**Use This Folder**  
→ Diesen Ordner verwenden  

**Valid until %@.**  
→ Gültig bis %@.  
<sub>Certificate detail. The placeholder is a date.</sub>

**Valid until %@. Refresh before then to avoid browser warnings.**  
→ Gültig bis %@. Erneuere es vorher, um Browserwarnungen zu vermeiden.  
<sub>Certificate detail. The placeholder is a date.</sub>

**Version**  
→ Version  

**Version %@**  
→ Version %@  

**View**  
→ Ansicht  

**Visits**  
→ Besuche  
<sub>Tab in a site's details showing its access log.</sub>

**What should we call it?**  
→ Wie soll sie heißen?  

**When it finishes, come back and click Check Again.**  
→ Wenn der Befehl fertig ist, komm hierher zurück und klicke auf „Erneut prüfen“.  

**When PHP or the server reports a problem with this site, it shows up here.**  
→ Wenn PHP oder der Server ein Problem mit dieser Website meldet, erscheint es hier.  

**While the server runs, this Mac shows your local copy and can’t reach the live site. Everyone else still sees the real one.**  
→ Solange der Server läuft, zeigt dieser Mac deine lokale Kopie und erreicht die Live-Website nicht. Alle anderen sehen weiterhin die echte.  

**Working…**  
→ Wird ausgeführt⍽…  

**Yes**  
→ Ja  
<sub>Answer to “Reachable”: the site opens in a browser.</sub>

**You can add other versions with Homebrew; they show up here when they’re ready. For example, in Terminal:**  
→ Weitere Versionen kannst du mit Homebrew hinzufügen; sie erscheinen hier, sobald sie bereit sind. Zum Beispiel im Terminal:  

**You enter your Mac password once, now.**  
→ Du gibst dein Mac-Passwort einmal ein, jetzt.  

**Your first site**  
→ Deine erste Website  

**Your Mac wouldn’t let the app pass your password along. You can turn on password-free mode yourself instead: open Terminal (in Applications > Utilities), type patchy trust, press Return and enter your Mac password. Then come back here.**  
→ Dein Mac hat der App nicht erlaubt, dein Passwort weiterzugeben. Du kannst den passwortfreien Modus stattdessen selbst einschalten: Öffne das Terminal (unter Programme > Dienstprogramme), gib patchy trust ein, drücke den Zeilenschalter und gib dein Mac-Passwort ein. Komm danach hierher zurück.  
<sub>Message in an error sheet.</sub>

**Your sites are running on PHP %@.**  
→ Deine Websites laufen mit PHP %@.  

**Your sites won’t open until it’s running. Show Details has the exact message from Patchy.**  
→ Deine Websites öffnen sich erst, wenn er läuft. Unter „Details einblenden“ steht die genaue Meldung von Patchy.  
<sub>Message in an error sheet.</sub>
