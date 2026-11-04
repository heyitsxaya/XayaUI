# Chat tabs: the lay-out call runs at most once a second, on whole-pixel width changes (XayaUI_Chat 0.6.9; fork: main)
Logged 2026-11-04 18:51 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Why
Xaya, 2026-11-04 (screenshot): "wow started dancing around on my screen and blinking". Which part moves was not stated. Asked:
- the game window itself (no addon can move it);
- or a part inside the game.

## The guard
- Chat 0.6.8 calls Blizzard's `FCFDock_UpdateTabs(dock, true)` whenever the dock's width differs from the last lay-out. The width
  was compared as a raw number.
- INFERENCE (not seen in game): a width that wobbles by a fraction of a pixel would make every re-anchor lay the tabs out again, and
  that lay-out also resets each tab's alpha (`FCFTab_UpdateAlpha` in `FCFDock_UpdateTabs`). On screen that is blinking tabs.
- Now:
  - the width is compared in whole pixels;
  - it lays out at most once per second;
  - a change in that second waits for the next re-anchor;
  - still out of combat only.

## Tests
- `tests/chat_run.py` (+3 checks):
  - four width changes in one second: one lay-out;
  - a second later: one more, for the latest width;
  - a width wobbling by 0.3 / -0.2 px: no extra lay-out.
- `tests/chat_world.lua`: `GetWidth` takes an optional test-set `_wobble`.
- Existing checks advance the test clock between steps.
- **Negative control:** with the 0.6.8 `Frame.lua` the three new checks fail (4 to 7 lay-outs in one second; 9 with the wobble).
- QA: D4i.
