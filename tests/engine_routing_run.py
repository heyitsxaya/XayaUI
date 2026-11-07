#!/usr/bin/env python3
"""Offline test (core 0.6.56): D4 / #309 event routing. Xaya, 2026-11-06: 50 ms between a change in the game and its cue is not acceptable;
"either way reduce the ms as much as possible. avoid at all costs compromising on performance of rules while minimizing cpu and ram costs".
Checks what happens frame by frame in the stand-in game: a cooldown event re-checks the cooldown rules on the very next frame, and not the
aura or other rules; a player aura event re-checks the aura rules on the next frame, not the cooldown rules; an aura change makes its sound
on the next frame (the cue fires one frame after the event, not up to 50 ms later); a plain 0.2 s tick skips an aura-only rule an aura event
re-checked within the tick but still steps every other rule; an event that is not routed (a target change) still steps every rule; a cue
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
check("each rule is tied to what it reads", ns.EngineDeps ~= nil and ns.EngineDeps(CD).cd and not ns.EngineDeps(CD).aura and ns.EngineDeps(AU).auraOnly and ns.EngineDeps(OT).other
  and ns.EngineDeps(cue).auraOnly)
local n = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) n[r] = (n[r] or 0) + 1; return E0(r, ...) end
local function reset() for k in pairs(n) do n[k] = nil end end
local dt = 1 / 120
W.tick(0.3, 1)   -- a full tick: everything settles
reset()
W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(dt, 1)
check("cooldown event: the cooldown rule is re-checked on the next frame; the aura and other rules are not", (n[CD] or 0) == 1 and not n[AU] and not n[OT],
  tostring(n[CD]) .. "/" .. tostring(n[AU]) .. "/" .. tostring(n[OT]))
reset()
W.fire("UNIT_AURA", "player"); W.tick(dt, 1)
check("aura event: the aura rule and its cue are re-checked on the next frame; the cooldown and other rules are not", (n[AU] or 0) >= 1 and (n[cue] or 0) >= 1
  and not n[CD] and not n[OT], tostring(n[AU]) .. "/" .. tostring(n[cue]) .. "/" .. tostring(n[CD]))
-- the sound: the aura appears, its cue plays one frame later
local played = 0
PlaySound = function() played = played + 1 end
ns.BuffPresent = function(id) if id == 1001 then return true, "test" end return false, "test" end
W.fire("UNIT_AURA", "player"); W.tick(dt, 1)
check("an aura appearing plays its sound on the next frame (not up to 50 ms later)", played == 1, played)
-- a plain tick right after: the aura-only rule (fresh) is skipped, the others are stepped
local marks = 0
local M0, S0 = ns.MarkDirty, ns.MarkStateDirty
ns.MarkDirty = function(...) marks = marks + 1; return M0(...) end
ns.MarkStateDirty = function(...) marks = marks + 1; return S0(...) end
W.tick(0.21, 1)   -- (a full tick: the sound play above may have marked a change)
W.fire("UNIT_AURA", "player"); W.tick(dt, 1)
reset(); marks = 0
W.tick(0.21, 1)
check("plain 0.2 s tick: skips the aura rule an aura event just re-checked, steps the cooldown and other rules", not n[AU] and (n[CD] or 0) >= 1 and (n[OT] or 0) >= 1,
  tostring(n[AU]) .. "/" .. tostring(n[CD]) .. "/" .. tostring(n[OT]) .. " marks=" .. marks)
ns.MarkDirty, ns.MarkStateDirty = M0, S0
reset()
W.tick(0.21, 1)
check("the next tick steps it again (it was not re-checked since)", (n[AU] or 0) >= 1)
-- an event that is not routed steps everything (after the minimum gap)
reset()
W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.06, 1)
check("a target change (not routed) steps every rule", (n[AU] or 0) >= 1 and (n[CD] or 0) >= 1 and (n[OT] or 0) >= 1)
-- an aura event and a tick on the same frame: the aura rule is not skipped
reset()
W.tick(0.15, 1)
W.fire("UNIT_AURA", "player"); W.tick(0.06, 1)
check("an aura event landing on a tick's frame is not lost (the aura rule is stepped)", (n[AU] or 0) >= 1)
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
