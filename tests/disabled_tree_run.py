#!/usr/bin/env python3
"""Offline test (build 0.6.2): Rules > Disabled lists a group only when it DIRECTLY holds a disabled rule, straight under the list,
with only those rules in it (no parent, grandparent or sibling groups around it). Loaded / Not Loaded keep their nested layout.
Also covers the row paths used to select a row (ScopePath, SelectKeep's rewrite, PlaceNewGroup), the missing reorder arrows on group
rows of the flat list, and the preview scope of a group row.
Run: python3 tests/disabled_tree_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok) R[#R + 1] = { name, ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded (ns.BuildOptionsTable)", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end

-- VDH > Defensives > HUD > Shields (disabled rule in Shields only); VDH > Personal Buffs (disabled rule); Externals (disabled rule) with its
-- own "Defensives"; a second "Defensives" under VDH holding a disabled rule (same name -> needs the parent in the label); a new empty group
-- made in the Disabled list; a disabled rule with no group; enabled rules in VDH, HUD and Defensives (they must not pull those groups in).
ns.folders = {
  { id = "f1", name = "VDH" }, { id = "f2", name = "Defensives", parent = "f1" }, { id = "f3", name = "HUD", parent = "f2" },
  { id = "f4", name = "Shields", parent = "f3" }, { id = "f5", name = "Personal Buffs", parent = "f1" },
  { id = "f6", name = "Externals" }, { id = "f7", name = "Defensives", parent = "f6" },
  { id = "f8", name = "Brand New", xuiScope = "disabled" }, { id = "f9", name = "Defensives", parent = "f1" },
}
local function rule(name, folder, enabled)
  local r = ns.NewRule(); r.name = name; r.folder = folder; r.enabled = enabled; ns.NormalizeRule(r); return r
end
ns.rules = {
  rule("shield off", "f4", false),     -- 1
  rule("hud on", "f3", true),          -- 2
  rule("vdh on", "f1", true),          -- 3
  rule("buff off", "f5", false),       -- 4
  rule("ext off", "f6", false),        -- 5
  rule("ext def off", "f7", false),    -- 6
  rule("loose off", nil, false),       -- 7
  rule("def on", "f2", true),          -- 8
  rule("def2 off", "f9", false),       -- 9
}
local built = ns.BuildOptionsTable()
local rules = built.args.cooldowns
check("Rules tab builds", rules ~= nil)
local dis = rules.args.disabledTab.args.disabled.args
local function keys(t) local o = {} for k in pairs(t) do o[#o + 1] = k end table.sort(o) return table.concat(o, ",") end
local function nm(g) return type(g.name) == "function" and g.name() or g.name end

check("parents / grandparents are not listed (f1, f2, f3 absent)", dis.f1 == nil and dis.f2 == nil and dis.f3 == nil)
check("every direct container is listed at the top of the list (f4, f5, f6, f7, f9)", dis.f4 and dis.f5 and dis.f6 and dis.f7 and dis.f9)
check("the empty group made in the Disabled list is listed", dis.f8 ~= nil)
check("Shields holds only its own rule, no group rows", dis.f4 and dis.f4.args.rule1 and dis.f4.args.f1 == nil and dis.f4.args.f2 == nil and dis.f4.args.f3 == nil)
local function groupKids(g) for k, v in pairs(g.args) do if tostring(k):match("^f%d") then return true end end return false end
check("no listed group has a group row inside it", not (groupKids(dis.f4) or groupKids(dis.f5) or groupKids(dis.f6) or groupKids(dis.f7) or groupKids(dis.f9)))
check("the rule is under its group, not also at the top", dis.rule1 == nil and dis.rule4 == nil and dis.rule5 == nil and dis.rule6 == nil and dis.rule9 == nil)
check("a disabled rule with no group stays at the top", dis.rule7 ~= nil)
check("enabled rules are not in the Disabled list", dis.rule2 == nil and dis.rule3 == nil and dis.rule8 == nil)
check("count is the group's own rules (Shields (1))", nm(dis.f4) == "Shields (1)")
check("same-named groups say which parent: Defensives - in VDH (1)", nm(dis.f9) == "Defensives - in VDH (1)")
check("same-named groups say which parent: Defensives - in Externals (1)", nm(dis.f7) == "Defensives - in Externals (1)")
check("no suffix without a clash (Personal Buffs (1))", nm(dis.f5) == "Personal Buffs (1)")
check("empty new group counts 0", nm(dis.f8) == "Brand New (0)")
check("DISABLED root count is the rules (6)", (function() local n = rules.args.disabledTab.args.disabled.name; return (type(n) == "function" and n() or n) == "DISABLED (6)" end)())

-- Loaded / Not Loaded keep the nested layout
local function nested(list) local g = list.f1; return g and g.args and g.args.f2 and g.args.f2.args and g.args.f2.args.f3 and true or false end
local en = rules.args.enabledTab.args
check("Loaded / Not Loaded still nest groups (VDH > Defensives > HUD in one of them)", nested(en.loaded.args) or nested(en.notloaded.args))

-- paths
local function P(...) return table.concat({ ... }, ">") end
local okc, ctx = pcall(ns.ReadContext)
check("ScopePath: disabled rule -> its own group directly under the list", P(ns.ScopePath(ns.rules[1], okc and ctx or nil)) == "cooldowns>disabledTab>disabled>f4>rule1")
check("ScopePath: ungrouped disabled rule -> straight under the list", P(ns.ScopePath(ns.rules[7], okc and ctx or nil)) == "cooldowns>disabledTab>disabled>rule7")
check("ScopePath: enabled rule keeps the full chain", (function()
  local p = P(ns.ScopePath(ns.rules[2], okc and ctx or nil)); return p:find("enabledTab", 1, true) and p:find(">f1>f2>f3>rule2", 1, true) and true or false end)())
local nf = { id = "f8", name = "Brand New", xuiScope = "disabled" }
check("PlaceNewGroup (Disabled): group directly under the list", P(ns.PlaceNewGroup(ns.folders[3], "disabled")) == "cooldowns>disabledTab>disabled>f3" )
check("PlaceNewGroup (Loaded): full chain as before", P(ns.PlaceNewGroup(ns.folders[3], "loaded")) == "cooldowns>enabledTab>loaded>f1>f2>f3")

-- the listed set, used by row selection
check("DisabledListed knows the listed groups only", ns.DisabledListed and ns.DisabledListed.f4 and not ns.DisabledListed.f1 and not ns.DisabledListed.f3)

-- reorder arrows: no arrows on group rows of the flat list; rule rows keep them
local Sib = ns.SiblingsForTest
if Sib then
  check("no up / down arrows on a group row in Disabled", select(2, Sib("disabled\001f4")) == nil)
  check("rule rows in Disabled still have arrows", select(2, Sib("disabled\001f4\001rule1")) ~= nil)
end
-- "Show tooltip on hover" is its own tick box in the group-wide Paste / Apply tree (and no longer rides along with "Texture / art")
local function leaf(list, key) for _, n in ipairs(list) do if type(n[2]) == "table" then local f = leaf(n[2], key); if f then return f end elseif n[1] == key then return n end end end
local hl = ns.PASTE_TREE and leaf(ns.PASTE_TREE, "vHoverTip")
check("Paste tree has a 'Show tooltip on hover' leaf", hl and hl[2] == "Show tooltip on hover")
check("that leaf copies the cue's hoverTip", ns.PASTE_VIS and ns.PASTE_VIS.vHoverTip and ns.PASTE_VIS.vHoverTip[1] == "hoverTip" and #ns.PASTE_VIS.vHoverTip == 1)
check("the tooltip leaf sits next to 'Only show while on an action bar'", (function()
  local function parent(list, key) for _, n in ipairs(list) do if type(n[2]) == "table" then if parent(n[2], key) then return parent(n[2], key) end; for _, c in ipairs(n[2]) do if c[1] == key then return n[2] end end end end end
  local sib = parent(ns.PASTE_TREE, "vHoverTip"); if not sib then return false end
  for _, c in ipairs(sib) do if c[1] == "vOnBar" then return true end end return false end)())
-- Moving a rule up / down in its group redraws the on-screen preview (dynamic groups lay out in rule order)
do
  ns.folders = { { id = "f1", name = "Dyn", cType = "dynamic", cGrowth = "RIGHT", cSpacing = 4 } }
  local a, b = rule("A", "f1", true), rule("B", "f1", true)
  for _, r in ipairs({ a, b }) do r.visual.enabled = true; r.visual.w = 40; r.visual.h = 40 end
  ns.rules = { a, b }
  local calls = 0
  local orig = ns.RefreshAllVisuals
  ns.RefreshAllVisuals = function(...) calls = calls + 1; return orig(...) end
  local mv = ns.ReorderRowForTest
  check("reorder hook present", mv ~= nil)
  if mv then
    mv({ uniquevalue = "loaded\001f1\001rule1" }, 1)
    check("moving a rule down swaps it with its neighbor", ns.rules[1] == b and ns.rules[2] == a)
    check("moving a rule redraws the preview (RefreshAllVisuals called)", calls >= 1)
    mv({ uniquevalue = "loaded\001f1\001rule1" }, 1)
    check("and back again", ns.rules[1] == a and ns.rules[2] == b and calls >= 2)
  end
  ns.RefreshAllVisuals = orig
end
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
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        if not ok:
            bad += 1
            print("FAIL:", name)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
