"""Core 0.6.69: externals and raid defensives in combat (Xaya, 2026-11-07, her words: "I turned EUI ones on because XUI isn't
reliably performing"), against XayaUI's real core files and stand-in game calls. Outcomes only: what a rule reads and what its status
says.

  1. In combat the game hides the aura (C_UnitAuras.GetUnitAuraBySpellID is RequiresNonSecretAura + SecretWhenUnitAuraRestricted;
     the 2026-11-01 capture rates all twelve captured spells of her external / raid bar "secret in some situations"), and an external
     someone else casts is never in your Cooldown Manager. XayaUI does not guess: the rule stays unknown. Before 0.6.69 the only
     trace was "unknown: restricted + spell not readable + not in CDM". Now the status says it plainly, and says whether the game's own
     aura container still draws the display (Combat/AuraDisplay.lua) or why not.
  2. A buff that carries another ID than the one the rule lists (a cast ID; the capture has same-name pairs such as Power Word: Barrier
     62618 / 81782): learned out of combat from a buff with the same name and a duration (AuraAlias.lua), then counted.

Spell IDs are those of the capture (docs/reference/spells/spells.json); every game answer is a stand-in.
Run: python3 tests/externals_in_combat_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
EVENTS = {}
local M = FRAME_METHODS
function M:RegisterEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], self) end
function M:RegisterUnitEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], self) end
function FIRE(e, ...) for _, f in ipairs(EVENTS[e] or {}) do local s = f["_s_OnEvent"]; if s then s(f, e, ...) end end end
C_Timer.After = function() end
COMBAT = false
InCombatLockdown = function() return COMBAT end
UnitAffectingCombat = function() return COMBAT end
SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
issecretvalue = function(v) return v == SECRET end
Enum = Enum or {}
Enum.SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
C_Secrets = { ShouldAurasBeSecret = function() return COMBAT end, GetSpellAuraSecrecy = function() return 2 end,
  ShouldSpellAuraBeSecret = function() return COMBAT end }
NAMES = { [33206] = "Pain Suppression", [62618] = "Power Word: Barrier", [81782] = "Power Word: Barrier", [22812] = "Barkskin", [900] = "Barkskin" }
C_Spell.GetSpellName = function(id) return NAMES[id] or ("Spell" .. tostring(id)) end
AURAS = {}   -- auras on you, by spell ID; hidden (secret) in combat
SECRET_ANSWER = false   -- her 2026-11-07 log shows the game answering nothing (nil) in combat; a secret answer is covered too
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if COMBAT then if SECRET_ANSWER then return SECRET end return nil end return AURAS[id] end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
  if COMBAT then return SECRET end
  local l = {}; for _, a in pairs(AURAS) do l[#l + 1] = a end
  table.sort(l, function(x, y) return x.spellId < y.spellId end)
  return l[i]
end
function AURA(id, dur) return { spellId = id, name = NAMES[id], duration = dur or 10, expirationTime = 100 + (dur or 10), applications = 0, auraInstanceID = id * 10, isHelpful = true } end
''')
toc = [l.strip() for l in open(os.path.join(ROOT, "XayaUI", "XayaUI.toc")) if l.strip() and not l.startswith("#")]
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
skip = ("Libs", "Console.lua", "GameMenu", "MinimapButton", "AuraSources", "Combat/")
loaded, failed = [], []
for f in toc:
    f = f.replace("\\", "/")
    if f.startswith(skip) or not f.endswith(".lua"):
        continue
    try:
        load(open(os.path.join(ROOT, "XayaUI", f), encoding="utf-8").read(), f, ns); loaded.append(f)
    except Exception as e:
        failed.append((f, str(e)[:200]))

fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)

check("every core file loads", not failed, failed)
check("AuraAlias.lua is in the toc and loaded", "AuraAlias.lua" in loaded and L.eval("NS.AuraAliasesOf ~= nil"))
L.execute(r'''
local ns = NS
ns.rules = CueRulesDB.rules
ns.Print = function() end
ns.Log = function() end
ns.runtime = ns.runtime or {}
function STEP() ns.tickID = (ns.tickID or 0) + 1 end
function EVAL(r) STEP(); local res, info = ns.Evaluate(r); ns.runtime[r] = ns.runtime[r] or {}; ns.runtime[r].info = info; return res, info end
PS = { uid = "ps", name = "Pain Suppression on me", enabled = true, useBuff = true, buffID = 33206, buffState = "present", load = { mode = "always" },
  visual = { enabled = true, trigger = "buffActive" } }
ns.rules[#ns.rules + 1] = PS
-- the container's answer, as Combat/AuraDisplay.lua gives it (D.OwnerOf; tested in aura_display_run.py)
OWNER = { false, "its display has no 'show when' choice" }
ns.AuraDisplay = { OwnerOf = function(r) return OWNER[1], OWNER[2] end }
''')

# ---------------------------------------------------------------- 1. hidden in combat: plain words, never a guess
L.execute("AURAS[33206] = AURA(33206, 8)")
res, info = L.eval("EVAL(PS)")
check("out of combat, Pain Suppression on you: present, read from the game", info.present is True and res is True, (info.present, info.buffSource))
check("out of combat: no hidden-aura note", L.eval("NS.HiddenAuraNote ~= nil and NS.HiddenAuraNote(PS) == nil"))
L.execute("COMBAT = true")
res, info = L.eval("EVAL(PS)")
src = str(info.buffSource)
check("in combat, not in the Cooldown Manager: unknown (never a guess), the rule does not fire", info.present is None and res is False, (info.present, src))
check("in combat: the reading says the game hides it, in plain words (was 'unknown: restricted + spell not readable + not in CDM')",
      src.startswith("hidden by the game right now") and "33206" in src and "Cooldown Manager" in src, src)
note = L.eval("NS.HiddenAuraNote and NS.HiddenAuraNote(PS)")
check("status note, container does not draw it: says XayaUI cannot show it and gives the container's reason",
      note is not None and "cannot show" in note and "show when" in note, note)
L.execute("OWNER = { true, \"its own slot on XayaUI's icon\" }")
note = L.eval("NS.HiddenAuraNote and NS.HiddenAuraNote(PS)")
check("status note, container draws it: says the game's aura container still draws the display, and what waits",
      note is not None and "still draws" in note and "Sounds" in note, note)
L.execute("OWNER = { nil }")
note = L.eval("NS.HiddenAuraNote and NS.HiddenAuraNote(PS)")
check("status note, no container display at all: says so", note is not None and "no display drawn" in note, note)
expl = L.eval("NS.ExplainRule(PS)")
check("/xui debug status line (ExplainRule) carries the note", "game hides this aura" in str(expl), expl)
L.execute("SECRET_ANSWER = true")
res, info = L.eval("EVAL(PS)")
check("in combat, the game answers with a secret instead of nothing: the same plain words", info.present is None and str(info.buffSource).startswith("hidden by the game right now"), info.buffSource)
L.execute("SECRET_ANSWER = false")
L.execute("OWNER = { false, \"its display has no 'show when' choice\" }")

# ---------------------------------------------------------------- 2. the same buff under another ID, learned out of combat
L.execute(r'''
COMBAT = false; AURAS = {}
PWB = { uid = "pwb", name = "Barrier (cast ID)", enabled = true, useBuff = true, buffID = 62618, buffState = "present", load = { mode = "always" },
  visual = { enabled = true, trigger = "buffActive" } }
NS.rules[#NS.rules + 1] = PWB
NS.AuraAliasForget()
''')
res, info = L.eval("EVAL(PWB)")
check("before anything is learned: the cast ID 62618 is not on you (out of combat: missing)", info.present is False, (info.present, info.buffSource))
L.execute("COMBAT = true; AURAS[81782] = AURA(81782, 10); NS._AuraAliasOnAura({ addedAuras = SECRET })")
check("in combat nothing is learned (the event's lists are secret there)", L.eval("NS.AuraAliasesOf(62618) == nil"))
L.execute("COMBAT = false; NS._AuraAliasOnAura({ addedAuras = { AURA(81782, 10) } })")
check("out of combat, a buff named like the rule's aura appears under 81782: learned as 62618's alias",
      L.eval("(function() local a = NS.AuraAliasesOf(62618); return a ~= nil and a[81782] == true end)()"))
check("the alias is saved (CueRulesDB.auraAlias), the rule is not edited", L.eval("CueRulesDB.auraAlias[62618][81782] == true and PWB.buffAlt == nil"))
res, info = L.eval("EVAL(PWB)")
check("out of combat the rule now reads present through the learned ID, and says so",
      info.present is True and "81782" in str(info.buffSource) and "same name" in str(info.buffSource), (info.present, info.buffSource))
L.execute("AURAS[81782] = nil")
res, info = L.eval("EVAL(PWB)")
check("the buff ends: missing again (out of combat)", info.present is False, (info.present, info.buffSource))

# passives and coexisting namesakes are never learned
L.execute(r'''
BK = { uid = "bk", name = "Barkskin", enabled = true, useBuff = true, buffID = 22812, buffState = "present", load = { mode = "always" }, visual = { enabled = true, trigger = "buffActive" } }
NS.rules[#NS.rules + 1] = BK; NS.AuraAliasForget()
NS._AuraAliasOnAura({ addedAuras = { AURA(900, 0) } })
''')
check("a namesake with no duration (a passive or talent) is never learned", L.eval("NS.AuraAliasesOf(22812) == nil"))
L.execute("AURAS[22812] = AURA(22812, 8); NS._AuraAliasOnAura({ addedAuras = { AURA(900, 8) } })")
check("a namesake that is up together with the rule's own aura is a different buff: not learned", L.eval("NS.AuraAliasesOf(22812) == nil"))
L.execute("AURAS = { [900] = AURA(900, 8) }; NS._AuraAliasOnAura({ isFullUpdate = true })")
check("a full update reads your buffs and learns too", L.eval("(function() local a = NS.AuraAliasesOf(22812); return a ~= nil and a[900] == true end)()"))
# no rule lists an aura: the handler does nothing (V14)
L.execute("SAVED_RULES = NS.rules; NS.rules = {}; NS.AuraAliasForget(); CALLS = 0; local o = C_UnitAuras.GetAuraDataByIndex; C_UnitAuras.GetAuraDataByIndex = function(...) CALLS = CALLS + 1; return o(...) end; NS._AuraAliasOnAura({ isFullUpdate = true }); C_UnitAuras.GetAuraDataByIndex = o; NS.rules = SAVED_RULES; NS.AuraAliasForget()")
check("no rule lists an aura ID: no aura is read (off costs nothing)", L.eval("CALLS == 0"))

print()
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
