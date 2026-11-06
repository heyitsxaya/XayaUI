# Stat Calculator: default panel 450 wide, the Rating cell shows the change (XayaUI_QoL 0.7.21)
Logged 2026-11-05 20:22 UTC. Session branch `claude/admiring-ride-sm7jrh` on `main` 19321e7 (QoL 0.7.20). Not run in game (QA E1z21).

## Request (Xaya, 2026-11-05, her words; answers to the three open questions of QoL 0.7.20)
1. "Stat calculator default width can be increased to cleanly fit all columns with default selected user font up to 450px"
2. "Rating cell while typing should show alongside the +/- stat amount"
3. "Haste ability list was just an example": every ability list stays nested (as built in 0.7.20). No change.

## Change
- `XayaUI_QoL/CharacterToolkit.lua`
  - `PANEL_W` 380 -> 450 (the default; a width saved by dragging the corner is kept, as before; Reset size goes to 450).
  - `GRID_RAT` 36 -> 80, so the Rating cell holds "1,287 +1,000" (12 characters: 12 x 0.55 x 11 = 72.6 px by the layout test's
    estimate). Default content 430: Stat = 430 - (80 + 98 + 56 + 44 + 4 x 10) = 112, so "Critical Strike" (15 x 0.55 x 11 = 90.75)
    and "» Abilities (per 100)" (a "»" line: room 112 + 10 + 80 - 12 = 190) fit on one line. Was Stat 86 at 380.
  - `GridCols`: below the default width the Rating column gives up its room first, down to 36 (its 0.7.20 width), so Stat keeps 86 as
    long as it can; at the narrowest panel (340, content 320) the columns are as in 0.7.20 and "528 +172" wraps inside its cell.
    Without this the narrowest panel failed the layout guard (Pt value reached the box: 304 > 266).
  - Side effect: the Note column (wide panels) starts at content 564 / panel 584; it was 520 / 540.
- `XayaUI_QoL/CharacterModel.lua` `MapRating`: `ratingText` = your rating, plus the typed change when it is not 0: "528 +172",
  "528 -28" (`Big` of the rounded `it.amount`, the box's difference from your rating). Primary stats have no Rating cell (unchanged).
- `XayaUI_QoL.toc` 0.7.21. USER-GUIDE (Stat Calculator > Columns), QA-CHECKLIST E1z21.

## Decisions (mine; each can be changed)
- DECISION: 450, the top of her range, not the smallest width that fits by the estimate (about 400 for the stat names): the estimate
  is not the game's font, so the extra room is the margin for it, and the wider Rating cell needs it.
- DECISION: the change reads "+172" / "-28" after the rating, in the Rating cell's colour (no green / red there: Current value already
  carries the tone).

## Tests
- `tests/char_stat_columns_run.py`: default content 430; typed 700 crit: Rating "528 +172" (its own font string at the Rating
  column); "Critical Strike" and "» Abilities (per 100)" must fit on one line at the default; layout widths 340, 380, 450, 583, 584, 760
  at text sizes 8 / 11 / 16; Gear tab's Current value 188 wide, Pt value at 320. 112 checks, 0 failed. On the old code (QoL 0.7.20's two
  Lua files put back, this test file kept): 112 checks, 4 failed; restored afterwards, 0 failed.
- `tests/char_stat_map_run.py`: Reset size returns to content 430 (was 360). 69 checks, 0 failed (on `main` the old expectation
  passes; it fails with this change until updated: checked).
- The other character tests unchanged and passing: char_gear_icons 26, char_pane_overlays 37, char_reskin 45, char_spells 73,
  char_toolkit2 171, char_toolkit 110, char_width_probe 19. `lua_pitfalls_run.py` FAILS: 0.

## Not verified
- In game: the real font widths (the 0.55 x size estimate), whether 450 sits well beside the character window.
