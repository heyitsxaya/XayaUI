# Rules sidebar: nested rows keep room for their names (#369) (XayaUI_Options 0.6.20; fork: main)
Logged 2026-11-04 16:52 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game. Xaya marked the
group-page issues higher priority (2026-11-04).

## Report (#369)
Rules > Enabled: nested group and rule names show 1-3 characters ("VD...", "De...", "Pe...", "A...", "F...").

Screenshot `docs/issue-screenshots/group-panel-truncation.png` on branch `claude/fervent-cerf-hldtwn`: the sidebar is about 185 px
wide.

## Cause (from the code)
- Row layout (`XayaUI_Options/Options.lua` DecorateButton):
  - left: the indent (8 px a level) + the reorder arrows (`ns.REORDER_W` + 11) + the open / close arrow + the 32 px type icon
    (`ns.TYPE_ICON_SIDEBAR_W`), so a level-4 name starts about 95 px in;
  - right: lock / note / eye / headphone columns (`xuiIconR`), about 41 px.
- In a 185 px sidebar (163 px rows) a level-4 row keeps about 27 px for its name.
- The sidebar was widened to 270 px only once, and only if it was 175 px or less (`Options.lua` DecorateTree, `status.xuiWide`).
  A narrower width saved later (the sidebar can be dragged) stayed.

## What changed
- `XayaUI_Options/Skin.lua` `ns.EnsureNameRoom(tree)`: after the sidebar is drawn, it finds the visible row with the least room for
  its name.
  - If that row has under 80 px (`ns.SIDEBAR_NAME_ROOM`), the sidebar widens by the shortfall in one `SetTreeWidth` call (still
    resizable).
  - It never widens beyond AceGUI's own limit, min(400, window width - 50) (`AceGUIContainer-TreeGroup.lua:561`).
  - It never narrows. Hidden rows, rows without text and rows that recorded no inset are ignored. A busy flag stops re-entry
    through SetTreeWidth.
- `XayaUI_Options/Options.lua`:
  - DecorateButton records each row's name insets (`xuiTextL` / `xuiTextR`), clears them first (AceGUI reuses row buttons);
  - the tree's RefreshTree hook calls `ns.EnsureNameRoom` after decorating.
- The full name on mouse-over already existed: AceGUI's tree tooltip (`AceGUIContainer-TreeGroup.lua:204`, on by default at `:292`;
  XayaUI never turns it off).
- `USER-GUIDE.md`: sidebar width.

## Scope (V4)
`SetTreeWidth` is called from `Options.lua` DecorateTree (the one-time 270 px widening, kept) and now from `ns.EnsureNameRoom`. Text
insets are set only in DecorateButton (`git grep 'button.text:SetPoint("LEFT"'`: one place). Other trees (Settings > feature trees)
do not use DecorateTree's rule-row layout, so their rows record no inset and are never widened.

## Tests
- `tests/sidebar_name_room_run.py` (new, 8 checks), on the real `ns.EnsureNameRoom` with a stand-in tree:
  - the screenshot's case: a 185 px sidebar, a level-4 row with 27 px, widened to 238 so it has 80 px;
  - enough room: untouched;
  - the window limit holds (a 400 px window: at most 350);
  - hidden and empty rows are ignored;
  - a row without recorded insets is ignored.
- **Negative control:** the old `Skin.lua` has no such function; the check that it exists fails, and with it everything it guards.
- QA: B60.
