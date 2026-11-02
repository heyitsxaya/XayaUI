-------------------------------------------------------------------------------
-- CursorHighlight.lua : a colored shape (circle, square, diamond, star) that sits under the mouse cursor.
-- Left tab of QoL UI Updates > Cursor. OFF by default; while off nothing is created, polled, or drawn.
-- Saved settings: CueRulesDB.cursorHighlight. Not run in game when written (2026-11-01): the look needs an in-game check.
--
-- Shapes: circle = a square texture cut with a circular mask; diamond = a Line region as thick as it is long, drawn at 45 degrees
-- (SetRotation only turns the image inside a texture, so it cannot turn a solid square into a diamond); square and star are plain textures.
-- Style "Outline" (circle, square, diamond): only the perimeter, drawn as Line regions with an adjustable thickness (a circle is a 64-sided
-- polygon). Every line hangs off one small anchor frame that follows the cursor, so moving the cursor costs a single SetPoint.
-- Shape "Game cursor art": a Blizzard cursor picture (or a path you type) drawn at the cursor. WoW does not let an addon hide the real pointer,
-- so this is drawn IN ADDITION to it. (SetCursor can swap the real pointer, but warcraft.wiki.gg states it has no effect over the 3D world.)
-------------------------------------------------------------------------------
local addonName, ns = ...

-- Circle: our own anti-aliased circle / ring pictures (Media\\Cursor\\CircleHD.tga and HLRing_01..20.tga). A square cut with a mask, or a ring built
-- from straight Line pieces, shows jagged edges and corners; the pictures are smooth. The 20 rings go from a hairline to a full disc; the one whose
-- thickness (as a share of the circle's width) is nearest to the chosen outline thickness is used. Ring k has thickness 0.006 * (0.5/0.006)^((k-1)/19).
local MEDIA = "Interface\\AddOns\\XayaUI\\Media\\Cursor\\"
local RING_N, RING_MIN, RING_MAX = 20, 0.006, 0.5
local function RingPath(size, t)
    local ratio = math.max(RING_MIN, math.min(RING_MAX, t / math.max(1, size)))
    local k = math.floor(math.log(ratio / RING_MIN) / math.log(RING_MAX / RING_MIN) * (RING_N - 1) + 0.5) + 1
    return ("%sHLRing_%02d.tga"):format(MEDIA, math.max(1, math.min(RING_N, k)))
end

local SHAPES = {
    circle  = { "Circle",  MEDIA .. "CircleHD.tga",         "BLEND" },
    square  = { "Square",  "Interface\\Buttons\\WHITE8X8",  "BLEND" },
    diamond = { "Diamond", "Interface\\Buttons\\WHITE8X8",  "BLEND" },
    star    = { "Star",    "Interface\\Cooldown\\star4",    "ADD"   },
    art     = { "Game cursor art", "Interface\\Cursor\\Point", "BLEND" },
}
local SHAPE_ORDER = { "circle", "square", "diamond", "star", "art" }
-- Any game texture: a path (Interface\\Icons\\Spell_Nature_Lightning), a numeric file ID (136048), or an atlas name. Blizzard ships these inside the
-- game client, so nothing has to be added to XayaUI. A wrong path shows a green square (the game's "missing texture").
local function SetGameTex(t, path)
    if type(path) == "string" then
        local n = tonumber(path); if n then path = n end
    end
    if type(path) == "string" and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(path) then
        t:SetAtlas(path, false)
    else
        t:SetTexture(path)
    end
end

local OUTLINE_OK = { circle = true, square = true, diamond = true }
-- Pictures from the game's own Interface\\Cursor folder. Taxi is the path warcraft.wiki.gg uses in its SetCursor example; Point is the
-- one CursorTrail already uses. NEITHER HAS BEEN CHECKED IN GAME as a texture: a green square means the path is wrong. Anything else: type a path.
local ART = {
    point = { "Hand (Interface\\Cursor\\Point)", "Interface\\Cursor\\Point" },
    taxi  = { "Taxi (Interface\\Cursor\\Taxi)",  "Interface\\Cursor\\Taxi"  },
    custom = { "My own path (type it below)", nil },
}
local ART_ORDER = { "point", "taxi", "custom" }

ns.CURSORHIGHLIGHT_DEFAULTS = {
    enabled = false,
    shape = "circle",
    size = 56,
    color = { 1.00, 0.82, 0.10 },
    opacity = 0.35,
    combatOnly = false,
    hideMouselook = true,
    style = "fill",        -- fill | outline
    thickness = 3,         -- outline line thickness in pixels
    art = "point",
    artPath = "",
    keepColors = false,    -- game cursor art: keep the picture's own colors instead of tinting it
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
    if c.style ~= "outline" then c.style = "fill" end
    c.thickness = math.max(1, math.min(12, tonumber(c.thickness) or 3))
    if not ART[c.art] then c.art = "point" end
    if type(c.artPath) ~= "string" then c.artPath = "" end
    return c
end
ns.CursorHighlight_Cfg = Ensure

-- runtime ---------------------------------------------------------------------
local frame, anchor, tex, mask, line
local ringLines = {}
local MAX_LINES = 64

local function Build()
    if frame then return end
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("TOOLTIP"); frame:SetFrameLevel(70)   -- under the gradient trail (level 80)
    frame:SetAllPoints(UIParent)
    frame:EnableMouse(false)
    anchor = CreateFrame("Frame", nil, frame)
    anchor:SetSize(1, 1)
    anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0, 0)
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

local function HideRing()
    for _, l in ipairs(ringLines) do l:Hide() end
end
-- one outline segment from (x1,y1) to (x2,y2), measured from the cursor
local function Segment(i, x1, y1, x2, y2, t, col)
    if i > MAX_LINES or not frame.CreateLine then return end
    local l = ringLines[i]
    if not l then l = frame:CreateLine(nil, "ARTWORK"); ringLines[i] = l end
    -- run each side half a thickness past its corners so neighbouring sides overlap into a square corner (no notch)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        local e = t * 0.5 / len
        x1, y1, x2, y2 = x1 - dx * e, y1 - dy * e, x2 + dx * e, y2 + dy * e
    end
    l:SetStartPoint("CENTER", anchor, x1, y1)
    l:SetEndPoint("CENTER", anchor, x2, y2)
    l:SetThickness(t)
    l:SetColorTexture(col[1], col[2], col[3], 1)
    l:Show()
end

-- lay out whatever the settings ask for; runs when a setting changes, never per frame
local function Layout(c)
    local col = c.color or { 1, 1, 1 }
    local size, op = c.size or 56, c.opacity or 0.35
    tex:Hide(); if line then line:Hide() end; HideRing()
    frame:SetAlpha(1)
    if c.style == "outline" and OUTLINE_OK[c.shape] and c.shape ~= "circle" then
        local r, t, n = size / 2, c.thickness or 3, 0
        if c.shape == "square" then
            local pts = { { -r, -r }, { r, -r }, { r, r }, { -r, r } }
            for k = 1, 4 do
                local p, q = pts[k], pts[k % 4 + 1]
                n = n + 1; Segment(n, p[1], p[2], q[1], q[2], t, col)
            end
        else   -- diamond: a square turned 45 degrees (corner to corner = size)
            local pts = { { 0, -r }, { r, 0 }, { 0, r }, { -r, 0 } }
            for k = 1, 4 do
                local p, q = pts[k], pts[k % 4 + 1]
                n = n + 1; Segment(n, p[1], p[2], q[1], q[2], t, col)
            end
        end
        frame.xuiOpacity = op   -- each line is drawn solid; the opacity setting is the whole frame's alpha
        frame:SetAlpha(op)
        return
    end
    frame.xuiOpacity = 1
    if c.shape == "diamond" and line then
        local d = size * 0.5 * 0.70710678
        line:SetStartPoint("CENTER", anchor, -d, -d)
        line:SetEndPoint("CENTER", anchor, d, d)
        line:SetThickness(size)
        line:SetColorTexture(col[1], col[2], col[3], op)
        line:Show()
        return
    end
    local sh = SHAPES[c.shape] or SHAPES.circle
    local path = sh[2]
    if c.shape == "art" then
        path = (c.art == "custom") and (c.artPath ~= "" and c.artPath or nil) or (ART[c.art] and ART[c.art][2])
    elseif c.shape == "circle" and c.style == "outline" then
        path = RingPath(size, c.thickness or 3)
    end
    SetGameTex(tex, path)
    tex:SetBlendMode(sh[3])
    SetMasked(false)
    if c.shape == "art" and c.keepColors then tex:SetVertexColor(1, 1, 1, op) else tex:SetVertexColor(col[1], col[2], col[3], op) end
    tex:SetSize(size, size)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    tex:Show()
end

local hiddenNow = false
local function OnUpdate()
    local c = CueRulesDB and CueRulesDB.cursorHighlight
    if not c then return end
    local hide = (c.hideMouselook and IsMouselooking and IsMouselooking())
        or (c.combatOnly and not (UnitAffectingCombat and UnitAffectingCombat("player")))
    hide = hide and true or false
    if hide ~= hiddenNow then
        hiddenNow = hide
        frame:SetAlpha(hide and 0 or (frame.xuiOpacity or 1))
    end
    if hide then return end
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
end

function ns.CursorHighlight_Apply()
    local c = Ensure()
    if not c then return end
    if not c.enabled then
        if frame then frame:SetScript("OnUpdate", nil); tex:Hide(); if line then line:Hide() end; HideRing(); frame:Hide() end
        return
    end
    Build()
    Layout(c)
    hiddenNow = false
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
                    style = { type = "select", order = 1.5, name = "Style", values = { fill = "Filled", outline = "Outline only (just the perimeter line)" }, sorting = { "fill", "outline" },
                        desc = "Outline draws only the edge of a circle, square or diamond, so you can see what is under the cursor.",
                        hidden = function() return not OUTLINE_OK[C().shape] end,
                        get = function() return C().style end,
                        set = function(_, v) C().style = v; Changed() end },
                    thickness = { type = "range", order = 1.6, name = "Outline thickness", min = 1, max = 12, step = 1,
                        hidden = function() return not (OUTLINE_OK[C().shape] and C().style == "outline") end,
                        get = function() return C().thickness end,
                        set = function(_, v) C().thickness = v; Changed() end },
                    art = { type = "select", order = 1.7, name = "Game cursor picture", values = function() local t = {}; for k, v in pairs(ART) do t[k] = v[1] end; return t end, sorting = ART_ORDER,
                        desc = "A picture from the game's own Interface\\Cursor folder, drawn at the cursor IN ADDITION to the real pointer (an addon cannot hide the real pointer). Not yet checked in game: a green square means the path is wrong.",
                        hidden = function() return C().shape ~= "art" end,
                        get = function() return C().art end,
                        set = function(_, v) C().art = v; Changed() end },
                    artPath = { type = "input", order = 1.8, name = "Picture path", width = "double",
                        desc = "Any game texture: a full in-game path (Interface\\Cursor\\Taxi, Interface\\Icons\\Spell_Nature_Lightning), a numeric file ID, or an atlas name. Files inside Interface\\AddOns work too (.blp, .tga or .png with power-of-two sides).",
                        hidden = function() return C().shape ~= "art" or C().art ~= "custom" end,
                        get = function() return C().artPath end,
                        set = function(_, v) C().artPath = tostring(v or ""):sub(1, 200); Changed() end },
                    keepColors = { type = "toggle", order = 1.9, width = "double", name = "Keep the picture's own colors (no tint)",
                        hidden = function() return C().shape ~= "art" end,
                        get = function() return C().keepColors and true or false end,
                        set = function(_, v) C().keepColors = v and true or false; Changed() end },
                    color = { type = "color", order = 2, name = "Color", hasAlpha = true,   -- the picker's transparency is the Opacity setting below
                        get = function() local col = C().color; return col[1], col[2], col[3], C().opacity or 0.35 end,
                        set = function(_, r, g, b, a) C().color = { r, g, b }; if a then C().opacity = math.max(0.05, math.floor(a * 20 + 0.5) / 20) end; Changed() end },
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
