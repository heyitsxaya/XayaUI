# A little calculator: /xui calc and a keypad window (XayaUI_Bonus 0.6.8; fork: main)
Logged 2026-11-04 21:37 UTC. Session 014bN6tSy3HbUDWYQsk69naX, branch `claude/inspiring-mendel-8r8qao`. Nothing here has run in the game.

## Request
Xaya, 2026-11-04: "add a feature: a little calculator". No further detail was given. Choices made here (each easy to change):
- two ways in: `/xui calc <sum>` answers in chat; `/xui calc` alone (or the minimap button's list) opens a small window;
- the window has a typed line, a keypad (C ( ) ÷ / 7 8 9 × / 4 5 6 - / 1 2 3 + / 0 . % =), the answer, and the last three sums;
- the answer replaces the line so the next sum builds on it; the last ten sums are saved (`CueRulesDB.calculator.history`);
- it lives in XayaUI_Bonus beside the Notepad (no other session is editing Bonus); no settings page (nothing to set).
Alternatives considered: chat-only (rejected: a keypad was the plain reading of "a little calculator"); inside the Notepad (rejected:
the Notepad is for text, and its toolbar is already full).

## Design
- Typed text is never run as code: `ns.CalcEval` is a tokenizer and a recursive-descent parser (sum, term, unary, power, postfix,
  primary). No loadstring, load or RunScript anywhere in the file (a test checks the source and the call counts).
- What a sum can hold: numbers with commas between groups of three, decimals, k / m / b, + - * / ^, x and the multiply / divide /
  minus signs (UTF-8 C3 97, C3 B7, E2 88 92), % after a number (divide by 100), brackets. -2^2 = -4 (a leading minus binds looser
  than ^), 2^3^2 = 512 (^ from the right).
- Every wrong sum returns a reason: divide by zero, a misplaced comma, the sum ending too soon, a missing bracket, a word, two numbers
  in a row, too long (200 characters), too large. Answers: commas, at most 6 decimals, e-notation from 1e15 or below 1e-6.
- Spacing: `ns.UI_MARGIN` / `ns.UI_GUTTER` from #351 phase 1 (Options 0.6.33) when XayaUI_Options is loaded, else 10.
- Registered through `XayaUI/Modules.lua` (`ns.RegisterCommand` "calc" / "calculator", `ns.RegisterLauncher` "calc", order 11).
  Not added: "calc" in core's `ns.MODULES` command list (`XayaUI/Modules.lua:84`), which only words the message when Bonus is off;
  core belongs to the rules session now. With Bonus off, `/xui calc` gets core's generic unknown-command reply.

## Scope (V4)
New file `XayaUI_Bonus/Calculator.lua`; `XayaUI_Bonus.toc` (0.6.8, Notes, file list). Nothing else reads or calls it.

## Tests
`tests/calculator_run.py` (new): 57 checks (answers worked out in Python, not by the code under test), 8 deliberate breaks, each
caught (one first-draft break was not: the history cap sits in two places, so the break now raises the cap itself). Negative control:
without Calculator.lua the test fails. The first run also caught two faults: a Lua pattern cannot repeat a group, so the comma check
`(,%d%d%d)+` was invalid and is now a split; and the stand-in frames returned functions for unset fields (a test fault).
`lua_pitfalls_run.py`: 76 files, FAILS 0.

## Not verified
In game: QA F6 (the window's look, the keypad's fit, Escape, the saved position).
