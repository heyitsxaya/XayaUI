# In-game QA walkthrough for the Generate buttons, filtered list and Select all (Dev Assist 0.7.13, Options 0.6.64)

Logged 2026-11-07 08:31 UTC. Session 014bN6tTRFsCmBvVCUDVtrds, branch `claude/generate-buttons-qa-walk` (from main 7b830cf). NOT on `main` yet: goes to the lander (session 014bN6tSZh6UFB2WcRuyXqBZ). UNTESTED in game.
Request log: REQUEST-LOG-session-014bN6tTRFsCmBvVCUDVtrds.md GEN-1 to GEN-4 (the feature, on main 687b624), GEN-5 to GEN-8 (the relayed orders below).
Version note: Dev Assist 0.7.13 follows 0.7.12 on main, Options 0.6.64 follows 0.6.63; the lander may renumber at landing.

## Why
Standing rule V22 (Xaya, 2026-11-07, her words, docs/process/VERIFICATION.md): "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing". The Generate buttons (Options 0.6.54, on main 687b624) landed before the rule and had only the checklist walk generated from QA B160. This is the hand-written walkthrough with prefill. The overnight order relayed by the 11-06 hub (2026-11-07 ~08:25 UTC, relayed, not seen by this session): every change needs a V22 walkthrough with prefill.

## What was added (code: Dev Assist only)
- `XayaUI_DevAssist/QAWalks-generate.lua`: walkthrough id `auto-generate-buttons`, QA B160 / B151 / B152, order 265, prefill = true, 12 steps. She presses the real buttons; each check reads what the picker lists (ns.AutoPicker.view) and offers its verdict on "Accept".
  1. Do it for me: opens Rules > Auto-Generate Rules, closes any list. Check: no list; 4 buttons per spec + 4 "for my class" on screen with the exact labels (compared with `AP.ButtonLabel`), none saying Auto-populate.
  2-5. CD / Aura / Target Debuff / All for the current spec: filter and kinds listed.
  6. Select all ticked: the tick box named "Select all" is on screen and every row is ticked. 7. unticked. 8. Aura list + Select all: aura rows ticked, the cooldowns and debuffs not shown stay unticked.
  9. Another spec's Aura button: the learned auras (C1) or no rows and the "Switch to <Spec>" message.
  10. Class buttons: class-wide CD list from two or more specs.
  11. A question (noVerdict): captures every Generate button's width and its text width, and the window width, into the note; asks about cut-off labels, wrapping, the header tick box and the title.
  12. Do it for me: unticks every pick of every spec and closes the list.
- `XayaUI_DevAssist.toc`: the file is listed; Version 0.7.12 -> 0.7.13.
- tests/qa_walks_generate_run.py (new, 32 checks).

## V4 scope (git grep)
`XayaUI_DevQA.Register` callers: QAWalks*.lua (all unchanged). The toc load order: the new file after QAWalks-display.lua (it needs XayaUI_DevQA from QAWalk.lua, loaded earlier). It reads the picker through `ns.OptionsApi.AutoPicker` (FILTERS, ButtonLabel, Load, Close, view, AllTicked, TickAll, Choice, SetChoice, BuildRows, NoneText, SpecName), all existing on main.

## Found by the full suite, fixed (Options 0.6.64)
The first full-suite run (commit 90c7c04) failed ONE check, the harness's boundary rule: "FAIL static: XayaUI_DevAssist/QAWalks-generate.lua:19 (XayaUI_DevAssist) uses ns.AutoPicker, which belongs to XayaUI_Options; go through Modules.lua instead" (tests/harness/run.py boundary_checks: an addon may read only core's names and what another addon publishes, PUBLISHED = Options, OptionsApi). The targeted tests (tests/qa_walks_generate_run.py 32/32, auto_picker_run.py) had passed: they do not run that rule. Fix: XayaUI_Options/Options.lua publishes the picker as `ns.OptionsApi.AutoPicker` right after `ns.OptionsApi = {}` (AutoPicker.lua loads before Options.lua, so the line sits there); the walkthrough reads it from there; the harness rule is NOT loosened. Options 0.6.63 -> 0.6.64. Runtime: one table field set at load; nothing else. New check in tests/qa_walks_generate_run.py: the picker is published as ns.OptionsApi.AutoPicker. `boundary_checks` alone: no findings after the fix; the full suite is rerun on the fix commit.
Runtime (CLEAN-8): Dev Assist only; the walkthrough is registered at load (one table), runs only when /xui dev qa is opened and a step is started; no event, OnUpdate, timer, hook or saved-variable field. V14: Dev Assist is the developer addon (loaded on demand by the player's choice).

## Tests (V1, V11)
tests/qa_walks_generate_run.py: 32 checks on the real addons in the stand-in game: registration (prefill, every step has a check or is a question); step 1 with a list open (refuses), after Do it for me (passes), and with a button renamed to "Auto-populate Havoc" (fails); steps 2-5 with the right and the wrong list (negative controls); Select all not ticked / ticked / unticked / ticked on the wrong rows; another spec with and without a learned aura; the class lists; step 11 no verdict; step 12 before and after. Negative control: without QAWalks-generate.lua the test fails (the walkthrough is not registered), as on main 7b830cf. Limit: the buttons' real clicks are emulated by calling the picker's own `AP.Load` and redrawing the window, as a click does.

## Relayed orders logged (she did not write them to this session; relayed by other sessions, unverified by this one)
See REQUEST-LOG-session-014bN6tTRFsCmBvVCUDVtrds.md GEN-5 to GEN-8. Effect here: no questions to her (the five open ones went to the question flow, session 014bN6tUZLKHa2NXorHRJghL, with their defaults); finished work goes to the lander, not pushed to main by this session.
