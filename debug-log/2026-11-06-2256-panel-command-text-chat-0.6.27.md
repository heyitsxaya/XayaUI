# /xui panel help text: "Chat Data Panel settings" (XayaUI_Chat 0.6.27; fork: main)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.
The rename of the Chat Bar (Chat 0.6.23, REQUEST-LOG UI-10) left the `/xui panel` help text in `XayaUI_Chat/Core.lua` saying "Chat Bar
settings" because S1's landing changed the same file; after merging main 687b624 it reads "/xui panel (Chat Data Panel settings)".
Text only. `tests/chat_run.py` all passed.
