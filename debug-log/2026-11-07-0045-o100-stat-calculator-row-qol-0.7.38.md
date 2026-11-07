# Minimap list: the Stat Calculator row shows just its name (XayaUI_QoL 0.7.38)
Logged 2026-11-07 00:45 UTC. Session 014bN6tSfFULX4BSXzmZ1yCx (function audit), branch `claude/function-audit`, on main 28380a9. Not run in the game.
Request: O-100 / REQUEST-LOG A11 FA-15 (her words: "calculator isn't "off" -- it's just not displayed. same with stat calculator and notes"; her answer "No word at all").
- `XayaUI_QoL/CharacterToolkit.lua`: the "stats" launcher row has no state function (entry[5] = nil). The row exists only while the
  Toolkit and its panel are on (`available`), as before.
- Test: `tests/audit_core_run.py` ("O-100 minimap row 'stats' has no on / off text"; fails on 28380a9). QA E1z194.
- Version from the coordinator's registry (QoL 0.7.37 is the UI bugs session's).
