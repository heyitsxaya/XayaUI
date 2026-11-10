#!/usr/bin/env python3
"""Review R21 (docs/plans/RULES-REVIEW-2026-11-10.md): a static group's saved arrangement crept when its displays mixed odd and even
sizes. The arrangement is applied again on every refresh (loading screens, every edit), so the row climbed half a pixel per apply,
for ever, the saved X / Y changed by themselves, and the mover view reported moves nobody made.
Checks, on the real addons in the stand-in game:
- the reported case (a 40x35 and a 40x40 display, both on the default point, Align top): 10 more refreshes leave X / Y as they are;
- 400 random groups (2 to 4 displays, mixed sizes, random own / target points, set or auto size, every Align / Distribute / Space
  mode): after the first apply, 12 more applies change no X / Y;
- the arrangement still does its job: aligned edges / centres in line within 1 px, and no display sticks out past an aligned edge.
Old code: the first check and most random groups drift (Y climbs 1 px every second apply).
Run: python3 tests/fix_u2visual_arrange_drift_run.py   (Lua 5.1 via lupa)."""
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
check("core keeps a group arrangement", ns and ns.ApplyGroupArrangement and ns.VisualCenterOffset)
if not (ns and ns.ApplyGroupArrangement) then return R end
local function mk(f, name, x, y, w, h, point, anchor)
  local r = ns.NewRule(); r.name = name; r.folder = f.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.w, r.visual.h = w, h
  r.visual.point, r.visual.anchor = point, anchor
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local function snap(l) local t = {}; for _, r in ipairs(l) do t[#t + 1] = r.visual.x .. "," .. r.visual.y end; return table.concat(t, " ") end

-- the reported case, through the real refresh path
do
  local f = ns.NewFolder("Align top 35 + 40")
  local A, B = mk(f, "A", 0, 0, 40, 35), mk(f, "B", 60, 0, 40, 40)
  f.cArrY = "top"
  ns.RefreshAllVisuals()
  local first = snap({ A, B })
  local trail = {}
  for i = 1, 10 do ns.RefreshAllVisuals(); trail[#trail + 1] = snap({ A, B }) end
  check("40x35 + 40x40, Align top: 10 more refreshes leave X / Y as they are", trail[#trail] == first, first .. " -> " .. table.concat(trail, " | "))
  local _, ay = ns.VisualCenterOffset(A); local _, by = ns.VisualCenterOffset(B)
  local ta, tb = ay + 35 / 2, by + 40 / 2
  check("  ...and their tops are in line (within 1 px), the 40 px one not pushed above", math.abs(ta - tb) < 1 and tb >= ta, ta .. " vs " .. tb)
end

-- random groups
local seed = 12345
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n + 1 end
local PTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local XM = { false, "left", "center", "right", "distribute", "space" }
local YM = { false, "top", "middle", "bottom", "distribute", "space" }
local drift, misaligned, groups, firstBad, firstMis = 0, 0, 0, nil, nil
for g = 1, 400 do
  local f = ns.NewFolder("R" .. g)
  if rnd(2) == 1 then f.cW, f.cH = 150 + rnd(101), 150 + rnd(101) end
  local l = {}
  for i = 1, 1 + rnd(3) do
    local pt = rnd(3) == 1 and PTS[rnd(9)] or nil
    local an = rnd(3) == 1 and PTS[rnd(9)] or nil
    l[i] = mk(f, "D" .. g .. "_" .. i, rnd(301) - 150, rnd(301) - 150, 19 + rnd(40), 19 + rnd(40), pt, an)
  end
  local xm, ym = XM[rnd(6)], YM[rnd(6)]
  if not xm and not ym then ym = "top" end
  f.cArrX, f.cArrY, f.cArrGap = xm or nil, ym or nil, 3 + rnd(8)
  groups = groups + 1
  ns.ApplyGroupArrangement(f)
  local first = snap(l)
  for _ = 1, 12 do ns.ApplyGroupArrangement(f) end
  if snap(l) ~= first then
    drift = drift + 1
    firstBad = firstBad or (tostring(xm) .. "/" .. tostring(ym) .. ": " .. first .. " -> " .. snap(l))
  end
  -- the arrangement still lines them up
  local e = {}
  for i, r in ipairs(l) do
    local cx, cy = ns.VisualCenterOffset(r); local w, h = r.visual.w, r.visual.h
    e[i] = { l = cx - w / 2, r = cx + w / 2, b = cy - h / 2, t = cy + h / 2, cx = cx, cy = cy }
  end
  local function spread(key)
    local lo, hi = math.huge, -math.huge
    for _, v in ipairs(e) do lo = math.min(lo, v[key]); hi = math.max(hi, v[key]) end
    return hi - lo
  end
  local bad = (xm == "left" and spread("l") >= 1) or (xm == "right" and spread("r") >= 1) or (xm == "center" and spread("cx") > 1)
    or (ym == "top" and spread("t") >= 1) or (ym == "bottom" and spread("b") >= 1) or (ym == "middle" and spread("cy") > 1)
  if bad then misaligned = misaligned + 1; firstMis = firstMis or (tostring(xm) .. "/" .. tostring(ym) .. ": " .. snap(l)) end
end
check(("random groups: after the first apply, 12 more change no X / Y (%d groups)"):format(groups), drift == 0, drift .. " drifted; first: " .. tostring(firstBad))
check("random groups: aligned edges / centres stay in line within 1 px", misaligned == 0, misaligned .. " off; first: " .. tostring(firstMis))
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
