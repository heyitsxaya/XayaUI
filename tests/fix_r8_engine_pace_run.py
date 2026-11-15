#!/usr/bin/env python3
"""Offline test (round 8, engine-core items 3 and 7; REQUEST-LOG A23 SD-66, her answer to "does 10/s for all include the every-live-rule
re-check": "1 -- can we guarantee performance and actually well-executed code?", recorded as "every re-check path at most 10 a second").
Round 7 held the routed passes to ROUTED_DUE = 0.0995 s apart, so 11 fell inside one second (the gate's warning "most runs within one
second: 11"), and the every-live-rule pass (movement, a target change, a glow ...) to MIN_GAP = 0.05 s, 20 a second; a load-fact change
re-checked every rule on every frame it happened.

What is measured (each part in its own fresh stand-in game; a pass is a frame in which the part's rule was checked):
  1. routed passes, an aura event every frame at 20 frames a second (0.0499 s apart: two frames add up to 0.0998 s, which round 7's
     0.0995 s let through): at most 10 passes in any one second; the first change after a quiet second on the very next frame;
  2. the every-live-rule pass, a target change every frame at 60 frames a second: at most 10 passes in any one second (round 7: 20);
     the first after a quiet second on the very next frame;
  3. full settles, a load fact (mounted) changing every frame at 60 frames a second: at most 10 full re-checks in any one second (round
     7: one per frame); the first after a quiet second on the very next frame, and the last change is never lost (the display ends as
     the last mount state says);
  4. every engine timer callback runs at most 10 times in any one second in parts 1 to 3 (the gate counts callback runs);
  5. a timer that fires before its moment (forced here: every engine one-shot timer of a part fires at half its delay): the routed and the
     every-live-rule passes still keep the pace and still run, and no frame script is left on (round 7 repair: before it, an early
     every-live-rule timer handed over to a frame script that ran every frame until the pace allowed the pass); (repair 1, the round-8
     reviewer) and a change at the END of a burst, with no event after it, is not lost when its timer fires early: a buff refreshed and
     removed two frames later (the routed timer), a target taken and dropped two frames later (the every-live-rule timer): the display
     shows the last state within half a second. In a storm the next event's Kick picks up lost work, so only a lone change shows a timer
     that fires early and does not set itself again;
  6. the combined maximum per second of the three paths when all three storms run at once is printed (not judged: each path is held on
     its own; SD-66 caps each path).
The tenth of a second applies to resource, range and cast re-checks too (they are routed): in a burst each can be up to 0.1 s late.
Stand-in: the whole-addon harness. The game's C_Timer firing at or after its delay is INFERENCE (UNVERIFIED IN GAME).
Run: python3 tests/fix_r8_engine_pace_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- engine timer callbacks: run times per callback function; an "early" mode fires each engine one-shot timer at half its delay
local EARLY = (MODE == "early")
local runs = {}
local function note(fn) local l = runs[fn]; if not l then l = {}; runs[fn] = l end; l[#l + 1] = W.now end
local function fromEngine() local i = debug.getinfo(3, "S"); return i and i.source and i.source:find("Engine.lua", 1, true) ~= nil end
local A0 = C_Timer.After
local early = 0
C_Timer.After = function(d, fn)
  if fromEngine() then
    local dd = d
    if EARLY and d > 0.02 then dd = d / 2; early = early + 1 end
    return A0(dd, function(...) note(fn); return fn(...) end)
  end
  return A0(d, fn)
end
local engineFrames = {}
local CF0 = CreateFrame
CreateFrame = function(...)
  local f = CF0(...)
  local i = debug.getinfo(2, "S")
  if i and i.source and i.source:find("Engine.lua", 1, true) then engineFrames[#engineFrames + 1] = f end
  return f
end
local function frameScriptOn() for _, f in ipairs(engineFrames) do if f._scripts and f._scripts.OnUpdate then return true end end return false end
local aura = { [1001] = { spellId = 1001, auraInstanceID = 501, name = "Probe", applications = 1, duration = 30, expirationTime = 0, sourceUnit = "player", isHelpful = true } }
C_UnitAuras.GetPlayerAuraBySpellID = function(id) local a = aura[id]; if a then local t = {}; for k, v in pairs(a) do t[k] = v end; return t end end
C_UnitAuras.GetUnitAuraBySpellID = function(u, id) if u == "player" then return C_UnitAuras.GetPlayerAuraBySpellID(id) end end
local mounted = false
IsMounted = function() return mounted end
local tgt = false
local UE0 = UnitExists
UnitExists = function(u, ...) if u == "target" then return tgt end return UE0(u, ...) end

L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local function mk(nm, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.text.enabled = false; r.sound.enabled = false; r.visual.trigger = "condition"
  f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local AU = mk("aura", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1001, "present", "none" end)
local MT = mk("mounted only", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1001, "present", "none"; r.load.mounted = "yes" end)
-- (early mode only) shows while you have a target: re-checked by the every-live-rule pass (a target change), nothing routed
local TG = EARLY and mk("has a target", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "playerState", what = "target", state = "yes" } } } end)
aura[1001].expirationTime = W.now + 30
ns.MarkDirty(); W.tick(1 / 60, 20)
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown(r) local fr = framesOf and framesOf[r]; return fr and fr:IsShown() and true or false end
local at = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...)
  local l = at[r]; if not l then l = {}; at[r] = l end
  if l[#l] ~= W.now then l[#l + 1] = W.now end
  return E0(r, ...)
end
local function most(l, from)
  local best = 0
  for i = 1, #l do
    if l[i] >= from then
      local n = 0
      for j = i, #l do if l[j] < l[i] + 1 - 1e-9 then n = n + 1 end end
      if n > best then best = n end
    end
  end
  return best
end
local function mostRuns(from)
  local best = 0
  for _, l in pairs(runs) do local n = most(l, from); if n > best then best = n end end
  return best
end
local function quiet() W.tick(0.25, 4) end
local function firstAfterQuiet(r, fire)
  quiet()
  local n0 = #(at[r] or {})
  fire(); W.tick(1 / 60, 1)
  return #(at[r] or {}) > n0
end
local P = {}
-- 1. routed: an aura event every frame at 20 frames a second
local function routed(sec, dt)
  local t0 = W.now
  local n = math.floor(sec / dt + 0.5)
  for i = 1, n do
    aura[1001].expirationTime = W.now + 30 + i   -- (a refresh: the check answers differently each time, so each pass re-checks the rule)
    W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 501 } })
    W.tick(dt, 1)
  end
  return t0
end
-- 2. every live rule: a target change every frame
local function allStorm(sec, dt)
  local t0 = W.now
  for _ = 1, math.floor(sec / dt + 0.5) do W.fire("PLAYER_TARGET_CHANGED"); W.tick(dt, 1) end
  return t0
end
-- 3. settles: mounted on, off, on ... every frame (the "mounted only" rule is not loaded when not mounted: only a full step checks it)
local function mountStorm(sec, dt)
  local t0 = W.now
  for _ = 1, math.floor(sec / dt + 0.5) do mounted = not mounted; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); W.tick(dt, 1) end
  return t0
end

if MODE == "main" then
  local ok1 = firstAfterQuiet(AU, function() aura[1001].expirationTime = W.now + 31; W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 501 } }) end)
  check("1. routed: the first aura change after a quiet moment is checked on the very next frame", ok1)
  quiet()
  local r0 = mostRuns(-1)
  local t1 = routed(3, 0.0499)
  P.routed = most(at[AU], t1)
  check("1. routed: an aura event every frame at 20 frames a second for 3 s: at most 10 passes in any one second (round 7: 11)", P.routed <= 10 and P.routed >= 6, P.routed)
  P.runs1 = mostRuns(t1)
  quiet()
  local ok2 = firstAfterQuiet(AU, function() W.fire("PLAYER_TARGET_CHANGED") end)
  check("2. every live rule: the first target change after a quiet moment is checked on the very next frame", ok2)
  quiet()
  local t2 = allStorm(3, 1 / 60)
  P.all = most(at[AU], t2)
  check("2. every live rule: a target change every frame at 60 frames a second for 3 s: at most 10 passes in any one second (round 7: 20)", P.all <= 10 and P.all >= 6, P.all)
  P.runs2 = mostRuns(t2)
  quiet()
  local ok3 = firstAfterQuiet(MT, function() mounted = not mounted; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED") end)
  check("3. settle: the first load-fact change after a quiet moment re-checks every rule on the very next frame", ok3)
  quiet()
  local t3 = mountStorm(3, 1 / 60)
  P.settle = most(at[MT], t3)
  check("3. settle: mounted switching every frame at 60 frames a second for 3 s: at most 10 full re-checks in any one second (round 7: 60)", P.settle <= 10 and P.settle >= 6, P.settle)
  P.runs3 = mostRuns(t3)
  mounted = true; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); W.tick(1 / 60, 10)
  check("3. ... the last change is not lost: mounted at the end, the 'mounted only' display shows within a tenth of a second", shown(MT))
  check("4. every engine timer callback ran at most 10 times in any one second during parts 1 to 3", math.max(P.runs1, P.runs2, P.runs3) <= 10,
    P.runs1 .. "/" .. P.runs2 .. "/" .. P.runs3)
  -- 6. all three at once: the combined maximum per second (reported)
  quiet()
  local t6 = W.now
  for i = 1, 180 do
    aura[1001].expirationTime = W.now + 40 + i
    W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 501 } }); W.fire("PLAYER_TARGET_CHANGED")
    mounted = not mounted; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
    W.tick(1 / 60, 1)
  end
  local ES = ns.EngineStats
  P.combined = most(at[AU], t6)
  check("6. (reported) all three storms at once for 3 s: the aura rule was checked in at most " .. P.combined .. " frames in any one second " ..
    "(routed, every-live-rule and settle passes together; each path at most 10)", true)
  if ES then
    check(("6. (reported) ns.EngineStats after the parts: routed %d, every live rule %d, settles %d, wakes %d"):format(ES.routed, ES.all, ES.settle, ES.wake), true)
  end
elseif MODE == "early" then
  quiet()
  local t1 = routed(2, 1 / 60)
  local r = most(at[AU], t1)
  local fsFrames = 0
  local t2 = W.now
  for _ = 1, 120 do W.fire("PLAYER_TARGET_CHANGED"); W.tick(1 / 60, 1); if frameScriptOn() then fsFrames = fsFrames + 1 end end
  local a = most(at[AU], t2)
  check("5. (setup) engine timers were made to fire early", early > 0, early)
  check("5. a routed timer that fires before its moment: the routed passes still keep the pace (at most 10 in any one second) and still run",
    r <= 10 and r >= 6, r)
  check("5. an every-live-rule timer that fires before its moment: the passes still keep the pace and still run", a <= 10 and a >= 6, a)
  check("5. ... and no frame script is left on to wait for the pace (round 7 repair: before it, every frame until the pace allowed the pass)",
    fsFrames <= 2, fsFrames .. " frames")
  -- (repair 1) a lone change at the end of a burst, its timer firing early, no event after it
  quiet()
  local e0 = early
  tgt = true; W.fire("PLAYER_TARGET_CHANGED"); W.tick(1 / 60, 2)
  check("5. (setup) a target taken: the 'has a target' display shows on the next frame", shown(TG))
  tgt = false; W.fire("PLAYER_TARGET_CHANGED"); W.tick(1 / 60, 30)
  check("5. the target dropped 2 frames later, the every-live-rule timer firing early, no event after it: the display hides within half a second",
    not shown(TG), early - e0 .. " early timers")
  quiet()
  e0 = early
  aura[1001].expirationTime = W.now + 50
  W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 501 } }); W.tick(1 / 60, 2)
  check("5. (setup) the buff refreshed: its icon shows", shown(AU))
  aura[1001] = nil
  W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { 501 } }); W.tick(1 / 60, 30)
  check("5. the buff removed 2 frames later, the routed timer firing early, no event after it: its icon hides within half a second",
    not shown(AU), early - e0 .. " early timers")
end
return R
end
'''


def run_case(mode):
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)
    out = [(res[i][1], bool(res[i][2])) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i])[:600] for i in range(1, len(world.errors) + 1)]
    return out, errs


def main():
    total = bad = nerr = 0
    for mode in ("main", "early"):
        out, errs = run_case(mode)
        for name, ok in out:
            total += 1
            print(("ok  " if ok else "FAIL: ") + name)
            bad += 0 if ok else 1
        for e in errs:
            nerr += 1
            print("ERROR in the game stand-in (%s): %s" % (mode, e))
    print("%d checks, %d failed, %d Lua errors" % (total, bad, nerr))
    sys.exit(1 if bad or nerr else 0)


if __name__ == "__main__":
    main()
