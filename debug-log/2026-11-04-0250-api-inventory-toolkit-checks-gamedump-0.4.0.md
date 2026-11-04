# API inventory and Character Toolkit checks (XayaUI Game Data Capture 0.4.0; fork: main)
Logged 2026-11-04 02:50 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.
Xaya: "I can do an /api call in the chat and presumably get the full list of api calls in game if you create a developer debugging function in xayaui" / "post the file in this chat as well so I can drag and drop now and feed you the data immediately".

## Why
The game's `/api` browser and the 12.1.5 generated documentation list only documented functions. Calls the Character Toolkit rebuild depends on are not in them, so they could not be confirmed from here:
- `GetSpellBaseCooldown`: it is not referenced anywhere in Blizzard's 12.1.5 UI source either (git grep of wow-ui-source live d07eb00).
- `GetInventoryItemDurability` and `GetRepairAllCost`: Blizzard's UI uses them, so they exist.
- `Enum.ItemCreationContext`: only its use as a type is documented.
- What `C_Item.GetDelvePreviewItemLink` builds for contexts other than delves: Blizzard's Delves difficulty picker calls it with (itemID, context).
- Whether the tooltip data of an equipped item carries `repairCost`: Blizzard's `TooltipDataRules` reads it, but shows it only in repair mode.

## What was added
- `XayaUI_GameDump/ApiInventory.lua` (new, loaded after GameDump.lua):
  - `GD.CaptureAPI` (`/xuidump api`, window button 5) saves `XayaUIGameDumpDB.api`: build, every global function name (sorted), every `C_*` namespace with its function names, every `Enum` with its values, every `Constants` table, every ALL-CAPS numeric global, and the methods of each widget type (one hidden throwaway object each).
  - `GD.ProbeToolkit` (`/xuidump toolkit`, window button 6) saves `XayaUIGameDumpDB.toolkitProbe` with:
    - base cooldowns (cdMS, gcdMS) of up to 60 castable current-spec spells;
    - the raw fields of the GCD spell 61304 (secret ones marked "SECRET");
    - durability and tooltip-data keys and `repairCost` per slot, plus `GetRepairAllCost` where it answers;
    - `Enum.ItemCreationContext` and the preview link and item level for each context, for one equipped item;
    - `C_TooltipInfo.GetItemByID` keys for a few contexts;
    - the item's stats with and without its enchant and gems;
    - whether `CharacterStatsPane`, `SetIgnoreParentAlpha` and `GetItemLevelColor` exist, the Mythic+ rating, and the `CR_*` constants.
- `GameDump.lua`: shares its helpers (`GD.DB`, `GD.Say`, `GD.Plain`, ...), adds buttons 5 and 6 (the window grows to 652 px), and adds the commands `api` and `toolkit`; `status` lists both captures.
- `XayaUI_GameDump.toc`: version 0.4.0, loads `ApiInventory.lua`.

## Checks
- `tests/gamedump_api_run.py` (new): 27 checks against stand-in game calls, 0 failed. They cover:
  - legacy globals listed;
  - namespaces, enums and constants recorded;
  - secret values skipped;
  - the off-spec spellbook line skipped for base cooldowns;
  - repair cost read only where given;
  - variant levels deduplicated;
  - the bare link has its enchant and gems emptied.
- Lua 5.1 syntax check: OK.
- Sent to Xaya as `XayaUI_GameDump-0.4.0.zip` for an immediate in-game run (QA-CHECKLIST J1 to J3).

Files: XayaUI_GameDump/ApiInventory.lua, GameDump.lua, XayaUI_GameDump.toc, tests/gamedump_api_run.py, USER-GUIDE.md (12.13), QA-CHECKLIST.md (J), this entry, MANIFEST.md5.
