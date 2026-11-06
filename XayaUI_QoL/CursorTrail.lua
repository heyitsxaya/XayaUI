-------------------------------------------------------------------------------
-- CursorTrail.lua : the Gradient Cursor Trail tab (QoL > Cursor, XayaUI QoL). A gradient trail that follows the mouse cursor.
--
-- * OFF by default. While off nothing is created, polled or drawn.
-- * Pre-populated with gradient presets; "Custom" lets you build your own with 2 to 6 colors; "Match the UI theme" (QoL 0.7.17)
--   takes the colors of the UI theme and follows it when the theme changes.
-- * Independent of the (currently switched-off) QoL Elements / Cursor Tracker files. Its saved
--   settings live in CueRulesDB.cursorTrail.
-- * Preset colors are Claude's choices, not taken from any other addon. Since QoL 0.7.17 they live in core (XayaUI/Theme.lua,
--   ns.Theme.CURSOR_PRESETS), where the UI themes made from them read the same table.
-- * Not run in game when written (2026-11-01): the texture paths and the look need an in-game check.
--
-- How it draws: a fixed pool of textures (no per-frame allocation). Each frame the cursor position
-- is read; points are dropped along the path it traveled. A dot's age picks its place on the
-- gradient (head = first color, tail = last color) and fades it out.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)

local MAXC = 6          -- most colors a gradient can have
local NPT  = 48         -- most dots on screen at once (all shapes except the smooth line)
local NRIB = 400        -- most dots for the smooth line (it lays them close together); dots are created as needed, oldest reused when full

ns.CURSORTRAIL_MAXC = MAXC

-- shape name -> label, texture, blend mode, kind   (Blizzard textures that ship with the game client)
-- kind: "tex" = the texture as is | "circle" = a square cut with a circular mask | "diamond" = a Line as thick as it is long, at 45 degrees
--       "ribbon" = a dense chain of soft round dots laid along a curve through the cursor path, with a round head at the cursor (a smooth, rounded ribbon).
-- Hand = Blizzard's gauntlet pointer (Interface\\Cursor\\Point; the old "Interact" path is the gear icon).
-- Cursor arrow = our own Media\\Cursor\\Arrow.tga (Blizzard ships no plain arrow texture).
local MEDIA = "Interface\\AddOns\\XayaUI_QoL\\Media\\Cursor\\"   -- this addon's own folder (0.6.0)
local SHAPES = {
    star    = { "Spark",         "Interface\\Cooldown\\star4",      "ADD",   "tex"     },
    square  = { "Square",        "Interface\\Buttons\\WHITE8X8",    "BLEND", "tex"     },
    circle  = { "Circle",        MEDIA .. "CircleHD.tga",           "BLEND", "tex"     },
    diamond = { "Diamond",       "Interface\\Buttons\\WHITE8X8",    "BLEND", "diamond" },
    line    = { "Smooth line",   MEDIA .. "Fill_circle.tga",        "BLEND", "ribbon"  },
    arrow   = { "Cursor arrow",  MEDIA .. "Arrow.tga",              "BLEND", "tex"     },
    hand    = { "Hand",          "Interface\\Cursor\\Point",        "BLEND", "tex"     },
    game    = { "Game texture (path, file ID or atlas)", "Interface\\Cursor\\Point", "BLEND", "tex" },   -- Blizzard assets: the path is typed under the shape
}
local SHAPE_ORDER = { "star", "circle", "square", "diamond", "line", "arrow", "hand", "game" }
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


-- Pre-configured gradients (head of the trail first). 3 to 6 colors each. Core's table (XayaUI/Theme.lua), read, never copied
-- (QoL 0.7.17): the UI themes "Cursor trail: <name>" are made from the same colors. Saved preset keys are unchanged.
local TH = ns.Theme
local PRESETS = (TH and TH.CURSOR_PRESETS) or {}
local PRESET_ORDER = (TH and TH.CURSOR_PRESET_ORDER) or {}
ns.CURSORTRAIL_PRESETS, ns.CURSORTRAIL_PRESET_ORDER = PRESETS, PRESET_ORDER

ns.CURSORTRAIL_DEFAULTS = {
    enabled = false,                       -- OFF until Xaya turns it on
    preset = "fel",                        -- a preset key, "theme" (Match the UI theme, QoL 0.7.17), or "custom"
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
    -- Match the UI theme: core decides the colors (Theme.TrailStops: a theme made from a gradient gives exactly that gradient,
    -- any other theme its accentText -> accent -> gradStart)
    if c.preset == "theme" and TH and TH.TrailStops then return TH.TrailStops() end
    local p = PRESETS[c.preset] or PRESETS[PRESET_ORDER[1]]
    if not p then return { { 1, 1, 1 } } end   -- core without the preset table (an older XayaUI folder): plain white, never an error
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
local frame, dots, cap
local stops
local lastX, lastY
local midX, midY             -- smooth line: the midpoint the last curve piece ended on
local lastDropX, lastDropY   -- the dot dropped most recently
local ringN, nDots = 0, 0    -- dots are reused in ring order, so the next slot is always the oldest
local capT = 0               -- smooth line: when the cursor last moved (the round head fades from then)
local curSh = SHAPES.star
local curPath = SHAPES.star[2]   -- the texture of the current shape (the typed path for "game")

-- put one dot's texture into the state the current shape needs
local function ConfigDot(d)
    SetGameTex(d.tex, curPath)
    d.tex:SetBlendMode(curSh[3])   -- the shape's blend mode, set here once per shape change instead of on every dot laid (QoL 0.7.13)
    local want = (curSh[4] == "circle") and d.mask ~= nil
    if want and not d.masked then pcall(d.tex.AddMaskTexture, d.tex, d.mask); d.masked = true
    elseif not want and d.masked then pcall(d.tex.RemoveMaskTexture, d.tex, d.mask); d.masked = false end
end

local function NewDot(i)
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
    local d = { tex = t, mask = m, line = ln, masked = false, on = false, born = 0, x = 0, y = 0, shown = false, lineShown = false }
    dots[i] = d
    nDots = i
    ConfigDot(d)
    return d
end

-- A dot's shown state and size are kept here, so the per-frame loop never asks the game (IsShown) and never re-hides a line the shape
-- does not use. Every hide goes through Off, so the flags cannot drift from what is on screen. (QoL 0.7.13: with Xaya's smooth line
-- the loop made about 1,600 texture calls a frame at speed, four per live dot; tests/cursor_trail_cost_run.py measures it.)
local function Off(d)
    d.on = false
    if d.shown then d.tex:Hide(); d.shown = false end
    if d.line and d.lineShown then d.line:Hide(); d.lineShown = false end
    d.sz = nil
end

local function Build()
    if frame then return end
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("TOOLTIP"); frame:SetFrameLevel(80)
    frame:SetAllPoints(UIParent)
    frame:EnableMouse(false)
    dots = {}
    cap = frame:CreateTexture(nil, "ARTWORK", nil, 1)   -- the round head of the smooth line
    cap:Hide()
end

local function ClearAll()
    if not dots then return end
    for i = 1, nDots do Off(dots[i]) end
    if cap then cap:Hide() end
    ringN, lastX, lastY, lastDropX, lastDropY, midX, midY = 0, nil, nil, nil, nil, nil, nil
    capT = 0
end

-- A dot never moves after it is dropped: it is anchored (and given its blend mode) once here, not on every rendered frame.
local function Drop(x, y, limit, blend)
    ringN = ringN % limit + 1
    local d = dots[ringN] or NewDot(ringN)
    d.on = true; d.born = GetTime(); d.x, d.y = x, y
    local t = d.tex
    t:ClearAllPoints()
    t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    d.placed = true
    d.px, d.py = lastDropX, lastDropY
    lastDropX, lastDropY = x, y
end

local function OnUpdate()
    local c = CueRulesDB and CueRulesDB.cursorTrail
    if not c or not stops then return end
    local now = GetTime()
    local life = math.max(0.1, c.length or 0.6)
    local size, op = c.size or 18, c.opacity or 1
    local sh = SHAPES[c.shape] or SHAPES.star
    local blend, kind = sh[3], sh[4]
    local ribbon = (kind == "ribbon")
    local limit = ribbon and NRIB or NPT
    -- how far apart the dots are laid. The ribbon lays them close (a quarter of their width, so about four overlap at any point and
    -- they merge into one smooth band; the alpha below is shared out by that overlap). It was 0.15 of the width (about seven overlapping):
    -- the same look at roughly 60% of the dots (QoL 0.7.13).
    local step = ribbon and math.max(1.5, size * 0.25) or math.max(2, size * 0.35)

    -- add dots along the path the cursor traveled since the last frame
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    x, y = x / s, y / s
    local hidden = c.hideMouselook and IsMouselooking and IsMouselooking()
    if hidden then
        lastX, lastY, lastDropX, lastDropY, midX, midY = nil, nil, nil, nil, nil, nil
        capT = 0
    else
        if lastX then
            local dx, dy = x - lastX, y - lastY
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist >= step then
                capT = now
                if ribbon then
                    -- A quadratic curve from the last midpoint, bent toward the previous sample, to the midpoint of the previous and new
                    -- sample. Joining pieces this way keeps the direction continuous, so corners between frames are rounded off.
                    local m0x, m0y = midX or lastX, midY or lastY
                    local m1x, m1y = (lastX + x) * 0.5, (lastY + y) * 0.5
                    local len = math.sqrt((lastX - m0x) ^ 2 + (lastY - m0y) ^ 2) + math.sqrt((m1x - lastX) ^ 2 + (m1y - lastY) ^ 2)
                    local n = math.max(1, math.min(80, math.ceil(len / step)))
                    for k = 1, n do
                        local t = k / n
                        local u = 1 - t
                        Drop(u * u * m0x + 2 * u * t * lastX + t * t * m1x, u * u * m0y + 2 * u * t * lastY + t * t * m1y, limit, blend)
                    end
                    midX, midY = m1x, m1y
                else
                    local n = math.min(8, math.floor(dist / step))
                    for k = 1, n do
                        local f = k / n
                        Drop(lastX + dx * f, lastY + dy * f, limit, blend)
                    end
                end
                lastX, lastY = x, y
            end
        else
            lastX, lastY = x, y
        end
    end

    -- age, color, fade and place every live dot
    local rev = c.reverse
    for i = 1, nDots do
        local d = dots[i]
        if d.on then
            local f = (now - d.born) / life
            if f >= 1 then
                Off(d)
            else
                local r, g, b = Grad(stops, rev and (1 - f) or f)
                local a = op * (1 - f)
                local sz = size * (1 - 0.45 * f)
                local ln = d.line
                if kind == "diamond" and ln then
                    if d.shown then d.tex:Hide(); d.shown = false end
                    local h = sz * 0.5 * 0.70710678
                    ln:SetStartPoint("BOTTOMLEFT", UIParent, d.x - h, d.y - h)
                    ln:SetEndPoint("BOTTOMLEFT", UIParent, d.x + h, d.y + h)
                    ln:SetThickness(sz)
                    ln:SetColorTexture(r, g, b, a)
                    ln:SetBlendMode(blend)
                    if not d.lineShown then ln:Show(); d.lineShown = true end
                else
                    if ln and d.lineShown then ln:Hide(); d.lineShown = false end
                    if ribbon then
                        -- about sz/step dots overlap at any point of the band; give each a share of the alpha so they add up to the intended opacity
                        a = 1 - (1 - a) ^ (1 / math.max(1, sz / step))
                    end
                    local t = d.tex
                    t:SetVertexColor(r, g, b, a)
                    local q = math.floor(sz * 2 + 0.5) / 2   -- half-pixel steps: the size is set only when it changes by that much
                    if d.sz ~= q then t:SetSize(q, q); d.sz = q end
                    if not d.placed then   -- (a dot placed by Drop keeps its anchor; this only covers one that was not)
                        t:SetBlendMode(blend)
                        t:ClearAllPoints()
                        t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", d.x, d.y)
                        d.placed = true
                    end
                    if not d.shown then t:Show(); d.shown = true end
                end
            end
        end
    end

    -- the smooth line's round head: a full dot at the cursor that fades from the moment the cursor stops
    if cap then
        local f = ribbon and not hidden and capT > 0 and (now - capT) / life or 1
        if f >= 1 then
            cap:Hide()
        else
            local r, g, b = Grad(stops, rev and (1 - f) or f)
            local sz = size * (1 - 0.45 * f)
            if cap.xuiPath ~= curPath then cap.xuiPath = curPath; SetGameTex(cap, curPath) end   -- (texture set only when it changes)
            cap:SetVertexColor(r, g, b, op * (1 - f))
            cap:SetBlendMode(blend)
            cap:SetSize(sz, sz)
            cap:ClearAllPoints()
            cap:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
            cap:Show()
        end
    end
end

-- Match the UI theme: the colors follow every theme change (core's Theme.OnResolve). The listener is in core's list only while the
-- trail is on AND set to Match the UI theme, and is taken out again otherwise (Theme.OffResolve), so with the trail off, or on with any
-- other gradient, a theme change does no trail work at all (rule V14).
local themeListening = false
local function OnThemeResolved()
    local c = CueRulesDB and CueRulesDB.cursorTrail
    if frame and c and c.enabled and c.preset == "theme" then stops = Stops(c) end
end
local function ListenTheme(on)
    on = on and true or false
    if on == themeListening or not (TH and TH.OnResolve) then return end
    if on then TH.OnResolve(OnThemeResolved)
    elseif TH.OffResolve then TH.OffResolve(OnThemeResolved)
    else return end   -- (a core without OffResolve: the listener stays, and returns at once while the trail is off or on another gradient)
    themeListening = on
end

-- (re)apply the saved settings. Called at login and after every change on the Cursor tab.
function ns.CursorTrail_Apply()
    local c = Ensure()
    if not c then return end
    if not c.enabled then
        ListenTheme(false)
        if frame then frame:SetScript("OnUpdate", nil); ClearAll(); frame:Hide() end
        return
    end
    Build()
    stops = Stops(c)
    ListenTheme(c.preset == "theme")
    curSh = SHAPES[c.shape] or SHAPES.star
    curPath = curSh[2]
    if c.shape == "game" and type(c.gamePath) == "string" and c.gamePath:match("%S") then curPath = (c.gamePath:gsub("^%s+", ""):gsub("%s+$", "")) end
    for i = 1, nDots do
        local d = dots[i]
        ConfigDot(d)
        Off(d)
    end
    cap:Hide()
    ringN, lastX, lastY, lastDropX, lastDropY, midX, midY = 0, nil, nil, nil, nil, nil, nil
    capT = 0
    frame:Show()
    frame:SetScript("OnUpdate", OnUpdate)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() ns.CursorTrail_Apply() end)

-- options: the Gradient Cursor Trail page (QoL > Cursor > Gradient Cursor Trail) ----------------------------------------------------
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
    presetValues.theme = "Match the UI theme"; presetSorting[#presetSorting + 1] = "theme"
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

    -- Colors | Dots | Behavior tabs (Xaya, 2026-11-03: a part's sections are tabs). The on/off switch is the tick box on this page's
    -- row in the left pane (xuiSwitch, QoL 0.7.18; Xaya 2026-11-05: "move all enable/disable toggles onto the sidebar instead").
    custom.order = 5
    return {
        type = "group", name = "Gradient Cursor Trail", order = 2, childGroups = "tab",
        xuiSwitch = { type = "toggle", name = "Gradient cursor trail",
            desc = "Turns the trail on. While it is off nothing is drawn or polled.",
            get = function() return C().enabled and true or false end,
            set = function(_, v) C().enabled = v and true or false; Changed() end },
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "A gradient trail that follows your mouse cursor. Off by default: tick the box next to Gradient Cursor Trail on the left to turn it on." },
            colors = {
                type = "group", name = "Colors", order = 2, hidden = isOff,
                args = {
                    preset = { type = "select", order = 1, width = "double", name = "Gradient",
                        desc = "A ready-made gradient; Match the UI theme (your UI theme's colors, following every theme change: a \"Cursor trail\" theme gives exactly its gradient, any other theme its selected-text, accent and glow colors); or Custom to choose your own colors (2 to 6).",
                        values = presetValues, sorting = presetSorting,
                        get = function() return C().preset end,
                        set = function(_, v) C().preset = v; Changed() end },
                    preview = { type = "description", order = 2, width = "full", fontSize = "medium",
                        name = function() return Preview(C()) end },
                    reverse = { type = "toggle", order = 4, name = "Reverse colors",
                        desc = "Swaps the ends: the first color ends up at the tail of the trail instead of next to the cursor.",
                        get = function() return C().reverse and true or false end,
                        set = function(_, v) C().reverse = v and true or false; Changed() end },
                    custom = custom,
                },
            },
            dots = {
                type = "group", name = "Dots", order = 3, hidden = isOff,
                args = {
                    shape = { type = "select", order = 3, name = "Dot shape", values = shapeValues, sorting = shapeSorting,
                        get = function() return C().shape end,
                        set = function(_, v) C().shape = v; Changed() end },
                    gamePath = { type = "input", order = 3.1, name = "Game texture", width = "double",
                        desc = "Any texture the game client already has: a path such as Interface\\Icons\\Spell_Nature_Lightning, a numeric file ID, or an atlas name. Nothing needs to be added to XayaUI. A green square means the path was not found.",
                        hidden = function() return C().shape ~= "game" end,
                        get = function() return C().gamePath or "" end,
                        set = function(_, v) C().gamePath = tostring(v or ""):sub(1, 200); Changed() end },
                    size = { type = "range", order = 6, name = "Dot size", min = 6, max = 48, step = 1,
                        get = function() return C().size end,
                        set = function(_, v) C().size = v; Changed() end },
                    opacity = { type = "range", order = 7, name = "Opacity", min = 0.1, max = 1, step = 0.05, isPercent = true,
                        get = function() return C().opacity end,
                        set = function(_, v) C().opacity = v; Changed() end },
                },
            },
            behavior = {
                type = "group", name = "Behavior", order = 4, hidden = isOff,
                args = {
                    length = { type = "range", order = 5, name = "Trail length (seconds)", min = 0.2, max = 1.5, step = 0.05,
                        get = function() return C().length end,
                        set = function(_, v) C().length = v; Changed() end },
                    hideMouselook = { type = "toggle", order = 8, width = "double", name = "Hide while turning the camera (mouselook)",
                        get = function() return C().hideMouselook and true or false end,
                        set = function(_, v) C().hideMouselook = v and true or false; Changed() end },
                },
            },
        },
    }
end

-- The Cursor node of the QoL tab (Xaya, 2026-11-03): its parts, Cursor Highlight and Gradient Cursor Trail, are nodes under it in
-- the left pane. Each part's on/off is the tick box on its own row (QoL 0.7.18; Xaya 2026-11-05: "move all enable/disable toggles
-- onto the sidebar instead"); Cursor itself has no single switch (two separate effects), so its row has no box and its page is a note.
function ns.BuildCursorGroup(Notify)
    local hl = ns.BuildCursorHighlightTab and ns.BuildCursorHighlightTab(Notify) or nil
    local tr = ns.BuildCursorTab(Notify)
    local overview = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Two separate effects that make your mouse cursor easy to find. Turn either on with the tick box on its row on the left, then pick it to set it up." },
    }
    overview.highlight = hl
    overview.trail = tr
    return { type = "group", name = "Cursor", order = 2, childGroups = "tree", args = overview }
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
ns.RegisterSettingsPage("qol", "cursor", ns.BuildCursorGroup)
-- /xui cursor [highlight|trail]: open the Cursor settings (Modules.lua lists this command as QoL's; it was never registered before 0.6.1)
ns.RegisterCommand("cursor", function(arg)
    arg = tostring(arg or ""):lower()
    local part = (arg:find("^high") and "highlight") or (arg:find("^trail") and "trail") or nil
    if part then ns.OpenSettingsPage("qol", "cursor", part) else ns.OpenSettingsPage("qol", "cursor") end
end, "/xui cursor [highlight|trail] (cursor highlight and trail settings)")
