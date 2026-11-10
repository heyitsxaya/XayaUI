#!/usr/bin/env python3
"""Review R19 / R20 follow-ups (docs/plans/RULES-REVIEW-2026-11-10.md; bundle-1 review "U2-visual"), Visual.lua and
Combat/AuraDisplay.lua.
(a) A group's Auto-size border / background box is followed by a watcher 5 times a second. It re-applied its whole look on every
    tick (a new backdrop table, colours, texture, strata, anchors). Now a tick only moves / resizes the box when what it measures
    changed; the look is applied on a refresh or a settings change.
(b) A deleted dynamic group's buff container kept showing its buffs (D.Build only visited the groups still in the list), while
    the members, moved up a level, got their own icons: each buff was drawn twice until /reload. Now it is retired.
Checks, on the real addons in the stand-in game (the game's aura container is a recorder here):
- Auto box with Border + Background: 2 s of watcher ticks with nothing moving re-apply nothing and move nothing; the box is still
  around the display;
- the display moves: the box follows (placement only, the look is not applied again); the display hides: the box hides; it shows
  again: the box comes back with its background and border;
- a settings change (background colour, border size, border off) still reaches the box; with no colour set the background is the
  default see-through black;
- (b) a dynamic group of two buffs, deleted: each buff is drawn by exactly one shown container (old: two), and the deleted group
  is no longer counted for group boxes; restored: the group's container draws both again, each once.
Old code: the 'nothing re-applied' check and the 'drawn once' checks fail.
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
check("core and the combat engine are loaded", ns and D and ns.UpdateGroupBoxes and ns.GroupBox and ns.UpdateGroupBox)
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
local function rect(fr) local l, b, w, h = fr:GetRect(); return l, b, l + w, b + h end
local function near(a, b) return a and b and math.abs(a - b) < 0.6 end
local function desc(box) if not (box and box:IsShown()) then return "box hidden" end local l, b, r, t = rect(box); return ("box %.1f %.1f %.1f %.1f"):format(l, b, r, t) end

-------------------------------------------------------------------------------------------------------------------------------
-- (a) the Auto box's watcher tick
-------------------------------------------------------------------------------------------------------------------------------
local G = ns.NewFolder("Boxed"); G.cBg = true; G.cBorder = true; G.cPad = 4; G.cX, G.cY = 200, 100
local r = ns.NewRule(); r.name = "Own display"; r.folder = G.id; r.enabled = true
r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = 0, 0; r.visual.w, r.visual.h = 40, 40
ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }
ns.SetPreview({ r }, "visual", true)
ns.MarkDirty(); ns.RefreshAllVisuals(); W.tick(0.25, 8)   -- (2 s: the engine's rebuild a second after an edit has run)
local box, fr = ns.GroupBox(G), ns.DisplayFrame(r)
local function around()
  if not (box and box:IsShown() and fr and fr:IsShown()) then return false end
  local l, b, rr, t = rect(fr); local bl, bb, br, bt = rect(box)
  return near(bl, l - 4) and near(bb, b - 4) and near(br, rr + 4) and near(bt, t + 4)
end
check("Auto + Border + Background: the box shows around the display plus the padding", around(), desc(box))
check("  ...the watcher that follows Auto boxes runs", ns.GroupBoxWatching())
if not (box and fr) then return R end
-- count what the box is told to do (the calls still go through)
local LOOK = { "SetBackdrop", "SetBackdropBorderColor", "SetFrameStrata", "SetFrameLevel" }
local BGLOOK = { "SetColorTexture", "SetTexture", "SetVertexColor" }
local PLACE = { "ClearAllPoints", "SetPoint", "SetSize", "SetParent" }
local n = {}
local function spy(o, list, tag)
  for _, m in ipairs(list) do
    local orig = o[m]
    rawset(o, m, function(...) n[tag] = (n[tag] or 0) + 1; return orig(...) end)
  end
end
spy(box, LOOK, "look"); spy(box.bg, BGLOOK, "look"); spy(box, PLACE, "place")
local function reset() n.look, n.place = 0, 0 end
reset()
W.tick(0.2, 10)   -- 2 s: 10 watcher ticks, nothing moves
check("R19 follow-up: 2 s of watcher ticks with nothing moving re-apply no look (backdrop, colours, texture, strata)", n.look == 0, n.look .. " calls")
check("  ...and do not move or resize the box", n.place == 0, n.place .. " calls")
check("  ...the box is still shown around the display", around(), desc(box))
-- the display moves (as items come and go in a group): the box follows on the next tick, placement only
reset()
fr:ClearAllPoints(); fr:SetPoint("CENTER", UIParent, "CENTER", -150, -80)
W.tick(0.2, 2)
check("the display moves: the box follows it", around(), desc(box))
check("  ...by moving / resizing only (the look is not applied again)", n.place > 0 and n.look == 0, ("place %d, look %d"):format(n.place, n.look))
-- nothing showing: the box hides; showing again: it comes back with its background and border
ns.runtime[r].visualWanted = false; ns.SetPreview({ r }, "visual", false); W.tick(0.2, 2)
check("the display hides: the box hides", not box:IsShown(), "display " .. tostring(fr:IsShown()) .. ", " .. desc(box))
ns.runtime[r].visualWanted = true; ns.SetPreview({ r }, "visual", true); W.tick(0.2, 2)
check("  ...it shows again: the box is back around it, background and border on", around() and box.bg:IsShown() and box:GetBackdrop() ~= nil, desc(box))
-- settings changes still reach the box (the editor calls ns.UpdateGroupBox on each step; a refresh calls it for every group)
local c = box.bg._color
check("no colour set: the background is the default see-through black", c and near(c[1], 0) and near(c[2], 0) and near(c[3], 0) and math.abs((c[4] or 0) - 0.45) < 0.01,
  c and table.concat(c, ",") or "none")
G.cBgColor = { 1, 0, 0, 0.5 }; ns.UpdateGroupBox(G)
c = box.bg._color
check("background colour changed: the box takes it", c and near(c[1], 1) and near(c[2], 0) and math.abs((c[4] or 0) - 0.5) < 0.01, c and table.concat(c, ",") or "none")
G.cBdSize = 3; ns.UpdateGroupBox(G)
local bd = box:GetBackdrop()
check("border size changed: the border takes it", bd and bd.edgeSize == 3, bd and bd.edgeSize)
G.cBorder = nil; ns.MarkDirty(); ns.RefreshAllVisuals(); W.tick(0.2, 2)
check("border switched off: the border is gone, the background stays", box:GetBackdrop() == nil and box.bg:IsShown() and box:IsShown())
G.cBorder = true; ns.MarkDirty(); ns.RefreshAllVisuals(); W.tick(0.2, 2)
bd = box:GetBackdrop()
check("  ...switched on again: the border is back at its size", bd and bd.edgeSize == 3, bd and bd.edgeSize)
ns.SetPreview({ r }, "visual", false)

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
check("  ...the deleted group no longer counts for group boxes", not engineListsGroup(Dy.id))
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
