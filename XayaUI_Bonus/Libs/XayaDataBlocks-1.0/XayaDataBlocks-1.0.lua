-------------------------------------------------------------------------------
-- XayaDataBlocks-1.0 : the "row of blocks" engine and the data types (time, FPS, latency, gold, durability, bags, stats ...) shared
-- by the Chat Bar (XayaUI_Chat) and the screen data panels (XayaUI_Bonus). Both keep their own settings and windows; this library
-- only knows what a block is, how to lay a row of them out, and what each data type shows.
-- A block = one clickable slot with a text, its own gaps, alignment, text scale, background and text color.
-- Shipped inside BOTH addons (each folder needs its own copy; the game loads files only from an addon's own folder). LibStub keeps
-- one copy running: the first one loaded, or a newer MINOR if the other addon carries a newer file. Neither addon needs the other.
-- Bump MINOR whenever this file changes (the sync checks that both copies are identical). Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local MAJOR, MINOR = "XayaDataBlocks-1.0", 2
local B = LibStub:NewLibrary(MAJOR, MINOR)
if not B then return end   -- this copy or a newer one is already running

B.MAXN = 20
-- per-block settings and their defaults (a bar may override a default through its get function)
B.DEF = { gapL = 10, gapR = 10, fill = false, align = "CENTER", scale = 100,
    bgOn = false, bgR = 0, bgG = 0, bgB = 0, bgA = 40, textOn = false, tR = 1, tG = 1, tB = 1, tA = 100 }

-------------------------------------------------------------------------------
-- Addon usage for the FPS / latency tooltips: the same numbers the game's Addon List shows (C_AddOnProfiler: current / average / peak
-- CPU as a share of the whole application, top addons by recent CPU) plus memory per addon (GetAddOnMemoryUsage, in KB).
-- B.UsageLines(topN, readMemory) -> a list of tooltip lines (plain strings; a line starting "#" is a heading). Never errors: a missing
-- API just leaves its section out. Memory (UpdateAddOnMemoryUsage: every addon's memory) is a costly call booked to the addon that
-- makes it, so it is read only when readMemory is true (the tooltip's first show on hover), or when nothing was read yet (MINOR 2,
-- REQUEST-LOG A15 P-14: her idle tooltip showed XayaUI_Chat at 9% "now" only while hovered; it was re-read every 15 s while hovered).
-- The once-a-second redraws keep refreshing the cheap CPU numbers. The block ends with a grey line saying the reading has a cost.
-------------------------------------------------------------------------------
local issecret = _G.issecretvalue or function() return false end
local function Number(v) v = tonumber(v); if v == nil or issecret(v) then return nil end return v end
local function Pct(p)
    if p >= 1 then return ("%.0f%%"):format(p) elseif p >= 0.1 then return ("%.1f%%"):format(p) elseif p >= 0.01 then return ("%.2f%%"):format(p) end
    return "0%"
end
local function Mem(kb) if kb >= 1024 then return ("%.1f MB"):format(kb / 1024) end return ("%.0f KB"):format(kb) end
local memCache, memAt

function B.UsageLines(topN, readMemory)
    topN = math.max(1, math.min(15, tonumber(topN) or 8))
    local out = { "#AddOn usage" }
    local prof = _G.C_AddOnProfiler
    local okEnabled, enabled = pcall(function() return prof and prof.IsEnabled and prof.IsEnabled() end)
    if okEnabled and enabled and Enum and Enum.AddOnProfilerMetric then
        pcall(function()
            local M = Enum.AddOnProfilerMetric
            local app = Number(prof.GetApplicationMetric(M.RecentAverageTime))
            local function Overall(metric)
                local a, o = Number(prof.GetApplicationMetric(metric)), Number(prof.GetOverallMetric(metric))
                if a and o and a > 0 then return Pct(o / a * 100) end
                return "--"
            end
            out[#out + 1] = ("CPU now: %s    average: %s    peak: %s"):format(Overall(M.RecentAverageTime), Overall(M.SessionAverageTime), Overall(M.PeakTime))
            local overall = Number(prof.GetOverallMetric(M.RecentAverageTime))
            local top = prof.GetTopKAddOnsForMetric and prof.GetTopKAddOnsForMetric(M.RecentAverageTime, topN)
            if app and overall and top and #top > 0 then
                out[#out + 1] = "#Top by CPU (now)"
                for _, r in ipairs(top) do
                    local name = r.addOnName
                    local v = name and Number(prof.GetAddOnMetric(name, M.RecentAverageTime))
                    local avg = name and Number(prof.GetAddOnMetric(name, M.SessionAverageTime))
                    if v then
                        local rel = app - overall + v
                        local line = ("%s   %s"):format(rel > 0 and Pct(v / rel * 100) or "--", name)
                        if avg then
                            local relA = (Number(prof.GetApplicationMetric(M.SessionAverageTime)) or 0) - (Number(prof.GetOverallMetric(M.SessionAverageTime)) or 0) + avg
                            if relA > 0 then line = line .. ("  (avg %s)"):format(Pct(avg / relA * 100)) end
                        end
                        out[#out + 1] = line
                    end
                end
            end
        end)
    else
        out[#out + 1] = "CPU use is not available (the game's addon profiler is off)."
    end
    if _G.GetAddOnMemoryUsage and _G.UpdateAddOnMemoryUsage and C_AddOns and C_AddOns.GetNumAddOns then
        pcall(function()
            local now = GetTime()
            if not memCache or not memAt or (readMemory and now - memAt > 1) then
                UpdateAddOnMemoryUsage()
                B.memReads = (B.memReads or 0) + 1   -- (counted for Dev Assist walkthrough J25)
                local list, total = {}, 0
                for i = 1, C_AddOns.GetNumAddOns() do
                    local kb = Number(GetAddOnMemoryUsage(i))
                    if kb and kb > 0 then
                        local name = C_AddOns.GetAddOnInfo(i)
                        if type(name) == "table" then name = name.name end
                        list[#list + 1] = { name = name or ("#" .. i), kb = kb }
                        total = total + kb
                    end
                end
                table.sort(list, function(a, b) return a.kb > b.kb end)
                memCache, memAt = { list = list, total = total }, now
            end
            if memCache.total > 0 then
                out[#out + 1] = "#Memory: " .. Mem(memCache.total) .. " total"
                for n = 1, math.min(topN, #memCache.list) do
                    out[#out + 1] = ("%s   %s"):format(Mem(memCache.list[n].kb), memCache.list[n].name)
                end
            end
        end)
    end
    return out
end

-- fills the game tooltip with `head` lines, then the usage lines; "#..." lines are gold headings
function B.AddUsage(tooltip, topN, readMemory)
    tooltip:AddLine(" ")
    for _, l in ipairs(B.UsageLines(topN, readMemory)) do
        if l:sub(1, 1) == "#" then tooltip:AddLine(l:sub(2), 1, 0.82, 0) else tooltip:AddLine(l, 1, 1, 1) end
    end
    tooltip:AddLine("Includes the cost of reading these numbers.", 0.6, 0.6, 0.6, true)
end

-- a slot: button with a background texture, a mouse-over highlight and a text. The caller adds its own scripts.
function B.MakeSlot(parent)
    local slot = CreateFrame("Button", nil, parent)
    slot.bg = slot:CreateTexture(nil, "BACKGROUND"); slot.bg:SetAllPoints(); slot.bg:Hide()
    slot.hl = slot:CreateTexture(nil, "HIGHLIGHT"); slot.hl:SetAllPoints(); slot.hl:SetColorTexture(1, 1, 1, 0.10)
    slot.fs = slot:CreateFontString(nil, "OVERLAY")
    slot.fs:SetPoint("CENTER", 0, 0)
    slot.fs:SetFont(STANDARD_TEXT_FONT, 12, "")
    slot.fs:SetWordWrap(false)
    return slot
end

-- font, size (with the block's own scale), colors and background of one slot.
-- p = { size =, path =, outline =, r =, g =, b = (bar text color), hover = bool }; get(i, field) -> the block's setting
function B.StyleSlot(slot, i, get, p)
    local size = math.max(6, math.min(80, math.floor(p.size * (tonumber(get(i, "scale")) or 100) / 100 + 0.5)))
    local fs, outline = slot.fs, p.outline or "OUTLINE"
    if not fs:SetFont(p.path or STANDARD_TEXT_FONT, size, outline) then fs:SetFont(STANDARD_TEXT_FONT, size, outline) end
    if get(i, "textOn") then fs:SetTextColor(get(i, "tR"), get(i, "tG"), get(i, "tB"), (tonumber(get(i, "tA")) or 100) / 100)
    else fs:SetTextColor(p.r or 1, p.g or 1, p.b or 1, p.a or 1) end
    if get(i, "bgOn") then
        slot.bg:SetColorTexture(get(i, "bgR"), get(i, "bgG"), get(i, "bgB"), (get(i, "bgA") or 40) / 100)
        slot.bg:Show()
    else
        slot.bg:Hide()
    end
    slot.hl:SetShown(p.hover and true or false)
end

-- places the first o.n slots along the frame and hides the rest.
-- o = { n =, vert = bool (stack top to bottom), sizing = "EVEN" | "AUTO", lead = px kept free at the start, trail = px kept free at the end,
--       get = function(i, field) }
-- AUTO: each block is as long as its text plus its gaps; blocks marked "fill" share what is left (none marked: everyone shares it).
function B.Layout(frame, slots, o)
    local n, vert, get = o.n, o.vert, o.get
    local len = (vert and frame:GetHeight() or frame:GetWidth()) or 0
    local thick = (vert and frame:GetWidth() or frame:GetHeight()) or 0
    local lead, trail = o.lead or 0, o.trail or 0
    local usable = len - lead - trail
    local sizes = {}
    if usable > 0 and n > 0 then
        if o.sizing ~= "AUTO" then
            for i = 1, n do sizes[i] = usable / n end
        else
            local nat, sum, fills = {}, 0, 0
            for i = 1, n do
                local fs = slots[i].fs
                local tw = (vert and fs:GetStringHeight() or fs:GetStringWidth()) or 0
                nat[i] = math.max(16, tw + (get(i, "gapL") or 0) + (get(i, "gapR") or 0))
                sum = sum + nat[i]
                if get(i, "fill") then fills = fills + 1 end
            end
            if sum >= usable then
                for i = 1, n do sizes[i] = nat[i] * usable / sum end
            else
                local left = usable - sum
                for i = 1, n do
                    local extra
                    if fills > 0 then extra = get(i, "fill") and left / fills or 0 else extra = left / n end
                    sizes[i] = nat[i] + extra
                end
            end
        end
    end
    local pos = lead
    for i = 1, B.MAXN do
        local slot = slots[i]
        if slot then
            slot:ClearAllPoints()
            if i <= n and sizes[i] then
                local sz, fs = sizes[i], slot.fs
                local al = get(i, "align")
                fs:ClearAllPoints()
                if vert then
                    slot:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -pos)
                    slot:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -pos)
                    slot:SetHeight(sz)
                    fs:SetWidth(math.max(1, thick - 6))
                    if al == "LEFT" then fs:SetPoint("LEFT", slot, "LEFT", 3, 0); fs:SetJustifyH("LEFT")
                    elseif al == "RIGHT" then fs:SetPoint("RIGHT", slot, "RIGHT", -3, 0); fs:SetJustifyH("RIGHT")
                    else fs:SetPoint("CENTER", slot, "CENTER", 0, 0); fs:SetJustifyH("CENTER") end
                else
                    slot:SetPoint("TOPLEFT", frame, "TOPLEFT", pos, 0)
                    slot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pos, 0)
                    slot:SetWidth(sz)
                    local gl, gr = get(i, "gapL") or 0, get(i, "gapR") or 0
                    fs:SetWidth(math.max(1, sz - gl - gr))
                    if al == "LEFT" then fs:SetPoint("LEFT", slot, "LEFT", gl, 0); fs:SetJustifyH("LEFT")
                    elseif al == "RIGHT" then fs:SetPoint("RIGHT", slot, "RIGHT", -gr, 0); fs:SetJustifyH("RIGHT")
                    else fs:SetPoint("CENTER", slot, "CENTER", (gl - gr) / 2, 0); fs:SetJustifyH("CENTER") end
                end
                pos = pos + sz
                slot:Show()
            else
                slot:Hide()
            end
        end
    end
end

-------------------------------------------------------------------------------
-- data types: B.Text.list (in order) and B.Text.by[key]; B.Text.Register(key, name, group, def) adds one.
-------------------------------------------------------------------------------
B.Text = B.Text or { list = {}, by = {} }
local function num(v) if type(v) == "number" and not issecret(v) then return v end end
local DT = B.Text

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
