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
local function ApplyCoords(tex, v, base)
    local l, r, t, b = base[1], base[2], base[3], base[4]
    local cx, cy, hw, hh = (l + r) / 2, (t + b) / 2, (r - l) / 2, (b - t) / 2
    local rad = math.rad(v.rotation or 0)
    local c, s = math.cos(rad), math.sin(rad)
    local fit = (v.rotation or 0) % 360 == 0 and 1 or (math.abs(c) + math.abs(s))
    local sx = v.flipH and -1 or 1
    local sy = v.flipV and -1 or 1
    local function pt(qx, qy)
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
    local W, H = fr:GetWidth(), fr:GetHeight()
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", fr, "TOPLEFT", x0 * W, -(1 - y1) * H)
    tex:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -(1 - x1) * W, y0 * H)
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
    tex:SetAllPoints(fr)
    local uv = tex.xuiUV
    if uv then tex:SetTexCoord(uv[1], uv[2], uv[3], uv[4], uv[5], uv[6], uv[7], uv[8]) end
end

local function AtlasBase(name)
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    if ok and type(info) == "table" and info.leftTexCoord then
        return { info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord }
    end
    return { 0, 1, 0, 1 }
end

-- Paint the rule's art onto any texture (main image and the outline copies).
local function SetArt(tex, rule, v)
    local base = { 0, 1, 0, 1 }
    local kind = ns.Val(v.kind)
    if kind == "spellicon" then
        local sid = tonumber(rule.spellID) or 0
        if sid == 0 then sid = tonumber(rule.buffID) or 0 end   -- no cooldown spell: use the aura's icon
        local ok, t = pcall(C_Spell.GetSpellTexture, sid)
        tex:SetTexture(ok and t or nil)
        local z = 0.08 + clamp(v.zoom or 0, 0, 0.3)
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

-- The overlay layer: same art as the base, or its own art (sharing the base's zoom / rotation / mirror).
local function SetOverlayArt(tex, rule, v)
    local o = v.overlay or {}
    if ns.Val(o.source) == "other" then
        SetArt(tex, rule, { kind = o.kind, tex = o.tex, zoom = v.zoom, rotation = v.rotation, flipH = v.flipH, flipV = v.flipV })
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
local function Container(f)
    local c = containers[f.id]
    if not c then c = CreateFrame("Frame", nil, UIParent); c:SetSize(1, 1); containers[f.id] = c end
    c:SetSize(math.max(1, f.cW or 1), math.max(1, f.cH or 1))
    if c.SetClipsChildren then c:SetClipsChildren(f.cClip and true or false) end
    local pf = f.parent and ns.FolderById(f.parent)
    local parentC = pf and Container(pf) or UIParent
    if c:GetParent() ~= parentC then c:SetParent(parentC) end
    local target = parentC
    local rel = f.cRel
    local gname = (rel == "custom") and f.cFrame or REL_FRAMES[rel]
    local g = gname and gname ~= "" and _G[gname]
    if g and g.GetCenter and g ~= c then target = g end
    local sc = math.max(0.1, f.cScale or 1)
    c:SetScale(sc)
    c:SetAlpha(f.cAlpha or 1)
    if f.cStrata then c:SetFrameStrata(f.cStrata) end
    if (f.cLevel or 0) > 0 then c:SetFrameLevel(f.cLevel) end
    c:ClearAllPoints()
    c:SetPoint(f.cPoint or "CENTER", target, f.cRelPoint or f.cPoint or "CENTER", (f.cX or 0) / sc, (f.cY or 0) / sc)
    return c
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
local function LayoutDynamic(df)
    if not df then return end
    local items = {}
    for _, r in ipairs(ns.rules or {}) do
        local fr = frames[r]
        if fr and fr:IsShown() and ((r.folder and DynAncestor(r.folder) == df)
            or (r.cursorConv and ns.CursorReminderFolder and ns.CursorReminderFolder() == df)) then
            items[#items + 1] = { fr = fr, w = fr:GetWidth(), h = fr:GetHeight() }
        end
    end
    if #items == 0 then return end
    local dir = df.cGrowth or "RIGHT"
    local horiz = (dir == "RIGHT" or dir == "LEFT" or dir == "HCENTER")
    local sp = df.cSpacing or 4
    local limit = horiz and (df.cW or 0) or (df.cH or 0)   -- 0 = no wrapping
    -- split into lines along the main axis
    local lines, line, used = {}, {}, 0
    for _, it in ipairs(items) do
        local len = horiz and it.w or it.h
        if #line > 0 and limit > 0 and used + sp + len > limit then
            lines[#lines + 1] = line; line, used = {}, 0
        end
        used = (#line == 0) and len or (used + sp + len)
        line[#line + 1] = it
    end
    lines[#lines + 1] = line
    local container = Container(df)
    local crossOff = 0
    for _, ln in ipairs(lines) do
        local pos, cur, prevLen, cross = {}, 0, 0, 0
        for i, it in ipairs(ln) do
            local len = horiz and it.w or it.h
            if i == 1 then cur = 0 else cur = cur + prevLen / 2 + sp + len / 2 end
            pos[i], prevLen = cur, len
            cross = math.max(cross, horiz and it.h or it.w)
        end
        local shift = 0
        if dir == "HCENTER" or dir == "VCENTER" then
            local n = #ln
            local lead = pos[1] - (horiz and ln[1].w or ln[1].h) / 2
            local trail = pos[n] + (horiz and ln[n].w or ln[n].h) / 2
            shift = (lead + trail) / 2
        end
        local co = crossOff + cross / 2
        for i, it in ipairs(ln) do
            local p = pos[i] - shift
            local x, y = 0, 0
            if dir == "RIGHT" or dir == "HCENTER" then x = p; y = -co
            elseif dir == "LEFT" then x = -p; y = -co
            elseif dir == "DOWN" or dir == "VCENTER" then y = -p; x = co
            elseif dir == "UP" then y = p; x = co end
            it.fr:ClearAllPoints()
            it.fr:SetPoint("CENTER", container, "CENTER", x, y)
        end
        crossOff = crossOff + cross + sp
    end
end

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
local function Place(fr, rule, parent)
    local v = rule.visual
    local g = SnapFrame(v)
    fr:ClearAllPoints()
    if g then
        local a = SNAP_ANCHOR[v.snap.pos or "TOP_CENTER"] or SNAP_ANCHOR.TOP_CENTER
        fr:SetPoint(a[1], g, a[2], v.x or 0, v.y or 0)   -- x / y are fine offsets from the snap point
    else
        fr:SetPoint("CENTER", parent, "CENTER", v.x or 0, v.y or 0)
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
    v.x = math.floor((cx * s - ux) + 0.5)
    v.y = math.floor((cy * s - uy) + 0.5)
    if useSnap then v.x, v.y = ns.SnapPosition(rule, fr, v.x, v.y) end
    Place(fr, rule, parent)
    if dyn then LayoutDynamic(dyn) end
    if ns.OnPositionChanged then ns.OnPositionChanged(rule) end
end
function ns.SnapToTarget(rule, key, pos)
    local v = rule.visual
    if not key then
        v.snap = nil
    else
        v.snap = { target = key, pos = pos or "TOP_CENTER" }
        v.x, v.y = 0, 0
        if not SnapFrame(v) then ns.Print("that frame does not exist in this client, so the aura keeps its own position.") end
    end
    ns.RefreshVisual(rule)
    if ns.OnPositionChanged then ns.OnPositionChanged(rule) end
end
-- Center on the current reference: the snap target's axis when snapped, otherwise the screen (the folder container's origin).
function ns.CenterVisual(rule, axis)
    local v = rule.visual
    if v.snap and v.snap.target then
        local side = tostring(v.snap.pos or "TOP_CENTER"):match("^(%u+)_")
        if axis == "h" and (side == "TOP" or side == "BOTTOM") then v.snap.pos = side .. "_CENTER"; v.x = 0
        elseif axis == "v" and (side == "LEFT" or side == "RIGHT") then v.snap.pos = side .. "_CENTER"; v.y = 0
        else ns.Print("this aura is snapped to that side of the frame; choose a top / bottom (horizontal) or left / right (vertical) snap to center along it.") return end
    elseif axis == "h" then v.x = 0
    else v.y = 0 end
    ns.RefreshVisual(rule)
    if ns.OnPositionChanged then ns.OnPositionChanged(rule) end
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

function ns.ShowVisualMenu(rule, anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then ns.Print("the menu API is not available in this client.") return end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(rule.name or "Aura")
        local v = rule.visual
        local st = root:CreateButton("Snap Target")
        st:CreateRadio("None (free position)", function() return not (v.snap and v.snap.target) end, function() ns.SnapToTarget(rule, nil) end)
        for _, t in ipairs(SNAP_TARGETS) do
            local sub = st:CreateButton(t.label)
            for _, p in ipairs(SNAP_POS) do
                sub:CreateRadio(p[2], function() return (v.snap and v.snap.target == t.key and v.snap.pos == p[1]) and true or false end,
                    function() ns.SnapToTarget(rule, t.key, p[1]) end)
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
        if not Unl(rule) then return end
        self.hovered = true
        PaintBorder(rule, self)
    end)
    fr:SetScript("OnLeave", function(self)
        self.hovered = false
        PaintBorder(rule, self)
    end)
    fr:SetScript("OnDragStart", function(self)
        if not Unl(rule) then return end
        self.wasDragged = true
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
        self:StartMoving()
    end)
    -- left click (without dragging) selects the aura and opens it in the editor; right click opens the move / snap / edit menu
    fr:SetScript("OnMouseUp", function(self, button)
        if not Unl(rule) then return end
        if self.wasDragged then self.wasDragged = false; return end
        if button == "LeftButton" then
            ns.SelectVisual(rule)
            if ns.EditRule then ns.EditRule(rule) end
        elseif button == "RightButton" then
            ns.SelectVisual(rule)
            ns.ShowVisualMenu(rule, self)
        end
    end)
    fr:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        CommitDrag(rule, self, true)
        if self.pairFr then
            local pr, pf = self.pairRule, self.pairFr
            self.pairRule, self.pairFr = nil, nil
            CommitDrag(pr, pf, false)   -- the partner keeps the offset it had; it is re-anchored to its own container
        end
    end)
    -- smooth animation: the engine ticks 5x per second, which made the wipe / fades step. While one of those
    -- effects is active, re-run just that part every rendered frame from the stored (absolute) expiry time.
    fr:SetScript("OnUpdate", function(self)
        local r = self.fxRule
        if r then ns.UpdateVisualText(r, self.fxInfo, true) end
    end)
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
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", fr, "TOPLEFT", off[1], off[2])
                t:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", off[1], off[2])
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

function ns.RefreshVisual(rule)
    local v = rule.visual
    local fr = GetFrame(rule)
    fr:SetSize(math.max(8, v.w or 128), math.max(8, v.h or 128))
    local parent, dyn = ParentFor(rule)
    if fr:GetParent() ~= parent then fr:SetParent(parent) end
    ApplyStrata(fr, rule.folder)
    Place(fr, rule, parent)
    if dyn then LayoutDynamic(dyn) end
    fr.baseAlpha = v.alpha or 1
    fr:SetAlpha(fr.baseAlpha)
    fr.tex:SetBlendMode(v.additive and "ADD" or "BLEND")
    fr.tex.xuiCropped = false; fr.tex:ClearAllPoints(); fr.tex:SetAllPoints(fr)
    fr.tex2.xuiCropped = false; fr.tex2:ClearAllPoints(); fr.tex2:SetAllPoints(fr)
    SetArt(fr.tex, rule, v)
    fr.tex:SetAlpha(clamp(v.texAlpha or 1, 0, 1))
    -- overlay layer (own tint / desaturate / blend / opacity)
    local ov = v.overlay
    -- Progress-texture rules (v.fill.enabled) default to a locked base+overlay layering, unless ov.advanced is on:
    -- the overlay never greys (stays the "clean" top layer) and the base greys automatically iff it's tinted, to
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
    fr:EnableMouse(Unl(rule))
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
function ns.UpdateVisualText(rule, info, fxOnly)
    local fr = frames[rule]
    if not fr then return end
    local v = rule.visual
    local previewing = ns.IsPreview(rule, "visual")
    local sample = ns.unlocked or previewing
    local ref = info and info.buffRef

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
    if f == nil and ref and ref.instanceID ~= nil and C_UnitAuras and C_UnitAuras.GetAuraDuration
        and C_CurveUtil and (v.fadeGrey or v.fadeAlpha) then
        local okd, d = pcall(C_UnitAuras.GetAuraDuration, "player", ref.instanceID)
        if okd and d and d.EvaluateRemainingPercent then dobj = d end
    end
    fr.curves = fr.curves or {}
    local function NumCurve(key, y0, y1)   -- remaining 0% -> y0, 100% -> y1
        local ck = key .. y0 .. "/" .. y1
        local c = fr.curves[ck]
        if c == nil then
            local okc, cv = pcall(C_CurveUtil.CreateCurve)
            c = false
            if okc and cv then
                if Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(cv.SetType, cv, Enum.LuaCurveType.Linear) end
                if pcall(cv.AddPoint, cv, 0, y0) and pcall(cv.AddPoint, cv, 1, y1) then c = cv end
            end
            fr.curves[ck] = c
        end
        return c or nil
    end
    local function ColorCurve(key, c0, c1)
        local ck = key .. table.concat(c0, ",") .. "/" .. table.concat(c1, ",")
        local c = fr.curves[ck]
        if c == nil then
            local okc, cv = pcall(C_CurveUtil.CreateColorCurve)
            c = false
            if okc and cv and CreateColor then
                if Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(cv.SetType, cv, Enum.LuaCurveType.Linear) end
                if pcall(cv.AddPoint, cv, 0, CreateColor(c0[1], c0[2], c0[3], c0[4]))
                    and pcall(cv.AddPoint, cv, 1, CreateColor(c1[1], c1[2], c1[3], c1[4])) then c = cv end
            end
            fr.curves[ck] = c
        end
        return c or nil
    end

    -- fade: desaturate (gray) or blend vertex color toward a chosen color as the buff runs out; gray while on cooldown
    local d = fr.baseDesat or 0
    if v.desatOnCD and info and info.cd and info.cd.onCd then d = 1 end
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
                local cv = ColorCurve("c", { fc[1] or 1, fc[2] or 1, fc[3] or 1, fc[4] or 1 }, { cr, cg, cb, ca })
                if cv then
                    local okr, res = pcall(dobj.EvaluateRemainingPercent, dobj, cv)
                    if okr and res then colorDone = pcall(function() fr.tex:SetVertexColor(res:GetRGBA()) end) end
                end
            else
                local cv = NumCurve("g", 1, d)
                if cv then
                    local okr, res = pcall(dobj.EvaluateRemainingPercent, dobj, cv)
                    if okr and res ~= nil then greyDone = pcall(fr.tex.SetDesaturation, fr.tex, res) end
                end
            end
        end
    end
    if not greyDone then pcall(fr.tex.SetDesaturation, fr.tex, d) end
    if not colorDone then fr.tex:SetVertexColor(cr, cg, cb, ca) end

    -- opacity: out-of-combat multiplier, fade opacity as the buff runs out, then the "about to expire" flash
    local alpha = fr.baseAlpha or 1
    local oa = v.oocAlpha or 1
    if oa < 1 and not ((UnitAffectingCombat and UnitAffectingCombat("player")) or false) and not sample then
        alpha = alpha * oa
    end
    local alphaDone = false
    if v.fadeGrey and fr.fadeToClear then
        if f ~= nil then
            alpha = alpha * f
        elseif dobj then
            local cv = NumCurve("t", 0, alpha)
            if cv then
                local okr, res = pcall(dobj.EvaluateRemainingPercent, dobj, cv)
                if okr and res ~= nil then alphaDone = pcall(fr.SetAlpha, fr, res) end
            end
        end
    end
    if v.fadeAlpha then
        local mn = clamp(v.fadeAlphaMin or 0.15, 0, 1)
        local mx = clamp(v.fadeAlphaMax or 1, 0, 1)
        if f ~= nil then
            alpha = alpha * (mn + (mx - mn) * f)
        elseif dobj then
            local cv = NumCurve("a", alpha * mn, alpha * mx)
            if cv then
                local okr, res = pcall(dobj.EvaluateRemainingPercent, dobj, cv)
                if okr and res ~= nil then alphaDone = pcall(fr.SetAlpha, fr, res) end
            end
        end
    end
    local fl = v.flash
    if fl and fl.enabled and rem and rem > 0 and rem <= (fl.threshold or 3) then
        local wave = 0.5 + 0.5 * math.sin((sample and ns.SampleTime() or GetTime()) * (fl.speed or 3) * 2 * math.pi)
        alpha = alpha * (0.2 + 0.8 * wave)
    end
    if not alphaDone then fr:SetAlpha(alpha) end

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
    local wantsFx = (fl2 and fl2.enabled) or v.fadeAlpha or v.fadeGrey or (v.flash and v.flash.enabled)
    -- tenths of a second must move every frame (the engine tick is only 5x per second), so while the duration text is in its
    -- decimal range it is redrawn from here too
    local tx = v.text
    local wantsTenths = tx and tx.enabled and tx.decimals and rem ~= nil and rem > 0 and rem < (tx.decimalBelow or 5)
    fr.fxRule = ((wantsFx or wantsTenths) and (f ~= nil or dobj ~= nil)) and rule or nil
    fr.fxInfo = info
    if wantsTenths then
        fr.text:SetText(FmtRemaining(rem, tx.decimals, tx.decimalBelow))
        fr.text:Show()
    end
    if fxOnly then return end

    -- stacks / charges text
    local ct = v.count
    if ct and ct.enabled then
        local shown = false
        if ns.Val(ct.source) == "charges" then
            local ok, ch = pcall(C_Spell.GetSpellCharges, rule.spellID)
            if ok and type(ch) == "table" then
                local okv, cur = pcall(function() return ch.currentCharges end)
                if okv and cur ~= nil then shown = pcall(fr.count.SetText, fr.count, cur) end
            end
        else
            if ref and ref.applications ~= nil then shown = pcall(fr.count.SetText, fr.count, ref.applications) end
        end
        if not shown and sample then fr.count:SetText("3"); shown = true end
        fr.count:SetShown(shown)
    else
        fr.count:Hide()
    end

    -- shield / absorb amount text
    local ab = v.absorb
    if ab and ab.enabled then
        local shown = false
        local val
        if ns.Val(ab.source) == "aura" then
            if ref and ref.instanceID then
                local ok, a = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", ref.instanceID)
                if ok and type(a) == "table" then
                    local okp, pts = pcall(function() return a.points and a.points[1] end)
                    if okp then val = pts end
                end
            end
        else
            local ok, tot = pcall(UnitGetTotalAbsorbs, "player")
            if ok then val = tot end
        end
        if val ~= nil then
            if not ns.IsSecret(val) and type(val) == "number" then
                if val > 0 or not ab.hideZero then
                    local txt
                    if ab.abbreviate ~= false then
                        if val >= 1e6 then txt = ("%.1fM"):format(val / 1e6)
                        elseif val >= 1e3 then txt = ("%.1fK"):format(val / 1e3)
                        else txt = ("%d"):format(val) end
                    else txt = ("%d"):format(val) end
                    fr.absorb:SetText(txt); shown = true
                end
            else
                -- secret: display-only, cannot be compared (so hideZero does not apply)
                local out = val
                if ab.abbreviate ~= false and AbbreviateLargeNumbers then
                    local okA, s2 = pcall(AbbreviateLargeNumbers, val)
                    if okA and s2 ~= nil then out = s2 end
                end
                shown = pcall(fr.absorb.SetText, fr.absorb, out)
            end
        end
        if not shown and sample then fr.absorb:SetText(ab.abbreviate ~= false and "12.3K" or "12345"); shown = true end
        fr.absorb:SetShown(shown)
    else
        fr.absorb:Hide()
    end

    -- duration text
    local t = v.text
    if not (t and t.enabled) then
        fr.text:Hide()
        if fr.cd then fr.cd:Hide() end
        return
    end
    -- path 1: readable numbers -> our own text (full control)
    if ref and ref.expiration and ref.duration then
        if fr.cd then fr.cd:Hide() end
        if ref.duration > 0 then
            local rem = ref.expiration - GetTime()
            if rem > 0 then
                fr.text:SetText(FmtRemaining(rem, t.decimals, t.decimalBelow))
                fr.text:Show()
                return
            end
        end
        fr.text:Hide()
        return
    end
    -- path 2: numbers are secret -> hand Blizzard a duration object (experimental)
    if ref and ref.instanceID ~= nil and fr.cd and fr.cd.SetCooldownFromDurationObject
        and C_UnitAuras and C_UnitAuras.GetAuraDuration then
        local ok, dur = pcall(C_UnitAuras.GetAuraDuration, "player", ref.instanceID)
        if ok and dur then
            local ok2 = pcall(fr.cd.SetCooldownFromDurationObject, fr.cd, dur)
            if ok2 then
                fr.text:Hide()
                fr.cd:Show()
                return
            end
        end
    end
    if fr.cd then fr.cd:Hide() end
    if sample then
        fr.text:SetText(FmtRemaining(rem or SAMPLE_DURATION, t.decimals, t.decimalBelow)); fr.text:Show()
    else
        fr.text:Hide()
    end
end

-- Show/hide as driven by the engine (ignored while unlocked / previewing: everything shows)
function ns.SetVisualShown(rule, shown)
    local fr = GetFrame(rule)
    local pv = ns.IsPreview(rule, "visual")
    if not rule.visual.enabled and not pv then fr:Hide() return end
    if Unl(rule) or pv or shown then fr:Show() else fr:Hide() end
    local dyn = rule.folder and DynAncestor(rule.folder)
    if dyn then LayoutDynamic(dyn) end
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

function ns.RefreshAllVisuals()
    for _, r in ipairs(ns.rules or {}) do
        ns.RefreshVisual(r)
        ns.SetVisualShown(r, ns.runtime and ns.runtime[r] and ns.runtime[r].visualWanted)
    end
end

function ns.ToggleUnlock()
    ns.unlocked = not ns.unlocked
    if not ns.unlocked then for r in pairs(pairOf) do ns.ClearPair(r) end end
    ns.Print(ns.unlocked and "visuals UNLOCKED: drag them, then /xui unlock again to lock."
        or "visuals locked.")
    ns.RefreshAllVisuals()
    if ns.QoL_RefreshAll then ns.QoL_RefreshAll() end
    if ns.Bars_RefreshAll then ns.Bars_RefreshAll() end
end

function ns.DropVisual(rule)
    local fr = frames[rule]
    if fr then fr:Hide(); frames[rule] = nil end
end
