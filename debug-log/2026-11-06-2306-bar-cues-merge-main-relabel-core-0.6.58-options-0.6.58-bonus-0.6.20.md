# Bar cues: main 687b624 merged in; relabelled to core 0.6.58, Options 0.6.58, Bonus 0.6.20, Dev Assist 0.7.6, QA B200-B210 / F21
Logged 2026-11-06 23:06 UTC. Session 014bN6tX7AoZQrGX246YSXjC, branch `claude/dreamy-edison-pvb3i1` (PR #417). Nothing new for the
player; this is the landing preparation S1 asked for (session 014bN6tWZxqCW85vMEyHdfnt: "When #417 is ready, merge main and relabel
above those numbers and QA IDs").

## Merge
- main 687b624 (core 0.6.57, Options 0.6.57, QoL 0.7.34, Chat 0.6.25, Bonus 0.6.19, Reskin 0.6.6, Dev Assist 0.7.5; root docs moved
  to docs/). Conflicts: the four .toc files and MANIFEST.md5 (versions), docs/QA-CHECKLIST.md (both sides added steps), and
  XayaUI_Options/Options.lua: main moved the picker's cue set-up into `ns.NewTypedCue` / `ns.CUE_FOR_TYPE`; main's side taken and
  `bar = "bar"` added to `ns.CUE_FOR_TYPE` (New Rule > Progress Bar still makes a Bar-cue rule).
- My root-doc edits (QA-CHECKLIST, USER-GUIDE, ROADMAP, SESSION-START-SUMMARY) followed the move to docs/ (git rename detection).

## Relabel (numbers checked against main and every branch, 23:0x UTC)
- core 0.6.53 -> 0.6.58, Options 0.6.51 -> 0.6.58 (main 0.6.57 / 0.6.57; no branch above), Bonus 0.6.18 -> 0.6.20 (main took 0.6.19),
  Dev Assist 0.7.5 -> 0.7.6 (its generated QAWalks-Checklist.lua changed).
- QA: B160-B167 -> B200-B207, B177-B179 -> B208-B210, F19 -> F21 (main has B160 and B177-B179 for other work, F19 / F20; the highest B
  on any branch is B199). Cross references inside the steps follow.
- REQUEST-LOG: this session's section header A8 -> A11 (main has "A8. Session S8-UI"; its rows are UI-n, mine stay S8-n).
- V20: `python3 tools/qa_walks_from_checklist.py` rebuilt XayaUI_DevAssist/QAWalks-Checklist.lua: B200-B210 and F21 are in the
  /xui dev qa walkthroughs.

## Tests
- tests/bar_cue_run.py: main's tests/aura_display_run.py gained a second placeholder (ENGINE_SUBS_SRC, the /xuiengine subcommands
  from Dev Assist) in the stand-in Part B borrows; Part B now fills it with an empty chunk. 98 checks, 0 failed (before that fix the
  run stopped at Part B's load: 87 checks, 1 failed).
- Full suite on the merge commit: see the commit message / report.
