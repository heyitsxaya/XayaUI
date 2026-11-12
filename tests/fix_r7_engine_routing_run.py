#!/usr/bin/env python3
"""Offline test (round 7, engine). What the player sees, for three round-7 changes to XayaUI_Rules/Engine.lua:
SD-63 (her answer "Keep, fix first"): the round-6 stuck icon. A rule with a countdown on its display (whole seconds) has an icon cue, a
  bar cue and a sound cue. A routed pass runs, then the aura goes about 10 ms before the rule's whole-second wake: the rule hides at its
  wake, and its cues must hide with the next routed pass (within a tenth of a second and one frame), stay hidden, and the sound cue must
  play again when the aura comes back. Before: the cues stayed on screen until the next change, and the sound was not played again.
Review of round 6 (cooldown routing, events.md:1443 SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory,
  itemID)): one cooldown event naming one spell while other cooldowns changed with it. Two spells sharing a category, a shared
  start-recovery lockout, an item whose use puts another item's spell on cooldown, a hidden (secret) category: the other spell's
  "ready" display must hide. A payload naming one spell and nothing else still re-checks only that spell's rules.
SD-61 (her answer "10/s for all, like EUI (Recommended)"): in a burst of aura events on every frame, a rule is re-checked at most 10
  times a second (never two within a tenth of a second); the first change after a quiet tenth of a second is drawn on the very next
  frame; once the events stop, nothing of the engine stays scheduled (no timer, no frame script).
Run: python3 tests/fix_r7_engine_routing_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- engine timers: every C_Timer call made from XayaUI_Rules/Engine.lua is noted, with its handle state
local engineTimers = {}
local function fromEngine() local i = debug.getinfo(3, "S"); return i and i.source and i.source:find("Engine.lua", 1, true) ~= nil end
local A0, T0, K0 = C_Timer.After, C_Timer.NewTimer, C_Timer.NewTicker
C_Timer.After = function(d, fn)
  if fromEngine() then local rec = { at = W.now + (d or 0), done = false }; engineTimers[#engineTimers + 1] = rec; return A0(d, function(...) rec.done = true; return fn(...) end) end
  return A0(d, fn)
end
C_Timer.NewTimer = function(d, fn)
  local h = T0(d, fn)
  if fromEngine() then engineTimers[#engineTimers + 1] = { at = W.now + (d or 0), handle = h, timer = true } end
  return h
end
C_Timer.NewTicker = function(d, fn, n)
  local h = K0(d, fn, n)
  if fromEngine() then engineTimers[#engineTimers + 1] = { ticker = true, handle = h } end
  return h
end
local G = { auras = {}, nextIID = 100, cds = {} }
local function copy(a) local t = {}; for k, v in pairs(a) do t[k] = v end; return t end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit ~= "player" then return nil end local a = G.auras[id]; return a and copy(a) or nil end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
C_UnitAuras.GetAuraDataByIndex = function(unit, i)
  if unit ~= "player" then return nil end
  local list = {}; for _, a in pairs(G.auras) do list[#list + 1] = a end
  table.sort(list, function(x, y) return x.auraInstanceID < y.auraInstanceID end)
  return list[i] and copy(list[i]) or nil
end
C_Spell.GetSpellCooldown = function(id)
  local c = G.cds[id]
  if c and W.now < c.start + c.dur then return { startTime = c.start, duration = c.dur, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 } end
  return { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
end
local function gain(id, dur)
  G.nextIID = G.nextIID + 1
  local a = { spellId = id, auraInstanceID = G.nextIID, name = "Spell " .. id, icon = 136243, applications = 1, duration = dur,
    expirationTime = W.now + dur, isHelpful = true, sourceUnit = "player" }
  G.auras[id] = a
  W.fire("UNIT_AURA", "player", { addedAuras = { a } })
end
local function lose(id) local a = G.auras[id]; G.auras[id] = nil; W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { a.auraInstanceID } }) end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local SOUND = "Interface\\AddOns\\XayaUI\\Media\\Audio\\CC0\\Kenney\\bong_001.ogg?cue"
local P = ns.NewRule(); P.name = "parent"; P.enabled = true
P.useBuff, P.buffID, P.buffState, P.cdState = true, 1001, "present", "none"
P.visual.enabled, P.visual.kind, P.visual.w, P.visual.h = true, "spellicon", 32, 32
P.visual.trigger = "buffActive"; P.visual.text.enabled = true; P.sound.enabled = false
ns.NormalizeRule(P); ns.rules[#ns.rules + 1] = P
local function cd(name, id)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.useCooldown, r.spellID, r.cdState, r.buffState = true, id, "ready", "none"
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32; r.visual.trigger = "condition"; r.sound.enabled = false
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local CD0 = cd("a cooldown", 4001)
local IC = ns.NewCueRule(P, "icon"); IC.visual.w, IC.visual.h = 32, 32
local BC = ns.NewCueRule(P, "bar"); BC.visual.w, BC.visual.h = 120, 16
local SC = ns.NewCueRule(P, "sound"); SC.sound.source, SC.sound.value = "file", SOUND
local A, B = cd("A (shared category)", 100), cd("B (shares A's category)", 200)
local C1, C2 = cd("C (cast)", 300), cd("D (shares C's recovery lockout)", 301)
local IT = cd("E (another item's spell)", 9401)
local X = cd("F (unrelated)", 500)
-- Q: reads aura 1002, a display with no countdown and no cue (so nothing but routed passes checks it: no stored-moment wake)
local Q = ns.NewRule(); Q.name = "pace"; Q.enabled = true
Q.useBuff, Q.buffID, Q.buffState, Q.cdState = true, 1002, "present", "none"
Q.visual.enabled, Q.visual.kind, Q.visual.w, Q.visual.h = true, "spellicon", 32, 32
Q.visual.trigger = "buffActive"; Q.visual.text.enabled = false; Q.sound.enabled = false
ns.NormalizeRule(Q); ns.rules[#ns.rules + 1] = Q
ns.MarkDirty()
W.tick(1 / 60, 30)
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown(r) local fr = framesOf and framesOf[r]; return fr and fr:IsShown() and true or false end
local function played() local n = 0; for _, s in ipairs(W.sounds) do if s == SOUND then n = n + 1 end end; return n end

---------------------------------------------------------------- SD-63: the stuck icon
local tg = W.now
gain(1001, 10.5); W.tick(0.004, 10)
check("(setup) the aura is up: the rule and its icon and bar cues are shown, the sound cue played", shown(P) and shown(IC) and shown(BC) and played() == 1,
  tostring(shown(P)) .. "/" .. tostring(shown(IC)) .. "/" .. tostring(shown(BC)) .. "/" .. played())
while W.now < tg + 0.486 do W.tick(0.002, 1) end
W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(0.002, 2)   -- a routed pass runs now
local lostAt = W.now
lose(1001)                                           -- the aura goes, about 10 ms before the rule's whole-second wake
local goneAt
while W.now < lostAt + 0.5 do W.tick(0.002, 1); if not goneAt and not shown(IC) and not shown(BC) then goneAt = W.now - lostAt end end
check("SD-63: the aura gone 10 ms before its rule's countdown wake: the icon and bar cues hide within a tenth of a second and one frame",
  goneAt ~= nil and goneAt <= 0.1 + 1 / 60, goneAt and ("%.0f ms"):format(goneAt * 1000) or "still shown after 0.5 s")
W.tick(0.1, 20)
check("SD-63: ... and 2 s later the rule, its icon cue and its bar cue are all hidden", not shown(P) and not shown(IC) and not shown(BC),
  tostring(shown(P)) .. "/" .. tostring(shown(IC)) .. "/" .. tostring(shown(BC)))
gain(1001, 10.5); W.tick(1 / 60, 3)
check("SD-63: the aura back: the icon cue shows again and the sound cue plays again", shown(IC) and played() == 2, tostring(shown(IC)) .. ", played " .. played())
lose(1001); W.tick(0.1, 5)

---------------------------------------------------------------- cooldown events naming one spell while others changed with it
local function ev(...) W.fire("SPELL_UPDATE_COOLDOWN", ...); W.tick(1 / 60, 3) end
W.tick(0.2, 1)
G.cds[100] = { start = W.now, dur = 30 }; G.cds[200] = { start = W.now, dur = 30 }
ev(100, 100, 77, 0, nil)
check("a shared category: one event names spell A (category 77); B, sharing it, no longer shows 'ready'", not shown(A) and not shown(B),
  tostring(shown(A)) .. "/" .. tostring(shown(B)))
W.tick(0.2, 1)
G.cds[300] = { start = W.now, dur = 30 }; G.cds[301] = { start = W.now, dur = 30 }
ev(300, 300, 0, 55, nil)
check("a shared start-recovery lockout: one event names spell C (start-recovery category 55); D no longer shows 'ready'", not shown(C1) and not shown(C2),
  tostring(shown(C1)) .. "/" .. tostring(shown(C2)))
W.tick(0.2, 1)
G.cds[9401] = { start = W.now, dur = 30 }
ev(9400, 9400, 0, 0, 5555)
check("an item used (item ID 5555, its spell 9400): another item's spell (9401) on the shared cooldown no longer shows 'ready'", not shown(IT), tostring(shown(IT)))
W.tick(0.2, 1)
G.cds[100], G.cds[200] = nil, nil
W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(1 / 60, 3)
W.tick(0.2, 1)
G.cds[100] = { start = W.now, dur = 30 }; G.cds[200] = { start = W.now, dur = 30 }
ev(100, 100, W.MarkSecret("secret-category"), 0, nil)
check("a hidden (secret) category: B no longer shows 'ready' (a field the game hides is never trusted)", not shown(A) and not shown(B),
  tostring(shown(A)) .. "/" .. tostring(shown(B)))
-- a payload naming one spell and nothing else: only that spell's rules are checked again
W.tick(0.2, 1)
local evals = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) evals[r] = (evals[r] or 0) + 1; return E0(r, ...) end
G.cds[500] = { start = W.now, dur = 30 }
ev(500, 500, 0, 0, nil)
ns.Evaluate = E0
check("a payload naming one spell and nothing else: its rule hides 'ready', and the other cooldown rules are not checked again",
  not shown(X) and (evals[X] or 0) >= 1 and not evals[A] and not evals[B] and not evals[C1] and not evals[IT],
  ("F %s, checked F %d, A %d, B %d"):format(tostring(shown(X)), evals[X] or 0, evals[A] or 0, evals[B] or 0))

---------------------------------------------------------------- SD-61: 10 a second, self-stopping
W.tick(0.5, 1)
-- (each engine step that checks the rule counts once: its cues check it again inside the same step)
local stepsAt, lastTick = {}, nil
E0 = ns.Evaluate
ns.Evaluate = function(r, ...)
  if r == Q and ns.InStep and ns.InStep() and ns.tickID ~= lastTick then lastTick = ns.tickID; stepsAt[#stepsAt + 1] = W.now end
  return E0(r, ...)
end
local function burst(n) for _ = 1, n do W.fire("UNIT_AURA", "player", { isFullUpdate = true }); W.tick(1 / 60, 1) end end
-- Q is checked again only when its aura's answer changed: to count passes, the aura's stacks change on every frame
local stacks = 0
gain(1002, 600); W.tick(1 / 60, 1)
W.tick(1 / 60, 20)
for k = 1, #stepsAt do stepsAt[k] = nil end
for _ = 1, 60 do stacks = stacks + 1; G.auras[1002].applications = stacks; W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { G.auras[1002].auraInstanceID } }); W.tick(1 / 60, 1) end
local minGap = math.huge
for k = 2, #stepsAt do if stepsAt[k] - stepsAt[k - 1] < minGap then minGap = stepsAt[k] - stepsAt[k - 1] end end
check("SD-61: one second of aura changes on every frame (60 fps): the rule is checked again at most 10 times (not 30, not 60)",
  #stepsAt >= 8 and #stepsAt <= 11, #stepsAt)
check("SD-61: ... never two checks within a tenth of a second (half a millisecond of rounding allowed)", minGap >= 0.0995 - 1e-9, ("closest %.1f ms"):format(minGap * 1000))
-- the first change after a quiet tenth of a second (the burst's last re-check ran up to a tenth of a second after its last event)
W.tick(1 / 60, 15)
for k = 1, #stepsAt do stepsAt[k] = nil end
G.auras[1002].applications = 999; W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { G.auras[1002].auraInstanceID } }); W.tick(1 / 60, 1)
check("SD-61: after a quiet tenth of a second the first change is checked on the very next frame", #stepsAt == 1, #stepsAt)
ns.Evaluate = E0
lose(1002); W.tick(1 / 60, 10)
-- once the events stop: no routed pass is scheduled (no C_Timer.After of the engine waits) and no engine frame script runs. (A
-- C_Timer.NewTimer the engine set for a stored moment, a cooldown's end, may still wait: that is not a pass; see the round-7 report.)
for k in pairs(G.cds) do G.cds[k] = nil end
W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(1 / 60, 3)
W.tick(0.5, 4)
local pending, scripts = 0, 0
for _, t in ipairs(engineTimers) do
  if t.ticker then if not t.handle:IsCancelled() then pending = pending + 1 end
  elseif not t.timer and not t.done then pending = pending + 1 end
end
for _, o in ipairs(W.objects) do
  local f = o._scripts and o._scripts.OnUpdate
  if f then local i = debug.getinfo(f, "S"); if i and i.source and i.source:find("Engine.lua", 1, true) and o:IsVisible() then scripts = scripts + 1 end end
end
local made = 0
for _, t in ipairs(engineTimers) do if t.ticker then made = made + 1 end end
check("SD-61: after the last event no routed pass is scheduled and no engine frame script runs (the pass is never set while nothing waits)",
  pending == 0 and scripts == 0, pending .. " timers, " .. scripts .. " scripts")
check("SD-60: the engine made no repeating timer (C_Timer.NewTicker) in this whole run", made == 0, made)
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
