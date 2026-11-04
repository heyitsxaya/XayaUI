# Clicking tabs no longer resizes the sidebar and the pane (XayaUI_Options 0.6.31; fork: main)
Logged 2026-11-04 20:17 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Reports
- Xaya, 2026-11-04 (screenshot of a group page on v0.6.31, sidebar very wide): "clicking tabs force-resizes the left and right panes".
- Earlier the same day: "rule sidebar continues to bug out and clip itself after any rule change" (task 30). Her later screenshot
  shows v0.6.31, so that report is on current code too.

## Cause (INFERENCE: read from the code, not seen in game)
- `ns.EnsureNameRoom` (Skin.lua, Options 0.6.20, #369) runs after every sidebar refresh. Every tab click and every edit rebuilds the
  tree.
- It measured each row with `GetWidth()`. A rebuilt tree is first set to AceGUI's default 175 px (`OnAcquire`), then to the saved
  width (`SetStatusTable`), and refreshed.
- If a row still reports its old width at that moment, the sidebar looks too narrow and is widened by the shortfall, again on every
  rebuild, up to the cap (min(400, window - 50)). It also widened a sidebar the user had dragged narrower, which reads as the panes
  jumping.
- Whether the live client returns the stale width there was not observed. The fix does not depend on it: the width is no longer
  measured.
- Task 30 (names clip after a change) may be the other face of this: a width the user dragged, overridden and then clamped. Not
  confirmed.

## What changed (`XayaUI_Options/Skin.lua`)
- The width a row needs comes from its own text insets (`xuiTextL` + `xuiTextR`, set by DecorateButton), plus 80 px for the name and
  the 22 px scroll-bar column (`AceGUIContainer-TreeGroup.lua:481 / 538`). The same rows always ask for the same width, so a
  rebuild changes nothing. It still only widens, and never past the cap.
- A sidebar the user dragged (the skin's drag handler) is marked `xuiManualWidth`; EnsureNameRoom no longer widens it. Full names
  still show on mouse-over (AceGUI's tree tooltip).
- QA B72.

## Tests
- `tests/sidebar_name_room_run.py` (+3, 11 checks):
  - rows that keep reporting a stale 153 px: a 300 px sidebar is left alone over 5 rebuilds; a 185 px one widens once to 238 and
    stays;
  - a dragged sidebar keeps its width.
  - Negative control: the old Skin.lua fails all 3 new checks. The 8 earlier checks pass on both.
