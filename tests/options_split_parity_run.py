#!/usr/bin/env python3
"""Platform split P3 "Options split" (Options 0.6.83; docs/plans/PLATFORM-SPLIT-2026-11-07.md sections 7, 10 and risk R8): the rule
editor and the rules tree moved out of XayaUI_Options/Options.lua into XayaUI_Options/RuleEditor/. A pure code move: the player must
get exactly the same settings window. Loads the real addons in the stand-in game, sets up one fixed state (rules with cues and an
outcome, nested groups, a disabled rule, a buff bar, a Recycle Bin item, a fixed clock) and builds the whole options table
(ns.BuildOptionsTable, every page of every module that is on). Every node is written out: its key path, type, order, width, name,
desc, the results of hidden / disabled / get / values / sorting / confirm / image called with an AceConfig-style info table, and every
other plain field; functions that change something (set, func, validate) are only noted as present. Version strings, table addresses,
dates and error positions are normalised.
  A The dump of the new code equals the dump of the old code (Options 0.6.82, main bd03eb5), compared per top tab (sha256 and node
    count), with every module on.
  B The same with each feature module switched off in turn (Chat, QoL, Bonus Features, Blizzard Reskin, Dev Assist, Nameplates, Media).
  C Off costs nothing (V14): a feature addon that is switched off has registered no settings page (ns.BuildSettingsPages(module)
    is empty) and its top tab is absent; the rule editor's own files register no page of their own.
The golden values below were produced by `python3 tests/options_split_parity_run.py --golden` on a checkout of bd03eb5 (the code
before the move). `--dump DIR` writes the full dumps, one file per variant, to compare by hand (diff) when a check fails.
Run: python3 tests/options_split_parity_run.py"""
import hashlib, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

GOLDEN_FILE = os.path.join(HERE, "options_split_parity_golden.json")
MODULES = ["XayaUI_Chat", "XayaUI_QoL", "XayaUI_Bonus", "XayaUI_Reskin", "XayaUI_DevAssist", "XayaUI_Nameplates", "XayaUI_Media"]
MODULE_KEY = {"XayaUI_Chat": "chat", "XayaUI_QoL": "qol", "XayaUI_Bonus": "bonus", "XayaUI_Reskin": "reskin"}

LUA = r'''
return function(W, L)
-- a fixed clock: Recycle Bin dates and "removed for good in" read time() / date()
local T0 = 1790000000
local osdate, ostime = os.date, os.time
rawset(_G, "time", function(t) if t then return ostime(t) end return T0 end)
rawset(_G, "date", function(f, t) return osdate(f, t or T0) end)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
if not (ns and ns.BuildOptionsTable) then return { "the settings window did not load" } end
-- the fixed state
local function rule(name, enabled) local r = ns.NewRule(); r.name = name; r.enabled = enabled; ns.NormalizeRule(r); return r end
ns.folders = {}
local g1 = ns.NewFolder and ns.NewFolder("Group One") or nil
local g2 = ns.NewFolder and g1 and ns.NewFolder("Inner Group", g1.id) or nil
local A = rule("Shell", true); A.useBuff = true; A.buffID = 48707; A.buffState = "present"
local B = rule("Cooldown watch", true); B.spellID = 47528; B.cdState = "ready"; if g1 then B.folder = g1.id end
local C = rule("Switched off", false); if g2 then C.folder = g2.id end
local D = rule("Sound only", true); D.spellID = 49576
ns.rules = { A, B, C, D }
pcall(ns.NewCueRule, A, "icon"); pcall(ns.NewCueRule, A, "text"); pcall(ns.NewCueRule, D, "sound"); pcall(ns.NewCueRule, B, "bar")
local E = rule("Deleted later", true); ns.rules[#ns.rules + 1] = E
if ns.RecycleRule then pcall(ns.RecycleRule, E) end
if ns.MarkDirty then pcall(ns.MarkDirty) end
W.tick(0.1, 3)
local root = ns.BuildOptionsTable()
-- the dump
local lines = {}
local function norm(s)
  s = tostring(s)
  s = s:gsub("0x%x+", "<addr>"):gsub("(%a+): <addr>", "%1"):gsub("%d%d%d%d%-%d%d%-%d%d %d%d:%d%d", "<date>")
  s = s:gsub("[%w_/%.%-]+%.lua:%d+:", "<src>:")
  return s
end
local function ser(v, depth, seen)
  local t = type(v)
  if t == "function" then return "fn" end
  if t == "string" then return (string.format("%q", norm(v)):gsub("\\\n", "\\n")) end   -- one line per node
  if t ~= "table" then return norm(v) end
  seen = seen or {}
  if seen[v] then return "<cycle>" end
  if depth > 4 then return "{...}" end
  seen[v] = true
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k], depth + 1, seen) end
  seen[v] = nil
  return "{" .. table.concat(out, ",") .. "}"
end
local CALL = { name = true, desc = true, hidden = true, disabled = true, get = true, values = true, sorting = true, confirm = true,
  image = true, imageWidth = true, imageHeight = true, order = true, width = true, descStyle = true, confirmText = true }
local function call(fn, info)
  local res = { pcall(fn, info) }
  if not res[1] then return "ERR " .. norm(res[2]) end
  local out = {}
  for i = 2, math.max(2, table.maxn(res)) do out[#out + 1] = ser(res[i], 0) end
  return table.concat(out, " | ")
end
local function walk(node, path, depth)
  if type(node) ~= "table" or depth > 40 then return end
  local info = { options = root, option = node, arg = node.arg, type = node.type, handler = node.handler, uiType = "dialog",
    uiName = "CueRules", appName = "CueRules" }
  for i, k in ipairs(path) do info[i] = k end
  local keys = {}
  for k in pairs(node) do if k ~= "args" and k ~= "plugins" then keys[#keys + 1] = k end end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do
    local v = node[k]
    if type(v) == "function" and CALL[k] then parts[#parts + 1] = tostring(k) .. "()=" .. call(v, info)
    else parts[#parts + 1] = tostring(k) .. "=" .. ser(v, 1) end
  end
  lines[#lines + 1] = table.concat(path, ".") .. " :: " .. table.concat(parts, " ; ")
  if type(node.args) == "table" then
    local ks = {}
    for k in pairs(node.args) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(ks) do
      local p = {}
      for i, x in ipairs(path) do p[i] = x end
      p[#p + 1] = tostring(k)
      walk(node.args[k], p, depth + 1)
    end
  end
end
walk(root, {}, 0)
-- C: which modules registered pages
local reg = {}
for _, m in ipairs({ "chat", "qol", "bonus", "reskin", "debugging", "nameplates", "media", "rules", "core", "cooldowns" }) do
  local ks = {}
  for k in pairs(ns.BuildSettingsPages(m, function() end)) do ks[#ks + 1] = k end
  table.sort(ks)
  reg[#reg + 1] = m .. "=" .. table.concat(ks, ",")
end
return { "ok", table.concat(lines, "\n"), table.concat(reg, " ") }
end
'''


def versions():
    out = {}
    for name, d in H.find_addons().items():
        toc = open(os.path.join(d, name + ".toc"), encoding="utf-8").read()
        m = re.search(r"^## Version:\s*(\S+)", toc, re.M)
        if m:
            out[name] = m.group(1)
    return out


def run_variant(off):
    folders = H.find_addons()
    enabled = [n for n in folders if n != off]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    if res[1] != "ok":
        return None, None, errs + [str(res[1])]
    dump = str(res[2])
    # version strings: the addons whose code changes take a new version; the dump must not depend on it
    for name, ver in sorted(versions().items(), key=lambda kv: -len(kv[1])):
        dump = dump.replace(ver, "<version>")
    return dump, str(res[3]), errs


def page_keys(addon):
    """the page keys an addon's own files register (ns.RegisterSettingsPage(module, key, ...)), read from its files"""
    out = set()
    d = H.find_addons()[addon]
    for base, _, files in os.walk(d):
        for f in files:
            if f.endswith(".lua"):
                src = open(os.path.join(base, f), encoding="utf-8", errors="replace").read()
                out |= set(re.findall(r'RegisterSettingsPage\(\s*"[a-z]+"\s*,\s*"(\w+)"', src))
    return out


def summarise(dump):
    tabs = {}
    for line in dump.split("\n"):
        path = line.split(" :: ", 1)[0]
        top = path.split(".", 1)[0] if path else "<root>"
        tabs.setdefault(top, []).append(line)
    return {t: [hashlib.sha256("\n".join(ls).encode("utf-8")).hexdigest()[:16], len(ls)] for t, ls in sorted(tabs.items())}


def main():
    dump_dir = None
    if "--dump" in sys.argv:
        dump_dir = sys.argv[sys.argv.index("--dump") + 1]
        os.makedirs(dump_dir, exist_ok=True)
    variants = [None] + MODULES
    results = {}
    errs_all = []
    for off in variants:
        tag = "all-on" if off is None else ("off-" + off)
        dump, reg, errs = run_variant(off)
        errs_all += [(tag, e) for e in errs]
        if dump is None:
            results[tag] = None
            continue
        if dump_dir:
            open(os.path.join(dump_dir, tag + ".txt"), "w", encoding="utf-8").write(dump + "\n")
        results[tag] = {"tabs": summarise(dump), "registered": reg}
    if "--golden" in sys.argv:
        json.dump(results, open(GOLDEN_FILE, "w", encoding="utf-8"), indent=1, sort_keys=True)
        print("golden written: %s (%d variants, %d Lua errors)" % (GOLDEN_FILE, len(results), len(errs_all)))
        for tag, e in errs_all:
            print("ERROR in the game stand-in [%s]: %s" % (tag, e[:400]))
        return
    golden = json.load(open(GOLDEN_FILE, encoding="utf-8"))
    total = bad = 0

    def check(name, ok, detail=""):
        nonlocal total, bad
        total += 1
        if not ok:
            bad += 1
        print(("PASS " if ok else "FAIL ") + name + (("  " + detail) if (detail and not ok) else ""))

    for off in variants:
        tag = "all-on" if off is None else ("off-" + off)
        got, want = results.get(tag), golden.get(tag)
        check("[%s] the options table builds" % tag, got is not None)
        if got is None or want is None:
            check("[%s] golden present" % tag, want is not None)
            continue
        keys = sorted(set(got["tabs"]) | set(want["tabs"]))
        for t in keys:
            check("[%s] %s: same nodes, names, descs, types, widths, hidden / disabled / get results as before the move" % (tag, t),
                  got["tabs"].get(t) == want["tabs"].get(t), "got %s want %s" % (got["tabs"].get(t), want["tabs"].get(t)))
        check("[%s] the same settings pages are registered per module" % tag, got["registered"] == want["registered"],
              "got %s want %s" % (got["registered"], want["registered"]))
        # C: off costs nothing (V14): none of the pages the switched-off addon's files register exists
        if off:
            have = set()
            for x in got["registered"].split():
                m, ks = x.split("=", 1)
                have |= set(k for k in ks.split(",") if k)
            own = page_keys(off)
            check("[%s] V14: the switched-off addon registered none of its %d settings pages" % (tag, len(own)), not (own & have),
                  "still registered: %s" % sorted(own & have))
            if off in ("XayaUI_Chat", "XayaUI_Bonus"):
                check("[%s] V14: its top tab is absent" % tag, MODULE_KEY[off] not in got["tabs"])
    allon = results.get("all-on")
    if allon:
        reg = dict(x.split("=", 1) for x in allon["registered"].split())
        check("the rule editor registers no settings page of its own (rules / core / cooldowns)",
              all(reg.get(m) == "" for m in ("rules", "core", "cooldowns")))
    for tag, e in errs_all:
        print("ERROR in the game stand-in [%s]: %s" % (tag, e[:600]))
    print("%d checks, %d failed, %d Lua errors" % (total, bad, len(errs_all)))
    sys.exit(1 if bad or errs_all else 0)


if __name__ == "__main__":
    main()
