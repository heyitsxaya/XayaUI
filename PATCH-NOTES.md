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
                                                   Blizzard Reskin, Dev Assist, Media, Nameplates. One heading per addon version.
  **Feature name**                                 a bold category line; add " (new)" for a brand-new feature
  - Bullet.                                        a change
    - Nested bullet.                               detail under the bullet above (two spaces)
    *Developers' notes: ...*                       italic, indented under the bullet it explains (two spaces)

What's New (the pane's first entry) is built from this file: every bullet of a "(new)" category, and every top-level bullet
that starts with "Added", newest first, grouped by addon. An addon's list keeps growing through its x.Y.* versions and starts
again when it reaches the next x.Y.0 (e.g. Quality of Life 0.8.0).
-->

## 2026-11-07 — Chat QA Walkthroughs

### Dev Assist 0.7.10

**In-game QA**
- Added four Chat walkthroughs to /xui dev qa for the old chat issues: move, resize and hide the chat (#210); arrow, button strip, panel and bottom edge (#229); hiding keeps the panel's size with no outlines (#250); one arrow, and the panel follows the chat (#296).
  - "Do it for me" does the setup, the addon reads the chat's real frames, and the last step puts your chat back as it was.
- After the check, these walkthroughs offer an "Accept: Pass" or "Accept: Fail" button with the addon's verdict. Nothing is recorded until you click it, and Pass, Fail and Skip still work.
  *Developers' notes: Not yet tested in game (QA D21). The last step of #296 is a decision for you and has no Accept.*

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

### Chat 0.6.27

**Chat History**
- Added whisper tab lists: "In-game whisper tabs" and "Battle.net whisper tabs" (As the game / Individual tabs / Consolidated tab / Both), and a box to combine Battle.net and in-game whispers in the consolidated tab. Consolidated tabs are named In-Game Whispers, BNet Whispers, or Whispers when combined.
  *Developers' notes: Not yet tested in game. With the combine box ticked and only one kind consolidated, the Whispers tab takes the other kind too; this is picked to revisit after you see it in game (QA D20).*
- The /xui panel help now says "Chat Data Panel settings".

### Quality of Life 0.7.36

**Stat Calculator**
- On-use and proc effects now read "Equipped: <item name>" or "Compared: <item name>", then a line break and the effect line.
- Added a set line under each item: "Set: <name> (with <other equipped items in it>)" under the equipped item, and "Also in <name>" or "Not in <name>: replacing the equipped item breaks the set" under each compared item.
- The armor row now reads "From mastery: <spell name> passive".
- The Ability Scaling table now reads Spell Name | Talent Modifiers | % PSV | Computed Value, with Computed Value left-aligned, a divider line between spells, and each spell foldable by clicking its name.
  *Developers' notes: Not yet tested in game. The set lines assume the game gives every piece of one set the same set number (QA E1z91, E1z92).*

### Options 0.6.59

**Bar Cues (new)**
- Added a Bar Options box on each Bar cue, and "Every bar: color style" on a group's Display tab.
- Smart Categories > Progress Bars now lists rules that have a Bar cue.

### Bonus Features 0.6.20

**Enhanced Tooltips**
- Added a "Type colors" section, on by default. On spell and aura tooltips, a damage school such as "fire damage" is now written "Fire Damage" in the game's color for that school, and a dispel type such as "Magic" takes its dispel color.
  *Developers' notes: Matches English game text only. Not yet tested in game.*

### Dev Assist 0.7.6

**In-game QA**
- Added the Bar cue walkthroughs to /xui dev qa (QA B200-B210, F21).

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

### Chat 0.6.25

**Chat Panel**
- The chat tab names now sit at one height: every docked tab's name is placed at the same spot, and a whisper tab keeps its left alignment at the same height.
  *Developers' notes: Not yet tested in game. No cause was found for "General" sitting lower; if it persists, /xui debug chatprobe lists its anchors (QA D19).*
- Fixed an issue where the Chat Bar sat at the top after the chat was collapsed: collapsed, the bar now drops to the bottom edge and its arrow points up.
- Renamed the Chat Bar to "Chat Data Panel". Added Left of the chat and Right of the chat to "Place the panel", and a panel width slider (40 to 200, default 90) for those sides.
- Added a "The mouse over the chat brings it back" tick box to Fade and hide (on by default, as the mouse always did before).
- Added a choice of click for quick ignore: pick from the free Alt / Ctrl / Shift combinations (plus Cmd on a Mac), or record your own, with a warning when the game also binds the click.
  *Developers' notes: Not yet tested in game (QA D15 to D18). Fn is not offered because no game call reads it.*

### Quality of Life 0.7.34

**Character Pane**
- The character window's text is laid out again once after a size change, so text no longer breaks after widening the window and bringing it back down. /xui reskin status gained a "Size change" line.
  *Developers' notes: Not yet tested in game. The cause is an inference about the game giving old positions right after a resize.*

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
  - Info: Version info, Readme, Help (FAQ) and Credits + Acknowledgements.
- Added a ? button to the settings window's title bar, beside collapse and X. It opens Info > Help (FAQ); the pane has the same button.
- Addon Info and Settings > Acknowledgements moved into the pane.
- Esc closes the pane first, then the settings window.
  *Developers' notes: Not yet tested in game (QA B197). In combat the game does not let addons hold Esc back, so one Esc closes both windows there.*

### Bonus Features 0.6.19

**Data Panels**
- Renamed Custom Data Panels and Bars to Data Panels.

**Enhanced Tooltips**
- The grey "via ..." source text at the end of an Aura ID line now shows only while Dev Assist is enabled.
  *Developers' notes: Not yet tested in game.*

### Dev Assist 0.7.5

**In-game QA (new)**
- Added /xui dev qa (also /xui qa test and /xui qatest): a window of walkthroughs, one step at a time, each with Do it for me and the addon's own check, which never decides for you. Answer Pass / Fail / Skip with a note.
  - Results are saved. The end screen has Screenshot, an Export code and Import a code, and Run again.
  - The list holds every open QA checklist item and every open unverified bug (34 walkthroughs, 330 items).
- Added /xuidev report, which reads back a player's debug report string.
  *Developers' notes: Not yet tested in game.*

## 2026-11-06 — Character Pane, Shopping List and All Reskins

### Chat 0.6.19

**Chat History**
- Fixed an issue where the chat history window dropped the letter after a literal "|" (r, n, c, T, H, A, K).
  *Developers' notes: Not yet tested in game (QA D12, D13).*

### Quality of Life 0.7.32

**Shopping List (new)**
- A panel that lists what your gear is missing and what your tracked recipes need. Off by default: turn it on with the tick box on the Shopping List row of the Blizzard UI Reskin tab. `/xui shop` shows or hides it (`/xui shop options`, `/xui shop status`).
  - Missing on your gear: each enchantable slot without an enchant and each empty socket, with one suggestion each. "+ Add" puts a suggestion in To buy.
  - Your tracked recipes: each with its reagents and have / need, counted the way Blizzard's tracker counts them.
  - Click a name while the Auction House is open to search for it there; Shift-click links the item.
- Blizzard's Professions list in the objective tracker now takes your theme's colors (its own switch: "Restyle Blizzard's Professions list").
  *Developers' notes: Which gems count as the one-per-character gem, and how enchant scrolls in your bags are counted, are not yet confirmed in game.*

### Quality of Life 0.7.31

**Character Pane**
- Added an Extra height slider (0 to 300 px, default 0) beneath Extra width. The slots spread out evenly, the model gets taller, and the weapons move down with the bottom of the window.
- Added a full stat list: the character window's stats pane can now show every line of the Stat Calculator's Character Stats, each name in its stat color. Arrange it under Character Pane > Stat list.

**Release Guard (new)**
- When you die, a box now covers the Release Spirit button so a misclick does not release you. Hold Shift (or Ctrl or Alt, in settings) to click through.
  *Developers' notes: Release Guard never presses Release for you; it only covers the button. Not yet tested in game.*
- Off by default. Turn it on under QoL > Release Guard. Works in raids only to start, or in raids and dungeons, or everywhere.

### XayaUI 0.6.51

**All Reskins**
- Added an All reskins tick box on the Blizzard UI Reskin tab button. Untick it and every reskin is off at once, with Blizzard's own look back (with Options 0.6.50, Chat 0.6.18 and Blizzard Reskin 0.6.4).
- Each reskin (Chat Panel, Character Pane, Esc Menu, Shopping List) now has its own tick box on its row, greyed while All reskins is off.

### Options 0.6.50

**Dynamic Groups**
- The group's Sort choices are now listed Default, Expiration, Name, Important, Manual. Manual is still the default.

### XayaUI 0.6.50

**Console**
- Added a command line to the console (`/xui console`). It takes any XayaUI command, with or without `/xui`; Up and Down bring back earlier commands.
  *Developers' notes: Up / Down recall, and `/save` and `/reload` from the console, are not yet tested in game.*
- All diagnostic commands now live under `/xui debug` (type `/xui debug` for the list) and print in the console. `/xui debug window` is renamed `/xui debug loader`.
- `/xui help` is now shorter: only the commands a player uses.

### Chat 0.6.17

**Chat History**
- Fixed an issue where a "|" in a chat line, and sometimes the letter after it, went missing in history.
  *Developers' notes: Whether copying such a line pastes one "|" or two is not yet tested in game.*

### Quality of Life 0.7.27

**Character Pane**
- Fixed an issue where players who used QoL 0.7.21-0.7.23 kept those versions' 240 px extra width. It now changes once to the new 42 px default; any other width you chose is kept.

### Bonus Features 0.6.17

**Utilities**
- Added `/notes` and `/calc`, short forms of `/xui notes` and `/xui calc`. If another addon already owns either word, XayaUI leaves it alone.

### Bonus Features 0.6.16

**Calculator**
- Added an on / off tick box for the Calculator (Bonus Features > Utilities > Calculator), on by default. Off, its window does not open; `/xui calc <sum>` still answers in chat.

### Bonus Features 0.6.14

**Enhanced Tooltips**
- The Tooltips feature is now called Enhanced Tooltips and has one tick box that turns the whole feature on or off.

**Notepad**
- The Notepad's tick box now turns the whole Notepad off, sharing included. Your notes are kept.

### Bonus Features 0.6.13

**Tooltips**
- On spell tooltips, an aura icon ID that is the same as the spell's own icon is no longer repeated.

### Chat 0.6.16

**Chat History**
- Added whisper tabs: whisper conversations get their own tabs, following the game's New Whispers setting, or all in one Whispers tab (History > Whisper tabs).

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

### Chat 0.6.15

**Chat History**
- The history window now opens on the chat tab you are on, with All moved to the end.

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

### Options 0.6.38

**Blizzard UI Reskin (new)**
- Every reskin now has one home: a Blizzard UI Reskin tab with Chat Panel, Character Pane and Esc Menu. The old Chat tab is gone; `/xui chat settings` and `/xui reskin options` still open the moved pages.
