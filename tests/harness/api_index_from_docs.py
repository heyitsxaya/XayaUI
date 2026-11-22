#!/usr/bin/env python3
"""Builds the harness's api_index.json from the repository's own docs/reference/api/api.json (Blizzard's generated API
documentation 12.1.5.70688, the same documentation build_api_index.py reads from the raw dump in Xaya's Drive folder). For cloud
sessions, where that Drive folder is not reachable: without an index the harness runs with "API documentation: NOT LOADED" and
checks no widget method or event. The output is derived data: write it outside the repository (or leave it uncommitted).
Same shape as build_api_index.py: functions {name: {args, returns}}, events {name: [payload names]}, enums {name: [fields]},
widgets {script object: [methods]}, tables [].
Secrecy (round 11b, SD-120; the hidden-data fight build spec, section 3.1, S.guard): "secrecy" carries the flags the stand-in needs to
treat hidden values as the game does, read from api.json's flags (never from widgets.md, which keeps one entry per method name and so
shows the Slider's SetValue flag for StatusBar too):
  secrecy.functions[name]          = [flags]   every function with a secrecy flag (see SECRECY_FLAG)
  secrecy.widgets["Object:Method"] = [flags]   per script-object type (SimpleStatusBarAPI:SetValue and SimpleSliderAPI:SetValue differ)
  secrecy.events[name]             = [flags]
  secrecy.argTypes[name or "Object:Method"] = [declared argument types]   for every SecretArguments=AllowedWhenTainted entry: a hidden
                                     string in a number parameter still errors there (patch 12.0.0 notes)
A flag keeps api.json's spelling ("SecretArguments=AllowedWhenTainted", "SecretWhenCooldownsRestricted"). build_api_index.py builds the
same section from the raw documentation dump through secrecy_section() below.
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


# A flag about hidden (secret) values or forbidden access: its name (before "=") holds "Secret", "Forbidden" or "Declassified", or it
# reads Requires...Access (RequiresUnitAuraAccess, RequiresFontStringTextAccess ...), or it is RequiresComparableUnitTokens.
SECRECY_FLAG = re.compile(r"^(?:[A-Za-z]*(?:Secret|Forbidden|Declassified)[A-Za-z]*|Requires[A-Za-z]*Access|RequiresComparableUnitTokens)(?:=|$)")


def arg_types(sig):
    """'SetValue(value: number, interpolation: StatusBarInterpolation = "Immediate")' -> ['number', 'StatusBarInterpolation']."""
    inner = sig[sig.find("(") + 1: sig.rfind(")")] if "(" in sig else ""
    out, depth, cur = [], 0, ""
    for ch in inner:
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
        m = re.match(r"\s*[A-Za-z_][A-Za-z0-9_]*\s*:\s*(.+?)\s*(?:=.*)?$", part)
        if m:
            res.append(m.group(1))
    return res


def secrecy_section(records):
    """records: (kind, name, flags, argTypes) with kind "functions" | "widgets" | "events", flags spelled as api.json spells them.
    Returns the index's "secrecy" section (see the module docstring)."""
    sec = {"functions": {}, "widgets": {}, "events": {}, "argTypes": {}}
    for kind, name, flags, types in records:
        keep = sorted(f for f in flags if SECRECY_FLAG.match(f))
        if not keep:
            continue
        sec[kind][name] = keep
        if kind != "events" and "SecretArguments=AllowedWhenTainted" in keep:
            sec["argTypes"][name] = list(types)
    return sec


def records_from_api_json(docs):
    """api.json's docs -> secrecy records (functions by full name, widget methods as "Object:Method", events)."""
    for name, f in docs["functions"].items():
        yield "functions", name, f.get("flags", []), arg_types(f.get("sig", ""))
    for method, entries in docs["widgetMethods"].items():
        for ent in entries:
            if ent.get("object"):
                yield "widgets", ent["object"] + ":" + method, ent.get("flags", []), arg_types(ent.get("sig", ""))
    for name, e in docs["events"].items():
        yield "events", name, (e.get("flags", []) if isinstance(e, dict) else []), []


def main():
    docs = json.load(open(SRC, encoding="utf-8"))["docs"]
    idx = {"functions": {}, "events": {}, "enums": {}, "widgets": {}, "tables": []}
    for name, f in docs["functions"].items():
        sig = f.get("sig", "")
        inner = sig[sig.find("(") + 1: sig.rfind(")")] if "(" in sig else ""
        idx["functions"][name] = {"args": names(inner), "returns": names(f.get("returns", ""))}
    for name, e in docs["events"].items():
        idx["events"][name] = names(e.get("payload", ""))
    # Enums keep their real values ({field: value}, ordered by value). api.json lists each enum's fields alphabetically, and world.lua
    # numbers a plain list by position, so a list here gave 741 of 856 enums the wrong numbers (Enum.SecrecyLevel.NeverSecret = 2, not 0).
    for name, fields in docs["enums"].items():
        if isinstance(fields, dict) and all(isinstance(v, (int, float)) for v in fields.values()):
            idx["enums"][name] = dict(sorted(fields.items(), key=lambda kv: kv[1]))
        else:
            idx["enums"][name] = list(fields.keys()) if isinstance(fields, dict) else list(fields)
    for method, entries in docs["widgetMethods"].items():
        for ent in entries:
            obj = ent.get("object")
            if obj:
                lst = idx["widgets"].setdefault(obj, [])
                if method not in lst:
                    lst.append(method)
    idx["secrecy"] = secrecy_section(records_from_api_json(docs))
    json.dump(idx, open(OUT, "w"), indent=0)
    print(OUT, {k: len(v) for k, v in idx.items()}, {k: len(v) for k, v in idx["secrecy"].items()})


if __name__ == "__main__":
    main()
