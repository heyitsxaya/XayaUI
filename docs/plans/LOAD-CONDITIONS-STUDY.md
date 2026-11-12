# Load conditions: what EllesmereUI and ElvUI offer that our Load tab lacks (2026-11-12)

> **Status: DRAFT, verification running.** Claims are being checked independently; corrections follow before anything goes to Xaya.

Request (her words): "review all load conditions in EUI and ElvUI and add what we're missing as options".

Status: study only. No addon file was changed. Nothing here is built yet; section 3 is the list to choose from.

Limit, stated as V25 asks: a cloud session has no game client. Every statement below about how the game, EllesmereUI (EUI) or
ElvUI behaves was read from source text or from our API reference (`docs/reference/api/`, build 12.1.5). None of it was measured
in game. Anything not read directly is marked **INFERENCE**.

---

## 1. Sources, versions, read-only statement

1. **Her Google Drive folder "Reference Addons (REFERENCE AND READ ONLY)".** Found by title search and read only (file listings
   and file sizes). Nothing in it was written, moved, renamed or deleted. No file was downloaded from it this time: the size check
   below was enough to tie each public copy to her copy.
2. **EllesmereUI, public repository EllesmereGaming/EllesmereUI**, default branch at commit 0f17daa (2026-11-12), version 9.8.4
   per its table of contents file. Shallow clone with git hooks off.
3. **ElvUI, public repository tukui-org/ElvUI**:
   - tag **v16.00** (commit 8a966b1, 2026-10-13): the version in her Drive folder (see sizes below). Main ElvUI source for this study.
   - default branch (commit 5c713f7, 2026-11-10, changelog top entry 16.01): read only to confirm nothing load-related changed.
   - tag **v14.07** (commit c8cf92f, 2026-01-16): read for the **nameplate style filter triggers**. ElvUI's own changelog says
     style filters were removed entirely in version 15.00 (Blizzard's new rules). So her ElvUI no longer has them; they are listed
     below as "ElvUI (older, removed)" for completeness only.

All clones live in the session scratchpad under `loadcond-study/src/<name>/` (`eui`, `elvui`, `elvui-v16.00`, `elvui-v14.07`).
Every file was read as text only. Nothing from them was run. The only helper is a byte-count script in `loadcond-study/tools/`,
run with `python3 -I`, that recomputes a file's size with Windows line endings.

| File (reference addon) | Matches her Drive copy? |
|---|---|
| EUI core `EllesmereUI_VisibilityRules.lua` (the shared show/hide conditions) | yes: 27,153 bytes with Windows line endings, same as hers (Drive copy dated 2026-11-08) |
| EUI core `EllesmereUI_Visibility.lua` (the event dispatcher for those conditions) | yes (62,774) |
| EUI core `EllesmereUI_Conditions.lua` (the "conditional overrides" picker) | yes (20,069) |
| EUI options `EllesmereUI_Widgets_Visibility.lua`, action bar paging, CDM / resource bar / unit frame state drivers | not size-checked (her copies sit in sub-folders not listed); same release as the three files above, so INFERENCE: same |
| ElvUI options `Nameplates.lua`, `ActionBars.lua`, `Filters.lua`, `UnitFrames.lua` | yes for **v16.00**: 80,343 / 42,780 / 25,091 / 182,670 bytes, identical to hers (Drive copies dated 2026-10-31). The default branch differs slightly (80,474 / 42,869 / 25,091 / 182,733) |
| ElvUI v14.07 style filter files | not in her folder (her ElvUI is v16.00, where they no longer exist) |

"Same size" is strong evidence two copies are the same, not proof (INFERENCE).

---

## 2. Comparison table

Columns: **EUI / ElvUI / XayaUI** = whether that addon offers the concept as a setting (where). XayaUI's side was read from
`XayaUI_Rules/Conditions.lua` (`ns.LOAD_TRI` line 1684, `ns.ReadContext`, `IdListWalk` line 1898, `CheckContextRaw` line 1962,
the group overrides inside it, and `rule.talents` from line 1571) and `XayaUI_Rules/Triggers.lua` (the Player State trigger,
line 877). "Trigger only" means XayaUI can already test it inside a rule's trigger, but not on the Load tab.

API column: entries in `docs/reference/api/` are cited as file:line. "undocumented" = the name exists in the client but has no
signature in the generated docs.

### 2a. Concepts XayaUI already covers (for completeness)

| Concept (own words) | EUI | ElvUI | XayaUI | API | Combat / secret notes | Notes |
|---|---|---|---|---|---|---|
| In combat / out of combat | yes, shared visibility row on most elements | yes: unit frame fader; v14 style filter | yes (Load) | `UnitAffectingCombat`, `InCombatLockdown` | none | |
| In a group / solo / in a raid group / party but not raid | yes, shared visibility row | yes: group-frame visibility macros; v14 style filter | yes (group + raid rows; "party not raid" = group yes + raid no) | `IsInGroup`, `IsInRaid` | none | |
| Inside an instance vs open world | yes (garrisons do not count as instanced) | yes: nameplate visibility per content type | yes (Load) | globals.md:353 `IsInInstance` | none | see M14 for the garrison nuance |
| Kind of instance (dungeon, raid, battleground, arena, scenario) | yes: conditional overrides picker; a dungeons-only row | yes: v14 style filter; v16 nameplate per-content toggles | yes (instance types) | globals.md:353 | none | |
| Difficulty (normal / heroic / mythic / keystone / timewalking / LFR) | no | yes: unit frame fader difficulty list; v14 style filter | yes (difficulty ID list) | `GetInstanceInfo` | none | ElvUI names them; we use IDs with "add current" |
| Mythic+ keystone run in progress | no (dungeons row includes it) | yes (as a difficulty) | yes (Load) | `C_ChallengeMode.IsChallengeModeActive` | none | |
| Specific map / specific instance | no | yes: v14 style filter (map IDs, instance IDs) | yes (map ID list with parent maps, instance ID list) | `C_Map.GetBestMapForUnit`, `GetInstanceInfo` | none | |
| Boss encounter in progress / specific encounter | no | no (v14 had "boss mod timer aura" which needs a third-party boss mod; different idea) | yes (Load + encounter ID list) | ENCOUNTER_START/END | none | |
| Mounted | yes (also counts druid travel forms, see M10) | no in v16; macro `[mounted]` possible in bar visibility text | yes (Load, plain mount only) | globals.md:370 `IsMounted` | none | |
| Resting area | yes, shared row | yes: v14 style filter; v16 nameplates | yes (Load) | `IsResting` | none | |
| Class, specialization, role from spec | yes: per-spec overrides of every setting | yes: v14 style filter (class + spec, player role) | yes (Load + group level) | `UnitClass`, `C_SpecializationInfo` | none | role nuance: see M12 |
| Hero talent tree | yes (bar glow conditions) | no | yes (Load) | `C_ClassTalents.GetActiveHeroTalentSpec` | none | |
| Talent / spell known or not known | yes (bar glow conditions) | yes: v14 style filter | yes (`rule.talents`, plus triggers) | `C_SpellBook.IsSpellKnown` etc. | none | |
| Specific item equipped / not equipped | no | yes: v14 style filter | yes (equipped list + trigger) | `C_Item.IsEquippedItem` | none | |
| Never / always / match all / match any | yes (never, always, match all, match any) | n/a | yes (load.mode) | n/a | n/a | EUI also has "hide" lanes that veto even under match-any; ours has no veto lane, every row is a requirement (design difference, not a missing condition) |

### 2b. Concepts XayaUI lacks on the Load tab

| # | Concept (own words) | EUI | ElvUI | XayaUI | API that would read it | Combat / secret concerns | Notes |
|---|---|---|---|---|---|---|---|
| M1 | Only while in a pet battle / only while NOT in one | fixed behaviour, not an option: unit frames, cooldown bars, resource bars, action bars all hide during pet battles | v16: action bar defaults hide during pet battles (bar visibility text); v14 style filter trigger | **no** | namespaces.md:3540 `C_PetBattles.IsInBattle` (undocumented signature: returns a bool, INFERENCE); events.md:1117 PET_BATTLE_OPENING_START, :1110 PET_BATTLE_CLOSE, :1118 PET_BATTLE_OVER | no secrecy flag known. A pet battle is not normal combat; whether combat lockdown applies is INFERENCE | highest value: today our displays stay up over the pet battle screen |
| M2 | Only while in a vehicle / never in a vehicle | yes, shared visibility row | yes: unit frame fader; v14 style filter | **trigger only** (Player State "In a vehicle") | globals.md:620 `UnitInVehicle` (`SecretArguments=AllowedWhenUntainted`: argument only); events.md:1594 UNIT_ENTERED_VEHICLE, :1596 UNIT_EXITED_VEHICLE | can change in combat; the result has no secret flag | |
| M3 | Only while the game has swapped your action bar (vehicle bar, override bar, possess/mind control) | fixed behaviour: cooldown bars and resource bars hide while the vehicle UI is up; action bar paging handles it | v16: default bar visibility hides on vehicle UI / override bar | **no** | namespaces.md:96 `C_ActionBar.HasVehicleActionBar`, :90 `HasOverrideActionBar`; events.md:1693 UPDATE_VEHICLE_ACTIONBAR, :1681 UPDATE_OVERRIDE_ACTIONBAR, :1683 UPDATE_POSSESS_BAR. Possess check: `HasBonusActionBar`/`IsPossessBarVisible` not checked in the reference (INFERENCE) | can change in combat; no secret flags | different from M2: some vehicles keep your bar, some quests give an override bar without a vehicle |
| M4 | Only while on a mount that can skyride (standing on the ground counts) / never then | yes, shared row (Forever client: always false) | no | **no** | namespaces.md:3694 `C_PlayerInfo.GetGlidingInfo` (second return: can glide); events.md:1162 PLAYER_CAN_GLIDE_CHANGED | can change in combat; no secret flag | also true for flight forms of non-druid races per EUI's notes (INFERENCE that the API covers them) |
| M5 | Only while actually airborne while skyriding / never then | yes, two visibility modes | yes: unit frame fader ("dynamic flight") | **no** | same function (first return: gliding); events.md:1186 PLAYER_IS_GLIDING_CHANGED. `IsFlying` (globals.md:350) has no change event of its own | can change in combat; no secret flag | EUI pairs "can glide" with "is flying"; using the gliding event alone avoids polling. Whether "gliding" and "airborne" are the same in every case is INFERENCE |
| M6 | Only inside a house or housing plot / never there | yes, shared row | no | **no** | namespaces.md:2348 `C_Housing.IsInsideHouseOrPlot`; also `IsInsideOwnedHouseOrPlot` (:2351) for "your own"; events.md:747 HOUSE_PLOT_ENTERED, :748 HOUSE_PLOT_EXITED | none known | |
| M7 | Only inside a delve (not a lair) / never there | yes: damage meter window option; a shared helper | no | **partly**: delves report as the "scenario" instance type, together with other scenarios; a difficulty ID could single them out (INFERENCE: delves have their own difficulty ID) | namespaces.md:3433 `C_PartyInfo.IsDelveInProgress`, :1608 `C_DelvesUI.IsInLair`; events.md:28 ACTIVE_DELVE_DATA_UPDATE plus the zone events we already register | none known | could be a seventh instance kind ("Delve") rather than a new row |
| M8 | Only while you have a target / only while you have a target you can attack (and the reverse) | yes, two shared rows | yes: unit frame fader (player has a target); v14 style filter | **trigger only** for "has a target"; **no** for "target is attackable" | globals.md:588 `UnitExists`, :565 `UnitCanAttack`; PLAYER_TARGET_CHANGED (already registered by our engine) | `UnitCanAttack`: arguments only flagged; whether the answer can come back secret for restricted units is INFERENCE. EUI notes soft-target flicker when the real target dies | |
| M9 | Only while Shift / Ctrl / Alt is held | yes: action bar paging by modifier | yes: v14 style filter; bar paging text | **no** | globals.md:394 `IsShiftKeyDown`, :340 `IsControlKeyDown`, :336 `IsAltKeyDown`, :369 `IsModifierKeyDown`; events.md:1011 MODIFIER_STATE_CHANGED | no secret flags; fires only when a modifier changes | cheap; mostly useful for "show extra info while Shift is held" |
| M10 | "Mounted" that also counts druid travel / aquatic / flight form | yes (built into its mounted row) | no | **no**: our Mounted row reads the mount only | `IsMounted` plus the shapeshift form (`GetShapeshiftFormID`, not in the reference: INFERENCE) or the Stance / Form trigger data we already have; UPDATE_SHAPESHIFT_FORM (already registered) | none known | best as a tick box on the existing Mounted row |
| M11 | Only in a zone or sub-zone with a given name (e.g. one inn, one city district) | no | yes: v14 style filter (zone names, sub-zone names) | **no** (map IDs do not reach sub-zones) | globals.md:315 `GetZoneText`, :283 `GetSubZoneText`, :206 `GetMinimapZoneText`; ZONE_CHANGED, ZONE_CHANGED_INDOORS, ZONE_CHANGED_NEW_AREA (already registered) | names are localized: a list typed in English fails on another client language | gone from current ElvUI; lower value |
| M12 | Role as assigned in the group (queued as healer while in a damage spec, raid leader set your role) | no | yes: ElvUI's player role prefers the assigned group role and falls back to the spec role | **no**: our role comes from the spec only | globals.md:597 `UnitGroupRolesAssigned` (`SecretWhenUnitIdentityRestricted`; for "player" INFERENCE: not restricted); events.md:1209 PLAYER_ROLES_ASSIGNED, GROUP_ROSTER_UPDATE | possible secret answer: treat as unknown | could be a choice on the existing Role row: "from spec" / "assigned in group" |
| M13 | A switch you flip yourself with a key binding (e.g. "show my extra cooldowns now") | yes: conditional overrides, a key-bound toggle outranks every other condition; only flips out of combat | no | **no** | none: our own saved state and a binding; no game event needed | must not flip protected frames in combat; ours are INFERENCE not protected | XayaUI-internal, no game API risk |
| M14 | "Instance" that does not count your garrison | yes (garrison excluded from its instance row) | no | **unclear**: our Instance row uses `IsInInstance`; whether a garrison reports as an instance is INFERENCE | namespaces.md:2121 `C_Garrison.IsOnGarrisonMap` (undocumented) | none | verify in game before building; may be a non-issue |
| M15 | Only while stealthed (any stealth, not just a stance) | yes: action bar paging pages on rogue stealth and druid prowl | yes (bar paging text) | **partly**: the Stance / Form trigger covers rogue stealth if the game reports it as a form (INFERENCE); not on Load | globals.md:395 `IsStealthed`; events.md:1689 UPDATE_STEALTH | can change in combat; no secret flag | covers Shadowmeld and similar too (INFERENCE) |
| M16 | Only while something (anything) is worn in a given gear slot, e.g. any shield in the off hand | no | yes: v14 style filter | **no** (we match item IDs, not "slot not empty") | `GetInventoryItemID` (not in the public reference: INFERENCE); PLAYER_EQUIPMENT_CHANGED (already registered) | none known | low value |

### 2c. Looked at and not proposed for the Load tab

- **Trigger-type conditions** (they change second to second, so they belong in triggers, not Load): you are casting; your health
  or power is not full; hovering the element with the mouse; having a focus target (already a trigger); being dead (already a
  trigger). ElvUI's unit frame fader uses these to fade frames in and out; EUI uses mouseover.
- **Conditions about another unit**, from ElvUI's old nameplate style filters: the unit's reaction, classification (elite, rare,
  boss), creature type, threat, raid marker, quest unit, guild, faction, PvP flag, level, owner, whether it is a pet, whether it is
  casting a given spell, auras on it, its health threshold. These describe the nameplate's unit, not you, and were removed in
  ElvUI 15.00. Out of scope for a load condition.
- **EUI's own feature states**: its "Party Mode" and "Dark Mode" are EllesmereUI features with no XayaUI equivalent. Its
  "Gamepad Mode" exists only on the WoW Forever client.
- **Your own level, war mode, faction**: neither EUI nor current ElvUI offers them as conditions (ElvUI v14's level trigger is the
  nameplate unit's level). Not on the list because the request was "what EUI and ElvUI have".

---

## 3. Missing concepts, with cost and risk

Every item is event-driven: the engine re-reads load facts only when one of the named events fires (V27: no polling). Items
marked "already registered" add no new event at all.

| # | Plain description | Cost / risk |
|---|---|---|
| M1 | Show only during a pet battle, or hide during one | Two new events (pet battle opening, pet battle close). Low cost. Risk: the check function has no documented signature (INFERENCE that it returns true/false); fall back to "unknown" if it does not. Probably wanted as a default "hide in pet battles" too |
| M2 | Show only in a vehicle, or never in a vehicle | Two unit events filtered to the player. Low cost. The check already exists in our Player State trigger, so it is a move, not new reading |
| M3 | Show only while the game has replaced your action bar (vehicle, override, possess), or never then | Three bar events (UPDATE_BONUS_ACTIONBAR is already registered for the bar cue). Low cost. Risk: the possess part is not in our reference (INFERENCE) |
| M4 | Show only on a skyriding mount (ground included), or never then | One event (can-glide changed). Low cost. Forever client has no skyriding: the row must hide or read "unknown" there |
| M5 | Show only while airborne on a skyriding mount, or never then | One event (gliding changed). Low cost. Risk: whether "gliding" equals "airborne" in every case is INFERENCE; check in game |
| M6 | Show only inside a house or housing plot (optionally only your own), or never there | Two events (plot entered / exited). Low cost. Retail only |
| M7 | Show only inside a delve (lairs excluded), or never there | No new event if read on the zone events we already have; maybe ACTIVE_DELVE_DATA_UPDATE (INFERENCE whether it is needed). Low cost. Cheapest form: add "Delve" to the instance kinds |
| M8 | Show only with a target / only with an attackable target, and the reverse | No new event (target change already registered). Low cost. Risk: soft targeting can briefly report a target after the real one dies; the attackable answer may be secret for some units (INFERENCE) |
| M9 | Show only while Shift, Ctrl or Alt is held | One event (modifier state changed), which only fires on a modifier press or release. Low cost. Risk: Shift-click in chat or bags also flips it; that is expected behaviour |
| M10 | Let "Mounted" also count druid travel, aquatic and flight forms | No new event (form change already registered). Very low cost. A tick box on the existing row |
| M11 | Show only in a zone or sub-zone with a given name | No new event (zone events already registered). Low cost. Risk: names depend on client language; offer "add current" so the stored name comes from the game |
| M12 | Use the role assigned in the group instead of the spec's role | One event (roles assigned) plus the roster event we already have. Low cost. Risk: the answer may be secret in some places; treat as unknown |
| M13 | A switch you toggle with a key binding, usable as a load condition | No game event; our own binding. Low cost. Design questions for Xaya: one switch or several, and does it flip in combat |
| M14 | "Instance" should not count your garrison | No new event. Verify in game first; may already behave this way |
| M15 | Show only while stealthed, or never then | One event (stealth update). Low cost |
| M16 | Show only while any item is worn in a chosen gear slot | No new event (equipment change already registered). Low cost, low value |

Suggested order by value (her call): M1, M2, M3, M8, M4/M5, M9, M10, M6, M7, M12, M13, then the rest.

---

## 4. Independence statement

Nothing was copied from EllesmereUI or ElvUI: no code, no data, no option keys, no label or tooltip text, no assets. Each concept
above is described in our own words from the behaviour it produces. Their files were read as text only, never run, and kept in
their own scratchpad directories. Her Drive folder was only listed and size-checked; nothing in it was written, moved, renamed or
deleted. Any XayaUI implementation of these concepts will be our own design and our own code, built on the game API entries cited
from `docs/reference/api/`.
