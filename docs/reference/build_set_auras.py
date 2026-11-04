#!/usr/bin/env python3
"""Builds XayaUI/SetBonusAuras.lua: which auras only a tier-set bonus can put on the player, and what that bonus needs (the item set,
how many pieces, which specialization). XayaUI uses it so a Buff / Aura trigger on such an aura knows, even in combat, that the aura
cannot be on you while the bonus is not active (core 0.6.20; Xaya 2026-11-04: tier sets "should be baked into the aura tracking").

Facts only (IDs and numbers), from Blizzard's client data tables as published by wago.tools:
  ItemSetSpell   ItemSetID, SpellID (the bonus), Threshold (pieces), ChrSpecID (0 = any spec), TraitSubTreeID (hero tree, 0 = any)
  SpellEffect    SpellID, EffectTriggerSpell, EffectAura (an aura-applying effect has EffectAura > 0)
  SpellName      names, for the comments only
  SkillLineAbility, TraitDefinition   spells a player can have from their class / talents (an aura they can apply is not set-only)
The current sets are the ones in docs/reference/spells/spells.json (the Encounter Journal's sets per spec, from /xuidump static).

How an aura is linked to a bonus (the community's reading of these columns, not confirmed in game):
  - every spell the bonus triggers, and what those trigger, up to 3 steps, that applies an aura;
  - kept only when NOTHING else can apply it: no spell outside this set's own chains triggers it, and it is not a class or talent
    spell itself. Anything else stays out, because a wrong link would make XayaUI say "missing" while the aura is up.
  - an aura linked from several bonuses of its set gets the fewest pieces any of them needs and every spec any of them is for, so
    XayaUI calls it "off" only when all of them are off (tests/build_set_auras_run.py).

Usage:
  python3 docs/reference/build_set_auras.py --build 12.1.5.70783 --cache <folder of the CSVs> --out XayaUI/SetBonusAuras.lua
The CSVs are downloaded from https://wago.tools/db2/<Table>/csv?build=<build> into --cache when missing. Standard library only.
"""
import argparse, csv, json, os, sys, urllib.request
from collections import defaultdict

TABLES = ["ItemSetSpell", "SpellEffect", "SpellName", "SkillLineAbility", "TraitDefinition"]
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")


def fetch(build, cache):
    os.makedirs(cache, exist_ok=True)
    for t in TABLES:
        p = os.path.join(cache, t + ".csv")
        if os.path.exists(p) and os.path.getsize(p) > 0:
            continue
        with urllib.request.urlopen("https://wago.tools/db2/%s/csv?build=%s" % (t, build), timeout=600) as r, open(p, "wb") as f:
            f.write(r.read())


def rows(cache, t):
    with open(os.path.join(cache, t + ".csv"), encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", required=True)
    ap.add_argument("--cache", required=True)
    ap.add_argument("--out", default=os.path.join(ROOT, "XayaUI", "SetBonusAuras.lua"))
    ap.add_argument("--date", default=None)
    ap.add_argument("--sets", default=os.path.join(ROOT, "docs", "reference", "spells", "spells.json"),
                    help="the file that lists the current sets (default: docs/reference/spells/spells.json)")
    a = ap.parse_args()
    fetch(a.build, a.cache)

    ref = json.load(open(a.sets, encoding="utf-8"))
    current, setName = set(), {}
    for cl in ref.get("classes", []):
        for _, lst in (cl.get("sets") or {}).items():
            for e in lst:
                current.add(int(e["setID"])); setName[int(e["setID"])] = e.get("name", "")

    names = {int(r["ID"]): r["Name_lang"] for r in rows(a.cache, "SpellName")}
    player = {int(r["Spell"]) for r in rows(a.cache, "SkillLineAbility") if r["Spell"]}
    for r in rows(a.cache, "TraitDefinition"):
        for k in ("SpellID", "OverridesSpellID", "VisibleSpellID"):
            if r[k] and r[k] != "0":
                player.add(int(r[k]))

    triggers = defaultdict(set)      # spell -> spells it triggers
    triggeredBy = defaultdict(set)   # spell -> spells that trigger it
    appliesAura = set()              # spells with an aura-applying effect
    for r in rows(a.cache, "SpellEffect"):
        sid = int(r["SpellID"] or 0)
        if not sid:
            continue
        t = int(r["EffectTriggerSpell"] or 0)
        if t:
            triggers[sid].add(t); triggeredBy[t].add(sid)
        if int(r["EffectAura"] or 0) > 0:
            appliesAura.add(sid)

    bonuses = []   # (set, pieces, spec, hero, bonus spell)
    for r in rows(a.cache, "ItemSetSpell"):
        s = int(r["ItemSetID"])
        if s in current:
            bonuses.append((s, int(r["Threshold"]), int(r["ChrSpecID"]), int(r["TraitSubTreeID"]), int(r["SpellID"])))

    def chain(start, depth=3):
        seen, frontier = {start}, {start}
        for _ in range(depth):
            nxt = set()
            for x in frontier:
                for y in triggers.get(x, ()):
                    if y not in seen:
                        seen.add(y); nxt.add(y)
            frontier = nxt
        return seen

    setChain = defaultdict(set)   # set -> every spell in its bonuses' chains
    chains = {}
    for (s, n, spec, hero, b) in bonuses:
        c = chain(b); chains[(s, n, spec, hero, b)] = c; setChain[s] |= c

    links = defaultdict(list)   # aura -> every bonus (set, pieces, spec, hero, bonus spell) that links it
    for key, c in chains.items():
        s, n, spec, hero, b = key
        for x in c:
            if x == b or x not in appliesAura or x in player:
                continue
            if any(t not in setChain[s] for t in triggeredBy.get(x, ())):
                continue   # something outside this set can apply it: not set-only
            links[x].append(key)

    # One entry per aura that XayaUI may read as "off" only when EVERY bonus linking it is off: the fewest pieces any of them needs, and
    # every spec any of them is for (0 = any spec wins). XayaUI never reads the hero tree, so a hero-only bonus is treated as any tree.
    out = {}   # aura -> {set, pieces, specs, bonus}
    for x, ks in links.items():
        sets = {k[0] for k in ks}
        if len(sets) != 1:
            continue   # (cannot happen after the filter above; kept out rather than guessed)
        n = min(k[1] for k in ks)
        specs = {k[2] for k in ks}
        if 0 in specs:
            specs = {0}
        b = min(k[4] for k in ks if k[1] == n)
        out[x] = {"set": ks[0][0], "pieces": n, "specs": specs, "bonus": b}

    date = a.date
    if not date:
        import datetime
        date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    L = ["-- XayaUI: auras only a tier-set bonus can put on you (generated; do not edit by hand).",
         "-- Source: Blizzard's client data tables for build %s as published by wago.tools (ItemSetSpell, SpellEffect, SpellName," % a.build,
         "-- SkillLineAbility, TraitDefinition), current sets from docs/reference/spells/spells.json; built by docs/reference/build_set_auras.py",
         "-- on %s. Facts only (IDs, counts). The aura-to-bonus link is the community's reading of SpellEffect (see the builder's header)." % date,
         "-- Fields: set = item set ID, pieces = pieces needed, specs = specializations the bonus is for (0 = any), bonus = the bonus spell.",
         "local _, ns = ...",
         "ns.SET_BONUS_BUILD = \"%s\"" % a.build,
         "ns.SET_BONUS_AURAS = {"]
    for x in sorted(out):
        e = out[x]
        specs = ", ".join(str(v) for v in sorted(e["specs"]))
        L.append("    [%d] = { set = %d, pieces = %d, specs = { %s }, bonus = %d },   -- %s <- %s (%s, %d pc)" % (
            x, e["set"], e["pieces"], specs, e["bonus"], names.get(x, "?").replace("\n", " "), names.get(e["bonus"], "?").replace("\n", " "),
            setName.get(e["set"], "?"), e["pieces"]))
    L.append("}")
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    print("wrote", a.out, "auras", len(out), "from", len(bonuses), "bonuses of", len(current), "sets")


if __name__ == "__main__":
    main()
