# Adding a cue failed with "attempt to index field 'AuraSound' (a nil value)" (XayaUI_Options 0.6.24, XayaUI_Bonus 0.6.7; fork: main)
Logged 2026-11-04 18:51 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Reported by Insivius (tester, via Xaya, 2026-11-04 13:03 local),
with a BugSack screenshot. Nothing here has run in the game.

## Report
"Trying to add a cue to my blood boil and getting this error, no new cues are being created."

`21x XayaUI_Options/Options.lua:2112: attempt to index field 'AuraSound' (a nil value)` in function 'member'
(AceConfigDialog-3.0.lua:215, FeedGroup), loaded through AdvancedInterfaceOptions' copy of Ace3.

## Cause
- `Options.lua:2112` is the same line in Options 0.6.15 to 0.6.20 (checked through `git log`; 0.6.14 and older have it elsewhere):
  the sound section's status line, `pcall(ns.AuraSound.StatusLine, rule)`.
- The lookup `ns.AuraSound.StatusLine` runs before `pcall`, so with `ns.AuraSound` nil the error escapes. AceConfigDialog then stops
  building the pane, and no cue gets added.
- The line is drawn only while the rule's "Let the game play this sound on the aura itself" is on.
- `ns.AuraSound` comes from `XayaUI/AuraSound.lua` (core 0.6.13+), which always sets it when it loads. So on his machine core's
  `AuraSound.lua` did not load. INFERENCE (his core version was not seen): an older or partly copied core folder, or new core files
  copied in without a game restart (WoW reads an addon's file list at start-up; also an INFERENCE). The neighbouring options all
  check `ns.AuraSound and ...` first; this one did not.

## What changed
- `XayaUI_Options/Options.lua`:
  - the status line checks `ns.AuraSound` first; without it the pane draws a red note: "needs XayaUI core 0.6.13 or newer: copy
    every XayaUI folder again, then restart the game";
  - `ns.AuraSources.Start` (the spell search's index build) is guarded the same way.
- `XayaUI_Bonus/NotepadShare.lua`: `ns.Compat.SendChatMessage` is guarded the same way.
- `tests/lua_pitfalls_run.py` (the V8 static gate), new rule: in a feature addon, `pcall(ns.X.fn, ...)` where ns.X is a table XayaUI
  core defines needs a guard on ns.X on the same line or the 3 above.
  - The core tables are read from core's own files, so the list cannot go stale.
  - `XayaUI_Chat`'s `C.ThemeOn()` counts as the guard for ns.Theme.

## Scope (V4)
`git grep -E "pcall\(ns\.[A-Za-z_]+\.[A-Za-z_]+"` over every addon: 22 hits.
- 19 were guarded already, or are core calling its own modules.
- 3 were unguarded calls from a feature addon into core: the two in Options and the one in Bonus, all fixed.
- The new gate rule fails on exactly those three in the old files.

## Tests
- `tests/lua_pitfalls_run.py`: on the old `Options.lua` / `NotepadShare.lua` the new rule reports 3 failures, including the
  reported line; on the new files, 0.
- `tests/cue_sound_guard_run.py` (new, 7 checks): builds the real settings tree in the stand-in game with a Blood Boil rule and a
  sound cue whose game-played sound is on, finds the cue's status line (`snd_gameSoundStatus`, on the cue's own rule), and reads it
  with and without `ns.AuraSound`.
  - New files: 7 of 7 pass; without `ns.AuraSound` the line reads the "core 0.6.13 or newer" note.
  - Negative control (the old one-line `name` function put back): 1 fails, with
    `Options.lua:2139: attempt to index field 'AuraSound' (a nil value)`, the reported error at today's line number.
  - A first attempt inside `tests/display_tab_run.py` looked for the line on the parent rule's pane; it sits on the cue's pane, so
    it was moved to its own test (and display_tab_run was left unchanged).
- QA: B64.
