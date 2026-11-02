-------------------------------------------------------------------------------
-- ChatPanel.lua : the info bar that sits below (or above) the main chat window - the counterpart of ElvUI's left chat data panel.
-- Own code, written from the option set only (ElvUI's license reserves all rights).
-- Works without the "ElvUI Chat Reskin" master switch and without the main XayaUI settings window:
--   /xui panel   (or right-click the bar)   opens its own small settings window.
-- Contents: up to three slots; each shows time, FPS, latency, gold, durability, free bag slots, or your own text.
-- UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local D = ns.CHAT_DEFAULTS
D.panelOn = false
D.panelAnchor = "BELOW"        -- BELOW | ABOVE the chat window
D.panelWidthMode = "CHAT"      -- CHAT (same width as the window) | CUSTOM
D.panelWidth = 400
D.panelHeight = 22
D.panelGap = 2
D.panelOffX, D.panelOffY = 0, 0
D.panelBg = true; D.panelBgR, D.panelBgG, D.panelBgB, D.panelBgAlpha = 0, 0, 0, 45
D.panelBorder = true; D.panelBorderR, D.panelBorderG, D.panelBorderB = 0, 0, 0
D.panelTextSize = 13; D.panelTextR, D.panelTextG, D.panelTextB = 1, 1, 1
D.panelSlots = 3
D.panelSlot1, D.panelSlot2, D.panelSlot3 = "TIME", "FPS", "LATENCY"
D.panelCustom1, D.panelCustom2, D.panelCustom3 = "", "", ""
D.panelHideWhenCollapsed = true
D.panelFadeUntilHover = false
D.panelClock24 = true
D.panelLocalTime = true

local function Store() return ns.chatDB end
local panel, win
local slots = {}

-- data sources -------------------------------------------------------------------------------------------------------------
local PROVIDERS = {}
local ORDER = { "NONE", "TIME", "FPS", "LATENCY", "GOLD", "DURABILITY", "BAGS", "CUSTOM" }
local NAMES = { NONE = "(empty)", TIME = "Time", FPS = "Frame rate", LATENCY = "Latency", GOLD = "Gold", DURABILITY = "Durability",
    BAGS = "Free bag slots", CUSTOM = "Custom text" }

PROVIDERS.NONE = { text = function() return "" end }
PROVIDERS.TIME = {
    text = function(s)
        local h, m
        if s.panelLocalTime == false and GetGameTime then h, m = GetGameTime() else h, m = tonumber(date("%H")), tonumber(date("%M")) end
        if s.panelClock24 == false then
            local suffix = h >= 12 and "pm" or "am"
            h = h % 12; if h == 0 then h = 12 end
            return ("%d:%02d %s"):format(h, m, suffix)
        end
        return ("%02d:%02d"):format(h, m)
    end,
    tip = function() return "Time", (date("%A %d %B")) end,
}
PROVIDERS.FPS = { text = function() return ("%d fps"):format(math.floor((GetFramerate and GetFramerate() or 0) + 0.5)) end }
PROVIDERS.LATENCY = {
    text = function()
        local _, _, home, world = GetNetStats()
        return ("%d ms"):format(world or home or 0)
    end,
    tip = function()
        local _, _, home, world = GetNetStats()
        return "Latency", ("Home: %d ms"):format(home or 0), ("World: %d ms"):format(world or 0)
    end,
}
PROVIDERS.GOLD = {
    text = function()
        local g = math.floor((GetMoney and GetMoney() or 0) / 10000)
        local txt = BreakUpLargeNumbers and BreakUpLargeNumbers(g) or tostring(g)
        return txt .. "|cffffd100g|r"
    end,
}
PROVIDERS.DURABILITY = {
    text = function()
        local lowest
        for slot = 1, 18 do
            if slot ~= 4 then   -- shirt has none
                local cur, max = GetInventoryItemDurability(slot)
                if cur and max and max > 0 then
                    local pct = cur / max * 100
                    if not lowest or pct < lowest then lowest = pct end
                end
            end
        end
        if not lowest then return "Dur --" end
        local c = lowest < 25 and "|cffff4040" or (lowest < 50 and "|cffffd100" or "|cff40ff40")
        return ("Dur %s%d%%|r"):format(c, math.floor(lowest + 0.5))
    end,
}
PROVIDERS.BAGS = {
    text = function()
        local free, total = 0, 0
        local last = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5
        for bag = 0, last do
            local f, t
            if C_Container and C_Container.GetContainerNumFreeSlots then
                f = C_Container.GetContainerNumFreeSlots(bag)
                t = C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
            end
            free = free + (f or 0); total = total + (t or 0)
        end
        return ("Bags %d/%d"):format(free, total)
    end,
}
PROVIDERS.CUSTOM = { text = function(s, i) return s["panelCustom" .. i] or "" end }

-- frame -------------------------------------------------------------------------------------------------------------------
local function OpenWindow() if ns.ChatPanel_ShowWindow then ns.ChatPanel_ShowWindow() end end

local function Over(f)
    if not f then return false end
    if f.IsMouseOver then local ok, v = pcall(f.IsMouseOver, f); if ok then return v and true or false end end
    return MouseIsOver and MouseIsOver(f) and true or false
end

local function UpdateText()
    local s = Store()
    if not (s and panel and panel:IsShown()) then return end
    local n = math.max(1, math.min(3, tonumber(s.panelSlots) or 3))
    for i = 1, 3 do
        local slot = slots[i]
        if slot then
            if i <= n then
                local pr = PROVIDERS[s["panelSlot" .. i] or "NONE"] or PROVIDERS.NONE
                local ok, txt = pcall(pr.text, s, i)
                slot.fs:SetText(ok and txt or "?")
            else
                slot.fs:SetText("")
            end
        end
    end
end

local function Layout()
    local s = Store()
    if not (s and panel) then return end
    local n = math.max(1, math.min(3, tonumber(s.panelSlots) or 3))
    local w = panel:GetWidth() or 0
    for i = 1, 3 do
        local slot = slots[i]
        slot:ClearAllPoints()
        if i <= n and w > 0 then
            slot:SetPoint("TOPLEFT", panel, "TOPLEFT", (i - 1) * (w / n), 0)
            slot:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", (i - 1) * (w / n), 0)
            slot:SetWidth(w / n)
            slot:Show()
        else
            slot:Hide()
        end
    end
end

local function Build()
    if panel then return panel end
    panel = CreateFrame("Frame", "XayaUIChatPanel", UIParent, "BackdropTemplate")
    panel:SetFrameStrata("LOW"); panel:SetFrameLevel(5)
    panel:EnableMouse(true)
    panel:SetScript("OnMouseUp", function(_, b) if b == "RightButton" then OpenWindow() end end)
    for i = 1, 3 do
        local slot = CreateFrame("Button", nil, panel)
        slot:RegisterForClicks("RightButtonUp")
        slot.fs = slot:CreateFontString(nil, "OVERLAY")
        slot.fs:SetPoint("CENTER", 0, 0)
        slot.fs:SetFont(STANDARD_TEXT_FONT, 12, "")
        slot:SetScript("OnClick", function(_, b) if b == "RightButton" then OpenWindow() end end)
        slot:SetScript("OnEnter", function(self)
            local s = Store(); if not s then return end
            local pr = PROVIDERS[s["panelSlot" .. i] or "NONE"]
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if pr and pr.tip then
                local a, b, c = pr.tip(s)
                GameTooltip:SetText(a or "")
                if b then GameTooltip:AddLine(b, 1, 1, 1) end
                if c then GameTooltip:AddLine(c, 1, 1, 1) end
            else
                GameTooltip:SetText(NAMES[s["panelSlot" .. i] or "NONE"] or "")
            end
            GameTooltip:AddLine("Right-click: panel settings", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slots[i] = slot
    end
    local acc, accHover = 0, 0
    panel:SetScript("OnUpdate", function(self, dt)
        acc = acc + dt; accHover = accHover + dt
        if acc >= 1 then acc = 0; UpdateText() end
        if accHover >= 0.1 then
            accHover = 0
            local s = Store()
            if s and s.panelFadeUntilHover then
                self:SetAlpha((Over(self) or Over(ChatFrame1)) and 1 or 0)
            elseif self:GetAlpha() ~= 1 then
                self:SetAlpha(1)
            end
        end
    end)
    panel:SetScript("OnSizeChanged", Layout)
    return panel
end

local function Style(s)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    panel:SetBackdropColor(s.panelBgR or 0, s.panelBgG or 0, s.panelBgB or 0, s.panelBg and (s.panelBgAlpha or 45) / 100 or 0)
    panel:SetBackdropBorderColor(s.panelBorderR or 0, s.panelBorderG or 0, s.panelBorderB or 0, s.panelBorder and 1 or 0)
    local path = (ns.FontPath and ns.FontPath(s.font)) or STANDARD_TEXT_FONT
    local size = math.max(6, math.min(40, tonumber(s.panelTextSize) or 13))
    for i = 1, 3 do
        local fs = slots[i].fs
        if not fs:SetFont(path or STANDARD_TEXT_FONT, size, "OUTLINE") then fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
        fs:SetTextColor(s.panelTextR or 1, s.panelTextG or 1, s.panelTextB or 1)
    end
end

local function Place(s)
    local cf = ChatFrame1
    panel:ClearAllPoints()
    local h = math.max(10, tonumber(s.panelHeight) or 22)
    local gap = tonumber(s.panelGap) or 2
    local ox, oy = tonumber(s.panelOffX) or 0, tonumber(s.panelOffY) or 0
    local below = s.panelAnchor ~= "ABOVE"
    local fromPoint, toPoint, fromR, toR, y
    if below then
        fromPoint, fromR, toPoint, toR, y = "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", -gap + oy
    else
        -- above the window: clear the tab row too
        local tab = _G.ChatFrame1Tab
        local tabH = (tab and tab:GetHeight() or 24)
        fromPoint, fromR, toPoint, toR, y = "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT", "TOPRIGHT", tabH + gap + oy
    end
    panel:SetPoint(fromPoint, cf, toPoint, ox, y)
    if s.panelWidthMode == "CUSTOM" then
        panel:SetSize(math.max(40, tonumber(s.panelWidth) or 400), h)
    else
        panel:SetPoint(fromR, cf, toR, ox, y)
        panel:SetHeight(h)
    end
end

function ns.ChatPanel_Refresh()
    local s = Store()
    if not s then return end
    local off = (not s.panelOn) or (not ChatFrame1)
        or (s.panelHideWhenCollapsed ~= false and ns.ChatDock_IsCollapsed and ns.ChatDock_IsCollapsed())
    if off then
        if panel then panel:Hide() end
        return
    end
    Build(); Style(s); Place(s); panel:Show()
    Layout(); UpdateText()
    C_Timer.After(0, function() if panel and panel:IsShown() then Layout(); UpdateText() end end)
end

-- standalone settings window ----------------------------------------------------------------------------------------------
local function BuildWindow()
    if win then return win end
    local CW = ns.CW
    if not CW then return end
    local f = CW.Window("XayaUIChatPanelWindow", "Chat panel", 300, 520)
    win = f
    local function S() return Store() or {} end
    local function setv(k) return function(v) local s = Store(); if s then s[k] = v end; ns.ChatPanel_Refresh() end end
    local function getv(k) return function() return S()[k] end end
    local function check(label, k, default)
        return CW.Check(label, function() local v = S()[k]; if v == nil then return default end; return v end, setv(k))
    end
    local function num(label, k, min, max, step) return CW.Number(label, getv(k), setv(k), min, max, step) end
    local function color(label, k)
        return CW.Color(label, function() local s = S(); return s[k .. "R"] or 1, s[k .. "G"] or 1, s[k .. "B"] or 1 end,
            function(r, g, b) local s = Store(); if s then s[k .. "R"], s[k .. "G"], s[k .. "B"] = r, g, b end; ns.ChatPanel_Refresh() end)
    end

    f:Add(CW.Note("An info bar under the chat window (right-click the bar to open this). Changes apply immediately and are saved. Scroll with the mouse wheel.", 0.7, 0.7, 0.7), 30)
    f:Add(check("Show the panel", "panelOn"), 20)
    f:Add(CW.Cycle("Position", { { "BELOW", "Below the chat" }, { "ABOVE", "Above the chat" } }, getv("panelAnchor"), setv("panelAnchor")), 20)
    f:Add(CW.Cycle("Width", { { "CHAT", "Same as the chat" }, { "CUSTOM", "Custom" } }, getv("panelWidthMode"), setv("panelWidthMode")), 20)
    f:Add(num("Custom width", "panelWidth", 40, 1500, 5), 20)
    f:Add(num("Height", "panelHeight", 10, 80, 1), 20)
    f:Add(num("Gap to the chat", "panelGap", -20, 60, 1), 20)
    f:Add(num("Nudge left / right", "panelOffX", -800, 800, 1), 20)
    f:Add(num("Nudge down / up", "panelOffY", -800, 800, 1), 20, 8)

    f:Add(CW.Header("Look"), 18)
    f:Add(check("Background", "panelBg"), 20)
    f:Add(color("Background color", "panelBg"), 20)
    f:Add(num("Background opacity (%)", "panelBgAlpha", 0, 100, 5), 20)
    f:Add(check("Border", "panelBorder"), 20)
    f:Add(color("Border color", "panelBorder"), 20)
    f:Add(num("Text size", "panelTextSize", 6, 40, 1), 20)
    f:Add(color("Text color", "panelText"), 20, 8)

    f:Add(CW.Header("Contents"), 18)
    f:Add(num("Number of slots (1-3)", "panelSlots", 1, 3, 1), 20)
    local values = {}
    for _, k in ipairs(ORDER) do values[#values + 1] = { k, NAMES[k] } end
    for i = 1, 3 do
        f:Add(CW.Cycle("Slot " .. i, values, getv("panelSlot" .. i), setv("panelSlot" .. i)), 20)
    end
    for i = 1, 3 do
        f:Add(CW.Text("Slot " .. i .. " custom text (used when the slot is Custom text; color codes work)", getv("panelCustom" .. i), setv("panelCustom" .. i)), 40)
    end
    f:Add(check("24-hour clock", "panelClock24", true), 20)
    f:Add(check("Time: use this computer's clock (off: realm time)", "panelLocalTime", true), 20, 8)

    f:Add(CW.Header("Behaviour"), 18)
    f:Add(check("Hide while the chat is collapsed", "panelHideWhenCollapsed", true), 20)
    f:Add(check("Show only while the mouse is over the chat or the panel", "panelFadeUntilHover"), 20, 8)

    local row = CreateFrame("Frame")
    local reset = CW.Button(row, 140, 20, "Reset panel settings", function()
        local s = Store(); if not s then return end
        for k, v in pairs(ns.CHAT_DEFAULTS) do if k:sub(1, 5) == "panel" then s[k] = v end end
        ns.ChatPanel_Refresh(); f:RefreshAll()
    end)
    reset:SetPoint("LEFT", 0, 0)
    f:Add(row, 24)
    f.OnMoved = function() local s = Store(); if s then local p, _, _, x, y = f:GetPoint(); s.panelWinPos = { p = p, x = x, y = y } end end
    return f
end

function ns.ChatPanel_ShowWindow()
    local f = BuildWindow()
    if not f then return end
    if f:IsShown() then f:Hide() return end
    f:ClearAllPoints()
    local pp = (Store() or {}).panelWinPos
    if pp and pp.p then f:SetPoint(pp.p, UIParent, pp.p, pp.x or 0, pp.y or 0) else f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    f:Show()
end

function ns.ChatPanel_SetOn(v)
    local s = Store(); if not s then return end
    s.panelOn = v and true or false
    ns.ChatPanel_Refresh()
end

-- driver -------------------------------------------------------------------------------------------------------------------
local drv = CreateFrame("Frame")
drv:RegisterEvent("PLAYER_ENTERING_WORLD")
drv:RegisterEvent("UPDATE_CHAT_WINDOWS")
drv:SetScript("OnEvent", function() C_Timer.After(0.3, ns.ChatPanel_Refresh) end)

-- options inside the main XayaUI window (the full set is in the small window: /xui panel) --------------------------------
function ns.ChatPanel_Options(Notify)
    local function S() return Store() or {} end
    return { type = "group", name = "Chat Panel", order = 9, args = {
        n = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "An info bar below the chat window (like ElvUI's chat data panel). It works without the ElvUI Chat Reskin switch, and its own small window (/xui panel, or right-click the bar) opens without this settings window." },
        on = { type = "toggle", order = 1, width = "full", name = "Show the chat panel",
            get = function() return S().panelOn and true or false end,
            set = function(_, v) ns.ChatPanel_SetOn(v); Notify() end },
        anchor = { type = "select", order = 2, name = "Position", values = { BELOW = "Below the chat", ABOVE = "Above the chat" }, sorting = { "BELOW", "ABOVE" },
            get = function() return S().panelAnchor or "BELOW" end,
            set = function(_, v) local s = Store(); if s then s.panelAnchor = v end; ns.ChatPanel_Refresh(); Notify() end },
        open = { type = "execute", order = 3, name = "Open the full panel settings window",
            func = function() ns.ChatPanel_ShowWindow() end },
    } }
end
