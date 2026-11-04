# In-game event probe, `/xuidump probe` (XayaUI_GameDump 0.6.0)
Logged 2026-11-04 08:24 UTC. Branch `worktree-agent-a0c9f673813a54498` (worktree; not pushed). Nothing here has run in the game yet.

## Request
Coordinator (session 014bN6tUvbkCv9Ha9VgNF4Xa), 2026-11-04: build an in-game data collector that Xaya runs on the morning of
2026-11-05, to answer the open questions of ROADMAP RM-INST (instanced content mapper) and task 28 (proc glows as aura signals).
Commands `on`, `off`, `status`, `clear`, `spells <id> ...`, `mark`. Ring buffer of about 6,000 entries, event handlers only, nothing
runs while off, every read checked with `issecretvalue`, every handler pcall-safe, anchors for the combat log. Items 1 to 11 below.
Then a run sheet (`docs/process/IN-GAME-DATA-2026-11-05.md`) and a test whose every check fails against a broken handler.

Extra signals asked by the coordinator mid-task ("needed so tomorrow's in-game data can confirm two inferences core will NOT act on
until then"):
- A. On GLOW_SHOW / _HIDE also `IsSpellOverlayed` of `C_Spell.GetBaseSpell(id)` / `GetOverrideSpell(id)` when they differ.
- B. Glow pairing: if core's `ns.PROC_GLOW_AURAS` (XayaUI_NS) exists at run time, read each paired aura about 0.1 s after a
  GLOW_SHOW with `C_UnitAuras.GetPlayerAuraBySpellID`: found / nil / secret. Not needed at load time (that table is on branch
  `claude/eloquent-rubin-n9zb99`, not in this worktree).
- C. For each watched spell, `C_Secrets.ShouldSpellAuraBeSecret(id)` next to the aura read, at combat start, combat end and on each
  UNIT_AURA for the player (retrospective gap 20: can "false" + a nil read be trusted as absent?).
- D. COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED: both IDs with GetTime().

## Scope (V4)
- `XayaUIGameDumpDB` readers: GameDump.lua, ApiInventory.lua, AuraCatalogue.lua, FormulaCapture.lua (each its own key);
  `docs/reference/build_reference.py` (reads `.api`); `tools/formula_fit.py` (reads `.formula`). The new key `.probe` is read by
  nothing else.
- `/xuidump` slash handler (GameDump.lua): new `probe` branch, the help line, and the `status` line (probe on/off and entry count).
- Window (GameDump.lua `GD.Toggle`): unchanged; the probe has no button (layout untouched).
- `CueRulesDB` is only read (rule spell IDs), never written. Core XayaUI is not changed and is not needed at load time.
- Tests that load GameDump.lua: `gamedump_api_run.py`, `gamedump_catalogue_run.py` (still pass); `formula_capture_run.py` (passes).

## What it records, and the question each answers
Output `XayaUIGameDumpDB.probe`: `.log` ring buffer (newest 6,000; `.dropped` counts the rest), `.anchors` (kept apart), `.stats`
(readable / secret / nil / error / missing, out of / in combat, per field; never dropped), `.secrecy`, `.watchPairs`, `.marks`,
`.errors` (handler failures, counted, logged once per kind), `.callErrors` (game calls that raised, first text), `.legend`.
Every entry: `t` = GetTime() to 3 decimals, `e` = code, `u` = unit token, `c` = InCombatLockdown(), then the fields.

| Item | Recorded | Answers |
|---|---|---|
| Anchors | at `on`, ENCOUNTER_START, ZONE_CHANGED_NEW_AREA, PLAYER_ENTERING_WORLD, `clear`, `off`, resume: GetTime, time(), GetServerTime, date(), GetInstanceInfo name / type / difficultyID / instanceID, context flags | lining entries up with WoWCombatLog.txt (local wall clock); with item 4 to the millisecond |
| 1 Context | at anchors and PLAYER_REGEN_DISABLED / _ENABLED: HasSecretRestrictions, ShouldAurasBeSecret, ShouldCooldownsBeSecret, IsLoggingCombat (enabled, advanced), `type(LoggingCombat)` (never called) | when restrictions switch on; whether the old global still exists for addons (ROADMAP RM-INST question) |
| 2 Proc glows | GLOW_SHOW / _HIDE (spellID, IsSpellOverlayed, base / override IDs and their IsSpellOverlayed when different, snapshot), OVERLAY_SHOW (spellID, overlayFileDataID, locationType) / _HIDE; pairing rows (B) | task 28: do glows reach an addon in combat with a readable ID; which ID is reported for a replaced spell; does core's glow → aura table agree with the aura read |
| 3 Spell state | OVERRIDE_UPDATED (base, override, snapshots), SPELL_UPDATE_ICON (spellID, snapshot), _USABLE and _CHARGES (merged within 2 s, with `n`). Snapshot: IsSpellUsable, GetOverrideSpell, GetSpellTexture, castTime, power-cost hasRequiredAura / requiredAuraID, maxCharges / charges isActive, cooldown isActive / isOnGCD | which spell-state reads stay readable in combat; does hasRequiredAura flip with a proc |
| 4 Your casts | UNIT_SPELLCAST_SUCCEEDED for the player (spellID) | exact alignment with the combat log's SPELL_CAST_SUCCESS |
| 5 Enemy casts | START / SUCCEEDED / CHANNEL_START / INTERRUPTED / STOP for boss1-5, target, focus, nameplateN: spellID, castGUID, interruptedBy (me / GUID kind / secret), GetSpellCastSecrecy for a readable ID | are enemy cast IDs readable, where (open world, dungeon, Mythic+, boss), and does the secrecy level predict it |
| 6 Mobs | NAME_PLATE_UNIT_ADDED / _REMOVED, UNIT_FLAGS when UnitAffectingCombat changes on a nameplate: creature ID, GUID, name, ShouldUnitIdentityBeSecret, classification, dead, CanBeRaidTarget, affecting combat | identity readable out of combat, hidden in combat? does a nameplate token stay with its mob through a pull? |
| 7 Timeline | TIMELINE_EVENT_ADDED (id, source, spellID, spellName, iconFileID, duration, severity, isApproximate), _REMOVED, _STATE_CHANGED (+ GetEventState, GetEventTimeRemaining); ENCOUNTER_START / _END payloads (unit status up to 5) | which timeline fields an addon can read in a pull |
| 8 Warnings | ENCOUNTER_WARNING (text, casterName, tooltipSpellID, duration, severity); RAID_BOSS_EMOTE text (200 characters) | are warnings / emotes readable |
| 9 Auras | UNIT_AURA player / target: payload readability, list lengths only (merged within 2 s); watched spells (C) | is the payload itself secret in combat; gap 20 |
| 10 Mark | `/xuidump probe mark` only: SetRaidTarget("target", 8) in pcall, error text, combat, GetRaidTargetIndex before / after; ADDON_ACTION_BLOCKED / _FORBIDDEN while on | can an addon mark a mob, in / out of combat |
| 11 Secrecy | at `on` / resume and `spells`: GetSpellCastSecrecy, GetSpellAuraSecrecy, name, for the built-in list (1233398, 402772, 1265968, 1265982, 1265790, 50842, 1306161, 1306162, 1310461, 53385, 85256, 383328), every spellID / buffID / buffAlt / trigger-row ID in CueRulesDB.rules and .bars, and IDs added by `spells` | secrecy level per priority spell |

Interpretations (say if wrong): "snapshot that spell once" = one snapshot per event, no follow-up reads. Watched spells (C) = the
built-in list plus the IDs added with `spells` (rule spells are only secrecy-checked; at most 40 are watched, to bound the cost of
reading them on every UNIT_AURA). SPELL_UPDATE_USABLE / _CHARGES / _ICON and UNIT_AURA are merged within 2-second windows (`n`, `tl`,
summed counts) so a dungeon run does not fill the 6,000 entries alone; `.stats` and `.count` keep every event.

Privacy: another player's name and GUID are stored only as "readable" / "secret" (nameplates of players, and units not known to be
non-players); interruptedBy keeps only "me" or the GUID kind; warning and emote text has the player's own name replaced with `<me>`
and group members' names with `<group>` (an unreadable name cannot be replaced: the entry says `scrub = "partial"`).

## API facts used (V2; docs/reference/api, documentation 12.1.5.70688, client 12.1.5.70783)
Quoted next to each item in `Probe.lua`. The flags that decide the code:
- Events with a secrecy flag: UNIT_SPELLCAST_* `SecretWhenUnitSpellCastRestricted`; ENCOUNTER_TIMELINE_EVENT_ADDED
  `SecretWhenEncounterEvent`; UNIT_AURA `SecretWhenAurasRestricted`. No flag: SPELL_ACTIVATION_OVERLAY_*, COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED,
  SPELL_UPDATE_*, NAME_PLATE_UNIT_*, UNIT_FLAGS, ENCOUNTER_START / _END / _WARNING, RAID_BOSS_EMOTE (CHAT_MSG_RAID_BOSS_EMOTE has
  `SecretInChatMessagingLockdown`), PLAYER_REGEN_*.
- Structures: EncounterTimelineEventInfo id / source / duration `NeverSecret`, the rest not; EncounterWarningInfo text, casterName,
  tooltipSpellID `SecretValue`, duration / severity no flag; SpellChargeInfo maxCharges / isActive and SpellCooldownInfo isActive /
  isOnGCD `NeverSecret`; SpellInfo.castTime and SpellPowerCostInfo hasRequiredAura / requiredAuraID no flag.
- Calls: UnitCreatureID `RequiresUnitIdentityAccess, SecretWhenUnitIdentityRestricted`; UnitGUID `SecretWhenUnitIdentityRestricted`;
  UnitName `SecretWhenUnitNameIdentityRestricted`; GetSpellCharges / GetSpellCooldown `SecretWhenCooldownsRestricted`;
  GetPlayerAuraBySpellID `RequiresNonSecretAura, SecretWhenUnitAuraRestricted`; C_EncounterTimeline.GetEventState /
  GetEventTimeRemaining `RequiresValidTimelineEvent, SecretArguments=NotAllowed` (asked only with a readable ID); C_Secrets.*,
  IsSpellOverlayed, UnitClassification, UnitIsDead, CanBeRaidTarget, UnitAffectingCombat, UnitIsPlayer
  `SecretArguments=AllowedWhenUntainted` (never passed a secret); SetRaidTarget `HasRestrictions`; GetRaidTargetIndex `SecretReturns`.
  Enum.SecrecyLevel NeverSecret 0, AlwaysSecret 1, ContextuallySecret 2.
- Blizzard's own UI (public mirror github.com/Gethe/wow-ui-source at 12.1.5.70783): `/combatlog` toggles `LoggingCombat()`
  (SlashCommands.lua), so the global exists for Blizzard's code; SetRaidTarget(unit, index) sets and (unit, 0) clears, the toggle
  lives in Blizzard's code (TargetFrame.lua, SecureTemplates.lua); the Cooldown Viewer registers UNIT_AURA with
  `RegisterUnitEvent("UNIT_AURA", "player", "target")` and reads COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED as (base, override);
  action buttons light the button whose spell equals the GLOW_SHOW payload (ActionButton.lua).

## INFERENCES (not documented; the code fails safe)
- A boolean or nil test on a secret raises in addon code like a comparison does: every value goes through `issecretvalue`
  (pcall-wrapped) before anything else; if the check itself fails, the value is treated as secret.
- `type()` of a secret reports the underlying type (the test's stand-in does the same), so secret tables are checked before any
  `type(x) == "table"` branch.
- Unit tokens in event payloads are not secret; a secret one is only counted (`castUnitSecret`, `plateUnitSecret`).
- Whether a nameplate token still answers at NAME_PLATE_UNIT_REMOVED: whatever it answers is recorded.
- Whether GetPlayerAuraBySpellID raises for a hidden aura (`RequiresNonSecretAura`): recorded as `<error>` with the text kept.
- Whether an addon may call LoggingCombat: unknown, so only its type is recorded.
- Whether SetRaidTarget from an addon is blocked (in or out of combat), and whether that shows Blizzard's "blocked" dialog: unknown;
  only on the explicit command; the run sheet says to click Ignore.
- The secrecy level of a spell may not be fixed: each check is kept; changes are listed.

## Checks
- `tests/gamedump_probe_run.py`: 99 checks on stand-in game functions (made-up values), then 103 deliberate breaks of `Probe.lua`.
  - Secrets: a userdata sentinel whose metatable raises on compare, arithmetic, join, tostring, index, call and length (counted even
    when a pcall swallows it); stand-in game functions raise if passed a secret. Result: 0 misuses, 0 secret arguments, no secret
    stored, every secret field stored as "secret". Lua 5.1 cannot trap `==` between a userdata and a string / nil; the stored
    outcome is checked instead.
  - Also: nothing registered or recorded while off (events fired and handlers called directly); every registered event is in
    `docs/reference/api/events.md` (the stand-in RegisterEvent raises on an unknown event, like the game); RegisterUnitEvent with at
    most 2 units; anchors; items 1 to 11 and A to D; ring buffer (6,100 events: 6,000 kept, oldest dropped, drops counted, anchors
    kept); `mark` only on command; a failing handler counted twice and logged once, no error escaping; status text and counts;
    clear; off; resume after a reload; no player name or other player's GUID stored; no OnUpdate; no global created.
  - Deliberate breaks: every one of the 103 is caught, and every one of the 99 checks fails under at least one break (for example
    "issecretvalue ignored" fails 26 checks; "mark on encounter start" fails 3; "handlers record while off" fails 7; "ring never
    drops" fails 2). Two breaks first went uncaught because the stand-in secret's `type()` said "userdata"; the stand-in now
    reports the underlying type and both are caught.
- `tests/gamedump_api_run.py` 27/27, `tests/gamedump_catalogue_run.py` 53/53, `tests/formula_capture_run.py` pass;
  `tests/lua_pitfalls_run.py` 0 fails.
- Full suite (`tests/run_all.py`): all 39 unit-test groups pass. The whole-addon harness reports 17 FAILs, every one
  `XayaUI_Options/Options.lua:4638: attempt to index global 'C_Texture'` (one per combination with XayaUI_Options). This was already
  there: the line dates from the repository's base commit, the harness world has no `C_Texture` stand-in, and the harness never
  loads XayaUI_GameDump. `tests/harness/api_index.json` is not in the repository, so the harness's method / event checks did not run.

## Not tested in game
Everything. In particular: real event volumes (whether 6,000 entries cover a dungeon run; the 2-second merging), the cost of reading
the watched spells on every UNIT_AURA in a raid, whether SetRaidTarget from an addon pops Blizzard's blocked-action dialog, the size
of the saved file, the resume at ADDON_LOADED, and every readability result (that is what the run is for).

Docs: run sheet `docs/process/IN-GAME-DATA-2026-11-05.md`; USER-GUIDE 12.13 (Event probe); QA-CHECKLIST J7 to J11.
Files: XayaUI_GameDump/Probe.lua (new), XayaUI_GameDump/GameDump.lua (`probe` command, help, status), XayaUI_GameDump/XayaUI_GameDump.toc
(0.6.0, Probe.lua), tests/gamedump_probe_run.py (new), docs/process/IN-GAME-DATA-2026-11-05.md (new), USER-GUIDE.md, QA-CHECKLIST.md,
this entry, MANIFEST.md5.
