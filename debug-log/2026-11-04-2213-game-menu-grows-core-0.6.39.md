# Game Menu grew on every open (core 0.6.39; regression from core 0.6.32; fork: main)
Logged 2026-11-04 22:13 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Handed over by the Dev Assist session with Xaya's report.
Nothing here has run in the game.

## Report (Xaya, 2026-11-04 evening, relayed by the Dev Assist session)
- "escape menu looks sus": screenshot of the Game Menu with the XayaUI skin; buttons Options, Shop, EllesmereUI, AddOns, What's New,
  Edit Mode, Support, Macros, XayaUI, Log Out, Exit Game, Return to Game; the dark panel runs far below Return to Game (the empty
  part about 1.7 times the button list).
- "closing and reopening the esc menu made it even larger".

## Cause (reproduced in tests/gamemenu_ratchet_run.py before the fix: 328 -> 418 px over three more opens)
Core 0.6.32 (`XayaUI/GameMenu.lua`, the "Game Menu clips" fix) measured the bottom padding on every build of the menu as
`padBefore = BottomGap(menu)`, from the menu as it was drawn at that moment, and `FitHeight` only ever made the menu taller. If the
menu's own layout keeps its current height (INFERENCE for the game: a child that covers the menu, such as a skin's backdrop sized to
it, keeps a layout frame from shrinking; Blizzard's MainMenuFrameTemplate source was not fetched), each open measured the previous
open's added XayaUI row as padding and added another row: one row taller per open.

## Fix (`XayaUI/GameMenu.lua`)
- The natural bottom padding is measured once, the first time the menu is built with the XayaUI row, before anything is added or
  fitted; a reading of 0 or above 60 px is not taken as padding (fallback 16, as before). INFERENCE: 60 is a sanity cap, not a game
  value.
- `FitHeight` fits the height to the lowest shown button plus that padding, shorter as well as taller. The core 0.6.32 case (another
  addon's button below the list) still fits: that button is counted while shown.
- `/xui gamemenu` diagnostics print the padding and what was read.
- `XayaUI.toc` 0.6.39; QA B82.

## Tests
- New `tests/gamemenu_ratchet_run.py` (5): a stand-in menu whose Layout never makes it shorter (a covering child); first open 20 px
  under Return to Game; four opens, same height and gap; a menu left 400 px too tall is fitted back. On the old GameMenu.lua: 3 FAIL.
- `tests/gamemenu_fit_run.py`: its last check asserted the old "never made shorter"; it now checks the menu fits its own buttons
  again (20 px, one row shorter) once the other addon's button is hidden (7, 0 failed). `tests/gamemenu_run.py` ALL PASSED.
