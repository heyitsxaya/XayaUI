# Shopping List: asks once when new gear may be an upgrade (QoL 0.7.62, Dev Assist 0.7.80)
Session 014bN6tWKcNdrDgUBzRK3BUh, branch claude/shopping-list-auto-detect-ieb029 (rebuilt on qa-installer-branch 236262bc; the
2026-11-07 build on the old main layout is replaced). Nothing here has run in the game. REQUEST-LOG A25 UPG-1 to UPG-3.

## Request
UPG-1 / UPG-2 (her words in the request log). Map: docs/reference/maps/SHOPPING-LIST-UPGRADE-TOAST.md.

## Scope (V4)
ShoppingList.lua (DEFAULTS, Cfg, the UPG-1 block, Apply, the event handler, the settings page's New gear tab, /xui shop status);
StatModel.lua (exports CM.ItemLevel, unchanged); QAWalks-display.lua (walkthrough upg-shop-toast). Events: BAG_UPDATE_DELAYED was
already registered by Apply (unregistered while off). New frame: XayaUIShoppingToast, made on the first toast only.

## API (V2), docs/reference/api
- `C_Item.GetItemUpgradeInfo(itemInfo: ItemInfo)` → `itemUpgradeInfo: ItemUpgradeInfo?` · SecretArguments=AllowedWhenUntainted (namespaces.md:2798);
  ItemUpgradeInfo: currentLevel, maxLevel, maxItemLevel (Nilable=False), trackString: cstring? and trackStringID: number? (Nilable) (structures.md:4285).
- `C_Item.GetItemGUID(itemLocation: ItemLocation (ItemLocationMixin))` → `itemGUID: WOWGUID` · SecretArguments=AllowedWhenUntainted (2763).
- `C_Item.GetItemNumSockets(itemInfo)` → `socketCount: number` (2786); `C_Item.GetItemGemID(itemInfo, index)` → `gemID` · MayReturnNothing (2765);
  `C_Item.GetItemInfoInstant(itemInfo)` → ..., `itemEquipLoc` · MayReturnNothing (2772).
- INFERENCE (not documented): the order of the track names; ItemLocation:CreateFromBagAndSlot / CreateFromEquipmentSlot exist as
  Blizzard's ItemLocationMixin constructors (code falls back to the link when they or the GUID are missing).

## Changes from the 2026-11-07 build (self-audit, her XUI three questions)
- "ignore item" was keyed by item ID: every copy of that item was ignored, against her answer "This exact item". Now the item's GUID.
- Gear you take off landed in the bags as "new" and could ask: worn gear is now part of the last look.
- The bag look ran unprotected inside the Shopping List's event handler: now pcall'd, the error kept for /xui shop status.
- The look reads only gear (no GetItemInfoInstant on non-gear beyond the equip-location check, no tooltip reads).
- Settings rows moved to their own tab (New gear); the track floor sits beside the higher-track tick (a dropdown never takes a row alone).

## Choices of mine, flagged (not chosen by her)
- The New gear switch defaults ON (inside the off-by-default Shopping List).
- Same track needs a higher item level than the weakest worn item of the slots; an empty slot always qualifies; unreadable track = no toast.
- `{gem}{enchant}` reads "<gem> + <enchant>", "2x " before the gem for two empty sockets; no toast when neither has a suggestion.
- Toasts are not held back in combat.

## Tests
tests/shopping_list_run.py 130 / 130 (section 12: 26 new checks). Negative control: with the old ShoppingList.lua / StatModel.lua
the run stops at section 12's first new call (Shop.ToastOff nil). QA E2i; walkthrough upg-shop-toast.

## Full suite (bf61db19, with the API index), and the two golden tests
5 check groups failed. On qa-installer-branch 236262bc (same harness) 4 of them fail the same way: american_spelling (13), info_pane (1),
options_split_parity (14), qa_walk_audit (1): not this change's, left as they are. Two came from this change, both "same as before"
snapshot tests, both brought back to the base's result:
- settings_seam B (2): the four new shoppingList defaults are the only difference (dump diff of 236262bc and the new code, all on, both
  sessions); added as UPG1_DEFAULTS_ADDED, taken out only where they hold their default. Now 56 / 56.
- options_split_parity (+1, off-XayaUI_Reskin): every variant differs from 236262bc in exactly the 6 New gear lines. Only that entry was
  updated; the 6 variants already stale on 236262bc were left (refreshing them would approve differences this change did not make).
  Now 14 failed, as on the base.
