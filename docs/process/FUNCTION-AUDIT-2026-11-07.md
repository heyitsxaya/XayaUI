# Function audit, 2026-11-07 (REQUEST-LOG A11 FA-1 = UI-60)

Her request (verbatim): "Things like this should never happen. / Go through every feature and element and confirm all functions within operate as expected with no additional / unexpected behaviors. Highest priority, open up a new session for this and run immediately."

Session 014bN6tSfFULX4BSXzmZ1yCx, branch `claude/function-audit` (from `origin/main` 687b624). Nothing in this file has been run in the game.

## How it was done
- Expected = what the control's label / tooltip, the code comments, docs/USER-GUIDE.md, docs/QA-CHECKLIST.md and the request log say it does.
- Actual = what the code does (file:line), traced by reading and, for defects, reproduced with a stand-in test.
- The reading was split by area across parallel reviewers; every row marked **defect** was checked again by this session against the code before it went in this table. Rows a reviewer reported that did not hold up are listed under "Rejected" with the reason.
- Verdicts: **OK** (expected = actual), **defect** (fixed or to fix; test named), **unclear** (the intended behaviour is not written down anywhere: a question for Xaya, nothing is changed until she answers).
- "Verified" = traced in our own code or reproduced in a test. "Inference" = depends on game behaviour the API reference does not document.

## Defects
| # | Addon / feature | Control | Expected | Actual (before the fix) | Verdict | Test |
|---|---|---|---|---|---|---|
| D1 | Bonus / Notepad format bar (UI-59) | R, Y, G, B colour buttons | Tester's expectation (UI-59): the highlighted text is kept and coloured. Tooltip: "type between the color code and the closing \|r" (silent on a selection). | `Ins("\|cff55dd55\|r", 2)` -> `EditBox:Insert` (Notepad.lua 748 on 687b624). The game's Insert replaces highlighted text (inference from the tester's screenshots; the API reference lists no getter for the highlighted range, only HighlightText / ClearHighlightText), so the highlighted word is replaced by an empty colour pair. The note autosaves, so the word is gone from the saved note too (Ctrl+Z can bring it back while the box is open). | defect, fixed (Bonus 0.6.20 pending number): `Wrap` lets Insert run, works out what it replaced from the text before / after, and puts it back between the colour code and \|r | tests/notepad_format_selection_run.py (16 of 24 checks fail on 687b624, 24 pass after) |
| D2 | Bonus / Notepad format bar | Spell | Same as D1 (not reported; found while reproducing D1). | Highlighted text replaced by `{spell:}`. | defect, fixed: the highlighted text goes inside the braces (`{spell:Fireball}`), which the formatted view already reads as a spell name. This placement is my choice: see question Q1. | same test |
| D3 | Bonus / Notepad format bar | H, bullet, checkbox | "starts the line with # / - / [ ]" (tooltips). | Highlighted text replaced by the prefix; with a whole line highlighted the line was lost and an extra empty line was left (`first\n\n# `). | defect, fixed: the prefix goes where the highlight starts (on a new line if that is mid-line, as without a highlight) and the highlighted text follows it. | same test |
| D4 | Bonus / Notepad format bar | all insert buttons on a full note (8000 characters) | Nothing is cut off. | The insert ran past the box's 8000-letter limit; the game cuts the inserted text (inference: SetMaxLetters is documented only by name). | defect, fixed: when the note is full the button does nothing and says so in chat. | same test (stub has no letter limit: it checks the text is unchanged) |

## Unclear (questions for Xaya)
| # | Feature | Question |
|---|---|---|
| Q1 | Notepad, Spell button with text highlighted | Built: the highlighted text goes inside the braces ({spell:Fireball}). Alternative: keep the text and insert {spell:} after it. |

## Checked OK
| Addon / feature | Control | Note |
|---|---|---|
| Bonus / Notepad format bar | View | Switches view, touches no text (Notepad.lua `ns.Notepad_SetView`). |
| Bonus / Notepad format bar | all insert buttons with nothing highlighted | Same result as before the fix (old-behaviour checks in the test pass on both). |

## Rejected reviewer reports
(none yet)
