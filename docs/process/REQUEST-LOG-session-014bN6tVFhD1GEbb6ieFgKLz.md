# Request log, session 014bN6tVFhD1GEbb6ieFgKLz (standing rule V15)

Kept on this session's branch (`claude/great-franklin-j4cahh`, PR heyitsxaya/XayaUI#411) so it merges without conflicts into the shared
`docs/process/REQUEST-LOG.md` (session S1, branch `claude/adoring-hawking-wyda59`, commit 2b4bdb2; not on `main` when this was written).
Same columns and statuses as that file. The rules V15-V17 reached this session from S1's message at 2026-11-06 00:18 UTC, after the
work below was built; they were read on S1's branch (2b4bdb2), not yet on `main`.

Status as of 2026-11-06 00:25 UTC. `main` = `0ef9cb0`. This branch: 4a1727d (core 0.6.49, Chat 0.6.16, QoL 0.7.23, Reskin 0.6.3),
039e9fa (tests only). NOT on `main`: held for Xaya's confirmations (V16) and one landing with the other sessions' core work (V17).

| # | Her words (verbatim; [screenshot]) | Status | Where / what | Notes |
|---|---|---|---|---|
| 1 | "XUI Console does nothing and has no input options" [the console window: title, What to send / Copy / Clear / Bug report, an empty dark area, nothing to type in] | BRANCH + CONFIRM | 4a1727d: a command line along the bottom of the console window runs /xui commands; what they print shows there | CONFIRM (V16, my readings, not her words): (a) "input options" = a line to type /xui commands in; (b) the empty-window hint and its wording; (c) a typed command prints in the console whatever "XayaUI's messages" is set to; (d) other slash commands (/reload ...) are refused; (e) NOT built: also show chat-routed messages while the window is open. |
| 2 | "can't some of these be consolidated into a /xui debug _____ ? this is a LOT of noise" [the /xui help list in the chat history window, "commands (29)"] | BRANCH + CONFIRM | 4a1727d: /xui help 14 lines; /xui debug lists the diagnostic commands; /xui debug <name> runs one | CONFIRM (V16): (a) which commands are "debug": status, probe, debuffs, perf, timing, talents, model, tracker, loc, media, mods, groups, icons, window, seed, auras, gamemenu, chatprobe, widthprobe (auras is also used to find IDs for rules); bug and unlock stay in /xui help; (b) the old forms (/xui status ...) still run, unlisted; (c) the old /xui debug loader check renamed /xui debug window; (d) option lists printed [on/off] instead of [on|off]. |
| 3 | "I hit my usage limit while you were working, but it has reset now. Please continue from where you left off." | n/a | — | Nothing from before the limit had been saved (clean tree, no branch on the remote); the work restarted from `main` 0ef9cb0. |

Found while doing #1-#2 (not her requests):
- The chat history window drops a "|" and the letter after it ("[highlighttrail]", "statusidthprobe" in her screenshot for #2):
  `XayaUI_Chat/History.lua C.Plain`. Avoided for the help lists in 4a1727d; the History.lua fix is a separate suggested task.
- Cloud test runs gave wrong Enum values (5812 of 6614): fixed in 039e9fa (tests only). `tests/cdm_warn_run.py` was red in the cloud
  on `main` because of it.
- Version clash: S1's branch (`claude/adoring-hawking-wyda59`, af87755) also uses core 0.6.49 and QoL 0.7.23. Whichever lands second
  renumbers (or both land as one bundle, V17).
