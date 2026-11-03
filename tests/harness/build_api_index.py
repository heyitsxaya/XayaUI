# Builds api_index.json (NOT committed: it is derived from Blizzard's documentation) from the in-client API documentation
# dump kept in Xaya's Drive folder "Blizzard API Data" (build 12.1.5.70688): documented global and namespaced functions,
# events with their payload names, enums, and widget methods. The harness uses it to (1) give every documented function a
# stand-in, (2) reject widget methods the game does not have, and (3) list every game name XayaUI touches that the
# documentation does not cover, for review.
# Usage: python3 build_api_index.py "<folder with WOW-API-FULL-*.txt>" [out.json]
import glob, json, re
import lupa.lua51 as l51
L = l51.LuaRuntime(unpack_returned_tuples=True)
L.execute("local function auto() return setmetatable({}, {__index = function(t, k) local v = setmetatable({}, {__index = function() return 0 end}); rawset(t, k, v); return v end}) end; Enum = auto(); Constants = auto(); DOCS = {}; APIDocumentation = { AddDocumentationTable = function(self, t) DOCS[#DOCS+1] = t end }")
import os, sys
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
n = L.eval("#DOCS")
for i in range(1, n + 1):
    t = L.eval("DOCS[%d]" % i)
    ns = t["Namespace"]; typ = t["Type"]; nm = t["Name"]
    for f in (t["Functions"] or {}).values():
        args = [a["Name"] for a in (f["Arguments"] or {}).values()]
        rets = [r["Name"] for r in (f["Returns"] or {}).values()]
        if typ == "ScriptObject":
            idx["widgets"].setdefault(nm, []).append(f["Name"])
        else:
            key = (ns + "." if ns else "") + f["Name"]
            idx["functions"][key] = {"args": args, "returns": rets}
    for e in (t["Events"] or {}).values():
        idx["events"][e["LiteralName"]] = [p["Name"] for p in (e["Payload"] or {}).values()]
    for tb in (t["Tables"] or {}).values():
        if tb["Type"] == "Enumeration":
            idx["enums"][tb["Name"]] = [f["Name"] for f in (tb["Fields"] or {}).values()]
json.dump(idx, open(OUT, "w"), indent=0)
print(nfiles, "files;", len(bad), "unparsed;", {k: len(v) for k, v in idx.items()})
print(bad[:5])
