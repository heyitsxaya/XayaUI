# Roadmap scaffolds combined on one branch (no version change)
Logged 2026-11-06-2326 UTC. Branch: `roadmap-features/combined` (from main 687b624). Session: https://claude.ai/code/session_014bN6tV8Z5syBadjkfcN2Z4 (request log CLEAN-4, section A12).

Xaya (question box): "Combine them into one roadmap on one branch — the other branches get marked as stale if no code is on them".

Done:
- The `roadmap-features/games/`, `roadmap-features/rppm/` and `roadmap-features/layout-profiles/` folders were copied unchanged from
  the heads 61178e8, c8e14b2 and 79b084d (`git checkout <head> -- <folder>`), with the six debug-log entries those branches added. The only edit: `SESSION-START-SUMMARY.md` references in the rppm and layout-profiles READMEs now read `docs/SESSION-START-SUMMARY.md` (the file moved; precheck "moved documents").
- Added `roadmap-features/README.md`, an index of the folders and where each came from.
- Not copied: layout-profiles' root `ROADMAP.md` edit. Main already has the RM-LAYOUTS row in `docs/ROADMAP.md`.

"No code" check: across all three scaffolds, no `.lua` file has a line that is neither blank nor a comment (`sed` strips `--`
comments, `grep -v` blank lines: 0 lines). So all three old branches count as stale under her rule.

Scope (V4): nothing outside `roadmap-features/`, these debug-log entries and `MANIFEST.md5`. Not for merge; nothing to test in game.
