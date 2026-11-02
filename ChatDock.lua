-- ChatDock.lua - a mover for the main chat window and an ElvUI-style collapse button (Xaya, 2026-11-01).
-- Independent of the "ElvUI Chat Reskin" master switch: it only touches where the chat sits and whether it is shown.
-- Collapse = every chat window, its tab and the dock are re-parented to a hidden frame (what ElvUI does), then put back.
local ADDON, ns = ...

ns.CHAT_DEFAULTS.dockButton = true      -- show the collapse button
ns.CHAT_DEFAULTS.dockCollapsed = false  -- remembered between sessions
ns.CHAT_DEFAULTS.dockBtnSide = "RIGHT"  -- which outer corner of the chat the button sits on
-- ns.chatDB.dockPos = { x = , y = }  (BOTTOMLEFT of ChatFrame1 relative to UIParent; nil = Blizzard's own place)

local function Store() return ns.chatDB end

local hidden = CreateFrame("Frame"); hidden:Hide()
local origParent = setmetatable({}, { __mode = "k" })
local collapsed = false
local btn, mover
local moveUnlocked = false

local function Targets()
    local t = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f, tab = _G["ChatFrame" .. i], _G["ChatFrame" .. i .. "Tab"]
        if f then t[#t + 1] = f end
        if tab then t[#t + 1] = tab end
    end
    if GeneralDockManager then t[#t + 1] = GeneralDockManager end
    return t
end

local function PlaceButton()
    if not btn then return end
    local s = Store() or {}
    btn:SetShown(s.dockButton ~= false)
    btn:ClearAllPoints()
    local cf = ChatFrame1
    local right = (s.dockBtnSide or "RIGHT") == "RIGHT"
    if collapsed then
        -- the chat is hidden, so anchor to where it was (remembered when it collapsed)
        local p = s.dockLast
        if p then btn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
        else btn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 10, 150) end
    elseif cf then
        if right then btn:SetPoint("BOTTOMLEFT", cf, "BOTTOMRIGHT", 4, 0)
        else btn:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", -4, 0) end
    end
    if btn.arrow then
        -- arrow points at the side the chat will come back from / go away to
        local pointRight = (not collapsed) == (not right)
        btn.arrow:SetText(collapsed and (right and ">" or "<") or (right and "<" or ">"))
    end
end

local function Apply()
    local s = Store()
    if not s then return end
    if s.dockCollapsed and not collapsed then
        local cf = ChatFrame1
        if cf and cf:GetLeft() then
            local sc = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
            s.dockLast = { x = cf:GetRight() * sc + 4, y = cf:GetBottom() * sc }
        end
        for _, f in ipairs(Targets()) do
            if f:GetParent() ~= hidden then origParent[f] = f:GetParent(); f:SetParent(hidden) end
        end
        collapsed = true
    elseif (not s.dockCollapsed) and collapsed then
        for _, f in ipairs(Targets()) do
            local p = origParent[f]
            if p and f:GetParent() == hidden then f:SetParent(p) end
        end
        wipe(origParent)
        collapsed = false
    elseif collapsed then
        -- new windows (whispers, pop-outs) opened while collapsed go away too
        for _, f in ipairs(Targets()) do
            if f:GetParent() ~= hidden then origParent[f] = f:GetParent(); f:SetParent(hidden) end
        end
    end
    PlaceButton()
end

function ns.ChatDock_SetCollapsed(v)
    local s = Store(); if not s then return end
    s.dockCollapsed = v and true or false
    Apply()
end

-- position -----------------------------------------------------------------------------------------------------------------
local function ApplyPosition()
    local s = Store()
    local p = s and s.dockPos
    local cf = ChatFrame1
    if not (p and cf) or InCombatLockdown() and cf:IsProtected() then return end
    cf:SetMovable(true)
    cf:ClearAllPoints()
    cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
    cf:SetUserPlaced(true)
    if FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, cf) end
end

local function SavePosition()
    local s, cf = Store(), ChatFrame1
    if not (s and cf and cf:GetLeft()) then return end
    local sc = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
    s.dockPos = { x = math.floor(cf:GetLeft() * sc + 0.5), y = math.floor(cf:GetBottom() * sc + 0.5) }
    if FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, cf) end
end

local function UpdateMover()
    if not mover then return end
    local on = (moveUnlocked or ns.unlocked) and not collapsed and ChatFrame1 and true or false
    mover:SetShown(on)
end

function ns.ChatDock_SetMoveUnlocked(v) moveUnlocked = v and true or false; UpdateMover() end
function ns.ChatDock_IsMoveUnlocked() return moveUnlocked end
function ns.ChatDock_ResetPosition()
    local s = Store(); if not s then return end
    s.dockPos = nil
    if FCF_RestorePositionAndDimensions and ChatFrame1 then
        -- Blizzard's saved layout wins again after /reload; put it back to the default corner right now
        ChatFrame1:ClearAllPoints()
        ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 95)
        if FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, ChatFrame1) end
    end
    PlaceButton()
end

local function Build()
    if btn or not ChatFrame1 then return end
    btn = CreateFrame("Button", "XayaUIChatCollapse", UIParent, "BackdropTemplate")
    btn:SetSize(16, 24)
    btn:SetFrameStrata("MEDIUM"); btn:SetFrameLevel(50)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btn:SetBackdropColor(0, 0, 0, 0.45); btn:SetBackdropBorderColor(0, 0, 0, 0.8)
    btn.arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    btn.arrow:SetPoint("CENTER", 0, 1)
    btn:SetAlpha(0.5)
    btn:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(collapsed and "Show chat" or "Hide chat")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self) self:SetAlpha(0.5); GameTooltip:Hide() end)
    btn:SetScript("OnClick", function() ns.ChatDock_SetCollapsed(not collapsed) end)

    mover = CreateFrame("Frame", "XayaUIChatMover", UIParent, "BackdropTemplate")
    mover:SetFrameStrata("DIALOG")
    mover:SetPoint("TOPLEFT", ChatFrame1, "TOPLEFT", -4, 30)   -- includes the tab row
    mover:SetPoint("BOTTOMRIGHT", ChatFrame1, "BOTTOMRIGHT", 4, -4)
    mover:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    mover:SetBackdropColor(0.1, 0.5, 1, 0.25); mover:SetBackdropBorderColor(0.2, 0.7, 1, 1)
    local t = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("CENTER"); t:SetText("Chat - drag to move")
    mover:EnableMouse(true); mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function() ChatFrame1:SetMovable(true); ChatFrame1:StartMoving() end)
    mover:SetScript("OnDragStop", function() ChatFrame1:StopMovingOrSizing(); SavePosition() end)
    mover:Hide()
    if ChatFrame1.HookScript then
        ChatFrame1:HookScript("OnSizeChanged", function() if not collapsed then PlaceButton() end end)
    end
    if hooksecurefunc and FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function() if collapsed then C_Timer.After(0, Apply) end end)
    end
end

function ns.ChatDock_Refresh()
    Build(); ApplyPosition(); Apply(); UpdateMover()
end

local drv = CreateFrame("Frame")
drv:RegisterEvent("PLAYER_ENTERING_WORLD")
drv:RegisterEvent("UPDATE_CHAT_WINDOWS")
drv:SetScript("OnEvent", function(_, ev)
    -- Blizzard re-applies its own saved layout around login, so apply ours a little later as well
    C_Timer.After(0.2, ns.ChatDock_Refresh)
    if ev == "PLAYER_ENTERING_WORLD" then C_Timer.After(2, ns.ChatDock_Refresh) end
end)
-- the addon-wide Unlock button also unlocks this mover
if ns.ToggleUnlock then hooksecurefunc(ns, "ToggleUnlock", function() UpdateMover() end) end

-- options (added to the chat page by ChatReskin.BuildChatTab) -----------------------------------------------------------
function ns.ChatDock_Options(Notify)
    local function note(text, order) return { type = "description", order = order, width = "full", fontSize = "medium", name = text } end
    return { type = "group", name = "Move & Collapse", order = 8, args = {
        n = note("Works with or without the ElvUI Chat Reskin switch. Collapse hides every chat window, its tabs and the dock; the small arrow button brings them back.", 0),
        btn = { type = "toggle", order = 1, width = "full", name = "Show the collapse button",
            get = function() return (Store() or {}).dockButton ~= false end,
            set = function(_, v) local s = Store(); if s then s.dockButton = v and true or false end; PlaceButton(); Notify() end },
        side = { type = "select", order = 2, name = "Button side", values = { RIGHT = "Right of the chat", LEFT = "Left of the chat" },
            get = function() return (Store() or {}).dockBtnSide or "RIGHT" end,
            set = function(_, v) local s = Store(); if s then s.dockBtnSide = v end; PlaceButton(); Notify() end },
        col = { type = "toggle", order = 3, width = "full", name = "Chat collapsed",
            get = function() return (Store() or {}).dockCollapsed and true or false end,
            set = function(_, v) ns.ChatDock_SetCollapsed(v); Notify() end },
        mvHdr = { type = "header", order = 10, name = "Mover" },
        mv = { type = "toggle", order = 11, width = "full", name = "Unlock the chat mover (drag the blue box)",
            desc = "The addon's main Unlock button also shows it.",
            get = function() return ns.ChatDock_IsMoveUnlocked() end,
            set = function(_, v) ns.ChatDock_SetMoveUnlocked(v); Notify() end },
        reset = { type = "execute", order = 12, name = "Reset chat position",
            func = function() ns.ChatDock_ResetPosition(); Notify() end },
    } }
end
