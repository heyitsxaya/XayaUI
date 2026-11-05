-------------------------------------------------------------------------------
-- Chat/Scroll.lua : the Chat Panel's own scroll bar, in the space right of the chat text, for slow manual scrolling.
--   * The arrows move the chat ONE line per click. Held down, they keep going at "scrollSpeed" lines a second after a short pause.
--   * The thumb shows where you are in the window's history and can be dragged. A click on the track moves one page.
--   * The mouse wheel over the bar scrolls one line per notch, like the chat itself.
-- It moves the window you are looking at (the selected tab). Every call that moves the text is one of the window's secure methods
-- (ScrollingMessageFrameSecureMixin in Blizzard_SharedXML/ScrollingMessageFrame.lua: ScrollByAmount, PageUp, PageDown,
-- SetScrollOffset), which the game runs as untainted even when an addon calls them. Reading the position (GetScrollOffset,
-- GetMaxScrollRange, GetNumVisibleLines) changes nothing. Own code, written from the game's published UI source. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local C = ns.Chat
local issecret = C.IsSecret
local function S() return ns.chat2 end
local function Num(v) v = tonumber(v); if not v or issecret(v) then return nil end return v end
local function Clamp(v, lo, hi, def) v = Num(v); if not v then return def end return math.max(lo, math.min(hi, v)) end

local REPEAT_DELAY = 0.35        -- seconds an arrow is held before it starts repeating
local MIN_THUMB = 12
local bar, up, down, track, thumb
local held, heldT = nil, 0       -- held: +1 (older) / -1 (newer) while an arrow is pressed
local dragging = false
local tick = 0

-- the window the pane shows right now (the selected tab of the dock)
function C.ScrollTarget()
    local dock, get = _G.GENERAL_CHAT_DOCK, _G.FCFDock_GetSelectedWindow
    if dock and type(get) == "function" then
        local ok, f = pcall(get, dock)
        if ok and type(f) == "table" then return f end
    end
    if type(_G.SELECTED_DOCK_FRAME) == "table" then return _G.SELECTED_DOCK_FRAME end
    return C.Main()
end

-- offset (0 = the newest line at the bottom), the largest offset, the number of lines the window shows
function C.ScrollPos(f)
    f = f or C.ScrollTarget()
    if not (f and f.GetScrollOffset and f.GetMaxScrollRange) then return nil end
    local ok, off, max, vis = pcall(function()
        return f:GetScrollOffset(), f:GetMaxScrollRange(), f.GetNumVisibleLines and f:GetNumVisibleLines() or nil
    end)
    if not ok then return nil end
    return Num(off), Num(max), Num(vis)
end

local function Call(method, ...)
    local f = C.ScrollTarget()
    if not (f and type(f[method]) == "function") then return false end
    return (pcall(f[method], f, ...))
end
function C.ScrollLines(n) return Call("ScrollByAmount", n) end          -- n > 0: older (up); n < 0: newer (down)

local Update
local function Step(dir) C.ScrollLines(dir); Update() end

local function Chevron(btn, pointsUp)
    btn.l1 = btn.l1 or btn:CreateLine(nil, "OVERLAY")
    btn.l2 = btn.l2 or btn:CreateLine(nil, "OVERLAY")
    local k = 3
    local function seg(l, x1, y1, x2, y2)
        l:SetThickness(1.5); l:SetColorTexture(1, 1, 1, 0.85)
        l:SetStartPoint("CENTER", btn, x1, y1); l:SetEndPoint("CENTER", btn, x2, y2)
    end
    if pointsUp then seg(btn.l1, -k, -k / 2, 0, k / 2); seg(btn.l2, 0, k / 2, k, -k / 2)
    else seg(btn.l1, -k, k / 2, 0, -k / 2); seg(btn.l2, 0, -k / 2, k, k / 2) end
end

local function CursorY(region)
    local _, cy = GetCursorPosition()
    local sc = region.GetEffectiveScale and region:GetEffectiveScale() or 1
    if not (Num(cy) and Num(sc) and sc > 0) then return nil end
    return cy / sc
end

local function ArrowButton(name, dir)
    local b = CreateFrame("Button", name, bar)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(1, 1, 1, 0.08)
    Chevron(b, dir > 0)
    b:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        held, heldT = dir, -REPEAT_DELAY
        Step(dir)
    end)
    b:SetScript("OnMouseUp", function() held = nil end)
    b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(1, 1, 1, 0.2) end)
    b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 1, 1, 0.08) end)
    return b
end

local function DragTo()
    local f = C.ScrollTarget()
    local _, max = C.ScrollPos(f)
    local cy, b, h, th = CursorY(track), track:GetBottom(), track:GetHeight(), thumb:GetHeight()
    if not (max and cy and Num(b) and Num(h) and Num(th)) or max <= 0 or h - th <= 0 then return end
    local frac = math.max(0, math.min(1, (cy - b - th / 2) / (h - th)))
    Call("SetScrollOffset", math.floor(frac * max + 0.5))
end

-- held arrows, a dragged thumb, and the thumb following the window (10 times a second). V14: set while the bar is shown, cleared when
-- "Chat Panel scroll bar" or the Chat Panel is turned off (C.ScrollBar_Layout).
local function Tick(_, dt)
    local s = S()
    if held then
        local every = 1 / Clamp(s and s.scrollSpeed, 1, 30, 6)
        heldT = heldT + dt
        local n = 0
        while heldT >= every and n < 30 do heldT = heldT - every; C.ScrollLines(held); n = n + 1 end
    end
    if dragging then DragTo() end
    tick = tick + dt
    if held or dragging or tick >= 0.1 then tick = 0; Update() end
end

local function Build()
    if bar then return end
    bar = CreateFrame("Frame", "XayaUIChatScrollBar", C.Pane())
    bar:SetFrameStrata("MEDIUM")
    bar:EnableMouseWheel(true)
    bar:SetScript("OnMouseWheel", function(_, delta) Step((delta or 0) > 0 and 1 or -1) end)
    up = ArrowButton("XayaUIChatScrollUp", 1)
    down = ArrowButton("XayaUIChatScrollDown", -1)
    track = CreateFrame("Button", "XayaUIChatScrollTrack", bar)
    track.bg = track:CreateTexture(nil, "BACKGROUND"); track.bg:SetAllPoints(); track.bg:SetColorTexture(1, 1, 1, 0.05)
    track:SetScript("OnMouseDown", function(self, button)      -- a click above the thumb: one page older; below: one page newer
        if button ~= "LeftButton" then return end
        local cy, tb, tt = CursorY(self), thumb:GetBottom(), thumb:GetTop()
        if not (cy and Num(tb) and Num(tt)) then return end
        if cy > tt then Call("PageUp") elseif cy < tb then Call("PageDown") end
        Update()
    end)
    thumb = CreateFrame("Button", "XayaUIChatScrollThumb", track)
    thumb.t = thumb:CreateTexture(nil, "ARTWORK"); thumb.t:SetAllPoints(); thumb.t:SetColorTexture(0.85, 0.85, 0.85, 0.45)
    thumb:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then dragging = true end end)
    thumb:SetScript("OnMouseUp", function() dragging = false end)
    thumb:SetScript("OnEnter", function(self) self.t:SetColorTexture(0.85, 0.85, 0.85, 0.8) end)
    thumb:SetScript("OnLeave", function(self) self.t:SetColorTexture(0.85, 0.85, 0.85, 0.45) end)
    bar:SetScript("OnHide", function() held = nil; dragging = false end)
end

-- the thumb: its size is the share of the history the window shows; its place is how far up you have scrolled
Update = function()
    if not (bar and bar:IsShown()) then return end
    local h = Num(track:GetHeight()) or 0
    local off, max, vis = C.ScrollPos()
    local th, y = h, 0
    if off and max and max > 0 then
        vis = math.max(1, vis or 1)
        th = math.max(MIN_THUMB, math.min(h, h * vis / (max + vis)))
        y = (h - th) * math.max(0, math.min(1, off / max))
    end
    thumb:ClearAllPoints()
    thumb:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, y)
    thumb:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, y)
    thumb:SetHeight(math.max(1, th))
    thumb:SetAlpha((max and max > 0) and 1 or 0.4)       -- nothing to scroll: a dim, full-height thumb
end
C.ScrollBar_Update = function() Update() end

function C.ScrollBar() return bar end

-- placed by C.Layout (Frame.lua), which keeps the space for it right of the text
function C.ScrollBar_Layout()
    local s, textA = S(), C.TextArea()
    if not (s and textA) then return end
    if not (s.scrollOwn and C.On()) then
        if bar then bar:Hide(); bar:SetScript("OnUpdate", nil) end
        return
    end
    Build()
    local w = Clamp(s.scrollW, 6, 20, 10)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", textA, "TOPRIGHT", 2, 0)
    bar:SetPoint("BOTTOMLEFT", textA, "BOTTOMRIGHT", 2, 0)
    bar:SetWidth(w)
    up:ClearAllPoints(); up:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0); up:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0); up:SetHeight(w)
    down:ClearAllPoints(); down:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0); down:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0); down:SetHeight(w)
    track:ClearAllPoints()
    track:SetPoint("TOPLEFT", up, "BOTTOMLEFT", 0, -2)
    track:SetPoint("BOTTOMRIGHT", down, "TOPRIGHT", 0, 2)
    bar:Show()
    bar:SetScript("OnUpdate", Tick)
    Update()
end

C.Register("scroll", function() C.ScrollBar_Layout() end)
-- the "scroll" part: C.ScrollBar_Layout above starts the bar's OnUpdate; this stops it when the switch or the whole Chat Panel goes off
-- (C.Teardown does not lay the bar out)
C.Part("scroll", function(s) return s.scrollOwn end, nil,
    function() if bar then bar:Hide(); bar:SetScript("OnUpdate", nil) end end)
