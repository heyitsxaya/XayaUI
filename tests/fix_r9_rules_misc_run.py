"""Round 9, rules-misc unit (REQUEST-LOG A23 SD-82, RB-30 leftover, V34 audit of the 'rules' service).
Run: python3 tests/fix_r9_rules_misc_run.py   (needs: pip install lupa)

A. SD-82, her answer "FAIL everywhere (Recommended)": no XayaUI call site may hand C_Timer a NEW function made from the same
   definition on a later call. The two known sites were XayaUI_Rules/ClassLearn.lua (the 3 s learn debounce) and
   XayaUI_Rules/AuraSound.lua (A.Queue, the 0.5 s sync debounce). The guard here is the gate's own P4 rule (tests/gate_common.py
   addTimer: a function whose definition, source:linedefined, was passed before from this site, but which is a different object, is
   a "new function"); it is applied to every function the two files hand to C_Timer.After over several debounce rounds.
   What the player gets is unchanged: one learn 3 s after a burst of spec / talent events, one aura-sound sync 0.5 s after a change.
B. RB-30 leftover: AuraSound's PLAYER_SPECIALIZATION_CHANGED (events.md 1215: unitTarget: UnitTokenVariant; no secret flag) also
   fires for other units. Another unit's spec change must not re-plan the game's aura sounds; the player's own still does.
C. V34 audit of RuleDefaults.lua's 'rules' service: BuildSpellList, BuildTalentList and ForgetSpellLists are read by the Stat
   Calculator (XayaUI_Bonus_StatCalculator/StatModel.lua) and stay; BarColorizeTypes has no reader on main (its reader was the Bonus
   Features tooltips retired to QA, SD-2) and is gone.
The repository root can be given as XUI_R9_ROOT (to run these checks on a copy of older files)."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); import xui_paths as XP
from lupa.lua51 import LuaRuntime
ROOT = os.environ.get("XUI_R9_ROOT") or os.path.join(HERE, "..")

fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)

# the gate's P4 guard (tests/gate_common.py addTimer / defOf), as a Lua helper both runtimes use
GUARD = r'''
GUARD = { protos = {}, fresh = 0, calls = 0 }
function GUARD.see(site, fn)
  local info = debug.getinfo(fn, "S")
  local def = site .. "|" .. tostring(info.source) .. ":" .. tostring(info.linedefined)
  GUARD.calls = GUARD.calls + 1
  local first = GUARD.protos[def]
  if first == nil then GUARD.protos[def] = fn elseif first ~= fn then GUARD.fresh = GUARD.fresh + 1 end
end
'''

# ---------------------------------------------------------------------------------------------------------------------------------
# A1. ClassLearn.lua
# ---------------------------------------------------------------------------------------------------------------------------------
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(GUARD)
L.execute(r'''
HANDLER, TIMERS, LEARNS = nil, {}, 0
CreateFrame = function() local f = {}; f.RegisterEvent = function() end; f.SetScript = function(self, _, fn) HANDLER = fn end; return f end
C_Timer = { After = function(d, fn) GUARD.see("ClassLearn", fn); TIMERS[#TIMERS + 1] = { d = d, fn = fn } end }
function RUN_TIMERS() local t = TIMERS; TIMERS = {}; for _, x in ipairs(t) do x.fn() end end
GetBuildInfo = function() return "12.0.1", "12345", "Jan 1 2026", 120001 end
InCombatLockdown = function() return false end
UnitClass = function() return "Test Class", "TESTCLASS" end
GetSpecializationInfoByID = function(id) return id, "Test Spec" end
date = os.date
C_Spell = { GetSpellCharges = function() end }
CueRulesDB = {}
local ns = { settingsTestHooks = { keepOld = true } }
_G.XayaUI_NS = ns
NS = ns
ns.CurrentSpecID = function() return 999 end
ns.CollectCooldownSpells = function() LEARNS = LEARNS + 1; return { { id = 1, name = "Alpha" } } end
''')
L.execute('assert(loadfile("%s"))("XayaUI", NS)' % os.path.join(ROOT, "XayaUI/Modules.lua").replace("\\", "/"))
L.execute('assert(loadfile("%s"))("XayaUI", NS)' % os.path.join(ROOT, "XayaUI_Rules/ClassLearn.lua").replace("\\", "/"))
L.execute(r'''
CL_ROUNDS = {}
for round = 1, 4 do
  HANDLER(nil, "TRAIT_CONFIG_UPDATED"); HANDLER(nil, "TRAIT_CONFIG_UPDATED"); HANDLER(nil, "PLAYER_SPECIALIZATION_CHANGED", "player")
  local armed, delay = #TIMERS, TIMERS[1] and TIMERS[1].d
  local before = LEARNS
  RUN_TIMERS()
  CL_ROUNDS[round] = { armed = armed, delay = delay, learned = LEARNS - before }
end
HANDLER(nil, "PLAYER_SPECIALIZATION_CHANGED", "party1")
CL_OTHER = #TIMERS
''')
r = L.eval("CL_ROUNDS")
check("ClassLearn: each burst of spec / talent events arms one 3 s timer (debounce kept)",
      all(r[i].armed == 1 and r[i].delay == 3 for i in range(1, 5)), [(r[i].armed, r[i].delay) for i in range(1, 5)])
check("ClassLearn: each timer learns the spec once (what the player gets is unchanged)",
      all(r[i].learned == 1 for i in range(1, 5)) and L.eval("NS.CLASS_AURA_DATA[999] ~= nil") is True,
      [r[i].learned for i in range(1, 5)])
check("ClassLearn: another unit's spec change arms nothing", L.eval("CL_OTHER") == 0, L.eval("CL_OTHER"))
check("ClassLearn (SD-82 guard): 4 timer calls, 0 new functions made per call",
      L.eval("GUARD.calls") == 4 and L.eval("GUARD.fresh") == 0, "calls %s, new functions %s" % (L.eval("GUARD.calls"), L.eval("GUARD.fresh")))

# ---------------------------------------------------------------------------------------------------------------------------------
# A2 + B. AuraSound.lua, loaded with the rest of XayaUI and XayaUI Rules on the engine bench (as tests/fix_u4_aurasound_load_run.py)
# ---------------------------------------------------------------------------------------------------------------------------------
bench = open(os.path.join(HERE, "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(GUARD)
L.execute(r'''
EVENTS = {}   -- [event] = { {frame, units or nil}, ... }: the game's registrations, a unit registration only gets its units
local M = FRAME_METHODS
function M:RegisterEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], { self }) end
function M:RegisterUnitEvent(e, ...) EVENTS[e] = EVENTS[e] or {}; local u = {}; for _, x in ipairs({ ... }) do u[x] = true end; table.insert(EVENTS[e], { self, u }) end
function M:UnregisterAllEvents() for _, l in pairs(EVENTS) do for i = #l, 1, -1 do if l[i][1] == self then table.remove(l, i) end end end end
function FIRE(e, unit)   -- what the game does: a frame registered for units hears only those units
  for _, reg in ipairs(EVENTS[e] or {}) do
    local f, u = reg[1], reg[2]
    if not u or u[unit] then local s = f["_s_OnEvent"]; if s then s(f, e, unit) end end
  end
end
function HANDLERS(e) local out = {}; for _, reg in ipairs(EVENTS[e] or {}) do out[#out + 1] = reg[1] end; return out end
TIMERS = {}
SITE_TIMERS = {}
C_Timer.After = function(d, fn)
  local info = debug.getinfo(2, "S")
  local site = tostring(info and info.source or "?")
  if site:find("AuraSound.lua", 1, true) then GUARD.see("AuraSound", fn); SITE_TIMERS[#SITE_TIMERS + 1] = d end
  TIMERS[#TIMERS + 1] = fn
end
function RUN_TIMERS() local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do fn() end end
function ASTIMERS() return #SITE_TIMERS end
hooksecurefunc = function(t, k, fn) if type(t) == "string" then return end; local old = t[k]; t[k] = function(...) local r = { old(...) }; fn(...); return unpack(r) end end
COMBAT = false
InCombatLockdown = function() return COMBAT end
UnitAffectingCombat = function() return COMBAT end
issecretvalue = function() return false end
Enum = Enum or {}
Enum.UnitAuraSoundTrigger = { Added = 0, ApplicationsIncreased = 1, Removed = 2 }
C_Map = { GetBestMapForUnit = function() return 2339 end }
HELD, NEXT = {}, 100
C_UnitAuras.AddAuraSound = function(trigger, info) NEXT = NEXT + 1; HELD[NEXT] = info.spellID; return NEXT end
C_UnitAuras.RemoveAuraSound = function(id) HELD[id] = nil end
function HOLDS(spell) for _, s in pairs(HELD) do if s == spell then return true end end return false end
''')
toc = XP.core_toc_lines(ROOT)
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{ settingsTestHooks = { keepOld = true } }"); L.globals().NS = ns
skip = ("Libs", "Console.lua", "GameMenu", "MinimapButton", "AuraSources", "Combat/")
failed = []
for f in toc:
    f = f.replace("\\", "/")
    if f.startswith(skip) or not f.endswith(".lua"):
        continue
    try:
        load(open(XP.core_file(ROOT, f), encoding="utf-8").read(), f, ns)
    except Exception as e:
        failed.append((f, str(e)[:200]))
check("every XayaUI and XayaUI Rules file loads", not failed, failed)

L.execute(r'''
NS.rules = CueRulesDB.rules
NS.Print = function() end
NS.Log = function() end
SPEC = 581   -- the bench's Vengeance; the rule below is for this spec only
GetSpecializationInfo = function() return SPEC, "Spec" .. SPEC end
C_SpecializationInfo = { GetSpecialization = function() return 2 end, GetSpecializationInfo = function() return SPEC, "Spec" .. SPEC end }
local r = { uid = "spec", name = "spec", enabled = true, useBuff = true, buffID = 6001, buffState = "present", cdState = "none",
  load = { mode = "all", specs = { ["581"] = true } },
  sound = { enabled = true, source = "file", value = "Interface\\AddOns\\SoundPack\\spec.ogg", channel = "Master" },
  gameSound = { enabled = true, when = "auto", channel = "Ambience", throttle = 1 } }
NS.rules[#NS.rules + 1] = r
SPECRULE = r
SYNCS = 0
local sync0 = NS.AuraSound.Sync
NS.AuraSound.Sync = function(...) SYNCS = SYNCS + 1; return sync0(...) end
BEFORE_SPEC = {}
for _, reg in ipairs(EVENTS.PLAYER_SPECIALIZATION_CHANGED or {}) do BEFORE_SPEC[reg] = true end
NS.AuraSound.OnEdited()
RUN_TIMERS()
-- the registration AuraSound made for the spec event when it started (the ones that were not there before)
AS_SPEC_REGS, AS_SPEC_PLAYER_ONLY = 0, true
for _, reg in ipairs(EVENTS.PLAYER_SPECIALIZATION_CHANGED or {}) do
  if not BEFORE_SPEC[reg] then
    AS_SPEC_REGS = AS_SPEC_REGS + 1
    local u = reg[2]
    if not (u and u.player and next(u, next(u)) == nil) then AS_SPEC_PLAYER_ONLY = false end
  end
end
''')
check("AuraSound: a ticked rule starts the feature and the first sync hands its sound to the game",
      L.eval("NS.AuraSound.Live()") is True and L.eval("HOLDS(6001)") is True and L.eval("SYNCS") == 1,
      "live %s holds %s syncs %s" % (L.eval("NS.AuraSound.Live()"), L.eval("HOLDS(6001)"), L.eval("SYNCS")))
check("AuraSound (RB-30): it registers the spec event for the player only, so the game does not call it for other units",
      L.eval("AS_SPEC_REGS") == 1 and L.eval("AS_SPEC_PLAYER_ONLY") is True, (L.eval("AS_SPEC_REGS"), L.eval("AS_SPEC_PLAYER_ONLY")))
# A2: debounce rounds through A.Queue (rule edits and the player's events)
L.execute(r'''
AS_ROUNDS = {}
for round = 1, 3 do
  local t0, s0 = ASTIMERS(), SYNCS
  NS.AuraSound.Queue(); NS.AuraSound.Queue(); FIRE("PLAYER_EQUIPMENT_CHANGED")
  local armed = ASTIMERS() - t0
  RUN_TIMERS()
  AS_ROUNDS[round] = { armed = armed, synced = SYNCS - s0, delay = SITE_TIMERS[#SITE_TIMERS] }
end
''')
r = L.eval("AS_ROUNDS")
check("AuraSound: each burst of changes arms one 0.5 s timer and syncs once (debounce kept)",
      all(r[i].armed == 1 and r[i].synced == 1 and r[i].delay == 0.5 for i in range(1, 4)),
      [(r[i].armed, r[i].synced, r[i].delay) for i in range(1, 4)])
# B: the spec event
L.execute(r'''
T0, S0 = ASTIMERS(), SYNCS
-- what the game delivers: the spec event for a group member (party1), then for a nameplate unit
FIRE("PLAYER_SPECIALIZATION_CHANGED", "party1"); FIRE("PLAYER_SPECIALIZATION_CHANGED", "nameplate3")
OTHER_ARMED_GAME = ASTIMERS() - T0
RUN_TIMERS()
-- the handler itself, as on a client where the frame was registered without a unit (RegisterEvent): every frame that listens
T1 = ASTIMERS()
for e, l in pairs(EVENTS) do
  if e == "PLAYER_SPECIALIZATION_CHANGED" then for _, reg in ipairs(l) do local s = reg[1]["_s_OnEvent"]; if s then s(reg[1], e, "raid7") end end end
end
OTHER_ARMED_HANDLER = ASTIMERS() - T1
RUN_TIMERS()
OTHER_SYNCS = SYNCS - S0
HELD_AFTER_OTHER = HOLDS(6001)
''')
check("AuraSound (RB-30): another unit's spec change (party1, nameplate3) arms no sync",
      L.eval("OTHER_ARMED_GAME") == 0, L.eval("OTHER_ARMED_GAME"))
check("AuraSound (RB-30): the handler ignores another unit's spec change even if it hears it (raid7)",
      L.eval("OTHER_ARMED_HANDLER") == 0, L.eval("OTHER_ARMED_HANDLER"))
check("AuraSound (RB-30): no re-plan for those, and the game keeps the player's sound",
      L.eval("OTHER_SYNCS") == 0 and L.eval("HELD_AFTER_OTHER") is True, (L.eval("OTHER_SYNCS"), L.eval("HELD_AFTER_OTHER")))
L.execute(r'''
T2, S2 = ASTIMERS(), SYNCS
SPEC = 577   -- the player changes spec: the rule is for spec 581 only
FIRE("PLAYER_SPECIALIZATION_CHANGED", "player")
PLAYER_ARMED = ASTIMERS() - T2
RUN_TIMERS()
PLAYER_SYNCS = SYNCS - S2
HELD_OTHER_SPEC = HOLDS(6001)
SPEC = 581
FIRE("PLAYER_SPECIALIZATION_CHANGED", "player"); RUN_TIMERS()
HELD_BACK = HOLDS(6001)
''')
check("AuraSound: the player's own spec change still re-plans (one timer, one sync)",
      L.eval("PLAYER_ARMED") == 1 and L.eval("PLAYER_SYNCS") == 1, (L.eval("PLAYER_ARMED"), L.eval("PLAYER_SYNCS")))
check("AuraSound: into a spec the rule is not for, the game's copy is taken back; back into its spec, the game holds it again",
      L.eval("HELD_OTHER_SPEC") is False and L.eval("HELD_BACK") is True, (L.eval("HELD_OTHER_SPEC"), L.eval("HELD_BACK")))
calls, fresh = L.eval("GUARD.calls"), L.eval("GUARD.fresh")
check("AuraSound (SD-82 guard): %d timer calls, 0 new functions made per call" % calls, calls >= 5 and fresh == 0,
      "calls %s, new functions %s" % (calls, fresh))

# ---------------------------------------------------------------------------------------------------------------------------------
# C. the 'rules' service (RuleDefaults.lua) against its readers on main
# ---------------------------------------------------------------------------------------------------------------------------------
L.execute(r'''
RS = NS.Service and NS.Service("rules")
NS.spellList, NS.talentList = { "x" }, { "y" }
if RS and RS.ForgetSpellLists then RS.ForgetSpellLists() end
FORGOT = NS.spellList == nil and NS.talentList == nil
''')
check("the 'rules' service is there", L.eval("type(RS)") == "table")
sm = open(os.path.join(ROOT, "XayaUI_Bonus_StatCalculator/StatModel.lua"), encoding="utf-8").read() \
    if os.path.isfile(os.path.join(ROOT, "XayaUI_Bonus_StatCalculator/StatModel.lua")) else ""
read_keys = sorted(set(re.findall(r"\bRS\.(\w+)", sm)))
check("the Stat Calculator reads the 'rules' service (StatModel.lua): %s" % ", ".join(read_keys),
      set(read_keys) >= {"BuildSpellList", "BuildTalentList", "ForgetSpellLists"}, read_keys)
check("every entry the Stat Calculator reads is in the service, as a function",
      read_keys and all(L.eval("type(RS.%s)" % k) == "function" for k in read_keys), read_keys)
check("the Stat Calculator's Refresh spell data still makes XayaUI Rules read its spellbook and talent lists again",
      L.eval("FORGOT") is True)
# readers on main of BarColorizeTypes through the service: every Lua file of every addon folder outside XayaUI_Rules
readers = []
for d in sorted(os.listdir(ROOT)):
    if not d.startswith("XayaUI") or d == "XayaUI_Rules" or not os.path.isdir(os.path.join(ROOT, d)):
        continue
    for dp, _, fs in os.walk(os.path.join(ROOT, d)):
        for fn in fs:
            if fn.endswith(".lua") and "BarColorizeTypes" in open(os.path.join(dp, fn), encoding="utf-8", errors="replace").read():
                readers.append(os.path.relpath(os.path.join(dp, fn), ROOT))
check("no addon on main outside XayaUI Rules reads BarColorizeTypes", not readers, readers)
check("(V34) the 'rules' service no longer offers BarColorizeTypes, which nothing on main reads",
      L.eval("RS and RS.BarColorizeTypes") is None)

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
