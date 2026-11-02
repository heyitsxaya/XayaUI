-------------------------------------------------------------------------------
-- ChatPanel.lua : the info bars ("data text panels") under or above the chat windows. Own code.
-- Works without the "ElvUI Chat Reskin" master switch and without the main XayaUI settings window:
--   /xui panel   (or right-click a bar)   opens a small settings window of its own.
-- Left panel = under the main chat window (ChatFrame1). Right panel = under the window chosen as "right chat window" (ChatPanels.lua).
-- Each has up to three slots (time, FPS + latency, FPS, latency, friends, gold, durability, free bag slots, your own text) and a toggle
-- button at its outer end that hides / shows that chat window.
-- Right panel settings use the same names as the left ones with an "r" in front (rpanelOn, rpanelAnchor, ...).
-- UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local D = ns.CHAT_DEFAULTS
local function K(side, k) return side == "R" and ("r" .. k) or k end

local BASE = {
    panelOn = false,
    panelAnchor = "BELOW",         -- BELOW | ABOVE the chat window
    panelWidthMode = "CHAT",       -- CHAT (same width as the window) | CUSTOM
    panelWidth = 400, panelHeight = 22, panelGap = 2, panelOffX = 0, panelOffY = 0,
    panelBg = true, panelBgR = 0, panelBgG = 0, panelBgB = 0, panelBgAlpha = 45,
    panelBorder = true, panelBorderR = 0, panelBorderG = 0, panelBorderB = 0,
    panelTextSize = 13, panelTextR = 1, panelTextG = 1, panelTextB = 1,
    panelValueR = 0.64, panelValueG = 0.21, panelValueB = 0.93,   -- numbers in friends etc. (purple, as in Xaya's screenshot)
    panelSlots = 3,
    panelCustom1 = "", panelCustom2 = "", panelCustom3 = "",
    panelHideWhenCollapsed = false,
    panelFadeUntilHover = false,
    panelClock24 = true, panelLocalTime = true,
}
for k, v in pairs(BASE) do D[k] = v; D["r" .. k] = v end
D.panelSlot1, D.panelSlot2, D.panelSlot3 = "FPSMS", "NONE", "FRIENDS"    -- the look in Xaya's screenshot
D.rpanelSlot1, D.rpanelSlot2, D.rpanelSlot3 = "TIME", "NONE", "GOLD"

local function Store() return ns.chatDB end
local panels = { L = {}, R = {} }    -- per side: frame, slots, toggle
local win, editSide = nil, "L"

-- data sources -------------------------------------------------------------------------------------------------------------
local PROVIDERS = {}
local ORDER = { "NONE", "TIME", "FPSMS", "FPS", "LATENCY", "FRIENDS", "GOLD", "DURABILITY", "BAGS", "CUSTOM" }
local NAMES = { NONE = "(empty)", TIME = "Time", FPSMS = "FPS and latency", FPS = "Frame rate", LATENCY = "Latency", FRIENDS = "Friends online",
    GOLD = "Gold", DURABILITY = "Durability", BAGS = "Free bag slots", CUSTOM = "Custom text" }

local function Hex(r, g, b) return string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5)) end
local function Val(s, side) return Hex(s[K(side, "panelValueR")], s[K(side, "panelValueG")], s[K(side, "panelValueB")]) end
local function Ramp(v, good, ok, invert)   -- green / yellow / red by threshold
    if invert then return v <= good and "|cff40ff40" or (v <= ok and "|cffffd100" or "|cffff4040") end
    return v >= good and "|cff40ff40" or (v >= ok and "|cffffd100" or "|cffff4040")
end

PROVIDERS.NONE = { text = function() return "" end }
PROVIDERS.TIME = {
    text = function(s, side)
        local h, m
        if s[K(side, "panelLocalTime")] == false and GetGameTime then h, m = GetGameTime() else h, m = tonumber(date("%H")), tonumber(date("%M")) end
        if s[K(side, "panelClock24")] == false then
            local suffix = h >= 12 and "pm" or "am"
            h = h % 12; if h == 0 then h = 12 end
            return ("%d:%02d %s"):format(h, m, suffix)
        end
        return ("%02d:%02d"):format(h, m)
    end,
    tip = function() return "Time", (date("%A %d %B")) end,
}
PROVIDERS.FPS = { text = function(_, _) local f = math.floor((GetFramerate and GetFramerate() or 0) + 0.5); return ("%s%d|r fps"):format(Ramp(f, 60, 30), f) end }
PROVIDERS.LATENCY = {
    text = function()
        local _, _, home, world = GetNetStats()
        local ms = world or home or 0
        return ("%s%d|r ms"):format(Ramp(ms, 60, 150, true), ms)
    end,
    tip = function()
        local _, _, home, world = GetNetStats()
        return "Latency", ("Home: %d ms"):format(home or 0), ("World: %d ms"):format(world or 0)
    end,
}
PROVIDERS.FPSMS = {
    text = function()
        local f = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
        local _, _, home, world = GetNetStats()
        local ms = world or home or 0
        return ("FPS: %s%d|r MS: %s%d|r"):format(Ramp(f, 60, 30), f, Ramp(ms, 60, 150, true), ms)
    end,
    tip = PROVIDERS.LATENCY.tip,
}
PROVIDERS.FRIENDS = {
    text = function(s, side)
        local wow = (C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends()) or 0
        local bn = 0
        if BNGetNumFriends then local _, online = BNGetNumFriends(); bn = online or 0 end
        return ("Friends: %s%d|r"):format(Val(s, side), wow + bn)
    end,
    click = function() if ToggleFriendsFrame then ToggleFriendsFrame(1) end end,
    tip = function()
        local wow = (C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends()) or 0
        local bn = 0
        if BNGetNumFriends then local _, online = BNGetNumFriends(); bn = online or 0 end
        return "Friends online", ("Game friends: %d"):format(wow), ("Battle.net friends: %d"):format(bn)
    end,
}
PROVIDERS.GOLD = {
    text = function()
        local g = math.floor((GetMoney and GetMoney() or 0) / 10000)
        local txt = BreakUpLargeNumbers and BreakUpLargeNumbers(g) or tostring(g)
        return txt .. "|cffffd100g|r"
    end,
    click = function() if ToggleAllBags then ToggleAllBags() end end,
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
        return ("Dur %s%d%%|r"):format(Ramp(lowest, 50, 25), math.floor(lowest + 0.5))
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
    click = function() if ToggleAllBags then ToggleAllBags() end end,
}
PROVIDERS.CUSTOM = { text = function(s, side, i) return s[K(side, "panelCustom" .. i)] or "" end }

-- frames ------------------------------------------------------------------------------------------------------------------
local TOGGLE_W = 20
local function OpenWindow() if ns.ChatPanel_ShowWindow then ns.ChatPanel_ShowWindow() end end

local function Over(f)
    if not f then return false end
    if f.IsMouseOver then local ok, v = pcall(f.IsMouseOver, f); if ok then return v and true or false end end
    return MouseIsOver and MouseIsOver(f) and true or false
end

local function WindowOf(side)
    if side == "L" then return _G.ChatFrame1 end
    return ns.ChatPanels_RightWindow and ns.ChatPanels_RightWindow() or nil
end
local function CollapsedOf(side)
    if side == "L" then return ns.ChatDock_IsCollapsed and ns.ChatDock_IsCollapsed() or false end
    return ns.ChatPanels_IsRightCollapsed and ns.ChatPanels_IsRightCollapsed() or false
end
local function ToggleInset(s, side)
    return (s.cpHideToggles and 0 or TOGGLE_W + 2)
end

local function UpdateText(side)
    local s, P = Store(), panels[side]
    if not (s and P.frame and P.frame:IsShown()) then return end
    local n = math.max(1, math.min(3, tonumber(s[K(side, "panelSlots")]) or 3))
    for i = 1, 3 do
        local slot = P.slots[i]
        if slot then
            if i <= n then
                local pr = PROVIDERS[s[K(side, "panelSlot" .. i)] or "NONE"] or PROVIDERS.NONE
                local ok, txt = pcall(pr.text, s, side, i)
                slot.fs:SetText(ok and txt or "?")
            else
                slot.fs:SetText("")
            end
        end
    end
end

local function Layout(side)
    local s, P = Store(), panels[side]
    if not (s and P.frame) then return end
    local n = math.max(1, math.min(3, tonumber(s[K(side, "panelSlots")]) or 3))
    local w = (P.frame:GetWidth() or 0)
    local inset = ToggleInset(s, side)
    local usable = w - inset
    local x0 = (side == "L") and inset or 0
    for i = 1, 3 do
        local slot = P.slots[i]
        slot:ClearAllPoints()
        if i <= n and usable > 0 then
            local sw = usable / n
            slot:SetPoint("TOPLEFT", P.frame, "TOPLEFT", x0 + (i - 1) * sw, 0)
            slot:SetPoint("BOTTOMLEFT", P.frame, "BOTTOMLEFT", x0 + (i - 1) * sw, 0)
            slot:SetWidth(sw)
            slot:Show()
        else
            slot:Hide()
        end
    end
end

local function UpdateToggle(side)
    local s, P = Store(), panels[side]
    if not (s and P.toggle) then return end
    local t = P.toggle
    t:ClearAllPoints()
    if side == "L" then
        t:SetPoint("TOPLEFT", P.frame, "TOPLEFT", 0, 0); t:SetPoint("BOTTOMLEFT", P.frame, "BOTTOMLEFT", 0, 0)
    else
        t:SetPoint("TOPRIGHT", P.frame, "TOPRIGHT", 0, 0); t:SetPoint("BOTTOMRIGHT", P.frame, "BOTTOMRIGHT", 0, 0)
    end
    t:SetWidth(TOGGLE_W)
    t:SetShown(not s.cpHideToggles)
    local collapsed = CollapsedOf(side)
    local out = (side == "L") and "LEFT" or "RIGHT"          -- arrow when the window is showing: it will slide away this way
    local back = (side == "L") and "RIGHT" or "LEFT"
    if t.chevron then t.chevron:SetDir(collapsed and back or out) end
    t:SetAlpha((collapsed and s.cpFadeToggles) and 0.3 or 1)
end

local function Build(side)
    local P = panels[side]
    if P.frame then return P.frame end
    local f = CreateFrame("Frame", side == "L" and "XayaUIChatPanel" or "XayaUIChatPanelRight", UIParent, "BackdropTemplate")
    P.frame, P.slots = f, {}
    f:SetFrameStrata("LOW"); f:SetFrameLevel(5)
    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function(_, b) if b == "RightButton" then OpenWindow() end end)
    for i = 1, 3 do
        local slot = CreateFrame("Button", nil, f)
        slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        slot.fs = slot:CreateFontString(nil, "OVERLAY")
        slot.fs:SetPoint("CENTER", 0, 0)
        slot.fs:SetFont(STANDARD_TEXT_FONT, 12, "")
        slot:SetScript("OnClick", function(_, b)
            if b == "RightButton" then OpenWindow() return end
            local s = Store(); if not s then return end
            local pr = PROVIDERS[s[K(side, "panelSlot" .. i)] or "NONE"]
            if pr and pr.click then pcall(pr.click) end
        end)
        slot:SetScript("OnEnter", function(self)
            local s = Store(); if not s then return end
            local key = s[K(side, "panelSlot" .. i)] or "NONE"
            local pr = PROVIDERS[key]
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if pr and pr.tip then
                local a, b, c = pr.tip(s)
                GameTooltip:SetText(a or "")
                if b then GameTooltip:AddLine(b, 1, 1, 1) end
                if c then GameTooltip:AddLine(c, 1, 1, 1) end
            else
                GameTooltip:SetText(NAMES[key] or "")
            end
            if pr and pr.click then GameTooltip:AddLine("Click: open", 0.6, 0.6, 0.6) end
            GameTooltip:AddLine("Right-click: panel settings", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        P.slots[i] = slot
    end
    -- toggle button at the outer end: hides / shows that chat window
    if ns.CW then
        local t = ns.CW.Button(f, TOGGLE_W, 20, "", function()
            if side == "L" then ns.ChatDock_SetCollapsed(not CollapsedOf("L"))
            else ns.ChatPanels_SetRightCollapsed(not CollapsedOf("R")) end
        end)
        t.chevron = ns.CW.Chevron(t, 14, "LEFT", 1, 0.82, 0)
        t.chevron.holder:SetPoint("CENTER")
        t:HookScript("OnEnter", function(self) self:SetAlpha(1); GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(CollapsedOf(side) and "Show chat" or "Hide chat"); GameTooltip:Show() end)
        t:HookScript("OnLeave", function() GameTooltip:Hide(); UpdateToggle(side) end)
        P.toggle = t
    end
    local acc, accHover = 0, 0
    f:SetScript("OnUpdate", function(self, dt)
        acc = acc + dt; accHover = accHover + dt
        if acc >= 1 then acc = 0; UpdateText(side) end
        if accHover >= 0.1 then
            accHover = 0
            local s = Store()
            if s and s[K(side, "panelFadeUntilHover")] then
                self:SetAlpha((Over(self) or Over(WindowOf(side))) and 1 or 0)
            elseif self:GetAlpha() ~= 1 then
                self:SetAlpha(1)
            end
        end
    end)
    f:SetScript("OnSizeChanged", function() Layout(side) end)
    return f
end

local function Style(s, side)
    local f, P = panels[side].frame, panels[side]
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(s[K(side, "panelBgR")] or 0, s[K(side, "panelBgG")] or 0, s[K(side, "panelBgB")] or 0,
        s[K(side, "panelBg")] and (s[K(side, "panelBgAlpha")] or 45) / 100 or 0)
    f:SetBackdropBorderColor(s[K(side, "panelBorderR")] or 0, s[K(side, "panelBorderG")] or 0, s[K(side, "panelBorderB")] or 0, s[K(side, "panelBorder")] and 1 or 0)
    local path = (ns.FontPath and ns.FontPath(s.font)) or STANDARD_TEXT_FONT
    local size = math.max(6, math.min(40, tonumber(s[K(side, "panelTextSize")]) or 13))
    for i = 1, 3 do
        local fs = P.slots[i].fs
        if not fs:SetFont(path or STANDARD_TEXT_FONT, size, "OUTLINE") then fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
        fs:SetTextColor(s[K(side, "panelTextR")] or 1, s[K(side, "panelTextG")] or 1, s[K(side, "panelTextB")] or 1)
    end
end

local function Place(s, side, cf)
    local f = panels[side].frame
    f:ClearAllPoints()
    local h = math.max(10, tonumber(s[K(side, "panelHeight")]) or 22)
    local gap = tonumber(s[K(side, "panelGap")]) or 2
    local ox, oy = tonumber(s[K(side, "panelOffX")]) or 0, tonumber(s[K(side, "panelOffY")]) or 0
    local below = s[K(side, "panelAnchor")] ~= "ABOVE"
    local fromPoint, toPoint, fromR, toR, y
    if below then
        fromPoint, fromR, toPoint, toR, y = "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", -gap + oy
    else
        -- above the window: clear the tab row too
        local tab = _G[(cf:GetName() or "ChatFrame1") .. "Tab"]
        local tabH = (tab and tab:GetHeight() or 24)
        fromPoint, fromR, toPoint, toR, y = "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT", "TOPRIGHT", tabH + gap + oy
    end
    f:SetPoint(fromPoint, cf, toPoint, ox, y)
    if s[K(side, "panelWidthMode")] == "CUSTOM" then
        f:SetSize(math.max(40, tonumber(s[K(side, "panelWidth")]) or 400), h)
    else
        f:SetPoint(fromR, cf, toR, ox, y)
        f:SetHeight(h)
    end
end

local function RefreshSide(side)
    local s = Store()
    if not s then return end
    local P = panels[side]
    local cf = WindowOf(side)
    local collapsed = CollapsedOf(side)
    local off = (not s[K(side, "panelOn")]) or (not cf)
        or (s[K(side, "panelHideWhenCollapsed")] and collapsed)
    if off then
        if P.frame then P.frame:Hide() end
        return
    end
    Build(side); Style(s, side); Place(s, side, cf); P.frame:Show()
    Layout(side); UpdateToggle(side); UpdateText(side)
end

function ns.ChatPanel_Refresh()
    RefreshSide("L"); RefreshSide("R")
    C_Timer.After(0, function() for _, side in ipairs({ "L", "R" }) do if panels[side].frame and panels[side].frame:IsShown() then Layout(side); UpdateText(side) end end end)
end

-- standalone settings window ----------------------------------------------------------------------------------------------
local function BuildWindow()
    if win then return win end
    local CW = ns.CW
    if not CW then return end
    local f = CW.Window("XayaUIChatPanelWindow", "Chat data panels", 310, 560)
    win = f
    local function S() return Store() or {} end
    local function setv(k) return function(v) local s = Store(); if s then s[K(editSide, k)] = v end; ns.ChatPanel_Refresh() end end
    local function getv(k) return function() return S()[K(editSide, k)] end end
    local function check(label, k, default)
        return CW.Check(label, function() local v = S()[K(editSide, k)]; if v == nil then return default end; return v end, setv(k))
    end
    local function num(label, k, min, max, step) return CW.Number(label, getv(k), setv(k), min, max, step) end
    local function color(label, k)
        return CW.Color(label, function() local s = S(); return s[K(editSide, k .. "R")] or 1, s[K(editSide, k .. "G")] or 1, s[K(editSide, k .. "B")] or 1 end,
            function(r, g, b) local s = Store(); if s then s[K(editSide, k .. "R")], s[K(editSide, k .. "G")], s[K(editSide, k .. "B")] = r, g, b end; ns.ChatPanel_Refresh() end)
    end

    f:Add(CW.Note("Info bars under the chat windows (right-click a bar to open this). Changes apply immediately and are saved. Scroll with the mouse wheel.", 0.7, 0.7, 0.7), 30)
    f:Add(CW.Cycle("Editing", { { "L", "Left panel (main chat)" }, { "R", "Right panel" } }, function() return editSide end,
        function(v) editSide = v; f:RefreshAll() end), 20)
    f:Add(CW.Note("The right panel sits under the chat window chosen as \"right chat window\" (chat tab > Panels). Without one it stays hidden.", 0.6, 0.6, 0.6), 30)
    f:Add(check("Show this panel", "panelOn"), 20)
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
    f:Add(color("Text color", "panelText"), 20)
    f:Add(color("Value color (friends count)", "panelValue"), 20, 8)

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
    f:Add(check("Hide while its chat window is collapsed", "panelHideWhenCollapsed", false), 20)
    f:Add(check("Show only while the mouse is over the chat or the panel", "panelFadeUntilHover"), 20)
    f:Add(CW.Check("Hide the toggle buttons (both panels)", function() return S().cpHideToggles end,
        function(v) local s = Store(); if s then s.cpHideToggles = v and true or false end; ns.ChatPanel_Refresh() end), 20)
    f:Add(CW.Check("Fade a toggle button while its chat window is hidden (both panels)", function() return S().cpFadeToggles end,
        function(v) local s = Store(); if s then s.cpFadeToggles = v and true or false end; ns.ChatPanel_Refresh() end), 20, 8)

    local row = CreateFrame("Frame")
    local reset = CW.Button(row, 170, 20, "Reset this panel's settings", function()
        local s = Store(); if not s then return end
        local pre = (editSide == "R") and "rpanel" or "panel"
        for k, v in pairs(ns.CHAT_DEFAULTS) do if k:sub(1, #pre) == pre and (editSide == "R" or k:sub(1, 6) ~= "rpanel") then s[k] = v end end
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

function ns.ChatPanel_SetOn(v, side)
    local s = Store(); if not s then return end
    s[K(side or "L", "panelOn")] = v and true or false
    ns.ChatPanel_Refresh()
end

-- driver -------------------------------------------------------------------------------------------------------------------
local drv = CreateFrame("Frame")
drv:RegisterEvent("PLAYER_ENTERING_WORLD")
drv:RegisterEvent("UPDATE_CHAT_WINDOWS")
drv:RegisterEvent("FRIENDLIST_UPDATE")
drv:RegisterEvent("BN_FRIEND_INFO_CHANGED")
drv:SetScript("OnEvent", function(_, ev)
    if ev == "PLAYER_ENTERING_WORLD" or ev == "UPDATE_CHAT_WINDOWS" then
        C_Timer.After(0.3, function() if ns.ChatPanels_Refresh then ns.ChatPanels_Refresh() else ns.ChatPanel_Refresh() end end)
    end
end)
