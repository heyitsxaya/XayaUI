# #351 phase 2d: the mover view's group X / Y popup and the frame picker on the core margin and gutter (core 0.6.37; fork: main)
Logged 2026-11-04 21:57 UTC. Session branch `claude/cool-ramanujan-ewx8e5`, after the engine session's core 0.6.34 / 0.6.35 (its
Visual.lua change, #121) reached `main` and was merged in. Nothing here has run in the game.

## Found (the new checks, run on the old Visual.lua: 3 FAIL)
- Group X / Y popup (`XayaUIGroupPosPopup`, 260 x 336): the X and Y edit boxes 6 px apart; the buttons 4-8 px apart; Close 8 px from
  the bottom edge; the anchor line had about 18 px before the next button, so a two-line anchor text ran into it.
- Frame picker (`XayaUIFramePicker`): its text 8 px from the top.

## What changed (`XayaUI/Visual.lua`)
- X / Y popup: the rows are placed by a running position from the top: the title M from the top, then the X box, the Y box, the
  four buttons, the anchor line (now 24 px tall, room for two lines, top-justified), the three anchor buttons and Close, each G after
  the one above; the height is set from the last row (384 px: Close M from the bottom). The side insets (16) are unchanged.
- Frame picker: the text M from the top-left corner.
- `XayaUI.toc` 0.6.37 (0.6.36 is the margin / gutter change in the same batch); QA B79.

## Tests
- `tests/window_margins_run.py` +6 (38 checks): a group with two displays, the mover view on, a right-click on the group's tag opens
  the popup (with a long anchor line); margin and gaps; the frame picker opens; margin and gaps. On the old Visual.lua: 3 FAIL.
- `tests/frame_anchor_run.py` (22) and `tests/mover_view_run.py` (21): 0 failed (the buttons are found by their text, not their
  position).
