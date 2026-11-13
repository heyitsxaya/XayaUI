# XayaUI Patch Notes

<!--
HOW THIS FILE WORKS (read by tools/build_info_pane_data.py; the game shows it in the version pane > Patch Notes).
The game cannot read this file. After any edit run:  python3 tools/build_info_pane_data.py
That rewrites XayaUI_Options/InfoPaneData.lua; tests/info_pane_run.py fails while the two disagree.

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

## 2026-11-13 — Druid class theme

### XayaUI 0.6.86

**Class Themes (new)**
- Added class themes: a class can now have its own look under the Class colors theme, ahead of anything else that would color the same part.
- Added the Druid class theme. With Class colors on a Druid, the glow behind a selected rule's top group now runs from Druid orange through lilac to blue, with the orange-to-lilac change spread smoothly across the middle of the bar.
  *Developers' notes: Not yet tested in game. Colors are the design's hex values (hex / 255) in XayaUI/Theme.lua T.CLASS_THEMES; the game draws the glow's 8 colors evenly spaced, so the table holds the even resample of the designed stops (tests/theme_class_glow_run.py checks it). The Druid's "Ready" color (#040A4E) is stored with the theme; nothing draws a Ready label on the glow yet.*

### Options 0.6.109

**Rule List**
- With a class theme that has its own glow (Druid), the selected rule's top group shows that glow, and the group's name turns dark red so it stays readable on the bright bar.
  *Developers' notes: The name (#590E00) reads at 4.95:1 or better over the left 45 % of the bar, where it sits, and 3.61:1 at the bar's far right (blue) end. A settings window with a theme of its own keeps its own glow.*

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
- Players keep /xui debug perf, /xui debug loader, /xui status, /xui auras, /xuiskin (turns the window skin off), and /xuiengine full and refresh.
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
