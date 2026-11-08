"""Duration engine test (Timing.lua with the real Core / Conditions / Outcomes / Cues / Engine): a speech cue on
"Anti-Magic Shell <= 2 s left" must fire in combat - where the game hides the aura's time - on the exact frame the threshold is
crossed, using the exact start reported by the Cooldown Manager and the length measured out of combat; the same for a hidden
cooldown. Stand-in game (tests/engine_bench.py stubs). Run: python3 tests/timing_run.py"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
COMBAT = false
SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
function issecretvalue(v) return v == SECRET end
Enum = Enum or {}
Enum.CooldownViewerAlertEventType = { Available = 1, PandemicTime = 2, OnCooldown = 3, ChargeGained = 4, OnAuraApplied = 5, OnAuraRemoved = 6 }
HOOKS = {}
function hooksecurefunc(t, name, fn) local orig = t[name]; t[name] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end end
-- the world: Anti-Magic Shell (aura 48707) up from AURA_START for 5 s; Death Strike-like cooldown 49998 started at CD_START, 12 s
AURA_START, AURA_LEN = nil, 5
CD_START, CD_LEN = nil, 12
local function auraUp() return AURA_START and NOW >= AURA_START and NOW < AURA_START + AURA_LEN end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
  if id ~= 48707 or not auraUp() then return nil end
  if COMBAT then return SECRET end
  return { auraInstanceID = 77, applications = 1, expirationTime = AURA_START + AURA_LEN, duration = AURA_LEN, spellId = 48707 }
end
C_UnitAuras.GetAuraDuration = function() return nil end
C_Spell.GetSpellCooldown = function(id)
  if id ~= 49998 then return { startTime = 0, duration = 0, isActive = false, isOnGCD = false } end
  if COMBAT then return { startTime = SECRET, duration = SECRET, isActive = SECRET, isOnGCD = SECRET } end
  local act = CD_START and NOW < CD_START + CD_LEN
  return { startTime = act and CD_START or 0, duration = act and CD_LEN or 0, isActive = act and true or false, isOnGCD = false }
end
C_Spell.GetSpellCharges = function() return nil end
-- the Cooldown Manager's icons (Blizzard's own code would call TriggerAlertEvent; the test calls it at the same moments)
local function cdmItem(spellID)
  local f = CreateFrame("Frame")
  f.cooldownInfo = { spellID = spellID }
  function f:GetSpellID() return spellID end
  function f:TriggerAlertEvent(ev) end
  function f:OnUnitAuraUpdatedEvent() end
  function f:OnCooldownIDSet() end
  return f
end
AMS = cdmItem(48707); DS = cdmItem(49998)
BuffIconCooldownViewer = CreateFrame("Frame"); function BuffIconCooldownViewer:GetChildren() return AMS end
EssentialCooldownViewer = CreateFrame("Frame"); function EssentialCooldownViewer:GetChildren() return DS end
UtilityCooldownViewer = CreateFrame("Frame"); function UtilityCooldownViewer:GetChildren() end
BuffBarCooldownViewer = CreateFrame("Frame"); function BuffBarCooldownViewer:GetChildren() end
-- keep every frame that gets an OnUpdate script, so the test can play rendered frames
UPDATERS = {}
local SetScript0 = FRAME_METHODS.SetScript
FRAME_METHODS.SetScript = function(self, n, fn) SetScript0(self, n, fn); if n == "OnUpdate" and fn then UPDATERS[#UPDATERS + 1] = self end end
SPOKEN = {}
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{ settingsTestHooks = { keepOld = true } }"); L.globals().NS = ns  # (P5) XayaUI Rules' data stays in CueRulesDB here, as before P5 (Modules.lua: a declared store opens as "old")
for f in ("XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI_Rules/RuleDefaults.lua", "XayaUI/Compat.lua", "XayaUI_Rules/Conditions.lua", "XayaUI_Rules/Timing.lua", "XayaUI_Rules/Triggers.lua", "XayaUI_Rules/Outcomes.lua", "XayaUI_Rules/Cues.lua", "XayaUI_Rules/Actions.lua", "XayaUI/Sound.lua", "XayaUI_Rules/Visual.lua", "XayaUI_Rules/Engine.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
# (core 0.6.56, REQUEST-LOG #81: /xui debug timing, the coverage report, is XayaUI Dev Assist's: the real function from
# XayaUI_DevAssist/CoreDebug.lua, set where the test calls it)
_cd = open(os.path.join(ROOT, "XayaUI_DevAssist", "CoreDebug.lua"), encoding="utf-8").read()
_a = _cd.index("local TIME_REFS"); _b = _cd.index("local function TimingReport()"); _c = _cd.index("\nend\n", _b) + 5
L.execute("local ns = NS\n" + _cd[_a:_c] + "\nNS.Timing.Report = TimingReport\n")
L.execute(r'''
local ns = NS
ns.Print = function() end
ns.PlaySound = function(s) SPOKEN[#SPOKEN + 1] = { at = NOW, what = s } end
ns.EffectiveSound = function(r) return r.name end
ns.KindHas = function(r, kind) return kind == "sound" and r.isCue end
-- the rule: Anti-Magic Shell present; a condition "aura seconds left <= 2" that switches on a speech cue
P = { uid = "p1", name = "Anti-Magic Shell", useBuff = true, buffID = 48707, buffState = "present", cdState = "none", enabled = true, load = { mode = "always" }, visual = { enabled = false } }
C = { uid = "c1", name = "2s left", parentUid = "p1", enabled = true, when = { list = { { ref = "n:buffRemain", cmp = "<=", num = 2 } } }, thenCues = { "k1" }, visual = { enabled = false } }
S = { uid = "s1", name = "SPEAK: shield ending", parentUid = "p1", isCue = true, cueKey = "k1", cueKind = "speech", enabled = true, visual = { enabled = false } }
-- a cooldown rule: "Death Strike seconds left <= 3" -> speech
P2 = { uid = "p2", name = "Death Strike", useCooldown = true, spellID = 49998, cdState = "none", enabled = true, load = { mode = "always" }, visual = { enabled = false } }
C2 = { uid = "c2", name = "3s to DS", parentUid = "p2", enabled = true, when = { list = { { ref = "n:cdRemain", cmp = "<=", num = 3 } } }, thenCues = { "k2" }, visual = { enabled = false } }
S2 = { uid = "s2", name = "SPEAK: strike soon", parentUid = "p2", isCue = true, cueKey = "k2", cueKind = "speech", enabled = true, visual = { enabled = false } }
ns.rules = { P, C, S, P2, C2, S2 }
ns.folders = {}
CueRulesDB.rules, CueRulesDB.folders = ns.rules, ns.folders
FRAME = 1 / 60
function PLAY(seconds)   -- rendered frames
  local n = math.floor(seconds / FRAME + 0.5)
  for i = 1, n do
    NOW = NOW + FRAME
    for _, f in ipairs(UPDATERS) do local fn = f._s_OnUpdate; if fn then fn(f, FRAME) end end
  end
end
function FIRST(name, after) for _, e in ipairs(SPOKEN) do if e.what == name and e.at >= (after or 0) then return e.at end end end
''')
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)
lua = lambda s: L.execute(s)

# 1. out of combat: the shield once, readable -> its length is measured; the cooldown once -> its length is measured
lua('NOW = 1000; PLAY(0.5); AURA_START = NOW; PLAY(6); CD_START = NOW; PLAY(13)')
check("aura length measured out of combat (5 s)", lua("return CueRulesDB.learnedAuraDur[48707] == 5"), lua("return tostring(CueRulesDB.learnedAuraDur[48707])"))
check("cooldown length measured out of combat (12 s)", lua("return CueRulesDB.learnedCooldown and CueRulesDB.learnedCooldown[49998] == 12"))
check("out of combat the speech fired at 2 s left (readable time)", lua("local t = FIRST('SPEAK: shield ending', AURA_START); return t and math.abs(t - (AURA_START + 3)) <= FRAME + 1e-9"), lua("return tostring(FIRST('SPEAK: shield ending', AURA_START)) .. ' vs ' .. tostring(AURA_START + 3)"))

# 2. combat: numbers hidden. The Cooldown Manager reports the shield applied on the exact frame it lands.
lua('COMBAT = true; SPOKEN = {}; PLAY(1); AURA_START = NOW + 0.0123; PLAY(0.0123); AMS.wasSetFromAura = true; AMS.auraInstanceID = SECRET; AMS:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraApplied); PLAY(1)')
check("in combat the aura's time is hidden from addon code", lua("return C_UnitAuras.GetUnitAuraBySpellID('player', 48707) == SECRET"))
check("estimate in use: exact start from the Cooldown Manager + measured 5 s", lua("local rt = NS.runtime[P]; local r = rt and rt.info and rt.info.buffRef; return r and r.estimated and math.abs(r.expiration - (AMS.xuiAppliedAt + 5)) < 1e-9"))
lua('PLAY(4.5)')
t = L.eval("FIRST('SPEAK: shield ending', AURA_START)"); want = L.eval("AMS.xuiAppliedAt + 3"); frame = L.eval("FRAME")
check("in combat the speech fires at 2 s left, on the crossing frame (within one rendered frame)", t is not None and 0 <= t - want <= frame + 1e-9, "fired %s, crossing %s" % (t, want))
lua('AMS.wasSetFromAura = false; AMS.auraInstanceID = nil; AMS:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved); PLAY(0.5)')
check("removal ends the estimate at once (aura reads absent, no stale time left)", lua("local rt = NS.runtime[P]; return rt and rt.info and rt.info.present == false"))
# (a condition on "seconds left" reads 0 while the aura is absent - existing behaviour, unchanged)

# 3. a cooldown hidden in combat: exact start from the Cooldown Manager + measured 12 s
lua('SPOKEN = {}; CD_START = NOW; DS:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnCooldown); PLAY(10)')
t2 = L.eval("FIRST('SPEAK: strike soon', CD_START)"); want2 = L.eval("DS.xuiCdStartAt + 9")
check("hidden cooldown: speech at 3 s left on the crossing frame", t2 is not None and 0 <= t2 - want2 <= frame + 1e-9, "fired %s, crossing %s" % (t2, want2))

# 4. the coverage report says how each rule gets its time
lua('PRINTED = {}; NS.Print = function(m) PRINTED[#PRINTED + 1] = m end; NS.Timing.Report()')
check("/xui debug timing: both rules covered, with their sources", lua("local a, b = false, false; for _, l in ipairs(PRINTED) do if l:find('Anti%-Magic Shell') and l:find('measured 5.0s') then a = true end if l:find('Death Strike') and l:find('measured 12.0s') then b = true end end return a and b and PRINTED[1]:find('2 rules covered') ~= nil"),
      lua("return table.concat(PRINTED, ' || ')"))
lua('CueRulesDB.learnedAuraDur[48707] = nil; PRINTED = {}; NS.Timing.Report()')
check("/xui debug timing: an unmeasured aura is flagged with the one fix", lua("for _, l in ipairs(PRINTED) do if l:find('^  !') and l:find('out of combat to measure') then return true end end return false"))
print(); print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED"); sys.exit(1 if fails else 0)
