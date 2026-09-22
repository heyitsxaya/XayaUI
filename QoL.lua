-------------------------------------------------------------------------------
-- QoL.lua : quality-of-life elements. Currently: customizable stats text boxes.
--
-- Format string uses {tokens}, e.g. "Crit {crit}  Haste {haste}". Standard WoW
-- color escapes (|cffRRGGBB...|r) also work inside the format.
--
-- Midnight note: patch 12.0.5 made player-stat APIs return SECRET values while
-- auras are restricted (combat / M+ / encounters). We never try to read those.
-- When a stat is secret we keep showing its last readable value (from outside
-- restriction); if it was never readable it shows "?".
-------------------------------------------------------------------------------
local addonName, ns = ...

local function num(v) if type(v) == "number" and not ns.IsSecret(v) then return v end end

-- kind: pct = percentage, int = whole number, dec = one decimal
ns.QOL_STATS = {
    crit      = { kind = "pct", desc = "Critical strike %",  fn = function() return GetCritChance() end },
    haste     = { kind = "pct", desc = "Haste %",            fn = function() return GetHaste() end },
    mastery   = { kind = "pct", desc = "Mastery %",          fn = function() return (GetMasteryEffect()) end },
    vers      = { kind = "pct", desc = "Versatility % (damage done)", fn = function()
                    local a, b = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE), GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
                    if num(a) == nil or num(b) == nil then return nil end
                    return a + b end },
    leech     = { kind = "pct", desc = "Leech %",            fn = function() return GetLifesteal() end },
    avoidance = { kind = "pct", desc = "Avoidance %",        fn = function() return GetAvoidance() end },
    dodge     = { kind = "pct", desc = "Dodge %",            fn = function() return GetDodgeChance() end },
    parry     = { kind = "pct", desc = "Parry %",            fn = function() return GetParryChance() end },
    block     = { kind = "pct", desc = "Block %",            fn = function() return GetBlockChance() end },
    ilvl      = { kind = "dec", desc = "Equipped item level", fn = function() local _, eq = GetAverageItemLevel(); return eq end },
    armor     = { kind = "int", desc = "Armor",              fn = function() local _, eff = UnitArmor("player"); return eff end },
    str       = { kind = "int", desc = "Strength",           fn = function() local _, eff = UnitStat("player", 1); return eff end },
    agi       = { kind = "int", desc = "Agility",            fn = function() local _, eff = UnitStat("player", 2); return eff end },
    sta       = { kind = "int", desc = "Stamina",            fn = function() local _, eff = UnitStat("player", 3); return eff end },
    int       = { kind = "int", desc = "Intellect",          fn = function() local _, eff = UnitStat("player", 4); return eff end },
    hp        = { kind = "int", desc = "Max health",         fn = function() return UnitHealthMax("player") end },
    absorb    = { kind = "int", desc = "Total absorb (shield) on you", fn = function() return UnitGetTotalAbsorbs("player") end },
}
ns.QOL_STAT_ORDER = { "crit", "haste", "mastery", "vers", "leech", "avoidance", "dodge", "parry", "block",
    "ilvl", "armor", "str", "agi", "sta", "int", "hp", "absorb" }

local cache = {} -- token -> last readable text

local function Render(box)
    local decs = math.max(0, math.min(2, box.decimals or 1))
    local text = (box.format or ""):gsub("{(%w+)}", function(key)
        local s = ns.QOL_STATS[key:lower()]
        if not s then return "{" .. key .. "}" end
        local ok, v = pcall(s.fn)
        v = ok and num(v) or nil
        if v then
            local txt
            if s.kind == "pct" then txt = ("%." .. decs .. "f"):format(v) .. "%"
            elseif s.kind == "dec" then txt = ("%.1f"):format(v)
            else txt = ("%d"):format(math.floor(v + 0.5)) end
            cache[key:lower()] = txt
            return txt
        end
        return cache[key:lower()] or "?"
    end)
    return text
end
ns.QoL_Preview = Render

local OUTLINE = { none = "", outline = "OUTLINE", thick = "THICKOUTLINE" }
local frames = setmetatable({}, { __mode = "k" })

local function GetFrame(box)
    local fr = frames[box]
    if fr then return fr end
    fr = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    fr:SetFrameStrata("MEDIUM")
    fr:SetClampedToScreen(true)
    fr:SetMovable(true)
    fr:RegisterForDrag("LeftButton")
    fr.fs = fr:CreateFontString(nil, "OVERLAY")
    fr.fs:SetFontObject(GameFontNormal)
    fr.fs:SetPoint("CENTER")
    fr:SetScript("OnDragStart", function(self) if ns.unlocked then self:StartMoving() end end)
    fr:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        local s = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
        box.x = math.floor((cx * s - ux) + 0.5)
        box.y = math.floor((cy * s - uy) + 0.5)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", box.x, box.y)
        if ns.OnPositionChanged then ns.OnPositionChanged(box) end
    end)
    frames[box] = fr
    return fr
end

function ns.QoL_Refresh(box)
    local fr = GetFrame(box)
    fr:ClearAllPoints()
    fr:SetPoint("CENTER", UIParent, "CENTER", box.x or 0, box.y or 0)
    fr:SetAlpha(box.alpha or 1)
    pcall(fr.fs.SetFont, fr.fs, ns.FontPath(box.font), box.size or 14, OUTLINE[box.outline or "outline"] or "OUTLINE")
    local c = box.color or { 1, 1, 1, 1 }
    fr.fs:SetTextColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    fr.fs:SetJustifyH(ns.Val(box.justify) or "LEFT")
    fr.fs:SetText(Render(box))
    fr:SetSize(math.max(20, fr.fs:GetStringWidth() + 10), math.max(14, fr.fs:GetStringHeight() + 8))
    fr:EnableMouse(ns.unlocked)
    if ns.unlocked then
        fr:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        fr:SetBackdropBorderColor(0.2, 0.8, 1, 1)
    else
        fr:SetBackdrop(nil)
    end
    local show = box.enabled and ns.QoLOn()
    if show and not ns.unlocked and not ns.Ignored(box.showCombat) then
        local inCombat = (UnitAffectingCombat("player") or InCombatLockdown()) and true or false
        show = (box.showCombat == "yes") == inCombat
    end
    fr:SetShown(show and true or false)
end

-- master switch (the tick box on the "Stat Tracking" sidebar row); on unless explicitly turned off
function ns.QoLOn()
    local t = CueRulesDB and CueRulesDB.qol
    return not (t and t.enabled == false)
end

function ns.QoL_RefreshAll()
    for _, b in ipairs(ns.qolBoxes or {}) do ns.QoL_Refresh(b) end
end

function ns.QoL_Drop(box)
    local fr = frames[box]
    if fr then fr:Hide(); frames[box] = nil end
end

function ns.QoL_NewBox()
    local b = ns.Copy(ns.QOL_BOX_DEFAULTS)
    b.name = "Stats " .. (#ns.qolBoxes + 1)
    b.y = b.y - (#ns.qolBoxes * 40)
    ns.qolBoxes[#ns.qolBoxes + 1] = b
    ns.QoL_Refresh(b)
    return b
end

function ns.QoL_OnDBReady() ns.QoL_RefreshAll() end

local f = CreateFrame("Frame")
for _, e in ipairs({
    "PLAYER_ENTERING_WORLD", "COMBAT_RATING_UPDATE", "MASTERY_UPDATE", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED",
}) do pcall(f.RegisterEvent, f, e) end
pcall(f.RegisterUnitEvent, f, "UNIT_STATS", "player")
local dirty, acc = true, 0
f:SetScript("OnEvent", function() dirty = true end)
f:SetScript("OnUpdate", function(_, e)
    acc = acc + e
    if dirty or acc >= 0.5 then
        dirty, acc = false, 0
        if ns.qolBoxes then ns.QoL_RefreshAll() end
    end
end)
