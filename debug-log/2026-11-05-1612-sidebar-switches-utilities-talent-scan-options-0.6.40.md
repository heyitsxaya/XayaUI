# Sidebar tick boxes, Bonus Features > Utilities, the talent scan in Settings (Options 0.6.40, QoL 0.7.18 (written as 0.7.16; 0.7.17 reached main first), Bonus 0.6.11)
Logged 2026-11-05 16:12 UTC. Worktree branch of `claude/adoring-hawking-wyda59` (base b8017df). Not run in game.

## Requests (Xaya, 2026-11-05, her words)
- A: "move all enable/disable toggles onto the sidebar instead for all bonus features and QoL items" (screenshot: the Bonus Features
  left pane with Custom Data Panels and Bars, Notepad, Tooltips as plain rows).
- B: "Under bonus features, create "Utilities" Group and nest Notepad and Calculator".
- C: "scan belongs in Settings" (screenshot: the "All talents (every class and spec)" section of Rules > Class/Spec Rule Creator).

## A. Tick boxes in the left pane
### Mechanism (XayaUI_Options/Options.lua, next to ROW_TOGGLES)
- A page or a part that has one on / off carries it as `group.xuiSwitch`: an ordinary AceConfig toggle that is no longer in its
  `args` (so the page does not draw it). The window draws it as a tick box on that row of a feature tab's left pane and calls the
  switch's own `get` / `set` (the same functions the in-page switch used, so every side effect stays), with the info table
  AceConfigDialog would give a toggle there (path, then "xuiSwitch"). Hover: the switch's name and desc (the old switch's text).
- Only trees whose path is one feature tab (`ns.OptionsApi.TABS`) are looked at: the window repaints every row 4 times a second and
  the Rules trees skip at once.
- Placement (#369, name room): every row keeps an empty 16 px slot left of its name for the open / close arrow. A row without parts
  gets the box in that slot (0 px taken from its name). A node with parts (Character Toolkit) gets the box right after the arrow
  slot; only its name moves right, by 17 px. That place is chosen from the node's structure (it has part groups), not from whether
  the arrow shows now, so the box does not jump under the mouse when the toolkit is ticked and its parts (hidden while it is off)
  appear. A first version put the box at the row's right end (20 px from every box row's name); dropped for the above.
- Click: `Tree.SwitchClick` runs the set with `Tree.hold` on (Notify returns at once, so redraw requests the set makes are
  dropped), cancels a pending console "view" redraw, then makes exactly one redraw that reuses the drawn tree (`Tree.Keep`), unless
  AceConfigDialog already has a fresh redraw pending (then that one is the only redraw). Measured in the harness: 1 redraw and 0
  tree builds per click. (The in-page switches redrew through AceConfigDialog's own redraw after a toggle plus the set's Notify,
  the pattern measured for the console switches in Options 0.6.39 at 2 builds and 2 redraws a click; not re-measured for these.)
- Why reusing the tree is safe here (Tree.Keep's rule): every switch's state is read only by functions inside the tree (get / hidden
  / disabled / name), never while it is built. Proof in the test: the whole options tree is built with each switch off and on and
  compared (everything but functions), with a control (two builds in a row are equal). A new switch that breaks this fails the test
  (the test lists every `xuiSwitch` in the feature tabs and fails on any it does not know).
- Click target: the box is a mouse-enabled child of the row, three frame levels above it. INFERENCE (standard behaviour, not stated
  in the API documentation; the rule rows' eye / lock buttons rely on it too): the game hands a click to the topmost mouse-enabled
  frame under the cursor, so a click on the box does not select or open the row.
- API (V2), from docs/reference/api/widgets.md (CheckButton): `SetChecked(checked: bool = false) · SecretArguments=AllowedWhenUntainted`,
  `GetChecked() → checked: bool`, `SetEnabled(enabled: bool) · SecretArguments=AllowedWhenUntainted`,
  `SetFrameLevel(frameLevel: number) · IsProtectedFunction, SecretArguments=AllowedWhenUntainted`, `EnableMouse(enable: bool = false) ·
  IsProtectedFunction, SecretArguments=NotAllowed`, `GetParent() → parent`. Template UICheckButtonTemplate (already used by
  ROW_TOGGLES in this file). No secret values pass through any of them.

### Which rows have a box (decisions; the switch is gone from the page)
| Row | Saved setting | Old in-page switch(es) removed |
|---|---|---|
| QoL > Character Toolkit | characterToolkit.enabled | page: enabled, and the overview's quick switches panelOn, overlaysOn, tooltipsOn |
| Character Toolkit > Panel | characterToolkit.panel | Layout tab: "Show the panel" |
| Character Toolkit > Slot Overlays | characterToolkit.overlays | Show tab: "Slot overlays" |
| Character Toolkit > Spell Math | characterToolkit.advanced | "Spell Math" |
| QoL > Cursor > Cursor Highlight | cursorHighlight.enabled | page: "Cursor highlight"; Cursor overview: "Cursor Highlight" |
| QoL > Cursor > Gradient Cursor Trail | cursorTrail.enabled | page: "Gradient cursor trail"; Cursor overview: "Gradient Cursor Trail" |
| Bonus > Custom Data Panels and Bars | dataPanels.general.enabled | General tab: "Enable Custom Data Panels and Bars" |
| Bonus > Utilities > Notepad | notepad.shown | "Show Notepad" |
No box: QoL > Cursor (two separate effects, no single switch), Bonus > Tooltips (four sections, each with its own switch on its tab;
no master), Bonus > Utilities (a group), Utilities > Calculator (nothing to switch). The Character Toolkit's "Tooltip lines" switch
(characterToolkit.tooltips) has no row of its own: it stays on Panel > Tooltips; its duplicate on the toolkit's overview is removed.
Data Panels' per-panel Enable switches are sections on the General tab (not rows): unchanged. The Blizzard UI Reskin tab is not
part of the request: unchanged. The shelved QoL Elements rows (ROW_TOGGLES: Stat Tracking, Cursor Tracker, Buff Bars) keep their
old left-of-name box (their files are not loaded).

### Off costs nothing (V14): what each box's off path does (not changed here; a separate audit is running)
- Cursor Highlight / Gradient Cursor Trail: off clears the OnUpdate and hides the frame (harness: OnUpdate nil after unticking).
  Each file creates one frame registered for PLAYER_LOGIN at load, whether on or off (it fires once).
- Character Toolkit: off unregisters its events and hides the panel and overlays. Hooks placed while it was on stay until /reload
  (game limit); `PaperDollFrame_UpdateStats` and the character window's OnShow hook still run `HookStatFrames` while it is off
  (hooks new stat rows; the tooltip, overlay and panel code return at once). The switch's text says "While it is off nothing is
  created, registered or read" and does not mention /reload (V14 asks that it does). Panel off: hidden; the toolkit's events stay
  registered while the toolkit is on (they also feed the overlays and tooltip lines).
- Notepad ("Show Notepad" off = the box hidden): the box frame is built at login even while hidden; the event frame keeps
  PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED / PLAYER_LOGOUT registered and refreshes the hidden box on each combat change;
  NotepadShare.lua's send pump runs an OnUpdate every frame and CHAT_MSG_ADDON stays registered (sharing). Whether V14 applies to
  a show / hide switch is a question for Xaya.
- Custom Data Panels and Bars (master off): panels hidden and their visibility drivers removed, but the driver frame keeps an
  OnUpdate running every frame (it returns at once while off) and PLAYER_ENTERING_WORLD / PLAYER_REGEN_DISABLED /
  PLAYER_REGEN_ENABLED / PLAYER_EQUIPMENT_CHANGED registered (each calls the refresh, which returns per panel).
- Level reached (V14 limit 1): all of these are in always-loaded addons, so their files are read at login either way.

## B. Utilities (XayaUI_Bonus/Utilities.lua, new; Calculator.lua, Notepad.lua)
- "utilities" is registered as a Bonus Features page; a group with childGroups "tree" whose children are the Calculator page
  (`ns.BuildCalculatorPage`, new) and the Notepad page (`ns.BuildNotepadTab`, no longer registered on its own). Children are sorted
  by name like the tab's pages (#274): Calculator, Notepad (decision; her sentence names Notepad first). Utilities' own page: one
  overview line per tool. No box on Utilities (no single setting).
- Calculator page: what it is, what a sum can hold, how to open it (button, /xui calc, the minimap button's list), and "Open
  calculator" (`ns.Calculator_Open`, new: shows the window, never closes it, cursor in the line). Text from Calculator.lua's
  header. Found while writing it: the header's example answer was wrong ("6.696083"); 23249 / 3472 = 6.69614055..., and the code
  prints 6.696141 (as USER-GUIDE 12.4b and QA F6 already said). Header fixed; the page's example is checked against the calculator
  in the test (V5).
- `ns.Notepad_OpenSettings` opens ("bonus", "utilities", "notepad"). No other caller opened the old ("bonus", "notepad") page.

## C. The talent scan in Settings
- Moved, unchanged in behaviour, from BuildClassCreator to Settings > UI Options > Rule Creation (BuildAddonSettings `rules.args`:
  talHdr, talInfo, talScan, plus talMsg for the last message, which the creator showed in its shared message line). Both settings
  layouts (skin on: Settings page > UI Options > Rule Creation tab; skin off: the single Settings tab > Rule Creation) share that
  table, so it shows in both.
- Why there (decision): what the scan saves (XayaUITalentDB) is read only by rule creation: the rule editor's talent search lists
  every spec and hero tree of the class from it (Options.lua SX.ClassSet, SX.Start). It is a whole-addon action, which is what
  Settings holds. Debugging was the other candidate (it is also a data capture); not chosen because nothing there uses the data.
- The message string lives in `ns.OptionsApi.talentScanMsg` (a field: the main chunk is at Lua 5.1's 200-local limit; no new
  file-level local added; checked by compiling Options.lua with loadstring in Lua 5.1).

## Scope (V4)
`git grep` of every reader: the removed toggles (`args.enabled` of the cursor pages: CursorTrail.lua's overview only; `overlaysOn`,
`panelOn`, `tooltipsOn`: tests/char_toolkit2_run.py, updated; `master`, `show`: their pages only), the "notepad" page key
(Notepad.lua opener and registration; tests/modules_run.py registers its own stand-in page under that key, unaffected), the talent
section (Options.lua only; USER-GUIDE 12.1), XayaUITalentDB readers (TalentDump.lua; Options.lua talent search), Tree.Keep users
(console switches, Tree.ViewChanged, Tree.SwitchClick), DecorateButton callers (DecorateTree, SafeDecorate), `ns.OpenSettingsPage("bonus"`
callers (DataPanels.lua, Notepad.lua). Pages touched: QoL > Character Toolkit (+ Panel, Slot Overlays, Spell Math), QoL > Cursor (+
Cursor Highlight, Gradient Cursor Trail), Bonus > Custom Data Panels and Bars, Bonus > Utilities (new) > Calculator (new) and Notepad
(moved), Settings > UI Options > Rule Creation, Rules > Class/Spec Rule Creator. Text: USER-GUIDE 12.1, 12.3, 12.4, 12.4b, 12.11,
12.12 and the layout paragraph; README (Notepad); QA E1, E1b, E1m, F2 marked; new B131, E3, F7, F8. Not changed: XayaUI/Modules.lua
section 5 still says the feature's own node shows "its overview (on/off switches, a short note)" (core file; left for a core
change).

## Tests
- `tests/sidebar_switches_run.py` (new, 72 checks; loads the real addons in the stand-in game, about 50 s). New code: 72 passed (also
  without the API index). Old code (b8017df, the test copied into a snapshot): 47 of 53 failed (no switches, the in-page switches
  still there, no Utilities, the scan still in the Rule Creator and not in Settings; the 6 that pass are setup and controls).
  Stand-in limits, stated in the test: no hit testing (the click target is checked as a mouse-enabled child above the row); no
  OnSizeChanged and 0 px row heights, so after each redraw the test runs AceGUI's own OnSizeChanged handler and clears the skin's
  fitted line count (a plain redraw of the old code shows one row without that); a message from an aura-setup timer opens the
  console window, whose own redraw would be counted, so its auto-open is off in the test.
- `tests/char_toolkit2_run.py`: the overview's overlaysOn is gone; it now drives the Slot Overlays row's switch (171 passed).
- Targeted: lua_pitfalls, char_toolkit, char_toolkit2, char_spells, char_stat_map, calculator, notepad, modules, tooltips, reskin_tab,
  console_toggle_cost, rules_subtabs_compact, window_footer, sidebar_name_room, options_layout_v11, window_margins: all passed.
- Full suite (`XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`, staged tree of this commit): ALL CHECKS PASS,
  89 test groups and the whole-addon harness (33 fresh-install combinations, 0 fail).
- Harness indexes built for this run from Gethe/wow-ui-source d07eb00 (12.1.5.70688): 622 files, 0 unparsed; 18235 names, 232
  deprecated-only (gitignored, not committed).

## Open questions for Xaya
1. Tooltips has no master switch (IDs, Item level, Enemy forces, Formulas each have their own on their tab). Make the four sections
   parts (rows) with a box each, add one master switch, or leave it?
2. Character Toolkit's "Tooltip lines" (character window stat tooltips) has no row: it stays on Panel > Tooltips. Its own row?
3. "Show Notepad" opens / closes the box; is a box for that what you want, and should V14 cover the Notepad's always-on pieces?
4. Utilities order: Calculator, Notepad (by name, as the tab's pages). Notepad first instead?
5. The Blizzard UI Reskin tab (Chat Panel, Character Pane, Esc Menu) still has its switches on the pages; same treatment?
