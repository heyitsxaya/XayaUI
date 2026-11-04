"""docs/reference/build_content.py (the builder of docs/reference/content/) on small made-up tables, written to a temporary folder.
Checks what ends up in the four output files: the expansion's items and nothing else, what an item's spell applies and to whom,
Mythic+ enemy-forces counts and percents per creature (only kill criteria are counted), the older dungeons of the expansion's Mythic+
seasons, encounters with their spells, class and spec IDs, the same output whatever Python's hash seed, and no written text (the
repository is public).
The IDs and names below are invented for the test; they are not game data. Run: python3 tests/build_content_run.py (standard library only)."""
import csv, json, os, subprocess, sys, tempfile
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BUILDER = os.path.join(ROOT, "docs", "reference", "build_content.py")
TEXT = "SENTINEL-WRITTEN-TEXT"   # stands in for Blizzard's descriptions; it must never reach an output file
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra)[:300] + "]"))
    if not ok: fails.append(name)

def write(folder, name, header, rows):
    with open(os.path.join(folder, name), "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f); w.writerow(header); w.writerows(rows)

def tables(d):
    # ---- items (expansion 11). ItemSparse is the filtered download; a row of another expansion in it must still be dropped.
    write(d, "ItemSparse.exp11.csv", ["ID", "Display_lang", "Description_lang", "ExpansionID", "ItemLevel", "OverallQualityID",
                                      "InventoryType", "ItemSet", "RequiredLevel"],
          [[5001, "Test Trinket", TEXT, 11, 250, 4, 12, 0, 80], [5002, "Test Helm", TEXT, 11, 260, 4, 1, 77, 80],
           [5003, "Old Sword", TEXT, 10, 100, 3, 13, 0, 70], [5004, "Test Potion", TEXT, 11, 1, 1, 0, 0, 80]])
    write(d, "Item.csv", ["ID", "ClassID", "SubclassID"], [[5001, 4, 0], [5002, 4, 4], [5003, 2, 7], [5004, 0, 1]])
    write(d, "ItemXItemEffect.csv", ["ID", "ItemEffectID", "ItemID"], [[1, 701, 5001], [2, 702, 5001], [3, 703, 5004], [4, 704, 5003]])
    write(d, "ItemEffect.csv", ["ID", "LegacySlotIndex", "TriggerType", "Charges", "CoolDownMSec", "CategoryCoolDownMSec",
                                "SpellCategoryID", "SpellID", "ChrSpecializationID"],
          [[701, 0, 0, 0, 120000, 0, 0, 6001, 0], [702, 1, 1, 0, 0, 0, 0, 6002, 0], [703, 0, 5, 3, 0, 0, 0, 6003, 65],
           [704, 0, 0, 0, 0, 0, 0, 6004, 0]])
    # 6001 (on use) triggers 6011, which applies an aura on the caster (target 1 = self).
    # 6002 (on equip) applies an aura to an enemy (target 6) itself.  6003 (trigger type 5) applies an aura with target 99.
    write(d, "SpellEffect.csv", ["ID", "EffectIndex", "Effect", "EffectAura", "ImplicitTarget_0", "ImplicitTarget_1",
                                 "EffectTriggerSpell", "SpellID"],
          [[1, 0, 64, 0, 1, 0, 6011, 6001], [2, 0, 6, 4, 1, 0, 0, 6011], [3, 0, 6, 3, 6, 0, 0, 6002], [4, 0, 6, 4, 99, 0, 0, 6003],
           [5, 0, 6, 4, 1, 0, 0, 6004]])
    write(d, "SpellName.csv", ["ID", "Name_lang"], [[6001, "Test Use"], [6011, "Test Buff"], [6002, "Test Debuff"], [6003, "Test Odd"],
                                                     [6004, "Old Buff"], [8001, "Boss Smash"], [8002, "Boss Roar"], [8101, "Old Boss Hit"]])
    # ---- instances. Map 3001: a dungeon of expansion 11. Map 3002: a dungeon of expansion 9 in season 40's Mythic+ rotation.
    # Map 3003: a dungeon of expansion 9 only in season 20 (no expansion-11 dungeon in it): not this expansion's.
    # Map 3004: a dungeon of expansion 11 whose challenge tree has an internal name ("Code Name"): only its bosses link it.
    write(d, "Map.csv", ["ID", "Directory", "MapName_lang", "MapDescription0_lang", "InstanceType", "ExpansionID", "MaxPlayers"],
          [[3001, "x", "Test Keep", TEXT, 1, 11, 5], [3002, "y", "Old Vault", TEXT, 1, 9, 5], [3003, "z", "Older Pit", TEXT, 1, 9, 5],
           [3004, "w", "Hidden Den", TEXT, 1, 11, 5]])
    write(d, "JournalInstance.csv", ["ID", "Name_lang", "Description_lang", "MapID"],
          [[1401, "Test Keep", TEXT, 3001], [1402, "Old Vault", TEXT, 3002], [1403, "Older Pit", TEXT, 3003], [1404, "Hidden Den", TEXT, 3004]])
    write(d, "JournalEncounter.csv", ["Name_lang", "Description_lang", "ID", "JournalInstanceID", "DungeonEncounterID", "OrderIndex", "UiMapID"],
          [["Second Boss", TEXT, 2502, 1401, 3502, 1, 2201], ["First Boss", TEXT, 2501, 1401, 3501, 0, 2201],
           ["Old Boss", TEXT, 2601, 1402, 3601, 0, 2202], ["Code Boss", TEXT, 2701, 1404, 3701, 0, 2203]])
    write(d, "JournalEncounterSection.csv", ["ID", "Title_lang", "BodyText_lang", "JournalEncounterID", "SpellID"],
          [[1, "Smash", TEXT, 2501, 8001], [2, "Smash again", TEXT, 2501, 8001], [3, "Roar", TEXT, 2501, 8002], [4, "Intro", TEXT, 2501, 0],
           [5, "Hit", TEXT, 2601, 8101]])
    write(d, "DungeonEncounter.csv", ["Name_lang", "ID", "MapID", "DifficultyID"],
          [["First Boss", 3501, 3001, 0], ["Second Boss", 3502, 3001, 0], ["Old Boss", 3601, 3002, 0], ["Code Boss", 3701, 3004, 0]])
    write(d, "EncounterEvent.csv", ["ID", "SpellID", "BroadcastTextID", "Severity", "DungeonEncounterID"],
          [[1, 8002, 0, 2, 3501], [2, 8001, 0, 1, 3501]])
    write(d, "MapChallengeMode.csv", ["Name_lang", "ID", "MapID", "ExpansionLevel", "CriteriaCount_0", "CriteriaCount_1", "CriteriaCount_2"],
          [["Test Keep", 901, 3001, 11, 1800, 1440, 1080], ["Old Vault", 902, 3002, 9, 2000, 1600, 1200],
           ["Older Pit", 903, 3003, 9, 1700, 1360, 1020], ["Hidden Den", 905, 3004, 11, 1500, 1200, 900]])
    write(d, "MythicPlusSeasonTrackedMap.csv", ["ID", "MapChallengeModeID", "DisplaySeasonID"],
          [[1, 901, 40], [2, 902, 40], [3, 902, 20], [4, 903, 20], [6, 905, 40]])
    # Enemy forces: tree 7000 "(Challenge)" > boss row 7002 (Type 165, encounter 3501 on map 3001) and 7001 "Enemy Forces" (total 200)
    # > four children: creatures 9001 (count 4), 9002 (count 10, not in the client's Creature table), 9003 (count 1), and a Type 92
    # criteria (amount 9999, not a kill). Tree 7500 is Test Keep's "(More Trash)" tree, linked only through its boss (3502).
    # Tree 7100 is the older dungeon's (name only). Tree 7400 has an internal name and is linked only through its boss (3701, map 3004).
    # Tree 7200 has an "Enemy Forces" child and a boss on map 3001 but is not a challenge tree: never attached.
    write(d, "CriteriaTree.csv", ["ID", "Description_lang", "Parent", "Amount", "Operator", "CriteriaID", "OrderIndex", "Flags"],
          [[7000, "1 Dungeon - Test Keep (Challenge)", 0, 0, 4, 0, 0, 0], [7002, "First Boss defeated", 7000, 1, 0, 8002, 0, 0],
           [7001, "Enemy Forces", 7000, 200, 9, 0, 1, 0],
           [7010, "", 7001, 4, 0, 8010, 0, 0], [7011, "", 7001, 10, 0, 8011, 1, 0], [7012, "", 7001, 1, 0, 8012, 2, 0],
           [7013, "", 7001, 9999, 0, 8013, 3, 0],
           [7500, "1 Dungeon - Test Keep - Challenge (More Trash)", 0, 0, 4, 0, 0, 0], [7502, "", 7500, 1, 0, 8502, 0, 0],
           [7501, "Enemy Forces", 7500, 400, 9, 0, 1, 0], [7510, "", 7501, 8, 0, 8010, 0, 0],
           [7100, "1 Dungeon - Old Vault (Challenge)", 0, 0, 4, 0, 0, 0], [7101, "Enemy Forces", 7100, 50, 9, 0, 0, 0],
           [7110, "", 7101, 5, 0, 8110, 0, 0],
           [7400, "12 Dungeon - Code Name (Challenge)", 0, 0, 4, 0, 0, 0], [7402, "Code Boss defeated", 7400, 1, 0, 8402, 0, 0],
           [7401, "Enemy Forces", 7400, 300, 9, 0, 1, 0], [7410, "", 7401, 3, 0, 8410, 0, 0],
           [7200, "Some Scenario", 0, 0, 4, 0, 0, 0], [7202, "", 7200, 1, 0, 8202, 0, 0], [7201, "Enemy Forces", 7200, 30, 9, 0, 1, 0],
           [7210, "", 7201, 3, 0, 8210, 0, 0]])
    write(d, "Criteria.csv", ["ID", "Type", "Asset", "Modifier_tree_ID"],
          [[8010, 0, 9001, 0], [8011, 0, 9002, 0], [8012, 0, 9003, 0], [8013, 92, 12345, 0], [8110, 0, 9101, 0], [8210, 0, 9201, 0],
           [8002, 165, 3501, 0], [8502, 165, 3502, 0], [8402, 165, 3701, 0], [8410, 0, 9401, 0], [8202, 165, 3501, 0]])
    write(d, "Creature.csv", ["ID", "Name_lang", "NameAlt_lang", "Title_lang", "Classification"],
          [[9001, "Test Guard", "", TEXT, 0], [9003, "Test Rat", "", "", 0], [9101, "Old Ghoul", "", "", 1], [9201, "Elsewhere", "", "", 0],
           [9401, "Code Rat", "", "", 0]])
    # ---- classes and specs. ChrClasses: the ID column is not the first one (as in the real table).
    write(d, "ChrClasses.csv", ["Name_lang", "Filename", "Description_lang", "ID"],
          [["Test Warrior", "TWARRIOR", TEXT, 1], ["Test Mage", "TMAGE", TEXT, 8]])
    write(d, "ChrSpecialization.csv", ["Name_lang", "Description_lang", "ID", "ClassID", "OrderIndex", "Role"],
          [["Fire", TEXT, 63, 8, 1, 2], ["Arcane", TEXT, 62, 8, 0, 2], ["Frost", TEXT, 64, 8, 2, 2], ["Arms", TEXT, 71, 1, 0, 2],
           ["Ferocity", TEXT, 74, 0, 0, 0]])

def run(d, out, extra_env=None, isolated=True):
    cmd = [sys.executable] + (["-I"] if isolated else []) + [BUILDER, "--build", "0.0.0.1", "--cache", d, "--out", out,
                                                              "--date", "2026-01-01"]
    env = dict(os.environ); env.update(extra_env or {})
    return subprocess.run(cmd, capture_output=True, text=True, env=env)

def load(out, name):
    p = os.path.join(out, name)
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {"about": {}, "data": []}

with tempfile.TemporaryDirectory() as d:
    tables(d)
    out = os.path.join(d, "out")
    r = run(d, out)
    check("the builder runs on the made-up tables (no download: every table is in the cache)", r.returncode == 0, r.stderr[-400:])

    items = load(out, "items.json")
    byId = {x["id"]: x for x in items["data"]}
    check("items: only the expansion's items, an older item in the download is dropped", sorted(byId) == [5001, 5002, 5004], sorted(byId))
    check("items: name, base item level, class and subclass, item set",
          byId.get(5002) == {"id": 5002, "name": "Test Helm", "ilvl": 260, "quality": 4, "inventoryType": 1, "classID": 4,
                             "subclassID": 4, "itemSet": 77, "requiredLevel": 80}, byId.get(5002))

    spells = {x["itemID"]: x["spells"] for x in load(out, "item-spells.json")["data"]}
    check("item spells: only items of the expansion, only items with a spell", sorted(spells) == [5001, 5004], sorted(spells))
    s1 = spells.get(5001, [])
    use = next((s for s in s1 if s["spell"] == 6001), {})
    check("an on-use spell that triggers a buff: the buff is listed as on you (self), reached through the used spell",
          use.get("trigger") == "on use" and use.get("cooldownMs") == 120000 and
          use.get("auras") == [{"id": 6011, "name": "Test Buff", "target": "self", "targetType": 1, "via": 6001}], use)
    equip = next((s for s in s1 if s["spell"] == 6002), {})
    check("an on-equip spell that applies an aura to an enemy: a debuff (enemy), applied by the spell itself",
          equip.get("trigger") == "on equip" and
          equip.get("auras") == [{"id": 6002, "name": "Test Debuff", "target": "enemy", "targetType": 6, "via": None}], equip)
    odd = (spells.get(5004) or [{}])[0]
    check("unknown trigger and target numbers are kept as numbers, never guessed",
          odd.get("trigger") == "trigger type 5" and odd.get("spec") == 65 and odd.get("charges") == 3 and
          [a.get("target") for a in odd.get("auras", [])] == ["target type 99"], odd)

    inst = {x["journalInstanceID"]: x for x in load(out, "instances.json")["data"]}
    check("instances: the expansion's dungeons AND the older dungeon in the expansion's Mythic+ season; not a dungeon only in another"
          " expansion's season", sorted(inst) == [1401, 1402, 1404], sorted(inst))
    keep = inst.get(1401, {})
    check("encounters in Adventure Guide order with their dungeon encounter IDs",
          [(e["name"], e["dungeonEncounterID"]) for e in keep.get("encounters", [])] == [("First Boss", 3501), ("Second Boss", 3502)],
          keep.get("encounters"))
    first = (keep.get("encounters") or [{}])[0]
    check("an encounter's abilities: each section spell once, sections without a spell left out",
          first.get("abilities") == [{"spell": 8001, "name": "Boss Smash"}, {"spell": 8002, "name": "Boss Roar"}], first.get("abilities"))
    check("an encounter's events with their severity",
          first.get("events") == [{"spell": 8001, "name": "Boss Smash", "severity": 1}, {"spell": 8002, "name": "Boss Roar", "severity": 2}],
          first.get("events"))
    ch = (keep.get("challenge") or [{}])[0]
    check("challenge mode: ID, timers (1, 2 and 3 chests), the seasons that track it",
          ch.get("mapChallengeModeID") == 901 and ch.get("timersSeconds") == [1800, 1440, 1080] and ch.get("trackedInSeasons") == [40], ch)
    ef = (ch.get("enemyForces") or [{}])
    check("enemy forces: both challenge trees of the dungeon, each saying how it was linked; a non-challenge 'Enemy Forces' is not"
          " attached", [(f.get("criteriaTree"), f.get("total"), f.get("linkedBy")) for f in ef] ==
          [(7000, 200, "encounters, name"), (7500, 400, "encounters")], [(f.get("criteriaTree"), f.get("linkedBy")) for f in ef])
    cr = ef[0].get("creatures", [])
    check("enemy forces: count and percent per creature kill (4 of 200 = 2%, 10 of 200 = 5%, 1 of 200 = 0.5%)",
          [(c["creatureID"], c["count"], c["percent"]) for c in cr] == [(9001, 4, 2.0), (9002, 10, 5.0), (9003, 1, 0.5)], cr)
    check("enemy forces: a creature the client's Creature table does not list keeps its ID and count, name null (never guessed)",
          [c.get("name") for c in cr] == ["Test Guard", None, "Test Rat"], [c.get("name") for c in cr])
    check("enemy forces: a criteria that is not a creature kill (Type 92) is listed apart and never counted",
          ef[0].get("notCreature") == [{"criteriaID": 8013, "type": 92, "asset": 12345, "amount": 9999}], ef[0].get("notCreature"))
    old = inst.get(1402, {})
    oldCh = (old.get("challenge") or [{}])[0]
    check("the older rotation dungeon: its expansion, its encounters and its enemy forces",
          old.get("expansionID") == 9 and [e["name"] for e in old.get("encounters", [])] == ["Old Boss"] and
          [(c["creatureID"], c["count"], c["percent"]) for f in oldCh.get("enemyForces", []) for c in f["creatures"]] == [(9101, 5, 10.0)],
          old)
    check("the older dungeon's tree is linked by its name", [f.get("linkedBy") for f in oldCh.get("enemyForces", [])] == ["name"],
          oldCh.get("enemyForces"))
    check("each instance says why it is listed", keep.get("listedBecause") == "expansion" and old.get("listedBecause") == "mythic+ season",
          (keep.get("listedBecause"), old.get("listedBecause")))
    den = ((inst.get(1404, {}).get("challenge") or [{}])[0].get("enemyForces") or [{}])[0]
    check("a challenge tree with an internal name is found through its boss's encounter (count 3 of 300 = 1%)",
          den.get("criteriaTree") == 7400 and den.get("linkedBy") == "encounters" and
          [(c["creatureID"], c["count"], c["percent"], c["name"]) for c in den.get("creatures", [])] == [(9401, 3, 1.0, "Code Rat")], den)

    classes = {c["classID"]: c for c in load(out, "classes.json")["data"]}
    check("classes: ID read from its column (not the first column), specs in their order",
          [s["specID"] for s in classes.get(8, {}).get("specs", [])] == [62, 63, 64] and classes.get(1, {}).get("file") == "TWARRIOR",
          classes.get(8))
    check("pet specializations are listed under class 0", [s["specID"] for s in classes.get(0, {}).get("specs", [])] == [74], classes.get(0))

    alltext = "".join(open(os.path.join(out, f), encoding="utf-8").read() for f in sorted(os.listdir(out))) if os.path.isdir(out) else ""
    check("no written text reaches the output (descriptions, titles, journal text): the repository is public", TEXT not in alltext)
    check("every output file names its source and build", all("wago.tools" in load(out, f)["about"].get("source", "") and "0.0.0.1" in
          load(out, f)["about"].get("source", "") for f in ("items.json", "item-spells.json", "instances.json", "classes.json")))

    # Same output whatever Python's hash seed (the files are committed: a rebuild must not reorder them).
    # A dungeon whose challenge mode and Adventure Guide names differ, each with its own enemy-forces tree, is where order could vary.
    with open(os.path.join(d, "MapChallengeMode.csv"), "a", encoding="utf-8", newline="") as f:
        csv.writer(f).writerow(["Test Keep: Upper", 904, 3001, 11, 1, 2, 3])
    with open(os.path.join(d, "MythicPlusSeasonTrackedMap.csv"), "a", encoding="utf-8", newline="") as f:
        csv.writer(f).writerow([5, 904, 40])
    with open(os.path.join(d, "CriteriaTree.csv"), "a", encoding="utf-8", newline="") as f:
        csv.writer(f).writerows([[7300, "1 Dungeon - Test Keep: Upper (Challenge)", 0, 0, 4, 0, 0, 0], [7301, "Enemy Forces", 7300, 40, 9, 0, 0, 0],
                                 [7310, "", 7301, 2, 0, 8010, 0, 0]])
    outs = set()
    for seed in range(8):
        o = os.path.join(d, "seed%d" % seed)
        r = run(d, o, {"PYTHONHASHSEED": str(seed)}, isolated=False)
        outs.add(open(os.path.join(o, "instances.json"), encoding="utf-8").read() if r.returncode == 0 else "error " + r.stderr[-200:])
    check("the same instances.json under 8 different hash seeds", len(outs) == 1, "%d different outputs" % len(outs))
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
