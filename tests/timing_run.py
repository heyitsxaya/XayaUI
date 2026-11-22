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
# (round 11b, build spec step 5) hidden data comes from the shared stand-in: the secret object and world.lua's restriction state
# (combat hides the aura and the cooldown below through C_Secrets, as the game does); no local fake.
BENCH_RESTRICTIONS = r'''
-- [bench restrictions] (round 11b, build spec step 5: one stand-in for hidden data, kept in the private XUI-Docs repo)
-- A test on the engine_bench.py stubs gets the shared secret object (tests/harness/secret.lua) and the restriction state machine of
-- tests/harness/world.lua, the same code the harness and the gates play. world.lua runs in its own environment, so its frames,
-- C_Spell and C_UnitAuras stay there and the bench's stubs and the test's own game model are untouched. This state gets:
--   W   the world: drive it with W.enterCombat / W.leaveCombat, W.startKey / W.completeKey, W.startEncounter / W.endEncounter,
--       W.enterInstance / W.leaveInstance; set W.auraSecrecy[id] / W.cdSecrecy[id] (0 NeverSecret, 1 AlwaysSecret, absent 2)
--   W.S the secret object: W.S.new(v) a hidden value, W.S.reveal(v) for asserts only (no global S: tests name rules S)
--   the installed type, issecretvalue, canaccessvalue, issecrettable, canaccesstable, tonumber, string.format (S.install), and
--   world's state-driven readers: C_Secrets, C_RestrictedActions, InCombatLockdown, UnitAffectingCombat, IsInInstance,
--   GetInstanceInfo, C_ChallengeMode and C_InstanceEncounter (a test may still replace any of them after this block).
-- The world's events (PLAYER_REGEN_DISABLED, ADDON_RESTRICTION_STATE_CHANGED, ...) go to BENCH_FIRE(event, ...) when the test defines
-- it (its own event delivery), and nowhere otherwise. Run once, after the bench and before any addon file (addons keep 'local type =
-- type'). Every copy of this block is the same: tests/fix_r11_fakes_run.py checks it (its owner should be engine_bench.py).
do
  local dir, G = ..., _G
  local env = {}
  for _, k in ipairs({ "assert", "collectgarbage", "coroutine", "debug", "dofile", "error", "gcinfo", "getfenv", "getmetatable", "ipairs",
      "load", "loadfile", "loadstring", "math", "newproxy", "next", "os", "pairs", "pcall", "print", "rawequal", "rawget", "rawset",
      "select", "setfenv", "setmetatable", "string", "table", "tonumber", "tostring", "type", "unpack", "xpcall", "_VERSION" }) do
    env[k] = rawget(G, k)
  end
  env._G = env
  local chunk = assert(loadfile(dir .. "world.lua"))
  setfenv(chunk, env)
  W = chunk()({})
  W.S.install(G, { legacy = W })
  for _, k in ipairs({ "C_Secrets", "C_RestrictedActions", "InCombatLockdown", "UnitAffectingCombat", "IsInInstance", "GetInstanceInfo",
      "C_ChallengeMode", "C_InstanceEncounter" }) do
    G[k] = env[k]
  end
  W.fire = function(e, ...) local f = rawget(G, "BENCH_FIRE"); if f then return f(e, ...) end end
end
-- [/bench restrictions]
'''
L.execute(BENCH_RESTRICTIONS, os.path.join(ROOT, "tests", "harness") + os.sep)
L.execute(r'''
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
  if C_Secrets.ShouldSpellAuraBeSecret(id) then return nil end   -- RequiresNonSecretAura: nil while the aura is hidden (spec 2.2)
  return { auraInstanceID = 77, applications = 1, expirationTime = AURA_START + AURA_LEN, duration = AURA_LEN, spellId = 48707 }
end
C_UnitAuras.GetAuraDuration = function() return nil end
C_Spell.GetSpellCooldown = function(id)
  if id ~= 49998 then return { startTime = 0, duration = 0, isActive = false, isOnGCD = false } end
  local act = CD_START and NOW < CD_START + CD_LEN
  local st, du = act and CD_START or 0, act and CD_LEN or 0
  -- while hidden the times are hidden numbers; isActive and isOnGCD stay readable (SpellCooldownInfo, spec 2.2: before round 11b this
  -- stand-in handed a hidden isActive, which the game never does)
  if C_Secrets.ShouldSpellCooldownBeSecret(id) then st, du = W.S.new(st), W.S.new(du) end
  return { startTime = st, duration = du, isActive = act and true or false, isOnGCD = false }
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
-- (round 5, V27 "No running loops") the engine no longer re-checks every rule on a 0.2 s tick: it steps when the game reports a change,
-- and waits for a stored moment (a "seconds left" deadline) with a one-shot timer. This stand-in changes the game's answers without
-- sending events, so each PLAY starts with the step that change's event brings, and C_Timer runs here (due timers each frame, as in the game).
TIMERS = {}
local function addTimer(d, fn) local t = { at = NOW + (d or 0), fn = fn }; t.Cancel = function() t.dead = true end; TIMERS[#TIMERS + 1] = t; return t end
C_Timer.After = function(d, fn) addTimer(d, fn) end
C_Timer.NewTimer = function(d, fn) local t; t = addTimer(d, function() fn(t) end); return t end
function PLAY(seconds)   -- rendered frames
  local n = math.floor(seconds / FRAME + 0.5)
  ENGINE_STEP(NS)
  for i = 1, n do
    NOW = NOW + FRAME
    local due = {}
    for j = #TIMERS, 1, -1 do local t = TIMERS[j]; if t.dead or t.at <= NOW then table.remove(TIMERS, j); if not t.dead then due[#due + 1] = t end end end
    for j = #due, 1, -1 do due[j].fn() end
    for _, f in ipairs(UPDATERS) do local fn = f._s_OnUpdate; if fn then fn(f, FRAME) end end
  end
end
function FIRST(name, after) for _, e in ipairs(SPOKEN) do if e.what == name and e.at >= (after or 0) then return e.at end end end
''')
fails = []
checked = []   # (round 11 repair, SD-138 / V35: a test fails if it prints no result count) every check() made, for the last line "N checks, M failed" tests/run_all.py reads
def check(name, ok, extra=""):
    checked.append(name)
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)
lua = lambda s: L.execute(s)

# 1. out of combat: the shield once, readable -> its length is measured; the cooldown once -> its length is measured
lua('NOW = 1000; PLAY(0.5); AURA_START = NOW; PLAY(6); CD_START = NOW; PLAY(13)')
check("aura length measured out of combat (5 s)", lua("return CueRulesDB.learnedAuraDur[48707] == 5"), lua("return tostring(CueRulesDB.learnedAuraDur[48707])"))
check("cooldown length measured out of combat (12 s)", lua("return CueRulesDB.learnedCooldown and CueRulesDB.learnedCooldown[49998] == 12"))
check("out of combat the speech fired at 2 s left (readable time)", lua("local t = FIRST('SPEAK: shield ending', AURA_START); return t and math.abs(t - (AURA_START + 3)) <= FRAME + 1e-9"), lua("return tostring(FIRST('SPEAK: shield ending', AURA_START)) .. ' vs ' .. tostring(AURA_START + 3)"))

# 2. combat: numbers hidden. The Cooldown Manager reports the shield applied on the exact frame it lands.
lua('W.enterCombat(); SPOKEN = {}; PLAY(1); AURA_START = NOW + 0.0123; PLAY(0.0123); AMS.wasSetFromAura = true; AMS.auraInstanceID = W.S.new(77); AMS:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraApplied); PLAY(1)')
# (round 11b: the spell-ID read answers nil while the aura is hidden, RequiresNonSecretAura; before, this stand-in answered a hidden token)
check("in combat the aura's time is hidden from addon code (the spell-ID read answers nil, RequiresNonSecretAura)",
      lua("return C_Secrets.ShouldAurasBeSecret() == true and C_UnitAuras.GetUnitAuraBySpellID('player', 48707) == nil"))
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

print()
if fails:
    print("FAILED: " + ", ".join(fails))
print("%d checks, %d failed" % (len(checked), len(fails)))
sys.exit(1 if fails else 0)
