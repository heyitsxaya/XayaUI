# Character window width: the 380 px default reaches installs that ran 0.7.21-0.7.23 (QoL 0.7.27)

Date: 2026-11-06 04:00 UTC. Branch: `claude/adoring-hawking-wyda59` (session S1, 014bN6tWZxqCW85vMEyHdfnt). Landed on its own, at her request.

## What she reported
- "this still looks overly large" and "surely this isn't 380px?" (REQUEST-LOG #58, #59), with screenshots of the character window at
  QoL 0.7.24: every enchant and gem block drawn, the window much wider than Blizzard's.

## Cause (found in the code, confirmed by her screenshots)
- `XayaUI_QoL/CharacterReskin.lua` `Cfg()` copies each default into her saved settings (`CueRulesDB.characterReskin`) and keeps any
  saved number. QoL 0.7.21-0.7.23 had the default extra width 240 (commit 36f1eb2), which was saved on first use. QoL 0.7.24 changed
  the default to 42 but never replaced a saved number, so her window stayed 338 + 240 = 578 (780 with the stats pane).
- Scale-free check from her screenshots: paperdoll part / stats pane (Blizzard's pane = 540 - 338 = 202 units) ~ 558 / 195 px = 2.86
  and 710 / 253 px = 2.81; at 380 it would be 380 / 202 = 1.88; at 578 it is 578 / 202 = 2.86. The pixel edges were read by eye
  (estimates); the gap between 1.88 and ~2.86 is far larger than that error.
- Why the tests missed it: every test started from an empty install (no saved settings).

## Her decision (question box, 2026-11-06)
- "Same, land it now": once per install, a saved Extra width of exactly 240 (the old default) becomes 42; any other saved number stays;
  a 240 she picks afterwards stays. Landed on its own today (an exception she chose to the one-landing-per-round rule V17).

## Change
- `Cfg()`: a one-time step with the marker `widePxTo42` (set on every install, fresh or old).
- QoL 0.7.24 -> 0.7.27 (0.7.25 and 0.7.26 are taken on other sessions' branches).

## Tests
- `tests/char_reskin_run.py` section 11 (5 checks): starting from 0.7.22's saved table, 240 becomes 42; a 240 picked afterwards stays;
  200 stays; a fresh install gets 42; a 240 saved as text counts. Negative control on the code before this change: 4 of the 5 fail
  (the "picked afterwards" check is a guard and passes on both).
- Full suite and precheck: see the landing commit.
- Not seen in game: QA E1z65.

## Open
- The general fix (store only what she changed, AceDB-style) is her pending defaults decision; every other default change has the
  same problem until then.
- At 380 the stand-in predicts most side enchant / gem blocks have no room (REQUEST-LOG #38); her feedback on the width is pending.
