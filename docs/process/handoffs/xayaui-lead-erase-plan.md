# SD-140 full erase: plan, rehearsal and open questions (appendix to xayaui-lead.md)
Produced 2026-11-17 by workflow wf_0ff868de-e9c: 7 agents, with an adversarial review of the erase list and an offline rehearsal. Raw result: xayaui-lead-erase-plan.json (same folder). NOTHING has been erased or pushed. The rehearsal ran on a mirror that is now stale (critic A1), so every step must be re-run on a fresh mirror.

## Erase list (proposed; 106 entries; prefixes end with /)
- `.claude/` (prefix): Claude session skill (process instructions: read VERIFICATION, SESSION-START-SUMMARY); process doc, not addon/test/tool code. Only file: .claude/skills/xayaui-change/SKILL.md
- `Claude outputs/` (prefix): Claude scratch output (notepad writeup, draft patches, Plater NPC-colour paste blocks); not shipped, not read by any tool or test
- `debug-log/` (prefix): 456 per-change process/analysis logs and handoffs; only reader is tools/precheck.py on qa-installer-branch (log-time check), which must be changed
- `docs/issue-screenshots/` (prefix): bug screenshots (8 PNGs); in her OFF list
- `docs/process/audits/` (prefix): process audits (debug-triage, toggle-audit)
- `docs/process/handoffs/` (prefix): session handoff notes (12 files)
- `ARCHIVE.md`: branch-archive note (process), only on archive/* branches
- `CHANGELOG.md`: 2026-10-31 dev changelog built from handoff notes, cites commits and docs/OPEN-ITEMS.md; superseded by PATCH-NOTES.md (kept); historical root file
- `FEATURE-BLURBS.md`: Claude draft feature write-ups with status notes and a licence flag for her; working document, historical root file
- `ROADMAP.md`: roadmap (old root location of docs/ROADMAP.md)
- `SESSION-START-SUMMARY.md`: session-start summary (old root location)
- `pa_tmp.md`: 'process and analysis' scratch note for the 0.5.50 notepad icons
- `docs/OPEN-ITEMS.md`: open items / unfiled issues list from handoff notes (status doc)
- `docs/ROADMAP.md`: the roadmap (her OFF list); note: tools/precheck.py on qa-installer-branch and tests/fix_r9_docs_run.py on the bundle-1 branch read it
- `docs/SESSION-START-SUMMARY.md`: session-start summary (her OFF list); read by tests/fix_r7_docs_repair_run.py, fix_r10_docs_run.py (bundle-1 branch) and tools/precheck.py (qa-installer-branch)
- `docs/TRIGGER-ENGINE-NOTES.md`: engine evidence/design notes from a handoff (working notes)
- `docs/design/DISPLAY-AUDIT-UI-47-2026-11-07.md`: one-off tab-by-tab audit (UI-47 step 3); audits are working docs; no test reads it
- `docs/reference/GCD-RESEARCH-2026-11-07.md`: research notes for UI-63 (web sources); not data a tool reads; StatModel.lua only cites it in a comment
- `docs/reference/HOVER-REWRITES-UI-65-2026-11-07.md`: old-vs-new hover text rewrite table (working list); no test reads it
- `docs/process/BRANCHES-2026-11-07.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/DECISIONS-2026-11-04.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/ELVUI-STRUCTURE-REVIEW-2026-11-05.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/FUNCTION-AUDIT-2026-11-07.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/HUB-HANDOFF-2026-11-07.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/IN-GAME-DATA-2026-11-05.md`: process note: instructions for one in-game data run on 2026-11-05 (not data a tool reads)
- `docs/process/OUTSTANDING-2026-11-06.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/OVERNIGHT-STATUS-2026-11-07.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/PERF-AUDIT-2026-11-07.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/PERF-CODE-NOTES.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/PUSH-PROCESS-REVIEW-2026-11-06.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/QUESTIONS-engine-session.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/REQUEST-LOG-ARCHIVE.md`: request log (process log, her OFF list)
- `docs/process/REQUEST-LOG-CROSS-CHAT.md`: request log (process log, her OFF list)
- `docs/process/REQUEST-LOG-session-014bN6tSs9peLMW4F93tnQcj.md`: request log (process log, her OFF list)
- `docs/process/REQUEST-LOG-session-014bN6tStyDJVemzE9tX7F38.md`: request log (process log, her OFF list)
- `docs/process/REQUEST-LOG-session-014bN6tTRFsCmBvVCUDVtrds.md`: request log (process log, her OFF list)
- `docs/process/REQUEST-LOG-session-014bN6tTZroPi49dAYwBbeGp.md`: request log (process log, her OFF list)
- `docs/process/REQUEST-LOG-session-014bN6tTuH6rxEfggbnTEH3o.md`: request log (process log, her OFF list)
- `docs/process/REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md`: request log (process log, her OFF list)
- `docs/process/REQUEST-LOG-session-014bN6tV8wAAEXAShpTKqUfz.md`: request log (process log, her OFF list)
- `docs/process/REQUEST-LOG-session-014bN6tVFhD1GEbb6ieFgKLz.md`: request log (process log, her OFF list)
- `docs/process/REQUEST-LOG.md`: request log (process log, her OFF list); read by the four fix_r*_docs tests on the bundle-1 branch
- `docs/process/RETROSPECTIVE.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/VERIFICATION.md`: verification process rules for Claude (process doc); read by bundle-1 docs tests and cited by SKILL.md/precheck
- `docs/process/WAKEUP-SUMMARY-2026-11-07.md`: process note / status / audit / handoff (docs/process top level)
- `docs/process/XAYA-STANDING-RULES.md`: her standing rules for Claude: a process doc; goes to the private repo, CLAUDE.md on main will point to where the rules live
- `docs/plans/AURA-CHECKS-EUI-STUDY-2026-11-12.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/AURA-PLAN.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/BLIZZARD-RESKIN-CANDIDATES-2026-11-06.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/CDM-TRACKING-REVIEW-2026-11-06.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/D8-RAID-RULES-SPEC-2026-11-07.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/DEBUG-TO-DEVASSIST-2026-11-06.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/DEVASSIST-PORT-NOTES.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/FIX-PLAN-2026-11-08-SESSION-SUMMARY.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/FIX-PLAN-2026-11-08-TRACKER.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/FIX-PLAN-2026-11-08.html`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/GAMES-MODULE-2026-11-05.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/GROUP-PAGE-REQUIREMENTS-2026-11-06.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/GROUP-PAGE-REVIEW-2026-11-04.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/HIDDEN-DATA-FIGHT-SPEC-2026-11-17.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/IDEA-CHAT-WORD-GAME-2026-11-05.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/IDEA-UPGRADE-OPTIONS-2026-11-05.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/INSTANCE-CAPTURE-2026-11-04.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/LOAD-CONDITIONS-PERF.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/LOAD-CONDITIONS-STUDY.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/MEMORY-REPORT-2026-11-11.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/MERGE-RULES-USE-CASES-2026-11-09.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/NAMEPLATES-PLAN-2026-11-07.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/NAMEPLATES-PLATER-INVENTORY-2026-11-07.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/NAVIGATION-MAP-2026-11-09.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/PLATFORM-SPLIT-2026-11-07.md`: plan / spec / study / review / tracker (docs/plans); many code/test comments cite it but none reads it
- `docs/plans/R10-QUESTIONS-2026-11-16.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/R7-EUI-STUDY-2026-11-13.md`: plan / spec / study / review / tracker (docs/plans); read by tests/fix_r9_docs_run.py:369 on the bundle-1 branch
- `docs/plans/R8-ANSWERS-SD73-76-2026-11-15.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/R9-INFO-PANE-TOOL-PATCH-2026-11-16.md`: plan holding a PENDING, unapplied patch to tools/build_info_pane_data.py on qa-installer-branch (read by fix_r9_docs_run.py); archive it first
- `docs/plans/REFERENCE-SCREENS-AND-FEASIBILITY-2026-11-04.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/RULE-BUILDER-DESIGN.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/RULE-BUILDER-SESSION-START.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/RULE-BUILDER-TRACKER.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/RULES-REVIEW-2026-11-10.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/SHOPPING-LIST-REQUIREMENTS-2026-11-05.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/STAT-CALCULATOR-BOUNDARY-MAP-2026-11-10.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/STAT-CALCULATOR-REDESIGN-2026-11-04.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/STAT-CALCULATOR-REQUIREMENTS-2026-11-04.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/STAT-CALCULATOR-TO-MAIN-2026-11-11.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/STAT-CALCULATOR-V25-SESSION-SUMMARY.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/STAT-CALCULATOR-V25-TRACKER.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/STAT-CALCULATOR-WIREFRAME-SPEC-2026-11-17.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/TEST-AUDIT-2026-11-17.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/TEST-EFFICACY-REVIEW-2026-11-17.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/TEST-FIDELITY-2026-11-16.md`: plan / spec / study / review / tracker (docs/plans)
- `docs/plans/V34-EUI-STUDY-2026-11-12.md`: plan / spec / study / review / tracker (docs/plans)
- `roadmap-features/README.md`: roadmap scaffold write-up (outline/feasibility/test plan, 'not for merging'); roadmap and plans are OFF
- `roadmap-features/games/ARCADE-FEASIBILITY.md`: roadmap scaffold write-up (feasibility research); roadmap and plans are OFF
- `roadmap-features/games/CORE-HOOK.md`: roadmap scaffold write-up (proposal, 'not decided'); roadmap and plans are OFF
- `roadmap-features/games/README.md`: roadmap scaffold write-up (outline only, 'not for merging'); roadmap and plans are OFF
- `roadmap-features/games/XayaUI_Games/Games/Falling/README.md`: roadmap scaffold note (on hold, decision pending); roadmap and plans are OFF
- `roadmap-features/games/XayaUI_Games/Games/LFGSim/README.md`: roadmap scaffold note (not designed, open question); roadmap and plans are OFF
- `roadmap-features/games/tests/README.md`: roadmap test plan (outline only); roadmap and plans are OFF
- `roadmap-features/layout-profiles/README.md`: roadmap scaffold write-up (outline only); roadmap and plans are OFF
- `roadmap-features/layout-profiles/tests/README.md`: roadmap test plan (outline only); roadmap and plans are OFF
- `roadmap-features/mplus-tools/README.md`: roadmap scaffold write-up (outline only); also present on qa-installer-branch; roadmap and plans are OFF
- `roadmap-features/mplus-tools/tests/README.md`: roadmap test plan (outline only); roadmap and plans are OFF
- `roadmap-features/rppm/README.md`: roadmap scaffold write-up (outline only); roadmap and plans are OFF
- `roadmap-features/rppm/tests/README.md`: roadmap test plan (outline only); roadmap and plans are OFF

## Borderline (left OUT of the erase list; Xaya decides)
- `RULES-GUIDE.md`: question: There is an old 'how rules work' guide for players, written on 2 Nov for version 0.5.40. It is no longer on any branch, only in old history. Is it one of your player guides to keep, or an old draft to erase? Recommendation: Keep. It is a player guide ('XayaUI Rules: User's Guide'), and player guides are on her keep list.
- `XayaUI_DevAssist/FORMULA-CAPTURE-WALKTHROUGH.md`: question: Dev Assist has step-by-step instructions that tell a player how to record their spell numbers by swapping gear, for the 'Observed' tooltip lines. Should those instructions be kept as a guide, or erased as a working note? The same text also sits at an older location, XayaUI_GameDump/FORMULA-CAPTURE-WALKTHROUGH.md. Recommendation: Keep both locations. It is a how-to for players and testers, like the QA checklist, and it ships inside the Dev Assist folder on qa-installer-branch. If she says erase, add both paths.
- `docs/process/qa-open-bugs.json`: question: There is a small list of open bugs. The testers' in-game checklist walk builds its 'bugs to confirm' step from it. Keep it because that tool needs it, or erase it and change the tool? Recommendation: Keep. It is input that tools/qa_walks_from_checklist.py:19 reads on qa-installer-branch. If she says erase, the six docs/process/ entries can become one prefix, docs/process/.
- `docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md`: question: There are written in-game test steps for the Stat Calculator on main, for you or a tester. The in-game Info pane's developer notes point to this file. Treat it like the QA checklist and keep it, or erase it with the other plans? Recommendation: Keep, or first move its steps into the QA checklist and then erase it. If it is erased as it stands, the Info pane text on main (XayaUI_Options/InfoPaneData.lua:13,19,114,126) and several test comments will point to a missing file. If erased, docs/plans/ can become one prefix.
- `docs/design/BUILD-RULES.md`: question: There is a file of coding standards: 'how every part of the addon is built so it all fits together'. Is that one of the build documents you want kept? Recommendation: Keep, as a build standard. No test reads it; tests/hover_brevity_run.py, tests/tooltip_parity_run.py and XayaUI/Modules.lua:1258 cite it in comments.
- `docs/design/DISPLAY-RULINGS.md`: question: There is a file that collects your own words behind each display rule, and the display rules file points to it for every rule. Keep it with the display rules, or erase it as part of the logs? Recommendation: Keep, as the companion to DISPLAY-RULES.md. A test reads DISPLAY-RULES.md, and that file says each new ruling is added here. Caveat: it quotes request-log row IDs and session-log file names.
- `docs/reference/maps/SHOPPING-LIST-UPGRADE-TOAST.md`: question: There is a developer's map of how the Shopping List 'new gear' popup works inside the code. It is only on one branch. Erase it as a working note? Recommendation: Erase. It is developer notes, not game data, and nothing reads it. It exists only on claude/shopping-list-auto-detect-ieb029.
- `roadmap-features/`: question: The roadmap 'scaffold' folders (games, M+ tools, layout profiles, RPPM) hold only outline files made of comments. Nothing in them runs. Erase the whole folder from history along with the roadmap? Recommendation: Erase the whole folder as one prefix, roadmap-features/. Every .lua file in it has 0 non-comment lines (checked on roadmap-features/combined), so it is all plan material. The prefix would replace the 13 roadmap-features/*.md entries on the erase list.
- `MANIFEST.md5`: question: The checksum list on main and the testers' branch names every file, including the ones being erased. It holds only their names, not their text. Should the old copies have those lines removed as well, so even the names disappear? Recommendation: Yes. Removing paths does not change this file's contents, so also rewrite the MANIFEST.md5 contents to drop lines that name erased paths, and regenerate it at the branch tips. Most historical versions name about 460 erased paths, including the REQUEST-LOG-session-<id> names. The same names also appear in kept text (code comments, PATCH-NOTES, tests); that text cannot be scrubbed by removing paths.

## Reviewer findings
- missed? `roadmap-features/games/XayaUI_Games/`: The erase list covers only the 13 roadmap-features/*.md files. It leaves 46 roadmap-features files uncovered, and 25 of them are here: 24 .lua files and XayaUI_Games.toc. Every one is outline or plan material. Every historical blob of every roadmap-features .lua has 0 non-comment lines. Command: `git -C mirror.git rev-list --all --objects | grep ' roadmap-features/.*\.lua$' | while read b p; do git cat-file -p $b | grep -vE '^\s*(--|$)' | wc -l ...` printed nothing above 0. Example Games.lua header: '-- Games.lua : OUTLINE ONLY (RM-GAMES, 2026-11-05). No code. Proposed, not decided.' Example .toc first line: '# OUTLINE ONLY (RM-GAMES, 2026-11-05). Not an installed addon: it lives under roadmap-features/ so no tool or game reads it.' The roadmap and plans are on her OFF list. The cleanest fix is the prefix roadmap-features/, which also replaces the 13 .md entries (the analyst's own borderline recommendation).
- missed? `roadmap-features/mplus-tools/XayaUI_MPlusTools/`: 14 uncovered files: 13 comment-only .lua outlines (Announce, CC, CastWatch, Comms, Cooldowns, Kicks, MPlus, Requests, SpellLists, Threat, UI/Options, UI/ThreatView, UI/Tracker) and XayaUI_MPlusTools.toc. The .toc header reads '# OUTLINE ONLY (RM-MPLUS, 2026-11-06). Not an installed addon ... Proposed .toc. The name, the saved table and the version are placeholders (README section 4, Q2).' This is roadmap scaffold material. Note that tools/qa-only-paths.txt on qa-installer-branch lists 'roadmap-features', and the branch tip carries this subtree.
- missed? `roadmap-features/rppm/`: 5 uncovered comment-only .lua outlines: XayaUI/ProcMath.lua, XayaUI/ProcRates.lua, XayaUI_Bonus/TooltipsRPPM.lua, XayaUI_DevAssist/ProcCount.lua, XayaUI_QoL/ToolkitRPPM.lua. Non-comment lines: 0 in each, measured by a show.sh-style loop with `grep -vE '^\s*(--|$)' | wc -l`. Roadmap scaffold.
- missed? `roadmap-features/layout-profiles/`: 2 uncovered comment-only .lua outlines: XayaUI/Layouts.lua (0 of 22 lines are code) and XayaUI_Options/LayoutsPage.lua (0 of 13). Roadmap scaffold.
- missed? `XayaUI_DevAssist/QAQuestions.lua`: An open-questions log for Xaya written in Lua (111276 bytes on qa-installer-branch; about 208 key= entries). Header: 'the open questions for Xaya ... Generated from the sessions' messages'. Entries are grouped by origin session, for example '-- from the D8 session (014bN6tTZroPi49dAYwBbeGp)', which is the same session id as an erased REQUEST-LOG-session-*.md. Each entry quotes her words verbatim, along with request-log/question ids (D8-Q1, O-109, H4, FA-16 ...) and what was held or shipped. It is effectively a status and question log, the same kind of content as the erased REQUEST-LOG and OPEN-ITEMS files. Caveat: it is code. XayaUI_DevAssist.toc:41 loads it, and tests/american_spelling_run.py:91-94 references it on qa-installer-branch. It is absent on main and on claude/dazzling-brown-x9fqrm (`git cat-file -s <ref>:XayaUI_DevAssist/QAQuestions.lua`). Report it as a candidate for her decision. Erasing it would need the .toc line and the test entries removed on qa-installer-branch. A grep over all 31 heads for session ids or 'handoff' (`git grep -c -E '014bN6t[A-Za-z0-9]{17}|handoff'`) ranks it second, after MANIFEST.md5, among the files that stay.
- missed? `XayaUI_Rules/Combat/README.md`: Borderline. The analyst kept it as code-folder documentation, but part of it is Claude process notes. One section reads '## Ownership: The combat-engine Claude instance owns this folder. The core instance owns everything else ... Changes to the bridge need both.' It also has 'Planned: ... Contract draft: project doc claude/XAYAUI-COMBAT-ENGINE-SPLIT-CONTRACT-DRAFT-2026-11-02.md' and dated checks ('checked 2026-11-04'). The same document exists at XayaUI_CombatEngine/README.md and XayaUI/Combat/README.md with the same Ownership and Planned sections (seen with show.sh). Ask her whether these are kept as folder docs (maybe with those sections edited out at the tips) or erased. tests/fix_r7_docs_run.py on the bundle-1 branch reads the XayaUI_Rules copy.
- missed? `XayaUI_CombatEngine/README.md`: An older location of the same combat-engine README. It has the same '## Ownership: The combat-engine Claude instance owns this folder' section and the Planned contract-draft pointer. Only ref with it: wip/notepad-icons (show.sh refs-with-it). It is a candidate together with XayaUI_Rules/Combat/README.md.
- missed? `XayaUI/Combat/README.md`: Another older location of the same combat-engine README, with the same Claude-instance ownership and planning notes. Same decision as XayaUI_Rules/Combat/README.md.
- borderline disagreement: roadmap-features/: the analyst left the prefix as a borderline question. That leaves 46 non-.md scaffold files (44 .lua, 2 .toc) uncovered if only the 13 .md entries are applied. Every historical version of every one of those .lua files is 100% comments, and both .toc files begin '# OUTLINE ONLY ... Not an installed addon'. Her scope says roadmap and plans are OFF, so this should be an erase prefix, not a question.
- borderline disagreement: docs/reference/maps/SHOPPING-LIST-UPGRADE-TOAST.md: the analyst recommends erasing it but left it off the erase list as borderline. If it is a working note, as the analyst says, it should be on the list. Otherwise it survives by default.
- borderline disagreement: allpaths.txt is incomplete. An independent walk of every commit (`git -C mirror.git rev-list --all > commits.txt; while read c; do git ls-tree -r -z --name-only $c; done | tr '\0' '\n' | sort -u`) gives 1810 paths, not 1803. Missing: Link-XayaUI.bat (a root-level tester installer, last seen in qa-installer-branch history, commit 27d9d8be 'Mirror main @ 075acd684'; not a working doc) and 6 debug-log files: 2026-11-06-2306-bar-cues-merge-main-relabel-core-0.6.58-options-0.6.58-bonus-0.6.20.md, 2026-11-07-0040-audit-chat-fixes-chat-0.6.32.md, 2026-11-07-0043-audit-qa-walks-restore-devassist-0.7.15.md, 2026-11-07-0045-o100-stat-calculator-row-qol-0.7.41.md, 2026-11-07-0631-audit-qa-walkthroughs-devassist-0.7.15.md, 2026-11-07-0831-generate-buttons-qa-walk-dev-assist-0.7.14.md. These 6 exist only in merge commits (for example c88048d9, 90095d3e, d79f4b44) and are covered by the debug-log/ prefix, so the erase still works. Any per-file check built from allpaths.txt (counts, verification after the rewrite) must use the full list.
- wrongly erased? `docs/plans/R9-INFO-PANE-TOOL-PATCH-2026-11-16.md`: This file is build material held in a plan document: a 24-line +/- patch to tools/build_info_pane_data.py that has not been applied at any tip. `git show <tip>:tools/build_info_pane_data.py | grep -cE 'KEEP_LANDINGS|XUI_ROOT'` returns 0 on main, qa-installer-branch, claude/dazzling-brown-x9fqrm and claude/rule-builder. On the bundle-1 tip, four kept player docs send the maintainer to it in their build headers: PATCH-NOTES.md:7 ("its round 9 change (KEEP_LANDINGS, XUI_ROOT) is NOT there yet ... with the patch in docs/plans/R9-INFO-PANE-TOOL-PATCH-2026-11-16.md. Until that patch is applied, QA's tool as it is puts every landing back"), docs/HELP-FAQ.md:7, docs/README-INGAME.md:7 and docs/USER-GUIDE.md:1001. If it is erased as it stands, the next rebuild of the player-visible XayaUI_Options/InfoPaneData.lua goes backwards (every landing comes back, against SD-69). The analyst only said to archive it. It should be applied to qa-installer-branch's tools/build_info_pane_data.py, and the four header lines changed, BEFORE the rewrite. After that the erase is fine.
- borderline disagreement: docs/process/IN-GAME-DATA-2026-11-05.md: the analyst calls it a one-off process note. Its text agrees ('For Xaya ... Claude reads the file afterwards', dated Thursday 2026-11-05). But the kept player guide names it as the event probe's 'run sheet' on all four kept tips: main docs/USER-GUIDE.md:869, qa-installer-branch :879, bundle-1 :905, rule-builder :880. It is a player/tester how-to of the same kind as XayaUI_DevAssist/FORMULA-CAPTURE-WALKTHROUGH.md, which the analyst keeps for that reason (USER-GUIDE.md links to it in the same section). Either ask Xaya, or erase it and remove that sentence from USER-GUIDE.md on every kept tip first, so the player guide does not point to a missing file.
- borderline disagreement: debug-log/2026-11-04-1550-terms-check-blizzard-wago.md (inside the debug-log/ prefix): this is the full licence and terms analysis (Blizzard EULA §1.C.6/§2.A.1.i, the add-on policy, 37 CFR 202.1(a), wago.tools having no terms). The kept data readme docs/reference/README.md:23 cites it on all four tips ('details in debug-log/2026-11-04-1550-terms-check-blizzard-wago.md'). It is a log, so erasing it fits her scope, but it is the evidence behind the public/full split of the kept spell and game data. Recommendation: copy it to the private archive, or fold the missing details into docs/reference/README.md, and drop the pointer before erasing. No code reads it.
- borderline disagreement: CHANGELOG.md: the analyst says PATCH-NOTES.md supersedes it. That is only partly true. PATCH-NOTES.md on main starts at the 0.6.x entries (its oldest headings are Options 0.6.39 / XayaUI 0.6.46), while CHANGELOG.md is the only Added/Changed/Fixed record for the 0.5.5-era 'Additional Triggers, Outcomes, Target Debuff' work (2026-10-30/31). `grep -niE 'Additional Triggers|Outcomes|Target Debuff'` on PATCH-NOTES.md finds none of those headings. Her keep list includes 'patch notes'. It is on no current branch (show.sh: refs-with-it is empty), so erasing it removes it only from history. Worth one question to her, or archive it privately. Its text cites commits and OPEN-ITEMS, so it reads more like a dev changelog than player notes.
- borderline disagreement: docs/reference/GCD-RESEARCH-2026-11-07.md: this sits inside the kept data folder and holds the sourced evidence for a game rule that code implements (GCD = 1.5/(1+haste), 0.75 s floor, fixed 1.0 s for energy melee). XayaUI_Bonus_StatCalculator/StatModel.lua:594 (main and bundle-1) and XayaUI_QoL/StatModel.lua:1045 (qa-installer-branch) cite it as 'Research, with sources'. No tool or test reads it, so it is not 'data the tools read'. Erasing it is defensible, but the code comment will then point to a missing file. Low risk.
- borderline disagreement: docs/design/DISPLAY-AUDIT-UI-47-2026-11-07.md: the kept, test-read docs/design/DISPLAY-RULES.md:77 links to it on all four tips. tests/display_standard_run.py:28 reads DISPLAY-RULES.md but only parses the section C value rows (lines 27-28, 214), so the erase does not break the test. Only the link dangles. I agree with erasing it.
- borderline disagreement: 'Claude outputs/' prefix: two of its files are not documents: Plater_NpcColors_S2_block.lua and XayaUI_NpcColors_S2_block.lua, NPC colour paste blocks for Plater (game data). They are erased anyway: Xaya said 'I don't think we should be having claude outputs pushed to the repository' (main docs/process/REQUEST-LOG-CROSS-CHAT.md:191, HIEFF-17). No kept tip references them: `git grep -l -i -E 'NpcColors|Claude outputs'` hits only docs and logs that are themselves erased. Agree with the erase.

## Offline rehearsal
- Tool: git-filter-repo 2.47.0 (pip show; `git-filter-repo --version` prints a40bce548d2c), installed in /tmp/claude-0/-home-user-XayaUI/15a42788-1ac6-5589-993e-20166a9f9969/scratchpad/erase/work-rehearse/venv. Git is 2.43.0 and Python is 3.13.18.
- Erased paths remaining in any head: 0; refs rewritten: 150; tip differences outside the erase list: none
- Pull refs: I rewrote all 119 refs/pull/* (109 head, 10 merge) in the local copy, because the mirror's fetch refspec is +refs/*:refs/*. 118 of the 119 original pull refs reach an erased path. GitHub treats refs/pull/* as read-only hidden refs, so a push of them is rejected ('deny updating a hidden ref'). Their old commits stay on GitHub, together with the erased blobs, until GitHub Support removes them; give Support the First Changed Commit 51355095ec1c334cd44c4ec036792831d94dd302 (also in rewrite.git/filter-repo/first-changed-commits). I could not test this rejection myself, because nothing may be pushed. The copy still has remote.origin.mirror=true (from the mirror clone). With that set, a plain `git push origin` acts like --mirror: it tries to push every refs/pull/* ref, which fails, and it would delete remote refs that are missing locally. I have not confirmed exactly how git 2.43 combines that setting with filter-repo's suggested `git push --all --tags origin`. Before the real push, remove mirror=true (or use a fresh clone of the rewritten repo) and push only the branches she keeps, with an explicit force refspec such as `git push --force origin 'refs/heads/<branch>:refs/heads/<branch>'`, after she has deleted the stale branches. That push is Xaya's step, not mine.
- Notes-repo extract: The notes repo is /tmp/claude-0/-home-user-XayaUI/15a42788-1ac6-5589-993e-20166a9f9969/scratchpad/erase/work-rehearse/notes.git. It is a bare repo built from main and claude/dazzling-brown-x9fqrm only, filtered with `git filter-repo --force --paths-from-file paths.txt` (no invert). It has 1112 commits in total: main has 1036 and claude/dazzling-brown-x9fqrm has 1112, so main is an ancestor. It started from 1446 commits; commits that touched no erased path were dropped. Size: 5.5M on disk, 5.03 MiB pack, 5859 objects. It holds 549 distinct paths, and none of them is outside the erase list. The tips have 76 files (main) and 87 files (bundle-1). It includes 435 debug-log files, among them the licence/terms note debug-log/2026-11-04-1550-terms-check-blizzard-wago.md (in history, not at the main tip). There is a gap: 84 of the 633 erased paths exist only on other branches, so this extract does not have them. The 84 are 43 roadmap-features files, 27 debug-log files, ARCHIVE.md, docs/OPEN-ITEMS.md, docs/TRIGGER-ENGINE-NOTES.md, the docs/plans/RULE-BUILDER-*, LOAD-CONDITIONS-* and STAT-CALCULATOR-{BOUNDARY-MAP,REVIEW,TO-MAIN,V25-*,WIREFRAME-SPEC} files (list in work-rehearse/erased-not-in-notes.txt). After the rewrite they would survive only in the backup bundle. For comparison I also built /tmp/claude-0/-home-user-XayaUI/15a42788-1ac6-5589-993e-20166a9f9969/scratchpad/erase/work-rehearse/notes-allheads.git from all 31 heads: 30 refs (one head had no erased path at all), 1349 commits, 6.2M, and it holds all 633 erased paths. Nothing was pushed.
- Commands:
  - `E=/tmp/claude-0/-home-user-XayaUI/15a42788-1ac6-5589-993e-20166a9f9969/scratchpad/erase; W=$E/work-rehearse; M=$E/mirror.git; P=$E/work-pathlist`
  - `mkdir -p $W && cd $W && python3 -m venv venv && ./venv/bin/pip install -q git-filter-repo && ./venv/bin/pip show git-filter-repo   # Version: 2.47.0`
  - `python3 -I -c '...compare erase.json with erase-files.txt...'   # 106 entries = 100 files + 6 prefixes, same as the proposal`
  - `# paths.txt = the 6 proposal prefixes + roadmap-features/ (replaces its 13 .md entries) + the 100 proposal files minus the roadmap-features/*.md entries, docs/plans/R9-INFO-PANE-TOOL-PATCH-2026-11-16.md (reviewer: wrongly erased until its patch is applied), CHANGELOG.md and docs/process/IN-GAME-DATA-2026-11-05.md (borderline, held out). Result: 91 lines (7 prefixes, 84 files). Written with: { cat $P/erase-prefixes.txt; echo roadmap-features/; grep -v '^roadmap-features/' $P/erase-files.txt | grep -vxF -e docs/plans/R9-INFO-PANE-TOOL-PATCH-2026-11-16.md -e CHANGELOG.md -e docs/process/IN-GAME-DATA-2026-11-05.md; } >> $W/paths.txt`
  - `git -C $M rev-list --all | while read c; do git -C $M ls-tree -r -z --name-only $c; done | tr '\0' '\n' | sort -u > $W/allpaths-orig.txt   # 1810 paths from 1874 commits`
  - `python3 -I $W/match.py $W/paths.txt $W/allpaths-orig.txt in > $W/expected-erased.txt   # 633 erased, 1177 kept; every one of the 91 entries matches at least one path (match.py copies filter-repo's literal prefix rule)`
  - `git -C $M for-each-ref --format='%(objectname) %(refname)' > $W/refs-before.txt   # 150 refs`
  - `cp -a $M $W/rewrite.git && git -C $W/rewrite.git config remote.origin.pushurl DISABLED-no-push-rehearsal`
  - `cd $W/rewrite.git && PATH=$W/venv/bin:$PATH git filter-repo --sensitive-data-removal --no-fetch --invert-paths --paths-from-file $W/paths.txt   # 'You rewrote 1872 (of 1874) commits'; First Changed Commit 51355095ec1c334cd44c4ec036792831d94dd302; no --force needed`
  - `git -C $W/rewrite.git for-each-ref --format='%(objectname) %(refname)' > $W/refs-after.txt; join -j2 ... refs-before refs-after   # heads 31/31 changed, pull 119/119 changed, none added or removed`
  - `git -C $W/rewrite.git log --branches --name-only -m --format= | sort -u   # 1177 paths, 0 match paths.txt`
  - `git -C $W/rewrite.git rev-list --branches | while read c; do git ls-tree -r -z --name-only $c; done ...   # full tree walk of all 1571 head commits: 0 erased paths`
  - `git -C $W/rewrite.git rev-list --all | while read c; do git ls-tree -r -z --name-only $c; done ...   # all 1580 commits incl. local refs/pull: 0 erased paths, 0 kept paths lost, 0 new paths`
  - `git clone -q --bare $W/rewrite.git $W/check.git; git -C $W/check.git fetch -q $W/rewrite.git '+refs/heads/*:refs/heads/*'; git -C $W/check.git fetch -q $M '+refs/heads/*:refs/original-check/*'`
  - `for r in <31 heads>: git -C $W/check.git diff --no-renames --name-status refs/original-check/$r refs/heads/$r   # every line is a D of an erased path; 0 non-deletions; 0 outside the list; 0 erased paths left at any new tip (results in $W/tipdiff.txt)`
  - `git -C $W/check.git diff --stat refs/original-check/main refs/heads/main   # 76 files changed, 11257 deletions(-)`
  - `awk '$2 ~ /^0+$/' $W/rewrite.git/filter-repo/commit-map | wc -l   # 294 commits dropped because they only touched erased paths (1874-294=1580)`
  - `for r in refs/pull/*: git -C $M rev-list --count $r -- <paths>   # 118 of 119 original pull refs reach an erased path`
  - `git init -q --bare $W/notes.git; git -C $W/notes.git fetch -q --no-tags $M '+refs/heads/main:refs/heads/main' '+refs/heads/claude/dazzling-brown-x9fqrm:refs/heads/claude/dazzling-brown-x9fqrm'; cd $W/notes.git && PATH=$W/venv/bin:$PATH git filter-repo --force --paths-from-file $W/paths.txt`
  - `git -C $W/notes.git rev-list --all | wc -l; git -C $W/notes.git count-objects -vH; du -sh $W/notes.git`
  - `(extra, for comparison) git init -q --bare $W/notes-allheads.git; fetch '+refs/heads/*:refs/heads/*' from $M; git filter-repo --force --paths-from-file $W/paths.txt   # 30 refs, 1349 commits, 6.2M, all 633 erased paths`
  - `git -C $M for-each-ref --format='%(objectname) %(refname)' | diff -q - $W/refs-before.txt   # mirror unchanged; git -C /home/user/XayaUI status --short printed nothing`
- Problems:
  - Five branch tips moved back. Their last commit(s) touched only erased files, so filter-repo dropped them and the branch now points to the nearest commit with kept changes: qa-installer-branch (old 236262bc 'Tracker and request log...'), claude/dazzling-brown-x9fqrm, claude/rule-builder, claude/function-audit and claude/stat-calculator-v25. As a result, qa-installer-branch and claude/stat-calculator-v25 now point to the same commit 2d86f937. The tip trees still differ from the old tips only by erased-path deletions, which I verified for all 31 heads. In total, 294 commits were dropped as empty.
  - The tip commit messages changed. filter-repo rewrites old commit IDs inside messages to the new IDs (for example main: b1bef6e becomes b486561). The author, the date and the rest of each message stayed the same. 37 old IDs in messages point to commits that were dropped and are left as they were (rewrite.git/filter-repo/suboptimal-issues).
  - Held out of this rehearsal (not erased, still in history), each needing her decision. docs/process/IN-GAME-DATA-2026-11-05.md is still on 25 heads, including main. CHANGELOG.md is on no head but is still in history (last at ea22c9f9). docs/plans/R9-INFO-PANE-TOOL-PATCH-2026-11-16.md is still on claude/dazzling-brown-x9fqrm: per the reviewer, apply its patch to qa-installer-branch's tools/build_info_pane_data.py and fix the four player-doc header lines first, then add it to the list. Borderline candidates not added: XayaUI_DevAssist/QAQuestions.lua, XayaUI_Rules/Combat/README.md, XayaUI_CombatEngine/README.md, XayaUI/Combat/README.md and docs/reference/maps/SHOPPING-LIST-UPGRADE-TOAST.md. The debug-log terms note, GCD-RESEARCH, DISPLAY-AUDIT and 'Claude outputs/' stay erased, because the reviewers agreed or called the erase low risk.
  - The rewritten tips will fail their own checks unless follow-up commits fix them. qa-installer-branch tools/precheck.py:249-250 runs os.listdir('debug-log') and reads docs/SESSION-START-SUMMARY.md, and :158 lists ROADMAP.md/SESSION-START-SUMMARY.md. tests/fix_r7_docs_run.py, fix_r7_docs_repair_run.py, fix_r9_docs_run.py and fix_r10_docs_run.py on claude/dazzling-brown-x9fqrm read docs/process/REQUEST-LOG.md. MANIFEST.md5 still names 76 erased paths on main and 483 on qa-installer-branch, so it needs to be regenerated with tools/manifest.py. tools/qa-only-paths.txt:11 'roadmap-features' becomes a stale entry. I checked all of this with git grep on rewrite.git; I did not run the tests.
  - Kept player and design docs still link to erased files, as the reviewers found (QA-CHECKLIST, DISPLAY-RULES, DISPLAY-RULINGS, docs/reference/README.md:23 and others), and session process text inside kept files is not removed by a path erase. Both need edits at the tips.
  - The copy still has remote.origin.mirror=true and the GitHub URL from the mirror clone. I set remote.origin.pushurl=DISABLED-no-push-rehearsal in rewrite.git, so an accidental push fails. With --sensitive-data-removal, filter-repo kept the origin remote. For the real run, push only the kept heads with explicit force refspecs, never a mirror push. I cannot confirm GitHub's exact rejection text for refs/pull, because nothing was pushed.
  - I ran with --no-fetch: offline, using the existing 150-ref mirror. Without --no-fetch, --sensitive-data-removal would run a mirror-like fetch from GitHub first. If the remote has changed since the mirror was taken, the real run must start from a new mirror clone.
  - allpaths.txt (1803 lines) is incomplete. My walk of all 1874 commits gives 1810 paths, which matches the reviewer. All checks above use the 1810-path list (work-rehearse/allpaths-orig.txt).
  - Nothing was pushed. The mirror refs match the snapshot taken before the run (diff -q). The bundle size and mtime are unchanged (18794154 bytes, 19:34). /home/user/XayaUI has no changes (branch claude/dazzling-brown-x9fqrm). All rehearsal files are in /tmp/claude-0/-home-user-XayaUI/15a42788-1ac6-5589-993e-20166a9f9969/scratchpad/erase/work-rehearse/: paths.txt, rewrite.git, check.git, notes.git, notes-allheads.git, filter-repo.log, tipdiff.txt, refs-before.txt and refs-after.txt.

## Branches (31 at the time of the scan; 2 more appeared since, critic A1)
| branch | head | last commit | status | recommendation | evidence |
|---|---|---|---|---|---|
| main | fda1e293 | 2026-11-12T18:43 | protected_core | rewrite_and_keep | Known keep. History touches docs/process and docs/plans (git log -1 main -- docs/process docs/plans is non-empty), so SD-140 requires a rewrite. |
| qa-installer-branch | 236262bc | 2026-11-12T18:48 | protected_core | rewrite_and_keep | Her QA branch. It is not contained in main: ahead=176, behind=15, git cherry main shows 25 '+', and merge-tree shows changes. It is the base of stat-calculator-v25 and shopping-list (git merge-base --is-ancestor qa-installer-branch <b> returns true for both). Rewriting it conflicts with her standing never-force-push rule. SD-140 names this branch as one to rewrite, but it needs her explicit OK at the moment of the push. |
| claude/dazzling-brown-x9fqrm | e79a4c76 | 2026-11-17T19:33 | protected_core | rewrite_and_keep | Active today. main is an ancestor: ahead=95, behind=0, cherry 94 '+'. Unmerged work. |
| claude/rule-builder | 699e19fd | 2026-11-17T15:22 | protected_core | rewrite_and_keep | Active today. ahead=124, behind=4, cherry 124 '+'. main is NOT an ancestor of this branch. |
| claude/stat-calculator-main | fda1e293 | 2026-11-12T18:43 | contained_in_main | her_delete | Same commit as main (fda1e293f7). merge-base --is-ancestor is true, ahead=0, merge-tree tree == main^{tree}. |
| claude/shopping-list-auto-detect-ieb029 | c14688bb | 2026-11-17T18:41 | active_or_unmerged_work | rewrite_and_keep | Active today. 5 commits are not on any kept branch (1 merge). 4 non-merge commits are not patch-equivalent on kept branches and change code: XayaUI_QoL/ShoppingList.lua, StatModel.lua, DevAssist QAWalks, tests, docs/USER-GUIDE.md. Built on qa-installer-branch. |
| claude/stat-calculator-v25 | 59583dbc | 2026-11-17T17:09 | active_or_unmerged_work | ask_her | Active today. Its 13 commits on top of qa-installer-branch (236262bc7b, an ancestor) touch ONLY docs/process/REQUEST-LOG.md and docs/plans/STAT-CALCULATOR-V25-{SESSION-SUMMARY,TRACKER}.md plus WIREFRAME-SPEC-2026-11-17.md. These are all in the erase scope, so after the rewrite this branch would equal qa-installer-branch. A live session is using these working docs, so she should decide whether to delete it or have them moved off git first. |
| claude/laughing-mendel-9lems1 | d4693763 | 2026-11-17T15:40 | active_or_unmerged_work | rewrite_and_keep | Active today. main is an ancestor. Its 6 'Class themes v2' commits are not patch-equivalent on any kept branch and change code (XayaUI/Theme.lua, TreePaint.lua, InfoPaneData.lua, tests, PATCH-NOTES.md). |
| claude/affectionate-turing-03e9tu | 028b10a9 | 2026-11-13T03:52 | active_or_unmerged_work | ask_her | 4 days old, so under the 5-day stale threshold. One code commit (Class themes v1: Druid glow; Theme.lua, TreePaint.lua, tests/theme_class_glow_run.py) is not on any kept branch and not patch-equivalent. laughing-mendel 'Class themes v2' uses the same version numbers and has its own DRUID entry, so it looks like a successor. I cannot confirm that it supersedes this branch: tests/theme_class_glow_run.py is absent from laughing-mendel, main and qa. |
| claude/feature-update-summary | 6643665d | 2026-11-08T22:40 | active_or_unmerged_work | ask_her | 9 days without commits. 4 non-merge commits are not patch-equivalent on kept branches: PATCH-NOTES.md entries 'Main Slims Down' and 'Character Pane Split and Chat Defaults', InfoPaneData.lua, and the DevAssist PN-1 question. git grep finds neither heading on main or qa-installer-branch. This is player-facing content that is not stored anywhere else. |
| claude/d8-raid-rules-ready | 248de577 | 2026-11-07T08:32 | active_or_unmerged_work | ask_her | HELD under O-109 by her order (BRANCHES-2026-11-07.md). 4 commits are not on any kept branch and not patch-equivalent. 2 of them are D8 Release Guard code (b3f0d5be, 91e8701a: Conditions.lua, Options.lua, QoL, DevAssist); 2 are docs plus MANIFEST. |
| claude/ui-bugs-focused | b95ec192 | 2026-11-07T14:19 | stale_superseded | her_delete | 10 days without commits. Its only commit not on main, b95ec192, has its parent dc45c253 on main and changes only MANIFEST.md5 and adds 1 line to docs/process/handoffs/ui-bugs.md, which is in the erase scope. After the erase it would carry nothing that main lacks. The head moved since the 2026-11-07 inventory (af3545e was contained then). |
| claude/settings-restructure-fallback | 376b5364 | 2026-11-07T11:40 | stale_superseded | her_delete | Its only commit not on main is a merge whose two parents, ddd2917e and bf2ce6a6, are both on main. git cherry shows 0 '+'. main landed the same two parents its own way (434d83a2, then 9bf8bc24), and nothing else has this merge's tree. This was an unused fallback landing. |
| claude/adoring-hawking-wyda59 | 65bf4d5f | 2026-11-07T08:34 | stale_superseded | her_delete | Merge dec2b0ab has both parents on main. The non-merge 65bf4d5 adds docs/process/handoffs/character-pane.md; that same blob (fd1b23df) is on main at b8b63b4a (git log main --find-object). Contained by content, and the file is in the erase scope. |
| claude/d8-raid-rules-main | dc7628f0 | 2026-11-07T07:48 | stale_superseded | her_delete | Owner says it is superseded by d8-raid-rules-ready. Its 2 code commits are not on kept branches, but the head is a direct parent of archive/2026-11-07 (merge-base --is-ancestor is true), so deleting the name loses nothing while that archive exists. |
| claude/function-audit | 8251eec0 | 2026-11-07T06:15 | stale_superseded | her_delete | 14 non-merge commits are not patch-equivalent on kept branches. The owner says they were redone as function-audit-land-2 on main; git cannot prove that. The head is a parent of archive/2026-11-07, so deleting the name loses nothing while that archive exists. |
| claude/d8-raid-rules | 4811da51 | 2026-11-07T05:55 | stale_superseded | her_delete | Superseded by d8-raid-rules-ready. 8 non-merge commits are not on kept branches. The head is a parent of archive/2026-11-07, so deleting the name loses nothing while that archive exists. |
| claude/perf-test-m-plus | 5cb963d0 | 2026-11-07T03:11 | stale_superseded | her_delete | 14 non-merge commits are not on kept branches: mostly PERF-CODE-NOTES docs, plus the RunRecord prompt, which was removed on purpose (CLEAN-10). The head is a parent of archive/2026-11-07. |
| claude/perf-click | a6e6b505 | 2026-11-07T11:02 | stale_superseded | her_delete | The owner redid this as perf-click-main (#452), which is on main. Its 3 commits are not patch-equivalent on kept branches. The head is a parent of archive/2026-11-07. |
| claude/fervent-cerf-hldtwn | 3ac67190 | 2026-11-07T00:24 | stale_superseded | her_delete | Superseded by d8-raid-rules-ready, and the owner session is inactive. 6 non-merge commits are not on kept branches. The head is a parent of archive/2026-11-07. |
| claude/eloquent-rubin-n9zb99 | 84aea1f5 | 2026-11-04T15:06 | stale_superseded | her_delete | git cherry shows 43 '-' and 2 '+'. Against all kept-branch patch-ids, the only non-equivalent non-merge commit is 04568db9 (MANIFEST.md5 regenerated, a generated file). The head is the parent of archive/2026-11-06. PR #363 is closed. |
| roadmap-features/games | 61178e82 | 2026-11-06T01:48 | stale_superseded | her_delete | Every file it changes versus main has the same blob in roadmap-features/combined (per-file rev-parse comparison), except MANIFEST.md5. PR #397 is closed. |
| roadmap-features/rppm | c8e14b2c | 2026-11-06T00:34 | stale_superseded | her_delete | All its files are identical in roadmap-features/combined except README.md, where combined only fixes one path reference (SESSION-START-SUMMARY.md becomes docs/SESSION-START-SUMMARY.md), and MANIFEST.md5. PR #398 is closed. |
| roadmap-features/layout-profiles | 79b084de | 2026-11-06T18:33 | stale_superseded | her_delete | Its Lua and test files are identical in combined. Its README differs only by a path fix. Its ROADMAP.md RM-LAYOUTS row is in main:docs/ROADMAP.md (git grep), and the roadmap is in the erase scope anyway. PR #421 is closed. |
| roadmap-features/combined | 93c5c748 | 2026-11-06T23:27 | active_or_unmerged_work | ask_her | Kept on purpose (Xaya 2026-11-06: roadmap scaffolds, not for merge; PR #429). It has 1 commit that is not on main, adding roadmap-features/{games,rppm,layout-profiles} and 7 debug-log notes. I cannot confirm whether roadmap-features/ counts as 'the roadmap' in her OFF scope (main itself has roadmap-features/mplus-tools). |
| archive/2026-11-07 | c80e63e1 | 2026-11-07T14:04 | active_or_unmerged_work | ask_her | A history keeper: an octopus merge whose parents are the heads of function-audit, perf-click, perf-test-m-plus, d8-raid-rules, d8-raid-rules-main and fervent-cerf-hldtwn. It holds 42 non-merge commits that are not patch-equivalent on any kept branch, so deleting it loses that superseded work. It also has docs/process in its history, so it must be rewritten if kept. |
| archive/2026-11-06 | 98f3d1b8 | 2026-11-06T23:15 | active_or_unmerged_work | ask_her | A history keeper whose only parent is the eloquent-rubin head. Only 2 of its non-merge commits are not patch-equivalent on kept branches: 04568db9 (MANIFEST regen) and the archive commit itself. It is almost entirely redundant with kept branches, but whether to keep archives is her call. |
| archive/2026-11-04 | 2c9ab082 | 2026-11-04T02:22 | active_or_unmerged_work | ask_her | An octopus over the heads of 15 removed branches, including frame-strata-conditions, magical-cray-jmspwv and wip/notepad-icons. 7 non-merge commits are not on kept branches (for example 'zzzz' f768847c, Chat 0.6.5 596766e8, Core 0.6.3 126d48ed, notepad icons, frame strata, Recycle Bin). It has no docs/process or docs/plans in its history; other erase-scope files (e.g. roadmap, session-start summary) were not checked. |
| wip/notepad-icons | bb7a1c68 | 2026-11-02T20:42 | stale_superseded | her_delete | Paused WIP from before the rewrite: 1 commit, not on kept branches. The head is a parent of archive/2026-11-04. The 11-07 inventory says the notepad icons are on main (not re-verified here). |
| claude/frame-strata-conditions | 6736aaa0 | 2026-11-01T01:41 | stale_superseded | her_delete | From before the rewrite: 1 commit, not on kept branches. The head is a parent of archive/2026-11-04, whose ARCHIVE.md lists #125 to port. |
| claude/magical-cray-jmspwv | add39d02 | 2026-09-24T16:41 | stale_superseded | her_delete | From before the rewrite: 1 commit (Recycle Bin). The 11-07 inventory says the Recycle Bin is on main as XayaUI/RecycleBin.lua; not re-verified here. The head is a parent of archive/2026-11-04. PR #92 is closed. |

Pull refs: There are 119 refs/pull/* refs across 109 PR numbers: 109 refs/pull/N/head plus 10 refs/pull/N/merge (409 429 433 434 435 440 446 492 525 527). Method, run in a private copy (git clone --mirror of mirror.git into work-branchclassifier/copy.git): loop over each ref from `git for-each-ref 'refs/pull/*/head' --format='%(refname)'` (same for */merge). History test, which is the one that matters for the erase: `git log -1 --format=%h <ref> -- docs/process docs/plans` is non-empty when any ancestor commit touched those paths, so their blobs are reachable from that PR ref. Tip test: `git ls-tree -r --name-only <ref> -- docs/process docs/plans | head -1`. Result: 101 of 109 PR numbers contain such files (both tests agree): 363 366 367 371 373 374 384-386 389 390 392-421 423-429 431-457 459 473 488-493 496-506 518 519 523-527. All 10 merge refs are among them. The 8 clean PRs are 92 94 95 226 358 360 361 362.

I made no changes to mirror.git, the backup bundle or /home/user/XayaUI. All work ran in a private copy (git clone --mirror of mirror.git) at /tmp/claude-0/-home-user-XayaUI/15a42788-1ac6-5589-993e-20166a9f9969/scratchpad/erase/work-branchclassifier/copy.git, because merge-tree --write-tree writes objects. Patch-id sets are in kept.pids and archive.pids in that folder.

Commands used:
(1) `TZ=UTC git log -1 --format=%cd --date=format-local:%Y-%m-%dT%H:%M:%SZ <b>`, plus `git merge-base --is-ancestor <b> main`, `git rev-list --count main..<b>` (and <b>..main), `git cherry main <b>`, and `git merge-tree --write-tree main <b>` compared to `main^{tree}`.
(2) Kept-branch patch-ids: `git log --no-merges --format=%H main qa-installer-branch claude/dazzling-brown-x9fqrm claude/rule-builder | ... git show | git patch-id --stable`. Each commit from `git rev-list <b> ^main ^qa-installer-branch ^claude/dazzling-brown-x9fqrm ^claude/rule-builder` was checked against that set. The same was done for archive/*.
(3) Owner = the Claude-Session trailer on the head commit, from `git log -1 --format=%B`.
(4) Files: `git diff-tree -r --name-only` per commit. I used a conservative 'certainly erased' set: docs/process/, docs/plans/, docs/issue-screenshots/, roadmap-features/, ROADMAP.md, docs/ROADMAP.md, SESSION-START-SUMMARY.md and docs/SESSION-START-SUMMARY.md. I cannot confirm whether debug-log/ (456 paths) and docs/OPEN-ITEMS.md fall under her 'process notes and logs'.

Totals: 31 branches. 4 protected (main, qa-installer-branch, claude/dazzling-brown-x9fqrm, claude/rule-builder). 1 contained in main (claude/stat-calculator-main, the same SHA as main). 17 her_delete. 9 ask_her. 27 of 31 branches have docs/process or docs/plans somewhere in their history; the 4 without are archive/2026-11-04, frame-strata-conditions, magical-cray-jmspwv and wip/notepad-icons.

Caveats:
- The 9 her_delete branches whose heads are parents of an archive/* branch (d8-raid-rules, d8-raid-rules-main, fervent-cerf, function-audit, perf-click, perf-test-m-plus, eloquent-rubin, wip/notepad-icons, frame-strata-conditions, magical-cray) lose nothing only while that archive branch exists. Their own commits are NOT patch-equivalent on main. If she deletes the archives, that superseded work is gone for good. The archives themselves are ask_her.
- The 3 roadmap-features/{games,rppm,layout-profiles} her_delete depend on roadmap-features/combined (ask_her).
- claude/ui-bugs-focused is her_delete only because its single unique line is in docs/process/handoffs/, which SD-140 erases anyway.
- Rewriting the active branches (shopping-list, stat-calculator-v25, laughing-mendel, rule-builder, dazzling-brown) changes their SHAs under live sessions. Those sessions must re-fetch or reset, or their next push will be non-fast-forward.
- qa-installer-branch: the rewrite conflicts with her never-force-push standing rule. SD-140 names it, but confirm with her at push time.
- The 11-07 inventory said eloquent-rubin had no merge base with main. Today `git merge-base main claude/eloquent-rubin-n9zb99` returns 8b508ee7.
- The roadmap-features/ question also affects main, which itself carries roadmap-features/mplus-tools.

## Files that read erased paths (must change at the tips)
- [test_reads_file] claude/dazzling-brown-x9fqrm (e79a4c76) tests/fix_r7_docs_run.py:188 reads `docs/process/REQUEST-LOG.md via read(), and HEAD:docs/process/REQUEST-LOG.md via git show (line 205). Its read() has no exists-guard, so the whole test crashes with FileNotFoundError.`. Fix: Delete section L (lines 187 to the end of the L2 block after line 205: L0, L1, L2 on SD-52 to SD-64 status cells), or move that section to the notes repo next to REQUEST-LOG.md. The rest of the test reads only staying files. Measured: 62 checks, 0 failed before; FileNotFoundError after.
- [test_reads_file] claude/dazzling-brown-x9fqrm (e79a4c76) tests/fix_r7_docs_repair_run.py:52 reads `docs/SESSION-START-SUMMARY.md (line 52, used by check Q6 at line 138) and docs/process/REQUEST-LOG.md (line 147, checks L0 to L2). read() has no exists-guard, so it crashes at line 52.`. Fix: Line 52: read only WHATS-NEW (wn). Q6 (line 138): drop the `and ("B401 to B%d" % last) in sss` half so it checks WHATS-NEW only. Delete the L section (lines 146 to 160: L0, L1, L2) or move it to the notes repo. Measured: 19 checks, 0 failed before; FileNotFoundError after.
- [test_reads_file] claude/dazzling-brown-x9fqrm (e79a4c76) tests/fix_r9_docs_run.py:137 reads `docs/process/VERIFICATION.md (137, F2), docs/plans/R9-INFO-PANE-TOOL-PATCH-2026-11-16.md (244-245, I3 and I4; I4 applies the patch's diff), docs/process/REQUEST-LOG.md (248 SD-69 row for I3; 377 for L1; HEAD:REQUEST-LOG via git show at 388 for L2), docs/plans/R7-EUI-STUDY-2026-11-13.md (369, S1), docs/ROADMAP.md (372, S2). read() returns '' for a missing file, so these checks FAIL instead of crashing.`. Fix: Delete F2 (137-140), S1 and S2 (368-374), and L1 and L2 (376-399), or move them to the notes repo. For I3 and I4 (243-293): first carry out the info-pane entry below (apply the R9 patch to tools/build_info_pane_data.py on qa-installer-branch), then replace I3 and I4 with one check that origin/qa-installer-branch's tool contains KEEP_LANDINGS and that `build_info_pane_data.py --check` passes on this checkout. Drop the SD-69 REQUEST-LOG row from `named`. Measured: 59 checks, 0 failed before; 58 checks, 5 failed after (F2, I3, S1, S2, L1; L2 silently skipped). I4 was skipped in my copy because origin/qa-installer-branch is missing there; in the real checkout it would also fail with 'no diff in docs/plans/R9-...'.
- [test_reads_file] claude/dazzling-brown-x9fqrm (e79a4c76) tests/fix_r10_docs_run.py:134 reads `docs/process/VERIFICATION.md (134: V1-V6), docs/process/REQUEST-LOG.md (135: L1-L6 and G1-G5; HEAD: copy via git show at 200 for L7), docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md (141, used in the C1/C2 loop at 222), docs/SESSION-START-SUMMARY.md (358: M1). read() returns '' for a missing file, so the checks FAIL.`. Fix: Delete the V block (147-176), L block (178-208), M block (357-360) and G block (378-391), or move them to the notes repo. Line 141: drop `scm`. Line 222: drop the ("STAT-CALCULATOR-MAIN-INGAME-CHECKS", scm) tuple so C1/C2 check USER-GUIDE and QA B436 only. Measured: 76 checks, 0 failed before; 75 checks, 22 failed after (L7 silently skipped).
- [tool_reads_file] claude/dazzling-brown-x9fqrm (e79a4c76); depends on qa-installer-branch (236262bc) tools/build_info_pane_data.py XayaUI_Options/InfoPaneData.lua (generated) / docs/plans/R9-INFO-PANE-TOOL-PATCH-2026-11-16.md:24 reads `The only copy of the round 9 change to tools/build_info_pane_data.py (KEEP_LANDINGS / XUI_ROOT) is the ```diff block in this plan file, which is being erased. No branch has KEEP_LANDINGS under tools/. dazzling-brown's InfoPaneData.lua cannot be rebuilt without it. I checked this: QA's tool unpatched (md5 13f244261ea57c2bf690e6235645b8eb) gives 'out of date' on dazzling-brown. With the plan's diff applied (md5 becomes 9522986e98995279fdfe8ea0f97da1ae) it gives 'matches its markdown sources'. On main, the unpatched tool already matches. tests/info_pane_run.py line 30 (KEEP = 5) must also match KEEP_LANDINGS.`. Fix: Before the erase, apply the diff in that plan to tools/build_info_pane_data.py on qa-installer-branch (the base md5 matches QA's tip today) and commit it there, or copy the diff into the notes repo. Then remove the 'pending, see docs/plans/R9-INFO-PANE-TOOL-PATCH...' text from PATCH-NOTES.md line 7 (HTML comment), docs/USER-GUIDE.md line 1001, docs/HELP-FAQ.md line 7 and tests/info_pane_run.py lines 30-32, and update fix_r9_docs I3/I4 as stated above.
- [tool_reads_file] qa-installer-branch (236262bc) tools/precheck.py:249 reads `os.listdir(ROOT/debug-log) (249), crashes with FileNotFoundError once debug-log/ is gone. read_text('docs/SESSION-START-SUMMARY.md') (250) is None-safe. MOVED_DOCS (158) requires docs/ROADMAP.md and docs/SESSION-START-SUMMARY.md to exist (check_doc_paths, 174-176). The tracked-file manifest check (252) also reads MANIFEST.md5, which still lists the erased files.`. Fix: Delete lines 249-251 (the 'debug-log times' group), and check_log_times/LOG_NAME/LOGGED with them, unless the debug-log time check moves to the notes repo. Remove "ROADMAP.md" and "SESSION-START-SUMMARY.md" from MOVED_DOCS (158). Drop `debug-log/|docs/process/REQUEST-LOG-session-` from DOC_PATH_SKIP (161); that part is dead but harmless. Regenerate MANIFEST.md5 with `python3 tools/manifest.py` after the erase. Measured: before, FAILS: 1 (an existing stale-checksum error). After, a FileNotFoundError traceback. With the crash bypassed in a probe copy: 'MANIFEST.md5 lists 466 file(s) git does not track', 'docs/ROADMAP.md is not in the repository' and 'docs/SESSION-START-SUMMARY.md is not in the repository'.
- [test_reads_file] qa-installer-branch (236262bc) tests/precheck_run.py:29 reads `Does not read the files. It feeds the names into precheck functions: line 29 ('summary updated in the future', check_log_times with docs/SESSION-START-SUMMARY.md), lines 24-31 (debug-log S3 cases), line 73 (expects 2 errors because ROADMAP.md is in MOVED_DOCS) and line 74. It passes both before and after the erase, but breaks once precheck.py is fixed as above.`. Fix: Together with the precheck.py fix: delete the S3 block (lines 24-31) if check_log_times is removed. Change line 73 to expect 1 error (or use another moved name such as WHATS-NEW.md). Delete line 74 (the debug-log history case) if DOC_PATH_SKIP loses debug-log/.
- [tool_reads_file] qa-installer-branch (236262bc) tools/qa_walks_from_checklist.py:19 reads `BUGS = docs/process/qa-open-bugs.json, loaded with json.load(open(BUGS)) at line 79 (17 issues). The file is under docs/process, so it is erased and the tool crashes with FileNotFoundError. It builds the '1. Open bugs to confirm' walk (key chk-bugs, QAWalks-Checklist.lua line 10).`. Fix: This needs Xaya's call, because the file is tool input data that happens to sit under docs/process. Option A: move qa-open-bugs.json to a staying path (e.g. tools/qa-open-bugs.json) and change line 19 to match. Option B: drop the open-bugs walk (lines 79-90) and regenerate XayaUI_DevAssist/QAWalks-Checklist.lua with `python3 tools/qa_walks_from_checklist.py`. Either way, update the generated header text at lines 111-112. Measured: --check printed 'in sync: 56 walkthroughs, 554 checklist items' before and a FileNotFoundError traceback after.
- [test_reads_file] qa-installer-branch (236262bc) tests/qa_walk_run.py:206 reads `Runs tools/qa_walks_from_checklist.py --check as a subprocess, so it fails through the tool above.`. Fix: No change of its own. It passes again once qa_walks_from_checklist.py is fixed (option A or B) and QAWalks-Checklist.lua is regenerated. Measured: 51 checks, 0 failed before; 51 checks, 1 failed after.
- [tool_reads_file] qa-installer-branch (236262bc) MANIFEST.md5:1 reads `Lists 466 erased working-doc paths with their md5 (of 1174 lines). tools/precheck.py check_manifest requires an exact match. Players and the Drive copy run `md5sum -c MANIFEST.md5`, according to the tools/manifest.py docstring.`. Fix: Run `python3 tools/manifest.py` on the rewritten tip and commit the result. Note that every historical MANIFEST.md5 blob keeps the erased file names and md5s unless the rewrite also edits MANIFEST.md5 blobs.
- [tool_reads_file] origin/main (fda1e293) MANIFEST.md5:1 reads `Lists 77 erased working-doc paths (of 499 lines). There is no checker on main (no tools/), but a human `md5sum -c MANIFEST.md5` would report 77 missing files.`. Fix: Delete MANIFEST.md5 from main, as dazzling-brown already does (SD-72), or drop the 77 lines. main has no tools/manifest.py, so it can only be regenerated with qa's tool.
- [comment_or_doc_link_only] qa-installer-branch (236262bc) .claude/skills/xayaui-change/SKILL.md:8 reads `Instructions that agent sessions follow: read docs/process/VERIFICATION.md and RETROSPECTIVE.md (8), read docs/SESSION-START-SUMMARY.md first (9), write debug-log entries (14, 23), append to docs/process/REQUEST-LOG.md (33), and use SESSION-START-SUMMARY section 4 for the order (58). This is not code, but it changes behaviour: sessions would look for the erased files or recreate them on the branch.`. Fix: Rewrite these lines to point to the notes repo (the same rules location the short CLAUDE.md on main will name), or remove the skill from qa-installer-branch.
- [comment_or_doc_link_only] origin/main (fda1e293) and claude/dazzling-brown-x9fqrm (e79a4c76) XayaUI_Options/InfoPaneData.lua:13 reads `No file read. These are in-game 'Developers' notes' strings, shown in the info pane, that cite docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md: main lines 13, 19, 114, 126; dazzling-brown lines 37, 43, 156, 166, 178. They are generated from PATCH-NOTES.md (main lines 36 and 53; dazzling-brown lines 160, 173 and 190).`. Fix: Optional: reword the PATCH-NOTES.md bullets to cite QA-CHECKLIST step B436 (on dazzling-brown) instead of the plan, regenerate with the (patched) tools/build_info_pane_data.py from qa-installer-branch, and re-run tests/info_pane_run.py. If they are left as they are, players see a dead path.
- [comment_or_doc_link_only] qa-installer-branch (236262bc) XayaUI_DevAssist/QAWalks-Checklist.lua:420 reads `No file read. In-game walkthrough step text (generated from docs/QA-CHECKLIST.md) that cites REQUEST-LOG-session-*.md and docs/plans/PLATFORM-SPLIT-2026-11-07.md: 88 lines, e.g. 420, 426, 442, 642-649, 680. XayaUI_DevAssist/QAQuestions.lua lines 1039 and 1049 cite docs/plans/IDEA-CHAT-WORD-GAME-2026-11-05.md and GAMES-MODULE-2026-11-05.md.`. Fix: Optional: edit the citations in docs/QA-CHECKLIST.md (88 mentions there), then regenerate QAWalks-Checklist.lua with tools/qa_walks_from_checklist.py (after its own fix). Edit QAQuestions.lua by hand.
- [comment_or_doc_link_only] all three tips (main line 36, qa line 125, dazzling-brown line 41) tests/devassist_rename_run.py:41 reads `git grep exclude pathspecs ":!docs/process/RETROSPECTIVE.md" (all three) and ":!debug-log" (qa). It does not read the files. I verified that git grep accepts an exclude pathspec for a path that does not exist (exit 0, normal output), and on main and qa the test result is unchanged before and after.`. Fix: No change needed. Optionally drop the dead exclude pathspecs and the 'history in debug-log/ and the RETROSPECTIVE stays as written' comment.

Nothing outside the working-doc folders reads them on main. The real dependents are on qa-installer-branch (tools/precheck.py, tools/qa_walks_from_checklist.py and the tests that call them, MANIFEST.md5) and on dazzling-brown (four docs tests, plus the info-pane tool patch that exists only inside an erased plan file). Everything else only mentions the paths in comments or display text.

SCOPE AND TIPS (read-only from the mirror): origin/main = refs/heads/main = fda1e293; qa-installer-branch = 236262bc; claude/dazzling-brown-x9fqrm = e79a4c76. /home/user/XayaUI HEAD is now ahead of e79a4c76 by commits that touch only docs/process/* (REQUEST-LOG.md, handoffs/xayaui-lead*.md). That changes nothing below. I extracted each tip with `git -C mirror.git archive refs/heads/<ref> | tar -x -C work-depscan/<ref>`. All my work is under /tmp/claude-0/-home-user-XayaUI/15a42788-1ac6-5589-993e-20166a9f9969/scratchpad/erase/work-depscan/. I did not touch the mirror, the bundle or /home/user/XayaUI, and I pushed nothing.

KNOWN STARTING POINT, verified with corrections:
- fix_r9_docs_run reads REQUEST-LOG.md, VERIFICATION.md, two plans (R9-INFO-PANE-TOOL-PATCH, R7-EUI-STUDY) and docs/ROADMAP.md. Correct.
- fix_r10_docs_run and fix_r7_docs_repair_run read SESSION-START-SUMMARY. Correct, and both also read REQUEST-LOG. fix_r10 also reads VERIFICATION.md and docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md.
- Missing from the starting list: tests/fix_r7_docs_run.py reads REQUEST-LOG.md and crashes.
- All four tests exist only on dazzling-brown, not on main or qa.

NOTHING ON MAIN READS A WORKING DOC: no tools/, no .github, and no test read changes. The only items on main are MANIFEST.md5 (77 stale lines), the InfoPaneData/PATCH-NOTES display text and the harmless devassist_rename pathspec.

NOT PRESENT AT ANY OF THE THREE TIPS:
- .github/workflows/mirror-qa-branch.yml exists only in older branches; it was removed in c92f4c4f and has no docs reads.
- No .toc file, no addon Lua and nothing in tests/harness reads a working doc (WoW Lua cannot read files). The only link is generated Lua text.
- The working-doc folders hold only md/png/json/html files (main 64/8/1/1, qa 453/8/1/1, dazzling-brown 76/8/1/1). So repo walkers that look only at .lua/.py files (lua_pitfalls, fix_r10_display F, gate_common, toc_files, etc.) are unaffected.
- american_spelling_run reads git ls-files, filtered to XayaUI* folders plus a fixed list of staying docs. Unaffected.

HOW I FOUND THEM:
1. A token-aware scan: `python3 -I work-depscan/classify.py` and `strings.py` over each tip, using 557 working-doc basenames and stems taken from allpaths.txt. This separates string literals in code from comments and docstrings.
2. Manual review of every non-comment hit.
3. Empirical before/after runs. I made git copies of each tip, `git rm` of docs/process, docs/plans, docs/issue-screenshots, debug-log, docs/SESSION-START-SUMMARY.md, docs/ROADMAP.md and docs/design/*AUDIT* (89 files on dazzling-brown, 77 on main, 466 on qa), then ran tests with exp/runtests.sh and exp/runlist.sh.

Results of the runs:
- dazzling-brown: all 256 *_run.py were run on the erased copy; the 27 that failed were re-run on the before copy. Only fix_r7_docs, fix_r7_docs_repair, fix_r9_docs and fix_r10_docs go from pass to fail. The other 23 fail identically before and after; these failures are from the environment and existed already.
- 7 tests timed out at 600 s both before and after, so I cannot confirm them empirically: gate_performance, gate_keyboard, gate_mouse, fix_r8_gate_scenario, fix_r9_gate_scenario, fix_r10_gate_bonus, fix_r10_display. Statically, none of them reads docs.
- main: the 47 tests that touch docs, git, os.walk or MANIFEST were run before and after. No differences.
- qa: the 71 candidate tests were run before and after. Only qa_walk_run changed (0 failed to 1 failed); two others differed only in timing.
- `python3 tools/precheck.py` on qa: FAILS: 1 before (an existing stale checksum on docs/plans/STAT-CALCULATOR-V25-TRACKER.md), a FileNotFoundError on debug-log/ after.
- `python3 tools/qa_walks_from_checklist.py --check` on qa: 'in sync' before, a FileNotFoundError on docs/process/qa-open-bugs.json after.

INFO PANE BUILDER (tools/build_info_pane_data.py, on qa only): it reads only PATCH-NOTES.md, docs/README-INGAME.md and docs/HELP-FAQ.md, all of which stay. Its round 9 patch, however, lives only in a doc that is being erased. See the dependents list. Checked with: unpatched tool --check on copies (main matches, dazzling-brown out of date), then `patch -p1` with the diff extracted from the plan (dazzling-brown matches), plus `git grep KEEP_LANDINGS <every head> -- tools` (no hits).

COMMENT/DOC-LINK-ONLY COUNTS, as path or filename mentions outside the working-doc folders (from classify.py; `tsv col3 != code/string`):
- main: 198 lines in 71 files. MANIFEST.md5 77; addon Lua/toc comments 36; tests docstrings/comments 52; staying docs 31; PATCH-NOTES 2. Examples: XayaUI_Rules/Combat/AuraModel.lua:30 '-- (core 0.6.74; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.4)'; tests/aura_gaps_run.py:1 docstring '(docs/process/RETROSPECTIVE.md)'; XayaUI_Rules/Editor/ShelvedElements.lua:5.
- qa-installer-branch: 666 lines in 126 files. MANIFEST.md5 466; addon Lua/toc 82; tests 71; staying docs 31; .claude 9; tools 5; README.md 1 (line 55, debug-log/). Examples: XayaUI_DevAssist/QAWalk.lua:22 '-- ... docs/plans/PLATFORM-SPLIT-2026-11-07.md section 15'; tests/char_stat_tooltip_lines_run.py:4 'docs/process/REQUEST-LOG.md section A24'.
- dazzling-brown: 167 lines in 104 files. Addon Lua 41; tests 86; staying docs 36; PATCH-NOTES 4. Examples: XayaUI_Options/ScopeEditor.lua:3; tests/key_review_run.py:3 'docs/process/REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md row 56'; tests/memory_report_run.py:9.
- Bare stems without a path (e.g. 'REQUEST-LOG A23') add more. A broad grep over *.py/*.lua/*.toc/*.sh gives 308 / 591 / 572 lines for main / qa / dazzling-brown, and these are almost all comments.
- Staying docs that cite erased paths: QA-CHECKLIST.md (88 on main and qa, 92 on dazzling-brown), DISPLAY-RULINGS.md 7, USER-GUIDE.md 4-5, DISPLAY-RULES.md 2, docs/reference/README.md 1, HOVER-REWRITES 1, docs/reference/build_content.py:5 (comment).
- If someone cleans up these staying-doc citations, watch for coupling: fix_r9 I3 requires the R9 plan path to stay in USER-GUIDE, HELP-FAQ and info_pane_run text that names the tool, and QAWalks-Checklist.lua must be regenerated after any QA-CHECKLIST edit.

FOR THE HISTORY REWRITE (I cannot confirm intent here): every historical MANIFEST.md5 blob, and the comments above, keep the erased file names, including the REQUEST-LOG-session-<id> names, even after the files themselves are removed. Removing the names too would need a blob/text rewrite of MANIFEST.md5 and the comments, not just a path filter.

## Completeness check, execution order and questions for Xaya (verbatim from the critic)

COMPLETENESS CRITIC: SD-140 full erase. Summary: it is NOT safe to run yet.

Nothing was pushed or changed in mirror.git, the backup bundle or /home/user/XayaUI.
- Mirror refs equal work-rehearse/refs-before.txt (`diff -q` passed).
- The bundle is still 18794154 bytes, timestamp 19:34:47.
- `git status --short` in /home/user/XayaUI prints nothing.

My files are in /tmp/claude-0/-home-user-XayaUI/15a42788-1ac6-5589-993e-20166a9f9969/scratchpad/erase/work-critic/:
- issues.tsv, issues-p*.json, icomments-p*.json: GitHub issue, PR and comment dumps.
- remote-now.txt: live refs from `git ls-remote origin`.
- new-paths.txt
- live.git: a fresh fetch of the live heads plus PRs #528 and #529. It borrows the mirror's objects through an alternates file and only reads them.

== A. GAPS FOUND (verified), each with the command I ran ==

A1. The mirror is already out of date, and sessions pushed working docs within the last hour.
Command: `git -C /home/user/XayaUI ls-remote origin > remote-now.txt`, then diffed against `git -C mirror.git for-each-ref`. Changes since the mirror was taken:
- 2 new branches: claude/bold-cerf-17je6r (0aaf3a02) and claude/lucid-mayer-pv4ytn (66dfbc3d).
- 2 new PRs: #528 and #529, each with a head and a merge ref.
- 4 heads moved: dazzling-brown e79a4c76→127a97b2, laughing-mendel d4693763→93c1478d, rule-builder 699e19fd→9edf1ece, stat-calculator-v25 59583dbc→ad4cdc0c.
`git log <old>..<new> --name-only` in live.git shows that all the new commits (20:14 to 20:23 UTC) touch only docs/process/handoffs/*, docs/process/REQUEST-LOG.md, docs/process/BRANCHES-2026-11-08.md and MANIFEST.md5. These are the "hub merge" handoffs.
Consequence: the rehearsal result (new SHAs, 31 heads) is stale. The real run must start from a fresh mirror taken after a freeze, and every check must be run again.

A2. The file-by-file docs/process list already misses a new file.
Command: `comm -23 live-tip-paths.txt allpaths-orig.txt`, then `match.py paths.txt new-paths.txt in`.
- 8 paths are new today. 7 are under docs/process/handoffs/ and are caught by the prefix.
- docs/process/BRANCHES-2026-11-08.md is NOT matched, so it would survive the erase.
Fix: move docs/process/qa-open-bugs.json to a staying path such as tools/ on the qa tip first. Then erase docs/process/ as one prefix. Rebuild the path list from the fresh mirror and diff it again.

A3. GitHub rulesets block the force-push on main, including for Xaya.
Commands: `gh api repos/heyitsxaya/XayaUI/rulesets/<id>` and `gh api repos/heyitsxaya/XayaUI/rules/branches/<b>`.
- "keep QA safe": targets ~DEFAULT_BRANCH, which is main, not QA. Rules: deletion and non_fast_forward. bypass_actors is empty, so nobody can force-push main while it is active.
- "keep it safe": targets refs/heads/main. Rules: deletion, non_fast_forward and update. It can be bypassed by RepositoryRole 5 (admin) and by Integration 1236702. I cannot confirm which app that integration is.
- qa-installer-branch has NO rules (the rules call returned []). The ruleset named for QA actually protects main.
So Xaya must disable "keep QA safe" for the push window and then turn it back on.

A4. The Claude cloud git proxy.
- The earlier branch delete was refused with HTTP 403 (from the task).
- I could not test a force-push without pushing, so I cannot confirm whether the proxy allows non-fast-forward pushes.
- The same proxy blocks the Actions API: `gh api .../actions/caches` returned "Access to this GitHub Actions path is not permitted through this proxy" (403). GraphQL is blocked too.
Branch deletes must be done by Xaya in the GitHub web page. Whether Claude can do the force-push is unproven. The fallback is that Xaya pushes from her own computer using a bundle Claude hands her.

A5. GitHub content outside git that holds the same material. A path erase does not touch any of it.
Commands: `gh api "repos/heyitsxaya/XayaUI/issues?state=all&per_page=100&page=N"` for N = 1 to 6, `issues/comments` and `pulls/comments`, then a Python regex scan. (`--paginate` breaks on this proxy because it uses the numeric-ID path.)
- 525 items: 414 issues and 111 PRs. All are authored by heyitsxaya. Plus 292 issue comments and 0 review comments.
- 233 bodies (110 PRs, 123 issues) and 48 comments name REQUEST-LOG, SESSION-START, ROADMAP, debug-log/, docs/process, docs/plans, handoff or session ids. In total, 216 session ids appear in bodies.
- 10 issues link erased files by URL: #368-370, #375, #377-381, #387.
- Issues tagged [Roadmap] (10), [Process] (6) and [Decision] (11) hold roadmap, process and decision text directly. Example: #517 "[Roadmap] Parked ideas and shelved features".
- There are 0 commit URLs and 0 uploaded attachments in this text.

A6. Other places checked.
- Tags: 0. Command: `grep -c refs/tags remote-now.txt`; the mirror also has none.
- Releases: 0. Command: `gh api .../releases`.
- Actions artifacts: total_count 0.
- Forks: forks_count 0 and `/forks` is empty. But allow_forking is true and the repo is public, so outside clones cannot be ruled out.
- Discussions: `gh api .../discussions` returned 0.
- Wiki: has_wiki is true, but `git ls-remote https://github.com/heyitsxaya/XayaUI.wiki.git` needs a login. I cannot confirm whether the wiki has content.
- Actions caches and old workflow-run logs (.github/workflows/mirror-qa-branch.yml existed in history): blocked (403), so I cannot confirm them.
- LFS: none. `git log --all -S'filter=lfs' -- .gitattributes` is empty.
- No .gitmodules.

A7. Sessions and clones that could push old history back.
Command: `git log --since=2026-11-14T00:00Z --format=%B <b> | grep -o session_...` in live.git, plus list_sessions. Recent commits by session:

| Branch | Session | Commits | Last commit (UTC) |
|---|---|---|---|
| claude/dazzling-brown-x9fqrm | session_014bN6tVBGo8BHkHu65TAcjD (this lead, still running) | 44 | 20:23 |
| claude/bold-cerf-17je6r | session_014bN6tWYS45jH9wSdj2RSxM | 2 | 20:15 |
| claude/lucid-mayer-pv4ytn | session_014bN6tWwZM5hKvbZkMFd4zN | 2 | 20:15 |
| claude/stat-calculator-v25 | session_014bN6tUmdW8ddPT74JogMYj | 14 | 20:15 |
| claude/rule-builder | session_014bN6tSvaDBEe8dCKeMYcgo | 3 | 20:15 |
| claude/laughing-mendel-9lems1 | session_014bN6tV7FhZNb6e8ToFNJQU | 2 | 20:14 |
| claude/shopping-list-auto-detect-ieb029 | session_014bN6tWKcNdrDgUBzRK3BUh | 4 | 18:41 |

- list_sessions shows all of those except the lead as ARCHIVED, so their containers and clones are gone. Unarchiving one before the rewrite would bring an old clone back.
- Still live: this lead session (its /home/user/XayaUI holds the full old history), and session_014bN6tTsXBFsDnGDauvbrLf, a "bridge" / remote-control-app session that is BLOCKED. That session runs on Xaya's own computer. I cannot confirm whether it has a XayaUI clone.
- Xaya's own computer and any GitHub Desktop clone: I cannot confirm.
- Any clone made before the rewrite that pushes to ANY branch name, including a new one, uploads the erased blobs again.

A8. Bundle 1 can land by fast-forward, but only if branches are rewritten together.
Command: `git -C work-rehearse/rewrite.git merge-base --is-ancestor A B`.
- After the single-run rewrite: main is an ancestor of dazzling-brown (behind 0), qa is an ancestor of shopping-list, and main is an ancestor of laughing-mendel.
- rule-builder is a fast-forward of neither main nor dazzling-brown, before or after the rewrite.
- So a fast-forward only works if main and dazzling-brown are rewritten in the SAME filter-repo run, from the same fresh mirror.
- dazzling-brown's 4 newest commits are docs-only and will be dropped as empty.
- Landing on main needs Xaya, because of the "update" rule.
- The 4 fix_r* docs tests still read erased files. They must be changed on dazzling-brown before it lands.

A9. The QA "retired" rule. VERIFICATION.md V30 on dazzling-brown says retired features on qa-installer-branch are "not touched unless she assigns it". The follow-up changes on QA therefore each need Xaya's assignment:
- tools/precheck.py
- tools/qa_walks_from_checklist.py plus regenerating QAWalks-Checklist.lua
- tests/precheck_run.py
- MANIFEST.md5 regeneration
- the .claude SKILL.md
- the R9 patch to tools/build_info_pane_data.py
- QAQuestions.lua
The one-time force-push exception for main and QA is already recorded in SD-140 (REQUEST-LOG.md:817: "a one-time exception to 'never force-push main / qa-installer-branch'").

A10. SD-140's own order requires an archive first: a full backup plus a private repo with the files' history, and that repo "must be created by her". I cannot confirm that the private repo exists.
- SD-141 put bundles of main and QA on Google Drive, folder id 1dTTNZIZlSNS-c-TVp7H9iaArm8TE-5-c. Those bundles contain the erased files, which is fine because they are private.
- notes.git from main and dazzling-brown misses 84 erased paths. notes-allheads.git has all 633, but neither includes today's new pushes.

A11. Names that stay behind:
- Every commit keeps its Claude-Session trailer.
- Commit subjects name docs (for example "Log SD-141 ...").
- filter-repo --sensitive-data-removal does not change commit messages. --replace-message could, if she wants it.

== B. ORDERED EXECUTION PLAN ==

1. **Xaya: answer the questions in section C.**
   - Check: the answers are logged under SD-140.

2. **Xaya: create the private notes repo. Claude: push the archive to it.**
   - Claude builds the archive from a fresh all-heads extract that includes today's pushes, and also copies the R9 patch and the debug-log terms note.
   - Check: `git ls-remote` on the private repo, and a path count of all erased paths compared with the extract.

3. **Xaya: stop new work.** No new XayaUI sessions; do not unarchive or resume any. The lead session stops pushing working docs. Hold the "hub merge" handoffs or send them to the private repo.
   - Check: Claude runs `git ls-remote origin` twice, 30 minutes apart, and the output is identical. list_sessions shows no running XayaUI session except the lead.

4. **Claude: prepare the fix commits on the live branches.** Nothing lands without Xaya's OK.
   - On dazzling-brown: the fix_r7, fix_r7_repair, fix_r9 and fix_r10 docs tests; the short CLAUDE.md; drop MANIFEST.md5.
   - On qa-installer-branch, only if she assigns it (V30): apply the R9 patch; fix precheck.py and precheck_run.py; move qa-open-bugs.json and point qa_walks_from_checklist.py at it, then regenerate; edit SKILL.md; regenerate MANIFEST.
   - Remove the links in kept docs that point to erased files (USER-GUIDE → IN-GAME-DATA, PATCH-NOTES/HELP-FAQ/README-INGAME → R9, and the others).
   - Check: tests pass before and after on copies with the files erased, using the same method as the deps scan.

5. **Xaya: land bundle 1 on main by fast-forward, and the QA fixes on QA.**
   - Check: `git merge-base --is-ancestor origin/main origin/claude/dazzling-brown-x9fqrm` before the merge, and that main equals the dazzling-brown SHA after.

6. **Xaya: delete the stale branches in the GitHub web page** (the her_delete list plus her answers on the ask_her branches and the 2 new handoff branches). Close or edit the PRs she wants gone.
   - Check: Claude runs `git ls-remote --heads origin` and compares it with the agreed keep list.

7. **Claude: take a new mirror clone and a new backup bundle.** Rebuild the full path list with ls-tree over every commit, not allpaths.txt. Regenerate paths.txt: use the docs/process/ and roadmap-features/ prefixes, and decide each new path.
   - Check: every path in the list matches at least one real path, and no new path in docs/process, docs/plans or debug-log/ is left unmatched.

8. **Claude: run filter-repo in a copy.** Command: `--sensitive-data-removal --no-fetch --invert-paths --paths-from-file`, in ONE run over all kept heads. Then regenerate MANIFEST.md5 at the tips if it still exists.
   - Check: 0 erased paths in any commit; tip diffs are deletions only; main is still an ancestor of dazzling-brown and qa of shopping-list; the tests from step 4 pass at the rewritten tips. Save first-changed-commits.

9. **Xaya: disable the "keep QA safe" ruleset**, and "keep it safe" too unless she relies on her admin bypass. Confirm the one-time force-push of main and QA.
   - Check: Claude reads the ruleset enforcement with `gh api`.

10. **Push only the kept heads**, one explicit force refspec each (`git push --force origin refs/heads/<b>:refs/heads/<b>`). Never `--mirror`; remove remote.origin.mirror first. The pusher is Claude only if the proxy allows non-fast-forward pushes; otherwise Xaya pushes from her computer using a bundle Claude hands her.
    - Check: `git ls-remote origin` heads equal the rewritten SHAs, and a fresh clone has 0 erased paths in any commit.

11. **Xaya: turn both rulesets back on.** Optionally retarget a ruleset at qa-installer-branch.
    - Check: `gh api .../rules/branches/main` and `.../qa-installer-branch`.

12. **Xaya: contact GitHub Support.** Ask them to remove the refs/pull/* records (113 refs as of now) and the cached views and unreachable objects, giving them the first-changed commits. She also deletes old Actions runs and logs and checks the wiki, both of which Claude cannot reach.
    - Check: Support's reply, then `git ls-remote origin 'refs/pull/*'`, which should be empty or only show new PRs.

13. **Claude: discard every old clone and re-clone.** That means this lead's /home/user/XayaUI, any clone on her computer, and nothing restarted from before the rewrite. Keep the old mirror and bundle only privately, until she says to delete them.
    - Check: `git ls-remote` stays stable over the next sessions' pushes, and a new grep of all heads finds 0 erased paths.

14. **Xaya: issues and PR text, separately** (see the question about issue and PR text). Edit or delete as she chooses.

== C. QUESTIONS FOR XAYA (plain language) ==

1. Have you already made the private repository for these notes? Nothing can be erased until they are safely copied there.
2. Several Claude helpers saved hand-over notes to GitHub in the last hour, for a "hub merge". Should those notes go to the private repository instead, and should all XayaUI sessions stay paused until the erase is finished?
3. A new note, a branch cleanup list from today, sits in the process folder and would have slipped through. Is it OK to erase the whole process folder at once, after moving the small "open bugs" list (which the testers' tool needs) to the tools folder?
4. Your GitHub safety settings block anyone, you included, from overwriting main. For the few minutes of the erase, will you switch off the setting called "keep QA safe" and switch it back on right after? Also, that setting protects main, not the QA branch. Do you want a setting that really protects the QA branch?
5. Claude's connection to GitHub has refused to delete branches before. It may also refuse the overwrite. If it does, are you OK running a short prepared command from your own computer, or should Claude try once on a throwaway branch first? A test like that is a push, so it needs your OK.
6. The QA branch follows your "retired, don't touch unless assigned" rule. Do you assign the small fixes there: the checker tool, the testers' walk tool, the info-pane tool patch, the checksum list and the old Claude skill file?
7. Your GitHub issues and pull request descriptions repeat much of the same text. 233 of them, plus 48 comments, mention the request logs, plans, roadmap or session names. There are also 10 roadmap issues, 6 process issues and 11 decision issues. The erase cannot reach these. Leave them, edit them, or delete some?
8. Every saved change still carries its Claude session label, and some change titles mention the notes. Is that acceptable, or should the change titles be cleaned too? That is extra work and risk.
9. Two new branches from today (a daily status check and a session cleanup check) hold only notes. Delete them along with the other stale branches?
10. Do you have a copy of XayaUI on your own computer, for example in GitHub Desktop? After the erase it must be thrown away and downloaded fresh, or it could put the old notes back.
11. Does the project have a GitHub wiki with pages in it? I could not check.

== D. CANNOT CONFIRM ==
- Whether the proxy accepts a force-push.
- Actions caches and old run logs.
- Wiki contents.
- Which app Integration 1236702 is.
- Whether outside clones exist. The repo is public, so this cannot be known.
- Whether the bridge session on Xaya's computer holds a XayaUI clone.
- GitHub Support's exact timing and scope for removing the refs/pull records.
