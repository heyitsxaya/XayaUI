# Content data pulls, offline part: docs/reference/content/ from the client data (build 12.1.5.70783; no addon code changed)
Logged 2026-11-04 15:23 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Builder: `docs/reference/build_content.py` (the draft from
`640031d`, fixed here). Test: `tests/build_content_run.py`. Nothing here runs in the game, and no addon reads these files yet.

## Request (Xaya, 2026-11-04, as recorded in the handoff)
"item ids for current expansion (not just season), item >> buff ids, item >> debuff ids, instanced content data ... ct/% per unit in
challenge mode ... class + spec ids", plus stats, targeted tooltip data and spell scaling (those need the game: see "Not done").

## Source
Blizzard's client data tables, build 12.1.5.70783, as CSVs from `https://wago.tools/db2/<Table>/csv?build=12.1.5.70783`.
- Downloaded 2026-11-04 into the session's scratch folder. Not committed. Read as data with `python3 -I`.
- Every column the builder reads was checked present in the real headers before the run.
- `ItemSparse`, filtered to ExpansionID 11: 7,928 rows, all ExpansionID 11.

## What the draft got wrong (found on the real data, each now a test)
1. **Older dungeons in the Mythic+ rotation were missing.** The draft kept only maps tagged expansion 11. In this build the two
   newest seasons that track a Midnight dungeon also track older ones:
   - season 34: Pit of Saron, Skyreach, Seat of the Triumvirate, Algeth'ar Academy;
   - season 37: Ruby Life Pools, Temple of Sethraliss, Kings' Rest.

   Fix: a season counts as the expansion's when it tracks at least one of its dungeons (INFERENCE: the table has no expansion
   column). Every dungeon those seasons track is listed, with `expansionID` and `listedBecause` ("expansion" / "mythic+ season").
   Which season is live is not in this data and is not claimed.
2. **Four Midnight dungeons got no enemy forces.** Their challenge trees use Blizzard's internal names, so the name link missed them:
   - "Lightbloom" = The Blinding Vale (tree 219305 "Lightbloom Dungeon - Blinding Vale" ties the two);
   - "Prove Your Worth" = Den of Nalorakk;
   - "Nexus Point" = Nexus-Point Xenas;
   - Kings' Rest's tree is "8.0 Dungeon - Kings' Rest - Challenge" (no parentheses).

   Fix: a second link through data. A challenge tree's boss rows are Criteria Type 165 with `Asset` = a `DungeonEncounter` ID, and
   `DungeonEncounter.MapID` is the dungeon. That Type 165 means "defeat this encounter" is an INFERENCE; the boss names on both
   sides match, for example "Emberdawn defeated" -> DungeonEncounter 3056 Emberdawn, map 2805 Windrunner Spire. Each tree says how
   it was linked: `linkedBy` "encounters", "name" or "encounters, name". A tree counts only when its root's name says "Challenge".
3. **Some dungeons have two enemy-forces trees.** A second one is named "... - Challenge (More Trash)" and has different counts:
   - Seat of the Triumvirate: 568 / 329;
   - Temple of Sethraliss: 687 / 264;
   - Kings' Rest: 608 / 286.

   The client data does not say which one the game uses. Both are listed. The in-game answer is the tree whose `total` equals
   `C_ScenarioInfo.GetCriteriaInfo`'s.
4. **Output order depended on Python's hash seed** (a set loop). The files are committed, so two runs must write the same bytes.
   Fixed: trees are sorted by ID.

## Checked against the facts verified by hand on 2026-11-04 (handoff)
- Windrunner Spire: criteria tree 216371, "Enemy Forces" total 591, 23 creature rows with counts 1-20. The three Type 92 rows
  (amounts 7, 70 and 9999) are listed under `notCreature` and never counted. All match.
- Correction to the handoff's wording: 18 of the 23 creature IDs are in the 232xxx range, not all 23.
- ItemSparse ExpansionID 11: 7,928 rows. Matches.
- The client's Creature table is a subset: only 2 of the 391 enemy-forces rows have a name (none of Windrunner Spire's 23).

## Output (docs/reference/content/, about 2.1 MB)
| File | Count |
|---|---|
| `items.json` | 7,928 items |
| `item-spells.json` | 2,317 items with 2,984 spells; 979 items reach at least one aura |
| `instances.json` | 23 instances; 16 kept for the expansion, 7 for its Mythic+ seasons |
| `classes.json` | 15 class rows, plus the pet specializations under class 0 |

Details:
- **Item spells, by trigger** (ItemEffect.TriggerType; INFERENCE for 0 and 1): on use 1,900, on equip 410. Other types are kept as
  numbers, never named: 6 (478), 10 (71), 7 (82), 9 (25), 5 (16), 3 (1), 4 (1). No row has type 2 ("chance on hit").
- **Aura targets** (ImplicitTarget_0; INFERENCE): self 1,383, enemy 23, ally 7. Others are kept as numbers: 25 (19), 0 (15),
  22 (4), 18 (2), 16 (2).
- **Instances:** 16 dungeons and 7 with Map.InstanceType 2; 77 encounters, 1,118 ability spells, 548 encounter events.
- **Mythic+ enemy forces:** all 15 dungeons of seasons 34 and 37 have them, 391 creature rows across 297 distinct creatures.
- **Classes:** the 13 playable classes plus Adventurer (14) and Traveler (15), which the client data also lists. Each playable class
  has an "Initial" spec row (before a spec is chosen). The pet specializations appear twice under different IDs. All as stored.

Further notes:
- **Public repository:** names and numbers only. The test puts a sentinel string in every description, title and body-text column,
  and checks that it never reaches an output file. On the real output, the longest string is 76 characters (a spell name). Every text
  field is a name: item, spell, encounter, instance, creature, class, spec, criteria-tree label. The criteria-tree labels are
  Blizzard's internal names, such as "12.0 Dungeon - Lightbloom (Challenge)". They are kept because they identify which tree is which,
  e.g. "(More Trash)".
- **ENCOUNTER_START** (V2): `docs/reference/api/events.md:562`: `ENCOUNTER_START` (encounterID: number, encounterName: cstring,
  difficultyID: number, groupSize: number) · SynchronousEvent · EncounterInfo. The documentation does not say `encounterID` is
  `DungeonEncounter.ID`, so `dungeonEncounterID`'s description marks it as an INFERENCE, to check against Dev Assist's probe anchors.

## Tests (V1, negative control)
- `tests/build_content_run.py`: 25 checks on made-up tables, assertions on the four output files.
- It **fails 7 checks on the draft** (`640031d`):
  - the older rotation dungeon (3 checks);
  - `listedBecause`;
  - the internal-name tree linked through its boss;
  - both trees with their `linkedBy`;
  - the same `instances.json` under 8 hash seeds (2 different outputs on the draft).
- It passes on the fixed builder. The other 18 checks pass on both (they test what the draft already did right).
- The real run is reproducible: the repository build is byte-identical to the scratch build inspected before it.

## Scope (V4)
New and changed files only:
- `docs/reference/build_content.py`, `docs/reference/content/*.json`;
- `tests/build_content_run.py`;
- `docs/reference/README.md` (new row);
- ROADMAP section 8 (new row).

No addon file reads `docs/reference/content/` (`git grep -n "reference/content"` finds only these docs), so no addon version
changes.

## Not done (next)
In-game captures, Dev Assist:
- `/xuidev instance`: per creature seen, its ID, name, Mythic+ count, spells cast and auras, with the encounter and instance IDs;
- `/xuidev stats`;
- `/xuidev tooltips`;
- item -> aura confirmation through the cast recorder.

They fill what the client data cannot: creature names and spells, which enemy-forces tree is live, and where an item's aura really
lands. Each must mark every read the game hides. The secrecy flags (`SecretWhenUnitIdentityRestricted` and others) are listed in the
handoff in SESSION-START-SUMMARY.md.
