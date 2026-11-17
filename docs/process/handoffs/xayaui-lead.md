# Handoff: XayaUI lead (bundle 1, rounds 1-10; round 11 planned; docs off main + history erase planned)
- Session: session_014bN6tVBGo8BHkHu65TAcjD · Project: heyitsxaya/XayaUI (PUBLIC repo) · Branch: claude/dazzling-brown-x9fqrm @ see the commit that adds this file (pushed: yes) · Open PRs: none for this branch (PR #523 merged 2026-11-09; no new PR on purpose, see §8 "PR refs") · Released/live: main fda1e293 (XayaUI 0.6.85, Options 0.6.108, Rules 0.7.0, Bonus / StatCalculator 0.6.46) is what players have; nothing from bundle 1 is on main.
- Child sessions: session_014bN6tSvaDBEe8dCKeMYcgo (Rule Builder, PR #525, design only until bundle 1 lands), session_014bN6tUmdW8ddPT74JogMYj (Stat Calculator review on QA branch). The hub is messaging both directly.
- Written 2026-11-17 for the hub merge (hub session_014bN6tUNTxxZDiYNEg9dw75; Xaya's words to the hub, 2026-11-17 ~20:09 UTC, verified in the hub transcript: "Communicate with all other chats, have every single chat pass ALL data to one hub, archive old chats, and redistribute all content into relevant chat sessions that contain all data necessary from the big chat session merge. Answer whatever questions you can that you have post-merge before asking again").

## 1. Purpose and scope
- Rebuild the XayaUI addon suite to Xaya's standards (docs/process/VERIFICATION.md V25-V34; her six code criteria; her SD-132 global rules, see §3) as one bundle ("bundle 1") on this branch, then land it on main by fast-forward only.
- Bundle 1 = rounds 1-10 (built) + round 11 (planned, §5). Landing conditions (all must hold): round 10 AND round 11 pass; all V27 and V33 gates; full suite on the exact landing commit with no hidden SKIPs; versions above main's; MANIFEST.md5 removed; no blockers in the final review; SD-120 hidden-data fight in the tests; SD-133 wireframes; SD-134 three-question review; SD-135 file map + call index; SD-138 landing check.
- After landing: give Xaya in-game steps in plain words; message the Rule Builder session that bundle 1 is on main so it can rebase RB-28.
- Also owned here: the request log (docs/process/REQUEST-LOG.md, rows through SD-141), the docs-off-main + full history erase (SD-140), the main/QA backup (SD-141, done).

## 2. Current state
Done on the branch (97 commits ahead of main; versions XayaUI 0.6.87, Options 0.6.110, Rules 0.7.2, Bonus / StatCalculator 0.6.47, new XayaUI_Debug 0.7.1):
- Rounds 1-9: engine rebuild (10-a-second routed aura checks, game-driven timing, route + narrow), XayaUI_Debug load-on-demand debug tools (off by default), V34 moves (rule editor into XayaUI_Options/RuleEditor, the mover), retired-core removal, display fx scheduler, docs. Each round: tests fail-before / pass-after, mutants, gates, harness, full suite on a snapshot.
- Round 10 (workflow run wf_87d42581-2e8): sound redesign (AuraSound), gate changes (Bonus folded into variants, per-event caps 600), Stat Calculator load-at-first-open, Calculator in XayaUI_Bonus, 29 closure-per-timer sites, docs. STATUS AT WRITING: final review running. RESULT: see §5 "Round 10 result" (filled in before push).
- Test-suite work 2026-11-16/17 (reports in docs/plans/): TEST-FIDELITY-2026-11-16.md, HIDDEN-DATA-FIGHT-SPEC-2026-11-17.md, TEST-AUDIT-2026-11-17.md, TEST-EFFICACY-REVIEW-2026-11-17.md.
- Her real SavedVariables run (SD-119): main fda1e293 fails 24 (Bonus words + an editor artifact); bundle 1 at 09250182 fails 10, all the editor artifact (harness calls get() on hidden options; AceConfigDialog does not). Her files are NOT in the repo (public) and were only in this session's container: a successor needs her to upload XayaUI.lua and XayaUI_Rules.lua (SavedVariables) again.
- SD-141 DONE: main fda1e293 and qa-installer-branch 236262bc backed up to her Google Drive folder "XayaUI GitHub backup 2026-11-17 (main + QA)" (top of My Drive): a files zip + full-history git bundle per branch, cut into 17 pieces of 3,000,000 bytes (connector limit), with "README - how to restore.txt" (join steps, restore commands, SHA-256 of every piece and whole file). Pieces rejoined byte-identical before upload; Drive sizes match.
Verified in game: NOTHING from bundle 1 (it is not on main; in-game steps are written at landing).
Not verified: anything depending on hidden (secret) aura/cooldown data in keys/raids (the stand-in never hides data: the reason for SD-120); CPU under real hidden data (measured stand-in about 2.3x under-read).

## 3. Xaya's decisions (dated; verbatim; recorded in docs/process/REQUEST-LOG.md unless noted)
All of SD-119..SD-141 (2026-11-16/17) are verbatim in REQUEST-LOG.md. The ones a successor must act on:
- SD-120 (her "yes"): the hidden-data fight goes into the tests before landing (stand-in and gates hide aura/cooldown data as keys, raids and boss fights do, incl. restricted out of combat; shared secret stand-ins throw the game's errors; CPU budget judged on that fight; ad60a051 re-recorded in it).
- SD-121 "sure, prompt me before I go into an instance if this is the one I want to log for the test each time until it's done"; SD-122 "After loading, before pull (Recommended)"; SD-123 "Create a separate tick element inside XayaUI debug and by default it should be off except for this one round"; SD-124 "Set number of runs (Recommended)" (3 Mythic+ keys + 2 raid bosses, then says once in chat to send the file); SD-125 "No, logger ships with it (Recommended)".
- SD-126 "Key only, raids in smaller tests (Recommended)"; SD-127 "Yes, fix it first (Recommended)" (every UNIT_AURA payload shape A/B/C failure blocks landing; fix F1 Engine RouteAura first); SD-128 "Logger records them (Recommended)".
- SD-129 "Yes, in round 11 (Recommended)" (test hygiene: empty passes fail; skin_button / aura_sources exit non-zero; fold memory_report).
- SD-130/131 standing rules (their method replaced by SD-138; intent stands).
- SD-132 her global rules (copy was docs/process/XAYA-STANDING-RULES.md, deleted per SD-137; distributed to her sessions per SD-136, 13 of 14 delivered, "Personal style curation application" inactive at send time). CODE and CODE: XUI parts go into VERIFICATION.md at round 11 start; a short CLAUDE.md on main.
- SD-133 "Yes, before landing (Recommended)" (wireframes, comment-able pages, for every bundle 1 new/changed screen); SD-134 "Yes, review all of bundle 1 (Recommended)" (three XUI completion questions); SD-135 "Yes, in round 11 (Recommended)" (file map + call index + a test that fails on unlisted additions).
- SD-137 "Keep only the coding rules (Recommended)".
- SD-138 "Amended version (Recommended)" = STANDING test rule (wording in TEST-EFFICACY-REVIEW section 6; becomes V35).
- SD-139 (2026-11-17) "Prints should be sent to chat but also sent directly to an error tracking file"; answers "Errors and warnings only (Recommended)", "Always save errors (Recommended)", "Yes, same file (Recommended)": every error/warning chat print also goes to CueRulesDB.errorLog (cap 50, code + count) even with Advanced Debugging off; tests read the same record and fail on unexpected entries (= SD-138 M1). Round 11.
- SD-140 (2026-11-17, screenshot of docs/process on main) "Docs like this should not be on main."; answers "A private repo (Recommended)", "All but player and build docs (Recommended)", "Now, as its own change", then (after being told the scope) "Full erase everywhere", and "Short CLAUDE.md on main (Recommended)". She asked "Most branches will be deleted, no?" (answered: deleting branches does not remove the 119 pull request records or old commits).
- SD-141 "Make a backup of qa and main and put it on Google Drive"; "Upload from your computer" (not possible: her computer offers no folder to cloud sessions) then "Split into pieces (Recommended)". Done.
- Standing constraints (older, still in force): reference addons are for sanity checks only, never copy code/data/assets/text; never write in the Drive "Reference Addons (REFERENCE AND READ ONLY)" folder; never force-push main or qa-installer-branch (SD-140 makes a one-time exception for the history erase only); every comment of hers goes into the request log, nothing dropped; prescriptive means exact; no guessing without a confirmed proposal (question tool); SD-104 questions in plain non-technical language; SD-113 no new addon folders unless they consolidate performance; SD-118 a part's chat words work only while that part is on; no model ID in commits/PRs; her SavedVariables never committed.

## 4. Open questions for Xaya
FILLED IN BELOW (§4a program-wide table from the records; §4b this session's own).

## 5. In-flight work and next steps
FILLED IN BELOW.

## 6. Dependencies on other sessions
- Rule Builder (session_014bN6tSvaDBEe8dCKeMYcgo, branch claude/rule-builder, PR #525): waits for bundle 1 on main, then rebases RB-28. Must be told when bundle 1 lands.
- Stat Calculator (session_014bN6tUmdW8ddPT74JogMYj): QA-branch review; bundle 1 already carries main's Stat Calculator (main fda1e293 merged in).
- Class themes v2 (PR #527, claude/laughing-mendel-9lems1), Shopping List UPG-1 (PR #492, claude/shopping-list-auto-detect-ieb029): open draft PRs from other sessions; they touch addon code and must land after or merge with bundle 1 (one bundled landing rule).
- The SD-140 history erase needs EVERY session that has a copy of the repo paused before the rewrite and restarted from a fresh copy after; otherwise an old copy pushes the erased files back.
- Feature update summary session (session_014bN6tU26cuzQ9LarKYhZQx): gets an itemized what's-new when bundle 1 lands (V18).

## 7. Key files, docs, trackers, artifacts, links
- docs/process/REQUEST-LOG.md (rows through SD-141); docs/process/VERIFICATION.md (V25-V34; V35 to add); docs/SESSION-START-SUMMARY.md (top block is current state); docs/ROADMAP.md.
- Plans: docs/plans/RULES-REVIEW-2026-11-10.md (bundle 1 findings), HIDDEN-DATA-FIGHT-SPEC-2026-11-17.md (round 11 build spec: game-rules table, secret.lua, world.lua state machine, gate key fight, tests T1-T14, risk sites F1-F15, plan steps 0-9 about 22 units, in-game steps §8), TEST-FIDELITY-2026-11-16.md, TEST-AUDIT-2026-11-17.md (248 KEEP, 1 MERGE; fix_r10_display hangs at 900 s; timing 2105 s, two tests 79.1%), TEST-EFFICACY-REVIEW-2026-11-17.md (M1-M8, costs).
- Code facts for round 11: tests/harness/world.lua:887-890 (all C_Secrets / C_RestrictedActions answers false); tests/gate_common.py:1904-1906 (readable UNIT_AURA payloads); tests/harness/scenario.lua:74-75 (sets W.combat before PLAYER_REGEN_DISABLED, wrong order; W.enterCombat at world.lua:1146 is right); tests/harness/scenario.lua:151-160 (calls get on hidden options); XayaUI_Options/RuleEditor/Editor.lua:1707-1740 (gameSound options guarded by hidden()); XayaUI_Rules/Engine.lua:1595-1604 SafeStep (catches engine errors; prints + RecordError only while Advanced Debugging is on); XayaUI/DebugRecord.lua (error record, CueRulesDB.errorLog, MAX_ENTRIES 50).
- Backups: Google Drive folder "XayaUI GitHub backup 2026-11-17 (main + QA)" (SD-141).
- This session's container-only material (lost when archived; NOT needed except as noted): her SavedVariables (re-upload needed), the full mirror + all-refs backup bundle (re-make from GitHub), the round 11 scope list (copied in full into §5 below).

## 8. Gotchas
- The repo is PUBLIC. Never commit her SavedVariables or personal data.
- PR refs: every new pull request creates a read-only GitHub record holding the working docs that SD-140 erases; no new PR was opened for this branch for that reason (INFERENCE that she would want this until the erase; ask if a PR is wanted).
- SafeStep swallows engine errors: a passing engine test can hide engine errors until SD-138 M1 / SD-139 is built (a deliberate error ran 38 times inside one engine test that still printed "58 checks, 0 failed").
- The cloud git proxy refused branch deletes before (HTTP 403); a force-push of the rewritten history may also be refused. Branch deletes are done by Xaya on GitHub's Branches page.
- Budgets are in Lua instructions, not ms. AceConfigDialog skips get() on hidden options; the harness does not (false errors on real data).
- Lua 5.1 metatables cannot make same-type ==, t[s] or truth tests throw, so the secret stand-in needs line hooks / key scans (spec).
- Full suite about 35 min; fix_r10_display hangs at 900 s (to fix in round 11).
- Fast-forward landing: once main's history is rewritten (SD-140), bundle 1 must be rebased onto the new main before it can fast-forward.

## 9. Environment needs (NAMES only)
- GitHub access to heyitsxaya/XayaUI (push to the dev branch; main only at landing); the new private notes repo once Xaya creates it (name proposed: XayaUI-notes).
- Google Drive connector (backups; reference addons folder read-only).
- Python 3, Lua 5.1 (tests/harness), git-filter-repo >= 2.47 (history erase; pip install).

## 10. Suggested successor
One XayaUI lead session that (1) collects round 10's result if this session could not (§5), (2) runs the SD-140 sequence in order, (3) builds round 11 and lands bundle 1. Keep it on Opus-class effort high; Xaya's CONFIG rule asks the session to confirm the most appropriate coding model (Fable 5.2 was recommended to her; she switches with /model; unanswered).

## 11. Archive readiness
FILLED IN BELOW.
