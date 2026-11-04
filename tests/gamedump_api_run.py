# Stub test for XayaUI_GameDump 0.4.0 ApiInventory.lua: /xuidump api (API inventory) and /xuidump toolkit (Character Toolkit checks)
# run against stand-in game calls. It checks that both captures run without errors, record what exists, skip secret values, and that
# the item-level variant scan keeps only links the (stand-in) game produced. Nothing here is game data; the numbers are made up.
# Run from the repo root: python3 tests/gamedump_api_run.py   Needs: pip install lupa.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
fails, n = 0, 0
function check(name, cond, extra) n = n + 1; if not cond then fails = fails + 1; print("FAIL: " .. name .. (extra ~= nil and ("  -> " .. tostring(extra)) or "")) else print("ok:   " .. name) end end
local said = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end
local function mk()
  local o = {}
  local methods = { Hide = function() end, Show = function() end, SetScript = function() end, RegisterEvent = function() end, UnregisterEvent = function() end,
    SetIgnoreParentAlpha = function() end, SetPoint = function() end }
  methods.CreateTexture = function() return setmetatable({}, { __index = { SetTexture = function() end, SetColorTexture = function() end } }) end
  methods.CreateFontString = function() return setmetatable({}, { __index = { SetText = function() end, SetFont = function() end } }) end
  methods.CreateLine = function() return setmetatable({}, { __index = { SetThickness = function() end } }) end
  methods.CreateAnimationGroup = function() return setmetatable({}, { __index = { Play = function() end } }) end
  return setmetatable(o, { __index = methods })
end
CreateFrame = function() return mk() end
date = function() return "2026-11-04 03:00" end
GetTime = function() return 100 end
issecretvalue = function(v) return v == "SECRET" end
InCombatLockdown = function() return false end
GetBuildInfo = function() return "12.1.5", "70688", "Oct 31 2026", 120105 end
C_Timer = { After = function() end }
UISpecialFrames = {}
tinsert = table.insert
SlashCmdList = {}
CR_CRIT_MELEE, MAX_SPELL_SCHOOLS, BASE_MOVEMENT_SPEED = 9, 7, 7
SECRET_CONSTANT = "SECRET"
Enum = { ItemCreationContext = { None = 0, RaidNormal = 3, RaidHeroic = 5, RaidMythic = 6, DungeonMythic = 16 },
         SpellBookSpellBank = { Player = 0, Pet = 1 } }
Constants = { TraitConsts = { VIEW_TRAIT_CONFIG_ID = -3 } }
GetHaste = function() return 31.84 end
GetSpellBaseCooldown = function(id) if id == 100 then return 0, 1500 end; if id == 101 then return 8000, 1500 end end
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return 2 end,
  GetSpellBookSkillLineInfo = function(i) if i == 1 then return { itemIndexOffset = 0, numSpellBookItems = 2, isGuild = false } end
    return { itemIndexOffset = 2, numSpellBookItems = 1, isGuild = false, offSpecID = 577 } end,
  GetSpellBookItemInfo = function(j) return ({ { spellID = 100, name = "Shear", isPassive = false }, { spellID = 101, name = "Sigil", isPassive = false }, { spellID = 999, name = "OffSpec", isPassive = false } })[j] end,
}
C_Spell = { GetSpellCooldown = function() return { startTime = "SECRET", duration = 1.14, isActive = true } end }
GetInventoryItemDurability = function(slot) if slot == 1 then return 78, 100 end; if slot == 5 then return 100, 100 end end
C_TooltipInfo = {
  GetInventoryItem = function(_, slot) if slot == 1 then return { repairCost = 2345, hyperlink = "|Hitem:500::::|h[Helm]|h", lines = {} } end; if slot == 5 then return { lines = {} } end end,
  GetItemByID = function(id, q, ctx) return { hyperlink = "|Hitem:" .. id .. "::::::::90:::" .. ctx .. "|h[Helm]|h", lines = { { leftText = "Helm" } } } end,
}
GetRepairAllCost = function() error("not at a vendor") end
GetInventoryItemLink = function(_, slot) if slot == 1 then return "|cffa335ee|Hitem:500:7000:213:0:0:0:0:0:90|h[Helm]|h|r" end end
C_Item = {
  GetDelvePreviewItemLink = function(id, ctx) if ctx == 0 then return nil end; return "|Hitem:" .. id .. "::::::::90:::" .. ctx .. "|h[Helm]|h" end,
  GetDetailedItemLevelInfo = function(link) local ctx = tonumber(link:match(":(%d+)|h")) or 0; return ({ [3] = 636, [5] = 649, [6] = 662, [16] = 649 })[ctx] or 600 end,
  GetItemStats = function(link) if link:find(":7000:213:") then return { ITEM_MOD_CRIT_RATING_SHORT = 400, ITEM_MOD_AGILITY_SHORT = 500 } end
    return { ITEM_MOD_CRIT_RATING_SHORT = 300, ITEM_MOD_AGILITY_SHORT = 500 } end,
}
C_ChallengeMode = { GetOverallDungeonScore = function() return 3806 end }
CharacterStatsPane = mk()
XayaUIGameDumpDB = nil
assert(loadfile(__GD__))("XayaUI_GameDump")
assert(loadfile(__API__))("XayaUI_GameDump")
local GD = XayaUIGameDump
check("captures are wired into the addon", type(GD.CaptureAPI) == "function" and type(GD.ProbeToolkit) == "function")
check("/xuidump api and toolkit are commands", SlashCmdList.XAYAUIDUMP ~= nil)

-- API inventory
SlashCmdList.XAYAUIDUMP("api")
local api = XayaUIGameDumpDB.api
check("api: saved", type(api) == "table")
local hasFn = {}
for _, k in ipairs(api.globals) do hasFn[k] = true end
check("api: legacy globals listed (GetSpellBaseCooldown, GetInventoryItemDurability)", hasFn.GetSpellBaseCooldown and hasFn.GetInventoryItemDurability)
check("api: global names sorted", (function() for i = 2, #api.globals do if api.globals[i - 1] > api.globals[i] then return false end end return true end)())
check("api: C_ namespaces with their functions", api.namespaces.C_Item and (function() for _, f in ipairs(api.namespaces.C_Item) do if f == "GetDelvePreviewItemLink" then return true end end end)())
check("api: enums with values (ItemCreationContext.RaidMythic = 6)", api.enums.ItemCreationContext and api.enums.ItemCreationContext.RaidMythic == 6)
check("api: numeric constants (CR_CRIT_MELEE = 9)", api.numbers.CR_CRIT_MELEE == 9)
check("api: secret values skipped", api.numbers.SECRET_CONSTANT == nil)
check("api: Constants tables copied", api.constants.TraitConsts and api.constants.TraitConsts.VIEW_TRAIT_CONFIG_ID == -3)
check("api: widget methods listed", api.widgets.Frame and #api.widgets.Frame > 0 and api.widgets.Texture and api.widgets.FontString)
check("api: build recorded", api.build.build == "70688" and api.build.toc == 120105)
check("api: counts said in chat", (function() for _, s in ipairs(said) do if s:find("API inventory:", 1, true) then return true end end end)())

-- Character Toolkit checks
SlashCmdList.XAYAUIDUMP("toolkit")
local p = XayaUIGameDumpDB.toolkitProbe
check("toolkit: saved", type(p) == "table")
check("toolkit: base cooldowns read for the current spec's spells only (off-spec line skipped)", #p.baseCooldowns == 2 and p.baseCooldowns[1].gcdMS == 1500 and p.baseCooldowns[2].cdMS == 8000)
check("toolkit: GCD spell fields, secret ones marked", p.gcdSpell.duration == 1.14 and p.gcdSpell.startTime == "SECRET" and p.gcdSpell.isActive == true)
check("toolkit: repair cost read where the game gives it", p.slots[1].repairCost == 2345 and p.slots[5].repairCost == nil)
check("toolkit: tooltip-data keys listed per slot", p.slots[1].tooltipKeys and #p.slots[1].tooltipKeys >= 2)
check("toolkit: GetRepairAllCost away from a vendor recorded as not available", p.repairAll == "not available here")
check("toolkit: preview links per context, nil contexts left out", #p.variants == 4 and p.variantItemID == 500)
check("toolkit: distinct item levels listed (636, 649, 662)", table.concat(p.variantLevels, ",") == "636,649,662", table.concat(p.variantLevels or {}, ","))
check("toolkit: tooltip-by-context route sampled", type(p.tooltipByContext) == "table" and next(p.tooltipByContext) ~= nil)
check("toolkit: stats with and without gems/enchant compared", p.statsWithGems.ITEM_MOD_CRIT_RATING_SHORT == 400 and p.statsBare.ITEM_MOD_CRIT_RATING_SHORT == 300)
check("toolkit: bare link has enchant and gems emptied", p.statsBareLink:find("|Hitem:500::::::0:0:90|h", 1, true) ~= nil, p.statsBareLink)
check("toolkit: stat pane, SetIgnoreParentAlpha, Mythic+ score", p.CharacterStatsPane == true and p.SetIgnoreParentAlpha == true and p.mplusScore == 3806)
check("toolkit: rating constants", p.CR.CR_CRIT_MELEE == 9)
SlashCmdList.XAYAUIDUMP("status")
check("status mentions api and toolkit captures", said[#said]:find("api: 2026-11-04 03:00", 1, true) ~= nil and said[#said]:find("toolkit checks: 2026-11-04 03:00", 1, true) ~= nil, said[#said])
io.write(("%d checks, %d failed\n"):format(n, fails))
'''.replace("__GD__", P("XayaUI_GameDump/GameDump.lua")).replace("__API__", P("XayaUI_GameDump/ApiInventory.lua")))
sys.exit(1 if lua.eval("fails") else 0)
