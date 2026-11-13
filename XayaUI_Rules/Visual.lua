-------------------------------------------------------------------------------
-- Visual.lua : one texture frame per rule, shown/hidden by the engine.
-- Rotation / mirror / flip, recolor, border, background, pulsing glow ring,
-- shape-following OUTLINE glow (1-10 px, color, pulse), fade-to-gray as the
-- buff runs out, desaturate on cooldown, buff-duration text, stacks/charges text.
-- Shown as a draggable sample while the mover (XayaUI Options, Mover.lua) unlocks it; its saved position and anchors are here.
-------------------------------------------------------------------------------
local addonName, ns = ...; ns = XayaUI_NS or ns -- (P4) XayaUI Rules shares the Platform's namespace (XayaUI/Core.lua)
local CoreS, PlatS = ns.Settings("core"), ns.Settings("platform")   -- (core 0.6.75, P2 settings seam: the same CueRulesDB keys as before; Modules.lua section 0b)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("core", "XayaUI_Rules", "XayaUIRulesDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)

local frames = setmetatable({}, { __mode = "k" }) -- rule -> frame
-- (bundle 1 round 7, REQUEST-LOG A23 SD-58, her words: "mover view only available when settings window is open"; V34) The mover is
-- XayaUI Options' Mover.lua, read only when the settings window's code loads. What stays here is what a display reads to show itself as
-- a draggable sample: ns.unlocked (the whole mover is open), ns.moveUnlocked (one rule's own movement unlock, from its sidebar row) and
-- ns.groupUnlocked (below). Only the mover writes them, and only while the settings window is open; session only, never saved.
ns.unlocked = false
ns.moveUnlocked = {}
local function Unl(rule) return (ns.unlocked or ns.moveUnlocked[rule]) and true or false end
function ns.IsMoveUnlocked(rule) return Unl(rule) end
-- The seam to the mover: XayaUI Options' Mover.lua sets ns.MoverDisplay to its handlers when the settings window's code loads (false
-- until then): a display's mouse and look in the mover, the display menu's entries, and the mover's on / off. The four names below are
-- this addon's: the settings window calls them (Lock Positions, the sidebar's lock icons), the "rules" service names ns.ToggleUnlock
-- (RuleDefaults.lua), and the combat engine follows each of them (Combat/AuraDisplay.lua hooks them at load: its aura containers step
-- aside for the mover's samples). Each only forwards to the mover, and does nothing while the mover is not loaded.
ns.MoverDisplay = false
function ns.ToggleUnlock(...) local M = ns.MoverDisplay; if M then return M.ToggleUnlock(...) end end
function ns.MoverExit(...) local M = ns.MoverDisplay; if M then return M.MoverExit(...) end end
function ns.SetMoveUnlocked(...) local M = ns.MoverDisplay; if M then return M.SetMoveUnlocked(...) end end
function ns.SetGroupUnlocked(...) local M = ns.MoverDisplay; if M then return M.SetGroupUnlocked(...) end end
-- D7 (core 0.6.56; Xaya 2026-11-06, her answer "Accept 1-3" + preview "Still works"): a rule that is switched off, or a cue of one, costs
-- nothing: the engine skips it after a one-time clean-up (Engine.lua Step), it never gets a display frame and its frame is freed when it is
-- switched off (here), and the Disabled tab still lists it. Only a preview (the sidebar eye) draws it, and only while previewed.
-- parents: optional uid -> parent map (built once by callers that walk every rule; FindParentRule is a scan outside an engine step).
function ns.RuleOff(rule, parents)
    if not rule then return true end
    if not rule.enabled then return true end
    local uid = rule.parentUid
    if type(uid) == "string" and uid ~= "" then
        local p
        if parents then p = parents[uid] elseif ns.FindParentRule then p = ns.FindParentRule(rule) end
        if p and not p.enabled then return true end
    end
    return false
end
-- Group movement (session only): unlocking a GROUP row shows one draggable outline around the whole group instead of unlocking
-- (and making selectable) every display inside it. ns.groupUnlocked[folderId] = true while that group is unlocked.
ns.groupUnlocked = {}
local function InFolder(fid, rootId)   -- is folder fid the folder rootId, or nested somewhere inside it?
    local id, guard = fid, 0
    while id and guard < 32 do
        if id == rootId then return true end
        local f = ns.FolderById(id)
        if not f then return false end
        id, guard = f.parent, guard + 1
    end
    return false
end
local function GroupUnl(rule)   -- the rule's display is shown (as a sample) because a group around it is unlocked; it is NOT draggable on its own
    if not rule.folder or not next(ns.groupUnlocked) then return false end
    local id, guard = rule.folder, 0
    while id and guard < 32 do
        if ns.groupUnlocked[id] then return true end
        local f = ns.FolderById(id)
        if not f then return false end
        id, guard = f.parent, guard + 1
    end
    return false
end
function ns.IsGroupUnlocked(f) return f and ns.groupUnlocked[f.id] and true or false end

-------------------------------------------------------------------------------
-- Preview state (transient, never saved). Keyed by rule / bar object.
-------------------------------------------------------------------------------
ns.previewSets = { visual = setmetatable({}, { __mode = "k" }), sound = setmetatable({}, { __mode = "k" }) }
function ns.IsPreview(obj, kind) return ns.previewSets[kind][obj] and true or false end
function ns.SetPreview(objs, kind, on)
    for _, o in ipairs(objs) do ns.previewSets[kind][o] = on or nil end
    if ns.MarkDirty then ns.MarkDirty() end
end
function ns.ClearPreview()
    for _, set in pairs(ns.previewSets) do for k in pairs(set) do set[k] = nil end end
    if ns.MarkDirty then ns.MarkDirty() end
end
-- Pause switch for previews: freezes the sample countdown and the flash pulse while the images stay on screen.
local pauseAt, pausedTotal = nil, 0
ns.previewPaused = false
function ns.SampleTime() return (pauseAt or GetTime()) - pausedTotal end
function ns.SetPreviewPaused(on)
    on = on and true or false
    if on == ns.previewPaused then return end
    ns.previewPaused = on
    if on then pauseAt = GetTime()
    else pausedTotal = pausedTotal + (GetTime() - (pauseAt or GetTime())); pauseAt = nil end
    if ns.MarkDirty then ns.MarkDirty() end
end
function ns.AnyPreview()
    for _, set in pairs(ns.previewSets) do if next(set) then return true end end
    return false
end

local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

-------------------------------------------------------------------------------
-- Texture coordinates: crop/base rect + mirror/flip + rotation about center.
-- The image is scaled by (|cos|+|sin|) so a square texture stays fully visible.
-------------------------------------------------------------------------------
-- Display box vs art box: the display (v.w x v.h) is the frame; the art (v.iconW x v.iconH, 0 = same as the display) is centered in it.
-- Where the art is larger than the display on an axis only the middle part is shown (fx / fy = the shown fraction of the art, 1 = all of it);
-- where it is smaller, the art is drawn smaller than the frame (bw x bh).
local function ArtBox(v)
    local W, H = math.max(8, v.w or 128), math.max(8, v.h or 128)
    local iw, ih = tonumber(v.iconW) or 0, tonumber(v.iconH) or 0
    if iw <= 0 then iw = W end
    if ih <= 0 then ih = H end
    local bw, bh = math.min(W, iw), math.min(H, ih)
    return W, H, bw, bh, bw / iw, bh / ih
end
-- How far the art sits inside the display on each side (0 when it fills or is cropped): the combat engine insets its slots' art with it.
function ns.ArtInset(v)
    local W, H, bw, bh = ArtBox(v or {})
    return (W - bw) / 2, (H - bh) / 2
end
local function ApplyCoords(tex, v, base)
    local _, _, _, _, fx, fy = ArtBox(v)
    local l, r, t, b = base[1], base[2], base[3], base[4]
    local cx, cy, hw, hh = (l + r) / 2, (t + b) / 2, (r - l) / 2, (b - t) / 2
    local rad = math.rad(v.rotation or 0)
    local c, s = math.cos(rad), math.sin(rad)
    local fit = (v.rotation or 0) % 360 == 0 and 1 or (math.abs(c) + math.abs(s))
    local sx = v.flipH and -1 or 1
    local sy = v.flipV and -1 or 1
    local function pt(qx, qy)
        qx, qy = qx * fx, qy * fy
        local ix = (qx * c + qy * s) * fit * sx
        local iy = (-qx * s + qy * c) * fit * sy
        return cx + ix * hw, cy - iy * hh
    end
    local ulx, uly = pt(-1, 1)
    local llx, lly = pt(-1, -1)
    local urx, ury = pt(1, 1)
    local lrx, lry = pt(1, -1)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
    tex.xuiUV = { ulx, uly, llx, lly, urx, ury, lrx, lry }
end

-- Progress-bar wipe: show only the sub-rectangle [x0,x1] x [y0,y1] of the frame (fractions, y from the bottom)
-- and the matching part of the picture (the texture mapping is affine, so corners interpolate exactly).
local function UVAt(uv, a, b)
    local llx, lly = uv[3], uv[4]
    return llx + a * (uv[7] - llx) + b * (uv[1] - llx), lly + a * (uv[8] - lly) + b * (uv[2] - lly)
end
local function CropTex(tex, fr, x0, x1, y0, y1)
    local uv = tex.xuiUV
    if not uv then return end
    local W, H, ix, iy = fr:GetWidth(), fr:GetHeight(), 0, 0
    local bx = tex.xuiBox   -- the art may be smaller than the frame (Icon width / height): the wipe runs over the art
    if bx then ix, iy, W, H = bx[1], bx[2], bx[3], bx[4] end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", fr, "TOPLEFT", ix + x0 * W, -(iy + (1 - y1) * H))
    tex:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -(ix + (1 - x1) * W), iy + y0 * H)
    local ulx, uly = UVAt(uv, x0, y1)
    local llx, lly = UVAt(uv, x0, y0)
    local urx, ury = UVAt(uv, x1, y1)
    local lrx, lry = UVAt(uv, x1, y0)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
    tex.xuiCropped = true
end
local function UncropTex(tex, fr)
    if not tex.xuiCropped then return end
    tex.xuiCropped = false
    tex:ClearAllPoints()
    local bx = tex.xuiBox
    if bx then
        tex:SetPoint("TOPLEFT", fr, "TOPLEFT", bx[1], -bx[2])
        tex:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -bx[1], bx[2])
    else
        tex:SetAllPoints(fr)
    end
    local uv = tex.xuiUV
    if uv then tex:SetTexCoord(uv[1], uv[2], uv[3], uv[4], uv[5], uv[6], uv[7], uv[8]) end
end

-- Put a texture where the art goes inside the display frame (centered art box; dx / dy shift it, used by the outline copies).
local function AnchorArt(tex, fr, v, dx, dy)
    local W, H, bw, bh = ArtBox(v)
    local ix, iy = (W - bw) / 2, (H - bh) / 2
    dx, dy = dx or 0, dy or 0
    tex.xuiCropped = false
    tex.xuiBox = (ix > 0 or iy > 0) and { ix, iy, bw, bh } or nil
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", fr, "TOPLEFT", ix + dx, -iy + dy)
    tex:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -ix + dx, iy + dy)
end

local function AtlasBase(name)
    local ok, info = false, nil   -- (C_Texture checked first: indexing a missing table is outside the pcall)
    if C_Texture and C_Texture.GetAtlasInfo then ok, info = pcall(C_Texture.GetAtlasInfo, name) end
    if ok and type(info) == "table" and info.leftTexCoord then
        return { info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord }
    end
    return { 0, 1, 0, 1 }
end

-- The art's own proportions (width / height), for "Maintain aspect ratio" (Options.lua). Zoom and the icon edge crop take the
-- same fraction off every side, so they keep the proportions. nil when the game cannot tell: it has no way to report the size
-- of a numeric file ID (the Blizzard alert art) or of a file path that is not in the graphics lists.
local function GraphicSize(path)
    path = tostring(path or ""):gsub("/", "\\"):lower()
    for _, g in ipairs(ns.LocalGraphics or {}) do
        if tostring(g[2]):lower() == path then return tonumber(g[3]), tonumber(g[4]) end
    end
end
function ns.ArtNativeRatio(v)
    v = v or {}
    local kind, w, h = ns.Val(v.kind), nil, nil
    if kind == "spellicon" then
        if (v.iconSrc or "auto") == "file" then w, h = GraphicSize(v.iconPath) end
        if not w then return 1 end   -- game icons are square (and your own icon files are required to be)
    elseif kind == "atlas" and v.tex and v.tex ~= "" then
        local ok, info = false, nil   -- (C_Texture checked first: indexing a missing table is outside the pcall)
        if C_Texture and C_Texture.GetAtlasInfo then ok, info = pcall(C_Texture.GetAtlasInfo, v.tex) end
        if ok and type(info) == "table" then w, h = tonumber(info.width), tonumber(info.height) end
    elseif kind and v.tex and v.tex ~= "" and not tonumber(v.tex) then
        w, h = GraphicSize(v.tex)
    end
    if w and h and w > 0 and h > 0 then return w / h end
end

-- Icon source for icon rules (v.iconSrc): auto = the first trigger's spell/item; spell / item = an ID chosen on the cue;
-- file = a picture the user supplied (a path inside an AddOns folder; should be square, at most 200x200).
local function IconTexture(rule, v)
    local src = v.iconSrc or "auto"
    if src == "file" then
        local p = tostring(v.iconPath or ""):gsub("/", "\\")
        if p == "" then return nil, true end
        return tonumber(p) or p, true
    elseif src == "spell" then
        local ok, t = pcall(C_Spell.GetSpellTexture, tonumber(v.iconSpell) or 0)
        return ok and t or nil
    elseif src == "item" then
        local ok, t = pcall(C_Item.GetItemIconByID, tonumber(v.iconItem) or 0)
        return ok and t or nil
    end
    local sid = tonumber(rule.spellID) or 0
    if sid == 0 then sid = tonumber(rule.buffID) or 0 end   -- an old-style icon rule that owns its own spell
    if sid ~= 0 then local ok, t = pcall(C_Spell.GetSpellTexture, sid); if ok and t then return t end end
    local parent = rule.parentUid and ns.FindParentRule and ns.FindParentRule(rule) or nil
    if ns.TriggerIcon then return (ns.TriggerIcon(parent or rule)) end
end
ns.IconTexture = IconTexture

-- Paint the rule's art onto any texture (main image and the outline copies).
local function SetArt(tex, rule, v)
    local base = { 0, 1, 0, 1 }
    local kind = ns.Val(v.kind)
    if kind == "spellicon" then
        local t, custom = IconTexture(rule, v)
        tex:SetTexture(t or 134400)   -- question mark until something resolves
        local z = (custom and 0 or 0.08) + clamp(v.zoom or 0, 0, 0.3)   -- game icons have a baked-in border (crop 8%); your own art is shown whole
        base = { z, 1 - z, z, 1 - z }
    elseif kind and v.tex and v.tex ~= "" then
        if kind == "atlas" then
            pcall(tex.SetAtlas, tex, v.tex, false)
            base = AtlasBase(v.tex)
        else
            pcall(tex.SetAtlas, tex, nil)
            tex:SetTexture(tonumber(v.tex) or v.tex)
            local z = clamp(v.zoom or 0, 0, 0.3)
            base = { z, 1 - z, z, 1 - z }
        end
    else
        tex:SetTexture(nil)
        return
    end
    ApplyCoords(tex, v, base)
end

function ns.ApplyTexture(tex, v) SetArt(tex, { spellID = 0 }, v) end
-- Paint a display's own art (kind, texture / atlas / spell icon, zoom, rotation, mirror, tint, desaturation) onto any texture:
-- the combat engine uses it so its icons look exactly like XayaUI's.
function ns.PaintDisplayArt(tex, rule)
    local v = rule.visual or {}
    SetArt(tex, rule, v)
    local t = v.tint or { 1, 1, 1, 1 }
    tex:SetVertexColor(t[1] or 1, t[2] or 1, t[3] or 1, t[4] or 1)
    pcall(tex.SetDesaturation, tex, v.desaturate and 1 or 0)
end

-- The overlay layer: same art as the base, or its own art (sharing the base's zoom / rotation / mirror).
local function SetOverlayArt(tex, rule, v)
    local o = v.overlay or {}
    if ns.Val(o.source) == "other" then
        SetArt(tex, rule, { kind = o.kind, tex = o.tex, zoom = v.zoom, rotation = v.rotation, flipH = v.flipH, flipV = v.flipV, w = v.w, h = v.h, iconW = v.iconW, iconH = v.iconH })
    else
        SetArt(tex, rule, v)
    end
end

-------------------------------------------------------------------------------
-- Text helpers
-------------------------------------------------------------------------------
local OUTLINE = { none = "", outline = "OUTLINE", thick = "THICKOUTLINE" }
local OPP = {
    TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT",
    TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT",
    BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT", CENTER = "CENTER",
}

local function PlaceText(fs, parent, t, defaultAnchor)
    fs:ClearAllPoints()
    local a = ns.Val(t.anchor) or defaultAnchor or "CENTER"
    if ns.Val(t.place) == "outer" and a ~= "CENTER" then
        fs:SetPoint(OPP[a] or "CENTER", parent, a, t.x or 0, t.y or 0)
    else
        fs:SetPoint(a, parent, a, t.x or 0, t.y or 0)
    end
end

local function StyleText(fs, parent, t, defaultAnchor)
    pcall(fs.SetFont, fs, ns.FontPath(t.font), t.size or 18, OUTLINE[t.outline or "outline"] or "OUTLINE")
    local c = t.color or { 1, 1, 1, 1 }
    fs:SetTextColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    PlaceText(fs, parent, t, defaultAnchor)
end
ns.StyleTextOn = StyleText   -- (BarCue.lua: a Bar cue's name text uses the same text settings)

local function FindCooldownText(cd)
    if cd.xuiText ~= nil then return cd.xuiText or nil end
    cd.xuiText = false
    for i = 1, cd:GetNumRegions() do
        local r = select(i, cd:GetRegions())
        if r and r.GetObjectType and r:GetObjectType() == "FontString" then cd.xuiText = r; break end
    end
    return cd.xuiText or nil
end

local function FmtRemaining(sec, decimals, below)
    if sec >= 3600 then return ("%dh"):format(math.floor(sec / 3600)) end
    if sec >= 60 then return ("%d:%02d"):format(math.floor(sec / 60), math.floor(sec % 60)) end
    if sec >= (below or 5) or not decimals then return ("%d"):format(math.ceil(sec)) end
    return ("%.1f"):format(sec)
end
ns.FmtRemaining = FmtRemaining
-- XayaUI's text style for any font string (the combat engine styles its own duration / stack text with it, so it matches).
ns.StyleText = StyleText

-- FmtRemaining as one of the game's own number formatters (C_StringUtil.CreateNumericRuleFormatter, 12.1.5), for text the GAME
-- draws from a secret time: the combat engine's duration text and the cooldown countdown below. The secret number never reaches
-- addon code; the game formats it with these rules. Before use, the formatter is checked against FmtRemaining on plain numbers (an
-- allowed call); if any answer differs, or the API is missing, it is not used and the caller falls back to the game's own format.
-- Breakpoint order (largest first) is what NumberAbbrevOptions documents; the other order is tried if the first one fails the check.
local timeFmtCache = {}
local TIME_PROBES = { 7325, 3600, 3599.5, 65.4, 60, 59.2, 12.2, 5, 4.96, 3.46, 1.04, 0.44 }
local function BuildTimeFormatter(decimals, below, ascending)
    local R = Enum and Enum.NumericRuleFormatRounding
    if not (R and C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return nil end
    local f = C_StringUtil.CreateNumericRuleFormatter()
    local bps = {
        { threshold = 3600, format = "%dh", components = { { div = 3600, step = 1, rounding = R.Down } } },
        { threshold = 60, format = "%d:%02d", components = { { div = 60, step = 1, rounding = R.Down }, { mod = 60, step = 1, rounding = R.Down } } },
    }
    if decimals then
        bps[#bps + 1] = { threshold = below, format = "%d", step = 1, rounding = R.Up }
        bps[#bps + 1] = { threshold = 0, format = "%.1f" }
    else
        bps[#bps + 1] = { threshold = 0, format = "%d", step = 1, rounding = R.Up }
    end
    if ascending then
        local rev = {}
        for i = #bps, 1, -1 do rev[#rev + 1] = bps[i] end
        bps = rev
    end
    f:SetBreakpoints(bps)
    for _, s in ipairs(TIME_PROBES) do
        if f:FormatNumber(s) ~= FmtRemaining(s, decimals, below) then return nil end
    end
    return f
end
function ns.TimeFormatter(decimals, below)
    decimals = decimals and true or false
    below = tonumber(below) or 5
    local key = (decimals and "d" or "n") .. below
    local c = timeFmtCache[key]
    if c ~= nil then return c or nil end
    local ok, f = pcall(BuildTimeFormatter, decimals, below, false)
    if not (ok and f) then ok, f = pcall(BuildTimeFormatter, decimals, below, true) end
    timeFmtCache[key] = (ok and f) or false
    return (ok and f) or nil
end
-- (round 7, SD-60, her answer "all timers are supported by EUI ... solve for it") the whole seconds a display's own text shows from an
-- aura time the game hides (("%d"):format of the remaining seconds, as the text has always shown them: UpdateVisualText path 2), as one
-- of the game's number formatters, so the game counts that text down itself through a duration text binding. Checked like
-- TimeFormatter before use; nil when the API is missing or an answer differs (the caller then hands the time to a cooldown widget).
local wholeFmt
local WHOLE_PROBES = { 3725.5, 61.9, 59.99, 12.2, 5, 4.96, 1.04, 0.44, 0 }
local function BuildWholeFormatter()
    local R = Enum and Enum.NumericRuleFormatRounding
    if not (R and C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return nil end
    local f = C_StringUtil.CreateNumericRuleFormatter()
    f:SetBreakpoints({ { threshold = 0, format = "%d", step = 1, rounding = R.Down } })
    for _, s in ipairs(WHOLE_PROBES) do
        if f:FormatNumber(s) ~= ("%d"):format(s) then return nil end
    end
    return f
end
function ns.WholeSecondsFormatter()
    if wholeFmt == nil then
        local ok, f = pcall(BuildWholeFormatter)
        wholeFmt = (ok and f) or false
    end
    return wholeFmt or nil
end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Folders are containers. A folder can define alpha, scale, strata / level and a screen position (relative to the
-- screen, its parent folder or another game frame) that its rules' displays inherit, and is either STATIC (each display
-- keeps its own X / Y inside the container; the default) or DYNAMIC (the addon lays the visible displays out itself and
-- ignores their own X / Y).
-------------------------------------------------------------------------------
local containers = {}
local REL_FRAMES = { player = "PlayerFrame", target = "TargetFrame", focus = "FocusFrame", minimap = "Minimap", chat = "ChatFrame1" }
local function DynAncestor(folderId)
    local id, guard = folderId, 0
    while id and guard < 32 do
        local f = ns.FolderById(id)
        if not f then return nil end
        if f.cType == "dynamic" then return f end
        id, guard = f.parent, guard + 1
    end
end
-- G9 (Xaya 2026-11-06, static group scaling: "Toggle + ask on resize"): with "Scale items to fit the box" ticked, a static group with a
-- set size scales what is inside it down (never up) so its displays fit the box. The box keeps its size on screen: the container is
-- scaled by the factor and made larger by the same factor. Measured from the saved X / Y and sizes of the group's own displays, from
-- the box's centre (INFERENCE: displays anchored to a corner of the box are measured the same way, so for them the fit is approximate).
local FIT_PTS = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }
local function ItemsExtent(f)
    local ex, ey, n = 0, 0, 0
    local W, Hh = math.max(1, f.cW or 1), math.max(1, f.cH or 1)
    for _, r in ipairs(ns.rules or {}) do
        local v = r.visual
        if r.folder == f.id and type(v) == "table" and v.enabled and not (v.snap and v.snap.target) then
            local w, h = math.max(8, v.w or 128), math.max(8, v.h or 128)
            local a, fp = ns.VisualPoints(r)
            local PA, PF = FIT_PTS[a] or FIT_PTS.CENTER, FIT_PTS[fp] or FIT_PTS.CENTER
            local cx = (v.x or 0) - (PF[1] - 0.5) * w + (PA[1] - 0.5) * W
            local cy = (v.y or 0) - (PF[2] - 0.5) * h + (PA[2] - 0.5) * Hh
            ex = math.max(ex, math.abs(cx) + w / 2); ey = math.max(ey, math.abs(cy) + h / 2); n = n + 1
        end
    end
    return ex, ey, n
end
function ns.GroupFitNeeded(f)   -- the factor the items need to fit the set box (1 = they fit), whatever the tick box says
    if not f or f.cType == "dynamic" or ns.GroupSizeMode(f) ~= "set" then return 1 end
    local ex, ey, n = ItemsExtent(f)
    if n == 0 then return 1 end
    local W, Hh = math.max(1, f.cW or 1), math.max(1, f.cH or 1)
    local k = 1
    if ex > 0 then k = math.min(k, (W / 2) / ex) end
    if ey > 0 then k = math.min(k, (Hh / 2) / ey) end
    return math.max(0.05, k)
end
function ns.GroupFitScale(f) return (f and f.cFit) and ns.GroupFitNeeded(f) or 1 end
-------------------------------------------------------------------------------
-- Group anchors (REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s rows 14, 16, 18, 28, 29; Rules 0.6.82). Her decisions, built as given:
-- A. "This group's anchor point" on a group in Auto size names a point of what is inside it, no longer a corner of the invisible
--    1 x 1 container (her EllesmereUI case: "Bottom left" left the icons about half an icon off the frame's corner):
--    - rows / columns growing one way (Right, Left, Down, Up): the WHOLE GRID's point ("Whole grid's corner"): the grid's point sits on
--      the frame's point and the grid grows away from it (ns.DynamicBlock pins the block there, as "From anchor point" does);
--    - a group of hand-placed displays ("Both now"): the outline of EVERY switched-on display directly in the group (enabled, also
--      ones not showing now: other spec, conditions not met), from the saved positions and sizes, never from live frames, so the
--      group never shifts while she plays (GA.Outline);
--    - Center, a Centered row / column and From anchor point keep what they did; a group with a set size keeps its box's point.
--    Existing Auto groups with a non-Center point keep their place on screen once ("Nothing moves": ns.MigrateGroupAnchors); from
--    then on changing the point moves the icons ("Icons move"), X / Y unchanged.
-- B. "I should be able to anchor to another rule group's position": f.cRel = "group", f.cGroup = the other group's id. The group
--    follows that group's FRAME: its box when it has a set size, otherwise its anchor point (after A the point of its grid or
--    outline: GA.Dot, a 1 x 1 frame on the container). No watcher: the game's anchors carry every move. GA.Loops is the one loop
--    guard (what each group is placed from: its cGroup, else its parent unless anchored to the screen; 32 steps).
-------------------------------------------------------------------------------
local GA = {}
local function DispSize(v) return math.max(8, tonumber(v.w) or 128), math.max(8, tonumber(v.h) or 128) end   -- (as RefreshVisual sizes it)
function GA.PlacedFrom(f)   -- the id of the group f is placed from (nil: the screen or a game frame)
    if f.cRel == "group" and f.cGroup ~= nil then return f.cGroup end
    if f.parent and f.cAnchorTo ~= "screen" then return f.parent end
    return nil
end
function GA.Loops(f, target)   -- would placing group f from group target make a loop? (also true past 32 steps)
    if not (f and target) then return true end
    local id, n = target.id, 0
    while id ~= nil do
        if id == f.id then return true end
        n = n + 1
        if n > 32 then return true end
        local g = ns.FolderById(id)
        if not g then return false end
        id = GA.PlacedFrom(g)
    end
    return false
end
-- a group another group may follow (the settings list and the frame picker offer only these): not itself, no loop, not the cursor group
function ns.GroupAnchorAllowed(f, target)
    return f ~= nil and target ~= nil and target ~= f and target.default ~= "cursor" and not GA.Loops(f, target)
end
function GA.Target(f)   -- the group f follows, when that is allowed now
    if f.cRel ~= "group" or f.cGroup == nil then return nil end
    local t = ns.FolderById(f.cGroup)
    if t and t ~= f and not GA.Loops(f, t) then return t end
    return nil
end
function ns.GroupAnchorTarget(f) return f and GA.Target(f) or nil end
local function ParentsMap()
    local parents = {}
    for _, r in ipairs(ns.rules or {}) do if r.uid and not r.parentUid then parents[r.uid] = r end end
    return parents
end
-- A2/A3: the outline of a hand-placed group (l, b, r, t from its container's centre, container units), from saved data: every
-- switched-on display directly in it that hangs from its container (not snapped to a game frame). nil when it has none, or when its
-- displays are laid out by a dynamic group (it, or one around it).
-- (review fix 4) Every display's refresh places its group (Container), and the outline walks every rule: during one refresh pass
-- (ns.RefreshAllVisuals, which changes no saved position) each group's outline is measured once and kept for the rest of that pass,
-- and only while ns.configVersion (bumped by every settings edit, ns.MarkDirty) and the group's size stay the same. Outside a pass it
-- is measured each time (a drag or a nudge between two passes is read at once).
GA.outlinePass, GA.outlineCache = nil, {}
function GA.Outline(f)
    local W, H = math.max(1, f.cW or 1), math.max(1, f.cH or 1)
    local pass = GA.outlinePass
    if pass then
        local e = GA.outlineCache[f.id]
        if e and e.pass == pass and e.ver == (ns.configVersion or 0) and e.W == W and e.H == H then return e[1], e[2], e[3], e[4] end
        local l, b, r, t = GA.MeasureOutline(f, W, H)
        GA.outlineCache[f.id] = { l, b, r, t, pass = pass, ver = ns.configVersion or 0, W = W, H = H }
        return l, b, r, t
    end
    return GA.MeasureOutline(f, W, H)
end
GA.outlineWalks = 0   -- (tests: how many times the rules were walked for an outline)
function GA.MeasureOutline(f, W, H)
    if f.cType == "dynamic" or DynAncestor(f.id) then return nil end
    GA.outlineWalks = GA.outlineWalks + 1
    local l, b, r, t, parents
    for _, x in ipairs(ns.rules or {}) do
        local v = x.visual
        if x.folder == f.id and type(v) == "table" and v.enabled and not (v.snap and v.snap.target) and not x.cursorConv then
            parents = parents or ParentsMap()
            if not ns.RuleOff(x, parents) then
                local w, h = DispSize(v)
                local a, fp = ns.VisualPoints(x)
                local PA, PF = FIT_PTS[a] or FIT_PTS.CENTER, FIT_PTS[fp] or FIT_PTS.CENTER
                local cx = (tonumber(v.x) or 0) - (PF[1] - 0.5) * w + (PA[1] - 0.5) * W
                local cy = (tonumber(v.y) or 0) - (PF[2] - 0.5) * h + (PA[2] - 0.5) * H
                l = l and math.min(l, cx - w / 2) or (cx - w / 2); r = r and math.max(r, cx + w / 2) or (cx + w / 2)
                b = b and math.min(b, cy - h / 2) or (cy - h / 2); t = t and math.max(t, cy + h / 2) or (cy + h / 2)
            end
        end
    end
    if not l then return nil end
    return l, b, r, t
end
function ns.GroupOutline(f) if f then return GA.Outline(f) end end   -- (tests, the walkthrough)
function ns.GroupOutlineWalks() return GA.outlineWalks end   -- (tests)
function GA.Point(f) local pt = f.cPoint or "CENTER"; if not FIT_PTS[pt] then pt = "CENTER" end; return pt end
-- Where the group's anchor point is, from its container's centre (container units), and whether the outline decides it (A3).
-- Set size: the box's point. Auto: a hand-placed group with a non-Center point: that point of its outline; otherwise the 1 x 1
-- container's point (a dynamic group's grid is pinned there: ns.DynamicBlock).
function GA.AnchorOffset(f, cw, ch)
    local pt = GA.Point(f)
    local P = FIT_PTS[pt]
    if pt ~= "CENTER" and ns.GroupSizeMode(f) == "auto" then
        local l, b, r, t = GA.Outline(f)
        if l then return l + P[1] * (r - l), b + P[2] * (t - b), true end
    end
    return (P[1] - 0.5) * cw, (P[2] - 0.5) * ch, false
end
-- B: the 1 x 1 frame on a group's anchor point that other groups follow (made the first time one does; kept in place by Container)
local Container
function GA.Dot(f)
    local c = Container(f)
    if not c.xuiDot then
        local d = CreateFrame("Frame", nil, c)
        d:SetSize(1, 1)
        if d.EnableMouse then d:EnableMouse(false) end
        c.xuiDot = d
        Container(f)   -- (places it)
    end
    return c.xuiDot
end
-- the screen point (UIParent units) of a group's anchor point. (review fix 5) Read from the dot when the group is followed (it has
-- one), otherwise worked out from the container (its centre + GA.AnchorOffset): measuring a group never makes a dot (V14)
function GA.AnchorXY(f)
    local c = Container(f)
    local d = c.xuiDot
    local x, y, s
    if d then
        x, y = d:GetCenter()
        if not x then return nil end
        s = d:GetEffectiveScale()
    else
        local l, b, w, h = c:GetRect()
        if not l then return nil end
        local ox, oy = GA.AnchorOffset(f, c:GetWidth(), c:GetHeight())
        x, y = l + w / 2 + ox, b + h / 2 + oy
        s = c:GetEffectiveScale()
    end
    s = s / UIParent:GetEffectiveScale()
    return x * s, y * s
end
function ns.GroupAnchorXY(f) if f then return GA.AnchorXY(f) end end   -- (tests, the walkthrough)
-- B: a group placed while it is already being placed (a group that follows one of its own nested groups, which is anchored to the
-- screen: the nested group's container still hangs inside it) gets its container as it is; the first call finishes placing it
GA.building = {}
function Container(f)
    local c = containers[f.id]
    if not c then c = CreateFrame("Frame", nil, UIParent); c:SetSize(1, 1); containers[f.id] = c end
    if GA.building[f.id] then return c end
    GA.building[f.id] = true
    local ok, err = pcall(GA.Place, f, c)
    GA.building[f.id] = nil
    if not ok then error(err, 0) end
    return c
end
function GA.Place(f, c)
    local fit = f.cFit and ns.GroupFitScale(f) or 1   -- (V14: nothing is measured unless the tick box is on)
    local cw, ch = math.max(1, f.cW or 1) / fit, math.max(1, f.cH or 1) / fit
    c:SetSize(cw, ch)
    -- clip only with a set size (G5: in Auto the container is the 1 x 1 anchor, clipping it would hide everything)
    if c.SetClipsChildren then c:SetClipsChildren((f.cClip and ns.GroupSizeMode(f) == "set") and true or false) end
    local pf = f.parent and ns.FolderById(f.parent)
    local parentC = pf and Container(pf) or UIParent
    if c:GetParent() ~= parentC then c:SetParent(parentC) end
    -- G8 (Xaya 2026-11-06: "nested groups get "anchored to: screen / parent group""): a nested group is measured from its parent group
    -- (as before) unless it is anchored to the screen; it stays inside its parent either way (opacity, scale and layer still apply)
    local toScreen = f.parent and f.cAnchorTo == "screen"
    local target = toScreen and UIParent or parentC
    local rel = f.cRel
    local relPoint = f.cRelPoint or f.cPoint or "CENTER"
    local tg = GA.Target(f)   -- B: another group (its set box, else its anchor point)
    if tg then
        if ns.GroupSizeMode(tg) == "set" then target = Container(tg) else target = GA.Dot(tg); relPoint = "CENTER" end
    else
        local gname = (rel == "custom") and f.cFrame or REL_FRAMES[rel]
        local g = gname and gname ~= "" and _G[gname]
        if g and g.GetCenter and g ~= c then target = g end
    end
    local sc = math.max(0.1, f.cScale or 1) * fit
    c:SetScale(sc)
    c:SetAlpha(f.cAlpha or 1)
    if f.cStrata then c:SetFrameStrata(f.cStrata) end
    if (f.cLevel or 0) > 0 then c:SetFrameLevel(f.cLevel) end
    c:ClearAllPoints()
    -- (anchored to the screen from inside a scaled parent: the offset is divided by the parent's scale too, so X / Y stay screen units)
    local pScale = 1
    if toScreen and target == UIParent and parentC ~= UIParent and parentC.GetEffectiveScale and UIParent.GetEffectiveScale then
        local ue = UIParent:GetEffectiveScale()
        if ue and ue > 0 then pScale = math.max(0.01, (parentC:GetEffectiveScale() or ue) / ue) end
    end
    local px, py = (f.cX or 0) / (sc * pScale), (f.cY or 0) / (sc * pScale)
    c.xuiOffDiv = sc * pScale   -- (review fix 2: the divisor of X / Y; ShiftGroup turns screen pixels into X / Y with the same one)
    local ox, oy, byOutline = GA.AnchorOffset(f, cw, ch)
    if byOutline then   -- A3: the outline's point (ox, oy from the container's centre) on the target's point
        c:SetPoint("CENTER", target, relPoint, px - ox, py - oy)
    else
        c:SetPoint(f.cPoint or "CENTER", target, relPoint, px, py)
    end
    if c.xuiDot then c.xuiDot:ClearAllPoints(); c.xuiDot:SetPoint("CENTER", c, "CENTER", ox, oy) end
    -- what the group's X / Y is measured from (the group outline drag needs its scale). B: a group that follows another group moves by
    -- its own parent's units (pScale is 1 there), not by the other group's scale
    c.xuiTarget = tg and (c:GetParent() or UIParent) or target
end
-- XayaUI's frame for a group (created on first use, kept in place from the group's settings): the combat engine hangs its icons here
function ns.GroupFrame(f) return f and Container(f) or nil end
-- XayaUI's own frame for one display (created and styled on first use): the combat engine sits its single slot exactly on it
function ns.DisplayFrame(rule)
    if not rule then return nil end
    if not frames[rule] then ns.RefreshVisual(rule) end
    return frames[rule]
end
-- the frame a rule's display hangs from, and its dynamic-group ancestor (if any)
local function ParentFor(rule)
    if rule.cursorConv and ns.CursorReminderFolder then   -- converted at-cursor reminder: hangs from the cursor group
        local cf = ns.CursorReminderFolder()
        if cf then return Container(cf), cf end
    end
    if not rule.folder then return UIParent end
    local d = DynAncestor(rule.folder)
    local f = d or ns.FolderById(rule.folder)
    if not f then return UIParent end
    return Container(f), d
end
local function ApplyStrata(fr, folderId)
    local strata, level
    local id, guard = folderId, 0
    while id and guard < 32 do
        local f = ns.FolderById(id)
        if not f then break end
        strata = strata or f.cStrata
        if not level and (f.cLevel or 0) > 0 then level = f.cLevel end
        id, guard = f.parent, guard + 1
    end
    strata = strata or "HIGH"
    if fr:GetFrameStrata() ~= strata then fr:SetFrameStrata(strata) end
    if level and fr:GetFrameLevel() ~= level then fr:SetFrameLevel(level) end
    if fr.txtHolder then fr.txtHolder:SetFrameLevel(fr:GetFrameLevel() + 10) end
    if fr.cd then fr.cd:SetFrameLevel(fr:GetFrameLevel() + 10) end
end
-- Where a dynamic group puts its FIRST display, relative to the group frame's centre, for a display of w x h.
-- This is the single source of truth for that spot: LayoutDynamic below follows it, and the combat engine places its own
-- icons with it, so the two can never disagree. Centred growth has no fixed first spot (it depends on the whole line): nil.
function ns.DynamicFirstOffset(df, w, h)
    local dir = df and df.cGrowth or "RIGHT"
    local rev = df and df.cWrapRev and true or false   -- extra rows go up / extra columns go left: the first line sits on the other side
    if dir == "RIGHT" or dir == "LEFT" then return 0, rev and h / 2 or -h / 2 end
    if dir == "DOWN" or dir == "UP" then return rev and -w / 2 or w / 2, 0 end
    return nil
end

-- Block growth: "Centered row", "Centered column", and "From anchor point" (rows or columns; Xaya 2026-11-04: "the growth should
-- also be informed by anchor placement in the parent group container"). The shown items form one block, laid out the way Blizzard's
-- flow layout does it (12.1.5 AnchorUtil.ApplyFlowLayout, read in the game's UI source; no code copied):
--   every line starts at the block's `corner` edge; each item sits by that corner on its line (top-aligned in a row that grows
--   down, and so on); lines are `spacing` apart; the block is as wide as its longest line and as tall as its lines.
-- The block's `pin` point sits on the group frame's `pinTo` point. The combat engine uses the same numbers (Combat/AuraDisplay.lua
-- FlowFor), and Blizzard sizes its container to the icons that are showing after every layout pass, in combat too
-- (Blizzard_CustomAuraContainer.lua OnLayoutComplete -> container:SetSize), so the block grows and shrinks around the pin.
-- From anchor point: the pin is the group's own anchor point ("This group's anchor point"), on the same point of the group's box,
-- and the items grow away from it: right from a left-side anchor, left from a right-side one, down from a top one, up from a
-- bottom one; a middle anchor (TOP, CENTER, BOTTOM for rows; LEFT, CENTER, RIGHT for columns) keeps the block centered on it.
-- Edge growths (Right, Left, Down, Up) keep their fixed first spot (ns.DynamicFirstOffset; nil here) with the Center point or a set
-- size. In Auto size with any other point (fix A, her answer "Whole grid's corner"): the whole grid is one block pinned by that point
-- on the same point of the 1 x 1 group frame, so the grid's point sits where the group is placed and the grid grows away from it;
-- inside the block the lines still run the growth's way and extra lines go to the side "New rows / columns go" says.
local EDGE_BLOCK = {   -- [growth][extra lines on the other side] = horiz, right, down, corner (the flow the engine uses for the growth)
    RIGHT = { [false] = { true, true, true, "TOPLEFT" }, [true] = { true, true, false, "BOTTOMLEFT" } },
    LEFT = { [false] = { true, false, true, "TOPRIGHT" }, [true] = { true, false, false, "BOTTOMRIGHT" } },
    DOWN = { [false] = { false, true, true, "TOPLEFT" }, [true] = { false, false, true, "TOPRIGHT" } },
    UP = { [false] = { false, true, false, "BOTTOMLEFT" }, [true] = { false, false, false, "BOTTOMRIGHT" } },
}
local PT_V = {   -- a frame point, from the frame's centre, in widths / heights
    CENTER = { 0, 0 }, TOP = { 0, .5 }, BOTTOM = { 0, -.5 }, LEFT = { -.5, 0 }, RIGHT = { .5, 0 },
    TOPLEFT = { -.5, .5 }, TOPRIGHT = { .5, .5 }, BOTTOMLEFT = { -.5, -.5 }, BOTTOMRIGHT = { .5, -.5 },
}
function ns.DynamicBlock(df)
    local dir = df and df.cGrowth or "RIGHT"
    local rev = df and df.cWrapRev and true or false
    if dir == "HCENTER" then   -- the first row's top edge on the group's centre (bottom edge when new rows go above)
        if rev then return { horiz = true, right = true, down = false, corner = "BOTTOMLEFT", pin = "BOTTOM", pinTo = "CENTER" } end
        return { horiz = true, right = true, down = true, corner = "TOPLEFT", pin = "TOP", pinTo = "CENTER" }
    elseif dir == "VCENTER" then   -- the first column's left edge on the group's centre (right edge when new columns go left)
        if rev then return { horiz = false, right = false, down = true, corner = "TOPRIGHT", pin = "RIGHT", pinTo = "CENTER" } end
        return { horiz = false, right = true, down = true, corner = "TOPLEFT", pin = "LEFT", pinTo = "CENTER" }
    elseif dir == "ANCHOR_ROW" or dir == "ANCHOR_COL" then
        local pt = df.cPoint or "CENTER"
        if not PT_V[pt] then pt = "CENTER" end
        local onRight, onBottom = pt:find("RIGHT", 1, true) ~= nil, pt:find("BOTTOM", 1, true) ~= nil
        return { horiz = (dir == "ANCHOR_ROW"), right = not onRight, down = not onBottom,
            corner = (onBottom and "BOTTOM" or "TOP") .. (onRight and "RIGHT" or "LEFT"), pin = pt, pinTo = pt }
    elseif EDGE_BLOCK[dir] and df then   -- fix A: Auto size with a point other than Center: the whole grid's point
        local pt = df.cPoint
        if pt and pt ~= "CENTER" and PT_V[pt] and ns.GroupSizeMode(df) == "auto" then
            local e = EDGE_BLOCK[dir][rev]
            return { horiz = e[1], right = e[2], down = e[3], corner = e[4], pin = pt, pinTo = pt }
        end
    end
    return nil
end

-- Sort of a dynamic group (Group tab "Sort"; Xaya 2026-11-04): Default, Expiration, Name, Important, Manual, plus Reverse.
-- One definition for XayaUI's own layout (below) and the engine's containers (Combat/AuraDisplay.lua, Blizzard's own sorts there).
-- Older saves: cSort nil / "none" = manual (rule order); "asc" = name; "desc" = name, reversed.
local SORT_OK = { default = true, expiration = true, name = true, important = true }
function ns.GroupSortOf(fo)
    local s, rev = fo and fo.cSort, (fo and fo.cSortRev) and true or false
    if s == "asc" then s = "name" elseif s == "desc" then s = "name"; rev = not rev end
    if not SORT_OK[s] then s = "manual" end
    return s, rev
end
-- For XayaUI's own items (preview, unlocked, and displays the engine does not draw), each sort uses what XayaUI can read:
--   manual      rule order (the sidebar)
--   name        the rule's name
--   important   the game's own flag for the rule's aura (C_Spell.IsSpellImportant), then rule order
--   default     the game's priority flag for the rule's aura (C_Spell.IsPriorityAura), then rule order
--   expiration  time left from the rule's own reading (exact or its estimate), soonest first; unknown after known; then rule order
-- Engine-drawn groups use Blizzard's comparators for these instead (same names), which also look at who cast the aura.
local function SpellFlag(fn, owner)
    local id = tonumber(owner and owner.buffID) or 0
    if id <= 0 or type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, id)
    return ok and v == true
end
local function TimeLeftOf(owner)
    local rt = ns.runtime and ns.runtime[owner]
    local ref = rt and rt.info and rt.info.present == true and rt.info.buffRef
    local e = ref and ref.expiration
    if type(e) == "number" and not issecretvalue(e) and e > 0 then return e - GetTime() end
end

-- G10 Align: where an item sits across its line (lo..hi on the cross axis, t = its thickness). start = top (rows) / left (columns),
-- end = bottom / right, center = the middle
local function CrossAlign(mode, rows, lo, hi, t)
    if mode == "start" then return rows and (hi - t / 2) or (lo + t / 2) end
    if mode == "end" then return rows and (lo + t / 2) or (hi - t / 2) end
    return (lo + hi) / 2
end
-- a dynamic group's items ({ w, h }) split into lines along the main axis: at the box's width / height (set size) and / or after
-- "Items per row / column"
function GA.SplitLines(df, items, horiz)
    local sp = df.cSpacing or 4
    local limit = horiz and (df.cW or 0) or (df.cH or 0)   -- 0 = no wrapping
    local wrapN = tonumber(df.cWrapN) or 0                  -- items per row / column (0 = no limit); the size limit above still applies
    local lines, line, used = {}, {}, 0
    for _, it in ipairs(items) do
        local len = horiz and it.w or it.h
        if #line > 0 and ((limit > 0 and used + sp + len > limit) or (wrapN > 0 and #line >= wrapN)) then
            lines[#lines + 1] = line; line, used = {}, 0
        end
        used = (#line == 0) and len or (used + sp + len)
        line[#line + 1] = it
    end
    lines[#lines + 1] = line
    return lines
end
-- the edge growths' fixed-first-spot layout (Right, Left, Down, Up with the Center point or a set size): put(it, x, y) gets each item's
-- centre from the group frame's centre. Also what ns.MigrateGroupAnchors reads to keep older groups where they were.
function GA.EdgeLayout(df, lines, dir, horiz, put)
    local sp = df.cSpacing or 4
    local cs = df.cWrapRev and -1 or 1   -- which way extra rows / columns go: down or right (1), up or left (-1)
    local crossOff = 0
    for _, ln in ipairs(lines) do
        local pos, cur, prevLen, cross = {}, 0, 0, 0
        for i, it in ipairs(ln) do
            local len = horiz and it.w or it.h
            if i == 1 then cur = 0 else cur = cur + prevLen / 2 + sp + len / 2 end
            pos[i], prevLen = cur, len
            cross = math.max(cross, horiz and it.h or it.w)
        end
        local co = crossOff + cross / 2
        for i, it in ipairs(ln) do
            local p = pos[i]
            local x, y = 0, 0
            if dir == "RIGHT" then x = p; y = -co * cs
            elseif dir == "LEFT" then x = -p; y = -co * cs
            elseif dir == "DOWN" then y = -p; x = co * cs
            elseif dir == "UP" then y = p; x = co * cs end
            if df.cAlign then   -- G10 Align (default: centred on the line, as before)
                if horiz then y = CrossAlign(df.cAlign, true, y - cross / 2, y + cross / 2, it.h)
                else x = CrossAlign(df.cAlign, false, x - cross / 2, x + cross / 2, it.w) end
            end
            put(it, x, y)
        end
        crossOff = crossOff + cross + sp
    end
end
-- (round 6, V27 P3) which rules can sit in each dynamic group: members[group] = the rules whose own group, or a group above it, is that
-- dynamic group, in rule order; cursor = the converted at-cursor reminders (their group is asked at layout time). Built in one pass
-- over the rules when the rule list, its length, the group list, its length or ns.configVersion (ns.MarkDirty) changed, and checked
-- again on every full engine step (ns.BeginVisualStep(true)): a rule moved to another group, or a group moved or made dynamic,
-- without a settings change announcing it, rebuilds it there. A layout then walks only its own members.
local EMPTY_LIST = {}
local dynIdx = { members = {}, posOf = {}, byUid = {}, cursor = {}, folderOf = {}, cursorFlag = {}, rulesSeen = {}, fParent = {}, fType = {}, fSeen = {} }
local function DynIndexStale()
    local rules, folders = ns.rules or EMPTY_LIST, ns.folders or EMPTY_LIST
    return dynIdx.rules ~= rules or dynIdx.n ~= #rules or dynIdx.folders ~= folders or dynIdx.nf ~= #folders
        or dynIdx.ver ~= (ns.configVersion or 0)
end
local function DynIndexBuild()
    local rules, folders = ns.rules or EMPTY_LIST, ns.folders or EMPTY_LIST
    local members, posOf, byUid, cursor = {}, {}, {}, {}
    local folderOf, cursorFlag, rulesSeen = dynIdx.folderOf, dynIdx.cursorFlag, dynIdx.rulesSeen
    local fParent, fType, fSeen = dynIdx.fParent, dynIdx.fType, dynIdx.fSeen
    local n = #rules
    for i = 1, n do
        local r = rules[i]
        posOf[r] = i
        if type(r.uid) == "string" and not r.parentUid then byUid[r.uid] = r end
        local df = r.folder and DynAncestor(r.folder)
        if df then
            local l = members[df]
            if not l then l = {}; members[df] = l end
            l[#l + 1] = r
        end
        if r.cursorConv then cursor[#cursor + 1] = r end
        rulesSeen[i], folderOf[i], cursorFlag[i] = r, r.folder or false, r.cursorConv and true or false
    end
    for i = n + 1, #rulesSeen do rulesSeen[i], folderOf[i], cursorFlag[i] = nil, nil, nil end
    local nf = #folders
    for i = 1, nf do local f = folders[i]; fSeen[i], fParent[i], fType[i] = f, f.parent or false, f.cType or false end
    for i = nf + 1, #fSeen do fSeen[i], fParent[i], fType[i] = nil, nil, nil end
    dynIdx.members, dynIdx.posOf, dynIdx.byUid, dynIdx.cursor = members, posOf, byUid, cursor
    dynIdx.rules, dynIdx.n, dynIdx.folders, dynIdx.nf, dynIdx.ver = rules, n, folders, nf, ns.configVersion or 0
    dynIdx.built = true
end
-- a full engine step: any rule's group, or any group's parent / kind, that changed without a settings change rebuilds the index
local function DynIndexCheck()
    if not dynIdx.built or DynIndexStale() then DynIndexBuild(); return end
    local rules, folders = dynIdx.rules, dynIdx.folders
    local rs, fo, cf = dynIdx.rulesSeen, dynIdx.folderOf, dynIdx.cursorFlag
    for i = 1, dynIdx.n do
        local r = rules[i]
        if rs[i] ~= r or fo[i] ~= (r.folder or false) or cf[i] ~= (r.cursorConv and true or false) then
            DynIndexBuild(); return
        end
    end
    local fs, fp, ft = dynIdx.fSeen, dynIdx.fParent, dynIdx.fType
    for i = 1, dynIdx.nf do
        local f = folders[i]
        if fs[i] ~= f or fp[i] ~= (f.parent or false) or ft[i] ~= (f.cType or false) then DynIndexBuild(); return end
    end
end
function GA.DynIndex()
    -- outside an engine step (the settings window, a redraw, the mover) every call checks the index against the rule and group lists,
    -- so an edit that did not announce itself (a sidebar swap) is laid out at once, as before; inside a step the full-step check holds
    if not (ns.InStep and ns.InStep()) then DynIndexCheck()
    elseif not dynIdx.built or DynIndexStale() then DynIndexBuild() end
    return dynIdx
end
-- two lists already in rule order, merged in rule order (only when a group is also the at-cursor reminders' group)
function GA.MergeByPos(a, b, posOf)
    local out, i, j = {}, 1, 1
    while a[i] ~= nil or b[j] ~= nil do
        local x, y = a[i], b[j]
        if x ~= nil and x == y then out[#out + 1] = x; i, j = i + 1, j + 1
        elseif y == nil or (x ~= nil and (posOf[x] or 0) < (posOf[y] or 0)) then out[#out + 1] = x; i = i + 1
        else out[#out + 1] = y; j = j + 1 end
    end
    return out
end
ns._DynIndexCheck = DynIndexCheck
-- a dynamic group's items as XayaUI lays them out now: one per rule (its first shown display; the rule's other display cues ride on
-- it), sorted (rule order, then the group's Sort). Each item: { fr, w, h, extra, owner }. Limit is not applied here.
function GA.DynItems(df)
    -- One slot per RULE (the rule is the container of its cues), in the rule's own list order: the order of the sidebar, which the
    -- up / down arrows and drag-and-drop change. A cue is not a slot of its own (0.6.4, #344): cues are kept in the list in the order
    -- they were made, so the old one-slot-per-cue layout ignored the sidebar order, and a rule's second display cue (a separate Text
    -- cue) took a slot of its own at the end of the group. The slot's size is the rule's first shown display; its other shown display
    -- cues sit centered on that slot.
    -- (round 6, V27 P3: "nothing loops over all rules on every game event") the group's own members come from GA.DynIndex, built once
    -- whenever the rule list, the groups or a setting changed; a layout walks only them, in rule order, as the walk over every rule did
    local idx = GA.DynIndex()
    local posOf, byUid = idx.posOf, idx.byUid
    local items, byOwner = {}, {}
    local list = idx.members[df] or EMPTY_LIST
    local cur = idx.cursor
    if #cur > 0 and ns.CursorReminderFolder and ns.CursorReminderFolder() == df then list = GA.MergeByPos(list, cur, posOf) end
    for li = 1, #list do
        local r = list[li]
        local fr = frames[r]
        if fr and (fr:IsShown() or fr.xuiLimited) and ((r.folder and DynAncestor(r.folder) == df)
            or (r.cursorConv and ns.CursorReminderFolder and ns.CursorReminderFolder() == df)) then
            local owner = (r.parentUid and byUid[r.parentUid]) or r
            local it = byOwner[owner]
            if not it then
                it = { fr = fr, w = fr:GetWidth(), h = fr:GetHeight(), name = tostring(owner.name or ""):lower(),
                    pos = posOf[owner] or posOf[r] or 0, extra = nil, owner = owner }
                byOwner[owner] = it
                items[#items + 1] = it
            else
                it.extra = it.extra or {}
                it.extra[#it.extra + 1] = fr
            end
        end
    end
    if #items == 0 then return items end
    for i, it in ipairs(items) do it.i = i end
    table.sort(items, function(a, b) if a.pos ~= b.pos then return a.pos < b.pos end return a.i < b.i end)
    do   -- Sort (group option); every sort falls back to rule order on ties
        local mode, rev = ns.GroupSortOf(df)
        for i, it in ipairs(items) do it.i = i end   -- (renumbered after the rule-order sort above)
        if mode == "name" then
            table.sort(items, function(a, b) if a.name == b.name then return a.i < b.i end return a.name < b.name end)
        elseif mode == "important" or mode == "default" then
            local fn = (mode == "important") and (C_Spell and C_Spell.IsSpellImportant) or (C_Spell and C_Spell.IsPriorityAura)
            for _, it in ipairs(items) do it.flag = SpellFlag(fn, it.owner) end
            table.sort(items, function(a, b) if a.flag ~= b.flag then return a.flag end return a.i < b.i end)
        elseif mode == "expiration" then
            for _, it in ipairs(items) do it.left = TimeLeftOf(it.owner) end
            table.sort(items, function(a, b)
                if a.left and b.left then if a.left ~= b.left then return a.left < b.left end return a.i < b.i end
                if a.left or b.left then return a.left ~= nil end
                return a.i < b.i
            end)
        end
        if rev then
            local n = #items
            for i = 1, math.floor(n / 2) do items[i], items[n - i + 1] = items[n - i + 1], items[i] end
        end
    end
    return items
end
-- a block growth (ns.DynamicBlock): put(it, x, y) gets each item's centre from the group frame's centre; cw / ch = the group frame's size
function GA.FlowBlock(df, blk, lines, horiz, cw, ch, put)
    local sp = df.cSpacing or 4
    -- the block: each line's length along the main axis and its thickness across it
    local thick, bMain, bCross = {}, 0, 0
    for li, ln in ipairs(lines) do
        local m, t = 0, 0
        for i, it in ipairs(ln) do
            m = m + (horiz and it.w or it.h) + ((i > 1) and sp or 0)
            t = math.max(t, horiz and it.h or it.w)
        end
        thick[li] = t
        if m > bMain then bMain = m end
        bCross = bCross + t + ((li > 1) and sp or 0)
    end
    local bw, bh = bMain, bCross
    if not horiz then bw, bh = bCross, bMain end
    local hv, pv, cv = PT_V[blk.pinTo], PT_V[blk.pin], PT_V[blk.corner]
    -- block centre (from the group frame's centre): the block's pin point on the group frame's pinTo point
    local bx = hv[1] * cw - pv[1] * bw
    local by = hv[2] * ch - pv[2] * bh
    local ox, oy = bx + cv[1] * bw, by + cv[2] * bh   -- the corner every line starts from
    local sx = blk.right and 1 or -1                   -- x grows right / left
    local sy = blk.down and -1 or 1                    -- y grows down / up
    local cross = 0
    for li, ln in ipairs(lines) do
        local main = 0
        for _, it in ipairs(ln) do
            local px, py   -- the item's own corner point
            if horiz then px, py = ox + main * sx, oy + cross * sy else px, py = ox + cross * sx, oy + main * sy end
            local cx, cy = px - cv[1] * it.w, py - cv[2] * it.h
            if df.cAlign then   -- G10 Align: across the line, by its top / centre / bottom (rows) or left / centre / right (columns)
                local a, b = cross, cross + thick[li]
                if horiz then cy = CrossAlign(df.cAlign, true, math.min(oy + a * sy, oy + b * sy), math.max(oy + a * sy, oy + b * sy), it.h)
                else cx = CrossAlign(df.cAlign, false, math.min(ox + a * sx, ox + b * sx), math.max(ox + a * sx, ox + b * sx), it.w) end
            end
            put(it, cx, cy)
            main = main + (horiz and it.w or it.h) + sp
        end
        cross = cross + thick[li] + sp
    end
end
-- the layout of a dynamic group's items ({ w, h }), whichever growth: put(it, x, y) gets each item's centre from the group frame's centre
function GA.LayItems(df, items, cw, ch, put)
    local dir = df.cGrowth or "RIGHT"
    local blk = ns.DynamicBlock(df)   -- Centered / From anchor point / an edge growth pinned by a corner: one block (see above)
    local horiz
    if blk then horiz = blk.horiz else horiz = (dir == "RIGHT" or dir == "LEFT") end
    local lines = GA.SplitLines(df, items, horiz)
    if blk then GA.FlowBlock(df, blk, lines, horiz, cw, ch, put) else GA.EdgeLayout(df, lines, dir, horiz, put) end
end
-- (review fix 1) the middle of a dynamic group's grid from its group frame's centre (container units), for its settings NOW: the items
-- it lays out now (shown, Limit applied); with nothing shown, every switched-on item from saved data (GA.SavedItems). The same items
-- before and after an anchor change, so Reanchor keeps the grid where it is. 0, 0 for a hand-placed group (its displays hang from
-- the container's centre whatever the point is).
function GA.ContentOffset(f, c)
    if f.cType ~= "dynamic" then return 0, 0 end
    local items = GA.DynItems(f)
    local lim = tonumber(f.cLimit) or 0
    if lim > 0 then for i = #items, lim + 1, -1 do items[i] = nil end end
    if #items == 0 then items = GA.SavedItems(f) end
    if #items == 0 then return 0, 0 end
    local l, b, r, t
    GA.LayItems(f, items, c:GetWidth(), c:GetHeight(), function(it, x, y)
        l = l and math.min(l, x - it.w / 2) or (x - it.w / 2); r = r and math.max(r, x + it.w / 2) or (x + it.w / 2)
        b = b and math.min(b, y - it.h / 2) or (y - it.h / 2); t = t and math.max(t, y + it.h / 2) or (y + it.h / 2)
    end)
    return (l + r) / 2, (b + t) / 2
end
local function LayoutDynamic(df)
    if not df then return end
    local items = GA.DynItems(df)
    if #items == 0 then return end
    do   -- G10 Limit (Xaya 2026-11-06: "Limit"): after sorting only the first N show; the rest wait (hidden, marked) until there is room
        local lim = tonumber(df.cLimit) or 0
        local keep = {}
        for i, it in ipairs(items) do
            local over = lim > 0 and i > lim
            local function set(fr)
                if over then if fr:IsShown() then fr:Hide() end; fr.xuiLimited = true
                elseif fr.xuiLimited then fr.xuiLimited = nil; fr:Show() end
            end
            set(it.fr)
            for _, ef in ipairs(it.extra or {}) do set(ef) end
            if not over then keep[#keep + 1] = it end
        end
        items = keep
        if #items == 0 then return end
    end
    local container = Container(df)
    GA.LayItems(df, items, container:GetWidth(), container:GetHeight(), function(it, x, y)
        it.fr:ClearAllPoints()
        it.fr:SetPoint("CENTER", container, "CENTER", x, y)
        if it.extra then   -- the rule's other display cues: on the same slot
            for _, ef in ipairs(it.extra) do ef:ClearAllPoints(); ef:SetPoint("CENTER", container, "CENTER", x, y) end
        end
    end)
end

-- Fix A, "Nothing moves" (her answer for every existing Auto group with a point other than Center): once per profile, behind the
-- saved version flag CoreS.groupAnchorVer (1 = done; running it again changes nothing), from saved data only, before anything is drawn.
-- Before 0.6.82 such a group's 1 x 1 container had its point P on the target's point Q, and what is inside hung from the container's
-- centre C = Q - pv (pv: P's offset from the centre of a 1 x 1 frame: FIT_PTS[P] - 0.5). From 0.6.82 the point P of what is inside
-- (O: the outline of every switched-on display of a hand-placed group; the whole grid of a Right / Left / Down / Up group, all its
-- switched-on items showing, in rule order) sits on Q. For O to stay where it was: Q' = C + o, where o = P of O measured from C with
-- the layout before 0.6.82, so Q' - Q = o - pv (container units), and in X / Y units:
--   cX' = cX + (o.x - pv.x) * scale * pScale,   cY' = cY + (o.y - pv.y) * scale * pScale
-- scale = the group's own scale (fit is 1 in Auto); pScale = its parents' scales multiplied, only for a nested group anchored to the
-- screen with no game frame named (Container's divisor; a named frame is taken to exist in play: INFERENCE). Groups with a set size,
-- the Center point, Centered row / column, From anchor point, or nothing switched on inside are left as they are.
function GA.SavedItems(df)   -- a dynamic group's slots from saved data (one per rule, its first switched-on display's size), rule order
    local items, seen, byUid, posOf, parents = {}, {}, {}, {}, ParentsMap()
    for i, r in ipairs(ns.rules or {}) do
        posOf[r] = i
        if type(r.uid) == "string" and not r.parentUid then byUid[r.uid] = r end
    end
    for _, r in ipairs(ns.rules or {}) do
        local v = r.visual
        if r.folder and type(v) == "table" and v.enabled and not r.cursorConv and DynAncestor(r.folder) == df and not ns.RuleOff(r, parents) then
            local owner = (r.parentUid and byUid[r.parentUid]) or r
            if not seen[owner] then
                seen[owner] = true
                local w, h = DispSize(v)
                items[#items + 1] = { w = w, h = h, pos = posOf[owner] or posOf[r] or 0, i = #items + 1 }
            end
        end
    end
    table.sort(items, function(a, b) if a.pos ~= b.pos then return a.pos < b.pos end return a.i < b.i end)
    local lim = tonumber(df.cLimit) or 0
    if lim > 0 then for i = #items, lim + 1, -1 do items[i] = nil end end
    return items
end
function GA.OldGridOutline(df)   -- the outline of a Right / Left / Down / Up grid as it was drawn before 0.6.82 (from the group frame's centre)
    local items = GA.SavedItems(df)
    if #items == 0 then return nil end
    local dir = df.cGrowth or "RIGHT"
    local horiz = (dir == "RIGHT" or dir == "LEFT")
    local l, b, r, t
    GA.EdgeLayout(df, GA.SplitLines(df, items, horiz), dir, horiz, function(it, x, y)
        l = l and math.min(l, x - it.w / 2) or (x - it.w / 2); r = r and math.max(r, x + it.w / 2) or (x + it.w / 2)
        b = b and math.min(b, y - it.h / 2) or (y - it.h / 2); t = t and math.max(t, y + it.h / 2) or (y + it.h / 2)
    end)
    return l, b, r, t
end
function GA.SavedPScale(f)
    if not (f.parent and f.cAnchorTo == "screen") then return 1 end
    local gname = (f.cRel == "custom") and f.cFrame or REL_FRAMES[f.cRel]
    if gname and gname ~= "" then return 1 end
    local s, id, n = 1, f.parent, 0
    while id and n < 32 do
        local p = ns.FolderById(id)
        if not p then break end
        s = s * math.max(0.1, p.cScale or 1) * (p.cFit and ns.GroupFitScale(p) or 1)
        id, n = p.parent, n + 1
    end
    return s
end
local EDGE_GROWTH = { RIGHT = true, LEFT = true, DOWN = true, UP = true }
function ns.MigrateGroupAnchors()
    if (CoreS.groupAnchorVer or 0) >= 1 then return 0 end
    local moved = {}
    for _, f in ipairs(ns.folders or {}) do
        local ok, err = pcall(function()
            local pt = f.cPoint
            if not (pt and pt ~= "CENTER" and FIT_PTS[pt] and ns.GroupSizeMode(f) == "auto") then return end
            local l, b, r, t, kind
            if f.cType == "dynamic" then
                if not EDGE_GROWTH[f.cGrowth or "RIGHT"] then return end
                l, b, r, t = GA.OldGridOutline(f); kind = "grid"
            else
                l, b, r, t = GA.Outline(f); kind = "outline"
            end
            if not l then return end
            local P = FIT_PTS[pt]
            local ox, oy = l + P[1] * (r - l), b + P[2] * (t - b)
            local div = math.max(0.1, f.cScale or 1) * GA.SavedPScale(f)
            local dx, dy = (ox - (P[1] - 0.5)) * div, (oy - (P[2] - 0.5)) * div
            f.cX = (f.cX or 0) + dx
            f.cY = (f.cY or 0) + dy
            moved[#moved + 1] = { id = f.id, name = tostring(f.name), point = pt, kind = kind, dx = dx, dy = dy }
        end)
        if not ok and ns.RecordError then pcall(ns.RecordError, "XayaUI group anchor update, group '" .. tostring(f.name) .. "': " .. tostring(err), nil, "XayaUI", "XUI-E011") end
    end
    CoreS.groupAnchorVer = 1
    CoreS.groupAnchorMoved = (#moved > 0) and moved or nil   -- (read by the QA walkthrough: which groups had their X / Y adjusted)
    return #moved
end

-- Group size (G5; Xaya 2026-11-06: "size = auto or set + clip / wrap tick boxes; auto fits the showing items, border follows").
-- Auto: the container stays the 1 x 1 anchor it is with no size (cW / cH nil, exactly as "0 = no fixed size" was, so the combat
-- engine and the layout read it unchanged); the set numbers wait in cSetW / cSetH. Set: cW / cH are the box.
function ns.GroupSizeMode(f)
    if f.cSize == "set" or f.cSize == "auto" then return f.cSize end
    return ((f.cW or 0) > 0 or (f.cH or 0) > 0) and "set" or "auto"
end
function ns.SetGroupSizeMode(f, mode)
    if mode == "auto" then
        if (f.cW or 0) > 0 then f.cSetW = f.cW end
        if (f.cH or 0) > 0 then f.cSetH = f.cH end
        f.cW, f.cH, f.cSize = nil, nil, "auto"
    else
        f.cW, f.cH = f.cW or f.cSetW or 200, f.cH or f.cSetH or 100
        f.cSize = "set"
    end
end
-- What a group shows now, in UIParent units (l, b, r, t; nil when nothing), for the mover view's outline and tag, centering and anchoring
-- to a group (no longer for a border box: SD-17 draws a group's border / background on each display): XayaUI's own shown frames in it
-- or nested in it, and (review R19) the combat engine's slots in it (Combat/AuraDisplay.lua ns.EngineSlotsEach). The engine draws
-- buff displays in the game's own aura containers and keeps XayaUI's frames for them hidden; whether such an aura is up is not
-- something the game lets addons know in combat, so an engine slot counts while it may show (loaded, talents, not unlocked). A single slot is measured as
-- XayaUI's own icon frame it sits on; a dynamic group's container as XayaUI's layout of the members that may show (GA.LayItems),
-- worked out once per change and kept. The containers' own geometry is never read (it can be secret in combat).
local gbRoot, gbUs, gbL, gbB, gbR, gbT   -- (the measure in progress; module locals so a measure allocates no table)
local engineExt = {}   -- [folderId] = { l, b, r, t, ver =, cfg = }: a dynamic engine group's grid from its group frame's centre
local function GBAdd(fl, fb, fr, ft)
    gbL = gbL and math.min(gbL, fl) or fl; gbB = gbB and math.min(gbB, fb) or fb
    gbR = gbR and math.max(gbR, fr) or fr; gbT = gbT and math.max(gbT, ft) or ft
end
local function GBFrame(fr)
    local fl, fb, fw, fh = fr:GetRect()
    if not fl then return end
    local s = fr:GetEffectiveScale() / gbUs
    GBAdd(fl * s, fb * s, (fl + fw) * s, (fb + fh) * s)
end
local function GBEngine(host, fid, sizes)
    if not InFolder(fid, gbRoot) then return end
    if host then GBFrame(host); return end
    local c, fo = containers[fid], ns.FolderById(fid)
    if not (c and fo) then return end
    local ver, cfg = ns.EngineSlotsVersion and ns.EngineSlotsVersion() or 0, ns.configVersion or 0
    local e = engineExt[fid]
    if not (e and e.ver == ver and e.cfg == cfg) then
        local l, b, r, t
        GA.LayItems(fo, sizes, c:GetWidth(), c:GetHeight(), function(it, x, y)
            l = l and math.min(l, x - it.w / 2) or (x - it.w / 2); r = r and math.max(r, x + it.w / 2) or (x + it.w / 2)
            b = b and math.min(b, y - it.h / 2) or (y - it.h / 2); t = t and math.max(t, y + it.h / 2) or (y + it.h / 2)
        end)
        e = { l, b, r, t, ver = ver, cfg = cfg }
        engineExt[fid] = e
    end
    if not e[1] then return end
    local cx, cy = c:GetCenter()
    if not cx then return end
    local s = c:GetEffectiveScale() / gbUs
    GBAdd((cx + e[1]) * s, (cy + e[2]) * s, (cx + e[3]) * s, (cy + e[4]) * s)
end
local function GroupBounds(f)
    gbRoot, gbUs, gbL, gbB, gbR, gbT = f.id, UIParent:GetEffectiveScale(), nil, nil, nil, nil
    for rule, fr in pairs(frames) do
        if fr:IsShown() and InFolder(rule.folder, f.id) then GBFrame(fr) end
    end
    if ns.EngineSlotsEach then pcall(ns.EngineSlotsEach, GBEngine) end
    return gbL, gbB, gbR, gbT
end
-- A group's border and background (G5 / G11; #372 "puts an assigned color / texture under the aura"). (SD-17, Xaya 2026-11-10, her
-- words: "Make it apply to individual auras, not the whole container"; "Every group has this same behavior".) They are drawn on EACH
-- display: XayaUI's own display frames (RefreshVisual) and every aura button the combat engine makes (Combat/AuraDisplay.lua, its own
-- list of the buttons it set up). There is no box around the group and nothing follows one: they are drawn when a display is set up or
-- a setting changes, never per frame. Off (neither border nor background): no texture is made (V14). The saved keys are unchanged
-- (cBorder, cBdColor, cBdSize, cBg, cBgColor, cBgTex, cPad); cPad is now the padding around each display. (SD-32, her answer "0 px
-- (Recommended)") A group with no saved padding draws them on the display's own edge (0 px); a saved padding is used as saved.
-- Which group's settings a display takes: its own group's, or, when that group has neither on, the nearest group around it that has
-- (the old box of a group also went round its nested groups' items).
local function DecoGroup(folderId)
    local id, n = folderId, 0
    while id and n < 32 do
        local f = ns.FolderById and ns.FolderById(id)
        if not f then return nil end
        if f.cBorder or f.cBg then return f end
        id, n = f.parent, n + 1
    end
    return nil
end
ns.GroupDecoFor = DecoGroup
local DEF_BG, DEF_BD = { 0, 0, 0, 0.45 }, { 0.6, 0.6, 0.65, 1 }
-- Draw group fo's border / background on one display `owner` (fo nil: hide them). d = the textures kept for that display by the
-- caller (in the caller's own table), nil until something is first switched on; returned. The background reaches cPad past the
-- display's edges, under everything the display draws on itself; the border lies along the inside of that padded edge.
function ns.PaintGroupDeco(owner, d, fo)
    if not fo then
        if d then d.bg:Hide(); for i = 1, 4 do d[i]:Hide() end end
        return d
    end
    if not d then
        d = { bg = owner:CreateTexture(nil, "BACKGROUND", nil, -8) }
        for i = 1, 4 do d[i] = owner:CreateTexture(nil, "OVERLAY", nil, -8) end
    end
    local p = tonumber(fo.cPad) or 0   -- (SD-32: 0 px when none is saved)
    if fo.cBg then
        local bg, c, tex = d.bg, fo.cBgColor or DEF_BG, fo.cBgTex
        if d.bgPad ~= p then   -- (placed again only when the padding changed)
            bg:ClearAllPoints()
            bg:SetPoint("TOPLEFT", owner, "TOPLEFT", -p, p); bg:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", p, -p)
            d.bgPad = p
        end
        if (type(tex) == "string" and tex ~= "") or type(tex) == "number" then
            bg:SetTexture(tex); bg:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
        else
            bg:SetVertexColor(1, 1, 1, 1)   -- (a texture used before leaves its tint: the plain color must not be tinted by it)
            bg:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.45)
        end
        bg:Show()
    else d.bg:Hide() end
    if fo.cBorder then
        local c, s = fo.cBdColor or DEF_BD, math.max(1, tonumber(fo.cBdSize) or 1)
        if d.bdPad ~= p or d.edge ~= s then
            local t, b, l, r = d[1], d[2], d[3], d[4]
            for i = 1, 4 do d[i]:ClearAllPoints() end
            t:SetPoint("TOPLEFT", owner, "TOPLEFT", -p, p); t:SetPoint("TOPRIGHT", owner, "TOPRIGHT", p, p); t:SetHeight(s)
            b:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", -p, -p); b:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", p, -p); b:SetHeight(s)
            l:SetPoint("TOPLEFT", owner, "TOPLEFT", -p, p); l:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", -p, -p); l:SetWidth(s)
            r:SetPoint("TOPRIGHT", owner, "TOPRIGHT", p, p); r:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", p, -p); r:SetWidth(s)
            d.bdPad, d.edge = p, s
        end
        for i = 1, 4 do d[i]:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1); d[i]:Show() end
    else for i = 1, 4 do d[i]:Hide() end end
    return d
end
local function PaintFrameDeco(fr, rule)
    fr.xuiGrpDeco = ns.PaintGroupDeco(fr, fr.xuiGrpDeco, DecoGroup(rule.folder))
end
-- A group's border / background setting changed (the editor, each step of a slider or color drag): drawn again on its displays and
-- its nested groups' (f nil: every display), and on the engine's aura buttons.
function ns.RefreshGroupDeco(f)
    for rule, fr in pairs(frames) do
        if not f or InFolder(rule.folder, f.id) then pcall(PaintFrameDeco, fr, rule) end
    end
    if ns.EngineGroupDeco then pcall(ns.EngineGroupDeco) end
end
-- A group's X / Y in the units of what it is placed from, a changed X / Y applied, and centering a group on the screen on one axis or both
-- ("center" = the middle of what it shows on the screen's middle). The mover's X / Y box (XayaUI Options, Mover.lua) uses these through
-- ns.VisualPos.
local function GroupTargetScale(fo)
    local c = containers[fo.id]
    local ts = c and c.xuiTarget and c.xuiTarget.GetEffectiveScale and c.xuiTarget:GetEffectiveScale()
    if not ts or ts <= 0 then ts = UIParent:GetEffectiveScale() end
    return ts
end
local function GroupPosChanged(fo)
    Container(fo)
    ns.MarkDirty()
    ns.Fire("CONFIG_CHANGED")
end
local function CenterGroup(fo, onX, onY)
    local l, b, r, t = GroupBounds(fo)
    if not l then ns.Print("this group has nothing shown to center") return end
    local us, ts = UIParent:GetEffectiveScale(), GroupTargetScale(fo)
    local sx, sy = UIParent:GetCenter()
    if onX then fo.cX = math.floor((fo.cX or 0) + (sx - (l + r) / 2) * us / ts + 0.5) end
    if onY then fo.cY = math.floor((fo.cY or 0) + (sy - (b + t) / 2) * us / ts + 0.5) end
    GroupPosChanged(fo)
end
-- a frame's rectangle in screen pixels (nil when the game gives none)
local function ScreenRect(f)
    local ok, l, b, w, h = pcall(f.GetRect, f)
    if not (ok and l and w) then return nil end
    local s = f:GetEffectiveScale()
    return l * s, b * s, (l + w) * s, (b + h) * s
end

-- Which side of the target a box is on: h = "LEFT" / "RIGHT" / "" (overlapping), v = "TOP" / "BOTTOM" / "" (screen pixels)
local function SideOf(gl, gb, gr, gt, tl, tb, tr, tt)
    local gx, gy = (gl + gr) / 2, (gb + gt) / 2
    local h = (gx < tl) and "LEFT" or ((gx > tr) and "RIGHT" or "")
    local v = (gy > tt) and "TOP" or ((gy < tb) and "BOTTOM" or "")
    return h, v
end
local SIDE_OPP = { LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP", [""] = "" }   -- (sides only; OPP above has the corners: #268 outer anchors read that one)
local function GroupScreenBounds(fo)
    local l, b, r, t = GroupBounds(fo)
    if not l then return nil end
    local us = UIParent:GetEffectiveScale()
    return l * us, b * us, r * us, t * us
end
-- move the group's container by (dx, dy) screen pixels through its X / Y offset. One X / Y unit moves the container by
-- ce / div screen pixels, div being the divisor Container placed it with (its scale, fit, and for a nested group anchored to the
-- screen its parents' scales: pScale). (review fix 2: the parents' scales were left out, so such a group moved twice as far at 0.5.)
local function ShiftGroup(fo, dx, dy)
    local c = Container(fo)
    local ce = c:GetEffectiveScale()
    local div = c.xuiOffDiv or math.max(0.1, fo.cScale or 1)
    if not ce or ce <= 0 then return end
    fo.cX = math.floor((fo.cX or 0) + dx * div / ce + 0.5)
    fo.cY = math.floor((fo.cY or 0) + dy * div / ce + 0.5)
    Container(fo)
end
-- (review fix 1) the screen point (screen pixels) of the middle of what the group holds as it is drawn now: the container's centre plus
-- the middle of the grid (a dynamic group: GA.ContentOffset) in the container's own units. A hand-placed group's displays hang from
-- the container's centre whatever the anchor point is, so for it this is the container's centre.
local function ContentXY(fo)
    local c = Container(fo)
    local l, b, r, t = ScreenRect(c)
    if not l then return nil end
    local ox, oy = GA.ContentOffset(fo, c)
    local s = c:GetEffectiveScale()
    return (l + r) / 2 + ox * s, (b + t) / 2 + oy * s
end
-- re-anchor a group without moving what it shows: the middle of its contents (ContentXY) is measured before and after the change,
-- and X / Y make up the difference. (review fix 1: it measured the container's own point; since 0.6.82 the anchor point also decides
-- where a Right / Left / Down / Up grid sits on the container, so a new point made the icons jump.) Used by every path that promises
-- "it stays where it is": the picker (a frame or a group), Anchor to the screen, a deleted followed group, Cancel moves for a link to
-- a group that is gone. The settings page's point list does not come here (her answer: changing the point moves the icons).
local function Reanchor(fo, set)
    local x0, y0 = ContentXY(fo)
    set()
    fo.cX, fo.cY = 0, 0
    local x1, y1 = ContentXY(fo)
    if x0 and x1 then ShiftGroup(fo, x0 - x1, y0 - y1) end
    GroupPosChanged(fo)
end
function ns.AnchorGroupToFrame(fo, target, name)
    if not (fo and target and name) then return false end
    local gl, gb, gr, gt = GroupScreenBounds(fo)
    if not gl then local c = Container(fo); gl, gb, gr, gt = ScreenRect(c) end
    local tl, tb, tr, tt = ScreenRect(target)
    if not (gl and tl) then return false end
    local h, v = SideOf(gl, gb, gr, gt, tl, tb, tr, tt)
    local rel = (v .. h ~= "") and (v .. h) or "CENTER"
    local own = (SIDE_OPP[v] .. SIDE_OPP[h] ~= "") and (SIDE_OPP[v] .. SIDE_OPP[h]) or "CENTER"
    Reanchor(fo, function() fo.cRel, fo.cFrame, fo.cGroup, fo.cPoint, fo.cRelPoint = "custom", name, nil, own, rel end)
    return true, own, rel
end
-- B: another group's box on screen (screen pixels): its set box, else what it shows now (GroupScreenBounds), else its anchor point
function GA.BoxRect(t)
    if ns.GroupSizeMode(t) == "set" then return ScreenRect(Container(t)) end
    local l, b, r, tp = GroupScreenBounds(t)
    if l then return l, b, r, tp end
    local x, y = GA.AnchorXY(t)
    if not x then return nil end
    local us = UIParent:GetEffectiveScale()
    return x * us, y * us, x * us, y * us
end
-- B: anchor a group to another group without moving it (the same sides as a picked frame: the group's side facing the other group)
function ns.AnchorGroupToGroup(fo, t)
    if not (fo and t) or not ns.GroupAnchorAllowed(fo, t) then return false end
    local gl, gb, gr, gt = GroupScreenBounds(fo)
    if not gl then local c = Container(fo); gl, gb, gr, gt = ScreenRect(c) end
    local tl, tb, tr, tt = GA.BoxRect(t)
    if not (gl and tl) then return false end
    local h, v = SideOf(gl, gb, gr, gt, tl, tb, tr, tt)
    local rel = (v .. h ~= "") and (v .. h) or "CENTER"
    local own = (SIDE_OPP[v] .. SIDE_OPP[h] ~= "") and (SIDE_OPP[v] .. SIDE_OPP[h]) or "CENTER"
    Reanchor(fo, function() fo.cRel, fo.cGroup, fo.cFrame, fo.cPoint, fo.cRelPoint = "group", t.id, nil, own, rel end)
    return true, own, rel
end
-- B: the followed group is deleted ("Stays put, link cleared"): every group that follows one of `ids` keeps its place on screen and
-- is placed from the screen (or its parent group) from then on. Called by the Recycle Bin before the groups leave (RuleBin.lua).
-- (review fix 3b) A group already in the Recycle Bin that follows one of `ids` gets the same rule: while the followed group is still
-- here, its X / Y are changed so that, once restored, it sits where it sat when it was deleted, and the link is cleared. Its
-- displays are in the bin with it, so only its container is measured (before / after: the change of target is all that differs,
-- the same for what it holds). Exact when its parent group is not in the bin as well (then it is measured from the screen; the
-- restore puts it back in that parent: see the debug log, open points).
local function ReleaseBinned(a)
    local had = containers[a.id]
    local ok = pcall(function()
        local c = Container(a)
        local l, b, r, t = ScreenRect(c)
        a.cRel, a.cGroup = nil, nil
        if not l then return end
        a.cX, a.cY = 0, 0
        c = Container(a)
        local l1, b1, r1, t1 = ScreenRect(c)
        if l1 then ShiftGroup(a, (l + r) / 2 - (l1 + r1) / 2, (b + t) / 2 - (b1 + t1) / 2) end
    end)
    a.cRel, a.cGroup = nil, nil
    local c = containers[a.id]
    if c and not had then c:Hide(); containers[a.id] = nil end   -- (made only to measure: the restore makes its own)
    return ok
end
function ns.ReleaseGroupAnchors(ids)
    local n = 0
    for _, a in ipairs(ns.folders or {}) do
        if a.cRel == "group" and a.cGroup ~= nil and ids[a.cGroup] and not ids[a.id] then
            pcall(Reanchor, a, function() a.cRel, a.cGroup = nil, nil end)
            if a.cRel == "group" then a.cRel, a.cGroup = nil, nil end   -- (a failed measure still clears the link)
            n = n + 1
        end
    end
    local bin = ns.RecycleDB and ns.RecycleDB()
    for _, it in ipairs(bin and bin.items or {}) do
        for _, a in ipairs(type(it.folders) == "table" and it.folders or {}) do
            if type(a) == "table" and a.cRel == "group" and a.cGroup ~= nil and ids[a.cGroup] and not ids[a.id] then
                ReleaseBinned(a)
                n = n + 1
            end
        end
    end
    return n
end
-- (review fix 3) a link to a group that is not there (any more): cleared. For the Recycle Bin's restore (a group that was in the bin
-- when the group it followed was deleted, from before review fix 3b) and for imports. Nothing moves: Container already ignores
-- such a link (GA.Target). Returns how many were cleared.
function ns.ClearStaleGroupLinks(list)
    local n = 0
    for _, a in ipairs(list or ns.folders or {}) do
        if a.cRel == "group" and (a.cGroup == nil or not ns.FolderById(a.cGroup)) then a.cRel, a.cGroup = nil, nil; n = n + 1 end
    end
    return n
end
-- close the gap to the anchored frame on the side(s) the group is on (B: a followed group: its box)
function ns.SnapGroupFlush(fo)
    if not fo then return false end
    local gl, gb, gr, gt = GroupScreenBounds(fo)
    local tl, tb, tr, tt
    local tg = GA.Target(fo)
    if tg then tl, tb, tr, tt = GA.BoxRect(tg)
    else
        local target = fo and fo.cRel == "custom" and fo.cFrame and _G[fo.cFrame]
        if not (target and target.GetRect) then return false end
        tl, tb, tr, tt = ScreenRect(target)
    end
    if not (gl and tl) then return false end
    local h, v = SideOf(gl, gb, gr, gt, tl, tb, tr, tt)
    local dx = (h == "LEFT" and (tl - gr)) or (h == "RIGHT" and (tr - gl)) or 0
    local dy = (v == "TOP" and (tt - gb)) or (v == "BOTTOM" and (tb - gt)) or 0
    ShiftGroup(fo, dx, dy)
    GroupPosChanged(fo)
    return true
end
function ns.UnanchorGroup(fo)
    if not fo then return end
    Reanchor(fo, function() fo.cRel, fo.cFrame, fo.cGroup, fo.cPoint, fo.cRelPoint = nil, nil, nil, nil, nil end)
end

-- /xui debug groups moved to XayaUI Dev Assist (core 0.6.56; REQUEST-LOG #81, XayaUI_DevAssist/CoreDebug.lua). It reads the frames
-- through this (read-only; nothing runs until it is typed).
function ns.VisualProbeState() return frames, containers, DynAncestor end


-------------------------------------------------------------------------------
-- Snap targets: pin a display to the edge of a Blizzard frame. `pos` = side + alignment along that side.
-- Frame names for the action bars follow the retail names [MEMORY: unverified for this build]; a name that does not exist
-- is skipped, and a missing target leaves the display where its own X / Y put it.
-------------------------------------------------------------------------------
local SNAP_TARGETS = {
    { key = "player", label = "Player Frame", frames = { "PlayerFrame" } },
    { key = "target", label = "Target Frame", frames = { "TargetFrame" } },
    { key = "focus",  label = "Focus Frame", frames = { "FocusFrame" } },
    { key = "party",  label = "Party Frames", frames = { "PartyFrame" } },
    { key = "buff",   label = "Buffs", frames = { "BuffFrame" } },
    { key = "debuff", label = "Debuffs", frames = { "DebuffFrame" } },
    { key = "chat",   label = "Chat Frame", frames = { "ChatFrame1" } },
    { key = "bar1",   label = "Action Bar 1 (Main)", frames = { "MainActionBar", "MainMenuBar" } },
    { key = "bar2",   label = "Action Bar 2 (Bottom Left)", frames = { "MultiBarBottomLeft" } },
    { key = "bar3",   label = "Action Bar 3 (Bottom Right)", frames = { "MultiBarBottomRight" } },
    { key = "bar4",   label = "Action Bar 4 (Right)", frames = { "MultiBarRight" } },
    { key = "bar5",   label = "Action Bar 5 (Right 2)", frames = { "MultiBarLeft" } },
    { key = "bar6",   label = "Action Bar 6", frames = { "MultiBar5" } },
    { key = "bar7",   label = "Action Bar 7", frames = { "MultiBar6" } },
    { key = "bar8",   label = "Action Bar 8", frames = { "MultiBar7" } },
}
-- my point -> the target's point, so the display sits OUTSIDE the target on the chosen side
local SNAP_ANCHOR = {
    TOP_LEFT = { "BOTTOMLEFT", "TOPLEFT" }, TOP_CENTER = { "BOTTOM", "TOP" }, TOP_RIGHT = { "BOTTOMRIGHT", "TOPRIGHT" },
    RIGHT_TOP = { "TOPLEFT", "TOPRIGHT" }, RIGHT_CENTER = { "LEFT", "RIGHT" }, RIGHT_BOTTOM = { "BOTTOMLEFT", "BOTTOMRIGHT" },
    BOTTOM_RIGHT = { "TOPRIGHT", "BOTTOMRIGHT" }, BOTTOM_CENTER = { "TOP", "BOTTOM" }, BOTTOM_LEFT = { "TOPLEFT", "BOTTOMLEFT" },
    LEFT_BOTTOM = { "BOTTOMRIGHT", "BOTTOMLEFT" }, LEFT_CENTER = { "RIGHT", "LEFT" }, LEFT_TOP = { "TOPRIGHT", "TOPLEFT" },
}
local function SnapFrame(v)
    local sn = v and v.snap
    if not (sn and sn.target) then return nil end
    if sn.target == "custom" then   -- a frame picked on screen (ns.PickFrame), kept by its name
        local g = type(sn.frame) == "string" and _G[sn.frame]
        if g and g.GetCenter then return g end
        return nil
    end
    for _, t in ipairs(SNAP_TARGETS) do
        if t.key == sn.target then
            for _, n in ipairs(t.frames) do
                local g = _G[n]
                if g and g.GetCenter then return g end
            end
        end
    end
end
-- one place decides where a display is anchored: to its snap target when it has one, else to its container
-- Anchors: a display's X / Y are measured from one point of its parent (the screen, or its group's container box). v.anchor is that point
-- (nil = CENTER). Inner (default) puts the display's own matching point on it, flush inside the box; outer (v.anchorPlace = "outer") puts the
-- display's OPPOSITE point there, so the display sits outside the box. Ignored while snapped to a Blizzard frame and in dynamic groups.
local ANCH = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }
-- P1 (#268, Xaya 2026-11-06: "separate points"; labels "Anchor point" -> "Anchored to" -> "To <target>'s point"): v.point is the
-- display's own point, chosen on its own. Older saves have none: their display point follows v.anchor (inner) or its opposite (outer).
local function AnchorPts(v)   -- the point on the parent, the point on the display
    local a = ANCH[v.anchor] and v.anchor or "CENTER"
    if ANCH[v.point] then return a, v.point end
    return a, (v.anchorPlace == "outer") and OPP[a] or a
end
function ns.VisualPoints(rule)   -- (the target's point, the display's own point) as used now
    return AnchorPts(rule and rule.visual or {})
end
local function VisDims(rule)   -- display size and parent size, in the parent's units
    local v = rule.visual
    local parent = ParentFor(rule)
    return math.max(8, v.w or 128), math.max(8, v.h or 128), (parent.GetWidth and parent:GetWidth()) or 0, (parent.GetHeight and parent:GetHeight()) or 0
end
-- where the display's CENTER is, as an offset from the parent's CENTER, whatever the anchor is
function ns.VisualCenterOffset(rule)
    local v = rule.visual
    local a, f = AnchorPts(v)
    local w, h, pw, ph = VisDims(rule)
    local A, F = ANCH[a], ANCH[f]
    return (v.x or 0) - (F[1] - 0.5) * w + (A[1] - 0.5) * pw, (v.y or 0) - (F[2] - 0.5) * h + (A[2] - 0.5) * ph
end
-- the inverse: store X / Y (rounded) so the display's center lands at that offset from the parent's center
function ns.SetVisualCenterOffset(rule, cx, cy)
    local v = rule.visual
    local a, f = AnchorPts(v)
    local w, h, pw, ph = VisDims(rule)
    local A, F = ANCH[a], ANCH[f]
    v.x = math.floor(cx + (F[1] - 0.5) * w - (A[1] - 0.5) * pw + 0.5)
    v.y = math.floor(cy + (F[2] - 0.5) * h - (A[2] - 0.5) * ph + 0.5)
end
-- P1: set the display's own point ("Anchor point") and / or the target's point ("To <target>'s point") separately; the display stays
-- exactly where it is (X / Y are recalculated). Once either is set this way the two points are independent (inner / outer no longer apply).
function ns.SetVisualPoints(rule, selfPoint, targetPoint)
    local v = rule and rule.visual
    if not v then return end
    local cx, cy = ns.VisualCenterOffset(rule)
    local a, f = AnchorPts(v)
    v.point = ANCH[selfPoint] and selfPoint or f
    v.anchor = ANCH[targetPoint] and targetPoint or a
    if v.anchor == "CENTER" then v.anchor = nil end
    v.anchorPlace = nil
    ns.SetVisualCenterOffset(rule, cx, cy)
    ns.RefreshVisual(rule)
    ns.Fire("CONFIG_CHANGED")
end
-- what the display is anchored to, for the "Anchored to" line: kind ("frame" / "group" / "screen") and a name
function ns.VisualAnchorTarget(rule)
    local v = rule and rule.visual
    if not v then return "screen", "the screen" end
    if v.snap and SnapFrame(v) then
        if v.snap.target == "custom" then return "frame", tostring(v.snap.frame or "a game frame") end
        for _, t in ipairs(SNAP_TARGETS) do if t.key == v.snap.target then return "frame", t.label end end
        return "frame", "a game frame"
    end
    local _, dyn = ParentFor(rule)
    local f = dyn or (rule.folder and ns.FolderById(rule.folder))
    if f then return dyn and "dynamic" or "group", tostring(f.name or "its group") end
    return "screen", "the screen"
end
-- change the anchor and / or inner-outer; X / Y are recalculated so the display stays exactly where it is
function ns.SetVisualAnchor(rule, anchor, place)
    local v = rule.visual
    if not v then return end
    local cx, cy = ns.VisualCenterOffset(rule)
    if anchor ~= nil then v.anchor = (ANCH[anchor] and anchor ~= "CENTER") and anchor or nil end
    if place ~= nil then v.anchorPlace = (place == "outer") and "outer" or nil end
    ns.SetVisualCenterOffset(rule, cx, cy)
    ns.RefreshVisual(rule)
    ns.Fire("CONFIG_CHANGED")
end
-- G7 (Xaya 2026-11-06: "align / distribute / spacing saved and kept applying"; when one display is dragged: "Arrangement wins"):
-- a static group can keep one arrangement per direction: f.cArrX = left / center / right / distribute / space, f.cArrY = top / middle /
-- bottom / distribute / space, f.cArrGap = the gap for space. It is applied again whenever one of its displays is refreshed,
-- dragged or nudged, so a dragged display goes back into line and a new or resized one joins it. It works on the displays directly in
-- the group (each nested group keeps its own) that are not snapped to a game frame; dynamic groups place their displays themselves.
-- ns.ArrangeList is also what the one-shot Align / Distribute / Space buttons use.
local Place   -- (defined below; the arrangement places frames with it)
local function ArrDims(r) local v = r.visual; return tonumber(v.x) or 0, tonumber(v.y) or 0, math.max(8, tonumber(v.w) or 128), math.max(8, tonumber(v.h) or 128) end
-- audit D18 (core 0.6.67): centres stay exact here and are rounded once, when X / Y are stored (SetVisualCenterOffset). Rounding the
-- centre too moved a display 1 px per apply whenever its centre fell on a half pixel (odd size with a corner anchor, ...), and the
-- arrangement is re-applied on every refresh: displays crept and the mover view reported moves nobody made.
-- (review R21) That alone still crept when the displays mix odd and even sizes: a display rounded half a pixel past the shared edge
-- made that edge the new reference on the next apply. So each placed centre is snapped here to where the display's whole-number X / Y
-- really puts it (k = stored X / Y minus centre), and on the side that never passes the reference: Align left / right / top / bottom
-- round towards the inside of the edge (the display that sets the edge stays where it is, so the edge never moves); Align center /
-- middle put the reference on the widest / tallest display's own grid first (the others then lie within half a pixel of it, so the
-- reference comes back the same); Distribute and Space round to the nearest pixel from ends that do not move. Applying again then
-- changes nothing.
local ArrKX, ArrKY = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })   -- (per call: centre -> stored X / Y offset)
local function ArrSnap(k, c, dir)   -- the centre nearest c that a whole-number X / Y can give; dir "up" / "down" never passes c
    local s = c + k
    if dir == "up" then s = math.ceil(s - 1e-6) elseif dir == "down" then s = math.floor(s + 1e-6) else s = math.floor(s + 0.5) end
    return s - k
end
local function ArrWidest(l, horiz)   -- the widest (horiz) / tallest display; the first in the list on a tie
    local best, bs
    for _, r in ipairs(l) do
        local _, _, w, h = ArrDims(r)
        local sz = horiz and w or h
        if not bs or sz > bs then best, bs = r, sz end
    end
    return best
end
function ns.ArrangeList(l, xMode, yMode, gap)
    if #l < 2 or not (xMode or yMode) then return false end
    gap = tonumber(gap) or 8
    for _, r in ipairs(l) do
        local v = r.visual
        local cx, cy = ns.VisualCenterOffset(r)
        ArrKX[r], ArrKY[r] = (tonumber(v.x) or 0) - cx, (tonumber(v.y) or 0) - cy
        v.x, v.y = cx, cy
    end
    local function sorted(horiz)
        local t = {}
        for i, r in ipairs(l) do t[i] = r end
        table.sort(t, function(a, b)
            local ax, ay = ArrDims(a); local bx, by = ArrDims(b)
            if horiz then if ax ~= bx then return ax < bx end else if ay ~= by then return ay > by end end
            return tostring(a.name) < tostring(b.name)   -- (a fixed order for ties, so applying again changes nothing)
        end)
        return t
    end
    if xMode == "left" or xMode == "center" or xMode == "right" then
        local lo, hi = math.huge, -math.huge
        for _, r in ipairs(l) do local x, _, w = ArrDims(r); lo = math.min(lo, x - w / 2); hi = math.max(hi, x + w / 2) end
        local mid
        if xMode == "center" then local wr = ArrWidest(l, true); mid = ArrSnap(ArrKX[wr], (lo + hi) / 2) end
        for _, r in ipairs(l) do local _, _, w = ArrDims(r)
            if xMode == "left" then r.visual.x = ArrSnap(ArrKX[r], lo + w / 2, "up")
            elseif xMode == "right" then r.visual.x = ArrSnap(ArrKX[r], hi - w / 2, "down")
            else r.visual.x = ArrSnap(ArrKX[r], mid) end
        end
    elseif xMode == "distribute" then
        local t = sorted(true)
        local a, b = ArrDims(t[1]), ArrDims(t[#t])
        for i, r in ipairs(t) do r.visual.x = ArrSnap(ArrKX[r], a + (b - a) * (i - 1) / (#t - 1)) end
    elseif xMode == "space" then
        local t, cur = sorted(true)
        for i, r in ipairs(t) do
            local x, _, w = ArrDims(r)
            if i == 1 then cur = x + w / 2 else r.visual.x = ArrSnap(ArrKX[r], cur + gap + w / 2); cur = r.visual.x + w / 2 end
        end
    end
    if yMode == "top" or yMode == "middle" or yMode == "bottom" then
        local top, bot = -math.huge, math.huge
        for _, r in ipairs(l) do local _, y, _, h = ArrDims(r); top = math.max(top, y + h / 2); bot = math.min(bot, y - h / 2) end
        local mid
        if yMode == "middle" then local hr = ArrWidest(l, false); mid = ArrSnap(ArrKY[hr], (top + bot) / 2) end
        for _, r in ipairs(l) do local _, _, _, h = ArrDims(r)
            if yMode == "top" then r.visual.y = ArrSnap(ArrKY[r], top - h / 2, "down")
            elseif yMode == "bottom" then r.visual.y = ArrSnap(ArrKY[r], bot + h / 2, "up")
            else r.visual.y = ArrSnap(ArrKY[r], mid) end
        end
    elseif yMode == "distribute" then
        local t = sorted(false)
        local _, a = ArrDims(t[1]); local _, b = ArrDims(t[#t])
        for i, r in ipairs(t) do r.visual.y = ArrSnap(ArrKY[r], a + (b - a) * (i - 1) / (#t - 1)) end
    elseif yMode == "space" then
        local t, cur = sorted(false)
        for i, r in ipairs(t) do
            local _, y, _, h = ArrDims(r)
            if i == 1 then cur = y - h / 2 else r.visual.y = ArrSnap(ArrKY[r], cur - gap - h / 2); cur = r.visual.y - h / 2 end
        end
    end
    for _, r in ipairs(l) do ns.SetVisualCenterOffset(r, r.visual.x, r.visual.y); ArrKX[r], ArrKY[r] = nil, nil end
    return true
end
local arranging = false
function ns.GroupArrangement(f) return f and (f.cArrX or f.cArrY) and f.cType ~= "dynamic" and true or false end
function ns.ApplyGroupArrangement(f)
    if arranging or not ns.GroupArrangement(f) then return false end
    local l = {}
    for _, r in ipairs(ns.rules or {}) do
        local v = r.visual
        if r.folder == f.id and type(v) == "table" and v.enabled and not (v.snap and v.snap.target) then l[#l + 1] = r end
    end
    if #l < 2 then return false end
    arranging = true
    local ok = pcall(ns.ArrangeList, l, f.cArrX, f.cArrY, f.cArrGap)
    for _, r in ipairs(l) do
        local fr = frames[r]
        if fr then pcall(Place, fr, r, (ParentFor(r))) end
    end
    arranging = false
    return ok
end
local function ArrangeAfter(rule)   -- the display's group keeps an arrangement: put it (and its neighbours) back in line
    if arranging or not (rule and rule.folder) then return end
    local f = ns.FolderById(rule.folder)
    if f and ns.GroupArrangement(f) then ns.ApplyGroupArrangement(f) end
end
function Place(fr, rule, parent)   -- (the local declared above the arrangement)
    local v = rule.visual
    local g = SnapFrame(v)
    fr:ClearAllPoints()
    if g then
        local a = SNAP_ANCHOR[v.snap.pos or "TOP_CENTER"] or SNAP_ANCHOR.TOP_CENTER
        fr:SetPoint(a[1], g, a[2], v.x or 0, v.y or 0)   -- x / y are fine offsets from the snap point
    else
        local a, f = AnchorPts(v)
        fr:SetPoint(f, parent, a, v.x or 0, v.y or 0)
    end
end
-- read where the frame is now and store it as the display's own X / Y (dragging always leaves any snap target). snapFn: the mover's drag
-- snapping (XayaUI Options, Mover.lua ns.SnapPosition), or nil to store the spot as it is
local function CommitDrag(rule, fr, snapFn)
    local v = rule.visual
    v.snap = nil
    local parent, dyn = ParentFor(rule)
    local cx, cy = fr:GetCenter()
    if not cx then return end
    local ux, uy = parent:GetCenter()
    local s = fr:GetEffectiveScale() / parent:GetEffectiveScale()
    local cox, coy = cx * s - ux, cy * s - uy   -- center offsets; snapping works on these, then they are stored relative to the anchor
    if snapFn then cox, coy = snapFn(rule, fr, math.floor(cox + 0.5), math.floor(coy + 0.5)) end
    ns.SetVisualCenterOffset(rule, cox, coy)
    Place(fr, rule, parent)
    if dyn then LayoutDynamic(dyn) end
    ArrangeAfter(rule)   -- G7: "arrangement wins"
    ns.Fire("CONFIG_CHANGED")
end
-- place a display again from its saved X / Y (the mover's arrow-key nudge): its group's layout or arrangement follows
local function PlaceDisplay(r)
    local fr = frames[r]
    if not fr then return false end
    local parent, dyn = ParentFor(r)
    Place(fr, r, parent)
    if dyn then LayoutDynamic(dyn) else ArrangeAfter(r) end
    return true
end
-- a display snapped to a frame picked on screen: the side and alignment nearest to where the display is now (SNAP_POS keys)
local function SnapPosFor(dl, db, dr, dt, tl, tb, tr, tt)
    local h, v = SideOf(dl, db, dr, dt, tl, tb, tr, tt)
    local dx, dy = (dl + dr) / 2, (db + dt) / 2
    if h ~= "" and v == "" then
        local third = (tt - tb) / 3
        return h .. "_" .. ((dy > tt - third) and "TOP" or ((dy < tb + third) and "BOTTOM" or "CENTER"))
    elseif v ~= "" then
        local third = (tr - tl) / 3
        return v .. "_" .. ((dx < tl + third) and "LEFT" or ((dx > tr - third) and "RIGHT" or "CENTER"))
    end
    return "TOP_CENTER"
end
function ns.SnapToPicked(rule, target, name)
    if not (rule and rule.visual and target and name) then return false end
    local v = rule.visual
    local fr = frames[rule]
    local pos = "TOP_CENTER"
    local tl, tb, tr, tt = ScreenRect(target)
    local dl, db, dr, dt
    if fr then dl, db, dr, dt = ScreenRect(fr) end
    if tl and dl then pos = SnapPosFor(dl, db, dr, dt, tl, tb, tr, tt) end
    v.snap = { target = "custom", frame = name, pos = pos }
    v.x, v.y = 0, 0
    ns.RefreshVisual(rule)
    ns.Fire("CONFIG_CHANGED")
    return true, pos
end
function ns.SnapToTarget(rule, key, pos)
    local v = rule.visual
    if not key then
        v.snap = nil
    else
        -- audit D19 (core 0.6.67): check the frame first; a missing frame changes nothing (before, X / Y were zeroed and the snap saved)
        if not SnapFrame({ snap = { target = key } }) then ns.Print("that frame does not exist in this client, so the aura keeps its own position."); return end
        v.snap = { target = key, pos = pos or "TOP_CENTER" }
        v.x, v.y = 0, 0
    end
    ns.RefreshVisual(rule)
    ns.Fire("CONFIG_CHANGED")
end
-- Center on the current reference: the snap target's axis when snapped, otherwise the screen (the folder container's origin).
function ns.CenterVisual(rule, axis)
    local v = rule.visual
    if v.snap and v.snap.target then
        local side = tostring(v.snap.pos or "TOP_CENTER"):match("^(%u+)_")
        if axis == "h" and (side == "TOP" or side == "BOTTOM") then v.snap.pos = side .. "_CENTER"; v.x = 0
        elseif axis == "v" and (side == "LEFT" or side == "RIGHT") then v.snap.pos = side .. "_CENTER"; v.y = 0
        else ns.Print("this aura is snapped to that side of the frame; choose a top / bottom (horizontal) or left / right (vertical) snap to center along it.") return end
    else
        local cx, cy = ns.VisualCenterOffset(rule)   -- "center" = the middle of the reference, whatever the anchor is
        if axis == "h" then cx = 0 else cy = 0 end
        ns.SetVisualCenterOffset(rule, cx, cy)
    end
    ns.RefreshVisual(rule)
    ns.Fire("CONFIG_CHANGED")
end

-- (Rules 0.6.78; #495, REQUEST-LOG PS-59) while the settings window is shown, a right-click on a display (it takes clicks while it is
-- unlocked for moving, as before) opens the element menu (XayaUI Options, ElementMenu.lua): "Element options" (this display's settings in
-- the rule editor, as a left click and "Edit This Aura" do), X and Y (this display's own visual.x / visual.y: the editor's Position X /
-- Y), then the display menu's entries (XayaUI Options, Mover.lua: the settings window is open, so it is loaded).
-- Registered with the first display frame made (no display, nothing registered: V14).
local DISPLAY_ELEMENT = {
    key = "ruleDisplays", label = "Display",
    targets = function(add) for r, fr in pairs(frames) do add(fr, "OnMouseUp", r) end end,
    open = function(rule) if ns.EditRule then ns.EditRule(rule) end end,
    getPos = function(rule) local v = rule.visual; return tonumber(v and v.x) or 0, tonumber(v and v.y) or 0 end,
    setPos = function(rule, x, y)
        local v = rule.visual
        if type(v) ~= "table" then return end
        v.x, v.y = x, y
        ns.RefreshVisual(rule)
        if ns.MarkDirty then ns.MarkDirty() end
    end,
    rows = function(rule) local M = ns.MoverDisplay; return M and M.MenuParts(rule) or {} end,
}

local function GetFrame(rule)
    local fr = frames[rule]
    if fr then return fr end
    fr = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    fr:SetFrameStrata("HIGH")
    fr:SetClampedToScreen(true)

    fr.bg = fr:CreateTexture(nil, "BACKGROUND", nil, -3)
    fr.bg:SetAllPoints()
    fr.bg:Hide()

    -- outline glow: copies of the art pushed out on concentric pixel-snapped rings, behind the image
    fr.olHolder = CreateFrame("Frame", nil, fr)
    fr.olHolder:SetAllPoints()
    fr.olHolder:SetFrameLevel(math.max(0, fr:GetFrameLevel() - 1))
    fr.ol = {}   -- textures are created on demand (see LayoutOutline)
    fr.olAnim = fr.olHolder:CreateAnimationGroup()
    fr.olAnim:SetLooping("BOUNCE")
    local olPulse = fr.olAnim:CreateAnimation("Alpha")
    olPulse:SetFromAlpha(1)
    olPulse:SetToAlpha(0.25)
    olPulse:SetDuration(0.6)

    fr.tex = fr:CreateTexture(nil, "ARTWORK")
    fr.tex:SetAllPoints()
    fr.tex2 = fr:CreateTexture(nil, "ARTWORK", nil, 1)   -- optional overlay layer
    fr.tex2:SetAllPoints()
    fr.tex2:Hide()

    fr.border = {}
    for i = 1, 4 do
        local b = fr:CreateTexture(nil, "OVERLAY")
        b:Hide()
        fr.border[i] = b
    end


    -- pulsing glow ring (built-in Blizzard button border, additive)
    fr.glow = fr:CreateTexture(nil, "OVERLAY")
    fr.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    fr.glow:SetBlendMode("ADD")
    fr.glow:SetPoint("CENTER")
    fr.glow:Hide()
    fr.glowAnim = fr.glow:CreateAnimationGroup()
    fr.glowAnim:SetLooping("BOUNCE")
    local pulse = fr.glowAnim:CreateAnimation("Alpha")
    pulse:SetFromAlpha(1)
    pulse:SetToAlpha(0.25)
    pulse:SetDuration(0.5)

    -- duration text: our own FontString (readable values) ...
    -- all texts live on a holder frame ABOVE the cooldown widget, overlay layer and outline (frame level +10),
    -- so no progress texture or wipe can ever cover them
    fr.txtHolder = CreateFrame("Frame", nil, fr)
    fr.txtHolder:SetAllPoints()
    fr.txtHolder:SetFrameLevel(fr:GetFrameLevel() + 10)
    fr.txtHolder:EnableMouse(false)
    fr.text = fr.txtHolder:CreateFontString(nil, "OVERLAY", nil, 7)
    fr.text:SetFontObject(GameFontNormal)
    fr.text:Hide()
    -- ... and a Blizzard Cooldown widget as the fallback when the numbers are secret. Its own built-in countdown
    -- digits are a SEPARATE draw path from fr.text (used only when the exact remaining time is secret, i.e. almost
    -- always in combat) and were left at fr's own frame level, so the overlay texture / outline could still cover
    -- them even after txtHolder was added for fr.text / fr.count / fr.absorb. Match txtHolder's elevated level.
    local okc, cd = pcall(CreateFrame, "Cooldown", nil, fr, "CooldownFrameTemplate")
    if okc and cd then
        cd:SetFrameLevel(fr:GetFrameLevel() + 10)
        cd:SetAllPoints()
        pcall(cd.SetDrawSwipe, cd, false)
        pcall(cd.SetDrawEdge, cd, false)
        pcall(cd.SetDrawBling, cd, false)
        pcall(cd.SetHideCountdownNumbers, cd, false)
        cd:Hide()
        fr.cd = cd
    end
    -- stacks / charges text
    fr.count = fr.txtHolder:CreateFontString(nil, "OVERLAY", nil, 7)
    fr.count:SetFontObject(GameFontNormal)
    fr.count:Hide()
    fr.absorb = fr.txtHolder:CreateFontString(nil, "OVERLAY", nil, 7)
    fr.absorb:SetFontObject(GameFontNormal)
    fr.absorb:Hide()

    -- (bundle 1 round 7, SD-58) The mouse on a display. "Show tooltip on hover" is the display's own. Everything the mover does with a
    -- display (its hover look and tooltip, drag, click to edit, right-click menu, and making it movable at all) is XayaUI Options'
    -- Mover.lua, reached through ns.MoverDisplay, which exists only once the settings window's code has loaded. A display takes clicks
    -- only while the mover has it unlocked (RefreshVisual), so these forward nothing otherwise.
    -- (round 7 repair, V28) Each forwards only while this display is unlocked, which is only while the settings window is open (the
    -- window's closing locks every display first, Mover.lua WindowClosed): with the window closed, a "Show tooltip on hover" display's
    -- mouse runs none of XayaUI Options' code, in or out of combat. A drag still running when its display locks is ended by the mover
    -- itself (Mover.lua DropDrag), so no drag waits for a stop that is not forwarded. RefreshVisual clears the mover's hover look.
    fr:SetScript("OnEnter", function(self)
        local M = Unl(rule) and ns.MoverDisplay
        if M then M.Enter(rule, self) elseif rule.visual and rule.visual.hoverTip then ns.ShowCueTooltip(rule, self) end
    end)
    fr:SetScript("OnLeave", function(self)
        local M = Unl(rule) and ns.MoverDisplay
        if M then M.Leave(rule, self) end
        if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    fr:SetScript("OnDragStart", function(self) local M = Unl(rule) and ns.MoverDisplay; if M then M.DragStart(rule, self) end end)
    fr:SetScript("OnDragStop", function(self) local M = Unl(rule) and ns.MoverDisplay; if M then M.DragStop(rule, self) end end)
    fr:SetScript("OnMouseUp", function(self, button) local M = Unl(rule) and ns.MoverDisplay; if M then M.MouseUp(rule, self, button) end end)
    -- smooth animation: the engine ticks 5x per second, which made the wipe / fades step. While one of those
    -- effects is active, re-run just that part every rendered frame from the stored (absolute) expiry time.
    -- (the per-frame effects script is attached only while an effect is running: see FxOnUpdate / SetFxRule)
    frames[rule] = fr
    if ns.RegisterElement then ns.RegisterElement(DISPLAY_ELEMENT) end   -- (#495) the new frame takes the right-click while the window is shown
    return fr
end

local function LayoutBorder(fr, v)
    local b = v.border
    if not (b and b.enabled) then
        for i = 1, 4 do fr.border[i]:Hide() end
        return
    end
    local sz = clamp(b.size or 1, 1, 10)
    local c = b.color or { 0, 0, 0, 1 }
    local t = fr.border
    for i = 1, 4 do t[i]:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1); t[i]:ClearAllPoints(); t[i]:Show() end
    t[1]:SetPoint("TOPLEFT"); t[1]:SetPoint("TOPRIGHT"); t[1]:SetHeight(sz)
    t[2]:SetPoint("BOTTOMLEFT"); t[2]:SetPoint("BOTTOMRIGHT"); t[2]:SetHeight(sz)
    t[3]:SetPoint("TOPLEFT"); t[3]:SetPoint("BOTTOMLEFT"); t[3]:SetWidth(sz)
    t[4]:SetPoint("TOPRIGHT"); t[4]:SetPoint("BOTTOMRIGHT"); t[4]:SetWidth(sz)
end

-- One physical screen pixel, in this frame's coordinate units (so outline offsets land on whole pixels).
local function PixelUnit(fr)
    local u = 1
    if GetPhysicalScreenSize then
        local ok, _, h = pcall(GetPhysicalScreenSize)
        local es = fr:GetEffectiveScale()
        if ok and h and h > 0 and es and es > 0 then u = (768 / h) / es end
    end
    return u
end

-- Outline styles: "border" = a crisp pixel border (own thickness, gap and color) with an optional soft glow around it,
-- drawn from solid strips on whole screen pixels; "shape" = copies of the art pushed outward (follows non-rectangular art).
-- Automatic picks the border for spell icons and the shape outline for everything else.
local function OutlineStyle(v)
    local st = v.outline and v.outline.style or "auto"
    if st == "auto" then st = (v.kind == "spellicon") and "border" or "shape" end
    return st
end
-- four strips forming a rectangular ring around the frame, from `inner` to `outer` pixels outside its edge
local function RingStrips(fr, list, at, inner, outer, r, g, b, a, blend)
    for k = 0, 3 do
        local t = list[at + k]
        if not t then
            t = fr.olHolder:CreateTexture(nil, "ARTWORK")
            list[at + k] = t
        end
        t:ClearAllPoints()
        if k == 0 then          -- top (full width, including the corners)
            t:SetPoint("BOTTOMLEFT", fr, "TOPLEFT", -outer, inner); t:SetPoint("TOPRIGHT", fr, "TOPRIGHT", outer, outer)
        elseif k == 1 then      -- bottom
            t:SetPoint("TOPLEFT", fr, "BOTTOMLEFT", -outer, -inner); t:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", outer, -outer)
        elseif k == 2 then      -- left (between the top and bottom strips)
            t:SetPoint("TOPLEFT", fr, "TOPLEFT", -outer, inner); t:SetPoint("BOTTOMRIGHT", fr, "BOTTOMLEFT", -inner, -inner)
        else                    -- right
            t:SetPoint("TOPLEFT", fr, "TOPRIGHT", inner, inner); t:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", outer, -inner)
        end
        t:SetColorTexture(r, g, b, a)
        t:SetBlendMode(blend)
        t:Show()
    end
end
local function LayoutPixelBorder(fr, v)
    local o = v.outline
    fr.olPx = fr.olPx or {}
    local list = fr.olPx
    local u = PixelUnit(fr)
    local function px(n) return math.max(0, math.floor(n + 0.5)) * u end
    local used = 0
    local bw, gap = clamp(math.floor((o.width or 2) + 0.5), 1, 10), clamp(math.floor((o.gap or 0) + 0.5), 0, 8)
    local c = o.color or { 1, 0.82, 0, 1 }
    if o.borderOn ~= false then
        RingStrips(fr, list, used + 1, px(gap), px(gap + bw), c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1, "BLEND")
        used = used + 4
    end
    if o.glowOn ~= false then
        local gs = clamp(math.floor((o.glowSize or 8) + 0.5), 1, 24)
        local ga = clamp(o.glowAlpha or 0.6, 0.05, 1)
        local gc = (o.glowSame == false and o.glowColor) or c
        local rings = math.min(gs, 12)
        local t = math.max(1, math.floor(gs / rings + 0.5))     -- pixels per ring
        local start = gap + ((o.borderOn ~= false) and bw or 0)
        for i = 1, rings do
            local inner, outer = start + (i - 1) * t, start + i * t
            local fall = (1 - (i - 0.5) / rings)
            RingStrips(fr, list, used + 1, px(inner), px(outer), gc[1] or 1, gc[2] or 1, gc[3] or 1, ga * fall * fall * (gc[4] or 1), "ADD")
            used = used + 4
        end
    end
    for i = used + 1, #list do list[i]:Hide() end
end
local function HidePixelBorder(fr)
    for i = 1, #(fr.olPx or {}) do fr.olPx[i]:Hide() end
end

local function LayoutOutline(fr, rule, v)
    local o = v.outline
    if not (o and o.enabled) then
        for i = 1, #fr.ol do fr.ol[i]:Hide() end
        HidePixelBorder(fr)
        fr.olAnim:Stop()
        return
    end
    if OutlineStyle(v) == "border" then
        for i = 1, #fr.ol do fr.ol[i]:Hide() end
        LayoutPixelBorder(fr, v)
    else
        HidePixelBorder(fr)
        local w = clamp(math.floor((o.width or 2) + 0.5), 1, 10)
        local c = o.color or { 1, 0.82, 0, 1 }
        local u = PixelUnit(fr)
        -- concentric rings (up to 4) so the stroke is filled all the way from the art to `w` px, with enough
        -- samples per ring that there are no gaps; offsets snapped to whole pixels; duplicates removed
        local offsets, seen = {}, {}
        local rings = math.min(w, 4)
        for k = 1, rings do
            local r = w * k / rings
            local n = clamp(math.ceil(2 * math.pi * r / 1.25), 8, 48)
            for j = 0, n - 1 do
                local ang = j * 2 * math.pi / n + (k % 2) * math.pi / n
                local dx = math.floor(math.cos(ang) * r / u + 0.5) * u
                local dy = math.floor(math.sin(ang) * r / u + 0.5) * u
                local key = dx .. "," .. dy
                if not seen[key] then seen[key] = true; offsets[#offsets + 1] = { dx, dy } end
            end
        end
        for i = #fr.ol + 1, #offsets do
            local t = fr.olHolder:CreateTexture(nil, "ARTWORK")
            pcall(t.SetSnapToPixelGrid, t, false)
            pcall(t.SetTexelSnappingBias, t, 0)
            t:Hide()
            fr.ol[i] = t
        end
        for i = 1, #fr.ol do
            local t = fr.ol[i]
            local off = offsets[i]
            if off then
                AnchorArt(t, fr, v, off[1], off[2])
                SetArt(t, rule, v)
                t:SetDesaturated(true)   -- so the color below is the color you see, not the art's own hues
                t:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
                t:SetBlendMode(v.additive and "ADD" or "BLEND")
                t:Show()
            else
                t:Hide()
            end
        end
    end
    if o.pulse then
        if not fr.olAnim:IsPlaying() then fr.olAnim:Play() end
    else
        fr.olAnim:Stop()
        fr.olHolder:SetAlpha(1)
    end
end

-- Tooltip for a cue with "Show tooltip on hover": the spell or item the cue is about (the icon-source choice on the cue, else the rule's
-- first trigger). Nothing is shown when the cue names neither.
function ns.ShowCueTooltip(rule, fr)
    if not (GameTooltip and fr) then return end
    local v = rule.visual or {}
    local kind, id
    local src = v.iconSrc or "auto"
    if src == "spell" and (tonumber(v.iconSpell) or 0) > 0 then kind, id = "spell", tonumber(v.iconSpell)
    elseif src == "item" and (tonumber(v.iconItem) or 0) > 0 then kind, id = "item", tonumber(v.iconItem)
    elseif ns.TriggerTarget then
        local parent = rule.parentUid and ns.FindParentRule and ns.FindParentRule(rule) or nil
        kind, id = ns.TriggerTarget(parent or rule)
    end
    if not id then return end
    GameTooltip:SetOwner(fr, "ANCHOR_RIGHT")
    local ok
    if kind == "item" then ok = pcall(GameTooltip.SetItemByID, GameTooltip, id)
    else ok = pcall(GameTooltip.SetSpellByID, GameTooltip, id) end
    if ok then GameTooltip:Show() else GameTooltip:Hide() end
end

function ns.RefreshVisual(rule)
    if not ns.IsPreview(rule, "visual") and ns.RuleOff(rule) then ns.DropVisual(rule); return end   -- D7: a switched-off rule gets no frame
    local v = rule.visual
    local fr = GetFrame(rule)
    fr:SetSize(math.max(8, v.w or 128), math.max(8, v.h or 128))
    local parent, dyn = ParentFor(rule)
    if fr:GetParent() ~= parent then fr:SetParent(parent) end
    ApplyStrata(fr, rule.folder)
    Place(fr, rule, parent)
    if dyn then LayoutDynamic(dyn) else ArrangeAfter(rule) end   -- (G7: a new or resized display joins its group's line)
    fr.baseAlpha = v.alpha or 1
    fr:SetAlpha(fr.baseAlpha)
    fr.tex:SetBlendMode(v.additive and "ADD" or "BLEND")
    AnchorArt(fr.tex, fr, v); AnchorArt(fr.tex2, fr, v)
    SetArt(fr.tex, rule, v)
    fr.tex:SetAlpha(clamp(v.texAlpha or 1, 0, 1))
    -- overlay layer (own tint / desaturate / blend / opacity)
    local ov = v.overlay
    -- Progress-texture rules (v.fill.enabled) default to a locked base+overlay layering, unless ov.advanced is on:
    -- the overlay never grays (stays the "clean" top layer) and the base grays automatically iff it's tinted, to
    -- sharpen the tint (see Core.lua's visual.overlay comment and the Options.lua "Advanced customization" toggle).
    local progLocked = (v.fill and v.fill.enabled) and not (ov and ov.advanced)
    fr.tex2On = ov and ov.enabled and true or false
    if fr.tex2On then
        SetOverlayArt(fr.tex2, rule, v)
        local ot = ov.tint or { 1, 1, 1, 1 }
        fr.tex2:SetVertexColor(ot[1] or 1, ot[2] or 1, ot[3] or 1, ot[4] or 1)
        local ovDesatOn = (not progLocked) and ov.desaturate
        pcall(fr.tex2.SetDesaturation, fr.tex2, ovDesatOn and 1 or 0)
        fr.tex2:SetBlendMode(ov.additive and "ADD" or "BLEND")
        fr.tex2:SetAlpha(clamp(ov.alpha or 1, 0, 1))
        fr.tex2:Show()
    else
        fr.tex2:Hide()
    end
    -- base recolor: optional desaturation first, then the tint multiplies what is left (tint works with additive too)
    local tint = v.tint or { 1, 1, 1, 1 }
    local baseDesatOn = progLocked and v.recolor or v.desaturate
    fr.baseDesat = baseDesatOn and 1 or 0
    fr.baseTint = v.recolor and tint or { 1, 1, 1, 1 }
    if v.recolor then
        fr.tex:SetVertexColor(tint[1] or 1, tint[2] or 1, tint[3] or 1, tint[4] or 1)
    else
        fr.tex:SetVertexColor(1, 1, 1, 1)
    end
    pcall(fr.tex.SetDesaturation, fr.tex, fr.baseDesat)
    -- background fill
    if v.bg and v.bg.enabled then
        local c = v.bg.color or { 0, 0, 0, 0.5 }
        fr.bg:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.5)
        fr.bg:Show()
    else
        fr.bg:Hide()
    end
    LayoutOutline(fr, rule, v)
    LayoutBorder(fr, v)
    PaintFrameDeco(fr, rule)   -- (SD-17) its group's border / background, on this display
    if v.glow then
        fr.glow:SetSize(math.max(8, v.w or 128) * 1.9, math.max(8, v.h or 128) * 1.9)
        fr.glow:Show()
        if not fr.glowAnim:IsPlaying() then fr.glowAnim:Play() end
    else
        fr.glowAnim:Stop()
        fr.glow:Hide()
    end
    -- text styling / placement
    local t = v.text
    if t then
        StyleText(fr.text, fr, t)
        if fr.cd then
            fr.cd:SetHideCountdownNumbers(not t.enabled)
            local cdt = FindCooldownText(fr.cd)
            if cdt then StyleText(cdt, fr, t) end
        end
    end
    if v.count then StyleText(fr.count, fr, v.count, "BOTTOMRIGHT") end
    if v.absorb then StyleText(fr.absorb, fr, v.absorb, "TOP") end
    -- a Bar cue (BarCue.lua): a status bar with icon, spark and name text instead of the art
    if v.kind == "bar" and ns.BarCueLayout then ns.BarCueLayout(fr, rule, v)
    elseif fr.barF and ns.BarCueHide then ns.BarCueHide(fr) end
    -- Mouse (V27, Xaya SD-29 "Hover only, clicks pass"): a display takes clicks only while the mover has it unlocked for moving (click to
    -- edit, right-click menu, drag); otherwise every click and camera drag passes through to the game. It sees the mouse moving only for
    -- "Show tooltip on hover" or in the mover (its hover highlight). Both are set every time, so no earlier state is left behind (before,
    -- a display without the tooltip turned clicks back on after EnableMouse(false) and caught clicks over the game world).
    -- docs/reference/api/widgets.md:110, 283-284 (EnableMouse, SetMouseClickEnabled, SetMouseMotionEnabled: protected functions; this
    -- frame is a plain unprotected Frame, so they work in combat). INFERENCE (not documented): EnableMouse sets clicks and motion together.
    -- (round 7, SD-58) The mover's look (border, name, hover wash) and its temporary group lock are XayaUI Options' (ns.MoverDisplay).
    local tip = v.hoverTip and true or false
    local M = Unl(rule) and ns.MoverDisplay or nil
    local movable = (M and not M.TempLocked(rule)) and true or false   -- (a group locked for now from its mover tag: P5)
    fr:EnableMouse(movable or tip)
    if fr.SetMouseClickEnabled then pcall(fr.SetMouseClickEnabled, fr, movable) end
    if fr.SetMouseMotionEnabled then pcall(fr.SetMouseMotionEnabled, fr, movable or tip) end
    if M then
        M.Paint(rule, fr)
    elseif fr.xuiMoverLook then   -- (the mover's look goes; a display it never painted has none)
        fr.xuiMoverLook, fr.hovered = nil, false
        if fr.hoverTex then fr.hoverTex:Hide() end
        fr:SetBackdrop(nil)
        if fr.label then fr.label:Hide() end
    end
    ns.UpdateVisualText(rule, ns.runtime and ns.runtime[rule] and ns.runtime[rule].info)
end

-- Preview / unlock sample: a timer that starts at 12.3 s and counts down to 0, then repeats, so the tenths-of-a-second
-- switch (Tenths Only Below) can be watched. The wipe, fades and text all read the same clock.
local SAMPLE_DURATION = 12.3
-- (round 7, SD-60) seconds until the sample countdown's whole-second text changes next (the engine wakes a previewed or unlocked display
-- then, instead of re-checking it every 0.2 s); nil while previews are paused (the sample does not move)
function ns.SampleNextChange()
    if ns.previewPaused then return nil end
    local rem = SAMPLE_DURATION - (ns.SampleTime() % SAMPLE_DURATION)
    return rem - math.floor(rem)
end

-- Dynamic, per-tick parts: desaturation, duration text, stacks/charges text.
-- One cached curve per display and purpose; rebuilt only when its end values change. (File-level functions taking the frame:
-- defined inside UpdateVisualText they were two new closures on every call, up to 30 times a second per display.)
local function NumCurve(fr, key, y0, y1)   -- remaining 0% -> y0, 100% -> y1
    local e = fr.curves[key]
    if e and e.a == y0 and e.b == y1 then return e.cv or nil end
    e = e or {}
    e.a, e.b, e.cv = y0, y1, false
    local okc, cv = pcall(C_CurveUtil.CreateCurve)
    if okc and cv then
        if Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(cv.SetType, cv, Enum.LuaCurveType.Linear) end
        if pcall(cv.AddPoint, cv, 0, y0) and pcall(cv.AddPoint, cv, 1, y1) then e.cv = cv end
    end
    fr.curves[key] = e
    return e.cv or nil
end
local function ColorCurve(fr, key, r0, g0, b0, a0, r1, g1, b1, a1)   -- remaining 0% -> colour 0, 100% -> colour 1
    local e = fr.curves[key]
    if e and e.a1 == r0 and e.a2 == g0 and e.a3 == b0 and e.a4 == a0
        and e.b1 == r1 and e.b2 == g1 and e.b3 == b1 and e.b4 == a1 then return e.cv or nil end
    e = e or {}
    e.a1, e.a2, e.a3, e.a4, e.b1, e.b2, e.b3, e.b4, e.cv = r0, g0, b0, a0, r1, g1, b1, a1, false
    local okc, cv = pcall(C_CurveUtil.CreateColorCurve)
    if okc and cv and CreateColor then
        if Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(cv.SetType, cv, Enum.LuaCurveType.Linear) end
        if pcall(cv.AddPoint, cv, 0, CreateColor(r0, g0, b0, a0)) and pcall(cv.AddPoint, cv, 1, CreateColor(r1, g1, b1, a1)) then e.cv = cv end
    end
    fr.curves[key] = e
    return e.cv or nil
end
-- Smooth effects between engine ticks (wipe, fades, flash, tenths of a second), at most ~30 times a second. The script is
-- attached to a display only while one of those effects is running, so idle displays cost nothing per rendered frame.
local function FxOnUpdate(self, elapsed)
    local r = self.fxRule
    if not r then self:SetScript("OnUpdate", nil); return end
    local acc = (self.fxAcc or 0) + (elapsed or 0)
    if acc < 0.033 then self.fxAcc = acc; return end
    self.fxAcc = 0
    local t = ns.perfOn and debugprofilestop()
    local ok, err = pcall(ns.UpdateVisualText, r, self.fxInfo, true)
    if t then ns.PerfAdd("fx", debugprofilestop() - t) end
    if not ok then   -- a failing effect stops itself instead of erroring every frame
        self.fxRule = nil
        self:SetScript("OnUpdate", nil)
        if ns.CaptureError then pcall(ns.CaptureError, "XayaUI display effect: " .. tostring(err), nil, "XUI-E012") end
    end
end
local function SetFxRule(fr, rule)
    if fr.fxRule == rule then return end
    local had = fr.fxRule ~= nil
    fr.fxRule = rule
    if rule and not had then fr.fxAcc = 0; fr:SetScript("OnUpdate", FxOnUpdate)
    elseif not rule and had then fr:SetScript("OnUpdate", nil) end
end

-- a secret-safe color writer for pcall (no closure per call)
local function SetVertexRGBA(tex, color) tex:SetVertexColor(color:GetRGBA()) end

-- Stack / charge count into a font string. Returns true when something is shown.
-- Stacks follow Blizzard's own rule (Cooldown Manager, aura buttons): shown from 2 up, so a buff that cannot stack (0) or has one
-- stack shows nothing, exactly like the combat engine's count. Charges show every readable value (0 charges is worth seeing).
-- In combat a stack count is hidden by the game unless the aura is never secret; the combat engine draws it for its displays.
local function DrawCount(fs, rule, ct, ref, sample, chargesOnly)
    local shown = false
    if ns.Val(ct.source) == "charges" then
        local ok, ch = pcall(C_Spell.GetSpellCharges, rule.spellID)
        if ok and type(ch) == "table" then
            local okv, cur = pcall(ns.Field, ch, "currentCharges")
            -- (secret in combat: tested only with issecretvalue, then handed to SetText)
            if okv and (ns.IsSecret(cur) or type(cur) == "number") then shown = pcall(fs.SetText, fs, cur) end
        end
    elseif not chargesOnly then
        local a = ref and ref.applications
        if type(a) == "number" then
            if a >= 2 then shown = pcall(fs.SetText, fs, a) end
        elseif ref and ref.instanceID and C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount then
            -- an aura with a readable id but no count read: the game's own display string ("" below 2 stacks)
            local okc, str = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, ref.unit or "player", ref.instanceID, 2, 999)
            if okc and str then shown = pcall(fs.SetText, fs, str) end
        end
    end
    if not shown and sample then fs:SetText("3"); shown = true end
    fs:SetShown(shown)
    return shown
end

-- The shield / absorb amount, as text. 12.1.5: UnitGetTotalAbsorbs returns a SECRET number always (SecretReturns, in and out of
-- combat), and one aura's own amount (AuraData.points) is readable only out of combat. A secret number can be drawn (SetText and
-- the game's number helpers accept it from addon code) but never compared, so "hide when zero" uses the game's
-- C_StringUtil.TruncateWhenZero ("" for zero). That helper cannot abbreviate: with BOTH "abbreviate" and "hide when zero" on, a
-- secret amount is abbreviated and a zero shows as "0" (no game helper does both; stated in /xui debug timing and the user guide).
local function ReadAbsorb(ab, ref)
    local val
    if ns.Val(ab.source) == "aura" then
        if ref and ref.instanceID and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
            local ok, a = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, ref.unit or "player", ref.instanceID)
            if ok and type(a) == "table" then
                local okp, pts = pcall(function() return a.points and a.points[1] end)
                if okp and type(pts) == "number" then val = pts end
            end
        end
        -- this aura's own amount is hidden (combat): show your total absorbs instead, the only shield number the game still gives
        -- (only for an aura on you: your absorbs are not the amount of a debuff on your target)
        if val == nil and ref and (ref.unit or "player") == "player" then
            local ok, tot = pcall(UnitGetTotalAbsorbs, "player")
            if ok then val = tot end
        end
    else
        local ok, tot = pcall(UnitGetTotalAbsorbs, "player")
        if ok then val = tot end
    end
    return val
end
local function DrawAbsorb(fs, ab, ref, sample)
    local shown = false
    local val = ReadAbsorb(ab, ref)
    local secret = ns.IsSecret(val)   -- (tested first: a secret is never compared, not even with nil)
    if not secret and type(val) == "number" then
        if val > 0 or not ab.hideZero then
            local txt
            if ab.abbreviate ~= false then
                if val >= 1e6 then txt = ("%.1fM"):format(val / 1e6)
                elseif val >= 1e3 then txt = ("%.1fK"):format(val / 1e3)
                else txt = ("%d"):format(val) end
            else txt = ("%d"):format(val) end
            fs:SetText(txt); shown = true
        end
    elseif secret then
        -- secret: handed only to the game's own number helpers and SetText
        local out = val
        if ab.abbreviate ~= false then
            local A = AbbreviateLargeNumbers or AbbreviateNumbers
            local okA, s2 = false, nil
            if A then okA, s2 = pcall(A, val) end
            if okA and s2 ~= nil then out = s2 end
        elseif ab.hideZero and C_StringUtil and C_StringUtil.TruncateWhenZero then
            local okT, s2 = pcall(C_StringUtil.TruncateWhenZero, val)
            if okT and s2 ~= nil then out = s2 end
        end
        shown = pcall(fs.SetText, fs, out)
    end
    if not shown and sample then fs:SetText(ab.abbreviate ~= false and "12.3K" or "12345"); shown = true end
    fs:SetShown(shown)
    return shown
end

-- Cooldown countdown for a display with no aura to time: the game's duration object for the spell's cooldown (or its recharge,
-- for a spell with charges) drives our own font string through a duration text binding (C_DurationUtil, 12.1.5). The game updates
-- the text itself every frame, exact in combat too, with XayaUI's own time format (ns.TimeFormatter). Returns true when bound.
local function StopCdBind(fr)
    if fr.cdBind and fr.cdBindOn then pcall(fr.cdBind.SetEnabled, fr.cdBind, false); fr.cdBindOn = false end
end
local function CooldownDuration(rule, cd)
    local id = tonumber(rule.spellID) or 0
    if id == 0 or not (cd and cd.known) or not C_Spell then return nil end
    if (cd.max or 1) > 1 then
        if cd.atMax ~= false or not C_Spell.GetSpellChargeDuration then return nil end   -- all charges back: nothing to count
        local ok, d = pcall(C_Spell.GetSpellChargeDuration, id)
        return ok and d or nil
    end
    if not cd.onCd or not C_Spell.GetSpellCooldownDuration then return nil end
    local ok, d = pcall(C_Spell.GetSpellCooldownDuration, id, true)   -- true: the global cooldown is not counted
    return ok and d or nil
end
ns.CooldownDurationOf = CooldownDuration   -- (BarCue.lua: a cooldown bar is driven by the same duration object)
-- (round 7) one binding per display, for either text: the cooldown countdown (path 4: nothing shown at zero) or the whole seconds of a
-- hidden aura time (path 2: "0" at its end, as the text showed before). endText is set only when it changes.
local function BindDurationText(fr, fmt, dur, endText)
    if fr.cdBind == false then return false end
    if not fr.cdBind then
        if not (C_DurationUtil and C_DurationUtil.CreateDurationTextBinding) then fr.cdBind = false; return false end
        local ok, b = pcall(C_DurationUtil.CreateDurationTextBinding)
        if not (ok and b) then fr.cdBind = false; return false end
        pcall(b.SetToDefaults, b)
        if not pcall(b.SetFontString, b, fr.text) then fr.cdBind = false; return false end
        fr.cdBind, fr.cdBindFmt, fr.cdBindEnd = b, nil, nil
    end
    local b = fr.cdBind
    if fr.cdBindEnd ~= endText then
        pcall(b.SetZeroDurationText, b, endText); pcall(b.SetExpiredText, b, endText)
        fr.cdBindEnd = endText
    end
    if fmt and fr.cdBindFmt ~= fmt then if pcall(b.SetFormatter, b, fmt) then fr.cdBindFmt = fmt end end
    if not pcall(b.SetDuration, b, dur) then return false end
    if not fr.cdBindOn then
        if not pcall(b.SetEnabled, b, true) then return false end
        fr.cdBindOn = true
    end
    return true
end
local function BindCooldownText(fr, t, dur)
    local fmt = ns.TimeFormatter(t.decimals, t.decimalBelow)
    if not fmt and AuraContainerInbound and AuraContainerInbound.GetDefaultAuraDurationFormatter then
        local okD, d = pcall(AuraContainerInbound.GetDefaultAuraDurationFormatter); fmt = okD and d or nil
    end
    return BindDurationText(fr, fmt, dur, "")
end

-- The companion of a display the combat engine draws: the game's container cannot draw a shield amount or spell charges, so these
-- two texts are drawn by XayaUI on a small frame of their own, laid exactly over the engine's icon (same place, parent and strata,
-- above it), shown while XayaUI's own rule says the display is up. Created only for displays that need it.
local function Companion(fr, rule)
    local c = fr.comp
    if not c then
        c = CreateFrame("Frame", nil, fr:GetParent() or UIParent)
        c:EnableMouse(false)
        c.count = c:CreateFontString(nil, "OVERLAY", nil, 7); c.count:SetFontObject(GameFontNormal)
        c.absorb = c:CreateFontString(nil, "OVERLAY", nil, 7); c.absorb:SetFontObject(GameFontNormal)
        c:Hide()
        fr.comp = c
    end
    -- placed and styled again only after a settings edit (ns.configVersion) or when its display moved to another parent
    local parent = fr:GetParent() or UIParent
    local ver = ns.configVersion or 0
    if c.ver ~= ver or c:GetParent() ~= parent then
        c.ver = ver
        local v = rule.visual
        if c:GetParent() ~= parent then c:SetParent(parent) end
        c:ClearAllPoints(); c:SetAllPoints(fr)
        StyleText(c.count, c, v.count or {}, "BOTTOMRIGHT")
        StyleText(c.absorb, c, v.absorb or {}, "TOP")
    end
    local strata = fr:GetFrameStrata() or "HIGH"
    if c:GetFrameStrata() ~= strata then c:SetFrameStrata(strata) end
    local lvl = math.min(fr:GetFrameLevel() + 30, 9000)
    if c:GetFrameLevel() ~= lvl then c:SetFrameLevel(lvl) end
    c:SetAlpha(fr.baseAlpha or 1)
    return c
end
local function SetCompanionShown(fr, rule, on)
    if on then
        local c = Companion(fr, rule)
        if not c:IsShown() then c:Show() end
    elseif fr.comp and fr.comp:IsShown() then
        fr.comp:Hide()
    end
end

function ns.UpdateVisualText(rule, info, fxOnly)
    local fr = frames[rule]
    if not fr then return end
    local v = rule.visual
    local previewing = ns.IsPreview(rule, "visual")
    local sample = ns.unlocked or previewing
    -- the aura this display times: the built-in Buff / Aura, else the first present aura trigger row (Conditions.lua AuraRowRef)
    local ref = info and (info.buffRef or info.auraRef)

    -- drawn by the combat engine: only the companion texts are XayaUI's (shield amount, spell charges)
    local comp = fr.comp
    if comp and comp:IsShown() then
        if fxOnly then return end
        local ct, ab = v.count, v.absorb
        if ct and ct.enabled then DrawCount(comp.count, rule, ct, ref, false, true) else comp.count:Hide() end
        if ab and ab.enabled then DrawAbsorb(comp.absorb, ab, ref, false) else comp.absorb:Hide() end
        return
    end

    -- remaining fraction of the buff (readable numbers only; secret numbers cannot be divided)
    local frac
    if ref and ref.expiration and ref.duration and ref.duration > 0 then
        frac = clamp((ref.expiration - GetTime()) / ref.duration, 0, 1)
    end

    -- remaining seconds (real when readable, sample cycle while unlocked / previewing)
    local rem
    if ref and ref.expiration and ref.duration and ref.duration > 0 then
        rem = ref.expiration - GetTime()
    end
    local sfrac
    if frac == nil and sample then
        rem = SAMPLE_DURATION - (ns.SampleTime() % SAMPLE_DURATION)
        sfrac = rem / SAMPLE_DURATION
    end
    local f = frac or sfrac

    -- No readable numbers but we hold an aura instance (e.g. found through the Cooldown Manager while auras are
    -- secret): use Blizzard's duration object + curves. The curve result goes straight into the widget setters,
    -- never into Lua arithmetic. (Midnight API, unverified in game - every call is pcall'd.)
    local dobj
    if f == nil and ref and ref.instanceID and C_UnitAuras and C_UnitAuras.GetAuraDuration
        and C_CurveUtil and (v.fadeGrey or v.fadeAlpha) then
        local okd, d = pcall(C_UnitAuras.GetAuraDuration, ref.unit or "player", ref.instanceID)
        if okd and d and d.EvaluateRemainingPercent then dobj = d end
    end
    fr.curves = fr.curves or {}

    -- fade: desaturate (gray) or blend vertex color toward a chosen color as the buff runs out; gray while on cooldown
    local d = fr.baseDesat or 0
    if v.desatOnCD and info and info.cd and info.cd.onCd then d = 1 end
    local mods = info and info.mods   -- from the true conditions that list this cue (Cues.lua EvaluateCue): glow / desat / alpha
    if mods and mods.desat ~= nil then d = mods.desat and 1 or 0 end
    do   -- glow: the cue's own setting unless a condition overrides it (RefreshVisual only sets it up from the cue's own setting)
        local wantGlow = v.glow and true or false
        if mods and mods.glow ~= nil then wantGlow = mods.glow end
        if wantGlow then
            fr.glow:SetSize(math.max(8, v.w or 128) * 1.9, math.max(8, v.h or 128) * 1.9)
            fr.glow:Show()
            if not fr.glowAnim:IsPlaying() then fr.glowAnim:Play() end
        elseif fr.glow:IsShown() then
            fr.glowAnim:Stop()
            fr.glow:Hide()
        end
    end
    local bt = fr.baseTint or { 1, 1, 1, 1 }
    local cr, cg, cb, ca = bt[1] or 1, bt[2] or 1, bt[3] or 1, bt[4] or 1
    local greyDone, colorDone = false, false
    if v.fadeGrey then
        local fmode = ns.Val(v.fadeMode)
        local toColor = fmode == "color"
        if fmode == "transparent" then
            -- fade the whole texture out toward fully transparent (handled with the opacity below)
            fr.fadeToClear = true
        else
            fr.fadeToClear = false
        end
        if f ~= nil then
            if fmode == "transparent" then
                -- no color change
            elseif toColor then
                local fc = v.fadeColor or { 1, 0.1, 0.1, 1 }
                local k = 1 - f
                cr = cr + ((fc[1] or 1) - cr) * k
                cg = cg + ((fc[2] or 1) - cg) * k
                cb = cb + ((fc[3] or 1) - cb) * k
                ca = ca + ((fc[4] or 1) - ca) * k
            else
                d = math.max(d, 1 - f)
            end
        elseif dobj then
            if fmode == "transparent" then
                -- handled by the alpha curve below
            elseif toColor then
                local fc = v.fadeColor or { 1, 0.1, 0.1, 1 }
                local cv = ColorCurve(fr, "c", fc[1] or 1, fc[2] or 1, fc[3] or 1, fc[4] or 1, cr, cg, cb, ca)
                if cv then
                    local okr, res = pcall(dobj.EvaluateRemainingPercent, dobj, cv)
                    if okr and res then colorDone = pcall(SetVertexRGBA, fr.tex, res) end
                end
            else
                local cv = NumCurve(fr, "g", 1, d)
                if cv then
                    local okr, res = pcall(dobj.EvaluateRemainingPercent, dobj, cv)
                    if okr and res then greyDone = pcall(fr.tex.SetDesaturation, fr.tex, res) end
                end
            end
        end
    end
    if mods and mods.desat ~= nil then greyDone = false end   -- an explicit condition choice beats the buff-timer fade
    if mods and mods.tint then   -- a condition's color tint replaces the cue's own tint (and any fade color) while it is true
        cr, cg, cb, ca = mods.tint[1] or 1, mods.tint[2] or 1, mods.tint[3] or 1, mods.tint[4] or 1
        colorDone = false
    end
    if not greyDone then pcall(fr.tex.SetDesaturation, fr.tex, d) end
    if not colorDone then fr.tex:SetVertexColor(cr, cg, cb, ca) end

    -- opacity: out-of-combat multiplier, fade opacity as the buff runs out, then the "about to expire" flash
    local alpha = fr.baseAlpha or 1
    if mods and mods.alpha ~= nil then alpha = mods.alpha end
    local oa = v.oocAlpha or 1
    if oa < 1 and not ((UnitAffectingCombat and UnitAffectingCombat("player")) or false) and not sample then
        alpha = alpha * oa
    end
    local alphaDone = false
    if v.fadeGrey and fr.fadeToClear then
        if f ~= nil then
            alpha = alpha * f
        elseif dobj then
            local cv = NumCurve(fr, "t", 0, alpha)
            if cv then
                local okr, res = pcall(dobj.EvaluateRemainingPercent, dobj, cv)
                if okr and res then alphaDone = pcall(fr.SetAlpha, fr, res) end
            end
        end
    end
    if v.fadeAlpha then
        local mn = clamp(v.fadeAlphaMin or 0.15, 0, 1)
        local mx = clamp(v.fadeAlphaMax or 1, 0, 1)
        if f ~= nil then
            alpha = alpha * (mn + (mx - mn) * f)
        elseif dobj then
            local cv = NumCurve(fr, "a", alpha * mn, alpha * mx)
            if cv then
                local okr, res = pcall(dobj.EvaluateRemainingPercent, dobj, cv)
                if okr and res then alphaDone = pcall(fr.SetAlpha, fr, res) end
            end
        end
    end
    local fl = v.flash
    if fl and fl.enabled and rem and rem > 0 and rem <= (fl.threshold or 3) then
        local wave = 0.5 + 0.5 * math.sin((sample and ns.SampleTime() or GetTime()) * (fl.speed or 3) * 2 * math.pi)
        alpha = alpha * (0.2 + 0.8 * wave)
    end
    if not alphaDone then fr:SetAlpha(alpha) end
    -- frame strata from a true condition; when no condition asks for one any more, back to the folder's strata
    if mods and mods.strata then
        if fr:GetFrameStrata() ~= mods.strata then pcall(fr.SetFrameStrata, fr, mods.strata) end
        fr.xuiModStrata = true
    elseif fr.xuiModStrata then
        fr.xuiModStrata = nil
        ApplyStrata(fr, rule.folder)
    end

    -- a Bar cue's value (BarCue.lua): readable / sample fraction, else a duration object the game drives
    local barMoving = false
    if v.kind == "bar" and fr.barF and ns.BarCueUpdate then barMoving = ns.BarCueUpdate(fr, rule, v, info, ref, f, sample, fxOnly) and true or false end

    -- progress-bar wipe (readable / sample fraction only; secret durations cannot be measured in Lua)
    local fl2 = v.fill
    if fl2 and fl2.enabled and f ~= nil then
        local mn, mx = clamp(fl2.min or 0, 0, 1), clamp(fl2.max or 1, 0, 1)
        local p = mn + (mx - mn) * (fl2.reverse and (1 - f) or f)
        p = clamp(p, 0, 1)
        local key = math.floor(p * 2000) .. (ns.Val(fl2.dir) or "bottom")
        if fr.wipeKey ~= key then
            fr.wipeKey = key
            local dir = ns.Val(fl2.dir) or "bottom"
            local pp = math.max(p, 0.002)
            local x0, x1, y0, y1 = 0, 1, 0, 1
            if dir == "bottom" then y1 = pp elseif dir == "top" then y0 = 1 - pp
            elseif dir == "left" then x1 = pp else x0 = 1 - pp end
            CropTex(fr.tex, fr, x0, x1, y0, y1)
            if fr.tex2On then CropTex(fr.tex2, fr, x0, x1, y0, y1) end
            fr.tex:SetShown(p > 0.002)
            if fr.tex2On then fr.tex2:SetShown(p > 0.002) end
        end
    else
        if fr.wipeKey then
            fr.wipeKey = nil
            UncropTex(fr.tex, fr); UncropTex(fr.tex2, fr)
            fr.tex:Show()
            if fr.tex2On then fr.tex2:Show() end
        end
    end

    -- keep the effects above animating every frame between engine ticks (only while a time source exists)
    local wantsFx = (fl2 and fl2.enabled) or v.fadeAlpha or v.fadeGrey or (v.flash and v.flash.enabled) or barMoving
    -- tenths of a second must move every frame (the engine tick is only 5x per second), so while the duration text is in its
    -- decimal range it is redrawn from here too
    local tx = v.text
    local wantsTenths = tx and tx.enabled and tx.decimals and rem ~= nil and rem > 0 and rem < (tx.decimalBelow or 5)
        and not (v.kind == "bar" and ns.BarCueSource and ns.BarCueSource(rule) == "cooldown")   -- (its text is the cooldown's)
    SetFxRule(fr, ((wantsFx or wantsTenths) and (f ~= nil or dobj ~= nil)) and rule or nil)
    fr.fxInfo = info
    if wantsTenths then
        local tk = math.floor(rem * 10)   -- tenths change 10 times a second: only then is the text rebuilt
        if fr.tenthKey ~= tk then fr.tenthKey = tk; fr.text:SetText(FmtRemaining(rem, tx.decimals, tx.decimalBelow)) end
        fr.text:Show()
    else
        fr.tenthKey = nil
    end
    if fxOnly then return end

    -- stacks / charges text
    local ct = v.count
    if ct and ct.enabled then DrawCount(fr.count, rule, ct, ref, sample, false) else fr.count:Hide() end

    -- shield / absorb amount text
    local ab = v.absorb
    if ab and ab.enabled then DrawAbsorb(fr.absorb, ab, ref, sample) else fr.absorb:Hide() end

    -- duration text (a Bar cue that times the spell's cooldown shows the cooldown's time, not the aura's: path 4 below)
    if v.kind == "bar" and ns.BarCueSource and ns.BarCueSource(rule) == "cooldown" then ref = nil end
    local t = v.text
    if not (t and t.enabled) then
        StopCdBind(fr)
        fr.text:Hide()
        if fr.cd then fr.cd:Hide() end
        return
    end
    -- path 1: readable numbers -> our own text (full control)
    if ref and ref.expiration and ref.duration then
        StopCdBind(fr)
        if fr.cd then fr.cd:Hide() end
        if ref.duration > 0 then
            -- #121: reuse the remaining time worked out at the top (same ref, same condition) instead of a second, shadowing `rem`
            if rem and rem > 0 then
                fr.text:SetText(FmtRemaining(rem, t.decimals, t.decimalBelow))
                fr.text:Show()
                return
            end
        end
        fr.text:Hide()
        return
    end
    -- numbers are secret (in combat). Everything below only ever hands the secret to a widget or string.format.
    -- (refs hold only readable instance ids since 0.6.3; in combat the game withholds aura access from addon code, so this path
    -- serves never-secret auras and readable ids from the tracker; the combat engine draws the rest exactly)
    if ref and ref.instanceID and C_UnitAuras and C_UnitAuras.GetAuraDuration then
        local ok, dur = pcall(C_UnitAuras.GetAuraDuration, ref.unit or "player", ref.instanceID)
        if not (ok and dur) then
            StopCdBind(fr)
            if ns.perfOn then ns.PerfPath(rule, "dur:GetAuraDuration " .. (ok and "returned nothing" or "failed")) end
        else
            -- path 2: our own text from the duration object: whole seconds, full control of font / size / place, and no dependence on
            -- Blizzard's cooldown-number setting. (round 7, SD-60) The game counts it down itself: the duration object drives the font
            -- string through a duration text binding with the same whole-seconds format (ns.WholeSecondsFormatter). Before, the text
            -- was the remaining seconds read once and written, and the engine redrew it every 0.2 s while it showed. A refresh of the
            -- aura comes with an aura event, which binds the new duration object (Engine.lua: the rule is checked on every aura event of
            -- its unit while this text shows).
            local wf = ns.WholeSecondsFormatter()
            if wf and BindDurationText(fr, wf, dur, "0") then
                if fr.cd then fr.cd:Hide() end
                fr.text:Show()
                if ns.perfOn then ns.PerfPath(rule, "dur:own text (bound, secret seconds)") end
                return
            end
            StopCdBind(fr)
            if ns.perfOn then ns.PerfPath(rule, wf and "dur:binding of secret seconds failed" or "dur:no whole-seconds formatter") end
            -- path 3: hand Blizzard's cooldown widget the duration object (its own countdown digits; they follow the
            -- game's "Show Numbers for Cooldowns" setting, which is why this is the fallback)
            if fr.cd and fr.cd.SetCooldownFromDurationObject then
                local ok2, err2 = pcall(fr.cd.SetCooldownFromDurationObject, fr.cd, dur)
                if ok2 then
                    fr.text:Hide()
                    fr.cd:Show()
                    if ns.perfOn then ns.PerfPath(rule, "dur:cooldown widget") end
                    return
                end
                if ns.perfOn then ns.PerfPath(rule, "dur:SetCooldownFromDurationObject failed: " .. tostring(err2):sub(1, 80)) end
            end
        end
    elseif not ref and not sample then
        -- path 4: no aura to time: the spell's cooldown (or recharge) counting down, drawn by the game from its duration object
        local dur = CooldownDuration(rule, info and info.cd)
        if dur and BindCooldownText(fr, t, dur) then
            if fr.cd then fr.cd:Hide() end
            fr.text:Show()
            if ns.perfOn then ns.PerfPath(rule, "dur:cooldown countdown (bound)") end
            return
        end
        if ns.perfOn then ns.PerfPath(rule, "dur:no aura reference") end
    else
        if ns.perfOn then ns.PerfPath(rule, ref and "dur:no aura instance id" or "dur:no aura reference") end
    end
    StopCdBind(fr)
    if fr.cd then fr.cd:Hide() end
    if sample then
        fr.text:SetText(FmtRemaining(rem or SAMPLE_DURATION, t.decimals, t.decimalBelow)); fr.text:Show()
    else
        fr.text:Hide()
    end
end

-- Show/hide as driven by the engine (ignored while unlocked / previewing: everything shows)
-- the frames that show this rule (its own display plus the displays of its cues), for glow actions
function ns.VisualFramesOf(rule)
    local out = {}
    if frames[rule] then out[#out + 1] = frames[rule] end
    if rule.uid and ns.CuesOf then
        for _, c in ipairs(ns.CuesOf(rule)) do if frames[c] then out[#out + 1] = frames[c] end end
    end
    return out
end
-- Dynamic groups are laid out when a member appears or disappears, once per group per engine step (flushed at the end of
-- the step); outside a step (options, unlock) at once. Before, every member re-laid its whole group on every step.
local layoutQueue, inStep = {}, false
local function QueueLayout(df)
    if not df then return end
    if inStep then layoutQueue[df] = true else LayoutDynamic(df) end
end
function ns.BeginVisualStep(full)
    inStep = true
    if full and ns._DynIndexCheck then ns._DynIndexCheck() end   -- (round 6: a full engine step checks the dynamic-group member index)
end
function ns.FlushLayouts()
    inStep = false
    for df in pairs(layoutQueue) do layoutQueue[df] = nil; LayoutDynamic(df) end
end

function ns.SetVisualShown(rule, shown)
    local pv = ns.IsPreview(rule, "visual")
    if not pv and ns.RuleOff(rule) then ns.DropVisual(rule); return end   -- D7: switched off: no frame (an existing one is freed)
    local want, comp = nil, false
    if not rule.visual.enabled and not pv then
        want = false
    elseif ns.EngineOwns and not (Unl(rule) or GroupUnl(rule) or pv) and ns.EngineOwns(rule) then
        want = false   -- drawn instead by the combat engine's secure aura container: ours stays hidden unless unlocked / previewing
        -- ... except the texts the container cannot draw (shield amount, spell charges): their companion shows while XayaUI's rule does
        comp = (shown and ns.EngineCompanion and ns.EngineCompanion(rule)) and true or false
    else
        want = (Unl(rule) or GroupUnl(rule) or pv or shown) and true or false
    end
    if ns.RulesDisabled then want, comp = false, false end   -- (V26) /xui disable: nothing of a rule shows, samples and previews included
    local fr = frames[rule]
    if not fr then
        if not want and not comp then return end   -- a display that has never shown needs no frame yet
        ns.RefreshVisual(rule)        -- creates and styles it
        fr = frames[rule]
    end
    if comp or fr.comp then SetCompanionShown(fr, rule, comp) end
    if not want then StopCdBind(fr) end   -- a hidden display's cooldown countdown stops updating
    if not want then fr.xuiLimited = nil end   -- (G10 Limit: no longer waiting for room)
    if want and fr.xuiLimited then return end   -- (still waiting: the group's layout shows it when there is room)
    if fr:IsShown() == want then return end
    fr:SetShown(want)
    QueueLayout(rule.folder and DynAncestor(rule.folder))
end


-- Each rule is refreshed on its own (one broken display cannot stop the rest). A rule whose display is switched off and that
-- has no frame yet gets none: sound-only cues and conditions no longer each carry a full display frame in memory.
local refreshErrSeen = setmetatable({}, { __mode = "k" })
function ns.RefreshAllVisuals()
    if ns.SyncCueFolders then pcall(ns.SyncCueFolders) end   -- a cue's group is its parent rule's group (Cues.lua)
    local outer = GA.outlinePass   -- (review fix 4: outlines measured once per pass; a nested call shares the outer pass)
    if not outer then GA.outlinePass = (GA.passNo or 0) + 1; GA.passNo = GA.outlinePass end
    local okAll, errAll = pcall(GA.RefreshAllPass)
    if not outer then GA.outlinePass = nil; wipe(GA.outlineCache) end
    if not okAll then error(errAll, 0) end
end
function GA.RefreshAllPass()
    local parents = {}   -- D7: uid -> parent, built once for this pass
    for _, r in ipairs(ns.rules or {}) do if r.uid and not r.parentUid then parents[r.uid] = r end end
    for _, r in ipairs(ns.rules or {}) do
        if not ns.IsPreview(r, "visual") and ns.RuleOff(r, parents) then
            if frames[r] then ns.DropVisual(r) end   -- switched off: freed, never rebuilt
        elseif frames[r] or (r.visual and r.visual.enabled) or ns.IsPreview(r, "visual") then
            local ok, err = pcall(ns.RefreshVisual, r)
            if ok then ok, err = pcall(ns.SetVisualShown, r, ns.runtime and ns.runtime[r] and ns.runtime[r].visualWanted) end
            if not ok and not refreshErrSeen[r] then
                refreshErrSeen[r] = true
                if ns.Print then ns.Print("display of '" .. tostring(r.name) .. "' could not be refreshed: " .. tostring(err)) end
                if ns.CaptureError then pcall(ns.CaptureError, "XayaUI display refresh: " .. tostring(err), nil, "XUI-E012") end
            end
        end
    end
    if ns.unlocked and ns.MoverDisplay then pcall(ns.MoverDisplay.AfterRefresh) end   -- (the mover's group tags: XayaUI Options, Mover.lua)
    if ns.EngineGroupDeco then pcall(ns.EngineGroupDeco) end   -- (SD-17) groups' border / background on the engine's aura buttons (ours: RefreshVisual)
end

-- (bundle 1 round 7, SD-58) What the mover (XayaUI Options, Mover.lua) uses of the layout above: the display frames, a group's measured
-- bounds, and the position and anchor operations it needs (each stores positions exactly as the editor's own settings do).
ns.VisualPos = {
    frames = frames, InFolder = InFolder, GroupBounds = GroupBounds, GroupScreenBounds = GroupScreenBounds, ScreenRect = ScreenRect,
    GroupTargetScale = GroupTargetScale, GroupPosChanged = GroupPosChanged, CenterGroup = CenterGroup, Reanchor = Reanchor,
    CommitDrag = CommitDrag, PlaceDisplay = PlaceDisplay, ParentFor = ParentFor, SnapTargets = SNAP_TARGETS,
}
if ns.On then
    -- (V26) /xui disable: every XayaUI rule display hides at once (XayaUI's own frames: allowed in combat); nothing shows until /xui
    -- enable. The mover and the sidebar's movement unlocks close on the same event (XayaUI Options, Mover.lua, when it is loaded).
    ns.On("RULES_DISABLED", function()
        for r in pairs(frames) do pcall(ns.SetVisualShown, r, false) end
    end)
end

function ns.DropVisual(rule)
    local fr = frames[rule]
    if fr then
        fr:Hide(); StopCdBind(fr)
        if fr.comp then fr.comp:Hide() end   -- (the companion hangs from the display's parent, not from the display)
        frames[rule] = nil
    end
end
