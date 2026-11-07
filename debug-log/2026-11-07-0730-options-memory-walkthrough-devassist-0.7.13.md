# Settings window memory check: walkthrough J19 (XayaUI Dev Assist 0.7.13)
Session 014bN6tTxYo6enpkMGsVkMqm, branch `claude/perf-options-memory` (from `claude/perf-test-m-plus-land` 036c7fd). Logged 2026-11-07
07:30 UTC. Nothing here has run in the game.

## Request (REQUEST-LOG A15 P-7, P-8)
- Her screenshot (no text): the AddOn usage tooltip with "Memory: 679.0 MB total", "380.8 MB XayaUI_Options", "56.9 MB XayaUI".
  380.8 / 679.0 = 0.561, so the settings addon held 56% of all addon memory at that moment.
- Her answers: context "Not sure"; next step "Quick check + fix (Recommended)": measure first, then propose the fix (V16).

## What the code says (INFERENCE until measured)
- XayaUI_Options/Options.lua (comment above `Tree.Get`, around line 308): "Every redraw of the window builds the whole tree (every rule,
  in several lists): 0.44-0.64 s of Lua with 229 rules in the test harness, and a click on a switch redraws at least once".
  `Tree.Get` keeps only the newest tree (`Tree.last`), so older trees are garbage until Lua collects them. The harness reports 2747
  option nodes per build in the all-addons combination.
- GetAddOnMemoryUsage most likely counts garbage not yet collected (INFERENCE). If it does, 380.8 MB may be mostly leftover trees,
  not memory the addon keeps. One screenshot cannot tell the two apart; J19 can.

## API (V2, docs/reference/api/api.json 12.1.5; no documentation text)
- `UpdateAddOnMemoryUsage()`: no returns. `GetAddOnMemoryUsage(name: uiAddon) -> result: number` [SecretArguments=AllowedWhenUntainted].
- `C_AddOns.IsAddOnLoaded(name: uiAddon) -> loadedOrLoading: bool, loaded: bool` [SecretArguments=AllowedWhenUntainted].
- `collectgarbage` is Lua's own (not in the index). INFERENCE: "count" and "collect" are allowed for addons; both are pcall'd.

## Change
- `XayaUI_DevAssist/QAWalks-perf.lua`: walkthrough "Performance: settings window memory (J19)", prefill = true, 5 steps:
  1. after /reload, settings addon not loaded (Pass only if not loaded); 2. window used; 3. closed 30 s; 4. "Do it for me" = full
  cleanup, then reading; 5. summary: leftover garbage = 3 - 4, kept = 4, all Lua memory at each reading. Readings kept in
  XayaUIDevAssistDB.qa.optionsMem; the summary is in the step note and the QA result code.
- QA J19; walkthroughs regenerated; Dev Assist 0.7.13.

## Tests (V1)
- `tests/qa_perf_walks_run.py` +9 checks (30 total): each J19 step tried in the right and wrong state; the summary's arithmetic
  (300.0 MB used, 250.0 MB freed by the cleanup, 50.0 MB kept) on stand-in numbers.

## Next
- Her J19 summary decides the fix (proposed to her first): leftover garbage -> fewer full tree builds (reuse the tree when the change
  does not need a new one; build only the open branch); kept -> find what holds it.
