# Function audit, Dev Assist: QA walkthroughs put back what "Do it for me" changed, and never touch a group of yours called "QA test group" (XayaUI_DevAssist 0.7.15)
Logged 2026-11-07 00:43 UTC. Session 014bN6tSfFULX4BSXzmZ1yCx (function audit, UI-60), branch `claude/function-audit`, on main 28380a9. Nothing here has run in the game.
Rows: docs/process/FUNCTION-AUDIT-2026-11-07.md D34, D35. Same unlanded Dev Assist 0.7.15 as the QAWalks-Checklist regeneration (3b2f801).

## What changed (`XayaUI_DevAssist/QAWalks.lua`)
- D35: the walkthroughs' test group is tagged `qaTest = true` when they make it; `TestGroup()` (reuse and Cleanup) matches the tag,
  not only the name. Before: any group named "QA test group" was reused, and Cleanup deleted it with every rule in it (to the Recycle
  Bin). A test group left by an older Dev Assist (untagged) is no longer found by Cleanup: delete it by hand (it is only test data).
- D34: "reskin-switches" remembers All reskins' state at step 1 and gets a last step that puts it back; "shopping-list" remembers the
  Shopping List's enabled / panel at step 1 and gets a last step that puts them back. Before: the walkthrough left All reskins as
  its last step set it, and the Shopping List switched on for good. The framework has no hook for a walkthrough that is closed
  half-way, so a walkthrough quit before its last step still leaves the change (said in the step texts: "Last step: ... put back").

## Tests
- `tests/qa_walk_run.py`: D35 (2 checks) and D34 (2 checks). On 28380a9 they fail (the player's group is deleted; the switches stay as
  the walkthrough left them).

## QA
Covered by the existing B176 walkthrough steps (the new last steps show in the walkthroughs themselves).

Versions renumbered for the landing on main bfc79ef (2026-11-07, numbers from the lander): core 0.6.62, Options 0.6.65, QoL 0.7.41, Chat 0.6.32, Bonus 0.6.25, Dev Assist 0.7.15.
