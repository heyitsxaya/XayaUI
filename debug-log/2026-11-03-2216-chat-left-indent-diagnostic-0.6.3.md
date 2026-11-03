# Xaya: strange indent at the left of the chat pane (XayaUI_Chat 0.6.1, fork: main)
Logged 2026-11-03 22:16 UTC. GitHub issue: #346. Xaya: "there's a strange indent in the chat pane now" (screenshot: about 40 px of empty space left of every line, system and friend-notification lines alike).
Cause: not found. Checked: saved textInset is 6; Blizzard's message frame anchors every line at the frame's left edge with a 0 offset (live ScrollingMessageFrame.lua), and the Chat Panel adds only that inset. Her account has showTimestamps "%I:%M " (config-cache.wtf, possibly stale); the game puts the stamp in front of each message as text, and a 6-character stamp is about the gap's width, but none shows in the screenshot, so that is a lead only (inference). No other chat addon is enabled on the character.
Change (XayaUI_Chat 0.6.3): read-only /xui chat indent: window-to-text-area distance, saved inset, the timestamp setting, and for up to four visible lines the line box's distance from the window edge and the first 40 characters with | codes shown as typed. Protected text is never read. No layout or behavior change.
Verified offline: tests/chat_run.py, 4 new checks (measures printed, |-codes shown as typed, protected text never printed, no module error); all unit suites pass.
Unverified in game: everything about the cause.
Needed from Xaya: /xui chat indent in game with some chat visible; the printed lines (or a screenshot); whether Options > Social > Timestamps is on.
Files: XayaUI_Chat/Core.lua, XayaUI_Chat/XayaUI_Chat.toc, tests/chat_run.py, MANIFEST.md5.
