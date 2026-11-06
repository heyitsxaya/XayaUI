# 2026-11-06 07:05 UTC: settings sidebar drops rows after a click in the right-hand pane (Options 0.6.52); cursor theme names (core 0.6.54); Dev Assist ilvlEquipped (0.7.3)

Session 014bN6tSs9peLMW4F93tnQcj, branch `claude/nifty-fermi-vz9z49`. Request log: `docs/process/REQUEST-LOG-session-014bN6tSs9peLMW4F93tnQcj.md` rows 2, 5, 9.

## Reports (verbatim)
- Insivius (relayed by Xaya): "Scroll panel broke when I tried to select "Cursor Highlight". It will not show more than 4 lines at a time and forces a scroll to navigate the menu" [v0.6.49: QoL sidebar shows 4 rows, the rest of the pane empty, scroll bar thumb half way].
- Xaya: "clicking options in the right hand side panel still consistently drops elements nested within it across all tabs. do a full review on what causes this bug to occur, because it's a problem with the pane iteself" [v0.6.50: QoL > Gradient Cursor Trail open; the sidebar shows 5 rows (Character Toolkit, Panel, Slot Overlays, Spell Math, Tooltip lines); Cursor, Cursor Highlight and Gradient Cursor Trail missing; the rest of the pane empty].
- Xaya: "theme names should drop "cursor theme:" prefix" [Theme list: "Cursor trail: Fel" ... "Cursor trail: Frost"].

## Cause (sidebar)
`XayaUI_Options/Skin.lua`, the RefreshTree wrapper every skinned sidebar runs (Rules, Smart Categories, QoL, Bonus Features, Chat,
Blizzard UI Reskin, Settings). AceGUI sizes its row window for 18 px rows; the wrapper refreshes with a pretend height, measures the
rows really drawn, then grows or shrinks the count and remembers it on the widget (`xuiLines`). The grow step was guarded by

    local _, mx = self.scrollbar and self.scrollbar:GetMinMaxValues()
    if cnt > 0 and total < avail - 40 and (mx or 0) > 0 then ... grow ...

In Lua 5.1 an operand of `and` is adjusted to one value (Lua 5.1 manual, section 2.5: a call's results are kept in full only as the
last element of an expression list), so `mx` was always nil and the grow step never ran (checked in the repo's Lua 5.1 runtime:
`local _, mx = sb and sb.GetMinMaxValues()` gives nil). The remembered count could only shrink. Any refresh that measured little room
lowered it for good:
1. a change in the right-hand pane: AceConfigDialog redraws the window; the stand-in shows the sidebar refreshed while it is still short
   during that redraw (the count fell to 1 of 8 rows in a 711 px sidebar, `tests/sidebar_rows_regrow_run.py` on the old code);
2. the window made short and tall again;
3. AceGUI recycles TreeGroup widgets: `xuiLines` was not cleared on release, so a tree could start from another tree's count.
Every tab's sidebar runs this wrapper, which matches "across all tabs".

INFERENCE (not checked in game): in the game the short moment in (1) is the same (the tree is re-anchored inside the redrawn window and
refreshes before it has its final height). The fix does not depend on which refresh was short: the count now grows back on the next
refresh (the frame's OnSizeChanged, a scroll, a click).

## Fix
- The grow step asks AceGUI's own list of rows (`#self.lines`, built by RefreshTree before drawing) whether rows are left over,
  instead of the scroll bar.
- `xuiLines` is cleared when the widget is released (Skin's OnRelease restore).
- `tests/lua_pitfalls_run.py` now flags `a, b = x and f()` (every name after the first is always nil). It found one more:
  `XayaUI_DevAssist/DevAssist.lua:417` `local avg, eq = GetAverageItemLevel and GetAverageItemLevel()`: the character capture's
  `ilvlEquipped` was always nil. Fixed (Dev Assist 0.7.3). INFERENCE: GetAverageItemLevel's second return is the equipped average
  (it is not in the repo's docs/reference/api/api.json, so this is from the game's widely used FrameXML behaviour, not quoted here);
  the fix only stops the value being dropped, it does not depend on what it holds.

## Scope (V4): every reader of the changed code
- `git grep -n "xuiLines"`: Skin.lua (the wrapper), tests/sidebar_switches_run.py (clears it before its own redraws; that clearing is
  what hid this defect there; left as is, still correct).
- `git grep -n "RefreshTree"` in XayaUI_Options: Skin.lua drag Finish, Select hook, the wrapper; Options.lua DecorateTree wrapper and
  line 5370; AceGUI TreeGroup itself. All go through the wrapper; none reads `xuiLines`.
- Same pattern elsewhere: a regex over every addon Lua file (no Libs) for two names from one `and` / `or` call: only Skin.lua and
  DevAssist.lua (the pcall(function() return x and f() end) lines keep one value on purpose).
- Theme names: `git grep "Cursor trail: "`: XayaUI/Theme.lua (the name), tests/cursor_ui_themes_run.py.
  Saved keys (`cursor_<preset>`) are unchanged; the list is ordered by key (ThemeEditor.lua sorting), not by name.

## Tests
- New `tests/sidebar_rows_regrow_run.py` (10 checks; real addons in the stand-in, rows at AceGUI's 18 px): every QoL sidebar row drawn
  after opening, after 1 and 3 changes in the right-hand pane, after the window is made short then tall, from a remembered count of 2,
  and a released widget forgets its count. Old Skin.lua: 5 fail (1 of 8 rows drawn after a right-pane change). New: 10 pass.
- `tests/lua_pitfalls_run.py`: old code 2 FAILS (Skin.lua:826, DevAssist.lua:417); new: 0.
- `tests/cursor_ui_themes_run.py`: names now expected without the prefix; 131 checks, 0 failed.
- Not seen in game: QA B168, B169, J16.

## Versions
Options 0.6.48 -> 0.6.52, core 0.6.50 -> 0.6.54, Dev Assist 0.7.2 -> 0.7.3 (0.6.49-0.6.51 / 0.6.51-0.6.53 are taken on other
sessions' branches: fervent-cerf, cool-ramanujan, dreamy-edison).
