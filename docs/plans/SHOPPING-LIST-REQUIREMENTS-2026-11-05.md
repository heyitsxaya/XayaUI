# Shopping List (Blizzard UI Reskin): every request, as one list (2026-11-05, 21:55 UTC)

Owner: Claude Code session `014bN6tStyDJVemzE9tX7F38` (branch `claude/cool-ramanujan-ewx8e5`). Nothing here ships until each row
marked OPEN is built, tested and checked against this list (the rule Xaya set for the Stat Calculator, 2026-11-04).

## Her words (2026-11-05, in order)
1. "Take all reskins and put them into a new tab: Blizzard UI Reskin ... Will apply in the future to: shopping list"
2. "Shopping list reskin is the profession / crafting list function, correct" (confirming Claude's reading)
3. "It should also auto-suggest the user's commonly used gear enchant if a given slot has an equipped item that can be enchanted. The
   same applies for gems for items that have empty sockets"
4. Her answers to four design questions (verbatim):
   - Form: "Both — we're also going to reskin the objective pane"
   - Where the suggestions show: "In the shopping list"
   - Commonly used: **"Default to one, user configurable default, also "select other" button to provide the list of other available
     options in case the user wants to feelcraft a different choice spontaneously and needs help looking it up. Clicking the name of
     the gem or item in the pane should autopopulate the auction house search if auction house pane is open. (Attach this note to
     feature details)"**
   - What a suggestion does: "Show + add to list"

## What the game gives (checked 2026-11-05)
- Blizzard's crafting shopping list is the objective tracker's Professions section (live 12.1.5 source,
  `Blizzard_ObjectiveTracker/Blizzard_ProfessionsRecipeTracker.lua`): every tracked recipe (`C_TradeSkillUI.GetRecipesTracked(isRecraft)`)
  with its required reagents from the recipe schematic, have / need; it redraws on `TRACKED_RECIPE_UPDATE`, `BAG_UPDATE_DELAYED`,
  `CURRENCY_DISPLAY_UPDATE`. `C_TradeSkillUI.SetRecipeTracked` / `IsRecipeTracked` / `GetRecipeSchematic` (namespaces.md:4898-4957).
- Auction House: `AuctionHouseFrame.SearchBar:SetSearchText(text)` then `:StartSearch()` is how the game's own search box searches
  (`Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSearchBar.lua:194-207`; `SearchBar` is a parentKey of `AuctionHouseFrame`,
  `Blizzard_AuctionHouseFrame.xml:71`, hidden on the Sell and Auctions tabs). `C_AuctionHouse.SendBrowseQuery` takes
  `itemClassFilters` (classID, subClassID, inventoryType; structures.md:331-349); results come with `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED`.
- Enchant scrolls are item class 8 (ItemEnhancement); by subclass (checked against the client item reference, build 12.1.5.70783, as
  the enchant-slot default was): helm 0, shoulders 2, chest 4, legs 8 (spellthreads / armor kits), boots 9, ring 10, weapon 11
  (with profession-tool enchants), ranged scopes 12. Gems are item class 3. Only these subclass numbers ship; no names or IDs.
- The game keeps no history of the enchants or gems you used: XayaUI has to remember what it sees on your gear.
- The enchant on an item: its link's enchant field (yes / no) and the tooltip's permanent-enchant line (its name); gems:
  `C_Item.GetItemGemID(link, i)`; empty sockets: the item's stat table (`EMPTY_SOCKET_*`). All already read by the Stat Calculator
  model (`XayaUI_QoL/CharacterModel.lua`: `CM.SlotInfo`, `CM.SlotEnchant`, `CM.EnchantSlots`).

## Rows
| # | Her words | Status | What gets built |
|---|---|---|---|
| S1 | "Take all reskins and put them into a new tab ... shopping list" | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2a) | Blizzard UI Reskin > Shopping List: its own page and switch (off by default; off costs nothing, V14). |
| S2 | "Both" (form) | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2a) | XayaUI's own **Shopping List panel** (movable, theme look): the tracked recipes with their reagents, have / need, done lines dimmed. |
| S3 | "Both" (form) | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2d) | **Blizzard's Professions section restyled** in the objective tracker (first piece of the Objective Pane reskin, S11), its own switch. |
| S4 | "auto-suggest the user's commonly used gear enchant if a given slot has an equipped item that can be enchanted" | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2b) | "Missing on your gear" at the top of the panel: each slot that takes an enchant (the Character Toolkit's enchant slots) whose item has none, with the suggested enchant. |
| S5 | "The same applies for gems for items that have empty sockets" | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2b) | Each equipped item with empty sockets: the suggested gem, how many sockets, how many of it are in your bags. |
| S6 | "Default to one" | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2b) | One suggestion per slot (per socket for gems): the most-used one XayaUI has seen on that slot on this character (gems: the most-used gem), the most recent if tied; what you wear now counts from the first look. |
| S7 | "user configurable default" | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2b, E2c) | Set the suggestion for a slot (and for gems) yourself, from Select other or by dropping / shift-clicking an item; it wins over the most-used one; "Clear" goes back. In the settings page too. |
| S8 | "'select other' button to provide the list of other available options ... needs help looking it up" | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2c) | Select other: the enchants (gems) you have used before, those in your bags, and, while the Auction House is open, what it lists for that slot (a browse by item class 8 + the slot's subclass; gems: class 3). Pick one to use now or to make it the default. |
| S9 | "Clicking the name of the gem or item in the pane should autopopulate the auction house search if auction house pane is open" | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2c) | Every item / reagent / suggestion name in the panel: a click puts it in the Auction House search and searches when the Auction House is open (on its Buy tab); otherwise a click shows the item's tooltip and shift-click links it as usual. |
| S10 | "Show + add to list" | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2c) | "+ Add" on a suggestion puts it in the panel's "To buy" list (name, need, have from your bags); removable; done when you have enough. |
| S11 | "we're also going to reskin the objective pane" | PLANNED (roadmap RM-OBJECTIVES) | The whole objective tracker in the theme; the Professions section (S3) is its first part. |
| S12 | C3, 2026-11-06: "let's see what's possible to pull from profession api details + auction house listings to see if we can compile a complete list of current-expansion / current gear enchantments from in-game calls (developer mode only)" | RESEARCHED; her answer "Not now — either wait for direct request or set for next week development after token reset (Wednesday)": DEFERRED to the week of 2026-11-11 (reminder set) | See "S12: what the game can give" below. |
| S13 | C9: "Stay dimmed, allow user to "clear" manually — prompt user after all reagents are found in bag if they want to stop tracking" | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2g) | An x on each recipe's title stops tracking it; once every reagent is in the bags, "All reagents are in your bags. Stop tracking it?" with Stop / Keep. |
| S14 | C10: "1 as long as prismatic / diamond is always considered (only one is ever possible to equip so its missing is always a default recommendation)" | built (QoL 0.7.32, branch; tests pass, not run in game: QA E2h) | The one-per-character gem (unique-equipped, limit 1, read from the game) is asked for on the first empty socket when none is worn. Its own default too (her answer: "Give the diamond a default too"). |
| S15 | C8: "For now colors only but build with the awareness the whole tracking container will be treated with restyling soon" | built (QoL 0.7.32, branch; tests pass) | One restyle for any objective-tracker section (`Shop.TRACKER_MODULES`), Professions only for now. |

## Decisions made by Claude (labelled; she can overrule)
- Per character (her answer did not name per-spec; per character was the recommended option and she chose the default-plus-choice
  form on top of it).
- Code lives in `XayaUI_QoL/ShoppingList.lua` (it reads the Stat Calculator's gear model there); its settings page is under module
  "reskin" like the Character Pane.
- The enchant to buy is found by its name (the enchant's tooltip name, e.g. "Amani Mastery", matches its scroll "Enchant Ring - Amani
  Mastery"): the bag count and the Auction House search use that name. INFERENCE until seen in game; said in its hover.

## Her answers to C1-C12 (2026-11-06, verbatim in docs/process/REQUEST-LOG-session-014bN6tStyDJVemzE9tX7F38.md, R64)
C1, C2, C4, C5, C6, C7 and C11 confirmed as built. C3, C8, C9, C10 and C12 changed or added work: rows S12-S15 above, and the Reskin
tab's switch on the tab itself (C12).

## S12: what the game can give for a complete list of this expansion's enchants (research, 2026-11-06)
Sources: the repo's API reference (`docs/reference/api`, build 12.1.5) and Blizzard's UI code as already cited in this doc.
Nothing here was tried in game.

- **From Enchanting itself:**
  - With an Enchanting window open (your own, or a linked one), `C_TradeSkillUI.GetAllRecipeIDs` lists every recipe of that
    profession, learned or not. It is "not in the generated documentation" (namespaces.md:4839): it exists, but its exact return
    needs an in-game check.
  - `C_TradeSkillUI.GetRecipeInfo(id)` gives name, categoryID, learned (namespaces.md:4887). `GetChildProfessionInfos()` /
    `GetProfessionChildSkillLineID()` give the expansion's own skill line ("Midnight Enchanting"), which keeps the list to this
    expansion.
  - `GetRecipeOutputItemData(id)` gives the scroll's itemID (namespaces.md:4894). `C_Item.GetItemInfo(scroll)` gives classID 8 and
    the subclass (= the slot, the numbers this module already ships) plus expansionID.
  - Result: every enchant this expansion's Enchanting can make, per slot, with its scroll. Each scroll is an exact item ID, so
    counting "have" no longer needs the name match.
  - Limit: only while a profession window is open. For a character without Enchanting, it needs another player's linked profession.
    INFERENCE: a linked window lists the same recipes.
- **From the Auction House:** the browse this module already sends (class 8 + slot subclass; gems class 3) returns every scroll / gem
  listed right now. Each item's expansionID (`C_Item.GetItemInfo`) keeps this expansion's. It shows what is sold, not everything that
  exists: a scroll nobody lists is missing.
- **Gems:** the same two routes, with Jewelcrafting (class 3).
- **"Developer mode only":** a capture command (for example `/xuidev enchants`) writes what it read to saved data. The list is built
  from it offline and checked, and ships only after her yes (her terms answer of 2026-11-05: "option a" = data built from in-game
  reads, a future enhancement). Dev Assist (`XayaUI_DevAssist/`) belongs to another session (PR #386): the capture goes there by
  agreement, or into this module behind a developer switch.
- **Proposal for her yes:**
  1. a Dev Assist capture of Enchanting + Jewelcrafting recipes (when their window is open) and of the Auction House's lists;
  2. a script that turns the capture into a per-slot list of scroll / gem item IDs for this expansion;
  3. the Shopping List uses that list for "have" (exact IDs) and for Select other ("every enchant for this slot"), falling back to
     the name match when the list has no entry.
