# Function audit, Notepad: restoring an earlier version from the Restore list opened in settings no longer errors when the box was never shown (XayaUI_Bonus 0.6.27)
Logged 2026-11-07 00:44 UTC. Session 014bN6tSfFULX4BSXzmZ1yCx (function audit, UI-60), branch `claude/function-audit`, on main 28380a9. Nothing here has run in the game.
Row: docs/process/FUNCTION-AUDIT-2026-11-07.md D48.

## What changed (`XayaUI_Bonus/Notepad.lua`)
The Restore list's "earlier version" row called SetEditText, which indexes the box (`frame`), with no check. The box is built only when
it is first shown; "Open Restore list" on the settings page works without it. So: Lua error "attempt to index upvalue 'frame' (a nil
value)" after the note text had already been replaced (nothing was lost: the text before it was snapshotted first). Now the edit box is
only updated when it exists; the note, its title and the list are updated as before. The trash rows already went through Select(),
which checks for the box.

## Tests
- `tests/notepad_restore_closed_run.py` (new, from the audit reviewer's scratch script): 4 checks; on main 28380a9 (Bonus 0.6.20) the "no Lua error"
  check fails (the error above). All pass now.

## QA
F23.

## Also in Bonus 0.6.27: minimap rows (O-100 / REQUEST-LOG A11 FA-15)
Her words (O-100): "calculator isn't "off" -- it's just not displayed. same with stat calculator and notes"; her answer "No word at all".
- `Notepad.lua` and `Calculator.lua`: their launcher rows have no state function (entry[5] = nil), so the list shows just the name.
  These rows exist only while the feature is on (`available`), so a switched-off feature still has no row.
- `DataPanels.lua`: the launcher row is named "Data Panels" (the feature's name since Bonus 0.6.18), tooltip "Open the Data Panels settings".
- Test: `tests/audit_core_run.py` O-100 checks (fail on 28380a9: the rows had "on" / "off" and the old name). QA F24.

Versions renumbered for the landing on main bf2ce6a (2026-11-07, numbers claimed for the lander to relabel): core 0.6.67, Options 0.6.69, QoL 0.7.42, Chat 0.6.33, Bonus 0.6.27, Dev Assist 0.7.19.
