# XayaUI core reference

The two references to check BEFORE relying on memory or general knowledge for any game fact in XayaUI work (Xaya, 2026-11-04: "both of these should serve as one of your core pillars of documentation for reference").

| Folder | What it is | Source |
|---|---|---|
| [`api/`](api/README.md) | Everything that exists in the live game client: every `C_` namespace and its functions, enums with values, `Constants` tables, the methods of each widget type, and the documented global functions. Each name carries Blizzard's documented signature and flags where Blizzard documents it (secret-value rules such as `SecretReturns`, `RequiresNonSecretAura`, `NeverSecret` fields). Events and structures from the documentation. | XayaUI Game Data Capture `/xuidump api`, client 12.1.5 (70783), captured 2026-11-03; Blizzard's generated API documentation 12.1.5 (70688) |
| [`spells/`](spells/README.md) | Every class, spec, hero tree and talent node (class, spec and hero trees of every spec, 13 classes), each spell's ID, name, ranks, cast time, base cooldown, charges and aura secrecy, and tier sets with their bonus spells. | XayaUI Game Data Capture `/xuidump static` (all-class scan through the game's talent view), built 2026-11-01 |
| [`charges.md`](charges.md) | The spells the client reported with more than one charge, and the talents whose text changes a spell's charges (with the spell names they mention), by class and spec. | Built from the `spells/` capture by the 0.6.9 charge review, 2026-11-04 |
| [`procs.md`](procs.md) | Every aura Blizzard's client data gives proc art or a button highlight, by class: which player spells it lights, how many other auras light the same button, base duration, max stacks and charges. A button only one aura lights identifies that aura in combat by its glow. | Blizzard's client data tables for build 12.1.5.70783, as published by wago.tools; built by `build_procs.py`, 2026-11-04 |
| [`content/`](content/) | The expansion's content as facts: `items.json` (every Midnight item: ID, name, base item level, quality, slot, class, item set), `item-spells.json` (each item's use / equip / proc spells and the auras they apply, with the target: on you or on an enemy), `instances.json` (Midnight's dungeons and raids plus the older dungeons its Mythic+ seasons track: encounters with their dungeon encounter IDs and ability spells, challenge mode timers, Mythic+ enemy forces per creature: count per kill and percent), `classes.json` (class and spec IDs). Each file's `about` block lists which fields are inferences. Names and numbers only. | Blizzard's client data tables for build 12.1.5.70783, as published by wago.tools; built by `build_content.py`, 2026-11-04 |

## Public version and full version
This repository is public, so it holds the `--public` build:
- **Kept here (facts):** names, IDs, signatures, flags, enums, talent tree structure and the numbers listed above.
- **Left out here:**
  - Blizzard's written text: spell descriptions, tooltip text, hero-tree descriptions, and Blizzard's notes on functions, events and fields.
  - The undocumented global functions and the numeric globals. Those lists also hold the names of every addon loaded during the capture.
- **The full version** has all of it and is private: Xaya's Google Drive folder "Blizzard API Data", file `XayaUI-reference-full-<date>.zip`. Read it through the Drive connector when a description or an undocumented global is needed. Never commit the full version here.

Why the split: Blizzard owns its written game text. Publishing it is a copyright question, and the current EULA wording could not be read from the cloud session (`www.blizzard.com` is outside its network allowance). Names, IDs and signatures are factual. They are widely published already, for example on warcraft.wiki.gg and in the public wow-ui-source mirror.

## How to use it
- Does a function exist, what does it take and return, and is it secret-restricted? Look in `api/namespaces.md` or `api/globals.md` (search the name), or `api/api.json` from a script.
- What does an enum hold? Look in `api/enums.md`. For example, `Enum.ItemCreationContext` has 192 values and is not in Blizzard's documentation.
- Which talents and spells does a class have, and in which tree? Look in `spells/<CLASSTOKEN>.md`, or `spells/spells.json`, where each spell lists the talent nodes and tier sets that reference it.
- A fact neither covers: ask for a new capture, or add a targeted check to `XayaUI_GameDump` (`/xuidump toolkit` is the pattern).

## Keeping it current
After a game patch, Xaya runs `/xuidump api` and `/xuidump static` in XayaUI Game Data Capture, then `/xuidump save`, and uploads `WTF\Account\<account>\SavedVariables\XayaUI_GameDump.lua`. Then:

```
python3 docs/reference/build_reference.py --saved <XayaUI_GameDump.lua> --docs <Blizzard_APIDocumentationGenerated folder> --out docs/reference --public
python3 docs/reference/build_reference.py --saved <XayaUI_GameDump.lua> --docs <Blizzard_APIDocumentationGenerated folder> --out <private folder>
```

The second command builds the full version, which goes to Drive, not here. Blizzard's documentation folder comes from the wow-ui-source mirror (`Interface/AddOns/Blizzard_APIDocumentationGenerated`) or the in-client `/api` files.

The generator reads only the game-data parts of the capture (`api`, `static`). It never writes out the character, aura, recorder or toolkit-check parts.

For a global-function list without other addons' names, make the capture with only XayaUI Game Data Capture enabled.
