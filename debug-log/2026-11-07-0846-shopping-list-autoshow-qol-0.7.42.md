# Shopping List: shows itself only at the Auction House or for missing enchants / gems (QoL 0.7.42, Dev Assist 0.7.21)
Session 014bN6tV7oStjTuVPEJbytBJ. Nothing here has run in the game.

## Request
UI-77 part 2 (relayed O-139; her words): "shopping list keeps popping up but there's no reason for it to show" [screenshot: the panel
with only "Recraft: Silvermoon Agent's Handwraps" 0/x; nothing missing on her gear, To buy empty].

## Cause (reproduced)
ShoppingList.lua Shop.Apply showed the panel whenever it ran with the panel option on: at login (ns.WhenReady), on every Blizzard UI
Reskin switch, and on every change on its settings page. Its X set panel.userHidden, which is not saved, so every reload brought it
back. tests/shopping_list_run.py section 11 on the old file: 8 of its new checks fail.

## Change (conservative reading, flagged; O-108: no questions)
- Never shows itself at login, after a loading screen, or on a settings / reskin switch by itself.
- Shows itself when the Auction House opens (AUCTION_HOUSE_SHOW), or when worn gear misses an enchant or a gem (Shop.Missing has an
  entry: checked at Apply, PLAYER_ENTERING_WORLD and PLAYER_EQUIPMENT_CHANGED), unless closed.
- A close (its X, or /xui shop while shown) is saved (shoppingList.closedTillAH) and holds across reloads until the next Auction House
  visit, which forgets it.
- Asked-for opens still open it at once: /xui shop, and turning the list or its panel on on its settings page (Shop.Apply(true); the
  shoppingList service's Apply passes the same flag, used by the Dev Assist walkthroughs).
- A tracked recipe alone (her case) never makes it show itself.

## Tests
shopping_list_run 82 / 82 (section 11 new: 13 checks, 8 fail on the old file); reskin_tab_switch_run 27 / 27 (the Shopping List counts
as started when its events are registered; a new check that the switch does not pop the panel up); qa_walks_display 40 / 40
(walkthrough ui-shop-autoshow). QA B233.
