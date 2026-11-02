-------------------------------------------------------------------------------
-- ChatWidgets.lua : tiny self-contained widgets (no Blizzard templates except BackdropTemplate) used by the chat dock's
-- position window and the below-chat panel's settings window, so both open without the main XayaUI settings window.
-- Arrows are drawn with Line objects, not font glyphs, so they cannot be clipped by a font's missing / thin characters.
-------------------------------------------------------------------------------
local ADDON, ns = ...
local W = {}
ns.CW = W

local BD = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
local ACCENT = { 0.2, 0.7, 1 }

local function Box(parent, r, g, b, a, er, eg, eb, ea)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop(BD)
    f:SetBackdropColor(r or 0, g or 0, b or 0, a or 0.8)
    f:SetBackdropBorderColor(er or 0, eg or 0, eb or 0, ea or 1)
    return f
end
W.Box = Box

local function Label(parent, text, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    if r then fs:SetTextColor(r, g, b) end
    return fs
end

-- Chevron ------------------------------------------------------------------------------------------------------------------
-- dir = "LEFT" | "RIGHT" | "UP" | "DOWN". size = the square it is drawn in (pixels).
local ANGLE = { RIGHT = 0, UP = math.pi / 2, LEFT = math.pi, DOWN = -math.pi / 2 }
function W.Chevron(parent, size, dir, r, g, b)
    local c = { holder = CreateFrame("Frame", nil, parent), size = size or 12, r = r or 1, g = g or 0.82, b = b or 0 }
    c.holder:SetSize(c.size, c.size)
    c.holder:EnableMouse(false)
    c.l1 = c.holder:CreateLine(nil, "OVERLAY")
    c.l2 = c.holder:CreateLine(nil, "OVERLAY")
    function c:SetColor(rr, gg, bb, aa)
        self.r, self.g, self.b = rr, gg, bb
        for _, l in ipairs({ self.l1, self.l2 }) do l:SetColorTexture(rr, gg, bb, aa or 1) end
    end
    function c:SetDir(d)
        local th = ANGLE[d] or 0
        local cs, sn = math.cos(th), math.sin(th)
        local h = self.size * 0.32
        local function pt(x, y) return x * cs - y * sn, x * sn + y * cs end
        local ax, ay = pt(-h * 0.6, h)
        local tx, ty = pt(h * 0.6, 0)
        local bx, by = pt(-h * 0.6, -h)
        local thick = math.max(2, math.floor(self.size / 7))
        for _, l in ipairs({ self.l1, self.l2 }) do l:SetThickness(thick) end
        self.l1:SetStartPoint("CENTER", self.holder, ax, ay); self.l1:SetEndPoint("CENTER", self.holder, tx, ty)
        self.l2:SetStartPoint("CENTER", self.holder, tx, ty); self.l2:SetEndPoint("CENTER", self.holder, bx, by)
        self.dir = d
    end
    c:SetColor(c.r, c.g, c.b)
    c:SetDir(dir or "RIGHT")
    return c
end

-- Button -------------------------------------------------------------------------------------------------------------------
function W.Button(parent, w, h, text, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetBackdrop(BD)
    b:SetBackdropColor(0.15, 0.15, 0.15, 0.9); b:SetBackdropBorderColor(0, 0, 0, 1)
    b:SetSize(w, h)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER"); b.text:SetText(text or "")
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0, 0, 0, 1) end)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if onClick then b:SetScript("OnClick", function(self, btn) onClick(self, btn) end) end
    return b
end

function W.ArrowButton(parent, size, dir, onClick)
    local b = W.Button(parent, size, size, "", onClick)
    b.chevron = W.Chevron(b, size - 6, dir, 1, 0.82, 0)
    b.chevron.holder:SetPoint("CENTER")
    return b
end

-- Window -------------------------------------------------------------------------------------------------------------------
-- win.content is where rows go: win:Add(row, height). Scrolls with the mouse wheel when the rows are taller than the window.
function W.Window(name, title, width, height)
    local f = Box(UIParent, 0.06, 0.06, 0.06, 0.96, 0, 0, 0, 1)
    if name then _G[name] = f end
    f:SetSize(width, height)
    f:SetFrameStrata("DIALOG"); f:SetFrameLevel(100)
    f:SetClampedToScreen(true)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); if self.OnMoved then self:OnMoved() end end)
    f:Hide()
    if name and UISpecialFrames then table.insert(UISpecialFrames, name) end

    local bar = Box(f, 0.12, 0.12, 0.12, 1, 0, 0, 0, 1)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(22)
    local t = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("LEFT", 8, 0); t:SetText(title or "")
    local x = W.Button(bar, 22, 22, "X", function() f:Hide() end)
    x:SetPoint("RIGHT", 0, 0)

    local sf = CreateFrame("ScrollFrame", nil, f)
    sf:SetPoint("TOPLEFT", 8, -28); sf:SetPoint("BOTTOMRIGHT", -8, 8)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(width - 16, 10)
    sf:SetScrollChild(content)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 30)))
    end)
    f.content, f.scroll, f.y, f.widgets = content, sf, 0, {}

    function f:Add(row, h, gap)
        h = h or 22
        row:SetParent(content)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -self.y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -self.y)
        row:SetHeight(h)
        self.y = self.y + h + (gap or 4)
        content:SetHeight(self.y)
        if row.Refresh then self.widgets[#self.widgets + 1] = row end
        return row
    end
    function f:RefreshAll()
        for _, w in ipairs(self.widgets) do pcall(w.Refresh, w) end
    end
    f:SetScript("OnShow", function(self) self:RefreshAll() end)
    return f
end

-- Rows (all return a frame with :Refresh()) --------------------------------------------------------------------------------
function W.Header(text)
    local r = CreateFrame("Frame")
    local fs = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("BOTTOMLEFT", 0, 2); fs:SetText(text)
    local ln = r:CreateTexture(nil, "ARTWORK"); ln:SetColorTexture(1, 1, 1, 0.15)
    ln:SetPoint("BOTTOMLEFT"); ln:SetPoint("BOTTOMRIGHT"); ln:SetHeight(1)
    return r
end

function W.Note(text, r, g, b)
    local row = CreateFrame("Frame")
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT"); fs:SetPoint("TOPRIGHT"); fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP")
    fs:SetTextColor(r or 0.7, g or 0.7, b or 0.7); fs:SetText(text)
    return row
end

function W.Check(label, get, set)
    local row = CreateFrame("Button")
    row.box = Box(row, 0.1, 0.1, 0.1, 1, 0, 0, 0, 1)
    row.box:SetSize(14, 14); row.box:SetPoint("LEFT", 0, 0)
    row.fill = row.box:CreateTexture(nil, "OVERLAY")
    row.fill:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    row.fill:SetPoint("TOPLEFT", 3, -3); row.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    row.text = Label(row, label)
    row.text:SetPoint("LEFT", row.box, "RIGHT", 6, 0); row.text:SetPoint("RIGHT")
    function row:Refresh() self.fill:SetShown(get() and true or false) end
    row:SetScript("OnClick", function(self) set(not get()); self:Refresh() end)
    return row
end

function W.Number(label, get, set, min, max, step)
    local row = CreateFrame("Frame")
    row.text = Label(row, label)
    row.text:SetPoint("LEFT", 0, 0)
    local plus = W.Button(row, 18, 18, "+", function() local v = (get() or 0) + (step or 1) * (IsShiftKeyDown() and 10 or 1); row:Apply(v) end)
    plus:SetPoint("RIGHT", 0, 0)
    row.edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    row.edit:SetBackdrop(BD); row.edit:SetBackdropColor(0.1, 0.1, 0.1, 1); row.edit:SetBackdropBorderColor(0, 0, 0, 1)
    row.edit:SetSize(56, 18); row.edit:SetPoint("RIGHT", plus, "LEFT", -2, 0)
    row.edit:SetFontObject("GameFontHighlightSmall"); row.edit:SetJustifyH("CENTER")
    row.edit:SetAutoFocus(false); row.edit:SetTextInsets(2, 2, 0, 0)
    local minus = W.Button(row, 18, 18, "-", function() local v = (get() or 0) - (step or 1) * (IsShiftKeyDown() and 10 or 1); row:Apply(v) end)
    minus:SetPoint("RIGHT", row.edit, "LEFT", -2, 0)
    row.text:SetPoint("RIGHT", minus, "LEFT", -4, 0)
    function row:Apply(v)
        v = tonumber(v)
        if not v then self:Refresh() return end
        if min and v < min then v = min end
        if max and v > max then v = max end
        set(v)
        self:Refresh()
    end
    function row:Refresh()
        local v = get()
        if not self.edit:HasFocus() then self.edit:SetText(v ~= nil and tostring(math.floor(v * 100 + 0.5) / 100) or "") end
    end
    row.edit:SetScript("OnEnterPressed", function(self) row:Apply(self:GetText()); self:ClearFocus() end)
    row.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); row:Refresh() end)
    row.edit:SetScript("OnEditFocusLost", function(self) row:Apply(self:GetText()) end)
    return row
end

-- values = ordered list of { key, text }; click = next, right click = previous
function W.Cycle(label, values, get, set)
    local row = CreateFrame("Frame")
    row.text = Label(row, label)
    row.text:SetPoint("LEFT", 0, 0)
    row.btn = W.Button(row, 120, 18, "", function(_, btn)
        local cur, idx = get(), 1
        for i, v in ipairs(values) do if v[1] == cur then idx = i end end
        idx = idx + (btn == "RightButton" and -1 or 1)
        if idx > #values then idx = 1 elseif idx < 1 then idx = #values end
        set(values[idx][1]); row:Refresh()
    end)
    row.btn:SetPoint("RIGHT", 0, 0)
    row.text:SetPoint("RIGHT", row.btn, "LEFT", -4, 0)
    function row:Refresh()
        local cur = get()
        for _, v in ipairs(values) do if v[1] == cur then self.btn.text:SetText(v[2]) return end end
        self.btn.text:SetText(tostring(cur))
    end
    return row
end

function W.Color(label, get, set)   -- get() -> r,g,b ; set(r,g,b)
    local row = CreateFrame("Frame")
    row.text = Label(row, label)
    row.text:SetPoint("LEFT", 0, 0)
    row.sw = Box(row, 1, 1, 1, 1, 0, 0, 0, 1)
    row.sw:SetSize(40, 16); row.sw:SetPoint("RIGHT", 0, 0)
    row.click = CreateFrame("Button", nil, row.sw); row.click:SetAllPoints()
    row.text:SetPoint("RIGHT", row.sw, "LEFT", -4, 0)
    function row:Refresh() local r, g, b = get(); self.sw:SetBackdropColor(r or 1, g or 1, b or 1, 1) end
    row.click:SetScript("OnClick", function()
        local r, g, b = get()
        local function apply() local nr, ng, nb = ColorPickerFrame:GetColorRGB(); set(nr, ng, nb); row:Refresh() end
        local function cancel(prev)
            if type(prev) == "table" then set(prev.r or prev[1] or r, prev.g or prev[2] or g, prev.b or prev[3] or b)
            else set(r, g, b) end
            row:Refresh()
        end
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = apply, cancelFunc = cancel })
        elseif ColorPickerFrame then   -- pre-10.2 shape
            ColorPickerFrame.func, ColorPickerFrame.cancelFunc, ColorPickerFrame.hasOpacity = apply, cancel, false
            ColorPickerFrame:SetColorRGB(r, g, b); ColorPickerFrame:Show()
        end
    end)
    return row
end

function W.Text(label, get, set)
    local row = CreateFrame("Frame")
    row.text = Label(row, label)
    row.text:SetPoint("TOPLEFT", 0, 0)
    row.edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    row.edit:SetBackdrop(BD); row.edit:SetBackdropColor(0.1, 0.1, 0.1, 1); row.edit:SetBackdropBorderColor(0, 0, 0, 1)
    row.edit:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2); row.edit:SetPoint("RIGHT", 0, 0); row.edit:SetHeight(18)
    row.edit:SetFontObject("GameFontHighlightSmall"); row.edit:SetAutoFocus(false); row.edit:SetTextInsets(4, 4, 0, 0)
    row.edit:SetMaxLetters(120)
    function row:Refresh() if not self.edit:HasFocus() then self.edit:SetText(get() or "") end end
    row.edit:SetScript("OnEnterPressed", function(self) set(self:GetText()); self:ClearFocus() end)
    row.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); row:Refresh() end)
    row.edit:SetScript("OnEditFocusLost", function(self) set(self:GetText()) end)
    return row
end
