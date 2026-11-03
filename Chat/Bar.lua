-------------------------------------------------------------------------------
-- Chat/Bar.lua : the Chat Bar. A row of data blocks (time, fps / latency, friends, gold, durability, bags, zone, your own text, the
-- character stats from Custom Data Panels, and a History block) that is an edge of the Chat Panel container: above or below the pane,
-- always the same width, collapsing with it. The blocks are drawn by DataBlocks.lua (shared with the screen data panels).
-- Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
local C = ns.Chat
local B = ns.DataBlocks
local issecret = C.IsSecret

local slots = {}
local edge
local function S() return ns.chat2 end

local function Hex(r, g, b)
    return string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5))
end
local function Val(s) return Hex(s.barValueR, s.barValueG, s.barValueB) end
local function Ramp(v, good, ok, invert)   -- green / yellow / red by threshold
    if invert then return v <= good and "|cff40ff40" or (v <= ok and "|cffffd100" or "|cffff4040") end
    return v >= good and "|cff40ff40" or (v >= ok and "|cffffd100" or "|cffff4040")
end
local function Num(v) v = tonumber(v); if not v or issecret(v) then return 0 end return v end

local P = {}
P.NONE = { name = "(empty)", text = function() return "" end }
P.TIME = { name = "Time",
    text = function(s)
        local h, m
        if s.barLocalTime == false and GetGameTime then h, m = GetGameTime() else h, m = tonumber(date("%H")), tonumber(date("%M")) end
        h, m = h or 0, m or 0
        if s.barClock24 == false then
            local suffix = h >= 12 and "pm" or "am"
            h = h % 12; if h == 0 then h = 12 end
            return ("%d:%02d %s"):format(h, m, suffix)
        end
        return ("%02d:%02d"):format(h, m)
    end,
    tip = function() return "Time", (date("%A %d %B")) end }
P.FPS = { name = "Frame rate", usage = true, tip = function() return "Frame rate", ("%d fps"):format(math.floor(Num(GetFramerate and GetFramerate()) + 0.5)) end, text = function() local f = math.floor(Num(GetFramerate and GetFramerate()) + 0.5); return ("%s%d|r fps"):format(Ramp(f, 60, 30), f) end }
P.LATENCY = { name = "Latency", usage = true,
    text = function()
        local _, _, home, world = GetNetStats()
        local ms = Num(world or home)
        return ("%s%d|r ms"):format(Ramp(ms, 60, 150, true), ms)
    end,
    tip = function()
        local _, _, home, world = GetNetStats()
        return "Latency", ("Home: %d ms"):format(Num(home)), ("World: %d ms"):format(Num(world))
    end }
P.FPSMS = { name = "Frame rate and latency", usage = true,
    text = function()
        local f = math.floor(Num(GetFramerate and GetFramerate()) + 0.5)
        local _, _, home, world = GetNetStats()
        local ms = Num(world or home)
        return ("FPS: %s%d|r MS: %s%d|r"):format(Ramp(f, 60, 30), f, Ramp(ms, 60, 150, true), ms)
    end,
    tip = function() return P.LATENCY.tip() end }
local function Online()
    local wow = (C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends()) or 0
    local bn = 0
    if BNGetNumFriends then local _, online = BNGetNumFriends(); bn = online or 0 end
    return Num(wow), Num(bn)
end
P.FRIENDS = { name = "Friends online",
    text = function(s) local w, b = Online(); return ("Friends: %s%d|r"):format(Val(s), w + b) end,
    click = function() if ToggleFriendsFrame then ToggleFriendsFrame(1) end end,
    tip = function() local w, b = Online(); return "Friends online", ("Game friends: %d"):format(w), ("Battle.net friends: %d"):format(b) end }
P.GOLD = { name = "Gold",
    text = function()
        local g = math.floor(Num(GetMoney and GetMoney()) / 10000)
        return (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or tostring(g)) .. "|cffffd100g|r"
    end,
    click = function() if ToggleAllBags then ToggleAllBags() end end }
P.DURABILITY = { name = "Durability",
    text = function()
        local lowest
        for slot = 1, 18 do
            if slot ~= 4 and GetInventoryItemDurability then
                local cur, max = GetInventoryItemDurability(slot)
                if cur and max and max > 0 then
                    local pct = cur / max * 100
                    if not lowest or pct < lowest then lowest = pct end
                end
            end
        end
        if not lowest then return "Dur --" end
        return ("Dur %s%d%%|r"):format(Ramp(lowest, 50, 25), math.floor(lowest + 0.5))
    end }
P.BAGS = { name = "Bag space",
    text = function()
        local free, total = 0, 0
        local last = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5
        for bag = 0, last do
            if C_Container and C_Container.GetContainerNumFreeSlots then
                free = free + Num(C_Container.GetContainerNumFreeSlots(bag))
                total = total + Num(C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag))
            end
        end
        return ("Bags %d/%d"):format(free, total)
    end,
    click = function() if ToggleAllBags then ToggleAllBags() end end }
P.ZONE = { name = "Zone",
    text = function()
        local z, sub = GetZoneText and GetZoneText() or "", GetSubZoneText and GetSubZoneText() or ""
        if sub ~= "" and sub ~= z then return z .. " - " .. sub end
        return z
    end }
P.HISTORY = { name = "Chat history", text = function() return "History" end, click = function() if C.History_Toggle then C.History_Toggle() end end,
    tip = function() return "Chat history", "Opens the copyable history of recent messages." end }
P.CUSTOM = { name = "Your own text", text = function(s, i) return s["barCustom" .. i] or "" end }

local ORDER = { "NONE", "TIME", "FPS", "LATENCY", "FPSMS", "FRIENDS", "GOLD", "DURABILITY", "BAGS", "ZONE", "HISTORY", "CUSTOM" }

-- every type of the character stats registered by DataPanels.lua (loaded later, so looked up while the game runs)
local function Prov(key)
    if P[key] then return P[key] end
    local d = ns.DataText and ns.DataText.by and ns.DataText.by[key]
    if not d then return P.NONE end
    local p = {
        name = (d.group == "General") and d.name or (d.group .. ": " .. d.name),
        text = function(s, i)
            local cfg = { decimals = 1, clock24 = s.barClock24, localTime = s.barLocalTime }
            local v = d.text(cfg, i)
            if d.label and v ~= "" and s.barLabels ~= false then return d.label .. " " .. Val(s) .. v .. "|r" end
            return v
        end,
        tip = d.tip and function() local t = d.tip({}, 1); return t[1], t[2], t[3] end or nil,
    }
    P[key] = p
    return p
end
function C.Bar_Types()
    local list = {}
    for _, k in ipairs(ORDER) do list[#list + 1] = { k, P[k].name } end
    if ns.DataText and ns.DataText.list then
        for _, d in ipairs(ns.DataText.list) do
            if not P[d.key] and d.group ~= "General" then list[#list + 1] = { d.key, d.group .. ": " .. d.name } end
        end
    end
    return list
end

-------------------------------------------------------------------------------
local function Get(s)
    return function(i, field)
        if field == "align" then return s["barAlign" .. i] or "CENTER" end
        if field == "fill" then return s["barFill" .. i] and true or false end
        return B.DEF[field]
    end
end

local function MakeSlot(i)
    local bar = C.Bar()
    local slot = B.MakeSlot(bar)
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:SetScript("OnClick", function(_, button)
        local s = S(); if not s then return end
        if button == "RightButton" then if C.OpenSettings then C.OpenSettings("bar") end return end
        local pr = Prov(s["barType" .. i])
        if pr and pr.click then pcall(pr.click) end
    end)
    local function ShowTip(self)
        local s = S(); if not s then return end
        local pr = Prov(s["barType" .. i])
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if pr and pr.tip then
            local a, b, c = pr.tip(s)
            GameTooltip:SetText(a or "")
            if b then GameTooltip:AddLine(b, 1, 1, 1) end
            if c then GameTooltip:AddLine(c, 1, 1, 1) end
        else
            GameTooltip:SetText((pr and pr.name) or "")
        end
        if pr and pr.usage and B.AddUsage then
            local ok, err = pcall(B.AddUsage, GameTooltip, 8)
            if not ok then GameTooltip:AddLine("Addon usage unavailable: " .. tostring(err), 1, 0.4, 0.4) end
        end
        if pr and pr.click then GameTooltip:AddLine("Click: open", 0.6, 0.6, 0.6) end
        GameTooltip:AddLine("Right-click: Chat Panel settings", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end
    slot:SetScript("OnEnter", function(self)
        local s = S(); if not s then return end
        if InCombatLockdown and InCombatLockdown() then return end
        ShowTip(self)
        local pr = Prov(s["barType" .. i])
        if pr and pr.usage then   -- the CPU numbers move: redraw once a second while the mouse is on the block
            local t = 0
            self:SetScript("OnUpdate", function(f, dt)
                t = t + dt
                if t < 1 then return end
                t = 0
                if InCombatLockdown and InCombatLockdown() then f:SetScript("OnUpdate", nil); GameTooltip:Hide(); return end
                if GameTooltip:IsOwned(f) then ShowTip(f) else f:SetScript("OnUpdate", nil) end
            end)
        end
    end)
    slot:SetScript("OnLeave", function(self) self:SetScript("OnUpdate", nil); GameTooltip:Hide() end)
    slots[i] = slot
    return slot
end

local function Count(s) return math.max(1, math.min(C.MAX_SLOTS, tonumber(s.barSlots) or 3)) end

local function UpdateText()
    local s = S()
    if not (s and s.barOn) then return end
    for i = 1, Count(s) do
        local slot = slots[i]
        if slot then
            local ok, txt = pcall(function() return Prov(s["barType" .. i]).text(s, i) end)
            slot.fs:SetText(ok and txt or "")
        end
    end
end

local function Style(s)
    local bar = C.Bar()
    if not edge then
        bar.bg = bar:CreateTexture(nil, "BACKGROUND"); bar.bg:SetAllPoints()
        edge = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        edge:SetAllPoints(bar)
        edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    end
    if s.barBgOn then
        local r, g, b, a = C.Color(s, "barBg", "xui-pane", "bg")
        bar.bg:SetColorTexture(r, g, b, a); bar.bg:Show()
    else
        bar.bg:Hide()
    end
    if s.barBorderOn then
        local r, g, b, a = C.Color(s, "barBorder", "xui-pane", "border")
        edge:SetBackdropBorderColor(r, g, b, a); edge:Show()
    else
        edge:Hide()
    end
end

local last
local function Place()
    local bar, s = C.Bar(), S()
    if not (bar and s and last and s.barOn and C.On()) then return end
    B.Layout(bar, slots, { n = last.n, sizing = last.sizing, lead = C.ArrowLead(), get = last.get })
    -- AUTO sizing measures the text, so lay out again once the strings have their widths
    if last.sizing == "AUTO" then B.Layout(bar, slots, { n = last.n, sizing = "AUTO", lead = C.ArrowLead(), get = last.get }) end
end

local function Refresh(s)
    if not C.On() or not C.Bar() then return end
    local bar = C.Bar()
    if not s.barOn then return end
    Style(s)
    local n = Count(s)
    for i = 1, n do if not slots[i] then MakeSlot(i) end end
    local get = Get(s)
    local pr = {
        size = math.max(8, math.min(40, tonumber(s.barTextSize) or 13)),
        path = C.FontPath(s.font), outline = "OUTLINE",
        r = s.barTextR, g = s.barTextG, b = s.barTextB, a = 1, hover = s.barHover,
    }
    for i = 1, n do B.StyleSlot(slots[i], i, get, pr) end
    UpdateText()
    last = { n = n, sizing = s.barSizing == "AUTO" and "AUTO" or "EVEN", get = get }
    Place()
    -- the game only knows a frame's real width a moment after it is anchored: lay out again whenever the bar's size is settled or changes
    if not bar._xuiSizeHook then
        bar._xuiSizeHook = true
        bar:HookScript("OnSizeChanged", function() Place() end)
    end
    C_Timer.After(0, Place)
end
C.Register("bar", Refresh)

local acc = 0
local up = CreateFrame("Frame")
up:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 1 then return end
    acc = 0
    local s = S()
    if s and s.barOn and C.On() and C.Bar() and C.Bar():IsShown() then pcall(UpdateText) end
end)
