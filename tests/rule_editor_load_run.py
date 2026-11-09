#!/usr/bin/env python3
"""The rule editor's load contract (Rules 0.7.0, Options 0.6.107; REQUEST-LOG A23 SD-6; was P4b / V14 of
docs/plans/PLATFORM-SPLIT-2026-11-07.md, when the editor was its own load-on-demand addon).
The rule editor is part of XayaUI Rules: its 15 files are XayaUI_Rules/Editor/*.lua, listed in XayaUI_Rules.toc after the engine
files. The game reads them at login with Rules; each only adds one set-up function to ns.RuleEditorFiles. XayaUI_Options
(Options.lua ns.OptionsApi.LoadRuleEditor, called by core's ns.LoadOptions through ns.Options.AfterLoad and by Toggle) runs those
functions once per session, in order, each with xpcall and the game's error handler, only while Rules is on, then drops the list.
Runs the real addons in the stand-in game and records every Lua file the loader reads (by chunk name), every frame made from an
editor file, the popups and the "EDITED" listeners.
  A XayaUI Rules on, at login: each of the 15 editor files (the real list, read from XayaUI_Rules.toc) is read exactly once, from
    XayaUI_Rules/Editor; ns.RuleEditorFiles holds 15 functions, one per file in .toc order; none of the editor's set-up has run: no
    ns.OptionsApi.RuleEditor.BuildRulesTab, no popup XAYAUI_AP_SAY / XAYAUI_AP_ALERT / XAYAUI_CONFIRM / XAYAUI_RENAME / XAYAUI_EXPORT /
    XAYAUI_GROUP_FIT, no frame made by an editor file, no "EDITED" listener from Drafts.lua.
  B opening the settings window runs each set-up function exactly once: the Rules tab is built, the popups and Drafts' "EDITED"
    listener exist, ns.RuleEditorFiles is nil; closing and opening again, opening a rule (ns.EditRule), a settings page, Drafts, the
    Class/Spec Rule Creator, Settings > Rule Creation and another LoadRuleEditor call run none of it again and read no file again; no
    LoadAddOn("XayaUI_Rules_Options") is asked for (that addon is gone). Those navigations land on the Rules sub-tabs / Rule Creation.
  C XayaUI Rules off: no editor file is read at all (login or window), ns.RuleEditorFiles is nil, the window opens and opens again
    without a Rules tab, ns.OpenPage("drafts" / "creator"), ns.OpenDraftSettings, ns.UI.Creator and ns.UI.Drafts do nothing, no error.
  D a set-up function that errors (one added in front of the 15): its error goes to the game's error handler, the 15 real ones still
    run once each and the Rules tab is built.
  E every set-up function errors: each error goes to the error handler, the window opens without the Rules tab, and one XayaUI message
    says the rule editor could not be set up.
Run: python3 tests/rule_editor_load_run.py   (Lua 5.1 via lupa)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402


def editor_files():
    """The rule editor's files, in load order, from XayaUI_Rules.toc (the Editor\\<name>.lua lines)."""
    toc = open(os.path.join(H.ROOT, "XayaUI_Rules", "XayaUI_Rules.toc"), encoding="utf-8").read()
    out = []
    for line in toc.splitlines():
        line = line.strip().replace("\\", "/")
        if line and not line.startswith("#") and line.startswith("Editor/") and line.endswith(".lua"):
            out.append(line[len("Editor/"):])
    return out


EDITOR_FILES = editor_files()

PRE = r'''
return function()
  READS, LOADS = {}, {}
  local ls = loadstring
  rawset(_G, "loadstring", function(src, name) READS[#READS + 1] = tostring(name); return ls(src, name) end)
end
'''

LUA = r'''
return function(W, L, mode, FILES)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local EDITOR = "@Interface/AddOns/XayaUI_Rules/Editor/"
local NFILES = #FILES
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
local n0, from0, per0 = editorReads()
local runs, origin = {}, {}
local errsBefore = #W.errors
local MARK = "XUI_TEST_EDITOR_SETUP_FAILS"
if mode == "off" then
  check("off: at login no file of the rule editor is read", n0 == 0, n0 .. " reads from " .. from0)
  check("off: no ns.RuleEditorFiles", ns.RuleEditorFiles == nil, type(ns.RuleEditorFiles))
else
  local once = true
  for _, f in ipairs(FILES) do if per0[f] ~= 1 then once = false end end
  check(mode .. ": at login each of the " .. NFILES .. " rule editor files is read exactly once, from XayaUI_Rules/Editor",
    NFILES == 15 and n0 == NFILES and once and from0 == "XayaUI_Rules/Editor", NFILES .. " files in the .toc, " .. n0 .. " reads from " .. from0)
  local list = ns.RuleEditorFiles
  local inOrder = type(list) == "table" and #list == NFILES
  local got = {}
  if type(list) == "table" then
    for i = 1, #list do
      local fn = list[i]
      local src = type(fn) == "function" and debug.getinfo(fn, "S").source or type(fn)
      got[#got + 1] = tostring(src):gsub("^" .. EDITOR:gsub("%p", "%%%0"), "")
      if src ~= EDITOR .. FILES[i] then inOrder = false end
    end
  end
  check(mode .. ": ns.RuleEditorFiles holds " .. NFILES .. " set-up functions, one per editor file in .toc order", inOrder, table.concat(got, ","))
  check(mode .. ": at login none of the editor's set-up has run: no ns.OptionsApi.RuleEditor.BuildRulesTab",
    not (ns.OptionsApi and ns.OptionsApi.RuleEditor and ns.OptionsApi.RuleEditor.BuildRulesTab))
  local p = popupsThere()
  check(mode .. ": at login none of the editor's popups is defined", #p == 0, table.concat(p, ","))
  check(mode .. ": at login no frame was made by an editor file", editorFrames == 0, editorFrames)
  local dl = draftsEditedListeners(ns)
  check(mode .. ": at login Drafts.lua has added no \"EDITED\" listener", dl == 0, tostring(dl))
  -- count each set-up function's runs (wrappers keep the order); D adds a failing one in front, E makes every one fail
  if type(list) == "table" then
    for i = 1, #list do
      local fn, f = list[i], FILES[i]
      runs[f] = 0
      if mode == "allfail" then
        list[i] = function() runs[f] = runs[f] + 1; error(MARK .. " " .. f) end
      else
        list[i] = function(...) runs[f] = runs[f] + 1; return fn(...) end
      end
    end
    if mode == "onefails" then table.insert(list, 1, function() error(MARK .. " extra") end) end
  end
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
local function runsOnce()
  local bad = {}
  for _, f in ipairs(FILES) do if runs[f] ~= 1 then bad[#bad + 1] = f .. "=" .. tostring(runs[f]) end end
  return #bad == 0, table.concat(bad, ",")
end
local function markedErrors()
  local k = 0
  for i = errsBefore + 1, #W.errors do if tostring(W.errors[i]):find(MARK, 1, true) then k = k + 1 end end
  return k
end
if mode == "on" or mode == "onefails" then
  local ok1, bad1 = runsOnce()
  check(mode .. ": the first opening runs each of the " .. NFILES .. " set-up functions exactly once", ok1, bad1)
  check(mode .. ": then ns.RuleEditorFiles is nil", ns.RuleEditorFiles == nil, type(ns.RuleEditorFiles))
  check(mode .. ": the Rules tab is built (BuildRulesTab exists, the tree has it)",
    type(ns.OptionsApi.RuleEditor.BuildRulesTab) == "function" and type(ns.BuildOptionsTable().args.cooldowns) == "table")
  check(mode .. ": opening read no file of the editor again", n == NFILES, n)
  if mode == "onefails" then
    check("onefails: the failing set-up function's error went to the game's error handler, once", markedErrors() == 1, markedErrors())
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
  local okP, badP = runsOnce()
  check("on: opening a settings page runs no set-up of the editor again", okP and editorReads() == NFILES, badP .. " / " .. editorReads() .. " reads")
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
  local ok2, bad2 = runsOnce()
  local n2 = editorReads()
  check("on: closing, opening again and every way into the editor run no set-up again and read no file again", ok2 and n2 == NFILES, bad2 .. " / " .. n2 .. " reads")
  local dl2 = draftsEditedListeners(ns)
  check("on: still one \"EDITED\" listener from Drafts.lua", dl2 == 1, tostring(dl2))
  check("on: still no LoadAddOn(\"XayaUI_Rules_Options\")", editorLoads() == 0, editorLoads())
elseif mode == "off" then
  check("off: opening the window reads no file of the rule editor", n == 0, n .. " reads from " .. from)
  check("off: no Rules tab", ns.BuildOptionsTable().args.cooldowns == nil)
  check("off: no BuildRulesTab", ns.OptionsApi.RuleEditor.BuildRulesTab == nil)
  local before = tabNow()
  ns.OpenPage("drafts"); ns.OpenPage("creator"); ns.OpenDraftSettings(); ns.UI.Creator(); ns.UI.Drafts(); W.tick(0.1, 3)
  check("off: Drafts, the Rule Creator and Settings > Rule Creation do nothing (the tab stays " .. tostring(before) .. ")", tabNow() == before, tostring(tabNow()))
  pcall(ns.ToggleUI); W.tick(0.1, 3); pcall(ns.ToggleUI); W.tick(0.1, 3)
  check("off: the window opens again", ACD.OpenFrames and ACD.OpenFrames.CueRules and true or false)
  check("off: after closing and opening again still no file of it read", editorReads() == 0)
  check("off: no popup of the editor defined", #popupsThere() == 0, table.concat(popupsThere(), ","))
  check("off: no frame made by an editor file", editorFrames == 0, editorFrames)
elseif mode == "allfail" then
  local ok1, bad1 = runsOnce()
  check("allfail: each set-up function ran once", ok1, bad1)
  check("allfail: each one's error went to the game's error handler", markedErrors() == NFILES, markedErrors())
  check("allfail: ns.RuleEditorFiles is nil", ns.RuleEditorFiles == nil, type(ns.RuleEditorFiles))
  check("allfail: no Rules tab", ns.BuildOptionsTable().args.cooldowns == nil)
  local m = 0
  for _, t in ipairs(said) do if t:find("the rule editor could not be set up: the Rules tab is left out", 1, true) then m = m + 1 end end
  check("allfail: one XayaUI message says the rule editor could not be set up", m == 1, m)
  pcall(ns.ToggleUI); W.tick(0.1, 3); pcall(ns.ToggleUI); W.tick(0.1, 3)
  local ok2, bad2 = runsOnce()
  check("allfail: closing and opening again tries no set-up again", ok2, bad2)
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
