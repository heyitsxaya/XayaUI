# XayaUI Patch Notes

<!--
HOW THIS FILE WORKS (read by tools/build_info_pane_data.py; the game shows it in the version pane > Patch Notes).
The game cannot read this file. After any edit, rebuild XayaUI_Options/InfoPaneData.lua with the tool. The tool lives only on
qa-installer-branch (SD-8), and its round 9 change (KEEP_LANDINGS, XUI_ROOT) is NOT there yet: it is pending, with the patch in
docs/plans/R9-INFO-PANE-TOOL-PATCH-2026-11-16.md. Until that patch is applied, QA's tool as it is puts every landing back.
Recent notes only (SD-69, her answer "Recent notes only in game (Recommended)"): the game shows only the newest 5 landings below,
plus an "Older notes" entry pointing to this file; this file keeps every landing.

Style: Blizzard's own patch notes (blue posts). Short past-tense or present-tense bullets ("Added ...", "... now ...",
"Fixed an issue where ..."). Only what is on `main`; never a change that did not land. No intro line.

Layout, newest landing first:
  ## YYYY-MM-DD — Short title                      one per landing on main (UTC date)
  ### <Addon> <version>                            Addon is one of: XayaUI, Options, Chat, Quality of Life, Bonus Features,
                                                   Blizzard Reskin, Dev Assist, Media, Nameplates, Rules, Rules Options. One heading per addon version.
  **Feature name**                                 a bold category line; add " (new)" for a brand-new feature
  - Bullet.                                        a change
    - Nested bullet.                               detail under the bullet above (two spaces)
    *Developers' notes: ...*                       italic, indented under the bullet it explains (two spaces)

What's New (the pane's first entry) is built from this file: every bullet of a "(new)" category, and every top-level bullet
that starts with "Added", newest first, grouped by addon. An addon's list keeps growing through its x.Y.* versions and starts
again when it reaches the next x.Y.0 (e.g. Quality of Life 0.8.0).
-->

## 2026-11-16 — Rules Fix Bundle 1

### XayaUI 0.6.87

**Install (read this first)**
- Replace the XayaUI, XayaUI_Options, XayaUI_Rules, XayaUI_Bonus and XayaUI_Bonus_StatCalculator folders as whole folders, and add the new XayaUI_Debug folder next to them. The rule editor moved from XayaUI_Rules to XayaUI_Options.

**Combat lock (new)**
- The settings window, the rule editor, the mover (/xui unlock), Combat Tracking Setup, the talent scan and /xui enable no longer open in combat. Asked for in combat, one chat line says so, for example "the settings window can't open during combat. It will open when combat ends.", and it opens by itself when combat ends. Only your last request is kept.
- If the settings window is open when combat starts, it closes and opens again where you were when combat ends. Rule edits you had not saved go to Rule Drafts, as on any close.
- Added /xui disable: it turns every rule off at once, in combat too, until you type /xui enable or /reload. /xui enable waits until combat ends.
- /xuiengine full and /xuiengine refresh are removed. Rules and the combat engine are set only in the settings window.
  *Developers' notes: Not yet tested in game.*

**Debug tools (new)**
- The debug tools are now their own addon, XayaUI Debug: the console window (/xui console), the bug report (/xui bug), the debug report (/xui report), /xui status, /xui auras, /xuiengine, and /xui debug status, perf and auras.
- The game reads XayaUI Debug only while Settings > Debugging > Advanced Debugging is on, once per login or /reload. With it off, each of those commands answers with one chat line saying what it needs.
- Added a performance tracker: /xui debug perf on starts it, /xui debug perf shows the report, /xui debug perf off stops it (it also stops by itself after 10 minutes). The report counts the combat engine's re-checks for each kind of re-check, shows the game's own CPU meter and the memory of each XayaUI addon, and gives the most re-checks in one second as a range when it cannot be pinned down, for example "10 to 14" with "(limit 10/s: possibly over)".
  *Developers' notes: Not yet tested in game (QA B402, B424). The tracker reads its counts every 0.23 seconds, so a re-check running steadily at exactly 10 a second can read "possibly over".*

**Advanced Debugging**
- Advanced Debugging is now off by default. If it was on, it stays on.
- While it is on, every login and /reload prints one chat line: "XayaUI: Advanced Debugging is on. Turn it off in /xui > Settings > Debugging."

**Keyboard and mouse**
- Fixed an issue where a XayaUI window first opened in combat could hold every key until combat ended, so the screenshot key, movement and abilities did not reach the game.
- Text boxes now let go of the keyboard when combat starts. The rule search box no longer takes the keyboard back after Esc.
- The minimap button's list no longer puts a click catcher over the game: it closes on Esc or on a click anywhere, and that click still reaches the game.
- The debug report's text no longer takes the keyboard when you click it, so you can take a screenshot of it.
- With the settings window closed, none of its code runs, and nothing it added keeps working in other addons' windows.
  *Developers' notes: Not yet tested in game (QA B419, B420).*

**Commands**
- /xui notes, /xui notepad, /xui note and /xui data now show the command list. Before, they printed a false "did not respond" line.
- /xui debug talents status and /xui debug talents followed by a name now answer at once, in combat too, with the settings window closed. Only the scan itself waits until combat ends.
- A part's commands now work only while that part is on. Typed while it is off, they run nothing and print one line naming the part and where to turn it on, for example "XayaUI: The Calculator is off. Turn it on in /xui > Bonus Features."
- /xui help now lists only the commands you can use right now. The debug tools' commands are listed only while Advanced Debugging has loaded them.

**Saved data**
- The last bug report is no longer kept in your saved settings; /xui bug builds it fresh each time. A detailed debug record left by an earlier XayaUI Dev Assist is cleared once at login.
- An old setting that kept aura displays away from the combat engine is removed once at login, with one chat line. The engine always draws them while any rule is on.

**Developer tools**
- /xui debug mouse (the right-click tracker) is no longer part of this download. It is kept for when the developer tools are rebuilt.
- /xui debug perf ui is removed. Any word after /xui debug perf now goes to the performance tracker.
- Removed leftover code that served only addons that are not part of this download. Your saved settings for those addons are kept.
- The performance tracker's redrawFill line now reads "bar fills and wipe steps written": it always counted both.
- Timers in XayaUI, XayaUI Options and XayaUI Rules no longer make a new function each time they are set, so they leave less for the game to clean up.
  *Developers' notes: Not yet tested in game (QA B423, B424).*

### Options 0.6.110

**Rule editor**
- The rule editor is now part of XayaUI Options, so its code is read only when the settings window first opens. It works as before.
- Combat Tracking Setup, the talent scan (/xui debug talents), the editor's spell and texture lists and the displays' right-click menu moved with it. They work as before.
- Fixed an issue where dragging a slider (bar cues, group layout, Keep up to (drafts)) rebuilt the whole settings window on every step. Keep up to (drafts) no longer deletes drafts while you drag it.
- Fixed an issue where hovering a spell or item search result switched off the game's item comparison tooltips until a /reload.
- Fixed an issue where Duplicate on a group copied only its name.
- The "Let the game play this sound" switch's hover text and the line under it now say plainly what the game's copy can and cannot do, and when XayaUI plays the sound itself instead.
  *Developers' notes: Not yet tested in game (QA B403, B404).*

**Mover**
- The mover (dragging displays and groups on screen) now works only while the settings window is open. /xui unlock opens the settings window with the mover on, and closing the window closes the mover.
- Moves you have not saved are kept when the window closes. The next time you open the settings window, one question asks: Save, Discard (everything goes back) or Keep editing. Nothing is asked at login.
- If combat closes the window, the mover opens again by itself with your moves when combat ends.
  *Developers' notes: Not yet tested in game (QA B405, B425).*

**Combat Tracking Setup**
- Combat Tracking Setup no longer opens over the game by itself after login or a spec change. The very first time you open the settings window, if no spec has a setup yet, it opens with it; after that, use the Open Combat Tracking Setup button on the Rules tab.
- It closes when the settings window closes, so its Learn step records your casts only while the settings window is open.
  *Developers' notes: Not yet tested in game (QA B406).*

**Recycle Bin**
- Fixed an issue where the Recycle Bin page said deleted items are checked every 30 minutes. They are checked when you log in or out and when the page lists them.

### Rules 0.7.2

**Combat engine**
- The engine's speed guard is removed: the engine no longer draws only your current spec's displays, or stops drawing until a /reload, when the game's CPU meter reads high.
- An aura or cooldown change now fully re-checks only the rules whose answer changed. Each kind of re-check runs at most 10 times a second.
- Moving, runes, totems and loss of control (stuns, roots, silences) now re-check only the rules that read them.
- Entering or leaving combat, a boss pull or its end, mounting and joining or leaving a group now re-check only the rules that change with it, instead of every rule. In the test stand-in, the frame at combat start or a boss pull now does a third to almost half less work.
- Talents are read again only when the game reports a talent, loadout, spec, hero talent or PvP talent change. The once-a-second talent check is gone.
- In combat, a hidden cooldown end and a hidden aura time on a display's text are now counted by the game itself.
- A Range Check row on your focus or pet is re-checked five times a second only while you have that focus or pet, and on your mouseover only while you hover a unit. A hidden cooldown end the game gives no timer for is re-checked only while that cooldown runs.
- A Cooldown Manager alert now re-checks only the rules that read that icon.
  *Developers' notes: Not yet tested in game (QA B407, B410 to B416, B426, B427, B430, B433). Measured in the test stand-in, not in the game (instructions, not milliseconds): the costliest frame in a fight is 391,300 Lua instructions, against main's 586,200 in the same test fight, about a third less (391,300 / 586,200 = 66.8%).*

**Displays**
- Fades, flashes, the cooldown sweep, bar fills and the tenths countdown now redraw at most 30 times a second on each display, and only while something on it changes. A display with nothing changing does no work.
- The tenths countdown always shows the tenth not yet gone below, the same on every redraw.
- A display's Out of combat opacity now also applies to displays the combat engine draws.
- A display hidden with the rest of the interface (Alt+Z, a cinematic) no longer keeps redrawing, and shows the right time as soon as it is back.
- Fixed an issue where a deleted group's border and background stayed on screen until a /reload.
- A group's border and background are now drawn on each display, every group, also on displays the combat engine draws. A group with no saved padding uses 0 px.
  *Developers' notes: Not yet tested in game (QA B426, B438).*

**Sounds**
- "Let the game play this sound" now follows the rule's Load tab exactly. The game's copy is given only while every Load choice is met, and taken back the moment one stops being met, in combat too. Combat, boss encounter, talent, Mythic+, group, zone and difficulty choices are all followed: a combat-only copy is given as each fight starts, a boss-only copy at the boss pull.
- If the game refuses the copy as a fight starts or at a boss pull, XayaUI notices and keeps the copy from before the fight for the rest of the session, so the sound still plays. The rule's pane says so and suggests adding the buff to your Cooldown Manager.
- A rule whose buff is in your Cooldown Manager no longer hands its sound to the game: XayaUI plays it itself and follows every setting of the rule, in fights too.
- The rule's pane now says that the game's copy can never repeat or wait for the rule's other triggers, conditions or ANY trigger mode.
- With "Only when mounted" or "Only when not mounted", the game's copy follows your mount, including a dismount straight into a pull.
- Another player changing spec no longer makes XayaUI re-plan its aura sounds.
  *Developers' notes: Not yet tested in game (QA B399, B434, B435). In the first fight of a session in which the game refuses the copy, combat-only and boss-only rules are silent.*

**Backups**
- Each rule backup is now kept as one compact block of text and read only when you load it or show its text, so backups take much less memory. Backups from earlier versions are converted once, at the first login, with nothing lost.
- Older XayaUI versions cannot read the new backups.
  *Developers' notes: Not yet tested in game (QA B408).*

### Bonus Features 0.6.47

**Install (read this first)**
- Replace both the XayaUI_Bonus and XayaUI_Bonus_StatCalculator folders.

**Calculator (new)**
- Added the Calculator: a small calculator window with a keypad, and sums in chat. /xui calc 23,249 / 3,472 prints "XayaUI: 23,249 / 3,472 = 6.696141". /xui calculator and /calc do the same (/calc only when no other addon uses it). /xui calc alone, or Calculator in the minimap button's list, opens or closes the window.
- It has its own tick box at Bonus Features > Calculator, on by default. Off, its commands only say it is off, and the window and its minimap row are gone.
- Enter works the sum out and lets go of the keyboard. The first Esc lets go of the keyboard and the second closes the window. Opened in combat, it does not take the keyboard.
- Your sums and the window's place stay on your computer: a profile carries only its on / off.
  *Developers' notes: Not yet tested in game (QA B437). It is read with XayaUI Bonus Features at login (about 39 KB in the test stand-in) and does nothing until you use it.*

**Stat Calculator**
- The Stat Calculator now loads the first time you open it (the minimap row, /xui stats, or the character window when you left the panel open), not at login. Until then, nothing of it is read.
- Turning it on or off now takes effect at once, with no "Reload now?" question. Turned off after it has loaded, it stops at once, and its memory is freed at your next /reload.
- /xui stats on is removed: turn it on in Bonus Features > Stat Calculator. While it is off, /xui stats says so and where to turn it on.
- It closes when a fight starts and no longer comes back by itself after the fight. Open it again from the minimap row, with /xui stats, or by opening the character window.
- Opening the settings window no longer loads it. Until you have opened it once in a session, its settings page shows its tick box and one line; its options appear after the first open.
- Closing the panel now lets go of what it worked out.
- /xui stats status now says why when the Stat Calculator could not load (for example, when it is switched off in the AddOns list).
- Fixed an issue where the panel's close button sat 2 pixels outside the panel.
  *Developers' notes: Not yet tested in game (QA B436; docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md). In the test stand-in, logging in with it on now uses 602.86 KB less Lua memory (8,326.61 - 7,723.75), and once it has been opened 1,684.57 KB stays until /reload (9,408.32 - 7,723.75).*

## 2026-11-12 — Stat Calculator

### Bonus Features 0.6.46

**Install (read this first)**
- XayaUI Bonus Features now comes in two folders. Copy both `XayaUI_Bonus` and `XayaUI_Bonus_StatCalculator` into Interface\AddOns.

**Stat Calculator**
- The Stat Calculator is now its own addon, XayaUI Bonus Features: Stat Calculator, listed in the game's AddOns list as load on demand. While the Stat Calculator is off, none of it is read. While it is on, it loads once at login (after combat if you log in during combat).
- Turning the Stat Calculator on or off now takes effect after a reload. The game asks "Reload now?".
- Added the Stat Calculator's settings to profiles, as Bonus Features under Profiles > Export and Import. Profiles made with an earlier test version bring them along too.
  *Developers' notes: Not yet tested in game, including how the AddOns list shows the new folder (docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md, section A).*

### Options 0.6.108

**Patch Notes**
- Patch Notes and What's New no longer list features that are not part of this download.

### Bonus Features 0.6.45

**Install (read this first)**
- XayaUI Bonus Features is back in this download and holds only the Stat Calculator. Delete your old XayaUI_Bonus folder before you copy the new one in: its tooltips, Notepad, Calculator and data panels are not part of this version.

**Stat Calculator (new)**
- Added the Stat Calculator: a panel beside the character window with every stat in one Character Stats section, where each number comes from, what the next point buys, the Stat Weights pane, a gear comparison and the Ability Scaling tab. Turn it on in Bonus Features > Stat Calculator. It is off until you do.
- Opens with the character window when you left it open, from the Stat Calculator row in the XayaUI minimap button's list, or with /xui stats. Opened on its own, Esc closes it.
- The panel and its minimap row are hidden in combat and come back after combat.
- Stat Calculator settings saved by an earlier test version are kept.
  *Developers' notes: Not yet tested in game (docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md). There is no Stat Calc button on the character window: that button belongs to Improved Character Display, which is not part of this download.*

## 2026-11-09 — Rules Only

### Rules 0.7.0

**Install (read this first)**
- Delete the XayaUI_Rules_Options folder from Interface\AddOns. The rule editor is now part of XayaUI Rules, so that folder is no longer used.
- XayaUI Bonus Features, XayaUI Chat, XayaUI Dev Assist and XayaUI QoL are no longer part of this download for now. Switch them off in the game's AddOns list or delete their folders: an old copy left on would run against the new XayaUI.
- Keep your XayaUI_Media folder if you put your own pictures or sounds in it. XayaUI still reads it.

**Rule editor**
- The rule editor is now part of XayaUI Rules. It works as before and is still built only the first time the settings window opens.
  *Developers' notes: Not yet tested in game. Its code is now read at login with XayaUI Rules: about 1.4 MB of memory, measured in standard Lua 5.1, not in the game client.*

### Options 0.6.107

**Settings window**
- The settings window now sets up the rule editor from XayaUI Rules instead of loading a separate addon.

## 2026-11-08 — Gradient Borders

### XayaUI 0.6.81

**Themes**
- Added gradient borders to the cursor trail themes: the settings window's frame, panes, buttons and tabs are drawn with a border that runs through the trail's colors. Solid themes draw exactly as before.
- Added a "Reverse gradient direction" switch on the Theme page, under the theme choice. It is independent of the cursor trail's own Reverse, and is saved and shared with the theme.
- Added "Use the gradient as the color of" in Advanced customization, which lets the gradient be the color of any palette color. Six earlier theme strings still import unchanged.
  *Developers' notes: Not yet tested in game (QA B294 to B296; walkthrough "debug-w9"). Issue #460. Chosen for you, change it in the Questions flow: a box's gradient runs left to right and a line along its length; only the settings window and core's flat buttons get gradient borders (not the version pane, the import window, the Blizzard Reskin, Character or Chat windows, dropdown boxes or the Esc menu button); anything else that asks for one solid color still gets the old color; and there is one Reverse per theme.*

### Options 0.6.102

**Theme**
- The Theme page carries the new switch and the gradient color list.

## 2026-11-08 — Debug Batch W7

### Options 0.6.100

**Settings Window**
- Clicking an option in the rule editor now does about half the work it did: the width of dropdown text is measured once and cached (by font, size, flags and scale) instead of on every click. In the test stand-in, game calls per click went from 53,802 to 27,704.
  *Developers' notes: Measured in the test stand-in only, not in game; the real click time needs your re-run of the J31 walkthrough ("perf-settings-click") and the new "debug-w7" walkthrough (QA B293). Issue #467 stays open.*

## 2026-11-08 — Debug Batch W5

### Rules 0.6.80

**Recycle Bin**
- Fixed an issue where the Recycle Bin listed a deleted cue under the wrong name: deleting "Sound 1" of three Sound cues showed "Sound 2". It now lists the cue under the name it had in the rule. The bin's storage format is unchanged.
  *Developers' notes: Not yet tested in game (QA B291, walkthrough "debug-w5"). Issue #485. The "cue in both places" and "restore not played" reports did not reproduce on the data side (105 checks, including real reloads); they most likely came from the old walkthrough's check, which Dev Assist 0.7.53 replaced. Issue #479 (the group Border tick) did not reproduce in 82 checks, so nothing was changed there; it stays open.*

## 2026-11-08 — Debug Batch W3

### Options 0.6.97

**Settings Window**
- Fixed an issue where collapsing the settings window moved its title-bar buttons next to the title. The Close, ? and collapse arrow now stay where they are, also after a redraw while collapsed.
- The window's bottom Close button, the ? button and the collapse arrow now have XayaUI's flat look instead of Blizzard's red buttons, while the window's own skin is on.
- Fixed an issue where the Accept button under "Theme string" was red. Accept, and the Okay button of text boxes, are now flat.
- Fixed an issue where the Reset buttons on the Theme page did not line up and could sit past their box. Reset now sits at the same place in every box, and the color swatches are a share of the box instead of a fixed width.
- Fixed an issue where "Delete saved" ran to the very edge of the Theme page. It now stays inside the page.
  *Developers' notes: Not yet tested in game (QA B287 to B289; walkthrough "debug-w3"). Issues #468, #471 and #478. Not built: the window's X button stays as it is (its X is its art, and which red button you meant is a question), and the Theme page's opacity default is unchanged. "Delete saved" is partly inferred: in game the edge you saw is assumed to be the same flush row.*

### Rules Options 0.6.81

**Rule Editor**
- Fixed an issue where clicking a rule option search result did not show the option. The click now folds the results, opens a closed section on the way and scrolls to the option.
  *Developers' notes: Not yet tested in game (QA B290). Issue #483.*

## 2026-11-08 — Debug Batch W2

### Rules 0.6.79

**Bar Cues**
- Fixed an issue where a bar with no damage type and no dispel type stayed the same fixed blue in every color style. Neon, Pastel and Muted now change it too (Neon 0.00 0.49 1.00, Pastel 0.66 0.83 1.00, Muted 0.39 0.54 0.70). Blizzard default and Custom keep the plain blue.
  *Developers' notes: Not yet tested in game (QA B284, walkthrough "debug-w2"). Issue #461. Also changed along with it: Rules Options 0.6.80.*

## 2026-11-08 — Debug Batch W1

### Rules Options 0.6.79

**Rule Editor**
- Fixed an issue where Devourer (and any spec after a gap in the spec numbers) was missing from the rule editor's Specialization list.
- Fixed an issue where the Cooldown Manager warning could show the same line more than once. Identical lines now show once.
- Fixed an issue where the rule type picker's Import row did not line up with the others.
- Fixed an issue where the type picker drew over the Drafts list.
  *Developers' notes: Not yet tested in game (QA B280 to B283; walkthrough "debug-w1"). Issues #476, #482, #484 and #487. Also changed along with it: Options 0.6.94 and Dev Assist 0.7.62.*

## 2026-11-08 — Element Menu

### XayaUI 0.6.80

**Element Menu (new)**
- Added a right-click menu for XayaUI elements. While the settings window is open, right-click an unlocked rule display, a data panel, the Notepad, the Calculator, the Shopping List, the chat sidebar, the Chat Data Panel or the Character window to get a menu at the cursor.
  - "Element options" opens that element's settings page.
  - X and Y boxes move the element. They are not offered for the chat sidebar, the Chat Data Panel or the Character window.
- Nothing changes with the settings window closed, or in combat.
  *Developers' notes: Not yet tested in game (QA I3). Chosen for you, change it in the Questions flow (#495): which elements get the menu (every XayaUI element with a settings page), that "Element options" opens that page in the window, that X and Y read and write the element's own saved position, and that a restyled Blizzard frame gets "Element options" only. Also changed along with it: Rules 0.6.78, Options 0.6.92, Chat 0.6.44, QoL 0.7.51, Bonus Features 0.6.35 and Dev Assist 0.7.61.*

## 2026-11-08 — Conflict Warnings and Reload on Switch

### XayaUI 0.6.79

**Conflict Warnings (new)**
- Added a conflict warning: when another addon that changes the same thing is loaded (ElvUI, EllesmereUI, Prat, SexyMap, BasicMinimap, TipTac, Plater, KuiNameplates, ThreatPlates or idTip), XayaUI says so once at login and on that part's settings page. Nothing is switched off.

**Reload on Switch**
- Turning Blizzard Reskin, any reskin page, Improved Chat or Nameplates on or off, and /xui chat on|off, /xui reskin on|off and /xui shop, now save and ask for a /reload instead of applying at once. The switch descriptions now say "Takes effect after a reload".
  *Developers' notes: Not yet tested in game (QA I2). Also changed along with it: Options 0.6.90, Chat 0.6.43, QoL 0.7.50, Bonus Features 0.6.34, Blizzard Reskin 0.6.23, Nameplates 0.2.3 and Dev Assist 0.7.60.*

## 2026-11-08 — Settings Migration

### XayaUI 0.6.78

**Saved Settings**
- Each addon now keeps its own saved settings: XayaUIReskinDB, XayaUIChatDB, XayaUIBonusDB, XayaUIQoLDB, XayaUIDevAssistDB and XayaUIRulesDB. They are copied once from the old place (CueRulesDB), which is kept. The old place is never written, and nothing is moved or deleted.
- A rules backup, "Rules before the settings move (<date>)", appears in Profiles > Backups.
- The counts are compared after the copy. If they do not match, that addon keeps reading the old place, and a warning, XUI-W006, is shown once.
  *Developers' notes: Not yet tested in game (walkthrough H16). Removing the old keys is not built (phase P6). Also changed along with it: Rules 0.6.77, Rules Options 0.6.78, QoL 0.7.49, Bonus Features 0.6.33, Chat 0.6.42, Blizzard Reskin 0.6.22 and Dev Assist 0.7.59.*

## 2026-11-08 — Rules Options Folder

### XayaUI 0.6.77

**Install (read this first)**
- Copy the second new folder, XayaUI_Rules_Options, into AddOns as well, next to XayaUI_Rules. The AddOns list gains "XayaUI Rules Options". It loads only when the rule editor opens.
  *Developers' notes: Not yet tested in game (walkthrough H15). You asked to build everything without waiting for your in-game test, so the Accept for the earlier code move (H14) no longer blocks the next phase.*

### Rules Options 0.6.77

**XayaUI Rules Options (new)**
- Added XayaUI Rules Options, a load-on-demand addon that holds the rule editor.

## 2026-11-07 — XayaUI Rules Is Its Own Addon

### XayaUI 0.6.76

**Install (read this first)**
- Copy the new XayaUI_Rules folder into AddOns AND replace the whole XayaUI folder (22 files left it, and GameMenu.lua is now GameMenuButton.lua). Without XayaUI_Rules no rules run.

**XayaUI Platform**
- The XayaUI folder is now titled "XayaUI Platform" in the AddOns list. It keeps your saved data (CueRulesDB), and nothing in it moves. Rules strings you exported before still import.
  *Developers' notes: Not yet tested in game; it needs your in-game Accept (walkthroughs "code-move", "code-move-off" and "code-move-on", QA H14) before phase P5 of the platform split. Replacing the whole XayaUI folder keeps it clean: the game loads only the files the addon's list names, so leftover files are unused.*

### Rules 0.6.76

**XayaUI Rules (new)**
- Added XayaUI Rules, a new addon that holds the rule engine, triggers, cues and displays, combat aura tracking, and rule sharing and the rules Recycle Bin, moved out of the XayaUI folder. You named it ("Call it Rules").
- XayaUI Rules can be switched off in the AddOns list: the rule commands answer that it is off, the Rules tabs and the rules part of Profiles are hidden, and Import shows the rules part as "needs XayaUI Rules".

### Options 0.6.84

**Internal**
- Internal: every addon now reads its settings through ns.Settings(module), and the rule editor and rules tree moved out of Options.lua into their own files (QoL 0.7.48, Bonus Features 0.6.32 and Dev Assist 0.7.57 were updated along with them). Nothing visible.
  *Developers' notes: Not yet tested in game (QA H12 and H13).*

## 2026-11-07 — Platform Services

### Options 0.6.80

**Profiles**
- Added a Nameplates part to Profiles: Export and Import carry your target color.
- Import now skips a part whose addon is not loaded and shows "needs <addon>" for it, instead of dropping it silently.
  *Developers' notes: Not yet tested in game (QA H11; walkthroughs "platform-services" and "platform-services-reload" in /xui dev qa). The rest of this landing is groundwork with nothing visible: profile parts and Recycle Bin kinds that each addon registers itself, theme scopes, and aura and tooltip services for Bonus Features.*

## 2026-11-07 — What Changed Overnight

### XayaUI 0.6.73

**Commands**
- /xui help now lists "/xui data (Data Panels)" in place of "custom data panels and bars".
  *Developers' notes: The hovers of the minimap button, the mover's group tabs and the chat's privacy, history and collapse buttons now share one helper; they read and look as before (QA B279). Not yet tested in game.*

**Engine and Performance**
- Rule and snapshot log lines are now built only while something reads them (the console window, the debug strip, or the record).
- Rules that are not loaded are no longer read during engine steps, except for a buff a display on that rule needs.
- Removed closures that the engine created for every rule read, and most errors from other addons no longer cost a call-stack read.
  *Developers' notes: Measured on stand-ins only, not in game.*
- An aura the game hides now reads "hidden by the game right now ...", and the rule status says whether the game's container still draws the display.

### Options 0.6.72

**Settings Window**
- Added new top tabs: Rules, QoL, Bonus Features, Blizzard Reskin, Profiles and Settings. The toolbar is gone: "+ New Rule" is at the left of the Rules row, and the Settings cog is now the Settings tab. The Blizzard UI Reskin tab is now called Blizzard Reskin everywhere a player reads it, including the Overview switch "Enable Blizzard Reskin" and chat messages.
- Added Profiles, with sub-tabs Import, Export and Recycle Bin. Export has one tick box per component (Rules and groups, Themes, Settings, QoL, Bonus Features, Blizzard Reskin); anything beyond Rules and groups makes a profile string. Import lists only what the string holds, each with a tick box.
- Hover texts are now at most two sentences.
  *Developers' notes: Not yet tested in game. Chosen for you, change it in the Questions flow: which settings each Profiles component holds, and what is never exported (Notepad, Shopping List, Recycle Bin, backups, drafts, calculator history, other players' names). Questions UI-25-newrule, UI-27-components, UI-27-personal, UI-27-merge, UI-27-backups, UI-27-eui and UI-24-label-scope.*
- The settings window now responds faster to clicks when there are many rules: only the rule on screen is built, and a click no longer rebuilds every rule's editor.
  *Developers' notes: Offline measurement only (313 rules, a click from 1,715 ms to about 100-200 ms of Lua). The window's narrowest width now follows only the dropdowns of rules you have opened (Q-PERF-8).*

## 2026-11-07 — Bar Cues

### XayaUI 0.6.58

**Bar Cues (new)**
- Added a Bar cue: a progress bar that tracks an aura's time left, a spell's cooldown or recharge, stacks, or charges. Make one with New Rule > Progress Bar, or Add a cue > Bar on any rule.
  - A new bar is 220 x 22 with a black 20% background, a 1 px border and a flat texture, draining from right to left, with the spell's icon on the left, its name inside the bar, the time on the right and a spark on the moving edge.
  - Tracks: Automatic (the aura, else the spell's cooldown), Aura time left, Spell cooldown / recharge, Stacks, or Charges. Maximum 0 uses the game's own maximum; if the game gives none, the bar stays empty.
  - Drain toward the left, right, bottom or top, or fill up instead. The icon can sit left, right or be hidden. The spark can be turned off and recolored.
  - Automatic color follows the type the spell's tooltip names (a school written as "<school> damage", or a dispel type), then the aura's dispel type, then blue.
  - Color style per bar: Blizzard default, Neon, Pastel, Muted / Dark, or Custom with a color for each of 12 types. A group's Display tab has "Every bar: color style", with "Force on every bar in this group" to override each bar's own choice.
  - Bar textures: Flat, Blizzard, Raid frame, the game's own power-bar art, any texture shared through LibSharedMedia, or your own file.
  - In combat, aura-time and stacks bars are drawn by the game's own aura buttons and keep moving while the game hides aura numbers. Cooldown bars are driven by the game from the cooldown's duration.
  *Developers' notes: Not yet tested in game (QA B200-B210). The combat drawing is built from Blizzard's 12.1.5 source and tested on a stand-in only.*

**Engine**
- Cooldown and aura cues now react one frame after the change instead of up to 58 ms later, and only the rules that read what changed are re-checked.
  *Developers' notes: Measured on a stand-in only (worst delay 58 ms to 8.3 ms, about 12% fewer rule checks), not in game (QA B199, B211, B212).*
- Reworked how closing the settings window ends the previews and unlocks it started (a structure fix to the earlier change).
- Once you have played a spec, its Auto-populate list shows that spec's Cooldown Manager auras and debuffs.

### Options 0.6.59

**Bar Cues (new)**
- Added a Bar Options box on each Bar cue, and "Every bar: color style" on a group's Display tab.
- Smart Categories > Progress Bars now lists rules that have a Bar cue.

## 2026-11-06 — Debug Report, Group Page and Auto-populate Buttons

### XayaUI 0.6.57

**Debug Report (new)**
- Added error codes and a debug report. XayaUI now records only errors and warnings, each with a code (XUI-E...), and only when they happen, so it costs nothing otherwise.
  - /xui report opens a readable summary you can screenshot, with a Copy string you can send.
  - The detailed record kinds (rule snapshots, aura answers and so on) now live in Dev Assist.
  *Developers' notes: Not yet tested in game.*

**Developer Tools**
- The developer diagnostics now exist only while Dev Assist is installed and enabled: /xui debug probe, timing, model, tracker, mods, groups, icons, media, seed, map, gamemenu, chatprobe, widthprobe, perf ui, debuffs and loc, /xuitt probe, lines and aura, /xui chat wrap, indent and whispers, /xuiskin pad and alpha, and /xuiengine auto, on, off and reset.
- Players keep /xui debug perf, /xui debug loader, /xui status, /xui auras, /xuiskin (turns the window skin off), and /xuiengine full and refresh (both removed later, in the 2026-11-10 rules rebuild: rules and the engine are set only in the settings window).
  *Developers' notes: Not yet tested in game.*

**Group Page**
- Added the tabs Group, Display, Load and Config to a group's page, with Group first.
  - Config holds the name, an Enabled switch, the group type, Sound Channel Override, new rule / nested group / delete, and "Made by: <character>".
- Added a group Size (Auto or Set, with optional Clip), and Border and Background tick boxes with color, texture and padding.
- Added "Anchored to: The parent group / The screen" for nested groups.
- Added Align & Arrange to static groups (Align left / center / right, Distribute, Space with a gap). The choice is saved: a display you drag, nudge, add or resize goes back into line.
- Added "Scale items to fit the box" for static groups with a Set size. Making the box smaller than its items asks "Scale the items to fit?" once.
- Added Limit (show at most N) and Align (Top / Center / Bottom, or Left / Center / Right) to dynamic groups.
- A rule's display position now reads "Anchor point", then "Anchored to:", then "To <target>'s point", and changing either no longer moves the display.
- Fixed an issue where "Outside" with a corner anchor acted as "Inside".
  *Developers' notes: Not yet tested in game.*

**Mover View**
- Added arrow-key nudging of the display or group you last clicked: 1 pixel, 10 with Shift. Not in combat.
- Added a small lock on each group's name tab that locks the group for now so you can reach what is under it. Nothing is saved.
- Leaving the mover view after moving something now asks Save moves or Cancel moves; Cancel puts everything back. Moves left by a /reload or logout without Save are offered back at login.
- The same prompt now shows when the settings window closes after it unlocked the displays and something moved.
  *Developers' notes: Not yet tested in game. A game crash cannot keep unsaved moves: the game writes saved data only at logout or /reload.*

**Settings Window**
- Closing the settings window now ends every preview, sidebar movement unlock, group unlock, preview pause and window-made unlock.
- Fixed an issue where previews stayed on screen after the settings window closed.
  *Developers' notes: Not yet tested in game.*

**Rules**
- Added the trigger choice Player State "Dead, not released".
- A rule that is switched off now costs nothing: no engine work and no display frame. Preview still works, and the rule is not shown in the unlock view.
- A talent in a rule's Load tab now clicks through Known (green), Not known (red) and Not set.
- New Sound cues now start on the SFX channel.
  *Developers' notes: Not yet tested in game.*

### Options 0.6.57

**Settings Window**
- Added even, thicker top tabs, no pane borders (a divider line instead), nested rows indented under their parent, and greyed-out settings and names under a feature that is switched off.
- The Blizzard UI Reskin tab now starts with an Overview row. "Enable Blizzard UI Reskin" is a tick box on that page, with a Reload / Later prompt, and the reskins' own pages show once it is on. This replaces the "All reskins" tick box on the tab.
  *Developers' notes: Not yet tested in game.*

**Auto-populate**
- Replaced the Auto-populate buttons with four per spec (and four for the class): Generate All Rules, Generate CD Tracking Rules, Generate Aura Tracking Rules and Generate Target Debuff Tracking Rules. A button filters the table below it, and nothing is made until you press Populate.
  - Added a Select all tick box above the table that ticks only the rows shown.
  - For a spec you are not in, the Aura and Target Debuff buttons list nothing and tell you to switch to that spec first.
- Added a titled auto-populate table: rows grouped under Spell CD, Aura and Debuff, a Spec column when listing every spec, and each spell's icon.
  - Added a Cue set-up column: Speech has a "Customize" box, and Sound and pictures have a picker you must choose from.
  - A row that could not be made stays in the table with an error popup; made rows leave it.
  - On-screen cues are placed in rows of 3 centered on the screen.
  - Added a "Hide / Show already generated rules" switch.
- The Cooldown Manager warning now reads "Blizzard's Cooldown Manager does not offer in-combat tracking for this aura for your current spec. Rule might not work reliably." where the game offers no tracking.
- Combat Tracking Setup moved from the Debugging page to Settings > UI Options > Rule Creation.
- Added the sidebar look: XayaUI's own eye and headphone icons, a flat padlock and a gold move arrow, "Delete (N)", "Move (N)" and "Deselect (N)", and "Link N Selected (move together)" in the right-click menu.
- Pressing a rule row and moving the mouse now starts a drag, with a line or highlighted group showing where it lands.
  *Developers' notes: Not yet tested in game. The button width is an estimate, and the aura and debuff lists rely on an inference about the Cooldown Manager's fields.*

### Options 0.6.56

**Patch Notes and Info (new)**
- Added a pane that opens when you click the version text in the settings window's bottom-left corner. It floats above the settings window, can be dragged by its title bar and reopens where you left it.
  - Patch Notes: What's New (new features only, newest first, per addon) and one entry per update.
  - Info: Version info, Readme, Help (FAQ) and Credits + Acknowledgments.
- Added a ? button to the settings window's title bar, beside collapse and X. It opens Info > Help (FAQ); the pane has the same button.
- Addon Info and Settings > Acknowledgments moved into the pane.
- Esc closes the pane first, then the settings window.
  *Developers' notes: Not yet tested in game (QA B197). In combat the game does not let addons hold Esc back, so one Esc closes both windows there.*

## 2026-11-06 — Character Pane, Shopping List and All Reskins

### Options 0.6.50

**Dynamic Groups**
- The group's Sort choices are now listed Default, Expiration, Name, Important, Manual. Manual is still the default.

### XayaUI 0.6.50

**Console**
- Added a command line to the console (`/xui console`). It takes any XayaUI command, with or without `/xui`; Up and Down bring back earlier commands.
  *Developers' notes: Up / Down recall, and `/save` and `/reload` from the console, are not yet tested in game.*
- All diagnostic commands now live under `/xui debug` (type `/xui debug` for the list) and print in the console. `/xui debug window` is renamed `/xui debug loader`.
- `/xui help` is now shorter: only the commands a player uses.

### Options 0.6.43

**Cooldown Manager Warnings**
- Added a warning when a rule follows an aura or target debuff that the game hides in combat and Blizzard's Cooldown Manager is not tracking. The rule's Display and Cues tabs say where to add it (with XayaUI 0.6.48).
  *Developers' notes: XayaUI cannot add it to the Cooldown Manager for you: Blizzard keeps that window closed to addons.*

## 2026-11-05 — Blizzard UI Reskin tab and Switched-off Features

### XayaUI 0.6.49

**Debugging**
- Added `/xui debug map`, a report command for the full-screen world map problem. It prints the map's state so the cause can be found; it does not fix the problem yet.

### Options 0.6.41

**Class/Spec Rule Creator**
- Added Choose which rules to make: tick only the cooldowns and target debuffs you want, pick each one's main cue, then Make the ticked rules. Your choices are kept per spec.
  *Developers' notes: Two different changes on main carry the label Options 0.6.41. They are listed as they are; history is not renumbered.*
- Switched-off features now cost nothing: a feature you turn off no longer runs timers, listens to events or keeps frames (with Chat 0.6.14, XayaUI 0.6.47, Blizzard Reskin 0.6.2 and Bonus Features 0.6.12).

### XayaUI 0.6.46

**Themes**
- Added each Gradient Cursor Trail gradient as a UI theme in Settings > Theme ("Cursor trail: <name>"). The trail can follow your UI theme, and the Cursor Highlight can use your theme's accent color (with Quality of Life 0.7.17).
- `/xui help` is now one command per line, with the command in your theme's accent color.

### Options 0.6.40

**Settings Window**
- In QoL and Bonus Features, each feature's on / off is now a tick box beside its name in the left pane.
- Notepad and Calculator are now grouped under a new Utilities entry in Bonus Features.
- Scan all talents now lives under Settings > UI Options > Rule Creation (`/xui talents` still works).

### Options 0.6.39

**Settings Window**
- The version text at the bottom of the settings window now replaces the Addon Info button and uses your theme colors.
- Console switches in settings no longer pause while the whole window rebuilds (with XayaUI 0.6.45).
