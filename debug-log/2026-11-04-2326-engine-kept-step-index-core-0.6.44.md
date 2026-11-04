# #309: the engine's rule and group indexes are kept between steps (core 0.6.44)
Logged 2026-11-04 23:26 UTC. Session branch `claude/fervent-cerf-hldtwn` (engine session). Part of Xaya's performance push (her words,
relayed by the Dev Assist session: "not just for opening the UI but also for while playing the game. this much memory demand makes
the addon worthless").

## Where things stood
Her rules, engine bench (run by the Dev Assist session on her file; the file stays in that session): garbage per step 52.49 KB (main
613dde6) -> 40.04 KB (core 0.6.40) -> 36.49 KB (core 0.6.41-0.6.43, the Options session's load-check fix). The 0.6.40 debug log named
the per-step rule index as the next cut and held it back: caching it on an edit signal risked a stale index (a cue following the
wrong parent) because about 20 code paths write `uid`, `parentUid` or the rule list (Cues, Outcomes, RecycleBin, Share, Drafts,
Options).

## Change (results unchanged)
- `XayaUI/Core.lua`: the rule index (parents by uid, children by parentUid, each parent's cue / condition lists) and the group index
  (group by id) are kept between steps. At the first lookup of each step the kept index is reused only if the list it was built from
  still holds the same entries in the same order with the same `uid`, `parentUid` and cue flag (rules) or `id` (groups); the check is a
  plain comparison per entry (no allocation, no edit signal needed). Any difference rebuilds the index exactly as before.
- The step table itself is emptied and reused (no new table per step).
- Lists handed out during a step stay read-only (as before: "callers read them, never change them").

## Verification
- `tests/engine_garbage_run.py`, 9 new checks:
  - step index alone (200 rules, 40 parents with 4 children each, 20 groups; every child asks for its parent, every parent for its
    cues and conditions, every group looked up): 24.43 KB per step on main fb23e4b, 0.00 KB now. The check (< 1 KB) fails on the old
    code.
  - edits that never announce themselves (no `ns.MarkDirty`): a cue moved to another parent, a condition turned into a cue, a rule
    added, a rule removed, rules reordered with a parent's uid changed together with its child, a group's id changed: the next step
    answers like a fresh build (pass on old and new: they guard the kept index).
- Bench, made-up file (86 rules incl. 6 child rules), 300 steps: 54.35 -> 48.00 KB per step on main fb23e4b; decisions identical
  (`SIGOUT` compared with `cmp`).
- Tests touching the step index pass (aura_display, charges_combat, count_gcd, debug_record, engine_garbage, engine_text,
  flat_buttons, frame_anchor, import, layout_parity, load_alloc, load_class, load_ids, mover_view, precheck, timing, tracked_buff);
  `lua_pitfalls_run` FAILS: 0.
- On her rules: to be measured by the Dev Assist session (her file is only there).

## Still open (#309)
Result tables and diagnostic text built per read every step (`ReadCooldown`, aura reads); waiting for the allocation profile on her
rules (asked of the Dev Assist session) before the riskier cuts. Event-to-rule routing waits on a perf capture (#307, QA B56).
Nothing was run in game; QA B114 covers the in-game memory check.
