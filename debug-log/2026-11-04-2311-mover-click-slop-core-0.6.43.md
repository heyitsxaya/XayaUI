# Mover view: a click with a small mouse slip moved and saved the display (core 0.6.43; fork: main)
Logged 2026-11-04 23:11 UTC. Session branch `claude/cool-ramanujan-ewx8e5`, on top of core 0.6.42 (the right-click fix). Nothing here has run in the game.

## Evidence (Xaya's third XayaUI.lua, compared with her previous save by the Dev Assist session, 2026-11-04)
The only changes were three display positions in one group (f17934909063738): rule 10 "T - Metamorphosis" y 111 -> 113; rule 13
"R - Soulmonger" x 67 -> 64; rule 32 "L - Calcified Spikes (cue)" x -170 -> -173, y 15 -> 19. INFERENCE: micro-drags. A click
in the mover view moved the mouse a few pixels, the game started a drag, the display followed, CommitDrag saved the new place (and
cleared any snap: `v.snap = nil`), and the click itself was swallowed. That fits "right mouse click mover is unreliable" for left
clicks too.

## Fix (`XayaUI/Visual.lua`)
- OnDragStart notes where the display was (`dragFrom`, its centre). OnDragStop: when it moved `CLICK_SLOP` (5 px) or less on each
  axis, it was a click: the display, and any linked or paired display that rode along, go back to their saved places
  (`ns.RefreshVisual`), nothing is saved and no snap is cleared, and the click runs (select, open in the editor). The left release
  that follows (or came first) is swallowed as part of the drag, so the editor opens once.
- A drag of more than 5 px is a move, as before.
- INFERENCE: 5 px is a choice (the shifts seen were 2-4 px); the game's own drag threshold is not documented here.
- `XayaUI.toc` 0.6.43; QA B85.

## Tests
- `tests/mover_click_run.py` (14, +5): the earlier drag checks now move 40 px (a real drag); a 3 px slip keeps the saved X / Y,
  puts the display back and opens the editor once; a 4 px slip released before OnDragStop keeps the snap setting and opens the
  editor once; a 40 px drag still moves, saves and opens nothing. On core 0.6.42's Visual.lua: 5 FAIL.
- `tests/mover_view_run.py` (21), `tests/frame_anchor_run.py` (22), `tests/window_margins_run.py` (44): 0 failed.
