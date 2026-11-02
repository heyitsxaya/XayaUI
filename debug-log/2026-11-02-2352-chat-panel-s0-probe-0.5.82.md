# Chat Panel rebuild, stage S0: read-only /xui chatprobe (build 0.5.82, fork: main)
Logged 2026-11-02-2352 UTC (device clock). GitHub issue: #297. Xaya: "rebuild the chat, please" (after the plan in debug-log/2026-11-02-2335-chat-reskin-rebuild-requested-0.5.76.md).

What was built: `Chat/Probe.lua` (new folder `Chat/`, listed in the toc after ChatPrivacy.lua) and the `/xui chatprobe` command (Core.lua, plus the help text). It is READ ONLY: it calls no writer method on any frame (the stub test counts them: 0). It records into `CueRulesDB.chatProbe` (saved on /reload): the game build and screen scale; the secrets API that exists; GetChatWindowInfo per window; for each chat window the frame, tab, edit box, button strip, resize button, background, scroll bar (shown, alpha, strata, size, screen position, parent, every anchor); child trees of ChatFrame1, its edit box, button strip, tab and the dock manager; a list of suspect Blizzard frames by name (QuickJoinToastButton, FriendsMicroButton, ChatFrameMenuButton, ...); every frame anchored to a chat object; and every shown frame in the top-left 420x420 of the screen with its text. It also prints up to six named top-left frames to the chat straight away, to name the floating "251" button.
Privacy: message TEXT is never recorded; only whether the newest message is secret and its length.

Tested: tests/chatprobe_run.py, 20 stub checks pass (read-only, broken frames do not stop it, top-left detection, anchored-to-chat detection, no message text saved, works without the secrets API and without EnumerateFrames). NOT run in game: the stub frames are stand-ins, so real Blizzard frame structure and the real secret-value behavior are unknown until Xaya runs it.

Her step: `/xui chatprobe`, then `/reload`; Claude reads WTF\Account\<name>\SavedVariables\CueRulesDB.lua (chatProbe table) through the linked computer. Then S1.
Inference flagged: that the "251" button is Blizzard's own social button is still an inference until the probe names it.
Files: Chat/Probe.lua (new), Core.lua, XayaUI.toc (0.5.81 to 0.5.82), USER-GUIDE.md (slash command line), tests/chatprobe_run.py (new). Backups: *.pre-chatprobe.20261102.* locally.
