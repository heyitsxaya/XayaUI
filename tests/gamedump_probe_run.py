# Test for XayaUI_GameDump 0.6.0 Probe.lua: /xuidump probe (event probe for the 12.1.5 readability questions), run against stand-in
# game functions in Lua 5.1. Nothing here is game data: unit names, GUIDs, creature / encounter IDs, secrecy levels and every return
# value are made up to drive the code paths. Spell IDs are the ones the request names, used as labels only.
#
# What it checks (outcomes: what ends up in XayaUIGameDumpDB.probe and in chat):
#   - secret values: issecretvalue says true for a sentinel userdata whose metatable RAISES on compare, arithmetic, concatenation,
#     tostring, indexing, calling and length, and type() of which reports the underlying type (as the game does; INFERENCE). Every secret must come out as the string "secret"; no misuse may happen (counted even
#     when a pcall swallows the error); no secret may be passed to a game function; none may be stored. (Lua 5.1 limit: `==` between
#     a userdata and a string or nil never calls a metamethod, so that one comparison cannot be trapped; the stored outcome is checked.)
#   - nothing is registered or recorded while off; every event registered is in the 12.1.5 documentation (the stand-in RegisterEvent
#     raises on an unknown event like the game); RegisterUnitEvent with at most 2 units; no OnUpdate; no global created.
#   - anchors, every item 1 to 11, the coordinator's extra signals (glow base / override, glow pairing about 0.1 s later, watched
#     spells' ShouldSpellAuraBeSecret + aura read), ring buffer cap / drops, `mark` only on command, failures counted once per kind,
#     status text, clear, off, resume after a reload, no player names or other players' GUIDs stored.
# Deliberate breaks: after the normal run, the probe source is broken on purpose in many ways (MUTATIONS below) and the same
# scenario is run again on each. Every break must make at least one check fail, and every check must fail under at least one break
# (otherwise that check could never fail). The last line carries FAILS: <n>.
# Run from the repo root: python3 tests/gamedump_probe_run.py   Needs: pip install lupa.
import os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GD_PATH = os.path.join(ROOT, "XayaUI_GameDump", "GameDump.lua").replace("\\", "/")
PROBE_PATH = os.path.join(ROOT, "XayaUI_GameDump", "Probe.lua")
EVENTS_MD = os.path.join(ROOT, "docs", "reference", "api", "events.md")
PROBE_SRC = open(PROBE_PATH, encoding="utf-8").read()
DOC_EVENTS = sorted(set(re.findall(r"^- `([A-Z0-9_]+)`", open(EVENTS_MD, encoding="utf-8").read(), re.M)))

SCENARIO = r'''
RESULTS, ORDER, FAILTXT, SECTION_ERRORS = {}, {}, {}, {}
function check(name, cond, extra)
  if RESULTS[name] ~= nil then error("duplicate check name: " .. name) end
  if cond then RESULTS[name] = true else RESULTS[name] = false; FAILTXT[name] = tostring(extra) end
  ORDER[#ORDER + 1] = name
end
function SECTION(name, f)
  local ok, err = pcall(f)
  if not ok then SECTION_ERRORS[#SECTION_ERRORS + 1] = name .. ": " .. tostring(err) end
end

-- secret sentinel: a userdata whose every operation raises (and is counted)
MISUSE, MISUSE_WHAT, SECRET_ARGS = 0, {}, 0
local TRAPS = {}
local function trap(what) return function() MISUSE = MISUSE + 1; if #MISUSE_WHAT < 5 then MISUSE_WHAT[#MISUSE_WHAT + 1] = what .. debug.traceback("", 2):sub(1, 300) end; error("secret value misused (" .. what .. ")", 2) end end
for _, k in ipairs({ "__index", "__newindex", "__call", "__concat", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm",
  "__lt", "__le", "__eq", "__len", "__tostring" }) do TRAPS[k] = trap(k) end
-- kind: what type() reports for it. INFERENCE (not in the API reference): in the game type() of a secret gives the underlying type
-- ("number", "string", "table"...), so a secret table passes a type(x) == "table" test; the stand-in does the same.
function SECRET(kind)
  local p = newproxy(true)
  local mt = getmetatable(p)
  for k, f in pairs(TRAPS) do mt[k] = f end
  mt.__secret = true
  mt.__kind = kind or "number"
  return p
end
local rawtype = type
issecretvalue = function(v)
  if rawtype(v) ~= "userdata" then return false end
  local mt = getmetatable(v)
  return rawtype(mt) == "table" and rawget(mt, "__secret") == true
end
type = function(v)
  if issecretvalue(v) then return rawget(getmetatable(v), "__kind") end
  return rawtype(v)
end
function ARG(v) if issecretvalue(v) then SECRET_ARGS = SECRET_ARGS + 1; error("secret argument not allowed (stand-in)", 2) end end

-- chat capture
said = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end
function SAID(pat) for i = #said, 1, -1 do if said[i]:find(pat, 1, true) then return said[i] end end end

-- frames: RegisterEvent raises on an event the 12.1.5 documentation does not list (as the game does)
FRAMES, ONUPDATE, LEAKED, LOADING = {}, {}, {}, "test"
local FM = {}
FM.__index = FM
function FM:RegisterEvent(e) if not DOC_EVENTS[e] then error('Attempt to register unknown event "' .. tostring(e) .. '"', 2) end; self.events[e] = true end
function FM:RegisterUnitEvent(e, u1, u2, u3)
  if u3 ~= nil then error("RegisterUnitEvent takes at most 2 units (stand-in)", 2) end
  if not DOC_EVENTS[e] then error('Attempt to register unknown event "' .. tostring(e) .. '"', 2) end
  self.events[e] = { [u1] = true, [u2 or u1] = true }
end
function FM:UnregisterEvent(e) self.events[e] = nil end
function FM:UnregisterAllEvents() self.events = {} end
function FM:SetScript(k, f) self.scripts[k] = f; if k == "OnUpdate" and f ~= nil then ONUPDATE[#ONUPDATE + 1] = self.born end end
function FM:GetScript(k) return self.scripts[k] end
for _, m in ipairs({ "Hide", "Show", "SetPoint", "SetSize", "SetAllPoints" }) do FM[m] = function() end end
CreateFrame = function() local f = setmetatable({ events = {}, scripts = {}, born = LOADING }, FM); FRAMES[#FRAMES + 1] = f; return f end
function PROBEFRAMES() local l = {} for _, f in ipairs(FRAMES) do if f.born == "Probe" then l[#l + 1] = f end end return l end
function FIRE(event, ...)
  local arg1 = ...
  for _, f in ipairs(FRAMES) do
    local reg = f.events[event]
    local hit = reg == true or (type(reg) == "table" and not issecretvalue(arg1) and arg1 ~= nil and reg[arg1])
    if hit and f.scripts.OnEvent then
      local ok, err = pcall(f.scripts.OnEvent, f, event, ...)
      if not ok then LEAKED[#LEAKED + 1] = event .. ": " .. tostring(err) end
    end
  end
end
-- call the probe's handler directly, as if an event reached it without registration
function DIRECT(event, ...)
  for _, f in ipairs(PROBEFRAMES()) do
    if f.scripts.OnEvent then
      local ok, err = pcall(f.scripts.OnEvent, f, event, ...)
      if not ok then LEAKED[#LEAKED + 1] = "direct " .. event .. ": " .. tostring(err) end
    end
  end
end

-- clock, timers
NOW = 1000.1234
GetTime = function() return NOW end
TIMERS = {}
C_Timer = { After = function(t, f) TIMERS[#TIMERS + 1] = { due = NOW + t, f = f } end }
function RUNTIMERS()   -- run due timers in order, the clock moving to each one's due time
  table.sort(TIMERS, function(a, b) return a.due < b.due end)
  while #TIMERS > 0 do local t = table.remove(TIMERS, 1); if t.due > NOW then NOW = t.due end; t.f() end
end
time = function() return 1793865600 end
GetServerTime = function() return 1793865601 end
date = function(fmt) if fmt == "%H:%M:%S" then return "09:00:00" end; if fmt == "%Y-%m-%d %H:%M" then return "2026-11-05 09:00" end; return "2026-11-05 09:00:00" end
INST = { "Voidscar Arena", "party", 8, 2999 }
GetInstanceInfo = function() return INST[1], INST[2], INST[3], "Mythic Keystone", 5, 0, false, INST[4], 5, nil, false end
GetBuildInfo = function() return "12.1.5", "70783", "Oct 31 2026", 120105 end
COMBAT = false
InCombatLockdown = function() return COMBAT end
IsInRaid = function() return false end

-- item 1
LOGGING, LOGGING_CALLED = true, 0
C_ChatInfo = { IsLoggingCombat = function() return LOGGING, false end }
LoggingCombat = function() LOGGING_CALLED = LOGGING_CALLED + 1 end

-- spells (made-up states)
NAMES = { [50842] = "Blood Boil", [1265968] = "Boiling Point", [85256] = "Templar's Verdict", [383328] = "Final Verdict", [1233398] = "Mad Shriek" }
CAST_SEC = { [1233398] = 1, [402772] = 0, [50842] = 0, [383328] = 2 }
AURA_SEC = { [1265968] = 2, [1306161] = 2 }
OVERLAYED = { [50842] = true, [383328] = true, [85256] = false }
BASE = { [383328] = 85256 }
OVERRIDE = { [85256] = 383328 }
PLAYER_AURAS = { [1265968] = "found" }
C_Secrets = {
  HasSecretRestrictions = function() return COMBAT end,
  ShouldAurasBeSecret = function() if COMBAT then return SECRET("boolean") end; return false end,
  ShouldCooldownsBeSecret = function() return COMBAT end,
  GetSpellCastSecrecy = function(id) ARG(id); if id == 85256 then return SECRET("number") end; return CAST_SEC[id] end,
  GetSpellAuraSecrecy = function(id) ARG(id); return AURA_SEC[id] or 0 end,
  ShouldUnitIdentityBeSecret = function(unit) ARG(unit); return COMBAT and unit ~= "player" end,
  ShouldSpellAuraBeSecret = function(id) ARG(id); return COMBAT and id == 1265968 end,
}
C_Spell = {
  GetSpellName = function(id) ARG(id); return NAMES[id] end,
  IsSpellUsable = function(id) ARG(id); if COMBAT then return SECRET("boolean"), SECRET("boolean") end; return true, false end,
  GetOverrideSpell = function(id) ARG(id); return OVERRIDE[id] or id end,
  GetBaseSpell = function(id) ARG(id); return BASE[id] or id end,
  GetSpellTexture = function(id) ARG(id); return 136001, 136000 end,
  GetSpellInfo = function(id) ARG(id); return { name = NAMES[id], castTime = COMBAT and SECRET("number") or 0, spellID = id } end,
  GetSpellPowerCost = function(id) ARG(id); if id == 50842 then return { { type = 6, cost = 0, hasRequiredAura = true, requiredAuraID = 1265968 } } end; return {} end,
  GetSpellCharges = function(id) ARG(id); if id == 50842 then return { maxCharges = 2, isActive = true, currentCharges = SECRET("number") } end end,
  GetSpellCooldown = function(id) ARG(id); return { isActive = false, isOnGCD = COMBAT and SECRET("boolean") or false, startTime = SECRET("number") } end,
}
C_SpellActivationOverlay = { IsSpellOverlayed = function(id) ARG(id); return OVERLAYED[id] == true end }
C_UnitAuras = { GetPlayerAuraBySpellID = function(id) ARG(id)
  local s = PLAYER_AURAS[id]
  if s == "secret" then return SECRET("table") elseif s == "error" then error("aura is secret (stand-in)") elseif s then return { spellId = id } end
end }
XayaUI_NS = { PROC_GLOW_AURAS = { [1265968] = { 50842 }, [1306161] = { 53385 }, [1310461] = { 53385, 85256, 383328 } } }

-- units (made up). nameplate4 is another player's nameplate.
UNITS = {
  player = { guid = "Player-1-0000AAAA", name = "Zerothia", player = true },
  party1 = { guid = "Player-1-0000BBBB", name = "Friendo", player = true },
  nameplate3 = { cid = 220001, guid = "Creature-0-1-2-3-220001-0000CCCC", name = "Void Shrieker", cls = "elite", rt = true, ac = false },
  nameplate4 = { guid = "Player-1-0000DDDD", name = "Strangerplay", player = true, ac = false },
  target = { cid = 220001, guid = "Creature-0-1-2-3-220001-0000CCCC", name = "Void Shrieker", cls = "elite", rt = true },
}
local function U(unit, k) local u = UNITS[unit]; return u and u[k] end
local function HIDDEN(unit) return COMBAT and not U(unit, "player") end
UnitExists = function(unit) ARG(unit); return UNITS[unit] ~= nil end
UnitIsPlayer = function(unit) ARG(unit); return U(unit, "player") == true end
UnitCreatureID = function(unit) ARG(unit); if HIDDEN(unit) then return SECRET("number") end; return U(unit, "cid") end
UnitGUID = function(unit) ARG(unit); if HIDDEN(unit) then return SECRET("string") end; return U(unit, "guid") end
UnitName = function(unit) ARG(unit); if HIDDEN(unit) then return SECRET("string"), nil end; return U(unit, "name"), nil end
UnitClassification = function(unit) ARG(unit); return U(unit, "cls") or "normal" end
UnitIsDead = function(unit) ARG(unit); return U(unit, "dead") == true end
CanBeRaidTarget = function(unit) ARG(unit); return U(unit, "rt") == true end
UnitAffectingCombat = function(unit) ARG(unit); return U(unit, "ac") == true end
C_EncounterTimeline = { GetEventState = function(id) ARG(id); return 0 end, GetEventTimeRemaining = function(id) ARG(id); return 12.34567 end }
MARKS = {}
SetRaidTarget = function(unit, idx) ARG(unit); MARKS[#MARKS + 1] = { unit, idx }; if COMBAT then error("blocked in combat (stand-in)") end end
GetRaidTargetIndex = function(unit) ARG(unit); return SECRET("number") end

-- XayaUI's rules (only the ID fields matter); talents use `id` and must not be read
CueRulesDB = { rules = { { spellID = 204021, buffID = 203819, buffAlt = { 1266619 }, talents = { { id = 555555, state = "known" } },
  extra = { list = { { type = "aura", spellID = 999001, alt = { 999002 } } } } } }, bars = { { buffID = 999003 } } }
SlashCmdList, UISpecialFrames, tinsert = {}, {}, table.insert

-- globals written by Probe.lua code (the probe must create none)
PROBE_GLOBALS = {}
setmetatable(_G, { __newindex = function(t, k, v)
  local info = debug.getinfo(2, "S")
  if info and info.source and info.source:find("Probe.lua", 1, true) then PROBE_GLOBALS[#PROBE_GLOBALS + 1] = tostring(k) end
  rawset(t, k, v)
end })

function DBP() return XayaUIGameDumpDB and XayaUIGameDumpDB.probe end
function LOG() local p, out = DBP(), {}; if not p then return out end; for i = p.first, p.last do if p.log[i] then out[#out + 1] = p.log[i] end end; return out end
function LAST(code, pred) local l = LOG(); for i = #l, 1, -1 do if l[i].e == code and (pred == nil or pred(l[i])) then return l[i] end end end
function NUM(code, pred) local n = 0; for _, e in ipairs(LOG()) do if e.e == code and (pred == nil or pred(e)) then n = n + 1 end end; return n end
function SLASH(s) SlashCmdList.XAYAUIDUMP(s) end
function NEAR(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.0015 end
function KEYS(t) local l = {} for k in pairs(t or {}) do l[#l + 1] = tostring(k) end; table.sort(l); return table.concat(l, ",") end
function HASEVENT(e) for _, f in ipairs(PROBEFRAMES()) do if f.events[e] then return f.events[e] end end end
function NEVENTS() local n = 0; for _, f in ipairs(PROBEFRAMES()) do for _ in pairs(f.events) do n = n + 1 end end; return n end

function LOAD()
  LOADING = "GameDump"; assert(loadfile(GD_PATH))("XayaUI_GameDump")
  LOADING = "Probe"; assert(loadstring(PROBE_SRC, "@Probe.lua"))("XayaUI_GameDump")
  LOADING = "test"
end

---------------------------------------------------------------------------------------------------------------------------------
SECTION("load", function()
  LOAD()
  FIRE("ADDON_LOADED", "XayaUI_GameDump")
  check("load: /xuidump probe is a command", type(XayaUIGameDump.Probe) == "function" and SlashCmdList.XAYAUIDUMP ~= nil)
  check("load: off, no probe frame listens to any event", NEVENTS() == 0, NEVENTS())
end)

SECTION("off", function()
  local function battery()
    FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 50842); FIRE("PLAYER_REGEN_DISABLED"); FIRE("UNIT_SPELLCAST_START", "nameplate3", "Cast-3-1", 1233398)
    FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-2", 50842); FIRE("NAME_PLATE_UNIT_ADDED", "nameplate3"); FIRE("UNIT_AURA", "player", { addedAuras = {} })
    FIRE("ENCOUNTER_START", 3001, "Boss", 8, 5); FIRE("ENCOUNTER_WARNING", { text = "x" }); FIRE("RAID_BOSS_EMOTE", "y"); FIRE("PLAYER_REGEN_ENABLED")
  end
  battery()
  DIRECT("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 50842); DIRECT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-2", 50842); DIRECT("PLAYER_REGEN_DISABLED")
  DIRECT("ENCOUNTER_START", 3001, "Boss", 8, 5); DIRECT("UNIT_AURA", "player", { addedAuras = {} })
  local p = DBP()
  check("off: nothing recorded (events fired, handlers called directly)", p == nil or (p.last == 0 and p.aLast == 0 and next(p.count) == nil), p and (p.last .. " entries " .. KEYS(p.count)))
  check("off: SetRaidTarget never called by an event", #MARKS == 0, #MARKS)
end)

local onT
SECTION("on", function()
  SLASH("probe on")
  onT = NOW
  local p = DBP()
  check("on: chat says ON", SAID("probe: ON.") ~= nil, said[#said])
  check("on: listens to glows, casts, plates, timeline, warnings; UNIT_AURA for player and target only",
    HASEVENT("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW") == true and HASEVENT("UNIT_SPELLCAST_START") == true and HASEVENT("NAME_PLATE_UNIT_ADDED") == true
    and HASEVENT("ENCOUNTER_TIMELINE_EVENT_ADDED") == true and HASEVENT("ENCOUNTER_WARNING") == true and type(HASEVENT("UNIT_AURA")) == "table"
    and HASEVENT("UNIT_AURA").player and HASEVENT("UNIT_AURA").target and not HASEVENT("UNIT_AURA").party1)
  check("on: every event registered is documented for 12.1.5 (none refused)", p and next(p.notRegistered) == nil, p and KEYS(p.notRegistered))
  local a = p and p.anchors[1] or {}
  check("anchor at on: GetTime (3 decimals), time(), GetServerTime(), date()", a.why == "on" and a.t == 1000.123 and a.time == 1793865600 and a.server == 1793865601 and a.date == "2026-11-05 09:00:00",
    tostring(a.why) .. " " .. tostring(a.t) .. " " .. tostring(a.date))
  check("anchor at on: GetInstanceInfo name, type, difficulty, instance ID", a.instance == "Voidscar Arena" and a.instanceType == "party" and a.difficultyID == 8 and a.instanceID == 2999)
  local c = a.ctx or {}
  check("context flags: restrictions, auras / cooldowns secret, combat logging", c.restr == false and c.aurasSecret == false and c.cdsSecret == false and c.logging == true and c.loggingAdv == false)
  check("context: LoggingCombat's type is recorded and it is never called", c.LoggingCombat == "function" and LOGGING_CALLED == 0, tostring(c.LoggingCombat) .. " called " .. LOGGING_CALLED)
  local first = p and p.log[1] or {}
  check("anchor entry in the log points to the anchor", first.e == "AN" and first.a == 1 and first.why == "on")
  local s = p and p.secrecy or {}
  check("secrecy list: built-in spells with label, game name, cast and aura levels",
    s[1233398] and s[1233398].label == "Mad Shriek" and s[1233398].name == "Mad Shriek" and s[1233398].cast == 1 and s[1233398].castLevel == "always"
    and s[1265968] and s[1265968].aura == 2 and s[1265968].auraLevel == "contextual" and s[402772] and s[402772].castLevel == "never")
  check("secrecy list: a secret level is stored as \"secret\"", s[85256] and s[85256].cast == "secret" and s[85256].castLevel == nil)
  check("secrecy list: XayaUI rule spells (spellID, buffID, buffAlt, trigger rows, bars), not talent IDs",
    s[204021] and s[203819] and s[1266619] and s[999001] and s[999002] and s[999003] and s[999003].src == "rules" and s[555555] == nil and p.ruleSpells == 6,
    tostring(p and p.ruleSpells))
  check("secrecy list: an SL entry in the log", NUM("SL") == 1)
  local aw = LAST("AW")
  check("watched spells: a baseline read at on", aw and aw.why == "on" and aw.w[1265968] and aw.w[1265968].a == "found" and aw.w[1265968].s == false and aw.w[50842].a == "none")
end)

SECTION("zones", function()
  NOW = NOW + 1
  FIRE("ZONE_CHANGED_NEW_AREA")
  FIRE("PLAYER_ENTERING_WORLD", false, true)
  local p = DBP()
  check("anchors on zone change and entering the world", p.anchors[2] and p.anchors[2].why == "zone" and p.anchors[3] and p.anchors[3].why == "enter" and p.anchors[3].reload == true)
end)

SECTION("glows out of combat", function()
  NOW = NOW + 1
  FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 50842)
  local g = LAST("GS")
  local sn = g and g.s or {}
  check("glow: spell ID and IsSpellOverlayed", g and g.id == 50842 and g.ovl == true and g.c == false)
  check("glow: spell snapshot (usable, required aura, charges, cooldown, cast time, icon)",
    sn.usable == true and sn.noPower == false and sn.costs and sn.costs[1] and sn.costs[1].hasAura == true and sn.costs[1].auraID == 1265968
    and sn.maxCharges == 2 and sn.chargeActive == true and sn.cdActive == false and sn.onGCD == false and sn.castTime == 0 and sn.icon == 136001 and sn.override == 50842)
  check("glow pairing: nothing read at the glow itself", NUM("GP") == 0)
  local gsT = g.t
  RUNTIMERS()
  NOW = NOW + 0.5
  FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 383328)
  local g2 = LAST("GS")
  check("glow: base spell differs -> its ID and IsSpellOverlayed are recorded too", g2 and g2.id == 383328 and g2.base == 85256 and g2.baseOvl == false and g2.overOvl == nil)
  RUNTIMERS()
  local gp1 = LAST("GP", function(e) return e.glow == 50842 end)
  local gp2 = LAST("GP", function(e) return e.glow == 383328 end)
  check("glow pairing: the paired aura is read about 0.1 s after the glow (found / none)",
    gp1 and gp1.aura == 1265968 and gp1.st == "found" and NEAR(gp1.t, gsT + 0.1) and gp1.shown == gsT and gp2 and gp2.aura == 1310461 and gp2.st == "none",
    gp1 and (tostring(gp1.t) .. " vs " .. tostring(gsT)))
  FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 50842)
  local gh = LAST("GH")
  check("glow hide: spell ID, IsSpellOverlayed and a snapshot", gh and gh.id == 50842 and gh.ovl == true and gh.s and gh.s.usable == true)
  FIRE("SPELL_ACTIVATION_OVERLAY_SHOW", 50842, 450913, 1, 1, 1, 1, 1)
  FIRE("SPELL_ACTIVATION_OVERLAY_HIDE", 50842)
  local os_, oh = LAST("OS"), LAST("OH")
  check("proc art: spell ID, file ID, location; hide", os_ and os_.id == 50842 and os_.file == 450913 and os_.loc == 1 and os_.s and oh and oh.id == 50842)
end)

SECTION("plates out of combat", function()
  NOW = NOW + 1
  FIRE("NAME_PLATE_UNIT_ADDED", "nameplate3")
  local na = LAST("NA", function(e) return e.u == "nameplate3" end)
  check("plate added out of combat: creature ID, GUID, name, identity flag, classification, dead, raid-target, combat",
    na and na.cid == 220001 and na.guid == "Creature-0-1-2-3-220001-0000CCCC" and na.name == "Void Shrieker" and na.idSecret == false
    and na.cls == "elite" and na.dead == false and na.rt == true and na.ac == false and na.pl == false)
  FIRE("NAME_PLATE_UNIT_ADDED", "nameplate4")
  local p4 = LAST("NA", function(e) return e.u == "nameplate4" end)
  check("another player's plate: name and GUID only as \"readable\"", p4 and p4.name == "readable" and p4.guid == "readable" and p4.pl == true)
  local before = DBP().last
  FIRE("UNIT_FLAGS", "nameplate3")
  check("UNIT_FLAGS without a combat change records nothing", DBP().last == before)
  FIRE("UNIT_FLAGS", "party1")
  check("UNIT_FLAGS on a non-nameplate unit records nothing", DBP().last == before)
end)

SECTION("combat start", function()
  NOW = NOW + 1
  COMBAT = true
  PLAYER_AURAS[1265968] = "secret"
  PLAYER_AURAS[1306161] = "error"
  FIRE("PLAYER_REGEN_DISABLED")
  local rd = LAST("RD")
  check("combat start: context flags, a secret answer stored as \"secret\"", rd and rd.c == true and rd.restr == true and rd.aurasSecret == "secret" and rd.cdsSecret == true and rd.LoggingCombat == "function")
  local aw = LAST("AW")
  check("watched spells at combat start: every spell, ShouldSpellAuraBeSecret + aura read",
    aw and aw.why == "combat start" and aw.w[1265968] and aw.w[1265968].s == true and aw.w[1265968].a == "secret" and aw.w[50842] and aw.w[50842].s == false and aw.w[50842].a == "none")
  check("watched spells: an aura read that raises is \"<error>\", its text kept", aw and aw.w[1306161] and aw.w[1306161].a == "<error>"
    and DBP().callErrors["C_UnitAuras.GetPlayerAuraBySpellID"] and tostring(DBP().callErrors["C_UnitAuras.GetPlayerAuraBySpellID"].first):find("stand-in", 1, true) ~= nil)
end)

SECTION("glows in combat", function()
  NOW = NOW + 1
  FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 50842)
  local g = LAST("GS")
  local sn = g and g.s or {}
  check("glow in combat: secret snapshot fields stored as \"secret\"", g and g.c == true and sn.usable == "secret" and sn.noPower == "secret" and sn.castTime == "secret" and sn.onGCD == "secret" and sn.maxCharges == 2)
  RUNTIMERS()
  local gp = LAST("GP")
  check("glow pairing in combat: a secret aura read is \"secret\"", gp and gp.glow == 50842 and gp.st == "secret" and gp.sab == true)
  FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", SECRET("number"))
  local gs = LAST("GS")
  check("glow with a secret spell ID: \"secret\", nothing asked with it", gs and gs.id == "secret" and gs.ovl == nil and gs.s == nil and gs.base == nil)
end)

SECTION("casts", function()
  NOW = NOW + 1
  FIRE("UNIT_SPELLCAST_START", "player", "Cast-3-P1", 50842, 1)
  FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-P1", 50842, 1)
  local pc = LAST("PC")
  check("your casts: UNIT_SPELLCAST_SUCCEEDED with the spell ID (START not kept)", pc and pc.id == 50842 and NUM("PC") == 1 and pc.u == nil)
  FIRE("UNIT_SPELLCAST_START", "nameplate3", "Cast-3-AAA", 1233398, 1)
  local cs = LAST("CS")
  check("enemy cast: readable spell ID, cast GUID, cast secrecy", cs and cs.u == "nameplate3" and cs.id == 1233398 and cs.g == "Cast-3-AAA" and cs.sec == 1)
  FIRE("UNIT_SPELLCAST_START", "nameplate3", SECRET("string"), SECRET("number"), 1)
  local cs2 = LAST("CS")
  check("enemy cast: secret spell ID and cast GUID stored as \"secret\", secrecy not asked", cs2 and cs2.id == "secret" and cs2.g == "secret" and cs2.sec == nil)
  FIRE("UNIT_SPELLCAST_SUCCEEDED", "boss1", "Cast-3-B", 402772, 1)
  FIRE("UNIT_SPELLCAST_CHANNEL_START", "target", "Cast-3-T", 383328, 1)
  FIRE("UNIT_SPELLCAST_STOP", "focus", "Cast-3-F", 1233398, 1)
  check("enemy casts: boss, target and focus units, each event kind", LAST("CC") and LAST("CC").u == "boss1" and LAST("CC").sec == 0 and LAST("CL") and LAST("CL").u == "target" and LAST("CT") and LAST("CT").u == "focus")
  local n = DBP().last
  FIRE("UNIT_SPELLCAST_START", "party1", "Cast-3-X", 1, 1)
  FIRE("UNIT_SPELLCAST_SUCCEEDED", "raid3", "Cast-3-Y", 1, 1)
  check("casts of party / raid units are not recorded", DBP().last == n)
  FIRE("UNIT_SPELLCAST_INTERRUPTED", "nameplate3", "Cast-3-I1", 1233398, "Player-1-0000AAAA", 1)
  FIRE("UNIT_SPELLCAST_INTERRUPTED", "nameplate3", "Cast-3-I2", 1233398, "Player-1-0000BBBB", 1)
  FIRE("UNIT_SPELLCAST_INTERRUPTED", "nameplate3", "Cast-3-I3", 1233398, "Creature-0-1-2-3-99-0000EEEE", 1)
  FIRE("UNIT_SPELLCAST_INTERRUPTED", "nameplate3", "Cast-3-I4", 1233398, SECRET("string"), 1)
  local ib = {}
  for _, e in ipairs(LOG()) do if e.e == "CI" then ib[#ib + 1] = tostring(e.ib) end end
  check("interrupts: interruptedBy as me / GUID kind / secret (no other player's GUID)", table.concat(ib, ",") == "me,Player,Creature,secret", table.concat(ib, ","))
  n = DBP().last
  FIRE("UNIT_SPELLCAST_START", SECRET("string"), "Cast-3-Z", 1, 1)
  check("a secret unit token is counted, nothing else recorded", DBP().last == n and DBP().count.castUnitSecret == 1)
end)

SECTION("plates in combat", function()
  NOW = NOW + 1
  UNITS.nameplate3.ac = true
  FIRE("UNIT_FLAGS", "nameplate3")
  local uf = LAST("UF")
  check("nameplate enters combat: UNIT_FLAGS entry, identity secret in combat", uf and uf.u == "nameplate3" and uf.was == false and uf.ac == true
    and uf.cid == "secret" and uf.guid == "secret" and uf.name == "secret" and uf.idSecret == true)
  FIRE("NAME_PLATE_UNIT_REMOVED", "nameplate3")
  local nr = LAST("NR")
  check("plate removed: entry with what the token still answers", nr and nr.u == "nameplate3" and nr.cid == "secret")
end)

SECTION("encounter and timeline", function()
  NOW = NOW + 1
  local nA = DBP().aLast
  FIRE("ENCOUNTER_START", 3001, "Made-up Boss", 8, 5)
  local es = LAST("ES")
  local a = DBP().anchors[DBP().aLast]
  check("encounter start: an anchor first, then the payload", DBP().aLast == nA + 1 and a.why == "encounter" and es and es.a == DBP().aLast and es.id == 3001 and es.name == "Made-up Boss" and es.diff == 8 and es.size == 5)
  FIRE("ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 11, source = 0, spellID = SECRET("number"), spellName = SECRET("string"), iconFileID = SECRET("number"), duration = 12.34567, severity = 1, isApproximate = SECRET("boolean"), maxQueueDuration = 0 })
  local ta = LAST("TA")
  check("timeline added: readable fields kept, secret ones \"secret\"", ta and ta.id == 11 and ta.source == 0 and ta.duration == 12.346 and ta.severity == 1
    and ta.spellID == "secret" and ta.spellName == "secret" and ta.iconFileID == "secret" and ta.isApproximate == "secret")
  FIRE("ENCOUNTER_TIMELINE_EVENT_ADDED", SECRET("table"))
  check("timeline added: a secret eventInfo is \"secret\"", LAST("TA").info == "secret")
  FIRE("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", 11)
  local ts = LAST("TS")
  check("timeline state: GetEventState and GetEventTimeRemaining for a readable ID", ts and ts.id == 11 and ts.st == 0 and ts.rem == 12.346)
  FIRE("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", SECRET("number"))
  local ts2 = LAST("TS")
  check("timeline state: a secret ID is \"secret\" and is not passed on", ts2 and ts2.id == "secret" and ts2.st == nil and ts2.rem == nil)
  FIRE("ENCOUNTER_TIMELINE_EVENT_REMOVED", 11)
  check("timeline removed: event ID", LAST("TR") and LAST("TR").id == 11)
  FIRE("ENCOUNTER_END", 3001, "Made-up Boss", 8, 5, 1, { { creatureID = 220001, creatureName = "Made-up Boss", remainingHealthPercent = 0 }, SECRET("table") })
  local ee = LAST("EE")
  check("encounter end: payload and unit status (secret element \"secret\")", ee and ee.success == 1 and ee.units and ee.units[1].cid == 220001 and ee.units[1].hp == 0 and ee.units[2] == "secret")
end)

SECTION("warnings", function()
  NOW = NOW + 1
  FIRE("ENCOUNTER_WARNING", { text = SECRET("string"), casterName = SECRET("string"), tooltipSpellID = SECRET("number"), duration = 5, severity = 2, isDeadly = SECRET("boolean") })
  local w = LAST("EW")
  check("warning: secret text, caster and spell ID are \"secret\"; duration and severity kept", w and w.text == "secret" and w.caster == "secret" and w.spellID == "secret" and w.dur == 5 and w.sev == 2)
  UNITS.party1.ac = nil
  FIRE("ENCOUNTER_WARNING", { text = "Void Shrieker fixates on Zerothia and Friendo! " .. string.rep("x", 300), casterName = "Void Shrieker", tooltipSpellID = 1233398, duration = 4.5, severity = 1 })
  local w2 = LAST("EW")
  check("warning: readable text kept to 200 characters, player names replaced", w2 and type(w2.text) == "string" and #w2.text == 200
    and w2.text:find("<me>", 1, true) and w2.text:find("<group>", 1, true) and not w2.text:find("Zerothia", 1, true) and not w2.text:find("Friendo", 1, true)
    and w2.caster == "Void Shrieker" and w2.spellID == 1233398, w2 and w2.text)
  FIRE("RAID_BOSS_EMOTE", string.rep("A", 300), "Boss", 5, true)
  check("boss emote: text kept to 200 characters", LAST("BE") and type(LAST("BE").text) == "string" and #LAST("BE").text == 200)
  FIRE("RAID_BOSS_EMOTE", SECRET("string"), "Boss", 5, true)
  check("boss emote: secret text is \"secret\"", LAST("BE").text == "secret")
end)

SECTION("auras", function()
  NOW = NOW + 1
  FIRE("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { { spellId = 1 }, { spellId = 2 } }, updatedAuraInstanceIDs = { 5 } })
  local au = LAST("AU")
  check("UNIT_AURA: readability and list lengths", au and au.u == "player" and au.full == false and au.add == 2 and au.upd == 1 and au.rem == nil and au.info == nil)
  local keys = {}
  for k in pairs(au or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  check("UNIT_AURA: no aura data is stored", table.concat(keys, ",") == "add,c,e,full,n,t,u,upd", table.concat(keys, ","))
  local n = DBP().last
  NOW = NOW + 0.5
  FIRE("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { { spellId = 3 } }, updatedAuraInstanceIDs = { 6, 7 } })
  NOW = NOW + 0.5
  FIRE("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { { spellId = 4 } }, updatedAuraInstanceIDs = { 8 } })
  check("UNIT_AURA: events within 2 s with the same readability merge (n, sums)", DBP().last == n and au.n == 3 and au.add == 4 and au.upd == 4 and NEAR(au.tl, NOW))
  FIRE("UNIT_AURA", "player", SECRET("table"))
  check("UNIT_AURA: a secret payload is \"secret\"", LAST("AU").info == "secret" and DBP().last == n + 1)
  FIRE("UNIT_AURA", "target", { isFullUpdate = true })
  check("UNIT_AURA for the target", LAST("AU").u == "target" and LAST("AU").full == true)
  local m = DBP().last
  FIRE("UNIT_AURA", "party1", { isFullUpdate = true })
  DIRECT("UNIT_AURA", "focus", { isFullUpdate = true })
  check("UNIT_AURA for other units is not recorded", DBP().last == m)
  local aw0 = NUM("AW")
  PLAYER_AURAS[1265968] = nil
  FIRE("UNIT_AURA", "player", { isFullUpdate = false, removedAuraInstanceIDs = { 9 } })
  local aw = LAST("AW")
  check("watched spells on UNIT_AURA: only the spell whose pair changed", NUM("AW") == aw0 + 1 and aw.why == "AU" and aw.w[1265968] and aw.w[1265968].a == "none" and aw.w[1265968].s == true and aw.w[50842] == nil)
  local wp = DBP().watchPairs
  check("watched spells: every read counted by pair", (wp["true/secret in combat"] or 0) >= 1 and (wp["true/none in combat"] or 0) >= 1 and (wp["false/none in combat"] or 0) >= 1 and (wp["false/found"] or 0) >= 1, KEYS(wp))
end)

SECTION("spell state", function()
  NOW = NOW + 3
  local n = DBP().last
  for i = 1, 5 do FIRE("SPELL_UPDATE_USABLE"); NOW = NOW + 0.2 end
  local us = LAST("US")
  check("SPELL_UPDATE_USABLE: merged within 2 s (n)", DBP().last == n + 1 and us.n == 5 and DBP().count.US == 5)
  NOW = NOW + 3
  FIRE("SPELL_UPDATE_USABLE")
  check("SPELL_UPDATE_USABLE: a new entry after the window", NUM("US") == 2)
  FIRE("SPELL_UPDATE_CHARGES"); FIRE("SPELL_UPDATE_CHARGES")
  check("SPELL_UPDATE_CHARGES: merged", NUM("CH") == 1 and LAST("CH").n == 2)
  FIRE("SPELL_UPDATE_ICON", 50842)
  check("SPELL_UPDATE_ICON: spell ID and a snapshot", LAST("IC") and LAST("IC").id == 50842 and LAST("IC").s ~= nil)
  local t0 = NOW
  FIRE("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", 85256, 383328)
  local ov = LAST("OV")
  check("override update: both IDs with GetTime and a snapshot of each", ov and ov.base == 85256 and ov.over == 383328 and NEAR(ov.t, t0) and ov.s and ov.so)
  FIRE("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", 85256, nil)
  check("override update: no override ID", LAST("OV").base == 85256 and LAST("OV").over == nil and LAST("OV").so == nil)
end)

SECTION("mark", function()
  check("mark: no event called SetRaidTarget", #MARKS == 0, #MARKS)
  SLASH("probe mark")
  local p = DBP()
  local m = p.marks[1] or {}
  check("mark in combat: SetRaidTarget(\"target\", 8) tried once, error text and combat recorded", #MARKS == 1 and MARKS[1][1] == "target" and MARKS[1][2] == 8
    and m.ok == false and tostring(m.err):find("blocked in combat", 1, true) ~= nil and m.c == true and m.before == "secret" and m.after == "secret")
  COMBAT = false
  SLASH("probe mark")
  local m2 = p.marks[2] or {}
  check("mark out of combat: success recorded, an MK log entry each time", #MARKS == 2 and m2.ok == true and m2.err == nil and m2.c == false and NUM("MK") == 2)
  COMBAT = true
end)

SECTION("combat end", function()
  NOW = NOW + 1
  COMBAT = false
  FIRE("PLAYER_REGEN_ENABLED")
  check("combat end: context flags", LAST("RE") and LAST("RE").c == false and LAST("RE").restr == false)
  check("watched spells at combat end", LAST("AW") and LAST("AW").why == "combat end" and LAST("AW").w[50842] ~= nil)
end)

SECTION("failures", function()
  local real = C_SpellActivationOverlay
  C_SpellActivationOverlay = setmetatable({}, { __index = function() error("stand-in failure") end })
  local nER = NUM("ER")
  FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 50842)
  FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 50842)
  C_SpellActivationOverlay = real
  local f = DBP().errors.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW
  check("a handler failure is counted every time and logged once per kind", f and f.n == 2 and tostring(f.first):find("stand-in failure", 1, true) ~= nil and NUM("ER") == nER + 1)
  check("no Lua error escaped a handler", #LEAKED == 0, LEAKED[1])
end)

SECTION("spells command", function()
  local n = DBP().last
  SLASH("probe spells 1233398 777777 abc -5")
  local p = DBP()
  check("spells: IDs added and checked at once; junk ignored", p.userSpells[777777] and p.userSpells[1233398] and p.userSpells[-5] == nil and p.secrecy[777777]
    and p.secrecy[777777].src:find("you", 1, true) and p.secrecy[1233398].src:find("list", 1, true) and SAID("checked 1233398") ~= nil)
  check("spells: one SL entry with the IDs", DBP().last == n + 1 and LAST("SL").why == "spells" and LAST("SL").ids[2] == 777777)
  COMBAT = true
  FIRE("PLAYER_REGEN_DISABLED")
  check("spells: added IDs are watched too", LAST("AW").w[777777] ~= nil)
  COMBAT = false
  FIRE("PLAYER_REGEN_ENABLED")
end)

SECTION("status", function()
  said = {}
  SLASH("probe status")
  local lines = XayaUIGameDump.ProbeState.StatusLines()
  local p = DBP()
  check("status: header with on, entries recorded, kept, dropped", lines[1]:find(("ON: %d entries recorded, %d kept, %d dropped"):format(p.last, p.last - p.first + 1, p.dropped), 1, true) ~= nil, lines[1])
  local ok = true
  for i = 1, 11 do if not (lines[i + 1] and lines[i + 1]:find("^" .. i .. " ")) then ok = false end end
  check("status: one line per item, 1 to 11", ok and #lines >= 12, #lines)
  check("status: counts match the log (casts, plates, glows)", lines[6]:find(("start %d, success %d"):format(p.count.CS, p.count.CC), 1, true) ~= nil
    and lines[7]:find(("plates added %d / removed %d, combat changes %d"):format(p.count.NA, p.count.NR, p.count.UF), 1, true) ~= nil
    and lines[3]:find(("glow show %d / hide %d"):format(p.count.GS, p.count.GH), 1, true) ~= nil, lines[6])
  check("status: readability split (enemy cast spell IDs readable / secret)", lines[6]:find("spell ID readable 8 (8 in combat), secret 1 (1 in combat)", 1, true) ~= nil, lines[6])
  check("status: printed to chat", SAID("probe: 5 enemy casts") ~= nil and SAID("probe: 11 secrecy list") ~= nil)
  SLASH("status")
  check("main /xuidump status names the probe", said[#said]:find("probe: ON, " .. p.last .. " entries", 1, true) ~= nil, said[#said])
end)

function WALKDB()
  local bad, names = 0, {}
  local function walk(t, d, seen)
    if d > 12 or seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
      if issecretvalue(k) or issecretvalue(v) then bad = bad + 1 end
      for _, x in ipairs({ k, v }) do
        if type(x) == "string" then
          for _, nm in ipairs({ "Zerothia", "Friendo", "Strangerplay", "0000AAAA", "0000BBBB", "0000DDDD" }) do if x:find(nm, 1, true) then names[#names + 1] = x end end
        end
      end
      if type(v) == "table" and not issecretvalue(v) then walk(v, d + 1, seen) end
    end
  end
  walk(XayaUIGameDumpDB, 0, {})
  return bad, names
end

SECTION("stored data before the ring test", function()
  local bad, names = WALKDB()
  check("no secret value is stored (full log)", bad == 0, bad)
  check("no player name or other player's GUID is stored (full log)", #names == 0, names[1])
end)

SECTION("ring buffer", function()
  local p = DBP()
  local before = p.last
  for i = 1, 6100 do NOW = NOW + 0.01; FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 100000 + i, 1) end
  local kept = p.last - p.first + 1
  check("ring buffer: keeps the newest 6000, drops the oldest, counts the drops", kept == 6000 and p.dropped == p.last - 6000 and p.log[p.first - 1] == nil
    and p.log[p.first] ~= nil and p.log[1] == nil and p.log[p.last].id == 106100 and p.log[p.first].id == 106100 - 5999, kept .. " kept, " .. p.dropped .. " dropped")
  check("ring buffer: anchors are kept apart and survive", p.anchors[1] and p.anchors[1].why == "on")
  local lines = XayaUIGameDump.ProbeState.StatusLines()
  check("status after drops: kept and dropped counts", lines[1]:find(("6000 kept, %d dropped"):format(p.dropped), 1, true) ~= nil, lines[1])
end)

SECTION("clear", function()
  SLASH("probe clear")
  local p = DBP()
  check("clear: log emptied, a clear anchor written (still on), added spell IDs kept", p.last == 1 and p.log[1].e == "AN" and p.anchors[1].why == "clear" and p.on == true and p.userSpells[777777] == true)
end)

SECTION("off again", function()
  SLASH("probe off")
  local p = DBP()
  check("off: an off anchor, every event unregistered", p.anchors[p.aLast].why == "off" and NEVENTS() == 0 and p.on == false and SAID("probe: OFF") ~= nil, NEVENTS())
  local n = p.last
  FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 50842); FIRE("UNIT_SPELLCAST_START", "nameplate3", "C", 1, 1); FIRE("ENCOUNTER_START", 1, "x", 1, 1)
  DIRECT("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 50842)
  check("off: nothing recorded afterwards", p.last == n)
end)

SECTION("resume", function()
  SLASH("probe on")
  FRAMES = {}                       -- a /reload: every frame is gone, the saved table stays
  LOAD()
  FIRE("ADDON_LOADED", "XayaUI_GameDump")
  local p = DBP()
  check("after a reload the probe resumes, writes a resume anchor and says so", p.on == true and p.anchors[p.aLast].why == "resume" and HASEVENT("UNIT_SPELLCAST_START") == true and SAID("resumed after a reload") ~= nil)
  SLASH("probe off")
end)

SECTION("hygiene", function()
  check("no secret value was misused (compare, arithmetic, join, tostring, index, length, call)", MISUSE == 0, MISUSE_WHAT[1])
  check("no secret value was passed to a game function", SECRET_ARGS == 0, SECRET_ARGS)
  local bad, names = WALKDB()
  check("no secret value is stored (end of run)", bad == 0, bad)
  local probeOnUpdate = 0
  for _, b in ipairs(ONUPDATE) do if b == "Probe" then probeOnUpdate = probeOnUpdate + 1 end end
  check("no OnUpdate script on a probe frame", probeOnUpdate == 0, probeOnUpdate)
  check("Probe.lua creates no global", #PROBE_GLOBALS == 0, table.concat(PROBE_GLOBALS, ","))
end)
'''


def run(src):
    lua = LuaRuntime()
    g = lua.globals()
    g.PROBE_SRC = src
    g.GD_PATH = GD_PATH
    t = lua.table()
    for e in DOC_EVENTS:
        t[e] = True
    g.DOC_EVENTS = t
    try:
        lua.execute(SCENARIO)
    except Exception as e:   # the scenario itself broke (a deliberate break can do that)
        return None, [], ["scenario: %s" % e], {}
    order = [lua.eval("ORDER")[i] for i in range(1, int(lua.eval("#ORDER")) + 1)]
    res = {n: bool(lua.eval("RESULTS")[n]) for n in order}
    errs = [lua.eval("SECTION_ERRORS")[i] for i in range(1, int(lua.eval("#SECTION_ERRORS")) + 1)]
    txt = {n: lua.eval("FAILTXT")[n] for n in order if not res[n]}
    return res, order, errs, txt


# Deliberate breaks: (name, [(exact text in Probe.lua, replacement), ...])
MUTATIONS = [
    ("issecretvalue ignored", [("    return s == true\nend", "    return false\nend")]),
    ("ring never drops", [("    while D.last - D.first + 1 > CAP do", "    while false do")]),
    ("drops not counted", [("        D.dropped = D.dropped + 1", "        D.dropped = D.dropped")]),
    ("time not rounded to 3 decimals", [('CUR.t = Round3(R1("GetTime", GetTime))', 'CUR.t = R1("GetTime", GetTime)')]),
    ("anchor without wall clock", [('    a.date = R1("date", date, "%Y-%m-%d %H:%M:%S")', '    a.date = nil')]),
    ("anchor without instance ID", [("    a.instanceID = Res(st, r, 8)", "    a.instanceID = Res(st, r, 7)")]),
    ("no anchor at ENCOUNTER_START", [('    local a = Anchor("encounter")', '    local a = nil')]),
    ("no anchor on zone change", [('H.ZONE_CHANGED_NEW_AREA = function() Begin(); Anchor("zone") end', 'H.ZONE_CHANGED_NEW_AREA = function() end')]),
    ("mark on encounter start", [('    Count("ES")', '    Count("ES"); P.Mark()')]),
    ("handlers record while off", [("    if not P.on then return end\n    local h = H[event]", "    local h = H[event]")]),
    ("off keeps events registered", [("    Unregister()\n    P.on, D.on = false, false", "    P.on, D.on = false, false")]),
    ("status loses an item line", [('    L[#L + 1] = ("6 mobs:', '    local _ = ("6 mobs:')]),
    ("status header miscounts drops", [('P.on and "ON" or "off", D.last, D.last - D.first + 1, D.dropped, CAP', 'P.on and "ON" or "off", D.last, D.last - D.first + 1, 0, CAP')]),
    ("status readability split wrong", [('g("ro") + g("rc"), g("rc"), g("so") + g("sc"), g("sc")', 'g("ro"), g("rc"), g("so"), g("sc")')]),
    ("status not printed", [("    for _, l in ipairs(P.StatusLines()) do Say(l) end", "    P.StatusLines()")]),
    ("LoggingCombat called", [("    t.LoggingCombat = type(_G.LoggingCombat)", "    t.LoggingCombat = type(_G.LoggingCombat); pcall(_G.LoggingCombat)")]),
    ("context flag read raw", [('    t.aurasSecret = R1("C_Secrets.ShouldAurasBeSecret", NS("C_Secrets", "ShouldAurasBeSecret"))', "    t.aurasSecret = C_Secrets.ShouldAurasBeSecret()")]),
    ("combat-log flag not read", [("    t.logging, t.loggingAdv = Res(st, r, 1), Res(st, r, 2)", "    t.logging, t.loggingAdv = nil, nil")]),
    ("glow: IsSpellOverlayed not recorded", [('        Put(e, "ovl", Overlayed(id), "glow.overlayed")', "")]),
    ("glow: base spell not checked", [("        if type(base) == \"number\" and base ~= id then", "        if false then")]),
    ("glow: asked with a secret ID", [('    if type(id) == "number" then\n        Put(e, "ovl", Overlayed(id), "glow.overlayed")', '    if id ~= nil then\n        Put(e, "ovl", Overlayed(spellID), "glow.overlayed")')]),
    ("glow: no snapshot", [("        e.s = Snap(id)\n        if code == \"GS\" then", "        if code == \"GS\" then")]),
    ("glow pairing read at once", [("    after(PAIR_DELAY, function()", "    (function(_, f) f() end)(PAIR_DELAY, function()")]),
    ("glow pairing ignores core table", [("    local map = type(ns) == \"table\" and ns.PROC_GLOW_AURAS or nil", "    local map = nil")]),
    ("glow pairing: aura state wrong", [('    if a == nil then return "none" end\n    return "found"', '    return "found"')]),
    ("snapshot: required aura not read", [('Put(x, "hasAura", F(c, "hasRequiredAura"), "snap.hasRequiredAura")', 'Put(x, "hasAura", nil, "snap.hasRequiredAura")')]),
    ("snapshot: secret stored raw", [('    Put(s, "usable", Res(st, r, 1), "snap.usable")', '    Put(s, "usable", (st == "ok" and r[2]) or st, "snap.usable")')]),
    ("snapshot: charges not read", [('    Put(s, "maxCharges", ResF(st, r, "maxCharges"), "snap.maxCharges")', '    Put(s, "maxCharges", nil, "snap.maxCharges")')]),
    ("proc art: file ID dropped", [('    Put(e, "file", V(overlayFileDataID), "overlay.fileDataID")', "")]),
    ("player casts: START kept too", [('        if event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end', "")]),
    ("player casts not recorded", [('        local e = Entry("PC")', '        do return end; local e = Entry("PC")')]),
    ("enemy casts: party units kept", [("    if not (ENEMY[unit] or IsPlate(unit)) then return end", "")]),
    ("enemy casts: cast GUID dropped", [('    Put(e, "g", V(castGUID, 80), "cast.guid")', "")]),
    ("enemy casts: secrecy asked with a secret ID", [('    if type(id) == "number" then Put(e, "sec", R1("C_Secrets.GetSpellCastSecrecy", NS("C_Secrets", "GetSpellCastSecrecy"), id), "cast.secrecy") end',
                                                     '    if id ~= nil then Put(e, "sec", R1("C_Secrets.GetSpellCastSecrecy", NS("C_Secrets", "GetSpellCastSecrecy"), spellID), "cast.secrecy") end')]),
    ("interrupts: full GUID stored", [('    return v:match("^(%a+)%-") or "readable"', "    return v")]),
    ("secret unit token not counted", [('    if IsSecret(unit) then D = Data(); Count("castUnitSecret"); return end', "    if IsSecret(unit) then return end")]),
    ("mobs: other players' names stored", [("    if pl ~= false then", "    if false then")]),
    ("mobs: identity read raw", [('    local guid = R1("UnitGUID", UnitGUID, unit)', "    local guid = UnitGUID(unit)")]),
    ("mobs: UNIT_FLAGS records without a change", [("    if ac == mobCombat[unit] then return end", "")]),
    ("mobs: UNIT_FLAGS for any unit", [('    if IsSecret(unit) or type(unit) ~= "string" or not IsPlate(unit) then return end', '    if IsSecret(unit) or type(unit) ~= "string" then return end')]),
    ("mobs: classification dropped", [('    Put(e, "cls", R1("UnitClassification", UnitClassification, unit), "mob.classification")', "")]),
    ("timeline: secret eventInfo not marked", [('    if IsSecret(info) then\n        Put(e, "info", SECRET, "timeline.info")', '    if false then\n        Put(e, "info", SECRET, "timeline.info")')]),
    ("timeline: duration not rounded", [('            if k == "duration" then v = Round3(v) end', "")]),
    ("timeline: state asked with a secret ID", [('    if type(id) == "number" then\n        Put(e, "st"', '    if id ~= nil then\n        Put(e, "st"')]),
    ("timeline: removed ID dropped", [('    Put(e, "id", V(eventID), "timeline.eventID")\n    Count("TR")', '    Count("TR")')]),
    ("encounter end: unit status dropped", [('Put(x, "cid", F(u, "creatureID"), "encounter.unit.creatureID")', 'Put(x, "cid", nil, "encounter.unit.creatureID")')]),
    ("encounter start: payload dropped", [("    e.a = a\n    Encounter(e, ...)", "    e.a = a")]),
    ("warnings: names not replaced", [("    for _, p in ipairs(names) do v = v:gsub(Esc(p[1]), p[2]) end", "")]),
    ("emotes: text not cut to 200", [("    if #v > maxLen then v = v:sub(1, maxLen) end\n    if partial", "    if partial")]),
    ("emotes: raw text passed on", [('    Put(e, "text", Scrub(V(text, 400), 200, e), "emote.text")', '    Put(e, "text", Scrub(text, 200, e), "emote.text")')]),
    ("warnings: severity dropped", [('        Put(e, "sev", F(info, "severity"), "warning.severity")', "")]),
    ("auras: counts wrong", [('        Put(e, "add", Len(info, "addedAuras"), "aura.added")', '        Put(e, "add", 0, "aura.added")')]),
    ("auras: not merged", [('    PushMerged("AU:" .. unit .. ":" .. K(e.info) .. K(e.full) .. K(e.add) .. K(e.upd) .. K(e.rem) .. K(e.c), e, { "add", "upd", "rem" })', "    Push(e)")]),
    ("auras: aura data stored", [('    Count("AU")', '    e.raw = info; Count("AU")')]),
    ("auras: other units recorded", [('    if IsSecret(unit) or (unit ~= "player" and unit ~= "target") then return end', "    if IsSecret(unit) then return end")]),
    ("auras: secret payload not marked", [('    if IsSecret(info) then\n        Put(e, "info", SECRET, "aura.info")', '    if false then\n        Put(e, "info", SECRET, "aura.info")')]),
    ("watch: ShouldSpellAuraBeSecret dropped", [("            w[id] = { s = sab, a = a }", "            w[id] = { a = a }")]),
    ("watch: every UNIT_AURA writes every spell", [('        if why ~= "AU" or not last or last.s ~= sab or last.a ~= a then', "        if true then")]),
    ("watch: not at combat start", [("    Push(e)\n    Watch(why)\nend", "    Push(e)\nend")]),
    ("watch: pairs not counted", [("        D.watchPairs[pairKey] = (D.watchPairs[pairKey] or 0) + 1", "")]),
    ("watch: user spells not watched", [("    for _, id in ipairs(extra) do if #ids < WATCH_CAP then ids[#ids + 1] = id end end", "")]),
    ("usable: not merged", [('PushMerged("US", Entry("US"))', 'Push(Entry("US"))')]),
    ("merge window never closes", [("e.t - m.e.t <= MERGE_WINDOW then", "true then")]),
    ("charges: not recorded", [('H.SPELL_UPDATE_CHARGES = function() Begin(); Count("CH"); PushMerged("CH", Entry("CH")) end', "H.SPELL_UPDATE_CHARGES = function() end")]),
    ("icon: no snapshot", [('    if fresh and type(id) == "number" then e.s = Snap(id) end', "")]),
    ("override: override ID dropped", [('    Put(e, "over", o, "override.override")', '    Put(e, "over", nil, "override.override")')]),
    ("rule IDs not read", [("    if type(db.rules) == \"table\" then Walk(db.rules, set, 1) end", "")]),
    ("rule walk reads talent IDs", [("local ID_KEYS, LIST_KEYS = { spellID = true, buffID = true }", "local ID_KEYS, LIST_KEYS = { spellID = true, buffID = true, id = true }")]),
    ("secrecy level read raw", [('    local cast = R1("C_Secrets.GetSpellCastSecrecy", NS("C_Secrets", "GetSpellCastSecrecy"), id)', "    local cast = C_Secrets.GetSpellCastSecrecy(id)")]),
    ("secrecy label dropped", [("    if label then s.label = label end", "")]),
    ("on: list not checked", [('    CheckList(resumed and "resume" or "on")', "")]),
    ("on: no baseline watch", [('    Watch("on")', "")]),
    ("spells: not checked at once", [("        CheckSecrecy(id, \"you\")\n        local s = D.secrecy[id]", "        local s = D.secrecy[id] or {}")]),
    ("spells: negative IDs accepted", [("        if n and n > 0 and n < 2147483648 and n == math.floor(n) then D.userSpells[n] = true", "        if n then D.userSpells[n] = true")]),
    ("handler failure escapes", [("    local ok, err = pcall(h, event, ...)\n    if not ok then pcall(Fail, event, err) end", "    h(event, ...)")]),
    ("failure logged every time", [("        Push({ t = CUR.t, e = \"ER\", k = kind, msg = f.first })\n    end\n    f.n = f.n + 1", "    end\n    Push({ t = CUR.t, e = \"ER\", k = kind, msg = f.first })\n    f.n = f.n + 1")]),
    ("failures not counted", [("    f.n = f.n + 1\nend", "end")]),
    ("call error text not kept", [("    if not c then c = { n = 0, first = V(err, 200) }; D.callErrors[name] = c end", "    if not c then c = { n = 0 }; D.callErrors[name] = c end")]),
    ("mark: error text dropped", [("        if not ok then m.err = V(err, 200) end", "")]),
    ("mark: combat not recorded", [('    local m = { t = CUR.t, c = CUR.c, date', '    local m = { t = CUR.t, c = nil, date')]),
    ("mark: no log entry", [('        local e = Entry("MK")', '        do return end; local e = Entry("MK")')]),
    ("resume does not happen", [("        if d.on == true then P.On(true) end", "        if false then P.On(true) end")]),
    ("clear keeps the log", [("    GD.DB().probe = nil", "    local _ = nil")]),
    ("clear drops added spells", [("    D.on, D.userSpells = old.on, old.userSpells or {}", "    D.on = old.on")]),
    ("OnUpdate added", [('local frame = CreateFrame("Frame")       -- every event above (plain RegisterEvent)\nframe:SetScript("OnEvent", OnEvent)',
                         'local frame = CreateFrame("Frame")\nframe:SetScript("OnEvent", OnEvent)\nframe:SetScript("OnUpdate", function() end)')]),
    ("global leak", [("local CUR = {}                 -- t, c of the event being handled", "CUR = {}")]),
    ("undocumented event registered", [('"RAID_BOSS_EMOTE", "ADDON_ACTION_BLOCKED"', '"RAID_BOSS_EMOTE", "UNIT_SPELLCAST_MADEUP", "ADDON_ACTION_BLOCKED"')]),
    ("RegisterUnitEvent with 3 units", [('"UNIT_AURA", "player", "target")', '"UNIT_AURA", "player", "target", "focus")')]),
    ("main status without the probe", [("    return P.on, type(p) == \"table\" and p.last or 0", "    return false, 0")]),
    ("on: chat line missing", [('        Say("ON. Play normally;', '        Say("Started. Play normally;')]),
    ("unit token kept off cast entries", [("    local e = Entry(code, unit)\n    local id = V(spellID)", "    local e = Entry(code)\n    local id = V(spellID)")]),
    ("regen: no context", [("    local e = Entry(code)\n    Context(e)", "    local e = Entry(code)")]),
    ("plate removed not recorded", [('H.NAME_PLATE_UNIT_REMOVED = function(_, unit) Plate("NR", unit) end', "H.NAME_PLATE_UNIT_REMOVED = function() end")]),
    ("/xuidump probe not wired", [("function GD.Probe(arg)", "function GD.ProbeX(arg)")]),
    ("events registered at load", [('auraFrame:SetScript("OnEvent", OnEvent)\n', 'auraFrame:SetScript("OnEvent", OnEvent)\nframe:RegisterEvent("PLAYER_REGEN_DISABLED")\n')]),
    ("mark at load", [('    self:UnregisterEvent("ADDON_LOADED")\n', '    self:UnregisterEvent("ADDON_LOADED")\n    P.Mark()\n')]),
    ("UNIT_AURA registered for every unit", [("    if auraFrame.RegisterUnitEvent then", "    if false then")]),
    ("timeline: state not read", [('        Put(e, "st", R1("C_EncounterTimeline.GetEventState", NS("C_EncounterTimeline", "GetEventState"), id), "timeline.state")', '        Put(e, "st", nil, "timeline.state")')]),
    ("auras: target ignored", [('(unit ~= "player" and unit ~= "target")', '(unit ~= "player")')]),
    ("override: base snapshot reused as the override's", [("    if type(o) == \"number\" and o ~= b then e.so = Snap(o) end", "    e.so = Snap(o or b)")]),
    ("spells: IDs left off the log entry", [('        e.why, e.ids = "spells", added', '        e.why = "spells"')]),
    ("status header miscounts entries", [('P.on and "ON" or "off", D.last, D.last - D.first + 1, D.dropped, CAP', 'P.on and "ON" or "off", D.last + 1, D.last - D.first + 1, D.dropped, CAP')]),
    ("enter-world anchor without its flags", [('    Anchor("enter", { login = V(isInitialLogin), reload = V(isReloadingUi) })', '    Anchor("enter")')]),
]


def main():
    started = time.time()
    fails = 0
    res, order, errs, txt = run(PROBE_SRC)
    if res is None:
        print("FAIL: the scenario did not run: %s" % errs)
        print("0 checks  FAILS: 1")
        return 1
    for n in order:
        print(("ok:   " if res[n] else "FAIL: ") + n + ("" if res[n] else "  -> " + str(txt.get(n))))
        fails += 0 if res[n] else 1
    for e in errs:
        print("FAIL: test section error: " + e)
        fails += 1
    # deliberate breaks
    caught_by = {n: [] for n in order}
    for name, edits in MUTATIONS:
        src = PROBE_SRC
        bad_edit = None
        for old, new in edits:
            if src.count(old) != 1:
                bad_edit = old
                break
            src = src.replace(old, new)
        if bad_edit is not None:
            print("FAIL: break '%s' does not apply (text found %d times): %r" % (name, PROBE_SRC.count(bad_edit), bad_edit[:60]))
            fails += 1
            continue
        mres, morder, merrs, _ = run(src)
        if mres is None:
            print("ok:   break '%s' is caught (the scenario cannot run)" % name)
            continue
        failed = [n for n in morder if not mres[n]]
        for n in failed:
            if n in caught_by:
                caught_by[n].append(name)
        if failed or merrs:
            print("ok:   break '%s' is caught by %d check(s), e.g. \"%s\"" % (name, len(failed), failed[0] if failed else merrs[0]))
        else:
            print("FAIL: break '%s' is NOT caught by any check" % name)
            fails += 1
    never = [n for n in order if not caught_by[n]]
    if never:
        for n in never:
            print("FAIL: no deliberate break makes this check fail: " + n)
        fails += len(never)
    else:
        print("ok:   every one of the %d checks fails under at least one deliberate break" % len(order))
    print("%d checks, %d deliberate breaks, %.1f s  FAILS: %d" % (len(order), len(MUTATIONS), time.time() - started, fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
