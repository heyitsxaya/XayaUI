#!/usr/bin/env python3
"""Offline test (round 8, engine-core item 1; the round 7 review's blocker on the cooldown fail safe, REQUEST-LOG A23 SD-60 / SD-68).
Round 7 made a Cooldown widget of the engine's own time a cooldown's hidden end (its OnCooldownDone wakes the rules). Its repair then
distrusted every widget for a whole second after any end (CD_END_GRACE) and re-checked the rule every 0.2 s meanwhile. So in NORMAL play
(a spell pressed again right after its cooldown ended, two charges recharging back to back, back-to-back global cooldowns) the rule was
re-checked five times a second while its next cooldown ran: the review's probe gave H [4] per cooldown, I [7], J [74] (before that repair:
[0], [1], [20]). Her answer SD-68 ("option two with gating"): the 0.2 s re-check runs only for a hidden cooldown end the game gives no
duration object for, and only while such a cooldown runs untimed.

What the player gets (each case in a fresh stand-in game, a "Cooldown ready" display of spell 4001, in combat, start and duration secret):
  H. a 3 s cooldown pressed again 0.3 s after each end, four times: no re-check while each cooldown runs, the display back after each end;
  I. two charges recharging back to back (3 s each), with no charge event when the first comes back: at most two re-checks during the
     second recharge (at the first charge's end, and one more 0.2 s later: the check that the game did not just keep reading the
     recharge as running for a moment past its end, INFERENCE), none on the 0.2 s re-check;
  I2. the same with the game's SPELL_UPDATE_CHARGES when the first charge comes back: at most two re-checks;
  J. a rule that counts the global cooldown, over 10 back-to-back global cooldowns of 1.2 s: at most two re-checks per global cooldown;
  K. the same with a hasted global cooldown of 0.75 s and 0.05 s between them (under one second: round 7 never left the 0.2 s re-check);
  and in H to K the 0.2 s cooldown re-check never runs (ns.EngineStats.pollCd stays at 0; the round-7 engine has no such counter, so
  there the re-check counts above are what fail);
  B. the rare case SD-68 keeps: the game gives no duration object: the re-check runs (pollCd counts it) while the cooldown runs, the
     display comes back at most 0.2 s and a frame after the end, and nothing is re-checked after.
Stand-in: the whole-addon harness with Cooldown widgets, duration objects and secret values stubbed by their documented contracts
(widgets.md:1013, namespaces.md:4398 / :4401), as in tests/fix_r7_cd_failsafe_run.py. That the game sends SPELL_UPDATE_COOLDOWN when a
new cooldown or global cooldown starts is INFERENCE (events.md:1443 names the event; it does not say when it fires); case I is played
both with and without a charge event. UNVERIFIED IN GAME.
Run: python3 tests/fix_r8_engine_cd_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local FRAME = 1 / 60
local function secret(name) return W.MarkSecret(setmetatable({}, { __tostring = function() return "SECRET " .. name end })) end
local SEC_START, SEC_DUR = secret("start"), secret("duration")
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
local IDLE = { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
local function RUN(gcd) return { startTime = SEC_START, duration = SEC_DUR, isEnabled = true, isActive = true, isOnGCD = gcd or false, modRate = 1 } end
-- the world: spell 4001's cooldown cd = { start, len }, its charges, the global cooldown
local G = { cd = nil, noDur = false, chargeBase = nil, gcd = nil, gcdLen = 1.2 }
local function cdRunning() return G.cd and W.now < G.cd.start + G.cd.len end
local function gcdRunning() return G.gcd and W.now < G.gcd + G.gcdLen end
C_Spell.GetSpellCooldown = function(id)
  if id == 61304 then return gcdRunning() and RUN(true) or IDLE end
  if id ~= 4001 then return IDLE end
  if cdRunning() then return RUN(false) end
  if gcdRunning() then return RUN(true) end
  return IDLE
end
C_Spell.GetSpellCooldownDuration = function(id)
  if G.noDur then return nil end
  if id == 61304 or (id == 4001 and not cdRunning()) then
    if gcdRunning() then return Duration(G.gcd, G.gcdLen) end
    return Duration(W.now, 0)
  end
  if id == 4001 then return Duration(G.cd.start, G.cd.len) end
  return nil
end
C_Spell.GetSpellCharges = function(id)
  if id ~= 4001 or not G.chargeBase then return nil end
  local t = W.now - G.chargeBase
  if t < 6 then return { currentCharges = (t < 3) and 0 or 1, maxCharges = 2, cooldownStartTime = SEC_START, cooldownDuration = SEC_DUR, chargeModRate = 1, isActive = true } end
  return { currentCharges = 2, maxCharges = 2, cooldownStartTime = 0, cooldownDuration = 0, chargeModRate = 1, isActive = false }
end
C_Spell.GetSpellChargeDuration = function(id)
  if id ~= 4001 or not G.chargeBase or G.noDur then return nil end
  local t = W.now - G.chargeBase
  if t < 3 then return Duration(G.chargeBase, 3) elseif t < 6 then return Duration(G.chargeBase + 3, 3) end
  return Duration(W.now, 0)
end

L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local CDR = ns.NewRule(); CDR.name = "cooldown ready"; CDR.enabled = true
CDR.useCooldown, CDR.spellID, CDR.cdState, CDR.buffState = true, 4001, "ready", "none"
CDR.visual.enabled, CDR.visual.kind, CDR.visual.w, CDR.visual.h = true, "spellicon", 32, 32
CDR.visual.text.enabled = false; CDR.sound.enabled = false; CDR.visual.trigger = "condition"
if MODE == "J" or MODE == "K" then CDR.countGCD = true end
ns.NormalizeRule(CDR); ns.rules[1] = CDR
ns.MarkDirty()
W.tick(FRAME, 30)
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown() local fr = framesOf and framesOf[CDR]; return fr and fr:IsShown() and true or false end
local evals = 0
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) if r == CDR then evals = evals + 1 end return E0(r, ...) end
local ES = ns.EngineStats
local function pollCd() return ES and ES.pollCd or 0 end
W.enterCombat(); W.tick(FRAME, 10)
check(MODE .. " (setup) out of the cooldown the 'ready' display shows", shown())
local p0 = pollCd()
local function noPoll(label) check(label .. ": the 0.2 s cooldown re-check never ran (ns.EngineStats.pollCd)", ES ~= nil and pollCd() - p0 == 0,
  ES and (pollCd() - p0) or "no ns.EngineStats") end

if MODE == "H" then
  for k = 1, 4 do
    G.cd = { start = W.now, len = 3 }
    W.fire("SPELL_UPDATE_COOLDOWN", 4001); W.tick(FRAME, 3)
    local e0 = evals
    while W.now < G.cd.start + G.cd.len - 0.02 do W.tick(FRAME, 1) end
    local mid = evals - e0
    check(("H%d. a 3 s cooldown pressed again 0.3 s after the last ended: not re-checked while it runs (round 7: 4)"):format(k), mid == 0, mid)
    while W.now < G.cd.start + G.cd.len + 0.3 do W.tick(FRAME, 1) end
    check(("H%d. ... and the 'ready' display is back after its end"):format(k), shown())
  end
  noPoll("H")
elseif MODE == "I" or MODE == "I2" then
  G.chargeBase = W.now
  W.fire("SPELL_UPDATE_CHARGES"); W.tick(FRAME, 3)
  check(MODE .. ". (setup) both charges spent: hidden", not shown())
  while W.now < G.chargeBase + 2.95 do W.tick(FRAME, 1) end
  local e0 = evals
  local sent = false
  while W.now < G.chargeBase + 5.95 do
    if MODE == "I2" and not sent and W.now >= G.chargeBase + 3 then sent = true; W.fire("SPELL_UPDATE_CHARGES") end
    W.tick(FRAME, 1)
  end
  check(MODE .. ". two charges recharging back to back" .. (MODE == "I2" and ", a charge event when the first comes back" or ", no charge event between") ..
    ": at most two re-checks during the second recharge (round 7: 7)", evals - e0 <= 2, evals - e0)
  W.tick(FRAME, 30)
  check(MODE .. ". ... the 'ready' display is back after both", shown())
  noPoll(MODE)
elseif MODE == "J" or MODE == "K" then
  G.gcdLen = (MODE == "K") and 0.75 or 1.2
  local gap = (MODE == "K") and 0.05 or 0.1
  local e0, n = evals, 0
  for _ = 1, 10 do
    G.gcd = W.now; n = n + 1
    W.fire("SPELL_UPDATE_COOLDOWN", 61304); W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 4002)
    while W.now < G.gcd + G.gcdLen + gap do W.tick(FRAME, 1) end
  end
  check(("%s. a rule counting the global cooldown, %d back-to-back global cooldowns of %.2f s: at most two re-checks each (round 7: 74 for J)"):format(
    MODE, n, G.gcdLen), evals - e0 <= 2 * n, evals - e0)
  noPoll(MODE)
  check(MODE .. ". ... the 'ready' display is back after the last", shown())
elseif MODE == "B" then
  G.noDur = true
  G.cd = { start = W.now, len = 3 }
  W.fire("SPELL_UPDATE_COOLDOWN", 4001); W.tick(FRAME, 3)
  check("B. (setup) on cooldown with no duration object: hidden", not shown())
  local endAt, backAt = G.cd.start + G.cd.len, nil
  while W.now < endAt + 1 do W.tick(FRAME, 1); if not backAt and shown() then backAt = W.now - endAt end end
  check("B. no duration object (the case SD-68 keeps): the 0.2 s re-check runs while the cooldown runs (pollCd counts it)",
    ES ~= nil and pollCd() - p0 >= 3 / 0.2 - 2, ES and (pollCd() - p0) or "no ns.EngineStats")
  check("B. ... the 'ready' display is back at most 0.2 s and a frame after the end", backAt ~= nil and backAt <= 0.2 + FRAME + 0.0005,
    backAt and ("%.0f ms"):format(backAt * 1000) or "not shown")
  local e1, q1 = evals, pollCd()
  W.tick(FRAME, 180)
  check("B. ... and after the end it stops: nothing re-checked in three quiet seconds", evals - e1 == 0 and pollCd() - q1 == 0, (evals - e1) .. " / " .. (pollCd() - q1))
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
    for mode in ("H", "I", "I2", "J", "K", "B"):
        out, errs = run_case(mode)
        for name, ok in out:
            total += 1
            print(("ok  " if ok else "FAIL: ") + name)
            bad += 0 if ok else 1
        for e in errs:
            nerr += 1
            print("ERROR in the game stand-in (case %s): %s" % (mode, e))
    print("%d checks, %d failed, %d Lua errors" % (total, bad, nerr))
    sys.exit(1 if bad or nerr else 0)


if __name__ == "__main__":
    main()
