# Roadmap: tank frame boss-target indicator added to RM-RAIDTOOLS-TANKS (docs only)
Logged 2026-11-06 22:41 UTC. Session branch `claude/ecstatic-cori-sfi3hk`. Nothing in the addons changed.

## Request (Xaya, 2026-11-06, her words)
See REQUEST-LOG-session-014bN6tTuH6rxEfggbnTEH3o.md row 5.

## Checked
- `UnitIsUnit` (globals.md:663): RequiresComparableUnitTokens, SecretWhenUnitComparisonRestricted.
- `SetAlphaFromBoolean` (widgets.md:246 and the same on other widget types): SecretArguments=AllowedWhenTainted, so addon code may pass a secret true / false.
- Events `UNIT_TARGET` (events.md:1653), `INSTANCE_ENCOUNTER_ENGAGE_UNIT` (events.md:855).

## Inferences (not tested)
The two marks can be drawn from secret answers; bosses turning for casts make the marks flicker; "by the tank" in her third line is a typo for "by the boss" (asked, not assumed in the build).
