-------------------------------------------------------------------------------
-- Tooltips.lua : tooltip modifiers for XayaUI (sibling addon). Written from the documented game API only.
--   1. ID lines: spell, item, aura, NPC, quest, currency, achievement, mount, toy, battle pet (+ optional icon ID)
--   2. Item level of the player under the mouse (yourself: equipped; others: Inspect, cached)
--   3. Enemy forces (Mythic+ count and percent) on hostile units, read live from the game
-- Not here yet: crowd control, true sight, and casts need an enemy database that does not exist.
--
-- Midnight (12.x): guarded APIs return SECRET values for units whose identity is restricted. Every read is pcall'd and checked with
-- issecretvalue; a value that can not be read is skipped, never guessed.
--
-- Sources (warcraft.wiki.gg): Tooltip_API, Struct_TooltipData, Enum.TooltipDataType, GUID, API_C_Spell.GetSpellTexture,
-- API_GetAverageItemLevel, API_NotifyInspect, API_C_PaperDollInfo.GetInspectItemLevel, API_C_ScenarioInfo.GetUnitCriteriaProgressValues.
-------------------------------------------------------------------------------
local addonName, ns = ...
-- With XayaUI loaded, share its namespace (the XayaUI_NS bridge from Core.lua, same as XayaUI_CombatEngine); otherwise run alone.
local integrated = _G.XayaUI_NS ~= nil
ns = _G.XayaUI_NS or ns
ns.TT = ns.TT or {}
local TT = ns.TT
TT.integrated = integrated

local isSecret = issecretvalue or function() return false end
local function readable(v) return v ~= nil and not isSecret(v) end

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------
TT.DEFAULTS = {
    ids = { enabled = true, spell = true, item = true, aura = true, npc = true, icon = false,
            quest = false, currency = false, achievement = false, mount = false, toy = false, battlepet = false },
    ilvl = { enabled = true, inspect = true, cacheSecs = 120 },
    forces = { enabled = true, onlyInDungeon = true, onlyMythicPlus = false },
}

local function fill(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            fill(dst[k], v)
        elseif dst[k] == nil then dst[k] = v end
    end
end

-- Saved data: XayaUI's CueRulesDB.tooltips when integrated, XayaUITooltipsDB.tooltips alone. Call after login.
function TT.DB()
    local root
    if integrated then CueRulesDB = CueRulesDB or {}; root = CueRulesDB
    else XayaUITooltipsDB = XayaUITooltipsDB or {}; root = XayaUITooltipsDB end
    root.tooltips = root.tooltips or {}
    fill(root.tooltips, TT.DEFAULTS)
    return root.tooltips
end

-- key = settings key, enum = Enum.TooltipDataType member, label = text on the tooltip line, name = options label
TT.ID_KINDS = {
    { key = "spell",       enum = "Spell",       label = "Spell ID",       name = "Spell IDs" },
    { key = "item",        enum = "Item",        label = "Item ID",        name = "Item IDs" },
    { key = "aura",        enum = "UnitAura",    label = "Aura ID",        name = "Aura IDs (buffs and debuffs)" },
    { key = "quest",       enum = "Quest",       label = "Quest ID",       name = "Quest IDs" },
    { key = "currency",    enum = "Currency",    label = "Currency ID",    name = "Currency IDs" },
    { key = "achievement", enum = "Achievement", label = "Achievement ID", name = "Achievement IDs" },
    { key = "mount",       enum = "Mount",       label = "Mount ID",       name = "Mount IDs" },
    { key = "toy",         enum = "Toy",         label = "Toy ID",         name = "Toy IDs" },
    { key = "battlepet",   enum = "BattlePet",   label = "Battle pet ID",  name = "Battle pet IDs" },
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function AddLine(tooltip, left, right)
    tooltip:AddDoubleLine(left, right, 1, 0.82, 0, 1, 1, 1)   -- label in the game's normal gold, value in white
end

-- Creature and Vehicle GUIDs: unitType-0-serverID-instanceID-zoneUID-npcID-spawnUID (wiki: GUID); the NPC id is field 6.
local function NpcIDFromGUID(guid)
    if type(guid) ~= "string" or not readable(guid) then return nil end
    local ok, unitType, _, _, _, _, id = pcall(strsplit, "-", guid)
    if ok and (unitType == "Creature" or unitType == "Vehicle") then return tonumber(id) end
end

-- Icon file id for a spell or aura (C_Spell.GetSpellTexture, first return) or an item. The wiki lists C_Item.GetItemIconByID only as a
-- redirect to C_Item.GetItemIcon, so each spelling is tried; pcall absorbs a wrong one.
local function IconID(kind, id)
    local ok, icon = pcall(function()
        if kind == "spell" or kind == "aura" then
            return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        elseif kind == "item" then
            if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
            if GetItemIcon then return GetItemIcon(id) end
            if C_Item and C_Item.GetItemIcon then return C_Item.GetItemIcon(id) end
        end
    end)
    if ok and readable(icon) and type(icon) == "number" then return icon end
end

-------------------------------------------------------------------------------
-- 1. ID lines (TooltipData.id, documented on Struct_TooltipData)
-------------------------------------------------------------------------------
function TT.OnIDData(tooltip, data, kind)
    local db = TT.DB()
    if not db.ids.enabled or not db.ids[kind.key] or type(data) ~= "table" then return end
    local id = data.id
    if not readable(id) or type(id) ~= "number" then return end
    AddLine(tooltip, kind.label .. ":", tostring(id))
    if db.ids.icon then
        local icon = IconID(kind.key, id)
        if icon then AddLine(tooltip, "Icon ID:", tostring(icon)) end
    end
end

-------------------------------------------------------------------------------
-- 2. Item level on hover
-------------------------------------------------------------------------------
local cache = {}        -- guid -> { ilvl, t }
local pending           -- the one inspect request in flight: { guid, unit, t }
local lastAsk = 0
local retryAfter = {}   -- guid -> earliest time to ask again after a failure

local function Now() return GetTime and GetTime() or 0 end

-- NotifyInspect keeps the client polling that player until ClearInspectPlayer (wiki: API_NotifyInspect), so always release,
-- except while the Inspect window is open, which owns the request then.
local function Release()
    if ClearInspectPlayer and not (InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()) then pcall(ClearInspectPlayer) end
end

local function MayInspect(unit)
    if InCombatLockdown and InCombatLockdown() then return false end
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then return false end
    local ok, can = pcall(CanInspect, unit)
    return ok and can and true or false
end

function TT.IlvlLine(tooltip, unit)
    local db = TT.DB()
    if not db.ilvl.enabled then return end
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok or not readable(isPlayer) or not isPlayer then return end

    if UnitIsUnit(unit, "player") then                               -- yourself: the second return is the EQUIPPED average (wiki)
        local _, equipped = GetAverageItemLevel()
        if readable(equipped) then AddLine(tooltip, "Item level:", ("%.1f"):format(equipped)) end
        return
    end
    if not db.ilvl.inspect then return end
    local okg, guid = pcall(UnitGUID, unit)
    if not okg or not readable(guid) then return end

    local now, hit = Now(), cache[guid]
    if hit and now - hit.t <= db.ilvl.cacheSecs then
        AddLine(tooltip, "Item level:", ("%.1f"):format(hit.ilvl))
        return
    end
    if pending and now - pending.t < 3 then return end              -- one request at a time
    if pending then pending = nil; Release() end                     -- the last one never answered (the server throttles silently)
    if now - lastAsk < 1.5 or (retryAfter[guid] or 0) > now then return end
    if not MayInspect(unit) then return end
    pending, lastAsk, retryAfter[guid] = { guid = guid, unit = unit, t = now }, now, now + 30
    pcall(NotifyInspect, unit)
    if hit then AddLine(tooltip, "Item level:", ("%.1f (old)"):format(hit.ilvl)) end
end

function TT.OnInspectReady(guid)
    if not pending or pending.guid ~= guid then return end            -- not our request (the Inspect window, another addon): leave it
    local unit = pending.unit
    pending = nil
    local ok, ilvl = pcall(function() return C_PaperDollInfo.GetInspectItemLevel(unit) end)
    if ok and readable(ilvl) and type(ilvl) == "number" and ilvl > 0 then
        cache[guid] = { ilvl = ilvl, t = Now() }
        retryAfter[guid] = nil
        if GameTooltip and GameTooltip:IsShown() and GameTooltip.RefreshData then pcall(GameTooltip.RefreshData, GameTooltip) end
    end
    Release()
end

-------------------------------------------------------------------------------
-- 3. Enemy forces on hostile units (C_ScenarioInfo.GetUnitCriteriaProgressValues: count, percent, percentString)
-------------------------------------------------------------------------------
local function ForcesInScope(f)
    if f.onlyMythicPlus then
        return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() and true or false
    end
    if f.onlyInDungeon then
        local inInstance, kind = IsInInstance()
        return inInstance and (kind == "party" or kind == "raid") and true or false
    end
    return true
end

function TT.ForcesLine(tooltip, unit)
    local f = TT.DB().forces
    if not f.enabled or not ForcesInScope(f) then return end
    local okc, canAttack = pcall(UnitCanAttack, "player", unit)
    if not okc or not readable(canAttack) or not canAttack then return end
    local okp, isPlayer = pcall(UnitIsPlayer, unit)
    if okp and readable(isPlayer) and isPlayer then return end
    local ok, count, pct = pcall(function() return C_ScenarioInfo.GetUnitCriteriaProgressValues(unit) end)
    if ok and readable(count) and readable(pct) and type(count) == "number" and type(pct) == "number" then
        AddLine(tooltip, "Enemy forces:", ("%.1f%% (%d)"):format(pct, count))
    end
end

-------------------------------------------------------------------------------
-- Unit tooltips + hooks
-------------------------------------------------------------------------------
function TT.OnUnitData(tooltip, data)
    if tooltip ~= GameTooltip then return end                         -- the post-call fires for every tooltip (wiki); units only matter here
    local unit = "mouseover"
    local okg, _, u = pcall(tooltip.GetUnit, tooltip)
    if okg and readable(u) and u then unit = u end
    local guid = type(data) == "table" and data.guid or nil           -- TooltipData.guid (Unit), may be secret
    if not readable(guid) then
        local okq, g = pcall(UnitGUID, unit)
        guid = okq and g or nil
    end
    local db = TT.DB()
    if db.ids.enabled and db.ids.npc then
        local npc = NpcIDFromGUID(guid)
        if npc then AddLine(tooltip, "NPC ID:", tostring(npc)) end
    end
    pcall(TT.IlvlLine, tooltip, unit)
    pcall(TT.ForcesLine, tooltip, unit)
end

local hooked
function TT.Init()
    if hooked then return end
    if type(TooltipDataProcessor) ~= "table" or type(TooltipDataProcessor.AddTooltipPostCall) ~= "function" then return end
    if type(Enum) ~= "table" or type(Enum.TooltipDataType) ~= "table" then return end
    hooked = true
    for _, kind in ipairs(TT.ID_KINDS) do
        local t = Enum.TooltipDataType[kind.enum]
        if t then TooltipDataProcessor.AddTooltipPostCall(t, function(tooltip, data) pcall(TT.OnIDData, tooltip, data, kind) end) end
    end
    if Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data) pcall(TT.OnUnitData, tooltip, data) end)
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("INSPECT_READY")
    f:SetScript("OnEvent", function(_, _, guid) TT.OnInspectReady(guid) end)
end

-------------------------------------------------------------------------------
-- /xuitt probe: what can this client read on the unit under the mouse?
-------------------------------------------------------------------------------
function TT.Probe()
    local function P(...) print("|cff9966ffXayaUI Tooltips|r", ...) end
    local unit = "mouseover"
    if not UnitExists(unit) then
        P("Point at a unit, then run it from a macro or: /run C_Timer.After(3, function() SlashCmdList.XUITT('probe') end)")
        return
    end
    local function show(v) if v == nil then return "nil" elseif isSecret(v) then return "SECRET" else return tostring(v) end end
    local function try(label, fn)
        local ok, a, b, c = pcall(fn)
        if not ok then P(label, "ERROR", tostring(a)) else P(label, show(a), b ~= nil and show(b) or "", c ~= nil and show(c) or "") end
    end
    try("UnitGUID", function() return UnitGUID(unit) end)
    local okg, guid = pcall(UnitGUID, unit)
    P("NPC ID from GUID", okg and tostring(NpcIDFromGUID(guid)) or "unreadable")
    try("UnitCanAttack", function() return UnitCanAttack("player", unit) end)
    try("UnitIsPlayer", function() return UnitIsPlayer(unit) end)
    try("Enemy forces (count, percent)", function() return C_ScenarioInfo.GetUnitCriteriaProgressValues(unit) end)
    try("CanInspect", function() return CanInspect(unit) end)
    P("IsInInstance type / M+ active", tostring((select(2, IsInInstance()))),
      tostring(C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()))
end
