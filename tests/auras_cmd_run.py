# Test for /xui auras (XayaUI core 0.6.6, AuraList.lua; restores #335). Stand-in game calls only; the IDs and numbers below are
# made up for the test, except the Enum values, which match the live client (docs/reference/api/enums.md).
# Run from the repo root: python3 tests/auras_cmd_run.py   Needs: pip install lupa.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
fails, n = 0, 0
function check(name, cond, extra) n = n + 1; if not cond then fails = fails + 1; print("FAIL: " .. name .. (extra ~= nil and ("  -> " .. tostring(extra)) or "")) else print("ok:   " .. name) end end
printed = {}
local function last(k) return printed[#printed - (k or 0)] or "" end
local function any(pat) for _, l in ipairs(printed) do if l:find(pat, 1, true) then return true end end return false end
ns = { Print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; printed[#printed + 1] = table.concat(t, " ") end }
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function(self, _, f) self.handler = f end } end
issecretvalue = function(v) return v == "SECRET" end
GetTime = function() return 100 end
Enum = { CooldownViewerCategory = { HiddenPassive = -2, HiddenActive = -1, Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 },
         SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 } }
local SPELLS = { [111] = "Divine Arbiter", [222] = "Immolation Aura", [333] = "Battle Shout", [444] = "Fiery Brand" }
C_Spell = {
  GetSpellName = function(id) return SPELLS[id] end,
  GetSpellInfo = function(x) for id, nm in pairs(SPELLS) do if nm:lower() == tostring(x):lower() then return { spellID = id, name = nm } end end end,
  IsPriorityAura = function(id) return id == 222 end,
  IsSpellImportant = function(id) return id == 111 end,
  IsExternalDefensive = function(id) return false end,
  IsSpellCrowdControl = function(id) return false end,
}
C_UnitAuras = { AuraIsBigDefensive = function(id) return id == 444 end }
C_Secrets = { GetSpellAuraSecrecy = function(id) if id == 333 then return 0 end; return 2 end }
local catCalls = 0
C_CooldownViewer = {
  GetCooldownViewerCategorySet = function(cat, allow) catCalls = catCalls + 1; if cat == 2 and allow == true then return { 9001, 9002 } end; return {} end,
  GetCooldownViewerCooldownInfo = function(cid)
    if cid == 9001 then return { spellID = 999, linkedSpellIDs = { 222 } } end   -- Immolation Aura's buff linked to a tracked entry
    if cid == 9002 then return { spellID = 111, linkedSpellIDs = {} } end
  end,
}
local shownFrame = { }
local viewer = { IsVisible = function() return true end }
BuffIconCooldownViewer = viewer
ns.FindCDMFrame = function(id) if id == 222 then return shownFrame, "BuffIconCooldownViewer" end end
local restricted = false
ns.AurasRestricted = function() return restricted end
local auras = {
  player = { HELPFUL = {
    { name = "Divine Arbiter", spellId = 111, applications = 3, duration = 30, expirationTime = 112.5, sourceUnit = "player" },
    { name = "Immolation Aura", spellId = 222, applications = 0, duration = 6, expirationTime = 104, sourceUnit = "player" },
    { name = "Battle Shout", spellId = 333, applications = 0, duration = 3600, expirationTime = 3000, sourceUnit = "party1" },
  }, HARMFUL = {} },
  target = { HARMFUL = { { name = "Fiery Brand", spellId = 444, applications = 0, duration = 10, expirationTime = 105, sourceUnit = "player" } } },
}
local readCalls = 0
C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter) readCalls = readCalls + 1; local u = auras[unit]; return u and u[filter] and u[filter][i] end
UnitExists = function(u) return u == "target" end
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__AL__))("XayaUI", ns)

-- (core 0.6.50: a diagnostic command, listed by /xui debug; /xui auras still runs)
check("registered as /xui auras, listed under /xui debug", ns.RunCommand("auras", "") and ns.RunDebugCommand("auras", "") and (function() for _, h in ipairs(ns.DebugCommandHelp()) do if h:find("auras [target", 1, true) then return true end end end)())
check("header: 3 buffs on player", any("3 buffs on player"), last(6))
check("line: name, ID, stacks, time of total, caster", any("Divine Arbiter  ID 111  x3  12.5 / 30 s  [you]"))
check("one stack is not printed as x1/x0", any("Immolation Aura  ID 222  4.0 / 6 s  [you]"))
check("cast by someone else: no [you]", any("Battle Shout  ID 333  2900.0 / 3600 s") and not any("Battle Shout  ID 333  2900.0 / 3600 s  [you]"))
check("secret in combat explained", any("readable in combat: no (secret in combat, encounters, Mythic+ and PvP)"))
check("never-secret aura says yes", any("readable in combat: yes (never secret)"))
check("Cooldown Manager on and shown (linked ID counts)", any("Cooldown Manager: on and shown (XayaUI sees it in combat)"))
check("offered but not switched on: says where", any("Cooldown Manager: offered (Tracked Buffs) but not switched on: turn it on there"))
check("not offered for this spec", any("Cooldown Manager: not offered for this spec"))
check("Blizzard flags listed", any("Blizzard: important") and any("Blizzard: priority"))
check("catalogue read with allowUnlearned = true (spec-wide, not only learned)", catCalls > 0)
-- debuffs on target
printed = {}
ns.RunCommand("auras", "target debuffs")
check("target debuffs listed", any("1 debuffs on target") and any("Fiery Brand  ID 444  5.0 / 10 s  [you]") and any("Blizzard: big defensive"))
printed = {}
ns.RunCommand("auras", "focus")
check("missing unit said plainly", last() == "/xui auras: no focus.", last())
printed = {}
ns.RunCommand("auras", "debuffs")
check("no debuffs on player", last() == "/xui auras: no debuffs on player.", last())
-- restricted: no live read at all
restricted = true; readCalls = 0; printed = {}
ns.RunCommand("auras", "")
check("restricted: refuses without calling the aura API", readCalls == 0 and last():find("hides aura details", 1, true) ~= nil, last())
-- one spell works while restricted
printed = {}
ns.RunCommand("auras", "222")
check("one spell by ID works in combat", last():find("Immolation Aura (ID 222): readable in combat: no", 1, true) ~= nil and readCalls == 0, last())
printed = {}
ns.RunCommand("auras", "divine arbiter")
check("one spell by (lower-case) name", last():find("Divine Arbiter (ID 111)", 1, true) ~= nil and last():find("offered (Tracked Buffs)", 1, true) ~= nil, last())
printed = {}
ns.RunCommand("auras", "|cff71d5ff|Hspell:333:0|h[Battle Shout]|h|r")
check("one spell by link", last():find("Battle Shout (ID 333): readable in combat: yes", 1, true) ~= nil, last())
printed = {}
ns.RunCommand("auras", "|cff71d5ff|hspell:333:0|h[battle shout]|h|r")
check("one spell by a link /xui lower-cased", last():find("Battle Shout (ID 333)", 1, true) ~= nil, last())
local savedInfo = C_Spell.GetSpellInfo
C_Spell.GetSpellInfo = function(x) if x == "Fiery Brand" then return { spellID = 444 } end end   -- a case-sensitive game lookup
C_SpellBook = { GetNumSpellBookSkillLines = function() return 1 end, GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end,
  GetSpellBookItemInfo = function(j) if j == 1 then return { spellID = 444, name = "Fiery Brand" } end end }
printed = {}
ns.RunCommand("auras", "fiery brand")
check("lower-case name found in the spellbook when the game lookup is case-sensitive", last():find("Fiery Brand (ID 444)", 1, true) ~= nil, last())
printed = {}
ns.RunCommand("auras", "immolation aura")
check("lower-case name found in the Cooldown Manager list", last():find("Immolation Aura (ID 222)", 1, true) ~= nil, last())
C_Spell.GetSpellInfo = savedInfo
printed = {}
ns.RunCommand("auras", "no such spell")
check("unknown spell said plainly", last():find("no spell found", 1, true) ~= nil, last())
restricted = false
-- secret data and refused reads
auras.player.HELPFUL[2] = "SECRET"
printed = {}
ns.RunCommand("auras", "")
check("secret aura table: stops and says so, keeps what was read", any("Divine Arbiter  ID 111") and any("hidden aura data"))
auras.player.HELPFUL[2] = { name = "SECRET", spellId = "SECRET", applications = "SECRET", duration = "SECRET", expirationTime = "SECRET", sourceUnit = "SECRET" }
printed = {}
ns.RunCommand("auras", "")
check("secret ID: listed as hidden, never compared", any("(hidden aura: the game keeps its ID secret)"))
auras.player.HELPFUL[2] = { name = "Immolation Aura", spellId = 222, applications = "SECRET", duration = 6, expirationTime = "SECRET" }
printed = {}
ns.RunCommand("auras", "")
check("secret stacks / time: left out, not guessed", any("Immolation Aura  ID 222  ? / 6 s"))
C_UnitAuras.GetAuraDataByIndex = function() error("blocked") end
printed = {}
ns.RunCommand("auras", "")
check("refused read reported", any("the game refused the aura read"))
-- facts API used by the rule editor later
local f = ns.AuraFacts(111)
check("ns.AuraFacts: secrecy, offered, flags", f.secrecy == 2 and f.cdmOffered == true and f.flags[1] == "important")
io.write(("%d checks, %d failed\n"):format(n, fails))
'''.replace("__MOD__", P("XayaUI/Modules.lua")).replace("__AL__", P("XayaUI/AuraList.lua")))
sys.exit(1 if lua.eval("fails") else 0)
