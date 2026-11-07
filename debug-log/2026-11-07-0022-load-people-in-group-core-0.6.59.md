# Load condition "People in my group: at least N" (core 0.6.59, Options 0.6.60; D8 part 2)

Engine session 2. Her answers (QUESTIONS-engine-session.md "Round 7 answers"): the DO NOT RELEASE load "in instance - raid party size => 20";
"People in my group". Versions above the pending combined bundle (core 0.6.58 / Options 0.6.59 there).
- Conditions.lua ReadContext: ctx.groupSize = max(1, GetNumGroupMembers()); in the context signature (memo). CheckContextRaw: load.groupMin
  (a number > 1) checks groupSize >= groupMin; unset / 0 / 1 = no bearing (#18). GROUP_ROSTER_UPDATE already steps the engine.
- V2: GetNumGroupMembers is NOT in the repository's 12.1.5 reference (docs/reference/api: no entry). INFERENCE (Blizzard's own UI use,
  warcraft.wiki.gg): members including you, 0 when solo. A non-number / secret / error -> unknown, the rule does not load (fail safe).
- Options.lua rule Load tab: "People in my group: at least (0 = any)" slider 0-40 (order 62, after Instance Type); locked with the other
  rows by a group's Never / Always.
- Test: tests/load_group_size_run.py (6 checks; the old code has no such condition). QA B213.
- The rest of D8 (Release Guard as a built-in entry in a "Raid Rules" sidebar group) moves to a new dedicated session (her answer "Fresh
  session (Recommended)"); spec: docs/plans/D8-RAID-RULES-SPEC-2026-11-07.md.
