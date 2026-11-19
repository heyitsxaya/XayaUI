#!/usr/bin/env python3
"""Bundle 1 round 7, the settings-only parts move into XayaUI Options (REQUEST-LOG A23 SD-57 / SD-58; V34 "off means not read").
Her words: SD-57 "editor is an 'options' pane so 3"; SD-58 "Move all four (Recommended)" (the Combat Tracking Setup window, the
displays' right-click menu, the talent scan, the editor's spell and texture lists). What moved: XayaUI_Rules/Editor/*.lua ->
XayaUI_Options/RuleEditor/; XayaUI_Rules/TextureList.lua and AuraSources.lua -> XayaUI_Options/RuleEditor/; Combat/AuraSetup.lua ->
XayaUI_Options/AuraSetup.lua; the talent scan -> XayaUI_Options/TalentDump.lua (XayaUI_Rules/TalentDump.lua keeps only the
/xui debug talents entry point, and the saved scan stays XayaUI Rules' XayaUITalentDB); core's right-click menu (Modules.lua section 11,
core keeps the registry) -> XayaUI_Options/ElementMenu.lua; core's ns.BuildMinimapTab -> XayaUI_Options/MinimapTab.lua. Also the false
Recycle Bin text (Options.lua, "Checked at login and every 30 minutes").
What the player gets, on the real addons in the stand-in game (tests/harness):
  L1 at login (XayaUI, XayaUI Rules, XayaUI Options installed; the settings window not opened) none of the moved code is read: no file
     XayaUI_Rules/Editor/*, Combat/AuraSetup.lua, AuraSources.lua or TextureList.lua, no file of XayaUI Options, and none of the
     functions only that code defines exists. Her saved talent scan (XayaUITalentDB) is there, as saved.
  L2 /xui debug talents status, the window never opened: it prints her saved scan's summary, the settings window stays closed, and
     XayaUI Rules writes the scan back unchanged at logout (nothing lost).
  L3 /xui debug talents in combat, the window's code never loaded: one line, nothing else (the window's code does not load in combat,
     V26). (round 8, SD-67 "Read-only answers anytime") /xui debug talents status and <name> in combat then answer at once from XayaUI
     Rules' reader of the saved scan, loading nothing; the scan keeps its combat lock and runs when combat ends.
  L4 Combat Tracking Setup (SD-53): not there at login; the very first opening of the settings window opens it on top; closing the
     settings window closes it; the next opening does not open it again.
  L5 Settings > Minimap Button: the page is there in the window with its switches ("Show the minimap button" hides and shows the
     button); dragging the button with the page built tells the window (ns.Minimap_Changed); before the window's code loads there is no
     page hook and a drag does nothing more.
  L6 Profiles > Recycle Bin > "Keep deleted items for": the help text says when the bin is really checked (at log in or out, when this
     list is shown or an item is restored) and no longer "every 30 minutes".
  L7 XayaUI Rules off, settings window opened: the window opens, the moved Rules parts build nothing (no Setup window, no talent scan
     functions, no Rules tab), the Minimap page and the Recycle Bin text are there; /xui debug talents says it needs XayaUI Rules.
  S  nothing in XayaUI core or XayaUI Rules calls into the moved code (a static check of every ns name only XayaUI Options defines, as
     the harness's boundary check, and of each moved function by name), so nothing breaks while XayaUI Options is not loaded.
Fails on the files before the move (proved on a copy of HEAD b4742900: 48 checks, 10 failed): L1 (the editor and the other parts are
read at login, their functions exist), L6 and L7's text check (the "every 30 minutes" text), S (core and Rules still define the moved
functions; the files are still in XayaUI_Rules), and L3's status line (the old code answered at once in combat, and its queued scan then
replaced the saved scan, so L2's logout control fails there too). UNVERIFIED IN GAME.
Run: python3 tests/fix_r7_relocate_run.py   (Lua 5.1 via lupa)"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

# the functions only the moved code defines (in its new home, XayaUI Options)
# (bundle 1 round 8, REQUEST-LOG A23 SD-67, her answer "Read-only answers anytime (Recommended)"; intended change) ns.TalentStatus and
# ns.TalentDB, the reader of the saved scan, are XayaUI Rules' again (XayaUI_Rules/TalentDump.lua, with the saved data), so they are no
# longer in this list; the scan itself (ScanAllTalents, OptionsApi.TalentScan) stays XayaUI Options'.
MOVED_NAMES = ["AuraSetup_Open", "AuraSetup_WithSettings", "AuraSetup_SettingsClosed", "AuraSetup_Refresh", "ScanAllTalents",
               "AuraSources", "TextureList", "BuildMinimapTab", "ElementWindowShown", "ElementsRefresh",
               "ElementWindowIsShown", "ElementHandlersAttached", "ElementMenu", "ElementMenuApply", "ElementRightClick",
               "RuleEditorFiles", "DraftsMax", "BuildDraftsPage"]
MOVED_RULES_FILES = ("Combat/AuraSetup.lua", "AuraSources.lua", "TextureList.lua")

PRE = r'''
return function()
  READS = {}
  local ls = loadstring
  rawset(_G, "loadstring", function(src, name) READS[#READS + 1] = tostring(name); return ls(src, name) end)
end
'''

SCAN = {"built": "2026-11-06 21:20", "build": 120105, "errors": {},
        "classes": {1: {"name": "Warrior", "token": "WARRIOR", "specs": {71: "Arms"},
                        "nodes": {9001: {"t": 0, "max": 1, "scope": "class", "specs": {71: True},
                                         "e": [{"entry": 1, "spell": 6673, "name": "Battle Shout"}]}}}}}

LUA = r'''
return function(W, L, mode, NAMES, MOVED)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local said = {}
local print0 = ns.Print
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end
local function saidAny(pat) for _, l in ipairs(said) do if l:find(pat, 1, true) then return true end end return false end
local function joined() return table.concat(said, " / ") end
local ACD
local function windowOpen() ACD = ACD or LibStub and LibStub("AceConfigDialog-3.0", true); return ACD ~= nil and ACD.OpenFrames.CueRules ~= nil end
local function setupShown() local f = rawget(_G, "XayaUIAuraSetupFrame"); return f ~= nil and f:IsShown() end
local function optionsLoaded() return (C_AddOns.IsAddOnLoaded("XayaUI_Options")) and true or false end
local function readsOf(pred) local n, l = 0, {}; for _, c in ipairs(READS) do if pred(c) then n = n + 1; l[#l + 1] = c:gsub("^@Interface/AddOns/", "") end end return n, table.concat(l, ",") end
local function movedRulesRead(c)
  if c:find("^@Interface/AddOns/XayaUI_Rules/Editor/") then return true end
  for _, f in ipairs(MOVED) do if c == "@Interface/AddOns/XayaUI_Rules/" .. f then return true end end
  return false
end
local function namesThere() local t = {}; for _, n in ipairs(NAMES) do if rawget(ns, n) ~= nil then t[#t + 1] = n end end return t end

if mode == "on" then
  -- L1
  local n1, l1 = readsOf(movedRulesRead)
  check("L1 at login no file XayaUI Rules gave to XayaUI Options is read (Editor/*, Combat/AuraSetup.lua, AuraSources.lua, TextureList.lua)", n1 == 0, l1)
  local n2, l2 = readsOf(function(c) return c:find("^@Interface/AddOns/XayaUI_Options/") ~= nil end)
  check("L1 at login no file of XayaUI Options is read", n2 == 0, l2)
  check("L1 at login XayaUI Options is not loaded", not optionsLoaded())
  local there = namesThere()
  check("L1 at login none of the functions only the moved code defines exists", #there == 0, table.concat(there, ","))
  check("L1 her saved talent scan is there at login, as saved (XayaUITalentDB, XayaUI Rules' saved variable)",
    type(XayaUITalentDB) == "table" and XayaUITalentDB.built == "2026-11-06 21:20" and XayaUITalentDB.classes[1].name == "Warrior")
  check("L4 at login there is no Combat Tracking Setup window", rawget(_G, "XayaUIAuraSetupFrame") == nil)
  check("L5 at login there is no Minimap Button page hook (a drag tells no window)", ns.Minimap_Changed == nil)
  -- L2
  said = {}
  SlashCmdList.XAYAUI("debug talents status"); W.tick(0.1, 3)
  check("L2 /xui debug talents status, the window never opened: it prints her saved scan's summary",
    saidAny("Last talent scan 2026-11-06 21:20 (build 120105): 1 classes, 1 nodes."), joined())
  check("L2 ... and the settings window stays closed", not windowOpen())
  check("[r8] L2 ... and XayaUI Options was not loaded to print it (SD-67: the reader is XayaUI Rules')", not optionsLoaded())
  said = {}
  SlashCmdList.XAYAUI("debug talents battle"); W.tick(0.1, 3)
  check("L2 /xui debug talents <name> finds the talent in her saved scan", saidAny("Warrior [class]: Battle Shout (spell 6673)"), joined())
  check("L2 the saved scan is unchanged", type(XayaUITalentDB) == "table" and XayaUITalentDB.built == "2026-11-06 21:20")
  check("[r8] L2 ... the name search did not load XayaUI Options either", not optionsLoaded())
  -- L3 (round 8: the window's code is still not loaded; SD-67) status in combat answers at once
  W.enterCombat(); W.tick(0.05, 2)
  said = {}
  SlashCmdList.XAYAUI("debug talents status"); W.tick(0.05, 2)
  check("L3 /xui debug talents status in combat answers at once (SD-67)", saidAny("Last talent scan 2026-11-06"), joined())
  said = {}
  SlashCmdList.XAYAUI("debug talents"); W.tick(0.05, 2)
  check("L3 /xui debug talents (scan) in combat: one line, the scan's combat lock (V26)",
    #said == 1 and said[1]:find("the talent scan can't run during combat. It will run when combat ends.", 1, true), joined())
  W.leaveCombat(); W.tick(0.1, 30)
  check("L3 ... and when combat ends the scan command runs and says what it did", #said >= 2, joined())
  -- L4: SD-53
  said = {}
  pcall(ns.ToggleUI); W.tick(0.1, 6)
  check("L4 the first opening of the settings window opens", windowOpen())
  check("L4 ... and the very first time ever, Combat Tracking Setup opens on top of it", setupShown())
  pcall(ns.ToggleUI); W.tick(0.1, 4)
  check("L4 closing the settings window closes Combat Tracking Setup", not windowOpen() and not setupShown())
  pcall(ns.ToggleUI); W.tick(0.1, 6)
  check("L4 the next opening does not open Combat Tracking Setup again", windowOpen() and not setupShown())
  -- L5
  local T = ns.BuildOptionsTable()
  local mm = T.args.set and T.args.set.args.minimap
  check("L5 Settings > Minimap Button is in the window", mm ~= nil and mm.name == "Minimap Button", mm and mm.name)
  local show = mm and mm.args.show
  check("L5 its switch is \"Show the minimap button\"", show ~= nil and show.name == "Show the minimap button")
  if show then
    show.set({}, false); W.tick(0.05, 2)
    local b = rawget(_G, "XayaUIMinimapButton")
    check("L5 switching it off hides the button", b ~= nil and not b:IsShown())
    show.set({}, true); W.tick(0.05, 2)
    check("L5 switching it on shows the button again", b ~= nil and b:IsShown())
  end
  check("L5 with the page built, a drag of the button tells the window (ns.Minimap_Changed is set)", type(ns.Minimap_Changed) == "function")
  local b = rawget(_G, "XayaUIMinimapButton")
  local ds = b and b:GetScript("OnDragStop")
  local okD = ds and pcall(ds, b)
  check("L5 ... and a drag stop runs with no error", okD == true, tostring(okD))
  -- L6
  local keep = T.args.profiles and T.args.profiles.args.bin and T.args.profiles.args.bin.args.keep
  local desc = keep and tostring(keep.desc) or ""
  check("L6 \"Keep deleted items for\" no longer says the bin is checked every 30 minutes", keep ~= nil and not desc:find("30 minutes", 1, true), desc)
  check("L6 ... it says when it is checked: at log in or out, when this list is shown or an item is restored",
    desc:find("Checked when you log in or out, and whenever this list is shown or an item is restored", 1, true) ~= nil, desc)
  pcall(ns.ToggleUI); W.tick(0.1, 3)
elseif mode == "combatfirst" then
  -- L3 with the window's code never loaded
  W.enterCombat(); W.tick(0.05, 2)
  said = {}
  SlashCmdList.XAYAUI("debug talents"); W.tick(0.05, 2)
  check("L3 /xui debug talents in combat, the window's code never loaded: one line",
    #said == 1 and said[1]:find("the talent scan can't run during combat. It will run when combat ends.", 1, true), joined())
  check("L3 ... XayaUI Options is not loaded in combat and the window does not open", not optionsLoaded() and not windowOpen())
  -- (bundle 1 round 8, SD-67 "Read-only answers anytime"; intended change) status and the name search answer at once in combat, from the
  -- reader kept with the saved scan, and load nothing. Before: one line, and the status was printed when combat ended. The scan asked
  -- for above stays queued: the session ends in combat (the logout below), so it never runs and her saved scan must come back unchanged.
  said = {}
  SlashCmdList.XAYAUI("debug talents status"); W.tick(0.05, 2)
  check("[r8] L3 /xui debug talents status in combat, the window's code never loaded: her saved scan's summary at once, one line",
    #said == 1 and said[1] == "Last talent scan 2026-11-06 21:20 (build 120105): 1 classes, 1 nodes.", joined())
  said = {}
  SlashCmdList.XAYAUI("debug talents battle"); W.tick(0.05, 2)
  check("[r8] L3 /xui debug talents <name> in combat: the talent at once", saidAny("Warrior [class]: Battle Shout (spell 6673)"), joined())
  check("[r8] L3 ... XayaUI Options is still not loaded and the window does not open", not optionsLoaded() and not windowOpen())
elseif mode == "rulesoff" then
  -- L7
  pcall(ns.ToggleUI); W.tick(0.1, 6)
  check("L7 XayaUI Rules off: the settings window opens", windowOpen())
  check("L7 no Combat Tracking Setup window and none of its functions", rawget(_G, "XayaUIAuraSetupFrame") == nil and ns.AuraSetup_Open == nil)
  check("L7 no talent scan functions and no editor lists", ns.ScanAllTalents == nil and ns.TextureList == nil and ns.AuraSources == nil)
  local T = ns.BuildOptionsTable()
  check("L7 no Rules tab", T.args.cooldowns == nil)
  local mm = T.args.set and T.args.set.args.minimap
  check("L7 Settings > Minimap Button is there", mm ~= nil and mm.name == "Minimap Button")
  local keep = T.args.profiles and T.args.profiles.args.bin and T.args.profiles.args.bin.args.keep
  check("L7 the Recycle Bin text is the true one", keep ~= nil and tostring(keep.desc):find("whenever this list is shown", 1, true) ~= nil)
  said = {}
  SlashCmdList.XAYAUI("debug talents"); W.tick(0.1, 3)
  check("L7 /xui debug talents says it needs XayaUI Rules", saidAny("XayaUI Rules"), joined())
  pcall(ns.ToggleUI); W.tick(0.1, 3)
end
end)
check(mode .. ": the session ran to the end", okAll, errAll)
local errs = {}
for i = 1, #W.errors do errs[#errs + 1] = tostring(W.errors[i]) end
check(mode .. ": no Lua error", #errs == 0, table.concat(errs, " | "):sub(1, 600))
return R
end
'''


def session(mode, saved):
    folders = H.find_addons()
    enabled = [n for n in folders if not (mode == "rulesoff" and n == "XayaUI_Rules")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    L.eval("function(src) return loadstring(src)()() end")(PRE)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, W, Ld, m, n, f) return loadstring(src)()(W, Ld, m, n, f) end")(
        LUA, world, loader, mode, H.to_lua(L, MOVED_NAMES), H.to_lua(L, list(MOVED_RULES_FILES)))
    out = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    if mode == "combatfirst":   # (no scan ran in this session) the scan she saved is what XayaUI Rules writes back at logout: nothing lost
        sv, _issues = loader.logout()
        tdb = sv["XayaUI_Rules"]["XayaUITalentDB"] if sv and sv["XayaUI_Rules"] else None
        after = tdb is not None and tdb["built"] == SCAN["built"] and tdb["classes"][1]["name"] == "Warrior"
        out.append(("L2 at logout XayaUI Rules writes her saved talent scan back unchanged (XayaUITalentDB: nothing lost)", bool(after)))
    return out


# (round 11, SD-129 "Yes, in round 11 (Recommended)": tests/memory_report_run.py folded in; test audit section 2) the pass/fail checks
# memory_report made, here in L1 on the same terms it made them: every addon folder switched on and nothing saved (a fresh install), and
# memory_report's realistic profile, a long-used install: the V27 gate's ~300-rule profile (tests/gate_common.py PROFILE_LUA) plus what
# such an install keeps (tests/memory_report.py EXTRAS_LUA: 3 backups, the old place the settings move kept, 20 Recycle Bin rules, 30
# drafts, a 50-entry error log, Dev Assist's record, the last bug report, a talent scan of every class, learned data), made by the one
# shared session A (memory_report.realistic_session_a), with XayaUI Options then loaded as /xui loads it (memory_report's "realistic"
# measurement). Its report itself is the tool tests/memory_report.py, outside the suite.
# (round 11 repair 1) the first fold played the gate's profile alone, without the extras, so a fault that shows only on a long-used
# install (for example: rules not loaded when drafts are saved) passed here although memory_report failed it ("FAIL realistic: no rules
# loaded"). The extras are back, and L1 checks that each one reached the login, so the condition cannot silently go missing again.
FOLD_LUA = r'''
return function(W, L, NAMES, MOVED, profile, EXP)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local function movedRulesRead()
  local n, l = 0, {}
  for _, c in ipairs(READS) do
    local hit = c:find("^@Interface/AddOns/XayaUI_Rules/Editor/") ~= nil
    for _, f in ipairs(MOVED) do if c == "@Interface/AddOns/XayaUI_Rules/" .. f then hit = true end end
    if hit then n = n + 1; l[#l + 1] = c:gsub("^@Interface/AddOns/", "") end
  end
  return n, table.concat(l, ",")
end
local function namesThere() local t = {}; for _, n in ipairs(NAMES) do if ns and rawget(ns, n) ~= nil then t[#t + 1] = n end end return t end
local tag = profile and "the realistic ~300-rule profile" or "a fresh install, every addon folder switched on"
local n1, l1 = movedRulesRead()
check("L1 [memory_report] " .. tag .. ": at login no file XayaUI Rules gave to XayaUI Options is read", n1 == 0, l1)
local there = namesThere()
check("L1 [memory_report] " .. tag .. ": at login none of the functions only the moved code defines exists", #there == 0, table.concat(there, ","))
if profile then
  -- the long-used install's saved extras are there at login (memory_report's realistic case is that install, not the rule list alone)
  local CoreS = ns.Settings and ns.Settings("core") or {}
  local db = rawget(_G, "CueRulesDB") or {}
  local got = {
    drafts = #(CoreS.drafts or {}),
    backups = ns.Backups and #(ns.Backups() or {}) or 0,
    errors = #(rawget(db, "errorLog") or {}),
    recycled = ns.RecycleDB and #((ns.RecycleDB() or {}).items or {}) or 0,
    talentClasses = #((rawget(_G, "XayaUITalentDB") or {}).classes or {}),
  }
  local miss = {}
  for _, k in ipairs({ "drafts", "backups", "errors", "recycled", "talentClasses" }) do
    if got[k] ~= EXP[k] or (EXP[k] or 0) <= 0 then miss[#miss + 1] = k .. " " .. tostring(got[k]) .. " (session A made " .. tostring(EXP[k]) .. ")" end
  end
  check("L1 [memory_report] the long-used install's saved extras are there at login (drafts " .. got.drafts .. ", backups " .. got.backups ..
    ", error log " .. got.errors .. ", Recycle Bin " .. got.recycled .. ", talent scan " .. got.talentClasses .. " classes)", #miss == 0, table.concat(miss, "; "))
  local n = 0
  for _ in ipairs(ns and ns.rules or {}) do n = n + 1 end
  check("L1 [memory_report] the realistic profile's rules are loaded at login (" .. n .. " rules; memory_report: 'no rules loaded')", n > 0, n)
  -- XayaUI Options, as /xui loads it (memory_report loaded it the same way: ns.LoadOptions, then the window opened and closed)
  local ok = ns.LoadOptions and ns.LoadOptions()
  pcall(ns.ToggleUI); W.tick(0.05, 10); pcall(ns.ToggleUI); W.tick(0.1, 20)
  check("L1 [memory_report] ... XayaUI Options loaded as /xui loads it", ok and C_AddOns.IsAddOnLoaded("XayaUI_Options") and true or false)
  local n2, l2 = movedRulesRead()
  check("L1 [memory_report] ... and with XayaUI Options loaded still no file XayaUI Rules gave to it is read from XayaUI Rules", n2 == 0, l2)
end
end)
if not okAll then check("the session ran to its end", false, errAll) end
return R
end
'''


def fold_session(saved_source, extras=None):
    """One login for the memory_report checks: saved_source None = a fresh install with every addon folder switched on (memory_report's
    moved_names_at_login); else memory_report's realistic profile (the long-used install) as its session A saved it, extras = what that
    session A made ({drafts, backups, errors, recycled, talentClasses}), each checked at login."""
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    L.eval("function(src) return loadstring(src)()() end")(PRE)
    sv = H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}})
    opts["saved"] = sv.Load(saved_source) if saved_source else L.table()
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    res = L.eval("function(src, W, Ld, n, f, p, e) return loadstring(src)()(W, Ld, n, f, p, e) end")(
        FOLD_LUA, world, loader, H.to_lua(L, MOVED_NAMES), H.to_lua(L, list(MOVED_RULES_FILES)), saved_source is not None,
        H.to_lua(L, extras or {}))
    out = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    out.append(("L1 [memory_report] the login (%s) raised no Lua error" % ("realistic profile" if saved_source else "fresh install"),
                not errs) if not errs else ("L1 [memory_report] the login raised no Lua error  [%s]" % str(errs[0])[:300], False))
    return out


# what memory_report's EXTRAS_LUA makes in session A (tests/memory_report.py: 2 backups of hers plus the settings move's, 20 deleted rules,
# 30 drafts, the error log at its cap of 50, a talent scan of 13 classes); the fold checks them exactly, so the long-used install is real
EXTRAS_EXPECTED = {"backups": 3, "recycled": 20, "drafts": 30, "errors": 50, "talentClasses": 13}
# the 50 error-log entries are seeded on purpose (EXTRAS_LUA step 5: ns.RecordError for a XayaUI_Rules file, XUI-E001); the suite's
# honest-result guard (tests/run_all.py, SD-138 M1) reads every stand-in's CueRulesDB.errorLog, so the test declares them, exactly
SEEDED_ERRORS = ("XUI-E001", 50)


def memory_report_checks():
    """memory_report's four pass/fail checks (each named where it stood there): (C3) moved functions after login, fresh install;
    (C2) moved XayaUI Rules files read at login, fresh and realistic; (C1) the realistic profile's rules loaded; (C4) the profile session A
    made has about 300 rules (at least 250, as memory_report held it; the gate holds its own profile at 290: gate_common.py integrity).
    The realistic profile is memory_report's own (memory_report.realistic_session_a: the gate's rule list plus EXTRAS_LUA)."""
    sys.path.insert(0, HERE)
    out = fold_session(None)
    try:
        import memory_report as MR   # noqa: E402  (the shared session A: the gate's ~300-rule profile plus a long-used install's extras)
    except ImportError as e:         # (SD-138 M1: a missing input is said, and fails)
        print("MISSING INPUT: tests/memory_report.py (memory_report's realistic session A): %s" % e)
        return out + [("L1 [memory_report] the realistic profile could be made (tests/memory_report.py importable)", False)]
    src, info, errs_a = MR.build_realistic_saved()
    n = int(info.get("rules") or 0)
    made = {k: int((info.get("extras") or {}).get(k) or 0) for k in EXTRAS_EXPECTED}
    out.append(("L1 [memory_report] the realistic profile session A made has about 300 rules (at least 250: %d)" % n, n >= 250))
    wrong = ["%s %d (expected %d)" % (k, made[k], v) for k, v in sorted(EXTRAS_EXPECTED.items()) if made[k] != v]
    out.append(("L1 [memory_report] session A made the long-used install's extras: " + ", ".join(
        "%s %d" % (k, v) for k, v in sorted(EXTRAS_EXPECTED.items())), not wrong) if not wrong else
        ("L1 [memory_report] session A made the long-used install's extras  [%s]" % "; ".join(wrong), False))
    out.append(("L1 [memory_report] session A (the realistic profile) raised no Lua error", not errs_a) if not errs_a else
               ("L1 [memory_report] session A raised no Lua error  [%s]" % str(errs_a[0])[:300], False))
    return out + fold_session(src, EXTRAS_EXPECTED)


def static_checks():
    """S: no use, in XayaUI core or XayaUI Rules, of an ns name only XayaUI Options defines (comments stripped), and no use there of
    the moved functions by name."""
    out = []
    folders = H.find_addons()
    bad = [b for b in H.boundary_checks(folders) if "which belongs to XayaUI_Options;" in b]
    out.append(("S no file of XayaUI core or XayaUI Rules uses a name only XayaUI Options defines (the harness's boundary check)",
                not bad, "; ".join(bad[:6])))
    files = H.addon_lua_files(folders)
    uses = []
    for addon in ("XayaUI", "XayaUI_Rules"):
        for f in files.get(addon, []):
            if not os.path.isfile(f):
                continue
            code = H.strip_comments(open(f, encoding="utf-8", errors="replace").read())
            for i, line in enumerate(code.split("\n"), 1):
                for n in MOVED_NAMES:
                    if re.search(r"\bns\.%s\b" % n, line):
                        uses.append("%s:%d ns.%s" % (os.path.relpath(f, H.ROOT), i, n))
    out.append(("S no file of XayaUI core or XayaUI Rules names a moved function (ns.%s ...)" % MOVED_NAMES[0], not uses, "; ".join(uses[:8])))
    gone = [p for p in ["XayaUI_Rules/Editor", "XayaUI_Rules/Combat/AuraSetup.lua", "XayaUI_Rules/AuraSources.lua", "XayaUI_Rules/TextureList.lua"]
            if os.path.exists(os.path.join(H.ROOT, p))]
    out.append(("S the moved files are gone from XayaUI_Rules", not gone, ", ".join(gone)))
    return out


def main():
    saved = {"XayaUI_Rules": {"XayaUITalentDB": SCAN}}
    results = []
    for mode in ("on", "combatfirst", "rulesoff"):
        results += session(mode, saved if mode != "rulesoff" else {})
    results += memory_report_checks()
    results += [(n, ok) if len(t) == 2 else (n + ("" if ok else "  [" + str(t[2]) + "]"), ok) for t in static_checks() for n, ok in [t[:2]]]
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    # (round 11, SD-138 M1) the error-log entries memory_report's session A seeds on purpose (EXTRAS_LUA step 5), declared exactly
    print("EXPECT_ERRORS %s %d" % SEEDED_ERRORS)
    print("%d checks, %d failed" % (len(results), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
