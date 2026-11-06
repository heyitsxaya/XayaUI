# Settings window: even top tabs, no pane borders, nesting, greying; Reskin switch on an Overview row; Data Panels (XayaUI_Options 0.6.55, XayaUI_Bonus 0.6.18, XayaUI_Reskin 0.6.5, Chat 0.6.21 / QoL 0.7.34 texts; fork: main)
Logged 2026-11-06 19:45 UTC. Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Requests (REQUEST-LOG A8, her words verbatim there)
- UI-5: nesting; greying; "Custom Data Panels and Bars" -> "Data Panels" / "Data Bars"; Blizzard UI Reskin switch "in the tab itself and then after a reload individual reskin items populate"; top tabs "evenly distributed across the pane, wider, and thicker", font "parent-level".
- UI-6: "replace the visual of the two column pane boxed display with a clean divider line and remove the frames otherwise".
- UI-7 / UI-8, her answers: Data Bars = ElvUI-style progress bars, roadmap, under Blizzard UI Reskin; switch "Right pane + reload prompt"; tabs "32 px, 14 pt, outlined"; "Borders go, fills stay"; nesting "Parent's name + 8 px"; greying "Left pane + their settings".
- Her UI-5 reverses her 2026-11-06 answer "Tick box on the tab itself" (Options 0.6.50): the later instruction is built.

## What changed
- `XayaUI_Options/Skin.lua`:
  - TopTabs: the window's top TabGroup (found by its tabs' values being the feature-tab keys) gets equal widths (frame width / n), no overlap, 32 px height, a font object per tab at 14 pt OUTLINE in the theme font and the tab colour; AceGUI's borderoffset moved under the row (top + 32 + 3). Runs after every BuildTabs and every skin pass; restored on release.
  - PaneFill / PaneDivider: tree pane, content pane and the tab box keep their fill, border colour alpha 0; a 1 px line (theme pane border colour) on the left pane's right edge. Restored on release.
- `XayaUI_Options/Options.lua`:
  - GreyWhileOff (in ModuleTabs): under a group with xuiSwitch, every leaf and inline group gets a wrapped `disabled` (true while that switch or an ancestor's is off); non-inline groups are not disabled (AceConfigDialog would lock their row); parts' own switches are greyed while the parent is off. A string `disabled` (handler method) is left alone.
  - NestX / NoteNameL: in feature tabs a level-2+ row's x0 = parent's name inset + 8.
  - GreyRow (after DecorateButton): a row whose own or ancestor switch is off shows its name in grey (0.5, 0.5, 0.5; colour codes stripped).
  - Reskin: TAB_SWITCHES emptied (no tab button box); ReskinOverview adds an "Overview" row (sorted first) whose page has "Enable Blizzard UI Reskin" (core ns.SetReskinTab, as before) and a note; a StaticPopup "Reload / Later" (C_UI.Reload, else ReloadUI); the reskins' pages are hidden unless the switch was on when XayaUI_Options loaded (reskinAtLoad).
  - Tree.RowSwitch header comment: "(Utilities, Cursor)" (handed over from S7).
- `XayaUI_Bonus/DataPanels.lua`: names "Data Panels" / "Enable Data Panels". ROADMAP: RM-DATABARS (Blizzard UI Reskin, future).
- Texts naming "All reskins" (Chat Core / Options, QoL CharacterReskin / ShoppingList, Reskin GameMenuSkin) now point at "Blizzard UI Reskin > Overview".

## Scope (V4)
`git grep` TAB_SWITCHES / PaintTabSwitch (Options.lua only); "All reskins" (5 addon files + 2 tests); "Custom Data Panels and Bars" (DataPanels.lua, USER-GUIDE, QA, 2 tests); PaneColors callers in Skin.lua (TabGroup, TreeGroup, their releases; inline-group boxes untouched); xuiSwitch providers (16, all read state without using `info`).

## Tests
- `tests/sidebar_switches_run.py` section G (new): top tabs even / 32 px / 14 pt outline / box below; borders gone, fills kept, divider; nesting (Calculator box = Utilities name + 8); greying (Notepad row grey, a setting disabled, back when ticked); Data Panels name. On Options 0.6.50 / Bonus 0.6.17 10 G checks fail (the settings-greyed check passes there too: Notepad already greyed its own settings; kept as a guard). 115 checks pass now.
- `tests/reskin_tab_switch_run.py` rewritten for the Overview switch (26 pass), `tests/reskin_tab_run.py` (22 pass), `tests/options_bonus_off_costs_nothing_run.py` (66 pass).
- Stand-in limits: the harness's SetNormalFontObject is a no-op, so the font object on the button is not checked, only its font.

## QA
B186-B198, F20 (F18 and F19 were taken).
