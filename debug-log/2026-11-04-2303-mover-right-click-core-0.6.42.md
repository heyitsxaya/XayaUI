# Mover view: a right-click after a drag could be swallowed (core 0.6.42; fork: main)
Logged 2026-11-04 23:03 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Handed over by the Dev Assist session. Nothing here has run in the game.

## Report (Xaya, 2026-11-04, relayed)
"right mouse click mover is unreliable". No steps or screenshot.

## Cause (reproduced in tests/mover_click_run.py on the old Visual.lua: 1 FAIL)
`XayaUI/Visual.lua`, a display in the mover view: OnDragStart set `self.wasDragged = true`; only OnMouseUp cleared it, and it did so
before looking at the button (`if self.wasDragged then self.wasDragged = false; return end`). The game sends OnDragStop to the frame
that started the drag, but OnMouseUp only to the frame under the cursor (INFERENCE from how the events are documented; not checked
in game): a display clamped to the screen or snapped away from the cursor, or a fast release, leaves the flag set, and the next click
on that display, often the right-click that opens its menu, was swallowed. So the menu opened every other time after such drags.
The Dev Assist session's other idea (a display above a group's tag taking the right-click) is not addressed here: no evidence yet.

## Fix (`XayaUI/Visual.lua`)
- A right-click is never swallowed (drags are left-button only: RegisterForDrag("LeftButton")).
- A left release is ignored only when it belongs to a drag: while the drag runs, or within 0.3 s (`DRAG_UP_WINDOW`) after
  OnDragStop, whichever of OnMouseUp / OnDragStop comes first.
- OnDragStop always clears `wasDragged` and notes the time; OnDragStart resets it.
- `XayaUI.toc` 0.6.42; QA B84.

## Not done (needs her steps)
Her earlier note "right clicking mouse with the cursor shape enabled makes cursor less responsive" is the QoL cursor highlight (a
different file). Holding the right button turns the camera (mouselook), during which the game hides the cursor; what "less
responsive" means there is not known. Asked for: which cursor option, what she does, what she sees.

## Tests
- New `tests/mover_click_run.py` (9): a left click opens the editor and a right click the menu; a drag released off the display,
  then a right click: the menu opens the first time (FAIL on the old file); then a left click opens the editor; a drag's own
  release (after or before OnDragStop) opens nothing; a later left click opens the editor.
- `tests/mover_view_run.py` (21), `tests/frame_anchor_run.py` (22), `tests/window_margins_run.py` (44): 0 failed.
