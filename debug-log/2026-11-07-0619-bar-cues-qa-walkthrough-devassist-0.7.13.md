# Bar cues: an in-game QA walkthrough with pre-fill (XayaUI_DevAssist 0.7.13)
Logged 2026-11-07 06:19 UTC. Session 014bN6tX7AoZQrGX246YSXjC, branch `claude/dreamy-edison-pvb3i1` on main 6b25c9b4. Not run in game.

## Request (Xaya, relayed to every session 2026-11-07 ~06:00 UTC; REQUEST-LOG A11 S8-14)
- "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill
  confirmation options or data capturing"; and "ship everything I asked for today and stop asking me questions until everything that is
  more than 6h old is completed and on main" (no question asked here).
- The bar cues (on main since 28380a96) had only the generated text walkthrough of their checklist steps (no checks, no pre-fill).

## Change
- `XayaUI_DevAssist/QAWalks-bars.lua` (new; in the .toc after QAWalks-chat.lua): walkthrough "Bar cues (progress bars)", QA B200,
  `prefill = true` (QAWalk.lua: the addon's verdict on one Accept button; nothing recorded without the click). Nine steps:
  1 "Do it for me" makes the rule "XayaUI QA: Bar test" on the first buff the player has (C_UnitAuras.GetAuraDataByIndex, out of
  combat) with one Bar cue, previewed; check: 220 x 22, background 20 %, 1 px border, picture layer hidden, icon, name.
  2 the bar moves (value in 0..1, a per-frame update or the game's timer, the value changed since step 1's setup).
  3 drawn in the colour XayaUI chose (GetStatusBarColor where the game answers, else XayaUI's own record) and why.
  4 "Do it for me" sets the cue's style to Neon; check: repainted, and a type colour differs from Blizzard default.
  5 "Do it for me" makes "XayaUI QA: Bar group", moves the rule in, forces Muted / Dark; check: the group's style wins, the cue's
  own Neon is kept underneath.
  6 the texture list: no entry twice, Blizzard power art present, no XayaUI fills.
  7 combat (noVerdict: a question for the person): preview off, rule out of the group, engine rebuilt; the check says whether
  the combat engine draws the bar (ns.EngineOwns).
  8 Enhanced Tooltips > Type colours on and colouring a sample line.
  9 "Do it for me" removes the test rule, its cue and the test group.
- Nothing else of the player's rules or groups is touched. V14: nothing runs until the walkthrough is opened.
- `docs/QA-CHECKLIST.md` B200 names the walkthrough; XayaUI_DevAssist/QAWalks-Checklist.lua regenerated.
- Dev Assist 0.7.10 -> 0.7.13 (0.7.11 is claude/ui-bugs-focused's, 0.7.12 claude/function-audit-land's and
  claude/perf-test-m-plus-land's; checked 06:1x UTC).

## Tests
- `tests/qa_walks_bars_run.py` (new): 21 checks, 0 failed: registered with pre-fill for B200; the combat step is noVerdict; every
  step's check passes on the working code; negative controls fail: a 55 % background, a bar that does not move, a bar drawn in
  another colour, a style that changes nothing, a group that does not force, a texture listed twice, Type colours off; the last step
  leaves no test rule or group. Without QAWalks-bars.lua: 2 checks, 1 failed.
- `lua_pitfalls_run.py` FAILS: 0.

## Not verified
- In game: everything. GetStatusBarColor's answer on a bar the game drives (INFERENCE: may be secret in combat; step 3 runs out of
  combat and falls back to XayaUI's record).
