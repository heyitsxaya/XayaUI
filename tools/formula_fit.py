#!/usr/bin/env python3
"""Fit spell numbers observed in game (XayaUI Dev Assist /xuiformula snapshots; the addon was XayaUI_GameDump before 0.7.0) against the stats recorded with them.

Usage:
  python3 tools/formula_fit.py PATH/TO/SavedVariables/XayaUI_DevAssist.lua           -> writes formula-report.md next to this script's output dir
  (a file saved before the rename, XayaUI_GameDump.lua, works the same)
  python3 tools/formula_fit.py SAVED.lua --emit                                     -> also writes XayaUI_SpellData_<CLASS>/ addon folders (load on demand)
  python3 tools/formula_fit.py SAVED.lua --out DIR                                  -> where report and folders go (default: the repository root)

Nothing here is mined: the input is only what the addon API reported in game. For each loadout (class + spec + talent set), each spell,
and each number in its description, it tries   y = a*X + b   and   y = (a*X + b) * (1 + versatility/100)   for every stat X that was
recorded, and keeps a fit only when it reproduces EVERY observation within the game's own rounding. It needs 3+ distinct values of X.
A fitted "a" holds every multiplier that stayed constant while gear changed (spec passives, talents): it is valid for that loadout.
Needs: pip install lupa (Lua 5.1, the same runtime the tests use).
"""
import argparse, os, re, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(ROOT, "tests"))

SCHOOLS = {"physical": 1, "holy": 2, "fire": 3, "nature": 4, "frost": 5, "shadow": 6, "arcane": 7}
# candidate stats, in order of preference when two fit equally well (attack power before agility, which can track it exactly)
CANDIDATES = ["ap", "sp", "heal", "primary", "hp", "weapon", "mastery", "haste", "crit", "vers"]
LABEL = {"ap": "attack power", "sp": "spell power", "heal": "healing power", "primary": "primary stat", "hp": "maximum health",
         "weapon": "weapon damage", "mastery": "mastery %", "haste": "haste %", "crit": "crit %", "vers": "versatility %"}


def to_py(v):
    """lupa table -> dict / list (1..n keys become a list)"""
    try:
        from lupa import lua51  # noqa: F401
    except Exception:
        pass
    if hasattr(v, "items") and not isinstance(v, (str, bytes, dict)):
        d = {k: to_py(x) for k, x in v.items()}
        if d and all(isinstance(k, int) for k in d) and sorted(d) == list(range(1, len(d) + 1)):
            return [d[i] for i in range(1, len(d) + 1)]
        return d
    return v


def load_saved(path):
    from lua51 import runtime
    L = runtime(unpack_returned_tuples=True)
    L.execute(open(path, encoding="utf-8", errors="replace").read())
    db = L.eval("XayaUIDevAssistDB or XayaUIGameDumpDB")   # (XayaUIGameDumpDB: the saved table's name before the 0.7.0 rename)
    if db is None:
        raise SystemExit("no XayaUIDevAssistDB (or XayaUIGameDumpDB) in " + path)
    f = to_py(db).get("formula")
    if not isinstance(f, dict) or not isinstance(f.get("loadouts"), dict):
        raise SystemExit("no formula snapshots in " + path + " (run /xuiformula start in game, then /reload)")
    return f


def stat_value(stats, key, school):
    if key == "ap": return stats.get("ap")
    if key == "sp":
        sp = stats.get("sp") or {}
        if isinstance(sp, list): sp = {i + 1: x for i, x in enumerate(sp)}
        return sp.get(school or 1)
    if key == "primary": return max(stats.get("str", 0), stats.get("agi", 0), stats.get("int", 0))
    if key == "weapon":
        lo, hi = stats.get("wlo"), stats.get("whi")
        return (lo + hi) / 2 if lo is not None and hi is not None else None
    return stats.get(key)


def lsq(xs, ys):
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    if sxx == 0: return None
    a = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx
    return a, my - a * mx


def within_rounding(pred, y):
    # the game prints whole numbers for large values and one decimal for small ones: allow half a unit, or 0.2% for big numbers
    return abs(pred - y) <= max(0.51 if y >= 10 else 0.051, abs(y) * 0.002)


def try_fit(points, key, school):
    """points: [(stats, y)] -> best fit dict or None"""
    rows = [(stat_value(s, key, school), s.get("vers") or 0.0, y) for s, y in points]
    rows = [r for r in rows if r[0] is not None]
    if len({r[0] for r in rows}) < 3: return None
    best = None
    for vers in (False, True):
        xs = [r[0] for r in rows]
        ys = [r[2] / (1 + r[1] / 100) if vers else r[2] for r in rows]
        f = lsq(xs, ys)
        if not f: continue
        a, b = f
        if abs(b) < max(0.5, 0.001 * max(abs(y) for y in ys)): b = 0.0
        def ok(a_, b_):
            return all(within_rounding((a_ * r[0] + b_) * ((1 + r[1] / 100) if vers else 1), r[2]) for r in rows)
        if not ok(a, b): continue
        # the game prints rounded numbers, so the least-squares slope is a little off (0.5196 for 0.52): report the simplest
        # coefficient, fewest decimals first, that still reproduces every observation
        for d in range(1, 7):
            ar, br = round(a, d), (round(b) if b else 0.0)
            if ok(ar, br):
                a, b = ar, br
                break
        preds = [(a * r[0] + b) * ((1 + r[1] / 100) if vers else 1) for r in rows]
        if True:
            err = max(abs(p - r[2]) for p, r in zip(preds, rows))
            cand = {"x": key, "a": a, "b": b, "vers": vers, "n": len(rows), "err": err,
                    "versTested": len({(r[0], round(r[1], 2)) for r in rows}) > len({r[0] for r in rows})}
            if best is None or err < best["err"] - 1e-9: best = cand
    if best and not best["versTested"]:
        best["vers"] = None   # versatility never changed at a fixed power: whether the number includes it is unknown
    return best


def label_for(tpl, idx):
    """the words after the idx-th '#' in the template, e.g. 'Physical damage'"""
    parts = tpl.split("#")
    if idx + 1 >= len(parts): return ""
    out = []
    for w in re.findall(r"[A-Za-z]+", parts[idx + 1])[:3]:
        out.append(w)
        if w.lower() in ("damage", "healing", "health", "absorb", "absorbs"): break
    return " ".join(out)


def school_for(label):
    w = label.split()[:1]
    return SCHOOLS.get(w[0].lower()) if w else None


def fit_loadout(L):
    snaps = L.get("snaps") or []
    spells = L.get("spells") or {}
    out = {}
    for sid, sp in spells.items():
        tpl = sp.get("tpl") or ""
        series = defaultdict(list)
        cds = []
        for sn in snaps:
            r = (sn.get("v") or {}).get(sid)
            if not r or r.get("t"): continue
            for i, y in enumerate(r.get("n") or []):
                series[i].append((sn["stats"], y))
            if r.get("cd") is not None and r.get("rate") is not None:
                cds.append((sn["stats"].get("haste"), r["cd"], r["rate"]))
        entry = {"name": sp.get("name"), "nums": [], "cd": None}
        for i, pts in sorted(series.items()):
            ys = [y for _, y in pts]
            label = label_for(tpl, i)
            if len(set(ys)) == 1:
                continue   # never moved (radius, duration, a fixed count): not a formula
            school = school_for(label)
            fit = None
            for key in CANDIDATES:
                fit = try_fit(pts, key, school)
                if fit: break
            entry["nums"].append({"i": i + 1, "label": label, "fit": fit, "n": len(pts),
                                  "levels": len({stat_value(s, 'ap', None) for s, _ in pts})})
        if cds:
            hastes = {round(h or 0, 2) for h, _, _ in cds}
            matches = all(h is not None and abs(rate - (1 + h / 100)) < 0.01 for h, _, rate in cds)
            entry["cd"] = {"d": cds[0][1], "haste": (matches if len(hastes) >= 2 else None), "n": len(cds)}
        if entry["nums"] or entry["cd"]:
            out[sid] = entry
    return out


def fmt_fit(f):
    if not f: return "no fit"
    s = f"{f['a']:g} × {LABEL[f['x']]}"
    if f["b"]: s += f" {'+' if f['b'] > 0 else '-'} {abs(f['b']):.1f}"
    if f["vers"] is True: s += ", × (1 + versatility)"
    elif f["vers"] is None: s += " (versatility not tested)"
    return s


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def emit_class(out_dir, cls, build, specs):
    folder = os.path.join(out_dir, f"XayaUI_SpellData_{cls}")
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, f"XayaUI_SpellData_{cls}.toc"), "w", newline="\n") as t:
        t.write("## Interface: 120100, 120105\n")
        t.write(f"## Title: XayaUI Spell Data ({cls})\n")
        t.write("## Notes: Spell formulas observed in game with /xuiformula (XayaUI Dev Assist) and fitted by tools/formula_fit.py. Loaded by XayaUI Bonus Features for your own class only.\n")
        t.write("## Author: Xaya\n## Group: XayaUI\n## LoadOnDemand: 1\n## Dependencies: XayaUI_Bonus\n\nData.lua\n")
    lines = ["-- Generated by tools/formula_fit.py from in-game observations. Do not edit by hand; re-run the walkthrough instead.",
             "XayaUI_SpellData = XayaUI_SpellData or {}",
             f"XayaUI_SpellData[{lua_str(cls)}] = {{ build = {lua_str(build)}, specs = {{"]
    for spec, by_spell in sorted(specs.items()):
        lines.append(f"  [{spec}] = {{")
        for sid, rows in sorted(by_spell.items()):
            parts = []
            for r in rows:
                f = r["fit"]
                v = "true" if f["vers"] is True else ("false" if f["vers"] is False else "nil")
                parts.append(f"{{ i = {r['i']}, x = {lua_str(f['x'])}, a = {f['a']:.6f}, b = {f['b']:.3f}, vers = {v}, n = {f['n']}, "
                             f"label = {lua_str(r['label'])}, tal = {lua_str(r['tal'])} }}")
            lines.append(f"    [{sid}] = {{ " + ", ".join(parts) + " },")
        lines.append("  },")
    lines.append("} }")
    with open(os.path.join(folder, "Data.lua"), "w", newline="\n") as d:
        d.write("\n".join(lines) + "\n")
    return folder


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("saved")
    ap.add_argument("--emit", action="store_true")
    ap.add_argument("--out", default=ROOT)
    a = ap.parse_args(argv)
    f = load_saved(a.saved)
    report = ["# Observed spell formulas", "", f"Source: `{os.path.basename(a.saved)}`. Fits are exact to the game's rounding on every observation.", ""]
    by_class = defaultdict(lambda: {"build": None, "specs": defaultdict(lambda: defaultdict(list))})
    for key, L in sorted(f["loadouts"].items()):
        snaps = L.get("snaps") or []
        res = fit_loadout(L)
        report += [f"## {L.get('specName')} {L.get('class')} (talents {L.get('hash')}), {len(snaps)} snapshots", "",
                   "| Spell | Number | Formula | Samples |", "|---|---|---|---|"]
        for sid, e in sorted(res.items()):
            for r in e["nums"]:
                report.append(f"| {e['name']} ({sid}) | #{r['i']} {r['label']} | {fmt_fit(r['fit'])} | {r['n']} |")
                if r["fit"]:
                    c = by_class[L.get("class")]
                    c["build"] = L.get("build")
                    c["specs"][L.get("specID")][sid].append(dict(r, tal=L.get("hash")))
            if e["cd"]:
                h = {True: "scales with haste", False: "does not scale with haste", None: "haste not varied"}[e["cd"]["haste"]]
                report.append(f"| {e['name']} ({sid}) | cooldown | {e['cd']['d']} s, {h} | {e['cd']['n']} |")
        report.append("")
    os.makedirs(a.out, exist_ok=True)
    rp = os.path.join(a.out, "formula-report.md")
    open(rp, "w", newline="\n").write("\n".join(report) + "\n")
    print("report:", rp)
    if a.emit:
        for cls, c in by_class.items():
            print("data addon:", emit_class(a.out, cls, c["build"], c["specs"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
