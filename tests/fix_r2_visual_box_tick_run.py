#!/usr/bin/env python3
"""Review R19 / R20 follow-ups (docs/plans/RULES-REVIEW-2026-11-10.md; bundle-1 review "U2-visual"), Visual.lua and
Combat/AuraDisplay.lua.
(b) A deleted dynamic group's buff container kept showing its buffs (D.Build only visited the groups still in the list), while
    the members, moved up a level, got their own icons: each buff was drawn twice until /reload. Now it is retired.
Checks, on the real addons in the stand-in game (the game's aura container is a recorder here):
- (b) a dynamic group of two buffs, deleted: each buff is drawn by exactly one shown container (old: two), and the deleted group
  is no longer counted for the mover outline (Visual.lua GroupBounds); restored: the group's container draws both again, each once.
(SD-17, round 3: the group border / background box and its watcher are gone (drawn on each display instead), so part (a), which
checked the watcher's tick, is removed; the new behaviour is checked by tests/fix_r3_border_run.py.)
Old code: the 'drawn once' checks fail.
Run: python3 tests/fix_r2_visual_box_tick_run.py   (Lua 5.1 via lupa)."""
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
local D = ns and ns.AuraDisplay
check("core and the combat engine are loaded", ns and D and ns.EngineSlotsEach)
if not (ns and D) then return R end
-- the game's aura container cannot run here: a recorder that keeps which buff IDs each of its aura groups lets through
CustomAuraContainerAuraProcessingPolicy = CustomAuraContainerAuraProcessingPolicy or { None = 0 }
AuraContainerSortMethod = AuraContainerSortMethod or { Default = 0, Expiration = 4, Name = 6 }
AuraContainerSortDirection = AuraContainerSortDirection or { Normal = 0, Reverse = 1 }
AnchorUtil = AnchorUtil or {}
AnchorUtil.FlowLayoutAxis = AnchorUtil.FlowLayoutAxis or { Horizontal = 0, Vertical = 1 }
AnchorUtil.FlowDirection = AnchorUtil.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }
local made = {}
local CF = CreateFrame
CreateFrame = function(kind, ...)
  local o = CF(kind == "AuraContainer" and "Frame" or kind, ...)
  if kind == "AuraContainer" then
    local rec = { ids = {}, on = {} }
    made[#made + 1] = { frame = o, rec = rec }
    for _, m in ipairs({ "SetUnit", "SetAuraProcessingPolicy", "SetAuraGroupLayout", "SetAuraGroupSortMethod", "SetFlowLayoutAxis",
      "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection", "SetFlowLayoutMaximumLineSize" }) do rawset(o, m, function() end) end
    rawset(o, "AddAuraGroup", function(_, name, _, info)
      rec.ids[name] = info and info.candidateFilters and info.candidateFilters.includeSpellIDs or {}; rec.on[name] = true
    end)
    rawset(o, "SetAuraGroupCandidateFilters", function(_, name, flt) rec.ids[name] = flt and flt.includeSpellIDs or {} end)
    rawset(o, "SetAuraGroupEnabled", function(_, name, v) rec.on[name] = v and true or false end)
  end
  return o
end
ns.runtime = ns.runtime or {}

-------------------------------------------------------------------------------------------------------------------------------
-- (b) a deleted dynamic group's buff container
-------------------------------------------------------------------------------------------------------------------------------
local nextID = 71000
local function mkBuff(f, name)
  nextID = nextID + 1
  local x = ns.NewRule(); x.name = name; x.folder = f.id; x.enabled = true
  x.visual = x.visual or {}; x.visual.enabled = true; x.visual.w, x.visual.h = 30, 30
  ns.NormalizeRule(x)
  x.useBuff, x.buffID, x.visual.trigger = true, nextID, "buffActive"
  ns.rules[#ns.rules + 1] = x
  ns.runtime[x] = { active = true, lastPlay = 0, visualWanted = true }
  return x
end
-- how many shown containers would draw this buff (a container on screen with an aura group switched on that lets it through)
local function drawers(id)
  local k = 0
  for _, m in ipairs(made) do
    if m.frame:IsVisible() then
      local hit = false
      for name, ids in pairs(m.rec.ids) do if m.rec.on[name] and ids[id] then hit = true end end
      if hit then k = k + 1 end
    end
  end
  return k
end
local function engineListsGroup(fid)
  local seen = false
  ns.EngineSlotsEach(function(host, f) if host == nil and f == fid then seen = true end end)
  return seen
end
local Dy = ns.NewFolder("Dynamic buffs"); Dy.cType = "dynamic"; Dy.cGrowth = "RIGHT"; Dy.cSpacing = 4; Dy.cX, Dy.cY = 0, -250
local b1, b2 = mkBuff(Dy, "Dyn buff 1"), mkBuff(Dy, "Dyn buff 2")
local function build() ns.MarkDirty(); D.Build(); ns.RefreshAllVisuals(); W.tick(0.25, 2) end
build()
check("the engine draws the dynamic group (both buffs in the group's container)", ns.EngineOwns(b1) and ns.EngineOwns(b2) and engineListsGroup(Dy.id))
check("  ...each buff is drawn once", drawers(b1.buffID) == 1 and drawers(b2.buffID) == 1, drawers(b1.buffID) .. "/" .. drawers(b2.buffID))
ns.RecycleFolder(Dy)
build()
check("R20 follow-up: the group deleted (Recycle Bin): its buffs are still drawn (the members moved up a level)",
  ns.EngineOwns(b1) and ns.EngineOwns(b2) and drawers(b1.buffID) >= 1 and drawers(b2.buffID) >= 1, drawers(b1.buffID) .. "/" .. drawers(b2.buffID))
check("  ...each buff is drawn once, not twice (the deleted group's container is gone)", drawers(b1.buffID) == 1 and drawers(b2.buffID) == 1,
  drawers(b1.buffID) .. "/" .. drawers(b2.buffID))
check("  ...the deleted group no longer counts for the mover outline", not engineListsGroup(Dy.id))
ns.folders[#ns.folders + 1] = Dy; b1.folder, b2.folder = Dy.id, Dy.id   -- (as Restore puts it back: same id)
build()
check("restored: the group's container draws both buffs again, each once", engineListsGroup(Dy.id) and drawers(b1.buffID) == 1 and drawers(b2.buffID) == 1,
  drawers(b1.buffID) .. "/" .. drawers(b2.buffID))
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
