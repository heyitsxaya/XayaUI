# Stat Calculator redesign (plan, 2026-11-04): waiting for Xaya's confirmation

Xaya's requests (2026-11-04 evening, in order, her words):
1. "'character toolkit' title should be changed to `Stat Calculator`". **Done** (QoL 0.7.3: the panel's title).
2. "stats pane should be stat value calculator".
3. "'sheet' tab is not intended to be a tab but instead a reskin of the character pane".
4. "prettify the character window". Her screenshots show:
   - Blizzard's stats pane with Defense / Offense / Ratings bands;
   - equipment slots with two item-level numbers each, a large quality-coloured one and a small white one, plus 1S / 2S socket
     marks.
5. "remove defense and offense tabs from stat calculator, they should be filters for 'Spells' that show stat conversion rate into
   the offensive/defensive spell scaling".
6. "gear pane should show small icons of the gear equipped and allow for a comparison column to drag and drop or click-select gear
   options to track stat changes into their relative calculations with highlights".
7. What If (done in QoL 0.7.4):
   - "adding the item does not auto-fill in information and does[n't] prompt an item to slot ... (weapon, trinket, ring)";
   - "primary stat is also not included in the what if calculator".
8. Follow-up on 7: "beyond this, show what will happen to your agility and therefore armor from armor + armor_from_item +
   armor_from_agi". Screenshot: the game's own trinket comparison, "-21 Agility, +63 Leech".
9. "spells pane still needs a full auto-populate". Screenshot: Spell math lists only the three spells added by hand (Immolation
   Aura, Fel Devastation, Chaos Nova).

## Today (QoL 0.7.4)
- Tabs: Sheet | Stats | Defense | Offense | Gear | What If | Spells.
- The panel docks beside the character window (`CharacterToolkit.lua`).
- **Slot overlays:** they put item level and socket / enchant marks on the character window's slots, when switched on
  (`ns.CharToolkit_UpdateOverlays`).
- **Spells:** "Spell math (advanced)", the spells the user adds. Each number in the spell's current description is divided by the
  current attack power or spell power. That is today's ratio, with talents and buffs already in it, not Blizzard's base
  coefficient. The panel says so.

## Proposed layout (to confirm)
| Today | Proposed |
|---|---|
| Sheet tab | **Gone as a tab.** The character window itself is restyled (item 3 / 4, below). |
| Stats tab | **Stat Values**. See question 1. |
| Defense, Offense tabs | **Gone as tabs.** Their content becomes two filters on Spells. |
| Gear tab | **Gear**: a row of small icons of what is equipped, and a comparison column (item 6). |
| What If | stays; adds the armor chain (item 8). |
| Spells tab | **Spells**: every spell from the spellbook, with Offense / Defense / All filters (item 5 / 9). |

### Character window restyle (items 3, 4)
- Restyle only:
  - XayaUI's own textures, fonts and overlay frames on top of Blizzard's character window, following the theme;
  - no changes to the window's scripts or layout in combat (taint).
- The Sheet's content (one compact list of every stat) moves onto the window's stat pane area.
- One item level per slot. Which of the two numbers is XayaUI's has to be checked first: the slot overlays draw one, and the other
  may be Blizzard's or another addon's.

### Spells (items 5, 9)
- **Auto-populate:**
  - every spell in the spellbook (`ns.BuildSpellList`, already used by the rule editor) whose description has numbers;
  - spells added by hand stay (they can be any ID).
- **Filters:**
  - Offense: spells whose description deals damage;
  - Defense: absorbs, heals, damage reduction, armor;
  - All.
  - This sorts by the description's words, so it is a heuristic. A spell can be moved by hand.
- **Per spell:** each number divided by attack power or spell power (as today), and what one point of the primary stat adds.
  Defense spells also show versatility's damage reduction where the game gives it.

### Gear (item 6)
- **Icons:** the equipped items as small icons in slot order, each with its item level, hover = the item's tooltip.
- **Comparison column:**
  - drag an item onto it, or click an item in the bags, or a "pick from bags" list (the same owned-items list the item search
    uses);
  - each line shows the stat changes through the same calculations as What If (ratings through the game's converter, primary
    stat to attack power, Stamina to health, armor), highlighted green / red.
  - With two of a kind equipped, the same "replace which one" choice as What If.

### Armor chain (item 8)
- Agility from the item, then armor, as base armor + the item's own armor + armor from Agility.
- For Vengeance the Agility -> armor link is the mastery: "Increases Armor by 88.7% of your Agility", read from the game in her
  screenshot.
- This is per spec, so the numbers must come from the game: `GetMasteryEffect`, `UnitArmor`, the item's armor. A formula is never
  typed in.
- To check first: what `UnitArmor` returns for the armor from Agility, and whether other specs have a similar link.

## Questions for Xaya
1. "Stats pane should be stat value calculator": rename the Stats tab, or make it compute what one point of each stat is worth to
   you (e.g. 1 Agility = X attack power = Y% more damage on your spells, 1 Haste rating = Z%)?
2. The character window restyle: only the stat list and the slots, or the whole window (frame, tabs, model background)?
3. Spells, auto-populate: every spell in the spellbook (can be 40+), or only the ones with damage / healing / absorb numbers in
   their description?
4. Gear comparison column: several items compared side by side, or one at a time?

## Build order once confirmed
1. Spells auto-populate and filters. Defense / Offense tabs removed.
2. Gear icons and comparison column.
3. Armor chain in What If and Gear.
4. Character window restyle; Sheet tab removed.
5. Stat Values, per question 1.

Each step: tests that fail on the old code, QA steps, a debug-log entry, versions, the full suite, `main`.
