#!/usr/bin/env python3
"""Platform split P4b (Options 0.6.87, XayaUI 0.6.77, XayaUI_Rules_Options 0.6.77; docs/plans/PLATFORM-SPLIT-2026-11-07.md Q1, V14):
the rule editor is its own load-on-demand addon, XayaUI_Rules_Options, which the settings window loads when it opens while XayaUI Rules
is on. Runs the real addons in the stand-in game and records every Lua file the loader reads (by chunk name) and every
C_AddOns.LoadAddOn call.
  A XayaUI Rules on: nothing of the editor is read at login; the first opening of the window reads each of its 14 files exactly once,
    from XayaUI_Rules_Options, with one LoadAddOn("XayaUI_Rules_Options"); closing and opening again, opening a rule (ns.EditRule),
    a settings page, Drafts, the Class/Spec Rule Creator and Settings > Rule Creation read nothing more and ask for no second load;
    those navigations land on the Rules sub-tabs / the Rule Creation tab.
  B XayaUI Rules off (V14): the window opens, closes and opens again, and ns.OpenPage("drafts" / "creator"), ns.OpenDraftSettings,
    ns.UI.Creator and ns.UI.Drafts do nothing: no file of the rule editor is read, no load of it is asked for, the selected tab does
    not change, no Lua error.
  C XayaUI Rules on but XayaUI_Rules_Options not installed: the window opens without the Rules tab, one XayaUI message says why, no Lua
    error.
Fails on the code before P4b (232552d): there the editor's files are XayaUI_Options/RuleEditor/*.lua, read with the window also while
XayaUI Rules is off (B), and not from XayaUI_Rules_Options (A).
Run: python3 tests/rule_editor_load_run.py   (Lua 5.1 via lupa)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402

EDITOR_FILES = ["Drafts.lua", "TriggersEditor.lua", "OutcomesEditor.lua", "DisplayTab.lua", "RuleSearch.lua", "AutoPicker.lua",
                "TreeHelpers.lua", "Editor.lua", "ShelvedElements.lua", "RulesTree.lua", "Sidebar.lua", "SpellSearch.lua", "SaveBar.lua",
                "RuleSettings.lua"]

PRE = r'''
return function()
  READS, LOADS = {}, {}
  local ls = loadstring
  rawset(_G, "loadstring", function(src, name) READS[#READS + 1] = tostring(name); return ls(src, name) end)
end
'''

LUA = r'''
return function(W, L, mode)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local la = C_AddOns.LoadAddOn
C_AddOns.LoadAddOn = function(n, ...) LOADS[#LOADS + 1] = tostring(n); return la(n, ...) end
LoadAddOn = C_AddOns.LoadAddOn
local FILES = { "Drafts.lua", "TriggersEditor.lua", "OutcomesEditor.lua", "DisplayTab.lua", "RuleSearch.lua", "AutoPicker.lua", "TreeHelpers.lua",
  "Editor.lua", "ShelvedElements.lua", "RulesTree.lua", "Sidebar.lua", "SpellSearch.lua", "SaveBar.lua", "RuleSettings.lua" }
local function editorReads()
  local n, from, per = 0, {}, {}
  for _, c in ipairs(READS) do
    for _, f in ipairs(FILES) do
      local folder = c:match("^@Interface/AddOns/(.-)/" .. f:gsub("%.", "%%.") .. "$")
      if folder == "XayaUI_Chat" then folder = nil end   -- XayaUI_Chat has a file of the same name (its own)
      if folder then n = n + 1; from[folder] = true; per[f] = (per[f] or 0) + 1 end
    end
  end
  local fl = {}
  for k in pairs(from) do fl[#fl + 1] = k end
  table.sort(fl)
  return n, table.concat(fl, ","), per
end
local function editorLoads() local n = 0; for _, x in ipairs(LOADS) do if x == "XayaUI_Rules_Options" then n = n + 1 end end return n end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local said = {}
local print0 = ns.Print
ns.Print = function(...) said[#said + 1] = table.concat({ tostring((...)) }, " "); return print0(...) end   -- (messages may go to the console window)
check(mode .. ": at login no file of the rule editor is read", editorReads() == 0, editorReads())
if mode == "on" then
  local r = ns.NewRule(); r.name = "Watch"; r.enabled = true; r.spellID = 47528; ns.NormalizeRule(r)
  ns.rules = { r }; CueRulesDB.rules = ns.rules
end
pcall(ns.ToggleUI); W.tick(0.1, 6)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub("AceConfigDialog-3.0")
local n, from, per = editorReads()
local open = ACD.OpenFrames and ACD.OpenFrames.CueRules and true or false
check(mode .. ": the settings window opens", open)
local function tabNow() local st = ACD:GetStatusTable("CueRules"); return st and st.groups and st.groups.selected end
local function subNow(...) local st = ACD:GetStatusTable("CueRules", { ... }); return st and st.groups and st.groups.selected end
if mode == "on" then
  local once = true
  for _, f in ipairs(FILES) do if per[f] ~= 1 then once = false end end
  check("on: the first opening reads each of the 14 rule editor files exactly once, from XayaUI_Rules_Options", n == 14 and once and from == "XayaUI_Rules_Options", n .. " reads from " .. from)
  check("on: the window asked for XayaUI_Rules_Options once", editorLoads() == 1, editorLoads())
  check("on: the Rules tab is built", type(ns.BuildOptionsTable().args.cooldowns) == "table")
  pcall(ns.ToggleUI); W.tick(0.1, 3); pcall(ns.ToggleUI); W.tick(0.1, 3)
  pcall(ns.EditRule, ns.rules[1]); W.tick(0.1, 3)
  pcall(ns.OpenSettingsPage, "qol", "cursor"); W.tick(0.1, 3)
  ns.OpenPage("drafts"); W.tick(0.1, 3)
  check("on: Drafts opens the Rules > Drafts sub-tab", tabNow() == "cooldowns" and subNow("cooldowns") == "draftsTab", tostring(tabNow()) .. "/" .. tostring(subNow("cooldowns")))
  ns.UI.Creator(); W.tick(0.1, 3)
  check("on: the Class/Spec Rule Creator opens the Rules > creator sub-tab", tabNow() == "cooldowns" and subNow("cooldowns") == "creatorTab", tostring(tabNow()) .. "/" .. tostring(subNow("cooldowns")))
  ns.OpenDraftSettings(); W.tick(0.1, 3)
  local s1, s2 = subNow("set"), subNow("set", "ui")
  check("on: Settings > Rule Creation opens", tabNow() == "set" and s1 == "ui" and s2 == "rules", tostring(tabNow()) .. "/" .. tostring(s1) .. "/" .. tostring(s2))
  local n2 = editorReads()
  check("on: closing, opening again and every way into the editor read nothing more and load it no second time", n2 == 14 and editorLoads() == 1, n2 .. " reads, " .. editorLoads() .. " loads")
elseif mode == "off" then
  check("off (V14): opening the window reads no file of the rule editor and asks for no load of it", n == 0 and editorLoads() == 0, n .. " reads from " .. from .. ", " .. editorLoads() .. " loads")
  check("off: no Rules tab", ns.BuildOptionsTable().args.cooldowns == nil)
  local before = tabNow()
  ns.OpenPage("drafts"); ns.OpenPage("creator"); ns.OpenDraftSettings(); ns.UI.Creator(); ns.UI.Drafts(); W.tick(0.1, 3)
  check("off: Drafts, the Rule Creator and Settings > Rule Creation do nothing (the tab stays " .. tostring(before) .. ")", tabNow() == before, tostring(tabNow()))
  pcall(ns.ToggleUI); W.tick(0.1, 3); pcall(ns.ToggleUI); W.tick(0.1, 3)
  check("off (V14): after closing and opening again still no file of it read", editorReads() == 0 and editorLoads() == 0)
else   -- missing
  check("missing: no Rules tab", ns.BuildOptionsTable().args.cooldowns == nil)
  local n = 0
  for _, t in ipairs(said) do if t:find("XayaUI Rules Options", 1, true) then n = n + 1 end end
  check("missing: one XayaUI message says the rule editor is not there", n == 1, n)
end
pcall(ns.ToggleUI); W.tick(0.1, 3)
return R
end
'''


def run(mode):
    folders = H.find_addons()
    if mode == "missing":
        folders = {k: v for k, v in folders.items() if k != "XayaUI_Rules_Options"}
    enabled = [n for n in folders if n != "XayaUI_DevAssist" and (mode != "off" or n != "XayaUI_Rules")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    L.eval("function(src) return loadstring(src)()() end")(PRE)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)
    out = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    out.append(("%s: no Lua error" % mode + ("" if not errs else "  [" + "; ".join(str(e)[:300] for e in errs[:3]) + "]"), not errs))
    return out


def main():
    results = run("on") + run("off") + run("missing")
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
