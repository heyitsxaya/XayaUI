# Calculator on / off tick box (Bonus 0.6.15)

Session 014bN6tWsEQA8BZbHidBmJ1Y, branch `claude/gallant-allen-gmvfr0`, 2026-11-06 05:05 UTC. UNTESTED IN GAME.

## Her words
"Calculator needs its own enable / disable toggle" [screenshot: Bonus Features left pane, Utilities expanded; Calculator with no
tick box, Notepad with a ticked box]. REQUEST-LOG section A7, row S7-1.

## What changed
- `XayaUI_Bonus/Calculator.lua`: the Calculator page carries an `xuiSwitch` named "Calculator" (the same sidebar tick box the Notepad,
  Enhanced Tooltips and Custom Data Panels rows use; `XayaUI_Options/Options.lua` `Tree.RowSwitch` draws it, unchanged).
  Saved as `CueRulesDB.calculator.enabled` (false = off; nil / true = on). Off:
  - an open window closes and its line lets go of the keyboard;
  - `/xui calc` with or without a sum prints only "The Calculator is off: tick it in Bonus Features > Utilities > Calculator."
    (no answer, no history line);
  - the minimap button's list leaves the Calculator row out (`available`, core 0.6.49);
  - the page's "Open calculator" button is greyed out.
  Saved sums and the window's position are kept.
- `XayaUI_Bonus/Utilities.lua`: overview line and header comment mention the Calculator's box.
- `XayaUI_Bonus/XayaUI_Bonus.toc`: 0.6.14 -> 0.6.15.

## Choices made without her words (to confirm, V16)
1. **Default: on**, so nothing changes for anyone until they untick it (the Notepad's precedent, Bonus 0.6.14, "on by default as it
   always was"). Alternative: off by default.
2. **Off covers `/xui calc <sum>` too** (no chat answers while off), following her words about the Notepad's box: "It should only
   enable or disable notepad functionality in its entirety". Alternative: the chat answer keeps working while only the window is off.
3. The off message wording above.

## V14 level reached
The file is read at login (XayaUI_Bonus is not load-on-demand), which costs its parse and function definitions. While off, nothing
of it is created or runs: it never had events, OnUpdate, timers or hooks; the window is built only on first open, and every way of
opening it checks the switch first. A window built earlier in the session stays a hidden frame until /reload (the game has no way to
delete a frame); nothing of it runs.

## Scope (V4)
`git grep -n -i calculator` (excluding the Stat Calculator): readers of `ns.Calculator_*` are Calculator.lua itself, Utilities.lua,
`tests/calculator_run.py`, `tests/sidebar_switches_run.py`, `tests/options_bonus_off_costs_nothing_run.py` (opens it while on; still
passes). Install paths: the command, the minimap launcher, the settings button. No display kinds or triggers involved.
Not changed: a stale comment in `XayaUI_Options/Options.lua` (Tree.RowSwitch header) still lists "Tooltips, Calculator" among rows
without a box; left alone so that Options needs no version bump while other sessions hold Options numbers on their branches.

## Tests (V1)
- `tests/calculator_run.py`: new "on / off" section (switch present and named Calculator, on by default; off closes the window, reads
  off, hides the minimap row, greys the button, `/xui calc` with and without a sum only says it is off, every opener does nothing,
  sums kept; on again restores all), and an "off at login" scenario in a fresh Lua state (V14: asked for every way, no frame created).
  5 new deliberate breaks (switch does nothing, off leaves the window open, command ignores off, minimap row stays, Open ignores off).
  73 checks, 13 breaks, FAILS: 0. Negative control: on the old Calculator.lua it gives FAILS: 9 (two section errors, breaks not found).
- `tests/sidebar_switches_run.py`: Calculator is in the list of rows with a switch; its drawn row has a ticked box; unticking it in
  the left pane switches the Calculator off and closes its window without selecting the row, with one redraw; ticking it turns it on.
  92 checks, 0 failed.
- QA-CHECKLIST F16.
