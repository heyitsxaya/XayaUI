# Function audit, Chat fixes: the game's line fade comes back when the Chat Panel is off, the ignore click says when it failed, whole-word filter phrases with punctuation or non-Latin letters (XayaUI_Chat 0.6.29)
Logged 2026-11-07 00:40 UTC. Session 014bN6tSfFULX4BSXzmZ1yCx (function audit, UI-60), branch `claude/function-audit`, on main 28380a9. Nothing here has run in the game.
Rows: docs/process/FUNCTION-AUDIT-2026-11-07.md D31, D32, D37.

## What changed
- `XayaUI_Chat/Fade.lua` + `Core.lua` (D31): before the first SetFading / SetTimeVisible on a chat window, its own values are kept
  (`GetFading` / `GetTimeVisible`, widgets.md 2413 / 2460, SimpleMessageFrameAPI); `C.Teardown` puts them back, like the indent value.
  Before: Blizzard's chat kept the Chat Panel's fade setting after the panel was turned off, until /reload.
- `XayaUI_Chat/Messages.lua` (D32): `C_FriendList.AddIgnore(name) -> added: bool` (namespaces.md 1847) is read; "Ignoring <name>"
  only when it was added, otherwise "Could not ignore <name>: the game did not add them (already ignored, or the Ignore list is full)."
- `XayaUI_Chat/Messages.lua` (D37): "Match whole words only" finds each plain occurrence and needs a word boundary only on a side
  where the phrase starts / ends with a letter or digit; bytes of non-ASCII characters count as letters. Before: `%f[%w]`/`%f[%W]`
  (ASCII only): "wts!", "$gold" and Cyrillic phrases never matched. Limit: non-ASCII punctuation (e.g. guillemets) also counts as a
  letter, so such a phrase edge needs a boundary (it still matches when surrounded by spaces).

## Scope (V4)
- SetFading / SetTimeVisible: only Fade.lua TextFade. Teardown is the one place the panel gives Blizzard's chat back.
- AddIgnore: only Messages.lua OnItemRef. HasPhrase: the message filter (Messages.lua) only.

## Tests
- `tests/chat_run.py`: D31 (1 check), D32 (2), D37 (7: helper + one through the real filter). On 28380a9: D31 and D32 fail (3);
  D37's 7 fail (no helper; the filter check fails because the old pattern never matches "wts!"). All pass now.
- `tests/chat_world.lua` (stand-in): GetFading / GetTimeVisible added; AddIgnore returns added: bool like the API.
- chat_collapse_bar, chat_data_panel_side, chat_off_costs_nothing, chat_pieces, chat_tab_align, chatprobe: pass.

## QA
D22, D23.
