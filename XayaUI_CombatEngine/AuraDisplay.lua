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
-- WHAT IT DRAWS: every enabled Buff-present rule (and its Icon cue) that sits directly in a dynamic group, automatically
-- (no tag, no switch).  Nothing is shipped: the spell IDs come from the user's own saved rules (CueRulesDB), exactly like
-- every other rule.  This module never edits a rule.  `/xuiengine off <group>` keeps one group with XayaUI; `/xuiengine auto off`
-- turns the automatic mode off for all groups.
--
-- PERFORMANCE GUARD: the user's condition for drawing everything through the engine is that it must not cost frames.  Every 5 s
-- the game's own per-addon CPU meter (C_AddOnProfiler) is read for this addon; if its recent average stays above LIMIT_MS for
-- NEED checks in a row, automatic mode is switched off (XayaUI draws again once combat ends) and the trip is saved to
-- CueRulesDB.engineDisplay.guardTrips.  Unverified in game: that the meter is on by default and that its unit is milliseconds.
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
local LIMIT_MS, NEED = 1.0, 3   -- performance guard (see the header)
local guard = { bad = 0 }

local function DB()
    local db = CueRulesDB
    if not db then return nil end
    db.engineDisplay = db.engineDisplay or {}
    db.engineDisplay.groups = db.engineDisplay.groups or {}   -- [folderId] = true (forced on) / false (kept with XayaUI)
    if db.engineDisplay.auto == nil then db.engineDisplay.auto = true end
    return db.engineDisplay
end

local function Say(...) if ns.Print then ns.Print(...) end end

-- The parent rule of `rule` (itself when it is a parent; its parent when it is a cue / condition rule).
local function ParentOf(rule)
    if not rule then return nil end
    if rule.parentUid then return ns.FindParentRule and ns.FindParentRule(rule) or nil end
    return rule
end

-- A Buff-present parent rule the engine can draw: enabled, tracks a buff, sits in a group.
local function Eligible(p)
    if type(p) ~= "table" or p.isCue or p.enabled == false or not p.useBuff or not p.folder then return false end
    local id = tonumber(p.buffID)
    return (id and id > 0) and true or false
end

-- Is `rule` (a parent or its cue) drawn by the engine right now?  Core asks this before showing its own icon.
-- (cached per engine tick: finding a cue's parent scans the rule list, and this is asked for every rule every tick)
local ownCache, ownTick, ownVer = setmetatable({}, { __mode = "k" }), -1, 0
function ns.EngineOwns(rule)
    local t = ns.tickID or 0
    if ownTick ~= t then ownCache, ownTick = setmetatable({}, { __mode = "k" }), t end
    local c = ownCache[rule]
    if c ~= nil then return c end
    local p = ParentOf(rule)
    local res = false
    if Eligible(p) then
        local g = groups[p.folder]
        res = (g and g.ok and g.ids and g.ids[tonumber(p.buffID)]) and true or false
    end
    ownCache[rule] = res
    return res
end
local function OwnChanged() ownTick = -1 end   -- a build / failure / switch changes the answers at once

-- Gather the enabled Buff-present rules of one folder.
local function Collect(fo)
    local ids, n, first = {}, 0, nil
    for _, r in ipairs(ns.rules or {}) do
        if r.folder == fo.id and Eligible(r) then
            ids[tonumber(r.buffID)] = true; n = n + 1
            if type(r.buffAlt) == "table" then for _, a in ipairs(r.buffAlt) do a = tonumber(a); if a and a > 0 then ids[a] = true end end end
            first = first or r
        end
    end
    return ids, n, first
end

-- Effects XayaUI draws itself that the engine's container cannot: listed so nothing is lost silently.
local function Drops(p)
    local out = {}
    local cue = ns.CuesOf and ns.CuesOf(p)
    cue = cue and cue[1]
    local v = (cue and cue.visual) or p.visual or {}
    if v.fadeGrey then out[#out + 1] = "grey / colour fade" end
    if v.fadeAlpha then out[#out + 1] = "opacity fade" end
    if v.flash and v.flash.enabled then out[#out + 1] = "flash" end
    if v.fill and v.fill.enabled then out[#out + 1] = "wipe" end
    if v.glow then out[#out + 1] = "glow" end
    if v.desatOnCD then out[#out + 1] = "grey on cooldown" end
    if ns.OutcomesOf then
        local ok, oc = pcall(ns.OutcomesOf, p)
        if ok and type(oc) == "table" and #oc > 0 then out[#out + 1] = "condition changes (" .. #oc .. ")" end
    end
    return out
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
    OwnChanged()
    g.ok, g.err = false, tostring(why)
    lastError = g.err
    if g.frame then g.frame:Hide() end
end

-- Create (once) or update the container for one folder.
local function BuildGroup(fo)
    OwnChanged()
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
    if n == 0 then g.ok, g.err = false, "no enabled Buff rules in this group"; if g.frame then g.frame:Hide() end; return g end
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
    if ok then g.ok, g.err = true, nil; OwnChanged() else Fail(g, err) end
    return g
end

local function TearDownGroup(fid)
    OwnChanged()
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
        if D.Wanted(fo) then BuildGroup(fo) else TearDownGroup(fo.id) end
    end
    RefreshCore()
end

-- Is this group drawn by the engine?  An explicit choice (/xuiengine on|off) wins; otherwise automatic mode decides.
function D.Wanted(fo)
    local db = DB()
    if not db then return false end
    local v = db.groups[fo.id]
    if v ~= nil then return v and true or false end
    return db.auto ~= false and fo.cType == "dynamic"
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
    if not db then return end
    local any, dropN = false, 0
    for _, fo in ipairs(ns.folders or {}) do
        local _, n = Collect(fo)
        if n > 0 and D.Wanted(fo) then
            any = true
            local g = groups[fo.id]
            Say(string.format("%s: %s (%d buff rules)%s", fo.name or fo.id, (g and g.ok) and "ENGINE DRAWN" or "NOT drawn by engine (XayaUI draws it)", n, (g and g.err) and (" - " .. g.err) or ""))
            if g and g.ok then
                for _, r in ipairs(ns.rules or {}) do
                    if r.folder == fo.id and Eligible(r) then
                        local d = Drops(r)
                        if #d > 0 then dropN = dropN + 1; Say("   " .. tostring(r.name) .. ": the engine does not draw " .. table.concat(d, ", ")) end
                    end
                end
            end
        end
    end
    if not any then Say("Nothing is drawn by the engine (automatic mode " .. (db.auto ~= false and "on" or "OFF") .. ").") end
    Say(string.format("automatic mode: %s.  Performance guard: %s", db.auto ~= false and "on" or "OFF",
        guard.last and string.format("engine addon %.2f ms recent average (limit %.1f)", guard.last, LIMIT_MS) or "no reading yet (the game's addon meter may be off)"))
    if lastError then Say("last engine error: " .. lastError) end
end

local function Slash(msg)
    local cmd, rest = tostring(msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    local db = DB()
    if not db then Say("saved data not loaded yet") return end
    if cmd == "auto" then
        local a = rest:lower()
        if a == "on" or a == "off" then db.auto = (a == "on"); guard.bad = 0; D.Build() end
        D.Status()
    elseif cmd == "on" or cmd == "off" then
        local fo, err = FindFolder(rest)
        if not fo then Say(err) return end
        db.groups[fo.id] = (cmd == "on")
        D.Build()
        D.Status()
    elseif cmd == "reset" then
        local fo, err = FindFolder(rest)
        if not fo then Say(err) return end
        db.groups[fo.id] = nil   -- back to automatic
        D.Build(); D.Status()
    elseif cmd == "refresh" or cmd == "build" then
        D.Build(); D.Status()
    elseif cmd == "list" then
        for _, fo in ipairs(ns.folders or {}) do
            local _, n = Collect(fo)
            if n > 0 then Say(string.format("%s: %d buff rules, %s", fo.name or fo.id, n, D.Wanted(fo) and "engine ON" or "engine off")) end
        end
    else
        D.Status()
        Say("/xuiengine auto on|off, on|off|reset <group>, refresh, list.  Draws buff rules in dynamic groups through Blizzard's secure aura container so they show in combat; automatic unless switched off.")
    end
end

SLASH_XUIENGINE1 = "/xuiengine"
SlashCmdList["XUIENGINE"] = Slash

-- Performance guard: read this addon's own CPU from the game's meter; trip automatic mode off if it stays high.
local function GuardCheck()
    local db = DB()
    if not (db and db.auto ~= false) then guard.bad = 0; return end
    if not (C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric and Enum and Enum.AddOnProfilerMetric) then return end
    local ok, v = pcall(C_AddOnProfiler.GetAddOnMetric, "XayaUI_CombatEngine", Enum.AddOnProfilerMetric.RecentAverageTime)
    if not ok or type(v) ~= "number" then return end
    guard.last = v
    if v > LIMIT_MS then guard.bad = guard.bad + 1 else guard.bad = 0 end
    if guard.bad >= NEED then
        guard.bad = 0
        db.auto = false
        db.guardTrips = db.guardTrips or {}
        db.guardTrips[#db.guardTrips + 1] = { at = date("%Y-%m-%d %H:%M:%S"), ms = v, limit = LIMIT_MS }
        while #db.guardTrips > 10 do table.remove(db.guardTrips, 1) end
        Say(string.format("performance guard: the engine addon averaged %.2f ms per frame (limit %.1f) for %d checks, so automatic engine drawing is OFF; XayaUI draws again once combat ends. Turn it back on with /xuiengine auto on.", v, LIMIT_MS, NEED))
        D.Build()
    end
end
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(5, function() pcall(GuardCheck) end) end
D.GuardCheck = GuardCheck

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not pendingBuild then return end
    D.Build()
end)

D._groups = groups   -- for tests
