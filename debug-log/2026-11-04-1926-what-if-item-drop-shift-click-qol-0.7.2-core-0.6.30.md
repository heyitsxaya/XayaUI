# What If: items can be dropped or shift-clicked into Compare an item (XayaUI_QoL 0.7.2, XayaUI 0.6.30; fork: main)
Logged 2026-11-04 19:26 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Report
Xaya, 2026-11-04, with a screenshot (Character Toolkit > What If, a third-party bag window open): "I can't drop or shift+click an
item into the item comparison".

## Cause (read in Blizzard's live UI source, Gethe/wow-ui-source `live`, fetched this session)
- Blizzard's own item buttons call `ChatFrameUtil.InsertLink(link)` on a chat-link click (`Blizzard_ItemButton/Mainline/
  ItemButtonTemplate.lua:379`, `HandleModifiedItemClick`).
- `ChatEdit_InsertLink` is a copy of that function, taken when the fallback addon loads
  (`Blizzard_DeprecatedChatInfo/Deprecated_ChatFrame.lua:43`). XayaUI's post-hook replaced only the `ChatFrameUtil` entry, so a
  bag addon calling the old name ran the original, unhooked function.
- The hook took the link only while the box had keyboard focus. Nothing handled a dropped item.
- INFERENCE: which name her bag addon calls was not checked; either way the fix covers both.

## What changed
- `XayaUI/Compat.lua` (0.6.30): `Compat.ChatHookTargets(name)` lists every place to hook (the 12.x function and the old global when
  it exists). Compat stays the only file that names the old global.
- `XayaUI_QoL/CharacterToolkit.lua` (0.7.2):
  - hooks both names. A click seen through both is taken once (same link, same GetTime).
  - Takes an item link while the box has focus, or while the What If tab is shown and no chat box is open. An open chat box keeps
    the link, as before. Spell and other links are ignored.
  - The link replaces the box's text and is compared at once.
  - `OnReceiveDrag` and `OnMouseUp` on the item box take an item from the cursor (`GetCursorInfo` "item", ID, link), compare it,
    and clear the cursor. `GetCursorInfo` is listed without returns in the reference (`globals.md:158`); the "item" form is
    INFERENCE until seen in game. Anything else on the cursor is left alone.
- `USER-GUIDE.md` Compare an item; QA E1p.

## Tests
- `tests/char_toolkit2_run.py` (150 checks, +10): a 12.x world where the old name is a copy; the old name reaches the box; no focus
  with What If shown; an open chat box keeps the link; another tab does not take it; a spell link is ignored; drop, click with an
  item on the cursor, and a dropped spell left alone.
  - Negative control: the old Compat / CharacterToolkit fail 5 of them.
- `tests/char_toolkit_run.py` (100), `tests/lua_pitfalls_run.py`: pass.
