# Character Toolkit phase 2: sections, value toggle, conversion hover, one model, sheet, What If, slot overlays (XayaUI QoL 0.7.0)
Logged 2026-11-04 08:27 UTC. Worktree branch `worktree-agent-abfe1cc4a9003ac17` (Claude Code session 014bN6tUvbkCv9Ha9VgNF4Xa). Nothing here has run in the game yet.

## Request
Xaya, 2026-11-04: "surface all possible data that can be pulled from the current API", "improve on [the character window] substantially", not copy it. Phase 2, in order:
1. Presentation: sections with headers, a rating / percent toggle for every rating line, a hover on each line saying where the number comes from. XayaUI's own theme; no code, art or layout from another addon.
2. One stat model feeding every tab (label / value / tooltip pairs, sections, value modes, live GCD, durability and repair cost, Mythic+ rating where the API gives them); StatMath.lua stays frame-free and tested.
3. The panel's own compact stat sheet with its own hover.
4. A What If pane: per-stat rating through the converter, and an item estimate only where the API gives the numbers.
5. Slot overlays (item level, missing enchant / socket where the API reports it; off by default) and a settings entry following the layout rule.

Left open on purpose (not decided here): filling the "not given by the game" rows from a database; the feature name.

## Scope (V4)
`git grep` for `CharToolkit_`, `BuildCharToolkitPage`, `chartoolkit`, `characterToolkit` outside the two toolkit files found no reader or caller. The toolkit plugs in only through `ns.RegisterSettingsPage("qol", "chartoolkit")` and `ns.RegisterCommand("stats")`. The whole-addon harness loads it and walks its settings page.

Touched:
- `XayaUI_QoL/StatMath.lua` (added WhatIf, StatDelta, Coins);
- `XayaUI_QoL/CharacterModel.lua` (new: every game read and the model);
- `XayaUI_QoL/CharacterToolkit.lua` (now the panel, sheet, What If inputs, overlays, events, tooltip hook, settings and command only);
- `XayaUI_QoL/XayaUI_QoL.toc` (0.7.0, loads CharacterModel.lua);
- `tests/char_toolkit_run.py` (phase-1 checks ported to the model), `tests/char_toolkit2_run.py` (new), `tests/char_toolkit_world.lua` (new, shared stand-in world);
- USER-GUIDE 12.12, QA-CHECKLIST E1d to E1n, ROADMAP RM-CHAR, MANIFEST.md5.

Saved settings: new keys in `CueRulesDB.characterToolkit`, each filled with a default by `Cfg()`: valueMode, lineModes, collapsed, whatIfStats, overlays, ovIlvl, ovSockets, ovEnchants, ovSize, enchantSlots. The saved tab names "overview" and "ratings" (0.6.2) map to "sheet" and "stats".

## What changed
1. **Presentation.**
   - Tabs: Sheet | Stats | Defense | Offense | Gear | What If | Spells. Every tab is made of sections with a header; clicking a header folds the section.
   - A line is its label on the left and its value on the right, with label / value detail pairs under it.
   - Hovering a line shows the conversion hover:
     - the total split into the rating share and other sources;
     - the converter and the rate;
     - base against buffs;
     - linked conversions (crit to parry, primary to attack power, dodge or parry, Stamina to health, Versatility to damage taken, block value to block reduction, attack power to DPS);
     - the thresholds.
   - "Show: %" / "Show: rating" in the title row switches every rating line; a click on one rating line flips that line alone (saved per stat; the button clears single-line flips).
   - Colors and font come from `ns.Theme` (classes xui-window, xui-titlebar, xui-tab, xui-tab-selected, xui-button, xui-label, xui-text, xui-text-muted). The panel repaints on `ns.Theme.OnResolve`.
2. **One model** (`CharacterModel.lua`, no frames).
   - `CM.Build(cfg, tab)` returns sections of items. An item has: key, label, kind (rating / stat / wide / input / note), value, the rating-mode value, tone, pairs and tip.
   - The panel tabs, the sheet, the What If pane, the slot overlays (`CM.SlotOverlay`, sharing `CM.SlotInfo` with the Gear tab) and the character-window tooltip lines all read it.
   - Every read goes through `R()`: missing or erroring calls give nothing ("unavailable"). Any secret return becomes `CM.HIDDEN` ("hidden in combat"), so a secret is never compared, formatted or used in arithmetic.
3. **Sheet:** every Stats / Defense / Offense item in two compact columns under the same section headers. Each cell has a hover built from the same lines as the full line (a test compares them), and a click flips a rating.
4. **What If:**
   - Per-stat rating boxes, plus the All ratings box (moved from the 0.6.2 header row). Both go through the game's converter, so thresholds apply, and the crossed thresholds are listed.
   - Compare an item, from a shift-clicked link or an item ID. Both stat tables come from `C_Item.GetItemStats` at the item level in the link, against the equipped item with the same equip location (`C_Item.GetItemInfoInstant`).
   - What the compare shows: rating deltas through the converter; the primary stat change through `GetAttackPowerForStat`; Stamina through `UnitHPPerStamina`; armor through `C_PaperDollInfo.GetArmorEffectiveness`.
   - Shown as not given: gems, enchants and set bonuses (not in an item's stat table); on-use and proc effects; the same item at another item level (no API gives those stats; `C_Item.GetDelvePreviewItemLink` builds links for creation contexts, but what it gives outside delves is the open J2/J3 probe, so it is not used).
5. **Slot overlays** (off by default) on `Character<Slot>Slot` buttons (names from Blizzard's PaperDollFrame.xml).
   - Item level at the bottom, empty sockets at the top (for example 2S).
   - E / E? on the slots the player ticks: the game does not say which slots take an enchant, so none are ticked by default.
   - Updates when the character window opens, through a post-hook on `PaperDollItemSlotButton_Update`, and on equipment, item-data, socket and enchant events (throttled to 0.2 s).
   - Settings layout: Character Toolkit is a node (its page: on/off and quick switches). Its parts are nodes under it: Panel (tabs Layout | What If | Tooltips), Slot Overlays (Show | Enchant Slots) and Spell Math. Every dropdown shares its row; the explanation is in the tooltip.

## Phase-1 behaviour corrected on the way (V9)
Each now has a test:
- **Primary stat base.** 0.6.2 showed `UnitStat`'s first return as the base. Blizzard's PaperDollFrame_SetStat shows base = stat - positive buffs - negative buffs, so the old base included buffs.
- **Spec reads.** 0.6.2 called the old globals GetSpecialization / GetSpecializationInfo / GetSpecializationMasterySpells. The 12.1.5 documentation lists the `C_SpecializationInfo` versions, and Blizzard's character window uses those. The C_ mastery call returns a table, so 0.6.2's mastery text could never have shown when only the C_ call exists. The model now uses C_ first and the globals as a fallback.
- **Crit and spell power.** Spell crit and spell power took the highest school; the character window uses the lowest school. Crit is now chosen exactly as PaperDollFrame_SetCritChance chooses it (V5 parity).
- **Block.** 0.6.2 read `GetShieldBlock` as "a block stops N damage". The character window passes it through armor effectiveness against your level to a percent, and the panel now does the same.
- **Gear change.** The event handler returned early for any event whose first payload was not "player". PLAYER_EQUIPMENT_CHANGED passes a slot number, so the panel did not refresh on a gear change. Now only UNIT_ events are filtered.
- **GCD.** 0.6.2 read the GCD only out of combat. It is now read on every SPELL_UPDATE_COOLDOWN, with the duration field checked for secrecy. While it is secret the panel shows "hidden in combat" with the last readable value, and after PLAYER_REGEN_ENABLED the last readable value shows again.

## Findings for Xaya (the API gives more than 0.6.2 said)
- `GetDodgeChanceFromAttribute` and `GetParryChanceFromAttribute` are documented in 12.1.5 (SecretWhenUnitStatsRestricted). The character window shows them in the Agility / Strength tooltip for tanks ("Increases dodge chance by ..%").
  - The panel now shows those totals ("Dodge from it", "From Agility").
  - The per-point rows stay "not given by the game", as decided.
- `ATTACK_POWER_MAGIC_NUMBER` (3.5 in Blizzard's PaperDollFrame.lua, read at run time, not typed in) is how the character window turns attack power into "Increases damage by N DPS". The panel shows that figure.
  - "Attack power -> weapon damage per hit" stays not given.
- Neither touches the open database question. Both are game figures; no database numbers were added.

## Game calls (12.1.5 documentation flags, docs/reference/api)
New in 0.7.0:

| Call | Flags | Use |
|---|---|---|
| `C_SpecializationInfo.GetSpecialization()` | SecretArguments=AllowedWhenUntainted | spec index |
| `C_SpecializationInfo.GetSpecializationInfo(index)` | SecretArguments=AllowedWhenUntainted | name, role, primary stat (6th) |
| `C_SpecializationInfo.GetSpecializationMasterySpells(index)` → table | SecretArguments=AllowedWhenUntainted | mastery text |
| `GetDodgeChanceFromAttribute()` | SecretWhenUnitStatsRestricted | dodge from Agility |
| `GetParryChanceFromAttribute()` | SecretWhenUnitStatsRestricted | parry from Strength |
| `C_PaperDollInfo.OffhandHasShield()` | (none) | show the block line |
| `C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")` → currentSeasonScore, runs | MayReturnNothing, SecretArguments=AllowedWhenUntainted | Mythic+ rating and best runs |
| `C_ChallengeMode.GetOverallDungeonScore()` | (none) | fallback score |
| `C_ChallengeMode.GetMapUIInfo(id)` | MayReturnNothing, SecretArguments=AllowedWhenUntainted | dungeon names |
| `C_MythicPlus.GetSeasonBestMythicRatingFromThisExpansion()` | MayReturnNothing | best this expansion |
| `C_MythicPlus.RequestMapInfo()` | (none) | once, when the panel first opens |
| `C_TooltipInfo.GetInventoryItem("player", slot)` | MayReturnNothing, SecretArguments=AllowedWhenUntainted | field `repairCost` (INFERENCE: undocumented field; Blizzard's TooltipDataRules shows it in repair mode) |
| `GetRepairAllCost()` → cost, canRepair | undocumented (Blizzard's MerchantFrame reads it this way) | only while MerchantFrame is shown |
| `C_Item.GetItemInfo(id)` (2nd value: link) | MayReturnNothing, SecretArguments=AllowedWhenUntainted | compare by item ID |
| `C_Item.GetItemInfoInstant(link)` (4th value: equip location) | MayReturnNothing, SecretArguments=AllowedWhenUntainted | which equipped item it replaces |
| `C_Item.RequestLoadItemDataByID(id)` | SecretArguments=AllowedWhenUntainted | item not loaded yet |
| `C_Spell.GetSpellCooldown(61304)` (now in combat too) | MayReturnNothing, SecretArguments=AllowedWhenTainted, SecretWhenCooldownsRestricted; fields startTime / duration / modRate may be secret, isActive / isOnGCD NeverSecret | live GCD |
| `ATTACK_POWER_MAGIC_NUMBER` | Blizzard UI value, undocumented | DPS from attack power |
| `ChatFrameUtil.InsertLink` (else `ChatEdit_InsertLink`) | Blizzard UI code, undocumented; post-hook only | shift-click into the item box (INFERENCE) |
| `PaperDollItemSlotButton_Update` | Blizzard UI code; post-hook only | slot overlays follow Blizzard's redraw |
| item link enchant field (2nd field after `item:`) | link format as listed on warcraft.wiki.gg "ItemLink"; INFERENCE that 12.1.5 keeps it | enchant check |

Kept from 0.6.2 (flags now quoted in the CharacterModel.lua header):
- SecretWhenUnitStatsRestricted: GetCombatRating, GetCombatRatingBonus, the crit / haste / mastery / versatility / avoidance / leech / speed / dodge / parry / block reads, UnitStat, UnitArmor, UnitAttackPower, GetAttackPowerForStat, UnitAttackSpeed, UnitDamage, UnitRangedDamage, GetSpellBonusDamage, GetShieldBlock, GetUnitSpeed and the regen reads.
- SecretWhenUnitHealthMaxRestricted: UnitHealthMax.
- No secret flag: GetCombatRatingBonusForCombatRatingValue (the converter), UnitHPPerStamina, GetUnitMaxHealthModifier, C_PaperDollInfo.GetArmorEffectiveness / AgainstTarget / GetStaggerPercentage, GetCritChanceProvidesParryEffect, C_Item.GetItemStats / GetDetailedItemLevelInfo.
- Undocumented, read the way Blizzard's UI reads them: GetInventoryItemLink, GetInventoryItemDurability (EquipmentManager.lua), GetAverageItemLevel (PaperDollFrame.lua).

Blizzard's own calls were read in wow-ui-source (live branch): PaperDollFrame.lua, PaperDollFrame.xml, MerchantFrame.lua, EquipmentManager.lua and TooltipDataRules.lua. Only how the game is called was read; no code was copied. No other addon was looked at.

## Decisions taken here, and why
- **Enchant check.** No slots are ticked by default: no API says which slots take an enchant, and a fixed list would be invented data. Asked as an open question in ROADMAP RM-CHAR.
- **Compare an item.** It replaces the equipped item with the same equip location (the lower item level of two rings or trinkets) because that is what the game reports. A two-hand against one-hand plus off-hand shows "nothing equipped of the same kind".
- **Inputs.** The What If per-stat and All amounts are saved; the item compare text is not (session only).

## Tests
- `tests/char_toolkit_run.py`: 100 checks, 0 failed. These are StatMath plus every 0.6.2 check, kept on the new model; new StatMath checks cover WhatIf with and across thresholds, the 0 floor, the mastery factor, StatDelta and Coins.
- `tests/char_toolkit2_run.py`: 134 checks, 0 failed. They cover: headers per tab and folding; label left and value right; theme colors and font; the value button and the single-line flip; the conversion hover text; short detail; block, DPS from attack power and dodge from Agility; crit parity with the character window; ranged weapon, mana regen, stagger, off hand, expertise and the spell power links; C_SpecializationInfo; the live GCD in combat, hidden, and after combat; Mythic+ and its fallback; durability, repair (sum, not given, vendor) and the enchant field; the sheet (cells, value mode, hover parity, click); layout (inside the width, no overlaps, text fits, two columns, tab labels, height); What If (+852 to the threshold, +1000 across it, mastery factor, -1000 to 0, All plus per-stat); item compare (by link, by ID loading and loaded, shift-click insert, Enter); overlays (off by default, item level, 1S, E? / E, switches, follows Blizzard's redraw); secrets on every tab, the sheet, the hover, the tooltip hook, the item compare and Spell Math; the settings layout and its switches changing what is shown.
- **Secret stand-in.** `type()` says "number" for it, as the game does for a secret number. Any comparison, arithmetic, concatenation, tostring or index on it counts as misuse and errors. The count stays 0.
- **Negative controls** (each run on a scratch copy):
  - the phase-2 test on the 0.6.2 code fails (no model);
  - removing the secret check in `R()`: 14 checks fail (misuse counted 6 times), then the test stops with an error;
  - ModeFor ignoring single-line flips: 3 fail;
  - WhatIf as a straight line: 1 fails in each file (the first file then stops with an error);
  - every slot flagged for an enchant: 1 fails;
  - headers not folding: 1 fails;
  - base read as UnitStat's first value: 1 fails;
  - GCD not read in combat (the 0.6.2 behaviour): 4 fail;
  - sheet hover built differently from the line hover: 2 fail;
  - value button doing nothing: 4 fail;
  - no GCD reset after combat: 1 fails;
  - no shift-click link insert hook: 2 fail;
  - sheet labels without the short label: 1 fails (text fit);
  - theme not used for the background: 1 fails.
- `python3 tests/lua_pitfalls_run.py`: FAILS: 0.
- `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`: every unit suite passes (char_toolkit2 134, char_toolkit 100, lua_pitfalls 69 files FAILS: 0, precheck_run 25). The whole-addon harness reports RESULT: FAIL (17). All 17 are the failure already there before this change: every combination with XayaUI_Options fails on Options.lua:4638, `C_Texture` nil in the harness world (IconReport). The baseline run at the start of this session had the same 17. No new failure; the QoL combinations without Options pass. The API index (`tests/harness/api_index.json`) is not in this checkout (built from Xaya's private documentation dump), so widget methods and events were not checked against it.

## Not verified in game (QA-CHECKLIST E1d to E1n)
- Every number and layout.
- Whether `C_Spell.GetSpellCooldown(61304)`'s duration is readable in combat.
- Whether the tooltip data carries `repairCost` away from a vendor.
- Whether `GetRepairAllCost` answers at a vendor as Blizzard's code implies.
- Whether the Mythic+ summary lists runs before the Mythic+ tab is opened.
- Whether `ChatFrameUtil.InsertLink` still exists and the hook puts a shift-clicked item into the box.
- Whether the overlays sit clear of Blizzard's SocketDisplay.
- The sheet's text widths (estimated at 0.55 x size per character).
- That the item link's enchant field is still the second field.
