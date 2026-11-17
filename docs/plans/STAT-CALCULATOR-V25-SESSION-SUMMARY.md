# Stat Calculator V25: session-start summary
Load this first in a new chat. Full history: `STAT-CALCULATOR-V25-TRACKER.md` (same folder). Request log: `docs/process/REQUEST-LOG.md` section A24.

## The job
Xaya's request: apply her code standards (V14, V23-V26, the six V25 criteria) and every kind of test used for XayaUI Rules to the Stat Calculator on `qa-installer-branch`.

## Her decisions (2026-11-10)
- Scope: the whole of CharacterToolkit.lua, CharacterModel.lua, StatMath.lua, StatsText.lua, CharacterPane.lua and CharacterReskin.lua. "Toolkit" is the wrong name now: every file name in scope gets reviewed and renamed (in every reference) to what the file does. Names are proposed to her first.
- V26: the Stat Calculator is unavailable in combat; the character window still opens in combat.
- Landing: merge into `qa-installer-branch` once all checks pass, plus a note on what bringing only the Stat Calculator into main needs.
- Multi-session: this file plus the tracker.

## Branch and baseline
- Work branch `claude/stat-calculator-v25` (from QA 92bd3ff). Never push to main; QA only after all checks pass. Never force-push.
- Pre-change copy of the tree: the session scratchpad (`prechange/`). Rebuild with `git archive 92bd3ff`.

## Process (from the Rules review)
1. Read-only review workflow (slices + lenses + one skeptic per medium+ finding) -> `docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md`.
2. Xaya picks the fix bundle (question box).
3. Fix units own their files; every fix has a test that fails on the pre-change code and passes after; one adversarial reviewer per unit.
4. Checks: targeted tests; `python3 tests/lua_pitfalls_run.py`; `python3 tests/harness/api_index_from_docs.py` then `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`; `python3 tools/manifest.py` after git add; `python3 tools/precheck.py` (FAILS: 0). Version bumps, debug log, patch notes, QA walk step.

## Active items
See the tracker, section "Status".

## Core dependency
Core on QA is older than main (main has the KeyCatch.lua fix bundle). Do not port core changes: flag any stat-tool problem that depends on core.

## Standing reminder (her words, A24 #8)
The full stat list freezes in combat "for now ... circle back to this later after we confirm performance is wholly optimized. ask repeatedly, since we might need to dynamically calculate character stats later". Ask her again after every performance confirmation.

## Standing rules 2026-11-17 (replace the older inherited global instructions)
Source: docs/process/XAYA-STANDING-RULES.md on claude/dazzling-brown-x9fqrm (147c569e; REQUEST-LOG SD-132), relayed by the main session. Binding from now on. Key additions for this work:
- CODE: the right coding model for the session (quality of landing first; cost-cutting that risks quality is unacceptable); error handling and documentation in every implementation; a maintained filemap and function call index; ask Xaya whether she wants wireframes for any UX/UI code.
- CODE: XUI: design wireframes alongside code builds; nothing is flagged complete until it passes three questions: (1) best-practice performance, low CPU/RAM, *elegant* code that scales without patching; (2) delivers the original request in full, plus reasonable extension cases; (3) fits the holistic system, siloed so a failure does not compromise the rest. How these apply to work already in progress is being asked of Xaya by the main session; until she answers, apply them to new work and raise conflicts.
- Never copy other codebases unless their license allows; research pointers only.
