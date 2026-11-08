# Test for XayaUI_DevAssist 0.7.1 `/xuidev instance` (Probe.lua section 12): the per-creature summary built on the event probe's enemy
# reads. Lua 5.1, stand-in game functions only: every creature, spell, criteria and season value below is made up to drive the code
# paths (nothing here is game data).
#
# The stand-in world (secret sentinel, frames, units, clock) is taken from tests/devassist_probe_run.py's SCENARIO text, up to its
# `function DBP()` line, so both tests run the probe in the same world. Added here: C_ScenarioInfo, C_ChallengeMode, C_MythicPlus and
# C_UnitAuras.GetAuraDataByIndex stand-ins.
#
# What it checks (outcomes: what ends up in XayaUIDevAssistDB.instance and in chat):
#   - probe on: the instance, its challenge-mode map, keystone level, scenario step with every criterion (weighted one included) and
#     the Mythic+ season are read;
#   - a nameplate out of combat files the creature: name, classification, Mythic+ count, harmful and helpful auras, instance and
#     encounter counts; an enemy cast files its spell under the caster; a player's nameplate is never filed;
#   - in combat (creature ID secret): the sighting is counted as hidden, the cast goes to orphanCasts, nothing secret is stored or
#     misused, no secret is passed to a game function;
#   - a secret Mythic+ count and secret auras are counted, never stored; a changed count sets `varies`;
#   - `/xuidev instance` scans the visible units and prints the summary; `status`, `clear`; `/xuidev probe clear` leaves the
#     instance data; missing game functions are tallied, not raised; the probe status gains line 12; `/xuidev status` names it.
# Deliberate breaks: the same scenario runs again with each hook cut (MUTATIONS). Every break must make at least one check fail
# (so the checks can fail on code without the feature). The last line carries FAILS: <n>.
# Run from the repo root: python3 tests/devassist_instance_run.py   Needs: pip install lupa.
import os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GD_PATH = os.path.join(ROOT, "XayaUI_DevAssist", "DevAssist.lua").replace("\\", "/")
MODULES_PATH = os.path.join(ROOT, "XayaUI", "Modules.lua").replace("\\", "/")
try:   # never read the terminal: nothing in this test needs input (debug W3; a Lua loadfile(nil) here once waited on stdin)
    sys.stdin.close()
    os.close(0)
    os.open(os.devnull, os.O_RDONLY)   # fd 0 = /dev/null for the Lua runtime too
except OSError:
    pass
PROBE_PATH = os.path.join(ROOT, "XayaUI_DevAssist", "Probe.lua")
EVENTS_MD = os.path.join(ROOT, "docs", "reference", "api", "events.md")
PROBE_SRC = open(PROBE_PATH, encoding="utf-8").read()
DOC_EVENTS = sorted(set(re.findall(r"^- `([A-Z0-9_]+)`", open(EVENTS_MD, encoding="utf-8").read(), re.M)))

_probe_test = open(os.path.join(ROOT, "tests", "devassist_probe_run.py"), encoding="utf-8").read()
_start = _probe_test.find("SCENARIO = r'''")
_end = _probe_test.find("function DBP()")
if _start < 0 or _end < 0 or _end < _start:
    print("could not find the stand-in world in tests/devassist_probe_run.py  FAILS: 1")
    sys.exit(1)
WORLD = _probe_test[_start + len("SCENARIO = r'''"):_end]

CHECKS = r'''
-- added stand-ins (made-up values)
MP = { nameplate3 = 4, target = "secret" }   -- Mythic+ count per unit; "secret" = a secret value
MP_PCT = 0.95
C_ScenarioInfo = {
  GetUnitCriteriaProgressValues = function(unit) ARG(unit)
    if COMBAT and not UNITS[unit].player then return SECRET("number"), SECRET("number"), SECRET("string") end
    local v = MP[unit]
    if v == "secret" then return SECRET("number"), SECRET("number"), SECRET("string") end
    if v == nil then return nil end
    return v, MP_PCT, "0.95%"
  end,
  GetScenarioStepInfo = function() return { title = "Voidscar Arena", numCriteria = 2, stepID = 77, weightedProgress = 10 } end,
  GetCriteriaInfo = function(i) ARG(i)
    if i == 1 then return { description = "Void Lord defeated", criteriaID = 9001, assetID = 3001, totalQuantity = 1, quantity = 0, isWeightedProgress = false, quantityString = "0/1", completed = false, flags = 0, criteriaType = 165 } end
    if i == 2 then return { description = "Enemy Forces", criteriaID = 9002, assetID = 608, totalQuantity = 285, quantity = 12, isWeightedProgress = true, quantityString = "4%", completed = false, flags = 0, criteriaType = 0 } end
  end,
}
C_ChallengeMode = { GetActiveChallengeMapID = function() return 560 end, GetActiveKeystoneInfo = function() return 12, {}, true end }
C_MythicPlus = { GetCurrentSeasonValues = function() return 17, 16, 18 end, GetCurrentSeason = function() return 16 end }
AURAS = {
  nameplate3 = { HARMFUL = { { spellId = 440001, name = "Void Rot" } }, HELPFUL = { { spellId = 440002, name = "Shadow Ward" } } },
  target = "secret",
}
C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter) ARG(unit); ARG(i); ARG(filter)
  local u = AURAS[unit]
  if u == "secret" then return SECRET("table") end
  local l = u and u[filter]
  return l and l[i]
end

function SLASH(s) SlashCmdList.XAYAUIDEV(s) end
function KEYS(t) local l = {} for k in pairs(t or {}) do l[#l + 1] = tostring(k) end; table.sort(l); return table.concat(l, ",") end
function DBI() return XayaUIDevAssistDB and XayaUIDevAssistDB.instance end
function C220() local x = DBI(); return x and x.creatures and x.creatures[220001] end
local function HASUSERDATA(t, depth)
  if depth > 8 then return false end
  for k, v in pairs(t) do
    if rawtype(k) == "userdata" or rawtype(v) == "userdata" then return true end
    if rawtype(v) == "table" and HASUSERDATA(v, depth + 1) then return true end
  end
  return false
end
local function HASSTRING(t, s, depth)
  if depth > 8 then return false end
  for k, v in pairs(t) do
    if (rawtype(v) == "string" and v:find(s, 1, true)) or (rawtype(k) == "string" and k:find(s, 1, true)) then return true end
    if rawtype(v) == "table" and HASSTRING(v, s, depth + 1) then return true end
  end
  return false
end

SECTION("load", function()
  LOADING = "DevAssist"; assert(loadfile(GD_PATH))("XayaUI_DevAssist")
  LOADING = "Probe"; assert(loadstring(PROBE_SRC, "@Probe.lua"))("XayaUI_DevAssist")
  LOADING = "test"
  check("load: /xuidev instance exists", type(XayaUIDevAssist.Instance) == "function")
end)

SECTION("probe on reads the instance", function()
  SLASH("probe on")
  local x = DBI()
  local r = x and x.instances and x.instances[2999]
  check("on: instance 2999 named", r and r.name == "Voidscar Arena" and r.type == "party", r and r.name)
  check("on: challenge-mode map and keystone level", r and r.cm == 560 and r.keyLevel == 12)
  check("on: difficulty counted", r and r.diffs and r.diffs[8] == 1)
  local st = r and r.step
  check("on: scenario step with both criteria", st and st.stepID == 77 and st.numCriteria == 2 and st.criteria[1] and st.criteria[2])
  local c2 = st and st.criteria[2]
  check("on: the weighted criterion keeps its tree's total", c2 and c2.isWeightedProgress == true and c2.totalQuantity == 285 and c2.assetID == 608)
  check("on: season values", x and x.season and x.season.display == 17 and x.season.milestone == 16 and x.season.reward == 18 and x.season.season == 16)
end)

SECTION("sightings out of combat", function()
  COMBAT = false
  FIRE("NAME_PLATE_UNIT_ADDED", "nameplate3")
  local c = C220()
  check("plate: creature filed", c ~= nil and c.n == 1 and c.nc == 0, c and c.n)
  check("plate: name and classification", c and c.name == "Void Shrieker" and c.cls == "elite")
  check("plate: Mythic+ count read", c and c.mp and c.mp.a == 4 and c.mp.p == 0.95 and c.mp.n == 1)
  check("plate: harmful and helpful auras with names", c and c.auras[440001] and c.auras[440001].f == "H" and c.auras[440001].name == "Void Rot"
    and c.auras[440002] and c.auras[440002].f == "B" and c.nAuras == 2)
  check("plate: instance counted", c and c.inst[2999] == 1)
  FIRE("NAME_PLATE_UNIT_ADDED", "nameplate4")
  check("player plate: never filed", DBI().nCreatures == 1 and not HASSTRING(DBI(), "Strangerplay", 1) and not HASSTRING(DBI(), "0000DDDD", 1))
  check("player plate: not counted as a hidden creature either", DBI().hidden[2999] == nil and DBI().skipped == 0)
  FIRE("NAME_PLATE_UNIT_REMOVED", "nameplate3")
  check("plate removed: not a new sighting", C220().n == 1)
  FIRE("UNIT_SPELLCAST_START", "nameplate3", "Cast-3-1", 1233398)
  FIRE("UNIT_SPELLCAST_SUCCEEDED", "nameplate3", "Cast-3-1", 1233398)
  FIRE("UNIT_SPELLCAST_STOP", "nameplate3", "Cast-3-1", 1233398)
  check("cast: filed under the caster (start and success, not stop)", C220().casts[1233398] == 2 and C220().nCasts == 1, C220().casts[1233398])
  FIRE("ENCOUNTER_START", 3001, "Void Lord", 8, 5)
  MP.nameplate3 = 5
  FIRE("NAME_PLATE_UNIT_ADDED", "nameplate3")
  check("encounter: sighting filed under the encounter", C220().enc[3001] == 1)
  check("Mythic+ count: a changed value sets varies", C220().mp.a == 5 and C220().mp.varies == true)
end)

SECTION("in combat", function()
  COMBAT = true
  FIRE("NAME_PLATE_UNIT_ADDED", "nameplate3")
  local h = DBI().hidden[2999]
  check("combat: hidden sighting counted, not filed", h and h.c == 1 and h.secret == 1 and C220().n == 2, h and h.c)
  FIRE("UNIT_SPELLCAST_START", "nameplate3", "Cast-3-2", 1233398)
  local o = DBI().orphanCasts[2999]
  check("combat: cast of an unreadable caster kept as orphan", o and o.ids[1233398] == 1 and o.n == 1)
  check("combat: creature ID tallied secret in combat", (DBI().fields["creatureID"].sc or 0) >= 1)
  FIRE("ENCOUNTER_END", 3001, "Void Lord", 8, 5, 1, {})
  COMBAT = false
end)

SECTION("scan and commands", function()
  said = {}
  SLASH("instance")
  check("scan: units visible now read (target, nameplate3, nameplate4)", SAID("instance: read 3 unit(s)") ~= nil, said[1])
  local c = C220()
  check("scan: target and plate are the same creature", c.n == 4, c.n)
  check("scan: target's secret Mythic+ count counted, value kept", c.mp.s == 1 and c.mp.a == 5)
  check("scan: target's secret auras tallied, nothing added", ((DBI().fields["aura.data"] or {}).so or 0) >= 1 and c.nAuras == 2)
  check("scan: summary printed", SAID("instance: 1 creatures") ~= nil and SAID("Mythic+ season: display 17") ~= nil)
  check("scan: no encounter after ENCOUNTER_END", c.enc[3001] == 1)
  said = {}
  SLASH("probe status")
  check("probe status: line 12", SAID("12 creatures filed for /xuidev instance: 1") ~= nil)
  said = {}
  SLASH("status")
  check("/xuidev status: instance named", SAID("instance: 1 creatures") ~= nil)
  SLASH("probe clear")
  check("probe clear: instance data kept", C220() ~= nil)
  local saved = C_ScenarioInfo
  C_ScenarioInfo = nil
  said = {}
  SLASH("instance")
  C_ScenarioInfo = saved
  check("missing functions: tallied, no failure", ((DBI().fields["mplus.actualValue"] or {}).mo or 0) >= 1 and SAID("failed") == nil)
  said = {}
  SLASH("instance bogus")
  check("usage on an unknown subcommand", SAID("usage: /xuidev instance") ~= nil)
  SLASH("instance clear")
  check("clear: emptied", DBI() == nil)
end)

SECTION("safety", function()
  check("safety: no secret misused", MISUSE == 0, table.concat(MISUSE_WHAT, " | "))
  check("safety: no secret passed to a game function", SECRET_ARGS == 0, SECRET_ARGS)
  check("safety: no handler error escaped", #LEAKED == 0, table.concat(LEAKED, " | "))
  check("safety: no global written by Probe.lua", #PROBE_GLOBALS == 0, table.concat(PROBE_GLOBALS, ","))
  check("safety: nothing secret stored", not HASUSERDATA(XayaUIDevAssistDB, 1))
  local p = XayaUIDevAssistDB.probe
  check("safety: no handler failure recorded", p == nil or next(p.errors or {}) == nil, p and KEYS(p.errors))
end)
'''

# each break cuts one hook; at least one check must fail under each
MUTATIONS = [
    ("sightings not hooked", [("    if IX.Seen then IX.Seen(e, unit) end\n", "")]),
    ("casts not hooked", [("    if IX.Cast then IX.Cast(unit, id, code) end\n", "")]),
    ("context not hooked", [("    if IX.Context then IX.Context(a.instanceID, a.instance, a.instanceType, a.difficultyID) end\n", "")]),
    ("encounter not kept", [('    IX.enc = (type(e.id) == "number") and e.id or nil', "    IX.enc = nil")]),
    ("players filed", [("    if e.pl ~= false then\n        if e.pl ~= true", "    if false then\n        if e.pl ~= true")]),
    ("secret Mythic+ stored", [("    if a == SECRET or p == SECRET then", "    if false then")]),
    ("no auras", [("    Auras(c, unit)\nend", "end")]),
]


def run(src):
    lua = LuaRuntime()
    g = lua.globals()
    g.PROBE_SRC = src
    g.GD_PATH = GD_PATH
    # the stand-in world (taken from devassist_probe_run.py) loads core's Modules.lua from MODULES_PATH; unset, loadfile(nil) read Lua
    # source from stdin, so a run with an open stdin (a background full suite) hung, and with stdin closed Modules.lua was never loaded
    g.MODULES_PATH = MODULES_PATH
    t = lua.table()
    for e in DOC_EVENTS:
        t[e] = True
    g.DOC_EVENTS = t
    try:
        lua.execute(WORLD + CHECKS)
    except Exception as e:
        return None, [], ["scenario: %s" % e], {}
    order = [lua.eval("ORDER")[i] for i in range(1, int(lua.eval("#ORDER")) + 1)]
    res = {n: bool(lua.eval("RESULTS")[n]) for n in order}
    errs = [lua.eval("SECTION_ERRORS")[i] for i in range(1, int(lua.eval("#SECTION_ERRORS")) + 1)]
    txt = {n: lua.eval("FAILTXT")[n] for n in order if not res[n]}
    return res, order, errs, txt


started = time.time()
fails = 0
res, order, errs, txt = run(PROBE_SRC)
if res is None:
    print("scenario failed to run: %s" % errs)
    print("0 checks  FAILS: 1")
    sys.exit(1)
for n in order:
    if not res[n]:
        fails += 1
        print("FAIL  %s  (%s)" % (n, txt.get(n)))
for e in errs:
    fails += 1
    print("SECTION ERROR  %s" % e)
for name, edits in MUTATIONS:
    src = PROBE_SRC
    for old, new in edits:
        if src.count(old) != 1:
            fails += 1
            print("BREAK %r: text to cut not found exactly once: %r" % (name, old[:60]))
            break
        src = src.replace(old, new)
    else:
        r2, o2, e2, _ = run(src)
        caught = r2 is None or bool(e2) or any(not r2[n] for n in o2) or len(o2) < len(order)
        if not caught:
            fails += 1
            print("BREAK %r: no check failed" % name)
print("%d checks, %d deliberate breaks, %.1f s  FAILS: %d" % (len(order), len(MUTATIONS), time.time() - started, fails))
sys.exit(1 if fails else 0)
