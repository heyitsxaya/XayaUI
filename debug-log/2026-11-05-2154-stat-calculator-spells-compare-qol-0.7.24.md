# Stat Calculator: Spells filter icon, spell columns, spell data button; Gear compare viewer "Changes" (XayaUI_QoL 0.7.24)
Logged 2026-11-05 21:54 UTC. Worktree branch on the session branch `claude/adoring-hawking-wyda59`, started at 7102a2a (QoL 0.7.23,
core 0.6.48). Core is not changed. Nothing here has run in the game (QA E1z50-E1z54).

## Requests (Xaya, 2026-11-05, her words)
1. Spells: "Filter tabs should be indicated by a filter icon on the right hand side with "none" by default (therefore showing all);
   Filter options should be "none" (show all), "offense," "defense," "utility""; "add columns to help clarity in info displays: Spell
   Name (spell id underneath) | % PSV (underneath each entry show "1 agility = {value}") | Talent Modifiers"; "remove "usable now" from
   spirit bomb"; "refresh spell data or load spell data should be a button above the spell segments and more clearly clickable /
   defined. put it as a centered button that is no more than 250px wide".
2. Gear: "compare viewer needs a little clearer - selecting an item for comparison from currently equipped gear should highlight the box
   to indicate its selection. clicking it again should deselect it. compare selection for rings, trinkets, and item slots should be
   relabeled to: ring slot #1, ring slot #2, trinket slot #1, trinket slot #2; weapon slots should be relabeled to main-hand and
   off-hand. compare item sublist should be icons like the equipped gear display, and selecting one should highlight the box of the item
   selected as well as the current option of filling in the name in the item slot. compare items should support multi-item selection
   and display. side by side and what it changes options are redundant. Rename the section to "Changes" and show stat changes and then
   "Spell Changes". show added proc differences and anticipated RPPM where applicable"; "gear compare pane should show Stat DR threshold
   and diminishing return true >> lost rating information".

## Scope (V4; `git grep` for spellFilter / SPELL_FILTERS / FilterOf / FilterBtn / filterBtns / RenderFilters, "Usable now" /
## IsSpellUsable, "Refresh spell data" / "Configure spell data" / kind "action", SpellItem / Spell ID, gearSide / gearEffects /
## gearOwn / cmpSlot / "Side by side" / "What it changes" / "Replace instead" / "Replacing" / SlotLabel, SelectGearSlot / PickItem /
## SetInput("item") / compareText / compareSlot / gearSlot, IconBtn / ic.selected / b.sel, SlotTip / TipLines)
- Readers of `spellFilter` / `SPELL_FILTERS` / `FilterOf`: `XayaUI_QoL/CharacterModel.lua` and `CharacterToolkit.lua` only (no other addon).
- `XayaUI_QoL/CharacterModel.lua`
  - `CM.SPELL_FILTERS`: None (show all) (key `all`, the saved default as before), Offense, Defense, Utility; `FILTER_TITLE.utility`
    "Active utility spells"; `CM.FilterOf` accepts `utility`; `CM.FilterShows(filter, kind)` (new) decides what a filter lists.
  - `SpellItem`: the label is the spell's name; `it.row` (new) carries "Spell ID: N", per number { value, pct, per ("1 Agility = +N") },
    the note / Entered lines, the talent modifiers, "Not picked". The pairs stay (the hover and `CM.PairLines` read them).
  - `SpellSection`: the "Usable now" pair and its `C_Spell.IsSpellUsable` call are removed; Spell Math off adds a note under the header
    (the button moved above it); `sec.spells` marks the table sections (Active, Inactive).
  - Gear: `CM.CompareSlotLabel` (new; SlotLabel itself unchanged: the slot overlays and the settings' enchant ticks keep the game's
    names); `ParseTip` (shared by `CM.SlotTip`, unchanged output plus `effectKinds`) and `CM.LinkTip(link)` (new); `CM.MAX_COMPARE`,
    `CM.compareLinks`, `CM.InList`, `CM.AddCompare`, `CM.CompareState` (new); `GearCompareSections` rewritten: the bag items as an
    icons item (`gearOwn`, was choice items `gearOwnN`), Replacing / Replace instead with the new names, one `gearChanges` section
    (`multi`): head `gearCols`, rows `gc_<stat>` (Equipped first, then each item; its change in `subs`), `gc_dr_<stat>` / `gc_tl_<stat>`,
    Stat effects `gc_<card>` / `gc_<card>:<line>` (the old "What it changes" lines; the `pr.change` lines too), Spell Changes
    `gc_spell<ID>`, effects `gc_fx_*`, `gc_fxd_*`, `gc_rppm`. `GearSections` marks the compared slot's icon from `CompareState`.
  - Removed: `gearSide` (Side by side), `gearEffects` (What it changes), the `gearOwnN` choice rows.
- `XayaUI_QoL/CharacterToolkit.lua`
  - Removed: `FilterBtn` / `filterBtns` / `RenderFilters` (the three filter buttons), the in-section action bar (the button row inside
    "- Active spells"), the icon's under-the-item-level `b.sel` mark.
  - New: `SpellDataButton` (UIPanelButtonTemplate + `ns.FlatButton`), `FilterIcon`, `FilterMenu`, `ns.CharToolkit_SetSpellFilter`,
    `RenderSpellBar` / `HideSpellBar`, `SpellCols` / `RenderSpells`, `MultiCols` / `RenderMulti`; `IconBtn` gets `selEdges` (the
    highlight frame) and the bag-item branch (`b.cand`: hover SetBagItem, click picks / lets go, no drop); the item level under an icon
    sits 3 px down (was 1) to clear the frame.
  - `ns.CharToolkit_SelectGearSlot` (a click on the selected slot lets it go and clears the comparison), `ns.CharToolkit_PickItem(text,
    slot, add)` (toggles; `add` for a drop), `ns.CharToolkit_SetInput("item")` (adds the item to the picked ones; empty clears them).
  - Settings: Spell Math > a spell's Filter has Utility; `Cfg` keeps a spell's `kind = "utility"`.
  - `ns.CharToolkit_Drawn` returns `spellBtn`, `filterIcon`, `filterMenu`, `menuRecs` (not `filters`).
- Checked, not changed: `XayaUI_QoL/CharacterReskin.lua`, the slot overlays (`CM.SlotOverlay`, `CM.SlotLabel`), the Stats tab, Stat
  Weights (only read: the DR rows reuse `RatingSections`' `analysis`, `thresholds`, `f`, as Stat Weights does), the item box's drop /
  shift-click hooks (unchanged; they go through `SetInput`).
- V14: nothing new runs while the toolkit is off: the button, the icon and the menu are made the first time the Spells tab is drawn
  (the panel exists only while the toolkit and its panel are on); no event, hook, OnUpdate or timer was added.

## API facts (V2; docs/reference/api)
- `C_TooltipInfo.GetHyperlink(hyperlink: cstring, optionalArg1: number?, optionalArg2: number?, hideVendorPrice: bool?)` → `data:
  TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted (namespaces.md:4708). Read through `R` (pcall); nil = "the game's
  tooltip could not be read". A secret link is not passed.
- `C_TooltipInfo.GetBagItem(bagIndex: BagIndex, slotIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing (namespaces.md:4696):
  not used (the link reads the same lines).
- `Enum.TooltipDataLineType`: `ItemSpellTriggerOnUse` = 44, `ItemSpellTriggerOnEquip` = 45, `ItemSpellTriggerOnProc` = 46
  (enums.md:12668-12670); as `CM.SlotTip` already read them.
- `C_Spell.IsSpellUsable(spellIdentifier: SpellIdentifier)` → `isUsable: bool, insufficientPower: bool` · SecretArguments=AllowedWhenTainted
  (namespaces.md:4440): no longer called.
- `GetAttackPowerForStat(stat: luaIndex, value: number)` → `result: number` · SecretArguments=AllowedWhenUntainted,
  SecretWhenUnitStatsRestricted (globals.md:123); `UnitAttackPower(unit)` → `attackPower, posBuff, negBuff` · SecretWhenUnitStatsRestricted
  (globals.md:559): Spell Changes, the same reads as Ability Scaling; a secret value says "hidden in combat".
- RPPM: `grep -i "ppm\|perMinute"` over docs/reference/api finds nothing; ROADMAP RM-RPPM: "**No API gives an RPPM value.**" So the
  Changes section shows "RPPM: not given by the game" and no number (no third-party data: RM-RPPM is a later step).
- INFERENCE: `GameTooltip:SetBagItem(bag, slot)` (the bag icon's hover) is the tooltip's own method, not in the generated widget docs;
  pcall'd, the item link (SetHyperlink) is the fallback, as the equipped icon's SetInventoryItem already does.
- INFERENCE: `CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")` then `ns.FlatButton` (core): the pattern core's console and
  the Calculator use; pcall'd, a plain Button is the fallback.

## Decisions (mine; each can be changed)
- DECISION (Utility): a spell is Utility when its words put it in neither Offense nor Defense (`CM.SpellKind` gives nil: no damage, no
  heal / absorb / armor / avoidance / leech / damage-taken words) and it is not set by hand to Offense / Defense / both. A spell added
  by hand can be set to Utility. "Both" spells show under Offense and Defense, not Utility. Utility spells without numbers are counted
  ("N without numbers"), as every filter does (the "List spells without numbers" setting lists them).
- DECISION (filter icon): a funnel drawn from four flat bars (XayaUI's own drawing, no game art) at the right end of the Spells tab's top
  row, 20 x 20; muted while None, gold (the label colour) with an accent dot while a filter is on; hover says which. The menu opens
  under it (a child of the panel, above the content), the current choice marked; choosing closes it. The saved key of None stays `all`.
- DECISION (spell data button): in the same top row, centred in the content, width min(250, content - 2 x (icon + gutter)), height
  text size + 12; its label and action are the old ones (Configure spell data while Spell Math is off, else Refresh spell data).
- DECISION (Value): the number itself (38,011) keeps a narrow column of its own, **Value**, between Spell Name and % PSV, one line per
  number, beside its percent. Widths: Value 0.55 x size x 8; Spell Name 27%, Talent Modifiers 22% of the content; % PSV the rest (141
  at the default 450 panel: "355.6% of attack power" fits one line at size 11). Every cell wraps in its column. Talent Modifiers
  shows "none" when no talent names the spell; an Inactive (not picked) talent shows "Not picked: a talent in your trees" under its ID.
- DECISION ("usable now"): it was a general line (any spell `C_Spell.IsSpellUsable` called not usable for a reason other than power, as
  Spirit Bomb without Soul Fragments), so it is removed for every spell, and the call with it.
- DECISION (multi-select): a plain click on a bag item picks it or lets it go (no modifier; shift / ctrl keep the game's own click, as
  on the equipped row); up to 3 picked (`CM.MAX_COMPARE`), a fourth lets the first one picked go; the Item box shows the last one
  picked; Enter in the box adds that item; an empty box lets them all go (as an empty box cleared the comparison before). An item for
  another kind of slot starts the list again. A dropped item is added, never let go.
- DECISION (the limit on screen): as many item columns as fit: item column at least 0.55 x size x 8, Pt value 0.55 x size x 9.5, Stat
  22% (at least 64); never fewer than one item column. 3 items at the default 450 panel up to text size 12, 2 at the narrowest (340) or
  text 16; a line under the head says "N more picked: drag the panel's corner wider ...".
- DECISION (Changes order): stat rows (item level, primary, Stamina, armor, each rating, empty sockets, enchant; DR threshold and True /
  lost under each secondary that changes), then **Stat effects** (the stat map's lines that change, the old "What it changes" lines as
  rows: Equipped = now, each item = then; kept so nothing it showed is lost), then **Spell Changes**, then **On-use and proc effects**.
  Ability Scaling moved from the stat effects to Spell Changes (per item).
- DECISION (Spell Changes): the spells added by hand (Spell Math, attack power ones) first, then the spellbook's damage spells (offense /
  both) with the largest first number; up to 6; each one's first number x (attack power with the item / now), the model's own scaling
  (Spells tab, Ability Scaling). Strength and Agility specs only (the model has no spell-power-per-Intellect read); others get a note.
- DECISION (DR rows): Equipped = the Stats tab's own numbers (Stat Weights' DR Threshold and T/L: the analysis with the game's percent);
  each item = `SM.Analyze` at rating + the item's change through the game's converter; "crosses N" (orange when gaining rating, green
  when losing) from `SM.WhatIf(...).crossed`; L in orange / green when it rises / falls by more than half a point.
- DECISION (effects): full-width lines, not table cells (effect text is long): "Equipped: <line>", "<item>: <line>" or "none", then the
  difference ("adds an effect the equipped item does not have", "loses the equipped item's effect", "the same effect", "a different
  effect"); the RPPM line only when one of the items has an Equip or proc line (types 45 / 46; "where applicable"), not for Use lines.
- DECISION (slot names): only the comparison uses the new names (its header, Replacing / Replace instead, hovers); the slot overlays and
  the Equipped icons' records keep the game's slot names.

## Tests (V1, V11; negative control)
- New `tests/char_spells_compare_run.py`: 68 checks, every one inside pcall: the filter icon (right end of the top row, None by default,
  muted, hover), its menu (None (show all) / Offense / Defense / Utility, None marked), Utility (only Banner), the saved choice read back
  after `Cfg()`, the icon's on state, Offense / Defense contents, a hand-set Utility spell; the column head and positions, "Spell ID: N"
  under the name, Value / % PSV / "1 Agility = +2.00" under it, Talent Modifiers ("Burning Fracture", "none"); no "Usable now" in any
  drawn text or hover; text fit at 450 / size 11; the button (UIPanelButtonTemplate, ns.FlatButton applied, above the first header,
  centred, <= 250, clear of the icon, hover, click, Configure label while off; at 340 / size 16); layout at panels 340 / 450 / 760 x
  text 8 / 11 / 16 x filters None / Utility; the equipped highlight (4 edges), Compare: Ring slot #1, click again lets go; the six new
  slot names; bag icons (item levels, hover SetBagItem then the link), pick (highlight + Item box), two and three columns, the fourth
  lets the first go, click again lets go, Enter adds an item; Replacing / Replace instead names; one Changes section; Critical Strike
  100 | 300 (+200) | 1,000 (+900), Pt 46.0 / 1%; DR threshold 1,380 | 1,380 | passed "crosses 1,380"; True / lost T 528 L 0.0 | T 728
  L 0.0 | T 1,423 L 4.8 (orange); order stats -> Stat effects -> Spell Changes; Spell Changes 6,944 | 7,144 (+200) | 6,944; effect
  lines word for word and the differences; "RPPM: not given by the game" and no RPPM number; no RPPM line without a proc / equip line;
  fit of number cells at 450 / 11; layout of the Gear tab with three items at 340 / 450 / 760 x 8 / 11 / 16 with the columns shown =
  what fits and the "more picked" line exactly when needed; the limit (3 at 450 / size 12, 2 at 340).
- Negative control: the new test run against 7102a2a (a scratch `git worktree add` under the session scratchpad, removed after):
  **68 checks, 68 failed**.
- Changed to the new structure (each change commented in the file): `char_spells_run.py` (filter icon and menu replace the three
  buttons; spell name / ID / columns; "Usable now" now asserted absent; the button), `char_gear_icons_run.py` ("Main-hand", the
  highlight frame), `char_toolkit_run.py` (the ID under the name), `char_toolkit2_run.py` (the Changes rows read through helpers in the
  old shape; bag icons; "Ring slot #2"), `char_stat_columns_run.py` (section 5: the Changes table, Spell Changes, the haste ability
  nested under its line, the Spells guard in columns). Run against 7102a2a: char_spells 2 failed then stopped (no filter icon),
  char_gear_icons 1 failed ("Main Hand") then stopped at the frame check, char_toolkit 1 failed, char_toolkit2 4 failed then stopped, char_stat_columns 6 failed.
- Targeted (this code): char_spells_compare 68 / 0, char_spells 72 / 0, char_gear_icons 26 / 0, char_toolkit 110 / 0, char_toolkit2
  134 / 0 + 166 / 0, char_stat_columns 111 / 0, char_stat_window 98 / 0, char_stat_map 69 / 0, char_pane_overlays 57 / 0, char_reskin
  46 / 0, char_width_probe 20 / 0. lua_pitfalls: 79 files, FAILS 0. Both changed Lua files compile with Lua 5.1 loadstring.
- Full suite: see the commit message / the report (run once at the end, after merging the session branch and main).

## Open questions (for Xaya)
1. Utility's definition (no damage / defensive words) and "both" spells not being Utility: right?
2. The Value column (the number beside % PSV) and "none" under Talent Modifiers: keep, or fold the number under the name?
3. Three picked items at most (the default panel shows all three up to text size 12): enough?
4. Stat effects (the old What it changes lines) kept between the stat rows and Spell Changes: keep, or drop them?
5. Spell Changes: which spells (hand-added first, then the 6 largest damage numbers), and nothing yet for Intellect specs: right?
