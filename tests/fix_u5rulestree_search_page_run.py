#!/usr/bin/env python3
"""A group's page is drawn while the sidebar search box has text (review R9; docs/plans/RULES-REVIEW-2026-11-10.md).
The search filter (RulesTree.lua ns.ApplyTreeFilter) hid every group with no matching rule in it, inline groups included. A group page's
Group / Display / Load / Config bodies are inline groups that never hold a rule, so with any search text the open group's page showed
its four tab buttons and nothing under them.
Checked on the real addons in the stand-in game, through the drawn window (AceGUI widgets that are visible):
  A no search text: the group's Group tab body is drawn (control)
  B search text that matches a rule in the group: the group's row is still listed, and its Group tab body is drawn
  C ...its Config tab (clicked) shows the Group name box; its Load tab shows the load conditions
  D ...a group with no matching rule is still left out of the list (the filter keeps working)
Run: python3 tests/fix_u5rulestree_search_page_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
check("the settings window addon is loaded", ns and ns.ApplyTreeFilter and ns.UI and ns.UI.Notify and ACD)
if not (ns and ns.ApplyTreeFilter and ACD) then return R end
ns.Print = function() end
local APP = "CueRules"
local NOTE = "Use the eye and headphone icons next to this group in the sidebar to preview every rule inside it at once."
-- a drawn, visible widget whose option has this name (and, if given, this widget type)
local function widget(name, typ)
  local of = ACD.OpenFrames and ACD.OpenFrames[APP]
  local hit
  local function walk(w, d)
    if hit or type(w) ~= "table" or d > 50 then return end
    local o = w.GetUserData and w:GetUserData("option")
    local nm = o and o.name
    if type(nm) == "function" then local ok, v = pcall(nm, {}); nm = ok and v or nil end
    if type(nm) == "string" then nm = nm:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
    if o and (typ == nil or w.type == typ) and nm == name and w.frame and w.frame:IsVisible() then hit = w; return end
    for _, c in ipairs(w.children or {}) do walk(c, d + 1) end
  end
  walk(of, 0)
  return hit
end
local function click(w) if w and w.Fire then w:Fire("OnClick") end; W.tick(0.1, 4) end
local function mkRule(name, folder)
  local r = ns.NewRule(); r.name = name; r.folder = folder.id; r.enabled = true
  r.useBuff, r.buffID, r.buffState = true, 1001 + #ns.rules, "present"
  r.visual.enabled, r.sound.enabled = false, false
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local f = ns.NewFolder("Searched Group"); mkRule("Probe Rule", f)
local g = ns.NewFolder("Other Group"); mkRule("Unrelated", g)
ns.MarkDirty(); W.tick(0.1, 3)
pcall(ns.ToggleUI); W.tick(0.1, 3)
local function search(q) ns.treeFilter = q; ns.treeFilterOpen = (q ~= "") or nil; ns.UI.Notify(); W.tick(0.1, 4) end
local function openGroup() ACD:SelectGroup(APP, "cooldowns", "enabledTab", "loaded", f.id); W.tick(0.1, 4) end
local function listed(id)
  local S = ns.RulesTreeStatus()
  local of = ACD.OpenFrames and ACD.OpenFrames[APP]
  local hit = false
  local function walk(w, d)
    if hit or type(w) ~= "table" or d > 50 then return end
    if w.type == "TreeGroup" and w.tree then
      local function rows(list) for _, e in ipairs(list or {}) do if e.value == id then hit = true end; rows(e.children) end end
      rows(w.tree)
    end
    for _, c in ipairs(w.children or {}) do walk(c, d + 1) end
  end
  walk(of, 0)
  return hit
end

-- A
search(""); openGroup()
check("A no search text: the group's Group tab body is drawn", widget(NOTE) ~= nil)
-- B
search("probe"); openGroup()
check("B search 'probe': the group's row is listed", listed(f.id))
check("B ...the tab buttons are drawn", widget("Group") ~= nil and widget("Config") ~= nil)
check("B ...and the Group tab body under them", widget(NOTE) ~= nil)
-- C
click(widget("Config"))
check("C ...Config tab clicked: the Group name box is drawn", widget("Group name") ~= nil)
click(widget("Load"))
check("C ...Load tab clicked: the load conditions are drawn", widget("Only Load This Group When") ~= nil or widget("Class") ~= nil)
click(widget("Group"))
-- D
check("D the group with no matching rule is left out of the list", not listed(g.id))
search("")
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
