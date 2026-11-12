#!/usr/bin/env python3
"""Offline test (round 7 repair, engine-b; the round 7 review's blocker on REQUEST-LOG A23 SD-60). Round 7 replaced the 0.2 s re-check of
a cooldown whose end the game hides (in combat) with a Cooldown widget of the engine's own, fed the cooldown's duration object
(C_Spell.GetSpellCooldownDuration / GetSpellChargeDuration), whose OnCooldownDone wakes the rule. Both calls are documented
MayReturnNothing (docs/reference/api/namespaces.md:4398 / :4401). The review found that with no duration object the rule was never woken
again (a "ready" display stayed hidden after the cooldown ended), and that a cooldown still reading active for a moment after its duration
object ended re-fed the widget an ended duration, which clears it without OnCooldownDone (clearIfZero defaults to true, widgets.md:1013),
with the same result. The engine now fails safe (V2): a hidden end that no widget it trusts times keeps that rule on the re-check it had
before round 7 (every 0.2 s), only until the cooldown reads ended or a widget times it. What the player sees is what they saw before
round 7 (V32): the display returns at most 0.2 s and a frame after the end.
Cases, each in a fresh stand-in game, a "Cooldown ready" display of a spell on a 3 s cooldown started in combat (start and duration secret):
  A. the game gives no duration object: the display returns after the end (before this repair: never);
  B. the same for a recharge (GetSpellChargeDuration gives nothing): the display returns after the recharge ends;
  C. the cooldown reads active 50 ms after its duration object ends, and a feed after the end clears the widget without firing: the
     display returns after the real end (before this repair: never);
  D. the cooldown is shortened while it runs (a cooldown event) and the game then gives no duration object: the widget's older, later
     end is not trusted, and the display returns after the new end (before this repair: at the old end, a second late);
  E. the normal case is unchanged: with a duration object the rule is not re-checked while the cooldown runs, and returns within two
     frames of the end;
  F. the cooldown is shortened while it runs, and the game gives the new duration object: a cooldown event feeds every waiting widget
     its cooldown's duration object again (the rule's own reading, running with its times secret, does not change, so the rule itself is
     not re-checked), and the display returns within two frames of the new end (before this repair: at the old end, a second late;
     before round 7: within 0.2 s);
  G. a cooldown event lands on the end (its pass feeds the widget an ended duration object before the widget runs out) while the
     cooldown still reads active for 50 ms: the feed does not silently clear the widget (clearIfZero false), and the display returns
     (before this repair: never);
  and in A to D, the fail-safe re-check is bounded: it stops once the cooldown has ended (no engine timer left armed, the rule not
  re-checked in three quiet seconds after).
Stand-in game: the whole-addon harness (tests/harness) with Cooldown widgets, duration objects and secret values stubbed by their
documented contracts. That OnCooldownDone runs at alpha 0 in combat, and whether the game ever gives no duration object for a running
cooldown or reads it active after its duration object ends, are UNVERIFIED IN GAME (INFERENCE).
Run: python3 tests/fix_r7_cd_failsafe_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local FRAME = 1 / 60
-- engine timers (C_Timer calls made from XayaUI_Rules/Engine.lua) still armed
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
local function armedEngineTimers()
  local n = 0
  for _, t in ipairs(engineTimers) do if not t.done and not (t.handle and t.handle:IsCancelled()) then n = n + 1 end end
  return n
end
-- secret values (issecretvalue answers true; arithmetic on them errors, as in the game)
local function secret(name) return W.MarkSecret(setmetatable({}, { __tostring = function() return "SECRET " .. name end })) end
local SEC_START, SEC_DUR = secret("start"), secret("duration")
-- duration objects; Cooldown widgets made by Engine.lua: a feed keeps the end; a feed whose end has passed clears the widget without
-- OnCooldownDone when clearIfZero is true (its documented default, widgets.md:1013), and with clearIfZero false leaves the widget as it
-- was (the least helpful reading of "do not clear"); OnCooldownDone runs on the first frame at or after the end (INFERENCE)
local function Duration(startAt, len) return { startAt = startAt, endAt = startAt + len } end
local engineWidgets = {}
local CF0 = CreateFrame
CreateFrame = function(kind, name, parent, template, ...)
  local f = CF0(kind, name, parent, template, ...)
  if kind == "Cooldown" then
    local i = debug.getinfo(2, "S")
    if i and i.source and i.source:find("Engine.lua", 1, true) then
      engineWidgets[#engineWidgets + 1] = f
      rawset(f, "SetCooldownFromDurationObject", function(self, d, clearIfZero)
        if d and d.endAt > W.now then self._endAt = d.endAt elseif clearIfZero ~= false then self._endAt = nil end
      end)
      rawset(f, "Clear", function(self) self._endAt = nil end)
    end
  end
  return f
end
local driver = CF0("Frame")
driver:SetScript("OnUpdate", function()
  for _, w in ipairs(engineWidgets) do
    if w._endAt and W.now >= w._endAt and w:IsVisible() then
      w._endAt = nil
      local fn = w._scripts and w._scripts.OnCooldownDone
      if fn then fn(w) end
    end
  end
end)
-- the world: spell 4001's cooldown (or recharge) G.cd = { start, len }; skew: how long it still reads active after its duration ends
local G = { cd = nil, charge = false, skew = 0, noDur = false }
local function running(extra) local c = G.cd; return c and W.now < c.start + c.len + (extra or 0) end
local IDLE = { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
C_Spell.GetSpellCooldown = function(id)
  if id ~= 4001 or G.charge or not running(G.skew) then return IDLE end
  return { startTime = SEC_START, duration = SEC_DUR, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
end
C_Spell.GetSpellCharges = function(id)
  if id ~= 4001 or not G.charge then return nil end
  if running(G.skew) then
    return { currentCharges = 1, maxCharges = 2, cooldownStartTime = SEC_START, cooldownDuration = SEC_DUR, chargeModRate = 1, isActive = true }
  end
  return { currentCharges = 2, maxCharges = 2, cooldownStartTime = 0, cooldownDuration = 0, chargeModRate = 1, isActive = false }
end
local function DurFor(charge)
  if G.noDur or charge ~= G.charge then return nil end
  if running() then return Duration(G.cd.start, G.cd.len) end
  return Duration(W.now, 0)
end
C_Spell.GetSpellCooldownDuration = function(id) if id ~= 4001 then return nil end return DurFor(false) end
C_Spell.GetSpellChargeDuration = function(id) if id ~= 4001 then return nil end return DurFor(true) end

L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local CDR = ns.NewRule(); CDR.name = "cooldown ready"; CDR.enabled = true
CDR.useCooldown, CDR.spellID, CDR.cdState, CDR.buffState = true, 4001, "ready", "none"
CDR.visual.enabled, CDR.visual.kind, CDR.visual.w, CDR.visual.h = true, "spellicon", 32, 32
CDR.visual.text.enabled = false; CDR.sound.enabled = false; CDR.visual.trigger = "condition"
-- (B: the spell has two charges; "ready" means both are there, Conditions.lua CheckCooldownState / atMax)
ns.NormalizeRule(CDR); ns.rules[1] = CDR
ns.MarkDirty()
W.tick(FRAME, 30)
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown() local fr = framesOf and framesOf[CDR]; return fr and fr:IsShown() and true or false end
local evals = 0
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) if r == CDR then evals = evals + 1 end return E0(r, ...) end

W.enterCombat(); W.tick(FRAME, 10)
check("(setup) out of the cooldown the 'ready' display shows", shown())
if MODE == "A" then G.noDur = true end
if MODE == "B" then G.charge, G.noDur = true, true end
if MODE == "C" then G.skew = 0.05 end
G.cd = { start = W.now, len = 3 }
W.fire(G.charge and "SPELL_UPDATE_CHARGES" or "SPELL_UPDATE_COOLDOWN", 4001); W.tick(FRAME, 6)
check("(setup) the spell goes on cooldown in combat (start and duration secret): the 'ready' display hides", not shown())
if MODE == "D" or MODE == "F" then
  -- one second in, the cooldown is cut to 2 s (a cooldown event; its reading, running with its times secret, does not change);
  -- D: the game now gives no duration object; F: it gives the new one
  W.tick(FRAME, 60)
  G.cd.len = 2; if MODE == "D" then G.noDur = true end
  W.fire("SPELL_UPDATE_COOLDOWN", 4001); W.tick(FRAME, 3)
  check("(setup) " .. MODE .. ": still on cooldown after the cut", not shown())
end
if MODE == "G" then
  -- a cooldown event half a frame before the end: its pass runs on the next frame, after the duration object has ended and before the
  -- widget's own frame script; the cooldown still reads active for 50 ms
  G.skew = 0.05
  local e = G.cd.start + G.cd.len
  while W.now + FRAME < e - FRAME / 2 do W.tick(FRAME, 1) end
  W.tick(e - FRAME / 2 - W.now, 1)
  W.fire("SPELL_UPDATE_COOLDOWN", 4001)
end
local endAt = G.cd.start + G.cd.len + G.skew
local e0 = evals
local backAt
while W.now < endAt + 3 do
  W.tick(FRAME, 1)
  if not backAt and shown() then backAt = W.now - endAt end
end
local during = evals - e0
local label = ({ A = "A. no duration object for the cooldown", B = "B. no duration object for the recharge",
  C = "C. the cooldown reads active 50 ms after its duration object ends", D = "D. the cooldown is cut short, then no duration object",
  E = "E. the normal case (a duration object)", F = "F. the cooldown is cut short, with a new duration object",
  G = "G. a cooldown event lands on the end, while the cooldown still reads active for 50 ms" })[MODE]
local timed = (MODE == "E" or MODE == "F")
local limit = timed and (2 * FRAME + 0.0005) or (0.2 + 2 * FRAME + 0.0005)
check(label .. ": the 'ready' display returns " .. (timed and "within two frames of the end" or "at most 0.2 s and a frame after the end, as before round 7"),
  backAt ~= nil and backAt <= limit, backAt and ("%.0f ms"):format(backAt * 1000) or "NOT SHOWN 3 s after the end")
if timed then
  check(MODE .. ". ... and the rule was not re-checked on a timer while the cooldown ran (only at its end)", during <= 2, during)
else
  -- bounded: about once per 0.2 s while it ran (at most 3 s / 0.2 s + a few), and nothing after
  check(label .. ": the fail-safe re-check is bounded while it runs (at most once per 0.2 s)", during <= 3 / 0.2 + 6, during)
end
local e1 = evals
W.tick(FRAME, 180)
check(label .. ": after the end nothing keeps re-checking the rule (three quiet seconds) and no engine timer stays armed",
  evals - e1 == 0 and armedEngineTimers() == 0, ("%d re-checks, %d timers"):format(evals - e1, armedEngineTimers()))
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
    out = []
    for i in range(1, len(res) + 1):
        out.append((res[i][1], bool(res[i][2])))
    errs = [str(world.errors[i])[:600] for i in range(1, len(world.errors) + 1)]
    return out, errs


def main():
    total = bad = nerr = 0
    for mode in ("A", "B", "C", "D", "E", "F", "G"):
        out, errs = run_case(mode)
        for name, ok in out:
            total += 1
            print(("ok  " if ok else "FAIL: ") + name)
            if not ok:
                bad += 1
        for e in errs:
            nerr += 1
            print("ERROR in the game stand-in (case %s): %s" % (mode, e))
    print("%d checks, %d failed, %d Lua errors" % (total, bad, nerr))
    sys.exit(1 if bad or nerr else 0)


if __name__ == "__main__":
    main()
