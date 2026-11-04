# Cooldown triggers: "Count the global cooldown" (XayaUI core 0.6.25, XayaUI_Options 0.6.21; fork: main)
Logged 2026-11-04 17:57 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Backlog item B, step 1. Xaya's request (2026-11-04,
screenshots of a cooldown trigger's options): "make sure whatever is currently supported by the api is reflected into our trigger
pane". Nothing here has run in the game.

## API facts (V2)
- `C_Spell.GetSpellCooldown(spellIdentifier)` → `spellCooldownInfo: SpellCooldownInfo` · MayReturnNothing,
  SecretArguments=AllowedWhenTainted, SecretWhenCooldownsRestricted (`docs/reference/api/namespaces.md:4400`).
- `SpellCooldownInfo` (`docs/reference/api/structures.md:6540-6549`): `isActive: bool` · NeverSecret, and `isOnGCD: bool?`
  · NeverSecret, Nilable. Both are readable in combat.
- nil (not given) counts as "not on the GCD". It never makes a spell read as on cooldown.
- INFERENCE (a third-party comment cited in the research): `isOnGCD` may be reliable only around SPELL_UPDATE_COOLDOWN. QA B61
  checks it in game.

## What changed
- `XayaUI/Conditions.lua`:
  - the shared cooldown reading (`ns.ReadCooldown`, cached per spell for every rule in one engine step) records `r.onGCD`;
  - `ns.CheckCooldownState` applies it only for a rule with `countGCD`: on the GCD, "Cooldown ready" and "Has a charge" are false,
    and "Not fully ready" and "On cooldown" are true;
  - the shared reading is never changed, so another rule on the same spell still ignores the GCD.
- `XayaUI/Triggers.lua`: the "Cooldown (any spell)" row gets a "Count the global cooldown" tick box and passes it on.
- `XayaUI_Options/Options.lua`: the rule's built-in Cooldown section gets the same tick box, with a tooltip.
- `USER-GUIDE.md`: the cooldown states paragraph.

## Scope (V4)
- `ns.CheckCooldownState` is called by the built-in Cooldown section (`ns.Evaluate`) and the "Cooldown (any spell)" row; both get
  the option.
- The "Spell" trigger's ready state (`Triggers.lua` "spell usable", which also ignores the GCD) is not changed: not part of this
  step.
- `r.onCd` / timing and display countdowns are unchanged.

## Tests
- `tests/count_gcd_run.py` (new, 16 checks), using the real Core, Conditions, Timing, Triggers and Outcomes with stand-in game
  calls:
  - unticked: the GCD is ignored, as before;
  - ticked: not ready on the GCD, and "On cooldown" true;
  - two rules on one spell answer apart in the same step;
  - in combat it is the same;
  - a 2-charge spell has no charge available on the GCD;
  - the trigger row behaves the same;
  - both tick boxes exist.
- **Negative control:** 8 of the 16 fail on the previous files (every countGCD answer, and the tick boxes).
- Passing: `charges_combat`, `timing`, `trigger_parity`, `engine_text`, `load_class`, `tracked_buff`, `lua_pitfalls`.
- QA: B61.
