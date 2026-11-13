#!/usr/bin/env python3
"""The rule editor's load contract (bundle 1 round 7, REQUEST-LOG A23 SD-57, her words: "editor is an 'options' pane so 3"; V34 "off
means not read"). Before round 7 (Rules 0.7.0, SD-6) the editor was XayaUI_Rules/Editor/, read at login with Rules, each file queuing
one set-up function that the settings window ran.
The rule editor is part of XayaUI Options: its files are XayaUI_Options/RuleEditor/*.lua (the 15 editor files and the editor's texture
and spell lists, TextureList.lua and AuraSources.lua), listed in XayaUI_Options.toc after the window's own files. The game reads them
only when XayaUI Options loads (the settings window's first opening); each stops at its first lines while XayaUI Rules is off.
Options.lua ns.OptionsApi.LoadRuleEditor only says, once per session, when Rules is on and the editor is not there.
Runs the real addons in the stand-in game and records every Lua file the loader reads (by chunk name), every frame made from an
editor file, the popups and the "EDITED" listeners.
  A XayaUI Rules on, at login: no file of the rule editor is read at all (from any folder); no ns.RuleEditorFiles queue exists; none
    of the editor's set-up has run: no ns.OptionsApi.RuleEditor.BuildRulesTab, no popup XAYAUI_AP_SAY / XAYAUI_AP_ALERT /
    XAYAUI_CONFIRM / XAYAUI_RENAME / XAYAUI_EXPORT / XAYAUI_GROUP_FIT, no frame made by an editor file, no "EDITED" listener from
    Drafts.lua.
  B opening the settings window reads each editor file exactly once, from XayaUI_Options/RuleEditor: the Rules tab is built, the
    popups and Drafts' "EDITED" listener exist; closing and opening again, opening a rule (ns.EditRule), a settings page, Drafts, the
    Class/Spec Rule Creator, Settings > Rule Creation and another LoadRuleEditor call read no file again; no
    LoadAddOn("XayaUI_Rules_Options") is asked for (that addon is gone). Those navigations land on the Rules sub-tabs / Rule Creation.
  C XayaUI Rules off: at login no editor file is read. Opening the window reads the editor files once with the rest of XayaUI Options
    (the game reads every file an addon lists; V34 residual, reported to Xaya), and each stops at once: no Rules tab, no BuildRulesTab,
    no popup, no frame made by an editor file, no "EDITED" listener; ns.OpenPage("drafts" / "creator"), ns.OpenDraftSettings,
    ns.UI.Creator and ns.UI.Drafts do nothing; the window opens again with no file read again; no error.
  D one editor file whose code errors (RuleMerge.lua, made to fail by the test): its error goes to the game's error handler, the other
    files still run once each and the Rules tab is built, with no "could not be set up" message.
  E every editor file errors: each error goes to the error handler, the window opens without the Rules tab, and one XayaUI message
    says the rule editor could not be set up; opening again reads and tries nothing again.
Run: python3 tests/rule_editor_load_run.py   (Lua 5.1 via lupa)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402


def editor_files():
    """The rule editor's files, in load order, from XayaUI_Options.toc (the RuleEditor\\<name>.lua lines)."""
    toc = open(os.path.join(H.ROOT, "XayaUI_Options", "XayaUI_Options.toc"), encoding="utf-8").read()
    out = []
    for line in toc.splitlines():
        line = line.strip().replace("\\", "/")
        if line and not line.startswith("#") and line.startswith("RuleEditor/") and line.endswith(".lua"):
            out.append(line[len("RuleEditor/"):])
    return out


EDITOR_FILES = editor_files()

PRE = r'''
return function()
  READS, LOADS, FAILFILES = {}, {}, {}
  local ls = loadstring
  -- FAILFILES[chunk name] = true: that file's code errors before it does anything (modes onefails / allfail)
  rawset(_G, "loadstring", function(src, name)
    READS[#READS + 1] = tostring(name)
    if FAILFILES[tostring(name)] then return function() error("XUI_TEST_EDITOR_SETUP_FAILS " .. tostring(name)) end end
    return ls(src, name)
  end)
end
'''

LUA = r'''
return function(W, L, mode, FILES)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local EDITOR = "@Interface/AddOns/XayaUI_Options/RuleEditor/"
local NFILES = #FILES
local MARK = "XUI_TEST_EDITOR_SETUP_FAILS"
-- D / E: which editor files the stand-in makes fail (their chunk errors before it does anything)
if mode == "onefails" then FAILFILES[EDITOR .. "RuleMerge.lua"] = true end
if mode == "allfail" then for _, f in ipairs(FILES) do FAILFILES[EDITOR .. f] = true end end
local la = C_AddOns.LoadAddOn
C_AddOns.LoadAddOn = function(n, ...) LOADS[#LOADS + 1] = tostring(n); return la(n, ...) end
LoadAddOn = C_AddOns.LoadAddOn
-- every frame made while code of an editor file is on the stack
local editorFrames = 0
local cf = CreateFrame
CreateFrame = function(...)
  for lv = 2, 40 do
    local i = debug.getinfo(lv, "S")
    if not i then break end
    if i.source and i.source:sub(1, #EDITOR) == EDITOR then editorFrames = editorFrames + 1; break end
  end
  return cf(...)
end
-- reads of a file named like an editor file, from any folder (the old XayaUI_Rules/Editor/ included)
local function editorReads()
  local n, from, per = 0, {}, {}
  for _, c in ipairs(READS) do
    for _, f in ipairs(FILES) do
      local folder = c:match("^@Interface/AddOns/(.-)/" .. f:gsub("%.", "%%.") .. "$")
      if folder then n = n + 1; from[folder] = true; per[f] = (per[f] or 0) + 1 end
    end
  end
  local fl = {}
  for k in pairs(from) do fl[#fl + 1] = k end
  table.sort(fl)
  return n, table.concat(fl, ","), per
end
local function readsOnce()
  local _, _, per = editorReads()
  local bad = {}
  for _, f in ipairs(FILES) do if per[f] ~= 1 then bad[#bad + 1] = f .. "=" .. tostring(per[f]) end end
  return #bad == 0, table.concat(bad, ",")
end
local function editorLoads() local n = 0; for _, x in ipairs(LOADS) do if x == "XayaUI_Rules_Options" then n = n + 1 end end return n end
local POPUPS = { "XAYAUI_AP_SAY", "XAYAUI_AP_ALERT", "XAYAUI_CONFIRM", "XAYAUI_RENAME", "XAYAUI_EXPORT", "XAYAUI_GROUP_FIT" }
local function popupsThere(list)
  local t = {}
  for _, k in ipairs(list or POPUPS) do if StaticPopupDialogs and StaticPopupDialogs[k] ~= nil then t[#t + 1] = k end end
  return t
end
-- the "EDITED" listeners that come from Drafts.lua (core keeps them in the upvalue "listeners" of ns.Fire, Modules.lua section 6)
local function draftsEditedListeners(ns)
  local lst
  for i = 1, 60 do
    local name, v = debug.getupvalue(ns.Fire, i)
    if not name then break end
    if name == "listeners" then lst = v; break end
  end
  if type(lst) ~= "table" then return nil end
  local n = 0
  for _, fn in ipairs(lst.EDITED or {}) do
    local src = debug.getinfo(fn, "S").source
    if src == EDITOR .. "Drafts.lua" then n = n + 1 end
  end
  return n
end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local said = {}
local print0 = ns.Print
ns.Print = function(...) said[#said + 1] = table.concat({ tostring((...)) }, " "); return print0(...) end   -- (messages may go to the console window)
local n0, from0 = editorReads()
local errsBefore = #W.errors
check(mode .. ": the toc lists the rule editor's " .. NFILES .. " files under XayaUI_Options/RuleEditor (15 editor files and its 2 lists)", NFILES == 17, NFILES)
check(mode .. ": at login no file of the rule editor is read, from any folder", n0 == 0, n0 .. " reads from " .. from0)
check(mode .. ": no ns.RuleEditorFiles queue", ns.RuleEditorFiles == nil, type(ns.RuleEditorFiles))
check(mode .. ": at login none of the editor's set-up has run: no ns.OptionsApi.RuleEditor.BuildRulesTab",
  not (ns.OptionsApi and ns.OptionsApi.RuleEditor and ns.OptionsApi.RuleEditor.BuildRulesTab))
local p0 = popupsThere()
check(mode .. ": at login none of the editor's popups is defined", #p0 == 0, table.concat(p0, ","))
check(mode .. ": at login no frame was made by an editor file", editorFrames == 0, editorFrames)
local dl0 = draftsEditedListeners(ns)
check(mode .. ": at login Drafts.lua has added no \"EDITED\" listener", dl0 == 0, tostring(dl0))
if mode ~= "off" then
  local r = ns.NewRule(); r.name = "Watch"; r.enabled = true; r.spellID = 47528; ns.NormalizeRule(r)
  ns.rules = { r }; CueRulesDB.rules = ns.rules
end

pcall(ns.ToggleUI); W.tick(0.1, 6)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub("AceConfigDialog-3.0")
local n, from = editorReads()
local open = ACD.OpenFrames and ACD.OpenFrames.CueRules and true or false
check(mode .. ": the settings window opens", open)
local function tabNow() local st = ACD:GetStatusTable("CueRules"); return st and st.groups and st.groups.selected end
local function subNow(...) local st = ACD:GetStatusTable("CueRules", { ... }); return st and st.groups and st.groups.selected end
local function markedErrors()
  local k = 0
  for i = errsBefore + 1, #W.errors do if tostring(W.errors[i]):find(MARK, 1, true) then k = k + 1 end end
  return k
end
local okR, badR = readsOnce()
check(mode .. ": the first opening reads each of the " .. NFILES .. " editor files exactly once, from XayaUI_Options/RuleEditor",
  okR and n == NFILES and from == "XayaUI_Options/RuleEditor", badR .. " / " .. n .. " reads from " .. from)
check(mode .. ": still no ns.RuleEditorFiles queue", ns.RuleEditorFiles == nil, type(ns.RuleEditorFiles))
if mode == "on" or mode == "onefails" then
  check(mode .. ": the Rules tab is built (BuildRulesTab exists, the tree has it)",
    type(ns.OptionsApi.RuleEditor.BuildRulesTab) == "function" and type(ns.BuildOptionsTable().args.cooldowns) == "table")
  if mode == "onefails" then
    check("onefails: the failing file's error went to the game's error handler, once", markedErrors() == 1, markedErrors())
    local m = 0
    for _, t in ipairs(said) do if t:find("rule editor could not be set up", 1, true) then m = m + 1 end end
    check("onefails: no 'could not be set up' message (the editor is there)", m == 0, m)
  end
end
if mode == "on" then
  local p = popupsThere({ "XAYAUI_AP_SAY", "XAYAUI_AP_ALERT", "XAYAUI_CONFIRM", "XAYAUI_RENAME", "XAYAUI_EXPORT" })
  check("on: after the set-up the editor's popups are defined (XAYAUI_GROUP_FIT only when first asked)", #p == 5, table.concat(p, ","))
  local dl = draftsEditedListeners(ns)
  check("on: after the set-up Drafts.lua listens to \"EDITED\" once", dl == 1, tostring(dl))
  check("on: the window asked for no LoadAddOn(\"XayaUI_Rules_Options\")", editorLoads() == 0, editorLoads())
  pcall(ns.ToggleUI); W.tick(0.1, 3); pcall(ns.ToggleUI); W.tick(0.1, 3)
  pcall(ns.EditRule, ns.rules[1]); W.tick(0.1, 3)
  -- a settings page through core's entry point (Modules.lua ns.OpenSettingsPage -> ns.LoadOptions -> ns.Options.OpenPage, Options.lua
  -- ns.OptionsApi.OpenPage). The feature pages it used to open (XayaUI QoL's "cursor") are gone from this branch, and the kept
  -- Blizzard Reskin > Theme page (ScopeEditor.lua) is left out while no element is restyled (SE.Build returns nil), so the test
  -- registers its own page on the QoL tab, the way a feature does (ns.RegisterSettingsPage).
  local PAGE = "xuitestpage"
  ns.RegisterSettingsPage("qol", PAGE, function()
    return { type = "group", name = "Test Page", args = { d = { type = "description", order = 1, name = "a stand-in page" } } }
  end)
  pcall(ns.OpenSettingsPage, "qol", PAGE); W.tick(0.1, 3)
  check("on: a settings page (ns.OpenSettingsPage(\"qol\", \"" .. PAGE .. "\")) opens that page on its tab",
    tabNow() == "qol" and subNow("qol") == PAGE, tostring(tabNow()) .. "/" .. tostring(subNow("qol")))
  local okP, badP = readsOnce()
  check("on: opening a settings page reads no editor file again", okP and editorReads() == NFILES, badP .. " / " .. editorReads() .. " reads")
  pcall(ns.UI.RecycleBin); W.tick(0.1, 3)
  check("on: the Recycle Bin opens Profiles > Recycle Bin", tabNow() == "profiles" and subNow("profiles") == "bin", tostring(tabNow()) .. "/" .. tostring(subNow("profiles")))
  ns.OpenPage("drafts"); W.tick(0.1, 3)
  check("on: Drafts opens the Rules > Drafts sub-tab", tabNow() == "cooldowns" and subNow("cooldowns") == "draftsTab", tostring(tabNow()) .. "/" .. tostring(subNow("cooldowns")))
  ns.UI.Creator(); W.tick(0.1, 3)
  check("on: the Class/Spec Rule Creator opens the Rules > creator sub-tab", tabNow() == "cooldowns" and subNow("cooldowns") == "creatorTab", tostring(tabNow()) .. "/" .. tostring(subNow("cooldowns")))
  ns.OpenDraftSettings(); W.tick(0.1, 3)
  local s1, s2 = subNow("set"), subNow("set", "ui")
  check("on: Settings > Rule Creation opens", tabNow() == "set" and s1 == "ui" and s2 == "rules", tostring(tabNow()) .. "/" .. tostring(s1) .. "/" .. tostring(s2))
  local again = ns.OptionsApi.LoadRuleEditor()
  check("on: LoadRuleEditor called again says the editor is there", again == true, tostring(again))
  local ok2, bad2 = readsOnce()
  local n2 = editorReads()
  check("on: closing, opening again and every way into the editor read no file again", ok2 and n2 == NFILES, bad2 .. " / " .. n2 .. " reads")
  local dl2 = draftsEditedListeners(ns)
  check("on: still one \"EDITED\" listener from Drafts.lua", dl2 == 1, tostring(dl2))
  check("on: still no LoadAddOn(\"XayaUI_Rules_Options\")", editorLoads() == 0, editorLoads())
elseif mode == "off" then
  check("off: no Rules tab", ns.BuildOptionsTable().args.cooldowns == nil)
  check("off: no BuildRulesTab", ns.OptionsApi.RuleEditor.BuildRulesTab == nil)
  check("off: no popup of the editor defined", #popupsThere() == 0, table.concat(popupsThere(), ","))
  check("off: no frame made by an editor file", editorFrames == 0, editorFrames)
  local dl = draftsEditedListeners(ns)
  check("off: Drafts.lua added no \"EDITED\" listener", dl == 0, tostring(dl))
  local before = tabNow()
  ns.OpenPage("drafts"); ns.OpenPage("creator"); ns.OpenDraftSettings(); ns.UI.Creator(); ns.UI.Drafts(); W.tick(0.1, 3)
  check("off: Drafts, the Rule Creator and Settings > Rule Creation do nothing (the tab stays " .. tostring(before) .. ")", tabNow() == before, tostring(tabNow()))
  pcall(ns.ToggleUI); W.tick(0.1, 3); pcall(ns.ToggleUI); W.tick(0.1, 3)
  check("off: the window opens again", ACD.OpenFrames and ACD.OpenFrames.CueRules and true or false)
  check("off: after closing and opening again no file of it is read again", editorReads() == NFILES, editorReads())
  check("off: still no frame made by an editor file", editorFrames == 0, editorFrames)
elseif mode == "allfail" then
  check("allfail: each editor file's error went to the game's error handler", markedErrors() == NFILES, markedErrors())
  check("allfail: no Rules tab", ns.BuildOptionsTable().args.cooldowns == nil)
  local m = 0
  for _, t in ipairs(said) do if t:find("the rule editor could not be set up: the Rules tab is left out", 1, true) then m = m + 1 end end
  check("allfail: one XayaUI message says the rule editor could not be set up", m == 1, m)
  pcall(ns.ToggleUI); W.tick(0.1, 3); pcall(ns.ToggleUI); W.tick(0.1, 3)
  local ok2, bad2 = readsOnce()
  local m2 = 0
  for _, t in ipairs(said) do if t:find("the rule editor could not be set up", 1, true) then m2 = m2 + 1 end end
  check("allfail: closing and opening again reads and tries nothing again (still one message)", ok2 and m2 == 1 and markedErrors() == NFILES, bad2 .. " / " .. m2)
end
pcall(ns.ToggleUI); W.tick(0.1, 3)
-- errors other than the ones this test made on purpose
local other = {}
for i = 1, #W.errors do if not tostring(W.errors[i]):find(MARK, 1, true) then other[#other + 1] = W.errors[i] end end
return R, other
end
'''


def run(mode):
    folders = H.find_addons()
    enabled = [n for n in folders if mode != "off" or n != "XayaUI_Rules"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    L.eval("function(src) return loadstring(src)()() end")(PRE)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res, other = L.eval("function(src, W, Ld, m, f) return loadstring(src)()(W, Ld, m, f) end")(
        LUA, world, loader, mode, H.to_lua(L, EDITOR_FILES))
    out = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [other[i] for i in range(1, len(other) + 1)]
    out.append(("%s: no other Lua error" % mode + ("" if not errs else "  [" + "; ".join(str(e)[:300] for e in errs[:3]) + "]"), not errs))
    return out


def main():
    results = run("on") + run("off") + run("onefails") + run("allfail")
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
