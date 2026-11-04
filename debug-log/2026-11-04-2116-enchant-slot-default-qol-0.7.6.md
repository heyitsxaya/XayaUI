# Enchant Slots: this expansion's enchantable slots are checked by default (XayaUI_QoL 0.7.6; fork: main)
Logged 2026-11-04 21:16 UTC. Session 014bN6tSy3HbUDWYQsk69naX, branch `claude/inspiring-mendel-8r8qao`. Nothing here has run in the game.

## Request
Xaya, 2026-11-04, with a screenshot of QoL > Character Toolkit > Slot Overlays > Enchant Slots (every slot unticked): "this should be
better. you can absolutely read professions for a current expansion and see what enchanting options are available and make an
educated guess from there". XayaUI_QoL is the parallel session's area (PR #385); this change was claimed with it by message first.

## What the game and the data say
- No API says which slots take an enchant (`docs/reference/api`: every enchant call works on a recipe, an item GUID or the open
  profession: `C_TradeSkillUI.GetEnchantItems`, `IsEnchantTargetValid`, `CraftEnchant`). An addon can list Enchanting recipes only
  on a character that has the profession, with it open, so "read the professions" works for enchanters only. A default is needed.
- Blizzard's client data, build 12.1.5.70783 (`docs/reference/content/items.json`, expansion 11), Item Enhancement items (classID 8)
  by subclass: 0 helm 12; 2 shoulders 21 (with cosmetic adornments); 4 chest 8; 8 legs 12 (spellthreads, armor kits); 9 boots 6;
  10 ring 18; 11 weapon 32 (with profession-tool enchants); 12 ranged scopes 8; 14 other 5. No cloak, bracer, belt, glove, neck,
  shield or off-hand enchant (name search and subclass both). Only slot numbers enter the addon: no IDs, names or values.
- Terms question 3b (summary section 4) is still open: "do not add new client-table data to shipped addon files". INFERENCE: a list
  of eight slot numbers is a design default, not client-table data; Xaya can veto it, and the code then falls back to the old empty
  default by deleting `CM.ENCHANT_DEFAULT`'s entries.

## Scope (V4)
`git grep enchantSlots`: `XayaUI_QoL/CharacterModel.lua` (SlotOverlay), `XayaUI_QoL/CharacterToolkit.lua` (defaults, Cfg, the overlay
caller, the Enchant Slots settings), `tests/char_toolkit2_run.py` (section 8 and the settings section). Nothing else reads it.

## What changed
- `CharacterModel.lua`: `CM.ENCHANT_DEFAULT` (head 1, shoulder 3, chest 5, legs 7, feet 8, rings 11 and 12, main hand 16);
  `CM.OffHandIsWeapon` (`C_Item.GetItemInfoInstant` classID = Enum.ItemClass.Weapon 2; MayReturnNothing,
  SecretArguments=AllowedWhenUntainted); `CM.EnchantSlots(c)`: the player's ticks once they changed any (`enchantSlotsSet`) or when a
  list was saved before 0.7.6, otherwise the default. The overlay's E? tooltip says which of the two flagged it.
- `CharacterToolkit.lua`: the overlay uses `CM.EnchantSlots`; the first tick change keeps every slot shown ticked, then applies the
  change; a "This expansion's slots" button clears the player's list; the note and the Enchant check tooltip say how it works.
- INFERENCE (marked in the code): an off-hand weapon takes the weapon enchant; shields and frills take none (no such enchants exist
  in the data).

## Tests
`tests/char_toolkit2_run.py`: 140 checks, 0 failed (6 new; one changed: the head with nothing ticked now shows E?, the requested
behaviour). The test world (`tests/char_toolkit_world.lua`) gets an off-hand slot button, a Glaive (weapon) and a Frill (held in off
hand), and GetItemInfoInstant returns a classID. Negative control: with the QoL change stashed, the new checks fail (the run stops at
the first call to `CM.EnchantSlots`). `char_toolkit_run.py` 100 checks, `lua_pitfalls_run.py`: pass.

## Not verified
In game: QA E1s.
