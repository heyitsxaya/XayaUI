# Settings: Game Menu tab broken, sidebar layout (build 0.5.68, fork: main)
Logged 2026-11-02-2300 UTC. Issue #279. Session: https://claude.ai/code/session_014bN6tT2RgkgAqnny8XmpAA

Xaya: clicking the Game Menu tab in Settings closes Settings and does nothing; keep the Game Menu settings in UI Options > Display. Then: Settings should follow the left sidebar / right pane format, with UI Options and Debugging in the sidebar. Cause of the first: only set_ui / set_debug counted as Settings tabs. Changed: Game Menu settings now sit in Display (below Condensed rule list); Settings is one page ("set") with a tree sidebar. Stub-checked only; not tested in game.
