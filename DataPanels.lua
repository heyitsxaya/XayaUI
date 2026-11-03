-------------------------------------------------------------------------------
-- DataPanels.lua : "Custom Data Panels and Bars" (tab under QoL UI Updates).
-- On-screen info strips, each showing 1-20 data slots. All of it is on the General tab as sections that open when switched on
-- (the chat's own bar, the Chat Bar, belongs to Chat Panel: QoL UI Updates > Chat Panel):
--   bl      Left Panel     (bottom-left corner of the screen)
--   br      Right Panel    (bottom-right corner)
--   center  Center Panel   (bottom center; any anchor, drag to move, or full screen width)
--   cpN     Custom Panels  (as many as you add: free anchor, drag to move, horizontal or vertical; stored in db.customs)
-- Older settings: Top Data Bar became the Center Panel; an enabled Custom Panel / Custom Bar became custom panels (originals kept in db.legacy).
-- Data types = what the Chat Bar offers (time, FPS, latency, gold, durability, bag slots, custom text) plus the stat set of the
-- old stat boxes (crit, haste, mastery, versatility, ilvl, ...). Every slot of every strip can show any of them.
-- Each slot is a block: its own gaps, alignment, text scale, background and text color, plus "auto sized" or "even split" rows and
-- "fill remaining space" blocks (settings under "Blocks" on every strip's page; layout and slot look live in DataBlocks.lua).
-- Own code, written from the option set only (no third-party addon code or data). UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local B = ns.DataBlocks      -- DataBlocks.lua: the block engine shared with the Chat Bar (Chat/Bar.lua)
local MAXSLOTS = B.MAXN
local FIXED = { "bl", "br", "center" }
local TITLES = { bl = "Left Panel", br = "Right Panel", center = "Center Panel" }
local MAX_CUSTOM = 12
local ANCHORS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local function num(v) if type(v) == "number" and not (ns.IsSecret and ns.IsSecret(v)) then return v end end

-------------------------------------------------------------------------------
-- data types
-------------------------------------------------------------------------------
local DT = { list = {}, by = {} }
ns.DataText = DT

-- def = { label = "Crit" (optional prefix), text = function(cfg, slotIndex) -> string, tip = function(cfg, slotIndex) -> { title, line, ... } }
function DT.Register(key, name, group, def)
    def.key, def.name, def.group = key, name, group
    if not DT.by[key] then DT.list[#DT.list + 1] = def end
    DT.by[key] = def
end

DT.Register("NONE", "(empty)", "General", { text = function() return "" end })
DT.Register("CUSTOM", "Custom text", "General", { text = function(cfg, i) return cfg["text" .. i] or "" end })
DT.Register("TIME", "Time", "General", {
    text = function(cfg)
        local h, m
        if cfg.localTime == false and GetGameTime then h, m = GetGameTime() else h, m = tonumber(date("%H")), tonumber(date("%M")) end
        if cfg.clock24 == false then
            local suffix = h >= 12 and "pm" or "am"
            h = h % 12; if h == 0 then h = 12 end
            return ("%d:%02d %s"):format(h, m, suffix)
        end
        return ("%02d:%02d"):format(h, m)
    end,
    tip = function() return { "Time", date("%A %d %B") } end,
})
DT.Register("FPS", "Frame rate", "General", { usage = true, tip = function() return { "Frame rate", ("%d fps"):format(math.floor((GetFramerate and GetFramerate() or 0) + 0.5)) } end, text = function() return ("%d fps"):format(math.floor((GetFramerate and GetFramerate() or 0) + 0.5)) end })
DT.Register("LATENCY", "Latency", "General", {
    usage = true,
    text = function() local _, _, home, world = GetNetStats(); return ("%d ms"):format(world or home or 0) end,
    tip = function() local _, _, home, world = GetNetStats(); return { "Latency", ("Home: %d ms"):format(home or 0), ("World: %d ms"):format(world or 0) } end,
})
DT.Register("GOLD", "Gold", "General", {
    text = function()
        local g = math.floor((GetMoney and GetMoney() or 0) / 10000)
        return (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or tostring(g)) .. "|cffffd100g|r"
    end,
    tip = function() return { "Gold", GetCoinTextureString and GetCoinTextureString(GetMoney() or 0) or "" } end,
})
DT.Register("DURABILITY", "Durability", "General", {
    label = "Dur",
    text = function()
        local lowest
        for slot = 1, 18 do
            if slot ~= 4 then
                local cur, max = GetInventoryItemDurability(slot)
                if cur and max and max > 0 then
                    local pct = cur / max * 100
                    if not lowest or pct < lowest then lowest = pct end
                end
            end
        end
        if not lowest then return "--" end
        local c = lowest < 25 and "|cffff4040" or (lowest < 50 and "|cffffd100" or "|cff40ff40")
        return ("%s%d%%|r"):format(c, math.floor(lowest + 0.5))
    end,
    tip = function() return { "Durability", "Shows your most damaged equipped piece." } end,
})
DT.Register("BAGS", "Free bag slots", "General", {
    label = "Bags",
    text = function()
        local free, total = 0, 0
        for bag = 0, (_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
            if C_Container and C_Container.GetContainerNumFreeSlots then
                free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
                total = total + ((C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or 0)
            end
        end
        return ("%d/%d"):format(free, total)
    end,
})

-- stats (values can be secret in restricted content: the last readable value is kept, "?" if never readable)
local STATS = {
    { "crit", "Crit", "pct", function() return GetCritChance() end },
    { "haste", "Haste", "pct", function() return GetHaste() end },
    { "mastery", "Mastery", "pct", function() return (GetMasteryEffect()) end },
    { "vers", "Versatility", "pct", function()
        local a, b = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE), GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
        if num(a) == nil or num(b) == nil then return nil end
        return a + b end },
    { "leech", "Leech", "pct", function() return GetLifesteal() end },
    { "avoidance", "Avoidance", "pct", function() return GetAvoidance() end },
    { "dodge", "Dodge", "pct", function() return GetDodgeChance() end },
    { "parry", "Parry", "pct", function() return GetParryChance() end },
    { "block", "Block", "pct", function() return GetBlockChance() end },
    { "ilvl", "Item Level", "dec", function() local _, eq = GetAverageItemLevel(); return eq end },
    { "armor", "Armor", "int", function() local _, eff = UnitArmor("player"); return eff end },
    { "str", "Strength", "int", function() local _, eff = UnitStat("player", 1); return eff end },
    { "agi", "Agility", "int", function() local _, eff = UnitStat("player", 2); return eff end },
    { "sta", "Stamina", "int", function() local _, eff = UnitStat("player", 3); return eff end },
    { "int", "Intellect", "int", function() local _, eff = UnitStat("player", 4); return eff end },
    { "hp", "Max Health", "int", function() return UnitHealthMax("player") end },
    { "absorb", "Absorb (shield)", "int", function() return UnitGetTotalAbsorbs("player") end },
}
local statCache = {}
for _, s in ipairs(STATS) do
    local key, name, kind, fn = s[1], s[2], s[3], s[4]
    DT.Register("STAT_" .. key, name, "Stats", {
        label = name,
        text = function(cfg)
            local ok, v = pcall(fn)
            v = ok and num(v) or nil
            if v then
                local decs = math.max(0, math.min(2, tonumber(cfg.decimals) or 1))
                local txt
                if kind == "pct" then txt = ("%." .. decs .. "f%%"):format(v)
                elseif kind == "dec" then txt = ("%.1f"):format(v)
                else txt = BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(v + 0.5)) or ("%d"):format(math.floor(v + 0.5)) end
                statCache[key] = txt
                return txt
            end
            return statCache[key] or "?"
        end,
    })
end

local function TypeValues()
    local values, order = {}, {}
    for _, d in ipairs(DT.list) do
        values[d.key] = (d.group == "General" and d.name) or (d.group .. ": " .. d.name)
        order[#order + 1] = d.key
    end
    return values, order
end

-------------------------------------------------------------------------------
-- settings
-------------------------------------------------------------------------------
local function Def(over)
    local d = {
        enabled = false, slots = 3, slot1 = "TIME", slot2 = "FPS", slot3 = "LATENCY",
        widthMode = "FIXED", width = 300, margin = 0, height = 22,
        anchor = "BOTTOMLEFT", x = 0, y = 0,
        growth = "H", justify = "CENTER",
        bg = true, bgR = 0, bgG = 0, bgB = 0, bgAlpha = 45,   -- "Backdrop Transparency" = lower alpha
        border = true, borderR = 0, borderG = 0, borderB = 0,
        textR = 1, textG = 1, textB = 1, labelR = 0.7, labelG = 0.7, labelB = 0.7,
        showLabels = true, decimals = 1, clock24 = true, localTime = true, textA = 100, borderA = 100,   -- alpha in percent
        strata = "LOW", level = 1,
        tipAnchor = "TOP", tipX = 0, tipY = 4,
        mouseover = false, hideInCombat = false, visibility = "",
        locked = true, movable = false,
        sizing = "EVEN", hoverHL = false, blocks = {},   -- per-block settings: blocks[i] = { gapL, gapR, fill, align, scale, bgOn, bgR/G/B/A, textOn, tR/G/B }
    }
    for k, v in pairs(over or {}) do d[k] = v end
    for i = 1, MAXSLOTS do d["text" .. i] = d["text" .. i] or "" end
    return d
end
ns.DATAPANEL_DEFAULTS = {
    general = { enabled = false, font = "none", outline = "OUTLINE", size = 13, blockCombatClick = false, blockCombatHover = false },   -- enabled = master switch
    bl = Def({ anchor = "BOTTOMLEFT", width = 400, slot1 = "GOLD", slot2 = "DURABILITY", slot3 = "BAGS" }),
    br = Def({ anchor = "BOTTOMRIGHT", width = 400, slot1 = "TIME", slot2 = "FPS", slot3 = "LATENCY" }),
    center = Def({ anchor = "BOTTOM", width = 400, movable = true, slot1 = "TIME", slot2 = "FPS", slot3 = "LATENCY" }),
    customs = {}, customNext = 1,   -- customs["cp1"] = { ...a strip..., name = "..." }
}
local function CustomDef() return Def({ anchor = "CENTER", width = 260, movable = true, name = "Custom Panel", slot1 = "STAT_crit", slot2 = "STAT_haste", slot3 = "STAT_mastery" }) end

local function DB() return ns.dataPanelDB end
local function Cfg(key) local db = DB(); return db and (db[key] or (db.customs and db.customs[key])) end
local function AllKeys()
    local out = { unpack(FIXED) }
    local db = DB()
    if db and db.customs then
        local c = {}
        for k in pairs(db.customs) do c[#c + 1] = k end
        table.sort(c, function(a, b) return (tonumber(a:match("%d+")) or 0) < (tonumber(b:match("%d+")) or 0) end)
        for _, k in ipairs(c) do out[#out + 1] = k end
    end
    return out
end
function ns.DataPanels_MasterOn() local db = DB(); return db and db.general and db.general.enabled and true or false end

function ns.DataPanels_OnDBReady()
    CueRulesDB.dataPanels = CueRulesDB.dataPanels or {}
    local dp = CueRulesDB.dataPanels
    dp.customs = dp.customs or {}
    -- 0.5.47: Top Data Bar, Custom Panel and Custom Bar were folded into Center Panel and the custom panels list. The old tables are kept in dp.legacy.
    if dp.top or dp.panel or dp.bar then
        dp.legacy = dp.legacy or {}
        if dp.top then
            dp.legacy.top = dp.top
            if dp.center == nil then dp.center = ns.Copy(dp.top) end
            dp.top = nil
        end
        for _, k in ipairs({ "panel", "bar" }) do
            if dp[k] then
                dp.legacy[k] = dp[k]
                if dp[k].enabled then
                    local n = dp.customNext or 1
                    dp.customNext = n + 1
                    dp.customs["cp" .. n] = ns.Copy(dp[k])
                    dp.customs["cp" .. n].name = (k == "bar") and "Custom Bar" or "Custom Panel"
                end
                dp[k] = nil
            end
        end
    end
    -- the master switch is new: a profile that already has a strip turned on keeps it on
    if dp.general and dp.general.enabled == nil then
        for _, k in ipairs({ "bl", "br", "center" }) do if type(dp[k]) == "table" and dp[k].enabled then dp.general.enabled = true; break end end
        for _, c in pairs(dp.customs) do if type(c) == "table" and c.enabled then dp.general.enabled = true; break end end
        if ns.chatDB and (ns.chatDB.panelOn or ns.chatDB.rpanelOn) then dp.general.enabled = true end   -- a chat info bar counts too
    end
    ns.Merge(dp, ns.DATAPANEL_DEFAULTS)
    for _, c in pairs(dp.customs) do if type(c) == "table" then ns.Merge(c, CustomDef()) end end   -- custom panels get any setting added since they were made
    ns.dataPanelDB = CueRulesDB.dataPanels
end

-------------------------------------------------------------------------------
-- frames
-------------------------------------------------------------------------------
local frames = {}   -- key -> { f = frame, slots = {} }
local OUTLINES = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }


-- one block's setting; unset values fall back to the strip's own settings (Text Justify = the default alignment) and to B.DEF
local BLOCK_FALLBACK = { gapL = 4, gapR = 4 }
local function BGet(cfg, i, f)
    local b = cfg.blocks and cfg.blocks[i]
    if b and b[f] ~= nil then return b[f] end
    if f == "align" then return cfg.justify or "CENTER" end
    if BLOCK_FALLBACK[f] ~= nil then return BLOCK_FALLBACK[f] end
    return B.DEF[f]
end
local function BSet(cfg, i, f, v)
    cfg.blocks = cfg.blocks or {}
    cfg.blocks[i] = cfg.blocks[i] or {}
    cfg.blocks[i][f] = v
end

local function Over(f)
    if not f then return false end
    if f.IsMouseOver then local ok, v = pcall(f.IsMouseOver, f); if ok then return v and true or false end end
    return MouseIsOver and MouseIsOver(f) and true or false
end

local function InCombat() return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) end

local function SlotText(cfg, i)
    local d = DT.by[cfg["slot" .. i] or "NONE"] or DT.by.NONE
    local ok, v = pcall(d.text, cfg, i)
    if not ok then return "?" end
    v = tostring(v or "")
    if cfg.showLabels and d.label and v ~= "" then
        return ("|cff%02x%02x%02x%s|r %s"):format(math.floor((cfg.labelR or 0.7) * 255 + 0.5), math.floor((cfg.labelG or 0.7) * 255 + 0.5), math.floor((cfg.labelB or 0.7) * 255 + 0.5), d.label, v)
    end
    return v
end

local Layout   -- defined below
local function UpdateText(key)
    local e, cfg = frames[key], Cfg(key)
    if not (e and cfg and e.f:IsShown()) then return end
    local n = math.max(1, math.min(MAXSLOTS, tonumber(cfg.slots) or 1))
    for i = 1, n do e.slots[i].fs:SetText(SlotText(cfg, i)) end
    if cfg.sizing == "AUTO" then Layout(key) end   -- block widths follow the text
end

function Layout(key)
    local e, cfg = frames[key], Cfg(key)
    if not (e and cfg) then return end
    local n = math.max(1, math.min(MAXSLOTS, tonumber(cfg.slots) or 1))
    B.Layout(e.f, e.slots, { n = n, vert = cfg.growth == "V", sizing = cfg.sizing, get = function(i, f) return BGet(cfg, i, f) end })
end

local function PointPos(fr, p)
    local l, r, t, b = fr:GetLeft(), fr:GetRight(), fr:GetTop(), fr:GetBottom()
    if not (l and r and t and b) then return end
    local x = p:find("LEFT") and l or (p:find("RIGHT") and r or (l + r) / 2)
    local y = p:find("TOP") and t or (p:find("BOTTOM") and b or (t + b) / 2)
    return x, y
end

local function OpenSettings() if ns.DataPanels_OpenSettings then ns.DataPanels_OpenSettings() end end

local function Build(key)
    if frames[key] then return frames[key] end
    local f = CreateFrame("Frame", "XayaUIDataPanel_" .. key, UIParent, "BackdropTemplate")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    local e = { f = f, slots = {} }
    frames[key] = e
    f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        local cfg = Cfg(key)
        if cfg and cfg.movable and not cfg.locked and cfg.widthMode ~= "SCREEN" and not InCombat() then self:StartMoving(); e.moving = true end
    end)
    f:SetScript("OnDragStop", function(self)
        if not e.moving then return end
        e.moving = false
        self:StopMovingOrSizing()
        local cfg = Cfg(key); if not cfg then return end
        local fx, fy = PointPos(self, cfg.anchor)
        local ux, uy = PointPos(UIParent, cfg.anchor)
        if fx and ux then cfg.x, cfg.y = math.floor(fx - ux + 0.5), math.floor(fy - uy + 0.5) end
        ns.DataPanels_Refresh(key)
        if ns.DataPanels_Changed then ns.DataPanels_Changed() end
    end)
    f:SetScript("OnMouseUp", function(_, b) if b == "RightButton" then OpenSettings() end end)
    for i = 1, MAXSLOTS do
        local s = B.MakeSlot(f)
        s:RegisterForClicks("RightButtonUp")
        s:RegisterForDrag("LeftButton")
        s:SetScript("OnDragStart", function() local sc = f:GetScript("OnDragStart"); if sc then sc(f) end end)
        s:SetScript("OnDragStop", function() local sc = f:GetScript("OnDragStop"); if sc then sc(f) end end)
        s:SetScript("OnClick", function(_, b)
            local g = DB() and DB().general or {}
            if g.blockCombatClick and InCombat() then return end
            if b == "RightButton" then OpenSettings() end
        end)
        local function ShowTip(self)
            local cfg = Cfg(key)
            if not cfg then return end
            local d = DT.by[cfg["slot" .. i] or "NONE"] or DT.by.NONE
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:ClearAllPoints()
            local a = cfg.tipAnchor or "TOP"
            GameTooltip:SetPoint(a, self, (a:find("TOP") and "BOTTOM") or (a:find("BOTTOM") and "TOP") or a, cfg.tipX or 0, cfg.tipY or 4)
            local lines
            if d.tip then local ok, r = pcall(d.tip, cfg, i); if ok then lines = r end end
            lines = lines or { d.name }
            GameTooltip:SetText(lines[1] or "")
            for n = 2, #lines do GameTooltip:AddLine(lines[n], 1, 1, 1) end
            if d.usage and B.AddUsage then
                local ok, err = pcall(B.AddUsage, GameTooltip, 8)
                if not ok then GameTooltip:AddLine("Addon usage unavailable: " .. tostring(err), 1, 0.4, 0.4) end
            end
            GameTooltip:AddLine("Right-click: panel settings", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end
        s:SetScript("OnEnter", function(self)
            local cfg, g = Cfg(key), (DB() and DB().general or {})
            if not cfg or (g.blockCombatHover and InCombat()) then return end
            ShowTip(self)
            local d = DT.by[cfg["slot" .. i] or "NONE"] or DT.by.NONE
            if d.usage then   -- the CPU numbers move: redraw once a second while the mouse is on the block
                local t = 0
                self:SetScript("OnUpdate", function(f, dt)
                    t = t + dt
                    if t < 1 then return end
                    t = 0
                    if InCombat() then f:SetScript("OnUpdate", nil); GameTooltip:Hide(); return end
                    if GameTooltip:IsOwned(f) then ShowTip(f) else f:SetScript("OnUpdate", nil) end
                end)
            end
        end)
        s:SetScript("OnLeave", function(self) self:SetScript("OnUpdate", nil); GameTooltip:Hide() end)
        e.slots[i] = s
    end
    return e
end

local function Style(key, cfg)
    local e, g = frames[key], (DB() and DB().general or {})
    local f = e.f
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(cfg.bgR or 0, cfg.bgG or 0, cfg.bgB or 0, cfg.bg and (cfg.bgAlpha or 45) / 100 or 0)
    if cfg.movable and not cfg.locked then f:SetBackdropBorderColor(0.2, 0.7, 1, 1)   -- unlocked: cyan edge = drag me
    else f:SetBackdropBorderColor(cfg.borderR or 0, cfg.borderG or 0, cfg.borderB or 0, cfg.border and (tonumber(cfg.borderA) or 100) / 100 or 0) end
    f:SetFrameStrata(cfg.strata or "LOW"); f:SetFrameLevel(math.max(1, math.min(128, tonumber(cfg.level) or 1)))
    local path = ns.FontPath and ns.FontPath(g.font) or STANDARD_TEXT_FONT
    local size = math.max(6, math.min(64, tonumber(g.size) or 13))
    local outline = OUTLINES[g.outline or "OUTLINE"] or "OUTLINE"
    local pp = { size = size, path = path, outline = outline, hover = cfg.hoverHL, r = cfg.textR or 1, g = cfg.textG or 1, b = cfg.textB or 1, a = (tonumber(cfg.textA) or 100) / 100 }
    local function get(i, f) return BGet(cfg, i, f) end
    for i = 1, MAXSLOTS do B.StyleSlot(e.slots[i], i, get, pp) end
end

local function Place(cfg, f)
    f:ClearAllPoints()
    local p = cfg.anchor or "CENTER"
    if cfg.widthMode == "SCREEN" then
        local a = p:find("BOTTOM") and "BOTTOM" or "TOP"
        f:SetPoint(a .. "LEFT", UIParent, a .. "LEFT", cfg.margin or 0, cfg.y or 0)
        f:SetPoint(a .. "RIGHT", UIParent, a .. "RIGHT", -(cfg.margin or 0), cfg.y or 0)
    else
        f:SetPoint(p, UIParent, p, cfg.x or 0, cfg.y or 0)
        f:SetWidth(math.max(24, tonumber(cfg.width) or 300))
    end
    f:SetHeight(math.max(12, tonumber(cfg.height) or 22))
end

local function SetVisibilityMacro(e, str)
    if not (RegisterStateDriver and UnregisterStateDriver) then return end
    str = (str and str:match("%S")) and str or nil
    if e.macro == str then return end
    if e.macro then pcall(UnregisterStateDriver, e.f, "visibility") end
    e.macro = str
    if str then pcall(RegisterStateDriver, e.f, "visibility", str) end
end

function ns.DataPanels_Refresh(key)
    if not key then for _, k in ipairs(AllKeys()) do ns.DataPanels_Refresh(k) end return end
    local cfg = Cfg(key)
    if not cfg then return end
    if not cfg.enabled or not ns.DataPanels_MasterOn() then
        local e = frames[key]
        if e then SetVisibilityMacro(e, nil); e.f:Hide() end
        return
    end
    local e = Build(key)
    Style(key, cfg); Place(cfg, e.f)
    if cfg.hideInCombat and InCombat() then SetVisibilityMacro(e, nil); e.f:Hide() return end
    SetVisibilityMacro(e, nil)
    e.f:Show()
    SetVisibilityMacro(e, cfg.visibility)   -- a macro conditional (e.g. "[petbattle] hide; show") takes over show / hide from here
    Layout(key); UpdateText(key)
    C_Timer.After(0, function() if e.f:IsShown() then Layout(key); UpdateText(key) end end)
end

-- driver --------------------------------------------------------------------------------------------------------------------
local drv = CreateFrame("Frame")
drv:RegisterEvent("PLAYER_ENTERING_WORLD")
drv:RegisterEvent("PLAYER_REGEN_DISABLED")
drv:RegisterEvent("PLAYER_REGEN_ENABLED")
drv:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
drv:SetScript("OnEvent", function(_, ev)
    if ev == "PLAYER_ENTERING_WORLD" then C_Timer.After(0.3, function() ns.DataPanels_Refresh() end) else ns.DataPanels_Refresh() end
end)
local acc, accHover = 0, 0
local keys, keysAt = nil, -1   -- the panel list, rebuilt at most once a second (it was rebuilt 11 times a second)
local function Keys()
    local now = GetTime()
    if not keys or now - keysAt >= 1 or now < keysAt then keys, keysAt = AllKeys(), now end
    return keys
end
drv:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt; accHover = accHover + dt
    if acc < 1 and accHover < 0.1 then return end
    if not ns.DataPanels_MasterOn() then acc, accHover = 0, 0; return end   -- feature off: nothing to update
    if acc >= 1 then acc = 0; for _, k in ipairs(Keys()) do UpdateText(k) end end
    if accHover >= 0.1 then
        accHover = 0
        for _, k in ipairs(Keys()) do
            local e, cfg = frames[k], Cfg(k)
            if e and cfg and e.f:IsShown() then
                local a = (cfg.mouseover and not Over(e.f)) and 0 or 1
                if e.f:GetAlpha() ~= a then e.f:SetAlpha(a) end
            end
        end
    end
end)

-------------------------------------------------------------------------------
-- options page: QoL UI Updates > "Custom Data Panels and Bars"
-------------------------------------------------------------------------------
function ns.BuildDataPanelsTab(Notify)
    local db = DB()
    if not db then return nil end
    local function Re(key) ns.DataPanels_Refresh(key) end
    local function Both(key) ns.DataPanels_Refresh(key); if Notify then Notify() end end
    ns.DataPanels_Changed = function() if Notify then Notify() end end
    local function MasterHidden() return not ns.DataPanels_MasterOn() end

    local general = { type = "group", name = "General", order = 1, args = {
        n = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Info panels for the screen. Tick the master switch below, then switch on the sections you want: a left, right, and center panel, and as many custom panels as you like. (The bar attached to the chat is the Chat Bar, under QoL UI Updates > Chat Panel.) Every block of every panel can show any data type (time, frame rate, latency, gold, durability, bag slots, custom text, or one of the character stats). Right-click any panel to jump here. The Chat Panels tab holds the backdrops, tab panel, and sizes of the Blizzard chat windows." },
        master = { type = "toggle", order = 0.1, width = "full", name = "Enable Custom Data Panels and Bars",
            desc = "Master switch. Off: no panel is shown and the sections below are hidden (their settings are kept). On: each section then has its own Enable switch.",
            get = function() return db.general.enabled and true or false end,
            set = function(_, v) db.general.enabled = v and true or false; ns.DataPanels_Refresh(); if Notify then Notify() end end },
        blocks = { type = "group", name = "Clicks and hovering", order = 1, inline = true, hidden = MasterHidden, args = {
            click = { type = "toggle", order = 1, name = "Block combat click", get = function() return db.general.blockCombatClick end, set = function(_, v) db.general.blockCombatClick = v end },
            hover = { type = "toggle", order = 2, name = "Block combat hover", get = function() return db.general.blockCombatHover end, set = function(_, v) db.general.blockCombatHover = v end },
        } },
        fonts = { type = "group", name = "Font Group", order = 2, inline = true, hidden = MasterHidden, args = {
            font = { type = "select", order = 1, name = "Font",
                values = function() local v = ns.FontList(); return v end, sorting = function() local _, o = ns.FontList(); return o end,
                get = function() return db.general.font end, set = function(_, v) db.general.font = v; Re() end },
            outline = { type = "select", order = 2, name = "Font Outline",
                values = { NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" }, sorting = { "NONE", "OUTLINE", "THICKOUTLINE" },
                get = function() return db.general.outline end, set = function(_, v) db.general.outline = v; Re() end },
            size = { type = "range", order = 3, name = "Font Size", min = 6, max = 64, step = 1,
                get = function() return db.general.size end, set = function(_, v) db.general.size = v; Re() end },
        } },
    } }

    local editIdx = {}
    -- one section of the General tab: an Enable switch, and the rest of the settings only while it is on
    local function Section(key, order)
        local cfg = Cfg(key)
        local isCustom = (key ~= "bl" and key ~= "br")   -- the center panel and the custom panels can be placed anywhere
        local custom = isCustom
        local canScreen = isCustom
        local function g(f) return function() return cfg[f] end end
        local function s(f, both) return function(_, v) cfg[f] = v; if both then Both(key) else Re(key) end end end
        local function col(name, o, rf, gf, bf, extra, af)   -- af: the field holding its opacity in percent (the picker then offers transparency)
            return { type = "color", order = o, name = name, hasAlpha = af and true or false, hidden = extra and extra.hidden or nil,
                get = function() return cfg[rf], cfg[gf], cfg[bf], af and ((tonumber(cfg[af]) or 100) / 100) or 1 end,
                set = function(_, r, gg, b, a) cfg[rf], cfg[gf], cfg[bf] = r, gg, b; if af and a then cfg[af] = math.floor(a * 100 + 0.5) end; Re(key) end }
        end
        local screen = function() return cfg.widthMode == "SCREEN" end
        local args = {
            n = { type = "description", order = 0, width = "full",
                name = (key == "bl" and "A fixed-width panel in the bottom left corner of the screen."
                    or key == "br" and "A fixed-width panel in the bottom right corner of the screen."
                    or key == "center" and "A panel at the bottom center of the screen. Pick any anchor point and offsets, make it full screen width, or unlock it and drag it."
                    or "A panel you can put anywhere: any anchor point, offsets, horizontal or vertical growth, full screen width or fixed width, or unlock it and drag it.") },
            enable = { type = "toggle", order = 1, name = "Enable", desc = "Turns this panel on and shows its settings.", get = g("enabled"), set = s("enabled", true) },
            mouseover = { type = "toggle", order = 2, name = "Mouseover", desc = "Only visible while the mouse is over it.", get = g("mouseover"), set = s("mouseover") },
            unlock = { type = "toggle", order = 3, name = "Unlock to drag", desc = "Drag it with the left mouse button (fixed-width only). The border turns blue while unlocked.",
                hidden = function() return not custom or screen() end,
                get = function() return not cfg.locked end, set = function(_, v) cfg.locked = not v; Re(key) end },
            size = { type = "group", name = "Size", order = 10, inline = true, args = {
                widthMode = { type = "select", order = 1, name = "Width mode", hidden = function() return not canScreen end,
                    values = { FIXED = "Fixed width", SCREEN = "Full screen width" }, sorting = { "FIXED", "SCREEN" }, get = g("widthMode"), set = s("widthMode", true) },
                width = { type = "range", order = 2, name = "Width", min = 24, max = 2008, step = 1, hidden = screen, get = g("width"), set = s("width") },
                margin = { type = "range", order = 3, name = "Side margin", min = 0, max = 1000, step = 1, hidden = function() return not screen() end, get = g("margin"), set = s("margin") },
                height = { type = "range", order = 4, name = "Height", min = 12, max = 1130, step = 1, get = g("height"), set = s("height") },
                growth = { type = "select", order = 5, name = "Growth", values = { H = "Horizontal", V = "Vertical" }, sorting = { "H", "V" }, get = g("growth"), set = s("growth") },
                justify = { type = "select", order = 6, name = "Text Justify", values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }, sorting = { "LEFT", "CENTER", "RIGHT" }, get = g("justify"), set = s("justify") },
            } },
            pos = { type = "group", name = "Position", order = 11, inline = true, args = {
                anchor = { type = "select", order = 1, name = "Anchor Point", hidden = function() return not custom and not canScreen end,
                    values = function() local t = {}; for _, a in ipairs(ANCHORS) do t[a] = a end; return t end, sorting = ANCHORS, get = g("anchor"), set = s("anchor") },
                x = { type = "range", order = 2, name = "X-Offset", min = -2000, max = 2000, step = 1, hidden = screen, get = g("x"), set = s("x") },
                y = { type = "range", order = 3, name = "Y-Offset", min = -2000, max = 2000, step = 1, get = g("y"), set = s("y") },
            } },
            template = { type = "group", name = "Template", order = 12, inline = true, args = {
                bg = { type = "toggle", order = 1, name = "Backdrop", get = g("bg"), set = s("bg") },
                bgColor = col("Backdrop color", 2, "bgR", "bgG", "bgB", nil, "bgAlpha"),
                bgAlpha = { type = "range", order = 3, name = "Backdrop opacity (%)", min = 0, max = 100, step = 5, get = g("bgAlpha"), set = s("bgAlpha") },
                border = { type = "toggle", order = 4, name = "Show Border", get = g("border"), set = s("border") },
                borderColor = col("Border color", 5, "borderR", "borderG", "borderB", nil, "borderA"),
                textColor = col("Text color", 6, "textR", "textG", "textB", nil, "textA"),
                labelColor = col("Label color", 7, "labelR", "labelG", "labelB"),
                labels = { type = "toggle", order = 8, name = "Show labels", desc = "Prefix such as \"Crit\" or \"Bags\" in front of the value.", get = g("showLabels"), set = s("showLabels") },
                decimals = { type = "range", order = 9, name = "Stat decimals", min = 0, max = 2, step = 1, get = g("decimals"), set = s("decimals") },
                clock24 = { type = "toggle", order = 10, name = "24-hour clock", get = g("clock24"), set = s("clock24") },
                localTime = { type = "toggle", order = 11, name = "Time: this computer's clock (off: realm time)", width = "double", get = g("localTime"), set = s("localTime") },
            } },
            strata = { type = "group", name = "Strata and Level", order = 13, inline = true, args = {
                strata = { type = "select", order = 1, name = "Frame Strata",
                    values = { BACKGROUND = "BACKGROUND", LOW = "LOW", MEDIUM = "MEDIUM", HIGH = "HIGH", DIALOG = "DIALOG" },
                    sorting = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }, get = g("strata"), set = s("strata") },
                level = { type = "range", order = 2, name = "Frame Level", min = 1, max = 128, step = 1, get = g("level"), set = s("level") },
            } },
            tip = { type = "group", name = "Tooltip", order = 14, inline = true, args = {
                anchor = { type = "select", order = 1, name = "Anchor", values = function() local t = {}; for _, a in ipairs(ANCHORS) do t[a] = a end; return t end, sorting = ANCHORS, get = g("tipAnchor"), set = s("tipAnchor") },
                x = { type = "range", order = 2, name = "X-Offset", min = -30, max = 30, step = 1, get = g("tipX"), set = s("tipX") },
                y = { type = "range", order = 3, name = "Y-Offset", min = -30, max = 30, step = 1, get = g("tipY"), set = s("tipY") },
            } },
            vis = { type = "group", name = "Visibility", order = 15, inline = true, args = {
                combat = { type = "toggle", order = 1, name = "Hide In Combat", get = g("hideInCombat"), set = s("hideInCombat") },
                macro = { type = "input", order = 2, width = "full", name = "Visibility State",
                    desc = "Optional macro conditional, for example [petbattle] hide; show . Leave empty for none.", get = g("visibility"), set = s("visibility") },
            } },
        }
        local contents = { type = "group", name = "Data Slots", order = 20, inline = true, args = {
            count = { type = "range", order = 0, name = "Number of DataTexts", min = 1, max = MAXSLOTS, step = 1, get = g("slots"), set = s("slots", true) },
        } }
        for i = 1, MAXSLOTS do
            contents.args["t" .. i] = { type = "select", order = i * 2, name = "Slot " .. i, hidden = function() return i > (cfg.slots or 1) end,
                values = function() local v = TypeValues(); return v end, sorting = function() local _, o = TypeValues(); return o end,
                get = function() return cfg["slot" .. i] or "NONE" end, set = s("slot" .. i, true) }
            contents.args["c" .. i] = { type = "input", order = i * 2 + 1, name = "Slot " .. i .. " text", width = "double",
                hidden = function() return i > (cfg.slots or 1) or cfg["slot" .. i] ~= "CUSTOM" end,
                get = function() return cfg["text" .. i] end, set = s("text" .. i) }
        end
        args.contents = contents

        -- blocks: one slot = one block with its own look; "Editing block" picks which one the settings below change
        local function nBlocks() return math.max(1, math.min(MAXSLOTS, tonumber(cfg.slots) or 1)) end
        local function cur() local n = nBlocks(); if (editIdx[key] or 1) > n then editIdx[key] = n end; return editIdx[key] or 1 end
        local function bg(f) return function() return BGet(cfg, cur(), f) end end
        local function bs(f) return function(_, v) BSet(cfg, cur(), f, v); Re(key) end end
        local function bcol(name, o, rf, gf, bf, af)
            return { type = "color", order = o, name = name, hasAlpha = af and true or false,
                get = function() local i = cur(); return BGet(cfg, i, rf), BGet(cfg, i, gf), BGet(cfg, i, bf), af and ((tonumber(BGet(cfg, i, af)) or 100) / 100) or 1 end,
                set = function(_, r, gg, b, a) local i = cur(); BSet(cfg, i, rf, r); BSet(cfg, i, gf, gg); BSet(cfg, i, bf, b); if af and a then BSet(cfg, i, af, math.floor(a * 100 + 0.5)) end; Re(key) end }
        end
        local function swap(i, j)   -- exchange two blocks: what they show, their custom text and their own settings
            cfg.blocks = cfg.blocks or {}
            cfg["slot" .. i], cfg["slot" .. j] = cfg["slot" .. j] or "NONE", cfg["slot" .. i] or "NONE"
            cfg["text" .. i], cfg["text" .. j] = cfg["text" .. j] or "", cfg["text" .. i] or ""
            cfg.blocks[i], cfg.blocks[j] = cfg.blocks[j], cfg.blocks[i]
        end
        args.blocks = { type = "group", name = "Blocks", order = 21, inline = true, args = {
            n = { type = "description", order = 0, width = "full",
                name = "Each data slot is a block. Auto sized: a block is as wide as its text plus its gaps; blocks set to \"Fill remaining space\" share what is left. Even split: every block gets the same width. Pick a block with \"Editing block\", then change it below." },
            sizing = { type = "select", order = 1, name = "Block sizing", values = { EVEN = "Even split", AUTO = "Auto sized" }, sorting = { "EVEN", "AUTO" },
                get = g("sizing"), set = s("sizing") },
            hover = { type = "toggle", order = 2, name = "Hover highlight blocks", get = g("hoverHL"), set = s("hoverHL") },
            idx = { type = "range", order = 3, name = "Editing block", min = 1, max = MAXSLOTS, step = 1,
                get = function() return cur() end, set = function(_, v) editIdx[key] = math.min(v, nBlocks()); if Notify then Notify() end end },
            what = { type = "description", order = 4, width = "full", fontSize = "medium",
                name = function() local i = cur(); local d = DT.by[cfg["slot" .. i] or "NONE"]; return "Block " .. i .. " of " .. nBlocks() .. ": " .. (d and d.name or "?") end },
            gapL = { type = "range", order = 5, name = "Left gap", min = 0, max = 200, step = 1, get = bg("gapL"), set = bs("gapL") },
            gapR = { type = "range", order = 6, name = "Right gap", min = 0, max = 200, step = 1, get = bg("gapR"), set = bs("gapR") },
            fill = { type = "toggle", order = 7, name = "Fill remaining space", desc = "Auto sized rows only.", get = bg("fill"), set = bs("fill") },
            align = { type = "select", order = 8, name = "Text align", values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }, sorting = { "LEFT", "CENTER", "RIGHT" },
                get = bg("align"), set = bs("align") },
            scale = { type = "range", order = 9, name = "Content scale (%)", min = 40, max = 300, step = 5, get = bg("scale"), set = bs("scale") },
            bgOn = { type = "toggle", order = 10, name = "Block background", get = bg("bgOn"), set = bs("bgOn") },
            bgCol = bcol("Block background color", 11, "bgR", "bgG", "bgB", "bgA"),
            bgA = { type = "range", order = 12, name = "Block background opacity (%)", min = 0, max = 100, step = 5, get = bg("bgA"), set = bs("bgA") },
            textOn = { type = "toggle", order = 13, name = "Own text color", get = bg("textOn"), set = bs("textOn") },
            textCol = bcol("This block's text color", 14, "tR", "tG", "tB", "tA"),
            left = { type = "execute", order = 20, name = "Move left / up", func = function()
                local i = cur(); if i > 1 then swap(i, i - 1); editIdx[key] = i - 1; Both(key) end end },
            right = { type = "execute", order = 21, name = "Move right / down", func = function()
                local i = cur(); if i < nBlocks() then swap(i, i + 1); editIdx[key] = i + 1; Both(key) end end },
            add = { type = "execute", order = 22, name = "Add block", func = function()
                local n = nBlocks(); if n < MAXSLOTS then cfg.slots = n + 1; editIdx[key] = n + 1; Both(key) end end },
            remove = { type = "execute", order = 23, name = "Remove block", func = function()
                local n, i = nBlocks(), cur(); if n <= 1 then return end
                for j = i, n - 1 do swap(j, j + 1) end
                cfg["slot" .. n], cfg["text" .. n] = nil, ""; if cfg.blocks then cfg.blocks[n] = nil end
                cfg.slots = n - 1; if editIdx[key] > n - 1 then editIdx[key] = n - 1 end
                Both(key) end },
        } }
        args.reset = { type = "execute", order = 30, name = "Reset this panel", confirm = true,
            func = function()
                local d = ns.Copy(ns.DATAPANEL_DEFAULTS[key] or CustomDef())
                if d.name ~= nil then d.name = cfg.name or d.name end
                local wasOn = cfg.enabled
                for k in pairs(cfg) do cfg[k] = nil end
                for k, v in pairs(d) do cfg[k] = v end
                cfg.enabled = wasOn
                Both(key)
            end }
        if key:sub(1, 2) == "cp" then   -- a custom panel: its own name, and removal
            args.name = { type = "input", order = 0.5, name = "Name", desc = "Only a label for this list.", get = g("name"), set = function(_, v) cfg.name = v; if Notify then Notify() end end }
            args.remove = { type = "execute", order = 31, name = "Remove this panel", confirm = true, confirmText = "Remove this custom panel and its settings?",
                func = function()
                    local db2 = DB(); if db2 and db2.customs then db2.customs[key] = nil end
                    if ns.DataPanels_RemoveSection then ns.DataPanels_RemoveSection(key) end
                    local e = frames[key]; if e then SetVisibilityMacro(e, nil); e.f:Hide() end
                    if Notify then Notify() end
                end }
        end
        -- collapsed while the panel is off: everything but its Enable switch (and name) is hidden
        for k, v in pairs(args) do
            if k ~= "enable" and k ~= "n" and k ~= "name" then
                local old = v.hidden
                v.hidden = function(...) if not cfg.enabled then return true end; if type(old) == "function" then return old(...) end; return old end
            end
        end
        local title = TITLES[key]
        return { type = "group", name = title or function() return (cfg.name and cfg.name ~= "") and cfg.name or key end, order = order, inline = true, hidden = MasterHidden, args = args }
    end

    local out = { type = "group", name = "Custom Data Panels and Bars", order = 10, childGroups = "tab", args = { general = general } }
    local gen = general.args
    gen.left = Section("bl", 10)
    gen.right = Section("br", 11)
    gen.center = Section("center", 12)

    -- custom panels: added and removed while the window is open (AceConfig re-reads the args table on every redraw)
    local customGroup
    customGroup = { type = "group", name = "Custom Panels", order = 14, inline = true, hidden = MasterHidden, args = {
        n = { type = "description", order = 0, width = "full", name = "Add as many panels as you need. Each one has its own place, size, look, and blocks." },
        add = { type = "execute", order = 1, name = "Add a custom panel", func = function()
            local count = 0
            for _ in pairs(db.customs) do count = count + 1 end
            if count >= MAX_CUSTOM then if ns.Print then ns.Print("That is the limit of " .. MAX_CUSTOM .. " custom panels.") end return end
            local nxt = db.customNext or 1
            db.customNext = nxt + 1
            local key = "cp" .. nxt
            db.customs[key] = CustomDef()
            db.customs[key].enabled = true
            db.customs[key].name = "Custom Panel " .. (count + 1)
            customGroup.args[key] = Section(key, 10 + nxt)
            ns.DataPanels_Refresh(key)
            if Notify then Notify() end
        end },
    } }
    ns.DataPanels_RemoveSection = function(key) customGroup.args[key] = nil end
    local ids = {}
    for k in pairs(db.customs) do ids[#ids + 1] = k end
    table.sort(ids, function(a, b) return (tonumber(a:match("%d+")) or 0) < (tonumber(b:match("%d+")) or 0) end)
    for _, k in ipairs(ids) do customGroup.args[k] = Section(k, 10 + (tonumber(k:match("%d+")) or 0)) end
    gen.custom = customGroup

    return out
end

function ns.DataPanels_OpenSettings(tab)   -- tab (optional): a tab key such as "general"
    if ns.UI and ns.UI.DataPanels then ns.UI.DataPanels(tab) end
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
ns.WhenReady(ns.DataPanels_OnDBReady)
ns.RegisterCommand("data", function() ns.DataPanels_OpenSettings() end, "/xui data (custom data panels and bars)")
ns.RegisterLauncher({ "data", "Custom data panels", "Open the custom data panels settings (also /xui data)", function() ns.DataPanels_OpenSettings() end, order = 30 })
ns.RegisterSettingsPage("bonus", "datapanels", ns.BuildDataPanelsTab)
