# Module map: Shopping List new-gear toast (UPG-1)

Where it lives: `XayaUI_QoL/ShoppingList.lua`, the block headed "UPG-1" (just above "On / off"). QoL 0.7.62. Nothing else in the
addon calls into it; it reads the Shopping List's own settings, suggestions and To buy list, and the Stat model's item level and
enchant slots.

## Call flow
```
BAG_UPDATE_DELAYED (Shop.Apply's event frame; registered only while the Shopping List is on)
  -> pcall(Shop.ScanBags, c)                        error -> Shop.upgrade.lastError (/xui shop status)
       worn gear + bag gear -> ItemKey (C_Item.GetItemGUID, else the link)
       keys not seen at the last look ("fresh")
       -> Shop.UpgradeCandidate(c, link, key)         nil + reason -> Shop.upgrade.lastSkip
            Ignored(c)[key]?  EQUIP_SLOTS[equipLoc]?  enchant slot (CM.EnchantSlots) or empty socket?
            Shop.TrackOf(link) (C_Item.GetItemUpgradeInfo .trackString -> TRACK_ORDER rank)
            c.minTrack floor; weakest worn item of the slots; c.onlyHigherTrack; same track -> higher item level (CM.ItemLevel)
       -> Shop.UpgradeOffer(c, cand)                   Shop.GemSuggestion / Shop.EnchantSuggestion; nil = nothing to add
       -> Shop.upgrade.queue -> ToastNext (returns while InCombatLockdown()) -> BuildToast (first time only) -> Shop.UpgradeToastText
event PLAYER_REGEN_ENABLED (combat over) -> ToastNext (a held toast shows)
Toast Yes / No -> ToastAnswer
       tick "ignore item" -> Ignored(c)[key] = true (per character)
       tick "only on a higher upgrade track" -> c.onlyHigherTrack
       Yes -> Shop.AddToBuy (gem x empty sockets; enchant x1), row keys "upg:<key>:gem" / "upg:<key>:ench"
       -> ToastNext (the next waiting item)
Shop.Apply with the Shopping List off, or the New gear switch off -> Shop.ToastOff (queue, seen keys and the toast cleared)
```

## Functions
| Function | Does | Reads | Writes |
|---|---|---|---|
| `Shop.CanReadTrack()` | the game gives upgrade tracks | `C_Item.GetItemUpgradeInfo` exists | - |
| `Shop.TrackOf(link)` | rank in `Shop.TRACK_ORDER`, track name | `C_Item.GetItemUpgradeInfo` | - |
| `Shop.UpgradeCandidate(c, link, key)` | is this item worth asking about; else nil + reason | settings, worn gear, sockets, enchant slots | - |
| `Shop.UpgradeOffer(c, cand)` | the gem and enchant to offer | suggestions (default, most used) | - |
| `Shop.UpgradeToastText(o)` | her sentence, filled in | - | - |
| `Shop.ScanBags(c)` | one look at worn and bag gear; queues toasts | bags, worn gear | `Shop.upgrade` |
| `Shop.ToastShown()`, `Shop.ToastFrame()` | for the tests and the walkthrough | - | - |
| `Shop.ToastOff()` | forget everything, hide the toast | - | `Shop.upgrade`, toast |
| `ToastAnswer(yes)` (local) | Yes / No | toast ticks | `c.ignored`, `c.onlyHigherTrack`, `c.buy` |

## Saved settings (`XayaUIQoLDB` -> `shoppingList`)
`upgradeToast` (bool, default true), `onlyHigherTrack` (bool), `minTrack` ("" or a track name), `ignored` (`[character] = { [GUID or link] = true }`).

## Isolation
- A failure in the bag look is caught (pcall) and kept for `/xui shop status`; the rest of the Shopping List's event handler runs.
- Off costs nothing (V14): no frame until the first toast; no scan while the switch or the Shopping List is off.
- Tests: `tests/shopping_list_run.py` section 12. QA: E2i, walkthrough `upg-shop-toast`.
