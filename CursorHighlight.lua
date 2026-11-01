-------------------------------------------------------------------------------
-- CursorHighlight.lua : a colored shape (circle, square, diamond, star) that sits under the mouse cursor.
-- Left tab of QoL UI Updates > Cursor. OFF by default; while off nothing is created, polled, or drawn.
-- Saved settings: CueRulesDB.cursorHighlight. Not run in game when written (2026-11-01): the look needs an in-game check.
--
-- Shapes: circle = a square texture cut with a circular mask; diamond = a Line region as thick as it is long, drawn at 45 degrees
-- (SetRotation only turns the image inside a texture, so it cannot turn a solid square into a diamond); square and star are plain textures.
-------------------------------------------------------------------------------
local addonName, ns = ...

local SHAPES = {
    circle  = { "Circle",  "Interface\\Buttons\\WHITE8X8",  "BLEND" },
    square  = { "Square",  "Interface\\Buttons\\WHITE8X8",  "BLEND" },
    diamond = { "Diamond", "Interface\\Buttons\\WHITE8X8",  "BLEND" },
    star    = { "Star",    "Interface\\Cooldown\\star4",    "ADD"   },
}
local SHAPE_ORDER = { "circle", "square", "diamond", "star" }

ns.CURSORHIGHLIGHT_DEFAULTS = {
    enabled = false,
    shape = "circle",
    size = 56,
    color = { 1.00, 0.82, 0.10 },
    opacity = 0.35,
    combatOnly = false,
    hideMouselook = true,
}

local function CopyVal(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyVal(x) end
    return t
end
local function Ensure()
    if not CueRulesDB then return nil end
    local c = CueRulesDB.cursorHighlight
    if type(c) ~= "table" then c = {}; CueRulesDB.cursorHighlight = c end
    for k, v in pairs(ns.CURSORHIGHLIGHT_DEFAULTS) do
        if c[k] == nil then c[k] = CopyVal(v) end
    end
    if type(c.color) ~= "table" then c.color = CopyVal(ns.CURSORHIGHLIGHT_DEFAULTS.color) end
    if not SHAPES[c.shape] then c.shape = "circle" end
    return c
end
ns.CursorHighlight_Cfg = Ensure

-- runtime ---------------------------------------------------------------------
local frame, tex, mask, line

local function Build()
    if frame then return end
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("TOOLTIP"); frame:SetFrameLevel(70)   -- under the gradient trail (level 80)
    frame:SetAllPoints(UIParent)
    frame:EnableMouse(false)
    tex = frame:CreateTexture(nil, "ARTWORK")
    tex:Hide()
    if frame.CreateMaskTexture then
        mask = frame:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(tex)
    end
    if frame.CreateLine then
        line = frame:CreateLine(nil, "ARTWORK")
        line:Hide()
    end
end

local masked = false
local function SetMasked(on)
    if not (tex and mask) then return end
    if on and not masked then pcall(tex.AddMaskTexture, tex, mask); masked = true
    elseif not on and masked then pcall(tex.RemoveMaskTexture, tex, mask); masked = false end
end

local function OnUpdate()
    local c = CueRulesDB and CueRulesDB.cursorHighlight
    if not c then return end
    local hide = (c.hideMouselook and IsMouselooking and IsMouselooking())
        or (c.combatOnly and not (UnitAffectingCombat and UnitAffectingCombat("player")))
    if hide then tex:Hide(); if line then line:Hide() end; return end
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    x, y = x / s, y / s
    local col = c.color or { 1, 1, 1 }
    local size, op = c.size or 56, c.opacity or 0.35
    if c.shape == "diamond" and line then
        tex:Hide()
        local d = size * 0.5 * 0.70710678
        line:SetStartPoint("BOTTOMLEFT", UIParent, x - d, y - d)
        line:SetEndPoint("BOTTOMLEFT", UIParent, x + d, y + d)
        line:SetThickness(size)
        line:SetColorTexture(col[1], col[2], col[3], op)
        line:Show()
    else
        if line then line:Hide() end
        tex:SetVertexColor(col[1], col[2], col[3], op)
        tex:SetSize(size, size)
        tex:ClearAllPoints()
        tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        tex:Show()
    end
end

function ns.CursorHighlight_Apply()
    local c = Ensure()
    if not c then return end
    if not c.enabled then
        if frame then frame:SetScript("OnUpdate", nil); tex:Hide(); if line then line:Hide() end; frame:Hide() end
        return
    end
    Build()
    local sh = SHAPES[c.shape] or SHAPES.circle
    tex:SetTexture(sh[2])
    tex:SetBlendMode(sh[3])
    if line then line:SetBlendMode(sh[3]) end
    SetMasked(c.shape == "circle")
    frame:Show()
    frame:SetScript("OnUpdate", OnUpdate)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() ns.CursorHighlight_Apply() end)

-- options: the "Cursor Highlight" tab --------------------------------------------
function ns.BuildCursorHighlightTab(Notify)
    local function C() return Ensure() or ns.CURSORHIGHLIGHT_DEFAULTS end
    local function Changed() ns.CursorHighlight_Apply(); if Notify then Notify() end end
    local function isOff() return not C().enabled end
    local shapeValues = {}
    for _, k in ipairs(SHAPE_ORDER) do shapeValues[k] = SHAPES[k][1] end
    return {
        type = "group", name = "Cursor Highlight", order = 1,
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "A colored shape that follows your mouse cursor so you can find it at a glance. Off by default." },
            enabled = { type = "toggle", order = 1, width = "full", name = "Cursor highlight",
                desc = "Turns the highlight on. While it is off nothing is drawn or polled.",
                get = function() return C().enabled and true or false end,
                set = function(_, v) C().enabled = v and true or false; Changed() end },
            settings = {
                type = "group", name = "Highlight", order = 2, inline = true, hidden = isOff,
                args = {
                    shape = { type = "select", order = 1, name = "Shape", values = shapeValues, sorting = SHAPE_ORDER,
                        get = function() return C().shape end,
                        set = function(_, v) C().shape = v; Changed() end },
                    color = { type = "color", order = 2, name = "Color", hasAlpha = false,
                        get = function() local col = C().color; return col[1], col[2], col[3] end,
                        set = function(_, r, g, b) C().color = { r, g, b }; Changed() end },
                    size = { type = "range", order = 3, name = "Size", min = 16, max = 160, step = 1,
                        get = function() return C().size end,
                        set = function(_, v) C().size = v; Changed() end },
                    opacity = { type = "range", order = 4, name = "Opacity", min = 0.05, max = 1, step = 0.05, isPercent = true,
                        get = function() return C().opacity end,
                        set = function(_, v) C().opacity = v; Changed() end },
                    combatOnly = { type = "toggle", order = 5, width = "double", name = "Only show in combat",
                        get = function() return C().combatOnly and true or false end,
                        set = function(_, v) C().combatOnly = v and true or false; Changed() end },
                    hideMouselook = { type = "toggle", order = 6, width = "double", name = "Hide while turning the camera (mouselook)",
                        get = function() return C().hideMouselook and true or false end,
                        set = function(_, v) C().hideMouselook = v and true or false; Changed() end },
                },
            },
        },
    }
end
