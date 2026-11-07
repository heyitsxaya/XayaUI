# D8: Release Guard as a built-in entry under Rules > Raid Rules (core 0.6.62, Options 0.6.64, QoL 0.7.40, Dev Assist 0.7.13)

D8 session (session_014bN6tTZroPi49dAYwBbeGp), branch claude/d8-raid-rules-main from main 6b25c9b. Logged 2026-11-07 06:25 UTC.
Spec and her words: docs/plans/D8-RAID-RULES-SPEC-2026-11-07.md. Built without asking her the open proposals: her relayed words
(2026-11-07 ~06:00 UTC) "for the love of everything, ship everything I asked for today and stop asking me questions until everything
that is more than 6h old is completed and on main". The conservative readings taken are listed in the spec ("Conservative readings").
Her direct answer to this session a few minutes earlier ("Hold the rule load condition changes and pass all other things that don't
overlap with it that pass") is superseded by that later message (the coordinator's reading); this is said in the report to her.

## What changed
- core Conditions.lua: ns.LoadAllows(rec, ctx): a rule's Load answer (CheckContext memo + CheckTalents) for a non-rule feature. Plus the
  load condition "People in my group: at least N" (engine session 2's 0f3151b, renumbered; its own debug log 2026-11-07-0022).
- QoL ReleaseGuard.lua: c.load is a rule-style Load table (default: instance yes, type Raid, groupMin 20); the old string migrates once
  (raid -> default, group -> Raid + Dungeon any size, all -> nothing), old value in c.loadOld; LoadsHere = ns.LoadAllows(c) (read only
  when the death window shows; no new event, frame or hook). The settings page no longer registers on the QoL tab; its "Where" select is
  gone (the Load tab replaces it).
- Options.lua: BuildLoadArgs(rec, onChange) extracted from BuildRule (the same Load tab, unchanged for rules: BuildRule calls it);
  BuildReleaseGuardEntry (Settings tab with Enabled + the QoL page's rows; Load tab on c); ns.ReleaseGuardScope; the entry listed under
  Enabled > Loaded / Not Loaded or Disabled (counted like a rule) and in a fixed RAID RULES group in the Smart Categories tab; RowMenu:
  Release Guard / Enable / Disable only; FixSelection follows its row between lists; RAID RULES drawn as a root row.
- Dev Assist: QAWalks-raidrules.lua, walkthroughs "d8-raid-rules" (B230-B236) and "d8-people-in-group" (B237), prefill = true.

## V4 scope (git grep before changing)
- ReleaseGuard readers: XayaUI_QoL/ReleaseGuard.lua (all), tests/release_guard_run.py, tests/sidebar_switches_run.py (qol>releaseguard),
  InfoPaneData.lua (README entry; the 0.7.31 patch notes stay as history), docs/USER-GUIDE.md 12.12d, docs/README-INGAME.md, QA E1z82
  and B189 (history).
- Row handling keyed on rule%d / f%d (so an unknown key is ignored): Resolve (eye / headphone), RowMenu, StartDrag / drag.Arm,
  ns.MultiClick / RuleOfButton, ns.SidebarRename, DeleteRule / ExportRule / DuplicateRule / MultiDelete / AddMoveMenu (take rule
  records), ApplyTreeFilter. The entry is not in ns.rules, so the engine, export, profile export and Recycle Bin never see it.

## V2
No new game call. ns.LoadAllows reads ns.ReadContext (IsInInstance etc., documented as before); GetNumGroupMembers: see the 0022 entry
(not in the 12.1.5 reference: INFERENCE, fails safe to "does not load").

## V14
While Release Guard is off nothing of it is made or registered (unchanged); the Load answer is read only inside Cover (death window up)
and when the options window lists the entry. tests/raid_rules_run.py: off, building the whole options window makes no frame.

## Tests (V1)
- tests/raid_rules_run.py (new, 19 checks). Negative control: run against main 6b25c9b: 16 of 19 fail; the 3 that pass there are
  guards ("off: not under Enabled", "not a rule record", "off: no frame").
- tests/release_guard_run.py: Load now stubbed (LOADOK); "where" checks replaced by "Load tab says no / yes"; page has no "Where".
- tests/sidebar_switches_run.py: qol>releaseguard removed from the expected rows (113 checks pass).
- tests/load_group_size_run.py (6 checks).
