-------------------------------------------------------------------------------
-- CursorTracker.lua : quality-of-life cursor tracker (toggle on / off, default OFF).
--
-- A small texture that follows the mouse cursor. Options: texture (built-in, one of the
-- local graphics, or a custom file path), height capped at 52 px, opacity, colorizer
-- (solid / class / rainbow / texture's own colours), sparkle trail, and reactions to the
-- global cooldown (GCD) and to spell casting (recolour / rescale the cursor ring, plus an
-- optional progress sweep ring).
--
-- Midnight note: cooldown / cast times may be SECRET values in restricted content. We never
-- compare or do arithmetic on a secret; if times are unreadable the sweep is tried through
-- duration objects (pcall) and otherwise the reaction is state-only (recolour / rescale).
-- When the master switch is off nothing is created or polled.
-------------------------------------------------------------------------------
local addonName, ns = ...

local MAXH = 52                       -- max texture height in px (= the ring in Xaya's reference screenshot)
ns.CURSOR_MAX_H = MAXH
local MEDIA = "Interface\\AddOns\\XayaUI\\Media\\Cursor\\"
local GCD_SPELL = 61304

ns.CURSOR_TEX_ORDER = { "ring", "ringthick", "dot", "crosshair", "sparkle", "glow" }
ns.CURSOR_TEX = {   -- label, path, w, h   (generated white-on-alpha TGAs, so tinting works)
    ring      = { "Ring",       MEDIA .. "Ring.tga",      64, 64 },
    ringthick = { "Ring Thick", MEDIA .. "RingThick.tga", 64, 64 },
    dot       = { "Dot",        MEDIA .. "Dot.tga",       64, 64 },
    crosshair = { "Crosshair",  MEDIA .. "Crosshair.tga", 64, 64 },
    sparkle   = { "Sparkle",    MEDIA .. "Sparkle.tga",   64, 64 },
    glow      = { "Soft Glow",  MEDIA .. "Glow.tga",      64, 64 },
}

ns.CURSOR_DEFAULTS = {
    enabled = false,
    -- cursor texture
    tex = "ring", customPath = "", size = 36, opacity = 1, offsetX = 0, offsetY = 0,
    -- colorizer: solid | class | rainbow | none (texture's own colours)
    colorMode = "solid", color = { 0.55, 0.2, 0.8 }, rainbowSpeed = 0.3,
    -- visibility
    showCombat = "none", hideMouselook = false,
    -- sparkle trail
    trailOn = false, trailTex = "sparkle", trailSize = 12, trailRate = 3, trailLife = 0.6,
    trailSpread = 6, trailOpacity = 1, trailOwnColor = false, trailColor = { 1, 0.85, 0.4 },
    -- global cooldown reaction
    gcdOn = false, gcdSweep = true, gcdRingTex = "ringthick", gcdRingSize = 44, gcdRingOpacity = 0.8,
    gcdRingColor = { 0.55, 0.2, 0.8 }, gcdReverse = false,
    gcdRecolor = false, gcdColor = { 1, 0.8, 0.2 }, gcdScale = 1, gcdAlphaMult = 1,
    gcdOnlyInstances = false, gcdCombatOnly = false,
    -- spell casting reaction
    castOn = false, castSweep = true, castRingTex = "ring", castRingSize = 50, castRingOpacity = 0.9,
    castRingColor = { 1, 0.45, 0.1 }, castReverse = false,
    castRecolor = true, castColor = { 1, 0.5, 0.1 }, castScale = 1.15, castAlphaMult = 1,
}

local function CopyVal(v) if type(v) == "table" then return { unpack(v) } end return v end
local function Cfg() return CueRulesDB and CueRulesDB.cursor end
local function IsSecret(v) return ns.IsSecret and ns.IsSecret(v) or false end

function ns.CursorOn() local c = Cfg(); return c and c.enabled and true or false end

-------------------------------------------------------------------------------
-- texture + colour helpers
-------------------------------------------------------------------------------
local lgIndex
local function ResolveTex(key, custom)
    local b = ns.CURSOR_TEX[key]
    if b then return b[2], b[3], b[4] end
    if key == "custom" then
        local p = tostring(custom or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub('^"(.*)"$', "%1")
        if p ~= "" then return tonumber(p) or p, 1, 1 end   -- unknown aspect: treated as square
    else
        if not lgIndex then
            lgIndex = {}
            for _, g in ipairs(ns.LocalGraphics or {}) do lgIndex[g[2]] = g end
        end
        local g = lgIndex[key]
        if g then return g[2], g[3], g[4] end
    end
    local d = ns.CURSOR_TEX.ring
    return d[2], d[3], d[4]
end

local function HSV(h)
    local i = math.floor(h * 6); local f = h * 6 - i
    local q, t = 1 - f, f
    i = i % 6
    if i == 0 then return 1, t, 0 elseif i == 1 then return q, 1, 0 elseif i == 2 then return 0, 1, t
    elseif i == 3 then return 0, q, 1 elseif i == 4 then return t, 0, 1 else return 1, 0, q end
end

local function BaseColor(cfg)
    local m = cfg.colorMode
    if m == "none" then return 1, 1, 1 end
    if m == "class" then
        local _, cls = UnitClass("player")
        local cc = cls and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(cls)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]))
        if cc then return cc.r, cc.g, cc.b end
        return 1, 1, 1
    end
    if m == "rainbow" then return HSV((GetTime() * (cfg.rainbowSpeed or 0.3)) % 1) end
    local c = cfg.color or { 1, 1, 1 }
    return c[1] or 1, c[2] or 1, c[3] or 1
end

-------------------------------------------------------------------------------
-- frames
-------------------------------------------------------------------------------
local fr, tex, tf, sw, gcdCd, castCd
local NPART = 48
local particles, activeN = {}, 0
local lastX, lastY, spawnAcc = nil, nil, 0
local mod = { color = nil, scale = 1, alpha = 1 }
local curKey, curState = nil, nil
local pollAcc = 0
local Layout

local function ClearTrail()
    for i = 1, #particles do local p = particles[i]; p.on = false; p.tex:Hide() end
    activeN, lastX, spawnAcc = 0, nil, 0
end

local function Spawn(cfg, x, y)
    for i = 1, NPART do
        local p = particles[i]
        if not p.on then
            p.on = true; activeN = activeN + 1
            p.born = GetTime()
            p.life = (cfg.trailLife or 0.6) * (0.7 + 0.6 * math.random())
            local sp = cfg.trailSpread or 6
            p.x = x + (math.random() - 0.5) * 2 * sp
            p.y = y + (math.random() - 0.5) * 2 * sp
            p.vx = (math.random() - 0.5) * 30
            p.vy = -10 - math.random() * 20
            p.size = math.min(MAXH, (cfg.trailSize or 12) * (0.6 + 0.8 * math.random()))
            p.rot = math.random() * 6.283
            p.spin = (math.random() - 0.5) * 4
            p.phase = math.random() * 6.283
            local r, g, b
            if cfg.trailOwnColor then local c = cfg.trailColor or { 1, 1, 1 }; r, g, b = c[1], c[2], c[3]
            else r, g, b = BaseColor(cfg) end
            p.tex:SetVertexColor(r, g, b)
            p.tex:Show()
            return
        end
    end
end

local function TrailMove(cfg, x, y)
    if lastX then
        local dx, dy = x - lastX, y - lastY
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 0.5 then
            spawnAcc = spawnAcc + d * (cfg.trailRate or 3) / 20
            local n = 0
            while spawnAcc >= 1 and n < 6 do
                local t = math.random()
                Spawn(cfg, lastX + dx * t, lastY + dy * t)
                spawnAcc = spawnAcc - 1; n = n + 1
            end
            if spawnAcc > 6 then spawnAcc = 0 end
        end
    end
end

local function TrailStep(cfg)
    local now, op = GetTime(), cfg.trailOpacity or 1
    for i = 1, NPART do
        local p = particles[i]
        if p.on then
            local age = now - p.born
            local f = age / p.life
            if f >= 1 then
                p.on = false; activeN = activeN - 1; p.tex:Hide()
            else
                p.tex:SetAlpha(op * (1 - f) * (0.65 + 0.35 * math.sin(now * 28 + p.phase)))
                local sz = p.size * (1 - 0.6 * f)
                p.tex:SetSize(sz, sz)
                p.tex:ClearAllPoints()
                p.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x + p.vx * age, p.y + p.vy * age)
                p.tex:SetRotation(p.rot + p.spin * age)
            end
        end
    end
end

-- GCD / cast readers -------------------------------------------------------
local function ReadGCD()
    local ok, cd = pcall(C_Spell.GetSpellCooldown, GCD_SPELL)
    if not ok or type(cd) ~= "table" then return nil end
    local a, st, du = cd.isActive, cd.startTime, cd.duration
    if IsSecret(a) then a = nil end
    if IsSecret(st) or IsSecret(du) then st, du = nil, nil end
    if a == nil and du then a = du > 0 end
    return a and true or false, st, du
end

local function ReadCast()   -- kind, startSec, durSec
    local ok, name, _, _, st, et = pcall(UnitCastingInfo, "player")
    local kind = "cast"
    if not (ok and name ~= nil) then
        ok, name, _, _, st, et = pcall(UnitChannelInfo, "player")
        kind = "channel"
        if not (ok and name ~= nil) then return nil end
    end
    if type(st) == "number" and type(et) == "number" and not IsSecret(st) and not IsSecret(et) then
        return kind, st / 1000, (et - st) / 1000
    end
    return kind, nil, nil
end

local function StartSweep(cdf, st, du, kind)
    cdf:Clear()
    if st and du and du > 0 then cdf:SetCooldown(st, du); return true end
    -- unreadable times: try duration objects (12.x), all inside pcall
    local ok = pcall(function()
        local obj
        if kind == "gcd" then obj = C_Spell.GetSpellCooldownDuration(GCD_SPELL)
        elseif kind == "cast" then obj = UnitCastingDuration("player")
        else obj = UnitChannelDuration("player") end
        if not obj then error("no duration") end
        cdf:SetCooldownFromDurationObject(obj)
    end)
    return ok
end

local function InInstance()
    local ok, inst = pcall(IsInInstance)
    return ok and inst and true or false
end

local function Compute(cfg)
    if cfg.castOn then
        local kind, st, du = ReadCast()
        if kind then return "cast", kind, st, du end
    end
    if cfg.gcdOn then
        local ok = true
        if cfg.gcdCombatOnly and not (UnitAffectingCombat("player")) then ok = false end
        if ok and cfg.gcdOnlyInstances and not InInstance() then ok = false end
        if ok then
            local a, st, du = ReadGCD()
            if a then return "gcd", "gcd", st, du end
        end
    end
end

local function SetupSweep(cdf, texKey, size, opacity, color, reverse)
    local path = ResolveTex(texKey)
    cdf:ClearAllPoints()
    cdf:SetPoint("CENTER", fr, "CENTER", 0, 0)
    local h = math.max(8, math.min(MAXH, size or 40))
    cdf:SetSize(h, h)
    cdf:SetSwipeTexture(path)
    local c = color or { 1, 1, 1 }
    cdf:SetSwipeColor(c[1] or 1, c[2] or 1, c[3] or 1, opacity or 1)
    cdf:SetReverse(reverse and true or false)
end

local function ApplyState(cfg, state, kind, st, du)
    curState = state
    mod.color, mod.scale, mod.alpha = nil, 1, 1
    gcdCd:Hide(); castCd:Hide()
    if state == "gcd" then
        if cfg.gcdRecolor then mod.color = cfg.gcdColor or { 1, 1, 1 } end
        mod.scale, mod.alpha = cfg.gcdScale or 1, cfg.gcdAlphaMult or 1
        if cfg.gcdSweep then
            SetupSweep(gcdCd, cfg.gcdRingTex, cfg.gcdRingSize, cfg.gcdRingOpacity, cfg.gcdRingColor, cfg.gcdReverse)
            gcdCd:Show()
            if not StartSweep(gcdCd, st, du, "gcd") then gcdCd:Hide() end
        end
    elseif state == "cast" then
        if cfg.castRecolor then mod.color = cfg.castColor or { 1, 1, 1 } end
        mod.scale, mod.alpha = cfg.castScale or 1, cfg.castAlphaMult or 1
        if cfg.castSweep then
            SetupSweep(castCd, cfg.castRingTex, cfg.castRingSize, cfg.castRingOpacity, cfg.castRingColor, cfg.castReverse)
            castCd:Show()
            if not StartSweep(castCd, st, du, kind) then castCd:Hide() end
        end
    end
    Layout(cfg)
end

-- sizes, texture, colour of the base cursor texture (uses the current reaction modifiers)
function Layout(cfg)
    local path, tw, th = ResolveTex(cfg.tex, cfg.customPath)
    local h = math.max(8, math.min(MAXH, (cfg.size or 36) * (mod.scale or 1)))
    local w = h * (tw or 1) / (th or 1)
    fr:SetSize(w, h)
    tex:SetTexture(path)
    if mod.color then tex:SetVertexColor(mod.color[1] or 1, mod.color[2] or 1, mod.color[3] or 1)
    else tex:SetVertexColor(BaseColor(cfg)) end
    local tpath = ResolveTex(cfg.trailTex)
    for i = 1, #particles do particles[i].tex:SetTexture(tpath) end
end

local function OnUpdate(self, el)
    local cfg = Cfg()
    if not cfg then return end
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    x, y = x / s, y / s
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + (cfg.offsetX or 0), y + (cfg.offsetY or 0))
    local ml = cfg.hideMouselook and IsMouselooking and IsMouselooking() or false
    self:SetAlpha(ml and 0 or (cfg.opacity or 1) * (mod.alpha or 1))
    sw:SetAlpha(ml and 0 or 1)
    if cfg.colorMode == "rainbow" and not mod.color then tex:SetVertexColor(BaseColor(cfg)) end
    if cfg.trailOn and not ml then TrailMove(cfg, x, y); lastX, lastY = x, y
    else lastX = nil end
    if activeN > 0 then TrailStep(cfg) end
    -- reactions: poll the state a few times a second; only re-apply when it changes
    if cfg.gcdOn or cfg.castOn then
        pollAcc = pollAcc + el
        if pollAcc >= 0.05 then
            pollAcc = 0
            local state, kind, st, du = Compute(cfg)
            local key = state and (state .. tostring(st or "") .. tostring(kind or "")) or nil
            if key ~= curKey then
                curKey = key
                ApplyState(cfg, state, kind, st, du)
            end
        end
    end
end

local function Ensure()
    if fr then return end
    fr = CreateFrame("Frame", nil, UIParent)
    fr:SetFrameStrata("TOOLTIP"); fr:SetFrameLevel(100)
    fr:EnableMouse(false)
    fr:SetSize(36, 36)
    tex = fr:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    -- sweep rings live on their own frame so the reaction opacity of the base ring does not dim them
    sw = CreateFrame("Frame", nil, UIParent)
    sw:SetFrameStrata("TOOLTIP"); sw:SetFrameLevel(101)
    sw:SetAllPoints(UIParent)
    sw:EnableMouse(false)
    local function MakeCd()
        local c = CreateFrame("Cooldown", nil, sw, "CooldownFrameTemplate")
        c.noCooldownCount = true
        c:SetHideCountdownNumbers(true)
        c:SetDrawEdge(false); c:SetDrawBling(false); c:SetDrawSwipe(true)
        c:EnableMouse(false)
        c:Hide()
        return c
    end
    gcdCd, castCd = MakeCd(), MakeCd()
    tf = CreateFrame("Frame", nil, UIParent)
    tf:SetFrameStrata("TOOLTIP"); tf:SetFrameLevel(90)
    tf:SetAllPoints(UIParent)
    tf:EnableMouse(false)
    for i = 1, NPART do
        local t = tf:CreateTexture(nil, "ARTWORK")
        t:SetBlendMode("ADD"); t:Hide()
        particles[i] = { tex = t, on = false }
    end
    fr:SetScript("OnUpdate", OnUpdate)
end

-- (re)apply everything from the saved settings
function ns.Cursor_Apply()
    local cfg = Cfg()
    if not cfg then return end
    local show = cfg.enabled and true or false
    if show and cfg.showCombat ~= "none" then
        local inCombat = (UnitAffectingCombat("player") or InCombatLockdown()) and true or false
        show = (cfg.showCombat == "yes") == inCombat
    end
    if not show then
        if fr then
            fr:Hide(); sw:Hide(); tf:Hide()
            gcdCd:Hide(); castCd:Hide()
            ClearTrail()
        end
        curKey, curState = nil, nil
        mod.color, mod.scale, mod.alpha = nil, 1, 1
        return
    end
    Ensure()
    curKey = nil                 -- force the reaction state to be re-evaluated
    mod.color, mod.scale, mod.alpha = nil, 1, 1
    Layout(cfg)
    fr:Show(); sw:Show(); tf:Show()
end

function ns.Cursor_Toggle(v)
    local cfg = Cfg(); if not cfg then return end
    if v == nil then v = not cfg.enabled end
    cfg.enabled = v and true or false
    ns.Cursor_Apply()
    return cfg.enabled
end

function ns.Cursor_OnDBReady()
    CueRulesDB.cursor = CueRulesDB.cursor or {}
    for k, v in pairs(ns.CURSOR_DEFAULTS) do
        if CueRulesDB.cursor[k] == nil then CueRulesDB.cursor[k] = CopyVal(v) end
    end
    ns.Cursor_Apply()
    if ns.CursorReminders_OnDBReady then ns.CursorReminders_OnDBReady() end
end

local ev =CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function() if Cfg() then ns.Cursor_Apply() end end)

-------------------------------------------------------------------------------
-- options page (an AceConfig group; built here to keep Options.lua under Lua's 200-locals limit)
-------------------------------------------------------------------------------
function ns.CursorTrackerGroup(Notify)
    local function C() return CueRulesDB.cursor or ns.CURSOR_DEFAULTS end
    local function apply() ns.Cursor_Apply(); Notify() end
    local function merge(o, extra) if extra then for k, v in pairs(extra) do o[k] = v end end return o end
    local function tog(key, name, order, extra)
        return merge({ type = "toggle", name = name, order = order,
            get = function() return C()[key] and true or false end,
            set = function(_, v) C()[key] = v; apply() end }, extra)
    end
    local function rng(key, name, order, min, max, step, extra)
        return merge({ type = "range", name = name, order = order, min = min, max = max, step = step,
            get = function() return C()[key] or min end,
            set = function(_, v) C()[key] = v; apply() end }, extra)
    end
    local function sel(key, name, order, vals, ord, extra)
        return merge({ type = "select", name = name, order = order, values = vals, sorting = ord,
            get = function() return C()[key] end,
            set = function(_, v) C()[key] = v; apply() end }, extra)
    end
    local function clr(key, name, order, extra)
        return merge({ type = "color", name = name, order = order, hasAlpha = false,
            get = function() local c = C()[key] or { 1, 1, 1 }; return c[1], c[2], c[3] end,
            set = function(_, r, g, b) C()[key] = { r, g, b }; apply() end }, extra)
    end
    local function off() return not C().enabled end

    -- texture pickers
    local builtV, builtO = {}, {}
    for _, k in ipairs(ns.CURSOR_TEX_ORDER) do
        local t = ns.CURSOR_TEX[k]
        builtV[k] = "|T" .. t[2] .. ":16|t " .. t[1]; builtO[#builtO + 1] = k
    end
    local texV, texO = {}, {}
    for _, k in ipairs(builtO) do texV[k] = builtV[k]; texO[#texO + 1] = k end
    texV.custom = "Custom file path..."; texO[#texO + 1] = "custom"
    for _, g in ipairs(ns.LocalGraphics or {}) do texV[g[2]] = g[1]; texO[#texO + 1] = g[2] end

    local COMBAT_V = { none = "Always", yes = "Only in combat", no = "Only out of combat" }
    local COMBAT_O = { "none", "yes", "no" }
    local COLOR_V = { solid = "Solid colour", class = "Class colour", rainbow = "Rainbow cycle", none = "Texture's own colours" }
    local COLOR_O = { "solid", "class", "rainbow", "none" }

    local function gcdOff() return not C().enabled or not C().gcdOn end
    local function castOff() return not C().enabled or not C().castOn end

    return {
        type = "group", name = "Cursor Tracker", order = 2,
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "A small texture that follows your mouse cursor. Turn it on with the tick box on this row in the sidebar, the switch below, or /xui cursor. It is OFF by default and costs nothing while off." },
            enabled = tog("enabled", "Enable cursor tracker", 1, { width = "full" }),

            look = { type = "group", inline = true, name = "Cursor Texture", order = 10, disabled = off, args = {
                tex = sel("tex", "Texture", 1, texV, texO, { width = "double",
                    desc = "Built-in shapes, any of your local graphics (Media\\Graphics), or your own file. Height is capped at " .. MAXH .. " px; the width follows the texture's proportions." }),
                customPath = { type = "input", name = "Custom file path", order = 2, width = "full",
                    desc = "Full in-game path, e.g. Interface\\AddOns\\XayaUI\\Media\\Cursor\\MyRing.tga (.tga or .blp; width and height a power of two). WoW can only load files inside its own install folder (Interface\\AddOns\\...), not from Documents or Downloads. A new file needs a full game restart. A wrong path shows a green square. Custom files are drawn square.",
                    hidden = function() return C().tex ~= "custom" end,
                    get = function() return C().customPath or "" end,
                    set = function(_, v) C().customPath = v; apply() end },
                size = rng("size", "Height (px)", 3, 8, MAXH, 1, { desc = "Maximum " .. MAXH .. " px (the size of your reference ring)." }),
                opacity = rng("opacity", "Opacity", 4, 0.05, 1, 0.05, { isPercent = true }),
                offsetX = rng("offsetX", "Offset X", 5, -30, 30, 1),
                offsetY = rng("offsetY", "Offset Y", 6, -30, 30, 1),
            } },

            colorizer = { type = "group", inline = true, name = "Colorizer", order = 20, disabled = off, args = {
                colorMode = sel("colorMode", "Colour mode", 1, COLOR_V, COLOR_O, { desc = "Also colours the sparkle trail (unless the trail has its own colour)." }),
                color = clr("color", "Colour", 2, { hidden = function() return C().colorMode ~= "solid" end }),
                rainbowSpeed = rng("rainbowSpeed", "Rainbow speed", 3, 0.05, 2, 0.05, { hidden = function() return C().colorMode ~= "rainbow" end }),
            } },

            trail = { type = "group", inline = true, name = "Sparkle Trail", order = 30, disabled = off, args = {
                trailOn = tog("trailOn", "Enable sparkle trail", 1, { width = "full", desc = "Sparkles spawn as the cursor moves and fade out. Nothing spawns while the cursor is still." }),
                trailTex = sel("trailTex", "Sparkle texture", 2, builtV, builtO, { disabled = function() return off() or not C().trailOn end }),
                trailSize = rng("trailSize", "Sparkle size (px)", 3, 4, 24, 1, { disabled = function() return off() or not C().trailOn end }),
                trailRate = rng("trailRate", "Density (per 20 px moved)", 4, 1, 10, 1, { disabled = function() return off() or not C().trailOn end }),
                trailLife = rng("trailLife", "Lifetime (s)", 5, 0.2, 2, 0.1, { disabled = function() return off() or not C().trailOn end }),
                trailSpread = rng("trailSpread", "Spread (px)", 6, 0, 20, 1, { disabled = function() return off() or not C().trailOn end }),
                trailOpacity = rng("trailOpacity", "Trail opacity", 7, 0.05, 1, 0.05, { isPercent = true, disabled = function() return off() or not C().trailOn end }),
                trailOwnColor = tog("trailOwnColor", "Use a separate trail colour", 8, { disabled = function() return off() or not C().trailOn end }),
                trailColor = clr("trailColor", "Trail colour", 9, { disabled = function() return off() or not C().trailOn end,
                    hidden = function() return not C().trailOwnColor end }),
            } },

            gcd = { type = "group", inline = true, name = "Global Cooldown", order = 40, disabled = off, args = {
                gcdOn = tog("gcdOn", "React to the global cooldown", 1, { width = "full" }),
                gcdSweep = tog("gcdSweep", "Show a GCD sweep ring", 2, { disabled = gcdOff,
                    desc = "A ring that drains (or fills) over the GCD. If the game hides the GCD times, the addon tries the duration-object route; if that fails the ring is skipped and only the recolour / rescale below applies." }),
                gcdRingTex = sel("gcdRingTex", "Ring texture", 3, builtV, builtO, { disabled = gcdOff }),
                gcdRingSize = rng("gcdRingSize", "Ring height (px)", 4, 8, MAXH, 1, { disabled = gcdOff }),
                gcdRingOpacity = rng("gcdRingOpacity", "Ring opacity", 5, 0.05, 1, 0.05, { isPercent = true, disabled = gcdOff }),
                gcdRingColor = clr("gcdRingColor", "Ring colour", 6, { disabled = gcdOff }),
                gcdReverse = tog("gcdReverse", "Fill instead of drain", 7, { disabled = gcdOff }),
                gcdRecolor = tog("gcdRecolor", "Recolour the cursor during the GCD", 8, { disabled = gcdOff }),
                gcdColor = clr("gcdColor", "GCD colour", 9, { disabled = gcdOff, hidden = function() return not C().gcdRecolor end }),
                gcdScale = rng("gcdScale", "Cursor scale during GCD", 10, 0.5, 2, 0.05, { disabled = gcdOff, desc = "Multiplies the cursor height; still capped at " .. MAXH .. " px." }),
                gcdAlphaMult = rng("gcdAlphaMult", "Cursor opacity during GCD (x)", 11, 0.1, 1, 0.05, { disabled = gcdOff, isPercent = true }),
                gcdOnlyInstances = tog("gcdOnlyInstances", "Only in instances", 12, { disabled = gcdOff }),
                gcdCombatOnly = tog("gcdCombatOnly", "Only in combat", 13, { disabled = gcdOff }),
            } },

            cast = { type = "group", inline = true, name = "Spell Casting", order = 50, disabled = off, args = {
                castOn = tog("castOn", "React to spell casting and channeling", 1, { width = "full",
                    desc = "Casting takes priority over the GCD reaction while it lasts." }),
                castSweep = tog("castSweep", "Show a cast progress ring", 2, { disabled = castOff,
                    desc = "Ring that follows your cast or channel. Needs readable cast times (or duration objects); otherwise only the recolour / rescale below applies." }),
                castRingTex = sel("castRingTex", "Ring texture", 3, builtV, builtO, { disabled = castOff }),
                castRingSize = rng("castRingSize", "Ring height (px)", 4, 8, MAXH, 1, { disabled = castOff }),
                castRingOpacity = rng("castRingOpacity", "Ring opacity", 5, 0.05, 1, 0.05, { isPercent = true, disabled = castOff }),
                castRingColor = clr("castRingColor", "Ring colour", 6, { disabled = castOff }),
                castReverse = tog("castReverse", "Fill instead of drain", 7, { disabled = castOff }),
                castRecolor = tog("castRecolor", "Recolour the cursor while casting", 8, { disabled = castOff }),
                castColor = clr("castColor", "Casting colour", 9, { disabled = castOff, hidden = function() return not C().castRecolor end }),
                castScale = rng("castScale", "Cursor scale while casting", 10, 0.5, 2, 0.05, { disabled = castOff }),
                castAlphaMult = rng("castAlphaMult", "Cursor opacity while casting (x)", 11, 0.1, 1, 0.05, { disabled = castOff, isPercent = true }),
            } },

            vis = { type = "group", inline = true, name = "Visibility", order = 60, disabled = off, args = {
                showCombat = sel("showCombat", "Show", 1, COMBAT_V, COMBAT_O),
                hideMouselook = tog("hideMouselook", "Hide while turning the camera (right mouse held)", 2, { width = "double" }),
            } },

            reset = { type = "execute", name = "Reset cursor tracker to defaults", order = 90, width = "double",
                confirm = true, confirmText = "Reset every cursor tracker setting to its default? (It will also be switched off.)",
                func = function()
                    if ns.CursorReminders_Revert then ns.CursorReminders_Revert() end   -- take away duplicated / converted reminders first
                    CueRulesDB.cursor = {}
                    for k, v in pairs(ns.CURSOR_DEFAULTS) do CueRulesDB.cursor[k] = CopyVal(v) end
                    apply()
                end },
        },
    }
end
