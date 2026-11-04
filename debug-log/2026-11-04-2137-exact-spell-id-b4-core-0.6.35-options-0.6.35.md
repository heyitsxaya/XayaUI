# "Exact spell ID" on cooldown triggers (B4) (core 0.6.35, Options 0.6.35)
Logged 2026-11-04 21:37 UTC. Session branch `claude/fervent-cerf-hldtwn` (engine session). From Xaya's backlog item B (spell trigger
options, from her reference screen 5): `docs/plans/REFERENCE-SCREENS-AND-FEASIBILITY-2026-11-04.md` item 4, "An exact spell ID toggle,
so a talent replacement is not followed (`C_Spell.GetOverrideSpell`)". Also in this commit: `docs/plans/GROUP-PAGE-REVIEW-2026-11-04.md`
(Xaya: "review all outstanding notes on how group is supposed to be reconfigured"; read-only review, nothing built).

## Behaviour
- A cooldown trigger (the rule's Cooldown section, and every "Cooldown (any spell)" trigger row) has a new tick box **Exact spell ID**.
- Unticked (default, unchanged): it reads the spell on your bar (`C_Spell.GetOverrideSpell`, as since gap 4).
- Ticked: it reads exactly the ID it was given: its cooldown, its charges (the charge watcher reads that ID too), its lockout and its
  "known" check; "Seconds left" comparisons read the same ID.

## Scope (V4: `grep -n 'SpellOnBar'`)
- Changed: `ns.ReadCooldown` (the once-per-step memo is now keyed by spell, max charges AND exact / following, so two rules on one
  spell answer apart), `ReadCooldownRaw`, the charge watcher `WatchCharges` (reads each rule's / row's ID the way that rule reads it),
  `Outcomes.lua` `n:cdRemain` (the parent's seconds-left number), the "Cooldown (any spell)" row (field + its pseudo rule), Options
  (tick box after "Count a lockout as cooldown", hidden with the section, cleared by Remove, copied with the spell IDs).
- New: `ns.CooldownReadID(trigger, id)`.
- Not changed (other trigger types, which follow the replacement on purpose): proc glow (`GlowIDs` asks the spell, its replacement and
  its base), "Spell usable", "Spell cast recently".
- Known limit: the in-combat cooldown estimate (Timing.lua) learns lengths by the rule's spell ID, whichever ID was read. Two rules on
  one spell, one exact and one following, share that learned length (it only matters when the game hides `isActive`, which it reports
  as NeverSecret, so INFERENCE: rare).

## API facts (V2)
- `C_Spell.GetOverrideSpell(spellIdentifier, spec = 0, onlyKnown = true, ignoreOverrideSpellID = 0) -> overrideSpellID` ·
  SecretArguments=AllowedWhenUntainted (docs/reference/api/namespaces.md:4394).
- `C_Spell.GetSpellCooldown(spellIdentifier) -> SpellCooldownInfo` · MayReturnNothing, SecretArguments=AllowedWhenTainted,
  SecretWhenCooldownsRestricted (namespaces.md:4400).
- Not documented: whether the game gives the base ID its own cooldown while a talent replaces it, or returns the replacement's for both.
  INFERENCE either way; QA B113 asks Xaya to report it. If both always match, the tick box changes nothing for that spell (it never
  guesses: it reads what the game reports for the exact ID).

## Verification
- `tests/count_gcd_run.py`: 8 new B4 checks (rule and row; following vs exact both ways; two rules in one step; a 2-charge base spell
  replaced by a 1-charge spell counts the base spell's charges; the options wiring). Negative control: on the code without B4 the
  outcome checks fail (ticked reads 7010: False; charge count 1 instead of 2); the default-behaviour check passes on both, as it should.
  Two older source-text checks in the same file were updated for the new key in the Cooldown section's list.
- USER-GUIDE (cooldown trigger), QA B113.

## Not done
B5 ("Track: Auto / Charges / Spell cooldown"): the notes give only the label, not what each choice should do, so it goes to Xaya as a
question (V12). B6 (track if not known) was already marked "ask Xaya whether she wants that at all". Nothing was run in game.
