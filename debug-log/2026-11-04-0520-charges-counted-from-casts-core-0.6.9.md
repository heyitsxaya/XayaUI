# Charges in combat counted from your casts; no early "ready" after a charge is used (XayaUI core 0.6.9; fork: main)
Logged 2026-11-04 05:20 UTC. Branch `claude/eloquent-rubin-n9zb99`. Follows #365 (0.6.8). Nothing here has run in the game yet.

## Reports
- Xaya, 2026-11-04: "the patch for insivius worked" (0.6.8, Death and Decay).
- Then: "insivius is experiencing a rule fire before he has charges available"; "the charge tracking needs refinement".
- "please be sure to review every spell or ability that has multiple charges and account for this across every class, spec, and potential talent change".

## Cause (0.6.8)
- **The flag that was trusted.** In combat the count is secret. 0.6.8 read "no charge recharging" (`SpellChargeInfo.isActive == false`, NeverSecret) as "full", for the cooldown trigger's Ready and for "charges == 2".
- **Why that flag lies.** Blizzard's documentation says that flag is also false when the recharge's "start time or duration are zero", and a cooldown can be on hold (`SpellCooldownInfo.isEnabled` false). So right after a cast it can say "not recharging" with a charge missing, and the rule fired.
- **It was always there.** The cooldown trigger's Ready has read the flag this way for a long time. It only became visible once 0.6.8 let his rule fire in combat.
- **Reproduced.** `tests/charges_combat_run.py` on 0.6.8: after a cast with the game reporting "not recharging", Ready = TRUE and count = 2.

## Blizzard facts used (12.1.5 UI source and API docs; read, not copied)
- `SpellChargeInfo.maxCharges` and `.isActive` are NeverSecret; so are `SpellCooldownInfo.isActive`, `.isOnGCD` and `.isEnabled`.
- Blizzard's Cooldown Manager shows a spell's own cooldown only once no charge is left; while charges are partly spent it shows the charge recharge instead (`Blizzard_CooldownViewer/CooldownViewer.lua` CheckCacheCooldownValuesFromCharges / CheckCacheCooldownValuesFromSpellCooldown).
- It raises `Enum.CooldownViewerAlertEventType.ChargeGained` on its icons through `TriggerAlertEvent` when a charge comes back (SetCachedChargeValues / ShouldTriggerChargeGainedAlert).
- The player's own `UNIT_SPELLCAST_SUCCEEDED` is readable in combat (already used by Triggers.lua).

## Change (Conditions.lua "Charges in combat", Outcomes.lua, Triggers.lua, Timing.lua)
- **Anchors:**
  - out of combat, the exact count;
  - the spell's own cooldown running (not the GCD) = 0;
  - "full" only when nothing is recharging AND none of your casts came after the last moment it was seen full: an exact read at the maximum, or a recharge seen to finish (recharging → not recharging).
- **Count = anchor − your casts since + the Cooldown Manager's charge gains since.** 2-charge spells recharging = 1.
  - 3+ charges in between: only with the spell in the Cooldown Manager.
  - A count that does not add up is unknown, never clamped.
- **On hold** (`isEnabled` false): not ready (for single-charge spells too), count unknown.
- **The spell on your bar:** `C_Spell.GetOverrideSpell` (a talent that replaces the spell) is read, and its casts count.
- **The watcher:** every rule's charge spell is read on `SPELL_UPDATE_CHARGES`, login, combat start and end, and spell / talent / spec changes, loaded or not. So a combat-only rule starts from an exact count, and a cast from an earlier pull never holds it back.
- `ns.CheckCooldownState`: "Has a charge" and "Not ready" are unknown when the count or readiness is unknown (before, "Has a charge" read TRUE).
- The charges condition (`n:cdCharges`) uses the cooldown reading's count. Your casts go to the counter (`ns.NoteChargeCast`). The Cooldown Manager's ChargeGained alerts are recorded on its icon (`xuiChargeGains`).
- `/xui status` names how the count was found and which spell was read. `/xui timing` describes the charge route.

## Review across classes (docs/reference/charges.md, new)
- Built from Xaya's capture (12.1.5, one Demon Hunter client): **46 spells** with base charges, and **53 talents** whose text changes a spell's charges. Example: Death's Echo gives Death and Decay a second charge, which is where Insivius's 2 charges come from.
- Facts only (IDs, names, counts, the spell names in each talent's charge sentence); descriptions stay private.
- **Limits:** one character's client; 24 of the spells are not in a talent tree, so their class is not named; talents worded differently can be missing.
- The code does not depend on this list: the maximum is read live, so every talent is followed when taken.

## Checks
- `tests/charges_combat_run.py` (new, 22). On 0.6.8, 11 of them fail, including the reported early fire. It covers:
  - his case (cast with "not recharging" → not ready, 1);
  - recharge running → 1; both used → 0; back to full only when a recharge is seen to finish;
  - a combat-only rule after a cast in an earlier pull;
  - on hold;
  - a replacement spell (read and counted);
  - 3 charges without the Cooldown Manager (unknown), with it (casts and gains counted; a count that does not add up → unknown; re-anchored at full);
  - single-charge on hold → not ready;
  - unknown never reads as "has a charge";
  - the cast and ChargeGained wiring.
- `tests/engine_text_run.py` and `tests/tracked_buff_run.py` still pass. So do timing, aura_sources, perf, auras_cmd and aura_display.
- Full suite and harness: see the commit.

## Not solved here (logged)
- A charge refunded by a proc in the same instant as the cast (no recharge ever seen) reads as not full until the next recharge finishes or combat ends. This fails safe: a cue can be late, never early.
- Charge spells whose casts report a different spell ID than the spell or its replacement are not counted.

Docs: USER-GUIDE (Charges), QA-CHECKLIST B26 / B27, docs/reference/charges.md.
Files: XayaUI/Conditions.lua, XayaUI/Outcomes.lua, XayaUI/Triggers.lua, XayaUI/Timing.lua, XayaUI/XayaUI.toc (0.6.9), tests/charges_combat_run.py (new), docs/reference/charges.md (new), USER-GUIDE.md, QA-CHECKLIST.md, this entry, MANIFEST.md5.
