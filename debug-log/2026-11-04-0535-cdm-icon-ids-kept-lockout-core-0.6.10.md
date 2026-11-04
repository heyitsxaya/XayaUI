# Cooldown Manager icons keep their spell IDs while hidden; a lockout is not "0 charges" (XayaUI core 0.6.10; fork: main)
Logged 2026-11-04 05:35 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Why
A facts-only read of EllesmereUI's Cooldown Manager files (uploaded by Xaya for a "sanity check without copying"; Blizzard API facts only, nothing copied) gave two facts that bear on XayaUI's in-combat reads:
1. **Hidden IDs.** A Blizzard Cooldown Manager icon's `GetSpellID()` and its `cooldownInfo` fields can read secret while the icon's aura is active. EllesmereUI keeps the last clean read per icon.
   - XayaUI's icon index dropped secret IDs. So in combat it could lose exactly the lit icon, and a "buff present" rule read unknown.
2. **Lockouts.** "The spell's own cooldown runs = 0 charges" is not universal: EllesmereUI's comment names spells that lock out briefly while charges remain.

## Change
- `Conditions.lua` `FrameIDs`: an icon's IDs are its spell ID, the override, the tooltip override and the linked IDs.
  - When any of them reads secret, the IDs the icon showed when readable (`xuiLastIDs`) are used.
  - `Timing.lua` clears them when Blizzard gives the icon another spell (`OnCooldownIDSet`).
  - Every field read is pcall'd and secret-checked.
- Charges (`ChargeState`):
  - the spell's own cooldown counts as 0 charges only while a charge is also recharging;
  - own cooldown with nothing recharging = a lockout: not ready, count unknown.

## Checks
- `tests/tracked_buff_run.py` +1: icon IDs secret while its aura is active → still found → PRESENT (fails when the kept IDs are not used).
- `tests/charges_combat_run.py` +1: lockout → not ready, count unknown (fails when the old 0 reading is put back).
- engine_text, timing, aura_sources and auras_cmd pass. Full suite: see the commit.

## Also from that read (for the Cooldown Manager bridge, not built yet)
- EllesmereUI does not add entries to Blizzard's Cooldown Manager: none of the uploaded files calls a layout setter.
- A hidden Blizzard viewer stops updating its icons; EllesmereUI keeps the bar viewer off screen but shown.
- `GetSpellCooldown().isOnGCD` is only reliable when read on `SPELL_UPDATE_COOLDOWN` (EllesmereUI comment). XayaUI reads it at evaluation time; noted for the retrospective.

Files: XayaUI/Conditions.lua, XayaUI/Timing.lua, XayaUI/XayaUI.toc (0.6.10), tests/tracked_buff_run.py, tests/charges_combat_run.py, this entry, MANIFEST.md5.
