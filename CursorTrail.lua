-------------------------------------------------------------------------------
-- CursorTrail.lua : the Gradient Cursor Trail tab (QoL UI Updates > Cursor). A gradient trail that follows the mouse cursor.
--
-- * OFF by default. While off nothing is created, polled or drawn.
-- * Pre-populated with gradient presets; "Custom" lets you build your own with 2 to 6 colors.
-- * Independent of the (currently switched-off) QoL Elements / Cursor Tracker files. Its saved
--   settings live in CueRulesDB.cursorTrail.
-- * Preset colors are Claude's choices, not taken from any other addon.
-- * Not run in game when written (2026-11-01): the texture paths and the look need an in-game check.
--
-- How it draws: a fixed pool of textures (no per-frame allocation). Each frame the cursor position
-- is read; points are dropped along the path it traveled. A dot's age picks its place on the
-- gradient (head = first color, tail = last color) and fades it out.
-------------------------------------------------------------------------------
local addonName, ns = ...

local MAXC = 6          -- most colors a gradient can have
local NPT  = 48         -- texture pool size (most dots on screen at once)

ns.CURSORTRAIL_MAXC = MAXC

-- shape name -> label, texture, blend mode, kind   (Blizzard textures that ship with the game client)
-- kind: "tex" = the texture as is | "circle" = a square cut with a circular mask | "diamond" = a Line as thick as it is long, at 45 degrees
--       "line" = one Line from each dot back to the one dropped before it (a smooth ribbon).
-- The cursor arrow and hand use Blizzard's cursor art (Interface\\Cursor\\Point and Interact); those two paths are from memory and were not
-- checked in game, so if either shows as a green square the path is wrong.
local SHAPES = {
    star    = { "Spark",         "Interface\\Cooldown\\star4",      "ADD",   "tex"     },
    square  = { "Square",        "Interface\\Buttons\\WHITE8X8",    "BLEND", "tex"     },
    circle  = { "Circle",        "Interface\\Buttons\\WHITE8X8",    "BLEND", "circle"  },
    diamond = { "Diamond",       "Interface\\Buttons\\WHITE8X8",    "BLEND", "diamond" },
    line    = { "Smooth line",   "Interface\\Buttons\\WHITE8X8",    "BLEND", "line"    },
    arrow   = { "Cursor arrow",  "Interface\\Cursor\\Point",        "BLEND", "tex"     },
    hand    = { "Hand",          "Interface\\Cursor\\Interact",     "BLEND", "tex"     },
}
local SHAPE_ORDER = { "star", "circle", "square", "diamond", "line", "arrow", "hand" }

-- Pre-configured gradients (head of the trail first). 3 to 6 colors each.
local PRESETS = {
    fel      = { "Fel",        { {0.35,1.00,0.25}, {0.15,0.80,0.45}, {0.55,0.20,0.85} } },
    fire     = { "Fire",       { {1.00,0.95,0.40}, {1.00,0.55,0.10}, {0.85,0.15,0.05}, {0.25,0.05,0.05} } },
    ocean    = { "Ocean",      { {0.70,1.00,1.00}, {0.15,0.75,0.95}, {0.10,0.35,0.85}, {0.05,0.10,0.45} } },
    aurora   = { "Aurora",     { {0.30,1.00,0.60}, {0.20,0.85,0.95}, {0.45,0.45,1.00}, {0.75,0.30,0.95} } },
    sunset   = { "Sunset",     { {1.00,0.90,0.45}, {1.00,0.55,0.30}, {0.95,0.30,0.50}, {0.55,0.25,0.75}, {0.20,0.15,0.50} } },
    vapor    = { "Vaporwave",  { {1.00,0.45,0.85}, {0.75,0.50,1.00}, {0.35,0.75,1.00}, {0.30,1.00,0.90} } },
    rainbow  = { "Rainbow",    { {1.00,0.20,0.20}, {1.00,0.70,0.10}, {0.95,1.00,0.20}, {0.25,0.90,0.35}, {0.25,0.55,1.00}, {0.65,0.30,0.95} } },
    gold     = { "Gold",       { {1.00,0.98,0.75}, {1.00,0.82,0.25}, {0.80,0.50,0.10} } },
    ice      = { "Frost",      { {1.00,1.00,1.00}, {0.65,0.90,1.00}, {0.30,0.55,1.00} } },
}
local PRESET_ORDER = { "fel", "fire", "ocean", "aurora", "sunset", "vapor", "rainbow", "gold", "ice" }
ns.CURSORTRAIL_PRESETS, ns.CURSORTRAIL_PRESET_ORDER = PRESETS, PRESET_ORDER

ns.CURSORTRAIL_DEFAULTS = {
    enabled = false,                       -- OFF until Xaya turns it on
    preset = "fel",                        -- a preset key, or "custom"
    customN = 3,                           -- how many of the custom colors are used (2 to 6)
    custom = { {1.00,0.30,0.30}, {1.00,0.85,0.20}, {0.30,0.50,1.00}, {0.30,1.00,0.50}, {0.85,0.40,1.00}, {1.00,1.00,1.00} },
    length = 0.6,                          -- seconds a dot lives (trail length)
    size = 18,                             -- dot size in px
    opacity = 1,
    shape = "star",
    reverse = false,                       -- tail takes the first color instead of the head
    hideMouselook = true,                  -- no trail while the camera is being turned with the mouse
}

local function CopyVal(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyVal(x) end
    return t
end

-- the saved table, with any missing keys filled from the defaults
local function Ensure()
    if not CueRulesDB then return nil end
    local c = CueRulesDB.cursorTrail
    if type(c) ~= "table" then c = {}; CueRulesDB.cursorTrail = c end
    for k, v in pairs(ns.CURSORTRAIL_DEFAULTS) do
        if c[k] == nil then c[k] = CopyVal(v) end
    end
    return c
end
ns.CursorTrail_Cfg = Ensure

-- the colors in use right now (list of {r,g,b})
local function Stops(c)
    if c.preset == "custom" then
        local n = math.max(2, math.min(MAXC, c.customN or 3))
        local t = {}
        for i = 1, n do t[i] = c.custom[i] or { 1, 1, 1 } end
        return t
    end
    local p = PRESETS[c.preset] or PRESETS[PRESET_ORDER[1]]
    return p[2]
end

-- color at position t (0 = first color, 1 = last color) along a list of stops
local function Grad(stops, t)
    local n = #stops
    if n == 1 then local s = stops[1]; return s[1], s[2], s[3] end
    if t <= 0 then local s = stops[1]; return s[1], s[2], s[3] end
    if t >= 1 then local s = stops[n]; return s[1], s[2], s[3] end
    local pos = t * (n - 1)
    local i = math.floor(pos)
    local f = pos - i
    local a, b = stops[i + 1], stops[i + 2]
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

-- runtime -------------------------------------------------------------------
local frame, dots
local stops
local lastX, lastY
local lastDropX, lastDropY   -- the dot dropped most recently (the "line" shape joins each dot to the one before it)
local activeN = 0

local function Build()
    if frame then return end
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("TOOLTIP"); frame:SetFrameLevel(80)
    frame:SetAllPoints(UIParent)
    frame:EnableMouse(false)
    dots = {}
    for i = 1, NPT do
        local t = frame:CreateTexture(nil, "ARTWORK")
        t:Hide()
        local m
        if frame.CreateMaskTexture then
            m = frame:CreateMaskTexture()
            m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m:SetAllPoints(t)
        end
        local ln
        if frame.CreateLine then ln = frame:CreateLine(nil, "ARTWORK"); ln:Hide() end
        dots[i] = { tex = t, mask = m, line = ln, masked = false, on = false, born = 0, x = 0, y = 0 }
    end
end

local function ClearAll()
    if not dots then return end
    for i = 1, NPT do local d = dots[i]; d.on = false; d.tex:Hide(); if d.line then d.line:Hide() end end
    activeN, lastX, lastY, lastDropX, lastDropY = 0, nil, nil, nil, nil
end

local function Drop(c, x, y)
    for i = 1, NPT do
        local d = dots[i]
        if not d.on then
            d.on = true; d.born = GetTime(); d.x, d.y = x, y
            d.px, d.py = lastDropX, lastDropY
            lastDropX, lastDropY = x, y
            activeN = activeN + 1
            return
        end
    end
end

local function OnUpdate()
    local c = CueRulesDB and CueRulesDB.cursorTrail
    if not c or not stops then return end
    local now = GetTime()
    local life = math.max(0.1, c.length or 0.6)
    local size, op = c.size or 18, c.opacity or 1
    local sh = SHAPES[c.shape] or SHAPES.star
    local blend, kind = sh[3], sh[4]

    -- add dots along the path the cursor traveled since the last frame
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    x, y = x / s, y / s
    local hidden = c.hideMouselook and IsMouselooking and IsMouselooking()
    if hidden then
        lastX, lastY, lastDropX, lastDropY = nil, nil, nil, nil
    else
        if lastX then
            local dx, dy = x - lastX, y - lastY
            local dist = math.sqrt(dx * dx + dy * dy)
            local step = math.max(2, size * 0.35)
            if dist >= step then
                local n = math.min(8, math.floor(dist / step))
                for k = 1, n do
                    local f = k / n
                    Drop(c, lastX + dx * f, lastY + dy * f)
                end
                lastX, lastY = x, y
            end
        else
            lastX, lastY = x, y
        end
    end

    -- age, color, fade and place every live dot
    local rev = c.reverse
    for i = 1, NPT do
        local d = dots[i]
        if d.on then
            local f = (now - d.born) / life
            if f >= 1 then
                d.on = false; activeN = activeN - 1; d.tex:Hide(); if d.line then d.line:Hide() end
            else
                local r, g, b = Grad(stops, rev and (1 - f) or f)
                local a = op * (1 - f)
                local sz = size * (1 - 0.45 * f)
                local ln = d.line
                if kind == "diamond" and ln then
                    d.tex:Hide()
                    local h = sz * 0.5 * 0.70710678
                    ln:SetStartPoint("BOTTOMLEFT", UIParent, d.x - h, d.y - h)
                    ln:SetEndPoint("BOTTOMLEFT", UIParent, d.x + h, d.y + h)
                    ln:SetThickness(sz)
                    ln:SetColorTexture(r, g, b, a)
                    ln:SetBlendMode(blend)
                    ln:Show()
                elseif kind == "line" and ln then
                    d.tex:Hide()
                    if d.px then
                        ln:SetStartPoint("BOTTOMLEFT", UIParent, d.px, d.py)
                        ln:SetEndPoint("BOTTOMLEFT", UIParent, d.x, d.y)
                        ln:SetThickness(math.max(2, sz * 0.5))
                        ln:SetColorTexture(r, g, b, a)
                        ln:SetBlendMode(blend)
                        ln:Show()
                    else ln:Hide() end
                else
                    if ln then ln:Hide() end
                    local t = d.tex
                    t:SetVertexColor(r, g, b, a)
                    t:SetBlendMode(blend)
                    t:SetSize(sz, sz)
                    t:ClearAllPoints()
                    t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", d.x, d.y)
                    t:Show()
                end
            end
        end
    end
end

-- (re)apply the saved settings. Called at login and after every change on the Cursor tab.
function ns.CursorTrail_Apply()
    local c = Ensure()
    if not c then return end
    if not c.enabled then
        if frame then frame:SetScript("OnUpdate", nil); ClearAll(); frame:Hide() end
        return
    end
    Build()
    stops = Stops(c)
    local sh = SHAPES[c.shape] or SHAPES.star
    for i = 1, NPT do
        local d = dots[i]
        d.tex:SetTexture(sh[2])
        local want = (sh[4] == "circle") and d.mask ~= nil
        if want and not d.masked then pcall(d.tex.AddMaskTexture, d.tex, d.mask); d.masked = true
        elseif not want and d.masked then pcall(d.tex.RemoveMaskTexture, d.tex, d.mask); d.masked = false end
        d.on = false; d.tex:Hide(); if d.line then d.line:Hide() end
    end
    lastDropX, lastDropY = nil, nil
    frame:Show()
    frame:SetScript("OnUpdate", OnUpdate)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() ns.CursorTrail_Apply() end)

-- options: the "Cursor" tab ----------------------------------------------------
-- A text strip showing the gradient (colored 1-px-wide texture escapes), so the colors can be judged without leaving the window.
local function Preview(c)
    local st = Stops(c)
    local parts = {}
    for i = 0, 23 do
        local r, g, b = Grad(st, i / 23)
        parts[#parts + 1] = ("|TInterface\\Buttons\\WHITE8X8:16:9:0:0:8:8:0:8:0:8:%d:%d:%d|t"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
    end
    return table.concat(parts)
end

function ns.BuildCursorTab(Notify)
    local function C() return Ensure() or ns.CURSORTRAIL_DEFAULTS end
    local function Changed() ns.CursorTrail_Apply(); if Notify then Notify() end end

    local presetValues, presetSorting = {}, {}
    for i, k in ipairs(PRESET_ORDER) do presetValues[k] = PRESETS[k][1]; presetSorting[i] = k end
    presetValues.custom = "Custom (build your own)"; presetSorting[#presetSorting + 1] = "custom"
    local shapeValues, shapeSorting = {}, {}
    for i, k in ipairs(SHAPE_ORDER) do shapeValues[k] = SHAPES[k][1]; shapeSorting[i] = k end

    local function isCustom() return C().preset == "custom" end
    local function isOff() return not C().enabled end

    local custom = {
        type = "group", name = "Custom gradient", order = 5, inline = true,
        hidden = function() return isOff() or not isCustom() end,
        args = {
            n = { type = "range", order = 1, name = "Number of colors", min = 2, max = MAXC, step = 1, width = "double",
                get = function() return C().customN end,
                set = function(_, v) C().customN = v; Changed() end },
            copyFrom = { type = "select", order = 2, name = "Copy a preset into Custom", width = "double",
                desc = "Replaces your custom colors with the chosen preset's colors (and the matching color count). Your custom colors are overwritten.",
                values = function() local t = {}; for _, k in ipairs(PRESET_ORDER) do t[k] = PRESETS[k][1] end; return t end,
                sorting = PRESET_ORDER,
                get = function() return nil end,
                set = function(_, k)
                    local p = PRESETS[k]; if not p then return end
                    local c = C()
                    for i, col in ipairs(p[2]) do c.custom[i] = { col[1], col[2], col[3] } end
                    c.customN = #p[2]
                    Changed()
                end },
        },
    }
    for i = 1, MAXC do
        custom.args["c" .. i] = { type = "color", order = 10 + i, width = "half", name = "Color " .. i,
            desc = i == 1 and "Head of the trail (next to the cursor)." or (i == MAXC and "Tail of the trail." or nil),
            hasAlpha = false,
            hidden = function() return i > (C().customN or 3) end,
            get = function() local col = C().custom[i] or { 1, 1, 1 }; return col[1], col[2], col[3] end,
            set = function(_, r, g, b) C().custom[i] = { r, g, b }; Changed() end }
    end

    return {
        type = "group", name = "Gradient Cursor Trail", order = 2,
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "A gradient trail that follows your mouse cursor. Off by default." },
            enabled = { type = "toggle", order = 1, width = "full", name = "Gradient cursor trail",
                desc = "Turns the trail on. While it is off nothing is drawn or polled.",
                get = function() return C().enabled and true or false end,
                set = function(_, v) C().enabled = v and true or false; Changed() end },
            settings = {
                type = "group", name = "Trail", order = 2, inline = true, hidden = isOff,
                args = {
                    preset = { type = "select", order = 1, width = "double", name = "Gradient",
                        desc = "A ready-made gradient, or Custom to choose your own colors (2 to 6).",
                        values = presetValues, sorting = presetSorting,
                        get = function() return C().preset end,
                        set = function(_, v) C().preset = v; Changed() end },
                    preview = { type = "description", order = 2, width = "full", fontSize = "medium",
                        name = function() return Preview(C()) end },
                    shape = { type = "select", order = 3, name = "Dot shape", values = shapeValues, sorting = shapeSorting,
                        get = function() return C().shape end,
                        set = function(_, v) C().shape = v; Changed() end },
                    reverse = { type = "toggle", order = 4, name = "Reverse colors",
                        desc = "Swaps the ends: the first color ends up at the tail of the trail instead of next to the cursor.",
                        get = function() return C().reverse and true or false end,
                        set = function(_, v) C().reverse = v and true or false; Changed() end },
                    length = { type = "range", order = 5, name = "Trail length (seconds)", min = 0.2, max = 1.5, step = 0.05,
                        get = function() return C().length end,
                        set = function(_, v) C().length = v; Changed() end },
                    size = { type = "range", order = 6, name = "Dot size", min = 6, max = 48, step = 1,
                        get = function() return C().size end,
                        set = function(_, v) C().size = v; Changed() end },
                    opacity = { type = "range", order = 7, name = "Opacity", min = 0.1, max = 1, step = 0.05, isPercent = true,
                        get = function() return C().opacity end,
                        set = function(_, v) C().opacity = v; Changed() end },
                    hideMouselook = { type = "toggle", order = 8, width = "double", name = "Hide while turning the camera (mouselook)",
                        get = function() return C().hideMouselook and true or false end,
                        set = function(_, v) C().hideMouselook = v and true or false; Changed() end },
                },
            },
            custom = custom,
        },
    }
end

-- The whole Cursor page (left tree entry of QoL UI Updates): Cursor Highlight is the first tab, Gradient Cursor Trail the second.
function ns.BuildCursorGroup(Notify)
    local hl = ns.BuildCursorHighlightTab and ns.BuildCursorHighlightTab(Notify) or nil
    local tr = ns.BuildCursorTab(Notify)
    return { type = "group", name = "Cursor", order = 2, childGroups = "tab", args = { highlight = hl, trail = tr } }
end
