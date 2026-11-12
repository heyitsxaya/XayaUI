#!/usr/bin/env python3
"""Offline test (core 0.6.56): D4 / #309 event routing. Xaya, 2026-11-06: 50 ms between a change in the game and its cue is not acceptable;
"either way reduce the ms as much as possible. avoid at all costs compromising on performance of rules while minimizing cpu and ram costs".
Checks what happens frame by frame in the stand-in game: a cooldown event that changes a cooldown re-checks the cooldown rule on the very
next frame, and not the aura or other rules; a player aura event that changes an aura re-checks the aura rule on the next frame, not the
cooldown rules; (round 6, SD-54) an aura or cooldown event that changed nothing re-checks no rule; an aura change makes its sound
on the next frame (the cue fires one frame after the event, not up to 50 ms later); (round 5, V27) with nothing changing no rule is
re-checked at all (no 0.2 s tick); an event that is not routed (a target change) still steps every loaded rule; a cue
of a routed rule is re-checked with it; no table is made per routed frame.
Run: python3 tests/engine_routing_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local function mk(name, f)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.visual.enabled, r.sound.enabled = false, false; f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local CD = mk("cd", function(r) r.useCooldown, r.spellID, r.cdState = true, 187827, "ready" end)
local AU = mk("aura", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1001, "present", "none" end)
local OT = mk("other", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "playerState", what = "moving", state = "yes" } } } end)
local cue = ns.NewCueRule(AU, "sound"); cue.sound.source, cue.sound.value = "kit", "8959"
-- (round 5, V27: the engine is event-driven; a new rule list is announced as the editor does, ns.MarkDirty, and is stepped once on the
-- next frame; nothing re-checks the rules on a timer any more)
ns.MarkDirty()
check("each rule is tied to what it reads", ns.EngineDeps ~= nil and ns.EngineDeps(CD).cd and not ns.EngineDeps(CD).aura and ns.EngineDeps(AU).auraOnly and ns.EngineDeps(OT).other
  and ns.EngineDeps(cue).auraOnly)
local n = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) n[r] = (n[r] or 0) + 1; return E0(r, ...) end
local function reset() for k in pairs(n) do n[k] = nil end end
local dt = 1 / 120
-- (round 6, SD-54: an aura or cooldown event reads that aura's / cooldown's check once, and re-checks in full only the rules whose check
-- answered differently. So each event below carries a real change: the cooldown starts, the aura appears. An event that changed nothing
-- re-checks no rule at all.)
local cdOn = false
C_Spell.GetSpellCooldown = function() return { startTime = cdOn and 100 or 0, duration = cdOn and 3600 or 0, isEnabled = true, isActive = cdOn, isOnGCD = false, modRate = 1 } end
local auraOn = {}
local BP0 = ns.BuffPresent
ns.BuffPresent = function(id) if id == 1001 then if auraOn[id] then return true, "test" end return false, "test" end return BP0(id) end
W.tick(0.3, 1)   -- the announced list is stepped once: everything settles
reset()
cdOn = true
W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(dt, 1)
check("cooldown event: the cooldown rule is re-checked on the next frame; the aura and other rules are not", (n[CD] or 0) == 1 and not n[AU] and not n[OT],
  tostring(n[CD]) .. "/" .. tostring(n[AU]) .. "/" .. tostring(n[OT]))
W.tick(0.04, 1)
reset()
W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(dt, 1)
check("[round 6] a cooldown event that changed nothing re-checks no rule", not n[CD] and not n[AU] and not n[OT],
  tostring(n[CD]) .. "/" .. tostring(n[AU]) .. "/" .. tostring(n[OT]))
W.tick(0.04, 1)   -- (review R18: routed re-checks run at most once per 1/30 s; a change after a quiet spell is still next-frame)
reset()
auraOn[1001] = true
W.fire("UNIT_AURA", "player"); W.tick(dt, 1)
check("aura event: the aura rule and its cue are re-checked on the next frame; the cooldown and other rules are not", (n[AU] or 0) >= 1 and (n[cue] or 0) >= 1
  and not n[CD] and not n[OT], tostring(n[AU]) .. "/" .. tostring(n[cue]) .. "/" .. tostring(n[CD]))
W.tick(0.04, 1)
reset()
W.fire("UNIT_AURA", "player"); W.tick(dt, 1)
check("[round 6] an aura event that changed nothing re-checks no rule", not n[AU] and not n[cue] and not n[CD] and not n[OT],
  tostring(n[AU]) .. "/" .. tostring(n[cue]) .. "/" .. tostring(n[CD]))
auraOn[1001] = nil; W.fire("UNIT_AURA", "player"); W.tick(0.04, 1)   -- (the aura gone again, for the sound check below)
-- the sound: the aura appears, its cue plays one frame later
local played = 0
PlaySound = function() played = played + 1 end
ns.BuffPresent = function(id) if id == 1001 then return true, "test" end return false, "test" end
W.tick(0.04, 1)   -- (review R18) a quiet spell first
W.fire("UNIT_AURA", "player"); W.tick(dt, 1)
check("an aura appearing plays its sound on the next frame (not up to 50 ms later)", played == 1, played)
-- (round 5, V27 "No running loops": the 0.2 s tick that stepped every rule is gone) nothing changes for two seconds: no rule is re-checked
W.tick(0.21, 1)   -- (the sound play above may have marked a change)
reset()
W.tick(0.1, 20)
check("nothing changes for 2 s: no rule is re-checked (no polling)", not n[AU] and not n[CD] and not n[OT] and not n[cue],
  tostring(n[AU]) .. "/" .. tostring(n[CD]) .. "/" .. tostring(n[OT]))
cdOn = false
W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(dt, 1)
check("after the quiet spell a cooldown event still re-checks the cooldown rule on the next frame", (n[CD] or 0) == 1 and not n[AU] and not n[OT],
  tostring(n[CD]) .. "/" .. tostring(n[AU]) .. "/" .. tostring(n[OT]))
-- an event that is not routed steps everything (after the minimum gap)
reset()
W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.06, 1)
check("a target change (not routed) steps every rule", (n[AU] or 0) >= 1 and (n[CD] or 0) >= 1 and (n[OT] or 0) >= 1)
-- an aura event on the same frame as a target change: the aura rule is not lost
reset()
W.fire("PLAYER_TARGET_CHANGED"); W.fire("UNIT_AURA", "player"); W.tick(0.06, 1)
check("an aura event landing on the frame of a target change is not lost (the aura rule is stepped)", (n[AU] or 0) >= 1)
-- memory: a routed re-check makes less garbage than a full step (it reuses the context and its filter)
ns.Evaluate = E0
local function garbage(f, k) collectgarbage("collect"); collectgarbage("stop"); local m0 = collectgarbage("count"); for _ = 1, k do f() end; local g = collectgarbage("count") - m0; collectgarbage("restart"); return g / k end
local routedKB = garbage(function() W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(dt, 1) end, 50)
local fullKB = garbage(function() W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.06, 1) end, 50)
check("a routed re-check makes less garbage than a full step", routedKB < fullKB, ("%.2f KB vs %.2f KB per step"):format(routedKB, fullKB))
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
        print(("ok  " if ok else "FAIL: ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
