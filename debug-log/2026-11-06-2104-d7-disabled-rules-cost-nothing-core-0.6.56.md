# D7: a switched-off rule costs nothing (core 0.6.56)

Engine session 2 (branch claude/fervent-cerf-hldtwn). Request log E29, E44. UNTESTED in game.
Her answers (question prompt, 2026-11-06, QUESTIONS-engine-session.md "Round 4 answers"): "Accept 1-3" and preview "Still works".

## What it cost before (read in the code, measured in the offline stand-in; NOT measured in game, only the ratios mean anything)
- Engine.lua Step visited every rule each step; a switched-off rule ran StepDisabled + StepPreview; a CUE of a switched-off rule ran the
  full StepEnabled (its own `enabled` stays true), so it was evaluated every step (the new test's negative control: 20 of 20 steps).
- Visual.lua RefreshAllVisuals / RefreshVisual built a (hidden) display frame for every rule with a display, on or off; the unlock / mover
  view drew switched-off rules as samples.
- Stand-in, 100 rules on + 300 off (each with a texture display): 400 frames, 1.37 ms per step, 28.6 ms per full display refresh,
  +17.2 MB after building; after the change: 100 frames, 0.81 ms, 2.8 ms, +4.4 MB (the same as 100 on and none off).
  Script: kept in the session scratchpad, not in the repository (a measurement, not a test).

## What changed
- ns.RuleOff(rule [, parents]) (Visual.lua): switched off, or a cue / condition of a switched-off rule.
- (1) Engine.lua Step: a switched-off rule is stepped once to clean up (finish its actions, hide its display) and then skipped
  (rt.offDone); a rule that was never on gets no runtime record at all. While it is previewed it is stepped; the step after the preview
  ends hides it again.
- (2) Visual.lua: SetVisualShown, RefreshVisual and RefreshAllVisuals free a switched-off rule's frame (ns.DropVisual) and never build
  one, unless it is previewed (the sidebar eye).
- (3) The Disabled tab is unchanged (ns.RuleScope still reads it as disabled).
- Behaviour change to flag: the unlock / mover view no longer draws switched-off rules (they have no frame). Switch a rule on to place it.

## Scope (V4)
ns.SetVisualShown callers (Engine StepEnabled / StepDisabled / StepPreview, Visual SetMoveUnlocked, SetGroupUnlocked, RefreshAllVisuals);
ns.RefreshVisual callers (Options editors' Changed(rule), Cues.lua NewCueRule, AutoPicker AddCue, sidebar Enable / Disable); every reader
of the frames table (VisualFramesOf, dynamic group layout, mover view, pairs / links). The charge watcher already skipped disabled rules.

## Tests
tests/disabled_costs_nothing_run.py (13 checks: no frame / no runtime record / no evaluation for a rule saved off and its cue; switched off
while shown -> gone and freed, never evaluated again; no frame in the mover view; preview draws it and ending the preview frees it;
switched back on shows again; still reads as Disabled). Negative control: 8 of 13 fail on the old code.
QA B193.
