# XayaUI QA checklist (0.6.1)

For testers. Tick each box in order; when something does not match the **Expect** line, stop that section and report it (see the end). Every step lists what you should see, so "it looked fine" is never a guess.

**Before you start:** in the game, type `/console scriptErrors 1` once (shows Lua errors on screen). If you use BugSack or a similar error catcher, keep it on.

---

## A. Install (5 minutes)

- [ ] **A1.** In `World of Warcraft\_retail_\Interface\AddOns\`, put these folders side by side (the game can stay open; `/reload` afterwards): `XayaUI`, `XayaUI_Options`, `XayaUI_Chat`, `XayaUI_QoL`, `XayaUI_Bonus`, `XayaUI_Reskin` (and `XayaUI_Media` if you have one). Each must sit directly in `AddOns` (not inside another folder).
  **Expect:** `AddOns\XayaUI\XayaUI.toc`, `AddOns\XayaUI_Chat\XayaUI_Chat.toc`, and so on exist.
  Using GitHub Desktop? Clone outside the game folder and copy the `XayaUI*` folders from the clone into `AddOns`; after each "Pull origin", copy them again and `/reload`. The **Expect** line above still applies.
- [ ] **A2.** If you had 0.5.x: delete or switch off `AddOns\XayaUI_CombatEngine` if it exists.
- [ ] **A3.** Start the game. At the character screen open **AddOns**.
  **Expect:** XayaUI with its entries grouped under it: XayaUI Options, XayaUI Chat, XayaUI QoL, XayaUI Bonus Features, XayaUI Blizzard Reskin. None marked "out of date" or "missing dependency".
- [ ] **A4.** Log in. **Expect:** no red Lua error. Chat shows no XayaUI error lines.

## B. Core (rules)

- [ ] **B1.** Type `/xui`. **Expect:** the XayaUI window opens (the first time can take a moment: the settings window loads now). Tabs along the top include Chat, QoL, Bonus Features, Import / Export.
- [ ] **B2.** `/xui` again. **Expect:** the window closes.
- [ ] **B3.** Open the game's Options > AddOns > XayaUI and press **Open XayaUI**. **Expect:** the game's options close and the XayaUI window opens.
- [ ] **B4.** Minimap button: left-click. **Expect:** a list with Notes, Settings, Custom data panels, Chat Panel, Chat privacy cover. Right-click: the window opens.
- [ ] **B5.** Make a rule (for example a sound when a spell comes off cooldown) and trigger it. **Expect:** it plays as it did in 0.5.x.
- [ ] **B6.** Your existing rules (if you had 0.5.x): all there, all still working.
- [ ] **B7.** `/xui status` and `/xui unlock` (twice). **Expect:** a status printout; unlock shows movable displays, the second one locks them.
- [ ] **B8.** A rule with a **Boss encounter** load condition set to "Only during a boss encounter": enter a boss fight. **Expect:** the rule loads during the fight (this was broken for some clients before 0.6.0).
- [ ] **B9.** A rule whose Actions **say** something in /say or /yell inside a dungeon, or in group chat: trigger it. **Expect:** the message is sent (also fixed in 0.6.0).

### B-engine. What displays show in combat (XayaUI 0.6.3). Use a training dummy; type `/xuiengine` first and keep its printout for the report.

- [ ] **B10.** A buff rule with an icon display, **Duration text** on, not in a dynamic group (for example Anti-Magic Shell or Power Word: Shield). Cast the buff in combat. **Expect:** the time counts down in combat, in XayaUI's format (`12`, then tenths such as `4.3` below 5 s if tenths are on), in the font, size and colour set on the display (before 0.6.3 it was small white text with an `s`). If it shows `12s` style instead, `/xuiengine` must say "time text in the game's own format" for that display: report that line.
- [ ] **B11.** The same rule with **Stacks** on, on a buff that cannot stack. **Expect:** no number (before: `0` or `1`). On a buff that stacks: the number from 2 stacks up, in combat too.
- [ ] **B12.** The same display with **Shield / absorb amount** on (source "this aura" or "total"). **Expect:** the amount shows over the engine's icon, in and out of combat. With **Abbreviate** off and **Hide when zero** on, nothing shows when you have no shield. (With both on, a `0` can show: known game limit, listed by `/xui timing`.)
- [ ] **B13.** A rule with an icon cue and a separate **Text** cue showing the duration (the #347 shape, no conditions). **Expect:** both show in combat; the Text cue's time is exact (counts down smoothly, no jumps when you recast). `/xuiengine` ends its summary with "plus 1 separate time / stack display".
- [ ] **B14.** A "Target Debuff (yours)" rule (the debuff as its only trigger, not in a dynamic group). Apply the debuff to dummy A, then target dummy B (no debuff), then back to A. **Expect:** the icon disappears at once on B and comes back at once on A, with A's remaining time (before 0.6.3 it could keep showing A's debuff on B).
- [ ] **B15.** A cooldown rule shown while the spell is **not ready**, with Duration text on. Use the spell in combat. **Expect:** the text counts the cooldown down to 0 (exact), and the global cooldown alone shows no countdown. A spell with charges: the time to the next charge.
- [ ] **B16.** A display with **Only while on an action bar** on: remove the spell from your bars. **Expect:** the display hides, also when the engine draws it.
- [ ] **B17.** `/xui timing`. **Expect:** one line per rule that uses time or stacks, no Lua error.
- [ ] **B18.** Out of combat with a proc or buff on you: `/xui auras`. **Expect:** one line per buff with its ID, stacks and time, and a second line with readable in combat / Cooldown Manager / Blizzard flags; no Lua error. Turn a listed buff on in Blizzard's Cooldown Manager (Tracked Buffs) and run it again: that buff now says "on and shown".
- [ ] **B19.** In combat: `/xui auras` says the game hides aura details right now; `/xui auras <an ID from B18>` still prints that spell's three facts. Paste both outputs into the report (testers with Divine Arbiter or Boiling Blood / Boiling Point: please include those).
- [ ] **B20.** A dynamic group of 3 or more buff rules (your Active Mitigation group works), Sort = **Manual**. Use the buffs in combat in a different order than the rules. **Expect:** the icons always show in the rule order, with no gaps; a buff that appears takes its place between the others. Then drag one rule to another place in the group (out of combat): the order follows.
- [ ] **B21.** Same group, Sort = **Expiration**, then **Important**, then **Name**, each with and without **Reverse**. **Expect:** the order changes accordingly, no Lua error; `/xuiengine` names the sort. Back to **Manual**: the rule order returns. **Save order and reload** reloads with the order kept.
- [ ] **B22.** (0.6.7) A dynamic group with Sort = **Manual** and Spacing 4, 3 or more buffs up in combat. **Expect:** the icons are 4 pixels apart, the same as unlocked (0.6.6 put them 8 apart in combat).
- [ ] **B23.** (0.6.7) Same group, Grow direction **Centered row**. Use the buffs one by one in combat. **Expect:** the row stays centered on the group's position and widens both ways as each buff appears, and closes up when one ends. Unlock the group: the preview shows the same spots.
- [ ] **B24.** (0.6.7) Grow direction **From anchor point, rows**, then set This group's anchor point to TOPRIGHT, then BOTTOMLEFT, then BOTTOM. **Expect:** TOPRIGHT: icons start at the group's top right and grow left; BOTTOMLEFT: start bottom left, grow right, new rows above; BOTTOM: centered on the bottom middle. In combat the icons stay on those spots as buffs come and go. Also try **From anchor point, columns**.
- [ ] **B25.** (0.6.8) Unholy, Death and Decay in the Cooldown Manager's Tracked Buffs, Insivius's rule (Death and Decay ready AND its buff 188290 / 434034 missing, loaded in combat; Condition 1: buff AND charges == 2 shows a texture and plays a sound). In combat with both charges, not standing in it: **Expect:** the texture shows and the sound plays; step into it: they stop; with one charge: they stay off. `/xui status` in combat shows the rule's buff answer coming from "CDM tracked buff of the rule's spell 43265".
- [ ] **B26.** (0.6.9) Insivius's Death and Decay rule (2 charges from Death's Echo). In combat, use one charge and step out of it: **Expect:** the texture and sound do NOT fire until the second charge is back (0.6.8 fired right after the cast). Use both: nothing until both are back. `/xui status` in combat shows the cooldown line "charges (max 2): ..." with how the count was found.
- [ ] **B27.** (0.6.9) A rule on a spell with 3 charges (`docs/reference/charges.md`), condition "charges == 2", the spell in Blizzard's Cooldown Manager: use one charge in combat. **Expect:** TRUE at 2, FALSE at 1 and 3. Without the spell in the Cooldown Manager: unknown below full (the rule does not fire), exact again at full or 0.

## C. Settings window switched off

- [ ] **C1.** At the character screen switch off **XayaUI Options** only. Log in, type `/xui`. **Expect:** one line saying the settings window is switched off and how to turn it on. Rules still work. No Lua error.
- [ ] **C2.** Switch XayaUI Options back on.

## D. XayaUI Chat

- [ ] **D1.** With Chat on: **Expect** the restyled chat panel as before; `/xui chat` prints its commands; `/xui chat settings` opens Chat > Chat Panel.
- [ ] **D1b.** In the window: Chat > Chat Panel. **Expect:** the Chat Panel page shows Enable Chat Panel and the theme switch; under Chat Panel in the left pane: Layout, Appearance, Chat Bar, Fade and hide, Filters, History, Sounds, Privacy. Click Appearance: tabs Background and border | Chat text | Tabs | Input line. Click Privacy: tabs Look | Button | Area and behavior. Every setting you had before is still there and keeps its value.
- [ ] **D1c.** Right-click a block on the Chat Bar. **Expect:** the window opens on Chat > Chat Panel > Chat Bar, Blocks tab.
- [ ] **D2.** A keyword or filter rule on the Chat Panel's Filters tab (for example highlight your name): have someone say it. **Expect:** it is highlighted or filtered (fixed in 0.6.0 for clients without the old chat functions).
- [ ] **D3.** Click the input area under the panel. **Expect:** the chat edit box opens. Collapse the panel while typing. **Expect:** the edit box closes.
- [ ] **D4.** `/xui privacy` twice. **Expect:** the cover hides the chat, then shows it again.
- [ ] **D4b.** (0.6.5) Type `/xui` so a long help line prints. **Expect:** the lines after the first of that message start further in than "XayaUI:". `/xui chat indent` prints `indent wrapped lines: setting on, the window's font on, its first line on`. Layout > Indent wrapped lines off: the lines start flush again.
- [ ] **D4c.** (0.6.5) A slim scroll bar sits right of the chat text. Click the up arrow once: **Expect** the chat moves up exactly one line. Hold it: after a short pause it keeps moving at about 6 lines a second; let go and it stops. The down arrow goes back toward the newest line. Drag the thumb; click above or below it (one page). Switch tabs: the bar scrolls the tab you see. Layout > Chat Panel scroll bar off: the bar goes and the text gets the space back.
- [ ] **D4d.** (0.6.5) Open the history window (corner button). **Expect:** a **Console** tab button at the end of the row. Run `/xui chat wrap`, click Refresh: the printed lines are listed under Console, and not under All or General.
- [ ] **D4e.** (0.6.5) `/xui chatprobe` inside a dungeon or in combat. **Expect:** no "chat probe failed ... Probe.lua:229 ... secret boolean" line; it prints "chat probe: N lines kept".
- [ ] **D5.** Switch **XayaUI Chat** off, /reload (or relog). **Expect:** Blizzard's normal chat; the Chat tab is gone from the window; the minimap list has no Chat rows; `/xui chat` says XayaUI Chat is switched off. No Lua error. Switch it back on.

## E. XayaUI QoL

- [ ] **E1.** QoL > Cursor. **Expect:** the Cursor page has two switches (Cursor Highlight, Gradient Cursor Trail), and both appear under Cursor in the left pane. Switch both on. **Expect:** the ring and trail follow the mouse; the ring textures show (not green squares).
- [ ] **E1b.** Click Cursor Highlight on the left. **Expect:** its switch at the top and the tabs Shape | Color and Size | Behavior. Click Gradient Cursor Trail. **Expect:** Colors | Dots | Behavior. Switch an effect off: its tabs go away, the switch stays.
- [ ] **E1c.** Type `/xui cursor`, then `/xui cursor trail`. **Expect:** the window opens on the Cursor page, then on Gradient Cursor Trail (no "did not respond" line).
- [ ] **E1d.** QoL > Character Toolkit: switch it on, open the character window (C). **Expect:** a panel on the right of the character window with Ratings, Defense and linked stats, Offense. Crit shows your rating, lost 0 (unless you are past a threshold), rating per 1%, and a next threshold. Compare its crit percent from rating with Blizzard's crit tooltip: they should match. `/xui stats status` should say "converter present".
- [ ] **E1d2.** Haste is the best in-game test of diminishing returns: at 1,287 haste rating = 29.25% (44.0 rating per 1%), the first threshold should sit near 1,320 rating (30%). **Expect:** Haste shows "Next threshold" about 33 rating away. If it says the converter shows none, the game's converter does not apply diminishing returns; then gear past 1,320 haste rating should show the orange "converter disagrees" line.
- [ ] **E1e.** Hover Critical Strike in Blizzard's stat list. **Expect:** a "XayaUI Character Toolkit" block under Blizzard's text. Hover Mastery in the panel. **Expect:** the threshold list and your mastery factor.
- [ ] **E1e2.** Panel tabs: click Overview, Ratings, Defense, Offense, Gear, Spells. **Expect:** each fills in without an error. Overview: your mastery text ("Increases Armor by ..% of your Agility" for Vengeance) and a one-line list of every stat. Ratings > Leech: "Other sources" equals your whole Leech if you have no leech rating. Gear: item levels match your gear; Gear totals' crit "character" figure matches Blizzard's crit tooltip rating (528 in Xaya's screenshot).
- [ ] **E1e3.** Type 200 in "What if +" and press Enter. **Expect:** every rating shows "What if +200 rating"; Mastery's gain is about 200 / 16.4 = 12.2% for Vengeance at 997 mastery (if no threshold is crossed).
- [ ] **E1f.** Cast any spell out of combat. **Expect:** Global Cooldown in the panel shows the GCD (about what your GCD display shows). Spell Math tab: switch it on, add Fracture (or any damage spell). **Expect:** its description numbers with a percent of attack power.
- [ ] **E2.** Switch **XayaUI QoL** off, relog. **Expect:** no cursor changes, no QoL tab, no error.

## F. XayaUI Bonus Features

- [ ] **F1.** `/xui notes`. **Expect:** the Notepad box with its icon toolbar (icons, not green squares). Type, close, reopen: the text is still there.
- [ ] **F2.** Bonus Features > Custom Data Panels and Bars: switch on the left panel. **Expect:** the strip appears with its data. Hover the FPS block: addon CPU and memory lines.
- [ ] **F3.** Hover a spell or item. **Expect:** ID lines as configured on Bonus Features > Tooltips.
- [ ] **F4.** Chat and Bonus both on: the Chat Bar and the data panels both show their blocks. Then switch only **XayaUI Chat** off: the data panels still work. Then only **Bonus** off (Chat on): the Chat Bar still works.
- [ ] **F5.** Switch **XayaUI Bonus Features** off, relog. **Expect:** no notepad, no panels, plain tooltips, no Bonus Features tab; `/xui notes` says Bonus Features is switched off.

## G. XayaUI Blizzard Reskin

- [ ] **G1.** Settings > UI Options > Display > Game Menu look: switch it on, press Esc. **Expect:** XayaUI's look on the Game Menu; every button does what its label says (Options, Shop, Log Out, Exit Game, Return to Game).
- [ ] **G2.** Switch **XayaUI Blizzard Reskin** off, relog. **Expect:** Blizzard's Game Menu; the XayaUI button in it still opens the window; the Game Menu look options are gone.

## H. Import / Export and backups

- [ ] **H1.** Right-click a rule > Export. Copy the text. Press **Import** (top bar), paste. **Expect:** "Readable rules", then Import adds it as a new folder "Imported: ...".
- [ ] **H2.** Settings > UI Options > Theme: export the theme. Paste that theme text into the **Import** button's window. **Expect:** "Readable: a theme"; Import applies it. Paste the same theme text into Import / Export > Import rules. **Expect:** a message that this text holds a theme and where themes are imported.
- [ ] **H3.** Paste an export you made with 0.5.x (if you kept one). **Expect:** it still imports.
- [ ] **H4.** Start an import in combat (training dummy). **Expect:** a line that it will be imported when combat ends; after combat it is there.
- [ ] **H5.** Import / Export > Backups: name one, **Save a backup**, change a rule, **Load (replace)** the backup. **Expect:** the rule is back as it was.

## I. Reload and logout

- [ ] **I1.** `/reload` twice with everything on. **Expect:** no error, settings unchanged.

---

## J. Game Data Capture (developer tool, XayaUI_GameDump 0.4.0)
- [ ] J1. `/xuidump api`: chat reports the counts (global functions, C_ namespaces, enums, numeric constants, widget types) with no Lua error. `/xuidump save`, then the file `XayaUI_GameDump.lua` has an `api` table.
- [ ] J2. `/xuidump toolkit` out of combat, away from a vendor: chat prints the GetSpellBaseCooldown, repair, preview-link and stat-pane lines with no Lua error.
- [ ] J3. `/xuidump toolkit` again while talking to a repair vendor; then `/xuidump save` and upload the file.
- [ ] J4. (GameDump 0.5.0) Out of combat, after button 1 (`/xuidump static`): `/xuidump catalogue`. **Expect:** progress lines in the window, then "aura catalogue done" with the counts and no Lua error, in under a minute. `/xuidump status` names the catalogue. Run it once on each spec you play, then `/xuidump save` and upload the file.
- [ ] J5. (GameDump 0.5.0) Start `/xuidump catalogue` and pull a training dummy while it runs. **Expect:** it pauses in combat and finishes after combat ends. Open the Adventure Guide afterwards: the tier and loot filter you had are still selected.
- [ ] J6. (GameDump 0.5.0) `/xuidump seen`, then play out of combat and in combat for a while, and `/xuidump seen` again. **Expect:** "aura log OFF" with a count; button 8 shows ON while it runs.

## Reporting a problem

Send, for each problem:
1. The step number (for example **D3**) and what you saw instead of the **Expect** line.
2. Which XayaUI addons were switched on.
3. The text of `/xui bug` (it opens a window with the error log; copy it), or the BugSack entry.
4. A screenshot if it is about how something looks.
