#!/usr/bin/env python3
"""Settings seam P2 (core 0.6.75; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 5 step 1, PS-7). ns.Settings(module) returns
that module's settings view; every read and write lands in the same CueRulesDB key as before. Checks:
  G  guard: no Lua file outside the Platform allow-list below uses CueRulesDB directly (a name in code, or the string
     "CueRulesDB" as in rawget(_G, "CueRulesDB")); comments and longer strings (a QA step telling the player to /dump it) do not
     count. In the Platform files, a module's key (from the owner lists in Modules.lua section 0b) is not touched directly either, except in
     Core.lua, which sets up the saved variables (first-run defaults). Run on main 2faeda5 it lists 319 uses.
  B  byte-identical saved data: a full scripted play session (tests/harness/scenario.lua: every command, minimap row and option
     of every addon), a /reload, on a fixed clock and fixed addon versions, with every addon on and with only XayaUI core on; the
     saved variables of every addon (canonical JSON, table addresses blanked) hash to exactly what the old code (main 2faeda5)
     saved: GOLDEN, made by `python3 tests/settings_seam_run.py --golden` run in a checkout of 2faeda5. Also: no view was asked for
     a key its module does not own during those sessions (ns.SettingsUnknownKeys() empty).
     (P4, platform split) since XayaUI_Rules declares XayaUITalentDB, the saved variables are compared merged across addon folders
     ({variable: value}), "core only" is XayaUI + XayaUI_Rules (the old XayaUI folder), and GOLDEN was made again on main 8ced2e3
     (the code before the split) in that form; the one allowed difference, the new folder's name in the three lists of installed
     XayaUI addons, is taken out (canon). With XayaUI Rules off (the Platform alone, and every other addon on): no Lua error, no view
     asked for a key it does not own, and nothing of the rules saved.
     (Debug chat defaults, Chat 0.6.46) one more allowed difference, in canon: the privacy cover's and the Sidebar's defaults that now
     reach the saved settings at login (listed in CHAT_DEFAULTS_ADDED, found by diffing the dumps of 1b974fe and the new code).
  C  a view kept from load time still reads the new data after: the saved variables arriving (first-run defaults), a profile
     import (Profiles > Import, a registered part), Theme "Reset everything", a backup "Load (replace)", and CueRulesDB being
     replaced as a whole; the hot-path caches (ns.AuraAliasesOf, read on every aura read) follow a view write, a profile part
     being applied and ns.SettingsChanged().
  D  module off costs nothing (V14): with every feature addon off, asking ns.Settings for each module and reading every key
     creates no key, no frame and no event registration, and the same view comes back every time.
  E  each view reads and writes exactly the CueRulesDB key it did before (Reskin's rsk / gm / friendColors inside CueRulesDB.ui);
     an unknown module gives nil; a key the module does not own is counted, and raises in strict mode.
Negative control: on main 2faeda5, G fails (direct uses everywhere), C/D/E fail (no ns.Settings), and B's "no unknown keys" check
fails; B's hash checks pass there by design (they are the reference the new code must match).
Run: python3 tests/settings_seam_run.py"""
import hashlib, json, os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)
sys.path.insert(0, HERE)
import settings_stores as SST  # noqa: E402  (P5: where each module keeps its settings)

# (P4) made by --golden in a checkout of main 8ced2e3 (the code before the platform split), with the saved variables merged across
# addon folders (canon below): XayaUITalentDB is declared by XayaUI_Rules since P4 instead of XayaUI, so the same data sits under
# another folder name; "core only" is the old XayaUI folder, i.e. XayaUI + XayaUI_Rules (+ XayaUI_Media) now.
GOLDEN = {
    "all on: play session": "1b08cc0ea14304c0a73f991822050a4127a1cac9389a0e7be120f235d4cc3039",
    "all on: reload": "c40a90a6ecea2fe4643e3425aacf020d2040bd30321bedefde003f8635475845",
    "core only: play session": "719d8932a1e2c4cca3e4e45416945f5a5a5d5dd219c842154b7f126664b35db8",
    "core only: reload": "719d8932a1e2c4cca3e4e45416945f5a5a5d5dd219c842154b7f126664b35db8",
}
# (P2, kept for the record) the hashes per addon folder, made in a checkout of main 2faeda5 (the code before the seam); 8ced2e3 matched them
GOLDEN_P2 = {
    "all on: play session": "92a578439513886e35eb3782bd23996ac273ae74d0390336da81ef4dadc4ea07",
    "all on: reload": "7d12f59a3828ffb556747e983ea057f7339bfbe981bc6109a8b95b805acc7125",
    "core only: play session": "d24424c40ec56fda2d7dc2d8776aa1fc3a40c10d37998dc4e43607764a7961b7",
    "core only: reload": "d24424c40ec56fda2d7dc2d8776aa1fc3a40c10d37998dc4e43607764a7961b7",
}

# The Platform (plan section 4 and the P2 brief): these files keep direct access to CueRulesDB, which the Platform folder declares.
PLATFORM = {
    "XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI/Theme.lua", "XayaUI/Share.lua", "XayaUI/RecycleBin.lua",
    "XayaUI/Sound.lua", "XayaUI/LocalSounds.lua", "XayaUI/LocalGraphics.lua", "XayaUI/UserMedia.lua", "XayaUI/Console.lua",
    "XayaUI/DebugRecord.lua", "XayaUI/Compat.lua", "XayaUI/MinimapButton.lua", "XayaUI/GameMenuButton.lua", "XayaUI_Options/Profiles.lua",
}
SV_INIT = {"XayaUI/Core.lua", "XayaUI/Modules.lua"}   # saved-variable set-up, the seam itself, the profile parts

# QA-branch modules: main keeps only core, Options, Rules, Rules_Options, QoL, Bonus, Dev Assist and Media; Chat, Reskin and Nameplates are
# on the QA branch only. A module's checks run when its folder is here; absent, they are printed as SKIP (never silently).
QA_MODULES = {"chat": "XayaUI_Chat", "reskin": "XayaUI_Reskin", "nameplates": "XayaUI_Nameplates"}
ABSENT = {m: a for m, a in QA_MODULES.items() if not os.path.isdir(os.path.join(ROOT, a))}


def skip(addon, text):
    print("SKIP (QA-branch module absent: %s) %s" % (addon, text))


def emit(res):
    """the checks a Lua chunk returned; an entry whose name starts with SKIP ( is a skipped check (printed, not counted)"""
    for i in range(1, len(res) + 1):
        if str(res[i][1]).startswith("SKIP ("):
            print(res[i][1])
        else:
            check(res[i][1], res[i][2])


results = []


def check(name, ok, extra=""):
    results.append((name, bool(ok)))
    print(("PASS " if ok else "FAIL ") + name + ("" if ok or not extra else "  [" + str(extra)[:400] + "]"))


# --------------------------------------------------------------------------------------------------------------------------- G
def lua_tokens(src):
    """(kind, text, line) for code: 'name', 'str' (string literal contents), 'other'. Comments are dropped."""
    i, n, line, out = 0, len(src), 1, []
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1; i += 1; continue
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                end = src.find("]" + m.group(1) + "]", i)
                end = n if end < 0 else end + len(m.group(1)) + 2
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            line += src.count("\n", i, end); i = end; continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            end = src.find("]" + m.group(1) + "]", i)
            end = n if end < 0 else end
            out.append(("str", src[i + len(m.group(0)):end], line))
            line += src.count("\n", i, end); i = end + len(m.group(1)) + 2; continue
        if c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            out.append(("str", src[i + 1:j], line)); line += src.count("\n", i, j); i = j + 1; continue
        m = re.match(r"[A-Za-z_]\w*", src[i:])
        if m:
            out.append(("name", m.group(0), line)); i += len(m.group(0)); continue
        out.append(("other", c, line)); i += 1
    return out


def owner_lists(root):
    """{module: [keys]} from Modules.lua's SETTINGS_KEYS (None when it is not there: the old code)."""
    p = os.path.join(root, "XayaUI", "Modules.lua")
    if not os.path.isfile(p):
        return None
    src = open(p, encoding="utf-8").read()
    start = src.index("local SETTINGS_KEYS = {") + len("local SETTINGS_KEYS = {")
    block = src[start:src.index("\n}\n", start)]
    out = {}
    for m in re.finditer(r"(\w+)\s*=\s*\{([^}]*)\}", block):
        out[m.group(1)] = re.findall(r'"(\w+)"', m.group(2))
    return out


def guard(root):
    files = subprocess.run(["git", "ls-files", "XayaUI*"], cwd=root, capture_output=True, text=True).stdout.split()
    owners = owner_lists(root) or {}
    platform_keys = set(owners.get("platform", []))
    module_keys = {k for m, ks in owners.items() if m != "platform" for k in ks} - platform_keys
    bad = []
    for f in files:
        if not f.endswith(".lua") or "/Libs/" in f:
            continue
        toks = lua_tokens(open(os.path.join(root, f), encoding="utf-8", errors="replace").read())
        for i, (kind, text, line) in enumerate(toks):
            direct = (kind == "name" and text == "CueRulesDB") or (kind == "str" and text == "CueRulesDB")
            if not direct:
                continue
            if f not in PLATFORM:
                bad.append("%s:%d uses CueRulesDB directly (go through ns.Settings)" % (f, line))
            elif f not in SV_INIT and kind == "name":
                # CueRulesDB.<key> / CueRulesDB["key"] in a Platform file: a module's key goes through its owner's view
                key = None
                if i + 2 < len(toks) and toks[i + 1][1] == "." and toks[i + 2][0] == "name":
                    key = toks[i + 2][1]
                elif i + 3 < len(toks) and toks[i + 1][1] == "[" and toks[i + 2][0] == "str":
                    key = toks[i + 2][1]
                if key in module_keys:
                    bad.append("%s:%d (Platform) touches module key CueRulesDB.%s directly (go through ns.Settings)" % (f, line, key))
    # (P5) no module reads another module's store directly: a module's saved variable (XayaUIReskinDB ...) is named only in its own
    # addon's folder and in the Platform's Modules.lua (the seam that opens it); every other file goes through ns.Settings(<owner>)
    try:
        stores = SST.layout(root)["stores"]
    except Exception:
        stores = {}
    for f in files:
        if not f.endswith(".lua") or "/Libs/" in f:
            continue
        folder = f.split("/", 1)[0]
        toks = None
        for m, st in stores.items():
            if folder == st["addon"] or f == "XayaUI/Modules.lua":
                continue
            if toks is None:
                toks = lua_tokens(open(os.path.join(root, f), encoding="utf-8", errors="replace").read())
            for kind, text, line in toks:
                if kind in ("name", "str") and text == st["var"]:
                    bad.append("%s:%d names %s's store %s directly (go through ns.Settings(\"%s\"))" % (f, line, m, st["var"], m))
    return bad


# --------------------------------------------------------------------------------------------------------------------------- B
PRELUDE = r'''
local FIXED, realTime, realDate = 1794000000, os.time, os.date
time = function(t) if t ~= nil then return realTime(t) end return FIXED end
date = function(f, t) f = f or "%c"; if f:sub(1, 1) == "!" then f = f:sub(2) end; return realDate("!" .. f, t or FIXED) end
local A = C_AddOns; local get = A.GetAddOnMetadata
A.GetAddOnMetadata = function(a, f) if f == "Version" then return "0" end return get(a, f) end
GetAddOnMetadata = A.GetAddOnMetadata
'''


def build(folders, enabled, saved):
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved or {}}))
    L.execute(PRELUDE)
    return L, world, loader


def play(folders, enabled, saved, quick):
    L, world, loader = build(folders, enabled, saved)
    S = L.eval("function(path, W, Ld, o) return dofile(path)(W, Ld, o) end")(
        os.path.join(H.HERE, "scenario.lua"), world, loader, H.to_lua(L, {"writeBack": True, "quick": quick}))
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    unknown = L.eval("(function() local ns = rawget(_G, 'XayaUI_NS'); if not (ns and ns.SettingsUnknownKeys) then return nil end;"
                     " local t = {}; for k in pairs(ns.SettingsUnknownKeys()) do t[#t + 1] = k end; table.sort(t); return table.concat(t, ', ') end)()")
    return (H.lua_to_py(S.saved) if S.saved else {}), errs, unknown


# (Debug chat defaults, Chat 0.6.46; see canon) the Chat defaults the old code never saved in the scripted session, with their values
CHAT_DEFAULTS_ADDED = {
    "chat2": {"sbGap": 2},
    "chat": {"privAlpha": 100, "privBorder": False, "privBtnAlpha": 90, "privBtnSize": 28, "privBtnX": 0, "privBtnY": 0,
             "privCoverTabs": False, "privImageChoice": "", "privPath": "", "privReveal": False, "privShowText": False,
             "privStartHidden": False, "privTexture": "Interface\\DialogFrame\\UI-DialogBox-Background", "privTile": False},
}
CHAT_COLOUR_WRITTEN_BACK = {"privR": (0.04, 0), "privG": (0.04, 0), "privB": (0.06, 0)}


STATS_HELP = "/xui stats [on||off||options||status]  Character Toolkit stat panel"


def _stats_line_back(v):
    if isinstance(v, dict):
        return {k: _stats_line_back(x) for k, x in v.items()}
    if isinstance(v, list):
        out = [_stats_line_back(x) for x in v]
        if all(isinstance(x, str) for x in out):
            # (2026-11-08, #37) the Bonus node is titled "Stat Calculator" now: the same line, its new path
            out = [x.replace("Turn it on in Bonus Features > Stat Calculator", "Turn it on in QoL > Character Toolkit").replace("Turn it on in Bonus Features > Character Toolkit", "Turn it on in QoL > Character Toolkit") for x in out]
            i = next((n for n, x in enumerate(out) if x.endswith(STATS_HELP)), None)
            c = next((n for n, x in enumerate(out) if "/xui cursor [highlight" in x), None)
            if i is not None and c is not None and i != c + 1:
                line = out.pop(i)
                c = next(n for n, x in enumerate(out) if "/xui cursor [highlight" in x)
                out.insert(c + 1, line)
        return out
    return v


def canon(saved):
    # (P4) the saved variables merged across addon folders ({variable: value}; every variable name is declared by one folder only)
    merged = {}
    for addon in sorted(saved):
        for var, val in (saved[addon] or {}).items():
            merged[var] = val
    # (P5) each module's own store folded back into CueRulesDB as it was laid out before (tests/settings_stores.py): the old code's
    # golden hash then still says "nothing a player set changed and nothing was lost"; the copy's marks (storeVersion ...) are dropped
    merged = SST.project(merged, SST.layout(ROOT))
    # (Rules 0.6.82, group anchors) the one-time "Nothing moves" update's own marks (its done flag, and the list of groups it adjusted
    # when there were any; the scenario has none): taken out, so the rest stays compared with the old code's golden
    if isinstance(merged.get("CueRulesDB"), dict):
        merged["CueRulesDB"].pop("groupAnchorVer", None)
        merged["CueRulesDB"].pop("groupAnchorMoved", None)
    # (P5) the one allowed difference: the old Platform made CueRulesDB.qol = { boxes = {} } (the shelved QoL stats-text boxes) whatever
    # was on; XayaUI QoL makes it in its own store now, so with QoL off there is none (PS-52; nothing of a switched-off module is made)
    if isinstance(merged.get("CueRulesDB"), dict) and "qol" not in merged["CueRulesDB"]:
        merged["CueRulesDB"]["qol"] = {"boxes": {}}
    # (Debug chat defaults, Chat 0.6.46) the one allowed difference in the chat settings: the privacy cover's and the Sidebar's defaults
    # now reach the saved settings at login (in the game they never did; tests/chat_defaults_run.py). Diffing the dumps of 1b974fe and the
    # new code (all on, both sessions): 18 lines, all here; core only: none. The keys the old code never saved are taken out where they
    # hold their default, and the cover colour the scenario writes back from the settings page (it showed 0, 0, 0 for a colour that was
    # missing; now the default) is put back to what the old page showed.
    db = merged.get("CueRulesDB")
    if isinstance(db, dict):
        for part, keys in CHAT_DEFAULTS_ADDED.items():
            t = db.get(part)
            if isinstance(t, dict):
                for k, v in keys.items():
                    if k in t and isinstance(t[k], bool) == isinstance(v, bool) and t[k] == v:
                        del t[k]
        t = db.get("chat")
        if isinstance(t, dict):
            for k, (now, was) in CHAT_COLOUR_WRITTEN_BACK.items():
                if isinstance(t.get(k), (int, float)) and abs(t[k] - now) < 1e-9:
                    t[k] = was
    # (character pane split stage 2, Bonus 0.6.37 / QoL 0.7.53) the two allowed differences in what the game printed (the debug record's
    # lines): /xui stats is registered by XayaUI Bonus Features once XayaUI QoL's settings are open (nothing of it while QoL is off), so
    # /xui help lists it after QoL's own commands (before: between /xui cursor and /xui reskin); and its "is off" line names Bonus Features
    # > Character Toolkit instead of QoL > Character Toolkit. Diffing the dumps of f870d78 and the new code (all on, both sessions): these
    # 4 lines per session, nothing else; core only: none. Put back here, so the rest stays compared with the old code's golden.
    merged = _stats_line_back(merged)
    text = re.sub(r"0x[0-9a-f]+", "0x", json.dumps(merged, sort_keys=True))
    # the lists of installed XayaUI addons (the debug record's session line, the bug report that quotes it, Dev Assist's review
    # signature) name the new folder too; that name is the only difference allowed (checked by diffing both dumps, P4 debug log)
    # (P4b) and the rule editor's folder (XayaUI_Rules_Options, not loaded in these sessions: the window is not opened), the same way
    text = text.replace(", XayaUI_Rules_Options 0 (not loaded)", "").replace(";XayaUI_Rules_Options=0", "")
    return text.replace(", XayaUI_Rules 0", "").replace(";XayaUI_Rules=0", "")


def sessions(root_folders):
    folders = root_folders
    every = set(folders)
    core_only = {n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Media")}   # (P4) the old XayaUI folder
    out = {}
    for tag, en in (("all on", every), ("core only", core_only)):
        s1, e1, u1 = play(folders, en, {}, False)
        s2, e2, u2 = play(folders, en, s1, True)
        out[tag + ": play session"] = (hashlib.sha256(canon(s1).encode()).hexdigest(), e1, u1, s1)
        out[tag + ": reload"] = (hashlib.sha256(canon(s2).encode()).hexdigest(), e2, u2, s2)
    return out


# --------------------------------------------------------------------------------------------------------------------------- C, D, E
SETUP = r'''
local function setup(W, L)
  L.startup()
  W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
  return rawget(_G, "XayaUI_NS")
end
local function ser(v, depth)   -- a value as text, keys sorted (what the game would save)
  depth = depth or 0
  if type(v) ~= "table" then return type(v) == "string" and ("%q"):format(v) or tostring(v) end
  if depth > 30 then return "{...}" end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local t = {}
  for _, k in ipairs(keys) do t[#t + 1] = "[" .. ser(k) .. "]=" .. ser(v[k], depth + 1) end
  return "{" .. table.concat(t, ",") .. "}"
end
local MODULES = { "platform", "core", "qol", "chat", "bonus", "reskin", "devassist" }
'''

HELD_LUA = SETUP + r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
local ns0 = rawget(_G, "XayaUI_NS")
-- the views each addon took when its files loaded (before the saved variables arrived) are the ones kept here
local ns = setup(W, L)
check("XayaUI loaded and ns.Settings exists", ns and type(ns.Settings) == "function")
if not (ns and ns.Settings) then return R end
local V = {}
for _, m in ipairs(MODULES) do V[m] = ns.Settings(m) end
-- (P5) the table a module's keys live in now: its own store once open, else CueRulesDB
local function HVAR(m) local st = ns.SettingsStore(m); if st and st.state == "own" then return st.var end return "CueRulesDB" end
local function HOME(m) return _G[HVAR(m)] end

section("C1 first-run defaults", function()
  check("C1: after the saved settings were set up, the core view held since load reads the same rules list the engine uses",
    V.core.rules ~= nil and rawequal(V.core.rules, HOME("core").rules) and rawequal(ns.rules, V.core.rules))
  check("C1: ... and the QoL view reads the stats-text boxes set up at load (P5: by XayaUI QoL, in its store)",
    V.qol.qol ~= nil and rawequal(V.qol.qol.boxes, HOME("qol").qol.boxes) and rawequal(ns.qolBoxes, V.qol.qol.boxes))
  check("C1: ... and the platform view reads the defaults written into CueRulesDB.ui (console open, Advanced Debugging on)",
    rawequal(V.platform.ui, CueRulesDB.ui) and V.platform.ui.advancedDebug == true and V.platform.ui.trayOpen == true)
end)

section("C2 profile import", function()
  local part = ns.ProfilePartsByKey().qol
  HOME("qol").cursorTrail = nil
  local res = part.apply(part.check({ cursorTrail = { marker = 7, enabled = false }, cursorHighlight = { marker = 9 } }), "merge", 1)
  check("C2: a QoL profile part applied: the held QoL view reads the new cursor trail table", res and V.qol.cursorTrail ~= nil
    and V.qol.cursorTrail.marker == 7 and rawequal(V.qol.cursorTrail, HOME("qol").cursorTrail), tostring(V.qol.cursorTrail))
  check("C2: ... and the merged cursor highlight value", V.qol.cursorHighlight and V.qol.cursorHighlight.marker == 9)
  local bonus = ns.ProfilePartsByKey().bonus
  if bonus then
    bonus.apply(bonus.check({ calculator = { marker = "c" } }), "merge", 1)
    check("C2: a Bonus part applied: the held Bonus view reads it", V.bonus.calculator and V.bonus.calculator.marker == "c")
  end
  if XUI_ABSENT.reskin or XUI_ABSENT.chat then
    R[#R + 1] = { "SKIP (QA-branch module absent: " .. (XUI_ABSENT.reskin and "XayaUI_Reskin" or "XayaUI_Chat") .. ") C2: the Blizzard Reskin part applied: Chat's view reads chat2, the platform view reads the tab switch", true }
  else
  local rk = ns.ProfilePartsByKey().reskin
  rk.apply(rk.check({ chat2 = { marker = 5 }, reskinTabOff = true }), "merge", 1)
  check("C2: the Blizzard Reskin part applied: Chat's view reads chat2, the platform view reads the tab switch",
    V.chat.chat2 and V.chat.chat2.marker == 5 and V.platform.reskinTabOff == true and ns.ReskinTabOn() == false)
  CueRulesDB.reskinTabOff = nil
  end
end)

section("C3 Theme Reset everything", function()
  local T = ns.Theme
  T.SetSize("L")
  check("C3: before: the platform view reads the theme's size L", V.platform.theme and V.platform.theme.size == "L")
  T.ResetAll()
  check("C3: Theme > Reset everything: the held platform view reads the reset theme (size M, base 'class')",
    rawequal(V.platform.theme, CueRulesDB.theme) and V.platform.theme.size == "M" and V.platform.theme.base == "class")
end)

section("C4 backup Load (replace)", function()
  HOME("core").barGroup.spacing = 11
  local ok = ns.Backup_Save("seam test", nil)
  check("C4: a backup is saved (through the platform's profiles key)", ok and #V.platform.profiles >= 1 and rawequal(V.platform.profiles, CueRulesDB.profiles))
  local snap
  for _, p in ipairs(ns.Backups()) do if p.name == "seam test" then snap = p.data end end
  snap = ns.Copy(snap); snap.bars = snap.bars or {}; snap.barGroup = { spacing = 11 }   -- (buff bars are off for now, so a backup leaves them out: put them in)
  HOME("core").barGroup.spacing = 33
  ns.Share_ApplyRules(ns.Copy(snap), "replace")
  check("C4: Load (replace) put the bar group back: the held core view reads spacing 11",
    rawequal(V.core.barGroup, HOME("core").barGroup) and V.core.barGroup.spacing == 11, tostring(V.core.barGroup and V.core.barGroup.spacing))
  check("C4: ... and the rules list the core view reads is the one the engine uses", rawequal(V.core.rules, ns.rules))
end)

section("C5 CueRulesDB replaced as a whole", function()
  -- (P5) a module with its own store reads that saved variable; the others (and the Platform) CueRulesDB: every backing table is
  -- replaced by a new one holding a marker, and each view held from before must read its marker at once
  local probe = { qol = "qol", chat = "chat", bonus = "calculator", devassist = "idProbe", core = "drafts", reskin = "rsk" }
  local keep, new = {}, { CueRulesDB = { ui = { x = 2 } } }
  for m in pairs(XUI_ABSENT) do probe[m] = nil end   -- (a QA-branch module whose folder is absent has no store to replace)
  for m, k in pairs(probe) do
    local st = ns.SettingsStore(m)
    local var = (st.state == "own") and st.var or "CueRulesDB"
    new[var] = new[var] or {}
    new[var][k] = { marker = m }
  end
  for var in pairs(new) do keep[var] = rawget(_G, var); _G[var] = new[var] end
  local bad = {}
  for m, k in pairs(probe) do local t = V[m][k]; if not (type(t) == "table" and t.marker == m) then bad[#bad + 1] = m end end
  check("C5: every backing table (CueRulesDB, each module's own store) replaced as a whole: each view held from before reads the new one at once",
    #bad == 0 and V.platform.ui.x == 2, table.concat(bad, ", "))
  if XUI_ABSENT.reskin then
    R[#R + 1] = { "SKIP (QA-branch module absent: XayaUI_Reskin) C5: (P5) Reskin's view does not read the copy left in CueRulesDB.ui (it reads XayaUIReskinDB)", true }
  else
  check("C5: (P5) Reskin's view does not read the copy left in CueRulesDB.ui (it reads XayaUIReskinDB)",
    not rawequal(V.reskin.rsk, CueRulesDB.ui and CueRulesDB.ui.rsk))
  end
  check("C5: ns.SettingsReady() follows it", ns.SettingsReady() == true)
  CueRulesDB = nil
  check("C5: with no CueRulesDB, the platform view reads nil and SettingsReady is false (nothing created by reading)",
    V.platform.ui == nil and ns.SettingsReady() == false and rawget(_G, "CueRulesDB") == nil)
  for var, t in pairs(keep) do _G[var] = t end
end)

section("C6 hot-path caches", function()
  HOME("core").auraAlias = nil
  ns.SettingsChanged()
  check("C6: no alias learned: AuraAliasesOf answers nil", ns.AuraAliasesOf(62618) == nil)
  V.core.auraAlias = { [62618] = { [81782] = true } }
  check("C6: an alias written through the view is seen by the per-aura-read cache", ns.AuraAliasesOf(62618) and ns.AuraAliasesOf(62618)[81782] == true)
  local ep = ns.settingsEpoch
  V.core.auraAlias = V.core.auraAlias
  check("C6: writing the same table back (x = x or {}) does not move the epoch", ns.settingsEpoch == ep)
  local hv = HVAR("core")   -- (P5) XayaUI Rules' own store once it has one
  local old = _G[hv]
  _G[hv] = ns.Copy(old); _G[hv].auraAlias = {}
  ns.SettingsChanged()
  check("C6: CueRulesDB (P5: or XayaUI Rules' store) replaced and ns.SettingsChanged(): the cache reads the new (empty) aliases", ns.AuraAliasesOf(62618) == nil)
  _G[hv] = old
  ns.SettingsChanged()
  local ep2 = ns.settingsEpoch
  local part = ns.ProfilePartsByKey().qol
  part.apply(part.check({ cursorTrail = { marker = 8 } }), "merge", 1)
  check("C6: applying a profile part moves the epoch (hot caches look again)", ns.settingsEpoch > ep2)
end)
return R
end
'''

OFF_LUA = SETUP + r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local ns = setup(W, L)
check("D: XayaUI loaded alone (every feature addon off) and ns.Settings exists", ns and type(ns.Settings) == "function")
if not (ns and ns.Settings) then return R end
local before, nObj = ser(CueRulesDB), #W.objects
local evBefore = ser(W.registeredEvents())
local unknownBefore = ser(ns.SettingsUnknownKeys())
local same = true
for _, m in ipairs(MODULES) do
  local v = ns.Settings(m)
  if v == nil or not rawequal(v, ns.Settings(m)) then same = false end
  for _, k in ipairs(ns.SettingsKeys(m)) do local _ = v[k] end
end
check("D: ns.Settings gives the same view every time, for every module", same)
check("D: asking for every module's view and reading every key creates no saved key (CueRulesDB byte-identical)", ser(CueRulesDB) == before)
check("D: ... no frame", #W.objects == nObj, #W.objects - nObj)
check("D: ... no event registration", ser(W.registeredEvents()) == evBefore)
check("D: ... and no unknown key was asked for", ser(ns.SettingsUnknownKeys()) == unknownBefore)
return R
end
'''

MAP_LUA = SETUP + r'''
return function(W, L, PLAN)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local ns = setup(W, L)
check("E: ns.Settings exists", ns and type(ns.Settings) == "function")
if not (ns and ns.Settings) then return R end
check("E: a name that is not a module gives nil (XayaUI Nameplates keeps its own XayaUINameplatesDB)", ns.Settings("nameplates") == nil and ns.Settings("Platform") == nil)
local bad = {}
for _, m in ipairs(MODULES) do
  local v = ns.Settings(m)
  for _, k in ipairs(XUI_ABSENT[m] and {} or ns.SettingsKeys(m)) do   -- (a QA-branch module whose folder is absent has no store: skipped, printed by the runner)
    local at = ns.SettingsStoredAt(m, k)
    -- (P5) a module with its own store (ns.SettingsStore(m).state == "own") keeps every key at the top of that saved variable
    local st = ns.SettingsStore(m)
    local own = st and st.state == "own" and _G[st.var]
    local function home() if own then return own end if at == "ui." .. k then return CueRulesDB.ui end return CueRulesDB end
    local keep = home()[k]
    local s = { sentinel = m .. "." .. k }
    v[k] = s
    if not rawequal(home()[k], s) then bad[#bad + 1] = m .. "." .. k .. " write" end
    local s2 = { other = true }
    home()[k] = s2
    if not rawequal(v[k], s2) then bad[#bad + 1] = m .. "." .. k .. " read" end
    home()[k] = keep
  end
end
check("E: every module's view writes and reads exactly its store's <key> (P5: a module with its own store, e.g. XayaUIReskinDB.rsk; the others CueRulesDB.<key>)", #bad == 0, table.concat(bad, ", "))
check("E: Reskin's view keys are recorded where Reskin kept them in CueRulesDB (what the copy reads)", ns.SettingsStoredAt("reskin", "rsk") == "ui.rsk" and ns.SettingsStoredAt("reskin", "gm") == "ui.gm"
  and ns.SettingsStoredAt("reskin", "friendColors") == "ui.friendColors" and ns.SettingsStoredAt("qol", "cursorTrail") == "cursorTrail")
check("E: characterReskin is readable through both QoL's and Reskin's views (open question; see the debug log)",
  ns.SettingsStoredAt("qol", "characterReskin") == "characterReskin" and ns.SettingsStoredAt("reskin", "characterReskin") == "characterReskin")
local n0 = ns.SettingsUnknownKeys()["qol.notAKey"] or 0
local _ = ns.Settings("qol").notAKey
check("E: a key the module does not own still reads (nothing breaks in game) and is counted", (ns.SettingsUnknownKeys()["qol.notAKey"] or 0) == n0 + 1)
ns.SettingsStrict(true)
local ok = pcall(function() return ns.Settings("qol").chat2 end)
ns.SettingsStrict(false)
check("E: strict mode (tests): reading Chat's chat2 through the QoL view raises", ok == false)
local all = {}
for _, m in ipairs(MODULES) do for _, k in ipairs(ns.SettingsKeys(m)) do all[#all + 1] = m .. ":" .. k end end
table.sort(all)
EXPECT_KEYS = table.concat(all, " ")
return R
end
'''


def runtime(enabled_filter):
    folders = H.find_addons()
    enabled = [n for n in folders if enabled_filter(n)]
    L, world, loader = build(folders, enabled, {})
    L.execute("XUI_ABSENT = { %s }" % ", ".join("%s = true" % m for m in ABSENT))
    return L, world, loader


def main():
    folders = H.find_addons()
    if "--golden" in sys.argv:
        for tag, (h, errs, unknown, saved) in sessions(folders).items():
            print('    "%s": "%s",   # %d Lua errors' % (tag, h, len(errs)))
        return
    # G
    bad = guard(ROOT)
    check("G: no direct CueRulesDB use outside the Platform allow-list (and no module key touched directly in Platform files); (P5) no module's store named outside its own addon", not bad,
          "%d: %s" % (len(bad), "; ".join(bad[:12])))
    # B
    for tag, (h, errs, unknown, saved) in sessions(folders).items():
        if tag.startswith("all on") and ABSENT:
            # GOLDEN's "all on" hashes hold the saved data of every addon, Chat's, Reskin's and Nameplates' included: with those folders absent
            # the data can differ only by them, and a hash cannot be filtered. "core only" (no such addon on) still compares.
            skip(", ".join(ABSENT.values()), "B: %s: saved variables byte-identical to the old code's" % tag)
        else:
            check("B: %s: saved variables byte-identical to the old code's" % tag, h == GOLDEN.get(tag), h)
        check("B: %s: no Lua error" % tag, not errs, "; ".join(str(e)[:300] for e in errs[:3]))
        check("B: %s: no view was asked for a key its module does not own" % tag, unknown == "", unknown)
    # (P4) XayaUI Rules off (the Platform alone, and every other addon on): no Lua error, and nothing of the rules is saved
    for tag, en in (("Rules off, Platform only", {n for n in folders if n in ("XayaUI", "XayaUI_Media")}),
                    ("Rules off, every other addon on", {n for n in folders if n != "XayaUI_Rules"})):
        s1, e1, u1 = play(folders, en, {}, False)
        s2, e2, u2 = play(folders, en, s1, True)
        db = (s2.get("XayaUI") or {}).get("CueRulesDB") or {}
        check("B: %s: play session and reload: no Lua error" % tag, not e1 and not e2, "; ".join(str(e)[:300] for e in (e1 + e2)[:3]))
        check("B: %s: no view was asked for a key its module does not own" % tag, (u1 or "") == "" and (u2 or "") == "", (u1, u2))
        check("B: %s: nothing of XayaUI Rules is saved (no rules, groups, buff bars; no XayaUITalentDB)" % tag,
              not any(k in db for k in ("rules", "folders", "bars", "barGroup")) and "XayaUI_Rules" not in s2, sorted(db))
    # C
    L, world, loader = runtime(lambda n: n not in ("XayaUI_Nameplates",))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(HELD_LUA, world, loader)
    emit(res)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    check("C: no Lua error in the stand-in game", not errs, "; ".join(str(e)[:300] for e in errs[:3]))
    # D
    L, world, loader = runtime(lambda n: n in ("XayaUI", "XayaUI_Media"))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(OFF_LUA, world, loader)
    emit(res)
    # E
    L, world, loader = runtime(lambda n: True)
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(MAP_LUA, world, loader)
    emit(res)
    for m, a in ABSENT.items():
        if m in ("chat", "reskin"):
            skip(a, "E: %s's view writes and reads exactly its store's <key> (part of the every-module check above)" % m)
    owners = owner_lists(ROOT) or {}
    every = sorted(k for ks in owners.values() for k in ks)
    # (core 0.6.83, character pane split stage 2) characterToolkit is split too: XayaUI Bonus Features keeps the Stat Calculator panel's
    # keys, QoL the slot overlays' and tooltip lines' (Modules.lua LEGACY_SPLIT)
    check("E: no key is owned twice except the split ones: characterReskin (QoL's features, Reskin's look) and characterToolkit (Bonus's panel, QoL's overlays)",
          sorted(set(k for k in every if every.count(k) > 1)) == ["characterReskin", "characterToolkit"], every)
    failed = sum(1 for _, ok in results if not ok)
    print("%d checks, %d failed" % (len(results), failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
