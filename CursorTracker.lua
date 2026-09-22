-------------------------------------------------------------------------------
-- CursorTracker.lua : quality-of-life cursor tracker (toggle on / off, default OFF).
--
-- A small texture that follows the mouse cursor. Options: texture (built-in, one of the
-- local graphics, or a custom file path), height capped at 52 px, opacity, colorizer
-- (solid / class / rainbow / texture's own colors), sparkle trail, and reactions to the
-- global cooldown (GCD) and to spell casting (recolor / rescale the cursor ring, plus an
-- optional progress sweep ring).
--
-- Midnight note: cooldown / cast times may be SECRET values in restricted content. We never
-- compare or do arithmetic on a secret; if times are unreadable the sweep is tried through
-- duration objects (pcall) and otherwise the reaction is state-only (recolor / rescale).
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
    -- colorizer: solid | class | rainbow | none (texture's own colors)
    colorMode = "solid", color = { 0.55, 0.2, 0.8 }, rainbowSpeed = 0.3,
    -- visibility
    showCombat = "none", hideMouselook = false,
    -- sparkle trail
    trailOn = false, trailTex = "sparkle", trailSize = 12, trailRate = 3, trailLife = 0.6,
    trailSpread = 6, trailOpacity = 1, trailOwnColor = false, trailColor = { 1, 0.85, 0.4 },
    -- global cooldown reaction (effects are drawn ON the cursor icon and follow its texture, size and scale)
    gcdOn = false, gcdSwipe = true, gcdOutline = false, gcdWipe = false, gcdGradient = false, gcdFade = false,
    gcdRecolor = false, gcdColor = { 1, 0.8, 0.2 }, gcdDir = "up", gcdReverse = false, gcdFxOpacity = 0.8,
    gcdOutlineScale = 1.25, gcdScale = 1, gcdAlphaMult = 1,
    gcdOnlyInstances = false, gcdCombatOnly = false,
    -- spell casting reaction: same effect set; by default it reads the GCD choices (castSame)
    castOn = false, castSame = true,
    castSwipe = true, castOutline = false, castWipe = false, castGradient = false, castFade = false,
    castRecolor = true, castColor = { 1, 0.5, 0.1 }, castDir = "up", castReverse = false, castFxOpacity = 0.9,
    castOutlineScale = 1.25, castScale = 1.15, castAlphaMult = 1,
}

local function CopyVal(v) if type(v) == "table" then return { unpack(v) } end return v end
local function Cfg() return CueRulesDB and CueRulesDB.cursor end
local function IsSecret(v) return ns.IsSecret and ns.IsSecret(v) or false end

function ns.CursorOn() local c = Cfg(); return c and c.enabled and true or false end

-------------------------------------------------------------------------------
-- texture + color helpers
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
local fr, tex, tf, sw, fxSwipe, fxOutline, fxWipe, fxGrad
local NPART = 48
local particles, activeN = {}, 0
local lastX, lastY, spawnAcc = nil, nil, 0
local mod = { color = nil, scale = 1, alpha = 1 }
local curKey, curState = nil, nil
local pollAcc = 0
local prog, fadeMul = nil, nil
local fxOn = {}
local Layout

-- reaction settings: casting reads the GCD's choices while "castSame" is ticked
local EFFECT_KEYS = { "Swipe", "Outline", "Wipe", "Gradient", "Fade", "Recolor", "Color", "Dir", "Reverse", "FxOpacity", "OutlineScale", "Scale", "AlphaMult" }
local function K(cfg, P, name)
    if P == "cast" and cfg.castSame then return cfg["gcd" .. name] end
    return cfg[P .. name]
end
ns.CURSOR_EFFECT_KEYS = EFFECT_KEYS

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

local function SetupCd(cdf, path, scale, opacity, color, reverse)
    local w, h = fr:GetSize()
    cdf:ClearAllPoints()
    cdf:SetPoint("CENTER", fr, "CENTER", 0, 0)
    cdf:SetSize(w * scale, h * scale)
    cdf:SetSwipeTexture(path)
    local c = color or { 1, 1, 1 }
    cdf:SetSwipeColor(c[1] or 1, c[2] or 1, c[3] or 1, opacity or 1)
    cdf:SetReverse(reverse and true or false)
end

-- show only the leading fraction f (0-1) of a texture that is laid over the cursor icon, growing from the given edge
local function Crop(t, w, h, f, dir)
    if f <= 0.002 then t:Hide(); return end
    if f > 1 then f = 1 end
    t:ClearAllPoints()
    if dir == "down" then
        t:SetPoint("TOPLEFT", fr, "TOPLEFT"); t:SetPoint("TOPRIGHT", fr, "TOPRIGHT"); t:SetHeight(h * f); t:SetTexCoord(0, 1, 0, f)
    elseif dir == "right" then
        t:SetPoint("BOTTOMLEFT", fr, "BOTTOMLEFT"); t:SetPoint("TOPLEFT", fr, "TOPLEFT"); t:SetWidth(w * f); t:SetTexCoord(0, f, 0, 1)
    elseif dir == "left" then
        t:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT"); t:SetPoint("TOPRIGHT", fr, "TOPRIGHT"); t:SetWidth(w * f); t:SetTexCoord(1 - f, 1, 0, 1)
    else
        t:SetPoint("BOTTOMLEFT", fr, "BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT"); t:SetHeight(h * f); t:SetTexCoord(0, 1, 1 - f, 1)
    end
    t:Show()
end

-- progress numbers for the wipe / gradient / fade effects (readable times; the GCD falls back to an estimate)
local function ProgressFor(state, st, du)
    if st and du and du > 0 then return { start = st, dur = du } end
    if state == "gcd" then
        local dur = 1.5
        local ok, h = pcall(GetHaste)
        if ok and type(h) == "number" and not IsSecret(h) then dur = math.max(0.75, 1.5 / (1 + h / 100)) end
        return { start = GetTime(), dur = dur, est = true }
    end
end

local function UpdateFx(cfg)
    if not prog or not curState then return end
    local P = curState
    local p = (GetTime() - prog.start) / prog.dur
    if p < 0 then p = 0 elseif p > 1 then p = 1 end
    local rev = K(cfg, P, "Reverse")
    local f = rev and p or (1 - p)
    local w, h = fr:GetSize()
    local dir = K(cfg, P, "Dir") or "up"
    if fxOn.wipe then Crop(fxWipe, w, h, f, dir) end
    if fxOn.grad then Crop(fxGrad, w, h, f, dir) end
    if fxOn.fade then
        local m = K(cfg, P, "AlphaMult") or 1
        fadeMul = m + (1 - m) * (rev and (1 - p) or p)
    end
end

local function ApplyState(cfg, state, kind, st, du)
    if state and not cfg[state .. "On"] then state = nil end   -- a reaction that is switched off never draws anything
    curState = state
    mod.color, mod.scale, mod.alpha = nil, 1, 1
    prog, fadeMul = nil, nil
    fxOn.wipe, fxOn.grad, fxOn.fade = false, false, false
    fxSwipe:Hide(); fxOutline:Hide(); fxWipe:Hide(); fxGrad:Hide()
    if state then
        local P = state
        local c = K(cfg, P, "Color") or { 1, 1, 1 }
        if K(cfg, P, "Recolor") then mod.color = c end
        mod.scale, mod.alpha = K(cfg, P, "Scale") or 1, K(cfg, P, "AlphaMult") or 1
        Layout(cfg)      -- sizes the cursor first: every effect below is sized from it
        local path = ResolveTex(cfg.tex, cfg.customPath)
        local op, rev = K(cfg, P, "FxOpacity") or 0.8, K(cfg, P, "Reverse")
        if K(cfg, P, "Swipe") then
            SetupCd(fxSwipe, path, 1, op, c, rev)
            fxSwipe:Show()
            if not StartSweep(fxSwipe, st, du, kind) then fxSwipe:Hide() end
        end
        if K(cfg, P, "Outline") then
            SetupCd(fxOutline, ResolveTex("ringthick"), K(cfg, P, "OutlineScale") or 1.25, op, c, rev)
            fxOutline:Show()
            if not StartSweep(fxOutline, st, du, kind) then fxOutline:Hide() end
        end
        local wantWipe, wantGrad, wantFade = K(cfg, P, "Wipe"), K(cfg, P, "Gradient"), K(cfg, P, "Fade")
        if wantWipe or wantGrad or wantFade then
            prog = ProgressFor(state, st, du)
            if prog then
                fxOn.wipe, fxOn.grad, fxOn.fade = wantWipe and true or false, wantGrad and true or false, wantFade and true or false
                if fxOn.wipe then fxWipe:SetTexture(path); fxWipe:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, op) end
                if fxOn.grad then
                    fxGrad:SetTexture(path)
                    local dir = K(cfg, P, "Dir") or "up"
                    local r, g, b = c[1] or 1, c[2] or 1, c[3] or 1
                    local dim, bright = CreateColor(r, g, b, op * 0.15), CreateColor(r, g, b, op)
                    local orient = (dir == "up" or dir == "down") and "VERTICAL" or "HORIZONTAL"
                    local lo, hi = dim, bright                    -- lo = bottom / left edge, hi = top / right edge
                    if dir == "down" or dir == "left" then lo, hi = bright, dim end
                    if not pcall(fxGrad.SetGradient, fxGrad, orient, lo, hi) then fxGrad:SetVertexColor(r, g, b, op) end
                end
                tex:SetAlpha(fxOn.wipe and 0.3 or 1)     -- the wipe reveals the icon over a dimmed copy of itself
            end
        end
    else
        Layout(cfg)
    end
    if not (state and prog and fxOn.wipe) then tex:SetAlpha(1) end
    UpdateFx(cfg)
end

-- sizes, texture, color of the base cursor texture (uses the current reaction modifiers)
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
    if prog then UpdateFx(cfg) end
    self:SetAlpha(ml and 0 or (cfg.opacity or 1) * (fadeMul or mod.alpha or 1))
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
    elseif curState or curKey then   -- both reactions were switched off while one was drawn: clear it now
        curKey = nil
        ApplyState(cfg, nil)
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
    fxSwipe, fxOutline = MakeCd(), MakeCd()
    fxWipe = sw:CreateTexture(nil, "ARTWORK"); fxWipe:Hide()
    fxGrad = sw:CreateTexture(nil, "ARTWORK", nil, 1); fxGrad:Hide()
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
            fxSwipe:Hide(); fxOutline:Hide(); fxWipe:Hide(); fxGrad:Hide()
            prog, fadeMul = nil, nil
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
    ApplyState(cfg, nil)        -- clears any reaction effects still drawn (e.g. after a setting was switched off)
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
            set = function(_, v) C()[key] = v; ns.Cursor_Apply() end }, extra)   -- no Notify: rebuilding the page mid-drag broke the slider
    end
    local function sel(key, name, order, vals, ord, extra)
        return merge({ type = "select", name = name, order = order, values = vals, sorting = ord,
            get = function() return C()[key] end,
            set = function(_, v) C()[key] = v; apply() end }, extra)
    end
    local function clr(key, name, order, extra)
        return merge({ type = "color", name = name, order = order, hasAlpha = false,
            get = function() local c = C()[key] or { 1, 1, 1 }; return c[1], c[2], c[3] end,
            set = function(_, r, g, b) C()[key] = { r, g, b }; ns.Cursor_Apply() end }, extra)
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
    local COLOR_V = { solid = "Solid color", class = "Class color", rainbow = "Rainbow cycle", none = "Texture's own colors" }
    local COLOR_O = { "solid", "class", "rainbow", "none" }

    local DIR_V = { up = "Up", down = "Down", left = "Left", right = "Right" }
    local DIR_O = { "up", "down", "left", "right" }
    -- one reaction group (GCD or casting). Every effect is drawn ON the cursor icon, so it takes the icon's texture,
    -- size and scale; casting reads the GCD's choices while "Same as Global Cooldown" is ticked.
    local function react(P, title, order)
        local function dis() return not C().enabled or not C()[P .. "On"] end
        local function hid() return P == "cast" and C().castSame and true or false end
        local function eff(n)   -- the value that is actually used (casting reads the GCD's while "same" is ticked)
            local c = C()
            if P == "cast" and c.castSame then return c["gcd" .. n] end
            return c[P .. n]
        end
        local function anyOf(...) for _, n in ipairs({ ... }) do if eff(n) then return true end end return false end
        -- an option is only shown while it can change something that is actually drawn
        local REL = {
            Color = function() return anyOf("Swipe", "Outline", "Wipe", "Gradient", "Recolor") end,
            Dir = function() return anyOf("Wipe", "Gradient") end,
            Reverse = function() return anyOf("Swipe", "Outline", "Wipe", "Gradient", "Fade") end,
            FxOpacity = function() return anyOf("Swipe", "Outline", "Wipe", "Gradient") end,
            OutlineScale = function() return anyOf("Outline") end,
        }
        local function fx(name, label, o, kind, extra, ...)
            local key = P .. name
            local d
            if kind == "tog" then d = tog(key, label, o, extra)
            elseif kind == "rng" then d = rng(key, label, o, ...)
            elseif kind == "sel" then d = sel(key, label, o, ...)
            else d = clr(key, label, o, extra) end
            local rel = REL[name]
            d.disabled = dis
            d.hidden = function() return hid() or not C()[P .. "On"] or (rel and not rel()) or false end
            return d
        end
        local a = {
            on = tog(P .. "On", P == "gcd" and "React to the global cooldown" or "React to spell casting and channeling", 1, { width = "full",
                desc = P == "cast" and "Casting takes priority over the GCD reaction while it lasts." or nil }),
        }
        if P == "cast" then
            a.castSame = tog("castSame", "Same as Global Cooldown", 2, { width = "full", disabled = dis,
                hidden = function() return not C().castOn end,
                desc = "Casting uses exactly the effects, color, direction and opacity chosen under Global Cooldown. Unticking copies the current Global Cooldown choices here so you can change them.",
                set = function(_, v)
                    local c = C()
                    if not v then for _, n in ipairs(ns.CURSOR_EFFECT_KEYS) do c["cast" .. n] = CopyVal(c["gcd" .. n]) end end
                    c.castSame = v and true or false
                    ns.Cursor_Apply(); Notify()
                end })
        end
        a.swipe = fx("Swipe", "Swipe overlay", 3, "tog", { desc = "The cursor's own shape is swiped clockwise over the duration, like a cooldown swipe. Works even when the game hides the times." })
        a.outline = fx("Outline", "Moving outline", 4, "tog", { desc = "A ring around the cursor that sweeps over the duration. Its size is a multiple of the cursor size." })
        a.wipe = fx("Wipe", "Wipe", 5, "tog", { desc = "The cursor is revealed edge to edge (over a dimmed copy) in the chosen direction. Needs readable times; the GCD is estimated from your haste when the game hides it." })
        a.gradient = fx("Gradient", "Gradient fill", 6, "tog", { desc = "A color gradient in the cursor's shape fills in the chosen direction. Same timing rules as Wipe." })
        a.fade = fx("Fade", "Transparency fade", 7, "tog", { desc = "The cursor's opacity moves from the 'Start opacity' below to full over the duration." })
        a.recolor = fx("Recolor", "Recolor the cursor", 8, "tog")
        a.color = fx("Color", "Effect color", 9, "clr")
        a.dir = fx("Dir", "Direction", 10, "sel", nil, DIR_V, DIR_O)
        a.reverse = fx("Reverse", "Fill instead of drain", 11, "tog", { desc = "Wipe, gradient and swipe drain by default; ticked they fill up." })
        a.fxOpacity = fx("FxOpacity", "Effect opacity", 12, "rng", nil, 0.05, 1, 0.05, { isPercent = true })
        a.outlineScale = fx("OutlineScale", "Outline size (x cursor)", 13, "rng", nil, 1, 1.8, 0.05)
        a.scale = fx("Scale", "Cursor scale", 14, "rng", nil, 0.5, 2, 0.05, { desc = "Multiplies the cursor height; still capped at " .. MAXH .. " px. Effects follow it." })
        a.alphaMult = fx("AlphaMult", "Start opacity", 15, "rng", nil, 0.1, 1, 0.05, { isPercent = true, desc = "Cursor opacity while this is active (the start value when Transparency fade is on)." })
        if P == "gcd" then
            a.inst = tog("gcdOnlyInstances", "Only in instances", 16, { disabled = dis, hidden = function() return not C().gcdOn end })
            a.combat = tog("gcdCombatOnly", "Only in combat", 17, { disabled = dis, hidden = function() return not C().gcdOn end })
        end
        -- the effect options are drawn only while the reaction is switched on; the whole group only while the tracker is on
        local top = { on = a.on }
        a.on = nil
        ns.GateRest(ns, a, "cur_" .. P .. "_fx", "Effects", 2, function() return C()[P .. "On"] end, {})
        top["pane_cur_" .. P .. "_fx"] = a["pane_cur_" .. P .. "_fx"]
        return ns.GatedPane(ns, "cur_" .. P, title, order, function() return C().enabled end, top)
    end

    local g = {
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
                colorMode = sel("colorMode", "Color mode", 1, COLOR_V, COLOR_O, { desc = "Also colors the sparkle trail (unless the trail has its own color)." }),
                color = clr("color", "Color", 2, { hidden = function() return C().colorMode ~= "solid" end }),
                rainbowSpeed = rng("rainbowSpeed", "Rainbow speed", 3, 0.05, 2, 0.05, { hidden = function() return C().colorMode ~= "rainbow" end }),
            } },

            trail = { type = "group", inline = true, name = "Sparkle Trail", order = 30, disabled = off, args = {
                trailOn = tog("trailOn", "Enable sparkle trail", 1, { width = "full", desc = "Sparkles spawn as the cursor moves and fade out. Nothing spawns while the cursor is still." }),
                trailTex = sel("trailTex", "Sparkle texture", 2, builtV, builtO, { disabled = function() return off() or not C().trailOn end }),
                trailSize = rng("trailSize", "Sparkle size (px)", 3, 4, 24, 1, { disabled = function() return off() or not C().trailOn end }),
                trailRate = rng("trailRate", "Density", 4, 1, 10, 1, { desc = "Sparkles per 20 px the cursor moves.", disabled = function() return off() or not C().trailOn end }),
                trailLife = rng("trailLife", "Lifetime (s)", 5, 0.2, 2, 0.1, { disabled = function() return off() or not C().trailOn end }),
                trailSpread = rng("trailSpread", "Spread (px)", 6, 0, 20, 1, { disabled = function() return off() or not C().trailOn end }),
                trailOpacity = rng("trailOpacity", "Trail opacity", 7, 0.05, 1, 0.05, { isPercent = true, disabled = function() return off() or not C().trailOn end }),
                trailOwnColor = tog("trailOwnColor", "Separate trail color", 8, { disabled = function() return off() or not C().trailOn end }),
                trailColor = clr("trailColor", "Trail color", 9, { disabled = function() return off() or not C().trailOn end,
                    hidden = function() return not C().trailOwnColor end }),
            } },

            gcd = react("gcd", "Global Cooldown", 40),
            cast = react("cast", "Spell Casting", 50),

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
    -- everything under the enable switch is drawn only while the tracker is on, as collapsible panes
    local ga, en = g.args, function() return C().enabled end
    local ta = ga.trail.args
    ns.GatePane(ns, ta, "cur_trailcol", "Trail color", 8.5, function() return C().trailOwnColor end, { "trailColor" })
    ns.GateRest(ns, ta, "cur_trail", "Trail options", 2, function() return C().trailOn end, { trailOn = true })
    for _, k in ipairs({ "look", "colorizer", "trail", "vis" }) do
        local grp = ga[k]
        ga[k] = ns.GatedPane(ns, "cur_" .. k, grp.name, grp.order, en, grp.args)
    end
    return g
end
