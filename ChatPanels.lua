-------------------------------------------------------------------------------
-- ChatPanels.lua : "Chat Panels" tab (QoL UI Updates > Custom Data Panels and Bars > Chat Panels): panel options for the Blizzard chat windows (own code).
--   * Chat panels: a backdrop behind the left window (ChatFrame1) and an optional right window, backdrop color / mode / textures,
--     panel width and height (applied to the chat windows when "Apply panel sizes" is on), Panel Snapping (backdrop replaces Blizzard's
--     window background).
--   * Tab panel: a strip behind the docked tabs, with transparency.
--   * Fade undocked tabs / Fade tabs without backdrop (used by ChatTabs.lua).
--   * Chat toggles (hide / fade) and the right window's collapse state (the left window's lives in ChatDock.lua).
--   * Data text panel positions and on/off (the panels themselves are in ChatPanel.lua).
-- "Right chat window": there is no separate right panel; you pick which Blizzard window plays that role.
-- UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local D = ns.CHAT_DEFAULTS
D.cpSnapping = false                -- backdrop panels replace Blizzard's window background (off so nothing changes until chosen)
D.cpBackdrop = "SHOWBOTH"           -- SHOWBOTH | LEFT | RIGHT | HIDEBOTH
D.cpColorR, D.cpColorG, D.cpColorB, D.cpColorA = 0, 0, 0, 32      -- seeded from Xaya's previous chat setup (0, 0, 0 at 0.3157)
D.cpTab = true; D.cpTabTransparent = true                         -- seeded from the same profile (both on)
D.cpSeparate = true                                               -- seeded: separate sizes on
D.cpWidth, D.cpHeight, D.cpWidthR, D.cpHeightR = 443, 180, 400, 180   -- seeded: 443 / 400 wide, 180 high
D.cpSizesOn = false                 -- the sizes only act on the chat windows when this is on
D.cpRightWindow = "NONE"            -- "NONE" or "ChatFrame2".."ChatFrame10"
D.cpRightCollapsed = false
D.cpTexL, D.cpTexR = "", ""
D.fadeUndockedTabs = false; D.fadeTabsNoBackdrop = true
D.cpHideToggles = false; D.cpFadeToggles = true
D.cpVer = 0

local WHITE = "Interface\\Buttons\\WHITE8X8"
local function Store() return ns.chatDB end
local hidden = CreateFrame("Frame"); hidden:Hide()
local origParent = setmetatable({}, { __mode = "k" })
local bd, tabPanel = {}, nil
local bgHidden = setmetatable({}, { __mode = "k" })

-- windows ------------------------------------------------------------------------------------------------------------------
function ns.ChatPanels_RightWindow()
    local s = Store()
    if not s or not s.cpRightWindow or s.cpRightWindow == "NONE" then return nil end
    local w = _G[s.cpRightWindow]
    if w and w ~= _G.ChatFrame1 and (w:IsShown() or origParent[w]) then return w end
    return nil
end

function ns.ChatPanels_IsRightCollapsed()
    local s = Store()
    return s and s.cpRightCollapsed and ns.ChatPanels_RightWindow() ~= nil or false
end

function ns.ChatPanels_LeftBackdropHidden()
    local s = Store()
    return s and s.cpSnapping and (s.cpBackdrop == "HIDEBOTH" or s.cpBackdrop == "RIGHT") or false
end

local function ModeShows(s, side)
    local m = s.cpBackdrop or "SHOWBOTH"
    return m == "SHOWBOTH" or (m == "LEFT" and side == "L") or (m == "RIGHT" and side == "R")
end

-- right window collapse ----------------------------------------------------------------------------------------------------
local function ApplyRightCollapse(s)
    local rw = ns.ChatPanels_RightWindow()
    local keep = {}
    if s.cpRightCollapsed and rw and not rw.isDocked then
        keep[rw] = true
        local tab = _G[(rw:GetName() or "") .. "Tab"]
        if tab then keep[tab] = true end
    end
    -- put back anything we hid earlier that is no longer meant to be hidden
    for f, p in pairs(origParent) do
        if not keep[f] then
            if f:GetParent() == hidden then f:SetParent(p) end
            origParent[f] = nil
        end
    end
    for f in pairs(keep) do
        if f:GetParent() ~= hidden then origParent[f] = f:GetParent(); f:SetParent(hidden) end
    end
end

function ns.ChatPanels_SetRightCollapsed(v)
    local s = Store(); if not s then return end
    s.cpRightCollapsed = v and true or false
    ns.ChatPanels_Refresh()
end

-- backdrops ----------------------------------------------------------------------------------------------------------------
local function Backdrop(side)
    if bd[side] then return bd[side] end
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetFrameStrata("BACKGROUND"); f:SetFrameLevel(1)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", 1, -1); f.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    bd[side] = f
    return f
end

local function StyleBackdrop(s, side, win, collapsed)
    local f = Backdrop(side)
    if not (s.cpSnapping and ModeShows(s, side) and win and not collapsed and win:GetLeft()) then f:Hide() return end
    local tab = _G[(win:GetName() or "") .. "Tab"]
    local tabH = (tab and tab:GetHeight()) or 24
    local extra = (ns.ChatDock_SideExtra and ns.ChatDock_SideExtra(win)) or 0
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", win, "TOPLEFT", -4, tabH + 4)
    f:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", extra + 4, -4)
    f:SetBackdropColor(s.cpColorR or 0, s.cpColorG or 0, s.cpColorB or 0, (s.cpColorA or 32) / 100)
    f:SetBackdropBorderColor(0, 0, 0, 0.8)
    local path = tostring(side == "L" and s.cpTexL or s.cpTexR or "")
    if path ~= "" then
        f.tex:SetTexture(path); f.tex:SetAlpha(0.5); f.tex:Show()
    else
        f.tex:Hide()
    end
    f:Show()
end

local function StyleTabPanel(s, collapsed)
    local dock = _G.GeneralDockManager
    if not tabPanel then
        tabPanel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        tabPanel:SetFrameStrata("BACKGROUND"); tabPanel:SetFrameLevel(2)
        tabPanel:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    end
    if not (s.cpSnapping and s.cpTab and dock and not collapsed and dock:GetLeft()) then tabPanel:Hide() return end
    tabPanel:ClearAllPoints()
    tabPanel:SetPoint("TOPLEFT", dock, "TOPLEFT", -2, 2)
    tabPanel:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 2, -2)
    local a = s.cpTabTransparent and 0.35 or 0.9
    tabPanel:SetBackdropColor(s.cpColorR or 0, s.cpColorG or 0, s.cpColorB or 0, a)
    tabPanel:SetBackdropBorderColor(0, 0, 0, 0.8)
    tabPanel:Show()
end

-- Panel Snapping: the backdrop replaces Blizzard's own window background. Only the texture's alpha is touched, so it can be given back.
local function ApplyBlizzardBackground(s, win)
    if not win then return end
    local bg = _G[(win:GetName() or "") .. "Background"]
    if not (bg and bg.SetAlpha) then return end
    if s.cpSnapping then
        bg:SetAlpha(0); bgHidden[win] = true
    elseif bgHidden[win] then
        bg:SetAlpha(1); bgHidden[win] = nil
    end
end

local function ApplySizes(s)
    if not s.cpSizesOn then return end
    local lw, rw = _G.ChatFrame1, ns.ChatPanels_RightWindow()
    local function size(win, w, h)
        if not win or (InCombatLockdown() and win:IsProtected()) then return end
        pcall(function()
            win:SetSize(w, h)
            if FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(win) end
        end)
    end
    size(lw, tonumber(s.cpWidth) or 443, tonumber(s.cpHeight) or 180)
    if s.cpSeparate then size(rw, tonumber(s.cpWidthR) or 400, tonumber(s.cpHeightR) or 180)
    else size(rw, tonumber(s.cpWidth) or 443, tonumber(s.cpHeight) or 180) end
end

function ns.ChatPanels_Refresh()
    local s = Store()
    if not s then return end
    if (s.cpVer or 0) < 1 then   -- 0.5.30 defaulted the data panel to hide while collapsed; the toggle button needs it to stay
        s.cpVer = 1; s.panelHideWhenCollapsed = false; s.rpanelHideWhenCollapsed = false
    end
    ApplyRightCollapse(s)
    ApplySizes(s)
    local lw, rw = _G.ChatFrame1, ns.ChatPanels_RightWindow()
    local lc = ns.ChatDock_IsCollapsed and ns.ChatDock_IsCollapsed()
    local rc = ns.ChatPanels_IsRightCollapsed()
    StyleBackdrop(s, "L", lw, lc)
    StyleBackdrop(s, "R", rw, rc)
    StyleTabPanel(s, lc)
    ApplyBlizzardBackground(s, lw); ApplyBlizzardBackground(s, rw)
    if ns.ChatPanel_Refresh then ns.ChatPanel_Refresh() end
    if ns.ChatTabs and ns.ChatTabs.Apply and s.enabled then pcall(ns.ChatTabs.Apply, s) end
end

local drv = CreateFrame("Frame")
drv:RegisterEvent("PLAYER_ENTERING_WORLD")
drv:RegisterEvent("UPDATE_CHAT_WINDOWS")
drv:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
drv:SetScript("OnEvent", function() C_Timer.After(0.5, ns.ChatPanels_Refresh) end)
if hooksecurefunc and type(_G.FCF_SetWindowAlpha) == "function" then
    hooksecurefunc("FCF_SetWindowAlpha", function() C_Timer.After(0, ns.ChatPanels_Refresh) end)
end

function ns.ChatPanels_Debug(say)
    local s = Store() or {}
    local rw = ns.ChatPanels_RightWindow()
    say("panels: snapping=" .. tostring(s.cpSnapping) .. " mode=" .. tostring(s.cpBackdrop) .. " sizesOn=" .. tostring(s.cpSizesOn)
        .. " rightWindow=" .. tostring(s.cpRightWindow) .. " (" .. tostring(rw and (rw:GetName() or "?") or "none") .. ")"
        .. " left backdrop=" .. tostring(bd.L and bd.L:IsShown()) .. " right backdrop=" .. tostring(bd.R and bd.R:IsShown())
        .. " tab panel=" .. tostring(tabPanel and tabPanel:IsShown()))
end

-- options: built by DataPanels.lua as a tab of Custom Data Panels and Bars (moved there from ElvUI Chat Reskin in 0.5.44) -------
function ns.ChatPanels_Options(Notify, order)
    local function S() return Store() or {} end
    local function Re() ns.ChatPanels_Refresh(); if Notify then Notify() end end
    local function tog(name, key, order, desc, disabled)
        return { type = "toggle", order = order, name = name, desc = desc, disabled = disabled,
            get = function() return S()[key] and true or false end,
            set = function(_, v) local s = Store(); if s then s[key] = v and true or false end; Re() end }
    end
    local function rng(name, key, order, min, max, disabled)
        return { type = "range", order = order, name = name, min = min, max = max, step = 1, disabled = disabled,
            get = function() return S()[key] or min end,
            set = function(_, v) local s = Store(); if s then s[key] = v end; Re() end }
    end
    local function windowValues()
        local v = { NONE = "None" }
        for i = 2, (NUM_CHAT_WINDOWS or 10) do
            local name = _G.GetChatWindowInfo and select(1, _G.GetChatWindowInfo(i)) or nil
            if name and name ~= "" then v["ChatFrame" .. i] = ("%d: %s"):format(i, name) end
        end
        return v
    end
    local function windowOrder()
        local o = { "NONE" }
        for i = 2, (NUM_CHAT_WINDOWS or 10) do
            local name = _G.GetChatWindowInfo and select(1, _G.GetChatWindowInfo(i)) or nil
            if name and name ~= "" then o[#o + 1] = "ChatFrame" .. i end
        end
        return o
    end
    local noRight = function() return ns.ChatPanels_RightWindow() == nil end
    return { type = "group", name = "Chat Panels", order = order or 7, args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Panel options for the Blizzard chat windows: the left panel is the main chat window; pick a window below to act as the right panel. The info bars beside the chat windows are set up on the General tab, Chat Panel section. Panel backdrops, tab panel, and sizes are off until you turn on Panel Snapping / Apply panel sizes. The tab fade options need the switch on ElvUI Chat Reskin > General." },
        fadeUndocked = tog("Fade Undocked Tabs", "fadeUndockedTabs", 1, "Fades the text on chat tabs that are not docked in the main chat window (needs the ElvUI Chat Reskin switch on, under ElvUI Chat Reskin > General)."),
        fadeNoBackdrop = tog("Fade Tabs No Backdrop", "fadeTabsNoBackdrop", 2, "Fades the text on docked tabs when the left panel's backdrop is hidden (needs Panel Snapping on)."),
        hideToggles = tog("Hide Chat Toggles", "cpHideToggles", 3, "Hides the small arrow buttons at the end of the data text panels."),
        fadeToggles = tog("Fade Chat Toggles", "cpFadeToggles", 4, "Fades the toggle button of a window that has been toggled off.", function() return S().cpHideToggles end),

        tabs = { type = "group", name = "Tab Panels", order = 20, inline = true, args = {
            trans = tog("Tab Panel Transparency", "cpTabTransparent", 1, nil, function() return not S().cpTab end),
            tab = tog("Tab Panel", "cpTab", 2, "A backdrop strip behind the docked chat tabs (needs Panel Snapping on)."),
        } },
        panels = { type = "group", name = "Chat Panels", order = 30, inline = true, args = {
            color = { type = "color", order = 1, name = "Backdrop Color", hasAlpha = true,
                get = function() local s = S(); return s.cpColorR or 0, s.cpColorG or 0, s.cpColorB or 0, (s.cpColorA or 32) / 100 end,
                set = function(_, r, g, b, a) local s = Store(); if s then s.cpColorR, s.cpColorG, s.cpColorB, s.cpColorA = r, g, b, math.floor(a * 100 + 0.5) end; Re() end },
            separate = tog("Separate Panel Sizes", "cpSeparate", 2),
            snapping = tog("Panel Snapping", "cpSnapping", 3, "On: the panel backdrops below replace Blizzard's window background. Off: Blizzard's own chat background color is used (ElvUI Chat Reskin > Window & Edit Box)."),
            backdrop = { type = "select", order = 4, name = "Panel Backdrop",
                values = { SHOWBOTH = "Show Both", LEFT = "Left Only", RIGHT = "Right Only", HIDEBOTH = "Hide Both" }, sorting = { "SHOWBOTH", "LEFT", "RIGHT", "HIDEBOTH" },
                get = function() return S().cpBackdrop or "SHOWBOTH" end,
                set = function(_, v) local s = Store(); if s then s.cpBackdrop = v end; Re() end },
            sizesOn = tog("Apply panel sizes to the chat windows", "cpSizesOn", 5, "Off: the sizes below do nothing and you can resize the windows by hand."),
            lh = rng("Left Panel Height", "cpHeight", 6, 60, 1000),
            lw = rng("Left Panel Width", "cpWidth", 7, 50, 2000),
            rh = rng("Right Panel Height", "cpHeightR", 8, 60, 1000, function() return not S().cpSeparate end),
            rw = rng("Right Panel Width", "cpWidthR", 9, 50, 2000, function() return not S().cpSeparate end),
            rightWin = { type = "select", order = 10, name = "Right chat window (this addon's addition)", values = windowValues, sorting = windowOrder,
                desc = "Which Blizzard chat window acts as the right panel. None = no right panel.",
                get = function() return S().cpRightWindow or "NONE" end,
                set = function(_, v) local s = Store(); if s then s.cpRightWindow = v; s.cpRightCollapsed = false end; Re() end },
            texNote = { type = "description", order = 20, width = "full",
                name = "Panel texture: a .tga file inside the World of Warcraft folder (for example Interface\\AddOns\\XayaUI\\Media\\MyPanel). Recommended size 256x128. A full game restart is needed after adding a new file. It is drawn faintly over the backdrop (Panel Snapping on)." },
            texL = { type = "input", order = 21, width = "full", name = "Panel Texture (Left)",
                get = function() return S().cpTexL or "" end,
                set = function(_, v) local s = Store(); if s then s.cpTexL = tostring(v or "") end; Re() end },
            texR = { type = "input", order = 22, width = "full", name = "Panel Texture (Right)", disabled = noRight,
                get = function() return S().cpTexR or "" end,
                set = function(_, v) local s = Store(); if s then s.cpTexR = tostring(v or "") end; Re() end },
        } },
    } }
end
