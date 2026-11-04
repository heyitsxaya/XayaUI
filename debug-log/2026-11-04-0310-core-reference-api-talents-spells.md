# Core reference: live-client API and every class's talents and spells (docs only; fork: main)
Logged 2026-11-04 03:10 UTC. Branch `claude/eloquent-rubin-n9zb99`. No addon code changed.
Xaya: "build yourself a complete and total api list from that please / also build yourself a complete talent and spell reference list / both of these should serve as one of your core pillars of documentation for reference". Then: "public repo is fine as long as you see nothing wrong with it and it in no way violates blizzard TOS".

## Sources
- Xaya's Game Data Capture files, uploaded 2026-11-04. They were read as DATA only: compiled and run with an empty Lua environment.
  - `api`: client 12.1.5 (70783), interface 120105, captured 2026-11-03 21:49 local.
  - `static`: the all-class talent scan, built 2026-11-01 20:28.
- Blizzard's generated API documentation, 12.1.5 (70688), from the wow-ui-source mirror. All 622 files parsed.

## What was built
- `docs/reference/build_reference.py`: the generator. It reads only the game-data parts of a capture (`api`, `static`); it never writes out the character, aura, recorder or toolkit-check parts. `--public` writes the facts-only version.
- `docs/reference/api/`:
  - namespaces: 259 namespaces, 4,793 functions, 4,181 documented;
  - documented globals: 685;
  - enums: 1,823 (980 not in the documentation, e.g. `Enum.ItemCreationContext` with 192 values);
  - `Constants` tables and the `CR_*` rating indices;
  - methods of 20 widget types;
  - from the documentation: 1,784 events and 841 structures;
  - `api.json`.
- `docs/reference/spells/`:
  - one file per class (13), with class, spec and hero trees;
  - 2,893 nodes and 3,419 entries;
  - per spell: ID, name, ranks, cast, base cooldown, charges, aura secrecy;
  - tier sets with their bonus spells;
  - other spells from the scan's list (4,899 spells in all);
  - `spells.json`, where each spell lists the nodes and sets that reference it.
- `docs/reference/README.md`: what each set is, how to use it, how to rebuild it after a patch. `SESSION-START-SUMMARY.md` now sends game-API questions to `docs/reference/` first.

## The public / private split (decision and why)
Xaya made publishing conditional on nothing being wrong and on no breach of Blizzard's terms. That could not be confirmed:
- `www.blizzard.com` and `community.developer.battle.net` are outside this cloud session's network allowance, so the current EULA text could not be read.
- A secondhand quote of the EULA prohibits "any unauthorized process or software that intercepts, collects, reads, or 'mines' information generated or stored by the Platform". The capture used the official addon API, as every addon does.
- Blizzard owns its written game text.

So this repository (public) holds only facts: names, IDs, signatures, flags, enums and tree structure.

The written text is kept out: spell descriptions, tooltip text, hero-tree descriptions and Blizzard's documentation notes. So are the undocumented globals and numeric globals, because they also list every addon loaded during the capture, which would reveal Xaya's installed addons.

The full version went to Xaya as `XayaUI-reference-full-2026-11-04.zip`, for her private Drive folder "Blizzard API Data". It is never to be committed here.

Checks: the public build contains no description lines, no `d`/`tt` spell fields, no documentation notes, and no names of the other loaded addons searched for (EllesmereUI, Deja). All 22 undocumented `C_` namespaces are Blizzard's own.

## Facts confirmed by the same captures (used by the Character Toolkit rebuild)
- `GetSpellBaseCooldown` exists (global only) and returns (cooldown ms, GCD ms). Xaya's Vengeance spells: 1,500 (Felblade 500, off-GCD 0).
- `C_Item.GetDelvePreviewItemLink` built item 271537 at 23 item levels (207 to 334) across 192 creation contexts. `C_TooltipInfo.GetItemByID(id, nil, context)` returns a `hyperlink` and an "Item Level" line.
- `C_Item.GetItemStats` ignores gems and enchants. It also counts a filled socket as `EMPTY_SOCKET_*`, so the Gear tab's "empty socket" warning (QoL 0.6.2) is wrong for filled sockets; fixed in the rebuild.
- Repair cost in tooltip data: not settled. All of Xaya's gear was at full durability; QA line to follow.
- `Frame:SetIgnoreParentAlpha` and `CharacterStatsPane` exist; Mythic+ rating reads (3806).

Files: docs/reference/ (README.md, build_reference.py, api/*, spells/*), SESSION-START-SUMMARY.md (two lines), this entry, MANIFEST.md5.
