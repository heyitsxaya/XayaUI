# Stat Calculator: the Sheet tab removed (XayaUI_QoL 0.7.14; fork: main)
Logged 2026-11-04 23:20 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Request (Xaya, 2026-11-04, with screenshots of the Sheet tab and of her character window)
"again, I don't care about this sheet at all. I want a reskin OF THE CHARACTER MENU AND NOTHING ELSE". Her earlier words (plan item 3):
"'sheet' tab is not intended to be a tab but instead a reskin of the character pane". The plan kept the Sheet until the reskin was
built (build order step 4); she does not want it in the meantime.

## What changed
- `XayaUI_QoL/CharacterModel.lua`: `CM.TABS` = Stats | Gear | What If | Spells.
- `XayaUI_QoL/CharacterToolkit.lua`: the Sheet renderer removed; a saved "sheet" tab (and the old "overview") opens Stats; a new
  profile starts on Stats. `CM.Build` still takes nil / "defense" / "offense" (the character window's tooltips use them).
- `USER-GUIDE.md`, QA E1d / E1e2 / E1i / E1l2 / E1t updated, E1z new; `XayaUI_QoL.toc` 0.7.14.
- Next: the QoL Character Reskin (the character window itself), task 40.

## Tests
- `tests/char_toolkit2_run.py` (162): the Sheet checks replaced: no Sheet tab; a saved Sheet tab opens Stats (no cells drawn); a
  fresh profile starts on Stats; the secret-value checks read the Stats tab instead of a sheet cell. On QoL 0.7.12's files the first
  three fail.
- `tests/char_spells_run.py` (60): the tab-row check without Sheet. `char_toolkit_run` (105), `char_gear_icons_run` (23),
  `window_margins_run` (44): 0 failed.
