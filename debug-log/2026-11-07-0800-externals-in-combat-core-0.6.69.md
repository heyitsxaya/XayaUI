# Externals and raid defensives in combat (core 0.6.69, Options 0.6.66, Dev Assist 0.7.26; QA J25)
Externals engine session, opened by the 11-06 hub (session_014bN6tSStpdmmCXviFAqPdQ). Branch `claude/externals-in-combat`, based on
`claude/perf-load-first` (297f097, core 0.6.66). Logged 2026-11-07 08:00 UTC. Nothing here has run in the game. The lander relabels
versions.

## Request (REQUEST-LOG A16 X-1)
Her words (relayed by the hub): "I turned EUI ones on because XUI isn't reliably performing". This is about externals and raid
defensives. Her "Externals (36)" group sits in the Disabled tab. EllesmereUI's "External, Raid + Misc" bar tracks 51052, 48707, 207400,
22812, 1044, 196718, 62618, 235450, 97462, 363534, 98008, 374227 and 1283344. Behaviour was compared only; no other addon's code was
read. O-108: no questions to her. O-109: load conditions are untouched.

## Sources (V2)
- docs/reference/api/namespaces.md (12.1.5 70783):
  - C_UnitAuras.GetUnitAuraBySpellID and GetPlayerAuraBySpellID: `RequiresNonSecretAura, SecretArguments=AllowedWhenTainted,
    SecretWhenUnitAuraRestricted`.
  - GetUnitAuraInstanceIDs and IsAuraFilteredOutByInstanceID: `RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted` (no
    secret-return flag). But Combat/AuraDisplay.lua:4 records "measured: GetUnitAuraInstanceIDs errors" in combat. The measurement was
    not found in debug-log, so it is unconfirmed either way. Not used.
  - C_UnitAuras.AuraIsBigDefensive(spellID) → bool, AllowedWhenTainted: read by the J25 walkthrough only.
- events.md: `UNIT_AURA (unitTarget, updateInfo) · SecretWhenAurasRestricted`. Seen in game on 11-04: lists secret in combat
  (debug-log/2026-11-04-2218).
- docs/reference/spells/spells.json (game capture 2026-11-01): aura secrecy 2 (ContextuallySecret) for all 12 captured IDs of her bar.
  1283344 is not in the capture. Same-name, no-cooldown second IDs: 51052/145629, 196718/209426, 62618/81782, 97462/97463,
  98008/325174, 207400/207401. INFERENCE: the second ID of each pair is the buff.
- Blizzard's UI source (Gethe/wow-ui-source live, 297d7aa = 12.1.5 70783; read-only clone outside the repo):
  - AuraUtil.lua:270-288 AuraUtil.AuraFilters lists EXTERNAL_DEFENSIVE, BIG_DEFENSIVE, RAID_IN_COMBAT, IMPORTANT, CROWD_CONTROL,
    DISPELLABLE and RAID_PLAYER_DISPELLABLE (the stand-in in tests/aura_display_run.py already had them).
  - ExternalDefensivesFrame.lua uses "HELPFUL|EXTERNAL_DEFENSIVE".
  - Blizzard_CustomAuraContainer.lua:78-84 says of includeSpellIDs: "Spell ID matching is only permitted for helpful buffs on
    assistable units". Blizzard_AuraContainerUtil.lua:90-108 compares `auraData.spellId` in the game's secure code
    (Blizzard_AuraContainer.toc `UseSecureEnvironment: 1`).
  - Blizzard_AuraContainer is also used by BuffFrame.lua, TargetFrame.xml and SecureGroupHeaders.lua.

## Root cause
1. The rule engine (Conditions.lua) has two sources in combat:
   - the by-spell-ID read (ReadAuraAPI), which the game answers with nothing for these spells;
   - Cooldown Manager icons. An external someone else casts on you is not among them (INFERENCE: the Cooldown Manager lists your own
     class's spells).
   So BuffPresentRaw returned "unknown: restricted + spell not readable + not in CDM". AuraTracker.Resolve only links auras to your OWN
   casts, or to a read made before combat, so the rule stayed unknown and never showed. That is correct (no guessing), but it was silent.
2. Blizzard's container (Combat/AuraDisplay.lua) CAN draw these in combat, but only for a rule it takes over. Rules it hands back (the
   reasons are in /xuiengine) fall to path 1 and stay hidden. On top of that, the performance guard switched automatic drawing OFF for
   the session whenever Blizzard_AuraContainer's whole CPU stayed above 1 ms, even after lean mode. That meter includes Blizzard's own
   buff frame, target frame and group headers. In a raid this can trip from Blizzard's work alone, and then every external vanishes in
   combat. INFERENCE: whether this is what happened to her needs her guard-trip record (captured by J25).
3. Both readers match the exact aura ID. A rule that lists a cast ID whose buff has another ID never matches (see the pairs above).

## Change
- Conditions.lua:
  - An aura the game hides now reads "hidden by the game right now (auras are secret, as in combat): aura N cannot be read and is not
    in your Cooldown Manager", for both a nil and a secret answer.
  - New ns.HiddenAuraNote(rule[, info]) builds the status text on demand (never per engine step). It says whether the game's container
    still draws the display (and what waits: sounds, conditions, "missing"), or why it does not.
  - BuffPresentRaw also reads learned same-name IDs (ns.AuraAliasesOf), only while the game shows auras.
- XayaUI/AuraAlias.lua (new, in XayaUI.toc after Conditions.lua). Out of combat, a helpful aura with a duration that appears on you,
  whose name equals the name of an aura ID one of your rules lists but whose ID differs, is saved as that ID's alias in
  CueRulesDB.auraAlias. Never learned: auras without a duration (passives), a namesake that is up together with the rule's own aura,
  more than 4 per ID. In combat it returns at once; with no rule listing an aura ID it reads nothing (V14). The rule itself is never
  edited.
- Combat/AuraDisplay.lua:
  - Learned aliases are added to the include list.
  - New D.OwnerOf(rule): true + where it is drawn, false + the reason it stays with XayaUI, nil if it is not an aura display.
  - Guard: stage 2 ("off") now needs evidence that XayaUI's containers are the cost. Lean mode must have handed displays back AND the
    reading must have fallen to ≤ 80 % of the reading that tripped lean. Otherwise the step is "kept": drawing stays on for the
    session, it is said in chat and recorded (guardTrips step "kept"), and the guard does not step again. INFERENCE: the 20 % margin.
  - /xuiengine status names the kept state.
- Outcomes.lua ExplainRule (/xui debug status) and Options StatusText (rule status) show the note.
- Dev Assist:
  - CoreDebug.lua: /xuiengine auto on/off also clears the kept state.
  - QAWalks-externals.lua: walkthrough J25 (prefill; data capture).

## Scope (V4: git grep)
- Readers of the unknown text: DevRecord.lua SourceKind (takes the text before "(" / ":" / "|"; works unchanged); Options.lua
  StatusText; Conditions.lua WhyNot / PrintStatusRaw; tests/Conditions.pre-0.5.83.lua (historic copy, not loaded).
- Callers of BuffPresentRaw: BuffPresentOnce → ns.BuffPresent → AuraPresentList / AuraPresence / BuffPresentAny / Triggers.lua aura
  rows (ns.AuraPresence) / Cues.lua and Outcomes.lua (the parent's info).
- AuraDisplay Classify ids: the built-in Buff / Aura with buffAlt, and a lone "Buff / Aura (another)" row with alt. A target debuff is
  not aliased (it is on the target, not the player).
- Guard: GuardCheck, Status, /xuiengine full (resets leanAt / leanHanded), CoreDebug EngineAuto (resets kept).

## Tests (V1, V5)
- tests/externals_in_combat_run.py (new). On the old code it fails with Xaya's exact in-game string ("unknown: restricted + spell not
  readable + not in CDM (game: aura secret now)") and on the missing note / alias. On the new code: FAILS 0.
- tests/aura_display_run.py:
  - section 19 (new): the alias is in the include list; OwnerOf for the slot, a cue, a handback reason, a cooldown-only display, and
    auto off.
  - The guard section was rewritten for the new rule: kept when the cost does not fall; off when lean lowered it but not enough. The
    new checks fail on the old code.

## Not built (the game withholds it)
WHICH external is on you, for XayaUI's own reading in combat (sounds, conditions, "missing" displays): the spell IDs are secret there,
and the event lists are too. The category filters (EXTERNAL_DEFENSIVE etc.) could tell "an external is on you" only if instance IDs
were readable in combat, which is unconfirmed (see above).

## Unverified in game
Everything: that the container draws her externals in combat; whether her rules list cast IDs; whether the guard tripped for her; and
the alias learning itself. J25 captures all of it.
