# #351 phase 2b: the chat history window on the core margin and gutter (XayaUI_Chat 0.6.11; fork: main)
Logged 2026-11-04 21:50 UTC. Session branch `claude/cool-ramanujan-ewx8e5`, on top of core 0.6.36 (ns.UI_MARGIN / ns.UI_GUTTER in
Modules.lua). Nothing here has run in the game.

## Found (survey in the 21:48 entry; `XayaUI_Chat/History.lua`)
- The search box 6 px under the tab buttons, the text 6 px under the search box.
- The privacy note 6 px above the window's bottom edge and 2 px under the Refresh / Live row (FOOT_NOTE 6 + NOTE_H 28 = 34; the
  buttons at 36).
- Live 6 px right of Refresh; the note 6 px short of the resize grip.

## What changed (`XayaUI_Chat/History.lua`)
- `M, G = ns.UI_MARGIN, ns.UI_GUTTER` (Chat depends on core). The footer bands are built from them: the note M above the bottom
  edge, the button row G above the note (FOOT_BTN 36 -> 48), the scroll area G above the buttons (FOOT_SCROLL 64 -> 78).
- The tab rows' height is now what they draw (rows x 24 - 4, the last row 20 tall); the search box G under them, the text G under
  the 20 px search box.
- Live G right of Refresh; the note G short of the grip (2 + 16 + G from the right).
- The close button and the grip are marked as edge controls (`xuiEdge`), as in the 21:48 entry's rule.
- At the smallest size (440 x 300) with one row of tabs the text area is still 128 px tall.
- `XayaUI_Chat.toc` 0.6.11; QA B77.

## Tests
- `tests/window_margins_run.py` +5 (20 checks): the history window opens; margin and gaps at its default size and at its smallest,
  the tab buttons as a segmented row. On `main` (`d11f404`): those 4 checks fail (close and grip aside, the search / scroll / button
  / note bands 6 and 2 px apart), 12 of 20 in all.
- `tests/chat_run.py`: all passed (its footer band checks still hold).
