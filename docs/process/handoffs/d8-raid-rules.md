# Handoff: D8 Raid Rules (session_014bN6tTZroPi49dAYwBbeGp), 2026-11-07 ~09:00 UTC

Cold start: read docs/process/VERIFICATION.md, the xayaui-change skill, docs/plans/D8-RAID-RULES-SPEC-2026-11-07.md (spec, her words,
"Conservative readings"), docs/process/REQUEST-LOG-session-014bN6tTZroPi49dAYwBbeGp.md (F1-F7 verbatim) and the engine session's log
REQUEST-LOG-session-014bN6tV8wAAEXAShpTKqUfz.md rows E30, E58, E76-E81. Call the account holder Xaya (she/her).

## State in one line
D8 is fully built and tested on **claude/d8-raid-rules-ready @ 91e8701** (draft PR #446, [HELD]); it is all load-condition work, so it is
**held under O-109** and must not reach main until Xaya answers D8-Q1 yes. Nothing of this session is on main except docs already landed
by others (none of mine). There is no non-load-condition code to land.

## Xaya's requests in this session (and the D8 requests it inherited), verbatim, with status
| # | Her words | Status |
|---|---|---|
| E76 | load "in instance - raid party size => 20" (= people in my group); "If it's not enabled it does not exist"; "It has to be enabled (it's not exactly a rule) and then the load conditions are applied after enabling / disabling."; "It belongs in "Raid Tools" under rules for now" | held O-109, claude/d8-raid-rules-ready@91e8701 |
| E77 | "A group in the sidebar" | held O-109, same |
| E78 | "Sorry, “Raid Rules”" | held O-109, same (group named RAID RULES) |
| E80 | "Yes, built-in entry" | held O-109, same |
| E81 | "Fresh session (Recommended)" | done (this session) |
| E58 | D8: "Rule drives the cover" | held O-109, same |
| F1 | (declined the question prompt with the four D8 proposals) | proposals sent to the QA flow as D8-Q2..Q7 |
| F2 | "Wait for refactor and code qa" | superseded by F6/F7 |
| F3 | (relayed) "As a standing rule, make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing" | applied on the held branch (walkthroughs d8-raid-rules, d8-people-in-group; ui-release-guard updated) |
| F4 | (relayed) "merge whatever's missing from main that still lands cleanly and has qa test scripting for in game confirmation prompting available." | nothing of mine lands cleanly without the held part |
| F5 | "Hold the rule load condition changes and pass all other things that don't overlap with it that pass" | in force (O-109) |
| F6 | (relayed) "for the love of everything, ship everything I asked for today and stop asking me questions until everything that is more than 6h old is completed and on main" | held per F5 (hub correction 06:16 UTC); no questions asked since |
| F7 | (relayed, O-150) "I have to go to sleep. I want everything I've requested over the last 16h — and I mean EVERYTHING — implemented and pushed to main when I wake up. ..." | held per F5/O-109; questions in the flow |

## What the held branch changes (for D8-Q1)
- core 0.6.70 Conditions.lua: load condition "People in my group: at least N" (ctx.groupSize from GetNumGroupMembers, INFERENCE, unknown =
  not loaded); ns.LoadAllows(rec, ctx) for non-rule features.
- Options 0.6.71: rule Load tab extracted into BuildLoadArgs (rules unchanged); RAID RULES group (Smart Categories) with Release Guard
  (Settings + Load tabs), listed under Enabled (Loaded / Not Loaded) or Disabled; not a rule record; menu Enable / Disable only; service
  "raidRules" (Scope).
- QoL 0.7.44 ReleaseGuard.lua: c.load is a rule Load table (default instance yes, Raid, groupMin 20); old Where migrates once
  (raid / all -> default, group -> Raid + Dungeon), old value in c.loadOld; page off the QoL tab; main's UI-57 (strata, /xui releaseguard)
  and UI-58 (no Everywhere) kept; one "releaseGuard" service (Cfg, State, Box, Death, Page, Apply, LoadsHere, LoadText; Loads removed).
- Dev Assist 0.7.31: QAWalks-raidrules.lua (d8-raid-rules B240-B246, d8-people-in-group B247, prefill); QAWalks-display.lua
  ui-release-guard step 1 reads the Load table.
- Tests: raid_rules (new, 19; 16 fail on main 6b25c9b), release_guard 19, qa_walks_display 23, load_group_size 6, disabled_tree 32,
  sidebar_switches. Static gate and precheck: 0 fails. **Full suite on 91e8701: not yet run** (the earlier full run on the old base,
  9fad28e, failed 3 groups, all fixed in dc7628f; next step 1 below).

## Branches and PRs
- **claude/d8-raid-rules-ready @ 91e8701**, PR #446: the held load-condition branch (base main 7b830cf). Land only on her yes.
- claude/d8-raid-rules-main @ dc7628f, PR #440: superseded (old base 6b25c9b). Stale.
- claude/d8-raid-rules @ 4811da5, PR #435: superseded. Stale.
- claude/d8-docs-to-main @ 8fc0538: contained in the ready branch. Stale.
- claude/fervent-cerf-hldtwn @ 0f3151b: engine session 2's base, contained. Stale.

## Versions claimed
core 0.6.70, Options 0.6.71, QoL 0.7.44, Dev Assist 0.7.31, QA B240-B247 (per the hub registry of 08:35 UTC; the lander relabels clashes).

## Questions sent to the QA flow (session_014bN6tUZLKHa2NXorHRJghL)
D8-Q1 ship the held load-condition changes?; D8-Q2 migration of the old Where (updated: Everywhere -> default, UI-58); D8-Q3 virtual
row vs record; D8-Q4 group holds Release Guard only; D8-Q5 placement (Smart Categories + Enabled / Disabled lists); D8-Q6 QoL row
removed; D8-Q7 full Load tab incl. talents, menu Enable / Disable only; D8-Q8 the Load tab can be emptied (= everywhere) vs UI-58.

## Next steps (successor)
1. Run the full suite on claude/d8-raid-rules-ready (`XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`; build the
   index first with `python3 tests/harness/api_index_from_docs.py` if missing). Fix anything red (no skipped tests).
2. Send the hash + suite result + versions to the lander as "held, ready on her yes" (not landable); a CLEAN-8 note to the perf session.
3. When perf's load-first chain (claude/perf-load-first; it changes Conditions.lua) lands, rebase onto main and re-run the D8 tests.
4. On D8-Q1 yes: apply her other D8-Q answers, re-run, hand to the lander; after landing send the V18 what's-new to
   session_014bN6tU26cuzQ9LarKYhZQx. On "no / keep holding": leave the branch as is.
