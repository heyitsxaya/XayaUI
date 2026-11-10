-- Stand-in game world for the character window tests (the Stat Calculator, Improved Character Display, the Character Reskin;
-- tests/char_statcalc_run.py, tests/char_statcalc2_run.py and the other char_* tests). Lua 5.1.
-- Every number here is a TEST STAND-IN (Xaya's Vengeance screenshot figures where she gave them, made-up values elsewhere); none of it
-- ships. Frames record what the addon does to them (points, sizes, text, colors, shown state, scripts, hooks) so the tests can
-- assert what the player would see.
fails, n = 0, 0
function check(name, cond, extra)
  n = n + 1
  if not cond then fails = fails + 1; print("FAIL: " .. name .. (extra ~= nil and ("  -> " .. tostring(extra)) or ""))
  else print("ok:   " .. name) end
end

-- frames -----------------------------------------------------------------------------------------------------------------------
function mk(kind)
  local o = { kind = kind, shown = false, pts = {}, scripts = {}, hooks = {}, events = {}, id = 0 }
  return setmetatable(o, { __index = function(t, k)
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local F = {
      Show = function(self) self.shown = true; if self.hooks.OnShow then for _, f in ipairs(self.hooks.OnShow) do f(self) end end end,
      Hide = function(self) self.shown = false; if self.hooks.OnHide then for _, f in ipairs(self.hooks.OnHide) do f(self) end end end,
      IsShown = function(self) return self.shown end,
      SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
      SetScript = function(self, s, f) self.scripts[s] = f end,
      GetScript = function(self, s) return self.scripts[s] end,
      HookScript = function(self, s, f) self.hooks[s] = self.hooks[s] or {}; table.insert(self.hooks[s], f) end,
      RegisterEvent = function(self, e) self.events[e] = true end, RegisterUnitEvent = function(self, e) self.events[e] = true end,
      UnregisterAllEvents = function(self) self.events = {} end,
      CreateTexture = function() return mk("Texture") end,
      CreateFontString = function() local f = mk("FS"); f.text = ""; f.font = { "Fonts\\FRIZQT__.TTF", 12, "" }; return f end,
      SetText = function(self, s) self.text = s end, GetText = function(self) return self.text end,
      SetFont = function(self, p, s, fl) self.font = { p, s, fl }; return true end,
      GetFont = function(self) local f = self.font or { "Fonts\\FRIZQT__.TTF", 12, "" }; return f[1], f[2], f[3] end,
      SetTextColor = function(self, r, g, b, a) self.color = { r, g, b, a } end,
      SetColorTexture = function(self, r, g, b, a) self.color = { r, g, b, a } end,
      GetStringHeight = function(self) return (self.font and self.font[2]) or 12 end,
      GetHeight = function(self) return self.h or 0 end, SetHeight = function(self, h) self.h = h end,
      SetWidth = function(self, w) self.w = w end, GetWidth = function(self) return self.w or 0 end,
      SetSize = function(self, w, h) self.w, self.h = w, h end, GetCenter = function() return 0, 0 end,
      SetPoint = function(self, ...) table.insert(self.pts, { ... }) end, ClearAllPoints = function(self) self.pts = {} end,
      GetVerticalScroll = function() return 0 end, GetChildren = function(self) return unpack(self.children or {}) end,
      IsOwned = function(self, f) return self.owner == f end,
      SetOwner = function(self, f) self.owner = f; self.lines = {} end,
      AddLine = function(self, s) self.lines = self.lines or {}; table.insert(self.lines, s) end,
      AddDoubleLine = function(self, a, b) self.lines = self.lines or {}; table.insert(self.lines, a .. " | " .. b) end,
      GetID = function(self) return self.id end, SetID = function(self, i) self.id = i end,
      GetFrameLevel = function() return 1 end,
      HasFocus = function(self) return self.focus == true end, IsMouseOver = function() return false end,
      Insert = function(self, s) self.text = (self.text or "") .. s end,
    }
    return F[k] or function() end
  end })
end
created = {}
CreateFrame = function(kind, name, parent) local f = mk(kind); f.parent = parent; if name then _G[name] = f end; created[#created + 1] = f; return f end
-- fire an event at every frame that registered it (as the game does)
function fire(event, ...) for _, f in ipairs(created) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end end end
UIParent = mk("Frame")
GameTooltip = mk("GameTooltip")
C_Timer = { After = function(_, fn) fn() end }
combat = false
InCombatLockdown = function() return combat end
hooksecurefunc = function(a, b, c)   -- hooksecurefunc("Global", fn) or hooksecurefunc(table, "key", fn), as in the game
  local t, key, fn = _G, a, b
  if type(a) == "table" then t, key, fn = a, b, c end
  local old = t[key]
  t[key] = function(...) local r = { old(...) }; fn(...); return unpack(r) end
end
STAT_CRITICAL_STRIKE, STAT_MASTERY, STAT_PARRY, SPELL_STAT3_NAME = "Critical Strike", "Mastery", "Parry", "Stamina"
SPELL_STAT1_NAME, SPELL_STAT2_NAME, SPELL_STAT4_NAME = "Strength", "Agility", "Intellect"
STAT_HASTE, STAT_VERSATILITY, STAT_ARMOR, STAT_DODGE, STAT_BLOCK = "Haste", "Versatility", "Armor", "Dodge", "Block"
HEADSLOT, FINGER0SLOT = "Head", "Finger"
ATTACK_POWER_MAGIC_NUMBER = 3.5   -- stand-in for the value in Blizzard's PaperDollFrame.lua

-- secrets: a stand-in secret number. type() says "number" (as the game does for a secret number), and ANY comparison, arithmetic,
-- concatenation, tostring or length on it counts as misuse and errors, so a test sees it.
misuse = 0
SECRET = setmetatable({}, {})
local function bad() misuse = misuse + 1; error("secret value misused", 2) end
for _, mm in ipairs({ "__lt", "__le", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__concat", "__len", "__call", "__tostring", "__index" }) do
  getmetatable(SECRET)[mm] = bad
end
local rawtype = type
type = function(v) if rawequal(v, SECRET) then return "number" end; return rawtype(v) end
issecretvalue = function(v) return rawequal(v, SECRET) end

-- game reads (VDH-like numbers from Xaya's screenshot: 528 crit = 11.48%, 997 mastery, 1,287 haste in a later one)
RATE = 1 / 46
function dr(x) local lin = x * RATE; if lin <= 30 then return lin end; return 30 + (lin - 30) * 0.9 end
ratings = { [9] = 528, [18] = 1200, [26] = 997, [29] = 120, [31] = 120, [21] = 0, [17] = 0, [14] = 0, [4] = 0, [3] = 0 }
GetCombatRating = function(i) return ratings[i] or 0 end
GetCombatRatingBonus = function(i) if i == 4 then return 0 end; if i == 31 then return dr(ratings[i]) / 2 end; return dr(ratings[i] or 0) end
GetCombatRatingBonusForCombatRatingValue = function(i, v) if i == 31 then return dr(v) / 2 end; if i == 4 then return v / 52 end; return dr(v) end
GetCritChance = function() return 22.48 end
GetRangedCritChance = function() return 5 end
GetSpellCritChance = function() return 5 end
GetHaste = function() return 29.25 end
-- (QoL 0.7.39, UI-63 / UI-64: the GCD rule reads the class; the game always has it) a Demon Hunter: a 1.5 s GCD that haste shortens
if UnitClass == nil then UnitClass = function(u) if u == "player" then return "Demon Hunter", "DEMONHUNTER", 12 end end end
GetMeleeHaste = function() return 29.25 end
GetMasteryEffect = function() return 88.69, 2.8 end
GetVersatilityBonus = function() return 0 end
GetAvoidance = function() return 0 end
GetLifesteal = function() return 13.61 end
GetSpeed = function() return 0 end
GetDodgeChance = function() return 16.52 end
GetParryChance = function() return 14.01 end
GetBlockChance = function() return 0 end
GetDodgeChanceFromAttribute = function() return 5 end
GetParryChanceFromAttribute = function() return 0 end
GetCritChanceProvidesParryEffect = function() return true end
UnitStat = function(_, i) local v = ({ 1000, 2637, 69647, 900 })[i]; return v, v, 0, 0 end
UnitHPPerStamina = function() return 20 end
GetUnitMaxHealthModifier = function() return 1.06 end
UnitHealthMax = function() return 1476516 end
UnitArmor = function() return 5685, 5685, 5685, 0 end
UnitEffectiveLevel = function() return 90 end
C_PaperDollInfo = { GetArmorEffectiveness = function(a, lvl) return a / (a + 12000) end, OffhandHasShield = function() return false end }
UnitAttackPower = function() return 3472, 0, 0 end
GetAttackPowerForStat = function(i, v) return v end
UnitAttackSpeed = function() return 2.0, 2.01 end
UnitDamage = function() return 8138.2, 8944.6, 0, 0, 0, 0, 1 end
C_SpecializationInfo = {
  GetSpecialization = function() return 2 end,
  GetSpecializationInfo = function() return 581, "Vengeance", "", 0, "TANK", 2 end,
  GetSpecializationMasterySpells = function() return { 203747 } end,
}
GetSpellBonusDamage = function() return 500 end
C_Spell = {
  GetSpellName = function(id) if id == 263642 then return "Fracture" elseif id == 203747 then return "Fel Blood" end end,
  GetSpellInfo = function(x) if x == "Fracture" then return { spellID = 263642, name = "Fracture" } end end,
  GetSpellDescription = function(id)
    if id == 203747 then return "Increases Armor by 101.8% of your Agility." end
    return "Rapidly slash your target for 6,944 Physical damage, and shatter 2 Lesser Soul Fragments. Generates 25 Fury. 15% more."
  end,
  GetSpellCooldown = function() return { startTime = 1, duration = 1.16, isActive = true } end,
}
GetAverageItemLevel = function() return 335.5, 334.25, 330 end
GetUnitSpeed = function() return 0, 7, 21, 4.9 end
BASE_MOVEMENT_SPEED = 7
UnitSpellHaste = function() return 29.25 end
GetRangedHaste = function() return 29.25 end
GetPowerRegen = function() return 0, 0 end
UnitPowerType = function() return 17, "FURY" end
GetOverrideAPBySpellPower = function() return 0 end
GetShieldBlock = function() return 0 end
UnitRangedDamage = function() return 0, 0, 0 end
GEAR = { [1] = "|cffa335ee|Hitem:1::::::::90:::::|h[Helm]|h|r", [11] = "|cffa335ee|Hitem:2:7000:::::::90:::::|h[Ring]|h|r" }
GetInventoryItemLink = function(_, slot) return GEAR[slot] end
DUR = { [1] = { 78, 100 }, [11] = { 100, 100 } }
GetInventoryItemDurability = function(slot) local d = DUR[slot]; if d then return d[1], d[2] end end
ITEMS = {
  Helm = { ilvl = 336, loc = "INVTYPE_HEAD", stats = { ITEM_MOD_CRIT_RATING_SHORT = 300, ITEM_MOD_HASTE_RATING_SHORT = 200, ITEM_MOD_AGILITY_SHORT = 500 } },
  Ring = { ilvl = 330, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_CRIT_RATING_SHORT = 100, ITEM_MOD_MASTERY_RATING_SHORT = 400, EMPTY_SOCKET_PRISMATIC = 1 } },
  Glaive = { ilvl = 330, loc = "INVTYPE_WEAPON", class = 2, stats = {} },      -- an off-hand weapon (Enum.ItemClass.Weapon = 2)
  Frill = { ilvl = 330, loc = "INVTYPE_HOLDABLE", class = 4, stats = {} },      -- held in off hand (Armor = 4)
  ["Better Helm"] = { ilvl = 346, loc = "INVTYPE_HEAD", stats = { ITEM_MOD_CRIT_RATING_SHORT = 400, ITEM_MOD_MASTERY_RATING_SHORT = 100,
    ITEM_MOD_AGILITY_SHORT = 600, ITEM_MOD_STAMINA_SHORT = 900, RESISTANCE0_NAME = 500 } },
}
local function itemOf(link) local name = type(link) == "string" and link:match("%[(.-)%]"); return name and ITEMS[name] end
loadRequests = {}
C_Item = {
  GetDetailedItemLevelInfo = function(link) local it = itemOf(link); return it and it.ilvl end,
  GetItemStats = function(link) local it = itemOf(link); if it then local t = {}; for k, v in pairs(it.stats) do t[k] = v end; return t end end,
  GetItemInfoInstant = function(link) local it = itemOf(link); if it then return 1, "Armor", "Leather", it.loc, 0, it.class or 4, 0 end end,
  GetItemInfo = function(id) if id == 3 then return "Better Helm", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r" end end,
  RequestLoadItemDataByID = function(id) table.insert(loadRequests, id) end,
}
-- sockets (QoL 0.7.19): an item's socket count is its stat table's EMPTY_SOCKET_ count (the stand-in follows the INFERENCE that the
-- table lists every socket, filled or not); GEMS[item name][socket] = gem item ID puts a gem in it; GEM_INFO the gem's icon and name
GEMS, GEM_INFO = {}, {}
C_Item.GetItemNumSockets = function(link)
  local it = itemOf(link); if not it then return 0 end
  local n = 0
  for k, v in pairs(it.stats) do if k:find("^EMPTY_SOCKET_") then n = n + v end end
  return n
end
C_Item.GetItemGemID = function(link, i) local name = type(link) == "string" and link:match("%[(.-)%]"); local g = name and GEMS[name]; return g and g[i] or nil end
C_Item.GetItemIconByID = function(id) local g = GEM_INFO[id]; return g and g.icon end
C_Item.GetItemGem = function(link, i)
  local id = C_Item.GetItemGemID(link, i); local g = id and GEM_INFO[id]
  if g then return g.name, "|cffa335ee|Hitem:" .. id .. "::::::::90:::::|h[" .. g.name .. "]|h|r" end
end
REPAIR = { [1] = 12345 }
C_TooltipInfo = { GetInventoryItem = function(_, slot) return { lines = {}, repairCost = REPAIR[slot] } end }
GetRepairAllCost = function() return 12345, true end
C_PlayerInfo = { GetPlayerMythicPlusRatingSummary = function() return { currentSeasonScore = 2450.6, runs = {
  { challengeModeID = 501, mapScore = 285.4, bestRunLevel = 12, bestRunDurationMS = 1, finishedSuccess = true },
  { challengeModeID = 502, mapScore = 310.0, bestRunLevel = 13, bestRunDurationMS = 1, finishedSuccess = false } } } end }
C_ChallengeMode = {
  GetMapUIInfo = function(id) return ({ [501] = "Dungeon A", [502] = "Dungeon B" })[id], id, 1800 end,
  GetOverallDungeonScore = function() return 1999 end,
}
C_MythicPlus = { RequestMapInfo = function() mythicRequested = true end, GetSeasonBestMythicRatingFromThisExpansion = function() return 2600, 15 end }
LARGE_NUMBER_SEPERATOR, DECIMAL_SEPERATOR = ",", "."

-- the character window's item slot buttons (names from Blizzard's PaperDollFrame.xml; IDs as the game sets them)
for _, s in ipairs({ { "HeadSlot", 1 }, { "NeckSlot", 2 }, { "Finger0Slot", 11 }, { "Finger1Slot", 12 }, { "SecondaryHandSlot", 17 } }) do
  local b = mk("ItemButton"); b.id = s[2]; _G["Character" .. s[1]] = b
end
function PaperDollItemSlotButton_Update(btn) end
ChatFrameUtil = { InsertLink = function(link) return false end }   -- the game's shift-click link insert (Blizzard UI code)
function PaperDollFrame_UpdateStats() end

printed = {}
ns = { Print = function(...) table.insert(printed, table.concat({ ... }, " ")) end }
CueRulesDB = {}

-- helpers for the tests
function row(model, key) for _, r in ipairs(model) do if r.key == key then return r end end end
function has(r, pat) for _, l in ipairs(r and r.lines or {}) do if l:find(pat, 1, true) then return true end end; return false end
function pair(it, label) for _, p in ipairs(it and it.pairs or {}) do if p.label == label then return p.value, p.tone end end end
function tipHas(it, pat) for _, l in ipairs(it and it.tip or {}) do if l:find(pat, 1, true) then return true end end; return false end

-- (character pane split stage 2: QoL 0.7.53 / Bonus 0.6.37; V25 R2) the old one-table settings are in two places now: the Stat
-- Calculator panel's keys in XayaUI Bonus Features (ns.StatCalc_Cfg, XayaUI_Bonus/StatCalculator.lua), the slot overlays', the
-- tooltip lines' and the Stat Calc button's in XayaUI QoL's Improved Character Display (ns.CharDisplay_Cfg, XayaUI_QoL/
-- ImprovedCharacterDisplay.lua); each has its own switch `enabled`. The tests written before the split set them up as one table:
-- CWC() is that table (reads and writes each key in its half; `enabled` is written to both and read from the panel's), CWA() applies
-- both halves, CWPage() is the two settings pages as one (the QoL page's parts and the Bonus page's, in one args table). TEST HELPERS
-- only: the game has no such joined table.
CW_QOL = { tooltips = true, overlays = true, ovIlvl = true, ovSockets = true, ovEnchants = true, ovSize = true, enchantSlots = true, enchantSlotsSet = true,
  statCalcButton = true }
function CWC()
  local p = ns.StatCalc_Cfg and ns.StatCalc_Cfg()
  local q = ns.CharDisplay_Cfg and ns.CharDisplay_Cfg()
  if not (p or q) then return nil end
  return setmetatable({}, {
    __index = function(_, k) if CW_QOL[k] then return q and q[k] end; if p then return p[k] end; return q and q[k] end,
    __newindex = function(_, k, v)
      if k == "enabled" then
        if p then p[k] = v end
        -- (V25 R2) the old shared switch showed no item details: as the one-time merge does for a player who had only it on, switching
        -- it on from off starts the item level / enchants / gems / full stat list parts off (a test that wants them sets them after
        -- this, or switches Improved Character Display on first: RC().features)
        if q then
          if v and not q.enabled then q.ilvl, q.enchants, q.gems, q.statList = false, false, false, false end
          q[k] = v
        end
      elseif CW_QOL[k] then if q then q[k] = v end
      elseif p then p[k] = v end
    end })
end
function CWA()
  if ns.CharDisplay_Apply then ns.CharDisplay_Apply() end
  if ns.StatCalc_Apply then ns.StatCalc_Apply() end
end
function CWPage(notify)
  local a = ns.BuildStatCalcPage and ns.BuildStatCalcPage(notify) or { args = {} }
  local b = ns.BuildCharDisplayPage and ns.BuildCharDisplayPage(notify) or { args = {} }
  local out = { name = a.name, xuiSwitch = a.xuiSwitch, childGroups = a.childGroups, type = a.type, args = {} }
  for k, v in pairs(b.args or {}) do out.args[k] = v end
  for k, v in pairs(a.args or {}) do out.args[k] = v end
  return out
end

-- (V25 R2) the Character Reskin's look (ns.CharReskin_Cfg, XayaUI_QoL/CharacterReskin.lua) and Improved Character Display
-- (ns.CharDisplay_Cfg, XayaUI_QoL/ImprovedCharacterDisplay.lua) as one table, for the tests written while both were one file: a look key
-- goes to the look, `features` (the old QoL > Character Pane switch) to Improved Character Display's switch, every other key to Improved
-- Character Display. RSA() applies both. TEST HELPERS only: the game has no such joined table.
RS_LOOK = { enabled = true, chrome = true, stats = true, wide = true, widePx = true, bgAlpha = true, tallPx = true, widePxTo42 = true }
function RC()
  return setmetatable({}, {
    __index = function(_, k)
      if RS_LOOK[k] then local l = ns.CharReskin_Cfg and ns.CharReskin_Cfg(); return l and l[k] end
      local d = ns.CharDisplay_Cfg and ns.CharDisplay_Cfg()
      if k == "features" then return d and d.enabled end
      return d and d[k]
    end,
    __newindex = function(_, k, v)
      if RS_LOOK[k] then local l = ns.CharReskin_Cfg and ns.CharReskin_Cfg(); if l then l[k] = v end; return end
      local d = ns.CharDisplay_Cfg and ns.CharDisplay_Cfg()
      if not d then return end
      if k == "features" then d.enabled = v else d[k] = v end
    end })
end
function RSA()
  if ns.CharReskin_Apply then ns.CharReskin_Apply() end
  if ns.CharDisplay_Apply then ns.CharDisplay_Apply() end
end

-- (V25 own-data standard) what Improved Character Display drew on a slot button and what the Character Reskin made on a tab, stat
-- category or stat row live in the addon's own weak tables keyed by Blizzard's frame (never fields on it): read only, an empty table
-- when nothing was made
function SD_(b) local f = ns.CharDisplay_SlotData; return (f and b and f(b)) or {} end
function RX_(fr) local f = ns.CharReskin_Extra; return (f and fr and f(fr)) or {} end
