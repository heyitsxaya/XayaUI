# Boundary map: Stat Calculator vs Improved Character Display vs Character Reskin (look)

Branch `claude/stat-calculator-v25`, read 2026-11-10. Read-only; nothing in the repo was changed.
Terms used below:
- **SC** = Stat Calculator = only the side panel (`XayaUI_Bonus/CharacterToolkit.lua`, frame `XayaUICharacterToolkit`, parent UIParent).
- **ICD** = Improved Character Display = everything that changes or draws on Blizzard's character window (slot marks, enchant / gem / embellishment blocks, full stat list, extra stat-tooltip lines, slot overlays).
- **LOOK** = the reskin's look (border, background, tab colours, stat-list art, wider / taller window).
Everything below was read directly unless marked INFERENCE.

---------------------------------------------------------------------------------------------------------------------------------
## 1. XayaUI_Bonus/CharacterToolkit.lua (2656 lines) - every touch of Blizzard's character window

### 1a. "Positions itself beside the window" (does NOT change the window)
| Lines | What | Panel works without it? | Minimal seam |
|---|---|---|---|
| 313 `Owner()` = `_G.PaperDollFrame or _G.CharacterFrame` | the frame the show/hide hooks go on | yes | keep (read-only reference) |
| 314 `Docked()` = `CharacterFrame:IsShown()` | decides docked vs standalone | yes (would always be standalone) | keep |
| 752, 755 (in `Build` 743-906) | drag allowed / free position saved only when not docked | yes | keep |
| 908-918 `Place()` | `panel:SetPoint(TOPRIGHT, cf, TOPLEFT, -GUT)` / `(TOPLEFT, cf, TOPRIGHT, GUT)` by `c.side`, else centre of UIParent + `c.free` | yes (standalone only) | keep: anchors the panel *to* the window, sets nothing *on* it |
| 2192 | `Render()` calls `Place()` every draw | - | keep |
| 2269-2282 `ShowIfDocked()` | on window open, show panel if `c.panelOpen` | yes (no auto-open) | keep; it is the auto-open-with-window behaviour |
| 2393-2406 (in `ns.CharToolkit_Apply` 2365-2419) | `owner:HookScript("OnShow", ShowIfDocked)` and `owner:HookScript("OnHide", ...)` (docked panel hides with the window; standalone re-renders) on PaperDollFrame (or CharacterFrame) | yes (no auto-open/close) | Post-hooks on Blizzard's frame but change nothing on it. Classified as "positions beside". Could go to a tiny "dock" helper; no move needed. |
| 2411-2417 (in Apply) | `Docked() and c.panelOpen -> ShowIfDocked()` | yes | keep |
| 2436-2438 (in `SetOpen` 2425-2445) | `panel.standalone = not Docked()` | yes | keep |
| 2563-2565 settings `side` select "Which side of the character window the panel docks to." | - | keep (SC setting) |

### 1b. "Changes or draws on the window" (candidates to move to ICD)
| Lines | What | Panel works without it? | Minimal seam |
|---|---|---|---|
| 2321-2344 `CharButton()` | creates `Button "XayaUICharacterToolkitButton"` **parented to CharacterFrame** (64x18), anchored left of `CharacterFrame.CloseButton` / `CharacterFrameCloseButton` (else TOPRIGHT -28,-3), text "Stat Calc", OnClick `ns.CharToolkit_Toggle()`, tooltip "Opens or closes the Stat Calculator beside this window..." | **yes**: panel also opens from minimap row (2358-2364) and `/xui stats` (2631-2654) | Move the button to ICD; ICD calls the SC through a service (e.g. `statCalc.Toggle/Shown`), SC exposes `ns.CharToolkit_Toggle` already and a "panel shown" query (`statCalc.Shown` at 2220 area). |
| 2346-2357 `ns.CharToolkit_UpdateButton()` | shows/hides the button and paints it with the theme's selected-tab colours while the panel is open | yes | Move with the button; SC needs a "state changed" notification (callback / service event) instead of calling it. Called from 2275, 2281, 2366-2418 (Apply x3), 2444 (SetOpen). |
| 2307-2320 comments | describe the button placement on the window | - | move with it |
| 2560 settings: Panel switch desc "the Stat Calc button on the character window opens and closes it..." and "Off: no panel, no button, no minimap row." | button visibility currently tied to SC `panel` switch | - | ICD needs its own switch (or reads SC's `enabled and panel` through service). |
| 2613 settings: enabled tip "Turns on the Stat Calculator and its character window tools." | wording claims window tools | - | text only |
| 2617 settings intro "a panel beside the character window (its Stat Calc button)..." | wording | - | text only |
| 2338 / 2560 / 2617 / 2636 | user-facing text naming the window button | - | text only |
| 2639-2649 `/xui stats status` | reads `ns.Settings("qol").characterToolkit` (ICD's overlays / tooltips switches) and prints them | yes | ICD settings read from the SC: drop those two fields or move to an ICD status command. |
| 816, 840 tooltip text "QoL > Character Toolkit > Panel" | stale path (Panel is now Bonus > Stat Calculator) | - | text only (not a window touch; noted) |

### 1c. Pieces in the file that do NOT touch the window (checked)
- Panel's own icon buttons use `GameTooltip:SetInventoryItem("player", slot)` / `SetBagItem` (573-589): tooltip on the panel's own buttons, reads inventory, not the window.
- Chat link post-hook 896-904 (`hooksecurefunc` on `ns.Compat.ChatHookTargets("InsertLink")`): chat, not the window.
- Theme hook 2407-2410 (`ns.Theme.OnResolve`).
- Comments only, nothing left in code: 7-9, 88/2240 ("slot overlays ... are XayaUI QoL's"), 82, 100 (overlay keys moved), 2294, 2299, 2373-2374. Header 58-60 still says "Slot overlays (off by default): item level, empty sockets, and 'no enchant'..." - stale comment, the code is in CharacterPane.lua.
- No slot-button, CharacterStatsPane, PaperDollItemSlotButton_Update or PaperDollFrame_UpdateStats reference in this file (grep: none).

### 1d. Dependency of the SC on QoL
- 63-69: model through the `statModel` service only (`Model()` / proxy `CM`).
- 112-171 `Cfg()` returns nil unless `SettingsReady("bonus")`, `SettingsReady("qol")` and the model exist.
- 2457-2466 startup waits for both stores.

---------------------------------------------------------------------------------------------------------------------------------
## 2. XayaUI_QoL/CharacterModel.lua (3717 lines; `ns.CharModel = CM` line 44; service `statModel` 1114-1124)

**It touches the character window: NO.** No CreateFrame, no hooks, no `Character*Slot` / `CharacterFrame` / `PaperDollFrame` references (grep). It reads game APIs only (GetInventoryItemLink, C_TooltipInfo.GetInventoryItem, C_PaperDollInfo.*, GetAverageItemLevel). Comments mention PaperDollFrame.lua as the reference for formulas (32, 242, 467).

Exports: `ns.CharModel` (44); service `statModel` = `{ GcdRule, GcdFor, Live (CM.gcd, CM.gcdHidden), Model(tab) = CM.Flat(MODEL_CLEAN, tab), CM }` (1119-1124).

Consumers and what they call (grep of `CM.x`):
- SC (CharacterToolkit.lua): AddCompare, Big, Build, ChangeDir, ClearCache, ClearTalents, CompareState, FilterOf, FitsSlot, Flat, GEAR_SUM_DEFAULT, GEAR_SUM_STYLES, GearSumStyle, HeaderInfo, InList, IsSecret, ItemStats, MAX_COMPARE, NoteOnly, Numbers, PrimaryStatIndex, R, ReadGCD, ResetSpellRequests, ResolveItemLink, SPELL_FILTERS, STAT_COLORS, SpellName, SpellRequested, TABS, TAB_OK, TooltipLines, ValueFor; state fields compareLinks, compareSlot, compareText, gearSlot, gcdHidden, svBase.
- CharacterPane.lua (ICD): Big, Build ("stats" and nil), ClearCache, EnchantSlots, IsSecret, PairLabel, PairLines, PairText, SLOTS, SlotLabel, SlotOverlay, TooltipLines.
- CharacterReskin.lua (ICD features): Big, Build ("stats"), EnchantSlots, IsSecret, LinkName, N, NO_ILVL, PlainText, R, SLOTS, ShortEnchant, SlotInfo, SlotTip, TooltipLines, TrackColor.
- ShoppingList.lua: EnchantSlots, IsSecret, LinkEnchanted, N, R, SLOTS, SlotEnchant, SlotInfo, SlotLabel.
- Dev Assist: QAWalks-stat-colors uses STAT_COLORS; QAWalks-display uses the statModel service.

### 2a. SC only
| Lines | Content |
|---|---|
| 957-983 `CM.ReadGCD` | live GCD read; only SC calls it (CharacterToolkit 2262-2285, on SPELL_UPDATE_COOLDOWN while panel on). Result `CM.gcd` is read by the stats build (421, 909, 3120) which ICD also builds: ICD's GCD line shows the live check only after the SC has read it (INFERENCE from code paths; shared state). |
| 1143 `CompareSlotLabel`; 1161-1166 `ItemStats` (also used internally by compare) | gear compare |
| 1431-1451 `GearIcon` | Gear tab icons |
| 1504-1527 `GEAR_SUM_STYLES`, `GEAR_SUM_DEFAULT`, `GearSumStyle` (and `GearSummarySection`, but see 2c) | |
| 1528-1546 `GearSections` (Build "gear") | |
| 1547-1764 compare: WI_STATS, ResolveItemLink, EquipLoc, PrimaryFrom, CompareCandidates, Replaced, CompareDeltas, SlotsForLink, FitsSlot, OwnedFor, QualityColor, ChangeTone, MAX_COMPARE, compareLinks, LinkKey, InList, AddCompare, CompareState | |
| 1765-2183 `GearCompareSections` | |
| 2184-2624 spell math: Numbers, SpellKind, SPELL_FILTERS, FilterOf, FilterShows, SpellRequested, ResetSpellRequests, SpellList, SpellItem, Talents, ClearTalents, TalentModifiers, `SpellSection` (Build "spells") | |
| 3630-3659 `HeaderInfo` | panel header |
| 3661-3664 `TABS`, `TAB_OK` | panel tabs |
| 3711-3715 `ValueFor` (also used by TooltipLines, so effectively shared) | |
| 2635 `svBase`, 2654-2680 `ChangeDir`/`Signed` (typed-number colouring; run inside the shared stats build) | panel's What If state lives on the shared module |
| 1063-1082 `StatColorFor`, 2637-2653 `STAT_COLORS` | used by SC and by TooltipLines (hence also ICD hovers) and Reskin list (`it.labelColor`): effectively shared |

### 2b. ICD only
| Lines | Content | Consumer |
|---|---|---|
| 1174-1180 `LinkEnchanted` | | ShoppingList |
| 1247-1279 `ENCHANT_DEFAULT`, `OffHandIsWeapon`, `EnchantSlots(c)` | | CharacterPane overlays + settings, CharacterReskin BlockItems (707-708), ShoppingList (248-249) |
| 1280-1300 `NO_ILVL`, `SlotOverlay(slot, opts)` | "What the overlay on one character-window slot shows" | CharacterPane (NO_ILVL also Reskin) |
| 1302-1330 `TRACK_QUALITY`, `TrackColor` | | CharacterReskin |
| 1331-1430 `PlainText`, enchant-line parse (TipLines, ParseTip), `SlotTip`, `LinkTip` (also GearCompare: shared), `LinkName`, `SlotEnchant`, `ShortEnchant` | | CharacterReskin, ShoppingList |
| 3701-3709 `PairLines` | "for the character window's tooltips and the flat list" | CharacterPane (and Flat, tests) |
| 225-1023 via `Build(cfg, nil)` only: `CharacterSection` 540-604, `DefenseSections` 620-768, `OffenseSections` 794-956 | only reached with tab nil (3688-3693) | CharacterPane AppendTooltip fallback (CharacterPane 231) and `CM.Flat(c, nil)` (tests, statModel.Model(nil)); the SC never builds tab nil in the game (only ns.CharToolkit_Model for tests) |

### 2c. Shared (SC and ICD both need)
| Lines | Content |
|---|---|
| 44-98 HIDDEN, TXT, IsSecret, R, N, Field, num, CR/IDX (86 `CM.R, CM.N, CM.num`) | guarded reads |
| 100-139 formatting: Big, P, SP, F, SB, BF, Show, L, StatName | |
| 141-165 Item/Pair/Tip, SpellName, SpellDesc | |
| 166-263 Context, SpecIndex, PrimaryStat, MasterySpells, Converter, ThresholdsFor, ClearCache, PrimaryStatIndex, CritRead | ClearCache called by SC (2292) and CharacterPane (163) |
| 265-440 RatingItem ... `RatingSections` | used by StatMapSections (3014), compare (1862) and spells (2555) |
| 441-535 ArmorPerPrimary, StatItem, PrimaryItem, StaminaItem | |
| 769-792 HasteRatingFor, SpellPowerNow | |
| 984-1023 GcdRule, GcdFor | |
| 1024-1037 `Flat` (SC tests + statModel.Model) | |
| 1038-1117 hover: HELP_KINDS, NotesOn, StatColorFor, `TooltipLines` | SC panel hover, CharacterReskin stat-list hover, CharacterPane test shim (56) |
| 1126-1143 `SLOTS`, `SlotLabel` | ICD (Pane, Reskin, ShoppingList) and SC internally (GearSections, compare) |
| 1144-1171 GEAR_STATS, ItemStats, ItemLevel | |
| 1181-1246 `SlotSockets`, `SlotInfo` | ICD (Reskin, ShoppingList) + SC internally (GearSummaryItems 1452-1502, GearSections) |
| 1452-1527 `GearSummaryItems`, `GearSummarySection` | built inside every "stats" build (3012), so ICD's builds compute it too (not displayed) |
| 2625-3543 stat map `StatMapSections` (+ helpers 2642-2992: MasteryLabel, STAT_COLORS, Signed, ChangeDir, Was*, SplitChanges, MapNote, MapSub, PerPoint, PairText 2761, NoteOnly 2772, PairLabel 2778, GridHead, MasteryNumbers, MapRating, SubHead, PowerItems, CritEffect) | the "Character Stats" section: SC Stats tab, ICD full stat list (Reskin `ns.CharReskin_ListModel` 1212-1231 reads section `map_character`), ICD tooltip lines (Pane 216 `Build(clean,"stats").byKey[map_*]`) |
| 3545-3628 `StatWeightsSection` | built with "stats" (SC displays; ICD builds but ignores) |
| 3666-3699 `Build` | dispatcher |

Nothing in CharacterModel.lua itself touches the character window. Its header (2-7) still describes it as "the one stat model behind QoL > Character Toolkit" and lists the slot overlays and tooltip lines as consumers.

---------------------------------------------------------------------------------------------------------------------------------
## 3. CharacterPane.lua and CharacterReskin.lua: links to the SC

### XayaUI_QoL/CharacterPane.lua (382 lines) - all ICD
- Calls NOTHING in CharacterToolkit.lua (grep: no `ns.CharToolkit_*` it calls is defined in the Bonus file; every `ns.CharToolkit_*` it uses it defines itself).
- Uses the SC's **naming** for its own exports: `ns.CharToolkit_TooltipLines` (56), `ns.CharToolkit_UpdateOverlays` (133), `ns.CharToolkit_OverlayText` (142), `ns.CharToolkit_KeyForLabel` (196), `ns.CharToolkit_HookStatFrames` (256). `ns.CharToolkit_UpdateOverlays` is also called by CharacterReskin.lua (1440, 1469, 1484). Same `ns` namespace as the Bonus file's `ns.CharToolkit_*` (collision risk only by name; no overlap today).
- Settings key `XayaUIQoLDB.characterToolkit` (41-52) = the QoL half of the SC's old key (LEGACY_SPLIT, see 4).
- Built from the SC's model / settings shape: AppendTooltip 202-244 builds `clean = setmetatable({ whatIf=0, whatIfStats={}, whatIfPrimary=false, detail="all", collapsed={}, statOpen={}, spells={} }, { __index = c })` (215) - the Stat Calculator's settings shape with the QoL cfg as fallback (comment 214: "the Stat Calculator's settings are XayaUI Bonus Features' now: the model is read with the panel's defaults"). Old SC keys left in XayaUIQoLDB.characterToolkit by the copy-not-move (e.g. gearSumStyle, spellsAll) can leak through `__index` (INFERENCE: harmless; only the stats build reads gearSumStyle, not shown).
- Text naming the SC: 12 (comment: tooltip lines "show the Stat Calculator's numbers ... an ambiguous piece, kept with QoL"), 322 TIP_TEXT "The panel's own hover does not need this.", 325 tip "Adds Stat Calculator lines to the character window's stat tooltips.", 376 intro "The Stat Calculator is in Bonus Features > Stat Calculator.".
- Window touches (all ICD): `Owner()` 85; overlays on `_G["Character"..slot]` 91-146; `PaperDollFrame:HookScript("OnShow")` 281-287; `hooksecurefunc("PaperDollFrame_UpdateStats")` 288-291; each `CharacterStatsPane` child `HookScript("OnEnter", AppendTooltip)` 246-255; `hooksecurefunc("PaperDollItemSlotButton_Update", UpdateOverlay)` 295-298.
- Calls into Reskin: `ns.CharReskin_DrawsIlvl/DrawsEnchants/DrawsSockets` (116-118).
- Settings page: `ns.RegisterSettingsPage("qol", "chartoolkit", ns.BuildCharToolkitPage)` 382, title "Character Toolkit" (370).

### XayaUI_QoL/CharacterReskin.lua (1757 lines)
- Calls NOTHING in CharacterToolkit.lua. Calls CharacterPane.lua's `ns.CharPane_ToolkitCfg` (707, enchant slots) and `ns.CharToolkit_UpdateOverlays` (1440, 1469, 1484).
- Exists "for" the SC only in wording/data: the full stat list is "every line of the Stat Calculator's Character Stats" built from `CM.Build(LIST_CLEAN, "stats")` with `LIST_CLEAN = { whatIf=0, whatIfStats={}, whatIfPrimary=false, detail="all", collapsed={} }` (1208, 1212-1231). Text naming the SC: comments 51-52, 1196-1206; settings strings 1590 ("Every line of the Stat Calculator's Character Stats ... gives the Stat Calculator's back"), 1662 ("Shows every Character Stats line of the Stat Calculator"); BlockItems hover 715 "(Character Toolkit > enchant slots)"; 57 "the Character Toolkit's good / warn tones". Nothing is configured from the SC's settings (it never reads XayaUIBonusDB).

---------------------------------------------------------------------------------------------------------------------------------
## 4. Settings

### Saved keys (core `XayaUI/Modules.lua` 73, 78, 83 module key lists; 106-112 LEGACY_SPLIT; 385-438 key move)
| Key | Holds | Side |
|---|---|---|
| `XayaUIBonusDB.characterToolkit` | panel keys (defaults CharacterToolkit 76-101): enabled, panel, side, detail, fontSize, opacity, advanced, spells, spellFilter, spellsAll, free, panelOpen, sizeMode, heightSmall, heightLarge, size, tab, gearSumStyle, whatIf, whatIfStats, whatIfPrimary, collapsed, statOpen (+ dropped valueMode/lineModes) | SC. `side` = which side of the window it docks; `panel` currently also governs the window's "Stat Calc" button (2348); `panelOpen` = auto-open with the window. |
| `XayaUIQoLDB.characterToolkit` | QoL half (CharacterPane 26-34): enabled, tooltips, overlays, ovIlvl, ovSockets, ovEnchants, ovSize, enchantSlots, enchantSlotsSet. Plus a stale full copy of the SC keys (key move = "copy, never move", Modules.lua 385-392) | ICD. `enabled` is in BOTH halves (LEGACY_SPLIT `both = { enabled = true }`, line 108). Also read by CharacterReskin (707) and ShoppingList (248) for enchantSlots, and by SC `/xui stats status` (CharacterToolkit 2642). QoL profile part saves it (XayaUI_QoL/ProfilePart.lua 10); Bonus profile part does NOT list characterToolkit (XayaUI_Bonus/ProfilePart.lua 10-11). |
| `XayaUIQoLDB.characterReskin` | "rest" half (features): features, ilvl, enchants, gems, statList, statHide, statOrder, statMode, statName, statColor, groupName, groupColor | ICD |
| `XayaUIReskinDB.characterReskin` | LEGACY_SPLIT sub (Modules.lua 106-107): enabled, chrome, stats, bgAlpha, wide, widePx, widePxTo42, tallPx | LOOK |
| `XayaUIQoLDB.characterReskinLook` | the LOOK half when XayaUI_Reskin is missing (CharacterReskin 81-118; Modules.lua 71-73) | LOOK |
| `CueRulesDB.characterReskin` (old, read via `ns.SettingsOldValue`, CharacterReskin 176-181) | fallback for `features` first value | ICD (migration only) |
| Platform profile part "reskin" (Modules.lua 1447-1449) | db includes `characterReskin` | LOOK+ICD key name |

### Settings pages
| Module / key | Title (tree) | Built in | Shows |
|---|---|---|---|
| `bonus` / `statcalc` | Bonus Features > **Stat Calculator** (parts Panel, Spell Math) | CharacterToolkit 2489-2622, registered 2630 | SC only; includes `side` (2563) and the panel switch whose text covers the window button (2560) |
| `qol` / `chartoolkit` | QoL > **Character Toolkit** (parts Slot Overlays, Tooltip lines) | CharacterPane 310-381, registered 382 | ICD |
| `qol` / `charpane` | QoL > **Character Pane** (switch `features`; ilvl, enchants, gems, statList; sub-page Stat list) | CharacterReskin 1580-1665, registered 1666 | ICD |
| `reskin` / `charreskin` | Blizzard UI Reskin > **Character Pane** (switch "Character Reskin"; chrome, stats, wide, widePx, tallPx, bgAlpha) | CharacterReskin 1672-1703, registered 1704 | LOOK |
Commands: `/xui stats` (SC, CharacterToolkit 2631-2654), `/xui reskin` (CharacterReskin 1720-1757, mixes LOOK and ICD status: slot blocks, stat list).
Note: two pages are titled "Character Pane" (qol/charpane and reskin/charreskin) and ICD is split across two QoL pages (chartoolkit + charpane).

---------------------------------------------------------------------------------------------------------------------------------
## 5. CharacterReskin.lua split: LOOK vs FEATURES (ICD)

Note: the A24 #3 plan says "split into CharacterReskin.lua (look) and CharacterPane.lua (features)", but **XayaUI_QoL/CharacterPane.lua already exists** (overlays + tooltip lines). The features half either merges into it or takes a new name.

### LOOK only
| Lines | Content |
|---|---|
| 76-118 | `LOOK = ns.SettingsSplitSub("characterReskin")`, ReskinS, `ReskinMissing`, `MainLook` (characterReskinLook) |
| 249-252 | MODEL_REGIONS |
| 254-276 | `StyleTabs` (tab colours) |
| 282-292 | `PaintBackground` |
| 294-332 | `StyleWindow` (fade frame art, border edges, inset fills, title colour) |
| 908-1100 | wider window + extra height: `wide` state, NotProtected, PointOf, WideFrames, OnCharacterTab, InCombat, PutBack, WaitForCombatEnd, TALL_COLS/tall/`ns.CharReskin_TallGap` (987), TallAnchors, RestoreTall, ApplyTall, RestoreWide (1036-1055), ApplyWide (1058-1099) |
| 1106-1128 | WideRegen, HookWide (`hooksecurefunc(CharacterFrame, "UpdateSize")`, `PaperDollFrame:HookScript("OnShow")`) |
| 1129 | `ns.CharReskin_WideOn` |
| 1153-1189 | `StyleStats` (stat-list art) |
| 1388 | `On(c)` |
| 1395-1422 | `OtherSkin`, `ns.CharReskin_OtherSkin`, `LookActive` |
| 1492-1500 (in Hook) | `ns.RegisterElement("characterPane")` |
| 1523-1525 (in Hook) | `hooksecurefunc("PanelTemplates_SetTab")` -> StyleTabs |
| 1672-1704 | `ns.BuildCharReskinPage`, register reskin/charreskin |
| 1709-1712 | `RegisterConflict` (its `on` uses `CharReskin_Active`, which includes the features: INFERENCE it should become LookActive after the split) |
| 1715-1718 | theme scope `reskin.charreskin` registration |
| 1720-1757 | `/xui reskin` (on/off are LOOK; status prints both) |

### FEATURES only (ICD)
| Lines | Content |
|---|---|
| 168-187 | loggedIn, `FeaturesOn` (`ns.CharReskin_FeaturesOn`); its first value falls back to the LOOK switch (`ns.SwitchInEffect("reskin.charreskin", lookT.enabled)`) |
| 336-373 | slot layout constants |
| 375-418 | SlotName, FontPath, SetSize, Mine, Rect, Overlaps, SlotBtn, Justify, `Geometry` (reads `ns.CharReskin_TallGap` 433 - coupling to LOOK) |
| 419-652 | LabelBoxes, WordsFit, Measure, PlaceTop, RowEnter/RowLeave, NewRow, BlockRows, ShowRow, SetBlockAlpha, Fit, LayoutBlock |
| 654-666 | CamShown, UpdateCamHide |
| 668-691 | ScanForeign, ShowIlvl |
| 693-762 | tipCache, EmbCount, BlockItems |
| 764-805 | `UpdateSlot` (**line 769 is LOOK**: `if c.chrome then Fade(slot frame art)`) |
| 807-826 | dup check |
| 828-862 | relayout (`SizeChanged` 862 is called by LOOK's wide/tall code 1012, 1031, 1044, 1088, 1114) |
| 864-897 | `UpdateSlots` |
| 899-906 | OtherText (for /xui reskin status) |
| 1194-1381 | full stat list: LIST_CLEAN, ListModel, ListOrder, HasRating, ListValue, UpdateStatList, HideStatList, QueueStatList, StatListRecs |
| 1423, 1427 | `FeatActive`, `ns.CharReskin_FeaturesActive` |
| 1428-1432 | `ns.CharReskin_DrawsIlvl/DrawsEnchants/DrawsSockets` (read by CharacterPane 116-118) |
| 1445-1453 | SLOT_EVENTS, SetEvents |
| 1501-1507 (in Hook) | camera ControlFrame OnShow/OnHide hooks |
| 1509-1515 (in Hook) | `hooksecurefunc("PaperDollItemSlotButton_Update")` -> UpdateSlot (also does the LOOK fade via 769) |
| 1526-1538 (in Hook) | slot-events frame |
| 1580-1666 | `ns.BuildCharPanePage`, register qol/charpane |

### Shared (both halves need)
| Lines | Content |
|---|---|
| 39-44 | ns, QolS, store declaration, CM |
| 52-62 | DEFAULTS (mixes both halves' keys), LIMITS, LIST_TABLES, GOOD/WARN, CHARRESKIN_DEFAULTS |
| 70-75, 119-152 | `cfg` proxy over featT/lookT, `Halves()`, `Cfg()` (`ns.CharReskin_Cfg`), widePxTo42 step |
| 188-199 | `diag` (CharReskinDiag), num, SCOPE/TC (`ns.CharReskin_ThemeCol`): both halves paint with the `reskin.charreskin` theme scope (e.g. stat list colours 1599, 1645) |
| 201-224 | Fade, Recolor, RestoreAll (Fade used by features via UpdateSlot 769 for chrome) |
| 226-229 | own, Own, SetOwnShown (`ns.CharReskinParts`; feature rows/stat list and look pieces share it) |
| 230-244 | Active/Guard/LookActive/FeatActive forward decls, LOOK_PARTS/FEAT_PARTS, `eff` view, `Eff()` |
| 1101-1105 | `WideAndSlots` (ApplyWide + UpdateSlots) |
| 1133-1148 | `characterReskin` service (WideOn = LOOK; Drawn counts ICD pieces and both flags) |
| 1424-1426 | Active, `ns.CharReskin_Active`, `ns.CharReskin_LookActive` |
| 1434-1443 | Guard (turns both off on error) |
| 1455-1461 | theme listener |
| 1463-1485 | ApplyNow (orders: background, chrome, wide, slots, stat art, stat list, events) |
| 1487-1491, 1516-1522 | Hook(): `CharacterFrame:HookScript("OnShow")` (both); `hooksecurefunc("PaperDollFrame_UpdateStats")` does StyleStats (LOOK) and QueueStatList (ICD) |
| 1541-1556 | `ns.CharReskin_Apply`, startup, `ns.RegisterReskin("charreskin")` (the Reskin tab switch also re-applies the features) |
| 1560-1575 | PageControls (both pages) |
Minimal seam: each half gets its own Cfg view (LOOK: lookT only; ICD: featT only), its own Fade/Own pools (or a tiny shared helper), and its own hook set; LOOK exposes `TallGap`, `WideOn` and a "size changed" signal; ICD's UpdateSlot drops the chrome fade (LOOK fades slot frames itself in its own `PaperDollItemSlotButton_Update` hook); `FeaturesOn`'s fallback to the LOOK switch stays a one-time migration read.

---------------------------------------------------------------------------------------------------------------------------------
## 6. Quotes from the docs

### docs/process/REQUEST-LOG.md, section A (session S1)
- Row 34 (line 71): "stat calculator should have a toggle open/close button on the character menu and remember the last-left state on next open; it should also have its own open button on the minimap and should be openable as its own standalone window without opening the character sheet." | MAIN (5490478) | af87755 | Minimap: built as a row in XayaUI's minimap list, not a separate icon: CONFIRM.
- Row 24 (line 62): "durability and repair can be removed from all stat calculator panes"
- Row 8 notes (line 47): "OPEN: QoL Character Toolkit hooks after switching off in a session; ..."
- Row 46 (line 83): "Assume yes for now" (Character Toolkit "Tooltip lines" gets its own row and tick box) ... "Character Toolkit > **Tooltip lines** row with its own tick box (was Panel > Tooltips); its hooks are placed only once it is on"
- Row 70 (line 105): "missing details about about all possible stats / the ability to customize how to display stats in the primary character window"
- Row 71 (line 106): Her answers 2026-11-06 (question box, to #69-#70): slot info "Over the model"; stats list "2 but customizable and prettified with colors" (option 2: the same lines as the Stat Calculator's Character Stats); customise: "Show / hide each stat, Order, % / rating / both, Groups and colours"
- Row 56 (line 91): minimap "If standalone addon, minimal button; otherwise fold into xui minimap button" ... "#34: Stat Calculator is part of XayaUI_QoL, so it stays a row in the XayaUI minimap button (as built)."

### REQUEST-LOG.md section A3 (session S3) (line 254-259) points to `docs/process/REQUEST-LOG-session-014bN6tStyDJVemzE9tX7F38.md`; relevant rows there:
- R39 (line 65): "stats pane should be stat value calculator / "character toolkit" title should be changed to `Stat Calculator`" [screenshot]
- R41 (line 67): ""sheet" tab is not intended to be a tab but instead a reskin of the character pane" / "prettify the character window" [3 screenshots]
- R45 (line 71): "improved character pane should show ivl colored based on ilv tier (track (common, adventurer, veteran, champion, heroic, mythic) AND upgrade tier (color gradient)); enchants + gems should show to the side of the character pane / character pane should be resizable"
- R55 (line 81): "THIS window needs to look beautiful and CLEAN. the window to the right needs to surface all interconnected data in a clean, digestible way" [screenshot]

### REQUEST-LOG.md section A24 (this session), rows 3-4 (lines 680-681)
- #3: file names: "reminder that the stat calculator is ONLY the window that appears by the side of the character pane. NOTHING that directly touches the character pane is part of the stat calculator and anything that currently is bundled in must be removed and separated"; reskin file: "Split into two files". Note column: "(c) ... (INFERENCE until mapped: the Stat Calc button on the character window, slot overlays, tooltip lines, the shared model's slot reads) moves out of it; ... (d) CharacterReskin.lua is split into CharacterReskin.lua (look) and CharacterPane.lua (features)."
- #4: "call the character functionality modifications Improved Character Display"

### docs/plans/STAT-CALCULATOR-REQUIREMENTS-2026-11-04.md
- Section heads: "## A. The character window (Blizzard's), restyled: QoL Character Reskin" (A1-A8) and "## B. The side panel (Stat Calculator)" (B1-B13). The document itself puts the window work outside the SC.
- A3: "the toolkit overlays leave their item level out under it"
- A5: "enchants + gems should show to the side of the character pane" (plan 11)
- A8: "The character window's stat tooltips: ... "do you see how these tooltips behave?"; "no. I don't want a bar next to the threshold"" -> "Our lines under Blizzard's stat tooltips become a compact block" (listed under section A, the window, not B).
- B3: "SIDE PANEL THAT SHOWS ME INFO ABOUT THE POINTS TO % CONVERSION PER STAT AND ... HOW MUCH EACH SECONDARY STAT INFLUENCES PARTS OF MY KIT"; "the window to the right needs to surface all interconnected data in a clean, digestible way"
- Reconciled conflicts: "#383 ("Stats are meant to be tooltips / direct reskins of the character window; only What If, Gear review and Spells are the extra pane") vs her later "side panel that shows ... points to % conversion ... how the stats map ... with the option to change the numbers": the later words win. The side panel's Stats tab is the map, and the map's editable numbers are the What If. The character window gets the reskin and the compact tooltips."
- The requirements doc does not mention the "Stat Calc" button on the window (that came later: REQUEST-LOG S1 #34) and does not list slot overlays under B.

---------------------------------------------------------------------------------------------------------------------------------
## Summary of what must move out of the SC file
1. The "Stat Calc" button on CharacterFrame: CharacterToolkit 2321-2357 (+ calls at 2275, 2281, 2366-2418, 2444 and the button wording in 2338, 2560, 2613, 2617). Only real window-drawing code left in the SC.
2. `/xui stats status` reading ICD settings (2639-2649): drop or move.
3. Stale header comment 58-60 (slot overlays).
Docking (Place 908-918), auto-open/close hooks on PaperDollFrame (2393-2406, 2269-2282), `side` setting: positioning only; can stay with the SC by her rule's wording ("the window that appears by the side"). A judgment call for her: the OnShow/OnHide HookScript is a hook on Blizzard's frame (it does not change the frame).
