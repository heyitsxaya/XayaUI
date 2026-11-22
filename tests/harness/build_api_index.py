# Builds api_index.json (NOT committed: it is derived from Blizzard's documentation) from the in-client API documentation
# dump kept in Xaya's Drive folder "Blizzard API Data" (build 12.1.5.70688): documented global and namespaced functions,
# events with their payload names, enums, and widget methods. The harness uses it to (1) give every documented function a
# stand-in, (2) reject widget methods the game does not have, and (3) list every game name XayaUI touches that the
# documentation does not cover, for review.
# (round 11b, SD-120) It also writes the "secrecy" section (the flags the stand-in needs for hidden values; layout in
# api_index_from_docs.py, whose secrecy_section() both builders share): every documentation field that is not a name, type, argument
# list, return list, payload or note becomes a flag spelled as api.json spells it ("SecretArguments=AllowedWhenTainted",
# "SecretWhenCooldownsRestricted"). Limit: this dump's loader reads every Enum value as 0, so a list-valued flag reads
# "SecretArgumentsAddAspect=[0]" here where api.json names the aspect; the stand-in reads only the flag names.
# Usage: python3 build_api_index.py "<folder with WOW-API-FULL-*.txt>" [out.json]
import glob, json, re
import lupa.lua51 as l51
L = l51.LuaRuntime(unpack_returned_tuples=True)
L.execute("local function auto() return setmetatable({}, {__index = function(t, k) local v = setmetatable({}, {__index = function() return 0 end}); rawset(t, k, v); return v end}) end; Enum = auto(); Constants = auto(); DOCS = {}; APIDocumentation = { AddDocumentationTable = function(self, t) DOCS[#DOCS+1] = t end }")
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from api_index_from_docs import secrecy_section  # noqa: E402  (the shared layout of the "secrecy" section)
SRC = (sys.argv[1] if len(sys.argv) > 1 else os.environ.get("XUI_API_DOCS", "")).rstrip("/") + "/"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "api_index.json")
nfiles = 0; bad = []
for p in sorted(glob.glob(SRC + "WOW-API-FULL-*.txt")):
    text = open(p, encoding="utf-8", errors="replace").read()
    for chunk in re.split(r"(?m)^-- ===== FILE: ", text)[1:]:
        name, _, body = chunk.partition("\n")
        nfiles += 1
        try:
            L.execute(body)
        except Exception as e:
            bad.append((name.strip(), str(e)[:100]))
idx = {"functions": {}, "events": {}, "enums": {}, "widgets": {}, "tables": []}
# the fields that are not flags (the same list docs/reference/build_reference.py uses to write api.json's flags)
BASIC = {"Name", "Type", "Arguments", "Returns", "Documentation", "Payload", "LiteralName", "Fields"}


def doc_flags(entry):
    """A documentation entry's flags, spelled as api.json spells them: a true field by its name, any other field as name=value."""
    out = []
    for k in sorted(str(x) for x in entry.keys()):
        if k in BASIC:
            continue
        v = entry[k]
        if l51.lua_type(v) == "table":
            v = "[" + ", ".join(str(x) for x in v.values()) + "]"
        out.append(k if v is True else "%s=%s" % (k, v))
    return out


def doc_arg_type(a):
    """An argument's declared type as api.json's signature writes it ("table<number>", "ItemLocation (ItemLocationMixin)?")."""
    t = str(a["Type"] or "?")
    if a["InnerType"]:
        t += "<%s>" % a["InnerType"]
    if a["Mixin"]:
        t += " (%s)" % a["Mixin"]
    if a["Nilable"]:
        t += "?"
    return t


secret_records = []
n = L.eval("#DOCS")
for i in range(1, n + 1):
    t = L.eval("DOCS[%d]" % i)
    ns = t["Namespace"]; typ = t["Type"]; nm = t["Name"]
    for f in (t["Functions"] or {}).values():
        args = [a["Name"] for a in (f["Arguments"] or {}).values()]
        rets = [r["Name"] for r in (f["Returns"] or {}).values()]
        types = [doc_arg_type(a) for a in (f["Arguments"] or {}).values()]
        if typ == "ScriptObject":
            idx["widgets"].setdefault(nm, []).append(f["Name"])
            secret_records.append(("widgets", "%s:%s" % (nm, f["Name"]), doc_flags(f), types))
        else:
            key = (ns + "." if ns else "") + f["Name"]
            idx["functions"][key] = {"args": args, "returns": rets}
            secret_records.append(("functions", key, doc_flags(f), types))
    for e in (t["Events"] or {}).values():
        idx["events"][e["LiteralName"]] = [p["Name"] for p in (e["Payload"] or {}).values()]
        secret_records.append(("events", e["LiteralName"], doc_flags(e), []))
    for tb in (t["Tables"] or {}).values():
        if tb["Type"] == "Enumeration":
            idx["enums"][tb["Name"]] = [f["Name"] for f in (tb["Fields"] or {}).values()]
idx["secrecy"] = secrecy_section(secret_records)
json.dump(idx, open(OUT, "w"), indent=0)
print(nfiles, "files;", len(bad), "unparsed;", {k: len(v) for k, v in idx.items()})
print(bad[:5])
