# Patchy UI — Product Brief for UI Design

This document describes Patchy, the people Patchy UI is for, and everything the first version of the app must do. It is written for the designer of the interface. It specifies function, content, and states; layout, visual style, and wording are the designer's to decide unless a section says otherwise.

## 1. Summary

**Patchy** is a command-line tool by Joe Workman that turns a Mac into a local web server for PHP websites. It is installed through Homebrew and used entirely from the Terminal.

**Patchy UI** is a native macOS app that does the same things with windows, buttons, and plain language. The user never opens the Terminal.

**The goal:** be the easiest way for someone to start hosting websites locally on their Mac with Patchy.

**The form:** a main window plus a menu bar item. Closing the window leaves the menu bar item running.

## 2. Who it is for

The primary user builds or maintains websites (WordPress, Total CMS, Drupal, plain PHP) and wants to run them on their own Mac before publishing. They are comfortable with Finder, folders, and a browser. They are not comfortable with the Terminal, and words like "vhost", "sudo", "Apache", and "/etc/hosts" mean little to them.

A secondary user is an experienced developer who already uses Patchy from the Terminal and wants a faster overview of many sites. A real example of this user has 26 sites configured at once.

Design for the first user without slowing down the second.

## 3. What Patchy does, in plain terms

A designer needs these concepts to understand the screens. The app should rarely show the technical terms in the right-hand column.

| Concept | What it means to the user | Technical term (avoid in the UI) |
|---|---|---|
| **Site** | A website on this Mac: a web address paired with a folder of files. | Virtual host, vhost |
| **Address** | The name typed into the browser, such as `mysite.test`. | Domain, ServerName |
| **Folder** | The folder on the Mac that holds the site's files. | Document root, docroot |
| **Server** | The engine that serves all sites. It is either running or stopped, for all sites at once. | Apache, httpd |
| **Secure connection** | Every site works over `https://` with no browser warning. Each site has a certificate with an expiry date. | SSL certificate, mkcert |
| **Routing** | While the server runs, each site's address points at this Mac instead of the internet. Stopping the server points the addresses back at the internet immediately. | /etc/hosts entries |
| **PHP version** | The version of the PHP language all sites run on. One version is active for every site. | mod_php, Homebrew formula |
| **Password-free mode** | A one-time setup that lets Patchy change routing without asking for the Mac password every time. | `patchy trust`, sudoers helper |
| **Logs** | A running record of visits and errors for each site. | access_log, error_log |

### Facts that affect the design

- **One server, many sites.** Start, stop, and restart apply to every site together. There is no per-site on/off switch.
- **One PHP version for all sites.** Switching it affects every site.
- **`.test` addresses are the safe default.** They can never clash with a real website. `.local` is also local-only.
- **Real addresses are allowed but risky.** A user can add `mycompany.com`. While the server runs, that Mac sees the local copy and cannot reach the live site. This needs a clear warning.
- **`www.` companion.** A two-part address such as `mysite.test` or `example.com` can also answer at `www.mysite.test`. This is a choice made when the site is added. Addresses with more parts (`shop.example.com`) and addresses that already start with `www.` do not get this choice.
- **Removing a site never deletes its folder.** Only the address, certificate, and server configuration go away.
- **Changes need the Mac password unless password-free mode is on.** Adding, removing, starting, and stopping all change routing.
- **Sites open on this Mac only.** The server does listen on the local network, but a site's address is only known to this Mac, so a phone or another computer cannot find it by name. macOS may show a one-time firewall prompt for `httpd`.

## 4. Scope of the first version

### Included

1. See all sites and their health at a glance
2. Add a site
3. Remove a site
4. Start, stop, and restart the server
5. Open a site in the browser; reveal its folder in Finder; copy its address
6. See and switch the PHP version
7. View per-site logs, live
8. See certificate status and refresh certificates
9. Set up password-free mode
10. Menu bar item with status and shortcuts
11. Clear guidance when Patchy or Homebrew is not installed

### Not included

- Installing Homebrew or Patchy for the user (the app shows what to do instead)
- Installing PHP versions or PHP extensions
- Editing the server or PHP configuration files
- Turning password-free mode off
- Changing an existing site's address or folder (the user removes and re-adds)
- App updates, licensing, and distribution

## 5. App-wide states

The whole app is always in exactly one of these states. Each needs a design.

| State | When | What the user must be able to do |
|---|---|---|
| **Checking** | On launch, briefly, while the app reads the Mac's setup. | Wait. Usually under a second. |
| **Patchy not installed** | Homebrew or Patchy is missing. | Read a short explanation, copy the install command (`brew install joeworkman/patchy/patchy`), follow a link to instructions, and press "Check again". Nothing else in the app is available. |
| **Password-free mode not set up** | Patchy is installed but password-free mode is off or out of date. | See sites and logs (read-only actions work). Be offered the setup before any action that changes routing. See section 6.9. |
| **Ready, no sites** | Everything works but no site exists yet. | Understand what a site is and add the first one. This is the most important first impression in the app. |
| **Ready, server running** | Normal use. | Everything. |
| **Ready, server stopped** | Sites exist but the server is off. | See that no site is reachable right now and start the server with one click. Sites remain listed; opening one in the browser would fail. |
| **Working** | A command is running. | See what is happening and that the app has not frozen. Other changing actions are unavailable until it finishes. |

The server has one further sub-state the design must show:

- **Partly routed.** The server is running but some site addresses are not pointing at this Mac (for example, after a manual edit). The fix is a single "Repair" action, which is the same as restart.

## 6. Functions

Each function lists what the user provides, what the app shows, how long it takes, and what can go wrong.

### 6.1 Site list

Shows every site. This is the home of the main window.

**For each site the app knows:**

| Field | Example | Notes |
|---|---|---|
| Address | `brightside-dental.test` | 6 to about 30 characters. Always present. |
| `www.` companion | `www.mysite.test` | Present or absent. |
| Folder | `~/Developer/Clients/Brightside Dental/website/public` | Often long; needs truncation. Shown with `~` for the home folder. |
| Folder exists | yes / no | A missing folder is a problem worth flagging. |
| Secure connection status | see 6.8 | Healthy, expiring soon, expired, invalid, or missing. |
| Reachable now | yes / no | Depends on the server running and the address being routed. |

**Requirements:**

- Sorted alphabetically by address.
- Works comfortably with 1 site and with 30 or more. Include a way to filter by typing.
- Problems (expiring certificate, missing folder, not routed) are visible in the list without opening the site.
- Selecting a site shows its detail (6.2).
- The list updates by itself when sites change, including changes made outside the app.

### 6.2 Site detail

Shows one site and its actions.

**Content:** address, `www.` companion if any, full folder path, secure connection status with expiry, whether it is reachable now.

**Actions:**

| Action | Result |
|---|---|
| Open in browser | Opens `https://<address>` in the default browser. Unavailable or warned when the server is stopped. |
| Copy address | Copies `https://<address>` to the clipboard. |
| Reveal folder | Opens the site's folder in Finder. |
| View logs | Shows the log viewer for this site (6.7). |
| Remove site | See 6.4. |

### 6.3 Add a site

The most important flow in the app. It should feel like two decisions: what to call the site, and where its files are.

**The user provides:**

| Input | Rules |
|---|---|
| **Address** | Required. Letters, numbers, hyphens, and dots only. Must contain a dot. Must not already exist. The app should steer the user toward `.test`, for example by letting them type just `mysite` and supplying `.test`. |
| **Folder** | Optional. Defaults to `~/Websites/<address>`. The user can pick any folder with the standard folder chooser. If the folder does not exist it is created. |
| **Also answer at `www.`** | A yes/no choice, on by default. Shown only for two-part addresses that do not start with `www.`. |

**Live feedback while typing:** the final address that will be created, the folder that will be used, and any validation problem.

**Real-address warning.** If the address does not end in `.test` or `.local`, the app must warn before continuing: this address may belong to a real website, and while the server runs that live website cannot be reached from this Mac. The user must explicitly confirm.

**What happens next:** the app points the address at this Mac, creates the secure certificate, creates the site, checks the configuration, and restarts the server. This takes roughly 5 to 15 seconds and should show progress in plain steps.

**First site ever:** creating the first certificate installs a local certificate authority, and macOS will ask for the Mac password once. The design should prepare the user for that prompt.

**Success:** the new site is selected in the list, with an obvious "Open in browser" next step.

**What can go wrong:**

| Problem | What the user should be told |
|---|---|
| Address already exists | Choose a different address. |
| Invalid characters | Which characters are allowed. |
| Password declined or wrong | Nothing was created; try again. |
| Configuration check failed | The site was not added and everything was rolled back. Offer the technical details. |
| Server did not come back up | The site was added but the server is not running. Offer details and a retry. |

### 6.4 Remove a site

**The user provides:** confirmation.

**The confirmation must say:** the address will stop working on this Mac, and the folder and its files are not deleted. For a real address, add that the live website becomes reachable again.

**Takes:** about 3 to 6 seconds, ending with a server restart.

**Multiple selection:** removing several sites at once is supported by Patchy and is a welcome addition, not a requirement.

### 6.5 Server control

**Always visible** in the main window and in the menu bar item: whether the server is running or stopped.

| Action | Available when | Effect | Takes |
|---|---|---|---|
| Start | Stopped | Starts the server and points all site addresses at this Mac. | 2 to 4 seconds |
| Stop | Running | Stops the server and releases all addresses back to the internet. | 1 to 3 seconds |
| Restart | Running | Restarts and repairs any addresses that are not routed. | 2 to 5 seconds |

**Stop needs care.** Stopping makes every site unreachable. For a user with real addresses, it also makes the live versions reachable again, which is sometimes the reason to stop. A brief explanation is appropriate; a blocking confirmation every time is not.

**What can go wrong on start:**

| Problem | What the user should be told |
|---|---|
| Another app is using the web ports (80/443) | Which app is using them, and that it must be quit first. |
| The background service is stuck | Stop, then start again. Offer this as one button. |
| Configuration error | Offer the technical details. |

**Read-only information shown somewhere appropriate** (settings or an about panel): Patchy version, server (Apache) version, active PHP version.

### 6.6 PHP version

**Shows:** the active PHP version (for example, 8.4) and the list of PHP versions installed on this Mac.

**Action:** choose a different installed version. Applies to every site.

**Takes:** 10 to 30 seconds and restarts the server. Needs clear progress.

**States:**

- Only one version installed: show it, and explain that more versions can be installed with Homebrew (show the command to copy, for example `brew install php@8.3`). The app does not install them.
- Switch failed: say so, show which version is now active, and offer details.

### 6.7 Log viewer

Each site has two logs:

- **Errors** — problems reported by the server and by PHP for that site. The one users need most.
- **Visits** — one line per request (time, path, result code).

**Requirements:**

- Choose between Errors and Visits for the selected site.
- Opens showing the most recent lines, newest at the bottom, and updates live as new lines arrive.
- Pause and resume live updating.
- Search or filter the visible lines by text.
- Clear the view (clears what is shown, not the file).
- Copy selected lines.
- Reveal the log file in Finder.
- Monospaced text. Lines are long (often 150 to 300 characters); decide between wrapping and horizontal scrolling.
- Empty state for a site with no log lines yet.

A server-wide error log also exists, for problems not tied to one site. It should be reachable, but it is secondary.

### 6.8 Certificates

Every site has a certificate that makes `https://` work without warnings. Certificates last a little over two years.

**Status per site:**

| Status | Condition | Severity |
|---|---|---|
| Healthy | More than 30 days left | None. Can be shown quietly, for example "Secure · 818 days". |
| Expiring soon | 30 days or fewer left | Warning |
| Expired | Past the expiry date | Error |
| Invalid | Certificate file cannot be read | Error |
| Missing | No certificate file | Error |

**Action: Refresh certificates.** Regenerates the certificates for every site at once. There is no per-site refresh.

- Takes 10 to 60 seconds depending on the number of sites.
- macOS asks for the Mac password, because the local certificate authority is reinstalled.
- Offer this action wherever a certificate problem is shown, and in settings.
- Browsers may need to be restarted afterwards; say so on completion.

### 6.9 Password-free mode setup

Without this, every add, remove, start, and stop would need the Mac password. The app treats this as a one-time setup step and asks for it before the first action that needs it.

**The setup screen must explain, briefly and honestly:**

- What it does: lets Patchy update which addresses point at this Mac without asking for the password each time.
- That it is limited: it grants permission for that one task only.
- That it needs the Mac password once, now.

**The flow:**

1. Explanation and a "Set up" button.
2. A secure password field for the Mac login password. The app passes it to macOS and does not store it.
3. Progress, then success or failure.

**States:**

| State | Shown as |
|---|---|
| Not set up | The setup offer. |
| Out of date | Same flow, described as an update ("Patchy was updated; this needs to be refreshed once"). |
| Enabled | A quiet confirmation in settings. No action needed. |
| Wrong password | Stay on the password step with a clear message. |
| Cannot be installed safely on this Mac | Explain that the app cannot set this up on this Mac, with details available. Rare. |

The user may dismiss the setup. Viewing sites and logs still works; changing actions keep offering the setup.

### 6.10 Menu bar item

Always present while the app runs, including when the main window is closed.

**The icon shows server status at a glance:** running, stopped, working, and needs attention.

**The menu contains:**

- Server status in words
- Start / Stop / Restart
- The list of sites; choosing one opens it in the browser. Must cope with 30 or more sites.
- A marker on sites that have a problem
- Add Site…
- Open Patchy UI (shows the main window)
- Settings…
- Quit

### 6.11 Settings

Groups the things that are set rarely:

- **PHP** — active version and switcher (6.6)
- **Certificates** — overall status and Refresh (6.8)
- **Password-free mode** — status and setup (6.9)
- **General** — launch at login; show or hide the Dock icon when only the menu bar item is in use
- **About** — app version, Patchy version, server version, link to Patchy's website, credit to Joe Workman as Patchy's author

## 7. Feedback and errors

These rules apply to every function.

- **Every action that takes more than a moment shows progress** in plain steps ("Creating secure certificate…"), not raw command output.
- **Every failure states what happened and what to do next** in plain language.
- **Technical details are always available but never the default.** A "Show details" control reveals the exact output from Patchy, with a way to copy it. This serves the experienced user and makes support possible.
- **Success is confirmed by a visible change** (the site appears, the status changes), with a brief confirmation only where the change is not obvious.
- **Only one changing action runs at a time.** While one runs, other changing actions are visibly unavailable; viewing and logs keep working.
- **Destructive or risky actions get a confirmation that names the consequence:** removing a site, adding a real address.

## 8. Language

- Use the plain terms in the left column of the table in section 3.
- Never require the user to know "Apache", "vhost", "sudo", "hosts file", "docroot", or "mkcert". These may appear inside "Show details".
- "Mac password" is the term for the login password macOS asks for.
- Addresses are shown lowercase, as typed in a browser, without `https://` in lists and with it where the user copies or opens.

## 9. Platform expectations

- Native macOS app for macOS 14 and later, built with SwiftUI. It should look and behave like a Mac app: standard sidebar, toolbar, sheets, settings window, and menu bar conventions.
- Light and dark appearance.
- Full keyboard access and VoiceOver labels. Standard shortcuts where they apply (for example, a shortcut for Add Site, and Delete to remove the selected site).
- Status must never be conveyed by colour alone.
- Minimum comfortable window size should still show the site list and one site's detail.

## 10. What the designer decides

- Overall layout of the main window, and how logs relate to site detail (tab, split, or separate window)
- How site health is shown in the list
- The shape of the Add Site flow (one sheet or short steps)
- First-run experience across the "not installed", "password-free mode", and "no sites" states
- Menu bar icon and its status variants
- App icon and visual identity. Patchy has no established visual identity to match; the name comes from Apache's origin as "a patchy server".
- All wording, within the rules in section 8

## 11. What comes back to engineering

For the build, the most useful deliverables are:

- Screens for each app-wide state in section 5
- Each flow in section 6, including its error and progress states
- The site list at 1, 5, and 30 sites, with a mix of healthy and problem sites
- Menu bar icon states and the menu
- Light and dark versions
- Final wording for buttons, warnings, confirmations, and empty states
