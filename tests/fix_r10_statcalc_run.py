#!/usr/bin/env python3
"""Bundle 1 round 10: the Stat Calculator loads at its first open, its switch acts at once, and nothing of it reopens after combat.
Xaya's answers (docs/process/REQUEST-LOG.md, verbatim):
  SD-94  "if window is not open, it shouldn't use memory"
  SD-105 "Load at first open (Recommended)": XayaUI_Bonus_StatCalculator is not loaded at login; it loads the first time its panel opens
         (the minimap row, /xui stats, or the character window opening while the panel was left open: docked). Off before the first
         open: nothing of it is read. Off after it loaded: inert at once, its memory freed at the next /reload. A close lets go of its
         stat model, layout records and caches; the test-only layout records are not built in normal play.
  SD-86  "Bonus itself as a module requires a reload. Only require a reload for an individual item that might require a reload."
  SD-118 "All parts, say how (Recommended)": "/xui stats on" no longer exists; while off, every /xui stats word prints core's one line.
  SD-100 "stat calculator isn't allowed to be open during combat"; SD-102 "Don't reappear".
  SD-103 "unsure, circle back to this within the broader scope of addon load demands" (PARKED): the settings window never loads it.
On the real addons of this tree in the stand-in game (tests/harness), what the player sees and gets:
  A  fresh install (off): none of its files read, no frame, no hook, no timer; every /xui stats word (including "on") prints core's one
     line; the character window opening and the minimap list load nothing; the settings window opens without loading it, its page
     shows the switch and one line.
  B  the REAL tick box on the Stat Calculator's row in the settings window, clicked on: saved on, no "Reload now?" question, nothing of
     it read yet, the drawn page line says its options appear after the first open (not stale), the loader's one hook is in, no
     event, no timer; /xui stats is listed in /xui help.
  C  first open from the minimap row: loaded once (its three files), the panel open on its own; the open settings window redraws with
     the detailed options (Panel, Spell Math). Normal play builds no layout records (the panel holds none) until a test reader asks.
     Closing the panel lets go of the stat model.
  D  the REAL tick box clicked off while loaded: one chat line ("... Its memory is freed at your next /reload."), no reload question,
     the panel hidden, no event left; the character window opening does no work in XayaUI_Bonus_StatCalculator beyond the raw switch
     read (counted in Lua instructions); /xui stats prints core's off line.
  E  saved on, panel left open: the character window opening is the first open (loaded, docked); in combat it loads nothing and after
     combat nothing loads or shows (SD-102); a later opening docks it.
  F  open on its own, combat starts: hidden, the end of combat reopens nothing and builds no model; the character window opened in combat
     does not bring it back after combat; reopening it afterwards docks it. In combat only PLAYER_REGEN_ENABLED is heard; closed, nothing.
  G  while on: /xui stats status (not loaded yet / loaded), options, off (typed: one line; the open settings page redraws at once).
  H  a profile import that switches it off (loaded) makes it inert at once with the same line; one that switches it on installs the hook.
In-game behaviour is UNVERIFIED IN GAME: the harness is a stand-in for the game (V25). Instruction counts are stand-in numbers.
Run: python3 tests/fix_r10_statcalc_run.py   (Lua 5.1 via lupa; slow: the stand-in settings window redraws take seconds)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
local chunks = {}
local rawLoadstring = loadstring
loadstring = function(src, name)
  if type(name) == "string" and name:find("/XayaUI_Bonus_StatCalculator/", 1, true) then chunks[#chunks + 1] = name end
  return rawLoadstring(src, name)
end
local loadCalls = {}
local rawLoadAddOn = C_AddOns.LoadAddOn
C_AddOns.LoadAddOn = function(n)
  if n == "XayaUI_Bonus_StatCalculator" then loadCalls[#loadCalls + 1] = { combat = W.combat } end
  return rawLoadAddOn(n)
end
local asked = {}
local rawShow = StaticPopup_Show
StaticPopup_Show = function(which, a1, ...) asked[#asked + 1] = { which, a1 }; return rawShow(which, a1, ...) end
-- frames, hooks and timers made while a file of XayaUI_Bonus or XayaUI_Bonus_StatCalculator is on the call stack (innermost XayaUI file)
local function fromBonus()
  for lv = 3, 60 do
    local info = debug.getinfo(lv, "S")
    if not info then break end
    local f = (info.source or ""):match("Interface/AddOns/(XayaUI[%w_]*)/")
    if f then return f == "XayaUI_Bonus" or f == "XayaUI_Bonus_StatCalculator", f end
  end
  return false
end
local timers, hookN = 0, 0
local rawCreate = CreateFrame
CreateFrame = function(...) local f = rawCreate(...); if fromBonus() then rawset(f, "_bonus", true) end; return f end
for _, k in ipairs({ "After", "NewTimer", "NewTicker" }) do
  local raw = C_Timer[k]
  C_Timer[k] = function(...) if fromBonus() then timers = timers + 1 end; return raw(...) end
end
local rawHookSecure = hooksecurefunc
hooksecurefunc = function(...) if fromBonus() then hookN = hookN + 1 end; return rawHookSecure(...) end
local function mine() local t = {}; for _, o in ipairs(W.objects) do if rawget(o, "_bonus") then t[#t + 1] = o end end; return t end
local function events()
  local list = {}
  for _, o in ipairs(mine()) do for e in pairs(o._events) do list[#list + 1] = e end end
  table.sort(list)
  return table.concat(list, ",")
end
-- the character window, made before the addons load (the game's own windows exist then); its OnShow hooks counted
rawset(_G, "CharacterFrame", rawCreate("Frame", "CharacterFrame", UIParent)); CharacterFrame:Hide()
local rawHookScript = CharacterFrame.HookScript
local cfHooks = 0
CharacterFrame.HookScript = function(self, script, fn, ...) if script == "OnShow" then cfHooks = cfHooks + 1 end; return rawHookScript(self, script, fn, ...) end
local said = {}
local function hear() local ns0 = rawget(_G, "XayaUI_NS"); if ns0 then ns0.Print = function(m) said[#said + 1] = tostring(m) end end end
local function saidSince(n) local t = {}; for i = n + 1, #said do t[#t + 1] = said[i] end; return t end
local function loaded() return C_AddOns.IsAddOnLoaded("XayaUI_Bonus_StatCalculator") and true or false end
local function panel() return rawget(_G, "XayaUIStatCalculator") end
local function shown() local p = panel(); return p ~= nil and p:IsShown() end
local function launcher()
  local ns0 = rawget(_G, "XayaUI_NS")
  for _, e in ipairs(ns0.Launchers and ns0.Launchers() or {}) do if e[1] == "stats" then return e end end
end
local function rowAvailable() local e = launcher(); return e ~= nil and (type(e.available) ~= "function" or (e.available() and true or false)) end
local function clickRow() local e = launcher(); if e and type(e[4]) == "function" then e[4]() end end
local OFF = "The Stat Calculator is off. Turn it on in /xui > Bonus Features."
local FREED = "The Stat Calculator is off. Its memory is freed at your next /reload."
-- Lua instructions run inside XayaUI_Bonus_StatCalculator's files while fn runs (stand-in count)
local function calcCost(fn)
  local n = 0
  debug.sethook(function()
    local info = debug.getinfo(2, "S")
    if info and (info.source or ""):find("XayaUI_Bonus_StatCalculator/", 1, true) then n = n + 1 end
  end, "", 1)
  local ok, err = pcall(fn)
  debug.sethook()
  if not ok then error(err, 0) end
  return n
end
'''

LOGIN = r'''
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.2, 10)
local ns = rawget(_G, "XayaUI_NS")
hear()
'''

# the settings window helpers (as tests/sidebar_switches_run.py drives the stand-in window)
WINDOW = r'''
local reg, ACD
local function root() return ACD and ACD.OpenFrames and ACD.OpenFrames["CueRules"] end
local function findW(w, pred)
  if not w then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local f = findW(c, pred); if f then return f end end
end
local function tree(tab) return findW(root(), function(w) local u = w.type == "TreeGroup" and w:GetUserDataTable(); return u and u.path and u.path[1] == tab and #u.path == 1 end) end
local function row(tab, uv) local t = tree(tab); for _, b in ipairs(t and t.buttons or {}) do if b:IsShown() and b.uniquevalue == uv then return b end end end
local function box(tab, uv) local b = row(tab, uv); local x = b and b.xuiSwitchBox; return (x and x:IsShown()) and x or nil end
local function settle(steps)
  W.tick(0.05, steps or 6)
  local t = tree("bonus"); local f = t and t.treeframe and t.treeframe:GetScript("OnSizeChanged")
  if f then t.xuiLines = nil; f(t.treeframe) end
end
local builds = 0
local function openWindow()
  ns.LoadOptions(); W.tick(0.1, 3)
  ns = rawget(_G, "XayaUI_NS"); hear()
  reg, ACD = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
  local orig = reg.tables["CueRules"]
  local lastT
  reg.tables["CueRules"] = function(...) local t = orig(...); if t ~= lastT then builds = builds + 1 end; lastT = t; return t end
  CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
  if not root() then pcall(ns.ToggleUI) end; settle()   -- (open it unless something already did)
  ACD:SelectGroup("CueRules", "bonus", "statcalc"); settle()
end
local function click(v)   -- the game flips the check box's tick, then runs its OnClick; then the next frames
  local x = box("bonus", "statcalc"); if not x then return false end
  x:SetChecked(v); x:Click("LeftButton")
  settle()
  return true
end
-- every label the open window draws now (the Stat Calculator page's line is one)
local function drawnText(s) return findW(root(), function(w) return w.type == "Label" and w.label and (w.label:GetText() or ""):find(s, 1, true) ~= nil end) ~= nil end
local function partRows() return row("bonus", "statcalc\001panelPart") ~= nil, row("bonus", "statcalc\001spells") ~= nil end
'''

# A + B + C + D + G (part): a fresh install, the settings window open
S_FRESH = r'''
return function(W, L)
''' + COMMON + LOGIN + WINDOW + r'''
section("A", function()
check("A off at login: none of its files read, not loaded, no LoadAddOn call", #chunks == 0 and not loaded() and #loadCalls == 0, #chunks)
check("A ...XayaUI_Bonus made no frame, no hook on the character window, no timer, no event", #mine() == 0 and cfHooks == 0 and hookN == 0
  and timers == 0 and events() == "", #mine() .. " frames, " .. cfHooks .. " hooks, " .. timers .. " timers, events " .. events())
for _, w in ipairs({ "", "on", "options", "status", "off", "help" }) do
  local n = #said
  ns.RunCommand("stats", w)
  local got = saidSince(n)
  check(("A /xui stats %s while off: exactly core's one line, nothing loaded"):format(w == "" and "(no word)" or w),
    #got == 1 and got[1] == OFF and not loaded() and #loadCalls == 0, table.concat(got, " / "))
end
check("A ...\"/xui stats on\" did not turn it on (SD-118: it no longer exists)", XayaUIBonusDB.characterToolkit == nil or XayaUIBonusDB.characterToolkit.enabled ~= true)
do
  local listedOff = false
  for _, l in ipairs(ns.CommandHelp and ns.CommandHelp() or {}) do if l:find("/xui stats", 1, true) then listedOff = true end end
  check("A ...core's help list leaves /xui stats out while it is off", not listedOff)
end
CharacterFrame:Show(); W.tick(0.1, 2); CharacterFrame:Hide()
check("A the character window opening loads nothing; the minimap row is left out of the list", not loaded() and #loadCalls == 0 and not rowAvailable() and launcher() ~= nil)
end)
section("A/B window", function()
openWindow()
check("A the settings window opens without loading it (SD-103 parked: the window never loads it)", root() ~= nil and not loaded() and #loadCalls == 0)
check("A ...its page shows the switch (unticked) and one line, no detailed options", box("bonus", "statcalc") ~= nil and box("bonus", "statcalc"):GetChecked() == false
  and drawnText("Off. Turn it on, then open it once, to see its options here.") and not (partRows()))
-- B the real tick box, on
local nAsk = #asked
check("B the real tick box on the Stat Calculator's row is clickable", click(true))
check("B ticked on: saved on, no \"Reload now?\" question", XayaUIBonusDB.characterToolkit.enabled == true and #asked == nAsk, #asked - nAsk)
check("B ...nothing of it is read yet (it loads at its first open)", not loaded() and #loadCalls == 0 and #chunks == 0)
check("B ...the drawn page says its options appear after the first open (the redrawn page is not stale)",
  drawnText("Its options appear here after you first open the Stat Calculator.") and not drawnText("Off. Turn it on"))
check("B ...the box shows it ticked", box("bonus", "statcalc") and box("bonus", "statcalc"):GetChecked() == true)
check("B ...the loader's one hook on the character window is in; no frame, no event, no timer", cfHooks == 1 and #mine() == 0 and events() == "" and timers == 0,
  cfHooks .. " hooks, " .. #mine() .. " frames, " .. timers .. " timers")
check("B ...the minimap row is in the list now (a click on it is the first open)", rowAvailable())
local help = ns.CommandHelp and ns.CommandHelp() or {}
local listed = false
for _, l in ipairs(help) do if l == "/xui stats [options|status|off] (Stat Calculator panel)" then listed = true end end
check("B .../xui help lists /xui stats [options|status|off] while it is on (SD-118; core's help list, ns.CommandHelp)", listed, table.concat(help, " | "))
-- G status before the first open
local n = #said
ns.RunCommand("stats", "status")
check("G /xui stats status before the first open: one line, on and not loaded yet; nothing loaded",
  #saidSince(n) == 1 and said[#said] == "Stat Calculator: on, not loaded yet (it loads the first time you open it)." and not loaded(), said[#said])
end)
section("C", function()
local b0 = builds
clickRow(); W.tick(0.1, 3); settle()
check("C first open from the minimap row: loaded once, out of combat, its three files read once", loaded() and #loadCalls == 1 and loadCalls[1].combat == false and #chunks == 3,
  #loadCalls .. " calls, " .. #chunks .. " chunks")
check("C ...the panel is open on its own", shown() and panel().standalone == true)
check("C ...the open settings window redrew with a fresh tree, and the page lists Panel and Spell Math", builds > b0 and partRows(), (builds - b0) .. " builds")
check("C normal play: the panel drew without layout records (none built: SD-105)", rawget(panel(), "model") ~= nil and rawget(panel(), "layoutRecs") == nil)
local d = ns.StatCalc_Drawn()
check("C ...a test reader asking for them turns them on: the records are there now", d and type(d.layout) == "table" and #d.layout > 0, d and d.layout and #d.layout)
clickRow(); W.tick(0.1, 2)
check("C closing the panel lets go of its stat model and layout records", not shown() and rawget(panel(), "model") == nil and rawget(panel(), "layoutRecs") == nil)
check("C ...and closed, its event frame listens to nothing", events() == "", events())
end)
section("D", function()
clickRow(); W.tick(0.1, 2)
check("D setup: open again", shown())
local nAsk, n = #asked, #said
check("D the real tick box clicked off while loaded", click(false))
local got = saidSince(n)
check("D ...one chat line: its memory is freed at the next /reload; no reload question", #got == 1 and got[1] == FREED and #asked == nAsk, table.concat(got, " / "))
check("D ...inert at once: the panel hidden, no event, no timer", not shown() and events() == "" and timers == 0, events())
check("D ...the drawn page hides Panel and Spell Math", not (partRows()))
local c = XayaUIBonusDB.characterToolkit
c.panelOpen = true
local cost = calcCost(function() CharacterFrame:Show(); CharacterFrame:Hide() end)
check(("D ...the character window opening (panel left open) does no work beyond the raw switch read: %d instructions in its files, at most 60 (stand-in)"):format(cost),
  cost <= 60 and not shown(), cost)
local n2 = #said
ns.RunCommand("stats", "")
check("D .../xui stats prints core's one off line", #saidSince(n2) == 1 and said[#said] == OFF, said[#said])
check("D ...no Lua error so far", #W.errors == 0, W.errors[1])
end)
return R
end
'''

# E + F + G: saved on (her install), panel left open (the default)
S_ON = r'''
return function(W, L)
''' + COMMON + LOGIN + WINDOW + r'''
local dbg
section("E", function()
check("E saved on: not loaded at login (SD-105), the loader's one hook in, no frame, no event, no timer", not loaded() and #chunks == 0 and cfHooks == 1
  and #mine() == 0 and timers == 0, cfHooks .. " hooks, " .. #mine() .. " frames")
W.enterCombat()
CharacterFrame:Show(); W.tick(0.1, 3)
check("E the character window opened in combat: nothing loads, nothing shows", not loaded() and #loadCalls == 0 and not shown())
CharacterFrame:Hide()
W.leaveCombat(); W.tick(0.2, 5)
check("E ...combat ends: nothing loads or shows (SD-102)", not loaded() and #loadCalls == 0 and not shown())
CharacterFrame:Show(); W.tick(0.1, 3)
check("E the character window opens out of combat: the first open, loaded once and docked beside it", loaded() and #loadCalls == 1 and shown()
  and panel().standalone == false, #loadCalls)
dbg = ns.Service("statCalcDebug")
CharacterFrame:Hide(); W.tick(0.1, 2)
check("E ...the window closed: the docked panel closes with it, its model let go", not shown() and rawget(panel(), "model") == nil)
end)
section("F", function()
local sc = ns.Service("statCalc")
ns.RunCommand("stats", ""); W.tick(0.1, 2)
check("F setup: /xui stats opens it on its own", shown() and panel().standalone == true)
W.enterCombat(); W.tick(0.1, 2)
check("F combat starts: hidden; only PLAYER_REGEN_ENABLED is heard", not shown() and events() == "PLAYER_REGEN_ENABLED", events())
local n = #said
ns.RunCommand("stats", ""); clickRow(); sc.Toggle()
check("F in combat: /xui stats, the minimap row and Toggle open nothing and say nothing; the row is left out", not shown() and #saidSince(n) == 0 and not rowAvailable())
local b0 = dbg.Builds()
CharacterFrame:Show(); W.tick(0.1, 2)
W.leaveCombat(); W.tick(0.2, 10)
check("F combat ends: nothing reopens (on its own or docked with the window opened in combat), no model built (SD-102)",
  not shown() and dbg.Builds() == b0, dbg.Builds() - b0)
check("F ...closed after combat, its event frame listens to nothing", events() == "", events())
check("F ...and the stat model it had when combat started is let go by the end of combat (SD-105; kept through the fight so combat start stays one Hide, SD-112)",
  rawget(panel(), "model") == nil and rawget(panel(), "layoutRecs") == nil)
CharacterFrame:Hide(); CharacterFrame:Show(); W.tick(0.1, 2)
check("F reopening the character window after combat docks it (its open state was kept)", shown() and panel().standalone == false)
CharacterFrame:Hide()
end)
section("G", function()
local n = #said
ns.RunCommand("stats", "status")
check("G /xui stats status once loaded: the calculator's line", #saidSince(n) == 1 and said[#said]:find("^Stat Calculator: on, panel on") ~= nil, said[#said])
ns.RunCommand("stats", "options"); W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS"); hear()
reg, ACD = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
settle()
local st = ACD:GetStatusTable("CueRules", { "bonus" })
check("G /xui stats options opens the settings window on the Stat Calculator page", root() ~= nil and st and st.groups and st.groups.selected == "statcalc",
  st and st.groups and st.groups.selected)
local pr, sr = partRows()
check("G setup: the open page lists Panel and Spell Math (loaded, on)", pr and sr)
local fresh = 0
local orig = reg.tables["CueRules"]
reg.tables["CueRules"] = function(...) fresh = fresh + 1; return orig(...) end
n = #said
ns.RunCommand("stats", "off"); settle()
check("G /xui stats off (loaded): one line, its memory is freed at the next /reload; saved off; no reload question", #saidSince(n) == 1 and said[#said] == FREED
  and XayaUIBonusDB.characterToolkit.enabled == false and #asked == 0, table.concat(saidSince(n), " / "))
pr, sr = partRows()
check("G ...the open settings page redraws at once with a fresh tree: Panel and Spell Math are gone from it (never stale)", fresh >= 1 and not pr and not sr,
  fresh .. " builds, rows " .. tostring(pr) .. "/" .. tostring(sr))
check("G ...inert: no event", events() == "", events())
local c = XayaUIBonusDB.characterToolkit
c.panelOpen = true
CharacterFrame:Hide()
local cost = calcCost(function() CharacterFrame:Show(); CharacterFrame:Hide() end)
check(("G ...switched off after it loaded, the character window opening (panel left open) does no work beyond the raw switch read: %d instructions in its files, at most 60 (stand-in)"):format(cost),
  cost <= 60 and not shown(), cost)
end)
return R
end
'''

# H: profile import, the calculator loaded
S_IMPORT = r'''
return function(W, L)
''' + COMMON + LOGIN + r'''
section("H", function()
ns.RunCommand("stats", ""); W.tick(0.1, 2)
check("H setup: opened (loaded)", loaded() and shown())
ns.LoadOptions(); W.tick(0.1, 2); ns = rawget(_G, "XayaUI_NS"); hear()
local P = ns.Profile
local snap = P.Snapshot({ bonus = true }, "mine")
snap.parts.bonus.characterToolkit.enabled = false
local n = #said
P.Apply(P.Check(snap)); W.tick(0.1, 2)
check("H a profile import that switches it off: inert at once (panel hidden, no event) with the one memory line", not shown() and events() == ""
  and XayaUIBonusDB.characterToolkit.enabled == false and table.concat(saidSince(n), "\n"):find(FREED, 1, true) ~= nil, table.concat(saidSince(n), " / "))
end)
return R
end
'''

S_IMPORT_ON = r'''
return function(W, L)
''' + COMMON + LOGIN + r'''
section("H on", function()
check("H setup: off, no hook", cfHooks == 0 and not loaded())
ns.LoadOptions(); W.tick(0.1, 2); ns = rawget(_G, "XayaUI_NS"); hear()
local P = ns.Profile
local snap = P.Snapshot({ bonus = true }, "mine")
snap.parts.bonus.characterToolkit = snap.parts.bonus.characterToolkit or {}
snap.parts.bonus.characterToolkit.enabled = true
P.Apply(P.Check(snap)); W.tick(0.1, 2)
check("H a profile import that switches it on: saved on, the loader's hook is in, nothing loaded yet, the row is in the list",
  XayaUIBonusDB.characterToolkit.enabled == true and cfHooks == 1 and not loaded() and rowAvailable(), cfHooks)
end)
return R
end
'''


def session(src, saved):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}})
    opts["saved"] = H.to_lua(L, saved or {})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(src, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return results, errs


ON = {"XayaUI_Bonus": {"XayaUIBonusDB": {"storeVersion": 1, "characterToolkit": {"enabled": True}}}}


def main():
    bad = n = 0
    errs = []
    for tag, src, saved in (("fresh install, settings window open", S_FRESH, {}), ("saved on", S_ON, ON),
                            ("profile import off", S_IMPORT, ON), ("profile import on", S_IMPORT_ON, {})):
        r, e = session(src, saved)
        for name, ok in r:
            n += 1
            print(("PASS " if ok else "FAIL ") + "[%s] %s" % (tag, name))
            bad += 0 if ok else 1
        errs.extend("[%s] %s" % (tag, x) for x in e)
    for e in errs:
        print("ERROR in the game stand-in:", e[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
