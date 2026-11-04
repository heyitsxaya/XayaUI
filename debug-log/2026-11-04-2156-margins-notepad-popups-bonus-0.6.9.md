# #351 phase 2c: the notepad's share, offer, export / import and restore windows on the core margin and gutter (XayaUI_Bonus 0.6.9; fork: main)
Logged 2026-11-04 21:56 UTC. Session branch `claude/cool-ramanujan-ewx8e5`, on top of core 0.6.36 (ns.UI_MARGIN / ns.UI_GUTTER).
Nothing here has run in the game. Bonus 0.6.8 is the Dev Assist session's calculator (not on `main` when this was written).

## Found (the new checks in tests/window_margins_run.py, run on the old files: 8 FAIL)
- Shared-note offer (`XayaUINoteOffer`, 320 x 220): 8 px insets; the text 4 px above the buttons; the buttons 6 px apart.
- Share window (`XayaUINoteShare`, 300 x 176): 8 px insets; the status line (26 px from 122 down) ran 6 px into Send / Cancel;
  Cancel 6 px from Send; the "post text" button 284 wide (8 px each side); rows 2-6 px apart.
- Export / import (`XayaUINoteIO`, 420 x 320): 8 px insets; the help 6 px under the mode buttons; the text 8 px above Select all.
- Restore list (`XayaUINotepadRestore`, 300 x 300): 6 px insets, the list 4 px under the close x; placed 6 px right of the notepad.

## What changed
- `XayaUI_Bonus/NotepadShare.lua`: `M, G = ns.UI_MARGIN, ns.UI_GUTTER` (Bonus depends on core).
  - Offer: title and text M inside; the text G above the 22 px buttons; buttons at M, M + 120 + G, M + 120 + G + 70 + G (the last
    ends M from the right edge).
  - Share: 176 -> 210 tall; title M; the note's name G under the close x; channel, player, "post text" (300 - 2M wide) and status
    rows G apart; Send / Cancel M from the bottom, G apart.
  - Export / import: title M; the mode buttons M from the left (a segmented row, 4 px seams kept); the help G under them, the text G
    under the help and G above Select all; status and Select all M from the bottom.
  - Both close x's marked as edge controls.
- `XayaUI_Bonus/Notepad.lua`: restore list title M, the list M inside and G under the close x, placed G right of the notepad.
- Not in this change: the notepad window itself (title bar, toolbar, format bar, text area). Its toolbar is a segmented icon row and
  its header rows are tightly coupled (HDR, TB_H, NAME_H, FB_H); it gets its own change.
- `XayaUI_Bonus.toc` 0.6.9; QA B78.

## Tests
- `tests/window_margins_run.py` +12 (32 checks): the four windows open (the offer through `ns.NotepadShare_Handle` with a one-part
  message), margin and gaps in each, the export window's mode buttons as a segmented row. On the old files: 8 FAIL (each window's
  margin and gap check), so the new checks are their own negative control.
- `tests/notepad_run.py` ALL PASS; `tests/debug_record_run.py` FAILS: 0; `tests/lua_pitfalls_run.py` 0 fails.
