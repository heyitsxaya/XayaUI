# Group page: buttons read in full (#368) and Group / Display / Load drawn as tabs (#370) (XayaUI_Options 0.6.19; fork: main)
Logged 2026-11-04 16:50 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game. Xaya marked these issues
higher priority (2026-11-04).

## Reports
- **#368:** Rules > Enabled > a group. The labels are cut:
  - top row: "Gro...", "Displ...", "Load";
  - action row: "Delete gro...", "Delete with conte...", "+ New r...", and "+ Nested gr" clipped at the pane's right edge;
  - "Enable...", "Disable...".

  Screenshot `docs/issue-screenshots/group-panel-truncation.png` on branch `claude/fervent-cerf-hldtwn`.
- **#370:** the top-row controls (Group / Display / Load) "should be tabs, not buttons".

## Cause (#368), reproduced offline
- Compact action buttons (`Skin.lua`, Options 0.6.4: as wide as their label, never stretched) were sized `GetStringWidth() + 26`,
  with a 64 px minimum.
- The label of an AceGUI button is pinned 15 px in from each side (`AceGUIWidget-Button.lua:87-88`; `Skin.lua:1170` repeats it),
  so its box is the button width - 30.
- INFERENCE: `GetStringWidth()` on that bounded label gives the width of the text as it fits now, not the text's own width.
  - The API reference lists both `GetStringWidth()` and `GetUnboundedStringWidth()` (`docs/reference/api/widgets.md:1458`, `:1463`,
    SecretWhenAnchoringSecret) without describing them.
  - Blizzard's own UI sizes text-fitted controls with `GetUnboundedStringWidth()` (`UIDropDownMenu.lua:811`, `:1366`;
    `SecureUtil.lua:78`; wow-ui-source live 12.1.5.70783, read this session).
- So a button narrower than its label sized itself to the cut text. On every layout pass it then lost 4 px (fitted width + 26 against
  a box of width - 30), down to the 64 px minimum. In the stand-in test every group-page button ends at 64 px and only "Load" fits,
  the pattern in the screenshot.
- Even when measured correctly, the padding of 26 left the label 4 px short of its box.

## What changed
- `XayaUI_Options/Skin.lua`:
  - `LabelWidth`: `GetUnboundedStringWidth` (falls back to `GetStringWidth`, error-protected);
  - `COMPACT_PAD` 26 -> 34 (the 30 px of insets plus 2 px clear on each side);
  - tab buttons (`arg.xuiTab`, #370): SkinButton paints them with the real tab's flat box and the theme classes `xui-tab` /
    `xui-tab-selected` (as SkinTabGroup does), with a hover in the selected-tab border color;
  - the layout pass puts `TAB_GAP` 2 px between tabs, against 10 px for other buttons.
- `XayaUI_Options/Options.lua`: the group page's Group / Display / Load controls carry `arg = { xuiTab = true, xuiTabSel = ... }`. The
  gold label marks the picked tab only while the skin is off (a color code would override the theme's tab text color).
- `USER-GUIDE.md`: the group page's tabs.

## Scope (V4)
- `ns.IsCompactButton` / `CompactWidth` size every execute button that has no `xuiLeft` / `xuiDel` / `xuiWide` / `xuiRow` arg, in
  every options page. So every compact button now gets 8 px wider than its label plus the old padding, and no longer shrinks. Rows of
  them wrap earlier (the wrap rule is unchanged: a button that does not fit starts the next row).
- `arg.xuiTab` is used only by the group page's three tab controls (`git grep xuiTab`).
- Not changed: "+ Nested gr" was clipped by the pane's right edge. With full-width buttons the row now wraps sooner. Whether the
  content width the layout pass uses still includes the pane's right column was not checked (INFERENCE: the scroll-bar column). QA B59
  checks it in game.

## Tests
- `tests/compact_button_width_run.py` (new, 15 checks), on the real `Skin.lua` layout pass with stand-in AceGUI buttons whose label
  box is width - 30:
  - every group-page label fits after 3 passes from a 64 px start;
  - a wide start settles at label + 34 and stays there;
  - the fallback without `GetUnboundedStringWidth`;
  - a row of four group buttons is sized to its labels;
  - tabs are 2 px apart while other buttons keep 10.
- `tests/display_tab_run.py` (+5 checks), on the real group page:
  - Group / Display / Load carry the tab marker;
  - Group is picked first, and clicking Load picks Load;
  - with the skin on, labels have no color code; with the skin off, the picked one is gold.
- **Negative control:**
  - the old `Skin.lua` fails 10 of the width checks, with the screenshot's pattern;
  - on the old `Options.lua` the tab-marker checks fail (no `arg`).
- `flex_dropdown_run.py`, `skin_button_run.py`, `layout_parity_run.py`: pass.
- QA: B59.
