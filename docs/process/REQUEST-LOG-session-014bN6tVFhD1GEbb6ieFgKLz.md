# Request log, session 014bN6tVFhD1GEbb6ieFgKLz (standing rule V15)

Kept on this session's branch (`claude/great-franklin-j4cahh`, PR heyitsxaya/XayaUI#411) so it merges without conflicts into the shared
`docs/process/REQUEST-LOG.md` (session S1, branch `claude/adoring-hawking-wyda59`, commit 2b4bdb2; not on `main` when this was written).
Same columns and statuses as that file. The rules V15-V17 reached this session from S1's message at 2026-11-06 00:18 UTC, after the
work below was built; they were read on S1's branch (2b4bdb2), not yet on `main`.

Status as of 2026-11-06 00:44 UTC. `main` = `7426e7f` (merged into this branch). This branch: core 0.6.50, Options 0.6.48, Chat 0.6.17,
QoL 0.7.26, Reskin 0.6.3 (built as 0.6.49 / 0.6.16 / 0.7.23 in 4a1727d, relabelled: those numbers were taken). NOT on `main`: held for Xaya's
confirmations (V16) and one landing with the other sessions' core work (V17).

| # | Her words (verbatim; [screenshot]) | Status | Where / what | Notes |
|---|---|---|---|---|
| 1 | "XUI Console does nothing and has no input options" [the console window: title, What to send / Copy / Clear / Bug report, an empty dark area, nothing to type in] | BRANCH + CONFIRM | 4a1727d (core 0.6.50 after relabel): a command line along the bottom of the console window runs /xui commands; what they print shows there | CONFIRM (V16, my readings, not her words): (a) "input options" = a line to type /xui commands in; (b) the empty-window hint and its wording; (c) a typed command prints in the console whatever "XayaUI's messages" is set to; (d) other slash commands (/reload ...) are refused. (e) answered in #4 (her 2): built. |
| 2 | "can't some of these be consolidated into a /xui debug _____ ? this is a LOT of noise" [the /xui help list in the chat history window, "commands (29)"] | BRANCH + CONFIRM | 4a1727d (core 0.6.50 after relabel): /xui help 14 lines; /xui debug lists the diagnostic commands; /xui debug <name> runs one | CONFIRM (V16): (a) which commands are "debug": status, probe, debuffs, perf, timing, talents, model, tracker, loc, media, mods, groups, icons, window, seed, auras, gamemenu, chatprobe, widthprobe (auras is also used to find IDs for rules); bug and unlock stay in /xui help (auras: her #4 3 asks for examples first); (b) answered in #4 (her 1): old forms taken out; (c) the old /xui debug loader check renamed /xui debug window; (d) option lists printed [on/off] instead of [on|off]. |
| 3 | "I hit my usage limit while you were working, but it has reset now. Please continue from where you left off." | n/a | — | Nothing from before the limit had been saved (clean tree, no branch on the remote); the work restarted from `main` 0ef9cb0. |
| 4 | "1) let’s move to /xui debug ____ — routinely used things can maybe get shortcut commands<br>2) yes as long as it doesn’t negatively impact performance<br>3) example context for either case!" | 4.1 BRANCH; 4.1 shortcuts CONFIRM; 4.2 BRANCH; 4.3 CONFIRM | this branch after 8ae717b (core 0.6.50, Options 0.6.48) | Read as answers to the three decisions of the first report (not the nine of the second): (1) old forms vs /xui debug only, (2) chat-routed messages in the open console, (3) /xui auras in help or debug. Stated to her for correction. 4.1: old forms taken out everywhere (dispatcher, feature registrations, /xui stats widthprobe, every message, USER-GUIDE, QA steps); "shortcut commands": proposed (status, auras), not built (V16). 4.2: built, cost one check per message, nothing while the console is closed; QA B152. 4.3: examples of both cases sent to her; waiting. |

Found while doing #1-#2 (not her requests):
- The chat history window drops a "|" and the letter after it ("[highlighttrail]", "statusidthprobe" in her screenshot for #2):
  `XayaUI_Chat/History.lua C.Plain`. Avoided for the help lists in 4a1727d; the History.lua fix is a separate suggested task.
- Cloud test runs gave wrong Enum values (5812 of 6614); `tests/cdm_warn_run.py` was red in the cloud on `main` because of it. Fixed
  on `main` by another session (7426e7f); this branch keeps `main`'s fix and adds `tests/harness_enum_values_run.py`.
- Version clash (resolved 00:22 UTC): PR #408 holds core 0.6.49 / QoL 0.7.23, `main` holds Chat 0.6.16, S1 / PR #410 hold QoL 0.7.24 /
  0.7.25; this branch moved to core 0.6.50, QoL 0.7.26, Chat 0.6.17 (Reskin 0.6.3 was free). PR #410's session plans core 0.6.51, Options
  0.6.46, Chat 0.6.18, Reskin 0.6.4 and edits `XayaUI_Reskin/GameMenuSkin.lua`, which this branch also changes (two lines at its end).
