#!/usr/bin/env python3
"""Builds the harness's api_index.json from the repository's own docs/reference/api/api.json (Blizzard's generated API
documentation 12.1.5.70688, the same documentation build_api_index.py reads from the raw dump in Xaya's Drive folder). For cloud
sessions, where that Drive folder is not reachable: without an index the harness runs with "API documentation: NOT LOADED" and
checks no widget method or event. The output is derived data: write it outside the repository (or leave it uncommitted).
Same shape as build_api_index.py: functions {name: {args, returns}}, events {name: [payload names]}, enums {name: [fields]},
widgets {script object: [methods]}, tables []; plus enumValues {name: {field: value}} (2026-11-06: the stand-in numbered an enum's
fields by their place in the list, and api.json lists them alphabetically, so 741 of 856 enums had wrong numbers in cloud runs, e.g.
Enum.SecrecyLevel.NeverSecret = 2 instead of 0; enums is now ordered by value and world.lua reads enumValues when it is there).
Usage: python3 tests/harness/api_index_from_docs.py [out.json]   then   XUI_API_INDEX=out.json python3 tests/run_all.py"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "..", "docs", "reference", "api", "api.json")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "api_index.json")


def names(spec):
    """'a: t, b: t?' -> ['a', 'b'] (types may hold commas inside brackets)."""
    out, depth, cur = [], 0, ""
    for ch in spec or "":
        if ch in "([{<":
            depth += 1
        elif ch in ")]}>":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur); cur = ""
        else:
            cur += ch
    out.append(cur)
    res = []
    for part in out:
        m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*:", part)
        if m:
            res.append(m.group(1))
    return res


docs = json.load(open(SRC, encoding="utf-8"))["docs"]
idx = {"functions": {}, "events": {}, "enums": {}, "enumValues": {}, "widgets": {}, "tables": []}
for name, f in docs["functions"].items():
    sig = f.get("sig", "")
    inner = sig[sig.find("(") + 1: sig.rfind(")")] if "(" in sig else ""
    idx["functions"][name] = {"args": names(inner), "returns": names(f.get("returns", ""))}
for name, e in docs["events"].items():
    idx["events"][name] = names(e.get("payload", ""))
for name, fields in docs["enums"].items():
    if isinstance(fields, dict):   # {field: value}: listed in value order, and the values themselves kept
        idx["enums"][name] = sorted(fields, key=lambda f: (fields[f], f))
        idx["enumValues"][name] = dict(fields)
    else:
        idx["enums"][name] = list(fields)
for method, entries in docs["widgetMethods"].items():
    for ent in entries:
        obj = ent.get("object")
        if obj:
            lst = idx["widgets"].setdefault(obj, [])
            if method not in lst:
                lst.append(method)
json.dump(idx, open(OUT, "w"), indent=0)
print(OUT, {k: len(v) for k, v in idx.items()})
