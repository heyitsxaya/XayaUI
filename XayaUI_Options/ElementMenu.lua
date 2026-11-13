-------------------------------------------------------------------------------
-- XayaUI_Options/ElementMenu.lua : the at-cursor menu a right-click on a XayaUI element opens while the settings window is shown
-- ("Element options" and X / Y inputs). Code moved unchanged from XayaUI core (XayaUI/Modules.lua section 11, core 0.6.80; #495,
-- REQUEST-LOG PS-59: her words and the design notes are kept there, with the registry).
-- (bundle 1 round 7, REQUEST-LOG A23 SD-58, her words: "Move all four (Recommended)"; V34) Part of XayaUI Options since round 7: the
-- game reads it only when the settings window's code loads, never at login. The menu only ever works while the window is shown, so
-- nothing changes for the player. What stays in core is the small registry, ns.RegisterElement / ns.ElementDefs (a module registers its
-- element when it makes the element's frame); core hands each registration to this file through ns.ElementMenuDriver once it is loaded.
-- Here: putting the right-click handlers on when the window opens and the frames' own scripts back when it closes, the menu itself
-- (made at the first right-click, its two events registered only while it shows), and the test entry points.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
if not (ns.ElementDefs and ns.ElementMenuDriver) then return end

local function Report(err)
    local h = geterrorhandler and geterrorhandler()
    if h then h(err) end
end
local function Call(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Report(err) end
    return ok
end

local elements, elementOrder = ns.ElementDefs()   -- core's registry (Modules.lua section 11): the same two tables, kept up to date there
local attached = {}          -- [frame] = { [script] = record } for script wrappers (put back when the window closes)
local hookedBlizz = {}       -- [frame] = { def, ctx }: post-hooks on Blizzard frames (stay until /reload, return at once while closed)
local windowShown = false
local menu                   -- the menu frame (made at the first right-click)
local function InCombat() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function Protected(f)
    if not (f and f.IsProtected) then return false end
    local ok, p = pcall(f.IsProtected, f)
    return (not ok) or (p and true or false)   -- an answer the game will not give: treated as protected (never touched)
end

local function Detach()
    for f, scripts in pairs(attached) do
        for script, rec in pairs(scripts) do
            if f:GetScript(script) == rec.wrapper then f:SetScript(script, rec.orig) end
            if rec.mouseOn and f.EnableMouse and not Protected(f) then f:EnableMouse(false) end
        end
    end
    attached = {}
end
local Open   -- (below)
local function AttachOne(def, f, script, ctx)
    if type(f) ~= "table" or not f.GetScript or Protected(f) then return end
    script = script or "OnMouseUp"
    if def.blizzard then
        if hookedBlizz[f] or InCombat() then return end   -- (the next opening tries again)
        hookedBlizz[f] = { def = def, ctx = ctx }
        f:HookScript(script, function(self, btn)
            if not windowShown or btn ~= "RightButton" then return end
            local h = hookedBlizz[self]
            if h then Open(h.def, h.ctx, self) end
        end)
        return
    end
    attached[f] = attached[f] or {}
    local rec = attached[f][script]
    if rec then rec.def, rec.ctx = def, ctx; return end
    rec = { def = def, ctx = ctx, orig = f:GetScript(script) }
    rec.wrapper = function(self, btn, ...)
        if btn == "RightButton" and windowShown and Open(rec.def, rec.ctx, self) then return end
        if rec.orig then return rec.orig(self, btn, ...) end
    end
    f:SetScript(script, rec.wrapper)
    if def.mouse and f.IsMouseEnabled and f.EnableMouse and not f:IsMouseEnabled() then f:EnableMouse(true); rec.mouseOn = true end
    attached[f][script] = rec
end
local function Attach(def)
    Call(def.targets, function(f, script, ctx) AttachOne(def, f, script, ctx) end)
end

-- core's ns.RegisterElement calls this for every element it stored (Modules.lua section 11): while the window is shown, the new frame
-- takes the right-click at once
ns.ElementMenuDriver(function(def) if windowShown then Attach(def) end end)
-- a module made a frame of a registered element while the window is shown: it takes the right-click now
function ns.ElementsRefresh() if windowShown then for _, k in ipairs(elementOrder) do Attach(elements[k]) end end end
-- XayaUI_Options says when its window is shown (Tree.DriverStart) and closed (Tree.Closed). Shown again (a redraw): new frames join.
function ns.ElementWindowShown(on)
    if on then
        windowShown = true
        for _, k in ipairs(elementOrder) do Attach(elements[k]) end
    else
        windowShown = false
        Detach()
        if menu then menu:Hide() end
    end
end
function ns.ElementWindowIsShown() return windowShown end
-- (tests) how many frames carry a right-click wrapper now
function ns.ElementHandlersAttached()
    local n = 0
    for _, s in pairs(attached) do for _ in pairs(s) do n = n + 1 end end
    return n
end

local function Round(v) v = tonumber(v); if not v then return nil end return math.floor(v + 0.5) end
local function Fill()
    local m = menu
    local def, ctx = m.def, m.ctx
    local hasXY = (not def.blizzard) and type(def.getPos) == "function" and type(def.setPos) == "function"
    m.hasXY = hasXY
    local M, G = ns.Style.margin, math.floor(ns.Style.gutter / 2)
    local y = M
    local rows = {}
    if type(def.rows) == "function" then
        local ok, r = pcall(def.rows, ctx)
        if ok and type(r) == "table" then rows = r end
    end
    local first = 1
    if rows[1] and rows[1].title then   -- the existing menu's own title stays on top
        m.title:SetText(tostring(rows[1].title)); m.title:ClearAllPoints(); m.title:SetPoint("TOPLEFT", M, -y); m.title:Show()
        y = y + 14 + G; first = 2
    else
        m.title:Hide()
    end
    m.options:ClearAllPoints(); m.options:SetPoint("TOPLEFT", M, -y); y = y + 22 + G
    m.xLabel:SetShown(hasXY); m.yLabel:SetShown(hasXY); m.x:SetShown(hasXY); m.y:SetShown(hasXY)
    if hasXY then
        local ok, x, yy = pcall(def.getPos, ctx)
        m.x:ClearAllPoints(); m.x:SetPoint("TOPLEFT", M + 24, -y); m.xLabel:ClearAllPoints(); m.xLabel:SetPoint("RIGHT", m.x, "LEFT", -10, 0)
        y = y + 20 + G
        m.y:ClearAllPoints(); m.y:SetPoint("TOPLEFT", M + 24, -y); m.yLabel:ClearAllPoints(); m.yLabel:SetPoint("RIGHT", m.y, "LEFT", -10, 0)
        y = y + 20 + G
        m.x:SetText(tostring(ok and Round(x) or 0)); m.y:SetText(tostring(ok and Round(yy) or 0))
        m.x:SetCursorPosition(0); m.y:SetCursorPosition(0)
    end
    -- the existing menu's entries (a sub-menu opens the game's own context menu with that entry's choices, as before)
    m.rowPool = m.rowPool or {}
    for _, b in ipairs(m.rowPool) do b:Hide() end
    m.lines = m.lines or {}
    for _, l in ipairs(m.lines) do l:Hide() end
    local nb, nl = 0, 0
    m.shownRows = {}
    for i = first, #rows do
        local r = rows[i]
        if r.divider or r.title then
            nl = nl + 1
            local l = m.lines[nl]
            if not l then l = m:CreateTexture(nil, "ARTWORK"); l:SetColorTexture(1, 0.6, 0.1, 0.5); l:SetHeight(1); m.lines[nl] = l end
            l:ClearAllPoints(); l:SetPoint("TOPLEFT", M, -(y + 2)); l:SetPoint("TOPRIGHT", -M, -(y + 2)); l:Show()
            y = y + 4 + G
        else
            nb = nb + 1
            local b = m.rowPool[nb]
            if not b then
                b = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
                b:SetSize(200, 20)
                if ns.FlatButton then ns.FlatButton(b) end
                m.rowPool[nb] = b
            end
            local text = tostring(r.text or r.radio or "")
            if r.sub then text = text .. "  >" end
            if r.radio and type(r.checked) == "function" then
                local okc, on = pcall(r.checked)
                if okc and on then text = "* " .. text end
            end
            b:SetText(text)
            b.row = r
            b:SetScript("OnClick", function(self)
                local row = self.row
                if row.sub then
                    if MenuUtil and MenuUtil.CreateContextMenu then
                        Call(MenuUtil.CreateContextMenu, self, function(_, root) row.sub(root) end)
                    end
                    return
                end
                local fn = row.func
                menu:Hide()
                if type(fn) == "function" then Call(fn) end
            end)
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", M, -y); b:Show()
            y = y + 20 + G
            m.shownRows[#m.shownRows + 1] = b
        end
    end
    m:SetHeight(y - G + M)
end
local function Apply()
    local m = menu
    if not (m and m:IsShown() and m.hasXY) or InCombat() then return end
    local def, ctx = m.def, m.ctx
    local okp, cx, cy = pcall(def.getPos, ctx)
    local x, y = Round(m.x:GetText()), Round(m.y:GetText())
    x, y = x or (okp and Round(cx)) or 0, y or (okp and Round(cy)) or 0
    if okp and Round(cx) == x and Round(cy) == y then Fill(); return end
    Call(def.setPos, ctx, x, y)
    Fill()
    ns.Fire("CONFIG_CHANGED")   -- the settings window redraws: its own page shows the new numbers
end
local function Build()
    if menu then return end
    local m = CreateFrame("Frame", "XayaUIElementMenu", UIParent, "BackdropTemplate")
    local M = ns.Style.margin
    -- the look of XayaUI's at-cursor X / Y popup (the group outline's, #267, XayaUI_Rules/Visual.lua ShowGroupPosPopup): near-black,
    -- a 1 px orange edge, the game's input boxes and XayaUI's flat buttons
    m:SetSize(200 + 2 * M, 100); m:SetFrameStrata("FULLSCREEN_DIALOG"); m:SetClampedToScreen(true); m:EnableMouse(true); m:Hide()
    m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    m:SetBackdropColor(0.05, 0.05, 0.05, 0.96); m:SetBackdropBorderColor(1, 0.6, 0.1, 1)
    m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    m.options = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
    m.options:SetSize(200, 22); m.options:SetText("Element options")
    if ns.FlatButton then ns.FlatButton(m.options, true) end
    m.options:SetScript("OnClick", function()
        local def, ctx = m.def, m.ctx
        m:Hide()
        if type(def.open) == "function" then Call(def.open, ctx)
        elseif type(def.page) == "table" then Call(ns.OpenSettingsPage, unpack(def.page)) end
    end)
    local function Box(label)
        local fs = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); fs:SetText(label)
        local eb = CreateFrame("EditBox", nil, m, "InputBoxTemplate")
        eb:SetSize(100, 20); eb:SetAutoFocus(false); eb:SetMaxLetters(8)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Apply() end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); Fill() end)
        eb:SetScript("OnTabPressed", function(self) Apply(); if self == m.x then m.y:SetFocus() else m.x:SetFocus() end end)
        return eb, fs
    end
    m.x, m.xLabel = Box("X")
    m.y, m.yLabel = Box("Y")
    -- closes on Escape, on a click outside it, and when combat starts; its events are registered only while it shows (V14)
    if UISpecialFrames then table.insert(UISpecialFrames, "XayaUIElementMenu") end
    m:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN"); self:RegisterEvent("PLAYER_REGEN_DISABLED") end)
    m:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN"); self:UnregisterEvent("PLAYER_REGEN_DISABLED")
        self.x:ClearFocus(); self.y:ClearFocus()
    end)
    m:SetScript("OnEvent", function(self, ev)
        if ev == "PLAYER_REGEN_DISABLED" then self:Hide(); return end
        if ev == "GLOBAL_MOUSE_DOWN" and not self:IsMouseOver() then self:Hide() end
    end)
    menu = m
end
Open = function(def, ctx, owner)
    if not windowShown or InCombat() or type(def) ~= "table" then return false end
    Build()
    menu.def, menu.ctx, menu.owner = def, ctx, owner
    Fill()
    local cx, cy = GetCursorPosition()
    local us = UIParent:GetEffectiveScale()
    if not (us and us > 0) then us = 1 end
    menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / us + 10, cy / us - 10)
    menu:Show()
    return true
end
-- (tests and Dev Assist's walkthrough) the menu frame, and a right-click as the game would send it
function ns.ElementMenu() return menu end
function ns.ElementMenuApply() Apply() end
function ns.ElementRightClick(f, script)
    script = script or "OnMouseUp"
    local fn = f and f.GetScript and f:GetScript(script)
    if fn then fn(f, "RightButton") end
    return menu ~= nil and menu:IsShown()
end
