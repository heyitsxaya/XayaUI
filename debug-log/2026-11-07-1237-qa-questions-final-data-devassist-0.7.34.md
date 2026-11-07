# QA question flow: final data landing (XayaUI_DevAssist 0.7.34)
Review-popup build session, branch `qa-review-popup`. This is a follow-up to the first landing, 302331b (Dev Assist 0.7.30, on main).
Only data changed: `XayaUI_DevAssist/QAQuestions.lua`. No code changed.

## Change
- Questions go from 187 (as landed) to 206. Each one is transcribed from the session that sent it (2026-11-07 09:22-12:36 UTC). Her
  words are copied exactly as sent; where a question has none, the screen says so.
- Added:
  - function audit: FA-D22, FA-D23 (informational), FA-D44-multi, FA-D41, FA-D42-count, FA-D45-empty, FA-11-builtin;
  - perf successor: Q-PERF-8;
  - UI-bugs successor display audit: Q-UIB-9 to Q-UIB-15.
- Changed:
  - Q-PERF-5 now says the change is built (branch claude/perf-click 580c205), as its successor session sent;
  - Q-UIB-1 adds that the title-bar ? and collapse buttons go flat with the X;
  - UI-24-label-scope now matches claude/settings-restructure f753ba1 word for word (renamed everywhere; the remaining choice is to
    also rename it in the older patch notes), so the two branches agree.
- Answers are saved under each question's key. No key that landed in 302331b was renamed, so no saved answer is lost.

## Tests
- `tests/qa_review_run.py`: 51 / 51.
- The full suite and precheck on the landing commit: the results are given in the landing report.

## Untested in game
The question screens with the new texts (length and wrapping).
