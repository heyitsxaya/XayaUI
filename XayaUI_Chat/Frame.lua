-------------------------------------------------------------------------------
-- Chat/Frame.lua : the Chat Panel container. ONE frame owns the chat's place and size. Inside it (top to bottom): the tab row, the
-- text, the input line (the edit box lives INSIDE the pane). The Chat Bar is an edge of the same container, above or below the pane.
-- Blizzard's windows are anchored to the container's regions and are never re-parented. Collapse and fade work through the alpha of
-- the Blizzard frames (a hook keeps the game's own SetAlpha calls from undoing it), so nothing is ever moved off screen.
-- Own code, written from the documented game API only. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local C = ns.Chat
local issecret = C.IsSecret

local container, pane, tabsA, textA, inputA, bar, arrow, mover, hint
C.master, C.fade = 1, 1
C.unlocked = false

local MIN_W, MIN_H, MAX_W, MAX_H = 220, 90, 1200, 1000
local ARROW_W = 20

local function Clamp(v, lo, hi, def)
    v = tonumber(v)
    if not v or issecret(v) then return def end
    return math.max(lo, math.min(hi, v))
end
local function S() return ns.chat2 end

function C.Container() return container end
function C.Pane() return pane end
function C.TextArea() return textA end
function C.TabsArea() return tabsA end
function C.InputArea() return inputA end
function C.Bar() return bar end
function C.IsCollapsed() local s = S(); return s and s.collapsed and true or false end
function C.ArrowLead() local s = S(); return (s and s.barOn) and ARROW_W or 0 end

-------------------------------------------------------------------------------
-- Building the frames
-------------------------------------------------------------------------------
local function Build()
    if container then return end
    container = CreateFrame("Frame", "XayaUIChat", UIParent)
    container:SetFrameStrata("LOW")
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    pane = CreateFrame("Frame", "XayaUIChatPane", container)
    pane:SetFrameStrata("BACKGROUND")
    tabsA = CreateFrame("Frame", nil, pane)
    textA = CreateFrame("Frame", nil, pane)
    textA:SetScript("OnSizeChanged", function() if C.On() and C.Rewrap then C.Rewrap() end end)   -- the text area was resized: wrap at the new width
    inputA = CreateFrame("Button", "XayaUIChatInput", pane)     -- the input line's strip; clicking it opens the edit box
    inputA:SetFrameStrata("LOW")
    inputA:RegisterForClicks("LeftButtonUp")
    inputA:SetScript("OnClick", function()
        if C.IsCollapsed() then return end
        local open = ns.Compat.Chat("OpenChat")
        if open then pcall(open, "", _G.ChatFrame1) end
    end)
    hint = inputA:CreateFontString(nil, "OVERLAY")
    hint:SetPoint("LEFT", inputA, "LEFT", 8, 0)
    hint:SetTextColor(1, 1, 1, 0.35)
    bar = CreateFrame("Frame", "XayaUIChatBar", container)
    bar:SetFrameStrata("LOW")
    C.hint = hint
end

-- the collapse arrow: a chevron drawn with two lines. Lives at the start of the bar; with the bar off it sits under the pane's corner.
local function BuildArrow()
    if arrow then return end
    arrow = CreateFrame("Button", "XayaUIChatArrow", container)
    arrow:SetSize(ARROW_W, ARROW_W)
    arrow:SetFrameStrata("MEDIUM")
    arrow.l1 = arrow:CreateLine(nil, "OVERLAY"); arrow.l2 = arrow:CreateLine(nil, "OVERLAY")
    arrow:SetScript("OnClick", function() C.SetCollapsed(not C.IsCollapsed()) end)
    arrow:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(C.IsCollapsed() and "Show the chat" or "Hide the chat")
        GameTooltip:Show()
    end)
    arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function DrawArrow(up)
    local k = 4
    local function seg(l, x1, y1, x2, y2)
        l:SetThickness(2); l:SetColorTexture(1, 1, 1, 0.9)
        l:SetStartPoint("CENTER", arrow, x1, y1); l:SetEndPoint("CENTER", arrow, x2, y2)
    end
    if up then seg(arrow.l1, -k, -k / 2, 0, k / 2); seg(arrow.l2, 0, k / 2, k, -k / 2)
    else seg(arrow.l1, -k, k / 2, 0, -k / 2); seg(arrow.l2, 0, -k / 2, k, k / 2) end
end

-------------------------------------------------------------------------------
-- Layout: size, position, regions
-------------------------------------------------------------------------------
local function TabH(s) return s.tabsShow and Clamp(s.tabHeight, 16, 40, 24) or 0 end

function C.Layout()
    local s = S()
    if not (s and container) then return end
    local W, H = Clamp(s.width, MIN_W, MAX_W, 440), Clamp(s.height, MIN_H, MAX_H, 230)
    local barOn = s.barOn and true or false
    local bh = barOn and Clamp(s.barH, 14, 60, 22) or 0
    local gap = barOn and Clamp(s.barGap, 0, 20, 2) or 0
    local below = (s.barSide ~= "TOP")
    container:ClearAllPoints()
    container:SetPoint(s.point or "BOTTOMLEFT", UIParent, s.point or "BOTTOMLEFT", tonumber(s.x) or 24, tonumber(s.y) or 90)
    container:SetSize(W, H + bh + gap)

    pane:ClearAllPoints(); bar:ClearAllPoints()
    if below then
        pane:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); pane:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0); bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    else
        pane:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0); pane:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); bar:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    end
    pane:SetHeight(H)
    bar:SetHeight(math.max(1, bh))
    bar:SetShown(barOn)

    local th = TabH(s)
    tabsA:ClearAllPoints()
    tabsA:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0); tabsA:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 0)
    tabsA:SetHeight(math.max(1, th))
    local ih = Clamp(s.inputH, 18, 60, 26)
    inputA:ClearAllPoints()
    inputA:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 2, 2); inputA:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -2, 2)
    inputA:SetHeight(ih)
    local inset = Clamp(s.textInset, 0, 30, 6)
    local own = s.scrollOwn and true or false      -- the Chat Panel's scroll bar (Scroll.lua) sits in the space right of the text
    local right = inset + ((own and (Clamp(s.scrollW, 6, 20, 10) + 2)) or ((s.scrollBar == "SHOW") and 14 or 0))
    textA:ClearAllPoints()
    textA:SetPoint("TOPLEFT", tabsA, "BOTTOMLEFT", inset, -2)
    textA:SetPoint("BOTTOMRIGHT", inputA, "TOPRIGHT", -right, 3)

    -- the arrow: first thing in the bar; with the bar off it hangs under the pane's corner (the pane is invisible while collapsed)
    BuildArrow()
    arrow:ClearAllPoints()
    if barOn then arrow:SetPoint("LEFT", bar, "LEFT", 0, 0)
    else arrow:SetPoint("TOPLEFT", container, "BOTTOMLEFT", 0, -2) end
    arrow:SetShown(true)
    local collapsed = s.collapsed and true or false
    -- the chevron points the way the chat goes when it collapses: toward the bar (a bar off counts as below the pane)
    local lower = below or not barOn
    DrawArrow((lower and collapsed) or ((not lower) and not collapsed))
    pane:SetShown(not collapsed)
    if mover then mover:ClearAllPoints(); mover:SetAllPoints(container) end
    C.Anchor()
    if C.ScrollBar_Layout then C.ScrollBar_Layout() end
    C.ApplyAlpha()
    if ns.ChatPrivacy_Refresh then ns.ChatPrivacy_Refresh() end
end

-------------------------------------------------------------------------------
-- Blizzard windows into the regions
-------------------------------------------------------------------------------
local function Docked(f) return f == _G.ChatFrame1 or (f.isDocked and true or false) end

local function PointsAt(o, rel, n)       -- true when every anchor of o is on rel (and there are n of them)
    if not (o and o.GetNumPoints) then return true end
    local ok, count = pcall(o.GetNumPoints, o)
    if not ok or count ~= n then return false end
    for i = 1, count do
        local ok2, _, r = pcall(o.GetPoint, o, i)
        if not ok2 or r ~= rel then return false end
    end
    return true
end
-- is the game's chat still glued to the container? (the game re-anchors windows when they are docked, dragged or reset)
function C.Glued()
    local cf = C.Main()
    if cf and not PointsAt(cf, textA, 2) then return false end
    local dock = _G.GeneralDockManager
    if dock and not PointsAt(dock, tabsA, 2) then return false end
    for _, f in ipairs(C.Frames()) do
        local eb = C.EditBoxOf(f)
        if eb and Docked(f) and not PointsAt(eb, inputA, 2) then return false end
    end
    return true
end

function C.Anchor()
    local s = S()
    if not (s and container and C.On()) then return end
    C.anchoring = true
    local cf = C.Main()
    C.Remember(cf); C.Remember(_G.GeneralDockManager)
    for _, f in ipairs(C.Frames()) do C.Remember(C.EditBoxOf(f)) end
    if cf then
        C.Try("anchor", function()
            cf:ClearAllPoints()
            cf:SetPoint("TOPLEFT", textA, "TOPLEFT", 0, 0)
            cf:SetPoint("BOTTOMRIGHT", textA, "BOTTOMRIGHT", 0, 0)
            if cf.SetUserPlaced then cf:SetUserPlaced(true) end
        end)
        if C_Timer and C_Timer.After then C_Timer.After(0.1, function() if C.On() then C.Rewrap(true) end end) end
        C.Try("dock", function()
            local dock = _G.GeneralDockManager
            if not dock then return end
            dock:ClearAllPoints()
            dock:SetPoint("TOPLEFT", tabsA, "TOPLEFT", 0, 0)
            dock:SetPoint("BOTTOMRIGHT", tabsA, "BOTTOMRIGHT", 0, 0)
            if s.tabsShow then C.Unsuppress(dock) else C.Suppress(dock) end
        end)
    end
    -- the input line sits inside the pane: every docked window's edit box takes the strip's rectangle
    for _, f in ipairs(C.Frames()) do
        local eb = C.EditBoxOf(f)
        if eb and Docked(f) then
            C.Try("editbox", function()
                eb:ClearAllPoints()
                eb:SetPoint("TOPLEFT", inputA, "TOPLEFT", 0, 0)
                eb:SetPoint("BOTTOMRIGHT", inputA, "BOTTOMRIGHT", 0, 0)
            end)
        end
    end
    C.Parts()
    C.anchoring = false
end

-- keep Blizzard's own pieces out of the way (or placed) as the options say
function C.Suppress(o)
    if not o then return end
    if not o._xuiSuppressed and o.IsShown then local ok, v = pcall(o.IsShown, o); o._xuiWasShown = ok and v and true or false end
    o._xuiSuppressed = true
    C.suppressed[o] = true
    if o.Hide then pcall(o.Hide, o) end
    if not o._xuiShowHook then
        o._xuiShowHook = true
        pcall(hooksecurefunc, o, "Show", function(self) if self._xuiSuppressed then self:Hide() end end)
        -- the game also shows and hides these with SetShown (FloatingChatFrame_UpdateScroll does it to the scroll bar), which the Show hook never sees
        if o.SetShown then pcall(hooksecurefunc, o, "SetShown", function(self, v) if v and self._xuiSuppressed then self:Hide() end end) end
    end
end
function C.Unsuppress(o)
    if not o or not o._xuiSuppressed then return end
    o._xuiSuppressed = false
    C.suppressed[o] = nil
    if o.Show and o._xuiWasShown ~= false then pcall(o.Show, o) end
end

local BORDER_PIECES = { "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture", "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }

function C.Parts()
    local s = S()
    local cf = C.Main()
    if not (s and cf) then return end
    local name = C.NameOf(cf)
    -- Blizzard's button strip
    local bf = C.ButtonFrameOf(cf)
    if bf then
        C.Remember(bf)
        C.Try("strip", function()
            if s.stripMode == "LEFT" or s.stripMode == "RIGHT" then
                C.Unsuppress(bf)
                bf:ClearAllPoints()
                local dx, dy = tonumber(s.stripX) or 0, tonumber(s.stripY) or 0
                if s.stripMode == "LEFT" then bf:SetPoint("TOPRIGHT", container, "TOPLEFT", -2 + dx, dy)
                else bf:SetPoint("TOPLEFT", container, "TOPRIGHT", 2 + dx, dy) end
            else
                C.Suppress(bf)
            end
        end)
    end
    -- the social / quick-join button (Blizzard anchors it to the chat's strip; with the strip hidden it would float to a screen corner)
    local sb = _G.QuickJoinToastButton
    if sb then
        C.Remember(sb)
        C.Try("social", function()
            if s.socialMode == "SHOW" then
                C.Unsuppress(sb)
                sb:ClearAllPoints()
                sb:SetPoint("BOTTOMLEFT", container, "TOPLEFT", tonumber(s.socialX) or 0, 2 + (tonumber(s.socialY) or 0))
            else
                C.Suppress(sb)
            end
        end)
    end
    -- scroll bar, resize grip, Blizzard's own background
    local sbar = cf.ScrollBar or _G[name .. "ScrollBar"]
    if sbar then C.Try("scrollbar", function() if s.scrollBar == "SHOW" and not s.scrollOwn then C.Unsuppress(sbar) else C.Suppress(sbar) end end) end
    -- the "back to the newest message" arrow: the game anchors it beside the (hidden) resize grip, outside the text; keep it inside the text area
    local tb = cf.ScrollToBottomButton
    if tb then
        C.Remember(tb)
        C.Try("tobottom", function()
            if s.toBottom == "HIDE" then C.Suppress(tb)
            else
                C.Unsuppress(tb)
                tb:ClearAllPoints()
                tb:SetPoint("BOTTOMRIGHT", textA, "BOTTOMRIGHT", 0, 2)
            end
        end)
    end
    local rz = cf.ResizeButton or _G[name .. "ResizeButton"]
    if rz then C.Try("resize", function() C.Suppress(rz) end) end
    for _, f in ipairs(C.Frames()) do
        if Docked(f) then
            local n = C.NameOf(f)
            local bg = f.Background or _G[n .. "Background"]
            if bg then C.Try("background", function() C.Suppress(bg) end) end
            -- the game's own frame border: four corners and four edges drawn around the window (FloatingBorderedFrame). Without this
            -- they stay on screen, offset from the pane, and look like a second chat under ours.
            C.Try("border", function()
                for _, suf in ipairs(BORDER_PIECES) do local t = _G[n .. suf]; if t then C.Suppress(t) end end
            end)
        end
    end
end

-------------------------------------------------------------------------------
-- Alpha: collapse and fade. The game sets alpha on its tabs / frames itself; the hook remembers its value and applies ours on top.
-------------------------------------------------------------------------------
local function HookAlpha(el)
    if el._xuiAlphaHook then return end
    el._xuiAlphaHook = true
    C.alphaEls[#C.alphaEls + 1] = el
    pcall(hooksecurefunc, el, "SetAlpha", function(self, a)
        if self._xuiSetting or type(a) ~= "number" or issecret(a) then return end
        self._xuiBase = a
        if C.master < 0.999 then self._xuiSetting = true; self:SetAlpha(a * C.master); self._xuiSetting = false end
    end)
end

function C.Elements()
    local out, seen = {}, {}
    local function add(o) if o and not seen[o] then seen[o] = true; out[#out + 1] = o end end
    for _, f in ipairs(C.Frames()) do
        if Docked(f) then
            add(f); add(C.TabOf(f)); add(C.EditBoxOf(f))
        end
    end
    add(_G.GeneralDockManager)
    local s = S()
    local bf = C.ButtonFrameOf(C.Main() or {})
    if bf and s and s.stripMode ~= "HIDE" then add(bf) end
    if s and s.socialMode == "SHOW" then add(_G.QuickJoinToastButton) end
    return out
end

function C.ApplyAlpha()
    local s = S()
    if not (s and container) then return end
    local collapsed = s.collapsed and true or false
    C.master = (collapsed and 0 or 1) * C.fade
    pane:SetAlpha(collapsed and 0 or C.fade)
    bar:SetAlpha((s.fadeBar and C.fade) or 1)
    local off = C.master < 0.02
    for _, el in ipairs(C.Elements()) do
        C.Try("alpha", function()
            HookAlpha(el)
            if el._xuiBase == nil then el._xuiBase = el:GetAlpha() end
            el._xuiSetting = true
            el:SetAlpha(el._xuiBase * C.master)
            el._xuiSetting = false
            if el.EnableMouse and el.IsMouseEnabled then
                if off then
                    if el._xuiMouse == nil then el._xuiMouse = el:IsMouseEnabled() end
                    el:EnableMouse(false)
                elseif el._xuiMouse ~= nil then
                    el:EnableMouse(el._xuiMouse); el._xuiMouse = nil
                end
            end
        end)
    end
end

function C.SetCollapsed(v)
    local s = S(); if not s then return end
    s.collapsed = v and true or false
    if s.collapsed then
        local eb, deactivate = ns.Compat.ActiveChatEditBox(), ns.Compat.Chat("DeactivateChat")
        if eb and deactivate then pcall(deactivate, eb) end
    end
    C.Layout()
end

-------------------------------------------------------------------------------
-- Mover and resize grip (shown with /xui chat move or the options button)
-------------------------------------------------------------------------------
local function BuildMover()
    if mover then return end
    mover = CreateFrame("Frame", "XayaUIChatMover", UIParent, "BackdropTemplate")
    mover:SetFrameStrata("DIALOG")
    mover:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    mover:SetBackdropColor(0.05, 0.14, 0.3, 0.94)   -- nearly solid: the chat underneath must not show through while you place it; mover:SetBackdropBorderColor(0.4, 0.75, 1, 1)
    mover:EnableMouse(true); mover:RegisterForDrag("LeftButton")
    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE"); mover.label:SetPoint("CENTER"); mover.label:SetTextColor(1, 1, 1, 1)
    mover:SetScript("OnDragStart", function() container:StartMoving() end)
    mover:SetScript("OnDragStop", function()
        container:StopMovingOrSizing()
        local s = S(); if not s then return end
        local l, b = container:GetLeft(), container:GetBottom()
        if type(l) == "number" and type(b) == "number" then s.point, s.x, s.y = "BOTTOMLEFT", math.floor(l + 0.5), math.floor(b + 0.5) end
        C.Layout()
    end)
    local grip = CreateFrame("Button", nil, mover)
    grip:SetSize(18, 18); grip:SetPoint("TOPRIGHT", mover, "TOPRIGHT", 0, 0)
    grip.t = grip:CreateTexture(nil, "OVERLAY"); grip.t:SetAllPoints(); grip.t:SetColorTexture(1, 1, 1, 0.8)
    grip:SetScript("OnMouseDown", function(self) self.sizing = true end)
    grip:SetScript("OnMouseUp", function(self) self.sizing = false end)
    grip:SetScript("OnUpdate", function(self)
        if not self.sizing then return end
        local s = S(); if not s then return end
        local cx, cy = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale()
        if not (sc and sc > 0) then return end
        cx, cy = cx / sc, cy / sc
        local l, b = container:GetLeft(), container:GetBottom()
        if type(l) ~= "number" then return end
        local extra = s.barOn and (Clamp(s.barH, 14, 60, 22) + Clamp(s.barGap, 0, 20, 2)) or 0
        s.width = math.floor(Clamp(cx - l, MIN_W, MAX_W, s.width) + 0.5)
        s.height = math.floor(Clamp(cy - b - extra, MIN_H, MAX_H, s.height) + 0.5)
        C.Layout()
    end)
    mover.grip = grip
    mover:SetScript("OnUpdate", function(self)
        local s = S(); if not s then return end
        self.label:SetText(("Chat Panel  %d x %d\nDrag to move. Drag the top-right corner to resize.\n/xui chat move to finish"):format(s.width or 0, s.height or 0))
    end)
    mover:Hide()
end

function C.ToggleMover()
    if not container then return end
    BuildMover()
    C.unlocked = not C.unlocked
    mover:SetAllPoints(container)
    mover:SetShown(C.unlocked)
    ns.Print("Chat Panel mover " .. (C.unlocked and "ON: drag the blue box, resize from its top-right corner. /xui chat move again to finish." or "OFF"))
    if C.unlocked and C.IsCollapsed() then C.SetCollapsed(false) end
end

-------------------------------------------------------------------------------
-- Refresh, hooks, upkeep
-------------------------------------------------------------------------------
local function Soft() if C.On() then C.Schedule() end end
local soonPending
function C.SoonAnchor()
    if soonPending then return end
    soonPending = true
    C_Timer.After(0, function() soonPending = false; if C.On() and not C.Glued() then C.Anchor() end end)
end

-------------------------------------------------------------------------------
-- Wrapping. The game's message frame wraps every line at the width it had when it last laid its lines out (ScrollingMessageFrame:
-- RefreshLayout sets each line's width to frame:GetWidth() once, and only again after a size change it hears about). The pane gives
-- that frame its size through two anchors, so a width it had before the pane moved it can stay in use: text then runs past the pane's
-- right edge and a long line or link breaks in the wrong place. C.WrapStatus measures it; C.Rewrap asks the frame to lay its lines
-- out again at the width it has now. The upkeep below does that on its own when a line's width differs from the frame's.
-------------------------------------------------------------------------------
local function Num(v) v = tonumber(v); if not v or C.IsSecret(v) then return nil end return v end
function C.WrapStatus()
    local cf = C.Main()
    if not (cf and textA) then return nil end
    local st = { cf = Num(cf.GetWidth and cf:GetWidth()), text = Num(textA:GetWidth()) }
    local lines = cf.visibleLines
    if type(lines) == "table" then
        st.numLines = #lines
        local first = lines[1]
        st.line = first and first.GetWidth and Num(first:GetWidth()) or nil
        -- GetStringWidth is the text's width as ONE line (0.6.4's "widest text 5567.7" was that), so it says nothing about wrapping.
        -- GetWrappedWidth is the widest line after wrapping: wider than the line's own box means text runs past the box's right edge.
        local wrapped, over, readable = 0, 0, false
        for _, fs in ipairs(lines) do
            local w = fs and fs.GetWrappedWidth and Num(fs:GetWrappedWidth()) or nil
            local box = fs and fs.GetWidth and Num(fs:GetWidth()) or nil
            if w then
                readable = true
                if w > wrapped then wrapped = w end
                if box and w > box + 0.6 then over = over + 1 end
            end
        end
        st.wrapped = readable and wrapped or nil
        st.over = readable and over or nil
    end
    return st
end
function C.WrapOff()   -- true when the frame is laying text out at a width that is not the one it has now
    local st = C.WrapStatus()
    if not st then return false end
    if st.line and st.cf and math.abs(st.line - st.cf) > 0.6 then return true end
    if st.cf and st.text and math.abs(st.cf - st.text) > 0.6 then return true end
    return false
end
local lastRewrap = 0
function C.Rewrap(force)
    local cf = C.Main()
    if not cf then return false end
    local now = GetTime and GetTime() or 0
    if not force and now - lastRewrap < 1 then return false end
    lastRewrap = now
    -- only MarkLayoutDirty: it is one of the window's secure methods (ScrollingMessageFrameSecureMixin), so the window lays its lines out
    -- again in its own OnUpdate, untainted. 0.5.107 to 0.6.4 also called RefreshIfNecessary, which is NOT secure: the game's layout code
    -- then ran as XayaUI_Chat code, and drawing protected (secret) text from tainted code may raise errors (risk, not seen in game).
    local ok = pcall(function()
        if cf.MarkLayoutDirty then cf:MarkLayoutDirty() end
    end)
    C.stats.rewraps = (C.stats.rewraps or 0) + (ok and 1 or 0)
    return ok
end

local function Refresh(s)
    if not C.On() then
        if container then container:Hide() end
        return
    end
    Build()
    container:Show()
    C.Layout()
    -- the game re-anchors these when windows are docked, locked or opened; anchor again right after
    for _, key in ipairs({ "FCF_DockUpdate", "FCF_RestorePositionAndDimensions", "FCF_SetLocked", "FCF_UpdateButtonSide", "FCF_SetWindowAlpha",
        "FCF_StopDragging", "FCF_DockFrame", "FCF_UnDockFrame", "FCF_ResetChatWindows" }) do
        C.HookOnce("frame:" .. key, key, nil, Soft)
    end
    -- the edit box opening and closing: hooked where the game itself calls them (ChatFrameUtil in 12.x; see Compat.lua)
    for _, key in ipairs({ "ActivateChat", "DeactivateChat" }) do
        local tbl, method = ns.Compat.ChatHookTarget(key)
        if tbl then C.HookOnce("frame:" .. key, tbl, method, Soft) end
    end
    -- the game moves a window by calling SetPoint / StopMovingOrSizing on it (dragging a tab, Edit Mode, a reset): glue it back at once
    local cf = C.Main()
    if cf then
        for _, m in ipairs({ "SetPoint", "ClearAllPoints", "StopMovingOrSizing", "SetUserPlaced" }) do
            C.HookOnce("cf:" .. m, cf, m, function() if not C.anchoring and C.On() then C.SoonAnchor() end end)
        end
    end
end
C.Register("frame", Refresh)

-- upkeep: input hint, anchors the game may have changed
local acc, slow = 0, 0
local up = CreateFrame("Frame")
up:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.3 then return end
    slow = slow + acc
    acc = 0
    local s = S()
    if s and container and C.On() and slow >= 3 then slow = 0; C.Parts() end   -- the game may put its strip / social button back
    if not (s and container and C.On()) then return end
    local cf = C.Main()
    if not C.Glued() then C.Anchor() end
    if cf and cf.IsShown and cf:IsShown() and C.WrapOff() then C.Rewrap() end
    local eb = C.EditBoxOf(cf or {})
    local typing = eb and eb.IsShown and eb:IsShown()
    hint:SetShown(s.inputHint and not typing and not s.collapsed and true or false)
    hint:SetText(s.inputHintText or "")
end)
