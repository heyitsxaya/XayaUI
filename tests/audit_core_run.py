#!/usr/bin/env python3
"""Function audit (UI-60, REQUEST-LOG A11; docs/process/FUNCTION-AUDIT-2026-11-07.md), core fixes in core 0.6.60.
- D18: a static group's saved arrangement re-applied 5 times leaves X / Y unchanged ("applying again changes nothing", Visual.lua).
  Old code: the centre was rounded, then X / Y rounded again: X, Y grew by 1 per apply (1, 2, 3, 4, 5) for 37x37 TOPLEFT displays.
- D19: Snap Target to a frame that does not exist keeps the display's X / Y and saves no snap ("the aura keeps its own position").
  Old code: X / Y were set to 0, 0 and the snap saved before the check.
Run: python3 tests/audit_core_run.py   (Lua 5.1 via lupa; the stand-in game in tests/harness)."""
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
local function mk(f, name, x, y, w, h, point)
  local r = ns.NewRule(); r.name = name; r.folder = f.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.w, r.visual.h = w, h
  r.visual.point = point
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
-- D18: three shapes that put a centre on a half pixel
local cases = {
  { "37x37 TOPLEFT, Align left + top, set 200x200 box", 37, 37, "TOPLEFT", 200, 200, "left", "top" },
  { "40x40 CENTER, Align right + bottom, set 201x201 box", 40, 40, nil, 201, 201, "right", "bottom" },
  { "37x41 TOPLEFT, Distribute + Space, set 300x100 box", 37, 41, "TOPLEFT", 300, 100, "distribute", "space" },
}
for _, c in ipairs(cases) do
  local f = ns.NewFolder("Arr " .. c[1]); f.cW, f.cH = c[5], c[6]
  local A, B, C = mk(f, "A", 0, 0, c[2], c[3], c[4]), mk(f, "B", 60, -10, c[2], c[3], c[4]), mk(f, "C", 130, 5, c[2], c[3], c[4])
  f.cArrX, f.cArrY = c[7], c[8]
  ns.ApplyGroupArrangement(f)
  local x1 = { A.visual.x, A.visual.y, B.visual.x, B.visual.y, C.visual.x, C.visual.y }
  local trail = {}
  for i = 1, 5 do ns.ApplyGroupArrangement(f); trail[#trail + 1] = A.visual.x .. "," .. A.visual.y .. "/" .. B.visual.x .. "," .. B.visual.y end
  local same = A.visual.x == x1[1] and A.visual.y == x1[2] and B.visual.x == x1[3] and B.visual.y == x1[4] and C.visual.x == x1[5] and C.visual.y == x1[6]
  check("D18 " .. c[1] .. ": 5 more applies change nothing", same, table.concat(trail, " "))
  check("D18 " .. c[1] .. ": X / Y stay whole numbers", A.visual.x % 1 == 0 and A.visual.y % 1 == 0 and C.visual.x % 1 == 0, x1[1] .. "," .. x1[2])
end
-- D18: Align left still lines up the left edges (the arrangement itself still works)
do
  local f = ns.NewFolder("Edges"); f.cW, f.cH = 200, 200
  local A, B = mk(f, "A", 3, 0, 37, 37, "TOPLEFT"), mk(f, "B", 40, -50, 37, 37, "TOPLEFT")
  f.cArrX = "left"; ns.ApplyGroupArrangement(f)
  check("D18 Align left: both left edges in line", A.visual.x == B.visual.x, A.visual.x .. " vs " .. B.visual.x)
end
-- D19: snap to a frame missing in this client
do
  local f = ns.NewFolder("Snap")
  local r = mk(f, "S", 37, -12, 40, 40)
  local saved = ns.Print; local said; ns.Print = function(m) said = m end
  ns.SnapToTarget(r, "nosuchframe_key", "TOP_CENTER")
  ns.Print = saved
  check("D19 missing frame: X / Y kept", r.visual.x == 37 and r.visual.y == -12, tostring(r.visual.x) .. "," .. tostring(r.visual.y))
  check("D19 missing frame: no snap saved", not (r.visual.snap and r.visual.snap.target), r.visual.snap and r.visual.snap.target)
  check("D19 missing frame: chat says it keeps its position", said and said:find("keeps its own position", 1, true), said)
end
-- D9 / D10: the talent scan
do
  local saveCT, saveTr, saveC = rawget(_G, "C_ClassTalents"), rawget(_G, "C_Traits"), rawget(_G, "Constants")
  C_ClassTalents = { InitializeViewLoadout = function() error("api changed") end, ViewLoadout = function() error("api changed") end }
  C_Traits = C_Traits or {}
  Constants = Constants or {}; Constants.TraitConsts = Constants.TraitConsts or { VIEW_TRAIT_CONFIG_ID = -3 }
  local good = { built = "old", classes = { [1] = { specs = {}, nodes = {} } }, errors = {} }
  XayaUITalentDB = good
  PlayerSpellsFrame = CreateFrame("Frame", "PlayerSpellsFrame", UIParent); PlayerSpellsFrame:Show()
  local ok, why = ns.ScanAllTalents()
  check("D9 talent window (PlayerSpellsFrame) open: the scan refuses", ok == false and tostring(why):find("Close the talent window", 1, true), why)
  PlayerSpellsFrame:Hide()
  local said; local sp = ns.Print; ns.Print = function(m) said = m end
  ok = ns.ScanAllTalents()
  W.tick(0.05, 30)
  ns.Print = sp
  check("D10 every class failed: the last good scan is kept", XayaUITalentDB == good, XayaUITalentDB and XayaUITalentDB.built)
  check("D10 the chat line says the previous scan is kept", said and said:find("previous scan is kept", 1, true), said)
  C_ClassTalents, C_Traits, Constants = saveCT, saveTr, saveC
end
-- D11 / FA-12: the minimap list row is "XayaUI Settings" and says it opens or closes
do
  local row
  for _, e in ipairs(ns.Launchers and ns.Launchers() or {}) do if e[1] == "settings" then row = e end end
  if not row and ns.launchers then for _, e in ipairs(ns.launchers) do if e[1] == "settings" then row = e end end end
  check("D11 minimap row named XayaUI Settings, tooltip says open or close", row and row[2] == "XayaUI Settings" and tostring(row[3]):find("Open or close", 1, true), row and row[2])
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
