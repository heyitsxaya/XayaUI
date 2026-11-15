#!/usr/bin/env python3
"""Offline test (round 8, engine-core item 2; REQUEST-LOG A23 SD-68, her answer "option two with gating and a performance tracker").
A Range Check row on a focus, mouseover or pet has no game range event (events.md:1440 and :23 name no unit; :1606 carries a fixed group
range), so the engine re-checks such a rule every 0.2 s. Before round 8 it did so for as long as the rule was loaded, with no focus, pet or
mouseover at all. Now only while that unit exists: a focus from PLAYER_FOCUS_CHANGED (events.md:1177), a pet from UNIT_PET (:1616), a
mouseover from UPDATE_MOUSEOVER_UNIT (:1679; the game sends nothing when the mouse leaves, so the re-check stops itself on the first pass
that finds no mouseover). How often it ran is counted in ns.EngineStats.pollRange (read by XayaUI_Debug).

What the player gets (one rule per unit, its display shown "while in range", in a fresh stand-in game):
  1. no focus, no pet, no mouseover: none of the three rules is re-checked in three seconds, and no engine timer is armed;
  2. a focus appears (PLAYER_FOCUS_CHANGED): its rule is re-checked about every 0.2 s (pollRange counts it); the focus walks out of range
     with no event: the display hides within 0.2 s and a frame; the focus is cleared: the re-checks stop;
  3. a pet is summoned (UNIT_PET): the same for the pet rule; the pet is dismissed: they stop;
  4. the mouse moves onto a unit (UPDATE_MOUSEOVER_UNIT): the same for the mouseover rule; the mouse leaves (no event): the re-checks stop
     by themselves within 0.2 s and a frame, and no engine timer stays armed;
  5. off costs nothing (V14): UNIT_PET and UPDATE_MOUSEOVER_UNIT are listened to only while a pet / mouseover rule is loaded.
Stand-in: the whole-addon harness; UnitExists and C_Spell.IsSpellInRange are stubbed (globals.md:588: UnitExists' result is not secret).
UNVERIFIED IN GAME: whether the game sends PLAYER_FOCUS_CHANGED when a focus despawns, and the in-game cost (QA B414 measures it).
Run: python3 tests/fix_r8_engine_poll_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local FRAME = 1 / 60
local exists, inRange = { focus = false, pet = false, mouseover = false }, { focus = true, pet = true, mouseover = true }
local UE0 = UnitExists
UnitExists = function(u) if exists[u] ~= nil then return exists[u] end return UE0(u) end
C_Spell.IsSpellInRange = function(id, unit) if exists[unit] then return inRange[unit] end return nil end
-- engine timers still armed
local engineTimers = {}
local function fromEngine() local i = debug.getinfo(3, "S"); return i and i.source and i.source:find("Engine.lua", 1, true) ~= nil end
local A0, T0 = C_Timer.After, C_Timer.NewTimer
C_Timer.After = function(d, fn)
  if fromEngine() then local rec = { done = false }; engineTimers[#engineTimers + 1] = rec; return A0(d, function(...) rec.done = true; return fn(...) end) end
  return A0(d, fn)
end
C_Timer.NewTimer = function(d, fn)
  if fromEngine() then
    local rec = { done = false }
    local h = T0(d, function(...) rec.done = true; return fn(...) end)
    rec.handle = h; engineTimers[#engineTimers + 1] = rec
    return h
  end
  return T0(d, fn)
end
local function armed() local n = 0; for _, t in ipairs(engineTimers) do if not t.done and not (t.handle and t.handle:IsCancelled()) then n = n + 1 end end; return n end
-- the engine's own frames (made by XayaUI_Rules/Engine.lua): other files and the stand-in may listen to these events for their own reasons
local engineFrames = {}
local CF0 = CreateFrame
CreateFrame = function(...)
  local f = CF0(...)
  local i = debug.getinfo(2, "S")
  if i and i.source and i.source:find("Engine.lua", 1, true) then engineFrames[#engineFrames + 1] = f end
  return f
end
local function listening(ev) for _, o in ipairs(engineFrames) do if o._events and o._events[ev] then return true end end return false end

L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
check("5. (setup) with no rule loaded, the engine does not listen to UNIT_PET or UPDATE_MOUSEOVER_UNIT", not listening("UNIT_PET") and not listening("UPDATE_MOUSEOVER_UNIT"))
local RU = {}
for _, u in ipairs({ "focus", "pet", "mouseover" }) do
  local r = ns.NewRule(); r.name = "range " .. u; r.enabled = true; r.useBuff = false
  r.extra = { mode = "all", list = { { type = "rangeCheck", spellID = 6001, unit = u, state = "yes" } } }
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.text.enabled = false; r.sound.enabled = false; r.visual.trigger = "condition"
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; RU[u] = r
end
ns.MarkDirty(); W.tick(FRAME, 10)
check("5. with a pet and a mouseover range rule loaded, the engine listens to UNIT_PET and UPDATE_MOUSEOVER_UNIT", listening("UNIT_PET") and listening("UPDATE_MOUSEOVER_UNIT"))
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown(r) local fr = framesOf and framesOf[r]; return fr and fr:IsShown() and true or false end
local ev = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) ev[r] = (ev[r] or 0) + 1; return E0(r, ...) end
local ES = ns.EngineStats
local function pr() return ES and ES.pollRange or 0 end
local function n(r) return ev[r] or 0 end

-- 1. none of the units exists
W.tick(FRAME, 30)
local a0, b0, c0, p0 = n(RU.focus), n(RU.pet), n(RU.mouseover), pr()
W.tick(FRAME, 180)
check("1. no focus, pet or mouseover: none of the three range rules is re-checked in three seconds (before: about 15 times each)",
  n(RU.focus) - a0 == 0 and n(RU.pet) - b0 == 0 and n(RU.mouseover) - c0 == 0,
  (n(RU.focus) - a0) .. "/" .. (n(RU.pet) - b0) .. "/" .. (n(RU.mouseover) - c0))
check("1. ... and no engine timer is armed", armed() == 0, armed())

local function case(u, startEv, startArg, stopEv, stopArg, label)
  exists[u], inRange[u] = true, true
  W.fire(startEv, startArg); W.tick(FRAME, 3)
  check(label .. ": in range, its display shows on the next frames", shown(RU[u]))
  local e0, q0 = n(RU[u]), pr()
  W.tick(FRAME, 60)
  local got = n(RU[u]) - e0
  check(label .. ": it is re-checked about every 0.2 s while the unit exists (one second: 4 to 6 times)", got >= 4 and got <= 6, got)
  check(label .. ": ... counted in ns.EngineStats.pollRange", ES ~= nil and pr() - q0 >= 4, ES and (pr() - q0) or "no ns.EngineStats")
  inRange[u] = false
  local t0, hid = W.now, nil
  for _ = 1, 30 do W.tick(FRAME, 1); if not hid and not shown(RU[u]) then hid = W.now - t0 end end
  check(label .. ": out of range with no event: the display hides within 0.2 s and a frame", hid ~= nil and hid <= 0.2 + FRAME + 0.0005,
    hid and ("%.0f ms"):format(hid * 1000) or "still shown")
  exists[u] = false
  if stopEv then W.fire(stopEv, stopArg) end
  W.tick(FRAME, 15)
  local e1, q1 = n(RU[u]), pr()
  W.tick(FRAME, 120)
  check(label .. ": the unit gone" .. (stopEv and "" or " (no event)") .. ": the re-checks stop (two quiet seconds)", n(RU[u]) - e1 == 0 and pr() - q1 == 0,
    (n(RU[u]) - e1) .. " / " .. (pr() - q1))
  check(label .. ": ... and no engine timer stays armed", armed() == 0, armed())
end
case("focus", "PLAYER_FOCUS_CHANGED", nil, "PLAYER_FOCUS_CHANGED", nil, "2. focus")
case("pet", "UNIT_PET", "player", "UNIT_PET", "player", "3. pet")
case("mouseover", "UPDATE_MOUSEOVER_UNIT", nil, nil, nil, "4. mouseover")
-- 5. switched off: the pet and mouseover events are let go
RU.pet.enabled, RU.mouseover.enabled = false, false
ns.MarkDirty(); W.tick(FRAME, 10)
check("5. with the pet and mouseover range rules switched off, the engine lets UNIT_PET and UPDATE_MOUSEOVER_UNIT go (V14)",
  not listening("UNIT_PET") and not listening("UPDATE_MOUSEOVER_UNIT"))
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
    total = bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], bool(res[i][2])
        total += 1
        print(("ok  " if ok else "FAIL: ") + name)
        bad += 0 if ok else 1
    nerr = len(world.errors)
    for i in range(1, nerr + 1):
        print("ERROR in the game stand-in: %s" % str(world.errors[i])[:600])
    print("%d checks, %d failed, %d Lua errors" % (total, bad, nerr))
    sys.exit(1 if bad or nerr else 0)


if __name__ == "__main__":
    main()
