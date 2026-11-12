#!/usr/bin/env python3
"""Offline test (rules review 2026-11-10, R3 and R18): what the rules engine costs in a fight, and that the player still gets every cue.
R3: a talent requirement is read once and kept until talents change (spec / trait / spellbook events) or a rule is edited; it is no
longer rebuilt for every rule on every step. A talent picked, a spec change of your own, or an edit is still seen at the next step.
R18: cooldown / player-aura events in a burst re-check their rules at most about 30 times a second (not on every rendered frame); a change
after a quiet spell still reacts on the very next frame, and a change inside a burst within 1/30 s; rules that are not loaded are left out
(round 7, SD-61, her answer "10/s for all, like EUI (Recommended)": the burst pace is now at most 10 a second, so a quiet moment is a
tenth of a second, and a change inside a burst reacts within a tenth of a second; the checks below follow that pace)
of those re-checks, except a rule whose display shows "while the buff is active".
Run: python3 tests/fix_u3engine_combat_cost_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
local function soundCue(r, file) local c = ns.NewCueRule(r, "sound"); c.sound.source, c.sound.value = "kit", file; return c end
-- the game: which talents are picked, which buffs you have; IsPlayerSpell calls are counted
local picked, talentReads, buffs = {}, 0, {}
local IPS0 = IsPlayerSpell
IsPlayerSpell = function(id) if type(id) == "number" and id >= 5000 and id < 8000 then talentReads = talentReads + 1; return picked[id] == true end; return IPS0(id) end
ns.BuffPresent = function(id) if buffs[id] then return true, "test" end return false, "test" end
local function played(file) local n = 0; for _, s in ipairs(W.sounds) do if s == file then n = n + 1 end end; return n end

-- T: loaded by its talent (5001 picked); its cue plays while buff 1003 is present (it always is here)
buffs[1003] = true
local T = mk("talent rule", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1003, "present", "none"
  r.talentMode, r.talents = "all", { { id = 5001, state = "known" } } end)
soundCue(T, "7001")
-- A: loaded, reads a cooldown and a buff; its cue plays while buff 1001 is present
local A = mk("aura rule", function(r) r.useBuff, r.buffID, r.buffState, r.useCooldown, r.spellID, r.cdState = true, 1001, "present", true, 187827, "any" end)
soundCue(A, "7002")
-- U: 100 rules that never load here (another spec), each with a talent requirement, a cooldown and a buff
local U = {}
for i = 1, 100 do
  U[i] = mk("unloaded " .. i, function(r) r.useBuff, r.buffID, r.buffState, r.useCooldown, r.spellID, r.cdState = true, 2000 + i, "present", true, 187827, "ready"
    r.talentMode, r.talents = "all", { { id = 6000 + i, state = "known" }, { id = 7000 + i, state = "notKnown" } }
    r.load = { mode = "never" } end)
end
-- B: not loaded, but its display shows while buff 1002 is active (that display ignores load conditions)
local B = mk("buff display", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1002, "present", "none"; r.load = { mode = "never" }
  r.visual.enabled, r.visual.trigger = true, "buffActive" end)
ns.MarkDirty()

local evals = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) local t = evals[r]; if not t then t = {}; evals[r] = t end; t[ns.tickID or 0] = true; return E0(r, ...) end
local function steps(r) local n = 0; for _ in pairs(evals[r] or {}) do n = n + 1 end; return n end
local function reset() for k in pairs(evals) do evals[k] = nil end end
local dt = 1 / 120
local function full(n) for _ = 1, n do W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.06, 1) end end
W.tick(0.3, 2)

---------------------------------------------------------------- R3
picked[5001] = false
W.fire("TRAIT_CONFIG_UPDATED", 1); full(2)
local before = played("7001")
-- (round 7, SD-60, her answer "1": events only; the kept answer is read again only on a talent or spec event, in or out of combat; see
-- tests/fix_r2_engine_followups_run.py. Round 7 repair: the out-of-combat check below said "at most twice (once a second)", the
-- round-6 ticker she removed; it now asks for none, a tighter check of the intended behaviour)
W.enterCombat(); full(1)
talentReads = 0
full(20)
check("R3: in combat, 20 steps with no talent change read no talent again (101 rules with a talent requirement)", talentReads == 0, talentReads)
W.leaveCombat(); full(1)
talentReads = 0
full(20)
check("R3: out of combat, 20 steps (1.2 s) with no talent event read no talent again (events only, SD-60)", talentReads == 0, talentReads)
check("R3: the talent not picked: the rule does not load, its cue is silent", played("7001") == before and not (ns.runtime[T] and ns.runtime[T].active))
picked[5001] = true
W.fire("TRAIT_CONFIG_UPDATED", 1); full(1)
check("R3: the talent picked (trait change): the rule loads and its cue plays at the next step", played("7001") == before + 1 and ns.runtime[T] and ns.runtime[T].active)
picked[5001] = false
W.fire("SPELLS_CHANGED"); full(1)
check("R3: talent dropped (spellbook change): the rule unloads at the next step", ns.runtime[T] and not ns.runtime[T].active)
picked[5001] = true
W.fire("PLAYER_SPECIALIZATION_CHANGED", "player"); full(1)
check("R3: your own spec change re-reads talents at the next step", ns.runtime[T] and ns.runtime[T].active)
T.talents[1].state = "notKnown"; ns.MarkDirty(); full(1)
check("R3: an edit (Known -> Not known) is seen at the next step", ns.runtime[T] and not ns.runtime[T].active)
T.talents[1].state = "known"; ns.MarkDirty(); full(1)
check("R3: ... and back", ns.runtime[T] and ns.runtime[T].active)
-- the garbage a full step makes with 101 talent rules (100 not loaded)
local function garbage(f, k) collectgarbage("collect"); collectgarbage("stop"); local m0 = collectgarbage("count"); for _ = 1, k do f() end; local g = collectgarbage("count") - m0; collectgarbage("restart"); return g / k end
full(2)
local kbWith = garbage(function() full(1) end, 20)
for i = 1, 100 do U[i].talentMode = "none" end
ns.MarkDirty(); full(2)
local kbWithout = garbage(function() full(1) end, 20)
for i = 1, 100 do U[i].talentMode = "all" end
ns.MarkDirty(); full(2)
check("R3: 100 talent requirements add under 2 KB of garbage to a step (before: about 17 KB)", kbWith - kbWithout < 2,
  ("%.2f KB with, %.2f KB without"):format(kbWith, kbWithout))

---------------------------------------------------------------- R18
W.tick(0.3, 1); W.tick(0.1, 1)
reset()
-- (round 6, SD-54: a cooldown event re-checks in full only the rules whose cooldown answered differently; so here the cooldown starts)
local GSC0 = C_Spell.GetSpellCooldown
C_Spell.GetSpellCooldown = function(id) if id == 187827 then return { startTime = W.now, duration = 3600, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 } end return GSC0(id) end
W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(dt, 1)
check("R18: after a quiet spell a cooldown event (the cooldown started) re-checks the loaded cooldown rule on the next frame", steps(A) == 1, steps(A))
C_Spell.GetSpellCooldown = GSC0
local u = 0; for i = 1, 100 do u = u + steps(U[i]) end
check("R18: ... and leaves out the 100 rules that are not loaded", u == 0, u)
-- a buff appears after a quiet spell: the cue plays on the next frame; the not-loaded buff display shows on the next frame
-- (round 7, SD-61: the quiet spell is a tenth of a second, the routed pace; it was 0.05 s for the 1/30 s pace)
W.tick(0.1, 1)
local a0 = played("7002")
buffs[1001], buffs[1002] = true, true
W.fire("UNIT_AURA", "player"); W.tick(dt, 1)
check("R18: a buff appearing after a quiet spell: its cue plays on the next frame", played("7002") == a0 + 1, played("7002") - a0)
check("R18: ... and a not-loaded rule's 'while the buff is active' display shows on the next frame", ns.runtime[B] and ns.runtime[B].visualWanted == true)
buffs[1001], buffs[1002] = nil, nil
W.tick(0.21, 2)
-- a raid-style burst: both events on every rendered frame for one second at 120 fps
reset()
for _ = 1, 120 do W.fire("UNIT_AURA", "player"); W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(dt, 1) end
check("R18 (round 7, SD-61): in a burst (events on every frame, 120 fps) a cooldown + aura rule is re-checked at most 10 times a second plus the ticks, not 120",
  steps(A) <= 15, steps(A))
-- a buff appearing inside the burst still reaches its cue within 1/30 s
local a1 = played("7002")
buffs[1001] = true
local frames = 0
for i = 1, 30 do W.fire("UNIT_AURA", "player"); W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(dt, 1); if played("7002") > a1 then frames = i; break end end
check("R18 (round 7, SD-61): a buff appearing inside the burst plays its cue within a tenth of a second (12 frames at 120 fps), no event lost",
  frames >= 1 and frames <= 12, frames)
ns.Evaluate = E0
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
