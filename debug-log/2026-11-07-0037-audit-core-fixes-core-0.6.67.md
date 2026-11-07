# Function audit, core fixes: backup replace keeps the built-in categories, arrangement no longer creeps, Snap to a missing frame keeps the position, talent scan guard and kept scan, minimap texts (XayaUI 0.6.67)
Logged 2026-11-07 00:37 UTC. Session 014bN6tSfFULX4BSXzmZ1yCx (function audit, UI-60), branch `claude/function-audit`, on main 28380a9. Nothing here has run in the game.
Rows: docs/process/FUNCTION-AUDIT-2026-11-07.md D9, D10, D11, D18, D19, D40. Her answer for D11: REQUEST-LOG A11 FA-12 ("1, XayaUI Settings").

## What changed
- `XayaUI/Share.lua` (D40): `Share_ApplyRules` in replace mode keeps a top-level folder's built-in category flag (`default`), once per
  key and only for a key `ns.DefaultFolderInfo` knows; "add" imports still never copy it. Before: Load (replace) of a backup turned
  Display Cues / Sound Cues / ... into plain folders and every rule's kind became hybrid (`EnsureDefaultFolders` does not run again
  once `ui.defaultFoldersV` is 3).
- `XayaUI/Visual.lua` (D18): `ArrangeList` keeps the centres exact (`ArrR` no longer rounds); X / Y are rounded once in
  `SetVisualCenterOffset`. Before: a half-pixel centre (odd size with a corner anchor, an even display in an odd box, ...) was
  rounded up twice, so X and Y grew by 1 on every apply, and the arrangement is applied on every refresh (Visual.lua member refresh).
- `XayaUI/Visual.lua` (D19): `ns.SnapToTarget` checks that the frame exists before saving anything; a missing frame leaves the
  snap and X / Y as they were (before: X / Y were zeroed and the snap saved, while chat said the aura "keeps its own position").
- `XayaUI/TalentDump.lua` (D9): the "close the talent window first" guard checks PlayerSpellsFrame (what Dev Assist checks,
  DevAssist.lua 266) as well as ClassTalentFrame. That ClassTalentFrame no longer exists in this client is an INFERENCE.
- `XayaUI/TalentDump.lua` (D10): a scan where no class could be read keeps the previous `XayaUITalentDB` and says so.
- `XayaUI/MinimapButton.lua` (D11, FA-12): the list row is "XayaUI Settings", its tooltip "Open or close the XayaUI settings window";
  the button's tooltip "Right-click: open or close the XayaUI settings". USER-GUIDE minimap paragraph.

## Scope (V4)
- `git grep "\.default"`: Core.lua (EnsureDefaultFolders, RuleKind via top.default, hybrid moves), Share.lua (this import). Replace
  is reached from Backups > Load (replace) and Import window replace (Options.lua -> ns.Share_ApplyRules(snap, "replace")).
- `ArrangeList` callers: ApplyGroupArrangement (every member refresh) and the one-shot Align / Distribute / Space buttons
  (Options / DisplayTab) - both now round once.
- `SnapToTarget` callers: the right-click Snap Target menu only (Visual.lua 1783, 1797); "custom" snaps are set by the frame picker.
- `XayaUITalentDB` readers: ns.TalentDB (rule creation, Options); none expects an empty table.
- "settings" launcher label: tests/modules_run.py uses its own stub row (not this one).

## Tests
- `tests/audit_core_run.py` (new, stand-in game): 14 checks; 8 fail on 28380a9 (D18 x2, D19 x2, D9, D10 x2, D11), all pass now.
  (The 40x40 CENTER case and the "whole numbers" / "Align left lines up" checks pass on both: kept as guards.)
- `tests/import_run.py`: D40 checks; 2 fail on 28380a9, 22 pass now.
- `tests/group_arrange_run.py` still passes (15).

## QA
B223, B224, B225.

## Added later the same day (still core 0.6.67, unlanded): D54, D55
- `XayaUI/Engine.lua` (D54): On Initialization runs when the load conditions AND the talent requirement hold (`info.talentOK == true`,
  as `ns.IsLoaded`); it is armed again when either fails, and for every rule on the player's own PLAYER_SPECIALIZATION_CHANGED
  (the event carries unitTarget, events.md 1215; registered for every unit, so only "player" counts). USER-GUIDE / Actions.lua
  say it runs "after login or /reload, a spec change, or when its load conditions become true".
- `XayaUI/RecycleBin.lua` (D55): deleting a group on its own records every rule it moves up (a rule with no uid yet gets one,
  ns.NewUID), so Restore moves them all back. Before: only rules that already had a uid (from a cue or condition) went back.
- Tests: `tests/audit_core_run.py` D54 (4 checks) and D55 (2): 3 fail on 28380a9. `tests/recycle_bin_run.py` passes (59).
- QA B226.
- `XayaUI/Visual.lua` (D27): the mover view's group name tab, on mouse down, selects the group for arrow-key nudges (QA B178) and,
  for a group locked for now, starts no drag (comment Visual.lua: "its tag does not drag"); the click still opens its settings.
  Same two checks as the sidebar handle. Tests: `tests/audit_core_run.py` D27 (2 of 3 fail on 28380a9); mover_session (29) and
  mover_view (22) pass. QA B227.

Versions renumbered for the landing on main bf2ce6a (2026-11-07, numbers claimed for the lander to relabel): core 0.6.67, Options 0.6.69, QoL 0.7.42, Chat 0.6.33, Bonus 0.6.27, Dev Assist 0.7.19.
