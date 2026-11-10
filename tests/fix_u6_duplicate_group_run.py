#!/usr/bin/env python3
"""Review R12 (docs/plans/RULES-REVIEW-2026-11-10.md): right-click on a group in the Rules sidebar > Duplicate made a copy that kept only
the group's name. A Dynamic Group came out as a plain group: no layout (grow direction, spacing, wrap), no place, no box, no load
override, no load IDs, no sound channel, for the top group and for every nested group.

The player sets up a Dynamic Group "Procs" with a layout, a place, a background, a load override, load IDs and a sound channel, and a
nested group "Inner" inside it that follows its sibling "Anchor" (a group that follows another group). She right-clicks "Procs" and picks
Duplicate. Checks what she gets: "Procs Copy" is a Dynamic Group with the same layout, place, box, load override, load IDs and sound
channel, holding copies of the same rules; its nested groups keep their own settings and names; the copied "Inner" follows the copied
"Anchor", not the original one; the copy is its own group (new id, made here, not edit-locked) and the original is unchanged.
Run: python3 tests/fix_u6_duplicate_group_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
local ACD, reg, APP = LibStub("AceConfigDialog-3.0"), LibStub("AceConfigRegistry-3.0"), "CueRules"
pcall(ns.ToggleUI); W.tick(0.05, 6)
check("the settings window is open", ACD.OpenFrames[APP] ~= nil)

local menu = {}
local function rec()
  local root = {}
  function root:CreateButton(text, fn) menu[tostring(text)] = fn; return rec() end
  function root:CreateTitle() return rec() end
  function root:CreateDivider() end
  function root:CreateRadio() return rec() end
  function root:CreateCheckbox() return rec() end
  function root:SetScrollMode() end
  function root:AddMenuAcquiredCallback() end
  return root
end
MenuUtil.CreateContextMenu = function(owner, gen) gen(owner, rec()) end
local function settle() W.tick(0.05, 6) end
local function findW(w, pred)
  if not w then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local f = findW(c, pred); if f then return f end end
end
local function tree() local s = ns.RulesTreeStatus(); return findW(ACD.OpenFrames[APP], function(w) return w.type == "TreeGroup" and w.status == s end) end
local function rowOf(id)   -- the row of this group in any sidebar list the window shows
  local found
  findW(ACD.OpenFrames[APP], function(w)
    if w.type ~= "TreeGroup" then return false end
    for _, b in ipairs(w.buttons or {}) do
      if b:IsShown() and (tostring(b.uniquevalue or ""):match("([^\001]+)$") or "") == id then found = b; return true end
    end
    return false
  end)
  return found
end
local function duplicate(id)
  menu = {}
  local b = rowOf(id)
  if b then b:Click("RightButton"); settle() end
  if menu["Duplicate"] then menu["Duplicate"](); settle(); return true end
  return false
end
local function byName(name, parent)
  for _, f in ipairs(ns.folders) do if f.name == name and f.parent == parent then return f end end
end

local display
for _, f in ipairs(ns.folders) do if not f.parent and f.default == "display" then display = f end end
local procs = { id = "f101", name = "Procs", cType = "dynamic", cArrX = 1, cArrY = 0, cArrGap = 6, cWrapN = 4, cSort = "name", cX = 120, cY = -40,
  cPoint = "TOP", cRelPoint = "BOTTOM", cBg = { 0.1, 0.2, 0.3, 0.8 }, cBorder = { 1, 1, 1, 1 }, cPad = 3, cStrata = "HIGH",
  loadOverride = true, loadIds = { 101, 202 }, soundChannel = "Dialog", editLocked = true, xuiScope = nil,
  origin = { by = "Someone-Else", how = "imported", at = 1 } }
local anchor = { id = "f102", name = "Anchor", parent = "f101", cType = "dynamic", cArrX = 0, cArrY = 1, cArrGap = 2 }
local inner = { id = "f103", name = "Inner", parent = "f101", cRel = "group", cGroup = "f102", cX = 5, cY = 7, soundChannel = "Ambience" }
ns.folders = { procs, anchor, inner }
if display then ns.folders[#ns.folders + 1] = display end
CueRulesDB.folders = ns.folders
ns.rules = {}
local function add(name, folder)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.useBuff, r.buffID, r.buffState = true, 3000 + #ns.rules, "present"
  r.folder = folder; ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
add("Proc A", "f101"); add("Proc B", "f101"); add("Anchor rule", "f102"); add("Inner rule", "f103")
if display then add("Display rule", display.id) end
CueRulesDB.rules = ns.rules
ACD:SelectGroup(APP, "cooldowns", "enabledTab", "loaded"); settle()
local s = ns.RulesTreeStatus(); s.groups["loaded\001f101"] = true; reg:NotifyChange(APP); settle()

check("the group row 'Procs' is in the sidebar and its menu has Duplicate", duplicate("f101"))
local copy = byName("Procs Copy", nil)
check("Duplicate made 'Procs Copy'", copy ~= nil)
if not copy then return end
check("the copy is a Dynamic Group, not a plain group", copy.cType == "dynamic", copy.cType)
check("the copy keeps the layout (grow, spacing, wrap, sort)", copy.cArrX == 1 and copy.cArrY == 0 and copy.cArrGap == 6 and copy.cWrapN == 4 and copy.cSort == "name",
  tostring(copy.cArrX) .. "/" .. tostring(copy.cArrGap) .. "/" .. tostring(copy.cWrapN))
check("the copy keeps its place on screen", copy.cX == 120 and copy.cY == -40 and copy.cPoint == "TOP" and copy.cRelPoint == "BOTTOM")
check("the copy keeps its box (background, border, padding, strata)", type(copy.cBg) == "table" and copy.cBg[4] == 0.8 and copy.cPad == 3 and copy.cStrata == "HIGH")
check("the copy's background is its own (changing it does not change the original)", copy.cBg ~= procs.cBg)
check("the copy keeps the load override and load IDs", copy.loadOverride == true and type(copy.loadIds) == "table" and copy.loadIds[2] == 202 and copy.loadIds ~= procs.loadIds)
check("the copy keeps the sound channel", copy.soundChannel == "Dialog", copy.soundChannel)
check("the copy is a group of its own: new id, top level like the original", copy.id ~= "f101" and copy.id:match("^f%d+$") ~= nil and copy.parent == nil, copy.id)
check("the copy is not edit-locked and is recorded as made here", not copy.editLocked and type(copy.origin) == "table" and copy.origin.how == "made" and copy.origin.by ~= "Someone-Else")
local n = 0
for _, r in ipairs(ns.rules) do if r.folder == copy.id then n = n + 1 end end
check("the copy holds copies of its 2 rules", n == 2, n)
local cAnchor, cInner = byName("Anchor", copy.id), byName("Inner", copy.id)
check("the nested groups are copied with their own names", cAnchor ~= nil and cInner ~= nil)
if cAnchor and cInner then
  check("the copied nested Dynamic Group keeps its layout", cAnchor.cType == "dynamic" and cAnchor.cArrY == 1 and cAnchor.cArrGap == 2)
  check("the copied nested group keeps its place and sound channel", cInner.cX == 5 and cInner.cY == 7 and cInner.soundChannel == "Ambience")
  check("the copied 'Inner' follows the copied 'Anchor', not the original", cInner.cRel == "group" and cInner.cGroup == cAnchor.id, tostring(cInner.cGroup))
  local ni = 0
  for _, r in ipairs(ns.rules) do if r.folder == cInner.id or r.folder == cAnchor.id then ni = ni + 1 end end
  check("the nested groups hold copies of their rules", ni == 2, ni)
end
check("the original is unchanged", procs.name == "Procs" and procs.id == "f101" and procs.editLocked == true and inner.cGroup == "f102"
  and procs.origin.how == "imported")

end)
if not okAll then check("the test ran to its end (a Lua error stopped it)", false, errAll) end
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
