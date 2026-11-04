# Defect retrospective, verification process, precheck tool and project skill (no addon code changed)
Logged 2026-11-04 06:48 UTC. Branch `claude/eloquent-rubin-n9zb99`.

## Request
Xaya, 2026-11-04:
- "review everything out of all the bugs filed and work backwards from their solves -- why did they not get caught and solved before
  being reported, and how do you prevent the same mistakes moving forward?"
- "identify gaps in logic or lacks of tethering talents and abilities together. identify missed opportunities at capturing aura
  data"
- "build a workflow process out of what you can identify as having missed"
- She called it "one of the highest priority tasks to complete within the project".

## What was done
- **`docs/process/RETROSPECTIVE.md`:**
  - every defect from #51-#365 plus this session's (56 classified, and process slips S3-S11), each with its cause, why it was missed
    and the rule that now catches it;
  - the code gap review (22 rows), each re-checked against the code on `main`. Gap 1 was partly wrong as reported and is corrected
    from Blizzard's source;
  - missed aura data sources.
  - Four Claude reviewers wrote the shares; the main session merged them and re-checked the surprising claims (#333 and #319
    confirmed; gap findings 1-22).
- **`docs/process/VERIFICATION.md`:** rules V1-V13, ordered by when they apply (before code, while testing, before committing, before
  "done").
- **`tools/precheck.py`:**
  - debug-log and summary times not in the future (and valid);
  - MANIFEST.md5 matches the tracked files;
  - no stray files in addon folders or at the root;
  - version bumped when an addon's code changed (`--base origin/main` before pushing to main);
  - unique QA step IDs;
  - each test prints a pass marker `run_all.py` accepts;
  - media lists naming files the repository lacks (warning, #333 / #290).
- **`tests/precheck_run.py`** (25 checks): every precheck check catches the slip it was written for and passes a clean case.
- **`.claude/skills/xayaui-change/SKILL.md`:** the process in short, plus the standing rules, so a new session applies it.
- **`SESSION-START-SUMMARY.md`:** current versions, active items (code-gap fix order, procs index, old-branch ports), pending actions
  (branch deletions with Xaya's rule, `stable` protection, #88 decisions), process and test status.
- **Renamed** `debug-log/2026-11-02-2400-...` to `2026-11-03-0000-...`: the new precheck rejected 24:00. Nothing referred to the old
  name.

## Checks
- `python3 tests/precheck_run.py`: 25 checks, 0 failed.
- `python3 tools/precheck.py`: FAILS: 0. Two warnings are the open media-list defects (#333: 149 pictures; #290: 229 sounds).

Files: docs/process/RETROSPECTIVE.md, docs/process/VERIFICATION.md, tools/precheck.py, tests/precheck_run.py,
.claude/skills/xayaui-change/SKILL.md, SESSION-START-SUMMARY.md, debug-log/2026-11-03-0000-... (renamed), this entry, MANIFEST.md5.
