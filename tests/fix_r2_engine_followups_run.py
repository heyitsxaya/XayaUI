#!/usr/bin/env python3
"""Offline test (rules review 2026-11-10, follow-ups to R3 and R18 in the rules engine).
R3 (round 7, SD-60, her answer "1": events only, no talent timer; an intended change of these checks, which asked before for a talent
change with no event to be seen "within about a second" by a once-a-second re-read): a talent picked or dropped is seen on the event, on
the very next frame, for every event in the API reference by which talents or the spec can change (spec, talents and loadouts saved or
switched, hero talents, PvP talents and War Mode, a reset by the game, the spellbook, entering the world), and for the talent-window
events that may or may not change one (compared, not re-checked); with no event no talent is read at all, in or out of combat (no timer).
R18 (round 7, SD-61, her answer "10/s for all, like EUI (Recommended)"; an intended change of these checks, which held the 1/30 s pace
before): with real frame-time wobble, cooldown / aura re-checks inside a burst come at most 10 times a second, never closer than a tenth
of a second, and a buff that appears in a raid fight reaches its cue within a tenth of a second and one frame.
R18: a routed re-check no longer builds a table of every rule's outcomes (Outcomes.lua) or walks the whole rule and group lists
(RuleDefaults.lua) each time; a rule list changed without announcing it is still seen at the next full step, an announced edit at once.
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

---------------------------------------------------------------- R3 follow-up (round 7, SD-60: on the event)
picked[5001] = false
W.fire("TRAIT_CONFIG_UPDATED", 1); full(2)
check("R3: talent not picked: the rule is not loaded", not active(T))
-- every event by which the reference says talents or the spec can change: picked, the event, one frame; dropped, the event, one frame
local EVENTS = {
  { "PLAYER_SPECIALIZATION_CHANGED", "player" }, { "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" }, { "ACTIVE_TALENT_GROUP_CHANGED", 2, 1 },
  { "PLAYER_TALENT_UPDATE" }, { "TRAIT_CONFIG_UPDATED", 1 }, { "TRAIT_CONFIG_LIST_UPDATED" }, { "ACTIVE_COMBAT_CONFIG_CHANGED", 1 },
  { "TRAIT_SUB_TREE_CHANGED", 31 }, { "PLAYER_PVP_TALENT_UPDATE" }, { "WAR_MODE_STATUS_UPDATE", true }, { "TALENTS_INVOLUNTARILY_RESET", false },
  { "SPELLS_CHANGED" }, { "PLAYER_ENTERING_WORLD", false, true },
  -- (round 7 repair) the spec changed by the game (events.md:1426)
  { "SPEC_INVOLUNTARILY_CHANGED", false },
  -- the talent window's own events (compared with the kept answer; only a real difference re-checks)
  { "TRAIT_NODE_CHANGED", 101 }, { "TRAIT_NODE_CHANGED_PARTIAL", 101, {} }, { "TRAIT_NODE_ENTRY_UPDATED", 201 }, { "TRAIT_TREE_CHANGED", 1 },
  { "TRAIT_CONFIG_CREATED", {} }, { "TRAIT_CONFIG_DELETED", 2 }, { "SELECTED_LOADOUT_CHANGED" }, { "CONFIG_COMMIT_FAILED", 1 },
  { "LEARNED_SPELL_IN_SKILL_LINE", 5001, 1, false },
  -- (round 7 repair) the related events the review asked about, compared the same way: a level gained (talent points; :1193), a node's
  -- condition (:1532), the old talent-point count (:271), and a pick, a PvP pick, a spec change or a starter build that failed (:1189,
  -- :1188, :1425, :1447: the game may have shown the pick before it failed; INFERENCE)
  { "PLAYER_LEVEL_UP", 80, 0, 0, 1 }, { "TRAIT_COND_INFO_CHANGED", 7 }, { "CHARACTER_POINTS_CHANGED", 1 },
  { "PLAYER_LEARN_TALENT_FAILED" }, { "PLAYER_LEARN_PVP_TALENT_FAILED" }, { "SPECIALIZATION_CHANGE_CAST_FAILED" },
  { "STARTER_BUILD_ACTIVATION_FAILED" },
}
local missed = {}
local played0 = played("7001")
for _, e in ipairs(EVENTS) do
  W.tick(0.2, 1)
  picked[5001] = true
  W.fire(e[1], e[2], e[3], e[4]); W.tick(1 / 60, 1)
  local on = active(T)
  W.tick(0.2, 1)
  picked[5001] = false
  W.fire(e[1], e[2], e[3], e[4]); W.tick(1 / 60, 1)
  local off = not active(T)
  if not (on and off) then missed[#missed + 1] = e[1] .. (on and "" or " (picked: not loaded)") .. (off and "" or " (dropped: still loaded)") end
end
check("R3: a talent picked, then dropped, is seen on the very next frame after each of the " .. #EVENTS .. " talent / spec events of the reference",
  #missed == 0, table.concat(missed, "; "))
check("R3: ... and the rule's cue plays each time it loads", played("7001") == played0 + #EVENTS, played("7001") - played0)
-- with no event at all: nothing reads the talents again (no timer), so nothing changes, in or out of combat
local function noEvent(label, inFight)
  if inFight then W.enterCombat() end
  full(2)
  local was = active(T)
  talentReads = 0
  picked[5001] = not picked[5001]   -- changed with no event
  full(40)   -- 2.4 s of steps
  check("R3: " .. label .. ": a talent changed with no event: no talent is read in 2.4 s of steps (no timer), the rule stays as it was",
    talentReads == 0 and active(T) == was, talentReads .. " reads, " .. tostring(active(T)))
  picked[5001] = not picked[5001]
  if inFight then W.leaveCombat() end
  full(2)
end
noEvent("out of combat", false)
noEvent("in combat", true)
-- a talent-window event that changed nothing re-checks no rule (one known / not known read per entry, compared) and makes no garbage
W.tick(0.3, 1)
local tick0 = ns.tickID
talentReads = 0
W.fire("TRAIT_NODE_CHANGED", 101); W.tick(1 / 60, 2)
check("R3: a talent-window event that changed nothing re-checks no rule (it compares the 101 entries once)",
  ns.tickID == tick0 and talentReads > 0 and talentReads <= 101, (ns.tickID - tick0) .. " steps, " .. talentReads .. " reads")
local kbMaybe = garbage(function() W.fire("TRAIT_NODE_CHANGED", 101) end, 40)
check("R3: ... and that compare makes under 0.5 KB of garbage", kbMaybe < 0.5, ("%.2f KB"):format(kbMaybe))

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
    for _ = 1, math.floor(rnd() * 14) do frame() end   -- a random point inside the burst
    local p0 = played("7002")
    buffs[1001] = true
    local t0, lat = W.now, nil
    for _ = 1, 40 do frame(); if played("7002") > p0 then lat = W.now - t0; break end end
    lat = lat or 99
    if lat > worst then worst = lat end
  end
  return worst
end
-- (round 7, SD-61: a tenth of a second, and the frame that crosses it)
local w60 = jitterBurstLatency(60, 0.0015, 60)
check("R18 (SD-61): a buff appearing inside a 60 fps burst with real frame wobble plays its cue within a tenth of a second and one frame, in 60 tries",
  w60 <= 0.1 + 1 / 60 + 0.0015, ("worst %.1f ms"):format(w60 * 1000))
local w120 = jitterBurstLatency(120, 0.00075, 60)
check("R18 (SD-61): ... and inside a 120 fps burst", w120 <= 0.1 + 1 / 120 + 0.00075, ("worst %.1f ms"):format(w120 * 1000))
-- the cap: count routed re-checks of A in one second of a wobbly 120 fps burst (a routed re-check leaves out the not-loaded rules)
-- (round 6, SD-54: an aura / cooldown event reads the rule's aura and cooldown checks once and re-checks the rule in full only when one
-- answered differently; here nothing changes, so what is counted is the engine reading A's checks: ns.Evaluate of A, or a read of its
-- buff or its cooldown, per engine step. The cap is the same: about 30 a second, not 120.)
local evals, evalAt = {}, {}
local E0, B0, C0 = ns.Evaluate, ns.BuffPresent, ns.ReadCooldown
local function mark(r) local t = evals[ns.tickID or 0]; if not t then t = {}; evals[ns.tickID or 0] = t; evalAt[ns.tickID or 0] = W.now end; t[r] = true end
ns.Evaluate = function(r, ...) mark(r); return E0(r, ...) end
ns.BuffPresent = function(id, ...) if id == 1001 and ns.InStep and ns.InStep() then mark(A) end; return B0(id, ...) end
ns.ReadCooldown = function(r, ...) if r == A then mark(A) end; return C0(r, ...) end
for _ = 1, 120 do W.fire("UNIT_AURA", "player"); W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(1 / 120 + (rnd() * 2 - 1) * 0.00075, 1) end
local routedN, fullN, times = 0, 0, {}
for k, t in pairs(evals) do if t[A] then if t[P[1]] then fullN = fullN + 1 else routedN = routedN + 1; times[#times + 1] = evalAt[k] end end end
table.sort(times)
local minGap = math.huge
for i = 2, #times do if times[i] - times[i - 1] < minGap then minGap = times[i] - times[i - 1] end end
ns.Evaluate, ns.BuffPresent, ns.ReadCooldown = E0, B0, C0
check("R18 (SD-61): in that 120 fps burst (about 1 s) the cooldown + aura rule is checked about 10 times between full steps, not 120 (nor 30)",
  routedN >= 8 and routedN <= 11, ("%d routed, %d full"):format(routedN, fullN))
check("R18 (SD-61): ... and never two of those checks closer than a tenth of a second (half a millisecond of rounding allowed)",
  minGap >= 0.0995 - 1e-9, ("closest %.1f ms"):format(minGap * 1000))

---------------------------------------------------------------- R18 follow-up: what a routed re-check costs
buffs[1001] = true
W.tick(0.3, 1)
-- one frame that is a routed re-check only (just after a full step, the next full step 0.2 s away)
local function routedFrame() W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.06, 1); W.tick(0.04, 1); W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(0.001, 1) end
local function quietFrame() W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.06, 1); W.tick(0.04, 1); W.tick(0.001, 1) end
local kbRouted = garbage(routedFrame, 30)
local kbQuiet = garbage(quietFrame, 30)
-- (round 6, V27 P1 / P4: the routed re-check now runs from a one-shot C_Timer.After made by the event instead of a frame script. The
-- stand-in game's C_Timer.After builds two Lua tables and two closures per call (tests/harness/world.lua addTimer); the game's own is a
-- C function (INFERENCE: no Lua garbage). That stand-in cost is measured here and taken out, so the bound below still holds XayaUI's own
-- garbage to 2 KB, as before round 5.)
local function noop() end
local kbTimer = garbage(function() C_Timer.After(3600, noop) end, 30)
W.timers = {}   -- (the 30 parked stand-in timers are dropped again)
local per = kbRouted - kbQuiet - kbTimer
-- the whole-list walk: one rule that reads neither cooldowns nor auras counts how often its "isCue" field is read (it has none, so
-- every read goes through its metatable); a routed re-check that does not step it has no reason to read it
local probe = P[200]
local cueReads = 0
setmetatable(probe, { __index = function(_, k) if k == "isCue" then cueReads = cueReads + 1 end end })
local routedReads, routedRan = 0, 0
local RC0 = ns.ReadCooldown
ns.ReadCooldown = function(r, ...) if r == A and ns.InStep and ns.InStep() then routedRan = routedRan + 1 end; return RC0(r, ...) end
for _ = 1, 10 do   -- each: a full step, a quiet frame, then a frame with only the routed re-check (counted)
  W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.06, 1); W.tick(0.04, 1)
  local r0 = routedRan
  cueReads = 0; W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(0.001, 1); routedReads = routedReads + cueReads
  if routedRan == r0 then routedRan = -1000 end   -- (the routed re-check did not run: the check below would test nothing)
end
ns.ReadCooldown = RC0
setmetatable(probe, nil)
check("R18: (setup) each of the 10 cooldown events below ran its routed re-check (it read the cooldown rule's cooldown)", routedRan >= 10, routedRan)
check("R18: 10 routed re-checks with no settings change do not walk the whole rule list (a rule they do not step is not read)",
  routedReads == 0, routedReads)
-- what is left (about 1 KB) is reading that one rule's cooldown and buff; the outcome table of all 200 conditions was about 10 KB more
check("R18: a routed re-check (1 cooldown rule with a display, 450 rules in all, 200 with a condition) makes under 2 KB of garbage, not a new outcome table",
  per < 2, ("%.2f KB per routed re-check (the stand-in's timer object, %.2f KB, taken out)"):format(per, kbTimer))

-- a rule list changed without ns.MarkDirty (same length) is still seen within about a second: condition 1 moves to parent 2
local cond1
for _, r in ipairs(ns.rules) do if r.parentUid == P[1].uid then cond1 = r end end
local function parentInStep() ns.BeginStepIndex(); local p = ns.FindParentRule(cond1); ns.EndStepIndex(); return p end
full(1)
check("R18: (setup) the step index has condition 1 under rule 1", parentInStep() == P[1], parentInStep() and parentInStep().name)
cond1.parentUid = P[2].uid   -- no ns.MarkDirty
full(1)
check("R18: a condition moved to another rule without announcing it is seen at the next full step (step index and outcome list)",
  parentInStep() == P[2] and ns.HasOutcomes(P[1]) == false and ns.HasOutcomes(P[2]) == true, parentInStep() and parentInStep().name)
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
