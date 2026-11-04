# #351 phase 1: one margin and one gutter in the settings window; the gutter between every two controls on a row (XayaUI_Options 0.6.33; fork: main)
Logged 2026-11-04 20:52 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Report
#351 (Xaya, 2026-11-03): "across all display panes in the entire addon, set a standard gutter and margin so that all elements are
not smushed directly into their container bounds". Phase 1 is the settings window only (XayaUI_Options). A parallel session (#386)
suggested this split and works on Dev Assist; coordinated by message.

## Found
- **Gutter:** `ns.FlexPrepass` (Skin.lua) added the 10 px gap only when a row stretched a control or held a compact button. Rows of
  fixed-width controls got none and touched each other: labels, icons, colour pickers, images and relative widths.
- **Margin:** the content insets XayaUI sets are 10 px already: inline boxes and indented boxes (10 + indent), the right pane
  (10 + the user's pane padding). AceGUI's own default inset is also 10. So the margin needed one definition, not new values.
- **Indents kept, not a margin:** the 20 px body indent of trigger / cue / condition panes is a deliberate hierarchy. The 42 px
  search area is a fixed widget area.

## What changed (`XayaUI_Options/Skin.lua`)
- `UI_MARGIN, UI_GUTTER = 10, 10`, defined once (also `ns.UI_MARGIN` / `ns.UI_GUTTER`).
- The right pane's inset and the indented box's inset read `UI_MARGIN`. Release handlers that give a widget back to AceGUI still
  restore AceGUI's own literal 10.
- `GAP` is `ns.UI_GUTTER`.
- The gutter goes between every two controls on a row; tab rows keep 2 px (#370). The row-wrap check already counted the gutter,
  so a row that only fit without it now wraps instead of touching.
- QA B75.

## Not done (phase 1b / later)
- The harness check that measures every rendered settings pane (VERIFICATION V11). The stand-in test below covers the layout rule
  only.
- The other windows (Chat history, Notepad, console, Dev Assist, data panels, the Game Menu skin): later phases, after the
  parallel Dev Assist work lands.

## Tests
- `tests/ui_gutter_run.py` (new, 8 checks), the real layout pass on stand-in widgets:
  - the constants are defined once and every inset reads UI_MARGIN;
  - three labels, an icon and its label, colour pickers and an image each get 10 px;
  - two labels that fit only without the gutter wrap;
  - tabs keep 2 px; stretching rows are unchanged.
  - Negative control: the old Skin.lua fails 5 (gaps 0 0 0).
- `tests/compact_button_width_run.py`, `tests/flex_dropdown_run.py`, `tests/sidebar_name_room_run.py`, `tests/skin_button_run.py`,
  `tests/layout_parity_run.py`: pass. The full suite runs before main.
