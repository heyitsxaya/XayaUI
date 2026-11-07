# Brief hover texts (UI-65): core 0.6.70, Options 0.6.71, QoL 0.7.44, Chat 0.6.34, Bonus 0.6.26, Reskin 0.6.8, Dev Assist 0.7.22
Session 014bN6tV7oStjTuVPEJbytBJ. Nothing here has run in the game.

## Request
UI-65 (her words): "Reiterating need for briefer, more direct, more user-legible tooltips" [Discord: Insivius "this tooltip is
hilarious" / "It's just very wordy" on the Enable Chat Panel hover]. Rule: BUILD-RULES section B (title + up to two sentences).

## Change
- Every option's hover text across core, Options, QoL, Chat, Bonus, Reskin and Dev Assist (Bonus Notepad.lua left out: the
  function-audit session owns it) rewritten to at most two short sentences: what that one control changes, then at most one limit.
- Done by a background agent (189 texts; old -> new list kept in docs/reference/HOVER-REWRITES-UI-65-2026-11-07.md), then reviewed
  here. Ten more texts it left over two sentences were shortened by hand (Calculator, Data Panels, Tooltips master switch, four in
  Options.lua, OutcomesEditor, the Shopping List switch, the Esc menu switch).
- The Tooltips page's shared "off costs nothing" tail (TooltipsUI.lua OFF) is now empty: that explanation is in the user guide.
- Strings only: no behaviour changed. The wording is ours (QA flow Q-UIB-8).

## Tests
hover_brevity_run (new; every literal desc = "..." at most two sentences): 54 of 293 longer on the old code, 0 now.
qa_walks_display 42 / 42: the walkthrough ui-short-hovers reads all 536 hover texts of the live options table; only Notepad's two
remain long. The agent's own full suite on its base had one fail, qa_walk_run's checklist sync, the known issue fixed in 0acb900.
QA B234.
