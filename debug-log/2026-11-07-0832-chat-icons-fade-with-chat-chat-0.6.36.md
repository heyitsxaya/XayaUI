# Every icon on the chat fades with it (O-143; Chat 0.6.36, Dev Assist 0.7.28)

Session 014bN6tUJW6J1rnMZ6Z7t7c1 (chat-round session), branch `claude/chat-round-1106`. Versions of this branch relabelled to the hub's registry in the same commit: split Chat 0.6.33 / Dev Assist 0.7.25, input line 0.6.34 / 0.7.26, sidebar 0.6.35 / core 0.6.68 / 0.7.27, this 0.6.36 / 0.7.28 (they were 0.6.32-0.6.34 / 0.7.14-0.7.16 / core 0.6.62 in the earlier commits).

## Her words (relayed by the hub as O-143, 2026-11-07)
"weird chat appearance when chat fades -- the sidebar icons should also be fading". Her screenshot (hub's description): with the chat faded out, a small chevron at the top-left and a gold-boxed eye at the top-right stayed at full strength.

## Cause (main 7b830cf)
- The chevron is the collapse arrow `XayaUIChatArrow` (XayaUI_Chat/Frame.lua BuildArrow): a child of the chat block's container, which is never faded; C.ApplyAlpha faded the pane and Blizzard's frames only.
- The eye is the privacy button `XayaUIChatPrivacyButton` (XayaUI_Chat/Privacy.lua BuildButton): parented to UIParent, its opacity set only from its own "Button opacity" setting.

## Fix
- C.ApplyAlpha sets the arrow's alpha to the fade, and the eye's resting opacity is multiplied by it while it sits beside the chat (`ns.ChatPrivacy_Fade`); under the mouse it shows fully, as its OnEnter does.
- The sidebar (built this round) fades with the chat by default ("Fade with the chat" now on unless unticked); its buttons are its children and fade with it.
- The mouse over the sidebar or the eye wakes the chat, as the mouse over the chat does (Fade.lua Tick).
- The Chat Data Panel keeps its own setting "Fade the Chat Data Panel too" (unchanged; INFERENCE: her complaint named the icons, not the panel).

## Tests
New `tests/chat_fade_controls_run.py` (9 checks; 5 fail on 64d8e78, 4 guards pass there). qa_walks_chat_run.py: walkthrough "chat-fade-controls" (D28) with two negatives.

## Not verified in game
All of it.
