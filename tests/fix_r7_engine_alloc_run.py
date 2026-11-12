#!/usr/bin/env python3
"""Offline test (round 7, engine-b; V25(2) "no per-frame table or string allocation", V27 "nothing ... beyond what is ABSOLUTELY
necessary"). What the player gets: the combat engine makes (almost) no garbage on its busiest passes, so the game's garbage collector
has nothing of XayaUI's to clean up mid-fight (a collection is a hitch the player feels: SD-49). Before round 7 the V27 gate measured
about 66 KB of new tables on each routed pass in its fight (10 a second) and about 500 KB on each full re-check.
Measured here with the game's own answers made garbage-free (every API stand-in hands back a table made once), so every byte counted
is XayaUI's, with the collector stopped around one pass:
  1. a routed cooldown pass (a cooldown event; every cooldown check is read, nothing changed): before, every read of a cooldown made a
     new reading table and grew it field by field (Conditions.lua ReadCooldownRaw);
  2. the same pass when a cooldown did change: a new reading is made only for that spell;
  3. a full re-check of every rule with nothing changed (a load fact such as combat start): before, every aura and cooldown check, its
     reader lists, the per-rule lists and the indexes were made new (Engine.lua BuildProbes), and every rule's load checks made a table
     per check (Conditions.lua CheckContextRaw), every absent aura a list of its IDs (ns.AuraPresence), every trigger row a record and
     every rule its row lists (Triggers.lua);
  4. a pass over target debuff rows (a target aura event, out of combat): before, each row's read made a new record;
  5. a deleted rule leaves the engine's holders: before, the engine's lists of checks kept a deleted rule (and its checks) for the rest
     of the session.
And what the player sees does not change: the displays shown after each pass are the ones the rules ask for.
The numbers are the stand-in's (Lua 5.1, tests/harness); the game's own API calls (C_Spell.GetSpellCooldown and the aura calls hand back
a new table each call) and the game's C_Timer are not counted: INFERENCE that the timer makes no Lua garbage. UNVERIFIED IN GAME.
Run: python3 tests/fix_r7_engine_alloc_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- the game's answers, made once (the game's own tables are not XayaUI's garbage): cooldowns, charges, auras, target debuffs
local CDS, CDT, OFF = {}, {}, { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
C_Spell.GetSpellCooldown = function(id) return CDT[id] or OFF end
C_Spell.GetSpellCharges = function() return nil end
C_Spell.GetSpellLossOfControlCooldownInfo = nil
local AUR = {}
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit ~= "player" then return nil end return AUR[id] end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return AUR[id] end
local AUR_LIST = {}
C_UnitAuras.GetAuraDataByIndex = function(unit, i) if unit ~= "player" then return nil end return AUR_LIST[i] end
local DEB = {}
C_UnitAuras.GetUnitAuras = function(unit, filter) if unit == "target" then return DEB end return AUR_LIST end
UnitExists = function(u) return u == "player" or u == "target" end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local function display(r) r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32; r.visual.text.enabled = false; r.sound.enabled = false end
local CDR, BUF, TGT = {}, {}, {}
for i = 1, 40 do   -- 40 "ready" displays of 40 spells, 20 buff displays (10 auras up), 10 target debuff rows
  local r = ns.NewRule(); r.name = "cd " .. i; r.enabled = true
  r.useCooldown, r.spellID, r.cdState, r.buffState = true, 7000 + i, "ready", "none"
  display(r); r.visual.trigger = "condition"; ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; CDR[i] = r
end
for i = 1, 20 do
  local r = ns.NewRule(); r.name = "buff " .. i; r.enabled = true
  r.useBuff, r.buffID, r.buffState, r.cdState = true, 8000 + i, "present", "none"
  display(r); r.visual.trigger = "buffActive"; ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; BUF[i] = r
end
for i = 1, 10 do
  local r = ns.NewRule(); r.name = "debuff " .. i; r.enabled = true; r.useBuff = false
  r.extra = { mode = "all", list = { { type = "targetDebuff", spellID = 9000 + i, unit = "target", state = "yes" } } }
  display(r); r.visual.trigger = "condition"; ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; TGT[i] = r
end
for i = 1, 10 do
  local a = { spellId = 8000 + i, auraInstanceID = 500 + i, name = "Aura " .. i, icon = 1, applications = 1, duration = 600,
    expirationTime = W.now + 600, isHelpful = true, sourceUnit = "player" }
  AUR[8000 + i] = a; AUR_LIST[#AUR_LIST + 1] = a
end
for i = 1, 5 do DEB[#DEB + 1] = { spellId = 9000 + i, auraInstanceID = 900 + i, duration = 600, expirationTime = W.now + 600, applications = 1, sourceUnit = "player" } end
for i = 1, 20 do CDT[7000 + i] = { startTime = W.now, duration = 600, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 } end
ns.MarkDirty(); W.tick(1 / 60, 30)
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown(r) local fr = framesOf and framesOf[r]; return fr and fr:IsShown() and true or false end
local function picture()
  local s = {}
  for i = 1, 40 do s[#s + 1] = shown(CDR[i]) and "1" or "0" end
  for i = 1, 20 do s[#s + 1] = shown(BUF[i]) and "1" or "0" end
  for i = 1, 10 do s[#s + 1] = shown(TGT[i]) and "1" or "0" end
  return table.concat(s)
end
-- what the rules ask for: cooldowns 21-40 ready, auras 1-10 up, debuffs 1-5 on the target
local WANT = ("0"):rep(20) .. ("1"):rep(20) .. ("1"):rep(10) .. ("0"):rep(10) .. ("1"):rep(5) .. ("0"):rep(5)
check("(setup) the displays shown are the ones the rules ask for", picture() == WANT, picture())

-- the engine's own pass functions, found from ns.SetRulesDisabled / ns.MarkStateDirty by name (as tests/engine_bench.py's helper does)
local function engineLocal(want)
  local seen, queue, qi = {}, { ns.SetRulesDisabled, ns.MarkStateDirty, ns.MarkDirty }, 1
  while queue[qi] do
    local fn = queue[qi]; qi = qi + 1
    local i = 1
    while true do
      local name, v = debug.getupvalue(fn, i)
      if not name then break end
      if type(v) == "function" and not seen[v] then
        local src = debug.getinfo(v, "S").source or ""
        if src:find("Engine.lua", 1, true) then
          if name == want then return v end
          seen[v] = true; queue[#queue + 1] = v
        end
      end
      i = i + 1
    end
  end
  error("Engine.lua's local function '" .. want .. "' was not found")
end
local RoutedTimer, SettleTimer = engineLocal("RoutedTimer"), engineLocal("SettleTimer")
-- one pass, measured: each new byte is billed to the line that made it (a line hook; the hook's own work is not counted), and only
-- lines of XayaUI's addon files count (the stand-in game's own Lua, tests/harness/world.lua and this test's API stand-ins, is not
-- XayaUI's). The collector is stopped for the whole measured part (below), so a collection cannot shrink Lua's own stack between
-- passes and bill its regrowth to a line. Returns the bytes and the three lines that made the most.
local gi = debug.getinfo
local function measured(fn)
  local acc = {}
  local last, prev = collectgarbage("count"), nil
  debug.sethook(function(_, line)
    local d = collectgarbage("count") - last
    if d > 0 and prev then acc[prev] = (acc[prev] or 0) + d end
    local info = gi(2, "S")
    local src = info and info.source or ""
    prev = (src:find("XayaUI", 1, true) and not src:find("/tests/", 1, true)) and ((src:match("([%w_]+%.lua)$") or src) .. ":" .. tostring(line)) or nil
    last = collectgarbage("count")
  end, "l")
  fn()
  debug.sethook()
  local d = collectgarbage("count") - last
  if d > 0 and prev then acc[prev] = (acc[prev] or 0) + d end
  local total, top = 0, {}
  for k, v in pairs(acc) do total = total + v; top[#top + 1] = { k, v } end
  table.sort(top, function(a, b) return a[2] > b[2] end)
  local o = {}
  for i = 1, math.min(3, #top) do o[#o + 1] = ("%s %d"):format(top[i][1], math.floor(top[i][2] * 1024 + 0.5)) end
  return math.floor(total * 1024 + 0.5), table.concat(o, ", ")
end
local function routedPass(fireIt) W.tick(0.2, 1); fireIt(); return measured(RoutedTimer) end
collectgarbage("collect"); collectgarbage("stop")
-- warm-up: every reading and list made once
for _ = 1, 3 do routedPass(function() W.fire("SPELL_UPDATE_COOLDOWN") end) end
W.tick(1 / 60, 10)

---------------------------------------------------------------- 1. a cooldown pass, nothing changed
local b1, w1 = 0, ""
for _ = 1, 5 do local b, w = routedPass(function() W.fire("SPELL_UPDATE_COOLDOWN") end); if b >= b1 then b1, w1 = b, w end end
W.tick(1 / 60, 10)
check("1. a cooldown event with nothing changed (40 cooldown checks read): the engine's pass makes under 1 KB of garbage (before: a new reading per spell, about 28 KB)",
  b1 < 1024, b1 .. " bytes; " .. w1)
check("1. ... and the displays shown are unchanged", picture() == WANT, picture())

---------------------------------------------------------------- 2. a cooldown changed
CDT[7021] = { startTime = W.now, duration = 600, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
local b2, w2 = routedPass(function() W.fire("SPELL_UPDATE_COOLDOWN") end)
W.tick(1 / 60, 10)
local WANT2 = ("0"):rep(21) .. ("1"):rep(19) .. WANT:sub(41)
check("2. one cooldown starts: its 'ready' display hides (the only change on screen)", picture() == WANT2, picture())
check("2. ... the pass makes a new reading for that spell only, and re-checks that rule: under 1 KB (before: about 32 KB)", b2 < 1024, b2 .. " bytes; " .. w2)
CDT[7021] = nil; W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(0.2, 2)

---------------------------------------------------------------- 3. a full re-check (a load fact changed: combat starts, ends)
-- every rule is checked again; what the rules read did not change, so nothing on screen changes
local function fullPass(on)
  W.combat = on; W.fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
  return measured(SettleTimer)
end
fullPass(true); W.tick(1 / 60, 3); fullPass(false); W.tick(1 / 60, 3)
local b3, w3 = 0, ""
for k = 1, 4 do local b, w = fullPass(k % 2 == 1); if b >= b3 then b3, w3 = b, w end; W.tick(1 / 60, 3) end
W.combat = false
-- (what is left: the reference a present aura's reading hands its rule, one small table per aura that is up, Conditions.lua MakeAuraRef)
check("3. a full re-check of 70 rules as combat starts or ends: under 60 bytes of garbage per rule (before: about 2.8 KB per rule)",
  b3 < 60 * 70, ("%d bytes, %.0f per rule; %s"):format(b3, b3 / 70, w3))
check("3. ... and the displays shown are unchanged", picture() == WANT, picture())

---------------------------------------------------------------- 4. target debuff rows
local b4, w4 = 0, ""
for _ = 1, 4 do local b, w = routedPass(function() W.fire("UNIT_AURA", "target", { isFullUpdate = true }) end); if b >= b4 then b4, w4 = b, w end end
W.tick(1 / 60, 10)
check("4. a target aura event (10 Target Debuff rows read): under 1 KB of garbage (before: a new record per row read, about 4 KB)", b4 < 1024, b4 .. " bytes; " .. w4)
check("4. ... and the displays shown are unchanged", picture() == WANT, picture())
collectgarbage("restart")

---------------------------------------------------------------- 5. a deleted rule leaves the engine's holders
-- a rule with an aura, a cooldown and a target debuff row, and a cue on it, is deleted (taken out of the list, as the Recycle Bin does).
-- Once the engine has checked the list again, none of its holders keyed by rule keeps it: the checks (Engine.lua checkCache), the
-- per-rule check lists (probesOf), the rule-and-cues lists (famOf, famLists). Before, a deleted rule stayed in them for the session: in
-- Lua 5.1 a weak key is not freed while its own value reaches it, and a rule's check list holds the rule as a reader. (Other files keep
-- a deleted rule too, outside this unit's files: see the round-7 report.)
local function engineTable(want)
  local seen, queue, qi = {}, { ns.SetRulesDisabled, ns.MarkStateDirty, ns.MarkDirty }, 1
  while queue[qi] do
    local fn = queue[qi]; qi = qi + 1
    local i = 1
    while true do
      local name, v = debug.getupvalue(fn, i)
      if not name then break end
      if name == want and type(v) == "table" then return v end
      if type(v) == "function" and not seen[v] then
        local src = debug.getinfo(v, "S").source or ""
        if src:find("Engine.lua", 1, true) then seen[v] = true; queue[#queue + 1] = v end
      end
      i = i + 1
    end
  end
end
local DEL, CUE
do
  local r = ns.NewRule(); r.name = "deleted"; r.enabled = true
  r.useBuff, r.buffID, r.buffState, r.cdState, r.useCooldown, r.spellID = true, 8001, "present", "ready", true, 7001
  r.extra = { mode = "all", list = { { type = "targetDebuff", spellID = 9001, unit = "target", state = "yes" } } }
  display(r); r.visual.trigger = "buffActive"; ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  local c = ns.NewCueRule(r, "icon"); c.visual.w, c.visual.h = 32, 32
  DEL, CUE = r, c
end
ns.MarkDirty(); W.tick(1 / 60, 10)
local holders = {}
for _, name in ipairs({ "checkCache", "famLists", "probesOf", "famOf" }) do local t = engineTable(name); if t then holders[name] = t end end
local function kept()
  local o = {}
  for name, t in pairs(holders) do if t[DEL] ~= nil or t[CUE] ~= nil then o[#o + 1] = name end end
  table.sort(o)
  return o
end
local before = kept()
check("(setup) the rule and its cue are in the engine's holders while they are in the list", #before >= 2, table.concat(before, ", "))
if ns.EndRule then ns.EndRule(CUE); ns.EndRule(DEL) end
for i = #ns.rules, 1, -1 do if ns.rules[i] == DEL or ns.rules[i] == CUE then table.remove(ns.rules, i) end end
ns.MarkDirty(); W.tick(1 / 60, 10)
local after = kept()
check("5. a deleted rule and its cue: once the engine has checked the rule list again, none of its holders keeps them", #after == 0,
  table.concat(after, ", "))
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
