# Ability Scaling table: Talent Modifiers before % PSV, foldable spells, dividers, Computed Value left-aligned (XayaUI_QoL 0.7.36; fork: main)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Request
UI-39 (verbatim): "put talent modifiers before % PSV for clarity / spell names should be collapsible and there should be divider lines
between each ability to segmenrt more clearly / put the numbers to left-align to be closer to their %PSV calculations".

## Change (`XayaUI_QoL/CharacterToolkit.lua`)
- Columns drawn Spell Name | Talent Modifiers | % PSV | Computed Value (SpellCols keeps sizing each column by its content; only the
  x order changed).
- Computed Value (and its new-value line, and its head) left-aligned.
- A 1 px line (theme window border colour, 60 % alpha) between two spells; none above the first.
- Each spell's name starts with "- " (open) or "+ " (folded), as the section heads; a click on its row (ns.CharToolkit_ToggleSpell)
  folds it to the name alone or opens it; kept in c.collapsed["spell:<key>"] (saved with the panel's other folds). Every spell open
  until folded.
- PlaceFS records the text's alignment for the tests.

## Tests
`tests/char_spells_compare_run.py`: column order, left alignment, dividers, fold / open (7 checks fail on QoL 0.7.35); the name
lookups in it and in `tests/char_spells_run.py` now include the "- " marker. char_toolkit 110, char_toolkit2 166, char_stat_columns
101: pass.

Missed at first and found by the full suite on 8280424: `tests/char_stat_round_run.py` looked spells up by their bare name; its
rowOf now accepts the "- " / "+ " marker (85 of 85 pass).

## QA
E1z92.
