# #351 phase 1b: a V11 layout test on a probe settings page drawn by the real AceGUI and skin (tests only; fork: main)
Logged 2026-11-04 21:16 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. No addon code changed.

## Why
- #351's plan asks for "a layout check in the test harness that measures every rendered pane". VERIFICATION V11 asks every
  layout change to check both axes, every child inside its parent, and no overlaps.
- Phase 1 (Options 0.6.33) tested the layout rule on stand-in widgets only.

## What was added
- `tests/options_layout_v11_run.py`: a probe page registered as its own AceConfig app, opened by the real AceConfigDialog, dressed
  by the real `ns.DecorateTrees` (the probe window as root), then measured in the stand-in game.
  - The page holds labels, an icon and its label, colour pickers, a tick box, a slider, a menu, two compact buttons, an inline box
    and a row of two tabs.
  - Checks: every widget inside its container's content area (both axes); no two widgets overlapping; at least `ns.UI_GUTTER`
    between two neighbours on a row (tab rows 2 px).
  - Drawing a probe page takes under a second; drawing the full settings tree in the stand-in game takes over 10 minutes.

## Limits (written into the test)
- Text width is not measured: the stand-in font has no real metrics. That part of V11 stays with QA B75.
- Full-width widgets (headings, inline boxes) are checked for being inside their container only.
  - AceGUI anchors them by the row's TOPLEFT and the content's RIGHT point (AceGUI-3.0.lua, Flow layout). The stand-in placed them
    at the content's middle, a false overlap.
  - Which of the two vertical constraints the game uses was not checked, so the stand-in was not changed.
- Neighbours are found by an equal top edge, so controls of different heights centred on one row (an icon and its label) are not
  paired.

## Result
- Current code: 6 of 6.
- Negative control (Skin.lua before #351, 052032c): the gutter check fails with "Label one -> Label two: 0.0 px",
  "Label two -> Label three: 0.0 px" and "Colour A -> Colour B: 0.0 px", the touching rows #351 reported.
