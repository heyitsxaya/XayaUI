# Moving a rule bricks the options window (build 0.5.85, fork: main)
Logged 2026-11-03-0030 UTC. GitHub issue: #305. Xaya: "any time I try to move a rule it bricks the ui", "all of these things have to be fixed immediately", "the game is broken right now".
Evidence: her saved CueRulesDB (after a /reload at 00:06 UTC) has errorLog = {} (empty), engineDisplay.groups = {} (the combat engine draws nothing). So no XayaUI Lua error was recorded; the failure is not a captured error or is not an error.
Not found by reading Options.lua (drag, drop, arrows, SelectKeep, ScopePath).
Change (hardening, not a confirmed fix): drag start / per-frame tick / drop and the reorder arrows run under pcall; on failure the drag is cancelled, highlight and drag frame cleared, the message printed to chat and saved to the error log. Recycled sidebar row buttons drop the previous row's height, note and type icons when they show a different rule.
Unverified: whether this stops the lock-up. Needs one reproduction with the message it prints.
Files: Options.lua, XayaUI.toc.
