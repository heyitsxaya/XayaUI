# Death and Decay rule fires in combat: buff read through the rule's spell's Tracked Buffs icon; charges read in combat (XayaUI core 0.6.8; fork: main)
Logged 2026-11-04 04:55 UTC. Branch `claude/eloquent-rubin-n9zb99`. Issue: https://github.com/heyitsxaya/XayaUI/issues/365. Nothing here has run in the game yet.

## Report
Insivius (via Xaya, 2026-11-04): "still having issues with auras not working", with his exported Death and Decay rule. Xaya: "death and decay buff is tracked in his cdm. it is appropriately tracked by EUI. it is failing in xui and not triggering at all with or without conditions. is the "all triggers" failing?"

## His rule (export, addonVersion 0.6.6)
- Death and Decay (Unholy only, loaded in combat). Triggers combined as ALL:
  - Cooldown 43265 **ready**;
  - Buff / Aura 188290 (+ 434034) **missing**.
- Condition 1: buff trigger AND `charges == 2`. It turns on a texture cue and a sound cue.

## Cause (code read, 0.6.7)
The ALL combine works as designed: it needs every trigger confirmed TRUE (`Conditions.lua` ns.Evaluate). In combat two answers were **unknown**:
1. **Buff missing.** Both auras are hidden in combat, so the only route is a Cooldown Manager icon carrying 188290 or 434034 (`FindCDMFrame` indexes each icon's spell, override and linked IDs).
   - A Tracked Buffs entry filed under the spell (43265) matches neither.
   - "Missing" over several IDs also needs each one confirmed absent (`ns.AuraPresentList`), and 434034 could never be read.
   - **Unconfirmed:** which IDs his entry carries.
2. **Charges.** `n:cdCharges` (`Outcomes.lua` NumRef) read only `currentCharges`, which is secret in combat.

## Fix
- **`ns.BuffPresentAny`** (Conditions.lua): when the aura answer is unknown, it reads the rule's own spell's **Tracked Buffs** icon or bar (`FindTrackedBuffFrame`: BuffIconCooldownViewer / BuffBarCooldownViewer only, never a cooldown icon). Guards:
  - one of the rule's aura IDs has the spell's name, or is the spell;
  - names come from `C_Spell.GetSpellName`, cached; a secret name never matches.
  - The source text says "CDM tracked buff of the rule's spell <id>".
- **`n:cdCharges`** in combat: `SpellChargeInfo.isActive` and `.maxCharges` are NeverSecret (12.1.5 docs).
  - Not recharging → the maximum.
  - Max 2 and recharging → 1, or 0 while the spell's own cooldown runs. This is the cooldown trigger's existing "empty" reading (main cooldown only at 0 charges; an inference, not documented).
  - Max 3+ and recharging → unknown.
- `/xui timing` says how charges are read in combat.

## Checks
- `tests/tracked_buff_run.py` (new, 11): his rule against stand-in game calls (Core + Conditions + Triggers + Outcomes).
  - Out of combat the aura API decides.
  - In combat, missing → rule TRUE and Condition 1 TRUE; standing in it → present and the rule FALSE; one charge → FALSE, not unknown.
  - Guards: an aura with another name stays unknown; a spell not in Tracked Buffs stays unknown; a cooldown icon is never used.
  - On the 0.6.7 Conditions.lua 6 checks fail; on the 0.6.7 Outcomes.lua 3 fail.
- `tests/engine_text_run.py`: 6 new checks on charges in combat (2 / 1 / 0 of 2; `== 2` TRUE at full; 3 charges recharging unknown; 3 at full exact). All 6 fail on the old Outcomes.lua.
  - An extra engine step in the first version of this block shifted the clock of the debuff-text check that follows. That check depends on when the display last refreshed its text. The block now runs no engine step.
- Related suites pass: timing, aura_sources, perf, auras_cmd, aura_display, layout_parity. Full suite and harness: see the commit.

Docs: USER-GUIDE (Buff present or missing, in combat; Charges in a condition); QA-CHECKLIST B25.
Files: XayaUI/Conditions.lua, XayaUI/Outcomes.lua, XayaUI/Timing.lua, XayaUI/XayaUI.toc (0.6.8), tests/tracked_buff_run.py (new), tests/engine_text_run.py, USER-GUIDE.md, QA-CHECKLIST.md, this entry, MANIFEST.md5.
