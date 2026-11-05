# Chat history: opens on the active tab, "All" last, whisper tabs (XayaUI_Chat 0.6.15)
Logged 2026-11-05 20:27 UTC. Session branch `claude/admiring-ride-sm7jrh`. Not run in game (QA D11).

## Request (Xaya, 2026-11-05, her words)
- "ALL tab in chat history open window should not the the default pane. It should also include whisper windows as individual tabs if
  selected as an option in either blizzard native social options or when toggled within the addon"
- To Claude's suggestion (open on the chat tab you are on, "All" at the end of the row): "Chat history - active tab, yes"
- "Our own switch should default to the current interface selection in blizzard OR bundle all whispers into a consolidated tab"

## Change
- `XayaUI_Chat/History.lua`
  - Each open shows the active chat tab (`C.History_ActiveKey`: the dock's selected window via `C.ScrollTarget`); a tab picked with
    `C.History_Select` applies at once while the window is open, else on its next open. A tab that no longer exists falls back to the
    first chat tab (was "All").
  - Tab order: chat tabs, whisper tabs, Console, All (was All first).
  - Whisper entries carry the conversation key: `CHAT_MSG_WHISPER` / `_INFORM` by the other person's name without realm, lowercased
    ("W:ann"); `CHAT_MSG_BN_WHISPER` / `_INFORM` by the event's Battle.net ID (arg 13, "B:<id>"), labelled with the BattleTag before "#"
    from `C_BattleNet.GetAccountInfoByID` (docs/reference namespaces.md:538), else "Battle.net friend". Secret values are never keys.
  - `C.History_WhisperMode`: setting `histWhispers` "game" (default): CVar whisperMode "popout" / "popout_and_inline" -> one tab per
    conversation, anything else or unreadable -> none; "one" -> a single Whispers tab.
  - The game's temporary whisper windows get no chat-window button (their conversations come from the messages instead), so a
    conversation never has two buttons.
- `XayaUI_Chat/Core.lua`: default `histWhispers = "game"`. `XayaUI_Chat/Options.lua`: History > "Whisper tabs" dropdown beside
  "Messages kept" (the options-style rule: no dropdown alone on a row). `XayaUI_Chat.toc` 0.6.15. USER-GUIDE (Chat Panel > History),
  QA-CHECKLIST D11.

## Decisions (mine; each can be changed)
- DECISION: "All" goes to the very end, after Console (her earlier wording "should not show except for on the last tab").
- DECISION: two choices only, as she named them; with the game set to In-line and "As the game" chosen there are no whisper tabs.
- DECISION: a conversation is matched by name without realm (the game's whisper window target and the message author can differ in
  whether they carry the realm). INFERENCE: two people of the same name on different realms share a tab.

## INFERENCES (not checked in game)
- A Battle.net whisper window's `chatTarget` is the same number as the message's Battle.net ID (arg 13), so the history opens on the
  right conversation from that window.
- `CHAT_MSG_WHISPER_INFORM`'s author argument is the person you whispered.

## Tests
- `tests/chat_run.py`: tab order General, Combat Log, Trade, Console, All; opens on the active tab, also after closing on another;
  whisperMode popout and popout_and_inline -> Ann, Bob tabs; Ann's tab holds her line and yours only; inline -> none; "one" -> a Whispers
  tab with every whisper; on a game whisper window the active key is W:ann (each), WHISPERS (one), none (In-line); default "game".
  All passed. On the old code (History.lua, Core.lua, Options.lua from HEAD, this test kept): 9 checks failed; restored: all passed.
- `chat_pieces_run.py`, `chat_off_costs_nothing_run.py` FAILS: 0; `window_margins_run.py` 44 / 0; `lua_pitfalls_run.py` FAILS: 0.
