# #351 phase 2e: the notepad window on the core margin and gutter (XayaUI_Bonus 0.6.10; fork: main)
Logged 2026-11-04 21:59 UTC. Session branch `claude/cool-ramanujan-ewx8e5`, on top of Bonus 0.6.9 (the notepad's popups).
Nothing here has run in the game.

## Found (the new checks, run on the old Notepad.lua: 3 FAIL)
- The text area 6 px from the sides, 3 px under the toolbar (4 under the name row without one, 2 under the format bar; 4 from a
  side toolbar).
- In the name row, the name box 4 px from the left, the character count 6 px from the right and 6 px from the box.

## What changed (`XayaUI_Bonus/Notepad.lua`)
- `Layout`: the text area (typing area, formatted view, note list) M from the sides; G under the name row, the toolbar (top) and
  the format bar, G from a side or bottom toolbar; 14 at the bottom kept (the resize grip's corner).
- Name row: the box M from the left, the count M from the right, G between them.
- The title bar, the name row and the toolbar are bands across the window (window chrome): marked as edge parts, and the test lets
  two edge parts touch (together they are the header). The toolbar's icons stay a segmented row (2 px seams). The grip is marked
  too.
- `XayaUI_Bonus.toc` 0.6.10; QA B80.
- This closes the windows the 21:48 survey listed, apart from those left as they are on purpose (the chat container and its
  text inset, a user setting; menus; data panels with user margins; the Game Menu skin with its own sliders).

## Tests
- `tests/window_margins_run.py` +6 (44 checks): the notepad opens; margin and gaps with the toolbar on top; its name row's sides
  (a 22 px band: only side margins apply). On the old Notepad.lua: 3 FAIL.
- `tests/notepad_run.py` ALL PASS.
