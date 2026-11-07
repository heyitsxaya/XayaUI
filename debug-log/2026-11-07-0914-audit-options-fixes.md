# Function audit: settings-window fixes D20-D26, D41-D47 and FA-11 (Recycle Bin for the red X)
Logged 2026-11-07 09:14 UTC. Session 014bN6tSfFULX4BSXzmZ1yCx, branch `claude/function-audit-opt` (from `claude/function-audit-land` ae88fc3).
Audit table: docs/process/FUNCTION-AUDIT-2026-11-07.md. Not run in the game. No `## Version` bumped and MANIFEST not rebuilt (the parent
session does both, and adds XayaUI_DevAssist/QAWalks-audit-options.lua to the toc and regenerates QAWalks-Checklist.lua).

Test: `tests/audit_options_run.py` (new, real addons in the stand-in game, settings window open for the last three parts): 69 checks.
Negative control: the same test run on a copy of ae88fc3 (git archive HEAD + the new test): every row below fails there except where noted.
Walkthrough test: `tests/qa_walks_audit_options_run.py` (new) runs every step of the new walkthroughs.

## Rows
- **D20** Load > Instance Options > Instance Type. Cause: TriGroup's getter returned true for an unset box while no box was selected;
  AceGUI's tri-state goes true -> nil -> false, so click 1 stored NOT and "selected" was never stored. Change: an unset box reads false
  (Options.lua TriGroup; "none ticked = any" is shown by the All box). Scope: `git grep TriGroup(` = one caller (instanceTypes).
  Fail-before: 4 checks (unset draws ticked; clicks gave not / nil / not).
- **D21** cue Sound / Speech setters. Cause: no ns.MarkDirty, so no EDITED event and no undo step. Change: MarkDirty in Play a sound,
  Sound (both branches), Repeat, Sound channel, Speech text / voice / speed / volume / repeat. The channel *volume* slider is the game's
  shared channel volume (not rule data) and is left as it was. Scope: Options.lua `sound` and `speechBody` (used by rules and, flattened,
  by Sound / Speech cues in OutcomesEditor.lua EmbedCue). Test: set each, wait, ns.UndoKey: the value goes back. Fail-before: 8 checks.
- **D22** Drafts > Restore with drafts off. Change: the Restore button asks first while drafts are off and the rule exists
  (`confirm` returning the text, AceConfig's own StaticPopup: "Drafts are off, so this replaces the rule '...' with the draft right away
  and keeps it. Replace it?"); its hover and the chat line say it is kept at once (drafts on: unchanged). Fail-before: 3 checks.
- **D23** opening a Load tab = "unsaved changes". Cause: getters create empty classes / specs / roles / heroes / instanceTypes tables; and
  a `load = {}` that gains only empty tables stopped being skipped. Change (the smaller one, Drafts.lua only): the compare treats a table
  that holds nothing but empty tables as missing (Ser; used by the drafts signature and the undo signature). Getters left as they are.
  Fail-before: 1 check.
- **D24** Info > Group. Change: MarkDirty + RefreshAllVisuals, as right-click > Move To. Fail-before: 1 check (EDITED 0, refreshes 0).
- **D25** Buff / Aura Remove. Change: also clears buffTimeOp / buffTimeSec. Fail-before: 2 checks.
- **D26 / D44** edit lock bypasses. Changes: ns.UndoKey and ns.DraftRestore refuse on a locked rule (chat line); ns.LockHeaderArg (new,
  Options.lua) wraps a header's arg.xuiActions (every icon drawn grayed, false) and arg.xuiEdit (set refused; Skin.lua drops focus and
  dims the box): applied by ns.LockArgs to every leaf with an arg, and by OutcomesEditor Header for cues / conditions; the built-in and
  extra trigger Remove functions and RemoveOutcome also return when locked; Delete key refuses a locked rule or group; multi-select
  Delete / Move skip locked rules with a chat count; double-click rename refuses a locked group (rules already refused).
  Scope: `git grep xuiActions` (TriggersEditor DecorateBuiltinTriggers + extra rows, OutcomesEditor Header, Skin.lua PaintActions),
  `git grep xuiEdit` (same, Skin.lua PaintNameEdit), DeleteKey, MultiDelete, MultiMove, SidebarRename. Fail-before: 3 checks (Restore,
  Ctrl+Z, header icons 14 of 20 active, name box) plus the window part (Delete key, multi-select, group rename).
- **D41** row lock on a cue-based rule. Changes: the row's lock targets also hold the rule itself (DecorateButton), and ns.IsEditLocked of
  a cue or condition follows its rule's lock. Test clicks the drawn lock icon in the sidebar.
- **D42** group Enabled / Enable all / Enable-Disable All Rules Inside / Delete Group count. Change: FolderTopRules (skips parentUid rows)
  in those five places; FolderRules itself (sidebar previews, paste, search, the "(N)" count in the group name) unchanged.
  Fail-before: 2 checks.
- **D43** group Display color Cancel. Cause confirmed in the bundled AceGUI ColorPicker: Cancel calls the callback with the swatch's start
  value. Change (DisplayTab.lua, every color control of the group Display tab): the first `set` while a picker is open keeps a copy of
  every display's visual table (and the group's forced bar colors); a `set` equal to the start color puts each copy back; the copy is
  dropped once the picker is closed. Fail-before: 1 check (A 1,0,0 B 1,0,0).
- **D45** number inputs. Change: OutcomesEditor compare value and TriggersEditor spell / talent / item ID boxes: text that is not a number
  keeps the old value (chat line); an empty box is 0. Fail-before: compare value fails; **the spell-ID check passed on the old code too**
  (not a valid negative control; cause not found in the time available: flagged).
- **D46** sidebar rename to an empty name keeps the old name. Fail-before: 1 check.
- **D47** save-bar buttons report an error through geterrorhandler (as the file does elsewhere). Test: DraftSave raising an error.
- **FA-11** (Xaya: "Recycle Bin, no prompt (Recommended)"). Core RecycleBin.lua: ns.RecycleChild (cue / condition: its place among its
  siblings, and for a cue the conditions that played it, by uid, then unlinked as ns.DeleteCue does) and ns.RecycleTrigger (built-in
  Cooldown / Buff fields, or a copy of an extra trigger row with its place in the trigger order, the condition rows that read it and the
  "activated by" choice). RecycleRestore puts them back (new uid / cue key on a clash; refuses while the owning rule is not live, the item
  stays). The red X (and the skin-off Remove) call them; existing kinds unchanged (tests/recycle_bin_run.py 59 checks pass). The bin page
  names them "Cue / Condition / Trigger of the rule '...'". Fail-before: bin count 0 and the restore part errors.

## Flagged readings (choices made without Xaya)
1. D22: only asks when drafts are off AND the rule still exists (restoring a deleted rule replaces nothing).
2. D23: fixed in the compare, not in the getters (the smaller change).
3. D26 / D44: multi-select Delete / Move act on the unlocked rules and skip the locked ones (rather than refusing the whole selection).
   A locked group's own name cannot be changed by double-click either (its Config page was already locked).
4. D41: locking a rule now also locks its cues and conditions (IsEditLocked follows the parent).
5. D42: the "(N)" rule count in a group's name still counts cue rows (not in the row; left unchanged).
6. D45: an empty box still clears the ID / value (0); the built-in trigger's Spell / Aura ID boxes in Options.lua have the same
   `tonumber(v) or 0` and were left (not in the row).
7. FA-11: the built-in Cooldown / Buff trigger's red X also goes to the bin; Restore refuses if the rule has that trigger again.

## Other tests run
lua_pitfalls (FAILS 0), drafts_run (24/0), recycle_bin_run (59/0), flex_dropdown_run, import_run (22/0), trigger_labels_run,
trigger_parity_run (56/0), delete_keeps_rule_run (43/0), sidebar_switches_run (see the commit message for its result).
tests/qa_walk_run.py is expected to fail until the parent regenerates QAWalks-Checklist.lua for B265-B278.
