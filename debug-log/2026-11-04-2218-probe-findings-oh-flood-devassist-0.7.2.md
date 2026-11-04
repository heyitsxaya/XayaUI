# Xaya's probe upload: what it shows, and proc-art hides no longer flood the log (XayaUI_DevAssist 0.7.2; fork: main)
Logged 2026-11-04 22:18 UTC. Session 014bN6tSy3HbUDWYQsk69naX. Nothing in the fix has run in the game.

## The upload
Xaya uploaded four SavedVariables files (no message): `XayaUI_DevAssist.lua` and its `.bak`, `XayaUI_GameDump.lua` and its `.bak`.
They were read as data only: each was loaded in an empty Lua 5.1 environment (no functions reachable), in the scratchpad, never in the
repository; nothing from them is copied here except counts and IDs.
- `XayaUI_DevAssist.lua`: the event probe (0.6.0 format), switched on 2026-11-04 11:23:45 local time, last resumed 17:09:09; open
  world (Eastern Kingdoms, instance ID 0), 6 combats; client 12.1.5.70783; 121 spell IDs from her rules. No handler errors, no game
  call that raised, no event refused. The cast recorder (`rec`) is empty. The `.bak` is the previous save of the same recording.
- `XayaUI_GameDump.lua` (the tool's name before 0.7.0): captures from 2026-11-01 20:28 (character, auras, static data) and
  2026-11-03 21:49-21:59 (API inventory, Character Toolkit checks), plus the cast recorder (30 spells, Vengeance Demon Hunter).

## Findings (counts from the probe's own tallies; c = in combat)
1. **Mob identity in open-world combat is readable**: creature ID, GUID, name and classification readable on 188 of 188 in-combat
   reads (594 of 594 out of combat). Instances may differ: QA J14 / the run sheet's dungeon step answers that.
2. **Proc glows**: spell 187827 glowed 15 times, all in combat, its ID and IsSpellOverlayed readable every time. No glow pairing
   entries: 187827 is not in core's PROC_GLOW_AURAS.
3. **Own casts** readable in combat: 1,756 of 1,756.
4. **UNIT_AURA payload** in combat: isFullUpdate secret on all 4,795 in-combat events; the added / removed lists secret on 657 / 640.
5. **Watched spells**: ShouldSpellAuraBeSecret returned true on every in-combat read (41,232) and false out of combat (4,800); the
   aura read was "none" every time. Expected: the watch list was only the built-in spells (Death Knight / Paladin), none of which
   this character has, so retrospective gap 20 is still open; it needs her own procs added with `/xuidev probe spells <id>`.
6. **No enemy casts at all** (no CS / CC / CL / CI / CT entries) over 6 combats with 391 nameplates seen. Either the mobs did not cast
   or the events did not arrive; this data cannot tell which (INFERENCE either way). The dungeon run answers it.
7. Combat logging was off (`C_ChatInfo.IsLoggingCombat` false). `LoggingCombat` exists for addons as a function (type only; never called).
8. **Fiery Brand**: C_Secrets rates 204021 and 207771 "contextual" for cast and aura; her rules use 207771. The cast recorder saw 6
   casts, all in combat, every aura event around them hidden: whether 207771 or 207744 lands on the enemy is still not settled.
9. **Fel Flame Fortification (393009)**, backlog G: the cast recorder files it under Immolation Aura (258920): a buff on the player,
   seen twice, out of combat, read from a snapshot, duration 0.0. Passed to the engine session.
10. **The flood**: 21,685 SPELL_ACTIVATION_OVERLAY_HIDE events, about two a second, almost all with no spell ID (21,079 out of combat).
    As log entries they pushed 22,811 older entries out of the 6,000 kept, so most of the day's record is gone.

## The fix (Dev Assist 0.7.2)
`Probe.lua` SPELL_ACTIVATION_OVERLAY_HIDE: a hide with no spell ID is counted (`.count.OH`, the overlay.id tally, and `.ohNoID` =
{ n, c, first, last }) and not logged; hides with an ID are logged as before. Status line 2 says how many had no ID.
Scope (V4): only this handler and status line 2; nothing else reads OH entries (`git grep '"OH"'`: Probe.lua, the probe test).
Test: `tests/devassist_probe_run.py` 100 checks (1 new: 50 no-ID hides leave the log length unchanged and are counted), 104
deliberate breaks (1 new: logging them again), FAILS 0. `devassist_instance_run.py`, `lua_pitfalls_run.py`: pass. QA J15.
