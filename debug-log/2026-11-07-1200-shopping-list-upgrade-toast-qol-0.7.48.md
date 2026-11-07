# Shopping List: toast for a new bag item that may be an upgrade (QoL 0.7.48, Dev Assist 0.7.57)
Session 014bN6tWKcNdrDgUBzRK3BUh, branch claude/shopping-list-auto-detect-ieb029. Nothing here has run in the game.

## Request (UPG-1, her words)
"auto detect new upgrade item in bag upon looting/landing IFF the item has a socket or can be enchanted. Do a single confirmation toast: "XUI has detected a new item that may potentially be an upgrade. Do you want to add a {gem}{enchant} to your shopping list for it?" yes no options. Tick Options: "ignore item," "only on a higher upgrade track" (the latter only if possible) underneath"
Her answers: upgrade = "same upgrade track (champion:champion, hero:hero, myth:myth, etc) or above ... Also allow for toggle in settings "don't make recommendations for the shopping list below ___ track" as an override"; tick = compare track order, "ilvl less important if the item is on a superior track"; ignore = this exact item, this character; Yes adds gem + enchant to To buy, toast top-center.

## Scope (V4)
Readers/callers: ShoppingList.lua (Cfg, Apply, event handler, settings page), CharacterModel.lua (CM.ItemLevel export), tests/shopping_list_run.py, QAWalks-display.lua. Events: BAG_UPDATE_DELAYED was already registered by Apply (off = unregistered, V14); the toast frame is built on the first toast only.

## API (V2)
C_Item.GetItemUpgradeInfo(itemInfo) -> ItemUpgradeInfo? (namespaces.md:2798; structures.md:4285: trackString cstring? Nilable). C_Item.GetItemNumSockets (2786), GetItemGemID (2765), GetItemInfoInstant itemEquipLoc (2772). INFERENCE: the order of track names (explorer < adventurer < veteran < champion < hero < myth) is not in the API docs; unknown name = unknown track = no toast.

## Decisions of mine, flagged (not chosen by her)
- New switch "Suggest gems and enchants for new gear" defaults ON (inside the off-by-default Shopping List).
- Same track needs a higher item level than the weakest worn item of the item's slots; an empty slot always qualifies; unreadable track = no toast.
- {gem}{enchant} shown as "<gem> + <enchant>" ("2x" before the gem for several empty sockets); the toast shows only when a suggestion exists for at least one part.
- The tick "only on a higher upgrade track" is saved on Yes or No as the setting (also on the settings page); hidden when the game gives no tracks.
- Toasts are not held back in combat.

## Tests
tests/shopping_list_run.py section 12: 36 new checks (118 / 118). Negative control: with the old ShoppingList.lua / CharacterModel.lua the run stops at the first new call (Shop.ToastOff is nil). QA E2i; walkthrough upg-shop-toast.
