#!/usr/bin/env python3
"""Offline test (rules review 2026-11-10, follow-ups to R3 and R18 in the rules engine).
R3: a talent picked or dropped with none of the spec / trait / spellbook events is still seen within about a second out of combat (the
kept answer is re-read once a second there), while in combat no talent is read again; the once-a-second re-read makes no garbage.
R18: with real frame-time wobble, cooldown / aura re-checks inside a burst still come every 2nd frame at 60 fps (every 4th at 120 fps),
so a buff that appears in a raid fight reaches its cue within 2 frames at 60 fps, and the cap of about 30 re-checks a second holds.
R18: a routed re-check no longer builds a table of every rule's outcomes (Outcomes.lua) or walks the whole rule and group lists
(RuleDefaults.lua) each time; a rule list changed without announcing it is still seen within about a second.
Run: python3 tests/fix_r2_engine_followups_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local function mk(name, f)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.visual.enabled, r.sound.enabled = false, false; f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local function soundCue(r, file) local c = ns.NewCueRule(r, "sound"); c.sound.source, c.sound.value = "kit", file; return c end
local picked, talentReads, buffs = {}, 0, {}
local IPS0 = IsPlayerSpell
IsPlayerSpell = function(id) if type(id) == "number" and id >= 5000 and id < 8000 then talentReads = talentReads + 1; return picked[id] == true end; return IPS0(id) end
ns.BuffPresent = function(id) if buffs[id] then return true, "test" end return false, "test" end
local function played(file) local n = 0; for _, s in ipairs(W.sounds) do if s == file then n = n + 1 end end; return n end
local function active(r) return ns.runtime[r] and ns.runtime[r].active and true or false end

-- T: loaded only while talent 5001 is picked; its cue plays while buff 1003 is present (it always is)
buffs[1003] = true
local T = mk("talent rule", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1003, "present", "none"
  r.talentMode, r.talents = "all", { { id = 5001, state = "known" } } end)
soundCue(T, "7001")
-- A: loaded, reads a cooldown and buff 1001, has a display of its own (shown while it holds); its cue plays when the buff appears
local A = mk("aura rule", function(r) r.useBuff, r.buffID, r.buffState, r.useCooldown, r.spellID, r.cdState = true, 1001, "present", true, 187827, "any"
  r.visual.enabled, r.visual.trigger = true, "condition" end)
soundCue(A, "7002")
-- 50 rules with talent requirements that never load (another spec)
for i = 1, 50 do
  mk("unloaded " .. i, function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 2000 + i, "present", "none"
    r.talentMode, r.talents = "all", { { id = 6000 + i, state = "known" }, { id = 7000 + i, state = "notKnown" } }
    r.load = { mode = "never" } end)
end
-- 200 loaded rules that read neither cooldowns nor your auras, each with a condition (an outcome)
local P = {}
for i = 1, 200 do
  P[i] = mk("parent " .. i, function(r) r.cdState, r.buffState = "none", "none"
    r.extra = { list = { { type = "targetDebuff", spellID = 3000 + i, unit = "target", state = "present" } } } end)
  P[i].uid = P[i].uid or ns.NewUID()
  local c = ns.NewRule(); c.name = "condition " .. i; c.parentUid = P[i].uid; c.visual.enabled, c.sound.enabled = false, false
  ns.NormalizeRule(c); ns.rules[#ns.rules + 1] = c
end
ns.MarkDirty()
W.tick(0.3, 2)
local function full(n) for _ = 1, n do W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.06, 1) end end
local function garbage(f, k) collectgarbage("collect"); collectgarbage("stop"); local m0 = collectgarbage("count"); for _ = 1, k do f() end; local g = collectgarbage("count") - m0; collectgarbage("restart"); return g / k end

---------------------------------------------------------------- R3 follow-up
picked[5001] = false
W.fire("TRAIT_CONFIG_UPDATED", 1); full(2)
check("R3: talent not picked: the rule is not loaded", not active(T))
local before = played("7001")
picked[5001] = true            -- picked with no trait / spellbook / spec event at all
local seenAt
for i = 1, 25 do full(1); if active(T) then seenAt = i * 0.06; break end end
check("R3: a talent picked with none of the talent events: out of combat the rule loads within about a second", seenAt ~= nil and seenAt <= 1.1, seenAt or "never")
check("R3: ... and its cue plays", played("7001") == before + 1, played("7001") - before)
picked[5001] = false
seenAt = nil
for i = 1, 25 do full(1); if not active(T) then seenAt = i * 0.06; break end end
check("R3: ... and dropped again with no event: the rule unloads within about a second", seenAt ~= nil and seenAt <= 1.1, seenAt or "never")
-- in combat: no talent is read again at all
W.enterCombat(); full(2)
talentReads = 0
full(40)   -- 2.4 s
check("R3: in combat, 40 steps over 2.4 s read no talent (51 rules with a talent requirement)", talentReads == 0, talentReads)
W.leaveCombat(); full(2)
-- out of combat: about one re-read a second, and it makes no garbage
talentReads = 0
full(40)
check("R3: out of combat, 2.4 s of steps re-read the 101 talent entries about once a second (not on every step)", talentReads > 0 and talentReads <= 4 * 101, talentReads)
local kbWith = garbage(function() full(1) end, 40)
local saved = {}
for _, r in ipairs(ns.rules) do if r.talentMode == "all" then saved[#saved + 1] = r; r.talentMode = "none" end end
ns.MarkDirty(); full(2)
local kbWithout = garbage(function() full(1) end, 40)
for _, r in ipairs(saved) do r.talentMode = "all" end
ns.MarkDirty(); full(2)
check("R3: the once-a-second talent re-read adds under 0.5 KB of garbage to a step", kbWith - kbWithout < 0.5, ("%.2f KB with, %.2f KB without"):format(kbWith, kbWithout))

---------------------------------------------------------------- R18 follow-up: frame-time wobble
-- frame times as the game delivers them: around the mean, wobbling by up to +-1.5 ms (60 fps) / +-0.75 ms (120 fps); fixed seed
local seed = 12345
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
local function jitterBurstLatency(fps, wobble, trials)
  local mean = 1 / fps
  local function frame() W.fire("UNIT_AURA", "player"); W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(mean + (rnd() * 2 - 1) * wobble, 1) end
  local worst = 0
  for _ = 1, trials do
    buffs[1001] = nil
    for _ = 1, 40 do frame(); if not active(A) then break end end
    for _ = 1, math.floor(rnd() * 7) do frame() end   -- a random point inside the burst
    local p0 = played("7002")
    buffs[1001] = true
    local n
    for i = 1, 12 do frame(); if played("7002") > p0 then n = i; break end end
    n = n or 99
    if n > worst then worst = n end
  end
  return worst
end
local w60 = jitterBurstLatency(60, 0.0015, 60)
check("R18: a buff appearing inside a 60 fps burst with real frame wobble plays its cue within 2 frames (about 33 ms), in 60 tries", w60 <= 2, "worst " .. w60)
local w120 = jitterBurstLatency(120, 0.00075, 60)
check("R18: ... and inside a 120 fps burst within 4 frames (about 33 ms)", w120 <= 4, "worst " .. w120)
-- the cap: count routed re-checks of A in one second of a wobbly 120 fps burst (a routed re-check leaves out the not-loaded rules)
local evals = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) local t = evals[ns.tickID or 0]; if not t then t = {}; evals[ns.tickID or 0] = t end; t[r] = true; return E0(r, ...) end
for _ = 1, 120 do W.fire("UNIT_AURA", "player"); W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(1 / 120 + (rnd() * 2 - 1) * 0.00075, 1) end
local routedN, fullN = 0, 0
for _, t in pairs(evals) do if t[A] then if t[P[1]] then fullN = fullN + 1 else routedN = routedN + 1 end end end
ns.Evaluate = E0
check("R18: in that 120 fps burst the cooldown + aura rule is re-checked at most about 30 times a second between full steps, not 120",
  routedN >= 20 and routedN <= 31, ("%d routed, %d full"):format(routedN, fullN))

---------------------------------------------------------------- R18 follow-up: what a routed re-check costs
buffs[1001] = true
W.tick(0.3, 1)
-- one frame that is a routed re-check only (just after a full step, the next full step 0.2 s away)
local function routedFrame() W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.06, 1); W.tick(0.04, 1); W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(0.001, 1) end
local function quietFrame() W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.06, 1); W.tick(0.04, 1); W.tick(0.001, 1) end
local kbRouted = garbage(routedFrame, 30)
local kbQuiet = garbage(quietFrame, 30)
local per = kbRouted - kbQuiet
-- what is left (about 1 KB) is reading that one rule's cooldown and buff; the outcome table of all 200 conditions was about 10 KB more
check("R18: a routed re-check (1 cooldown rule with a display, 450 rules in all, 200 with a condition) makes under 2 KB of garbage, not a new outcome table",
  per < 2, ("%.2f KB per routed re-check"):format(per))

-- a rule list changed without ns.MarkDirty (same length) is still seen within about a second: condition 1 moves to parent 2
local cond1
for _, r in ipairs(ns.rules) do if r.parentUid == P[1].uid then cond1 = r end end
local function parentInStep() ns.BeginStepIndex(); local p = ns.FindParentRule(cond1); ns.EndStepIndex(); return p end
full(1)
check("R18: (setup) the step index has condition 1 under rule 1", parentInStep() == P[1], parentInStep() and parentInStep().name)
cond1.parentUid = P[2].uid   -- no ns.MarkDirty
local seenAfter
for i = 1, 25 do full(1); if parentInStep() == P[2] and ns.HasOutcomes(P[1]) == false then seenAfter = i * 0.06; break end end
check("R18: a condition moved to another rule without announcing it is seen within about a second (step index and outcome list)",
  seenAfter ~= nil and seenAfter <= 1.1, seenAfter or "never")
-- an announced change is seen at once
cond1.parentUid = P[1].uid; ns.MarkDirty()
ns.BeginStepIndex(); local p1 = ns.FindParentRule(cond1); ns.EndStepIndex()
check("R18: ... and an announced edit (ns.MarkDirty) is seen at the very next step", p1 == P[1] and ns.HasOutcomes(P[1]) == true, p1 and p1.name)
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
