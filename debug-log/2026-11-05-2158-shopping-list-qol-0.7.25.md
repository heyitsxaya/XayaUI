# Shopping List: XayaUI's panel, Blizzard's Professions list restyled, enchant and gem suggestions (XayaUI_QoL 0.7.25; fork: main)
Logged 2026-11-05 21:58 UTC. Session `014bN6tStyDJVemzE9tX7F38`, branch `claude/cool-ramanujan-ewx8e5` restarted from main 0ef9cb0.
Nothing here has run in the game.

## Request (Xaya, 2026-11-05)
"Shopping list reskin is the profession / crafting list function, correct"; "It should also auto-suggest the user's commonly used gear
enchant if a given slot has an equipped item that can be enchanted. The same applies for gems for items that have empty sockets".
Her answers to four questions: form "Both — we're also going to reskin the objective pane"; suggestions "In the shopping list";
action "Show + add to list"; and her note for the feature details: "Default to one, user configurable default, also "select other"
button to provide the list of other available options in case the user wants to feelcraft a different choice spontaneously and needs
help looking it up. Clicking the name of the gem or item in the pane should autopopulate the auction house search if auction house pane
is open." Every request is a row in `docs/plans/SHOPPING-LIST-REQUIREMENTS-2026-11-05.md` (S1-S11); ROADMAP RM-SHOP carries her note
verbatim; the objective pane reskin is the new row RM-OBJECTIVES.

## What the game gives (checked in Blizzard's live 12.1.5 source and the API docs)
- The crafting shopping list is the objective tracker's Professions section (`Blizzard_ProfessionsRecipeTracker.lua`): tracked recipes
  (`C_TradeSkillUI.GetRecipesTracked`), each required slot's first reagent, counted over every quality with
  `ProfessionsUtil.AccumulateReagentsInPossession`, redrawn on `TRACKED_RECIPE_UPDATE` / `BAG_UPDATE_DELAYED`; the module frame is
  `ProfessionsRecipeTracker`, laid out through `EndLayout`, finished lines show `line.Icon` (a check).
- Auction House: `AuctionHouseFrame.SearchBar:SetSearchText` + `:StartSearch` (the game's own search box, hidden on Sell / Auctions);
  `C_AuctionHouse.SendBrowseQuery` with `itemClassFilters`, results on `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED`.
- Enchant scrolls: item class 8, subclass by slot (helm 0, shoulders 2, chest 4, legs 8, boots 9, rings 10, weapons 11, scopes 12),
  checked against the client item reference; only the numbers ship. Gems: class 3.
- No history of what you used exists in the game: XayaUI counts what it sees.

## What changed
- New `XayaUI_QoL/ShoppingList.lua` (in the toc after CharacterReskin.lua): settings `CueRulesDB.shoppingList`; history per character
  (enchant per slot, rings sharing one; gems), counted once per appearance; suggestions (this session's pick > your default > the most
  used, most recent if tied); Missing on your gear (the Character Toolkit's enchant slots without an enchant; items with empty sockets,
  from `CM.SlotInfo`); have / need (by item ID, or for an enchant the scrolls whose name holds its name: INFERENCE, said in the hover);
  the tracked recipes; To buy (+ Add, x, no duplicates); a name click searches the Auction House only while it is open; Select other
  (used before, bags, the Auction House's browse for that slot) with "Default"; Blizzard's Professions section recoloured after its
  layout (a `hooksecurefunc` post-hook on `ProfessionsRecipeTracker.EndLayout`); settings page Blizzard UI Reskin > Shopping List
  (module "reskin"); `/xui shop [options|status]`. Off by default; while off nothing is created, registered or hooked (V14).
- `XayaUI_QoL.toc` 0.7.25 (0.7.23 and 0.7.24 belong to other sessions; 0.7.25 was assigned to this batch by them); USER-GUIDE 0 and 12.12c; QA E2a-E2d; ROADMAP RM-SHOP
  (in progress), RM-OBJECTIVES (planned); requirements S1-S10 built, S11 planned.

## Limits and inferences
- The enchant scroll is found by name (no game call maps an enchant to its scroll); a name the scroll does not hold is not counted.
- The Auction House browse also fills Blizzard's own results list (it is the same query the Buy tab sends): wanted, it shows the options.
- Restyling Blizzard's tracker section: a post-hook on a Blizzard module; whether another UI addon that skins the tracker fights it,
  and whether it ever raises "Interface action failed", is QA E2d.

## Tests
- New `tests/shopping_list_run.py` (47 checks): off costs nothing; history once per appearance, per character; suggestions and the order
  pick > default > most used > most recent; have / need; tracked recipes over qualities and with Blizzard's own counter; + Add / no
  duplicates / x; the Auction House search only while open (and not started on the Sell tab); Select other's three sources and the
  class 8 subclass 10 browse; pick for now and Default; the tracker restyle after Blizzard's layout; layout bounds; settings; off again.
  On main 0ef9cb0 (no ShoppingList.lua) it cannot load: every check fails.
- `tests/reskin_tab_run.py`: the tab's pages now Character Pane | Chat Panel | Esc Menu | Shopping List (22 / 0).
- char_reskin, char_toolkit, char_toolkit2, char_stat_map, char_spells, char_gear_icons, modules, window_margins, options_layout_v11,
  lua_pitfalls (81 files): 0 failed.
