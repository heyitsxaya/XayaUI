# Stat Calculator: window (button, saved state, minimap row, Min / Max), one Character Stats section, Stat Weights (XayaUI_QoL 0.7.23, core 0.6.48)
Logged 2026-11-05 20:52 UTC. Worktree branch on the session branch `claude/adoring-hawking-wyda59`: started at 907475b (QoL 0.7.21),
merged the session branch at 0f05ad6 (main efab00a: QoL 0.7.21 "Stat Calculator opens 450 wide, Rating 528 +172"; this branch's
character pane build relabelled QoL 0.7.22) before the final run, so this batch is QoL 0.7.23. Nothing here has run in the game
(QA E1z45-E1z49).

## Requests (Xaya, 2026-11-05, her words)
1. "stat calculator should have a toggle open/close button on the character menu and remember the last-left state on next open; it
   should also have its own open button on the minimap and should be openable as its own standalone window without opening the
   character sheet. should have a min/max window toggle that toggles between two configured sizes -- one smaller and one larger (NOT
   full screen, just longer) -- as well as the free resize option in the bottom corner"
2. "combine primary, secondary, and tertiary stats into one major section under the name "Character Stats""; structure Core Stats >
   Primary (agility / strength / intellect, stamina), General (health; mana / energy / resource "(for a drain-type resource: total
   amount; for a generator: max possible; generation rate only for drain classes)"; gcd; movement speed), Offensive (Attack Power /
   Spell Power, Attack Speed, Weapon DPS, Damage, Critical strike effectiveness), Defensive (Armor, Dodge, Parry, Block); then
   Secondaries, then Tertiaries. "remove "all ratings" as an entry option"; "durability and repair can be removed from all stat
   calculator panes"; the Gear tab's Summary "belongs in stats pane". Her crit example: "Enchant Ring - Eyes of the Eagle ...
   increasing critical strike effectiveness by 2%".
3. "Stat Weights should be a collapsible pane below the character stats that shows how all stats affect one another"; columns "Stat |
   Rating (P / %) | PPP | | DR Threshold | T/L Rating | Influences"; her row "Haste | 1442 / 32.5% | 48.9 / 1% (under if above DR
   threshold DR conversion value) | DR Threshold | T: 1429 / L: 12.2 | Influences: GCD (amount), Attack Speed (amount)"; "hovering over
   a given row/column for influences should say "{stat} increases/decreases {other stat} by {amount}"".

## Scope (V4; `git grep` for Launchers / RegisterLauncher, userHidden, Toggle, ShowIfDocked, c.size, whatIf / "all" / map_all,
## durability / repair / MoneyText / SlotRepairCost / GetRepairAllCost / MERCHANT_ / UPDATE_INVENTORY_DURABILITY, gearSum, map_weapon /
## map_regen / map_ranged, Primary stats / Secondary stats / Offense (what feeds it), noAll, MAP_KEY)
- Core 0.6.48: a launcher entry may carry `available = function` (`XayaUI/Modules.lua` documents it); `XayaUI/MinimapButton.lua`
  leaves an entry whose `available()` is false out of the list (`Visible`, read each time the list opens) and hides its row on
  Settings > Minimap Button (`hidden` function). Readers of the list: those two only. (A first version added `ns.UnregisterLauncher`
  and took the row out of the list on switch-off; the full suite's `tests/sidebar_switches_run.py` failed 2 checks with it: "the options
  tree is the same with qol>chartoolkit (and its panelPart) off and on (a tick may reuse the drawn tree)", because the Minimap Button
  page's row list changed with the switch, so a sidebar tick that reuses the drawn tree would have shown a stale list. Replaced by
  `available`, which keeps the tree the same; that test then passed, 72 / 0.)
- `XayaUI_QoL/CharacterToolkit.lua`:
  - settings `panelOpen` (default true), `sizeMode` (small / large), `heightSmall` 440, `heightLarge` 760; `c.size` keeps the width only
    (a saved height from before becomes `heightSmall`); `c.whatIf` forced to 0.
  - `ns.CharToolkit_SetOpen`, `Toggle` (now SetOpen(not shown)), `SizeMode`, `UpdateButton`; `ShowIfDocked` follows `panelOpen`
    (replaces the session-only `panel.userHidden`); the character window's OnHide closes a docked panel, keeps one opened on its own.
  - the Stat Calc button (`XayaUICharacterToolkitButton`), made only once the toolkit and its panel are on, hidden when either goes off;
    the minimap row registered once at load with `available` = toolkit and panel on.
  - the Min / Max button (`panel.sizeBtn`) in the title row; the grip sets the width and the current mode's height; `Render` sets the
    mode's height (the content-following height is gone).
  - `RenderGrid`: `subhead` records (the tree's headings), the Gear Summary's cmp head and rows (`CmpHead` / `CmpRow`, shared with
    `RenderSections`); `RenderWeights` / `WeightCols` for the Stat Weights pane.
  - events: UPDATE_INVENTORY_DURABILITY, MERCHANT_SHOW, MERCHANT_CLOSED no longer registered (nothing reads them now).
  - `MAP_KEY`: speed -> map_aspeed, damage -> map_damage (the character window's Attack Speed / Damage tooltips).
  - settings page: All ratings field removed; Smaller / Larger height; Reset size resets both heights; texts.
- `XayaUI_QoL/CharacterModel.lua`:
  - `StatMapSections` builds one section `map_character` "Character Stats" (headings `SubHead`); the old Primary / Secondary / Tertiary
    / Offense / Defense sections are its parts, in her order. New lines: Health (`map_health`), resources (`map_power<type>`), Movement
    speed (`map_movespeed`), Attack Speed / Weapon DPS / Damage (`map_aspeed`, `map_wdps`, `map_damage`, from the old `map_weapon` and
    `map_ranged`), Critical strike effectiveness (`map_critfx`). Block always listed. Removed: `map_all` (All ratings), `map_regen`
    (the resource lines replace it), `map_weapon`, `map_ranged`. Every "what feeds what" number is kept in `ctx.weights`.
  - `StatWeightsSection` (`map_weights`, built after it for the Stats tab only).
  - `GearSummaryItems` (from `GearSections`); `GearSections` = icons + comparison. Removed: the Durability and repair section,
    the comparison's Durability / Repair rows, `MoneyText`, `SlotRepairCost`, the durability read in `SlotInfo`.
  - `Context`: `whatIfAll` always 0. The Gear comparison's copy (`ctx.compare`, was `noAll`) skips the headings and the Gear Summary.
- Checked, not changed: `CharacterReskin.lua` (the button anchors to Blizzard's close button, which the wider window moves with the
  right edge); the Spells tab; slot overlays; `XayaUI_DevAssist/ApiInventory.lua` (its own repair-cost probe, a developer tool, not a
  Stat Calculator pane: left as it is).
- Tests changed to the new structure (each change commented in the file): `char_gear_icons_run.py`, `char_pane_overlays_run.py`,
  `char_spells_run.py`, `char_stat_columns_run.py`, `char_stat_map_run.py`, `char_toolkit2_run.py`, `char_toolkit_run.py`. New:
  `tests/char_stat_window_run.py`.

## Decisions (mine; each can be changed)
- DECISION: **button placement**: the character window's title row, 64 x 18, 4 px left of Blizzard's close button, label "Stat Calc"
  (the theme's selected-tab colours while the panel is open). Nothing of Blizzard's is in that row besides the title text (centred)
  and the close button (INFERENCE below); the slots, model and stats pane start under it; the wider window moves the close button.
- DECISION: **one saved open state** for every way of opening and closing (button, minimap row, /xui stats, the panel's X). The
  character window opens with the panel the way it was left; closing the character window does not change it.
- DECISION: **standalone**: opened while the character window is closed, the panel stands at its own place (`c.free`, kept when
  dragged, as before), docks beside the character window while that is open, and stays open (back at its place) when the window
  closes. Opened with the window, it closes with it.
- DECISION: **minimap**: a "Stat Calculator" row in XayaUI's minimap button list (order 12, after Notes and Calculator), state on / off;
  listed only while the toolkit and its panel are on (core's new `available`). Not a separate minimap icon (open question 1).
- DECISION: **Min / Max**: a 40 x 18 button left of the panel's close X ("Max" while small, "Min" while large); heights 440 and 760 to
  start, each 300-1100 (the grip's limits), settings Panel > Layout > Smaller height / Larger height (step 10). The width stays one
  value (the 450 default since QoL 0.7.21; the grip sets it). The grip sets the current mode's height. The 450 default width and the
  heights do not conflict, so both are kept as the coordinator asked.
- DECISION: the panel's height is now always one of the two (before: its content's height up to the character window's, or the
  dragged height). A height dragged before 0.7.23 becomes the smaller height.
- DECISION: **tree drawing**: Character Stats is one foldable section; its headings are not foldable on their own; level 1 (Core
  Stats, Secondaries, Tertiaries, Gear Summary) at the left edge in the label colour, level 2 (Primary, General, Offensive, Defensive)
  8 px in. One column head under Core Stats (with Change: the primary stat's box), and under Secondaries and Tertiaries (Rating and
  Change), as before.
- DECISION: **Gear Summary** placed last inside Character Stats, after Tertiaries, as a level-1 heading, drawn as its old table.
- DECISION: line labels: "Global cooldown" (her "gcd"), "Movement speed", "Attack Speed", "Weapon DPS", "Damage", "Critical strike
  effectiveness"; heading labels exactly hers ("Secondaries", "Tertiaries").
- DECISION: **Block always listed** (her list names it; 0.00% with no shield is what the game gives). **Stagger** kept after Block for
  a Brewmaster (only when the game gives one above 0).
- DECISION: **Health** is its own General line (UnitHealthMax); Stamina keeps its "» Health" line (its Pt value: health per point).
- DECISION: **resources**: drain type = Mana, Focus, Energy (they refill on their own): the total and the generation rate (base, and
  "while casting" in the note); every other pool: its maximum, no rate; Runes: the count and one rune's recharge time. Pools shown:
  your current one, then each class resource (Mana, Combo Points, Runes, Runic Power, Soul Shards, Astral Power, Holy Power,
  Maelstrom, Chi, Insanity, Arcane Charges, Essence) whose maximum is above 0. The current amount (UnitPower) is not drawn: the panel
  refreshes on stat events, so it would be stale; keeping it live would need UNIT_POWER_FREQUENT (cost).
- DECISION: a line the game gives no number for puts "not given by the game" in its note cell with the value empty (the value column,
  98 px, cannot hold the words on one line; the existing "hidden in combat" fit check found it).
- DECISION: **Attack Speed / Weapon DPS / Damage** read the main hand (the ranged weapon when there is no melee one); off hand and
  ranged under them; physical damage modifier and expertise under Damage.
- DECISION: **Stat Weights**: rows primary stat, Stamina, Critical Strike, Haste, Mastery, Versatility, Avoidance, Leech, Speed.
  Rating (P / %) = rating / total percent (primary and Stamina: the stat alone); PPP = rating for 1% with no penalty, with "DR: N / 1%"
  (the rate the next point gets) under it once a threshold is passed (her "(under if above DR threshold DR conversion value)"); DR
  Threshold = the next threshold's rating, "N (passed)" past the last one, "none" when the converter shows none, "after combat" while
  unread; T/L = "T: rating - lost / L: lost" (L one decimal). Influences: what each stat feeds now, the amounts the stat map already
  works out (Agility / Strength: attack power, dodge / parry, armor through mastery; Intellect: spell power "not given"; Stamina:
  health = Stamina x health per Stamina; Critical Strike: parry; Haste: GCD = GCD x (1 + haste) - GCD and attack speed the same way,
  both marked estimate in the hover; Mastery: armor, attack power from its text; Versatility: damage and healing done, damage taken;
  tertiaries: their own effect). The cell signs each amount ("GCD (-0.34 s)"); the hover says it in words ("Haste decreases Global
  cooldown by 0.34 s (estimate)"). Influences get their own column from content 560 (panel 580), else they sit under the row. Default
  open; the fold is saved in `collapsed.map_weights`. Name kept "Stat Weights" (hers; the hover and the guide say it is not a
  simulated damage-per-point weight).
- DECISION: the All ratings amount saved from before is reset to 0 (it would otherwise change every rating out of sight).

## INFERENCES
- INFERENCE: Blizzard's ButtonFrameTemplate gives CharacterFrame its close button as `CloseButton` (global CharacterFrameCloseButton)
  in the top-right corner of the title row, the title text is centred, and nothing else of Blizzard's sits in that row (not re-read
  for this change); without a close button the Stat Calc button anchors 28 px from the window's top-right corner.
- INFERENCE: UnitPowerMax gives 0 for a pool the class does not have (not documented); a druid may list more pools than its form uses.
- INFERENCE: GetRuneCooldown's duration is a rune's full recharge time (the documentation gives only the names startTime, duration,
  isRuneReady); it is read from the first rune whose duration is above 0, and nothing is shown while every rune is ready.
- INFERENCE: GetPowerRegenForPowerType's "casting" figure is the rate while casting (from its return name castingPowerRegen).
- INFERENCE: critical strike effectiveness is matched on the English words "critical strike effectiveness by N%" in any tooltip line
  (left or right text) of the equipped items; on another language nothing matches and the line says "none found". Whether the
  game's enchant line carries the effect text, or only the enchant's name (the 0.7.21 log found only the name on the enchant line),
  is not known: the in-game step E1z48 asks.
- INFERENCE (as before): the attack speed and GCD influences assume all haste shortens them (estimates, marked).

## Game API (V2; docs/reference/api, quoted in full)
- `UnitPowerType(unit: UnitTokenPvPRestrictedForAddOns, index: number = 0)` → `powerType: PowerType, powerTypeToken: string, rgbX:
  number, rgbY: number, rgbZ: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted (globals.md:690)
- `UnitPowerMax(unitToken: UnitTokenPvPRestrictedForAddOns, powerType: PowerType?, unmodified: bool = false)` → `maxPower: number` ·
  SecretArguments=AllowedWhenUntainted, SecretWhenUnitPowerMaxRestricted (globals.md:687). Secret answer: "not given now".
- `UnitPower(unitToken: UnitTokenPvPRestrictedForAddOns, powerType: PowerType?, unmodified: bool = false)` → `power: number` ·
  SecretArguments=AllowedWhenUntainted, SecretWhenUnitPowerRestricted (globals.md:683). Not called (decision above).
- `GetPowerRegen()` → `basePowerRegen: number, castingPowerRegen: number` · SecretWhenUnitStatsRestricted (globals.md:241); the
  fallback for the current pool when the next call is missing.
- `GetPowerRegenForPowerType(powerType: number)` → `basePowerRegen: number, castingPowerRegen: number` ·
  SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted (globals.md:242)
- `GetRuneCooldown(runeIndex: luaIndex)` → `startTime: number, duration: number, isRuneReady: bool` · MayReturnNothing,
  SecretArguments=AllowedWhenUntainted (globals.md:257)
- `GetUnitSpeed(unit: UnitToken)` → `currentSpeed: number, runSpeed: number, flightSpeed: number, swimSpeed: number` ·
  SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted (globals.md:308); percent of BASE_MOVEMENT_SPEED (7,
  constants.md), as the character window's movement speed.
- `C_TooltipInfo.GetInventoryItem(unit: UnitToken, slot: luaIndex, hideUselessStats: bool?)` → `data: TooltipData` · MayReturnNothing,
  SecretArguments=AllowedWhenUntainted (namespaces.md:4711); lines read through the existing `TipLines` / `CM.PlainText` (secret
  text is skipped).
- Critical strike: the documentation lists only `GetCritChance()` → `result: number` · SecretWhenUnitStatsRestricted (globals.md:150),
  `GetSpellCritChance()` (globals.md:278) and `GetRangedCritChance()` (globals.md:248), each a chance; no call gives effectiveness.
- `Enum.PowerType` (enums.md:10234): Mana 0, Rage 1, Focus 2, Energy 3, ComboPoints 4, Runes 5, RunicPower 6, SoulShards 7, LunarPower
  8, HolyPower 9, Alternate 10, Maelstrom 11, Chi 12, Insanity 13, ..., ArcaneCharges 16, Fury 17, Pain 18, Essence 19.
- Unchanged reads (quoted in earlier logs): UnitHealthMax, UnitHPPerStamina, GetUnitMaxHealthModifier, UnitAttackSpeed, UnitDamage,
  UnitRangedDamage, UnitRangedAttackPower, GetExpertise, the rating converter. The pool names are the game's global strings named by
  the token (MANA, RUNIC_POWER, ...; INFERENCE that each exists), English fallbacks otherwise.
- Widget calls: the same as before (CreateFrame Button / Texture / FontString, SetPoint, SetSize, SetScript, Show / Hide).

## V14 (off costs nothing)
Level reached: the toolkit's files are read at login (QoL is always loaded; stated in V14), and the minimap row's entry (a table with
its functions) is registered then, as Notes and Calculator do; it is not listed while off. While the toolkit or its Panel part is off:
no panel frame, no Stat Calc button, no minimap row in the list (`char_stat_window_run.py` checks all three at login with the toolkit off, and
with the toolkit on and the panel off). Turning either off hides the button and removes the row at once. The durability and vendor
events are no longer registered at all. The owner hooks are unchanged (placed once the toolkit is first on; they return at once while
it is off, as before).

## Tests
- New `tests/char_stat_window_run.py`: 98 checks (three loads: the main run and two "next session" loads with the saved settings).
  The minimap list is core's real MinimapButton.lua, opened with a click on its button; the rows read are the shown rows.
  Button made only when on, its size, parent and anchor; a click closes / opens the panel and saves it; the next window open (and the
  next session) follows the saved state; the panel's X saves closed; a click on the minimap row opens it with the character window closed (at
  CENTER + c.free), docks, stays open when the window closes, closes again; /xui stats; Min / Max heights 440 / 760, the settings move
  them (500 / 900), the grip sets the large height and the width, Min then gives the small height at that width, limits; the Stats
  tab's two headers; the eight headings in order and indent; the lines under each heading in her order; Health, Movement speed,
  Attack Speed / Weapon DPS / Damage; Fury (max, no rate), Mana (total, rate), Death Knight (Runic Power then Runes with 8.5 s), secret
  maximum ("not given now", no misuse), no UnitPowerMax ("not given by the game"); critical strike effectiveness +4% from two rings'
  text (colour codes removed), each source in the hover, none found, no tooltip data; no All ratings (line, box, setting; a saved
  amount does nothing); no durability / repair text on Stats, Gear, a clicked slot, Spells; the Gear Summary table on Stats and not on
  Gear; Stat Weights below Character Stats, heads, rows, Haste / Crit / Agility / Mastery cells and influences, hover sentences
  (Haste, Crit, Agility, Stamina, Versatility), the column head hover, past a threshold (DR line under PPP, "1,380 (passed)", T 1,488 /
  L 12.0), "not given" with no GCD read, fold / unfold saved, influences under the row (narrow) or in their column (wide); the Gear
  comparison has no headings / summary / weights; layout at panel widths 340 / 450 / 583 / 584 / 760 x text sizes 8 / 11 / 16 with
  typed numbers (inside the width, no overlaps); secret ratings (weights read hidden, no misuse); switched off / on / panel off.
- **Negative control** (V1): the new file run in separate `git worktree add` copies under the scratchpad (removed afterwards) of
  907475b (the head this started from) and 0f05ad6 (the session branch after the 0.7.21 merge): 98 checks, 92 failed on each. The 6
  that pass there are all marked "(guard)" (off at login nothing exists; the panel docks by default; the window re-opens with it;
  /xui stats toggles; next session with it left open). Every unmarked check fails there.
- Changed existing tests (old expectations replaced by the new behaviour, each marked [0.7.23] or commented): `char_toolkit2_run.py`
  (headers, folding Character Stats, the durability / repair checks now one "none on any tab" check, crit +852 without All ratings,
  no All ratings box or setting), `char_toolkit_run.py` (the +852 check through crit's own amount, no comparison durability row, the
  Summary read from Stats), `char_stat_map_run.py` (headers, the weapon card's three lines, Block 0.00%, the grip / reset heights;
  the merge conflict kept both the 430 content width and the heights), `char_stat_columns_run.py` (headings for headers, 3 column
  heads, 8 boxes, the Summary on Stats), `char_gear_icons_run.py`, `char_pane_overlays_run.py`, `char_spells_run.py` (the Gear tab's
  smaller detail lines it counted were the Durability lines: now it checks that no full-size spell-math line leaks to Gear).
- `tests/sidebar_switches_run.py` (72 checks) failed 2 on the first full run (the UnregisterLauncher version, above) and passes with
  `available`. `modules_run.py` 32, `minimap_run.py` 18, `calculator_run.py` FAILS: 0, all char tests pass.
- Results on the final tree: see the commit message / report (full suite with `XUI_API_INDEX=tests/harness/api_index.json`, the index
  built by `tests/harness/api_index_from_docs.py`: 4970 functions, 1784 events, 76 widget method lists). `lua_pitfalls_run.py` 79 files,
  FAILS: 0; CharacterModel.lua, CharacterToolkit.lua, Modules.lua compile (tests/lua51.py loadstring).

## Not verified
Everything in game (QA E1z45-E1z49): the button's place against the real title row (and with the reskin's Clean window), the rune
recharge read, the pools a druid lists, whether any item text carries "critical strike effectiveness by N%", the look of the headings.

## Open questions for Xaya
1. Minimap: a row in XayaUI's minimap button list now; do you want a separate minimap icon of its own instead (or as well)?
2. Split resources: both pools are shown (e.g. Runic Power and Runes); keep, or only the main one?
3. Stat Weights: keep the name (it is not a simulated damage-per-point weight), and keep the amounts as "what the stat gives now"
   (GCD -0.34 s is all of your haste), or per 1% / per point?
4. Critical strike effectiveness: is the text on your enchanted items worded "critical strike effectiveness by N%"? (E1z48)
5. Min / Max heights 440 / 760 and the width as one value: right defaults?
