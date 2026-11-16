#!/usr/bin/env python3
"""Offline test (round 9, REQUEST-LOG A23 SD-77, her answer "Route + narrow (Recommended)").

Before round 9 the costliest frame of every fight was combat start: entering combat is a load fact, so the engine re-checked every rule
(about 300 in the V27 gate) in one frame, and did the same at combat end, at a boss pull, on mounting or joining a group. Movement, a
rune, a totem and a loss of control re-checked every live rule. Now (XayaUI_Rules/Engine.lua, NW and ns.MarkStateDirty; Triggers.lua;
Conditions.lua ns.LoadReads):

  A. ROUTE: each of PLAYER_STARTED_MOVING / PLAYER_STOPPED_MOVING, PLAYER_TOTEM_UPDATE, RUNE_POWER_UPDATE and LOSS_OF_CONTROL_ADDED /
     _UPDATE re-checks only the rules with a row that reads it (and, for a loss of control, the cooldown checks: a lockout), on the next
     frame; the row's display changes on that frame; no every-live-rule pass runs. With a live rule whose row type the routing does not
     know, the same event re-checks every live rule (the fallback).
  B. NARROW: combat start, combat end, a boss pull (ENCOUNTER_START: the encounter and its ID), the boss's end, mounting, joining a
     group: on the frame after the change exactly the rules the change concerns are re-checked (their load reads it; combat, the
     encounter: also every rule with a row outside the aura / cooldown checks, the rules whose check answers differently, and the
     displays with an out-of-combat opacity), no other rule; what each shows on that frame is right (V31, V32): a combat-only rule
     appears, an out-of-combat rule goes, a Target Debuff "absent" row goes in combat (its answer is unknown there) and comes back
     after, a display drawn at half opacity out of combat is drawn fully in combat and at half again after, a boss-only rule follows
     the pull, a mount or group rule follows its fact; a rule nothing concerns is not re-checked and still shows what it showed.
  C. ns.LoadReads is a superset of what the load check reads: on 400 generated rules (own Load tab, groups, nested groups, Always /
     Never, a talent requirement) and every single context value changed, a load answer that changes always names that value.
  D. completeness of the route: every place in XayaUI_Rules that reads movement, totems, runes or loss of control (IsPlayerMoving,
     GetUnitSpeed, GetTotemInfo, GetRuneCooldown / ReadyRunes, C_LossOfControl / PlayerHasLossOfControl, GetSpellLossOfControlCooldownInfo)
     belongs to a reader the engine routes that event to.
  E. Lua 5.1: Engine.lua compiles, with at least 10 of the main chunk's 200 local names free at its busiest point (round 8 left 1;
     the round-8 prototype of this change did not compile).
  F. memory: 10 more combat in / out cycles after 5 to saturate add nothing to the Lua heap that stays (whole KB, after a full collect).
  G. completeness of the narrowing: every place in XayaUI_Rules that reads combat, mount, group, rest, instance, zone, encounter,
     Mythic+ or spec is covered by it (the load facts, the Target Debuff "absent" answer, the out-of-combat opacity) or is named as not
     a rule's answer or drawing (a chat channel, the game-played sound copy, the combat engine's own events) in this file.
Stand-in: the whole-addon harness (tests/harness). UNVERIFIED IN GAME.
Run: python3 tests/fix_r9_engine_narrow_run.py"""
import os, re, sys, glob, random
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name, ok and true or false, extra ~= nil and tostring(extra) or nil } end
-- ---------------------------------------------------------------- the game model
local G = { auras = {}, moving = false, totems = {}, runes = 0, loc = {}, group = false, enc = false, mounted = false, locked = {},
  target = { exists = true, debuffs = {} }, combo = 2 }
local function copy(a) local t = {}; for k, v in pairs(a) do t[k] = v end; return t end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) local a = G.auras[id]; return a and copy(a) or nil end
C_UnitAuras.GetUnitAuraBySpellID = function(u, id) if u == "player" then return C_UnitAuras.GetPlayerAuraBySpellID(id) end end
C_UnitAuras.GetUnitAuras = function(unit) if unit == "target" and G.target.exists then return G.target.debuffs end return {} end
local UE0 = UnitExists
UnitExists = function(u) if u == "target" then return G.target.exists end return UE0(u) end
IsPlayerMoving = function() return G.moving end
GetTotemInfo = function(slot) local t = G.totems[slot]; if t then return true, "Totem", W.now, 30, 136243, 1, t end; return false, "", 0, 0, 0, 1, 0 end
GetRuneCooldown = function(i) return 0, 10, i <= G.runes end
C_LossOfControl.GetActiveLossOfControlDataCount = function() return #G.loc end
C_LossOfControl.GetActiveLossOfControlData = function(i) return G.loc[i] end
C_Spell.GetSpellLossOfControlCooldownInfo = function(id) if G.locked[id] then return { isActive = true, startTime = W.now, duration = 3 } end return nil end
C_Spell.GetSpellCooldown = function() return { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 } end
C_SpellBook.IsSpellKnownOrInSpellBook = function() return true end
IsPlayerSpell = function() return true end
IsInGroup = function() return G.group end
IsMounted = function() return G.mounted end
C_InstanceEncounter = { IsEncounterInProgress = function() return G.enc end }
UnitPower = function(u, e) return G.combo end
for i = 1, 20 do G.auras[1000 + i] = { spellId = 1000 + i, auraInstanceID = 500 + i, name = "Buff " .. i, applications = 1, duration = 600,
  expirationTime = 0, sourceUnit = "player", isHelpful = true } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
for _, a in pairs(G.auras) do a.expirationTime = W.now + 600 end
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local function mk(nm, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.trigger = "condition"; r.visual.text.enabled = false; r.sound.enabled = false
  f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local function always(nm, f) return mk(nm, function(r) r.cdState, r.buffState = "none", "none"; if f then f(r) end end) end
local function row(nm, t) return always(nm, function(r) r.extra = { list = { t } } end) end
local P = {}   -- every rule by name
local function keep(r) P[r.name] = r; return r end
for i = 1, 20 do keep(mk("buff " .. i, function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1000 + i, "present", "none" end)) end
for i = 1, 8 do keep(mk("cooldown " .. i, function(r) r.useCooldown, r.spellID, r.cdState, r.buffState = true, 2000 + i, "ready", "none" end)) end
keep(always("combat only", function(r) r.load.combat = "yes" end))
keep(mk("combat buff", function(r) r.useBuff, r.buffID, r.buffState, r.cdState, r.load.combat = true, 1100, "present", "none", "yes" end))
local cue = ns.NewCueRule(P["combat only"], "sound"); cue.sound.source, cue.sound.value = "kit", "8959"; P["combat only (cue)"] = cue
keep(always("out of combat only", function(r) r.load.combat = "no" end))
keep(always("not mounted", function(r) r.load.mounted = "no" end))
keep(always("group only", function(r) r.load.group = "yes" end))
keep(always("boss only", function(r) r.load.encounter = "yes" end))
keep(always("boss 2001 only", function(r) r.load.encounterIDs = { ["2001"] = true } end))
keep(row("debuff absent", { type = "targetDebuff", spellID = 5001, unit = "target", state = "no", cdmAbsent = "no" }))
keep(always("half opacity out of combat", function(r) r.visual.oocAlpha = 0.5 end))
keep(row("moving", { type = "playerState", what = "moving", state = "yes" }))
keep(row("stunned", { type = "playerState", what = "stunned", state = "yes" }))
keep(row("loss of control", { type = "lossOfControl", any = true, state = "yes" }))
keep(row("totem", { type = "totem", slot = "any", spellID = 0, state = "yes" }))
keep(row("runes", { type = "resource", power = "runes", op = ">=", count = 3 }))
keep(row("death knight runes", { type = "dkRunes", op = ">=", count = 2 }))
keep(row("combo points", { type = "resource", power = "comboPoints", op = ">=", count = 3 }))
keep(row("alive", { type = "playerState", what = "alive", state = "yes" }))
keep(mk("locked out", function(r) r.useCooldown, r.spellID, r.cdState, r.buffState, r.countLOC = true, 2100, "ready", "none", true end))
for _, r in ipairs(ns.rules) do if r.visual then r.visual.x, r.visual.y = 0, 0 end end
ns.MarkDirty(); W.tick(1 / 60, 20); W.tick(0.5, 2)
local ES = ns.EngineStats
local frames = ns.VisualProbeState and ns.VisualProbeState()
local function shown(nm) local f = frames and frames[P[nm]]; return f and f:IsShown() and true or false end
local function alpha(nm) local f = frames and frames[P[nm]]; return f and f:IsShown() and ("%.2f"):format(f:GetAlpha()) or "-" end
-- every rule's display as the player sees it (shown, and opacity), for "a rule nothing concerns still shows what it showed"
local function look() local t = {}; for nm in pairs(P) do t[nm] = tostring(shown(nm)) .. "/" .. alpha(nm) end; return t end
local n = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) n[r] = (n[r] or 0) + 1; return E0(r, ...) end
local function reset() for k in pairs(n) do n[k] = nil end end
-- the rules re-checked since reset() (by name, sorted), and the rules never re-checked
local function names() local t = {}; for r in pairs(n) do t[#t + 1] = tostring(r.name) end; table.sort(t); return t end
local function setOf(l) local s = {}; for _, x in ipairs(l) do s[x] = true end; return s end
local function same(got, want)
  local a, b = setOf(got), setOf(want)
  local extra, miss = {}, {}
  for x in pairs(a) do if not b[x] then extra[#extra + 1] = x end end
  for x in pairs(b) do if not a[x] then miss[#miss + 1] = x end end
  table.sort(extra); table.sort(miss)
  return #extra == 0 and #miss == 0, ("re-checked %d; not expected: [%s]; missing: [%s]"):format(#got, table.concat(extra, ", "), table.concat(miss, ", "))
end
W.tick(0.5, 2)
check("(setup) out of combat: the absent debuff row shows, the half-opacity display is drawn at 0.50, the out-of-combat rule shows",
  shown("debuff absent") and alpha("half opacity out of combat") == "0.50" and shown("out of combat only") and not shown("combat only"),
  ("%s %s %s %s"):format(tostring(shown("debuff absent")), alpha("half opacity out of combat"), tostring(shown("out of combat only")), tostring(shown("combat only"))))

-- the rules a change of restriction (combat, an encounter) re-checks besides its load readers: every live rule with a row outside the checks
local ROWS = { "moving", "stunned", "loss of control", "totem", "runes", "death knight runes", "combo points", "alive" }
local function plus(a, b) local t = {}; for _, x in ipairs(a) do t[#t + 1] = x end; for _, x in ipairs(b) do t[#t + 1] = x end; return t end
-- play one change; on the frame after it: which rules were re-checked, and what the player sees
local function play(label, fire, want, sees, settleFirst)
  W.tick(0.25, 2)   -- (a quiet moment: the change runs on the very next frame)
  local before = look()
  local all0, set0 = ES.all, ES.settle
  reset()
  fire()
  W.tick(1 / 60, 1)
  local got = names()
  local ok, why = same(got, want)
  check("B. " .. label .. ": exactly the rules it concerns are re-checked on the next frame", ok, why)
  check("B. " .. label .. ": no every-live-rule pass, one settle pass", ES.all == all0 and ES.settle == set0 + 1,
    ("every-live-rule passes %d, settle passes %d"):format(ES.all - all0, ES.settle - set0))
  local now = look()
  local bad = {}
  for nm, v in pairs(now) do
    local w = sees[nm]
    if w == nil then w = before[nm] end   -- (a rule the change does not concern: as it was)
    if v ~= w then bad[#bad + 1] = nm .. " " .. v .. " (want " .. w .. ")" end
  end
  table.sort(bad)
  check("B. " .. label .. ": on that frame every display shows what it should (the rest as before)", #bad == 0, table.concat(bad, "; "))
end
local LOADED = "true/1.00"
local HALF = "true/0.50"
local GONE = "false/-"
play("combat start", function() W.enterCombat() end,
  plus({ "combat only", "combat only (cue)", "combat buff", "out of combat only", "debuff absent", "half opacity out of combat" }, ROWS),
  { ["combat only"] = LOADED, ["out of combat only"] = GONE, ["debuff absent"] = GONE, ["half opacity out of combat"] = LOADED })
-- the rules a change loaded join the live lists: in combat, the combat-only buff rule follows its aura events (it was not loaded before)
do
  W.tick(0.25, 2)
  local a = { spellId = 1100, auraInstanceID = 1100, name = "Combat buff", applications = 1, duration = 30, expirationTime = W.now + 30, sourceUnit = "player", isHelpful = true }
  G.auras[1100] = a; W.fire("UNIT_AURA", "player", { addedAuras = { copy(a) } }); W.tick(1 / 60, 1)
  local on = shown("combat buff")
  W.tick(0.25, 2)
  G.auras[1100] = nil; W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { 1100 } }); W.tick(1 / 60, 1)
  check("B. after combat start, a rule the change loaded follows its own events: the combat-only buff rule shows on its aura's event and hides when it goes",
    on and not shown("combat buff"), tostring(on) .. " / " .. tostring(shown("combat buff")))
end
play("boss pull (ENCOUNTER_START: the encounter and its ID)", function() G.enc = true; W.fire("ENCOUNTER_START", 2001, "Stand-in Boss", 16, 20) end,
  plus({ "boss only", "boss 2001 only" }, ROWS), { ["boss only"] = LOADED, ["boss 2001 only"] = LOADED })
play("the boss's end (ENCOUNTER_END)", function() G.enc = false; W.fire("ENCOUNTER_END", 2001, "Stand-in Boss", 16, 20, 1) end,
  plus({ "boss only", "boss 2001 only" }, ROWS), { ["boss only"] = GONE, ["boss 2001 only"] = GONE })
play("combat end", function() W.leaveCombat() end,
  plus({ "combat only", "combat only (cue)", "combat buff", "out of combat only", "debuff absent", "half opacity out of combat" }, ROWS),
  { ["combat only"] = GONE, ["out of combat only"] = LOADED, ["debuff absent"] = LOADED, ["half opacity out of combat"] = HALF })
play("mounting", function() G.mounted = true; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED") end, { "not mounted" }, { ["not mounted"] = GONE })
play("dismounting", function() G.mounted = false; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED") end, { "not mounted" }, { ["not mounted"] = LOADED })
play("joining a group", function() G.group = true; W.fire("GROUP_ROSTER_UPDATE") end, { "group only" }, { ["group only"] = LOADED })
play("leaving the group", function() G.group = false; W.fire("GROUP_ROSTER_UPDATE") end, { "group only" }, { ["group only"] = GONE })

-- A. the routed events
local function route(label, fire, want, sees)
  W.tick(0.25, 2)
  local before = look()
  local all0 = ES.all
  reset()
  fire()
  W.tick(1 / 60, 1)
  local ok, why = same(names(), want)
  check("A. " .. label .. ": only the rules that read it are re-checked, on the next frame", ok, why)
  check("A. " .. label .. ": no every-live-rule pass", ES.all == all0, ES.all - all0)
  local now = look()
  local bad = {}
  for nm, v in pairs(now) do
    local w = sees[nm]; if w == nil then w = before[nm] end
    if v ~= w then bad[#bad + 1] = nm .. " " .. v .. " (want " .. w .. ")" end
  end
  table.sort(bad)
  check("A. " .. label .. ": on that frame its rows show the change, every other display as before", #bad == 0, table.concat(bad, "; "))
end
local POWER = { "runes", "death knight runes", "combo points" }
route("PLAYER_STARTED_MOVING", function() G.moving = true; W.fire("PLAYER_STARTED_MOVING") end, { "moving" }, { moving = LOADED })
route("PLAYER_STOPPED_MOVING", function() G.moving = false; W.fire("PLAYER_STOPPED_MOVING") end, { "moving" }, { moving = GONE })
route("PLAYER_TOTEM_UPDATE (placed)", function() G.totems[1] = 5394; W.fire("PLAYER_TOTEM_UPDATE", 1) end, { "totem" }, { totem = LOADED })
route("PLAYER_TOTEM_UPDATE (gone)", function() G.totems[1] = nil; W.fire("PLAYER_TOTEM_UPDATE", 1) end, { "totem" }, { totem = GONE })
route("RUNE_POWER_UPDATE (ready)", function() G.runes = 4; W.fire("RUNE_POWER_UPDATE", 4, true) end, POWER,
  { runes = LOADED, ["death knight runes"] = LOADED })
route("RUNE_POWER_UPDATE (spent)", function() G.runes = 1; W.fire("RUNE_POWER_UPDATE", 2, false) end, POWER,
  { runes = GONE, ["death knight runes"] = GONE })
route("LOSS_OF_CONTROL_ADDED (a stun, the spell locked)", function()
  G.loc = { { locType = "STUN", timeRemaining = 2 } }; G.locked[2100] = true; W.fire("LOSS_OF_CONTROL_ADDED", "player", 1) end,
  { "stunned", "loss of control", "locked out" }, { stunned = LOADED, ["loss of control"] = LOADED, ["locked out"] = GONE })
route("LOSS_OF_CONTROL_UPDATE (over)", function() G.loc = {}; G.locked[2100] = nil; W.fire("LOSS_OF_CONTROL_UPDATE", "player") end,
  { "stunned", "loss of control", "locked out" }, { stunned = GONE, ["loss of control"] = GONE, ["locked out"] = LOADED })
-- the fallback: a live rule with a row type the routing does not know: movement re-checks every live rule again
local odd = keep(row("unknown row type", { type = "madeUpRowType", state = "yes" }))
ns.MarkDirty(); W.tick(1 / 60, 10); W.tick(0.5, 2)
local all0 = ES.all
reset(); G.moving = true; W.fire("PLAYER_STARTED_MOVING"); W.tick(1 / 60, 1)
local got = names()
check("A. fallback: with a live rule whose row type the routing does not know, movement re-checks every live rule",
  ES.all == all0 + 1 and #got >= 40 and shown("moving"), ("every-live-rule passes %d, re-checked %d, moving row %s"):format(ES.all - all0, #got, tostring(shown("moving"))))
for i = #ns.rules, 1, -1 do if ns.rules[i] == odd then table.remove(ns.rules, i) end end
P["unknown row type"] = nil
G.moving = false; ns.MarkDirty(); W.tick(1 / 60, 10); W.tick(0.5, 2)

-- F. memory: combat in and out again and again (after saturation nothing stays)
ns.Evaluate = E0
local function cycle() W.enterCombat(); W.tick(1 / 60, 3); G.enc = true; W.fire("ENCOUNTER_START", 2001, "B", 16, 20); W.tick(1 / 60, 3)
  G.enc = false; W.fire("ENCOUNTER_END", 2001, "B", 16, 20, 1); W.tick(1 / 60, 3); W.leaveCombat(); W.tick(1 / 60, 3); W.tick(0.25, 2) end
for _ = 1, 5 do cycle() end
collectgarbage("collect"); collectgarbage("collect")
local m0 = collectgarbage("count")
for _ = 1, 10 do cycle() end
collectgarbage("collect"); collectgarbage("collect")
local m1 = collectgarbage("count")
local ws = #W.sounds
check("F. 10 combat in / out cycles (with a boss pull each) after 5 to saturate: no Lua memory stays (under 1 KB, the stand-in's own sound list excluded)",
  m1 - m0 < 1, ("%.1f KB -> %.1f KB: %+.2f KB; the stand-in's sound list holds %d entries"):format(m0, m1, m1 - m0, ws))
local errs = {}
for i = 1, #W.errors do errs[#errs + 1] = tostring(W.errors[i]):sub(1, 160) end
check("no Lua error", #W.errors == 0, table.concat(errs, " | "))
return R
end
'''

# ---- C: ns.LoadReads is a superset of what the load check reads -----------------------------------------------------------------
LOADREADS = r'''
return function(W, L, seed)
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
math.randomseed(seed)
local function pick(t) return t[math.random(#t)] end
local TRI = { "yes", "no", nil, nil }
local FACTS = ns.CTX_FACTS
if not (FACTS and ns.LoadReads) then return { bad = -1, why = "ns.CTX_FACTS / ns.LoadReads missing" } end
-- groups: some nested, some with lists, one Always (with class / spec kept), one Never
ns.folders = {}
local folders = {}
for i = 1, 8 do
  local f = ns.NewFolder("G" .. i, (i > 4 and math.random() < 0.6) and folders[math.random(4)].id or nil)
  if math.random() < 0.4 then f.loadClasses = { WARRIOR = true } end
  if math.random() < 0.4 then f.loadSpecs = { ["71"] = true } end
  if math.random() < 0.3 then f.loadRoles = { TANK = true } end
  if math.random() < 0.3 then f.loadInst = { party = true } end
  if math.random() < 0.4 then f.loadIds = { mapIDs = (math.random() < 0.5) and { ["2"] = true } or nil, encounterIDs = (math.random() < 0.5) and { ["2001"] = true } or nil,
    difficulties = (math.random() < 0.3) and { ["8"] = true } or nil, sizes = (math.random() < 0.3) and { ["5"] = true } or nil,
    instanceIDs = (math.random() < 0.3) and { ["600"] = true } or nil } end
  if i == 7 then f.loadOverride = "always"; f.alwaysClass = true end
  if i == 8 then f.loadOverride = "never" end
  folders[i] = f
end
local rules = {}
ns.rules = rules
for i = 1, 400 do
  local r = ns.NewRule(); r.name = "r" .. i; r.enabled = true
  local l = r.load
  for _, c in ipairs(ns.LOAD_TRI) do l[c.key] = pick(TRI) end
  local m = math.random()
  l.mode = (m < 0.1) and "always" or (m < 0.15) and "never" or (m < 0.45) and "any" or nil
  if math.random() < 0.3 then l.classes = { WARRIOR = true, MAGE = (math.random() < 0.5) or nil } end
  if math.random() < 0.3 then l.specs = { ["71"] = true } end
  if math.random() < 0.1 then l.specID = 72 end
  if math.random() < 0.3 then l.roles = { DAMAGER = true } end
  if math.random() < 0.1 then l.role = "TANK" end
  if math.random() < 0.2 then l.heroes = { ["31"] = true } end
  if math.random() < 0.3 then l.instanceTypes = { party = true, raid = (math.random() < 0.5) or nil } end
  if math.random() < 0.2 then l.mapIDs = { ["2"] = (math.random() < 0.7) and true or "not" } end
  if math.random() < 0.2 then l.encounterIDs = { ["2001"] = true } end
  if math.random() < 0.2 then l.difficulties = { ["8"] = true } end
  if math.random() < 0.2 then l.sizes = { ["5"] = true } end
  if math.random() < 0.2 then l.instanceIDs = { ["600"] = (math.random() < 0.7) and true or "not" } end
  if math.random() < 0.1 then l.alwaysClass = true end
  if math.random() < 0.1 then l.alwaysSpec = true end
  if math.random() < 0.15 then l.classUse = false end
  if math.random() < 0.5 then r.folder = folders[math.random(#folders)].id end
  rules[i] = r
end
ns.configVersion = (ns.configVersion or 0) + 1
-- two values for every context fact (equipGen: the gear count; "talents" is not a context value)
local VALUES = { instanceType = { "party", "raid" }, specID = { 71, 72 }, role = { "TANK", "DAMAGER" }, hero = { 31, 32 }, class = { "WARRIOR", "MAGE" },
  mapID = { 2, 3 }, instanceID = { 600, 601 }, difficultyID = { 8, 1 }, instSize = { 5, 20 }, encounterID = { 2001, 0 }, equipGen = { 1, 2 } }
local function base()
  local c = {}
  for _, f in ipairs(FACTS) do local v = VALUES[f]; if v then c[f] = v[math.random(2)] else c[f] = math.random() < 0.5 end end
  c.maps = { [c.mapID] = true }
  return c
end
local bad, tried, changed, why = 0, 0, 0, {}
local raw = ns._CheckContextRawForTests or function(r, c) return ns.CheckContext(r, c) end   -- (no sig on c: the memo is not used)
for i = 1, #rules do
  local r = rules[i]
  local reads = {}
  for _, k in ipairs(ns.LoadReads(r)) do reads[k] = true end
  for t = 1, 6 do
    local a = base()
    for _, f in ipairs(FACTS) do
      local b = {}; for k, v in pairs(a) do b[k] = v end
      local v = VALUES[f]
      if v then b[f] = (a[f] == v[1]) and v[2] or v[1] else b[f] = not a[f] end
      b.maps = { [b.mapID] = true }
      local oa = ns.CheckContext(r, a)
      local ob = ns.CheckContext(r, b)
      tried = tried + 1
      if oa ~= ob then
        changed = changed + 1
        if not reads[f] then bad = bad + 1; if #why < 6 then why[#why + 1] = r.name .. ": " .. f end end
      end
    end
  end
end
return { bad = bad, tried = tried, changed = changed, why = table.concat(why, "; ") }
end
'''

# ---- D: every reader of the routed events is routed -------------------------------------------------------------------------------
READERS = re.compile(r"\b(IsPlayerMoving|GetUnitSpeed|GetTotemInfo|GetRuneCooldown|ReadyRunes\(|C_LossOfControl|PlayerHasLossOfControl\(|"
                     r"LossOfControlNow\(|GetSpellLossOfControlCooldownInfo)")
# where each reader may sit, and the route that covers it: (file, the enclosing row type or function) -> what the engine must route there
COVERED = {
    ("Triggers.lua", "playerState"): "movement and loss of control: ns.STATE_ROUTE (moving -> move, the loss-of-control checks -> loc)",
    ("Triggers.lua", "totem"): "totem", ("Triggers.lua", "lossOfControl"): "loc", ("Triggers.lua", "dkRunes"): "power",
    ("Triggers.lua", "resource"): "power",
    ("Triggers.lua", "fn:ReadyRunes"): "power (its readers: the dkRunes and resource rows)",
    ("Triggers.lua", "fn:ns.TriggerNumber"): "power (a resource row's number, read by its own rule's conditions)",
    ("Triggers.lua", "fn:ns.PlayerHasLossOfControl"): "loc (read by the playerState row)",
    ("Triggers.lua", "fn:LossOfControlNow"): "loc (read by the lossOfControl row)",
    ("Conditions.lua", "fn:ReadCooldownRaw"): "the cooldown checks, read on a loss of control (rule.countLOC)",
    ("Triggers.lua", "events"): "the event registration itself",
}


def enclosing(lines, i):
    for j in range(i, -1, -1):
        m = re.match(r'^Add\("(\w+)"', lines[j])
        if m:
            return m.group(1)
        m = re.match(r'^(?:local )?function ([\w.:]+)', lines[j])
        if m:
            return "fn:" + m.group(1)
        if re.match(r'^local ev = CreateFrame|^for _, e in ipairs|^[\w.]+:SetScript\("On', lines[j]):
            return "events"
    return "?"


# ---- G: every reader of a load fact is covered by the narrowed re-check (or is not a rule's answer or drawing) ------------------------
LOAD_READERS = re.compile(r"\b(UnitAffectingCombat|InCombatLockdown|IsMounted|IsInGroup|IsInRaid|IsResting|IsInInstance|GetInstanceInfo|"
                          r"GetBestMapForUnit|IsChallengeModeActive|InEncounter|GetSpecialization\b|GetSpecializationInfo|GetActiveHeroTalentSpec|"
                          r"UnitGroupRolesAssigned)")
LOAD_COVERED = {
    ("Conditions.lua", "fn:ns.SetMatch"): "the Yes / No load facts (ns.LOAD_TRI): NW.by",
    ("Conditions.lua", "fn:CurrentSpec"): "spec / role: NW.by, and every live rule (NW.ALL_LIVE)",
    ("Conditions.lua", "fn:ReadPlace"): "zone, instance, difficulty, size, encounter ID: NW.by",
    ("Conditions.lua", "fn:ns.ReadContext"): "instance type, hero talents: NW.by",
    ("Conditions.lua", "fn:ns.LoadPlaceNow"): "the settings' Add current buttons (not a rule's answer)",
    ("Triggers.lua", "targetDebuff"): "'absent' unknown in combat: every aura check is read on a combat edge (NW.RESTRICT)",
    ("Visual.lua", "fn:ns.UpdateVisualText"): "the out-of-combat opacity: NW.ooc",
    ("Engine.lua", "events"): "(the engine's own combat flag for status snapshots, on entering the world)",
    ("Actions.lua", "fn:DoChat"): "the chat channel at the moment an action posts (not a rule's answer or drawing)",
    ("AuraList.lua", "fn:CurrentSpec"): "the Cooldown Manager catalogue (a spec change re-checks every live rule)",
    ("AuraSound.lua", "fn:MountedNow"): "the game-played sound copy follows the mount and combat events itself (SD-25)",
    ("AuraSound.lua", "fn:A.Sync"): "the game-played sound copy (its own events)", ("AuraSound.lua", "fn:OnMount"): "the game-played sound copy",
    ("AuraSound.lua", "fn:A.Queue"): "the game-played sound copy (its own events)",
    ("ClassLearn.lua", "fn:CL.Learn"): "learning paused in combat (not a rule's answer)",
    ("AuraDisplay.lua", "fn:D.Build"): "the combat engine's protected container waits for combat end (its own event)",
    ("AuraDisplay.lua", "fn:QueueBuild"): "the combat engine's container (its own events)", ("AuraDisplay.lua", "fn:RulesOff"): "/xui disable",
    ("AuraModel.lua", "fn:SpecID"): "the combat engine's model (its own events)", ("AuraModel.lua", "fn:AurasReadable"): "the combat engine's learning",
    ("AuraModel.lua", "fn:RefreshSoon"): "the combat engine's model (its own events)", ("AuraTracker.lua", "events"): "the tracker's own events",
}


def scan_load_readers():
    found, uncovered = [], []
    for f in sorted(glob.glob(os.path.join(ROOT, "XayaUI_Rules", "*.lua")) + glob.glob(os.path.join(ROOT, "XayaUI_Rules", "Combat", "*.lua"))):
        lines = open(f, encoding="utf-8").read().split("\n")
        for i, ln in enumerate(lines):
            if LOAD_READERS.search(ln.split("--", 1)[0]):
                key = (os.path.basename(f), enclosing(lines, i))
                found.append(key)
                if key not in LOAD_COVERED:
                    uncovered.append("%s:%d (%s)" % (key[0], i + 1, key[1]))
    return found, uncovered


def scan_readers():
    found, uncovered = [], []
    for f in sorted(glob.glob(os.path.join(ROOT, "XayaUI_Rules", "*.lua")) + glob.glob(os.path.join(ROOT, "XayaUI_Rules", "Combat", "*.lua"))):
        lines = open(f, encoding="utf-8").read().split("\n")
        for i, ln in enumerate(lines):
            code = ln.split("--", 1)[0]
            if READERS.search(code) and not re.search(r'"(PLAYER_|RUNE_|LOSS_OF)', code):
                key = (os.path.basename(f), enclosing(lines, i))
                found.append("%s:%d %s" % (key[0], i + 1, key[1]))
                if key not in COVERED:
                    uncovered.append("%s:%d (%s)" % (key[0], i + 1, key[1]))
    return found, uncovered


DEPS = r'''
return function(W, L)
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
local function d(t) local r = ns.NewRule(); r.name = "x"; r.enabled = true; r.extra = { list = { t } }; return ns.EngineDeps(r) end
local out = {}
out.moving = d({ type = "playerState", what = "moving" }).move and true or false
out.stunned = d({ type = "playerState", what = "stunned" }).loc and true or false
out.rooted = d({ type = "playerState", what = "rooted" }).loc and true or false
out.silenced = d({ type = "playerState", what = "silenced" }).loc and true or false
out.incap = d({ type = "playerState", what = "incapacitated" }).loc and true or false
out.totem = d({ type = "totem" }).totem and true or false
out.loc = d({ type = "lossOfControl" }).loc and true or false
out.dkRunes = d({ type = "dkRunes" }).power and true or false
out.resource = d({ type = "resource", power = "runes" }).power and true or false
out.range = d({ type = "rangeCheck", unit = "target", spellID = 1 }).move and true or false
local route = ns.STATE_EVENT_ROUTE or {}
out.ev = (route.PLAYER_STARTED_MOVING == "move" and route.PLAYER_STOPPED_MOVING == "move" and route.PLAYER_TOTEM_UPDATE == "totem"
  and route.RUNE_POWER_UPDATE == "rune" and route.LOSS_OF_CONTROL_ADDED == "loc" and route.LOSS_OF_CONTROL_UPDATE == "loc") and true or false
return out
end
'''


def lua_room(path):
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    chk = L.eval("function(s) local f, e = loadstring(s); if f then return true end return false, e end")
    src = open(path, encoding="utf-8").read()
    def ok(k):
        # k extra names declared first are live through the whole main chunk: this finds the room at its busiest point (inside a block)
        r = chk("".join("local _xr%d = %d " % (i, i) for i in range(k)) + src)
        return r[0] if isinstance(r, tuple) else r
    if not ok(0):
        return -1
    k = 0
    while ok(k + 1):
        k += 1
    return k


def new_world():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    return L, world, loader


def main():
    total = bad = 0

    def report(name, ok, extra=None):
        nonlocal total, bad
        total += 1
        bad += 0 if ok else 1
        print(("ok  " if ok else "FAIL: ") + name + ("" if not extra else "  [%s]" % extra))

    L, world, loader = new_world()
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    for i in range(1, len(res) + 1):
        report(res[i][1], bool(res[i][2]), res[i][3])

    L, world, loader = new_world()
    out = L.eval("function(src, W, Ld, s) return loadstring(src)()(W, Ld, s) end")(LOADREADS, world, loader, 9)
    report("C. ns.LoadReads names every load fact whose change changes a load answer (400 generated rules x 6 contexts x every fact)",
           out["bad"] == 0 and (out["changed"] or 0) > 200,
           "%s tried, %s answers changed, %s not named: %s" % (out["tried"], out["changed"], out["bad"], out["why"]))

    found, uncovered = scan_readers()
    report("D. every place in XayaUI_Rules that reads movement, totems, runes or loss of control is a reader the engine routes (%d places)"
           % len(found), not uncovered and len(found) >= 8, "; ".join(uncovered) or None)
    L, world, loader = new_world()
    d = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(DEPS, world, loader)
    miss = [k for k in ("moving", "stunned", "rooted", "silenced", "incap", "totem", "loc", "dkRunes", "resource", "range", "ev") if not d[k]]
    report("D. each such reader is tied to its event in the engine (Player State Moving and the Range Check rows -> movement; the "
           "loss-of-control checks and rows -> loss of control; Totem -> totem; the rune rows -> runes) and Triggers.lua sends each event its kind",
           not miss, ", ".join(miss) or None)

    lfound, luncovered = scan_load_readers()
    report("G. every place in XayaUI_Rules that reads combat, mount, group, rest, instance, zone, encounter, Mythic+ or spec is covered by the "
           "narrowed re-check or is not a rule's answer or drawing (%d places)" % len(lfound), not luncovered and len(lfound) >= 20,
           "; ".join(luncovered) or None)
    room = lua_room(os.path.join(ROOT, "XayaUI_Rules", "Engine.lua"))
    report("E. Lua 5.1: Engine.lua compiles with at least 10 of its main chunk's 200 local names free at its busiest point", room >= 10,
           "free: %d" % room if room >= 0 else "does not compile")
    print("%d checks, %d failed" % (total, bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
