-- ChatDock.lua - a mover for the main chat window, a collapse button, a precise-position window, the chat's side strip
-- option, and the free-move fix (Xaya, 2026-11-01; reworked 2026-11-02).
-- Independent of the "ElvUI Chat Reskin" master switch: it only touches where the chat sits and whether it is shown.
-- Collapse = every chat window, its tab and the dock are re-parented to a hidden frame, then put back.
local ADDON, ns = ...

ns.CHAT_DEFAULTS.dockButton = true      -- show the collapse button
ns.CHAT_DEFAULTS.dockCollapsed = false  -- remembered between sessions
ns.CHAT_DEFAULTS.dockBtnSide = "RIGHT"  -- which outer corner of the chat the button sits on
ns.CHAT_DEFAULTS.dockBtnX, ns.CHAT_DEFAULTS.dockBtnY = 0, 0   -- fine-tune offsets of the collapse button
ns.CHAT_DEFAULTS.chatFreeMove = true    -- remove Blizzard's keep-away-from-the-screen-edge margin on the main chat window
ns.CHAT_DEFAULTS.sideStrip = "SHOW"     -- Blizzard's button strip / scroll bar beside the chat: SHOW | MOUSEOVER | HIDE
ns.CHAT_DEFAULTS.nudgeStep = 1          -- pixels per arrow click in the position window (Shift = x10)
-- ns.chatDB.dockPos = { x = , y = }  (BOTTOMLEFT of ChatFrame1 relative to UIParent; nil = Blizzard's own place)

local function Store() return ns.chatDB end

-- The holding frame is a child of UIParent so it has the same scale. Parented to nothing it would be scale 1, and with a UI scale below 1
-- everything anchored to a chat window (the bar under it, the privacy cover, the buttons) would grow by 1 / UI scale while the chat is collapsed.
local hidden = CreateFrame("Frame", nil, UIParent); hidden:Hide()
local origParent = setmetatable({}, { __mode = "k" })
local collapsed = false
local btn, mover, nudge
local moveUnlocked = false
local dragged = false

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

function ns.ChatDock_IsCollapsed() return collapsed end

-- side strip -------------------------------------------------------------------------------------------------------------
-- "Side strip" = what hangs beside each chat window: the button frame, the scroll bar and the scroll-to-bottom button.
-- Names are Blizzard's; any that do not exist on this client are skipped (/xui chat lists what was found).
local stripMouse = setmetatable({}, { __mode = "k" })   -- frame -> true when we turned its mouse off
local stripFound = {}
local stripDriver

local function StripTargets(i)
    local cf = _G["ChatFrame" .. i]
    local t = {}
    if not cf then return t end
    local bf = _G["ChatFrame" .. i .. "ButtonFrame"] or cf.buttonFrame
    if bf then t[#t + 1] = bf end
    if cf.ScrollBar then t[#t + 1] = cf.ScrollBar end
    if cf.ScrollToBottomButton then t[#t + 1] = cf.ScrollToBottomButton end
    return t
end

local function Over(f)
    if not f then return false end
    if f.IsMouseOver then local ok, v = pcall(f.IsMouseOver, f); if ok then return v and true or false end end
    return MouseIsOver and MouseIsOver(f) and true or false
end

local function SetMouse(f, on)
    if on then
        if stripMouse[f] then f:EnableMouse(true); stripMouse[f] = nil end
    else
        if f:IsMouseEnabled() then stripMouse[f] = true; f:EnableMouse(false) end
    end
end

local function ApplyStrip()
    local s = Store()
    if not s then return end
    local mode = s.sideStrip or "SHOW"
    wipe(stripFound)
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        for _, f in ipairs(StripTargets(i)) do
            stripFound[#stripFound + 1] = (f:GetName() or ("ChatFrame" .. i .. ".child")) .. (f:IsShown() and "" or " (hidden)")
            local show
            if mode == "HIDE" then show = false
            elseif mode == "MOUSEOVER" then show = Over(cf) or Over(f) or (cf.editBox and cf.editBox:HasFocus())
            else show = true end
            pcall(function()
                f:SetAlpha(show and 1 or 0)
                SetMouse(f, show)
                if f.GetChildren then for _, c in ipairs({ f:GetChildren() }) do SetMouse(c, show) end end
            end)
        end
    end
    -- hidden / mouse-over modes re-check a few times a second (Blizzard fades and re-shows these pieces itself)
    stripDriver = stripDriver or CreateFrame("Frame")
    if mode == "SHOW" then
        if stripDriver.on then stripDriver:SetScript("OnUpdate", nil); stripDriver.on = false end
    elseif not stripDriver.on then
        stripDriver.on = true
        local acc = 0
        stripDriver:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc < 0.15 then return end
            acc = 0
            ApplyStrip()
        end)
    end
end
ns.ChatDock_ApplyStrip = ApplyStrip

-- How far (in the chat's own units) anything visible sticks out past the chat frame's right edge.
local function SideExtra(cf)
    local cr = cf and cf:GetRight()
    if not cr then return 0 end
    local mx = cr
    local function see(f)
        if f and f.IsShown and f:IsShown() and f.GetRight and (not f.GetAlpha or f:GetAlpha() > 0) then
            local r = f:GetRight()
            if r and r > mx then mx = r end
        end
    end
    local n = (cf.GetName and cf:GetName()) or "ChatFrame1"
    see(_G[n .. "ButtonFrame"]); see(cf.ScrollBar); see(cf.ScrollToBottomButton); see(_G[n .. "Background"])
    if cf.GetRegions then
        for _, r in ipairs({ cf:GetRegions() }) do
            if r.IsObjectType and r:IsObjectType("Texture") then see(r) end
        end
    end
    return math.min(math.max(mx - cr, 0), 80)
end

ns.ChatDock_SideExtra = SideExtra

-- collapse button --------------------------------------------------------------------------------------------------------
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
        -- sit outside everything Blizzard hangs beside the window (button strip, scroll bar, scroll-to-bottom arrows, background art)
        local dx, dy = tonumber(s.dockBtnX) or 0, tonumber(s.dockBtnY) or 0
        if right then btn:SetPoint("BOTTOMLEFT", cf, "BOTTOMRIGHT", SideExtra(cf) + 4 + dx, dy)
        else btn:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", -4 + dx, dy) end
    end
    if btn.chevron then
        -- the arrow points the way the chat will go (hide) or come back from (show)
        btn.chevron:SetDir(collapsed and (right and "RIGHT" or "LEFT") or (right and "LEFT" or "RIGHT"))
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
    if ns.ChatPanel_Refresh then ns.ChatPanel_Refresh() end
end

function ns.ChatDock_SetCollapsed(v)
    local s = Store(); if not s then return end
    s.dockCollapsed = v and true or false
    Apply()
end

-- position -----------------------------------------------------------------------------------------------------------------
-- Blizzard keeps the main chat window about 50 px above the bottom and 35 px in from the sides (a clamp margin sized for the edit box
-- and the button strip), so it cannot be dragged to the screen edge. chatFreeMove sets that margin to zero.
local function FreeMove()
    local s, cf = Store(), ChatFrame1
    if not (s and cf) or s.chatFreeMove == false then return end
    pcall(function()
        if cf.SetClampRectInsets then cf:SetClampRectInsets(0, 0, 0, 0) end
        if cf.SetClampedToScreen then cf:SetClampedToScreen(true) end   -- still never lost off-screen
    end)
end

local function ApplyPosition()
    local s = Store()
    local p = s and s.dockPos
    local cf = ChatFrame1
    if not (p and cf) or InCombatLockdown() and cf:IsProtected() then return end
    local sc = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if sc <= 0 then sc = 1 end
    FreeMove()
    cf:SetMovable(true)
    cf:ClearAllPoints()
    cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.x / sc, p.y / sc)
    cf:SetUserPlaced(true)
    if FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, cf) end
end

local function CurrentXY()
    local s, cf = Store() or {}, ChatFrame1
    if cf and cf:GetLeft() then
        local sc = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return math.floor(cf:GetLeft() * sc + 0.5), math.floor(cf:GetBottom() * sc + 0.5)
    end
    if s.dockPos then return s.dockPos.x, s.dockPos.y end
    return 0, 0
end

local function SavePosition()
    local s, cf = Store(), ChatFrame1
    if not (s and cf and cf:GetLeft()) then return end
    local x, y = CurrentXY()
    s.dockPos = { x = x, y = y }
    if FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, cf) end
    if nudge and nudge:IsShown() then nudge:RefreshAll() end
    if ns.ChatDock_EnsureRoom then pcall(ns.ChatDock_EnsureRoom) end
end

-- Exact placement: x, y = where the chat's bottom-left corner goes, in pixels from the screen's bottom-left.
-- Kept so that at least 40 px of the chat stays on screen (the Reset button and /xui unlock can always bring it back).
function ns.ChatDock_SetPosition(x, y)
    local s, cf = Store(), ChatFrame1
    if not (s and cf) then return end
    x, y = tonumber(x), tonumber(y)
    if not (x and y) then return end
    local sc = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local w, h = (cf:GetWidth() or 0) * sc, (cf:GetHeight() or 0) * sc
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    x = math.min(math.max(x, -(w - 40)), sw - 40)
    y = math.min(math.max(y, -(h - 40)), sh - 40)
    s.dockPos = { x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
    ApplyPosition()
    PlaceButton()
    if nudge then nudge:RefreshAll() end
end

-- A bar under the main chat (ChatPanel.lua) needs room below the chat for itself and the edit box: lift the chat if it sits lower.
function ns.ChatDock_EnsureRoom()
    local s, cf = Store(), ChatFrame1
    if not (s and cf and cf:GetLeft()) then return end
    local need = ns.ChatPanel_BottomReserve and ns.ChatPanel_BottomReserve() or 0
    if need <= 0 then return end
    local x, y = CurrentXY()
    if y < need then ns.ChatDock_SetPosition(x, need) end
end

local function UpdateMover()
    if not mover then return end
    local on = (moveUnlocked or ns.unlocked) and not collapsed and ChatFrame1 and true or false
    mover:SetShown(on)
    if not on and nudge then nudge:Hide() end
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
    if nudge then nudge:RefreshAll() end
end

-- position window (click the blue mover box) -----------------------------------------------------------------------------
local function BuildNudge()
    if nudge then return nudge end
    local CW = ns.CW
    if not CW then return end
    local f = CW.Window("XayaUIChatNudge", "Chat position", 228, 292)
    local function step()
        local s = Store() or {}
        local v = tonumber(s.nudgeStep) or 1
        return (IsShiftKeyDown() and v * 10 or v)
    end
    local function move(dx, dy)
        local x, y = CurrentXY()
        ns.ChatDock_SetPosition(x + dx * step(), y + dy * step())
    end

    f:Add(CW.Note("The chat's bottom-left corner, in pixels from the bottom-left of the screen. Type a value and press Enter, or use the arrows (hold Shift for 10 times the step).", 0.7, 0.7, 0.7), 44)
    f:Add(CW.Number("X (from left)", function() local x = CurrentXY(); return x end,
        function(v) local _, y = CurrentXY(); ns.ChatDock_SetPosition(v, y) end, -5000, 10000, 1), 20)
    f:Add(CW.Number("Y (from bottom)", function() local _, y = CurrentXY(); return y end,
        function(v) local x = CurrentXY(); ns.ChatDock_SetPosition(x, v) end, -5000, 10000, 1), 20)
    f:Add(CW.Number("Arrow step (pixels)", function() return (Store() or {}).nudgeStep or 1 end,
        function(v) local s = Store(); if s then s.nudgeStep = math.max(1, math.floor(v)) end end, 1, 200, 1), 20, 8)

    -- cardinal arrows
    local pad = CreateFrame("Frame")
    local S = 30
    local up = CW.ArrowButton(pad, S, "UP", function() move(0, 1) end);    up:SetPoint("TOP", pad, "TOP", 0, 0)
    local dn = CW.ArrowButton(pad, S, "DOWN", function() move(0, -1) end); dn:SetPoint("BOTTOM", pad, "BOTTOM", 0, 0)
    local lt = CW.ArrowButton(pad, S, "LEFT", function() move(-1, 0) end); lt:SetPoint("RIGHT", pad, "CENTER", -S / 2 - 2, 0)
    local rt = CW.ArrowButton(pad, S, "RIGHT", function() move(1, 0) end); rt:SetPoint("LEFT", pad, "CENTER", S / 2 + 2, 0)
    f:Add(pad, 3 * S + 4, 8)

    local row = CreateFrame("Frame")
    local b1 = CW.Button(row, 66, 20, "Bottom edge", function() local x = CurrentXY(); ns.ChatDock_SetPosition(x, 0) end)
    b1:SetPoint("LEFT", 0, 0)
    local b2 = CW.Button(row, 66, 20, "Left edge", function() local _, y = CurrentXY(); ns.ChatDock_SetPosition(0, y) end)
    b2:SetPoint("LEFT", b1, "RIGHT", 4, 0)
    local b3 = CW.Button(row, 66, 20, "Reset", function() ns.ChatDock_ResetPosition() end)
    b3:SetPoint("LEFT", b2, "RIGHT", 4, 0)
    f:Add(row, 22)
    f.OnMoved = function() local s = Store(); if s then local p, _, _, x, y = f:GetPoint(); s.nudgePos = { p = p, x = x, y = y } end end
    nudge = f
    return f
end

function ns.ChatDock_ShowNudge()
    local f = BuildNudge()
    if not f then return end
    f:ClearAllPoints()
    local s = Store() or {}
    local np = s.nudgePos
    if np and np.p then
        f:SetPoint(np.p, UIParent, np.p, np.x or 0, np.y or 0)
    elseif mover and mover:IsShown() and mover:GetTop() and mover:GetTop() + f:GetHeight() + 10 < UIParent:GetHeight() then
        f:SetPoint("BOTTOMLEFT", mover, "TOPLEFT", 0, 8)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    f:Show()
end

-- build --------------------------------------------------------------------------------------------------------------------
local function Build()
    if btn or not ChatFrame1 then return end
    btn = CreateFrame("Button", "XayaUIChatCollapse", UIParent, "BackdropTemplate")
    btn:SetSize(18, 28)
    btn:SetFrameStrata("MEDIUM"); btn:SetFrameLevel(50)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btn:SetBackdropColor(0, 0, 0, 0.45); btn:SetBackdropBorderColor(0, 0, 0, 0.8)
    -- drawn with lines, not a font character: a glyph here was being cut off by the box
    btn.chevron = ns.CW and ns.CW.Chevron(btn, 16, "LEFT", 1, 0.82, 0)
    if btn.chevron then btn.chevron.holder:SetPoint("CENTER", 0, 0) end
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
    t:SetPoint("CENTER"); t:SetText("Chat - drag to move, click for exact position")
    mover:EnableMouse(true); mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function() dragged = true; FreeMove(); ChatFrame1:SetMovable(true); ChatFrame1:StartMoving() end)
    mover:SetScript("OnDragStop", function() ChatFrame1:StopMovingOrSizing(); SavePosition(); PlaceButton() end)
    mover:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and not dragged then ns.ChatDock_ShowNudge() end
        dragged = false
    end)
    mover:Hide()
    if ChatFrame1.HookScript then
        ChatFrame1:HookScript("OnSizeChanged", function() if not collapsed then PlaceButton() end end)
    end
    if hooksecurefunc and FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function() if collapsed then C_Timer.After(0, Apply) end end)
    end
    -- Blizzard re-applies its own clamp margin whenever it restores a window's saved place
    if hooksecurefunc and FCF_RestorePositionAndDimensions then
        hooksecurefunc("FCF_RestorePositionAndDimensions", function() C_Timer.After(0, FreeMove) end)
    end
end

function ns.ChatDock_Refresh()
    Build(); FreeMove(); ApplyPosition(); Apply(); UpdateMover(); ApplyStrip()
    C_Timer.After(0.6, PlaceButton)
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

function ns.ChatDock_Debug(say)
    local cf = ChatFrame1
    local x, y = CurrentXY()
    say("dock: collapsed=" .. tostring(collapsed) .. " pos=" .. x .. "," .. y .. " saved=" .. tostring(Store() and Store().dockPos ~= nil))
    if cf and cf.GetClampRectInsets then
        local l, r, t, b = cf:GetClampRectInsets()
        say("dock: ChatFrame1 clamp insets L/R/T/B = " .. tostring(l) .. "/" .. tostring(r) .. "/" .. tostring(t) .. "/" .. tostring(b)
            .. "  freeMove=" .. tostring((Store() or {}).chatFreeMove ~= false))
    end
    say(("dock: effective scale ChatFrame1=%.3f  UIParent=%.3f  parent of ChatFrame1=%s  (the two scales must match, collapsed or not)"):format(
        cf and cf:GetEffectiveScale() or 0, UIParent:GetEffectiveScale(), tostring(cf and cf:GetParent() and (cf:GetParent():GetName() or (cf:GetParent() == hidden and "hidden holder" or "unnamed")))))
    say("dock: pieces sticking out past the chat's right edge = " .. string.format("%.1f", SideExtra(cf)) .. " px (collapse button sits beyond this)")
    say("dock: side strip mode=" .. tostring((Store() or {}).sideStrip) .. "  found: " .. (#stripFound > 0 and table.concat(stripFound, ", ") or "(none yet)"))
    local bf = _G.ChatFrame1ButtonFrame
    if bf and bf:GetWidth() then
        say(("dock: ChatFrame1ButtonFrame width=%.0f shown=%s  scrollbar=%s  scrollToBottom=%s"):format(bf:GetWidth(), tostring(bf:IsShown()),
            tostring(cf and cf.ScrollBar ~= nil), tostring(cf and cf.ScrollToBottomButton ~= nil)))
    end
end

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
        bx = { type = "range", order = 4, name = "Collapse button: move right (pixels)", min = -100, max = 100, step = 1,
            get = function() return (Store() or {}).dockBtnX or 0 end,
            set = function(_, v) local s = Store(); if s then s.dockBtnX = v end; PlaceButton(); Notify() end },
        by = { type = "range", order = 5, name = "Collapse button: move up (pixels)", min = -100, max = 400, step = 1,
            get = function() return (Store() or {}).dockBtnY or 0 end,
            set = function(_, v) local s = Store(); if s then s.dockBtnY = v end; PlaceButton(); Notify() end },
        mvHdr = { type = "header", order = 10, name = "Mover" },
        mv = { type = "toggle", order = 11, width = "full", name = "Unlock the chat mover (drag the blue box; click it for exact X / Y and arrows)",
            desc = "The addon's main Unlock button also shows it.",
            get = function() return ns.ChatDock_IsMoveUnlocked() end,
            set = function(_, v) ns.ChatDock_SetMoveUnlocked(v); Notify() end },
        pos = { type = "execute", order = 12, name = "Open the exact-position window",
            func = function() ns.ChatDock_ShowNudge() end },
        free = { type = "toggle", order = 13, width = "full", name = "Let the chat reach the screen edge",
            desc = "Blizzard keeps the main chat window about 50 pixels above the bottom of the screen. This removes that margin.",
            get = function() return (Store() or {}).chatFreeMove ~= false end,
            set = function(_, v) local s = Store(); if s then s.chatFreeMove = v and true or false end; ns.ChatDock_Refresh(); Notify() end },
        reset = { type = "execute", order = 14, name = "Reset chat position",
            func = function() ns.ChatDock_ResetPosition(); Notify() end },
        stripHdr = { type = "header", order = 20, name = "Side strip" },
        stripNote = note("The strip beside the chat window: Blizzard's button column, the scroll bar and the scroll-to-bottom arrows. Mouse-wheel scrolling keeps working when it is hidden.", 21),
        strip = { type = "select", order = 22, name = "Side strip",
            values = { SHOW = "Always show (Blizzard's default)", MOUSEOVER = "Show only while the mouse is over the chat", HIDE = "Hide" },
            sorting = { "SHOW", "MOUSEOVER", "HIDE" },
            get = function() return (Store() or {}).sideStrip or "SHOW" end,
            set = function(_, v) local s = Store(); if s then s.sideStrip = v end; ApplyStrip(); PlaceButton(); Notify() end },
    } }
end
