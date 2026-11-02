-- XayaUI: AuraDisplay -- draws a group's buff icons through Blizzard's own secure aura container, so they keep working in
-- combat when addon code cannot read auras.
--
-- WHY: in combat, addon code is refused aura reads (measured: GetUnitAuraInstanceIDs errors, UNIT_AURA payload tables are
-- secret).  Blizzard's CustomAuraContainer does the aura selection and the duration drawing in its own secure code, so the
-- icons are correct in combat without this addon ever reading a secret value.  This module only CONFIGURES that container.
--
-- Built from Blizzard's published UI source only (Blizzard_AuraContainer: CustomAuraContainer / CustomAuraButton /
-- AuraContainerUtil / AuraContainerFlowLayout, live branch).  No other addon's code or data is used.
--
-- WHAT IT DRAWS: Buff-present rules (and their Icon cue) that carry an `engineTag` field, in folders the user switched on with
-- /xuiengine.  Nothing is shipped: the spell IDs come from the user's own saved rules (CueRulesDB), exactly like every other
-- rule.  Rules without the tag are never touched.  This module never edits a rule.
--
-- KNOWN LIMITS (also in the design doc):
--   * candidateFilters.includeSpellIDs is real in Blizzard's code but absent from the generated API docs: it may change.
--     Every call is pcall'd; on any failure the group is marked failed and XayaUI keeps drawing its own icons (no gap).
--   * The engine cannot tell XayaUI which buffs are up (that would be reading secret state), so rule-level sounds and
--     conditions for these rules are not driven by it.  This module is display-only.
--   * Group layout is Blizzard's flow layout (collapses empty space itself); XayaUI's per-item sort is not applied.
--   * HCENTER / VCENTER growth is not supported (Blizzard's flow has no centered mode); those groups are left to XayaUI.
local _, ns = ...
ns = XayaUI_NS or ns

local D = {}
ns.AuraDisplay = D

local REL_FRAMES = { player = "PlayerFrame", target = "TargetFrame", focus = "FocusFrame", minimap = "Minimap", chat = "ChatFrame1" }
-- vector from a frame point to the frame centre, as a multiple of (width, height)
local TO_CENTER = {
    CENTER = { 0, 0 }, TOP = { 0, -.5 }, BOTTOM = { 0, .5 }, LEFT = { .5, 0 }, RIGHT = { -.5, 0 },
    TOPLEFT = { .5, -.5 }, TOPRIGHT = { -.5, -.5 }, BOTTOMLEFT = { .5, .5 }, BOTTOMRIGHT = { -.5, .5 },
}

local groups = {}      -- [folderId] = { frame = container, ok = bool, err = string?, ids = {set}, n = count }
local pendingBuild     -- build requested during combat lockdown
local lastError

local function DB()
    local db = CueRulesDB
    if not db then return nil end
    db.engineDisplay = db.engineDisplay or {}
    db.engineDisplay.groups = db.engineDisplay.groups or {}
    return db.engineDisplay
end

local function Say(...) if ns.Print then ns.Print(...) end end

-- Is `rule` (a parent or its cue) drawn by the engine right now?  Core asks this before showing its own icon.
function ns.EngineOwns(rule)
    if not rule or not rule.engineTag or not rule.folder then return false end
    local g = groups[rule.folder]
    return (g and g.ok) and true or false
end

-- Gather the user's tagged, enabled Buff-present rules of one folder.
local function Collect(fo)
    local ids, n, first = {}, 0, nil
    for _, r in ipairs(ns.rules or {}) do
        if not r.isCue and r.folder == fo.id and r.engineTag and r.enabled ~= false and r.useBuff then
            local id = tonumber(r.buffID)
            if id and id > 0 then
                ids[id] = true; n = n + 1
                if type(r.buffAlt) == "table" then for _, a in ipairs(r.buffAlt) do a = tonumber(a); if a and a > 0 then ids[a] = true end end end
                first = first or r
            end
        end
    end
    return ids, n, first
end

local function CueOf(rule)
    local cues = ns.CuesOf and ns.CuesOf(rule)
    return cues and cues[1]
end

-- Blizzard's flow layout settings for a XayaUI growth direction (nil = unsupported).
local function FlowFor(dir)
    local A, F = AnchorUtil.FlowLayoutAxis, AnchorUtil.FlowDirection
    if dir == "RIGHT" then return A.Horizontal, "TOPLEFT", F.Right, F.Down, -1, 1 end        -- wraps down
    if dir == "LEFT" then return A.Horizontal, "TOPRIGHT", F.Left, F.Down, 1, 1 end
    if dir == "DOWN" then return A.Vertical, "TOPLEFT", F.Right, F.Down, -1, 1 end            -- wraps right
    if dir == "UP" then return A.Vertical, "BOTTOMLEFT", F.Right, F.Up, -1, -1 end
end

-- Place the container so the FIRST icon's centre lands where XayaUI puts a dynamic group's first icon (the container centre).
local function Place(c, fo, anchor, iw, ih)
    local sc = math.max(0.1, fo.cScale or 1)
    local target = UIParent
    local rel = fo.cRel
    local gname = (rel == "custom") and fo.cFrame or REL_FRAMES[rel]
    local g = gname and gname ~= "" and _G[gname]
    if g and g.GetCenter then target = g end
    local pt = fo.cPoint or "CENTER"
    local rp = fo.cRelPoint or pt
    -- XayaUI: container point `pt` sits at target.rp + (cX, cY); the first icon is at the container's centre
    local tc = TO_CENTER[pt] or TO_CENTER.CENTER
    local cw, ch = math.max(1, fo.cW or 1), math.max(1, fo.cH or 1)
    local fx = (fo.cX or 0) + tc[1] * cw      -- first-icon centre relative to target.rp
    local fy = (fo.cY or 0) + tc[2] * ch
    -- Blizzard: the container corner `anchor` is the first icon's matching corner
    local ac = TO_CENTER[anchor] or TO_CENTER.CENTER   -- corner -> icon centre, in icon sizes
    local ox = fx - ac[1] * iw
    local oy = fy - ac[2] * ih
    c:SetScale(sc)
    c:SetAlpha(fo.cAlpha or 1)
    if fo.cStrata then c:SetFrameStrata(fo.cStrata) end
    c:ClearAllPoints()
    c:SetPoint(anchor, target, rp, ox / sc, oy / sc)
end

local function ButtonInit(w, h, cue)
    local v = (cue and cue.visual) or {}
    local zoom = 0.08 + (tonumber(v.zoom) or 0)
    local tx, cn = v.text or {}, v.count or {}
    local font = STANDARD_TEXT_FONT
    return function(btn)
        -- runs inside Blizzard's frame creation (securecallfunction); a failure here is caught by the caller
        btn:SetSize(w, h)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(btn)
        icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
        btn:SetIcon(icon)
        local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        cd:SetAllPoints(btn)
        cd:SetDrawSwipe(false); cd:SetDrawEdge(false); cd:SetHideCountdownNumbers(true)
        btn:SetDurationCooldown(cd)
        if tx.enabled ~= false then
            local fs = btn:CreateFontString(nil, "OVERLAY")
            fs:SetFont(font, tonumber(tx.size) or 11, "OUTLINE")
            fs:SetPoint(tx.anchor or "CENTER", btn, tx.anchor or "CENTER", tonumber(tx.x) or 0, tonumber(tx.y) or 0)
            btn:SetDurationText(fs, {})
        end
        if cn.enabled ~= false then
            local fs = btn:CreateFontString(nil, "OVERLAY")
            fs:SetFont(font, tonumber(cn.size) or 11, "OUTLINE")
            fs:SetPoint(cn.anchor or "BOTTOMRIGHT", btn, cn.anchor or "BOTTOMRIGHT", tonumber(cn.x) or 0, tonumber(cn.y) or 0)
            btn:SetApplicationCount(fs, {})
        end
    end
end

local function Fail(g, why)
    g.ok, g.err = false, tostring(why)
    lastError = g.err
    if g.frame then g.frame:Hide() end
end

-- Create (once) or update the container for one folder.
local function BuildGroup(fo)
    local g = groups[fo.id] or {}
    groups[fo.id] = g
    local dir = fo.cGrowth or "RIGHT"
    local axis, anchor, hdir, vdir, _, _ = FlowFor(dir)
    if fo.cType ~= "dynamic" or not axis then
        g.ok, g.err = false, (fo.cType ~= "dynamic") and "group is not a dynamic group" or ("growth " .. tostring(dir) .. " not supported")
        return g
    end
    local ids, n, first = Collect(fo)
    g.ids, g.n = ids, n
    if n == 0 then g.ok, g.err = false, "no enabled tagged Buff rules in this group"; if g.frame then g.frame:Hide() end; return g end
    local cue = CueOf(first)
    local v = (cue and cue.visual) or {}
    local iw, ih = tonumber(v.w) or 30, tonumber(v.h) or 30
    local sp = tonumber(fo.cSpacing) or 4
    local limit = (axis == AnchorUtil.FlowLayoutAxis.Horizontal) and (fo.cW or 0) or (fo.cH or 0)
    if limit <= 0 then limit = math.huge end

    local ok, err = pcall(function()
        if not g.frame then
            if C_AddOns and C_AddOns.LoadAddOn and not CustomAuraContainerTemplate then pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer") end
            local c = CreateFrame("Frame", "XayaUIEngine_" .. fo.id, UIParent, "CustomAuraContainerTemplate")
            c:SetUnit("player")
            c:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
            c:AddAuraGroup("main", "HELPFUL", {
                candidateFilters = { includeSpellIDs = ids },
                sortMethod = AuraContainerSortMethod.Default,
                sortDirection = AuraContainerSortDirection.Normal,
                maxFrameCount = math.huge,
                layout = { elementSpacing = sp, lineSpacing = sp, elementWidth = iw, elementHeight = ih },
                initializeFrame = ButtonInit(iw, ih, cue),
            })
            g.frame = c
        else
            g.frame:SetAuraGroupCandidateFilters("main", { includeSpellIDs = ids })
            g.frame:SetAuraGroupLayout("main", { elementSpacing = sp, lineSpacing = sp, elementWidth = iw, elementHeight = ih })
        end
        local c = g.frame
        c:SetFlowLayoutAxis(axis)
        c:SetFlowLayoutAnchorPoint(anchor)
        c:SetFlowLayoutGrowthDirection(hdir, vdir)
        c:SetFlowLayoutMaximumLineSize(limit)
        Place(c, fo, anchor, iw, ih)
        c:Show()
    end)
    if ok then g.ok, g.err = true, nil else Fail(g, err) end
    return g
end

local function TearDownGroup(fid)
    local g = groups[fid]
    if g then g.ok = false; if g.frame then g.frame:Hide() end end
end

local function RefreshCore()
    if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end
end

-- (Re)build every switched-on group.  Safe to call any time; defers while in combat lockdown.
function D.Build()
    local db = DB()
    if not db then return end
    if InCombatLockdown and InCombatLockdown() then pendingBuild = true; return end
    pendingBuild = nil
    for _, fo in ipairs(ns.folders or {}) do
        if db.groups[fo.id] then BuildGroup(fo) else TearDownGroup(fo.id) end
    end
    RefreshCore()
end

local function FindFolder(q)
    q = tostring(q or ""):lower()
    if q == "" then return nil, "name a group" end
    local hit, count
    count = 0
    for _, fo in ipairs(ns.folders or {}) do
        if tostring(fo.id):lower() == q or tostring(fo.name or ""):lower() == q then return fo end
        if tostring(fo.name or ""):lower():find(q, 1, true) then hit, count = fo, count + 1 end
    end
    if count == 1 then return hit end
    return nil, (count == 0) and ("no group matches '" .. q .. "'") or (count .. " groups match '" .. q .. "'; use more of the name")
end

function D.Status()
    local db = DB()
    local any = false
    for _, fo in ipairs(ns.folders or {}) do
        if db and db.groups[fo.id] then
            any = true
            local g = groups[fo.id]
            local _, n = Collect(fo)
            Say(string.format("%s: %s (%d tagged buff rules)%s", fo.name or fo.id, (g and g.ok) and "ENGINE DRAWN" or "NOT drawn by engine (XayaUI draws it)", n, (g and g.err) and (" - " .. g.err) or ""))
        end
    end
    if not any then Say("No group is switched on. Use /xuiengine on <group name>.") end
    if lastError then Say("last engine error: " .. lastError) end
end

local function Slash(msg)
    local cmd, rest = tostring(msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    local db = DB()
    if not db then Say("saved data not loaded yet") return end
    if cmd == "on" or cmd == "off" then
        local fo, err = FindFolder(rest)
        if not fo then Say(err) return end
        db.groups[fo.id] = (cmd == "on") or nil
        D.Build()
        D.Status()
    elseif cmd == "refresh" or cmd == "build" then
        D.Build(); D.Status()
    elseif cmd == "list" then
        for _, fo in ipairs(ns.folders or {}) do
            local _, n = Collect(fo)
            if n > 0 then Say(string.format("%s: %d tagged buff rules, %s", fo.name or fo.id, n, db.groups[fo.id] and "engine ON" or "engine off")) end
        end
    else
        D.Status()
        Say("/xuiengine on|off <group>, refresh, list.  Draws a group's tagged buffs through Blizzard's secure aura container so they show in combat.")
    end
end

SLASH_XUIENGINE1 = "/xuiengine"
SlashCmdList["XUIENGINE"] = Slash

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not pendingBuild then return end
    D.Build()
end)

D._groups = groups   -- for tests
