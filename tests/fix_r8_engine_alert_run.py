#!/usr/bin/env python3
"""Offline test (round 8, engine-core item 6; REQUEST-LOG A23 SD-69, ticked by her: "Cooldown alert: re-check its icon only").
Blizzard's Cooldown Manager icons report the exact moments an aura was applied or removed, a cooldown started or became ready, a charge
came back (TriggerAlertEvent, Enum.CooldownViewerAlertEventType, enums.md:3194; XayaUI post-hooks it read-only, Timing.lua). Before round
8 each such alert re-checked EVERY live rule (Timing.lua called ns.MarkStateDirty()). Now an alert reads again only what an icon's moment
can change: the aura checks that do not answer from the aura API alone (an icon's own answer, an estimate made from an icon's moments, a
name match) and the cooldown checks; only the rules whose check answered differently are re-checked.

What the player gets (a fresh stand-in game; 60 live rules: 50 buff rules answered by the aura API, 5 rules whose buff (9060) is answered
by a Cooldown Manager icon, 5 cooldown rules (spells 9101-9105) whose display shows the spell's charges):
  1. the icon lights and its alert fires (OnAuraApplied): the 5 rules that read that icon show their display within a frame;
  2. ... and only those rules are re-checked (before round 8: all 60 live rules; round 8 before its repair: also the 5 charge displays,
     which the engine re-checks outside the checks, whichever icon alerted: the reviewer's case);
  3. an alert about the icon that changes nothing it shows (PandemicTime): no rule is re-checked in full, and no cooldown is read;
  4. the icon unlit with its alert (OnAuraRemoved): the 5 displays hide within a frame, again with only those rules re-checked;
  5. ns.EngineStats.alert counts the alerts;
  6. (repair) a cooldown icon of spell 9101 reports a charge gained (ChargeGained): only the cooldown of 9101 is read and only its rule is
     re-checked (its charge display), not the other four cooldown rules nor any aura rule;
  7. (repair) a "Cooldown ready" display of spell 9106 (no charge display: re-checked only through its cooldown check), its cooldown hidden
     in combat (isActive secret) and timed by the Cooldown Manager's moments: the icon reports the cooldown started (OnCooldown), then
     ready a second later (Available, a reset): the display shows within two frames of that alert (without the alert's read of the
     cooldown check it would wait for the 0.2 s re-check of a hidden cooldown, SD-68 case B);
  8. (repair) the same cooldown started again (OnCooldown) and left to run out on the measured length (3 s): the display shows within two
     frames of the estimated end (the alert's pass works out the cooldown's end again: Plan with cdFresh).
The same parity is proven against the engine before round 6 by tests/fix_r6_routing_replay_run.py (its Cooldown Manager alert stream).
Stand-in: the whole-addon harness with a Cooldown Manager buff viewer whose icon has the TriggerAlertEvent method the game's icons have
(INFERENCE from Blizzard's code, as Timing.lua; UNVERIFIED IN GAME).
Run: python3 tests/fix_r8_engine_alert_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local FRAME = 1 / 60
Enum.CooldownViewerAlertEventType = Enum.CooldownViewerAlertEventType or { Available = 1, PandemicTime = 2, OnCooldown = 3, ChargeGained = 4, OnAuraApplied = 5, OnAuraRemoved = 6 }
local A = Enum.CooldownViewerAlertEventType
local auras = {}
for i = 1, 50 do auras[7000 + i] = { spellId = 7000 + i, auraInstanceID = 800 + i, name = "Buff " .. i, applications = 1, duration = 60, expirationTime = 0, sourceUnit = "player", isHelpful = true } end
local function copy(a) local t = {}; for k, v in pairs(a) do t[k] = v end; return t end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) local a = auras[id]; return a and copy(a) or nil end
C_UnitAuras.GetUnitAuraBySpellID = function(u, id) if u == "player" then return C_UnitAuras.GetPlayerAuraBySpellID(id) end end
-- the Cooldown Manager's buff viewer: one icon for spell 9060, which Blizzard's code lights (wasSetFromAura) and alerts on
local icon = { wasSetFromAura = false, auraInstanceID = nil, cooldownInfo = { spellID = 9060 } }
icon.GetSpellID = function() return 9060 end
icon.IsShown = function() return true end
icon.TriggerAlertEvent = function(self, ev) end
BuffIconCooldownViewer = { IsVisible = function() return true end, GetChildren = function() return icon end }
-- (repair) the cooldown viewer: one icon for spell 9101
local function cdIconOf(id)
  local ic = { cooldownInfo = { spellID = id } }
  ic.GetSpellID = function() return id end
  ic.IsShown = function() return true end
  ic.TriggerAlertEvent = function(self, ev) end
  return ic
end
local cdIcon, hidIcon = cdIconOf(9101), cdIconOf(9106)
EssentialCooldownViewer = { IsVisible = function() return true end, GetChildren = function() return cdIcon, hidIcon end }
-- (repair, 7 / 8) spell 9106 on a cooldown the game hides in combat: start, duration and isActive secret, no duration object
local hidden9106 = false
local SEC = W.MarkSecret(setmetatable({}, { __tostring = function() return "SECRET" end }))
local GSC0 = C_Spell.GetSpellCooldown
C_Spell.GetSpellCooldown = function(id, ...)
  if id == 9106 then
    if hidden9106 and W.combat then return { startTime = SEC, duration = SEC, isEnabled = true, isActive = SEC, isOnGCD = false, modRate = 1 } end
    return { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
  end
  return GSC0(id, ...)
end

L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local function mk(nm, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.text.enabled = false; r.sound.enabled = false; r.visual.trigger = "condition"
  f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
for i = 1, 50 do auras[7000 + i].expirationTime = W.now + 60 end
for i = 1, 50 do mk("buff " .. i, function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 7000 + i, "present", "none" end) end
local ICON = {}
for i = 1, 5 do ICON[i] = mk("icon reader " .. i, function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 9060, "present", "none" end) end
-- (repair) each cooldown rule's display shows the spell's charges: the engine re-checks such a rule outside the checks (Engine.lua Deps
-- cdText), so before the repair every alert re-checked all five, whichever icon it came from
local CD = {}
for i = 1, 5 do CD[i] = mk("cooldown " .. i, function(r) r.useCooldown, r.spellID, r.cdState, r.buffState = true, 9100 + i, "ready", "none"; r.visual.count = { enabled = true, source = "charges" } end) end
local RDY = mk("ready 9106", function(r) r.useCooldown, r.spellID, r.cdState, r.buffState = true, 9106, "ready", "none" end)
ns.MarkDirty(); W.tick(FRAME, 20)
W.enterCombat(); W.tick(FRAME, 20)
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown(r) local fr = framesOf and framesOf[r]; return fr and fr:IsShown() and true or false end
local function anyShown() for i = 1, 5 do if shown(ICON[i]) then return true end end return false end
local function allShown() for i = 1, 5 do if not shown(ICON[i]) then return false end end return true end
local n = 0
local E0 = ns.Evaluate
local evalOf = {}
ns.Evaluate = function(r, ...) n = n + 1; evalOf[r] = (evalOf[r] or 0) + 1; return E0(r, ...) end
-- the cooldowns read (the engine's cooldown checks read through ns.ReadCooldown, looked up at each call)
local cdReads = {}
local RC0 = ns.ReadCooldown
ns.ReadCooldown = function(r, ...) local id = r and tonumber(r.spellID) or 0; cdReads[id] = (cdReads[id] or 0) + 1; return RC0(r, ...) end
local function reads() local t, k = 0, 0; for id, c in pairs(cdReads) do t = t + c; k = k + 1 end return t, k end
local function wipe(t) for k in pairs(t) do t[k] = nil end end
check("(setup) the icon is unlit: the 5 icon readers are hidden", not anyShown())
local ES = ns.EngineStats
local a0 = ES and ES.alert or 0
W.tick(0.25, 2)
-- 1 / 2: lit
n = 0
icon.wasSetFromAura = true; icon:TriggerAlertEvent(A.OnAuraApplied)
W.tick(FRAME, 2)
check("1. the icon lights with its alert (OnAuraApplied): the 5 rules that read it show within a frame", allShown())
check("2. ... and only the rules whose answer the alert changed are re-checked (5 icon readers; before: all 60 live rules)", n <= 5, n)
-- 3: an alert that changes nothing
W.tick(0.25, 2)
n = 0; wipe(cdReads)
icon:TriggerAlertEvent(A.PandemicTime)
W.tick(FRAME, 3)
check("3. an alert that changes nothing the icon shows (PandemicTime): no rule is re-checked in full (before: all 60)", n == 0, n)
check("3. ... and no cooldown is read (the alert's icon is an aura's; before the repair: every cooldown check)", (reads()) == 0, (reads()))
-- 4: unlit
W.tick(0.25, 2)
n = 0
icon.wasSetFromAura = false; icon:TriggerAlertEvent(A.OnAuraRemoved)
W.tick(FRAME, 2)
check("4. the icon unlit with its alert (OnAuraRemoved): the 5 displays hide within a frame", not anyShown())
check("4. ... again only those 5 rules are re-checked", n <= 5, n)
check("5. ns.EngineStats.alert counts the three alerts", ES ~= nil and ES.alert - a0 == 3, ES and (ES.alert - a0) or "no ns.EngineStats")
-- 6: a cooldown icon's alert
W.tick(0.25, 2)
n = 0; wipe(cdReads); wipe(evalOf)
cdIcon:TriggerAlertEvent(A.ChargeGained)
W.tick(FRAME, 3)
local others = 0
for i = 2, 5 do others = others + (evalOf[CD[i]] or 0) + (cdReads[9100 + i] or 0) end
check("6. a charge gained on the icon of spell 9101: its cooldown is read", (cdReads[9101] or 0) >= 1, cdReads[9101] or 0)
check("6. ... the other four cooldowns are neither read nor their rules re-checked", others == 0, others)
check("6. ... only the rule of spell 9101 is re-checked (its charge display reads that icon)", n == 1 and (evalOf[CD[1]] or 0) == 1, n)
-- 7 / 8: a cooldown hidden in combat, timed by the icon's moments (the length measured earlier: Timing.lua LearnedCooldown)
local LC = ns.Timing and ns.Timing.LearnedCooldown and ns.Timing.LearnedCooldown()
if LC then LC[9106] = 3 end
check("(setup) the 'ready 9106' display shows (off cooldown)", shown(RDY))
hidden9106 = true; W.fire("SPELL_UPDATE_COOLDOWN", 9106); W.tick(FRAME, 3)
hidIcon:TriggerAlertEvent(A.OnCooldown); W.tick(FRAME, 3)
check("(setup) 9106 on a hidden cooldown, its start from the icon: the 'ready' display hides", LC ~= nil and not shown(RDY))
W.tick(FRAME, 60)
hidIcon:TriggerAlertEvent(A.Available)
local t7 = W.now
while W.now < t7 + 0.5 and not shown(RDY) do W.tick(FRAME, 1) end
check("7. the icon reports the hidden cooldown ready (Available): the display shows within two frames", shown(RDY) and W.now - t7 <= 2 * FRAME + 1e-6,
  string.format("%.3f s", W.now - t7))
W.tick(0.25, 2)
hidIcon:TriggerAlertEvent(A.OnCooldown)
local t8 = W.now
W.tick(FRAME, 3)
check("(setup) started again (OnCooldown): the display hides", not shown(RDY))
while W.now < t8 + 4 and not shown(RDY) do W.tick(FRAME, 1) end
check("8. ... and shows within two frames of the estimated end (the start + the measured 3 s)", shown(RDY) and math.abs(W.now - (t8 + 3)) <= 2 * FRAME + 1e-6,
  string.format("%.3f s after the alert", W.now - t8))
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
