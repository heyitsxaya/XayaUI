#!/usr/bin/env python3
"""A window redraw with many groups costs about what it costs without groups (review R17; docs/plans/RULES-REVIEW-2026-11-10.md).
Every redraw of the settings window (a click on any switch redraws at least once) builds the rule lists. The group helpers
(XayaUI_Options/RuleEditor/TreeHelpers.lua FolderRules / IsInFolder) searched the group list once per step of every rule's group chain and made
a table per rule, and the build asked them once or twice per group: with an auto-generated Class > Spec > type tree (64 groups) and
300 rules with a cue each, the groups made a build take about 30 times as long as the same rules with no groups.
Checked on the real addons in the stand-in game, with the window's own build (AceConfigRegistry's options table, as Tree.Get runs it):
  A what 300 more rules (with a cue each) add to one build: with 64 groups less than 2 times the garbage they add with no groups
    (each group's own page, built once per build whatever the rules, is left out by taking the difference; before the fix
    about 9x)
  B ...and less than 4 times the time (the stand-in's Lua, timed with os.clock: the ratio is what counts; before the fix about 25x)
  C the lists are unchanged: a group holding loaded rules is in Loaded, one holding only not-loaded rules in Not Loaded, a new empty
    group in the list it was made in (Loaded / Not Loaded), a group whose rules are all switched off is in Disabled and not in Loaded,
    and a group that holds rules only inside its nested groups is not listed as empty
  D the group helpers give the same answers as before (a rule in a nested group is in every group above it; a looping parent chain
    ends; a missing group holds nothing)
Run: python3 tests/fix_u5rulestree_folder_cost_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local INFO = {}
local function check(name, ok, extra) R[#R + 1] = { name .. "  [" .. tostring(extra) .. "]", ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
local P = ns and ns.OptionsApi and ns.OptionsApi.RuleEditorParts
check("the settings window addon and the rule editor are loaded", reg and P and P.FolderRules, tostring(P))
if not (reg and P and P.FolderRules) then return R end
ns.Print = function() end
local APP = "CueRules"
local function mkRule(name, folderId, loaded, enabled)
  local r = ns.NewRule(); r.name = name; r.folder = folderId; r.enabled = enabled ~= false; r.uid = ns.NewUID()
  r.useCd = true; r.spellID = 203720; r.cdState = "ready"
  if not loaded then r.load = { combat = "yes" } end   -- loads only in combat: Not Loaded out of combat
  r.visual.enabled, r.sound.enabled = false, false
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  local c = ns.NewRule(); c.name = name .. " (cue)"; c.parentUid = r.uid; c.isCue, c.cueKind = true, "icon"; c.folder = folderId
  c.visual.enabled = true; c.visual.kind = "spellicon"; c.visual.trigger = "condition"; c.enabled = true
  ns.NormalizeRule(c); ns.rules[#ns.rules + 1] = c
  return r
end
local function shape(withGroups, nRules)
  ns.rules, ns.folders = {}, {}
  CueRulesDB.rules, CueRulesDB.folders = ns.rules, ns.folders
  local leaves = {}
  if withGroups then   -- Class > Spec > type, as Auto-Generate Rules makes them (4 + 12 + 48 = 64 groups)
    for c = 1, 4 do
      local cf = ns.NewFolder("Class " .. c)
      for s = 1, 3 do
        local sf = ns.NewFolder("Spec " .. c .. "." .. s, cf.id)
        for _, t in ipairs({ "Defensive", "Offensive", "Utility", "Unsorted" }) do leaves[#leaves + 1] = ns.NewFolder(t, sf.id) end
      end
    end
  end
  for i = 1, nRules do
    local leaf = leaves[(i % math.max(1, #leaves)) + 1]
    mkRule("Rule " .. i, leaf and leaf.id or nil, i % 3 ~= 0, i % 10 ~= 0)
  end
end
local function build() return reg:GetOptionsTable(APP)("dialog", "AceConfigDialog-3.0") end
local function measure(withGroups, nRules)
  shape(withGroups, nRules)
  build()   -- (warm up)
  collectgarbage("collect"); collectgarbage("stop")
  local k0 = collectgarbage("count")
  local t0 = os.clock()
  build()
  local dt, kb = os.clock() - t0, collectgarbage("count") - k0
  collectgarbage("restart"); collectgarbage("collect")
  local best = dt
  for _ = 1, 2 do local t1 = os.clock(); build(); best = math.min(best, os.clock() - t1) end
  return best, kb
end
-- What each further rule adds to a build (300 more rules, each with a cue), without groups and with 64 groups. (Each group's own page
-- is built once per build whatever the rules: that part does not grow with the rules and is left out by taking the difference.)
local tA, gA = measure(false, 150)
local tB, gB = measure(false, 450)
local tC, gC = measure(true, 150)
local tD, gD = measure(true, 450)
INFO[#INFO + 1] = ("no groups: %.1f / %.1f ms, %.2f / %.2f MB;  64 groups: %.1f / %.1f ms, %.2f / %.2f MB per build (150 / 450 rules)"):format(
  tA * 1000, tB * 1000, gA / 1024, gB / 1024, tC * 1000, tD * 1000, gC / 1024, gD / 1024)
local dg0, dg1, dt0, dt1 = gB - gA, gD - gC, tB - tA, tD - tC
check("A 300 more rules (600 with their cues) in 64 groups add less than 2x the garbage they add with no groups", dg1 < 2 * dg0,
  ("%.2f MB vs %.2f MB"):format(dg1 / 1024, dg0 / 1024))
check("B ...and less than 4x the time", dt1 < 4 * dt0, ("%.1f ms vs %.1f ms"):format(dt1 * 1000, dt0 * 1000))

-- C the lists
ns.rules, ns.folders = {}, {}
CueRulesDB.rules, CueRulesDB.folders = ns.rules, ns.folders
local gL = ns.NewFolder("Has loaded"); mkRule("L1", gL.id, true)
local gN = ns.NewFolder("Has not loaded"); mkRule("N1", gN.id, false)
local gE = ns.NewFolder("Empty here")
local gEN = ns.NewFolder("Empty made in Not Loaded"); gEN.xuiScope = "notloaded"
local gD = ns.NewFolder("All off"); mkRule("D1", gD.id, true, false)
local gO = ns.NewFolder("Outer"); local gI = ns.NewFolder("Inner off", gO.id); mkRule("D2", gI.id, true, false)
local t = build()
local tabs = t.args.cooldowns.args
local loaded, notl, dis = tabs.enabledTab.args.loaded.args, tabs.enabledTab.args.notloaded.args, tabs.disabledTab.args.disabled.args
local function has(list, id) return list[id] ~= nil end
check("C a group holding a loaded rule is in Loaded (not in Not Loaded)", has(loaded, gL.id) and not has(notl, gL.id))
check("C a group holding only a not-loaded rule is in Not Loaded (not in Loaded)", has(notl, gN.id) and not has(loaded, gN.id))
check("C a new empty group is in Loaded; one made in Not Loaded is in Not Loaded", has(loaded, gE.id) and not has(notl, gE.id) and has(notl, gEN.id) and not has(loaded, gEN.id))
check("C a group whose rules are all switched off is in Disabled, not in Loaded", has(dis, gD.id) and not has(loaded, gD.id) and not has(notl, gD.id))
check("C a group holding rules only inside its nested group is not listed as an empty group", not has(loaded, gO.id) and not has(notl, gO.id))

-- D the helpers
local inner = 0
for _, r in ipairs(P.FolderRules(gO.id)) do if r.folder == gI.id then inner = inner + 1 end end
check("D a rule (and its cue) in a nested group is in the group above it", #P.FolderRules(gO.id) == 2 and inner == 2, #P.FolderRules(gO.id))
check("D IsInFolder: nested yes, sibling no", P.IsInFolder(gI.id, gO.id) and not P.IsInFolder(gL.id, gO.id))
check("D a group that does not exist holds nothing", #P.FolderRules("f-none") == 0)
local a, b = ns.NewFolder("Loop A"), ns.NewFolder("Loop B"); a.parent, b.parent = b.id, a.id; mkRule("Looped", a.id, true)
check("D a looping parent chain ends: the rule is in both groups of the loop, counted once", #P.FolderRules(a.id) == 2 and #P.FolderRules(b.id) == 2 and not P.IsInFolder(a.id, gO.id),
  #P.FolderRules(a.id) .. "/" .. #P.FolderRules(b.id))
local okB = pcall(build)
check("D ...and the window still builds with it", okB)
return R, INFO
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
    res, info = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    if info:
        for i in range(1, len(info) + 1):
            print("INFO", info[i])
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
