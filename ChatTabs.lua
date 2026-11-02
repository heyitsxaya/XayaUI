-------------------------------------------------------------------------------
-- ChatTabs.lua : Chat Reskin, tabs. Own code only.
--   * Blizzard's tab art is removed and each tab gets a flat background (selected / not selected colors).
--   * The selected tab is marked with a selector around its name (> Name <, [ Name ], { Name }, ( Name ) or none) in its own color.
--   * Selected / not selected text colors, whisper tabs in the class color of the person, dimmed inactive docked tabs.
--   * Optional: tab names and the copy button only show while the mouse is over the chat or its tab.
-- UNTESTED in game. A wrong API name is caught (pcall) and shown by /xui chat; it cannot break the chat window.
-------------------------------------------------------------------------------
local addonName, ns = ...

local T = {}
ns.ChatTabs = T
local issecret = _G.issecretvalue or function() return false end
local errors, hooked = {}, {}
T.errors = errors

local function Store() return ns.chatDB end
local function On(s) return s and s.enabled and not (ns.ChatReskin_BlockedReason and ns.ChatReskin_BlockedReason()) end
local function Try(what, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not errors[what] then errors[what] = tostring(err) end
    return ok
end
local function Hex(r, g, b) return string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5)) end

-- how the selected tab's name is wrapped: %s = selector color, name, selector color
T.STYLES = {
    NONE = "%s", ARROW = "%s>|r%s%s<|r", ARROW1 = "%s>|r %s %s<|r", ARROW2 = "%s<|r%s%s>|r", ARROW3 = "%s<|r %s %s>|r",
    BOX = "%s[|r%s%s]|r", BOX1 = "%s[|r %s %s]|r", CURLY = "%s{|r%s%s}|r", CURLY1 = "%s{|r %s %s}|r",
    CURVE = "%s(|r%s%s)|r", CURVE1 = "%s(|r %s %s)|r",
}
T.STYLE_NAMES = { NONE = "None", ARROW = "> Name <", ARROW1 = ">  Name  <", ARROW2 = "< Name >", ARROW3 = "<  Name  >",
    BOX = "[Name]", BOX1 = "[ Name ]", CURLY = "{Name}", CURLY1 = "{ Name }", CURVE = "(Name)", CURVE1 = "( Name )" }
T.STYLE_ORDER = { "NONE", "ARROW", "ARROW1", "ARROW2", "ARROW3", "BOX", "BOX1", "CURLY", "CURLY1", "CURVE", "CURVE1" }

-- The text of a selected tab: pure function (tested offline).
function T.SelectedText(style, name, r, g, b)
    local fmt = T.STYLES[style] or T.STYLES.ARROW1
    if style == "NONE" then return name end
    local hex = Hex(r, g, b)
    return string.format(fmt, hex, name, hex)
end

local TEX_PREFIXES = { "", "Selected", "Active", "Highlight" }
local function TabOf(frame) return frame.tab or _G[(frame:GetName() or "") .. "Tab"] end
local function TextOf(tab) return tab and (tab.Text or _G[(tab:GetName() or "") .. "Text"]) end
local function ChatOfTab(tab)
    if tab.xuiOwner then return tab.xuiOwner end
    local id = tab:GetID()
    tab.xuiOwner = id and _G["ChatFrame" .. id]
    return tab.xuiOwner
end

-- Fade the tab's text: everywhere (old option), for undocked tabs, or for tabs docked in a panel whose backdrop is hidden.
local function FadeOn(s, chat)
    if s.tabFadeUntilHover then return true end
    if not chat then return false end
    if s.fadeUndockedTabs and not chat.isDocked then return true end
    if s.fadeTabsNoBackdrop and chat.isDocked and ns.ChatPanels_LeftBackdropHidden and ns.ChatPanels_LeftBackdropHidden() then return true end
    return false
end
T.FadeOn = FadeOn

local function StripArt(tab, name)
    for _, p in ipairs(TEX_PREFIXES) do
        for _, side in ipairs({ "Left", "Middle", "Right" }) do
            local key = p .. side
            local t = _G[name .. "Tab" .. key] or tab[key]
            if t and t.SetTexture then pcall(t.SetTexture, t); t:SetAlpha(0) end
        end
    end
    for _, key in ipairs({ "glow", "Glow", "leftHighlightTexture", "middleHighlightTexture", "rightHighlightTexture" }) do
        -- the new-message glow stays: it is how Blizzard flashes a tab. Only the highlight art is removed.
        if key:find("ighlight") and tab[key] then tab[key]:SetAlpha(0) end
    end
end

local function EnsureBackground(tab)
    if tab.xuiBG then return tab.xuiBG end
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -3)
    bg:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 0)
    tab.xuiBG = bg
    return bg
end

-- Colors / name / background of one tab (called from Blizzard's own tab color function and from refreshes).
function T.UpdateTab(tab, selected)
    local s = Store()
    if not tab or not On(s) or not tab.GetID then return end
    if tab:GetParent() == _G.ChatConfigFrameChatTabManager then return end
    local chat = ChatOfTab(tab)
    local text = TextOf(tab)
    if not chat or not text then return end
    if selected == nil then selected = tab.xuiSelected end
    tab.xuiSelected = selected and true or false
    local name = chat.name or _G.UNKNOWN or "?"
    if issecret(name) or type(name) ~= "string" then return end
    local whisper = tab.conversationIcon and chat.chatTarget and true
    local shown = name
    if whisper then
        tab.xuiWhisperName = tab.xuiWhisperName or name:gsub("([%S]-)%-[%S]+", "%1|cFF999999*|r")
        shown = tab.xuiWhisperName
    end
    if selected then
        local sel = s.tabSelector or "ARROW1"
        local label = (sel == "NONE") and shown or T.SelectedText(sel, shown, s.tabSelR, s.tabSelG, s.tabSelB)
        if tab.SetText then tab:SetText(label) end
        if s.tabSelectedTextEnabled then
            text:SetTextColor(s.tabR or 1, s.tabG or 1, s.tabB or 1)
        end
    else
        if tab.SetText then tab:SetText(shown) end
        local r, g, b = s.tabTextR or 0.75, s.tabTextG or 0.75, s.tabTextB or 0.75
        if whisper and s.tabClassWhispers then
            local token = ns.ChatText and ns.ChatText.ClassToken and ns.ChatText.ClassToken(name)
            local tbl = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
            local c = token and tbl and tbl[token]
            if c then r, g, b = c.r, c.g, c.b end
        end
        text:SetTextColor(r, g, b)
    end
    local bg = EnsureBackground(tab)
    if s.tabBackdrop then
        if selected then bg:SetColorTexture(s.tabBgSelR or 0.18, s.tabBgSelG or 0.18, s.tabBgSelB or 0.18, (s.tabBgSelAlpha or 80) / 100)
        else bg:SetColorTexture(s.tabBgR or 0, s.tabBgG or 0, s.tabBgB or 0, (s.tabBgAlpha or 45) / 100) end
        bg:Show()
    else
        bg:Hide()
    end
    if FadeOn(s, chat) and not tab.xuiHover then bg:SetAlpha(0) else bg:SetAlpha(1) end
end

local function AlphaOf(tab, selected)
    local s = Store()
    if not On(s) or not s.tabDimInactive then return nil end
    local chat = ChatOfTab(tab)
    if not chat then return nil end
    local sel = _G.GeneralDockManager and _G.GeneralDockManager.selected
    return ((not chat.isDocked) or chat == sel) and 1 or 0.6
end

local function Hover(chat, tab, on)
    local s = Store()
    if not On(s) or not FadeOn(s, chat) then return end
    tab.xuiHover = on
    local text = TextOf(tab)
    if text then text:SetShown(on) end
    if tab.conversationIcon then tab.conversationIcon:SetShown(on) end
    if tab.xuiBG then tab.xuiBG:SetAlpha(on and 1 or 0) end
    if chat and chat.xuiCopy then chat.xuiCopy:SetAlpha(on and 0.35 or 0) end
end

local function StyleTab(chat)
    local tab = TabOf(chat)
    if not tab then return end
    local s = Store()
    local name = chat:GetName() or ""
    Try("tabArt", StripArt, tab, name)
    local text = TextOf(tab)
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", tab, "CENTER", 0, -1)
    end
    -- Height 0 = Blizzard's own height. Changing it moves the first tab (anchored by its bottom) away from the others (centered in the
    -- dock's scroll frame), so the added tabs floated above the chat; a custom height therefore also re-anchors the dock (T.FixDock).
    local h = tonumber(s.tabHeightCustom) or 0
    if h > 0 and tab.SetHeight then tab:SetHeight(h) end
    if tab.conversationIcon then
        tab.conversationIcon:ClearAllPoints()
        tab.conversationIcon:SetPoint("RIGHT", text or tab, "LEFT", -1, 0)
    end
    if not hooked[tab] then
        hooked[tab] = true
        Try("tabAlpha", hooksecurefunc, tab, "SetAlpha", function(self, _, skip)
            if skip then return end
            local a = AlphaOf(self)
            if a then self:SetAlpha(a, true) end
        end)
        Try("tabHover", function()
            tab:HookScript("OnEnter", function() Hover(chat, tab, true) end)
            tab:HookScript("OnLeave", function() Hover(chat, tab, false) end)
            chat:HookScript("OnEnter", function() Hover(chat, tab, true) end)
            chat:HookScript("OnLeave", function() Hover(chat, tab, false) end)
        end)
    end
    local dock = _G.GeneralDockManager
    local selected = (not chat.isDocked) or (dock and dock.selected == chat) or false
    T.UpdateTab(tab, selected)
    local a = AlphaOf(tab)
    if a then tab:SetAlpha(a, true) end
    if FadeOn(s, chat) then
        if not tab.xuiHover then Hover(chat, tab, false) end
    else
        tab.xuiHover = nil
        if text then text:Show() end
        if tab.conversationIcon then tab.conversationIcon:Show() end
        if chat.xuiCopy then chat.xuiCopy:SetAlpha(0.35) end
    end
end

-- Keep the docked tabs level with the first tab when a custom tab height is set: the dock's scroll frame starts at the top of the
-- first (or combat log) tab and is as tall as the tabs.
function T.FixDock()
    local s = Store()
    local h = s and tonumber(s.tabHeightCustom) or 0
    local dock = _G.GeneralDockManager
    if h <= 0 or not On(s) or not dock or not dock.scrollFrame or not dock.primary or not dock.overflowButton then return end
    local log = _G.COMBATLOG
    local first = (log and log.isDocked and TabOf(log)) or TabOf(dock.primary)
    if not first then return end
    local sf = dock.scrollFrame
    sf:ClearAllPoints()
    sf:SetPoint("TOPLEFT", first, "TOPRIGHT", 0, 0)
    sf:SetPoint("RIGHT", dock.overflowButton, "LEFT", 0, 0)
    sf:SetHeight(h)
end

local pendingDock
local function RefreshDock()
    if pendingDock then return end
    pendingDock = true
    C_Timer.After(0, function()
        pendingDock = nil
        -- tab widths change with the selector text: let Blizzard lay the docked tabs out again
        if _G.FCFDock_UpdateTabs and _G.GENERAL_CHAT_DOCK then pcall(_G.FCFDock_UpdateTabs, _G.GENERAL_CHAT_DOCK, true) end
        pcall(T.FixDock)
    end)
end

function T.Apply(s)
    if not On(s) then return end
    for _, f in ipairs((ns.ChatText and ns.ChatText.Frames and ns.ChatText.Frames()) or {}) do
        Try("styleTab", StyleTab, f)
    end
    if not hooked.global then
        hooked.global = true
        if _G.hooksecurefunc and type(_G.FCFTab_UpdateColors) == "function" then
            Try("hookColors", hooksecurefunc, "FCFTab_UpdateColors", function(tab, selected)
                local st = Store()
                if On(st) then pcall(T.UpdateTab, tab, selected) end
            end)
        end
        if type(_G.FCFDock_ScrollToSelectedTab) == "function" then
            Try("hookScroll", hooksecurefunc, "FCFDock_ScrollToSelectedTab", function() local st = Store(); if On(st) then pcall(T.FixDock) end end)
        end
        if type(_G.FCFDock_SelectWindow) == "function" then
            Try("hookSelect", hooksecurefunc, "FCFDock_SelectWindow", function()
                C_Timer.After(0, function() local st = Store(); if On(st) then T.Apply(st) end end)
            end)
        end
    end
    RefreshDock()
end

function T.Debug(say)
    local any
    for k, v in pairs(errors) do say("  chat tabs ERROR " .. k .. ": " .. v); any = true end
    if not any then say("  chat tabs: no errors recorded") end
end
