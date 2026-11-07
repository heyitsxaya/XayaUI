# 2026-11-07 08:32 UTC: XayaUI Nameplates 0.2.0, "Match my Plater settings" (Blizzard's own nameplate options)

Nameplates session. REQUEST-LOG A15 NP-1, NP-4 (overnight order: everything implemented). Logged 2026-11-07 08:32 UTC.

## Change
- `XayaUI_Nameplates/BlizzardOptions.lua` (new): 12 rows, each mapping one of her Plater settings (inventory section 3) to one bit of
  Blizzard's nameplate option bit fields `nameplateInfoDisplay`, `nameplateCastBarDisplay`, `nameplateThreatDisplay`,
  `nameplateEnemyNpcAuraDisplay` (names from Blizzard_NamePlateConstants.lua; bit = the Enum.NamePlate* value, as Blizzard reads it in
  Blizzard_NamePlateUnitFrame.lua 488-501 / 635-638 and Blizzard_NamePlateHealthBar.lua 78-79, 12.1.5 commit 297d7aa).
  Apply / Put back on a click only, refused in combat; the values before the first Apply are saved (`XayaUINameplatesDB.blizzBefore`)
  and Put back restores exactly those. Each set is read back; a refused one is named.
- `Core.lua`: the page gets "Blizzard's nameplate options": the list (with her Plater setting beside each), "Now: N of 12 match",
  Match my Plater settings, Put back. Version 0.2.0 (toc lists the new file).
- Dev Assist 0.7.32 (0.7.31 is the highest on other branches, d8-raid-rules-ready): second walkthrough "nameplates-blizzard-options" (prefill; reads the 12 bits back).
- QA-CHECKLIST K5; QAWalks-Checklist.lua regenerated. Plan: slice 2a.

## V2
- `C_CVar.GetCVarBitfield(name: cstring, index: luaIndex)` → `value: bool?` · SecretArguments=NotAllowed
- `C_CVar.SetCVarBitfield(name: cstring, index: luaIndex, value: bool)` → `success: bool` · RequiresIndexInRange, RequiresNonReadOnlyCVar, RequiresNonSecureCVar, RequiresValidAndPublicCVar, SecretArguments=NotAllowed
- `Enum.NamePlateInfoDisplay` CurrentHealthPercent 1, CurrentHealthValue 2, RarityIcon 3; `Enum.NamePlateCastBarDisplay` SpellName 1, SpellIcon 2, SpellTarget 3, HighlightImportantCasts 4; `Enum.NamePlateThreatDisplay` Progressive 1, Flash 2, HealthBarColor 3; `Enum.NamePlateEnemyNpcAuraDisplay` Debuffs 2, CrowdControl 3.
INFERENCES (the walkthrough reads the bits back in game): the enum value is the luaIndex (CvarUtil.lua's emulation decrements it
"going into C++"); these console variables are not secure (else the game refuses and the addon names the refused rows); her "aggro
glow" maps to Blizzard's Progressive threat display.

## Mapping choices (flagged; in the QA question flow via NP-Q1 / NP-Q7)
Enemy buffs are left alone (her profile shows the unit's own buffs "as Blizzard does" but not enemy buffs in general: ambiguous).
"Highlight when cast target" is left alone (no Plater setting maps to it). Highlight important casts is turned on as the replacement for
her important-cast scripts (plan B3).

## Tests
`tests/nameplates_run.py` section G (8 checks): no option read or set at load; refused in combat; the 12 bits set as her profile; unmapped
bits untouched; "12 of 12 match"; Put back restores what was there before the FIRST Match; Put back greyed after; a refused option is
named. Mutations caught: Flash row value flipped (G3), combat guard removed (G2). Negative control: before 0.2.0 the file and buttons do
not exist (section G errors).

## Not verified in game
All of it (K5 and the walkthrough).

## 0.2.1 (2026-11-07 ~10:15 UTC): found by the full suite on 2b1bbb6
- `display_standard_run.py` check 3 and `sidebar_switches_run.py` A: the Target colour row switch had no `tip` (the left-pane hover; UI-42 wants one sentence without "Off") and was not in the sidebar test's list of rows with a switch. Core.lua now gives `tip` = "Colours your target's health bar on Blizzard's nameplates in the colour set on this page (default teal)."; `qol>nameplates` added to the test's WANT list (the row exists only while the addon is enabled). Both tests fail on 2b1bbb6 and pass now. Version 0.2.1.
