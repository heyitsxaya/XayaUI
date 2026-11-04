# XayaUI QA checklist (0.6.1)

For testers. Tick each box in order; when something does not match the **Expect** line, stop that section and report it (see the end). Every step lists what you should see, so "it looked fine" is never a guess.

**Before you start:** in the game, type `/console scriptErrors 1` once (shows Lua errors on screen). If you use BugSack or a similar error catcher, keep it on.

---

## A. Install (5 minutes)

- [ ] **A1.** Close the game. In `World of Warcraft\_retail_\Interface\AddOns\`, put these folders side by side: `XayaUI`, `XayaUI_Options`, `XayaUI_Chat`, `XayaUI_QoL`, `XayaUI_Bonus`, `XayaUI_Reskin` (and `XayaUI_Media` if you have one). Each must sit directly in `AddOns` (not inside another folder).
  **Expect:** `AddOns\XayaUI\XayaUI.toc`, `AddOns\XayaUI_Chat\XayaUI_Chat.toc`, and so on exist.
  Using GitHub Desktop? Follow `QA-INSTALL.md` on the `qa-installer-branch` branch instead of copying folders by hand; the **Expect** line above still applies.
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

## Reporting a problem

Send, for each problem:
1. The step number (for example **D3**) and what you saw instead of the **Expect** line.
2. Which XayaUI addons were switched on.
3. The text of `/xui bug` (it opens a window with the error log; copy it), or the BugSack entry.
4. A screenshot if it is about how something looks.
