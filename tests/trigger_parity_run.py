#!/usr/bin/env python3
"""Offline test (core 0.6.3 / Options 0.6.4, #350 with #264 / #288 / #300 / #155 / #173 / #278 / #314): aura trigger parity and the new
trigger items. Buff / Aura (another) rows read like the built-in one (extra aura IDs, seconds left, stacks and seconds-left numbers for
conditions); the built-in gets a seconds-left requirement; Target Debuff gets seconds left; the Loss of control trigger with separate effects;
stacks offered only for auras that can stack; the "readable in combat" line; duplicating the built-in keeps the extra IDs; field visibility.
The game is stubbed (aura tables, loss-of-control data, secrecy levels). Run: python3 tests/trigger_parity_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("   [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
check("core loaded with the new readers", ns and ns.AuraPresentList and ns.TimeLeftCheck and ns.TriggerAuraNumbers and ns.CountSupport and ns.TriggerCombatNote)
-- the game: auras on you by spell ID
local auras = {}
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) return auras[id] end
local function aura(id, left, total, apps) auras[id] = { spellId = id, auraInstanceID = id * 10, expirationTime = left and (GetTime() + left) or 0, duration = total or 0, applications = apps or 0 } end
local TY = ns.TRIGGER_TYPES
check("Buff / Aura (another) has extra IDs and seconds left", (function()
  local keys = {}; for _, f in ipairs(TY.buffAura.fields) do keys[f.key] = f.kind end
  return keys.alt == "idlist" and keys.timeOp == "select" and keys.timeSec == "number" end)())

-- 1. extra aura IDs on a further aura row: ANY of them
local row = { type = "buffAura", spellID = 1001, alt = { 1002, 1003 }, state = "yes" }
aura(1003, 12, 20, 3)
local v = ns.CheckTrigger(row)
check("row: present when an EXTRA ID is on you", v == true)
local st, rem = ns.TriggerAuraNumbers(row)
check("row: stacks and seconds left come from the aura found", st == 3 and rem and math.abs(rem - 12) < 0.01, tostring(st) .. " " .. tostring(rem))
auras = {}
check("row: missing when none is on you (out of combat)", ns.CheckTrigger(row) == false)
st, rem = ns.TriggerAuraNumbers(row)
check("row: absent -> 0 stacks, no seconds (decision D1)", st == 0 and rem == nil, tostring(st) .. " " .. tostring(rem))
check("row: a time condition on the absent row aura is NOT met (D1)", ns.AuraTimeRefAbsent and ns.AuraTimeRefAbsent("n:x1t", { extra = { list = { row } } }, nil) == true)
row.state = "no"
check("row: State MISSING inverts", ns.CheckTrigger(row) == true)
row.state = "yes"

-- 2. seconds left on the row
aura(1001, 10, 20, 0)
row.timeOp, row.timeSec = ">=", 5
check("row: 'at least 5 seconds left' with 10 left = true", ns.CheckTrigger(row) == true)
row.timeOp = "<"
check("row: 'less than 5' with 10 left = false", ns.CheckTrigger(row) == false)
W.tick(1, 6)
check("row: 'less than 5' after 6 seconds (4 left) = true", ns.CheckTrigger(row) == true)
aura(1001, nil, 0, 0)   -- permanent aura
row.timeOp, row.timeSec = ">=", 30
check("row: a permanent aura has unlimited time left", ns.CheckTrigger(row) == true)
auras = {}; auras[1009] = { spellId = 1009 }   -- an aura never seen before, time not readable
local rowU = { type = "buffAura", spellID = 1009, state = "yes", timeOp = ">=", timeSec = 30 }
check("row: time unreadable and no estimate -> unknown (never fires on a guess)", ns.CheckTrigger(rowU) == nil)
aura(1001, nil, 0, 0)
row.timeOp = "any"
check("row: 'any time left' ignores the time", ns.CheckTrigger(row) == true)
row.timeOp = nil

-- 3. normalize: extra IDs cleaned, bad comparisons dropped
local r0 = ns.NewRule(); r0.extra = { list = { { type = "buffAura", spellID = 5, alt = { "7", 5, 7, -1, "x", 9 }, timeOp = "maybe", timeSec = "4" } } }
ns.NormalizeExtra(r0)
local t0 = r0.extra.list[1]
check("normalize: extra IDs are numbers, no repeats, not the main ID", t0.alt and #t0.alt == 2 and t0.alt[1] == 7 and t0.alt[2] == 9, t0.alt and table.concat(t0.alt, ","))
check("normalize: an unknown comparison is dropped, seconds is a number", t0.timeOp == nil and t0.timeSec == 4)

-- 4. built-in Buff / Aura: seconds left
local B = ns.NewRule(); B.name = "B"; B.useBuff = true; B.buffID = 2001; B.buffState = "present"; B.cdState = "none"; B.enabled = true; ns.NormalizeRule(B)
B.uid = B.uid or ns.NewUID()
ns.rules = { B }
aura(2001, 8, 20, 0)
B.buffTimeOp, B.buffTimeSec = ">", 5
ns.tickID = (ns.tickID or 0) + 1
local _, info = ns.Evaluate(B, ns.ReadContext())
check("built-in: 'more than 5 seconds left' with 8 left = true", info.buffOK == true)
B.buffTimeOp = "<="
ns.tickID = ns.tickID + 1
_, info = ns.Evaluate(B, ns.ReadContext())
check("built-in: 'at most 5' with 8 left = false", info.buffOK == false)
B.buffState = "missing"
ns.tickID = ns.tickID + 1
_, info = ns.Evaluate(B, ns.ReadContext())
check("built-in: the time is ignored while State is MISSING", info.buffOK == false)
B.buffState = "present"
B.buffTimeOp = "nonsense"; ns.NormalizeRule(B)
check("built-in: normalize drops an unknown comparison", B.buffTimeOp == nil)

-- 5. condition numbers: stacks / seconds left of a row, and refs follow a moved row
B.extra = { list = { { type = "itemCount", itemID = 1, op = ">=", count = 1 }, { type = "buffAura", spellID = 3001, state = "yes" } } }
aura(3001, 6, 10, 4)
local stn, tn = ns.NumRef("n:x2s", B, {}), ns.NumRef("n:x2t", B, {})
check("condition number: row 2 stacks = 4", stn == 4, stn)
check("condition number: row 2 seconds left = 6", tn and math.abs(tn - 6) < 0.01, tn)
local cond = ns.NewRule(); cond.parentUid = B.uid; cond.when = { list = { { ref = "n:x2t", cmp = "<", num = 3 }, { ref = "n:x2s", cmp = ">=", num = 2 } } }
ns.rules[#ns.rules + 1] = cond
ns.RemapOutcomeRefs(B, function(n) if n == 2 then return "x1" elseif n == 1 then return "x2" end return "x" .. n end)
check("moving a trigger re-points 'seconds left' and 'stacks' checks (suffix kept)", cond.when.list[1].ref == "n:x1t" and cond.when.list[2].ref == "n:x1s", cond.when.list[1].ref .. " " .. cond.when.list[2].ref)
cond.when.list[1].ref, cond.when.list[2].ref = "n:x2t", "n:x2s"

-- 6. stacks only where the aura can stack (#300)
local maxStacks = { [3001] = 5, [3002] = 1 }
C_Spell.GetSpellMaxCumulativeAuraApplications = function(id) return maxStacks[id] or 0 end
local v1 = ns.RefChoicesFor(B)
check("stacks offered for an aura that stacks (game says 5)", v1["n:x2s"] ~= nil and v1["n:x2t"] ~= nil)
B.extra.list[2].spellID = 3002
cond.when.list[2].ref = "n:x2t"
v1 = ns.RefChoicesFor(B)
check("stacks NOT offered for an aura that cannot stack (game says 1); seconds left still offered", v1["n:x2s"] == nil and v1["n:x2t"] ~= nil)
cond.when.list[2].ref = "n:x2s"
v1 = ns.RefChoicesFor(B)
check("a stacks check already in use stays listed", v1["n:x2s"] ~= nil)
ns.Settings("core").learnedAuraStacks = { [3002] = { max = 3, seen = 4 } }
check("an aura seen above 1 stack counts as stacking even if the game says 1", ns.AuraMayStack(3002) == true)
ns.Settings("core").learnedAuraStacks = {}
C_Spell.GetSpellMaxCumulativeAuraApplications = nil
check("no answer from the game and never seen: may stack (not hidden on a guess)", ns.AuraMayStack(4242) == true)
ns.Settings("core").learnedAuraStacks = { [4243] = { max = 1, seen = 3 } }
check("no answer from the game, seen 3 times never above 1: does not stack", ns.AuraMayStack(4243) == false)
C_Spell.GetSpellMaxCumulativeAuraApplications = function(id) return maxStacks[id] or 0 end
local C2 = ns.NewRule(); C2.useBuff = true; C2.buffID = 3002; C2.buffState = "present"
check("count support: a rule on a non-stacking aura has nothing to count", ns.CountSupport(C2).any == false)
C2.buffID = 3001
check("count support: a stacking aura has stacks", ns.CountSupport(C2).stacks == true)

-- 7. Target Debuff: seconds left
local list = {}
C_UnitAuras.GetUnitAuras = function(unit, filter) return list end
UnitExists = function(u) return u == "player" or u == "target" end
list = { { spellId = 204598, expirationTime = GetTime() + 9, duration = 12, applications = 0 } }
local td = { type = "targetDebuff", spellID = 204598, unit = "target", state = "yes", timeOp = ">=", timeSec = 5 }
check("target debuff: 'at least 5 seconds left' with 9 left = true", ns.CheckTrigger(td) == true)
td.timeSec = 10
check("target debuff: 'at least 10' with 9 left = false", ns.CheckTrigger(td) == false)
local _, trem = ns.TriggerAuraNumbers(td)
check("target debuff: seconds-left number for conditions", trem and math.abs(trem - 9) < 0.01, trem)

-- 8. Loss of control on you
local loc = {}
C_LossOfControl.GetActiveLossOfControlDataCount = function() return #loc end
C_LossOfControl.GetActiveLossOfControlData = function(i) return loc[i] end
loc = { { locType = "STUN", spellID = 853, timeRemaining = 3, duration = 6 } }
local L1 = { type = "lossOfControl", state = "yes", stun = true }
check("loss of control: Stunned ticked, stunned = true", ns.CheckTrigger(L1) == true)
local L2 = { type = "lossOfControl", state = "yes", fear = true }
check("loss of control: Feared ticked, stunned = false", ns.CheckTrigger(L2) == false)
local L3 = { type = "lossOfControl", state = "yes", any = true }
check("loss of control: Any effect = true", ns.CheckTrigger(L3) == true)
L1.timeOp, L1.timeSec = ">=", 2
check("loss of control: 'at least 2 seconds left' with 3 left = true", ns.CheckTrigger(L1) == true)
L1.timeSec = 4
check("loss of control: 'at least 4' with 3 left = false", ns.CheckTrigger(L1) == false)
local L4 = { type = "lossOfControl", state = "yes" }
check("loss of control: nothing ticked -> unknown (not set)", ns.CheckTrigger(L4) == nil)
loc = {}
check("loss of control: no effect = false", ns.CheckTrigger(L3) == false)
loc = { { spellID = 1 } }   -- the effect name not readable
check("loss of control: a hidden effect name -> unknown", ns.CheckTrigger(L3) == nil)
loc = {}
check("loss of control is offered in the Add menu list", TY.lossOfControl ~= nil and not TY.lossOfControl.hideFromMenu)

-- 9. "readable in combat" line
Enum = Enum or {}
Enum.SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
local sec = { [5001] = 0, [5002] = 2 }
C_Secrets.GetSpellAuraSecrecy = function(id) return sec[id] or 2 end
ns.FindCDMFrame = function(id) return nil end
local nr = { type = "buffAura", spellID = 5001 }
check("combat line: never-secret aura reads 'readable'", (ns.TriggerCombatNote(B, "x", nr) or ""):find("readable") ~= nil)
nr.spellID = 5002
check("combat line: hidden aura says to add it to the Cooldown Manager", (ns.TriggerCombatNote(B, "x", nr) or ""):find("Cooldown Manager") ~= nil and (ns.TriggerCombatNote(B, "x", nr) or ""):find("hidden") ~= nil)
check("combat line: loss of control is readable (docs)", (ns.TriggerCombatNote(B, "x", { type = "lossOfControl" }) or ""):find("readable") ~= nil)

-- 10. the editor: duplicate the built-in keeps the extra IDs; seconds field shows only when a comparison is chosen
local E = ns.NewRule(); E.name = "Dup"; E.useBuff = true; E.buffID = 6001; E.buffAlt = { 6002, 6003 }; E.buffState = "present"; E.buffTimeOp = ">="; E.buffTimeSec = 3; E.enabled = true
ns.NormalizeRule(E); E.uid = ns.NewUID()
ns.rules = { E }
local built = ns.BuildOptionsTable()
local function find(t, key, depth)
  if type(t) ~= "table" or depth > 30 then return nil end
  if t[key] then return t[key] end
  for k, v in pairs(t) do if type(v) == "table" and k ~= "parent" then local r = find(v, key, depth + 1); if r then return r end end end
end
local function holder(t, key, depth)   -- the table whose key is `key`
  if type(t) ~= "table" or depth > 30 then return nil end
  if t[key] then return t end
  for k, v in pairs(t) do if type(v) == "table" and k ~= "parent" then local r = holder(v, key, depth + 1); if r then return r end end end
end
local pane = find(built, "pane_trig_buff", 0)
check("editor: the built-in Buff / Aura pane exists", pane ~= nil)
local acts = pane and pane.args.hdr.arg.xuiActions()
if acts and acts.copy then acts.copy() end
local cp = E.extra.list[1]
check("duplicate: the copy keeps every extra aura ID and the seconds left", cp and cp.type == "buffAura" and cp.alt and #cp.alt == 2 and cp.alt[1] == 6002 and cp.timeOp == ">=" and cp.timeSec == 3)
built = ns.BuildOptionsTable()
local trigArgs = holder(built, "pane_trig_buff", 0)
local xpane = trigArgs and trigArgs.x1
local body = xpane and (xpane.args.body or xpane.args)
local tsec = body and find(body, "timeSec", 0)
local top = body and find(body, "timeOp", 0)
check("editor: the row has Seconds left and Seconds", tsec ~= nil and top ~= nil)
cp.timeOp = nil
check("editor: Seconds hidden while 'Any time left'", tsec and tsec.hidden() == true)
check("editor: 'Any time left' shown as the choice when nothing is set", top and top.get() == "any")
cp.timeOp = "<"
check("editor: Seconds shown once a comparison is chosen", tsec and tsec.hidden() == false)
cp.state = "no"
check("editor: Seconds left hidden while State is MISSING", top and tsec and top.hidden() == true and tsec.hidden() == true)
local altBox = body and find(body, "alt", 0)
check("editor: extra aura IDs box on the row", altBox and altBox.type == "input" and altBox.get() == "6002, 6003")
if altBox then altBox.set(nil, "6004, 6004, 6001, 7") end
check("editor: typing IDs keeps numbers, drops repeats and the main ID", cp.alt and #cp.alt == 2 and cp.alt[1] == 6004 and cp.alt[2] == 7, cp.alt and table.concat(cp.alt, ","))
local bt = find(trigArgs and trigArgs.pane_trig_buff or {}, "buffTimeOp", 0)
check("editor: built-in Buff / Aura has its own Seconds left", bt ~= nil and bt.get() == ">=")
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = ["XayaUI", "XayaUI_Media", "XayaUI_Options"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), H.to_lua(L, {}))
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        if not ok:
            bad += 1
            print("FAIL:", name)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
