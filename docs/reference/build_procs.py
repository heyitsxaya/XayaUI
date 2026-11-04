#!/usr/bin/env python3
"""Builds docs/reference/procs.md: which auras Blizzard's client data gives proc art or a button highlight, and which player
spells each one lights. Facts only (IDs, names, numbers), from Blizzard's client data tables as published by wago.tools.
No descriptions or other Blizzard text are written.

Usage:
  python3 docs/reference/build_procs.py --build 12.1.5.70783 --cache <folder for the downloaded CSVs> [--out docs/reference/procs.md]

The CSVs are downloaded from https://wago.tools/db2/<Table>/csv?build=<build> into --cache (skipped when already there).
Only the standard library is used; the CSVs are parsed as data, never run.
"""
import argparse, csv, os, sys, urllib.request
from collections import defaultdict

TABLES = ["SpellActivationOverlay", "SpellClassOptions", "SpellName", "ChrClasses", "SpellAuraOptions", "SpellMisc",
          "SpellDuration", "SkillLineAbility", "TraitDefinition"]
PLAYABLE = range(1, 14)   # ChrClasses IDs 1-13 (14 Adventurer and 15 Traveler are not playable classes)


def fetch(build, cache):
    os.makedirs(cache, exist_ok=True)
    for t in TABLES:
        p = os.path.join(cache, t + ".csv")
        if os.path.exists(p) and os.path.getsize(p) > 0:
            continue
        url = "https://wago.tools/db2/%s/csv?build=%s" % (t, build)
        with urllib.request.urlopen(url, timeout=300) as r, open(p, "wb") as f:
            f.write(r.read())


def rows(cache, t):
    with open(os.path.join(cache, t + ".csv"), encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)


def u32(v):
    return int(v) & 0xFFFFFFFF


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", required=True)
    ap.add_argument("--cache", required=True)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "procs.md"))
    ap.add_argument("--date", default=None, help="date written in the header (default: today, UTC)")
    a = ap.parse_args()
    fetch(a.build, a.cache)

    names = {r["ID"]: r["Name_lang"] for r in rows(a.cache, "SpellName")}
    classes = {}   # spell class set -> (class ID, name, token)
    for r in rows(a.cache, "ChrClasses"):
        if int(r["ID"]) in PLAYABLE:
            classes[int(r["SpellClassSet"])] = (int(r["ID"]), r["Name_lang"], r["Filename"])
    sco = {}       # spell -> (class set, mask)
    for r in rows(a.cache, "SpellClassOptions"):
        sco[r["SpellID"]] = (int(r["SpellClassSet"]), [u32(r["SpellClassMask_%d" % i]) for i in range(4)])
    on_line = {r["Spell"] for r in rows(a.cache, "SkillLineAbility")}
    talent = set()
    for r in rows(a.cache, "TraitDefinition"):
        for k in ("SpellID", "OverridesSpellID", "VisibleSpellID"):
            if r[k] and r[k] != "0":
                talent.add(r[k])
    player = on_line | talent
    stacks, charges = {}, {}
    for r in rows(a.cache, "SpellAuraOptions"):
        if r["DifficultyID"] == "0":
            stacks[r["SpellID"]], charges[r["SpellID"]] = int(r["CumulativeAura"]), int(r["ProcCharges"])
    dur_ms = {r["ID"]: int(r["Duration"]) for r in rows(a.cache, "SpellDuration")}
    duration = {}
    for r in rows(a.cache, "SpellMisc"):
        if r["DifficultyID"] == "0" and r["DurationIndex"] not in ("", "0"):
            duration[r["SpellID"]] = dur_ms.get(r["DurationIndex"])

    by_set = defaultdict(list)   # class set -> spells in it (for the mask match)
    for sid, (cs, m) in sco.items():
        by_set[cs].append((sid, m))

    overlays = list(rows(a.cache, "SpellActivationOverlay"))
    entries = []                 # one per overlay row
    for r in overlays:
        aura = r["SpellID"]
        cs = sco.get(aura, (None, None))[0]
        hm = [u32(r["IconHighlightSpellClassMask_%d" % i]) for i in range(4)]
        lit = []
        if cs is not None and any(hm):
            lit = sorted((s for s, m in by_set[cs] if any(x & y for x, y in zip(hm, m))), key=int)
        entries.append({"row": r["ID"], "aura": aura, "set": cs, "mask": hm, "art": r["OverlayFileDataID"] not in ("", "0"),
                        "loc": r["ScreenLocationID"], "lit": lit})

    # reverse index: lit player spell -> overlay auras (same class set) that light it
    lit_by = defaultdict(list)
    for e in entries:
        for s in e["lit"]:
            if s in player:
                lit_by[s].append(e["aura"])

    def nm(s):
        return names.get(s, "(no name)").replace("|", "/")

    def dur(s):
        d = duration.get(s)
        if d is None:
            return ""
        if d < 0:
            return "until cancelled"
        return ("%g s" % (d / 1000.0)) if d else ""

    out = []
    w = out.append
    date = a.date
    if not date:
        import datetime
        date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    w("# Proc art and button highlights by aura")
    w("")
    w("Built %s from Blizzard's client data tables for **build %s**, as published by wago.tools "
      "(`https://wago.tools/db2/<Table>/csv?build=%s`). Facts only: IDs, names and numbers. No descriptions or other "
      "Blizzard text. Rebuild with `docs/reference/build_procs.py` (see its header)." % (date, a.build, a.build))
    w("")
    w("## What this is for")
    w("In combat the game hides most auras from addons, but the events that light a button (`SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` "
      "/ `_HIDE`, `C_SpellActivationOverlay.IsSpellOverlayed`) and the screen-edge proc art (`SPELL_ACTIVATION_OVERLAY_SHOW` / `_HIDE`) "
      "carry no secrecy flag in the 12.1.5 API documentation (`api/events.md`, `api/namespaces.md`). When a lit button has exactly one "
      "aura that can light it, the glow says that aura is up.")
    w("")
    w("## How it was built, and its limits")
    w("- **Source tables:** `SpellActivationOverlay` (one row per aura with proc art or a button highlight), `SpellClassOptions` "
      "(each spell's class set and class mask), `ChrClasses` (class set of each class), `SpellName`, `SpellAuraOptions` "
      "(max stacks, charges), `SpellMisc` + `SpellDuration` (base duration), `SkillLineAbility` and `TraitDefinition` (which spells "
      "a player can have).")
    w("- **Which buttons an aura lights:** the spells of the aura's own class set whose class mask shares a bit with the row's "
      "`IconHighlightSpellClassMask`. This is how the community documents these columns (column names as wago.tools publishes "
      "them); it is not confirmed in game.")
    w("- **Shared buttons:** \"shared with N\" counts the other auras in this table that light the same button. Only a button "
      "with no other aura (\"only this aura\") identifies its aura by its glow alone. Otherwise the character's talents and set "
      "bonuses must rule the others out.")
    w("- **Player spells only** are named in the lit-buttons column: spells on a skill line (`SkillLineAbility`) or in a talent "
      "(`TraitDefinition`). Other spell IDs the mask matches are counted at the end of the cell.")
    w("- **Not covered:** auras with no row here (most auras), whatever the server decides at run time, and which spell ID the "
      "glow event reports when a spell is replaced (for example Final Verdict for Templar's Verdict). Check in game.")
    w("- **Duration** is the base duration (difficulty 0). Talents, gear and haste can change it. **Stacks** is the most the aura "
      "can stack (0 = does not stack). **Charges** is the number of uses before it is consumed (0 = not consumed by uses).")
    w("")

    by_class = defaultdict(list)
    other = []
    for e in entries:
        if e["set"] in classes:
            by_class[e["set"]].append(e)
        else:
            other.append(e)
    total = len(entries)
    w("## Summary")
    w("| Class | Auras with a row | With a button highlight | Of those, a button no other aura lights |")
    w("|---|---|---|---|")
    for cs in sorted(classes, key=lambda c: classes[c][1]):
        es = by_class.get(cs, [])
        hl = [e for e in es if any(s in player for s in e["lit"])]
        uniq = [e for e in hl if any(s in player and len(lit_by[s]) == 1 for s in e["lit"])]
        w("| %s | %d | %d | %d |" % (classes[cs][1], len(es), len(hl), len(uniq)))
    w("| (no playable class) | %d | | |" % len(other))
    w("")
    w("%d rows in `SpellActivationOverlay` for this build." % total)
    w("")

    for cs in sorted(classes, key=lambda c: classes[c][1]):
        es = sorted(by_class.get(cs, []), key=lambda e: int(e["aura"]))
        if not es:
            continue
        w("## %s (`%s`)" % (classes[cs][1], classes[cs][2]))
        w("")
        w("| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |")
        w("|---|---|---|---|---|---|---|---|")
        for e in es:
            cells = []
            pl = [s for s in e["lit"] if s in player]
            for s in pl:
                n = len(lit_by[s]) - 1
                cells.append("%s %s (%s)" % (nm(s), s, "only this aura" if n == 0 else "shared with %d" % n))
            rest = len(e["lit"]) - len(pl)
            if rest:
                cells.append("+%d other spell ID%s" % (rest, "" if rest == 1 else "s"))
            w("| %s | %s | %s | %s | %s | %s | %s | %s |" % (
                e["aura"], nm(e["aura"]), ("yes (position %s)" % e["loc"]) if e["art"] else "no",
                "; ".join(cells) if cells else "", dur(e["aura"]), stacks.get(e["aura"], ""), charges.get(e["aura"], ""), e["row"]))
        w("")
        shared = sorted({s for e in es for s in e["lit"] if s in player and len(lit_by[s]) > 1}, key=int)
        if shared:
            w("**Buttons lit by more than one aura (%s):**" % classes[cs][1])
            w("")
            w("| Button | Auras that light it |")
            w("|---|---|")
            for s in shared:
                w("| %s %s | %s |" % (nm(s), s, "; ".join("%s %s" % (nm(x), x) for x in sorted(set(lit_by[s]), key=int))))
            w("")

    w("## Rows with no playable class")
    w("Auras whose spell has no playable class set (items, races, professions, encounters, removed content). IDs and names only.")
    w("")
    w("| Aura ID | Aura | Screen art | Overlay row |")
    w("|---|---|---|---|")
    for e in sorted(other, key=lambda e: int(e["aura"])):
        w("| %s | %s | %s | %s |" % (e["aura"], nm(e["aura"]), "yes" if e["art"] else "no", e["row"]))
    w("")
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    print("wrote", a.out, "rows", total)


if __name__ == "__main__":
    sys.exit(main())
