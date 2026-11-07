# 2026-11-07 07:17 UTC: XayaUI Nameplates 0.1.0 (target colour on Blizzard's nameplates); Dev Assist 0.7.14 walkthrough

Nameplates session, opened by "Outstanding items 11-06" (session_014bN6tSStpdmmCXviFAqPdQ). REQUEST-LOG A15, NP-1 / NP-2 / NP-3.
Logged 2026-11-07 07:17 UTC.

## Request (Xaya, 2026-11-07 07:04 UTC, her words)
"if you can replicate the following mods and profile functionality into xui and make it cost less, here are the nameplate mods and
settings I rely on" (four Plater export strings). Relayed: "I rely heavily on these three at least, though" (Aura Reorder, Current
Target Color, Reorder Nameplate).

## Reading the export strings (#290)
Copied from the transcript into the session's scratch folder, outside the repo. Decoded for reading only, with Python run isolated
(`python3 -I`), from a separate tools folder: base64, raw deflate, CBOR. All four decoded to the last byte; strings 1 and 3 are
identical. No Lua from them was run. Nothing from them is in the repo except behaviour described in our own words, and her own
values (sizes, colours, on/off), in docs/plans/NAMEPLATES-PLATER-INVENTORY-2026-11-07.md. Plater's spell and NPC lists are given as
counts only.

## Decisions (flagged readings; her standing order: no questions until her older items are on main)
R1-R6 in docs/plans/NAMEPLATES-PLAN-2026-11-07.md. The base is Blizzard's own nameplates; the new addon is disabled by default; target
colour is CSS teal; the settings page is QoL > Nameplates.

## Change
- New addon `XayaUI_Nameplates` 0.1.0 (`## DefaultState: disabled`, own SavedVariables `XayaUINameplatesDB`):
  - `Core.lua`: settings (Target colour on, colour teal rgb(0,128,128) by default), the QoL > Nameplates settings page (the row's
    tick box = Target colour; colour picker; Teal button), `/xui nameplates` (what is on, whether a nameplate addon such as Plater is
    loaded, what the last refresh found), service "nameplates" for the walkthrough.
  - `TargetColor.lua`: one texture of ours (white, tinted) over the fill texture of the target's Blizzard health bar
    (`plate.UnitFrame.HealthBarsContainer.healthBar:GetStatusBarTexture()`, Blizzard_NamePlateBase.lua / Blizzard_NamePlateUnitFrame.lua
    at 12.1.5 commit 297d7aa). Events: PLAYER_TARGET_CHANGED (at once), NAME_PLATE_UNIT_ADDED / _REMOVED (next frame, one queued
    refresh at most; on removal the shown texture is hidden at once because Blizzard re-uses the unit frame). The target's plate is
    found with `C_NamePlate.GetNamePlateForUnit("target")`; `UnitIsUnit` is never called. The player's own plate is skipped.
- `XayaUI_DevAssist` 0.7.14 (0.7.13 is the highest on other branches: chat-246-whisper, d8-raid-rules-main, dreamy-edison-pvb3i1):
  `QAWalks-nameplates.lua`, walkthrough "nameplates-target-colour" (prefill; 9 steps; reads the shown texture's tint, whether the
  addon listens, combat state and instance type; question steps for what only eyes can judge; remembers and puts back the settings).
  `QAWalks-Checklist.lua` regenerated.
- docs/QA-CHECKLIST.md: new section K, steps K1-K4 (no branch uses K).

## V2: game API, quoted (docs/reference/api)
- `C_NamePlate.GetNamePlateForUnit(unitToken: UnitTokenNamePlate, includeForbidden: bool = false)` → `nameplate: NamePlateFrame` · SecretArguments=AllowedWhenUntainted
- `UnitIsUnit(unit1: UnitToken, unit2: UnitToken)` → `result: bool` · RequiresComparableUnitTokens, SecretArguments=AllowedWhenUntainted, SecretWhenUnitComparisonRestricted (why it is not used)
- `NAME_PLATE_UNIT_ADDED (unitToken: UnitTokenType) · SynchronousEvent`; `NAME_PLATE_UNIT_REMOVED (unitToken: UnitTokenType) · SynchronousEvent`; `PLAYER_TARGET_CHANGED · SynchronousEvent`
- `SetVertexColor(colorR, colorG, colorB, a)` · SecretArguments=AllowedWhenTainted (Texture)
INFERENCES (checked by K3 and the walkthrough): GetNamePlateForUnit("target") answers in Mythic+ combat; a texture added to Blizzard's
health bar draws above its fill and below its text; adding it causes no blocked-action message; `## DefaultState: disabled` leaves a
fresh install unticked.

## Scope (V4)
New addon; no existing reader or caller. Core APIs used: ns.RegisterSettingsPage("qol", ...), ns.RegisterCommand("nameplates"),
ns.Provide("nameplates"), ns.Print. No core change. The harness (`tests/harness/run.py`) picks the folder up automatically.

## Tests
- `tests/nameplates_run.py` (new, 27 checks): off at login (no event, no texture, no timer, no OnUpdate); on: the target's bar shows
  teal, anchored to its fill, ARTWORK sub-level 7, one plate only; target change, target cleared, plate added later (next frame),
  several adds = one refresh, removal hides at once, own plate never, a plate without Blizzard's unit frame, UnitIsUnit never called,
  colour / Teal / switch off (incl. a refresh queued before off) / back on, `/xui nameplates` names Plater.
  Negative control: before this change the folder does not exist, so every check fails. Mutations tried, each caught by exactly one
  check: no hide on removal (C4), anchored to the bar instead of the fill (B3), a UnitIsUnit call (D3 and an error).
- `tests/lua_pitfalls_run.py` FAILS 0; harness `--only XayaUI_Nameplates XayaUI_DevAssist --fresh-only` PASS (1 warning, the existing
  debugRecord drift).
- Full suite and precheck: see the commit.

## Not verified in game
Everything. K1-K4 and the walkthrough cover it. The cost comparison with Plater is the performance-test session's (CLEAN-8 note sent).
