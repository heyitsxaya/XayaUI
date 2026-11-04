# Cooldown triggers: "Count a lockout as cooldown" (XayaUI core 0.6.27, XayaUI_Options 0.6.23; fork: main)
Logged 2026-11-04 18:03 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Backlog item B, step 3 (Xaya's cooldown-trigger options: "Show
Loss of Control"). Nothing here has run in the game.

## API facts (V2)
- `C_Spell.GetSpellLossOfControlCooldownInfo(spellIdentifier)` → `lossOfControlInfo: SpellLossOfControlInfo` · MayReturnNothing,
  SecretArguments=AllowedWhenTainted, SecretWhenCooldownsRestricted (`docs/reference/api/namespaces.md:4411`).
- `SpellLossOfControlInfo` (`structures.md:6592-6598`): `isActive: bool` · NeverSecret; `shouldReplaceNormalCooldown: bool` ·
  NeverSecret; startTime / duration / modRate carry no flag.
- So whether a lockout runs is readable in combat (INFERENCE: the NeverSecret field reads as for SpellCooldownInfo; QA B63 checks).
  Not given (nil, or the call failed) = no lockout.
- Blizzard's own action-button use was not re-read this session; the field names are taken at their documented meaning.

## What changed
- `XayaUI/Conditions.lua`:
  - the shared cooldown reading records `r.locked`;
  - `ns.CheckCooldownState` treats `rule.countLOC` + locked like the global cooldown: not ready, no charge, on cooldown;
  - only that rule's answer changes.
- `XayaUI/Triggers.lua`: the "Cooldown (any spell)" row gets the tick box and passes it on.
- `XayaUI_Options/Options.lua`: the built-in Cooldown section gets it. It is in the list hidden with the section, cleared by Remove
  and carried by copy-section.
- `USER-GUIDE.md`: the cooldown paragraph.

## Tests
- `tests/count_gcd_run.py`, 30 to 35 checks:
  - countLOC off: a lockout is ignored;
  - on: not ready, also in combat;
  - ready again when the lockout ends;
  - the trigger row: the same;
  - the option lists cover it.
- **Negative control:** on `9b68419`, 7 checks fail: the lockout checks, and the option lists without countLOC.
- Passing: `charges_combat`, `timing`, `trigger_parity`, `engine_text`, `lua_pitfalls`.
- QA: B63.
