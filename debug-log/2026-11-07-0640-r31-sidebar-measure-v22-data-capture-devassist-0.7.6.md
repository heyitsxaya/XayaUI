# R31 sidebar names after a rule change; V22 data capture (Dev Assist 0.7.6)
Logged 2026-11-07 06:40 UTC. Branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Her words
- R31: "rule sidebar continues to bug out and clip itself after any rule change is made" [screenshot, not visible to this session].
- V22 (relayed 2026-11-07; the coordinator numbers it V22, V21 being the issue labels): "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test
  walk through with pre-fill confirmation options or data capturing".

## R31: what was tried
- Reproduction in the stand-in game (real addons, real settings window, main 687b624 + this branch):
  - setup: a rule with a long name three groups deep, opened in the Rules sidebar;
  - before any change: sidebar 238 px, the tightest name 102 px;
  - after a rename (NotifyChange): 238 px / 102 px;
  - six enable / disable changes: 238 px every time; the tightest name 102 px, or 209 px while the rule sits in the shorter list.
- Not reproduced. INFERENCE: the report may predate the #35 fix (the sidebar measured rows mid-rebuild and widened or narrowed
  on every redraw; `ns.EnsureNameRoom` now uses each row's own text insets). Not confirmed.
- Next: the walkthrough "Rules sidebar: names after a rule change" (QA B179d) measures her sidebar before and after a change and
  saves the numbers with her answers.

## V22 data capture
- `QAWalk.lua`: each check's result is kept with the answer:
  - `a` = the addon's verdict (Y / N / ?);
  - `d` = what it saw (up to 200 characters, plain text).
- It is shown on the end screen ("the addon saw: ...").
- It travels in the export code as `aN=` lines; on import, `a` is checked against Y / N / ? and `d` is cleaned like every other field.
- `tests/qa_walk_run.py`: 42 checks, including the saved data and its round trip.
