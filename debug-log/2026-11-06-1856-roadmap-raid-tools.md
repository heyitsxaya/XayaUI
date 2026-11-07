# Roadmap: Raid Tools (Release Guard move, Big Wigs data, Tank Focus Frame) logged (docs only)
Logged 2026-11-06 18:56 UTC. Session branch `claude/ecstatic-cori-sfi3hk`. Nothing in the addons changed.

## Request (Xaya, 2026-11-06, her words)
See REQUEST-LOG-session-014bN6tTuH6rxEfggbnTEH3o.md row 3.

## Checked in the repository
- Release Guard: `XayaUI_QoL/ReleaseGuard.lua` (header: QoL > Release Guard, saved in `CueRulesDB.releaseGuard`, not run in game, QA E1z82).
- Aura reads on other units: `docs/reference/api/namespaces.md:5323-5339` (`SecretWhenUnitAuraRestricted`, `RequiresUnitAuraAccess`, `RequiresNonSecretAura`). Role read: `globals.md:597` (`SecretWhenUnitIdentityRestricted`).
- Big Wigs: only the sound packs are in the repository (Addon Info page, `LocalSounds.lua`). Nothing about how Big Wigs exposes data to other addons is in the repository; not looked up. I cannot find data to confirm it.
- Whether secure frames can change in combat is an INFERENCE (not looked up in the reference).

## What changed
ROADMAP.md: rows RM-RAIDTOOLS, RM-RAIDTOOLS-BW, RM-RAIDTOOLS-TANKS and a waiting-on-decision entry. Read as logging, not building or moving code.
