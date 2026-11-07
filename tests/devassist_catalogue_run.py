# Stub test for XayaUI_DevAssist 0.5.0 AuraCatalogue.lua: /xuidump catalogue (every aura the game points to for the current season and
# expansion) and /xuidump seen (the aura log), run against stand-in game calls. Nothing here is game data: the spell IDs and names are
# made up, except that the Boiling Point case uses the IDs Xaya gave (talent 1265790, auras 1265982 / 1265968) to show the name match.
# Run from the repo root: python3 tests/gamedump_catalogue_run.py   Needs: pip install lupa.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
fails, n = 0, 0
function check(name, cond, extra) n = n + 1; if not cond then fails = fails + 1; io.write("FAIL: " .. name .. (extra ~= nil and ("  -> " .. tostring(extra)) or "") .. "\n") else io.write("ok:   " .. name .. "\n") end end
function F(id) return (XayaUIDevAssistDB.catalogue.facts or {})[id] or {} end
local said = {}
local realPrint = print
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end
function SAID(pat) for _, s in ipairs(said) do if s:find(pat, 1, true) then return s end end end
local function mk()
  local o = { events = {} }
  local methods = { Hide = function() end, Show = function() end, SetScript = function(self, k, f) self["on" .. k] = f end,
    RegisterEvent = function(self, e) self.events[e] = true end, UnregisterEvent = function(self, e) self.events[e] = nil end,
    UnregisterAllEvents = function(self) self.events = {} end, RegisterUnitEvent = function(self, e) self.events[e] = true end,
    SetIgnoreParentAlpha = function() end, SetPoint = function() end }
  methods.CreateTexture = function() return setmetatable({}, { __index = { SetTexture = function() end, SetColorTexture = function() end } }) end
  methods.CreateFontString = function() return setmetatable({}, { __index = { SetText = function() end, SetFont = function() end } }) end
  methods.CreateLine = function() return setmetatable({}, { __index = { SetThickness = function() end } }) end
  methods.CreateAnimationGroup = function() return setmetatable({}, { __index = { Play = function() end } }) end
  return setmetatable(o, { __index = methods })
end
FRAMES = {}
CreateFrame = function() local f = mk(); FRAMES[#FRAMES + 1] = f; return f end
date = function() return "2026-11-04 05:00" end
GetTime = function() return 100 end
issecretvalue = function(v) return v == "SECRET" end
COMBAT = false
InCombatLockdown = function() return COMBAT end
GetBuildInfo = function() return "12.1.5", "70783", "Oct 31 2026", 120105 end
-- timers run when the test pumps them (C_Timer.After(0) = next frame)
TIMERS = {}
C_Timer = { After = function(t, f) TIMERS[#TIMERS + 1] = { t = t, f = f } end }
function PUMP(maxN, longToo)   -- run queued timers in order; 30-second ones only when longToo
  local k, deferred = 0, {}
  while #TIMERS > 0 and k < (maxN or 100000) do
    local t = table.remove(TIMERS, 1)
    if t.t == 0 or longToo then k = k + 1; t.f() else deferred[#deferred + 1] = t end
  end
  for _, t in ipairs(deferred) do TIMERS[#TIMERS + 1] = t end
  return k
end
UISpecialFrames = {}
tinsert = table.insert
SlashCmdList = {}

-- spells: a tiny made-up spell space, scanned up to TEST_UPPER
local SPELLS = {
  [100] = "Immolation Aura", [258920] = "Immolation Aura",          -- old IDs
  [1265790] = "Boiling Point", [1265982] = "Boiling Point", [1265968] = "Boiling Point",
  [1296661] = "Divine Arbiter", [1306161] = "Divine Arbiter", [1306162] = "Divine Arbiter",
  [1300001] = "Boss Smash", [1300002] = "Boss Smash",              -- a boss ability and its debuff
  [1300010] = "Trinket Proc", [1300011] = "Trinket Proc",          -- an item spell and its aura
  [1300020] = "Set Bonus 4pc", [1300021] = "Set Bonus 4pc",
  [1300030] = "Linked Buff",                                       -- a Cooldown Manager linked spell
  [1300040] = "Unrelated New Spell",
  [1300050] = "Bursting",                                          -- an affix aura
  [1300060] = "A;B=C",                                             -- separators in a name
}
-- the raid boss's abilities: enough for the recent cut-off; a dungeon boss's; an older dungeon boss's
for i = 0, 24 do SPELLS[1299000 + i] = "Mechanic " .. i end
SPELLS[1299100], SPELLS[1299101] = "Dungeon Mechanic", "Dungeon Mechanic 2"
SPELLS[600500] = "Old Mechanic"
SECRET_NAME_ID = 1300070
C_Spell = {
  GetSpellName = function(id) if id == SECRET_NAME_ID then return "SECRET" end; return SPELLS[id] end,
  GetSpellTexture = function(id) return SPELLS[id] and 136243 or nil end,
  DoesSpellExist = function(id) return SPELLS[id] ~= nil end,
  GetSpellDescription = function(id) return SPELLS[id] and ("desc of " .. id) or nil end,
  IsSpellImportant = function(id) return id == 1265982 end,
  IsPriorityAura = function(id) return id == 1306161 end,
  IsSpellCrowdControl = function(id) return id == 1300002 end,
  IsExternalDefensive = function() return false end,
  IsSpellPassive = function(id) return id == 1265790 end,
}
C_UnitAuras = { AuraIsBigDefensive = function() return false end }
C_Secrets = { GetSpellAuraSecrecy = function(id) if id == 1300030 then return "SECRET" end; return 2 end }
LOADED = 0
Spell = { CreateFromSpellID = function(_, id) return { ContinueOnSpellLoad = function(_, f) LOADED = LOADED + 1; f() end } end }
Item = { CreateFromItemID = function(_, id) return { ContinueOnItemLoad = function(_, f) f() end } end }
-- Cooldown Manager (this spec): one entry links its talent to a buff
Enum = { CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 } }
C_CooldownViewer = {
  GetCooldownViewerCategorySet = function(cat) if cat == 2 then return { 11 } end; if cat == 0 then return { 12 } end; return {} end,
  GetCooldownViewerCooldownInfo = function(cd) if cd == 11 then return { cooldownID = 11, spellID = 258920, linkedSpellIDs = { 1300030 }, selfAura = true, hasAura = true, charges = false, isKnown = true }
    end; if cd == 12 then return { cooldownID = 12, spellID = "SECRET", linkedSpellIDs = {} } end end,
}
GetSpecialization = function() return 2 end
GetSpecializationInfo = function() return 581, "Vengeance" end
UnitClass = function() return "Demon Hunter", "DEMONHUNTER", 12 end
UnitName = function() return "Xaya", "Realm" end
-- Encounter Journal: 3 tiers, the two newest scanned; one raid boss, one dungeon boss, loot with an item spell
EJ = { tier = 1, lootClass = 7, lootSpec = 66, slot = 4, selected = nil }
EJ_GetNumTiers = function() return 3 end
EJ_GetTierInfo = function(t) return ({ "Old", "Midnight", "Current Season" })[t] end
EJ_GetCurrentTier = function() return EJ.tier end
EJ_SelectTier = function(t) EJ.tier = t end
EJ_GetLootFilter = function() return EJ.lootClass, EJ.lootSpec end
EJ_SetLootFilter = function(c, s) EJ.lootClass, EJ.lootSpec = c, s end
local INST = { [2] = { raid = { 1001 }, dungeon = { 2001 } }, [3] = { raid = { 1001 }, dungeon = { 2001, 2002 } }, [1] = { raid = { 9001 }, dungeon = {} } }
EJ_GetInstanceByIndex = function(i, isRaid) local l = INST[EJ.tier][isRaid and "raid" or "dungeon"]; local id = l[i]; if id then return id, "Instance " .. id end end
EJ_SelectInstance = function(jid) EJ.selected = jid end
local BOSSES = { [1001] = { { "Raid Boss", 501, 7001 } }, [2001] = { { "Dungeon Boss", 502, 7101 } }, [2002] = {}, [3001] = { { "Old Dungeon Boss", 503, 7201 } }, [9001] = { { "Very Old Boss", 504, 7301 } } }
EJ_GetEncounterInfoByIndex = function(i, jid) local b = (BOSSES[jid] or {})[i]; if b then return b[1], "d", b[2], b[3], "link", jid, 9000 + b[2], 1 end end
local SECTIONS = {
  [7001] = { spellID = 0, firstChildSectionID = 7002 },
  [7002] = { spellID = 1300001, siblingSectionID = 7003 },
  [7003] = { spellID = 1299000, firstChildSectionID = 7004, siblingSectionID = 7001 },   -- a loop back to the root: must not hang
  [7004] = { spellID = 1299001, siblingSectionID = 7502 },
  [7101] = { spellID = 1299100, siblingSectionID = 7102 },
  [7102] = { spellID = 1299101 },
  [7201] = { spellID = 600500 },
  [7301] = { spellID = 999999 },
}
for i = 2, 24 do SECTIONS[7500 + i] = { spellID = 1299000 + i, siblingSectionID = (i < 24) and (7501 + i) or nil } end
local LOOT = { [1001] = { { itemID = 40001 } }, [2001] = { { itemID = 40002 }, { itemID = "SECRET" } } }
C_EncounterJournal = {
  GetSectionInfo = function(id) return SECTIONS[id] end,
  GetSlotFilter = function() return EJ.slot end,
  SetSlotFilter = function(s) EJ.slot = s end,
  ResetSlotFilter = function() EJ.slot = 0 end,
  GetLootInfoByIndex = function(i) local l = LOOT[EJ.selected] or {}; return l[i] end,
  GetInstanceForGameMap = function(mapID) if mapID == 600 then return 3001 end; if mapID == 601 then return 2001 end end,
}
EJ_GetNumLoot = function() return #(LOOT[EJ.selected] or {}) end
C_ChallengeMode = {
  GetMapTable = function() return { 50, 51 } end,
  GetMapUIInfo = function(id) if id == 50 then return "Old Dungeon", 50, 1800, 1, 2, 600 end; return "New Dungeon", 51, 1900, 1, 2, 601 end,
  GetAffixInfo = function(id) if id == 9 then return "Bursting", "affix text", 1 end end,
}
C_MythicPlus = { GetCurrentAffixes = function() return { { id = 9, seasonID = 17 } } end, GetCurrentSeason = function() return 17 end }
-- item sets
GetNumClasses = function() return 2 end
GetClassInfo = function(c) if c == 1 then return "Warrior", "WARRIOR", 1 end; return "Paladin", "PALADIN", 2 end
GetNumSpecializationsForClassID = function(c) return c == 2 and 2 or 1 end
GetSpecializationInfoForClassID = function(c, i) if c == 1 then return 71 end; return ({ 65, 70 })[i] end
C_LootJournal = {
  GetItemSets = function(c, s) if c == 2 then return { { setID = 300, name = "Paladin Tier", itemLevel = 700 } } end; return {} end,
  GetItemSetItems = function(id) return { { itemID = 50001 }, { itemID = 50002 } } end,
}
C_Item = {
  GetSetBonusesForSpecializationByItemID = function(spec, item) if spec == 70 then return { 1300020 } end; return {} end,
  GetItemSpell = function(id) if id == 40001 then return "Trinket Proc", 1300010 end end,
  DoesItemExistByID = function(id) return id ~= 40002 end,
}
UnitExists = function(u) return u == "player" or u == "target" end
C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
  if unit == "player" and filter == "HELPFUL" and i == 1 then return { spellId = 1306161, name = "Divine Arbiter", sourceUnit = "player", duration = 30, applications = 25 } end
  if unit == "target" and filter == "HARMFUL" and i == 1 then return { spellId = 1300002, name = "Boss Smash", sourceUnit = "boss1", duration = 6, applications = 1 } end
end
CharacterStatsPane = mk()
XayaUIDevAssistDB = nil
assert(loadfile(__GD__))("XayaUI_DevAssist")
assert(loadfile(__API__))("XayaUI_DevAssist")
assert(loadfile(__CAT__))("XayaUI_DevAssist")
local GD = XayaUIDevAssist
check("catalogue and aura log are wired in", type(GD.CaptureCatalogue) == "function" and type(GD.SeenToggle) == "function")
-- the static scan's class spells (normally from /xuidump static)
GD.DB().static = { spells = { [1265790] = { n = "Boiling Point", d = "talent text" }, [1296661] = { n = "Divine Arbiter" } } }

-- refused in combat
COMBAT = true
SlashCmdList.XAYAUIDEV("catalogue")
check("refuses to start in combat", SAID("runs out of combat") ~= nil and not GD.Catalogue.running)
COMBAT = false

GD.Catalogue.testUpper = 1310000
SlashCmdList.XAYAUIDEV("catalogue")
check("starts and says what it reads", SAID("reading the Cooldown Manager") ~= nil and GD.Catalogue.running)
-- pause in combat halfway through the name scan, then carry on
PUMP(100)
COMBAT = true
PUMP(5)
local pausedAt = GD.Catalogue.next
check("pauses the name scan in combat", GD.Catalogue.paused == "scan", tostring(GD.Catalogue.paused))
PUMP(5)
check("  ...and reads nothing more while in combat", GD.Catalogue.next == pausedAt)
COMBAT = false
for _, f in ipairs(FRAMES) do if f.events.PLAYER_REGEN_ENABLED and f.onOnEvent then f.onOnEvent(f, "PLAYER_REGEN_ENABLED") end end
check("  ...and carries on when combat ends", GD.Catalogue.paused == nil)
PUMP(100000, true)
local c = XayaUIDevAssistDB.catalogue
check("finished and saved", type(c) == "table" and not GD.Catalogue.running and SAID("aura catalog done") ~= nil, SAID("aura catalog done"))   -- (FA-16: American spelling in what the player sees)
check("build recorded", c.build and c.build.build == "70783")
check("no character name or realm stored", not (function() local function walk(t, d) if d > 6 then return false end for k, v in pairs(t) do if v == "Xaya" or v == "Realm" or k == "Xaya" then return true end; if type(v) == "table" and walk(v, d + 1) then return true end end end return walk(XayaUIDevAssistDB, 0) end)())
-- 1) Cooldown Manager
check("cdm: entries per category, kept per spec", c.cdm.categories.TrackedBuff[1].spellID == 258920 and XayaUIDevAssistDB.catalogueCDM[581] ~= nil)
check("cdm: linked spell IDs are seeds", c.seeds[1300030] and c.seeds[1300030]:find("cdm-linked", 1, true))
check("cdm: a secret spell ID is not stored", c.cdm.categories.Essential[1] and c.cdm.categories.Essential[1].spellID == nil)
check("cdm: this spec recorded", c.spec.id == 581 and c.spec.class == "DEMONHUNTER")
-- 2) / 3) journal and Mythic+
check("journal: tier names, the two newest scanned", c.ej.tiers[3] == "Current Season" and #c.ej.scanned == 2 and c.ej.scanned[1] == 2 and c.ej.scanned[2] == 3)
check("journal: the oldest tier is not scanned", c.ej.instances[9001] == nil and not c.seeds[999999])
check("journal: raid boss abilities from the whole section tree (loop-safe)", c.seeds[1300001] and c.seeds[1299001] and c.seeds[1299024] and c.seeds[1300001]:find("raid", 1, true))
check("journal: dungeon boss abilities", c.seeds[1299100] and c.seeds[1299101] and c.seeds[1299101]:find("dungeon", 1, true))
check("journal: an instance in both tiers is read once", c.ej.instances[1001] and #c.ej.instances[1001].encounters == 1)
check("journal: loot item IDs (secret one skipped)", #c.ej.instances[2001].loot == 1 and c.ej.instances[2001].loot[1] == 40002)
check("mythic+: an older dungeon in the rotation is walked too", c.ej.instances[3001] and c.ej.instances[3001].why == "mplus" and c.seeds[600500] == "mplus")
check("mythic+: season maps with their journal instance", c.mplus.maps[50].journalInstanceID == 3001 and c.mplus.maps[51].name == "New Dungeon" and c.mplus.season == 17)
check("mythic+: a dungeon also in the newest tier is tagged both ways", c.ej.instances[2001].why:find("mplus", 1, true) and c.ej.instances[2001].why:find("dungeon", 1, true))
check("mythic+: this week's affixes", c.mplus.affixes[9] and c.mplus.affixes[9].name == "Bursting")
check("journal: the Adventure Guide's tier, loot filter and slot filter are put back", EJ.tier == 1 and EJ.lootClass == 7 and EJ.lootSpec == 66 and EJ.slot == 4)
-- 4) / 5) sets and items
check("sets: per class, with the spec's set-bonus spells", c.sets[300] and c.sets[300].classes.PALADIN and c.sets[300].bonus[70][1] == 1300020 and c.seeds[1300020])
check("items: the use / proc spell of a loot item", c.items[40001] and c.items[40001].spellID == 1300010 and c.seeds[1300010])
check("items: an item the game does not know is read without waiting", c.items[40002] == nil)
-- 6) / 7) names
check("class spells from the static scan are seeds", c.seeds[1265790] == "class" and c.usedStatic == true)
check("name scan: Boiling Point's two auras share the talent's name", c.matches[1265982] == "Boiling Point" and c.matches[1265968] == "Boiling Point")
check("name scan: Divine Arbiter's tier-set auras share the talent's name", c.matches[1306161] == "Divine Arbiter" and c.matches[1306162] == "Divine Arbiter")
check("name scan: boss debuff, item aura and set aura share their sources' names", c.matches[1300002] and c.matches[1300011] and c.matches[1300021])
check("name scan: an affix's aura matches the affix name", c.matches[1300050] == "Bursting")
check("name scan: an old ID with a current spell's name is found too", c.matches[100] == "Immolation Aura" and c.matches[258920] == nil)
check("name scan: an unrelated spell is not a match", c.matches[1300040] == nil)
check("name scan: a secret name is skipped", c.matches[1300070] == nil)
check("recent: cut-off = 5th percentile of the raid boss abilities (the older Mythic+ dungeon does not pull it down)", c.recent.from == 1299000 and c.recent.how:find("5th percentile of the raid", 1, true), tostring(c.recent.from) .. " " .. tostring(c.recent.how))
check("recent: every named ID from the cut-off is kept by name", c.recent.text:find("1300040=Unrelated New Spell", 1, true) and not c.recent.text:find("258920=", 1, true) and not c.recent.text:find("600500=", 1, true))
check("recent: separators in names are replaced", c.recent.text:find("1300060=A B C", 1, true) ~= nil)
-- 8) facts
check("facts: aura secrecy and Blizzard's flags", F(1265982).sec == 2 and F(1265982).flags == "imp" and F(1306161).flags == "pri" and F(1300002).flags == "cc", tostring(F(1265982).sec) .. " " .. tostring(F(1265982).flags))
check("facts: a secret secrecy value is not stored", c.facts[1300030] and F(1300030).sec == nil)
check("facts: descriptions loaded for matches", F(1265968).d == "desc of 1265968")
check("facts: class spells keep their facts in .static (not repeated)", c.facts[1296661] == nil)
check("summary counts", c.summary.matches >= 9 and c.summary.instances == 4 and c.summary.encounters == 3 and c.summary.scannedTo == 1310000, tostring(c.summary.matches) .. " " .. tostring(c.summary.instances) .. " " .. tostring(c.summary.encounters))
-- a hand-set cut-off, and 0 turns it off
GD.Catalogue.testUpper = 1310000
SlashCmdList.XAYAUIDEV("catalogue 0")
PUMP(100000, true)
check("catalogue 0: no recent list", XayaUIDevAssistDB.catalogue.recent.from == nil and XayaUIDevAssistDB.catalogue.recent.text == "")
-- second spec: the first spec's Cooldown Manager entries still feed the seeds
GetSpecializationInfo = function() return 577, "Havoc" end
C_CooldownViewer.GetCooldownViewerCategorySet = function() return {} end
SlashCmdList.XAYAUIDEV("catalogue")
PUMP(100000, true)
check("another spec: both specs kept, the first spec's links still seeds", XayaUIDevAssistDB.catalogueCDM[577] and XayaUIDevAssistDB.catalogueCDM[581] and XayaUIDevAssistDB.catalogue.seeds[1300030])

-- aura log
SlashCmdList.XAYAUIDEV("seen")
local s = XayaUIDevAssistDB.seen
check("aura log: on, reads what is up now (your buff, the target's debuff)", s and s.auras[1306161] and s.auras[1306161].on.you and s.auras[1306161].maxStacks == 25 and s.auras[1306161].buff and s.auras[1300002].debuff and s.auras[1300002].from.other)
local logf
for _, f in ipairs(FRAMES) do if f.events.UNIT_AURA then logf = f end end
logf.onOnEvent(logf, "UNIT_AURA", "player", { addedAuras = { { spellId = 1265982, name = "Boiling Point", sourceUnit = "player", isHelpful = true, duration = 15, applications = 0 } } })
check("aura log: a new aura out of combat", s.auras[1265982] and s.auras[1265982].buff and s.auras[1265982].dur == 15 and s.auras[1265982].from.you)
logf.onOnEvent(logf, "UNIT_AURA", "party1", { addedAuras = { { spellId = "SECRET", name = "SECRET" } } })
check("aura log: a secret aura is counted, not stored", s.hidden == 1)
COMBAT = true
logf.onOnEvent(logf, "UNIT_AURA", "player", { addedAuras = { { spellId = 1300011, name = "Trinket Proc" } } })
check("aura log: nothing read in combat", s.auras[1300011] == nil)
COMBAT = false
logf.onOnEvent(logf, "PLAYER_REGEN_ENABLED")
check("aura log: what is still up is read when combat ends", s.auras[1306161].c >= 2)
logf.onOnEvent(logf, "UNIT_AURA", "nameplate3", { addedAuras = { { spellId = 1300040, name = "x" } } })
check("aura log: other units ignored", s.auras[1300040] == nil)
SlashCmdList.XAYAUIDEV("seen")
check("aura log: off says how many", SAID("aura log OFF") ~= nil)
SlashCmdList.XAYAUIDEV("status")
check("status mentions the catalogue and the aura log", said[#said]:find("catalog:", 1, true) ~= nil and said[#said]:find("aura log:", 1, true) ~= nil, said[#said])
io.write(("%d checks, %d failed\n"):format(n, fails))
'''.replace("__GD__", P("XayaUI_DevAssist/DevAssist.lua")).replace("__API__", P("XayaUI_DevAssist/ApiInventory.lua")).replace("__CAT__", P("XayaUI_DevAssist/AuraCatalogue.lua")))
sys.exit(1 if lua.eval("fails") else 0)
