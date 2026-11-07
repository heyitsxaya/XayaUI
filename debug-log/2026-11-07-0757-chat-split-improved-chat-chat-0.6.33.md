# Chat settings split: Blizzard UI Reskin > Chat Panel (look) and QoL > Improved Chat (behaviour) (Chat 0.6.33, Dev Assist 0.7.25)

Session 014bN6tUJW6J1rnMZ6Z7t7c1 (chat-round session), branch `claude/chat-round-1106`, built on `claude/chat-246-whisper` (Chat 0.6.31, CHATREV-10/11/12) merged with `main` 7b830cf.

## Her words (REQUEST-LOG A8 UI-18 / UI-19 / UI-21, 2026-11-06)
- UI-18: "chat reskin (colors, boxes, fonting go to blizzard UI reskin. other functionality (whispers, history, filtering, etc -- anything newly added by the addon) go to "Improved Chat" in QoL"
- UI-19: "review the difference between ElvUI reskin and ElvUI chat modes -- assuming all purely visual elements remain in skin and all things that directly modify chat behavior go into QoL"; switches: "1 but note in improved chat that it likely displays better with a chat reskin (should support other chat reskin options)"
- UI-21, the item list: "Yes, as listed".

## What changed
- Settings: Blizzard UI Reskin > Chat Panel keeps General (Font options; Color + display options: background, border, texture, input look, hint), Chat Tabs (tab row, tab look) and Layout (size, position, mover, inside the pane, indent wrapped lines, Blizzard's pieces: button strip, Blizzard's scroll bar, social button, back-to-newest arrow). New QoL > Improved Chat (own tick box on its row, her note) holds General (Scroll and fade options incl. the slow-scrolling bar and "Chat hidden (collapsed)"; Chat history incl. whisper tab lists, combine box, "Switch to a new whisper tab I start"; Timestamp, copying, and links), Chat Data Panel, Filters, Sounds, Privacy. Her #246 headers (CHATREV-11) are kept, each on the page its items belong to. Settings keys are unchanged; every control exists once.
- Runtime: two switches. `C.On()` = the Chat Panel (skin); new `C.ImprovedOn()` = `chat2.improvedOn ~= false` (default on, so saved profiles keep what they had). Parts are tagged (`C.PART_GROUP`): bar, fade, console, messages, filter, itemref, scroll, whisperSelect -> improved; panel (refresh events) -> either; the rest (upkeep, anchoring) -> skin. `C.Teardown` split into `C.TeardownSkin` (Blizzard's chat back) and the Improved Chat half (collapse / fade alpha, block hidden). With the Chat Panel off and Improved Chat on, the block is laid over Blizzard's chat where the game put it (`C.HostRect`: main window left / right, tab row top, input line bottom) and follows it when the game moves it (existing hooks -> `C.SoonAnchor` -> `C.Layout`); Blizzard's chat itself is not moved or restyled. With Improved Chat off, the Chat Data Panel, collapse arrow, slow-scrolling bar, history button, privacy button, fade, filters, history, sounds and whisper switch do not run.
- `/xui panel` and a right-click on a data block open QoL > Improved Chat > Chat Data Panel; old addresses (look / behavior / history) still open the right page. New launcher "Improved Chat".
- Dev Assist 0.7.25: walkthrough "chat-settings-layout" rewritten for the two pages; new walkthrough "chat-improved-split" (pre-fill); "chat-whisper-switch" checks Improved Chat instead of the Chat Panel.

## Scope (V4: readers of the gating)
`git grep -n "C.On()\|C.active\|s.barOn\|s.scrollOwn\|s.collapsed" XayaUI_Chat`: Bar.lua (Refresh, Place, Tick), Fade.lua (Refresh, Tick), Frame.lua (Build OnSizeChanged, Layout, Parts, ToBottomUpdate, HookAlpha, Elements, SoonAnchor, Refresh, Upkeep, mover grip), History.lua (ConsoleOn, button), Privacy.lua (canShow), Scroll.lua (layout), Skin.lua (focus hooks, tab-row hook), Messages.lua / Sounds.lua / Whispers.lua (through their parts). Options: Options.lua only (no XayaUI_Options file changed: the QoL page registers through `ns.RegisterSettingsPage("qol", ...)`).

## Tests
- New `tests/chat_improved_split_run.py` (17 checks; 14 fail on 9f0ed8b, the 3 guards pass there).
- Updated for the move: chat_run.py (pages, right-click address, "off" now means the Chat Panel only), chat_off_costs_nothing_run.py (section A saves both switches off), chat_246_whisper_run.py (her #246 headers per page), chat_data_panel_side_run.py, qa_walks_chat_run.py (both walkthroughs + negatives); chat_world.lua gets `W.allChatOptions`.

## Not verified in game
Everything above. Improved Chat beside another addon's chat skin (ElvUI chat module) is untested; the block reads ChatFrame1's place, which such an addon may move (INFERENCE: the move hooks see it).
