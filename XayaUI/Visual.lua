-------------------------------------------------------------------------------
-- Visual.lua : one texture frame per rule, shown/hidden by the engine.
-- Rotation / mirror / flip, recolor, border, background, pulsing glow ring,
-- shape-following OUTLINE glow (1-10 px, color, pulse), fade-to-gray as the
-- buff runs out, desaturate on cooldown, buff-duration text, stacks/charges text.
-- Drag-to-position while unlocked (/xui unlock).
-------------------------------------------------------------------------------
local addonName, ns = ...

local frames = setmetatable({}, { __mode = "k" }) -- rule -> frame
ns.unlocked = false
ns.moveUnlocked = {}   -- per-rule "movement unlocked" (session only); set from the lock icon on the sidebar rows
local function Unl(rule) return (ns.unlocked or ns.moveUnlocked[rule]) and true or false end
function ns.IsMoveUnlocked(rule) return Unl(rule) end
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
local pairOf, tempUnl = {}, {}   -- session-only paired-aura links (both directions) and the auras a pair unlocked for its partner

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

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- On-screen selection, snapping and the right-click menu (only while visuals are unlocked)
-------------------------------------------------------------------------------
ns.selectedVisual = nil
local SNAP_GRID, SNAP_NEAR = 10, 10
local SNAP_LABELS = { free = "Free Move", grid = "Grid (10 px)", auras = "Other Auras' Edges & Centers", center = "Screen Center Lines" }

-- border color for an unlocked display: white while hovered (this is the box a click will hit), orange when
-- selected, cyan otherwise. A faint white wash on hover makes it readable over busy art.
local function PaintBorder(r, f)
    if not (Unl(r) and f.SetBackdropBorderColor) then return end
    if f.hovered then f:SetBackdropBorderColor(1, 1, 1, 1)
    elseif r == ns.selectedVisual then f:SetBackdropBorderColor(1, 0.6, 0.1, 1)
    else f:SetBackdropBorderColor(0.2, 0.8, 1, 1) end
    if f.hoverTex then f.hoverTex:SetShown(f.hovered and true or false) end
end
local function PaintBorders()
    for r, f in pairs(frames) do PaintBorder(r, f) end
end
function ns.SelectVisual(rule) ns.selectedVisual = rule; PaintBorders() end

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
local function Container(f)
    local c = containers[f.id]
    if not c then c = CreateFrame("Frame", nil, UIParent); c:SetSize(1, 1); containers[f.id] = c end
    local fit = f.cFit and ns.GroupFitScale(f) or 1   -- (V14: nothing is measured unless the tick box is on)
    c:SetSize(math.max(1, f.cW or 1) / fit, math.max(1, f.cH or 1) / fit)
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
    local gname = (rel == "custom") and f.cFrame or REL_FRAMES[rel]
    local g = gname and gname ~= "" and _G[gname]
    if g and g.GetCenter and g ~= c then target = g end
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
    c:SetPoint(f.cPoint or "CENTER", target, f.cRelPoint or f.cPoint or "CENTER", (f.cX or 0) / (sc * pScale), (f.cY or 0) / (sc * pScale))
    c.xuiTarget = target   -- what the group's X / Y is measured from (the group outline drag needs its scale)
    return c
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
-- Returns nil for the edge growths (Right, Left, Down, Up), which keep their fixed first spot (ns.DynamicFirstOffset).
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
local function LayoutDynamic(df)
    if not df then return end
    -- One slot per RULE (the rule is the container of its cues), in the rule's own list order: the order of the sidebar, which the
    -- up / down arrows and drag-and-drop change. A cue is not a slot of its own (0.6.4, #344): cues are kept in the list in the order
    -- they were made, so the old one-slot-per-cue layout ignored the sidebar order, and a rule's second display cue (a separate Text
    -- cue) took a slot of its own at the end of the group. The slot's size is the rule's first shown display; its other shown display
    -- cues sit centered on that slot.
    local items, byOwner, posOf, byUid = {}, {}, {}, {}
    for i, r in ipairs(ns.rules or {}) do
        posOf[r] = i
        if type(r.uid) == "string" and not r.parentUid then byUid[r.uid] = r end   -- one pass, so the layout stays linear in the rule count
    end
    for _, r in ipairs(ns.rules or {}) do
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
    if #items == 0 then return end
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
    local dir = df.cGrowth or "RIGHT"
    local blk = ns.DynamicBlock(df)   -- Centered / From anchor point: one block, laid out like Blizzard's flow (see above)
    local horiz
    if blk then horiz = blk.horiz else horiz = (dir == "RIGHT" or dir == "LEFT") end
    local sp = df.cSpacing or 4
    local limit = horiz and (df.cW or 0) or (df.cH or 0)   -- 0 = no wrapping
    local wrapN = tonumber(df.cWrapN) or 0                  -- items per row / column (0 = no limit); the size limit above still applies
    local cs = df.cWrapRev and -1 or 1                      -- which way extra rows / columns go: down or right (1), up or left (-1)
    -- split into lines along the main axis
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
    local container = Container(df)
    local function Put(it, x, y)
        it.fr:ClearAllPoints()
        it.fr:SetPoint("CENTER", container, "CENTER", x, y)
        if it.extra then   -- the rule's other display cues: on the same slot
            for _, ef in ipairs(it.extra) do ef:ClearAllPoints(); ef:SetPoint("CENTER", container, "CENTER", x, y) end
        end
    end
    if blk then
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
        local bx = hv[1] * container:GetWidth() - pv[1] * bw
        local by = hv[2] * container:GetHeight() - pv[2] * bh
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
                Put(it, cx, cy)
                main = main + (horiz and it.w or it.h) + sp
            end
            cross = cross + thick[li] + sp
        end
        return
    end
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
            Put(it, x, y)
        end
        crossOff = crossOff + cross + sp
    end
end

-- The draggable outline for an unlocked group: fitted around the group's shown displays, drags the GROUP (its X / Y), not the displays.
local groupHandles = {}
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
local function GroupBounds(f)
    local l, b, r, t
    local us = UIParent:GetEffectiveScale()
    for rule, fr in pairs(frames) do
        if fr:IsShown() and InFolder(rule.folder, f.id) then
            local fl, fb, fw, fh = fr:GetRect()
            if fl then
                local s = fr:GetEffectiveScale() / us
                fl, fb, fw, fh = fl * s, fb * s, fw * s, fh * s
                l = l and math.min(l, fl) or fl; b = b and math.min(b, fb) or fb
                r = r and math.max(r, fl + fw) or (fl + fw); t = t and math.max(t, fb + fh) or (fb + fh)
            end
        end
    end
    return l, b, r, t
end
-- The group's box (G5 / G11; #372 "puts an assigned color / texture under the aura"; the WeakAuras group-tab border, CHAT-3d): a
-- border and / or a background behind the group's items. Auto size: it hugs what is showing now (GroupBounds) plus padding and
-- follows as items come and go; Set size: it is the container's box. Off (neither border nor background): nothing is made (V14), and
-- the watcher that follows Auto boxes runs only while one such box exists.
local boxes, boxWatch = {}, nil
local function BoxOn(f) return (f.cBorder or f.cBg) and true or false end
function ns.GroupBox(f) return f and boxes[f.id] or nil end
function ns.UpdateGroupBox(f)
    local b = boxes[f.id]
    if not BoxOn(f) then if b then b:Hide() end; return end
    local c = containers[f.id]
    if not b then
        b = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        if b.EnableMouse then b:EnableMouse(false) end
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b)
        boxes[f.id] = b
    end
    local pad = tonumber(f.cPad) or 4
    b:ClearAllPoints()
    if ns.GroupSizeMode(f) == "set" and c then
        if b:GetParent() ~= c then b:SetParent(c) end
        b:SetPoint("TOPLEFT", c, "TOPLEFT", -pad, pad); b:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", pad, -pad)
    else
        if b:GetParent() ~= UIParent then b:SetParent(UIParent) end
        local l, bt, r, t = GroupBounds(f)
        if not l then b:Hide(); return end
        b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l - pad, bt - pad)
        b:SetSize((r - l) + 2 * pad, (t - bt) + 2 * pad)
    end
    if c then
        if c.GetFrameStrata then b:SetFrameStrata(c:GetFrameStrata()) end
        if c.GetFrameLevel then b:SetFrameLevel(math.max(0, c:GetFrameLevel())) end
    end
    local bg = f.cBgColor or { 0, 0, 0, 0.45 }
    if f.cBg then
        local tex = f.cBgTex
        if type(tex) == "string" and tex ~= "" or type(tex) == "number" then b.bg:SetTexture(tex); b.bg:SetVertexColor(bg[1] or 1, bg[2] or 1, bg[3] or 1, bg[4] or 1)
        else b.bg:SetColorTexture(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 0.45) end
        b.bg:Show()
    else b.bg:Hide() end
    if b.SetBackdrop then
        if f.cBorder then
            local bd = f.cBdColor or { 0.6, 0.6, 0.65, 1 }
            b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = math.max(1, tonumber(f.cBdSize) or 1) })
            b:SetBackdropBorderColor(bd[1] or 1, bd[2] or 1, bd[3] or 1, bd[4] or 1)
        else b:SetBackdrop(nil) end
    end
    b:Show()
end
function ns.UpdateGroupBoxes()
    local anyAuto = false
    for _, f in ipairs(ns.folders or {}) do
        if BoxOn(f) or boxes[f.id] then pcall(ns.UpdateGroupBox, f) end
        if BoxOn(f) and ns.GroupSizeMode(f) == "auto" then anyAuto = true end
    end
    if anyAuto then
        if not boxWatch then
            boxWatch = CreateFrame("Frame")
            boxWatch.t = 0
            boxWatch:SetScript("OnUpdate", function(self, e)
                self.t = self.t + (e or 0)
                if self.t < 0.2 then return end
                self.t = 0
                local still = false
                for _, f in ipairs(ns.folders or {}) do
                    if BoxOn(f) and ns.GroupSizeMode(f) == "auto" then still = true; pcall(ns.UpdateGroupBox, f) end
                end
                if not still then self:SetScript("OnUpdate", nil); boxWatch = nil end
            end)
        end
    elseif boxWatch then boxWatch:SetScript("OnUpdate", nil); boxWatch = nil end
end
function ns.GroupBoxWatching() return boxWatch ~= nil end   -- (tests)
-- Right-click on the outline: type the group's X / Y, or center it on the screen on one axis or both ("center" = the outline's middle on the
-- screen's middle). X / Y are the same numbers as the group's X / Y offset options.
local posPopup
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
-------------------------------------------------------------------------------
-- Anchor to any frame on screen (Xaya 2026-11-04, on the group X / Y popup: "allow anchoring/snapping to other frames in the UI").
-- Picking: a banner asks to point at a frame and press Shift (a click would also hit the frame: target a unit, cast a spell). The
-- frame under the cursor is read with GetMouseFoci() (docs/reference/api/globals.md:214, no flags) and walked up to its first NAMED
-- parent that the name finds again (_G[name] == frame): only a name survives a /reload. Forbidden frames, UIParent / WorldFrame and
-- XayaUI's own picker frames are skipped. The candidate is outlined with its name; Cancel (or 30 s) stops.
-------------------------------------------------------------------------------
local picker
local function NamedTarget(r)
    local guard = 0
    while r and guard < 40 do
        guard = guard + 1
        local okF, forb = pcall(function() return r.IsForbidden and r:IsForbidden() end)
        if not okF or forb then return nil end
        if r == UIParent or r == WorldFrame or r.xuiPickerOwn then return nil end
        local okN, name = pcall(function() return r.GetName and r:GetName() end)
        if okN and type(name) == "string" and name ~= "" and not ns.IsSecret(name) and _G[name] == r and r.GetRect then return r, name end
        local okP, par = pcall(function() return r.GetParent and r:GetParent() end)
        r = okP and par or nil
    end
end
function ns.FrameUnderCursor()
    if type(GetMouseFoci) ~= "function" then return nil end
    local ok, foci = pcall(GetMouseFoci)
    if not (ok and type(foci) == "table") then return nil end
    for _, r in ipairs(foci) do
        local f, name = NamedTarget(r)
        if f then return f, name end
    end
end
local function ScreenRect(f)
    local ok, l, b, w, h = pcall(f.GetRect, f)
    if not (ok and l and w) then return nil end
    local s = f:GetEffectiveScale()
    return l * s, b * s, (l + w) * s, (b + h) * s
end
function ns.PickFrame(title, onPick)
    local P = picker
    if not P then
        P = CreateFrame("Frame", "XayaUIFramePicker", UIParent, "BackdropTemplate")
        P.xuiPickerOwn = true
        P:SetSize(420, 58); P:SetPoint("TOP", UIParent, "TOP", 0, -60); P:SetFrameStrata("TOOLTIP"); P:EnableMouse(true)
        P:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        P:SetBackdropColor(0.05, 0.05, 0.05, 0.95); P:SetBackdropBorderColor(1, 0.6, 0.1, 1)
        P.text = P:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); P.text:SetPoint("TOPLEFT", ns.UI_MARGIN, -ns.UI_MARGIN); P.text:SetPoint("RIGHT", -90, 0)
        P.text:SetJustifyH("LEFT")
        P.cancel = CreateFrame("Button", nil, P, "UIPanelButtonTemplate"); P.cancel:SetSize(70, 22); P.cancel:SetPoint("RIGHT", -10, 0)
        P.cancel:SetText("Cancel"); P.cancel.xuiPickerOwn = true
        P.cancel:SetScript("OnClick", function() P:Hide() end)
        if ns.FlatButton then ns.FlatButton(P.cancel) end
        P.hi = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        P.hi.xuiPickerOwn = true
        P.hi:SetFrameStrata("TOOLTIP"); P.hi:EnableMouse(false)
        P.hi:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 }); P.hi:SetBackdropBorderColor(0.3, 1, 0.3, 1)
        P.hi.label = P.hi:CreateFontString(nil, "OVERLAY", "GameFontNormal"); P.hi.label:SetPoint("BOTTOMLEFT", P.hi, "TOPLEFT", 0, 2)
        P.hi:Hide()
        P:SetScript("OnHide", function(self) self.hi:Hide(); self.onPick = nil end)
        P:SetScript("OnUpdate", function(self)
            if GetTime() - (self.startedAt or 0) > 30 then self:Hide(); return end
            local f, name = ns.FrameUnderCursor()
            self.cand, self.candName = f, name
            local us = UIParent:GetEffectiveScale()
            local l, b, r, t
            if f then l, b, r, t = ScreenRect(f) end
            if l then
                self.hi:ClearAllPoints()
                self.hi:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l / us, b / us)
                self.hi:SetSize(math.max(4, (r - l) / us), math.max(4, (t - b) / us))
                self.hi.label:SetText(name)
                self.hi:Show()
            else
                self.hi:Hide()
            end
            local down = IsShiftKeyDown and IsShiftKeyDown() or false
            if down and not self.shiftWas and f then
                local fn = self.onPick
                self:Hide()
                if fn then fn(f, name) end
                return
            end
            self.shiftWas = down
        end)
        picker = P
    end
    P.text:SetText((title or "Anchor to a frame") .. "\n|cffaaaaaaPoint at a frame and press Shift. Cancel stops.|r")
    P.onPick, P.startedAt, P.shiftWas = onPick, GetTime(), (IsShiftKeyDown and IsShiftKeyDown()) or false
    P:Show()
    return P
end
function ns.FramePicker() return picker end   -- (tests)

-- Which side of the target a box is on: h = "LEFT" / "RIGHT" / "" (overlapping), v = "TOP" / "BOTTOM" / "" (screen pixels)
local function SideOf(gl, gb, gr, gt, tl, tb, tr, tt)
    local gx, gy = (gl + gr) / 2, (gb + gt) / 2
    local h = (gx < tl) and "LEFT" or ((gx > tr) and "RIGHT" or "")
    local v = (gy > tt) and "TOP" or ((gy < tb) and "BOTTOM" or "")
    return h, v
end
local SIDE_OPP = { LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP", [""] = "" }   -- (sides only; OPP above has the corners: #268 outer anchors read that one)
local function PointXY(fr, pt)   -- a frame's point, in screen pixels
    local l, b, r, t = ScreenRect(fr)
    if not l then return nil end
    local x = pt:find("LEFT") and l or (pt:find("RIGHT") and r or (l + r) / 2)
    local y = pt:find("TOP") and t or (pt:find("BOTTOM") and b or (b + t) / 2)
    return x, y
end
local function GroupScreenBounds(fo)
    local l, b, r, t = GroupBounds(fo)
    if not l then return nil end
    local us = UIParent:GetEffectiveScale()
    return l * us, b * us, r * us, t * us
end
-- move the group's container by (dx, dy) screen pixels through its X / Y offset
local function ShiftGroup(fo, dx, dy)
    local c = Container(fo)
    local ce = c:GetEffectiveScale()
    local sc = math.max(0.1, fo.cScale or 1)
    if not ce or ce <= 0 then return end
    fo.cX = math.floor((fo.cX or 0) + dx * sc / ce + 0.5)
    fo.cY = math.floor((fo.cY or 0) + dy * sc / ce + 0.5)
    Container(fo)
end
-- re-anchor a group without moving it on screen: the container's own point is measured before and after, and X / Y make up the difference
local function Reanchor(fo, set, point)
    local c = Container(fo)
    local x0, y0 = PointXY(c, point)
    set()
    fo.cX, fo.cY = 0, 0
    c = Container(fo)
    local x1, y1 = PointXY(c, point)
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
    Reanchor(fo, function() fo.cRel, fo.cFrame, fo.cPoint, fo.cRelPoint = "custom", name, own, rel end, own)
    return true, own, rel
end
-- close the gap to the anchored frame on the side(s) the group is on
function ns.SnapGroupFlush(fo)
    local target = fo and fo.cRel == "custom" and fo.cFrame and _G[fo.cFrame]
    if not (target and target.GetRect) then return false end
    local gl, gb, gr, gt = GroupScreenBounds(fo)
    local tl, tb, tr, tt = ScreenRect(target)
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
    Reanchor(fo, function() fo.cRel, fo.cFrame, fo.cPoint, fo.cRelPoint = nil, nil, nil, nil end, "CENTER")
end
local function AnchorText(fo)
    if fo.cRel == "custom" and fo.cFrame then
        local g = _G[fo.cFrame]
        return "Anchored to |cffffd100" .. fo.cFrame .. "|r" .. ((g and g.GetRect) and "" or " |cffff6060(not found now: the screen)|r")
    end
    if fo.cRel then return "Anchored to |cffffd100" .. tostring(fo.cRel) .. "|r" end
    return "Anchored to the screen" .. (fo.parent and " (its parent group)" or "")
end

local function FillPosPopup(p)
    local fo = ns.FolderById(p.fid)
    if not fo then p:Hide() return end
    p.title:SetText(tostring(fo.name))
    if p.anchorText then p.anchorText:SetText(AnchorText(fo)) end
    if p.flush then p.flush:SetEnabled(fo.cRel == "custom" and fo.cFrame ~= nil) end
    p.x:SetText(tostring(fo.cX or 0)); p.y:SetText(tostring(fo.cY or 0))
    p.x:SetCursorPosition(0); p.y:SetCursorPosition(0)
end
local function ShowGroupPosPopup(fo)
    local p = posPopup
    if not p then
        p = CreateFrame("Frame", "XayaUIGroupPosPopup", UIParent, "BackdropTemplate")
        -- rows from the top, G apart (#351 phase 2; they were 4-8 px apart and the last one 8 px from the bottom); the height is set
        -- after the last row
        local M, G = ns.UI_MARGIN, ns.UI_GUTTER
        p:SetSize(260, 384); p:SetFrameStrata("FULLSCREEN_DIALOG"); p:SetClampedToScreen(true); p:EnableMouse(true)
        p:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        p:SetBackdropColor(0.05, 0.05, 0.05, 0.96); p:SetBackdropBorderColor(1, 0.6, 0.1, 1)
        p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal"); p.title:SetPoint("TOP", 0, -M)
        local y = M + 14 + G   -- the next row's top, from the popup's top (under the 14 px title)
        local function Box(label, y)
            local fsl = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); fsl:SetPoint("TOPLEFT", 16, y); fsl:SetText(label)
            local eb = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
            eb:SetSize(100, 20); eb:SetPoint("TOPLEFT", 110, y + 4); eb:SetAutoFocus(false); eb:SetMaxLetters(8)
            eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            return eb
        end
        local function Apply()
            local fo2 = ns.FolderById(p.fid)
            if not fo2 then return end
            local x, y = tonumber(p.x:GetText()), tonumber(p.y:GetText())
            if x then fo2.cX = math.floor(x + 0.5) end
            if y then fo2.cY = math.floor(y + 0.5) end
            GroupPosChanged(fo2); FillPosPopup(p)
        end
        p.x = Box("X offset", -(y + 4)); y = y + 20 + G   -- Box puts the 20 px edit box 4 px above its label
        p.y = Box("Y offset", -(y + 4)); y = y + 20 + G
        p.x:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Apply() end)
        p.y:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Apply() end)
        local function Btn(text, fn)
            local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
            b:SetSize(228, 22); b:SetPoint("TOP", 0, -y); b:SetText(text)
            y = y + 22 + G
            b:SetScript("OnClick", function() fn() end)
            if ns.FlatButton then ns.FlatButton(b) end
            return b
        end
        Btn("Apply X / Y", Apply)
        Btn("Center on screen (X)", function() local f2 = ns.FolderById(p.fid); if f2 then CenterGroup(f2, true, false); FillPosPopup(p) end end)
        Btn("Center on screen (Y)", function() local f2 = ns.FolderById(p.fid); if f2 then CenterGroup(f2, false, true); FillPosPopup(p) end end)
        Btn("Center on screen (X, Y)", function() local f2 = ns.FolderById(p.fid); if f2 then CenterGroup(f2, true, true); FillPosPopup(p) end end)
        p.anchorText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        p.anchorText:SetPoint("TOPLEFT", 16, -y); p.anchorText:SetPoint("RIGHT", -16, 0); p.anchorText:SetJustifyH("LEFT")
        p.anchorText:SetHeight(24); p.anchorText:SetJustifyV("TOP")   -- room for two lines (a long frame name)
        y = y + 24 + G
        Btn("Anchor to a frame on screen...", function()
            local f2 = ns.FolderById(p.fid); if not f2 then return end
            ns.PickFrame("Anchor the group '" .. tostring(f2.name) .. "' to a frame", function(target, name)
                local f3 = ns.FolderById(p.fid); if not f3 then return end
                if ns.AnchorGroupToFrame(f3, target, name) then ns.Print("group '" .. tostring(f3.name) .. "' anchored to " .. name .. " (it stays where it is; Snap flush closes the gap)") end
                if p:IsShown() then FillPosPopup(p) end
            end)
        end)
        p.flush = Btn("Snap flush to that frame", function() local f2 = ns.FolderById(p.fid); if f2 then ns.SnapGroupFlush(f2); FillPosPopup(p) end end)
        Btn("Anchor to the screen (stays in place)", function() local f2 = ns.FolderById(p.fid); if f2 then ns.UnanchorGroup(f2); FillPosPopup(p) end end)
        Btn("Close", function() p:Hide() end)
        p:SetHeight(y - G + M)   -- 384: M under the Close button
        if UISpecialFrames then table.insert(UISpecialFrames, "XayaUIGroupPosPopup") end
        posPopup = p
    end
    p.fid = fo.id
    FillPosPopup(p)
    local cx, cy = GetCursorPosition()
    local us = UIParent:GetEffectiveScale()
    p:ClearAllPoints(); p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / us + 10, cy / us - 10)
    p:Show()
end

local function GroupHandle(f)
    local h = groupHandles[f.id]
    if h then return h end
    h = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    h:SetFrameStrata("HIGH"); h:SetFrameLevel(900)
    h:EnableMouse(true)
    h:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    h:SetBackdropColor(1, 0.6, 0.1, 0.08); h:SetBackdropBorderColor(1, 0.6, 0.1, 1)
    h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.label:SetPoint("BOTTOMLEFT", h, "TOPLEFT", 0, 2)
    h.fid = f.id
    local function Done(self)
        if not self.drag then return end
        self.drag = nil
        ns.MarkDirty()
        ns.Fire("CONFIG_CHANGED")
    end
    h:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" then return end
        local fo = ns.FolderById(self.fid)
        if not fo then return end
        if ns.MoverSelect and not ns.IsMoverTempLocked(fo) then ns.MoverSelect("group", fo) end
        if ns.IsMoverTempLocked(fo) then return end   -- (locked for now: the tag still opens the settings, but does not drag)
        local cx, cy = GetCursorPosition()
        self.drag = { cx = cx, cy = cy, x = fo.cX or 0, y = fo.cY or 0 }
    end)
    h:SetScript("OnMouseUp", function(self, btn)
        if btn == "RightButton" then
            local fo = ns.FolderById(self.fid)
            if fo then ShowGroupPosPopup(fo) end
        else
            Done(self)
        end
    end)
    h:SetScript("OnUpdate", function(self)
        local fo = ns.FolderById(self.fid)
        if not fo or not ns.groupUnlocked[self.fid] then self:Hide() return end
        if self.drag then
            if not IsMouseButtonDown("LeftButton") then Done(self)
            else
                local c = containers[fo.id]
                local ts = (c and c.xuiTarget and c.xuiTarget.GetEffectiveScale and c.xuiTarget:GetEffectiveScale()) or UIParent:GetEffectiveScale()
                if not ts or ts <= 0 then ts = 1 end
                local cx, cy = GetCursorPosition()
                fo.cX = math.floor(self.drag.x + (cx - self.drag.cx) / ts + 0.5)
                fo.cY = math.floor(self.drag.y + (cy - self.drag.cy) / ts + 0.5)
                Container(fo)
            end
        end
        local l, b, r, t = GroupBounds(fo)
        self:ClearAllPoints()
        if l then
            local pad = 4
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l - pad, b - pad)
            self:SetSize(math.max(24, r - l + 2 * pad), math.max(24, t - b + 2 * pad))
        else   -- nothing visible inside: a small box at the group's own position
            local c = Container(fo)
            local cx, cy = c:GetCenter()
            local s = c:GetEffectiveScale() / UIParent:GetEffectiveScale()
            if cx then self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * s, cy * s) else self:SetPoint("CENTER") end
            self:SetSize(80, 40)
        end
    end)
    groupHandles[f.id] = h
    return h
end
function ns.SetGroupUnlocked(f, on)
    if not f then return end
    ns.groupUnlocked[f.id] = on and true or nil
    local h = GroupHandle(f)
    if on then h.label:SetText(tostring(f.name) .. "  (drag to move the group; right-click for X / Y and centering)"); h:Show()
    else h.drag = nil; h:Hide(); if posPopup and posPopup.fid == f.id then posPopup:Hide() end end
    for _, r in ipairs(ns.rules or {}) do
        if r.visual and InFolder(r.folder, f.id) then
            ns.RefreshVisual(r)
            ns.SetVisualShown(r, ns.runtime and ns.runtime[r] and ns.runtime[r].visualWanted)
        end
    end
    if ns.RefreshGroupTags then ns.RefreshGroupTags() end   -- an unlocked group shows its handle instead of its mover-view tag
end

-------------------------------------------------------------------------------
-- Mover view (Xaya 2026-11-04: "when you open the anchors/mover view, enable hover-over groups or individual icons and enable the
-- ability to go to a specific element to modify its options"). While every display is unlocked (/xui unlock), each group with a
-- display on screen gets a faint outline (it takes no mouse, so the displays inside stay draggable) and a name tab above it. Hovering
-- the tab lights the outline and names the group; a click opens the group's settings, a right-click its X / Y popup, and dragging the
-- tab moves the whole group. Nested groups stack their tabs upward so they do not cover each other. Displays get a tooltip (GetFrame).
-------------------------------------------------------------------------------
local groupTags = {}
local TAG_H, TAG_PAD = 16, 4
function ns.FolderPathText(fid)
    local names, id, g = {}, fid, 0
    while id and g < 32 do
        local f = ns.FolderById(id)
        if not f then break end
        table.insert(names, 1, tostring(f.name)); id, g = f.parent, g + 1
    end
    return table.concat(names, " > ")
end
local function FolderDepth(f)
    local d, id = 0, f.parent
    while id and d < 32 do local p = ns.FolderById(id); if not p then break end; d, id = d + 1, p.parent end
    return d
end
local function ShownIn(f)
    local n = 0
    for rule, fr in pairs(frames) do if fr:IsShown() and InFolder(rule.folder, f.id) then n = n + 1 end end
    return n
end
local function TagWanted(f)
    return ns.unlocked and f and f.default ~= "cursor" and not ns.groupUnlocked[f.id]   -- (an unlocked group has its own handle)
end
local function TagTooltip(t)
    local fo = ns.FolderById(t.fid)
    if not (fo and GameTooltip) then return end
    GameTooltip:SetOwner(t, "ANCHOR_TOP")
    GameTooltip:AddLine("Group: " .. ns.FolderPathText(fo.id), 1, 0.82, 0)
    GameTooltip:AddLine(ShownIn(fo) .. " display(s) on screen", 1, 1, 1)
    GameTooltip:AddLine("Click: open this group's settings", 0.6, 0.85, 1)
    GameTooltip:AddLine("Right-click: X / Y, centering and anchoring", 0.6, 0.85, 1)
    GameTooltip:AddLine("Drag this tab: move the whole group", 0.6, 0.85, 1)
    GameTooltip:Show()
end
local function GroupTag(f)
    local t = groupTags[f.id]
    if t then return t end
    t = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    t:SetFrameStrata("MEDIUM"); t:SetFrameLevel(50)   -- under the displays (HIGH) and the settings window
    t:EnableMouse(true)
    t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    t:SetBackdropColor(0.05, 0.05, 0.05, 0.85); t:SetBackdropBorderColor(1, 0.6, 0.1, 0.9)
    t.label = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.label:SetPoint("LEFT", 4, 0)
    t.box = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    t.box:SetFrameStrata("MEDIUM"); t.box:SetFrameLevel(49)
    t.box:EnableMouse(false)
    t.box:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    t.box:SetBackdropBorderColor(1, 0.6, 0.1, 0.35)
    t.fid = f.id
    -- P5: the lock icon locks this group for now (no save): its displays let the mouse through to what is under them
    t.lock = CreateFrame("Button", nil, t)
    t.lock:SetSize(TAG_H - 2, TAG_H - 2); t.lock:SetPoint("RIGHT", -2, 0)
    t.lock.tex = t.lock:CreateTexture(nil, "OVERLAY"); t.lock.tex:SetAllPoints()
    t.lock.tex:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    t.lock:SetScript("OnClick", function()
        local fo = ns.FolderById(t.fid)
        if fo then ns.SetMoverTempLock(fo, not ns.IsMoverTempLocked(fo)) end
    end)
    t.lock:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(ns.IsMoverTempLocked(ns.FolderById(t.fid)) and "Unlock this group" or "Lock this group for now", 1, 0.82, 0)
        GameTooltip:AddLine("While locked its displays cannot be dragged and the mouse reaches what is under them. Nothing is saved; it ends when you leave the mover view.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    t.lock:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    local function Lit(on) t.box:SetBackdropBorderColor(1, 0.6, 0.1, on and 1 or 0.35) end
    t:SetScript("OnEnter", function(self) self.hovered = true; Lit(true); TagTooltip(self) end)
    t:SetScript("OnLeave", function(self)
        self.hovered = false; Lit(false)
        if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    t:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" then return end
        local fo = ns.FolderById(self.fid)
        if not fo then return end
        -- audit D27 (core 0.6.62): like the sidebar handle: a click selects the group for arrow-key nudges (QA B178), and a group
        -- locked for now does not drag ("its tag does not drag"); the click still opens its settings (OnMouseUp)
        if ns.MoverSelect and not ns.IsMoverTempLocked(fo) then ns.MoverSelect("group", fo) end
        if ns.IsMoverTempLocked(fo) then self.drag = { locked = true }; return end
        local cx, cy = GetCursorPosition()
        self.drag = { cx = cx, cy = cy, x = fo.cX or 0, y = fo.cY or 0, moved = false }
    end)
    t:SetScript("OnMouseUp", function(self, btn)
        local fo = ns.FolderById(self.fid)
        if not fo then self.drag = nil; return end
        if btn == "RightButton" then self.drag = nil; ShowGroupPosPopup(fo); return end
        local d = self.drag
        self.drag = nil
        if d and d.moved then GroupPosChanged(fo)   -- a drag: the new X / Y is saved
        elseif ns.EditFolder then ns.EditFolder(fo) end   -- a click: open the group's settings
    end)
    t:SetScript("OnUpdate", function(self)
        local fo = ns.FolderById(self.fid)
        if not TagWanted(fo) then self.drag = nil; self:Hide(); self.box:Hide(); return end
        local d = self.drag
        if d and d.locked then
            if not IsMouseButtonDown("LeftButton") then self.drag = nil end
        elseif d then
            if not IsMouseButtonDown("LeftButton") then
                self.drag = nil
                if d.moved then GroupPosChanged(fo) end
            else
                local cx, cy = GetCursorPosition()
                if d.moved or math.abs(cx - d.cx) + math.abs(cy - d.cy) > 3 then
                    d.moved = true
                    local ts = GroupTargetScale(fo)
                    fo.cX = math.floor(d.x + (cx - d.cx) / ts + 0.5)
                    fo.cY = math.floor(d.y + (cy - d.cy) / ts + 0.5)
                    Container(fo)
                end
            end
        end
        local l, b, r, top = GroupBounds(fo)
        if not l then   -- nothing of this group on screen: the tag stays, invisible and not clickable, until something shows
            self:SetAlpha(0); self:EnableMouse(false); self.box:Hide()
            return
        end
        self:SetAlpha(1); self:EnableMouse(true)
        local locked = ns.IsMoverTempLocked(fo)
        self.label:SetText(tostring(fo.name) .. (locked and " (locked)" or ""))
        self.lock.tex:SetDesaturated(not locked); self.lock.tex:SetAlpha(locked and 1 or 0.6)
        self:SetSize(math.max(40, (self.label:GetStringWidth() or 40) + 8 + TAG_H), TAG_H)
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l - TAG_PAD, top + TAG_PAD + 1 + FolderDepth(fo) * (TAG_H + 1))
        self.box:ClearAllPoints()
        self.box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l - TAG_PAD, b - TAG_PAD)
        self.box:SetSize(r - l + 2 * TAG_PAD, top - b + 2 * TAG_PAD)
        self.box:Show()
    end)
    t:Hide(); t.box:Hide()
    groupTags[f.id] = t
    return t
end
-- shows a tag for every group while everything is unlocked (its OnUpdate keeps it in place and hides it once that ends)
function ns.RefreshGroupTags()
    if not ns.unlocked then
        for _, t in pairs(groupTags) do t.drag = nil; t:Hide(); t.box:Hide() end
        return
    end
    for _, f in ipairs(ns.folders or {}) do
        if TagWanted(f) then GroupTag(f):Show() elseif groupTags[f.id] then groupTags[f.id]:Hide(); groupTags[f.id].box:Hide() end
    end
end
function ns.GroupTagFor(fid) return groupTags[fid] end   -- (tests)

-- /xui debug groups moved to XayaUI Dev Assist (core 0.6.56; REQUEST-LOG #81, XayaUI_DevAssist/CoreDebug.lua). It reads the frames
-- through this (read-only; nothing runs until it is typed).
function ns.VisualProbeState() return frames, containers, DynAncestor end

local function SnapMode() return (CueRulesDB and CueRulesDB.ui and CueRulesDB.ui.snapMode) or "free" end

-- x, y are offsets of the frame center from the screen center (UI units). Returns the snapped offsets.
function ns.SnapPosition(rule, fr, x, y)
    local mode = SnapMode()
    if mode == "grid" then
        return math.floor(x / SNAP_GRID + 0.5) * SNAP_GRID, math.floor(y / SNAP_GRID + 0.5) * SNAP_GRID
    elseif mode == "center" then
        if math.abs(x) <= SNAP_NEAR then x = 0 end
        if math.abs(y) <= SNAP_NEAR then y = 0 end
        return x, y
    elseif mode == "auras" then
        local ux, uy = UIParent:GetCenter()
        local w, h = fr:GetWidth() / 2, fr:GetHeight() / 2
        local bestX, bestY, dX, dY = nil, nil, SNAP_NEAR + 1, SNAP_NEAR + 1
        for r, o in pairs(frames) do
            if r ~= rule and o:IsShown() and o:GetCenter() then
                local s = o:GetEffectiveScale() / UIParent:GetEffectiveScale()
                local ocx, ocy = o:GetCenter()
                ocx, ocy = ocx * s - ux, ocy * s - uy
                local ow, oh = o:GetWidth() * s / 2, o:GetHeight() * s / 2
                -- my left / center / right against their left / center / right (and the same vertically)
                for _, mine in ipairs({ -w, 0, w }) do
                    for _, theirs in ipairs({ ocx - ow, ocx, ocx + ow }) do
                        local d = math.abs((x + mine) - theirs)
                        if d < dX then dX = d; bestX = theirs - mine end
                    end
                end
                for _, mine in ipairs({ -h, 0, h }) do
                    for _, theirs in ipairs({ ocy - oh, ocy, ocy + oh }) do
                        local d = math.abs((y + mine) - theirs)
                        if d < dY then dY = d; bestY = theirs - mine end
                    end
                end
            end
        end
        if bestX and dX <= SNAP_NEAR then x = math.floor(bestX + 0.5) end
        if bestY and dY <= SNAP_NEAR then y = math.floor(bestY + 0.5) end
    end
    return x, y
end

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
local SNAP_POS = {
    { "TOP_LEFT", "Top Left" }, { "TOP_CENTER", "Top Center" }, { "TOP_RIGHT", "Top Right" },
    { "RIGHT_TOP", "Right Top" }, { "RIGHT_CENTER", "Right Center" }, { "RIGHT_BOTTOM", "Right Bottom" },
    { "BOTTOM_RIGHT", "Bottom Right" }, { "BOTTOM_CENTER", "Bottom Center" }, { "BOTTOM_LEFT", "Bottom Left" },
    { "LEFT_BOTTOM", "Left Bottom" }, { "LEFT_CENTER", "Left Center" }, { "LEFT_TOP", "Left Top" },
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
-- audit D18 (core 0.6.62): centres stay exact here and are rounded once, when X / Y are stored (SetVisualCenterOffset). Rounding the
-- centre too moved a display 1 px per apply whenever its centre fell on a half pixel (odd size with a corner anchor, ...), and the
-- arrangement is re-applied on every refresh: displays crept and the mover view reported moves nobody made.
local function ArrR(n) return n end
function ns.ArrangeList(l, xMode, yMode, gap)
    if #l < 2 or not (xMode or yMode) then return false end
    gap = tonumber(gap) or 8
    for _, r in ipairs(l) do local cx, cy = ns.VisualCenterOffset(r); r.visual.x, r.visual.y = cx, cy end
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
        for _, r in ipairs(l) do local _, _, w = ArrDims(r)
            r.visual.x = ArrR(xMode == "left" and lo + w / 2 or xMode == "right" and hi - w / 2 or (lo + hi) / 2) end
    elseif xMode == "distribute" then
        local t = sorted(true)
        local a, b = ArrDims(t[1]), ArrDims(t[#t])
        for i, r in ipairs(t) do r.visual.x = ArrR(a + (b - a) * (i - 1) / (#t - 1)) end
    elseif xMode == "space" then
        local t, cur = sorted(true)
        for i, r in ipairs(t) do
            local x, _, w = ArrDims(r)
            if i == 1 then cur = x + w / 2 else r.visual.x = ArrR(cur + gap + w / 2); cur = r.visual.x + w / 2 end
        end
    end
    if yMode == "top" or yMode == "middle" or yMode == "bottom" then
        local top, bot = -math.huge, math.huge
        for _, r in ipairs(l) do local _, y, _, h = ArrDims(r); top = math.max(top, y + h / 2); bot = math.min(bot, y - h / 2) end
        for _, r in ipairs(l) do local _, _, _, h = ArrDims(r)
            r.visual.y = ArrR(yMode == "top" and top - h / 2 or yMode == "bottom" and bot + h / 2 or (top + bot) / 2) end
    elseif yMode == "distribute" then
        local t = sorted(false)
        local _, a = ArrDims(t[1]); local _, b = ArrDims(t[#t])
        for i, r in ipairs(t) do r.visual.y = ArrR(a + (b - a) * (i - 1) / (#t - 1)) end
    elseif yMode == "space" then
        local t, cur = sorted(false)
        for i, r in ipairs(t) do
            local _, y, _, h = ArrDims(r)
            if i == 1 then cur = y - h / 2 else r.visual.y = ArrR(cur - gap - h / 2); cur = r.visual.y - h / 2 end
        end
    end
    for _, r in ipairs(l) do ns.SetVisualCenterOffset(r, r.visual.x, r.visual.y) end
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
-- read where the frame is now and store it as the display's own X / Y (dragging always leaves any snap target)
local function CommitDrag(rule, fr, useSnap)
    local v = rule.visual
    v.snap = nil
    local parent, dyn = ParentFor(rule)
    local cx, cy = fr:GetCenter()
    if not cx then return end
    local ux, uy = parent:GetCenter()
    local s = fr:GetEffectiveScale() / parent:GetEffectiveScale()
    local cox, coy = cx * s - ux, cy * s - uy   -- center offsets; snapping works on these, then they are stored relative to the anchor
    if useSnap then cox, coy = ns.SnapPosition(rule, fr, math.floor(cox + 0.5), math.floor(coy + 0.5)) end
    ns.SetVisualCenterOffset(rule, cox, coy)
    Place(fr, rule, parent)
    if dyn then LayoutDynamic(dyn) end
    ArrangeAfter(rule)   -- G7: "arrangement wins"
    ns.Fire("CONFIG_CHANGED")
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
        -- audit D19 (core 0.6.62): check the frame first; a missing frame changes nothing (before, X / Y were zeroed and the snap saved)
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
-- Paired auras (session only): dragging one drags the other with it. Pairing unlocks the partner for movement, and
-- locking (or unpairing) puts that back.
function ns.PairedWith(rule) return pairOf[rule] end
function ns.ClearPair(rule)
    local o = pairOf[rule]
    if not o then return end
    pairOf[rule], pairOf[o] = nil, nil
    for _, r in ipairs({ rule, o }) do
        if tempUnl[r] then tempUnl[r] = nil; ns.SetMoveUnlocked({ r }, false) end
    end
end
function ns.SetPair(rule, other)
    ns.ClearPair(rule)
    if not other or other == rule then return end
    ns.ClearPair(other)
    pairOf[rule], pairOf[other] = other, rule
    for _, r in ipairs({ rule, other }) do
        if not Unl(r) then tempUnl[r] = true; ns.SetMoveUnlocked({ r }, true) end
    end
end

-- Linked auras (saved on the rule as rule.link = a shared id): dragging any member moves every other member by the same amount, so
-- their positions relative to each other are kept. Hold SHIFT when you start a drag to move just that one (its offset to the others
-- then changes, which is the new relative position). Members that are snapped to a game frame are left where they are.
function ns.LinkMembers(rule)
    local out = {}
    local id = rule and rule.link
    if not id then return out end
    for _, o in ipairs(ns.rules or {}) do if o ~= rule and o.link == id and o.visual then out[#out + 1] = o end end
    return out
end
function ns.LinkAura(rule, other)
    if not (rule and other and rule ~= other) then return end
    local id = other.link or rule.link or ("L" .. tostring(time()) .. tostring(math.random(1000, 9999)))
    -- joining another group moves the whole of the old group's membership with the dragged rule's choice: keep it simple, only this rule joins
    other.link, rule.link = id, id
    if ns.MarkDirty then ns.MarkDirty() end
end
function ns.UnlinkAura(rule)
    if not (rule and rule.link) then return end
    local id = rule.link
    rule.link = nil
    local left, last = 0, nil
    for _, o in ipairs(ns.rules or {}) do if o.link == id then left = left + 1; last = o end end
    if left == 1 then last.link = nil end   -- a link of one is no link
    if ns.MarkDirty then ns.MarkDirty() end
end

local DRAG_UP_WINDOW = 0.3   -- seconds after OnDragStop in which a left release still belongs to the drag (the mover view)
-- A drag that moved the display this little (px, each axis) was a click with a shaky hand, not a move (core 0.6.43): Xaya's saved
-- displays shifted by 2-4 px after clicks in the mover view (her XayaUI.lua, 2026-11-04, compared by the Dev Assist session).
local CLICK_SLOP = 5
function ns.ShowVisualMenu(rule, anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then ns.Print("the menu API is not available in this client.") return end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(rule.name or "Aura")
        local v = rule.visual
        local st = root:CreateButton("Snap Target")
        st:CreateRadio("None (free position)", function() return not (v.snap and v.snap.target) end, function() ns.SnapToTarget(rule, nil) end)
        st:CreateButton("Pick a frame on screen...", function()
            ns.PickFrame("Snap '" .. tostring(rule.name) .. "' to a frame", function(target, name)
                local ok, pos = ns.SnapToPicked(rule, target, name)
                if ok then ns.Print("'" .. tostring(rule.name) .. "' snapped to " .. name .. " (" .. tostring(pos):lower():gsub("_", " ") .. ")") end
            end)
        end)
        if v.snap and v.snap.target == "custom" and v.snap.frame then
            st:CreateRadio("Picked: " .. tostring(v.snap.frame), function() return v.snap and v.snap.target == "custom" end, function() end)
        end
        for _, t in ipairs(SNAP_TARGETS) do
            local sub = st:CreateButton(t.label)
            for _, p in ipairs(SNAP_POS) do
                sub:CreateRadio(p[2], function() return (v.snap and v.snap.target == t.key and v.snap.pos == p[1]) and true or false end,
                    function() ns.SnapToTarget(rule, t.key, p[1]) end)
            end
        end
        do
            local lk = root:CreateButton("Linked Auras (move together)")
            if lk.SetScrollMode then lk:SetScrollMode(320) end
            lk:CreateRadio("Not linked", function() return not rule.link end, function() ns.UnlinkAura(rule) end)
            for _, o in ipairs(ns.rules or {}) do
                if o ~= rule and o.visual then
                    lk:CreateRadio(o.name or "Aura", function() return rule.link ~= nil and o.link == rule.link end,
                        function() if rule.link and o.link == rule.link then ns.UnlinkAura(rule) else ns.LinkAura(rule, o) end end)
                end
            end
        end
        root:CreateButton("Center Vertically", function() ns.CenterVisual(rule, "v") end)
        root:CreateButton("Center Horizontally", function() ns.CenterVisual(rule, "h") end)
        local pr = root:CreateButton("Paired Aura")
        if pr.SetScrollMode then pr:SetScrollMode(320) end
        pr:CreateRadio("None", function() return pairOf[rule] == nil end, function() ns.ClearPair(rule) end)
        for _, o in ipairs(ns.rules or {}) do
            if o ~= rule and o.visual and frames[o] then
                pr:CreateRadio(o.name or "Aura", function() return pairOf[rule] == o end, function() ns.SetPair(rule, o) end)
            end
        end
        root:CreateDivider()
        local function radio(parent, mode)
            parent:CreateRadio(SNAP_LABELS[mode], function() return SnapMode() == mode end, function()
                CueRulesDB.ui = CueRulesDB.ui or {}
                CueRulesDB.ui.snapMode = mode
                ns.Print("aura positioning: " .. SNAP_LABELS[mode])
            end)
        end
        radio(root, "free")
        local snap = root:CreateButton("Drag Snapping")
        radio(snap, "grid"); radio(snap, "auras"); radio(snap, "center")
        root:CreateDivider()
        root:CreateButton("Edit This Aura", function() if ns.EditRule then ns.EditRule(rule) end end)
        local fo = rule.folder and ns.FolderById(rule.folder)
        if fo then root:CreateButton("Edit Its Group (" .. tostring(fo.name) .. ")", function() if ns.EditFolder then ns.EditFolder(fo) end end) end
    end)
end

local function GetFrame(rule)
    local fr = frames[rule]
    if fr then return fr end
    fr = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    fr:SetFrameStrata("HIGH")
    fr:SetClampedToScreen(true)
    fr:SetMovable(true)
    fr:RegisterForDrag("LeftButton")

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

    fr.label = fr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fr.label:SetPoint("BOTTOM", fr, "TOP", 0, 2)

    -- hover highlight (unlocked only): faint white wash; the border itself turns white in PaintBorder
    fr.hoverTex = fr:CreateTexture(nil, "OVERLAY", nil, 7)
    fr.hoverTex:SetAllPoints()
    fr.hoverTex:SetColorTexture(1, 1, 1, 0.18)
    fr.hoverTex:Hide()

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
    fr.label:SetParent(fr.txtHolder)
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

    fr:SetScript("OnEnter", function(self)
        if not Unl(rule) then
            if rule.visual and rule.visual.hoverTip then ns.ShowCueTooltip(rule, self) end
            return
        end
        self.hovered = true
        PaintBorder(rule, self)
        -- mover view (Xaya 2026-11-04): name what this is and what a click does
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local par = rule.parentUid and ns.FindParentRule and ns.FindParentRule(rule)
            GameTooltip:AddLine(tostring(par and par.name or rule.name), 1, 0.82, 0)
            if par then GameTooltip:AddLine("A cue of this rule", 1, 1, 1) end
            if rule.folder then GameTooltip:AddLine("Group: " .. ns.FolderPathText(rule.folder), 1, 1, 1) end
            GameTooltip:AddLine("Click: open its settings", 0.6, 0.85, 1)
            GameTooltip:AddLine("Right-click: snap, link, center, edit its group", 0.6, 0.85, 1)
            GameTooltip:AddLine(rule.link and "Drag: move it with its linked auras (Shift: alone)" or "Drag: move it", 0.6, 0.85, 1)
            GameTooltip:Show()
        end
    end)
    fr:SetScript("OnLeave", function(self)
        self.hovered = false
        PaintBorder(rule, self)
        if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    fr:SetScript("OnDragStart", function(self)
        if not Unl(rule) or (ns.MoverTempLocked and ns.MoverTempLocked(rule)) then return end
        if ns.MoverSelect then ns.MoverSelect("display", rule) end   -- (P4: the arrow keys nudge what was last dragged or clicked)
        self.wasDragged, self.dragStoppedAt = true, nil
        -- a paired aura rides along: anchor it to this one at its current offset for the length of the drag
        local o = pairOf[rule]
        local of = o and frames[o]
        self.pairRule, self.pairFr = nil, nil
        if of and of:IsShown() and Unl(o) then
            local ax, ay = self:GetCenter()
            local bx, by = of:GetCenter()
            if ax and bx then
                local sA, sB = self:GetEffectiveScale(), of:GetEffectiveScale()
                of:ClearAllPoints()
                of:SetPoint("CENTER", self, "CENTER", (bx * sB - ax * sA) / sB, (by * sB - ay * sA) / sB)
                self.pairRule, self.pairFr = o, of
            end
        end
        -- linked auras ride along unless SHIFT is held: shown ones are anchored to this frame at their current offset for the drag
        self.linkRides, self.linkHidden, self.linkStart = nil, nil, nil
        if rule.link and not IsShiftKeyDown() then
            local sv = rule.visual
            local pA = ParentFor(rule)
            if not (sv.snap and sv.snap.target) then self.linkStart = { sv.x or 0, sv.y or 0, pA } end
            local ax, ay = self:GetCenter()
            for _, o in ipairs(ns.LinkMembers(rule)) do
                local ov = o.visual
                if not (ov.snap and ov.snap.target) then
                    local of2 = frames[o]
                    if of2 and of2:IsShown() and ax then
                        local bx, by = of2:GetCenter()
                        if bx then
                            local sA, sB = self:GetEffectiveScale(), of2:GetEffectiveScale()
                            of2:ClearAllPoints()
                            of2:SetPoint("CENTER", self, "CENTER", (bx * sB - ax * sA) / sB, (by * sB - ay * sA) / sB)
                            self.linkRides = self.linkRides or {}
                            self.linkRides[#self.linkRides + 1] = { o, of2 }
                        end
                    elseif self.linkStart then
                        self.linkHidden = self.linkHidden or {}
                        self.linkHidden[#self.linkHidden + 1] = o   -- not on screen right now: shifted by the same amount in its saved X / Y
                    end
                end
            end
        end
        self.dragFrom = { self:GetCenter() }   -- where it was, to tell a small slip from a move (CLICK_SLOP)
        self:StartMoving()
    end)
    -- left click (without dragging) selects the aura and opens it in the editor; right click opens the move / snap / edit menu
    -- (core 0.6.42; Xaya 2026-11-04: "right mouse click mover is unreliable") Drags are left-button only, so a right click is never
    -- swallowed. A left release is ignored only when it ends a drag: while the drag runs (wasDragged) or within DRAG_UP_WINDOW after
    -- OnDragStop. Before, OnMouseUp alone cleared wasDragged and swallowed whatever came next; a drag released off the display (the
    -- game sends OnDragStop to the dragging frame but OnMouseUp only to the frame under the cursor) left it set, and the next right
    -- click was lost.
    fr:SetScript("OnMouseUp", function(self, button)
        if not Unl(rule) then return end
        if button == "LeftButton" and (self.wasDragged or (self.dragStoppedAt and (GetTime() - self.dragStoppedAt) <= DRAG_UP_WINDOW)) then
            self.dragStoppedAt = nil
            return
        end
        if button == "LeftButton" then
            ns.SelectVisual(rule)
            if ns.MoverSelect then ns.MoverSelect("display", rule) end
            if ns.EditRule then ns.EditRule(rule) end
        elseif button == "RightButton" then
            ns.SelectVisual(rule)
            ns.ShowVisualMenu(rule, self)
        end
    end)
    fr:SetScript("OnDragStop", function(self)
        self.wasDragged, self.dragStoppedAt = false, GetTime()
        self:StopMovingOrSizing()
        local from = self.dragFrom
        self.dragFrom = nil
        local cx, cy = self:GetCenter()
        if from and from[1] and cx and math.abs(cx - from[1]) <= CLICK_SLOP and math.abs(cy - from[2]) <= CLICK_SLOP then
            -- a click, not a move: everything goes back where it is saved (nothing is saved, no snap is cleared), then the click runs
            -- (the left release that follows, or came first, is swallowed as part of the drag: one click action)
            pcall(ns.RefreshVisual, rule)
            for _, p in ipairs(self.linkRides or {}) do pcall(ns.RefreshVisual, p[1]) end
            if self.pairRule then pcall(ns.RefreshVisual, self.pairRule) end
            self.linkRides, self.linkHidden, self.linkStart, self.pairRule, self.pairFr = nil, nil, nil, nil, nil
            ns.SelectVisual(rule)
            if ns.EditRule then ns.EditRule(rule) end
            return
        end
        CommitDrag(rule, self, true)
        if self.linkRides then
            for _, p in ipairs(self.linkRides) do CommitDrag(p[1], p[2], false) end
        end
        if self.linkHidden and self.linkStart then
            local dx, dy = (rule.visual.x or 0) - self.linkStart[1], (rule.visual.y or 0) - self.linkStart[2]
            for _, o in ipairs(self.linkHidden) do
                local ov = o.visual
                if ParentFor(o) == self.linkStart[3] then ov.x, ov.y = (ov.x or 0) + dx, (ov.y or 0) + dy; pcall(ns.RefreshVisual, o) end
            end
        end
        self.linkRides, self.linkHidden, self.linkStart = nil, nil, nil
        if self.pairFr then
            local pr, pf = self.pairRule, self.pairFr
            self.pairRule, self.pairFr = nil, nil
            CommitDrag(pr, pf, false)   -- the partner keeps the offset it had; it is re-anchored to its own container
        end
    end)
    -- smooth animation: the engine ticks 5x per second, which made the wipe / fades step. While one of those
    -- effects is active, re-run just that part every rendered frame from the stored (absolute) expiry time.
    -- (the per-frame effects script is attached only while an effect is running: see FxOnUpdate / SetFxRule)
    frames[rule] = fr
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
    fr.label:SetText(rule.name)
    -- a Bar cue (BarCue.lua): a status bar with icon, spark and name text instead of the art
    if v.kind == "bar" and ns.BarCueLayout then ns.BarCueLayout(fr, rule, v)
    elseif fr.barF and ns.BarCueHide then ns.BarCueHide(fr) end
    -- "Show tooltip on hover" needs the frame to see the mouse; clicks still pass through to whatever is behind it unless unlocked for moving
    local tip = v.hoverTip and true or false
    local movable = Unl(rule) and not (ns.MoverTempLocked and ns.MoverTempLocked(rule))   -- (a group locked for now from its mover tag: P5)
    fr:EnableMouse(movable or tip)
    if tip then
        pcall(fr.SetMouseClickEnabled, fr, movable and true or false)
        pcall(fr.SetMouseMotionEnabled, fr, true)
    elseif fr.SetMouseClickEnabled then
        pcall(fr.SetMouseClickEnabled, fr, true)
    end
    if Unl(rule) then
        fr:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        PaintBorder(rule, fr)
        fr.label:Show()
    else
        fr.hovered = false
        if fr.hoverTex then fr.hoverTex:Hide() end
        fr:SetBackdrop(nil)
        fr.label:Hide()
    end
    ns.UpdateVisualText(rule, ns.runtime and ns.runtime[rule] and ns.runtime[rule].info)
end

-- Preview / unlock sample: a timer that starts at 12.3 s and counts down to 0, then repeats, so the tenths-of-a-second
-- switch (Tenths Only Below) can be watched. The wipe, fades and text all read the same clock.
local SAMPLE_DURATION = 12.3

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

-- secret-safe text writers for pcall (no closure per call)
local function SetWholeSeconds(fs, sec) fs:SetText(("%d"):format(sec)) end
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
local function BindCooldownText(fr, t, dur)
    if fr.cdBind == false then return false end
    if not fr.cdBind then
        if not (C_DurationUtil and C_DurationUtil.CreateDurationTextBinding) then fr.cdBind = false; return false end
        local ok, b = pcall(C_DurationUtil.CreateDurationTextBinding)
        if not (ok and b) then fr.cdBind = false; return false end
        pcall(b.SetToDefaults, b)
        if not pcall(b.SetFontString, b, fr.text) then fr.cdBind = false; return false end
        pcall(b.SetZeroDurationText, b, ""); pcall(b.SetExpiredText, b, "")
        fr.cdBind, fr.cdBindFmt = b, nil
    end
    local b = fr.cdBind
    local fmt = ns.TimeFormatter(t.decimals, t.decimalBelow)
    if not fmt and AuraContainerInbound and AuraContainerInbound.GetDefaultAuraDurationFormatter then
        local okD, d = pcall(AuraContainerInbound.GetDefaultAuraDurationFormatter); fmt = okD and d or nil
    end
    if fmt and fr.cdBindFmt ~= fmt then if pcall(b.SetFormatter, b, fmt) then fr.cdBindFmt = fmt end end
    if not pcall(b.SetDuration, b, dur) then return false end
    if not fr.cdBindOn then
        if not pcall(b.SetEnabled, b, true) then return false end
        fr.cdBindOn = true
    end
    return true
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
        StopCdBind(fr)
        local ok, dur = pcall(C_UnitAuras.GetAuraDuration, ref.unit or "player", ref.instanceID)
        if not (ok and dur) then
            if ns.perfOn then ns.PerfPath(rule, "dur:GetAuraDuration " .. (ok and "returned nothing" or "failed")) end
        else
            -- path 2: our own text from the duration object's remaining time: whole seconds, full control of font / size / place,
            -- and no dependence on Blizzard's cooldown-number setting
            if dur.GetRemainingDuration then
                local okr, remS = pcall(dur.GetRemainingDuration, dur)
                if okr and remS then
                    local oks = pcall(SetWholeSeconds, fr.text, remS)
                    if oks then
                        if fr.cd then fr.cd:Hide() end
                        fr.text:Show()
                        if ns.perfOn then ns.PerfPath(rule, "dur:own text (secret seconds)") end
                        return
                    end
                    if ns.perfOn then ns.PerfPath(rule, "dur:format of secret seconds failed") end
                else
                    if ns.perfOn then ns.PerfPath(rule, "dur:GetRemainingDuration " .. (okr and "nil" or "failed")) end
                end
            end
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
function ns.BeginVisualStep() inStep = true end
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

function ns.SetMoveUnlocked(objs, on)
    for _, r in ipairs(objs or {}) do
        if not on and pairOf[r] then ns.ClearPair(r) end
        ns.moveUnlocked[r] = on and true or nil
        if r.visual then
            ns.RefreshVisual(r)
            ns.SetVisualShown(r, ns.runtime and ns.runtime[r] and ns.runtime[r].visualWanted)
        end
    end
end

-- Closing the settings window ends everything it started on screen (core 0.6.56; Xaya, 2026-11-06: "typing /xui and closing the menu does
-- not turn off previews -- this is a high priority issue, as it indicates that the addon is still running its options pane indirectly in
-- some way. this should not happen"). Up to now only the eye / headphone previews ended; the sidebar's per-rule and per-group movement
-- unlocks (sample displays with their boxes and names), the preview pause and an unlock made with the window's Lock Positions button stayed.
local windowOpen = false   -- the settings window is open (told by XayaUI_Options: ns.SetWindowOpen)
function ns.SetWindowOpen(on) windowOpen = on and true or false end
function ns.WindowOpen() return windowOpen end
function ns.EndWindowState()
    if ns.ClearPreview and ns.AnyPreview and ns.AnyPreview() then ns.ClearPreview() end
    if ns.previewPaused and ns.SetPreviewPaused then ns.SetPreviewPaused(false) end
    local rules = {}
    for r in pairs(ns.moveUnlocked) do rules[#rules + 1] = r end
    if #rules > 0 then ns.SetMoveUnlocked(rules, false) end
    local fids = {}
    for fid in pairs(ns.groupUnlocked) do fids[#fids + 1] = fid end
    for _, fid in ipairs(fids) do
        local f = ns.FolderById and ns.FolderById(fid)
        if f then ns.SetGroupUnlocked(f, false) else ns.groupUnlocked[fid] = nil end
    end
    if ns.unlocked and ns.unlockedByWindow then ns.ToggleUnlock() end
    ns.unlockedByWindow = nil
    if ns.MarkDirty then ns.MarkDirty() end
end

-- Each rule is refreshed on its own (one broken display cannot stop the rest). A rule whose display is switched off and that
-- has no frame yet gets none: sound-only cues and conditions no longer each carry a full display frame in memory.
local refreshErrSeen = setmetatable({}, { __mode = "k" })
function ns.RefreshAllVisuals()
    if ns.SyncCueFolders then pcall(ns.SyncCueFolders) end   -- a cue's group is its parent rule's group (Cues.lua)
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
    if ns.unlocked then ns.RefreshGroupTags() end   -- a group made or changed while everything is unlocked gets its mover-view tag
    pcall(ns.UpdateGroupBoxes)   -- the groups' border / background boxes (G5 / G11)
end

-------------------------------------------------------------------------------
-- Mover session (P4 / P5; Xaya 2026-11-06, her words: "arrow-key nudges yes; moves held until Save"; "lock icon in mover tool allows for
-- a temporary lock to account for potentially multiple rule groups stacked on top of each other; does not force a save. exiting out of
-- mover mode first creates a prompt to cancel or commit move changes. create a temp layout in drafts in case of game crash or something
-- which auto-deletes after a user clicked save").
-- - Opening the mover view (/xui unlock) keeps every display's and group's position aside (the draft, CueRulesDB.moverDraft). Moves
--   show at once; leaving the mover view with any move asks "Save moves" (the draft is deleted) or "Cancel moves" (all go back).
-- - The game writes saved data only at logout, /reload, a disconnect or quitting (not at a crash). So the draft covers a /reload or a
--   logout without Save: at the next login a prompt offers to keep or undo those moves. After a crash nothing of the session was
--   written: the last saved layout is what loads (the moves are lost, the layout is not damaged).
-- - The lock icon on a group's mover tag locks that group for now: its displays let the mouse through (to reach what is under them)
--   and its tag does not drag. It saves nothing and ends with the mover view.
-- - Arrow keys nudge the display or group last clicked or dragged in the mover view by 1 pixel (Shift: 10). Not in combat.
-------------------------------------------------------------------------------
local mover = { tempLock = {}, sel = nil }
local R_KEYS = { "x", "y", "anchor", "point", "anchorPlace" }
local F_KEYS = { "cX", "cY", "cRel", "cPoint", "cRelPoint", "cFrame", "cAnchorTo" }
local function Copy(t) if type(t) ~= "table" then return t end local o = {}; for k, v in pairs(t) do o[k] = Copy(v) end; return o end
local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function TakeDraft()
    local d = { at = time and time() or 0, rules = {}, folders = {} }
    for i, r in ipairs(ns.rules or {}) do
        local v = r.visual
        if type(v) == "table" then
            local e = { i = i, n = tostring(r.name), snap = Copy(v.snap) }
            for _, k in ipairs(R_KEYS) do e[k] = v[k] end
            d.rules[#d.rules + 1] = e
        end
    end
    for _, f in ipairs(ns.folders or {}) do
        if f.id then
            local e = {}
            for _, k in ipairs(F_KEYS) do e[k] = f[k] end
            d.folders[tostring(f.id)] = e
        end
    end
    return d
end
local function DraftRule(e)   -- the rule a draft entry is about (same place in the list and same name), or nil
    local r = ns.rules and ns.rules[e.i]
    if r and tostring(r.name) == e.n and type(r.visual) == "table" then return r end
end
-- what moved since the draft was taken: a list of { kind = "display" / "group", obj, entry }
function ns.MoverChanges(d)
    d = d or (CueRulesDB and CueRulesDB.moverDraft)
    local out = {}
    if type(d) ~= "table" then return out end
    for _, e in ipairs(d.rules or {}) do
        local r = DraftRule(e)
        if r then
            local v, moved = r.visual, not Same(r.visual.snap, e.snap)
            for _, k in ipairs(R_KEYS) do if v[k] ~= e[k] then moved = true end end
            if moved then out[#out + 1] = { kind = "display", obj = r, entry = e } end
        end
    end
    for fid, e in pairs(d.folders or {}) do
        local f = ns.FolderById(fid) or ns.FolderById(tonumber(fid))
        if f then
            for _, k in ipairs(F_KEYS) do if f[k] ~= e[k] then out[#out + 1] = { kind = "group", obj = f, entry = e }; break end end
        end
    end
    return out
end
local function Restore(d)
    for _, c in ipairs(ns.MoverChanges(d)) do
        if c.kind == "display" then
            local v = c.obj.visual
            for _, k in ipairs(R_KEYS) do v[k] = c.entry[k] end
            v.snap = Copy(c.entry.snap)
        else
            for _, k in ipairs(F_KEYS) do c.obj[k] = c.entry[k] end
            pcall(Container, c.obj)
        end
    end
end
local function EndSession(save)
    local d = CueRulesDB and CueRulesDB.moverDraft
    if d and not save then Restore(d) end
    if CueRulesDB then CueRulesDB.moverDraft = nil end
    wipe(mover.tempLock); mover.sel = nil
    if ns.MarkDirty then ns.MarkDirty() end
    ns.Fire("CONFIG_CHANGED")
end
function ns.MoverTempLocked(rule)   -- the display sits in a group locked for now from the mover tag's lock icon
    if not (ns.unlocked and rule and rule.folder and next(mover.tempLock)) then return false end
    for fid in pairs(mover.tempLock) do if InFolder(rule.folder, fid) then return true end end
    return false
end
function ns.SetMoverTempLock(f, on)
    if not f then return end
    mover.tempLock[f.id] = on and true or nil
    if mover.sel and mover.sel.kind == "group" and mover.sel.obj == f and on then mover.sel = nil end
    for _, r in ipairs(ns.rules or {}) do
        if r.visual and frames[r] and InFolder(r.folder, f.id) then pcall(ns.RefreshVisual, r) end
    end
end
function ns.IsMoverTempLocked(f) return f and mover.tempLock[f.id] and true or false end
function ns.MoverSelect(kind, obj) if ns.unlocked and obj then mover.sel = { kind = kind, obj = obj } end end
function ns.MoverSelection() return mover.sel end
-- P4: move the selected display or group by dx / dy pixels (its own units)
function ns.MoverNudge(dx, dy)
    local s = mover.sel
    if not (ns.unlocked and s) then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if s.kind == "group" then
        if mover.tempLock[s.obj.id] then return false end
        s.obj.cX = (s.obj.cX or 0) + dx; s.obj.cY = (s.obj.cY or 0) + dy
        GroupPosChanged(s.obj)
    else
        local r = s.obj
        if not (r.visual and frames[r]) or ns.MoverTempLocked(r) then return false end
        r.visual.x = (r.visual.x or 0) + dx; r.visual.y = (r.visual.y or 0) + dy
        local parent, dyn = ParentFor(r)
        Place(frames[r], r, parent)
        if dyn then LayoutDynamic(dyn) else ArrangeAfter(r) end
        ns.Fire("CONFIG_CHANGED")
    end
    return true
end
local NUDGE = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
local function KeyFrame()   -- made on the first opening of the mover view (V14); shown only while it is open
    if mover.keys then return mover.keys end
    local k = CreateFrame("Frame", "XayaUIMoverKeys", UIParent)
    k:EnableKeyboard(true)
    k:SetScript("OnKeyDown", function(self, key)
        local n = NUDGE[key]
        local used = n and not (InCombatLockdown and InCombatLockdown()) and mover.sel ~= nil
        if not (InCombatLockdown and InCombatLockdown()) and self.SetPropagateKeyboardInput then
            pcall(self.SetPropagateKeyboardInput, self, not used)   -- every other key still reaches the game
        end
        if used then
            local step = (IsShiftKeyDown and IsShiftKeyDown()) and 10 or 1
            ns.MoverNudge(n[1] * step, n[2] * step)
        end
    end)
    mover.keys = k
    return k
end
function ns.MoverKeyFrame() return mover.keys end
local function PromptAndThen(which, text, onSave, onCancel)
    StaticPopupDialogs[which] = StaticPopupDialogs[which] or {
        -- (no hide on Escape: an Escape must never throw moves away; the two buttons are her two choices)
        text = "%s", button1 = "Save moves", button2 = "Cancel moves", timeout = 0, whileDead = true, hideOnEscape = false,
        preferredIndex = 3,
        OnAccept = function(self, data) if data and data.save then data.save() end end,
        OnCancel = function(self, data, reason) if reason ~= "clicked" then return end if data and data.cancel then data.cancel() end end,
    }
    local dlg = StaticPopup_Show(which, text, nil, { save = onSave, cancel = onCancel })
    if dlg and dlg.SetFrameStrata then dlg:SetFrameStrata("TOOLTIP") end
    mover.prompt = which
end
function ns.MoverPromptShown() return mover.prompt end
local function Lock()
    ns.unlocked = false
    for r in pairs(pairOf) do ns.ClearPair(r) end
    if mover.keys then mover.keys:Hide() end
    ns.Print("visuals locked.")
    ns.RefreshAllVisuals()
    ns.RefreshGroupTags()
    if ns.QoL_RefreshAll then ns.QoL_RefreshAll() end
    if ns.Bars_RefreshAll then ns.Bars_RefreshAll() end
end
-- leave the mover view: Save keeps the moves, Cancel puts every display and group back where it was when the view opened
function ns.MoverExit(choice)
    mover.prompt = nil
    if choice == "save" or choice == "cancel" then EndSession(choice == "save") end
    if ns.unlocked then Lock() end
end
-- at login: a draft left by a /reload or logout without Save
function ns.MoverCheckDraft()
    local d = CueRulesDB and CueRulesDB.moverDraft
    if not d or ns.unlocked then return end
    local n = #ns.MoverChanges(d)
    if n == 0 then CueRulesDB.moverDraft = nil; return end
    local when = (date and d.at and d.at > 0) and date("%Y-%m-%d %H:%M", d.at) or "earlier"
    PromptAndThen("XAYAUI_MOVER_DRAFT", ("XayaUI: the mover view was left without Save (%s): %d display(s) or group(s) were moved. Keep these moves?"):format(when, n),
        function() mover.prompt = nil; EndSession(true) end,
        function() mover.prompt = nil; EndSession(false); ns.RefreshAllVisuals() end)
end
if ns.AtLogin then ns.AtLogin(function() ns.MoverCheckDraft() end) end   -- (Modules.lua; absent where Visual.lua is loaded on its own)

function ns.ToggleUnlock()
    if ns.unlocked then
        -- P5: leaving the mover view with moves asks first
        local n = #ns.MoverChanges()
        if n > 0 then
            PromptAndThen("XAYAUI_MOVER_EXIT", ("You moved %d display(s) or group(s) in the mover view. Save the moves, or cancel them (everything goes back to where it was)?"):format(n),
                function() ns.MoverExit("save") end, function() ns.MoverExit("cancel") end)
            return
        end
        ns.MoverExit("save")
        return
    end
    if CueRulesDB then CueRulesDB.moverDraft = TakeDraft() end
    wipe(mover.tempLock); mover.sel = nil
    KeyFrame():Show()
    ns.unlocked = true
    -- remembered so closing the settings window ends an unlock made while it was open (its Lock Positions button), not one typed as
    -- /xui unlock with the window closed (core-owned window flag, ns.WindowOpen / ns.EndWindowState); locking clears paired auras in Lock()
    ns.unlockedByWindow = ns.WindowOpen() and true or nil
    ns.Print("visuals UNLOCKED: drag them, then /xui unlock again to lock (you are asked to save or cancel the moves). Arrow keys nudge the display or group you last clicked (Shift: 10 pixels). Hover a display or a group's name tab to see what it is; click it to open its settings; the lock on a group's tab locks it for now.")
    ns.RefreshAllVisuals()
    ns.RefreshGroupTags()
    if ns.QoL_RefreshAll then ns.QoL_RefreshAll() end
    if ns.Bars_RefreshAll then ns.Bars_RefreshAll() end
end

function ns.DropVisual(rule)
    local fr = frames[rule]
    if fr then
        fr:Hide(); StopCdBind(fr)
        if fr.comp then fr.comp:Hide() end   -- (the companion hangs from the display's parent, not from the display)
        frames[rule] = nil
    end
end

-- /xui debug mods: what is really on a cue's frame right now (so a modifier that "does not apply" can be traced: data -> condition -> merged mods -> frame).
function ns.VisualDebug(rule)
    local fr = frames[rule]
    if not fr then return nil end
    local function try(f, ...) local ok, a, b, c, d = pcall(f, ...); if ok then return a, b, c, d end end
    local r, g, b, a = try(fr.tex.GetVertexColor, fr.tex)
    return { shown = fr:IsShown(), alpha = try(fr.GetAlpha, fr), strata = try(fr.GetFrameStrata, fr),
             color = r and { r, g, b, a } or nil, desat = try(fr.tex.GetDesaturation, fr.tex), glow = fr.glow and fr.glow:IsShown() or false }
end
