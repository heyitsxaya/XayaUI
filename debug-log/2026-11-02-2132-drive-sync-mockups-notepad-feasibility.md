# Debug log 2026-11-02: Drive sync, #259 mockups, notepad feasibility answer

Build: XayaUI 0.5.56 (no code change, no version bump). Session: 014bN6tT2RgkgAqnny8XmpAA (Claude Code, Sonnet 5.5). Status: docs only; nothing tested in game.

## What happened
1. Google Drive copy was at 0.5.49; synced to 0.5.56 (44 files copied from the local addon folder, `XayaUI_Tooltips` renamed `DELETE_XayaUI_Tooltips`, `md5sum -c MANIFEST.md5` clean, toc version 0.5.56). Debug-log entries for 0.5.50 to 0.5.56 and the notepad PNG icons are now in Drive too.
2. #259 mockups drawn from the real option code (private Claude artifact "XayaUI Pane Mockups"). No addon code changed.
3. Notepad feasibility answer written (below).

## GitHub writes
First attempt was refused by the session permission check; Xaya then restated the standing authorization and both were posted: new issue #272 (A) and a comment on #259 (B). Text kept below for the record.

### A. New issue: "Notepad: combat time per unit, rule-linked notes, party assignment inputs (feasibility)"
Build: XayaUI 0.5.56. Session 014bN6tT2RgkgAqnny8XmpAA. Status: feasibility answer only, nothing built, NOT tested in game.

Request (Xaya): (1) while in combat, can the notepad track time spent in combat with a given unit, and can rules be linked to dedicated notes that appear under specific combat conditions? (2) can it have inputs such as party member assignments or links to abilities?

Answer (sources: warcraft.wiki.gg/wiki/Secret_values, first 100,000 of 144,048 characters read; XayaUI code at 659ce79):
- Own combat time and boss-encounter time: feasible. XayaUI already reads player combat state (Conditions.lua 585) and encounter state (Conditions.lua 596); Engine.lua registers PLAYER_REGEN_DISABLED / ENABLED. Timer = GetTime() minus start time. The wiki page does not say these are restricted; absence on that page is not proof.
- Time in combat with a GIVEN unit: UNVERIFIED. The page says UnitName returns secret values for non-player, non-pet units in combat, and unit identity is secret unless the unit is player-controlled or in your party/raid. It does not mention UnitAffectingCombat or UnitGUID. Needs a read-only in-game probe (UnitAffectingCombat and UnitGUID on target, boss1-5, nameplates; dungeon and raid) before any design.
- Rule-to-note link: feasible as a new rule Action (Actions.lua RunActions) that shows and selects a note. Notepad has no select-by-id function yet (Notepad_Next / Prev / AddNote exist). Limited to conditions rules can already read; an UNKNOWN condition does not fire. Showing a plain frame in combat is believed allowed (inference).
- Links to abilities: already supported, `{spell:ID}` (USER-GUIDE 12.4).
- Party assignments: typed text works today. A roster picker is plausible: UnitName is secret only for non-player or pet units per the wiki, so party member names should be readable; UnitGroupRolesAssigned is not mentioned (unconfirmed). Engine.lua registers GROUP_ROSTER_UPDATE. An inserted name is a text snapshot and goes stale when the group changes.
- Xaya previously asked to pause notepad work; not resumed. Probe not written.

### B. Comment on #259
Build 0.5.56, session 014bN6tT2RgkgAqnny8XmpAA. Mockups drawn from the real option code and published as a private Claude artifact titled "XayaUI Pane Mockups" (Add-trigger menu, Target Debuff, Buff / Aura, Texture display, Text). No addon code changed. Findings: the options window is AceConfig/AceGUI, so a tick box plus inline dropdown needs paired options with fractional widths, not a new widget (alignment must still be checked in game: AceGUI dropdown without a label is 26 px high with alignoffset 12; Skin.lua has its own row layout). The Add menu has 18 entries in code (16 types + 2 built-ins), not 19. Waiting on Xaya for four decisions: menu variant, aura Unit/Type at add time vs editable, pane order, small sliders vs number boxes. Not yet mocked: Conditions and cues, Sound, Notepad / Chat / Data Panels.
