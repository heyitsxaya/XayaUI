#!/usr/bin/env python3
"""Builds docs/reference/content/: the current expansion's items, what each item's spells apply, its instances (dungeons and raids,
plus the older dungeons its Mythic+ seasons bring back) with their encounters, boss abilities and Mythic+ "enemy forces" counts per
creature, and every class and spec ID. Tested on made-up tables by tests/build_content_run.py; first run on real data 2026-11-04
(debug-log/2026-11-04-*-content-data-pulls-*.md)
(Xaya 2026-11-04: "Build out everything you need wrt functionalities to pull: item ids for current expansion (not just season),
item >> buff ids, item >> debuff ids, instanced content data ... ct/% per unit in challenge mode ... class + spec ids").

Facts only (IDs, numbers, names), from Blizzard's client data tables as published by wago.tools. No written text (descriptions,
journal body text, tooltips): the repository is public (docs/reference/README.md, "Public version and full version").
Tables and the columns read:
  ItemSparse (ID, Display_lang, ExpansionID, ItemLevel, OverallQualityID, InventoryType, ItemSet, RequiredLevel), Item (ClassID,
  SubclassID), ItemXItemEffect (ItemID, ItemEffectID), ItemEffect (TriggerType, SpellID, ChrSpecializationID, CoolDownMSec, Charges),
  SpellEffect (SpellID, Effect, EffectAura, EffectTriggerSpell, ImplicitTarget_0), SpellName, Map (ExpansionID, InstanceType,
  MaxPlayers), JournalInstance, JournalEncounter, JournalEncounterSection (SpellID only), DungeonEncounter, EncounterEvent
  (SpellID, Severity), MapChallengeMode (CriteriaCount_0..2), MythicPlusSeasonTrackedMap, CriteriaTree, Criteria (Type, Asset),
  Creature (Name_lang, Classification), ChrClasses, ChrSpecialization.
Which classes are playable comes from the game's own class list, captured in game (docs/reference/spells/spells.json), never
from ChrClasses: that table also has rows that are not playable classes (14 Adventurer and 15 Traveler in 12.1.5).

INFERENCES (the community's reading of these columns; each output file says which of its fields rest on them):
  - Who an item's aura lands on: ImplicitTarget_0 of the aura-applying effect. 1 = the caster ("self", a buff on you),
    6 = an enemy target ("enemy", a debuff), 21 = an ally ("ally"); any other number is kept as is ("target type N").
  - ItemEffect.TriggerType: 0 = on use, 1 = on equip, 2 = chance on hit; other numbers kept as is.
  - Mythic+ enemy forces: a dungeon's challenge criteria tree (its root's name says "Challenge") has a child "Enemy Forces" whose
    Amount is the total needed; each of ITS children whose criteria has Type 0 counts kills of the creature in Criteria.Asset, and
    that child's Amount is the count one kill gives (percent = Amount / total * 100). Children of other criteria types are listed
    separately as "notCreature" and never counted. Checked by hand for Windrunner Spire on 2026-11-04 (23 creature rows, amounts
    1-20, total 591); to be confirmed in game against C_ScenarioInfo.GetUnitCriteriaProgressValues (Dev Assist /xuidev instance).
  - MapChallengeMode.CriteriaCount_0..2: the timer limits in seconds (1, 2 and 3 chests).
  - No key column links a challenge tree to its dungeon. Two links are used, and each tree says which ("linkedBy"):
      "encounters": the tree's boss rows are Criteria Type 165 whose Asset is a DungeonEncounter ID, and DungeonEncounter.MapID is
                    the dungeon (all of the tree's bosses on one map). This finds trees named with Blizzard's internal names
                    ("Lightbloom" = The Blinding Vale, "Prove Your Worth" = Den of Nalorakk, "Nexus Point" = Nexus-Point Xenas).
      "name":       the root is "<n> Dungeon - <name> (Challenge)" and <name> is the challenge mode's or the Adventure Guide's name.
    Older dungeons have a second tree, "... (More Trash)", with other counts. Every linked tree is listed; which one the game uses
    is NOT in the client data: compare "total" with C_ScenarioInfo.GetCriteriaInfo in game.
  - The expansion's Mythic+ seasons: MythicPlusSeasonTrackedMap has no expansion column, so a season counts as the expansion's when
    it tracks at least one dungeon on one of the expansion's maps. Every dungeon those seasons track is listed, older ones included
    ("listedBecause": "mythic+ season"); in 12.1.5.70783 seasons 34 and 37 bring back seven older dungeons this way.
  - JournalEncounter.DungeonEncounterID is the encounterID ENCOUNTER_START sends (the documentation only says "encounterID:
    number"); to be confirmed against Dev Assist's probe anchors.
What the client data does not hold, and so is not here: trash creatures' spells, which creatures are in an instance other than through
the enemy-forces list, and many current creatures' names (the client's Creature table lists a subset; missing names stay null).

Usage:
  python3 docs/reference/build_content.py --build 12.1.5.70783 --cache <folder for the CSVs> [--expansion 11] [--out docs/reference/content]
The CSVs are downloaded from https://wago.tools/db2/<Table>/csv?build=<build> into --cache when missing (ItemSparse filtered to the
expansion). Standard library only. Run it with python3 -I; the CSVs are read as data.
"""
import argparse, csv, json, os, re, sys, urllib.request
from collections import defaultdict

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
TABLES = ["Item", "ItemXItemEffect", "ItemEffect", "SpellEffect", "SpellName", "Map", "JournalInstance", "JournalEncounter",
          "JournalEncounterSection", "DungeonEncounter", "EncounterEvent", "MapChallengeMode", "MythicPlusSeasonTrackedMap",
          "CriteriaTree", "Criteria", "Creature", "ChrClasses", "ChrSpecialization"]
TARGET = {1: "self", 6: "enemy", 21: "ally"}                 # INFERENCE (see the header)
TRIGGER = {0: "on use", 1: "on equip", 2: "chance on hit"}    # INFERENCE


def fetch(build, cache, expansion):
    os.makedirs(cache, exist_ok=True)
    want = [(t, t + ".csv", "") for t in TABLES]
    want.append(("ItemSparse", "ItemSparse.exp%d.csv" % expansion, "&filter%%5BExpansionID%%5D=%d" % expansion))
    for table, name, extra in want:
        p = os.path.join(cache, name)
        if os.path.exists(p) and os.path.getsize(p) > 0:
            continue
        url = "https://wago.tools/db2/%s/csv?build=%s%s" % (table, build, extra)
        with urllib.request.urlopen(url, timeout=900) as r, open(p, "wb") as f:
            f.write(r.read())


def rows(cache, name):
    with open(os.path.join(cache, name), encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)


def num(v, default=0):
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


def build(cache, expansion, playableTokens=None):
    names = {num(r["ID"]): r["Name_lang"] for r in rows(cache, "SpellName.csv")}

    # ---- spells: what each spell triggers and which of its effects apply an aura, with the target of that effect
    triggers = defaultdict(set)
    auraTargets = defaultdict(set)   # spell -> ImplicitTarget_0 of its aura-applying effects
    for r in rows(cache, "SpellEffect.csv"):
        s = num(r["SpellID"])
        if not s:
            continue
        t = num(r["EffectTriggerSpell"])
        if t:
            triggers[s].add(t)
        if num(r["EffectAura"]) > 0:
            auraTargets[s].add(num(r["ImplicitTarget_0"]))

    def auras_of(spell, depth=3):
        """every aura-applying spell reachable from `spell` through EffectTriggerSpell (itself included), with its target(s)"""
        seen, frontier, out = {spell}, [spell], []
        for _ in range(depth + 1):
            nxt = []
            for x in frontier:
                if x in auraTargets:
                    for tt in sorted(auraTargets[x]):
                        out.append({"id": x, "name": names.get(x), "target": TARGET.get(tt, "target type %d" % tt), "targetType": tt,
                                    "via": None if x == spell else spell})
                for y in sorted(triggers.get(x, ())):
                    if y not in seen:
                        seen.add(y); nxt.append(y)
            frontier = nxt
        return out

    # ---- items of the expansion
    itemBase = {}
    for r in rows(cache, "Item.csv"):
        itemBase[num(r["ID"])] = (num(r["ClassID"]), num(r["SubclassID"]))
    items = []
    for r in rows(cache, "ItemSparse.exp%d.csv" % expansion):
        if num(r["ExpansionID"], -1) != expansion:
            continue   # (the download is filtered; a row from elsewhere is never kept)
        i = num(r["ID"])
        cls, sub = itemBase.get(i, (None, None))
        items.append({"id": i, "name": r["Display_lang"], "ilvl": num(r["ItemLevel"]), "quality": num(r["OverallQualityID"]),
                      "inventoryType": num(r["InventoryType"]), "classID": cls, "subclassID": sub, "itemSet": num(r["ItemSet"]),
                      "requiredLevel": num(r["RequiredLevel"])})
    items.sort(key=lambda x: x["id"])
    ids = {x["id"] for x in items}

    # ---- item -> its spells -> the auras they apply (buff on you, debuff on an enemy ...)
    effects = {num(r["ID"]): r for r in rows(cache, "ItemEffect.csv")}
    itemEffects = defaultdict(list)
    for r in rows(cache, "ItemXItemEffect.csv"):
        it = num(r["ItemID"])
        if it in ids:
            e = effects.get(num(r["ItemEffectID"]))
            if e is not None:
                itemEffects[it].append(e)
    itemSpells = {}
    for it in sorted(itemEffects):
        lst = []
        for e in sorted(itemEffects[it], key=lambda e: num(e["ID"])):
            sp = num(e["SpellID"])
            if not sp:
                continue
            tr = num(e["TriggerType"])
            lst.append({"spell": sp, "name": names.get(sp), "trigger": TRIGGER.get(tr, "trigger type %d" % tr), "triggerType": tr,
                        "spec": num(e["ChrSpecializationID"]), "cooldownMs": num(e["CoolDownMSec"]), "charges": num(e["Charges"]),
                        "auras": auras_of(sp)})
        if lst:
            itemSpells[str(it)] = lst

    # ---- instances of the expansion (the Adventure Guide's dungeons and raids whose map belongs to it)
    maps = {num(r["ID"]): r for r in rows(cache, "Map.csv")}
    dungeonEnc = {num(r["ID"]): r for r in rows(cache, "DungeonEncounter.csv")}
    sections = defaultdict(list)
    for r in rows(cache, "JournalEncounterSection.csv"):
        sp = num(r["SpellID"])
        if sp:
            sections[num(r["JournalEncounterID"])].append(sp)
    events = defaultdict(list)
    for r in rows(cache, "EncounterEvent.csv"):
        sp = num(r["SpellID"])
        if sp:
            events[num(r["DungeonEncounterID"])].append({"spell": sp, "name": names.get(sp), "severity": num(r["Severity"])})
    encByInst = defaultdict(list)
    for r in rows(cache, "JournalEncounter.csv"):
        encByInst[num(r["JournalInstanceID"])].append(r)
    challenge = defaultdict(list)
    for r in rows(cache, "MapChallengeMode.csv"):
        challenge[num(r["MapID"])].append(r)
    seasons = defaultdict(set)
    for r in rows(cache, "MythicPlusSeasonTrackedMap.csv"):
        seasons[num(r["MapChallengeModeID"])].add(num(r["DisplaySeasonID"]))
    # the expansion's Mythic+ seasons (INFERENCE, see the header) and every map they track, older expansions' included
    cmMap = {num(c["ID"]): num(c["MapID"]) for lst in challenge.values() for c in lst}
    def mapExpansion(mid):
        return num(maps[mid]["ExpansionID"], -1) if mid in maps else -1
    expSeasons = set()
    for cmID, ss in seasons.items():
        if mapExpansion(cmMap.get(cmID, 0)) == expansion:
            expSeasons |= ss
    rotationMaps = {cmMap[cmID] for cmID, ss in seasons.items() if cmID in cmMap and ss & expSeasons}

    # Mythic+ enemy forces, found through the criteria trees
    tree = {}
    children = defaultdict(list)
    for r in rows(cache, "CriteriaTree.csv"):
        tree[num(r["ID"])] = r
        children[num(r["Parent"])].append(r)
    crit = {num(r["ID"]): r for r in rows(cache, "Criteria.csv")}
    creatures = {num(r["ID"]): r for r in rows(cache, "Creature.csv")}
    forcesByName = defaultdict(list)
    forcesByMap = defaultdict(list)
    for node in tree.values():
        if node["Description_lang"] != "Enemy Forces":
            continue
        root = tree.get(num(node["Parent"]))
        if not root or "challenge" not in root["Description_lang"].lower():
            continue   # an "Enemy Forces" outside a challenge tree (a scenario, a delve) is not Mythic+
        m = re.match(r"^.*? - (.+) \(Challenge\)\s*$", root["Description_lang"])
        bossMaps = set()
        for sib in children.get(num(root["ID"]), []):
            c = crit.get(num(sib["CriteriaID"]))
            if c is not None and num(c["Type"]) == 165 and num(c["Asset"]) in dungeonEnc:   # INFERENCE: 165 = defeat this encounter
                bossMaps.add(num(dungeonEnc[num(c["Asset"])]["MapID"]))
        if not m and len(bossMaps) != 1:
            continue
        counted, other = [], []
        for ch in sorted(children.get(num(node["ID"]), []), key=lambda r: (num(r["OrderIndex"]), num(r["ID"]))):
            c = crit.get(num(ch["CriteriaID"]))
            amount = num(ch["Amount"])
            if c is not None and num(c["Type"]) == 0 and num(c["Asset"]) > 0:
                cid = num(c["Asset"])
                cr = creatures.get(cid)
                counted.append({"creatureID": cid, "count": amount,
                                "name": cr["Name_lang"] if cr else None, "classification": num(cr["Classification"]) if cr else None})
            else:
                other.append({"criteriaID": num(ch["CriteriaID"]), "type": num(c["Type"]) if c else None,
                              "asset": num(c["Asset"]) if c else None, "amount": amount})
        total = num(node["Amount"])
        for x in counted:
            x["percent"] = round(x["count"] * 100.0 / total, 2) if total else None
        entry = {"criteriaTree": num(root["ID"]), "tree": root["Description_lang"], "total": total, "creatures": counted,
                 "notCreature": other}
        if m:
            forcesByName[m.group(1).strip().lower()].append(entry)
        if len(bossMaps) == 1:
            forcesByMap[bossMaps.pop()].append(entry)

    instances = []
    for r in rows(cache, "JournalInstance.csv"):
        mid = num(r["MapID"])
        mp = maps.get(mid)
        if not mp:
            continue
        if num(mp["ExpansionID"], -1) == expansion:
            why = "expansion"
        elif mid in rotationMaps:
            why = "mythic+ season"
        else:
            continue
        inst = {"journalInstanceID": num(r["ID"]), "name": r["Name_lang"], "mapID": mid, "instanceType": num(mp["InstanceType"]),
                "maxPlayers": num(mp["MaxPlayers"]), "expansionID": num(mp["ExpansionID"], -1), "listedBecause": why,
                "encounters": [], "challenge": []}
        for e in sorted(encByInst.get(inst["journalInstanceID"], []), key=lambda e: num(e["OrderIndex"])):
            de = num(e["DungeonEncounterID"])
            inst["encounters"].append({"journalEncounterID": num(e["ID"]), "name": e["Name_lang"], "dungeonEncounterID": de,
                                       "uiMapID": num(e["UiMapID"]),
                                       "abilities": [{"spell": s, "name": names.get(s)} for s in sorted(set(sections.get(num(e["ID"]), [])))],
                                       "events": sorted(events.get(de, []), key=lambda x: x["spell"])})
        for c in challenge.get(mid, []):
            cm = {"mapChallengeModeID": num(c["ID"]), "name": c["Name_lang"],
                  "timersSeconds": [num(c["CriteriaCount_%d" % k]) for k in range(3)],
                  "trackedInSeasons": sorted(seasons.get(num(c["ID"]), [])), "enemyForces": []}
            found = {}   # criteria tree -> (entry, how it was linked)
            for key in (c["Name_lang"].strip().lower(), r["Name_lang"].strip().lower()):
                for f in forcesByName.get(key, []):
                    found.setdefault(f["criteriaTree"], (f, set()))[1].add("name")
            for f in forcesByMap.get(mid, []):
                found.setdefault(f["criteriaTree"], (f, set()))[1].add("encounters")
            for t in sorted(found):   # by tree ID: the same file every build
                f, how = found[t]
                f = dict(f); f["linkedBy"] = ", ".join(sorted(how))
                cm["enemyForces"].append(f)
            inst["challenge"].append(cm)
        instances.append(inst)
    instances.sort(key=lambda x: x["journalInstanceID"])

    # ---- classes and specs
    specs = defaultdict(list)
    for r in rows(cache, "ChrSpecialization.csv"):
        specs[num(r["ClassID"])].append({"specID": num(r["ID"]), "name": r["Name_lang"], "order": num(r["OrderIndex"]), "role": num(r["Role"])})
    classes = []
    for r in rows(cache, "ChrClasses.csv"):
        cid = num(r["ID"])
        # playable: from the game's own class list (playableTokens), never from this table (it also has non-playable rows,
        # e.g. 14 Adventurer and 15 Traveler in 12.1.5); None when that list is not available (unknown, never guessed)
        classes.append({"classID": cid, "file": r["Filename"], "name": r["Name_lang"],
                        "playable": (r["Filename"] in playableTokens) if playableTokens is not None else None,
                        "specs": sorted(specs.get(cid, []), key=lambda s: (s["order"], s["specID"]))})
    classes.sort(key=lambda x: x["classID"])
    pet = sorted(specs.get(0, []), key=lambda s: s["specID"])
    return items, itemSpells, instances, classes, pet


def write_lines(path, header, records):
    """one record per line (readable diffs); `header` is a dict written first"""
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("{\n\"about\": " + json.dumps(header, ensure_ascii=False) + ",\n\"data\": [\n")
        for i, r in enumerate(records):
            f.write(json.dumps(r, ensure_ascii=False, sort_keys=True) + (",\n" if i < len(records) - 1 else "\n"))
        f.write("]\n}\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", required=True)
    ap.add_argument("--cache", required=True)
    ap.add_argument("--expansion", type=int, default=11, help="Enum.ExpansionLevel (11 = Midnight)")
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "reference", "content"))
    ap.add_argument("--date", default=None)
    ap.add_argument("--playable-from", default=os.path.join(ROOT, "docs", "reference", "spells", "spells.json"),
                    help="the game's own class list, captured in game (classes[].token); marks which ChrClasses rows are playable")
    a = ap.parse_args()
    fetch(a.build, a.cache, a.expansion)
    playableTokens = None
    if os.path.isfile(a.playable_from):
        with open(a.playable_from, encoding="utf-8") as f:
            playableTokens = {c["token"] for c in json.load(f).get("classes", []) if isinstance(c, dict) and c.get("token")}
    items, itemSpells, instances, classes, pet = build(a.cache, a.expansion, playableTokens)
    date = a.date
    if not date:
        import datetime
        date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    src = "Blizzard's client data tables, build %s, as published by wago.tools; built by docs/reference/build_content.py on %s" % (a.build, date)
    os.makedirs(a.out, exist_ok=True)
    write_lines(os.path.join(a.out, "items.json"), {"source": src, "expansion": a.expansion, "count": len(items),
        "fields": "id, name, ilvl (base level; the level that drops depends on bonus lists), quality, inventoryType, classID, subclassID, itemSet, requiredLevel",
        "note": "ExpansionID tags the item's expansion; it is not the patch an item was added in."}, items)
    write_lines(os.path.join(a.out, "item-spells.json"), {"source": src, "items": len(itemSpells),
        "fields": "per item: spell, trigger (INFERENCE from ItemEffect.TriggerType), spec (0 = any), cooldownMs, charges, auras: the aura-applying spells reached through EffectTriggerSpell (up to 3 steps) with target (INFERENCE from ImplicitTarget_0: self = a buff on you, enemy = a debuff, ally)",
        "note": "Many item effects are scripted on the server: the data then shows no aura, or a dummy one. Confirm in game with the Dev Assist cast recorder / aura log."},
        [{"itemID": int(k), "spells": v} for k, v in sorted(itemSpells.items(), key=lambda kv: int(kv[0]))])
    write_lines(os.path.join(a.out, "instances.json"), {"source": src, "instances": len(instances),
        "fields": "journalInstanceID, name, mapID, instanceType (Map.InstanceType as stored), maxPlayers, expansionID, listedBecause (expansion, or mythic+ season: an older dungeon one of the expansion's Mythic+ seasons tracks; INFERENCE); encounters: journalEncounterID, dungeonEncounterID (INFERENCE: = ENCOUNTER_START's encounterID), uiMapID, abilities (Adventure Guide section spells), events (EncounterEvent spells, severity); challenge: mapChallengeModeID, timersSeconds (INFERENCE), trackedInSeasons, enemyForces (INFERENCE): every challenge tree linked to the dungeon (linkedBy: encounters = its boss criteria are on this map; name = its name), each with total, creatures (creatureID, count per kill, percent, name when the client lists it), notCreature; when several trees are listed (older dungeons have a '(More Trash)' one), the one the game uses is the one whose total C_ScenarioInfo.GetCriteriaInfo shows in game",
        "note": "Trash creatures' spells and an instance's full creature list are not in the client data; Dev Assist's /xuidev instance capture records them in game."}, instances)
    nPlayable = sum(1 for c in classes if c["playable"])
    write_lines(os.path.join(a.out, "classes.json"), {"source": src, "rows": len(classes),
        "playable": nPlayable if playableTokens is not None else None,
        "fields": "classID, file, name, playable, specs (specID, name, order, role as stored); pet specializations listed under classID 0 (not a class)",
        "note": "ChrClasses also holds rows that are not playable classes. playable = the class is in the game's own class list, captured in game (docs/reference/spells/spells.json); null when that list was not available. Each playable class also has an 'Initial' spec row (before a spec is chosen)."},
        classes + [{"classID": 0, "file": "PET", "name": "(pet specializations)", "playable": False, "specs": pet}])
    nf = sum(len(f["creatures"]) for i in instances for c in i["challenge"] for f in c["enemyForces"])
    print("wrote %s: items %d, items with spells %d, instances %d, enemy-forces creatures %d, class rows %d (playable %s)" % (
        a.out, len(items), len(itemSpells), len(instances), nf, len(classes), nPlayable if playableTokens is not None else "unknown"))


if __name__ == "__main__":
    main()
