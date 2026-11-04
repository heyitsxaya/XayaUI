# Game Menu: the box no longer ends on Return to Game when the XayaUI button is on (XayaUI 0.6.32; fork: main)
Logged 2026-11-04 20:30 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Report
Xaya, 2026-11-04 (screenshot of the ESC menu with XayaUI's Game Menu skin; entries Options, Shop, EllesmereUI, AddOns, What's New,
Edit Mode, Support, Macros, XayaUI, Log Out, Exit Game, Return to Game): "game menu when button is enabled clips incorrectly". The
box ends at the bottom of Return to Game, with no margin.

## Cause (INFERENCE: her screenshot, and that it happens only with the XayaUI button on; Blizzard's layout template code was not read)
- `GameMenu.lua` adds a layout slot through the menu's own `AddButton`, then calls `menu:Layout()`.
- Blizzard's menu is built by `GameMenuFrameMixin:InitButtons` (`Blizzard_GameMenu/Shared/GameMenuFrame.lua`, live source, read
  this session) with `AddButton` / `AddSection` / `AddCloseButton`. Those come from `MainMenuFrameTemplate` (Blizzard_SharedXML),
  whose file was not found this session.
- A layout that sizes the menu from its own entries does not count a button that another addon places itself, nor the extra
  height that addon gave the menu.
- Calling Layout after that addon has run throws its extra height away, so the menu ends a row short. With the XayaUI button off,
  `GameMenu.lua` never calls Layout, which matches "when button is enabled".
- XayaUI's Game Menu skin (match mode) draws its box exactly over the menu's rectangle, so it shows the same.

## What changed (`XayaUI/GameMenu.lua`)
- Before adding anything, the gap between the lowest shown button and the menu's bottom is measured (16 px if it cannot be read).
- After Layout, and again one frame later, the menu is made tall enough that its lowest shown button keeps that gap.
- It is never made shorter.
- `/xui gamemenu` prints the gap it found and wanted ("height fit").
- QA B73.

## Tests
- `tests/gamemenu_fit_run.py` (new, 7 checks), with geometry:
  - a stand-in menu laid out from its pooled buttons only;
  - another addon's button placed under the last one, with 30 px added for it;
  - the menu built with the XayaUI button off, then on.
  - Checks: the lowest button keeps its 20 px; the menu is one row taller, not shorter; a menu that fits is left alone; never made
    shorter.
  - Negative control: on the old file the other addon's button ends 10 px below the menu's bottom (the clipping), and 5 of 7 fail.
- `tests/gamemenu_run.py`, `tests/lua_pitfalls_run.py`: pass.
