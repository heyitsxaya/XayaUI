# Stat Calculator Spells: the spell ID beside the name, the number lines readable (XayaUI_QoL 0.7.11; issues #378, #380; fork: main)
Logged 2026-11-04 22:00 UTC. Session branch `claude/cool-ramanujan-ewx8e5`, on top of QoL 0.7.10. Nothing here has run in the game.

## Reports (filed 2026-11-04 18:08 by another session from Xaya's screenshots)
- #378: "way too tiny": the Spells tab's number lines ("83.1% of attack power; 1 Agility = +0.83") were small and dim next to the
  spell names, and wrapped ("... 1 Agility =" / "+0.83").
- #380: "Spell ID: " next to the name instead of "#258920" at the right edge.

## Cause
- Every item's detail lines (pairs) are drawn one point smaller than the panel's text size and in the muted colour, with the value in
  the right half of the line: right for the Stats tab's short labels and values, wrong for spell math, where the value is the
  sentence and the label a number.
- The spell's ID was the line's value, drawn at the right edge.

## What changed
- `XayaUI_QoL/CharacterModel.lua` (SpellItem): label = name + "   Spell ID: N" (the ID part grey), value empty; `bigPairs = true`.
- `XayaUI_QoL/CharacterToolkit.lua` (RenderSections): a line with an empty value is drawn across the whole width; an item with
  `bigPairs` draws its detail lines at the panel's text size, in the text colour, with the value taking 70% of the line. Other items
  are unchanged.
- The panel's Text size setting (Panel > Layout) still scales all of it; the font size in points and Xaya's UI scale are not known
  (#378 says so), so QA E1w asks her to report readability.
- `XayaUI_QoL.toc` 0.7.11; USER-GUIDE (Spells); QA E1w.

## Not done here (decision-needed in their issues)
#377 (configure-spell-data button, active / inactive), #379 (colour secondaries), #381 (resize grip), #382 (the Show: % toggle "does
nothing"; three columns side by side), #383 (scope), #387 (linked stat changes in What If): they wait on Xaya's answers.

## Tests
- `tests/char_spells_run.py` +5 (60): the label reads the name then "Spell ID: 9001", value empty; drawn across the whole width;
  the spell math lines at the panel's text size (11); their value column 70% of the line; the Stats tab keeps size - 1. On QoL 0.7.10's
  files: 4 FAIL.
- `tests/char_toolkit_run.py`: the Fracture row check now expects the ID in the label (105, 0 failed).
