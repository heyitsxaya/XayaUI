#!/usr/bin/env python3
"""The Stat Calculator loads on demand, and its settings travel in profiles (XayaUI Bonus Features 0.6.46, Options 0.6.108).
Xaya, REQUEST-LOG A24 #12 (her words): "if the addon or element within an addon is off it should not be read at all. this is true for
all addon  elements and should be detected once per reload"; A24 #13, the option she chose: "XayaUI_Bonus keeps only a tiny loader: the
on/off switch, settings page entry, /xui stats and the minimap row. The calculator code moves to XayaUI_Bonus_StatCalculator, shown in
the AddOns list under Bonus Features as 'load on demand'. Off means it is never read; on means it loads once per reload."; profiles:
"Yes, include them (Recommended)".
On the real addons of this tree in the stand-in game (tests/harness: every folder loaded as the game's loader does, load-on-demand
addons only through C_AddOns.LoadAddOn), with the saved variables carried over each /reload. What the player gets:
  L1  off at login (a fresh install): no file of XayaUI_Bonus_StatCalculator is read (the game's loader never runs one of its chunks);
      no statCalc / statModel service; Bonus Features > Stat Calculator is there with its switch and one line, no detailed options;
      /xui stats says it is off and how to turn it on; the minimap list leaves the row out; no LoadAddOn call was made.
  L2  turned on in the settings (the tick box on its row): the choice is saved, the game's "Reload now?" question names the Stat
      Calculator, the line says a /reload loads it, and nothing of it is read in this session; after the /reload it is loaded once at
      PLAYER_LOGIN, its detailed options are on the page, /xui stats opens the panel, the minimap row is in the list; the loader's frame
      then listens to no event.
  L3  login in combat (combat lockdown): it is NOT loaded while the lockdown lasts (no LoadAddOn call in combat); combat ends: loaded,
      once; then the loader listens to nothing.
  L4  turned off while loaded (/xui stats off): saved off, the line says it takes effect after a reload, and the calculator keeps
      working until the /reload (the row stays, the panel opens); after the /reload none of its files is read again.
  L5  on, but XayaUI_Bonus_StatCalculator switched off in the game's AddOns list: one line says so; no Lua error.
  P1  profiles, the calculator off and not loaded: Export offers Bonus Features; its part holds the Stat Calculator's settings (with the
      switch); Import of a profile with that part says nothing is missing (never "needs XayaUI Bonus Features" while it is installed).
  P2  importing it writes the Stat Calculator's settings (side, text size, spells, the switch) into XayaUIBonusDB.characterToolkit and
      asks for a reload.
  P3  an older profile string from qa-installer-branch (its Bonus Features part: data panels / tooltips / calculator; its QoL part with
      characterToolkit, where QA keeps the Stat Calculator's settings, plus Improved Character Display's keys): Bonus Features is
      offered and imports the Stat Calculator's settings; only the QoL part is listed as needing XayaUI QoL; Improved Character
      Display's keys are not written.
Negative control (run on an archive of c4ae19b, before this change, with this file copied in): 15 of 30 fail: there is no
XayaUI_Bonus_StatCalculator folder; L1 (the calculator's service and functions exist with it off: its files were read; the page has
no one-line form; /xui stats does not mention the reload), L2 (no reload question: the switch applied at once; not loaded at login
through LoadAddOn), L3 (no wait for the end of combat), L4 (off applied at once), L5 (no line), P1 (no Bonus Features profile part, so
P2-P3 do not run there).
In-game: the AddOns list's look, LoadAddOn's timing and the reload question are UNVERIFIED IN GAME
(docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md).
Run: python3 tests/statcalc_lod_run.py   (Lua 5.1 via lupa)"""
import copy, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

PART = "XayaUI_Bonus_StatCalculator"

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- every chunk the game's loader runs, by its name ("@Interface/AddOns/<folder>/<file>")
local chunks = {}
local rawLoadstring = loadstring
loadstring = function(src, name)
  if type(name) == "string" and name:find("/XayaUI_Bonus_StatCalculator/", 1, true) then chunks[#chunks + 1] = name end
  return rawLoadstring(src, name)
end
local loadCalls = {}
local rawLoadAddOn = C_AddOns.LoadAddOn
C_AddOns.LoadAddOn = function(n)
  if n == "XayaUI_Bonus_StatCalculator" then loadCalls[#loadCalls + 1] = { n = tostring(n), combat = W.combat } end
  return rawLoadAddOn(n)
end
local asked = {}
local rawShow = StaticPopup_Show
StaticPopup_Show = function(which, a1, ...) asked[#asked + 1] = { which, a1 }; return rawShow(which, a1, ...) end
local said = {}
local function hear() local ns0 = rawget(_G, "XayaUI_NS"); if ns0 then ns0.Print = function(m) said[#said + 1] = tostring(m) end end end
local function last() return said[#said] or "" end
local function loaded() return C_AddOns.IsAddOnLoaded("XayaUI_Bonus_StatCalculator") and true or false end
local function bonusFrameEvents()
  -- the loader's frame: made by XayaUI_Bonus/StatCalculatorLoader.lua (the only frame XayaUI_Bonus makes)
  local n = 0
  for _, o in ipairs(W.objects) do
    if rawget(o, "_bonusLoader") then for _ in pairs(o._events) do n = n + 1 end end
  end
  return n
end
local rawCreate = CreateFrame
CreateFrame = function(...)
  local f = rawCreate(...)
  local info = debug.getinfo(2, "S")
  if info and (info.source or ""):find("XayaUI_Bonus/StatCalculatorLoader.lua", 1, true) then rawset(f, "_bonusLoader", true) end
  return f
end
local function rowListed()
  local ns0 = rawget(_G, "XayaUI_NS")
  for _, e in ipairs(ns0.Launchers and ns0.Launchers() or {}) do
    if e[1] == "stats" then return (type(e.available) ~= "function") or (e.available() and true or false), true end
  end
  return false, false
end
local function page() local ns0 = rawget(_G, "XayaUI_NS"); local p = ns0.BuildSettingsPages and ns0.BuildSettingsPages("bonus") or {}; return p.statcalc end
if not rawget(_G, "CharacterFrame") then rawset(_G, "CharacterFrame", CreateFrame("Frame", "CharacterFrame", UIParent)) end
CharacterFrame:Hide()
'''

LOGIN = r'''
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.2, 10)
local ns = rawget(_G, "XayaUI_NS")
hear()
'''

# L1 + L2 (first session: fresh, off; turned on in the settings)
S_OFF = r'''
return function(W, L)
''' + COMMON + LOGIN + r'''
check("L1 off at login: no file of XayaUI_Bonus_StatCalculator is read, it is not loaded, and LoadAddOn was not called",
  #chunks == 0 and not loaded() and #loadCalls == 0, table.concat(chunks, ", "))
check("L1 ...no statCalc / statModel service and none of its functions exist", ns.Service("statCalc") == nil and ns.Service("statModel") == nil
  and ns.StatCalc_Apply == nil and ns.StatModel == nil)
check("L1 ...the loader's frame listens to no event once the login is past", bonusFrameEvents() == 0, bonusFrameEvents())
local p = page()
local noteText = p and p.args and p.args.note and (type(p.args.note.name) == "function" and p.args.note.name() or p.args.note.name)
check("L1 Bonus Features > Stat Calculator is there with its switch (off) and one line, no detailed options",
  p ~= nil and p.name == "Stat Calculator" and p.xuiSwitch and p.xuiSwitch.get() == false and p.args.panelPart == nil and p.args.spells == nil
  and type(noteText) == "string" and noteText:find("\n", 1, true) == nil, noteText)
ns.RunCommand("stats", "")
check("L1 /xui stats says it is off and how to turn it on", last():find("Stat Calculator is off", 1, true) ~= nil and last():find("/reload", 1, true) ~= nil, last())
local avail, reg = rowListed()
check("L1 the minimap list's Stat Calculator row is registered and left out of the list", reg and not avail)
-- L2 turned on with the tick box on its row
check("L2 setup: the settings window loads", ns.LoadOptions and ns.LoadOptions())
p = page()
p.xuiSwitch.set({}, true)
W.tick(0.1, 3)
check("L2 turned on: the choice is saved (the tick box shows it on)", p.xuiSwitch.get() == true and XayaUIBonusDB.characterToolkit.enabled == true)
check("L2 ...the game's \"Reload now?\" question is asked once, naming the Stat Calculator", #asked == 1 and asked[1][1] == "XAYAUI_RESKIN_RELOAD"
  and asked[1][2] == "Stat Calculator", #asked)
p = page()
noteText = p and p.args.note and p.args.note.name()
check("L2 ...the page's line says a /reload loads it", type(noteText) == "string" and noteText:find("/reload", 1, true) ~= nil and p.args.panelPart == nil, noteText)
W.fire("PLAYER_ENTERING_WORLD", false, true); W.tick(0.2, 10)
check("L2 ...and nothing of it is read in this session", #chunks == 0 and not loaded() and #loadCalls == 0, #chunks)
return R
end
'''

# L2 after the reload + L4 (turned off while loaded)
S_ON = r'''
return function(W, L)
''' + COMMON + LOGIN + r'''
check("L2 after the /reload: loaded once, at PLAYER_LOGIN, out of combat (its three files read once)", loaded() and #loadCalls == 1
  and loadCalls[1].n == "XayaUI_Bonus_StatCalculator" and loadCalls[1].combat == false and #chunks == 3, #loadCalls .. " calls, " .. #chunks .. " chunks")
check("L2 ...the loader's frame then listens to no event", bonusFrameEvents() == 0, bonusFrameEvents())
check("L2 ...the page has its detailed options (Panel, Spell Math) and the same switch", (function()
  local p = page(); return p and p.args.panelPart ~= nil and p.args.spells ~= nil and p.xuiSwitch and p.xuiSwitch.get() == true end)())
ns.RunCommand("stats", "")
W.tick(0.1, 3)
local panel = rawget(_G, "XayaUIStatCalculator")
check("L2 .../xui stats opens the panel and the minimap row is in the list", panel ~= nil and panel:IsShown() and (rowListed()))
-- L4 turned off while loaded
ns.RunCommand("stats", "off")
check("L4 /xui stats off: saved off; it says it takes effect after a reload", XayaUIBonusDB.characterToolkit.enabled == false
  and last():find("takes effect after a reload", 1, true) ~= nil, last())
W.tick(0.1, 3)
check("L4 ...the calculator keeps working until the /reload (the panel stays open, the row stays)", panel:IsShown() and (rowListed()))
ns.RunCommand("stats", ""); W.tick(0.1, 2); ns.RunCommand("stats", ""); W.tick(0.1, 2)
check("L4 ...and still opens and closes with /xui stats", panel:IsShown())
return R
end
'''

# L4 after the reload: off again
S_OFF2 = r'''
return function(W, L)
''' + COMMON + LOGIN + r'''
check("L4 after the /reload: none of its files is read, it is not loaded, no LoadAddOn call", #chunks == 0 and not loaded() and #loadCalls == 0, #chunks)
local avail = rowListed()
check("L4 ...the minimap row is left out of the list", not avail)
return R
end
'''

# L3 login in combat
S_COMBAT = r'''
return function(W, L)
''' + COMMON + r'''
L.startup()
W.enterCombat()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.2, 10)
local ns = rawget(_G, "XayaUI_NS")
hear()
check("L3 login in combat lockdown: not loaded, no LoadAddOn call, none of its files read", not loaded() and #loadCalls == 0 and #chunks == 0, #loadCalls)
check("L3 ...the loader listens to the end of combat only", bonusFrameEvents() == 1, bonusFrameEvents())
W.tick(1, 5)
W.leaveCombat(); W.tick(0.2, 5)
check("L3 combat ends: loaded once, out of combat", loaded() and #loadCalls == 1 and loadCalls[1].combat == false and #chunks == 3, #loadCalls)
check("L3 ...then the loader listens to nothing", bonusFrameEvents() == 0, bonusFrameEvents())
W.enterCombat(); W.leaveCombat(); W.tick(0.2, 3)
check("L3 ...a later combat loads nothing again", #loadCalls == 1 and #chunks == 3, #loadCalls)
return R
end
'''

# L5 on, but the load-on-demand addon switched off in the AddOns list
S_DISABLED = r'''
return function(W, L)
''' + COMMON + r'''
L.startup()
local ns = rawget(_G, "XayaUI_NS")
hear()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.2, 10)
local found = false
for _, l in ipairs(said) do if l:find("switched off in the game's AddOns list", 1, true) and l:find("XayaUI Bonus Features: Stat Calculator", 1, true) then found = true end end
check("L5 on, but XayaUI Bonus Features: Stat Calculator switched off in the AddOns list: one line says so", found and not loaded() and #chunks == 0, table.concat(said, " | "))
return R
end
'''

# P1-P3 profiles, the calculator off (not loaded)
S_PROFILE = r'''
return function(W, L, QA)
''' + COMMON + LOGIN + r'''
check("P setup: the settings window loads, the calculator is not loaded", ns.LoadOptions and ns.LoadOptions() and not loaded())
local P = ns.Profile
local part = P and P.BY_KEY and P.BY_KEY.bonus
check("P1 Export offers Bonus Features while the Stat Calculator is off and not loaded", part ~= nil and part.label == "Bonus Features")
if not part then return R end
local snap = P.Snapshot({ bonus = true }, "mine")
local ct = snap.parts.bonus and snap.parts.bonus.characterToolkit
check("P1 ...its part holds the Stat Calculator's settings, with the switch (side left, text size 13, her spell, off)",
  type(ct) == "table" and ct.side == "left" and ct.fontSize == 13 and type(ct.spells) == "table" and ct.spells[1] and ct.spells[1].id == 263642
  and ct.enabled == false, ct and (tostring(ct.side) .. " " .. tostring(ct.fontSize) .. " " .. tostring(ct.enabled)))
check("P1 ...and says which addon reads it (part information: XayaUI_Bonus, format 2)", snap.partInfo and snap.partInfo.bonus
  and snap.partInfo.bonus.module == "XayaUI_Bonus" and snap.partInfo.bonus.v == 2)
-- P2 import it with other values
snap.parts.bonus.characterToolkit.side = "right"; snap.parts.bonus.characterToolkit.fontSize = 15; snap.parts.bonus.characterToolkit.enabled = true
local data = P.Check(snap)
check("P2 Import: nothing is missing (never \"needs XayaUI Bonus Features\" while it is installed); Bonus Features is offered",
  #P.Missing(data) == 0 and #P.Held(data) == 1 and P.Held(data)[1].key == "bonus", #P.Missing(data))
local nAsk = #asked
local res = P.Apply(data)
local c = XayaUIBonusDB.characterToolkit
check("P2 ...the Stat Calculator's settings are written to XayaUIBonusDB.characterToolkit (right, 15, on) and a reload is asked for",
  c.side == "right" and c.fontSize == 15 and c.enabled == true and res.reload == true and #res.skipped == 0, tostring(c.side) .. " " .. tostring(c.fontSize))
-- P3 an older string from qa-installer-branch
local qa = QA
local data3 = P.Check(qa)
local held, missing = {}, {}
for _, x in ipairs(P.Held(data3)) do held[#held + 1] = x.key end
for _, x in ipairs(P.Missing(data3)) do missing[#missing + 1] = x.title end
check("P3 an older QA string: Bonus Features is offered; only the QoL part needs another addon (XayaUI QoL), never Bonus Features",
  table.concat(held, ",") == "bonus" and table.concat(missing, ",") == "XayaUI QoL", table.concat(held, ",") .. " / " .. table.concat(missing, ","))
local res3 = P.Apply(data3)
c = XayaUIBonusDB.characterToolkit
check("P3 ...its Stat Calculator settings (from QA's QoL part) are imported: side left, text size 12, height 820, its spell",
  c.side == "left" and c.fontSize == 12 and c.heightLarge == 820 and c.spells and c.spells[1] and c.spells[1].id == 100780, tostring(c.side) .. " " .. tostring(c.fontSize))
check("P3 ...Improved Character Display's keys are not written (overlays, ovIlvl)", c.overlays == nil and c.ovIlvl == nil)
local skipped = table.concat(res3.skipped or {}, ",")
check("P3 ...the import reports only XayaUI QoL as skipped", skipped == "XayaUI QoL", skipped)
return R
end
'''

HER = {"enabled": False, "panel": True, "side": "left", "fontSize": 13, "spells": [{"id": 263642, "base": "ap"}], "heightLarge": 900}
QA_STRING = {"v": 1, "name": "qa", "addonVersion": "0.6.83", "parts": {
    "bonus": {"dataPanels": {"enabled": True}, "tooltips": {"enabled": True}, "calculator": {"enabled": True}},
    "qol": {"cursorTrail": {"enabled": True}, "characterToolkit": {"enabled": True, "panel": True, "side": "left", "fontSize": 12,
                                                                 "heightLarge": 820, "spells": [{"id": 100780, "base": "ap"}],
                                                                 "overlays": True, "ovIlvl": True}}},
    "partInfo": {"qol": {"v": 3, "module": "XayaUI_QoL", "title": "XayaUI QoL", "label": "QoL"}}}


def store_on(on, extra=None):
    ct = {"enabled": on}
    ct.update(extra or {})
    return {"XayaUI_Bonus": {"XayaUIBonusDB": {"storeVersion": 1, "characterToolkit": ct}}}


def session(src, saved, enabled=None, arg=None):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    en = {k: True for k in folders if enabled is None or enabled(k)}
    opts = H.to_lua(L, {"folders": folders, "enabled": en})
    opts["saved"] = H.savedvars(L).Load(saved) if isinstance(saved, str) else H.to_lua(L, saved or {})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    res = L.eval("function(src, W, Ld, a) return loadstring(src)()(W, Ld, a) end")(src, world, loader, H.to_lua(L, arg) if arg is not None else None)
    out, _ = loader.logout()
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return results, H.savedvars(L).Serialize(out), errs


def main():
    bad = n = 0
    errs = []
    n += 1
    if not os.path.isdir(os.path.join(H.ROOT, PART)):
        bad += 1
        print("FAIL there is a %s folder (the Stat Calculator's load-on-demand addon)" % PART)
    else:
        print("PASS there is a %s folder (the Stat Calculator's load-on-demand addon)" % PART)

    def report(tag, results, e):
        nonlocal bad, n
        for name, ok in results:
            n += 1
            print(("PASS " if ok else "FAIL ") + "[%s] %s" % (tag, name))
            if not ok:
                bad += 1
        errs.extend("[%s] %s" % (tag, x) for x in e)

    r, saved1, e = session(S_OFF, {})
    report("off, then turned on", r, e)
    r, saved2, e = session(S_ON, saved1)
    report("on after the reload, then turned off", r, e)
    r, _, e = session(S_OFF2, saved2)
    report("off after the reload", r, e)
    r, _, e = session(S_COMBAT, store_on(True))
    report("login in combat", r, e)
    r, _, e = session(S_DISABLED, store_on(True), enabled=lambda k: k != PART)
    report("AddOns list", r, e)
    r, _, e = session(S_PROFILE, store_on(False, copy.deepcopy({k: v for k, v in HER.items() if k != "enabled"})), arg=copy.deepcopy(QA_STRING))
    report("profiles", r, e)
    n += 1
    if errs:
        bad += 1
        print("FAIL no Lua errors in the stand-in game  [%s]" % errs[0][:500])
    else:
        print("PASS no Lua errors in the stand-in game")
    print("%d checks, %d failed" % (n, bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
