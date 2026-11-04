# Builds XayaUI's two reference sets from a XayaUI Game Data Capture file and Blizzard's generated API documentation:
#   api/     everything that exists in the live client (/xuidump api), each name joined with its documented signature, flags
#            and notes where Blizzard documents it; events, structures and enums from the documentation
#   spells/  every class, spec, hero tree and talent node of the all-class scan (/xuidump static), with each spell's text,
#            cast time, base cooldown, charges and aura secrecy, plus tier sets and their bonus spells
# Only the game-data parts of the capture are read: .api and .static. The character, aura and recorder parts (.char, .auras,
# .rec, .toolkitProbe) are personal and are never written out.
#
# Usage: python3 docs/reference/build_reference.py --saved <XayaUI_DevAssist.lua, or XayaUI_GameDump.lua from before 0.7.0> --docs <Blizzard_APIDocumentationGenerated dir> --out <dir>
# Needs: pip install lupa. The SavedVariables file is run as DATA only (compiled, run with an empty environment).
import argparse, json, os, re, glob, collections
import lupa.lua51 as l51

ap = argparse.ArgumentParser()
ap.add_argument("--saved", required=True)
ap.add_argument("--docs", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--public", action="store_true", help="facts only, for the public repo: no written text (spell descriptions, hero-tree blurbs, Blizzard's documentation notes) and no undocumented globals or numeric globals (those also hold every loaded addon's names)")
args = ap.parse_args()

L = l51.LuaRuntime(unpack_returned_tuples=True)

def to_py(v):
    if l51.lua_type(v) == "table":
        if v["__enumname"] is not None:   # a named Enum value (see the documentation loader below)
            return str(v["__enumname"])
        keys = list(v.keys())
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [to_py(v[k]) for k in sorted(keys)]
        return {str(k): to_py(v[k]) for k in keys}
    return v

# ---- 1. the capture, as data ------------------------------------------------------------------------------------------------
load = L.eval('''function(src)
  local f, err = loadstring(src, "savedvars")
  if not f then return nil, err end
  local env = {}
  setfenv(f, env)
  local ok, e = pcall(f)
  if not ok then return nil, e end
  return env.XayaUIDevAssistDB or env.XayaUIGameDumpDB   -- (the name before the 0.7.0 rename)
end''')
r = load(open(args.saved, encoding="utf-8", errors="replace").read())
db_lua = r[0] if isinstance(r, tuple) else r
if db_lua is None:
    raise SystemExit("could not read the capture: %s" % (r[1] if isinstance(r, tuple) else "?"))
api = to_py(db_lua["api"]) if db_lua["api"] else None
static = to_py(db_lua["static"]) if db_lua["static"] else None

# ---- 2. Blizzard's generated documentation ----------------------------------------------------------------------------------
# Enum values the documentation names (SecretReturnsForAspect = { Enum.SecretAspect.Cooldown }) keep their names: a value read from
# Enum is a marker holding "SecretAspect.Cooldown", and arithmetic on markers keeps the names ("A + B"); to_py turns a marker into
# its text. Before, every Enum value read 0 and the reference printed "[0]". Constants stay numbers.
L.execute(r"""
local EV = {}
local function mk(name) return setmetatable({ __enumname = name }, EV) end
local function nm(x) if type(x) == "table" and x.__enumname then return x.__enumname end return tostring(x) end
EV.__tostring = function(t) return t.__enumname end
for op, sym in pairs({ __add = " + ", __sub = " - ", __mul = " * ", __div = " / ", __mod = " % ", __pow = " ^ " }) do
  EV[op] = function(a, b) return mk(nm(a) .. sym .. nm(b)) end
end
EV.__unm = function(a) return mk("-" .. nm(a)) end
local function auto(named) return setmetatable({}, {__index = function(t, k)
  local v = setmetatable({}, {__index = function(_, f) if named then return mk(k .. "." .. tostring(f)) end return 0 end})
  rawset(t, k, v); return v end}) end
Enum = auto(true); Constants = auto(false); DOCS = {}
APIDocumentation = { AddDocumentationTable = function(self, t) DOCS[#DOCS+1] = t end }
""")
bad = []
docfiles = sorted(glob.glob(os.path.join(args.docs, "*.lua")))
for p in docfiles:
    try:
        L.execute(open(p, encoding="utf-8", errors="replace").read())
    except Exception as e:
        bad.append((os.path.basename(p), str(e)[:80]))
docs = to_py(L.eval("DOCS")) or []
build_txt = ""
vt = os.path.join(args.docs, "..", "..", "..", "version.txt")
if os.path.exists(vt):
    build_txt = open(vt).read().strip()

BASIC = {"Name", "Type", "Arguments", "Returns", "Documentation", "Payload", "LiteralName", "Fields"}
def lst(x): return x if isinstance(x, list) else (list(x.values()) if isinstance(x, dict) else [])
def ftype(a):
    t = a.get("Type", "?")
    if a.get("InnerType"): t += "<%s>" % a["InnerType"]
    if a.get("Mixin"): t += " (%s)" % a["Mixin"]
    return t
def param(a):
    s = "%s: %s" % (a.get("Name", "?"), ftype(a))
    if a.get("Nilable"): s += "?"
    if "Default" in a: s += " = %s" % json.dumps(a["Default"])
    return s
def flags(d):
    out = []
    for k in sorted(d):
        if k in BASIC: continue
        v = d[k]
        if isinstance(v, list): v = "[" + ", ".join(str(x) for x in v) + "]"
        out.append(k if v is True else "%s=%s" % (k, v))
    return out
def docline(d):
    if args.public: return ""
    ds = lst(d.get("Documentation"))
    return " ".join(str(x) for x in ds).strip()

dfun, devents, dstruct, denums, dwidget = {}, {}, {}, {}, {}
for t in docs:
    ns, typ, nm = t.get("Namespace"), t.get("Type"), t.get("Name")
    for f in lst(t.get("Functions")):
        entry = {"sig": "%s(%s)" % (f.get("Name"), ", ".join(param(a) for a in lst(f.get("Arguments")))),
                 "returns": ", ".join(param(a) for a in lst(f.get("Returns"))), "flags": flags(f), "doc": docline(f), "system": nm}
        if typ == "ScriptObject":
            dwidget.setdefault(f.get("Name"), []).append(dict(entry, object=nm))
        else:
            dfun[(ns + "." if ns else "") + f.get("Name")] = entry
    for e in lst(t.get("Events")):
        devents[e.get("LiteralName")] = {"payload": ", ".join(param(a) for a in lst(e.get("Payload"))), "flags": flags(e), "doc": docline(e), "system": nm}
    for tb in lst(t.get("Tables")):
        if tb.get("Type") == "Enumeration":
            denums[tb.get("Name")] = {f.get("Name"): f.get("EnumValue") for f in lst(tb.get("Fields"))}
        elif tb.get("Type") in ("Structure", "CallbackType", "Constants"):
            dstruct[tb.get("Name")] = {"type": tb.get("Type"), "fields": [dict(param=param(f), flags=flags(f), doc=docline(f)) for f in lst(tb.get("Fields")) or lst(tb.get("Values"))], "system": nm}

def md_sig(name, d):
    s = "`%s%s`" % (name.rsplit(".", 1)[0] + "." if "." in name else "", d["sig"])
    if d["returns"]: s += " → `%s`" % d["returns"]
    if d["flags"]: s += " · " + ", ".join(d["flags"])
    if d["doc"]: s += " · " + d["doc"]
    return s

os.makedirs(args.out, exist_ok=True)
W = lambda rel, text: (os.makedirs(os.path.dirname(os.path.join(args.out, rel)), exist_ok=True), open(os.path.join(args.out, rel), "w", encoding="utf-8").write(text))

# ---- 3. API reference -------------------------------------------------------------------------------------------------------
if api:
    b = api.get("build", {})
    live_ns = api.get("namespaces", {})
    live_glob = api.get("globals", [])
    counts = api.get("counts", {})
    doc_ns_funcs = collections.defaultdict(set)
    for k in dfun:
        if "." in k:
            n, f = k.split(".", 1); doc_ns_funcs[n].add(f)
    documented_live = sum(1 for n, fs in live_ns.items() for f in fs if (n + "." + f) in dfun)
    documented_glob = sum(1 for g in live_glob if g in dfun)
    head = ("Captured in the live client by XayaUI Game Data Capture (`/xuidump api`): build %s (%s), interface %s, captured %s (local time).\n"
            "Signatures, flags and notes come from Blizzard's generated API documentation%s. Where the client is newer than the documentation, a name can exist without a documented signature.\n\n"
            % (b.get("version"), b.get("build"), b.get("toc"), api.get("at"), (" (" + build_txt + ")") if build_txt else ""))
    # namespaces
    out = ["# C_ namespaces in the live client\n", head]
    for n in sorted(live_ns):
        fs = live_ns[n]
        nd = sum(1 for f in fs if (n + "." + f) in dfun)
        out.append("\n## %s (%d functions, %d documented)\n" % (n, len(fs), nd))
        for f in fs:
            k = n + "." + f
            out.append("- " + (md_sig(k, dfun[k]) if k in dfun else "`%s.%s` · not in the generated documentation" % (n, f)))
        gone = sorted(doc_ns_funcs.get(n, set()) - set(fs))
        if gone:
            out.append("- Documented but not present in this client: " + ", ".join("`%s`" % g for g in gone))
    missing_ns = sorted(set(doc_ns_funcs) - set(live_ns))
    if missing_ns:
        out.append("\n## Documented namespaces not present in this client\n")
        for n in missing_ns: out.append("- `%s` (%d documented functions)" % (n, len(doc_ns_funcs[n])))
    W("api/namespaces.md", "\n".join(out) + "\n")
    # globals
    out = ["# Global functions in the live client\n", head,
           "This list holds every function in the global table at capture time: the game's own functions, Blizzard's UI code, AND every loaded addon's globals. A capture with only XayaUI Game Data Capture enabled gives the game-and-Blizzard-UI list alone.\n"]
    letter = None
    shown_glob = [g for g in live_glob if (not args.public) or g in dfun]
    if args.public:
        out.append("PUBLIC VERSION: only the %d globals Blizzard documents are listed. The full list (%d names) also holds every loaded addon's globals, so it stays in the private copy until a capture is made with only XayaUI Game Data Capture enabled.\n" % (len(shown_glob), len(live_glob)))
    for g in shown_glob:
        L0 = g[0].upper()
        if L0 != letter:
            letter = L0; out.append("\n## %s\n" % letter)
        out.append("- " + (md_sig(g, dfun[g]) if g in dfun else "`%s`" % g))
    W("api/globals.md", "\n".join(out) + "\n")
    # enums
    out = ["# Enums in the live client\n", head]
    for n in sorted(api.get("enums", {})):
        vals = api["enums"][n]
        out.append("\n## Enum.%s (%d)%s\n" % (n, len(vals), "" if n in denums else " · not in the generated documentation"))
        for k, v in sorted(vals.items(), key=lambda kv: (kv[1] if isinstance(kv[1], (int, float)) else 0, kv[0])):
            out.append("- `%s` = %s" % (k, v))
    W("api/enums.md", "\n".join(out) + "\n")
    # constants
    out = ["# Constants in the live client\n", head, "\n## Constants tables\n"]
    def walk(prefix, v, depth=0):
        if isinstance(v, dict):
            for k in sorted(v): walk(prefix + "." + k, v[k], depth + 1)
        elif isinstance(v, list):
            for i, x in enumerate(v, 1): walk("%s[%d]" % (prefix, i), x, depth + 1)
        else:
            out.append("- `%s` = %s" % (prefix, json.dumps(v)))
    for n in sorted(api.get("constants", {})): walk("Constants." + n, api["constants"][n])
    out.append("\n## Numeric globals (ALL-CAPS names)\n")
    if args.public:
        out.append("PUBLIC VERSION: held back (they include every loaded addon's constants); in the private copy. The rating indices XayaUI uses: " + ", ".join("`%s` = %s" % (k, api.get("numbers", {}).get(k)) for k in sorted(api.get("numbers", {})) if k.startswith("CR_") or k in ("MAX_SPELL_SCHOOLS", "BASE_MOVEMENT_SPEED")))
    else:
        for k, v in sorted(api.get("numbers", {}).items()): out.append("- `%s` = %s" % (k, v))
    W("api/constants.md", "\n".join(out) + "\n")
    # widgets
    out = ["# Widget methods in the live client\n", head, "Each list is read from one real object of that type. Where Blizzard documents a method (ScriptObject documentation), its signature is shown.\n"]
    for kind in sorted(api.get("widgets", {})):
        ms = api["widgets"][kind]
        out.append("\n## %s (%d methods)\n" % (kind, len(ms)))
        for m in ms:
            d = dwidget.get(m)
            if d:
                d0 = d[0]
                out.append("- `%s(%s)`%s%s · %s" % (m, d0["sig"].split("(", 1)[1].rstrip(")"), (" → `%s`" % d0["returns"]) if d0["returns"] else "",
                                                ((" · " + ", ".join(d0["flags"])) if d0["flags"] else ""), d0["object"]))
            else:
                out.append("- `%s`" % m)
    W("api/widgets.md", "\n".join(out) + "\n")
    # events and structures (documentation only: an addon cannot list events)
    out = ["# Events (Blizzard's generated documentation)\n", "From the documentation%s. The live client cannot list its events to an addon, so this list is the documented set.\n" % ((" (" + build_txt + ")") if build_txt else "")]
    for e in sorted(devents):
        d = devents[e]
        out.append("- `%s`%s%s%s · %s" % (e, (" (" + d["payload"] + ")") if d["payload"] else "", (" · " + ", ".join(d["flags"])) if d["flags"] else "",
                                          (" · " + d["doc"]) if d["doc"] else "", d["system"]))
    W("api/events.md", "\n".join(out) + "\n")
    out = ["# Structures (Blizzard's generated documentation)\n", "Fields of the tables the API returns or takes. `NeverSecret` on a field means it stays readable in combat.\n"]
    for s in sorted(dstruct):
        d = dstruct[s]
        out.append("\n## %s (%s, %s)\n" % (s, d["type"], d["system"]))
        for f in d["fields"]:
            out.append("- `%s`%s%s" % (f["param"], (" · " + ", ".join(f["flags"])) if f["flags"] else "", (" · " + f["doc"]) if f["doc"] else ""))
    W("api/structures.md", "\n".join(out) + "\n")
    summary = {
        "client": b, "captured": api.get("at"), "documentation": build_txt or "(unknown build)",
        "counts": counts, "documentedNamespaceFunctions": documented_live, "documentedGlobals": documented_glob,
        "documentedFunctionsTotal": len(dfun), "documentedEvents": len(devents), "documentedStructures": len(dstruct),
        "docFilesUnparsed": bad,
    }
    live_out = api
    if args.public:
        live_out = dict(api, globals=[g for g in live_glob if g in dfun], numbers={k: v for k, v in api.get("numbers", {}).items() if k.startswith("CR_") or k in ("MAX_SPELL_SCHOOLS", "BASE_MOVEMENT_SPEED")}, publicVersion=True)
    W("api/api.json", json.dumps({"summary": summary, "live": live_out, "docs": {"functions": dfun, "events": devents, "structures": dstruct,
                                                                            "enums": denums, "widgetMethods": dwidget}}, indent=0, sort_keys=True))
    W("api/README.md", "\n".join([
        "# API reference (XayaUI core reference)\n",
        head,
        "| | Count |", "|---|---|",
        "| Global functions (game, Blizzard UI and loaded addons) | %d (%d documented) |" % (counts.get("globalFunctions", 0), documented_glob),
        "| C_ namespaces | %d |" % counts.get("namespaces", 0),
        "| C_ namespace functions | %d (%d documented) |" % (counts.get("namespaceFunctions", 0), documented_live),
        "| Enums | %d |" % counts.get("enums", 0),
        "| Numeric ALL-CAPS globals | %d |" % counts.get("numbers", 0),
        "| Widget types | %d |" % len(api.get("widgets", {})),
        "| Documented events | %d |" % len(devents),
        "| Documented structures | %d |" % len(dstruct),
        "",
        "Files: `namespaces.md`, `globals.md`, `enums.md`, `constants.md`, `widgets.md`, `events.md`, `structures.md`, and `api.json` (all of it, machine-readable).",
        "",
        "How to read a line: `` `C_Item.GetItemStats(itemLink: cstring)` → `statTable: LuaValueVariant` · SecretArguments=AllowedWhenUntainted ``. `?` after a type means it may be nil; flags are Blizzard's own (for example `SecretReturns`, `RequiresNonSecretAura`, `MayReturnNothing`). A name with no signature exists in the client but is not in the generated documentation (older global functions, Blizzard UI code, addons).",
        "",
        "Rebuild: `python3 docs/reference/build_reference.py --saved <XayaUI_DevAssist.lua> --docs <Blizzard_APIDocumentationGenerated folder> --out docs/reference --public`.",
        "",
        ("PUBLIC VERSION (this repository is public): Blizzard's written notes on functions, events and fields are left out, and so are the undocumented globals and numeric globals (they also hold the names of every addon loaded during the capture). The full version, with all of that, is in Xaya's private Google Drive folder \"Blizzard API Data\" (XayaUI-reference-full-*.zip)." if args.public else "FULL VERSION: private. Do not commit it to the public repository; the repository holds the --public build."),
    ]) + "\n")

# ---- 4. Talent and spell reference ------------------------------------------------------------------------------------------
SEC = {0: "never secret", 1: "always secret", 2: "secret in some situations"}
def clean(s):
    if not isinstance(s, str): return ""
    s = re.sub(r"\|T[^|]*\|t", "", s)
    s = re.sub(r"\|A[^|]*\|a", "", s)
    s = re.sub(r"\|c[0-9a-fA-F]{8}", "", s).replace("|r", "")
    s = re.sub(r"\|H[^|]*\|h", "", s).replace("|h", "")
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    return s.strip()
def facts(sp):
    out = []
    ct = sp.get("ct")
    if isinstance(ct, (int, float)) and ct > 0: out.append("cast %.2g s" % (ct / 1000))
    elif ct == 0: out.append("instant")
    cd = sp.get("cd")
    if isinstance(cd, (int, float)) and cd: out.append("base cooldown %g s" % cd)
    ch = sp.get("ch")
    if isinstance(ch, (int, float)) and ch: out.append("%d charges" % ch)
    if sp.get("sec") in SEC: out.append("aura " + SEC[sp["sec"]])
    if sp.get("missing"): out.append("the game does not know this ID")
    return ", ".join(out)
def text_block(sp, indent="  "):
    if args.public: return []
    d = clean(sp.get("d") or (sp.get("tt") and ("(tooltip) " + sp["tt"])) or "")
    if not d: return []
    return [indent + "> " + line if line else indent + ">" for line in d.split("\n")]

if static:
    spells = static.get("spells", {})
    refs = collections.defaultdict(list)
    classes = static.get("classes", [])
    if isinstance(classes, dict): classes = list(classes.values())
    index = ["# Talent and spell reference (XayaUI core reference)\n",
             "From XayaUI Game Data Capture's all-class scan (`/xuidump static`), built %s, interface %s. Every class's talent trees were read through the game's talent view (class, spec and hero trees of every spec); each spell's text, cast time, base cooldown (GetSpellBaseCooldown), charges and aura secrecy were read from the game. Text is the game's own wording for the character that ran the scan (numbers in descriptions can depend on that character's stats and talents).\n" % (static.get("built"), static.get("build")),
             "Aura secrecy (`Enum.SecrecyLevel`): never secret / always secret / secret in some situations. Which call produced it is not recorded in the capture; `C_Secrets.GetSpellAuraSecrecy` is the documented call that returns that enum (inference).\n",
             "| Class | Specs | Talent nodes | Entries | Hero trees | File |", "|---|---|---|---|---|---|"]
    for c in classes:
        token, name = c.get("token"), c.get("name")
        specs = c.get("specs", {}) or {}
        hero = c.get("hero", {}) or {}
        nodes = c.get("nodes", {}) or {}
        nent = sum(len(n.get("e") or []) for n in nodes.values())
        index.append("| %s | %s | %d | %d | %s | [%s.md](%s.md) |" % (name, ", ".join("%s (%s)" % (v, k) for k, v in sorted(specs.items())), len(nodes), nent,
                                                                     ", ".join(h.get("name", "?") for h in hero.values()) or "none", token, token))
        out = ["# %s talents and spells\n" % name, "Class token `%s`. Specs: %s.\n" % (token, ", ".join("%s (%s)" % (v, k) for k, v in sorted(specs.items())))]
        groups = collections.OrderedDict()
        groups[("class", None)] = []
        for sid in sorted(specs, key=lambda x: int(x)): groups[("spec", int(sid))] = []
        for hid in sorted(hero, key=lambda x: int(x)): groups[("hero", int(hid))] = []
        for nid, n in sorted(nodes.items(), key=lambda kv: int(kv[0])):
            scope = n.get("scope")
            nspecs = n.get("specs") or []
            if scope == "hero": key = ("hero", n.get("hero"))
            elif scope == "spec" and len(nspecs) == 1: key = ("spec", nspecs[0])
            elif scope == "spec": key = ("spec", nspecs[0] if nspecs else None)
            else: key = ("class", None)
            groups.setdefault(key, []).append((nid, n))
            for e in n.get("e") or []:
                if e.get("spell"): refs[str(e["spell"])].append({"class": token, "node": int(nid), "scope": scope, "specs": nspecs, "hero": n.get("hero")})
        for (kind, gid), lst_nodes in groups.items():
            if kind == "class": out.append("\n## Class talents (all specs)\n")
            elif kind == "spec": out.append("\n## %s talents (spec %s)\n" % (specs.get(str(gid), "?"), gid))
            else:
                h = hero.get(str(gid), {})
                out.append("\n## Hero tree: %s (%s)\n" % (h.get("name", "?"), gid))
                if h.get("desc") and not args.public: out.append("> " + clean(h["desc"]) + "\n")
            if not lst_nodes: out.append("(none)"); continue
            for nid, n in lst_nodes:
                es = n.get("e") or []
                choice = n.get("choice") or len(es) > 1
                specnote = ""
                if kind == "spec" and len(n.get("specs") or []) > 1:
                    specnote = " · also " + ", ".join(specs.get(str(s), str(s)) for s in n["specs"] if s != gid)
                if kind == "hero" and n.get("specs"):
                    specnote = " · specs " + ", ".join(specs.get(str(s), str(s)) for s in n["specs"])
                out.append("- Node %s%s%s" % (nid, " · choice" if choice else "", specnote))
                for e in es:
                    sp = spells.get(str(e.get("spell")), {}) if e.get("spell") else {}
                    nm = e.get("name") or sp.get("n") or (e.get("oName")) or "?"
                    bits = ["spell %s" % e["spell"]] if e.get("spell") else []
                    if e.get("maxRanks"): bits.append("%d rank%s" % (e["maxRanks"], "" if e["maxRanks"] == 1 else "s"))
                    if e.get("passive"): bits.append("passive")
                    if e.get("sub"): bits.append("picks hero tree %s" % e["sub"])
                    f = facts(sp)
                    if f: bits.append(f)
                    out.append("  - **%s** (%s)" % (nm, ", ".join(bits)))
                    out.extend(text_block(sp, "    "))
        sets = c.get("setInfo", {}) or {}
        if sets:
            out.append("\n## Tier sets (Encounter Journal)\n")
            for sid in sorted(sets, key=lambda x: int(x)):
                for setID, info in sorted((sets[sid] or {}).items(), key=lambda kv: int(kv[0])):
                    out.append("- %s (set %s, item level %s, spec %s): items %s" % (info.get("name"), setID, info.get("ilvl"), specs.get(str(sid), sid),
                                                                                  ", ".join(str(i) for i in info.get("items") or [])))
                    for bid in info.get("bonus") or []:
                        sp = spells.get(str(bid), {})
                        refs[str(bid)].append({"class": token, "set": int(setID), "spec": int(sid)})
                        out.append("  - Bonus **%s** (spell %s%s)" % (sp.get("n", "?"), bid, (", " + facts(sp)) if facts(sp) else ""))
                        out.extend(text_block(sp, "    "))
        W("spells/%s.md" % token, "\n".join(out) + "\n")
    other = ["# Spells not tied to a talent node or tier set\n",
             "These came from the spell list the scan was given (its class grouping was not saved in the capture).\n"]
    for sid in sorted(spells, key=lambda x: int(x)):
        if sid in refs: continue
        sp = spells[sid]
        f = facts(sp)
        other.append("- **%s** (spell %s%s)" % (sp.get("n", "?"), sid, (", " + f) if f else ""))
        other.extend(text_block(sp, "  "))
    W("spells/other-spells.md", "\n".join(other) + "\n")
    sm = static.get("summary", {})
    index += ["", "Totals: %s spells (%s with a description, %s tooltip text only, %s IDs the game did not know), %s talent nodes, %s entries, %s scan errors." % (
        sm.get("spells"), sm.get("withDescription"), sm.get("tooltipOnly"), sm.get("unknownToGame"), sm.get("nodes"), sm.get("entries"), sm.get("errors")),
        "", "Also: [other-spells.md](other-spells.md) (spells from the scan's spell list that no talent node or tier set references) and `spells.json` (everything, machine-readable, with each spell's talent-node and tier-set references).",
        "", ("PUBLIC VERSION (this repository is public): spell descriptions, tooltip text and hero-tree descriptions are Blizzard's written text and are left out here; IDs, names, ranks, cast time, base cooldown, charges and aura secrecy are kept. The full version with the text is in Xaya's private Google Drive folder \"Blizzard API Data\" (XayaUI-reference-full-*.zip)." if args.public else "FULL VERSION: private. Do not commit it to the public repository; the repository holds the --public build.")]
    W("spells/README.md", "\n".join(index) + "\n")
    def pub_sp(v):
        return {k: x for k, x in v.items() if not (args.public and k in ("d", "tt"))}
    def pub_cls(c):
        if not args.public: return c
        c = dict(c); c["hero"] = {k: {"name": h.get("name")} for k, h in (c.get("hero") or {}).items()}
        return c
    W("spells/spells.json", json.dumps({"built": static.get("built"), "build": static.get("build"), "summary": sm, "classes": [pub_cls(c) for c in classes],
                                        "publicVersion": bool(args.public), "spells": {k: dict(pub_sp(v), refs=refs.get(k, [])) for k, v in spells.items()}}, indent=0, sort_keys=True))
print("api:", bool(api), "spells:", bool(static), "doc files:", len(docfiles), "unparsed:", len(bad), "->", args.out)
