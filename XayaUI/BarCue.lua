-------------------------------------------------------------------------------
-- BarCue.lua : the Bar cue kind (ROADMAP RM-BARS).
-- Xaya 2026-11-06, "Time to build progress bar cues!", and her answers (docs/process/REQUEST-LOG.md S8-1 .. S8-4):
--   a NEW Bar cue kind (beside Icon / Texture / Text); it tracks aura time left, a spell's cooldown / recharge, stacks or charges;
--   its parts are an icon (left / right / none), a spark, name and time texts, and the stack / charge count;
--   colour: "Read tooltip to see what type is specified" FIRST, then the game's dispel type of the aura, then a fixed blue;
--   colour styles: Blizzard default, Neon, Pastel, Muted / Dark, and Custom (a colour picker for each type), set on each Bar cue; a
--   group can force its own on every bar inside it (S8-10); type names in tooltips are title-cased and coloured (S8-10);
--   default look: 220 x 22, black background at 20 %, 1 px black border, flat texture, horizontal, drains right to left.
-- XayaUI draws the bar here (Visual.lua calls ns.BarCueLayout / ns.BarCueUpdate for a display whose kind is "bar"). The combat
-- engine draws aura bars in combat through the game's own aura buttons (Combat/AuraDisplay.lua ButtonInit), using
-- ns.BarCueSource / ns.BarCueColor / ns.BarDispelColorMap from this file, so both paths decide the same way (parity test:
-- tests/bar_cue_run.py).
-- Game facts used (docs/reference/api, 12.1.5): StatusBar:SetTimerDuration(LuaDurationObject, interpolation, direction)
-- (SecretArguments=AllowedWhenUntainted); StatusBar:SetStatusBarColor (SecretArguments=AllowedWhenTainted);
-- C_TooltipInfo.GetSpellByID (no secret flag); C_TooltipInfo.GetUnitAuraByAuraInstanceID (SecretWhenUnitAuraRestricted);
-- C_Spell.GetSpellCooldownDuration / GetSpellChargeDuration (MayReturnNothing). The game has NO call that gives a spell's school
-- (only garrison mission data has a schoolMask), which is why the school is read from the tooltip text.
-- Blizzard's default colours are read from the game at run time, never copied into this file: dispel types from
-- AuraUtil.GetAuraBorderColor (Blizzard_FrameXMLUtil), schools from COMBATLOG_DEFAULT_COLORS.schoolColoring (Blizzard_CombatLogBase,
-- load on demand; loaded only when a bar needs a school colour). Missing in the client = that type falls back to the fixed blue.
-------------------------------------------------------------------------------
local addonName, ns = ...

local issecret = ns.IsSecret or rawget(_G, "issecretvalue") or function() return false end
local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------
ns.BAR_CUE_VERSION = 2   -- bump when BAR_CUE_DEFAULTS gains a key, so saved bars get it once
ns.BAR_FALLBACK_COLOR = { 0.25, 0.62, 1, 1 }   -- "Fixed blue" (Xaya, S8-3): XayaUI's own buff-bar blue
ns.BAR_CUE_DEFAULTS = {
    source = "auto",      -- auto | aura | cooldown | stacks | charges   (auto: the aura when the rule watches one, else the cooldown)
    max = 0,              -- stacks / charges bar: the full value (0 = what the game says: max stacks / max charges)
    dir = "left",         -- the edge the fill drains toward: left (right to left) | right | bottom | top
    reverse = false,      -- fill up instead of draining
    texture = "flat",     -- flat | blizz | raid | lsm:<name> | file
    texFile = "",         -- texture = "file": a texture path or file ID
    colorMode = "auto",   -- auto (the type colour: tooltip, dispel type, fixed blue) | fixed (color below)
    style = "blizzard",   -- the type colours' style: blizzard | neon | pastel | muted | custom (a group can force its own: BarCueStyle)
    custom = {},          -- style = custom: [type] = { r, g, b, a }; a type never picked shows Blizzard's colour
    color = { 0.25, 0.62, 1, 1 },
    icon = "left",        -- left | right | none
    spark = { enabled = true, color = { 1, 1, 1, 0.9 }, w = 12 },
    name = { enabled = true, anchor = "LEFT", x = 4, y = 0, size = 12, color = { 1, 1, 1, 1 } },
}

local function Copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = Copy(v) end
    return o
end
-- Missing keys of a saved bar table are filled from the defaults (older saves, imports). Values already there are kept.
local function Fill(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then dst[k] = Copy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" and v[1] == nil then Fill(dst[k], v) end
    end
end
function ns.BarCueSettings(v)
    if type(v) ~= "table" then return Copy(ns.BAR_CUE_DEFAULTS) end
    local b = v.bar
    if type(b) == "table" and b.filled == ns.BAR_CUE_VERSION then return b end   -- (already complete: no walk per frame)
    if type(v.bar) ~= "table" then v.bar = {} end
    Fill(v.bar, ns.BAR_CUE_DEFAULTS)
    v.bar.filled = ns.BAR_CUE_VERSION
    return v.bar
end
function ns.IsBarDisplay(rule) return type(rule) == "table" and type(rule.visual) == "table" and rule.visual.kind == "bar" end

-- A new Bar cue's look (Cues.lua NewCueRule). Only a Bar cue gets a `bar` table; other rules never save one.
function ns.InitBarCue(cue)
    local v = cue.visual
    v.kind = "bar"
    v.w, v.h = 220, 22
    v.keepAspect = false
    v.bg = { enabled = true, color = { 0, 0, 0, 0.2 } }          -- "Background 20%" (Xaya, S8-4)
    v.border = { enabled = true, size = 1, color = { 0, 0, 0, 1 } }
    v.text = v.text or {}
    v.text.enabled, v.text.anchor, v.text.x, v.text.y, v.text.size = true, "RIGHT", -4, 0, 12
    v.count = v.count or {}
    v.count.anchor, v.count.size = "CENTER", 12
    v.bar = Copy(ns.BAR_CUE_DEFAULTS)
end

-------------------------------------------------------------------------------
-- What the bar tracks
-------------------------------------------------------------------------------
local function ExtraRows(p) return (type(p.extra) == "table" and type(p.extra.list) == "table") and p.extra.list or {} end
-- The aura the rule watches (built-in Buff / Aura, else the first aura row), or 0.
function ns.BarAuraSpell(p)
    if type(p) ~= "table" then return 0 end
    local id = tonumber(p.buffID) or 0
    if p.useBuff and id > 0 then return id end
    for _, row in ipairs(ExtraRows(p)) do
        if type(row) == "table" and (row.type == "buffAura" or row.type == "targetDebuff") then
            local rid = tonumber(row.spellID) or 0
            if rid > 0 then return rid end
        end
    end
    if id > 0 then return id end
    return 0
end
function ns.BarCooldownSpell(p) return type(p) == "table" and (tonumber(p.spellID) or 0) or 0 end
local function OwnerOf(cue)
    if cue and cue.parentUid and ns.FindParentRule then return ns.FindParentRule(cue) or cue end
    return cue
end
-- The source a bar uses now: aura | cooldown | stacks | charges. Automatic = the aura when the rule watches one, else the cooldown.
function ns.BarCueSource(cue)
    local b = ns.BarCueSettings(cue and cue.visual)
    local s = b.source
    if s == "aura" or s == "cooldown" or s == "stacks" or s == "charges" then return s end
    local p = OwnerOf(cue)
    if ns.BarAuraSpell(p) > 0 then return "aura" end
    if ns.BarCooldownSpell(p) > 0 then return "cooldown" end
    return "aura"
end
-- The spell whose name, icon and colour the bar shows.
function ns.BarCueSpell(cue)
    local p = OwnerOf(cue)
    local s = ns.BarCueSource(cue)
    if s == "cooldown" or s == "charges" then return ns.BarCooldownSpell(p) end
    return ns.BarAuraSpell(p)
end
-- The full value of a stacks / charges bar: the cue's own number, else the game's (max stacks of the aura / max charges). nil = unknown.
function ns.BarCueMax(cue, cd)
    local b = ns.BarCueSettings(cue and cue.visual)
    local m = tonumber(b.max) or 0
    if m > 0 then return m end
    local s = ns.BarCueSource(cue)
    if s == "stacks" then
        local n = ns.AuraMaxStacks and ns.AuraMaxStacks(ns.BarCueSpell(cue))
        if type(n) == "number" and n > 0 then return n end
        return nil
    elseif s == "charges" then
        local n = cd and cd.max
        if type(n) == "number" and n > 1 then return n end
        return nil
    end
end

-------------------------------------------------------------------------------
-- Colour types, Blizzard's default colours, styles
-------------------------------------------------------------------------------
ns.BAR_DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
ns.BAR_SCHOOLS = { "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }
ns.BAR_TYPES = {}
for _, t in ipairs(ns.BAR_DISPEL_TYPES) do ns.BAR_TYPES[#ns.BAR_TYPES + 1] = t end
for _, t in ipairs(ns.BAR_SCHOOLS) do ns.BAR_TYPES[#ns.BAR_TYPES + 1] = t end
local IS_DISPEL, IS_SCHOOL = {}, {}
for _, t in ipairs(ns.BAR_DISPEL_TYPES) do IS_DISPEL[t] = true end
for _, t in ipairs(ns.BAR_SCHOOLS) do IS_SCHOOL[t] = true end
ns.BAR_TYPE_LABEL = { Magic = "Magic", Curse = "Curse", Disease = "Disease", Poison = "Poison", Bleed = "Bleed",
    Physical = "Physical", Holy = "Holy", Fire = "Fire", Nature = "Nature", Frost = "Frost", Shadow = "Shadow", Arcane = "Arcane" }
local SCHOOL_MASK = { Physical = "MaskPhysical", Holy = "MaskHoly", Fire = "MaskFire", Nature = "MaskNature", Frost = "MaskFrost",
    Shadow = "MaskShadow", Arcane = "MaskArcane" }

ns.BAR_STYLES = { "blizzard", "neon", "pastel", "muted", "custom" }
ns.BAR_STYLE_LABEL = { blizzard = "Blizzard default", neon = "Neon", pastel = "Pastel", muted = "Muted / Dark", custom = "Custom" }

local combatLogTried = false
local function SchoolTable()
    local t = rawget(_G, "COMBATLOG_DEFAULT_COLORS")
    if type(t) ~= "table" and not combatLogTried then
        combatLogTried = true
        local load = (C_AddOns and C_AddOns.LoadAddOn) or rawget(_G, "LoadAddOn")
        if load then pcall(load, "Blizzard_CombatLogBase") end
        t = rawget(_G, "COMBATLOG_DEFAULT_COLORS")
    end
    return type(t) == "table" and type(t.schoolColoring) == "table" and t.schoolColoring or nil
end
-- Blizzard's own colour for a type, read from the game. Returns r, g, b or nil.
function ns.BarBlizzardColor(t)
    if IS_DISPEL[t] then
        local AU = rawget(_G, "AuraUtil")
        if not (AU and AU.GetAuraBorderColor) then return nil end
        local ok, c = pcall(AU.GetAuraBorderColor, t)
        if not (ok and type(c) == "table") then return nil end
        if c.GetRGB then local okr, r, g, b = pcall(c.GetRGB, c); if okr and type(r) == "number" then return r, g, b end end
        if type(c.r) == "number" then return c.r, c.g, c.b end
        return nil
    elseif IS_SCHOOL[t] then
        local sc = SchoolTable()
        local E = Enum and Enum.Damageclass
        local key = E and E[SCHOOL_MASK[t]]
        local c = sc and key ~= nil and sc[key]
        if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
        return nil
    end
end

-- RGB <-> HSV (all 0..1)
local function ToHSV(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn
    local h = 0
    if d > 0 then
        if mx == r then h = ((g - b) / d) % 6
        elseif mx == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, (mx > 0) and (d / mx) or 0, mx
end
local function ToRGB(h, s, v)
    local i = math.floor(h * 6) % 6
    local f = h * 6 - math.floor(h * 6)
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    if i == 0 then return v, t, p elseif i == 1 then return q, v, p elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v elseif i == 4 then return t, p, v end
    return v, p, q
end
-- Each preset keeps the colour's hue (the "same family of colors") and moves only saturation and brightness.
local STYLE_FN = {
    neon = function(s, v) return clamp(s * 1.35 + 0.15, 0, 1), 1 end,
    pastel = function(s, v) return s * 0.45, clamp(v * 0.35 + 0.65, 0, 1) end,
    muted = function(s, v) return s * 0.6, v * 0.7 end,
}
function ns.BarStyleTransform(style, r, g, b)
    local fn = STYLE_FN[style]
    if not fn then return r, g, b end
    local h, s, v = ToHSV(r, g, b)
    s, v = fn(s, v)
    return ToRGB(h, s, v)
end

-- The colour style a Bar cue uses (Xaya, S8-10: "Cue sets it, group overrides if forcibly set"): the nearest group around the cue
-- whose "Force on every bar in this group" is ticked, else the cue's own style. Returns style, custom colours table (or nil), and the
-- forcing group (or nil).
function ns.BarCueStyle(cue)
    local id, guard = cue and cue.folder, 0
    while id and guard < 32 do
        local f = ns.FolderById and ns.FolderById(id)
        if not f then break end
        if f.barStyleForce and ns.BAR_STYLE_LABEL[f.barStyle] then
            return f.barStyle, (type(f.barCustom) == "table") and f.barCustom or nil, f
        end
        id, guard = f.parent, guard + 1
    end
    local b = ns.BarCueSettings(cue and cue.visual)
    local st = ns.BAR_STYLE_LABEL[b.style] and b.style or "blizzard"
    return st, (type(b.custom) == "table") and b.custom or nil, nil
end
-- The colour a type shows in a style: r, g, b, a, or nil when the game gives no colour for it (then: fixed blue).
-- Custom: the type's own picked colour (custom[type]); a type never picked shows Blizzard's colour.
function ns.BarTypeColor(t, style, custom)
    style = style or "blizzard"
    if style == "custom" and type(custom) == "table" then
        local c = custom[t]
        if type(c) == "table" and type(c[1]) == "number" then return c[1], c[2] or 0, c[3] or 0, c[4] or 1 end
    end
    local r, g, b = ns.BarBlizzardColor(t)
    if not r then return nil end
    r, g, b = ns.BarStyleTransform(style, r, g, b)
    return r, g, b, 1
end
local function Hex(r, g, b) return ("%02x%02x%02x"):format(math.floor(clamp(r, 0, 1) * 255 + 0.5), math.floor(clamp(g, 0, 1) * 255 + 0.5), math.floor(clamp(b, 0, 1) * 255 + 0.5)) end
local function TitleWord(w) return w:sub(1, 1):upper() .. w:sub(2):lower() end
-- A type written the way Xaya asked (S8-10): title case, in its colour. "Fire" -> "Fire Damage" in the Fire colour, and a dispel type
-- in brackets after it in the dispel type's colour ("Fire Damage (Magic)"); a dispel type alone: "Magic". style / custom: the cue's.
function ns.BarTypeLabel(t, d, style, custom)
    local out = {}
    if t and IS_SCHOOL[t] then
        local r, g, b = ns.BarTypeColor(t, style, custom)
        out[#out + 1] = r and ("|cff" .. Hex(r, g, b) .. t .. " Damage|r") or (t .. " Damage")
    elseif t and IS_DISPEL[t] and not d then
        d = t
    end
    if d and IS_DISPEL[d] then
        local r, g, b = ns.BarTypeColor(d, style, custom)
        local w = (#out > 0) and ("(" .. d .. ")") or d
        out[#out + 1] = r and ("|cff" .. Hex(r, g, b) .. w .. "|r") or w
    end
    return table.concat(out, " ")
end

-------------------------------------------------------------------------------
-- The type a tooltip names
-------------------------------------------------------------------------------
-- English words only: on another client language nothing matches and the bar falls back (stated to Xaya, S8-4).
local LOWER_SCHOOLS = {}
for _, s in ipairs(ns.BAR_SCHOOLS) do LOWER_SCHOOLS[#LOWER_SCHOOLS + 1] = { s, s:lower() } end
local function Str(x)
    if x == nil or issecret(x) or type(x) ~= "string" then return nil end
    return x
end
-- The school named first in a text: each "<word> damage" in order; a word names the school whose name it contains earliest
-- ("Shadowflame damage" -> Shadow: the first school named, Xaya S8-4).
function ns.BarSchoolInText(text)
    text = Str(text)
    if not text then return nil end
    for word in text:gmatch("(%a+) [Dd]amage") do
        local lw, best, bestAt = word:lower(), nil, nil
        for _, pair in ipairs(LOWER_SCHOOLS) do
            local at = lw:find(pair[2], 1, true)
            if at and (not bestAt or at < bestAt) then best, bestAt = pair[1], at end
        end
        if best then return best end
    end
end
-- The school a damage word names: the school whose name it contains earliest ("Shadowflame" -> Shadow), or nil.
local function SchoolOfWord(word)
    local lw, best, bestAt = word:lower(), nil, nil
    for _, pair in ipairs(LOWER_SCHOOLS) do
        local at = lw:find(pair[2], 1, true)
        if at and (not bestAt or at < bestAt) then best, bestAt = pair[1], at end
    end
    return best
end
-- "<word> damage (<Dispel>)": the dispel type written in brackets right after the damage words (Xaya S8-10), or nil.
local function BracketDispel(text, from)
    local d = text:match("^%s*%((%a+)%)", from)
    if d and IS_DISPEL[TitleWord(d)] then return TitleWord(d) end
end
-- The type a tooltip's lines name, and a dispel type written in brackets after the damage words:
--   the dispel type in the first line's right-hand text (aura tooltips: "Magic"), else the first school named in the rest
--   ("<word> damage", optionally followed by "(Magic)"), else a bracketed dispel type after damage words that name no school.
-- Returns type, whether the tooltip had text to read (false = not loaded yet), the bracketed dispel type.
function ns.BarTypeInTooltip(data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil, false end
    local lines = data.lines
    local any, lone = false, nil
    for i, line in ipairs(lines) do
        if type(line) == "table" then
            local l, r = Str(line.leftText), Str(line.rightText)
            if l or r then any = true end
            if i == 1 then
                if r and IS_DISPEL[r] then return r, true end
            else
                for _, text in ipairs({ l or "", r or "" }) do
                    local pos = 1
                    while true do
                        local st, e, word = text:find("(%a+) [Dd]amage", pos)
                        if not st then break end
                        local school = SchoolOfWord(word)
                        local d = BracketDispel(text, e + 1)
                        if school then return school, true, d end
                        lone = lone or d
                        pos = e + 1
                    end
                end
            end
        end
    end
    if lone then return lone, true, nil end
    return nil, any and #lines > 1
end
local tipType = {}   -- [spellID] = { t = type, d = bracketed dispel } | false (read, names none). Not remembered before the text loads.
function ns.BarTooltipType(spellID, unit, instanceID)
    spellID = tonumber(spellID) or 0
    if spellID <= 0 then return nil end
    local known = tipType[spellID]
    if known ~= nil then if known then return known.t, known.d end return nil end
    local TI = rawget(_G, "C_TooltipInfo")
    if not TI then return nil end
    -- a live aura's tooltip names its dispel type (top right); read it while the game lets addon code see the aura
    if instanceID and TI.GetUnitAuraByAuraInstanceID then
        local ok, data = pcall(TI.GetUnitAuraByAuraInstanceID, unit or "player", instanceID)
        if ok then
            local t, _, d = ns.BarTypeInTooltip(data)
            if t then tipType[spellID] = { t = t, d = d }; return t, d end
        end
    end
    if not TI.GetSpellByID then return nil end
    local ok, data = pcall(TI.GetSpellByID, spellID)
    if not ok then return nil end
    local t, read, d = ns.BarTypeInTooltip(data)
    if t then tipType[spellID] = { t = t, d = d }; return t, d end
    if read and not instanceID then tipType[spellID] = false end
    return nil
end
function ns.BarForgetTooltipTypes() tipType = {} end   -- (tests, /reload-free re-read)

-- The game's tooltips (XayaUI_Bonus Enhanced Tooltips; Xaya S8-10 "Also in game tooltips"): every "<word> damage" whose word names a
-- school becomes "<Word> Damage" in that school's colour, and a dispel type in brackets right after it takes its dispel colour.
-- wholeIsDispel: the text is the dispel type alone (an aura tooltip's top right). Blizzard's own colours, read from the game. A word
-- right after a "|" (inside a colour code) is left alone. Returns the new text (the same text when nothing matched).
function ns.BarColorizeTypes(text, wholeIsDispel)
    text = Str(text)
    if not text then return nil end
    if wholeIsDispel then
        if IS_DISPEL[text] then
            local r, g, b = ns.BarTypeColor(text)   -- (not `d and ns.BarTypeColor(d)`: `and` keeps only the first value)
            if r then return "|cff" .. Hex(r, g, b) .. text .. "|r" end
        end
        return text
    end
    if not text:find("[Dd]amage") then return text end
    local out, pos, changed = {}, 1, false
    while true do
        local st, e, word = text:find("(%a+) [Dd]amage", pos)
        if not st then break end
        local school = (st == 1 or text:sub(st - 1, st - 1) ~= "|") and SchoolOfWord(word) or nil
        out[#out + 1] = text:sub(pos, st - 1)
        if school then
            local r, g, b = ns.BarTypeColor(school)
            local label = TitleWord(word) .. " Damage"
            out[#out + 1] = r and ("|cff" .. Hex(r, g, b) .. label .. "|r") or label
            pos = e + 1
            local sp, word2, close = text:match("^(%s*)%((%a+)%)()", pos)
            local dd = word2 and IS_DISPEL[TitleWord(word2)] and TitleWord(word2)
            if dd then
                local r2, g2, b2 = ns.BarTypeColor(dd)
                out[#out + 1] = sp .. (r2 and ("|cff" .. Hex(r2, g2, b2) .. "(" .. dd .. ")|r") or ("(" .. dd .. ")"))
                pos = close
            end
            changed = true
        else
            out[#out + 1] = text:sub(st, e)
            pos = e + 1
        end
    end
    if not changed then return text end
    out[#out + 1] = text:sub(pos)
    return table.concat(out)
end

-- The game's dispel type of a live aura, when addon code may read it (out of combat). nil = unknown or none.
function ns.BarAuraDispelType(unit, instanceID)
    if not (instanceID and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then return nil end
    local ok, a = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit or "player", instanceID)
    if not (ok and type(a) == "table") then return nil end
    local okd, d = pcall(function() return a.dispelName end)
    d = okd and Str(d) or nil
    if d and IS_DISPEL[d] then return d end
    return nil
end

-- The bar's colour: r, g, b, a, where it came from ("fixed" | "tooltip" | "dispel" | "fallback"), the type, a bracketed dispel type.
-- Order (Xaya, S8-4 "Tooltip first"): the type the tooltip names > the game's dispel type of the aura > fixed blue.
-- The type colours are drawn in the cue's style (ns.BarCueStyle: the cue's own, or that of a group that forces one).
function ns.BarCueColor(cue, ref)
    local b = ns.BarCueSettings(cue and cue.visual)
    if b.colorMode == "fixed" then
        local c = b.color or ns.BAR_FALLBACK_COLOR
        return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1, "fixed"
    end
    local style, custom = ns.BarCueStyle(cue)
    local spell = ns.BarCueSpell(cue)
    local src = ns.BarCueSource(cue)
    local aura = (src == "aura" or src == "stacks")
    local t, d = ns.BarTooltipType(spell, ref and ref.unit, aura and ref and ref.instanceID or nil)
    if t then
        local r, g, bl, a = ns.BarTypeColor(t, style, custom)
        if r then return r, g, bl, a, "tooltip", t, d end
    end
    if aura and ref then
        local dt = ns.BarAuraDispelType(ref.unit, ref.instanceID)
        if dt then
            local r, g, bl, a = ns.BarTypeColor(dt, style, custom)
            if r then return r, g, bl, a, "dispel", dt end
        end
    end
    local c = ns.BAR_FALLBACK_COLOR
    return c[1], c[2], c[3], c[4], "fallback"
end
-- For the combat engine's aura buttons: the dispel-type colours in the cue's style, keyed the way the game's aura button keys them
-- (Blizzard_CustomAuraButton.lua GetDispelTypeMapKey: dispelName or "None"); "None" = the fixed blue.
function ns.BarDispelColorMap(cue)
    if not CreateColor then return nil end
    local style, custom = ns.BarCueStyle(cue)
    local map = {}
    for _, t in ipairs(ns.BAR_DISPEL_TYPES) do
        local r, g, b = ns.BarTypeColor(t, style, custom)
        local c = r and { r, g, b } or ns.BAR_FALLBACK_COLOR
        map[t] = CreateColor(c[1], c[2], c[3], 1)
    end
    local f = ns.BAR_FALLBACK_COLOR
    map.None = CreateColor(f[1], f[2], f[3], 1)
    return map
end
-- A short signature of a cue's colour style (the engine bakes the colours into its buttons: a change makes a new slot).
function ns.BarStyleSig(cue)
    local style, custom, f = ns.BarCueStyle(cue)
    local p = { style, f and f.id or "" }
    if style == "custom" and type(custom) == "table" then
        for _, t in ipairs(ns.BAR_TYPES) do
            local c = custom[t]
            p[#p + 1] = type(c) == "table" and (tostring(c[1]) .. "," .. tostring(c[2]) .. "," .. tostring(c[3])) or "-"
        end
    end
    return table.concat(p, ";")
end

-------------------------------------------------------------------------------
-- Textures
-------------------------------------------------------------------------------
local BUILTIN_TEX = {
    flat = { "Flat", "Interface\\Buttons\\WHITE8X8" },
    blizz = { "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
    raid = { "Raid frame", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
}
local BUILTIN_ORDER = { "flat", "blizz", "raid" }
-- The game's own bar art (Xaya S8-12 "Add Blizzard power-bar art"): read at run time from Blizzard's PowerBarColor table
-- (Blizzard_UnitFrame/Mainline/PowerBarColorUtil.lua, 12.1.5): an entry's `atlas`, or for an `atlasElementName` the name the player
-- frame builds from it, "UI-HUD-UnitFrame-Player-PortraitOn-Bar-<element>" (UnitFrame.lua / AlternatePowerBarBase.lua), plus the
-- player frame's health bar. An atlas the game does not know (C_Texture.GetAtlasInfo) is left out. Nothing is copied into this file.
local function Title(key)
    return (tostring(key):lower():gsub("_", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end
local function AtlasKnown(name)
    local CT = rawget(_G, "C_Texture")
    if not (CT and CT.GetAtlasInfo) then return true end   -- (cannot check: kept; a missing atlas draws nothing, it never errors)
    local ok, info = pcall(CT.GetAtlasInfo, name)
    return ok and info ~= nil
end
function ns.BarBlizzardAtlases()
    local out, seen = {}, {}
    local function add(label, name)
        if type(name) ~= "string" or name == "" or seen[name] or not AtlasKnown(name) then return end
        seen[name] = true
        out[#out + 1] = { label, name }
    end
    add("Health", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health")
    local PBC = rawget(_G, "PowerBarColor")
    if type(PBC) == "table" then
        local keys = {}
        for k, info in pairs(PBC) do if type(k) == "string" and type(info) == "table" then keys[#keys + 1] = k end end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local info = PBC[k]
            if type(info.atlas) == "string" then add(Title(k), info.atlas)
            elseif type(info.atlasElementName) == "string" then add(Title(k), "UI-HUD-UnitFrame-Player-PortraitOn-Bar-" .. info.atlasElementName) end
        end
    end
    return out
end
-- XayaUI's own bar art (Xaya S8-12 "Add XayaUI's own bar art"): the "[Bar Fills]" pictures of LocalGraphics.lua whose name says they
-- are a fill ("..._Fill", "...-fill", "...BarHorizontal"); sparks, frames, backgrounds and flashes are not bar fills. These files are
-- listed from XayaUI\Media\Graphics on Xaya's install; the repository does not hold them (issue #333), so on another install they draw
-- nothing until they are added.
function ns.BarXayaFills()
    local out = {}
    for _, g in ipairs(ns.LocalGraphics or {}) do
        local label, path = g[1], g[2]
        if type(label) == "string" and type(path) == "string" then
            local nm = label:match("^%[Bar Fills%]%s*(.+)$")
            local l = nm and nm:lower()
            if l and (l:find("_fill$") or l:find("%-fill$") or l:find("barhorizontal$")) then out[#out + 1] = { nm, path } end
        end
    end
    return out
end
-- XayaUI's bar fills offered to every addon that reads LibSharedMedia "statusbar" (S8-12), as "XayaUI <name>". Once per session.
local lsmDone
function ns.BarRegisterLSM()
    if lsmDone then return 0 end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not lsm then return 0 end
    lsmDone = true
    local n = 0
    for _, e in ipairs(ns.BarXayaFills()) do
        if pcall(lsm.Register, lsm, "statusbar", "XayaUI " .. e[1], e[2]) then n = n + 1 end
    end
    return n
end
if ns.AtLogin then ns.AtLogin(function() pcall(ns.BarRegisterLSM) end) end

local function Norm(p) return type(p) == "string" and p:gsub("/", "\\"):lower() or tostring(p) end
-- The Bar texture list: XayaUI's three (Flat, Blizzard, Raid frame), the game's power-bar art, XayaUI's bar fills, every
-- LibSharedMedia status-bar texture, your own file. A texture already listed (same file) is listed once (Xaya S8-12 "Fix
-- duplicates": LibSharedMedia's own defaults are the same game files as Flat / Blizzard / Raid frame, and XayaUI's fills are
-- registered there too).
function ns.BarTextureList()
    local values, order, seen = {}, {}, {}
    local function add(key, label, path)
        if path then
            local np = Norm(path)
            if seen[np] then return end
            seen[np] = true
        end
        values[key] = label; order[#order + 1] = key
    end
    for _, k in ipairs(BUILTIN_ORDER) do add(k, BUILTIN_TEX[k][1], BUILTIN_TEX[k][2]) end
    for _, e in ipairs(ns.BarBlizzardAtlases()) do add("atlas:" .. e[2], "Blizzard power: " .. e[1], "atlas:" .. e[2]) end
    for _, e in ipairs(ns.BarXayaFills()) do add("gfx:" .. e[2], "XayaUI: " .. e[1], e[2]) end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm then
        local names = {}
        for n in pairs(lsm:HashTable("statusbar")) do names[#names + 1] = n end
        table.sort(names)
        for _, n in ipairs(names) do
            local okp, p = pcall(lsm.Fetch, lsm, "statusbar", n, true)
            add("lsm:" .. n, n, okp and p or nil)
        end
    end
    add("file", "Texture ID / path...")
    return values, order
end
function ns.BarTexturePath(b)
    local key = b and b.texture or "flat"
    if BUILTIN_TEX[key] then return BUILTIN_TEX[key][2] end
    if key == "file" then
        local p = tostring(b.texFile or ""):gsub("/", "\\")
        if p ~= "" then return tonumber(p) or p end
        return BUILTIN_TEX.flat[2]
    end
    if type(key) == "string" then
        local atlas = key:match("^atlas:(.+)$")
        if atlas then return atlas end   -- (SetStatusBarTexture takes an atlas name, as Blizzard's own unit frames call it)
        local gfx = key:match("^gfx:(.+)$")
        if gfx then return gfx end
    end
    local n = type(key) == "string" and key:match("^lsm:(.+)$")
    local lsm = n and LibStub and LibStub("LibSharedMedia-3.0", true)
    local p = lsm and lsm:Fetch("statusbar", n, true)
    return p or BUILTIN_TEX.flat[2]
end

-- dir -> StatusBar orientation, reverse fill. "left" = the fill shrinks toward the left edge (drains right to left).
ns.BAR_ORIENT = { left = { "HORIZONTAL", false }, right = { "HORIZONTAL", true }, bottom = { "VERTICAL", false }, top = { "VERTICAL", true } }
function ns.BarOrient(b)
    local o = ns.BAR_ORIENT[b and b.dir or "left"] or ns.BAR_ORIENT.left
    return o[1], o[2]
end
-- Where the spark sits on the fill texture: its moving edge.
function ns.BarSparkPoint(b)
    local orient, rev = ns.BarOrient(b)
    if orient == "HORIZONTAL" then return rev and "LEFT" or "RIGHT" end
    return rev and "BOTTOM" or "TOP"
end
-- The icon square and the bar's rectangle inside a w x h display: icon side "left" | "right" | nil. Returns iconSize, bar insets.
function ns.BarGeometry(b, w, h)
    local side = b and b.icon
    if side ~= "left" and side ~= "right" then return 0, 0, 0 end
    local orient = ns.BarOrient(b)
    local s = (orient == "HORIZONTAL") and h or w
    s = math.min(s, (orient == "HORIZONTAL") and w or h)
    if side == "left" then return s, s, 0 end
    return s, 0, s
end

-------------------------------------------------------------------------------
-- XayaUI's own drawing (Visual.lua display frame)
-------------------------------------------------------------------------------
local SPARK_TEX = "Interface\\CastingBar\\UI-CastingBar-Spark"
local function TimerDir(reverse)
    local E = Enum and Enum.StatusBarTimerDirection
    if reverse then return E and E.ElapsedTime or 0 end
    return E and E.RemainingTime or 1
end
local function Immediate()
    local E = Enum and Enum.StatusBarInterpolation
    return E and E.Immediate or 0
end
local function Parts(fr)
    if fr.barF then return fr.barF end
    local bar = CreateFrame("StatusBar", nil, fr)
    bar:SetFrameLevel(fr:GetFrameLevel() + 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local icon = fr:CreateTexture(nil, "ARTWORK", nil, 2)
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(SPARK_TEX)
    spark:SetBlendMode("ADD")
    local holder = fr.txtHolder or fr
    local name = holder:CreateFontString(nil, "OVERLAY", nil, 7)
    name:SetFontObject(GameFontNormal)
    fr.barF, fr.barIcon, fr.barSpark, fr.barName = bar, icon, spark, name
    return bar
end
-- Hide the bar parts of a frame whose display is not a bar.
function ns.BarCueHide(fr)
    if not fr.barF then return end
    fr.barF:Hide(); fr.barIcon:Hide(); fr.barName:Hide()
end

-- Static look: after every settings change (Visual.lua RefreshVisual).
function ns.BarCueLayout(fr, rule, v)
    local b = ns.BarCueSettings(v)
    local bar = Parts(fr)
    fr.tex:Hide(); fr.tex2:Hide()
    local w, h = math.max(8, v.w or 220), math.max(8, v.h or 22)
    local iconS, l, r = ns.BarGeometry(b, w, h)
    local orient, rev = ns.BarOrient(b)
    bar:ClearAllPoints()
    if orient == "HORIZONTAL" then
        bar:SetPoint("TOPLEFT", fr, "TOPLEFT", l, 0)
        bar:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -r, 0)
    else
        bar:SetPoint("TOPLEFT", fr, "TOPLEFT", 0, -l)
        bar:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", 0, r)
    end
    bar:SetStatusBarTexture(ns.BarTexturePath(b))
    bar:SetOrientation(orient)
    bar:SetReverseFill(rev and true or false)
    bar:Show()
    -- icon
    local ic = fr.barIcon
    ic:ClearAllPoints()
    if iconS > 0 then
        ic:SetSize(iconS, iconS)
        local pt
        if orient == "HORIZONTAL" then pt = (b.icon == "left") and "LEFT" or "RIGHT"
        else pt = (b.icon == "left") and "TOP" or "BOTTOM" end
        ic:SetPoint(pt, fr, pt, 0, 0)
        local spell = ns.BarCueSpell(rule)
        local ok, t = pcall(C_Spell.GetSpellTexture, spell)
        ic:SetTexture((ok and t) or 134400)
        ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ic:Show()
    else
        ic:Hide()
    end
    -- spark on the fill's moving edge (anchored to the fill texture, so it follows a bar the game drives too)
    local sp = fr.barSpark
    sp:ClearAllPoints()
    if b.spark and b.spark.enabled then
        local fill = bar:GetStatusBarTexture()
        local sw = math.max(1, tonumber(b.spark.w) or 12)
        local bw, bh = math.max(1, w - iconS), h
        if orient == "VERTICAL" then bw, bh = w, math.max(1, h - iconS) end
        if orient == "HORIZONTAL" then sp:SetSize(sw, bh * 2.2); pcall(sp.SetRotation, sp, 0)
        else sp:SetSize(bw * 2.2, sw); pcall(sp.SetRotation, sp, math.rad(90)) end
        if fill then sp:SetPoint("CENTER", fill, ns.BarSparkPoint(b), 0, 0) end
        local c = b.spark.color or { 1, 1, 1, 0.9 }
        sp:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
        sp:Show()
    else
        sp:Hide()
    end
    -- name text
    local nm = b.name or {}
    if nm.enabled then
        if ns.StyleTextOn then ns.StyleTextOn(fr.barName, bar, nm, "LEFT") end
        local okn, s = pcall(C_Spell.GetSpellName, ns.BarCueSpell(rule))
        fr.barName:SetText((okn and s) or "")
        fr.barName:Show()
    else
        fr.barName:Hide()
    end
    fr.barColorKey = nil
end

local function Paint(fr, rule, ref)
    local r, g, b, a, why, t = ns.BarCueColor(rule, ref)
    if fr.barCR ~= r or fr.barCG ~= g or fr.barCB ~= b or fr.barCA ~= a then
        fr.barCR, fr.barCG, fr.barCB, fr.barCA = r, g, b, a
        fr.barF:SetStatusBarColor(r, g, b, a)
    end
    fr.barColorWhy, fr.barColorType = why, t
end

-- (file-level helpers: no closure is made per step or per rendered frame)
local function SetValue(fr, b, x, applyReverse)
    x = clamp(x, 0, 1)
    if applyReverse and b.reverse then x = 1 - x end
    local bar = fr.barF
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(x)
    fr.barSpark:SetShown((b.spark and b.spark.enabled and x > 0.002 and x < 0.998) and true or false)
    fr.barTimed = nil
end
local function SetTimer(fr, b, dur)
    if not dur then return false end
    local bar = fr.barF
    local ok = pcall(bar.SetTimerDuration, bar, dur, Immediate(), TimerDir(b.reverse))
    if ok then
        fr.barTimed = true
        fr.barSpark:SetShown((b.spark and b.spark.enabled) and true or false)
    end
    return ok
end

-- Per step (Visual.lua UpdateVisualText): the value. f = the readable remaining fraction of the aura (or the preview's sample),
-- nil when the game hides it. fxOnly = a smooth-animation frame between steps (only the value moves; the colour is kept).
-- Returns true while the bar moves on XayaUI's clock (the effects loop keeps it smooth); a bar the game drives returns false.
function ns.BarCueUpdate(fr, rule, v, info, ref, f, sample, fxOnly)
    if not fr.barF then return false end
    local b = ns.BarCueSettings(v)
    if not fxOnly then Paint(fr, rule, ref) end
    local src = ns.BarCueSource(rule)
    if src == "aura" then
        if f ~= nil then SetValue(fr, b, f, true); return true end
        if fxOnly then return false end
        if ref and ref.instanceID and C_UnitAuras and C_UnitAuras.GetAuraDuration then
            local ok, d = pcall(C_UnitAuras.GetAuraDuration, ref.unit or "player", ref.instanceID)
            if ok and d and SetTimer(fr, b, d) then return false end
        end
        SetValue(fr, b, 0, true)   -- the time cannot be read: an empty bar, never a guessed one
        return false
    elseif src == "cooldown" then
        if sample and f ~= nil and not (info and info.cd and info.cd.onCd) then SetValue(fr, b, f, true); return true end   -- preview sample
        if fxOnly then return false end
        local dur = ns.CooldownDurationOf and ns.CooldownDurationOf(rule, info and info.cd)
        if dur and SetTimer(fr, b, dur) then return false end
        -- ready, or the cooldown cannot be read: no time remaining (the timer's own end state: empty, or full when reversed)
        SetValue(fr, b, 0, true)
        return false
    end
    if fxOnly then return false end
    -- stacks / charges: a value out of the bar's full value (reverse does not apply to a count: 3 of 5 fills three fifths)
    local cd = info and info.cd
    local mx = ns.BarCueMax(rule, cd)
    local cur
    if src == "stacks" then
        local a = ref and ref.applications
        if type(a) == "number" and not issecret(a) then cur = a end
    else
        local n = cd and cd.count
        if type(n) == "number" and not issecret(n) then cur = n end
    end
    if sample and cur == nil then cur, mx = 3, mx or 5 end   -- preview sample (like the count text's sample "3")
    if cur and mx and mx > 0 then SetValue(fr, b, cur / mx, false) else SetValue(fr, b, 0, false) end
    return false
end
