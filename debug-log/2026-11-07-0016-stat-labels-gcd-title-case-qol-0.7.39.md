# Stat list labels: GCD, Movement Speed, Critical Strike Effectiveness (XayaUI_QoL 0.7.39)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Request
UI-62 (Xaya, verbatim): "Global Cooldown should be GCD / Critical strike effectiveness should be title cased like every other line".
Also UI-61: Insivius in game, "text appears to be fixed for resizing now!" (closes UI-56; the QoL 0.7.33 relayout).

## Change (`XayaUI_QoL/CharacterModel.lua`)
- map_gcd "Global cooldown" -> "GCD"; map_critfx "Critical strike effectiveness" -> "Critical Strike Effectiveness".
- map_movespeed "Movement speed" -> "Movement Speed": the one other line of the list not in title case ("like every other line"; the
  session's reading, told to her).
- The same lines show in the character window's stat list and the Stat Calculator's Stats tab. The » notes under the Haste card and
  the hover sentences are unchanged.

## Tests
`tests/char_stat_window_run.py`: the General / Offensive line lists and the line lookups use the new labels (7 checks fail on the old
labels); 98 / 98. char_stat_map 69, char_stat_columns 101, char_toolkit2 166: pass.

## QA
E1z94.
