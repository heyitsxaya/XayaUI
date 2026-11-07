# Good morning, Xaya: overnight summary (2026-11-07)

Written by the overnight hub (session_014bN6tWMaSvKkwjeonHvvch). Main code = **f81561d** (the last push that changed code; anything after it is docs only; every push passed the full test suite, the Lua pitfall check and precheck on its exact commit). Details: docs/process/OVERNIGHT-STATUS-2026-11-07.md.

## What's missing or wrong (read first)

1. **Nothing has been tested in the game.** Every item below passed the automated suite (33 add-on combinations each push), and none of it has been seen in WoW yet. The review popup lists everything to check.
2. **Held on purpose (your O-109):** all of D8 raid rules is the load-condition change, so none of it is on main. It is on `claude/d8-raid-rules-ready` (code 91e8701, draft PR #446 [HELD]), full suite PASS. It is question **D8-Q1**, first in the flow. Answer "release" and it can land.
3. **Not built, waiting on your answers** (each is a question in the flow):
   - Nameplates: Aura Reorder (NP-Q5) and the later slices.
   - Reskins: micro menu / bag bar / calendar + mail icons (RSK-Q14); close buttons / tabs / scroll bars / dropdowns (RSK-Q15); combat HUD (RSK-Q4, held: taint risk); skyriding (RSK-Q6). The shop can't be reskinned. Older-expansion windows weren't in your lists.
   - Function audit: 55 of 58 rows fixed; D29, D30, D33 wait on you.
   - Character pane: B8 meaning unclear; #73 "narcissus addon" isn't in your Drive (and we never copy other addons); B7 / B11 / B14 left as they are.
   - Display audit (UI-47 step 3): no fix your rulings settle by themselves; 7 gaps are questions Q-UIB-9..15.
   - UI-32 (Voice sound tab) and UI-41 (nested-group button placement, waits for your screenshots).
4. **Not built by choice:**
   - LFG / Wordle / RPPM: paused by your words ("Pause on all of this until further notice"). RMG-Q0 asks lift / keep paused.
   - Roadmap items (RM-GSEARCH, Raid Tools, M+ Tools, layouts): you asked for roadmap entries only. R24 (right-side cue panel, from 11-04) and R62 (objective pane reskin, 11-05) are older than your 16-hour window: questions S3-Q13 / S3-Q14. C3 and RM-LAYOUTS stay deferred to next week, as you said.
5. **Performance target not proven:** a settings-window click went from ~1.7 s to ~0.10-0.20 s in a stand-in with your 313 rules. Your target is under 0.1 s. Walkthrough J31 measures it in game (Q-PERF-5, Q-PERF-8). First open: ~2.1-2.5 s → 0.83 s (target < 1 s, met in the stand-in).
6. **Small decisions for you:** LibStub ships 4 unused self-test files (harmless; delete or keep). Patch notes have no entries for Bonus 0.6.28 and QoL 0.7.43-0.7.45 beyond the hover rewrites.
7. **Branches for you to delete (O-151):** docs/process/BRANCHES-2026-11-07.md (final refresh against main f81561d, ~14:10 UTC) lists **66 branches** that are fully in main (53) or stale (13), with one delete line each. Run `git fetch --prune` first. Each line is `git push origin --force-with-lease=refs/heads/<name>:<sha> :refs/heads/<name>`, so it refuses any branch that moved after the list was written. Six of the stale ones (function-audit, perf-click, perf-test-m-plus, d8-raid-rules, d8-raid-rules-main, fervent-cerf-hldtwn) were redone under new commits, so git can't prove them contained; their heads are kept in `archive/2026-11-07`, so deleting loses nothing. `claude/adoring-hawking-wyda59` has one docs commit whose file is already on main word for word, so it is safe to delete too. **Keep:** `claude/d8-raid-rules-ready` (held, O-109), `roadmap-features/combined`, `archive/*`, `qa-installer-branch`. Branches with code not on main and not held: **none**.

## What landed overnight (main 7b830cf → f81561d)

- **QA review popup + question flow** (your O-150): on first load it lists **148 walkthroughs** (all of them, because you haven't acknowledged a build yet) and **207 questions**, D8-Q1 first. "Don't show again until the next update" limits later loads to what's new.
- Settings window: top tabs Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings; "+ New Rule" at the left of the Rules row; Profiles = Import / Export / Recycle Bin (UI-23..27); "Blizzard UI Reskin" renamed "Blizzard Reskin" everywhere you read it.
- Performance: load-first, log gate, error handler, engine churn, one build per Options open, click builds only the open rule editor, tooltip memory (O-129/130/133/135/145/147/149).
- Chat: Chat Panel (look) / Improved Chat (behaviour) split, input line, sidebar, icons fade with the chat (O-143), friend class colours, whisper fixes (#439).
- UI bugs: icon columns, Auto-Generate icon, Rules sub-tabs 4% smaller / narrower (O-146), flat console buttons + Shopping List auto-show (O-139), "Select string" (O-128), shorter hovers (UI-65), shared tooltip helper.
- Function audit: 55 fixes (Notepad, launcher list O-100, settings window, QoL, Bonus).
- Externals in combat (O-142): hidden-aura status text, same-name buff IDs, a guard, walkthrough J26.
- Nameplates: new add-on XayaUI_Nameplates 0.2.1 (off by default): Current Target Color, "Match my Plater settings" (12 Blizzard nameplate options, with a Put back button).
- Reskins: 33 Blizzard windows, minimap Square / Circle, tooltips, objective tracker, toasts and pop-ups, loot rolls, menus, chat bubbles (with a repaint guard), status bars, minimap buttons, panel buttons.
- Character pane Stat Calculator round, bar-cue walkthrough, Generate-buttons walkthrough, group page / mover view walkthroughs, overnight Patch Notes entry.
- Safety: a test that every add-on's .toc lists its files (a merge had dropped Whispers.lua; caught and fixed); a test-harness fix that made suites take minutes instead of an hour.

## Sessions

- Archived (all work on main or recorded in a handoff file): 20.
- Still open: the lander; the QA flow (owns the questions); feature summary (your V18 notes); perf successor (owns PERF-CODE-NOTES); UI bugs successor; reskin successor (waits on RSK-Q11..Q15); branch cleanup.

## Counts used above (sources)

- 148 walkthroughs and 207 questions: the QA flow session's static count on the merged tree at 14:00 UTC (unique QA.Register ids across the 18 QAWalks files; 47 generated from the checklist).
- Performance numbers: the perf sessions' stand-in harness with your 313-rule shape, not in-game measurements.
