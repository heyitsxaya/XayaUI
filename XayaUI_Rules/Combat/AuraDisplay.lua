-- XayaUI: AuraDisplay -- draws every aura display through Blizzard's own secure aura container, so durations and stacks keep
-- working in combat, when addon code may not read auras.
--
-- WHY: in combat, addon code is refused aura reads (measured: GetUnitAuraInstanceIDs errors, UNIT_AURA payloads are secret).
-- Blizzard's CustomAuraContainer selects the auras and draws icon, time and stacks in its own secure code, so the display is
-- right in combat without this addon ever reading a secret value. This module only CONFIGURES containers.
-- Built from Blizzard's published UI source only (Blizzard_AuraContainer, live branch). No other addon's code or data is used.
--
-- WHAT IT DRAWS (automatically, no tag, no switch): every enabled display that shows an aura while it is up -
--   * buff rules inside a DYNAMIC group: one container per group, laid out like the group (growth, spacing, wrap);
--   * every other buff rule (no group, or a static group): one single-slot container sitting exactly on XayaUI's own icon;
--   * "Target Debuff (yours)" rules outside dynamic groups: a single slot on the target / focus, your debuffs only.
-- A display is taken only when the engine can show it faithfully: the display appears while the aura is up and nothing else
-- but load / talent settings decides it (those are followed live). Everything else stays with XayaUI, and `/xuiengine` names
-- every such display and the reason, so nothing slips through silently. Nothing is shipped: spell IDs come from the user's
-- own rules. This module never edits a rule.
--
-- POSITION: containers hang from XayaUI's own frames (the group frame, or the display's own frame) and use XayaUI's own
-- layout rule (ns.DynamicFirstOffset), so parent groups, anchors, scale, opacity and moves are inherited, never recomputed.
-- tests/layout_parity_run.py fails if the engine ever lands anywhere else.
--
-- PERFORMANCE GUARD: every 5 s the game's per-addon CPU meter (C_AddOnProfiler) is read for Blizzard's container code
-- (Blizzard_AuraContainer), where the containers' work is counted. Above LIMIT_MS for NEED checks in a row: first the displays of
-- specs you are not playing are handed back ("lean" mode); if it is still high, automatic mode goes off. Both last until the next
-- /reload or login only (0.6.13): the same container code also draws Blizzard's own target-frame auras (TargetFrame.xml uses the
-- AuraContainer widget), so the reading is not XayaUI's alone and must not switch XayaUI off for good. Each trip is announced and
-- logged (engineDisplay.guardTrips). Unverified in game: that the meter is on by default and that its unit is milliseconds.
--
-- KNOWN LIMITS (all stated by /xuiengine): icon order inside a group follows the game's aura order; mixed icon sizes in one group
-- are drawn at the first one's size; fades, flash, wipe, glow and condition-driven changes are XayaUI effects the container
-- cannot draw; a cue that a condition lists shows only while that condition is true (0.6.19, #260), with its opacity, grey and tint
-- changes drawn on a single slot (not inside a dynamic group; glow and strata not at all). includeSpellIDs is real in Blizzard's code but
-- absent from the generated API docs: every container call is pcall'd and a failure hands the display back to XayaUI (no gap).
local _, ns = ...; ns = XayaUI_NS or ns -- (P4) XayaUI Rules shares the Platform's namespace (XayaUI/Core.lua)
local CoreS = ns.Settings("core")   -- (core 0.6.75, P2 settings seam: the same CueRulesDB keys as before)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("core", "XayaUI_Rules", "XayaUIRulesDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)
ns = XayaUI_NS or ns

-- Loaded once: XayaUI itself loads the engine files (XayaUI.toc), so pulling the repo is enough; an old separate
-- XayaUI_CombatEngine folder (installed before 0.6.0) finds this and steps aside (no double load).
ns.engineFiles = ns.engineFiles or {}
if ns.engineFiles.AuraDisplay then return end
ns.engineFiles.AuraDisplay = true

local D = {}
ns.AuraDisplay = D

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local groups = {}      -- [folderId] = { frame, ok, err, ids = {spellID=true}, n, members = {rule...}, sig }
local singles = {}     -- [parentRule] = { frame, ok, err, host, kind, display, single = true }
local extras = {}      -- [displayCue] = the same, for a rule's OTHER display cues that show time / stacks (one slot each, #347)
local owned = setmetatable({}, { __mode = "k" })   -- [rule] = slot record (a parent and its cues), rebuilt with every build
local left = {}        -- displays the engine does not draw: { rule, reason }
local pendingBuild, lastError
local serial = 0       -- build number: a slot built by the latest build carries it
local LIMIT_MS, NEED = 1.0, 3
local LEAN_REASON = "lean mode: not for the spec you are playing"
local guard = { bad = 0 }   -- .lean / .off: this session's trips (never saved)

local REL_FRAMES = { player = "PlayerFrame", target = "TargetFrame", focus = "FocusFrame", minimap = "Minimap", chat = "ChatFrame1" }
-- vector from a frame point to the frame centre, as a multiple of (width, height)
local TO_CENTER = {
    CENTER = { 0, 0 }, TOP = { 0, -.5 }, BOTTOM = { 0, .5 }, LEFT = { .5, 0 }, RIGHT = { -.5, 0 },
    TOPLEFT = { .5, -.5 }, TOPRIGHT = { -.5, -.5 }, BOTTOMLEFT = { .5, .5 }, BOTTOMRIGHT = { -.5, .5 },
}

local function DB()
    if not ns.SettingsReady("core") then return nil end
    local db = CoreS
    db.engineDisplay = db.engineDisplay or {}
    local e = db.engineDisplay
    e.groups = e.groups or {}   -- [folderId] = true (forced on) / false (kept with XayaUI)
    if e.auto == nil then e.auto = true end
    -- 0.6.13: guard trips no longer persist. Undo a saved one: "lean" was only ever set by the guard; "auto off" is undone only when
    -- the last saved trip turned it off (a player's own /xuiengine auto off after that cannot be told apart, and is reported).
    if e.guardV ~= 2 then
        e.guardV = 2
        local trips = type(e.guardTrips) == "table" and e.guardTrips or {}
        local last = trips[#trips]
        local undone = {}
        if e.lean then e.lean = nil; undone[#undone + 1] = "lean mode" end
        if e.auto == false and type(last) == "table" and last.step == "off" then e.auto = true; undone[#undone + 1] = "automatic drawing OFF" end
        if #undone > 0 then
            e.guardUndone = { at = date and date("%Y-%m-%d %H:%M:%S") or "?", what = table.concat(undone, " and "), trip = type(last) == "table" and last.at or nil }
        end
    end
    return e
end

local function Say(...) if ns.Print then ns.Print(...) end end
-- is XayaUI Dev Assist loaded (it has /xuiengine auto, on, off and reset since core 0.6.56)
local function DevOn() return ns.DevAssistOn and ns.DevAssistOn() or false end

-------------------------------------------------------------------------------
-- Rules: which display does XayaUI draw for a rule, and can the engine draw it faithfully?
-------------------------------------------------------------------------------
local function ParentOf(rule)
    if not rule then return nil end
    if rule.parentUid then return ns.FindParentRule and ns.FindParentRule(rule) or nil end
    return rule
end

-- The rule whose display XayaUI draws: the first cue with a display switched on, else the rule's own display.
local function IsDisplay(r)
    if not (r and r.visual and r.visual.enabled) then return false end
    return (not ns.KindHas) or ns.KindHas(r, "visual")   -- what Engine.lua DisplayWanted requires too
end
local function DisplayOf(p)
    local cues = ns.CuesOf and ns.CuesOf(p) or {}
    for _, c in ipairs(cues) do if IsDisplay(c) then return c end end
    if IsDisplay(p) then return p end
    return nil
end
-- XayaUI's own size for a display (Visual.lua RefreshVisual: at least 8, 128 when unset)
local function DisplaySize(v)
    return math.max(8, tonumber(v.w) or 128), math.max(8, tonumber(v.h) or 128)
end

local function FolderById(id) return id and ns.FolderById and ns.FolderById(id) or nil end
-- The dynamic group that lays out a rule in `folderId` (the nearest dynamic group, walking up: XayaUI's DynAncestor).
local function DynGroupId(folderId)
    local id, n = folderId, 0
    while id and n < 32 do
        local f = FolderById(id)
        if not f then return nil end
        if f.cType == "dynamic" then return f.id end
        id, n = f.parent, n + 1
    end
end
-- Did the user keep this group (or a group around it) with XayaUI? (/xuiengine off <group>)
local function KeptWithXayaUI(folderId)
    local db = DB()
    local id, n = folderId, 0
    while db and id and n < 32 do
        if db.groups[id] == false then return true end
        local f = FolderById(id)
        if not f then return false end
        id, n = f.parent, n + 1
    end
    return false
end

local function ExtraRows(p)
    local l = type(p.extra) == "table" and type(p.extra.list) == "table" and p.extra.list or nil
    return l or {}
end
local function NeedsCooldown(p)
    return ns.CooldownUsed and ns.CooldownUsed(p) and not (ns.Ignored and ns.Ignored(p.cdState)) or false
end

-- The same buff under another spell ID, learned in this player's game (AuraAlias.lua): a rule that lists a cast ID whose buff carries
-- its own ID is matched by the container too. The container matches the AURA's spell ID only (Blizzard_AuraContainerUtil.lua).
local function WithAliases(ids)
    if not ns.AuraAliasesOf then return ids end
    local add
    for id in pairs(ids) do
        local al = ns.AuraAliasesOf(id)
        if al then for a in pairs(al) do if not ids[a] then add = add or {}; add[#add + 1] = a end end end
    end
    if add then for _, a in ipairs(add) do ids[a] = true end end
    return ids
end

-- Classify a parent rule. Returns spec (what to draw) or nil and the reason it stays with XayaUI ("" = not an aura display).
--   spec = { kind = "buff" | "debuff", unit, filter, ids = {set}, display, trigger }
local function Classify(p)
    if type(p) ~= "table" or p.parentUid then return nil, "" end
    if p.enabled == false then return nil, "" end
    local display = DisplayOf(p)
    if not display then return nil, "" end
    -- a Bar cue (BarCue.lua): the game's aura button drives aura-time and stack bars; a bar that times the spell's cooldown or
    -- charges is XayaUI's (the game drives that bar from the cooldown's duration object, exact in combat too)
    if display.visual.kind == "bar" and ns.BarCueSource then
        local src = ns.BarCueSource(display)
        if src == "cooldown" or src == "charges" then return nil, "a Bar that times the spell's cooldown / charges (XayaUI draws it; the game drives the bar)" end
        if src == "stacks" and not (ns.BarCueMax and ns.BarCueMax(display)) then return nil, "a stacks Bar with no maximum (set Maximum on the cue; the game gives none for this aura)" end
    end
    local trigger = display.visual.trigger
    local rows = ExtraRows(p)
    local buffID = tonumber(p.buffID) or 0
    if p.useBuff and buffID > 0 then
        if p.buffState == "missing" then return nil, "shows while the aura is MISSING (the engine can only draw auras that are up)" end
        if trigger ~= "buffActive" and trigger ~= "condition" then return nil, "its display has no 'show when' choice" end
        if trigger == "condition" then
            if NeedsCooldown(p) then return nil, "shown only when its cooldown state also matches" end
            if #rows > 0 then return nil, "shown only when its other triggers also match" end
        end
        local ids = { [buffID] = true }
        if type(p.buffAlt) == "table" then for _, a in ipairs(p.buffAlt) do a = tonumber(a); if a and a > 0 then ids[a] = true end end end
        return { kind = "buff", unit = "player", filter = "HELPFUL", ids = WithAliases(ids), display = display, trigger = trigger }
    end
    -- a rule whose only trigger is one "Buff / Aura (another)" row (the built-in one removed): the same as the built-in Buff / Aura
    if #rows == 1 and type(rows[1]) == "table" and rows[1].type == "buffAura" and not p.useBuff and buffID == 0 and not NeedsCooldown(p) then
        local id = tonumber(rows[1].spellID) or 0
        if id <= 0 then return nil, "" end
        if rows[1].state == "no" then return nil, "shows while the aura is MISSING (the engine can only draw auras that are up)" end
        if trigger ~= "condition" then return nil, "its display has no 'show when' choice" end
        -- the row's extra aura IDs count too (retrospective gap 9: the engine icon stayed empty while the trigger counted a variant)
        local rids = { [id] = true }
        if type(rows[1].alt) == "table" then for _, a in ipairs(rows[1].alt) do a = tonumber(a); if a and a > 0 then rids[a] = true end end end
        return { kind = "buff", unit = "player", filter = "HELPFUL", ids = WithAliases(rids), display = display, trigger = trigger }
    end
    -- a rule whose only trigger is one "Target Debuff (yours)" row
    if #rows == 1 and type(rows[1]) == "table" and rows[1].type == "targetDebuff" and not NeedsCooldown(p) then
        local t = rows[1]
        local id = tonumber(t.spellID) or 0
        if id <= 0 then return nil, "" end
        if t.state == "no" then return nil, "shows while the debuff is MISSING (the engine can only draw auras that are up)" end
        if trigger ~= "condition" then return nil, "its display has no 'show when' choice" end
        return { kind = "debuff", unit = (t.unit == "focus") and "focus" or "target", filter = "HARMFUL|PLAYER", ids = { [id] = true }, display = display, trigger = trigger }
    end
    if p.useBuff or #rows > 0 then
        for _, t in ipairs(rows) do
            if type(t) == "table" and (t.type == "buffAura" or t.type == "targetDebuff") then return nil, "shows an aura only together with other triggers" end
        end
    end
    return nil, ""   -- cooldown / state / other displays: not aura displays
end

-- Spec filter for "lean" mode (performance guard first stage): only rules that load for the spec being played.
local function CurrentSpecID()
    if not (GetSpecialization and GetSpecializationInfo) then return nil end
    local ok, i = pcall(GetSpecialization)
    if not ok or not i then return nil end
    local ok2, id = pcall(GetSpecializationInfo, i)
    return ok2 and id or nil
end
local function LoadsForSpec(p, spec)
    local classes = p.load and p.load.classes
    if type(classes) == "table" and next(classes) and p.load.classUse ~= false then
        local okC, _, file = pcall(UnitClass, "player")
        if okC and file and ns.SetActive and ns.SetActive(classes) and not ns.SetMatch(classes, file) then return false end
    end
    local specs = p.load and p.load.specs
    if spec == nil or type(specs) ~= "table" or next(specs) == nil then return true end
    return specs[tostring(spec)] and true or false
end

-- XayaUI's own answer to "may this display show now?" apart from the aura itself: load and talent settings, as the engine's
-- last step found them (a display that shows only "when the aura is up" ignores load in XayaUI too).
-- "Only while on an action bar" is followed too (Engine.lua DisplayWanted hides such a display whatever its trigger).
local function Allowed(p, display, trigger)
    local v = display and display.visual
    if v and v.requireOnBar and ns.SpellOnActionBar then
        local id = tonumber(p.spellID) or 0
        if id == 0 then id = tonumber(p.buffID) or 0 end
        if id ~= 0 and not ns.SpellOnActionBar(id) then return false end
    end
    -- #260 (Xaya, 2026-11-04: "If a condition is enabled it should be enforced in or out of combat"): a display cue that a condition
    -- lists shows only while XayaUI's own reading of that cue is true (one of its switched-on conditions is true; Cues.lua
    -- EvaluateCue). Before 0.6.19 the engine showed it whenever the aura was up. A condition XayaUI cannot read in combat (for example
    -- stacks, which the game hides) is not met there, so such a display stays hidden in combat: unknown never shows.
    if display and display ~= p and display.isCue and ns.CueGated and ns.CueGated(p, display) then
        local crt = ns.runtime and ns.runtime[display]
        local cinfo = crt and crt.info
        if not (cinfo and cinfo.result == true) then return false end
    end
    if trigger ~= "condition" then return true end
    local rt = ns.runtime and ns.runtime[p]
    local info = rt and rt.info
    if not info then return true end
    return info.ctxOK ~= false and info.talentOK ~= false
end

-- Effects XayaUI draws itself that the container cannot (said per rule by /xuiengine, so nothing differs silently).
local function Drops(p, display, single, slot)
    local out = {}
    local v = (display and display.visual) or {}
    local f = v.fill
    if f and f.enabled and not single and v.kind ~= "bar" then out[#out + 1] = "progress drain (drawn only for a display on its own, not inside a group)" end
    if v.kind == "bar" and slot and slot.barDispel == "failed" then out[#out + 1] = "bar color by dispel type (the game refused it here; the bar shows the fixed blue)" end
    if f and f.enabled and single and ((tonumber(f.min) or 0) ~= 0 or (tonumber(f.max) or 1) ~= 1) then out[#out + 1] = "drain start / end limits" end
    if v.fadeGrey then out[#out + 1] = "grey / color fade" end
    if v.fadeAlpha then out[#out + 1] = "opacity fade" end
    if v.flash and v.flash.enabled then out[#out + 1] = "flash" end
    if v.glow then out[#out + 1] = "glow" end
    if v.desatOnCD then out[#out + 1] = "grey on cooldown" end
    -- the container cannot draw these two; a single slot gets them from XayaUI's companion texts, a group's icons do not
    if not single and v.absorb and v.absorb.enabled then out[#out + 1] = "shield amount text (drawn only for a display on its own, not inside a group)" end
    if not single and v.count and v.count.enabled and ns.Val and ns.Val(v.count.source) == "charges" then out[#out + 1] = "spell charges text (drawn only for a display on its own)" end
    if v.text and v.text.enabled and slot and slot.fmtFallback then out[#out + 1] = "time text in the game's own format (XayaUI's format could not be set up in this client)" end
    if not single and display then   -- (single slots leave the rule's other display cues to XayaUI, see Own)
        local n = 0
        for _, c in ipairs(ns.CuesOf and ns.CuesOf(p) or {}) do if c ~= display and c.visual and c.visual.enabled then n = n + 1 end end
        if n > 0 then out[#out + 1] = ("its other display cue%s (%d), such as a separate text, %s hidden while the group is drawn by the game"):format(n > 1 and "s" or "", n, n > 1 and "are" or "is") end
    end
    if display and display.cueKey and ns.ConditionsOf then
        local gate, mod = 0, 0
        for _, c in ipairs(ns.ConditionsOf(p)) do
            if c.enabled ~= false and type(c.thenCues) == "table" then
                for _, k in ipairs(c.thenCues) do
                    if k == display.cueKey then
                        gate = gate + 1
                        local m = type(c.thenMods) == "table" and c.thenMods[k]
                        if type(m) == "table" and m.on ~= false then mod = mod + 1 end
                        break
                    end
                end
            end
        end
        -- (0.6.19, #260: a listed display now shows only while its condition is true, and a single slot draws opacity, grey and tint)
        if gate > 0 then out[#out + 1] = "a condition XayaUI cannot read in combat (stacks, aura time) is not met there, so the display stays hidden in combat until it can be read" end
        if mod > 0 then out[#out + 1] = single and ("glow and strata changes from conditions (opacity, grey and tint are drawn) (%d)"):format(mod) or ("changes from conditions inside a dynamic group (glow, grey, opacity, tint, strata) (%d)"):format(mod) end
    end
    return out
end

-------------------------------------------------------------------------------
-- Ownership (asked by XayaUI for every display it is about to show)
-------------------------------------------------------------------------------
function ns.EngineOwns(rule)
    local slot = owned[rule]
    return (slot and slot.ok) and true or false
end
-- Does a display the engine draws on its own need XayaUI's companion texts (Visual.lua): a shield amount, or spell charges as its
-- count? The container draws icon, time, drain and aura stacks only.
local function NeedsCompanion(v)
    if type(v) ~= "table" then return false end
    if v.absorb and v.absorb.enabled then return true end
    return (v.count and v.count.enabled and ns.Val and ns.Val(v.count.source) == "charges") and true or false
end
function ns.EngineCompanion(rule)
    local slot = owned[rule]
    if not (slot and slot.ok and slot.single and slot.spec and slot.spec.display == rule) then return false end
    return NeedsCompanion(rule.visual)
end
-- A slot owns the rule and the display it draws. 0.6.2 (#347): a single slot no longer owns the rule's OTHER display cues (a separate
-- Text cue with the duration / shield amount, a second texture): the container cannot draw them, and owning them hid them, so they
-- vanished in game while the preview showed them. They stay with XayaUI, placed where XayaUI puts them. In a dynamic group they
-- stay owned (hidden), because XayaUI's own group layout would place them as extra items; /xuiengine says so (Drops).
-- 0.6.3: of those other display cues, the ones showing time / stacks / a drain get a slot of their own (ExtraDisplays, D.Build) when
-- only the rule's trigger decides them; owned[cue] then points at that slot. A shield amount or charges count on any single slot is
-- drawn by XayaUI's companion text (ns.EngineCompanion).
local function Own(slot, p, single)
    owned[p] = slot
    local display = slot and slot.spec and slot.spec.display
    for _, c in ipairs(ns.CuesOf and ns.CuesOf(p) or {}) do
        if not single or c == display or not (c.visual and c.visual.enabled) then owned[c] = slot end
    end
end

-------------------------------------------------------------------------------
-- Containers
-------------------------------------------------------------------------------
-- The same definition as Visual.lua ns.DynamicBlock (which wins when it is loaded), so the engine never ignores a growth setting;
-- tests/layout_parity_run.py checks the two agree for every growth, anchor point and wrap side.
local EDGE_BLOCK = {   -- (as Visual.lua's) [growth][extra lines on the other side] = horiz, right, down, corner
    RIGHT = { [false] = { true, true, true, "TOPLEFT" }, [true] = { true, true, false, "BOTTOMLEFT" } },
    LEFT = { [false] = { true, false, true, "TOPRIGHT" }, [true] = { true, false, false, "BOTTOMRIGHT" } },
    DOWN = { [false] = { false, true, true, "TOPLEFT" }, [true] = { false, false, true, "TOPRIGHT" } },
    UP = { [false] = { false, true, false, "BOTTOMLEFT" }, [true] = { false, false, false, "BOTTOMRIGHT" } },
}
function D._BlockFallback(fo)
    local dir = fo and fo.cGrowth or "RIGHT"
    local rev = fo and fo.cWrapRev and true or false
    if dir == "HCENTER" then
        if rev then return { horiz = true, right = true, down = false, corner = "BOTTOMLEFT", pin = "BOTTOM", pinTo = "CENTER" } end
        return { horiz = true, right = true, down = true, corner = "TOPLEFT", pin = "TOP", pinTo = "CENTER" }
    elseif dir == "VCENTER" then
        if rev then return { horiz = false, right = false, down = true, corner = "TOPRIGHT", pin = "RIGHT", pinTo = "CENTER" } end
        return { horiz = false, right = true, down = true, corner = "TOPLEFT", pin = "LEFT", pinTo = "CENTER" }
    elseif dir == "ANCHOR_ROW" or dir == "ANCHOR_COL" then
        local pt = fo.cPoint or "CENTER"
        if not TO_CENTER[pt] then pt = "CENTER" end
        local onRight, onBottom = pt:find("RIGHT", 1, true) ~= nil, pt:find("BOTTOM", 1, true) ~= nil
        return { horiz = (dir == "ANCHOR_ROW"), right = not onRight, down = not onBottom,
            corner = (onBottom and "BOTTOM" or "TOP") .. (onRight and "RIGHT" or "LEFT"), pin = pt, pinTo = pt }
    elseif EDGE_BLOCK[dir] and fo then   -- (Rules 0.6.82, fix A) Auto size with a point other than Center: the whole grid's point
        local pt = fo.cPoint
        local auto
        if fo.cSize == "set" or fo.cSize == "auto" then auto = (fo.cSize == "auto") else auto = not ((fo.cW or 0) > 0 or (fo.cH or 0) > 0) end
        if pt and pt ~= "CENTER" and TO_CENTER[pt] and auto then
            local e = EDGE_BLOCK[dir][rev]
            return { horiz = e[1], right = e[2], down = e[3], corner = e[4], pin = pt, pinTo = pt }
        end
    end
    return nil
end

-- Blizzard's flow layout settings for a XayaUI growth direction (nil = unsupported). Edge growths (Right, Left, Down, Up) return
-- axis, start corner and directions; block growths (Centered row / column, From anchor point) also return the container point
-- that is pinned (`pin`) and the point of XayaUI's group frame it is pinned on (`pinTo`).
local function FlowFor(dir, rev, fo)
    local A, F = AnchorUtil.FlowLayoutAxis, AnchorUtil.FlowDirection
    -- a block first: an edge growth is one too in Auto size with a point other than Center (Rules 0.6.82, fix A: the whole grid's point
    -- on the group's point; the start corner and directions are the edge growth's own, listed below)
    local blk = fo and (ns.DynamicBlock or D._BlockFallback)(fo)
    if blk then
        return blk.horiz and A.Horizontal or A.Vertical, blk.corner, blk.right and F.Right or F.Left, blk.down and F.Down or F.Up, blk.pin, blk.pinTo
    end
    if dir == "RIGHT" then
        if rev then return A.Horizontal, "BOTTOMLEFT", F.Right, F.Up end                -- extra rows go up
        return A.Horizontal, "TOPLEFT", F.Right, F.Down end                            -- wraps down
    if dir == "LEFT" then
        if rev then return A.Horizontal, "BOTTOMRIGHT", F.Left, F.Up end
        return A.Horizontal, "TOPRIGHT", F.Left, F.Down end
    if dir == "DOWN" then
        if rev then return A.Vertical, "TOPRIGHT", F.Left, F.Down end                  -- extra columns go left
        return A.Vertical, "TOPLEFT", F.Right, F.Down end                              -- wraps right
    if dir == "UP" then
        if rev then return A.Vertical, "BOTTOMRIGHT", F.Left, F.Up end
        return A.Vertical, "BOTTOMLEFT", F.Right, F.Up end
    -- Block growth (Xaya 2026-11-04: "the trick would be getting the dynamic group to expand and contract based on the aura windows
    -- actually appearing"; "the growth should also be informed by anchor placement in the parent group container"). Visual.lua
    -- ns.DynamicBlock is the one definition, for XayaUI's own layout and this container. After every layout pass Blizzard sets the
    -- container's size to the icons that are showing, in combat too (Blizzard_CustomAuraContainer.lua
    -- CustomAuraContainerFlowLayoutMixin:OnLayoutComplete -> container:SetSize), so a container pinned by the block's `pin` point
    -- grows and shrinks around it as auras come and go.
    -- (the blocks are returned at the top)
end

-- The longest a line may be before it wraps: the container's width / height and / or "items per row / column" (same rule as XayaUI's
-- Visual.lua LayoutDynamic; the engine's icons all use the first display's size, so for equal sizes the two agree exactly).
local function WrapLimit(fo, horizontal, iw, ih, sp)
    local limit = horizontal and (fo.cW or 0) or (fo.cH or 0)
    local n = tonumber(fo.cWrapN) or 0
    if n > 0 then
        local by = n * (horizontal and iw or ih) + (n - 1) * sp + 0.5
        if limit <= 0 or by < limit then limit = by end
    end
    if limit <= 0 then limit = math.huge end
    return limit
end

-- XayaUI's "progress" direction -> status bar orientation / reverse fill (Visual.lua CropTex: "bottom" keeps the bottom part
-- of the art, so the top edge comes down = a vertical bar filling from the bottom; "top" the reverse; "left" / "right" sideways)
local BAR_DIR = {
    none = { "VERTICAL", false }, bottom = { "VERTICAL", false }, top = { "VERTICAL", true },
    left = { "HORIZONTAL", false }, right = { "HORIZONTAL", true },
}
local function TimerDirection(reverse)
    local E = Enum and Enum.StatusBarTimerDirection
    if reverse then return E and E.ElapsedTime or 0 end
    return E and E.RemainingTime or 1
end
-- Does this display use XayaUI's progress drain, which a single slot draws as a Blizzard duration bar?
local function UsesBar(display, single)
    local f = display and display.visual and display.visual.fill
    return single and f and f.enabled and true or false
end

-- The button's look. A group's buttons show whichever of its auras is up, so they take the aura's own icon; a single slot
-- shows one display, so it is painted with that display's own art (XayaUI's art routine), its background, opacity, and - for a
-- progress display - a status bar the game itself drives from the aura's duration (the drain keeps working in combat).
-- A single slot's art sits where XayaUI draws it: art set smaller than the display (Icon width / height) is inset and centered;
-- art larger than the display is cropped by its texture coordinates (PaintDisplayArt), so it fills the slot.
local function FitArt(region, btn, v, single)
    local ix, iy = 0, 0
    if single and ns.ArtInset then ix, iy = ns.ArtInset(v) end
    if ix > 0 or iy > 0 then
        region:SetPoint("TOPLEFT", btn, "TOPLEFT", ix, -iy)
        region:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -ix, iy)
    else
        region:SetAllPoints(btn)
    end
end

-- A container text styled like XayaUI's (ns.StyleText); a font is set first, so the text can never be left without one.
local function Style(fs, btn, t, default, font)
    fs:SetFont(font, 12, "OUTLINE")
    if ns.StyleText and pcall(ns.StyleText, fs, btn, t, default) then return end
    fs:SetFont(font, tonumber(t.size) or 12, "OUTLINE")
    fs:ClearAllPoints()
    fs:SetPoint(default, btn, default, tonumber(t.x) or 0, tonumber(t.y) or 0)
end

-- A Bar cue's button (BarCue.lua decides source, colour, geometry for both paths): icon square, a status bar the game drives
-- (aura time: SetDurationBar; stacks: SetApplicationBar), a spark on the fill's edge, the aura's name (SetSpellName), the time and
-- count texts. Colour: the tooltip's type or a fixed colour is set once; otherwise the game colours the fill by the aura's dispel
-- type (AddDispelTypeTexture, PreserveAsset style, our colour map with "None" = the fixed blue), in combat too.
-- Blizzard 12.1.5 source read for this (no code copied): Blizzard_CustomAuraButton.lua SetDurationBar, SetApplicationBar,
-- SetSpellName, AddDispelTypeTexture / ApplyDispelTypeTexture; Blizzard_AuraContainerUtil.lua ValidateInboundScriptObject (an
-- inbound object must be the button or a descendant of it).
local function BarEdge(region, btn, l, r, orient)   -- the bar's rectangle inside the button, beside the icon square
    region:ClearAllPoints()
    if orient == "HORIZONTAL" then
        region:SetPoint("TOPLEFT", btn, "TOPLEFT", l, 0)
        region:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -r, 0)
    else
        region:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -l)
        region:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, r)
    end
end
local function BarButtonInit(w, h, display, single, rec)
    local v = display.visual or {}
    local b = ns.BarCueSettings(v)
    local src = ns.BarCueSource(display)
    local tx, cn, nm = v.text or {}, v.count or {}, b.name or {}
    local font = STANDARD_TEXT_FONT
    local orient, rev = ns.BarOrient(b)
    local iconS, l, r = ns.BarGeometry(b, w, h)
    local texPath = ns.BarTexturePath(b)
    local cr, cg, cb, ca, why = ns.BarCueColor(display, nil)
    local map = (why == "fallback") and ns.BarDispelColorMap and ns.BarDispelColorMap(display) or nil
    local maxApps = (src == "stacks") and ns.BarCueMax(display) or nil
    return function(btn)
        btn:SetSize(w, h)
        if single then btn:SetAlpha(tonumber(v.alpha) or 1) end
        if single and rec then rec.btns = rec.btns or {}; rec.btns[#rec.btns + 1] = btn; rec.modSig = nil end
        if v.bg and v.bg.enabled then
            local c = v.bg.color or { 0, 0, 0, 0.2 }
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(btn)
            bg:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.2)
        end
        if v.border and v.border.enabled and (tonumber(v.border.size) or 0) > 0 then
            local s, c = tonumber(v.border.size) or 1, v.border.color or { 0, 0, 0, 1 }
            for i = 1, 4 do
                local e = btn:CreateTexture(nil, "OVERLAY")
                e:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
                if i == 1 then e:SetPoint("TOPLEFT"); e:SetPoint("TOPRIGHT"); e:SetHeight(s)
                elseif i == 2 then e:SetPoint("BOTTOMLEFT"); e:SetPoint("BOTTOMRIGHT"); e:SetHeight(s)
                elseif i == 3 then e:SetPoint("TOPLEFT"); e:SetPoint("BOTTOMLEFT"); e:SetWidth(s)
                else e:SetPoint("TOPRIGHT"); e:SetPoint("BOTTOMRIGHT"); e:SetWidth(s) end
            end
        end
        if iconS > 0 then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(iconS, iconS)
            local pt
            if orient == "HORIZONTAL" then pt = (b.icon == "left") and "LEFT" or "RIGHT" else pt = (b.icon == "left") and "TOP" or "BOTTOM" end
            icon:SetPoint(pt, btn, pt, 0, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            btn:SetIcon(icon)   -- the game paints the aura's own icon
        end
        local bar = CreateFrame("StatusBar", nil, btn)
        BarEdge(bar, btn, l, r, orient)
        bar:SetStatusBarTexture(texPath)
        bar:SetOrientation(orient)
        bar:SetReverseFill(rev and true or false)
        bar:SetStatusBarColor(cr, cg, cb, ca)
        if src == "stacks" and maxApps then
            btn:SetApplicationBar(bar, { maxApplications = maxApps })
        else
            btn:SetDurationBar(bar, { direction = TimerDirection(b.reverse) })
        end
        if map then
            local E = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
            local okD = pcall(btn.AddDispelTypeTexture, btn, bar:GetStatusBarTexture(),
                { showAlways = true, style = E and E.PreserveAsset or 3, customDispelColorMap = map })
            if rec then rec.barDispel = okD and "game" or "failed" end
        elseif rec then rec.barDispel = why end
        if b.spark and b.spark.enabled then
            local sp = bar:CreateTexture(nil, "OVERLAY")
            sp:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
            sp:SetBlendMode("ADD")
            local sw = math.max(1, tonumber(b.spark.w) or 12)
            if orient == "HORIZONTAL" then sp:SetSize(sw, h * 2.2) else sp:SetSize(w * 2.2, sw); pcall(sp.SetRotation, sp, math.rad(90)) end
            local c = b.spark.color or { 1, 1, 1, 0.9 }
            sp:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
            pcall(sp.SetPoint, sp, "CENTER", bar:GetStatusBarTexture(), ns.BarSparkPoint(b), 0, 0)
        end
        if nm.enabled then
            local fs = bar:CreateFontString(nil, "OVERLAY")
            Style(fs, bar, nm, "LEFT", font)
            btn:SetSpellName(fs)   -- the game writes the aura's name (in a group: whichever aura the button shows)
        end
        if tx.enabled then
            local fs = btn:CreateFontString(nil, "OVERLAY")
            Style(fs, btn, tx, "RIGHT", font)
            local fmt = ns.TimeFormatter and ns.TimeFormatter(tx.decimals, tx.decimalBelow)
            local okF = fmt and pcall(btn.SetDurationText, btn, fs, { textFormatter = fmt })
            if not okF then
                if rec then rec.fmtFallback = true end
                btn:SetDurationText(fs, {})
            end
        end
        if cn.enabled and not (ns.Val and ns.Val(cn.source) == "charges") then
            local fs = btn:CreateFontString(nil, "OVERLAY")
            Style(fs, btn, cn, "CENTER", font)
            btn:SetApplicationCount(fs, {})
        end
    end
end

local function ButtonInit(w, h, display, single, rec)
    if display and display.visual and display.visual.kind == "bar" and ns.BarCueSettings then return BarButtonInit(w, h, display, single, rec) end
    local v = (display and display.visual) or {}
    local zoom = 0.08 + (tonumber(v.zoom) or 0)
    local tx, cn = v.text or {}, v.count or {}
    local font = STANDARD_TEXT_FONT
    local paint = single and ns.PaintDisplayArt
    return function(btn)
        -- runs inside Blizzard's frame creation; a failure here is caught by the caller
        btn:SetSize(w, h)
        if single then btn:SetAlpha(tonumber(v.alpha) or 1) end
        if single and rec then rec.btns = rec.btns or {}; rec.btns[#rec.btns + 1] = btn; rec.modSig = nil end   -- (a new button: draw the current condition changes on it too)
        if single and v.bg and v.bg.enabled then
            local c = v.bg.color or { 0, 0, 0, 0.5 }
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(btn)
            bg:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.5)
        end
        if UsesBar(display, single) then
            local bar = CreateFrame("StatusBar", nil, btn)
            FitArt(bar, btn, v, single)
            bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            local art = bar:GetStatusBarTexture()
            if paint then paint(art, display) else btn:SetIcon(art) end
            if paint and rec then rec.arts = rec.arts or {}; rec.arts[#rec.arts + 1] = art end
            local d = BAR_DIR[v.fill.dir or "bottom"] or BAR_DIR.bottom
            bar:SetOrientation(d[1])
            bar:SetReverseFill(d[2])
            btn:SetDurationBar(bar, { direction = TimerDirection(v.fill.reverse) })
        elseif paint then
            local art = btn:CreateTexture(nil, "ARTWORK")
            FitArt(art, btn, v, single)
            paint(art, display)
            if rec then rec.arts = rec.arts or {}; rec.arts[#rec.arts + 1] = art end
        else
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(btn)
            icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
            btn:SetIcon(icon)
        end
        local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        cd:SetAllPoints(btn)
        cd:SetDrawSwipe(false); cd:SetDrawEdge(false); cd:SetHideCountdownNumbers(true)
        btn:SetDurationCooldown(cd)
        -- texts: shown exactly when XayaUI shows them (switched on), styled by XayaUI's own text routine (font, size, outline,
        -- colour, inner / outer place), and the time in XayaUI's own format when the game accepts it (Visual.lua TimeFormatter)
        if tx.enabled then
            local fs = btn:CreateFontString(nil, "OVERLAY")
            Style(fs, btn, tx, "CENTER", font)
            local fmt = ns.TimeFormatter and ns.TimeFormatter(tx.decimals, tx.decimalBelow)
            local okF = fmt and pcall(btn.SetDurationText, btn, fs, { textFormatter = fmt })
            if not okF then
                if rec then rec.fmtFallback = true end   -- said by /xuiengine for this slot
                btn:SetDurationText(fs, {})
            end
        end
        -- aura stacks only: a count set to show spell CHARGES is drawn by XayaUI's companion text (the container counts stacks)
        if cn.enabled and not (ns.Val and ns.Val(cn.source) == "charges") then
            local fs = btn:CreateFontString(nil, "OVERLAY")
            Style(fs, btn, cn, "BOTTOMRIGHT", font)
            btn:SetApplicationCount(fs, {})
        end
    end
end

-- Sort of a dynamic group (Group tab, "Sort"; Xaya 2026-11-04: Default, Expiration, Name, Important, Manual).
--   manual      the group's own member numbers: one aura group per member, numbered in rule order (layoutIndex). Blizzard's flow
--               lays groups out by that number and skips empty ones ("Empty groups do not contribute spacing or force a new line",
--               AnchorUtil.lua), so an aura that appears takes its place between the ones already up, in combat, with no gap.
--   default / expiration / name / important   Blizzard's own comparators on one aura group (AuraContainerSortMethod Default,
--               Expiration, Name, ImportantOnly; Blizzard_AuraContainerUtil.lua AuraContainerSortComparators).
-- Reverse = AuraContainerSortDirection.Reverse for Blizzard's sorts, highest number first for manual.
-- Older saves: cSort nil / "none" = manual (rule order); "asc" = name; "desc" = name, reversed.
local SORT_METHOD = { default = "Default", expiration = "Expiration", name = "Name", important = "ImportantOnly" }
local function SortOf(fo)   -- the shared definition lives in Visual.lua (ns.GroupSortOf), so XayaUI's own layout and the engine agree
    if ns.GroupSortOf then return ns.GroupSortOf(fo) end
    -- the same mapping, in case this file ever loads without Visual.lua (a setting must never be ignored silently)
    local s, rev = fo and fo.cSort, (fo and fo.cSortRev) and true or false
    if s == "asc" then s = "name" elseif s == "desc" then s = "name"; rev = not rev end
    if not SORT_METHOD[s] then s = "manual" end
    return s, rev
end
local function SortArgs(sortKey, rev)
    local m = AuraContainerSortMethod[SORT_METHOD[sortKey] or "Default"] or AuraContainerSortMethod.Default
    local d = rev and AuraContainerSortDirection.Reverse or AuraContainerSortDirection.Normal
    return m, d
end

-- Create a container. The template is an AuraContainer widget: created as a plain "Frame" its built-in OnLoad never runs and
-- Blizzard's own OnLoad errors with "attempt to index field 'dirtyFlags'" (seen in game, engine 0.3.0).
local containerN = 0
local function BareContainer(unit)
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer") end
    containerN = containerN + 1
    local c = CreateFrame("AuraContainer", "XayaUIEngine" .. containerN, UIParent, "CustomAuraContainerTemplate")
    c:SetUnit(unit)
    c:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
    return c
end
local function NewContainer(unit, filter, ids, w, h, sp, display, maxCount, single, rec, sortKey, rev)
    local c = BareContainer(unit)
    local method, dir = SortArgs(sortKey or "default", rev)
    c:AddAuraGroup("main", filter, {
        candidateFilters = { includeSpellIDs = ids },
        sortMethod = method,
        sortDirection = dir,
        maxFrameCount = maxCount,
        layout = { elementSpacing = sp, lineSpacing = sp, elementWidth = w, elementHeight = h },
        initializeFrame = ButtonInit(w, h, display, single, rec),
    })
    return c
end
-- A dynamic group's container keeps its aura groups for the whole session (Blizzard: groups are add-only, there is no remove;
-- a group is switched off with SetAuraGroupEnabled). Each group is made for one MEMBER and one look (Blizzard bakes the button look
-- in when the group is made, initializeFrame), keyed by the rule's uid + its look, so:
--   reorder (drag / arrows)  only the groups' numbers change (SetAuraGroupLayout layoutIndex); nothing is created
--   a member's look changes  that member gets a new group; its old one is switched off
--   Blizzard sort            one shared group (keyed by member 1's look) is used and the member groups are switched off
-- A hidden container does not listen to aura events (Blizzard_AuraContainer.lua: ShouldRegisterForDynamicEvents = IsVisible() and
-- IsEnabled()), but its buttons stay in memory, so the container itself is never replaced while the group exists.
local function EnsureGroup(g, key, kind, w, h, sp, display, rec, sortKey, rev)
    g.keyOf = g.keyOf or {}
    local name = g.keyOf[key]
    if name then return name, false end
    g.nKeys = (g.nKeys or 0) + 1
    name = (kind == "main" and "s" or "g") .. g.nKeys
    local method, dir = SortArgs(sortKey or "default", rev)
    g.frame:AddAuraGroup(name, "HELPFUL", {
        candidateFilters = { includeSpellIDs = {} },   -- an empty set shows nothing (Blizzard_AuraContainerUtil.lua); filled below
        sortMethod = method,
        sortDirection = dir,
        maxFrameCount = (kind == "main") and math.huge or 1,
        layout = { elementSpacing = sp, lineSpacing = sp, groupSpacing = 0, groupLineSpacing = sp, elementWidth = w, elementHeight = h },
        initializeFrame = ButtonInit(w, h, display, false, rec),
    })
    g.keyOf[key] = name
    g.made = g.made or {}
    g.made[#g.made + 1] = name
    return name, true
end

-- Where XayaUI puts a dynamic group's first icon (fallback when XayaUI is too old to say), in icon sizes.
local FIRST_ICON = { RIGHT = { 0, -.5 }, LEFT = { 0, -.5 }, DOWN = { .5, 0 }, UP = { .5, 0 } }
-- The strata XayaUI gives the group's displays: the nearest group (this one, then its parents) that sets one, else HIGH.
local function StrataFor(fo)
    local f, n = fo, 0
    while f and n < 32 do
        if f.cStrata then return f.cStrata end
        f, n = FolderById(f.parent), n + 1
    end
    return "HIGH"
end

-- Place a group container so its first icon lands exactly where XayaUI would draw the group's first icon. It hangs from
-- XayaUI's own frame for the group, so the group's position, its parent groups, scale, opacity and moves all carry over.
local function PlaceGroup(c, fo, anchor, iw, ih, pin, pinTo)
    if pin then   -- block growth: the self-sizing container hangs from XayaUI's group frame by its pin point
        pinTo = pinTo or pin
        local host = ns.GroupFrame and ns.GroupFrame(fo)
        if host then
            if c:GetParent() ~= host then c:SetParent(host) end
            c:SetScale(1); c:SetAlpha(1)
            c:SetFrameStrata(StrataFor(fo))
            c:ClearAllPoints()
            c:SetPoint(pin, host, pinTo, 0, 0)
            return
        end
        -- fallback: the group frame's pinTo point from the group's own settings (same numbers as Visual.lua Container)
        local sc = math.max(0.1, fo.cScale or 1)
        local target = UIParent
        local gname = (fo.cRel == "custom") and fo.cFrame or REL_FRAMES[fo.cRel]
        local g = gname and gname ~= "" and _G[gname]
        if g and g.GetCenter then target = g end
        local pt = fo.cPoint or "CENTER"
        local tc = TO_CENTER[pt] or TO_CENTER.CENTER
        local W, H = math.max(1, fo.cW or 1), math.max(1, fo.cH or 1)
        local pc = TO_CENTER[pinTo] or TO_CENTER.CENTER
        local cx = (fo.cX or 0) / sc + tc[1] * W - pc[1] * W
        local cy = (fo.cY or 0) / sc + tc[2] * H - pc[2] * H
        c:SetScale(sc); c:SetAlpha(fo.cAlpha or 1); c:SetFrameStrata(StrataFor(fo))
        c:ClearAllPoints()
        c:SetPoint(pin, target, fo.cRelPoint or pt, cx, cy)
        return
    end
    local fx, fy
    if ns.DynamicFirstOffset then fx, fy = ns.DynamicFirstOffset(fo, iw, ih) end
    if not fx then local f = FIRST_ICON[fo.cGrowth or "RIGHT"] or { 0, 0 }; fx, fy = f[1] * iw, f[2] * ih end
    local ac = TO_CENTER[anchor] or TO_CENTER.CENTER   -- container corner `anchor` -> first icon centre, in icon sizes
    local ox, oy = fx - ac[1] * iw, fy - ac[2] * ih
    local host = ns.GroupFrame and ns.GroupFrame(fo)
    if host then
        if c:GetParent() ~= host then c:SetParent(host) end
        c:SetScale(1); c:SetAlpha(1)
        c:SetFrameStrata(StrataFor(fo))
        c:ClearAllPoints()
        c:SetPoint(anchor, host, "CENTER", ox, oy)
        return
    end
    -- fallback (XayaUI too old to share its group frame): the same position from the group's own settings
    -- (Visual.lua Container: the group frame is cW x cH in its own scaled units and its point sits cX / scale units from the target)
    local sc = math.max(0.1, fo.cScale or 1)
    local target = UIParent
    local gname = (fo.cRel == "custom") and fo.cFrame or REL_FRAMES[fo.cRel]
    local g = gname and gname ~= "" and _G[gname]
    if g and g.GetCenter then target = g end
    local pt = fo.cPoint or "CENTER"
    local tc = TO_CENTER[pt] or TO_CENTER.CENTER
    local cx = (fo.cX or 0) / sc + tc[1] * math.max(1, fo.cW or 1)
    local cy = (fo.cY or 0) / sc + tc[2] * math.max(1, fo.cH or 1)
    c:SetScale(sc); c:SetAlpha(fo.cAlpha or 1); c:SetFrameStrata(StrataFor(fo))
    c:ClearAllPoints()
    c:SetPoint(anchor, target, fo.cRelPoint or pt, cx + ox, cy + oy)
end

-- Place a single slot exactly on XayaUI's own icon for the display: same parent (so the same group scale and opacity), anchored
-- to that icon (which stays in place, hidden, while the engine draws), same strata.
local function PlaceSingle(c, host, w, h)
    local parent = host:GetParent() or UIParent
    if c:GetParent() ~= parent then c:SetParent(parent) end
    c:SetScale(1); c:SetAlpha(1)
    c:SetFrameStrata(host:GetFrameStrata() or "HIGH")
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", host, "CENTER", -w / 2, h / 2)
end

-------------------------------------------------------------------------------
-- Unlock: while visuals, a group or a display are unlocked, XayaUI shows its own draggable samples; the engine steps aside.
-------------------------------------------------------------------------------
local function FolderUnlocked(folderId)
    if ns.unlocked then return true end
    local gu = ns.groupUnlocked
    if not gu or not next(gu) then return false end
    local id, n = folderId, 0
    while id and n < 32 do
        if gu[id] then return true end
        local f = FolderById(id)
        if not f then return false end
        id, n = f.parent, n + 1
    end
    return false
end
local function RuleUnlocked(display)
    return ns.unlocked or (ns.moveUnlocked and ns.moveUnlocked[display]) or FolderUnlocked(display.folder) or false
end

-------------------------------------------------------------------------------
-- Build
-------------------------------------------------------------------------------
local function Fail(slot, why)
    slot.ok, slot.err = false, tostring(why)
    lastError = slot.err
    -- (core 0.6.56; REQUEST-LOG #82) a guarded game call failed: recorded with its code, only when it happens (DebugRecord.lua)
    if ns.RecordWarn then pcall(ns.RecordWarn, "XUI-W002", slot.err) end
    if slot.frame then slot.frame:Hide() end
end

local function ColorKey(c)
    if type(c) ~= "table" then return "-" end
    return tostring(c[1]) .. "," .. tostring(c[2]) .. "," .. tostring(c[3]) .. "," .. tostring(c[4])
end
-- A Bar cue's own settings and the bar colour style (BarCue.lua): baked into the buttons too
local function TextKey(t)
    t = t or {}
    return table.concat({ tostring(t.enabled), tostring(t.size), tostring(t.anchor), tostring(t.x), tostring(t.y), tostring(t.font),
        tostring(t.outline), tostring(t.place), ColorKey(t.color) }, ",")
end
local function BarLookKey(display)
    local v = display.visual or {}
    if v.kind ~= "bar" or not ns.BarCueSettings then return "" end
    local b = ns.BarCueSettings(v)
    local sp, bo = b.spark or {}, v.border or {}
    local r, g, bl, a, why = ns.BarCueColor(display, nil)
    return "|bar|" .. table.concat({ tostring(ns.BarCueSource(display)), tostring(b.max), tostring(b.dir), tostring(b.reverse), tostring(b.texture),
        tostring(b.texFile), tostring(b.colorMode), ColorKey(b.color), tostring(b.icon), tostring(sp.enabled), tostring(sp.w), ColorKey(sp.color),
        TextKey(b.name), tostring(bo.enabled), tostring(bo.size), ColorKey(bo.color), tostring(why), ColorKey({ r, g, bl, a }),
        ns.BarStyleSig and ns.BarStyleSig(display) or "",
        tostring(ns.BarCueMax and ns.BarCueMax(display) or "") }, "|")
end
-- Everything about a display's look that is baked into its slot's buttons (an edit to any of it makes a new slot)
local function LookKey(display)
    local v = display.visual or {}
    local f, bg, t, c, tn = v.fill or {}, v.bg or {}, v.text or {}, v.count or {}, v.tint or {}
    local bc = bg.color or {}
    return table.concat({ tostring(v.kind), tostring(v.tex), tostring(v.zoom), tostring(v.rotation), tostring(v.flipH), tostring(v.flipV),
        tostring(v.alpha), tostring(v.desaturate), tostring(tn[1]), tostring(tn[2]), tostring(tn[3]), tostring(tn[4]),
        tostring(f.enabled), tostring(f.dir), tostring(f.reverse), tostring(bg.enabled), tostring(bc[1]), tostring(bc[2]), tostring(bc[3]), tostring(bc[4]),
        tostring(t.enabled), tostring(t.size), tostring(t.anchor), tostring(t.x), tostring(t.y),
        tostring(t.font), tostring(t.outline), tostring(t.place), tostring(t.decimals), tostring(t.decimalBelow), ColorKey(t.color),
        tostring(c.enabled), tostring(c.size), tostring(c.anchor), tostring(c.x), tostring(c.y),
        tostring(c.font), tostring(c.outline), tostring(c.place), tostring(c.source), ColorKey(c.color),
        tostring(display.spellID), tostring(display.buffID), tostring(v.iconSrc), tostring(v.iconPath), tostring(v.iconSpell), tostring(v.iconItem), tostring(v.iconW), tostring(v.iconH), tostring(v.keepAspect) }, "|")
        .. BarLookKey(display)
end

local function BuildGroup(fo, members)
    local g = groups[fo.id] or {}
    groups[fo.id] = g
    g.members, g.ids, g.n, g.serial, g.allowed = members, {}, #members, serial, {}
    local dir = fo.cGrowth or "RIGHT"
    local axis, anchor, hdir, vdir, pin, pinTo = FlowFor(dir, fo.cWrapRev and true or false, fo)
    if not axis then
        Fail(g, "growth " .. tostring(dir) .. " not supported")
        return g
    end
    for _, m in ipairs(members) do for id in pairs(m.spec.ids) do g.ids[id] = true end end
    local display = members[1].spec.display
    local iw, ih = DisplaySize(display.visual)
    local sp = tonumber(fo.cSpacing) or 4
    local limit = WrapLimit(fo, axis == AnchorUtil.FlowLayoutAxis.Horizontal, iw, ih, sp)
    local sortKey, rev = SortOf(fo)
    local ok, err = pcall(function()
        if not g.frame then
            g.fmtFallback = nil
            g.frame = BareContainer("player")
            g.keyOf, g.made, g.nKeys = {}, {}, 0
        end
        local c = g.frame
        local active = {}
        g.memberKey, g.mainKey, g.mode = {}, nil, sortKey
        if sortKey == "manual" then
            local n = #members
            for i, m in ipairs(members) do
                local w, h = DisplaySize(m.spec.display.visual)
                local id = tostring(m.rule.uid or m.rule.name or i)
                local name = EnsureGroup(g, id .. "\n" .. LookKey(m.spec.display) .. "#" .. w .. "x" .. h, "member", w, h, sp, m.spec.display, g)
                c:SetAuraGroupCandidateFilters(name, { includeSpellIDs = m.spec.ids })
                -- groupSpacing 0: Blizzard's flow already adds elementSpacing after every icon, and adds groupSpacing on top of it
                -- before the next group on the same line (AnchorUtil.ApplyFlowLayout), so sp here would put 2 x sp between members
                -- (the 0.6.6 build did; fixed in 0.6.7)
                c:SetAuraGroupLayout(name, { elementSpacing = sp, lineSpacing = sp, groupSpacing = 0, groupLineSpacing = sp,
                    elementWidth = w, elementHeight = h, layoutIndex = rev and (n - i + 1) or i })
                g.memberKey[i] = name
                active[name] = true
            end
        else
            local name = EnsureGroup(g, "\nmain\n" .. LookKey(display) .. "#" .. iw .. "x" .. ih, "main", iw, ih, sp, display, g, sortKey, rev)
            c:SetAuraGroupSortMethod(name, SortArgs(sortKey, rev))
            c:SetAuraGroupCandidateFilters(name, { includeSpellIDs = g.ids })
            c:SetAuraGroupLayout(name, { elementSpacing = sp, lineSpacing = sp, elementWidth = iw, elementHeight = ih, layoutIndex = 1 })
            g.mainKey = name
            active[name] = true
        end
        -- every group not used now is switched off; the used ones start on (load / talent answers follow in D.SyncLive)
        for _, name in ipairs(g.made) do c:SetAuraGroupEnabled(name, active[name] == true) end
        c:SetFlowLayoutAxis(axis)
        c:SetFlowLayoutAnchorPoint(anchor)
        c:SetFlowLayoutGrowthDirection(hdir, vdir)
        c:SetFlowLayoutMaximumLineSize(limit)
        PlaceGroup(c, fo, anchor, iw, ih, pin, pinTo)
        c:SetShown(not FolderUnlocked(fo.id))
    end)
    g.dirty = true   -- the live filter (load) is set by D.SyncLive
    if ok then g.ok, g.err = true, nil else Fail(g, err) end
    return g
end

local function BuildSingle(p, spec, store, key)
    store, key = store or singles, key or p
    local s = store[key] or {}
    store[key] = s
    s.spec, s.ok, s.serial, s.single, s.parent = spec, false, serial, true, p
    local display = spec.display
    local host = ns.DisplayFrame and ns.DisplayFrame(display)
    if not host then Fail(s, "XayaUI has no frame for this display") return s end
    s.host = host
    local w, h = DisplaySize(display.visual)
    local ok, err = pcall(function()
        -- a container's unit and filter are fixed at creation: a slot whose aura kind changed gets a new container
        -- unit, filter and the button's look are fixed when a container is made: a changed one gets a new container
        local look = LookKey(display)
        if s.frame and (s.unit ~= spec.unit or s.filter ~= spec.filter or s.w ~= w or s.h ~= h or s.look ~= look) then s.frame:Hide(); s.frame = nil end
        if not s.frame then
            s.fmtFallback = nil
            s.arts, s.btns, s.modSig = {}, {}, nil   -- (the old container's buttons are gone)
            s.frame = NewContainer(spec.unit, spec.filter, spec.ids, w, h, 0, display, 1, true, s)
            s.unit, s.filter, s.w, s.h, s.look = spec.unit, spec.filter, w, h, look
        else
            s.frame:SetAuraGroupCandidateFilters("main", { includeSpellIDs = spec.ids })
        end
        local c = s.frame
        local A, F = AnchorUtil.FlowLayoutAxis, AnchorUtil.FlowDirection
        c:SetFlowLayoutAxis(A.Horizontal)
        c:SetFlowLayoutAnchorPoint("TOPLEFT")
        c:SetFlowLayoutGrowthDirection(F.Right, F.Down)
        c:SetFlowLayoutMaximumLineSize(math.huge)
        PlaceSingle(c, host, w, h)
    end)
    if ok then s.ok, s.err = true, nil else Fail(s, err) end
    return s
end

-- A rule's OTHER display cues that show time or stacks (a separate Text cue with the duration, a second icon with a drain) get a slot
-- of their own, so they are exact in combat too (#347). Only when nothing but the rule's trigger decides them: a cue that a
-- condition lists is switched by that condition, which the container cannot follow, so it stays with XayaUI (its duration estimate).
-- A cue no condition lists follows the trigger (Cues.lua ns.CueGated, 0.6.14), so it gets a slot.
local function ExtraDisplays(p, spec)
    local out = {}
    for _, c in ipairs(ns.CuesOf and ns.CuesOf(p) or {}) do
        local gated = ns.CueGated(p, c)
        if c ~= spec.display and IsDisplay(c) and not gated then
            local v = c.visual
            if (v.text and v.text.enabled) or (v.fill and v.fill.enabled) or (v.count and v.count.enabled and not (ns.Val and ns.Val(v.count.source) == "charges")) then
                out[#out + 1] = c
            end
        end
    end
    return out
end

local function RefreshCore()
    if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end
end

-- (Re)build everything. Safe to call any time; waits for the end of combat when in combat lockdown.
function D.Build()
    local db = DB()
    if not db then return end
    if InCombatLockdown and InCombatLockdown() then pendingBuild = true; return end
    pendingBuild = nil
    serial = serial + 1
    if ns.SyncCueFolders then pcall(ns.SyncCueFolders) end   -- group membership = the parent rule's group (Cues.lua)
    for k in pairs(owned) do owned[k] = nil end
    left = {}
    local spec = guard.lean and CurrentSpecID() or nil
    local byGroup, wantSingle = {}, {}
    if db.auto ~= false and not guard.off then
        for _, p in ipairs(ns.rules or {}) do
            local s, why = Classify(p)
            if not s then
                if why ~= "" then left[#left + 1] = { p, why } end
            elseif KeptWithXayaUI(s.display.folder) then
                left[#left + 1] = { p, "its group is kept with XayaUI (/xuiengine reset <group> to undo)" }
            elseif guard.lean and not LoadsForSpec(p, spec) then
                left[#left + 1] = { p, LEAN_REASON }
            else
                local gid = DynGroupId(s.display.folder)   -- (XayaUI lays a display out by ITS OWN group)
                local fo = FolderById(gid)
                if fo then
                    if s.kind ~= "buff" then
                        left[#left + 1] = { p, "a target debuff inside a dynamic group (the group's container shows your buffs only)" }
                    else
                        local l = byGroup[gid]
                        if not l then l = {}; byGroup[gid] = l end
                        l[#l + 1] = { rule = p, spec = s }
                    end
                else
                    wantSingle[p] = s
                end
            end
        end
    end
    for _, fo in ipairs(ns.folders or {}) do
        local members = byGroup[fo.id]
        if members then
            local g = BuildGroup(fo, members)
            for _, m in ipairs(members) do
                Own(g, m.rule)
                if not g.ok then left[#left + 1] = { m.rule, "its group failed: " .. tostring(g.err) } end
            end
        elseif groups[fo.id] then
            local g = groups[fo.id]
            g.ok = false
            if g.frame then g.frame:Hide() end
        end
    end
    for p, s in pairs(singles) do
        if not wantSingle[p] then s.ok = false; if s.frame then s.frame:Hide() end end
    end
    local wantExtra = {}
    for p, spec in pairs(wantSingle) do
        local s = BuildSingle(p, spec)
        Own(s, p, true)
        if not s.ok then
            left[#left + 1] = { p, "failed: " .. tostring(s.err) }
        else
            -- the rule's other time / stack displays: one slot each, same aura, sized and placed like that display
            for _, c in ipairs(ExtraDisplays(p, spec)) do
                local es = { kind = spec.kind, unit = spec.unit, filter = spec.filter, ids = spec.ids, display = c, trigger = c.visual.trigger }
                local x = BuildSingle(p, es, extras, c)
                wantExtra[c] = true
                if x.ok then owned[c] = x else left[#left + 1] = { c, "failed: " .. tostring(x.err) } end
            end
        end
    end
    for c, x in pairs(extras) do
        if not wantExtra[c] then x.ok = false; if x.frame then x.frame:Hide() end end
    end
    D.SyncLive()
    RefreshCore()
end

-------------------------------------------------------------------------------
-- Live sync (4 times a second): load / talent answers and unlock state. Cheap: no allocation unless something changed.
-------------------------------------------------------------------------------
local STORES = { singles, extras }
-- #260: the changes a true condition makes to a cue (opacity, desaturate, tint; Cues.lua EvaluateCue info.mods), drawn on a single
-- slot's own art and buttons, the same way XayaUI draws them on its own frame (Visual.lua). When they change, the art is first
-- painted again from the display's own settings, so nothing is left from a condition that is no longer true. Glow and strata are not
-- drawn on engine slots (/xuiengine says so); inside a dynamic group the members' icons are the game's, so changes are not drawn there.
local function ModsOf(display)
    local crt = ns.runtime and ns.runtime[display]
    return crt and crt.info and crt.info.mods
end
local function ApplyMods(s, display)
    local mods = ModsOf(display)
    local sig = ""
    if mods then
        local t = mods.tint
        sig = tostring(mods.desat) .. "|" .. tostring(mods.alpha) .. "|" .. (type(t) == "table" and table.concat({ t[1] or 1, t[2] or 1, t[3] or 1, t[4] or 1 }, ",") or "-")
    end
    if s.modSig == sig then return end
    s.modSig = sig
    local v = (display and display.visual) or {}
    for _, art in ipairs(s.arts or {}) do
        if ns.PaintDisplayArt then pcall(ns.PaintDisplayArt, art, display) end   -- the display's own look first
        if mods then
            if mods.desat ~= nil then pcall(art.SetDesaturation, art, mods.desat and 1 or 0) end
            if type(mods.tint) == "table" then
                local t = mods.tint
                pcall(art.SetVertexColor, art, t[1] or 1, t[2] or 1, t[3] or 1, t[4] or 1)
            end
        end
    end
    local alpha = (mods and mods.alpha ~= nil) and tonumber(mods.alpha) or (tonumber(v.alpha) or 1)
    for _, b in ipairs(s.btns or {}) do pcall(b.SetAlpha, b, alpha) end
end
D._ApplyMods = ApplyMods

function D.SyncLive()
    for _, store in ipairs(STORES) do
        for _, s in pairs(store) do
            if s.ok and s.frame then
                local show = Allowed(s.parent, s.spec.display, s.spec.trigger) and not RuleUnlocked(s.spec.display)
                if s.frame:IsShown() ~= show then pcall(s.frame.SetShown, s.frame, show) end
                if show and s.spec.display and s.spec.display.isCue then pcall(ApplyMods, s, s.spec.display) end
            end
        end
    end
    for fid, g in pairs(groups) do
        if g.ok and g.frame then
            -- the group's filter holds the members that may show now; it is rewritten only when one of them changes
            local changed = g.dirty
            for i, m in ipairs(g.members) do
                local a = Allowed(m.rule, m.spec.display, m.spec.trigger)
                if g.allowed[i] ~= a then g.allowed[i] = a; changed = true end
            end
            if changed then
                if g.mode == "manual" then
                    -- one aura group per member: switch the member's own group on or off (an empty ID set would also show
                    -- nothing, Blizzard_AuraContainerUtil.lua: includeSpellIDs rejects every aura not in it)
                    local okAll = true
                    for i in ipairs(g.members) do
                        local key = g.memberKey and g.memberKey[i]
                        if key and not pcall(g.frame.SetAuraGroupEnabled, g.frame, key, g.allowed[i] and true or false) then okAll = false end
                    end
                    if okAll then g.dirty = false end
                elseif g.mainKey then
                    local ids = {}
                    for i, m in ipairs(g.members) do
                        if g.allowed[i] then for id in pairs(m.spec.ids) do ids[id] = true end end
                    end
                    if pcall(g.frame.SetAuraGroupCandidateFilters, g.frame, g.mainKey, { includeSpellIDs = ids }) then g.dirty = false end
                end
            end
            local show = not FolderUnlocked(fid)
            if g.frame:IsShown() ~= show then pcall(g.frame.SetShown, g.frame, show) end
        end
    end
end
D.SyncShown = D.SyncLive   -- (older name, used by the unlock hooks)

-------------------------------------------------------------------------------
-- Status (/xuiengine): what the engine draws, what it does not and why, and every difference it cannot avoid
-------------------------------------------------------------------------------
function D.Status()
    local db = DB()
    if not db then return end
    if db.auto == false or guard.off then
        Say(guard.off and db.auto ~= false
            and ("automatic engine drawing is OFF for this session (performance guard): XayaUI draws every display itself. " .. (DevOn() and "/xuiengine auto on, or a /reload, turns it back on." or "A /reload turns it back on."))
            or ("automatic engine drawing is OFF: XayaUI draws every display itself." .. (DevOn() and " /xuiengine auto on to turn it on." or " It was switched off with XayaUI Dev Assist's /xuiengine auto off: turn it on there.")))
        if lastError then Say("last engine error: " .. lastError) end
        return
    end
    local nG, nGRules, nS, nSOk = 0, 0, 0, 0
    for _, fo in ipairs(ns.folders or {}) do
        local g = groups[fo.id]
        if g and g.members and g.serial == serial then
            nG = nG + 1; nGRules = nGRules + #g.members
            Say(string.format("%s: %s (%d buff rules)%s", fo.name or fo.id, g.ok and "ENGINE DRAWN" or "NOT drawn by engine (XayaUI draws it)",
                #g.members, g.err and (" - " .. g.err) or ""))
            if g.ok then
                local w0, h0, mixed = nil, nil, false
                for _, m in ipairs(g.members) do
                    local w, h = DisplaySize(m.spec.display.visual)
                    if w0 and (w ~= w0 or h ~= h0) then mixed = true end
                    w0, h0 = w0 or w, h0 or h
                end
                if mixed and SortOf(fo) ~= "manual" then Say("   (icons in this group have different sizes; with a game sort the engine draws them all at the first one's size; Manual sort keeps each size)") end
                if #g.members > 1 then
                    local mode, rev = SortOf(fo)
                    local SORT_TEXT = { manual = "Manual: the group's own order (rule order), each member its own size and look; an aura that appears takes its place between the others",
                        default = "Default (the game's own sort)", expiration = "Expiration (the game's own sort)", name = "Name (the game's own sort)",
                        important = "Important first (the game's own sort)" }
                    Say("   (sort: " .. SORT_TEXT[mode] .. (rev and ", reversed" or "") .. ")")
                end
                for _, m in ipairs(g.members) do
                    local d = Drops(m.rule, m.spec.display, false, g)
                    if #d > 0 then Say("   " .. tostring(m.rule.name) .. ": " .. table.concat(d, "; ")) end
                end
            end
        end
    end
    for p, s in pairs(singles) do
        if s.serial == serial then
            nS = nS + 1
            if s.ok then
                nSOk = nSOk + 1
                local d = Drops(p, s.spec.display, true, s)
                if #d > 0 then Say("   " .. tostring(p.name) .. " (on its own): " .. table.concat(d, "; ")) end
            end
        end
    end
    local nX = 0
    for c, x in pairs(extras) do
        if x.serial == serial and x.ok then
            nX = nX + 1
            local d = Drops(x.parent, c, true, x)
            if #d > 0 then Say("   " .. tostring(c.name) .. " (extra display of " .. tostring(x.parent and x.parent.name) .. "): " .. table.concat(d, "; ")) end
        end
    end
    Say(string.format("Engine draws: %d group%s (%d rules) and %d rule%s on their own%s.", nG, nG == 1 and "" or "s", nGRules, nSOk, nSOk == 1 and "" or "s",
        nX > 0 and string.format(", plus %d separate time / stack display%s of those rules", nX, nX == 1 and "" or "s") or ""))
    if #left > 0 then
        -- grouped by reason, so a long list stays readable; every display XayaUI keeps is counted
        local byWhy, order = {}, {}
        for _, e in ipairs(left) do
            local l = byWhy[e[2]]
            if not l then l = {}; byWhy[e[2]] = l; order[#order + 1] = e[2] end
            l[#l + 1] = tostring(e[1].name)
        end
        Say(string.format("XayaUI keeps %d aura display%s:", #left, #left == 1 and "" or "s"))
        for _, why in ipairs(order) do
            local l = byWhy[why]
            local shown = {}
            for i = 1, math.min(6, #l) do shown[i] = l[i] end
            Say(string.format("   %d - %s: %s%s", #l, why, table.concat(shown, ", "), #l > 6 and (", and " .. (#l - 6) .. " more") or ""))
        end
    else
        Say("XayaUI keeps no aura displays: every one is drawn by the engine.")
    end
    Say(string.format("automatic mode: %s%s%s.  Performance guard: %s", db.auto ~= false and "on" or "OFF", guard.lean and " (lean for this session: this spec only)" or "",
        guard.kept and " (kept on: the cost did not fall when lean mode handed displays back, so it is the game's own frames)" or "",
        guard.last and string.format("Blizzard's aura containers %.2f ms recent average (limit %.1f; includes Blizzard's own target-frame auras)%s", guard.last, LIMIT_MS,
            guard.own and string.format("; all of XayaUI %.2f ms", guard.own) or "") or "no reading yet (the game's addon meter may be off)"))
    if db.guardUndone then
        Say(string.format("note: %s, saved by an earlier performance-guard trip%s, was undone in 0.6.13 (trips now last one session).", db.guardUndone.what,
            db.guardUndone.trip and (" (" .. db.guardUndone.trip .. ")") or ""))
    end
    if lastError then Say("last engine error: " .. lastError) end
end

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------
local function FindFolder(q)
    q = tostring(q or ""):lower()
    if q == "" then return nil, "name a group" end
    local hit, count = nil, 0
    for _, fo in ipairs(ns.folders or {}) do
        if tostring(fo.id):lower() == q or tostring(fo.name or ""):lower() == q then return fo end
        if tostring(fo.name or ""):lower():find(q, 1, true) then hit, count = fo, count + 1 end
    end
    if count == 1 then return hit end
    return nil, (count == 0) and ("no group matches '" .. q .. "'") or (count .. " groups match '" .. q .. "'; use more of the name")
end

-- core 0.6.56 (Xaya 2026-11-06, REQUEST-LOG #81, her answer "Yes, as recommended": players keep full and refresh; auto, on, off and
-- reset move to XayaUI Dev Assist). Those four are registered by Dev Assist (ns.RegisterSubcommand("xuiengine", ...),
-- XayaUI_DevAssist/CoreDebug.lua) and reach the engine through D.DB, D.FindFolder and D._guard; without Dev Assist they do not exist.
D.DB, D.FindFolder = DB, FindFolder
local function Slash(msg)
    local cmd, rest = tostring(msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    local db = DB()
    if not db then Say("saved data not loaded yet") return end
    if cmd == "full" then   -- leave lean mode: every spec's displays again
        guard.lean, guard.leanAt, guard.leanHanded = nil, nil, nil; guard.bad = 0; D.Build(); D.Status()
    elseif cmd == "refresh" or cmd == "build" then
        D.Build(); D.Status()
    elseif cmd ~= "" and ns.RunSubcommand and ns.RunSubcommand("xuiengine", cmd, rest) then
        -- (Dev Assist's: auto on / off, on / off / reset <group>)
    else
        D.Status()
        -- (no "|r" in chat text: WoW reads it as a colour code)
        Say("/xuiengine full (leave lean mode);  /xuiengine refresh." .. (ns.SubcommandList and ns.SubcommandList("xuiengine", "/xuiengine ") or "")
            .. "  Draws every aura display through Blizzard's secure aura container so time and stacks show in combat.")
    end
end
SLASH_XUIENGINE1 = "/xuiengine"
SlashCmdList["XUIENGINE"] = Slash

-------------------------------------------------------------------------------
-- Performance guard: Blizzard's container code, from the game's own meter (see the header)
-------------------------------------------------------------------------------
local function Metric(name)
    local ok, v = pcall(C_AddOnProfiler.GetAddOnMetric, name, Enum.AddOnProfilerMetric.RecentAverageTime)
    return (ok and type(v) == "number") and v or nil
end
local function GuardCheck()
    local db = DB()
    if not (db and db.auto ~= false and not guard.off) or guard.kept then guard.bad = 0; return end
    if not (C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric and Enum and Enum.AddOnProfilerMetric) then return end
    -- The containers' work is counted under Blizzard_AuraContainer. The engine's own Lua is counted under XayaUI together with
    -- everything else XayaUI does (rules, sounds, the settings window), so that number is shown, never used to trip: handing
    -- displays back would not lower it. (Before 0.6.13 the old XayaUI_CombatEngine name was read here; since 0.6.0 that addon
    -- does not exist, so it always read nothing.)
    local blizz = Metric("Blizzard_AuraContainer")
    guard.own = Metric("XayaUI")
    if not blizz then return end
    local v = blizz
    guard.last = v
    if v > LIMIT_MS then guard.bad = guard.bad + 1 else guard.bad = 0 end
    if guard.bad < NEED then return end
    guard.bad = 0
    db.guardTrips = db.guardTrips or {}
    local step = guard.lean and "off" or "lean"
    -- 0.6.69 (externals, Xaya 2026-11-07 "XUI isn't reliably performing"): the meter counts ALL of Blizzard_AuraContainer, which also
    -- runs Blizzard's own buff frame, target frame and group headers (Blizzard's UI source: BuffFrame.lua, TargetFrame.xml,
    -- SecureGroupHeaders.lua). Switching off hands every display back to XayaUI, which cannot show a hidden aura in combat (an
    -- external defensive vanishes). So "off" needs evidence that XayaUI's containers are the cost: lean mode handed displays back AND
    -- the reading then fell by at least a fifth. Otherwise drawing stays on for the session and the reason is recorded.
    -- INFERENCE (unverified in game): that a fifth is a fair margin over the meter's own swing between readings.
    if step == "off" and not ((guard.leanHanded or 0) > 0 and guard.leanAt and v <= guard.leanAt * 0.8) then
        step = "kept"
        guard.kept = true
    end
    db.guardTrips[#db.guardTrips + 1] = { at = date("%Y-%m-%d %H:%M:%S"), ms = v, limit = LIMIT_MS, step = step, session = true }
    while #db.guardTrips > 10 do table.remove(db.guardTrips, 1) end
    if step == "kept" then
        if ns.RecordWarn then pcall(ns.RecordWarn, "XUI-W003", ("Blizzard's aura containers %.2f ms per frame; not lowered by lean mode, so not XayaUI's: drawing stays on"):format(v)) end
        Say(string.format("performance guard: Blizzard's aura containers still cost %.2f ms per frame (limit %.1f), but handing back XayaUI's other-spec displays did not lower it, so the cost is the game's own frames. The engine keeps drawing your displays (auras hidden in combat stay visible).", v, LIMIT_MS))
        return
    end
    if step == "lean" then
        guard.lean, guard.leanAt = true, v
        if ns.RecordWarn then pcall(ns.RecordWarn, "XUI-W003", ("Blizzard's aura containers %.2f ms per frame (limit %.1f)"):format(v, LIMIT_MS)) end
        Say(string.format("performance guard: Blizzard's aura containers cost %.2f ms per frame (limit %.1f; this includes Blizzard's own target-frame auras), so the engine now draws only the displays of the spec you are playing (lean mode, applied once combat ends, until /reload). /xuiengine full to undo.", v, LIMIT_MS))
    else
        guard.off = true
        if ns.RecordWarn then pcall(ns.RecordWarn, "XUI-W004", ("still %.2f ms per frame in lean mode (limit %.1f)"):format(v, LIMIT_MS)) end
        Say(string.format("performance guard: still %.2f ms per frame in lean mode, so automatic engine drawing is OFF until /reload; XayaUI draws the displays itself once combat ends." .. (DevOn() and " /xuiengine auto on to turn it back on now." or ""), v))
    end
    D.Build()
    if step == "lean" then   -- how many displays lean mode handed back (the evidence the "off" step needs)
        local n = 0
        for _, e in ipairs(left) do if e[2] == LEAN_REASON then n = n + 1 end end
        guard.leanHanded = n
    end
end
D.GuardCheck = GuardCheck

-------------------------------------------------------------------------------
-- Events and hooks
-------------------------------------------------------------------------------
-- rule / group edits arrive as ns.MarkDirty; rebuild once, a second after the last one (never in combat)
local rebuildQueued = false
local function QueueBuild()
    if rebuildQueued then return end
    rebuildQueued = true
    local function Run() rebuildQueued = false; pcall(D.Build) end
    if C_Timer and C_Timer.After then C_Timer.After(1, Run) else Run() end
end
D.QueueBuild = QueueBuild

if hooksecurefunc then
    if ns.ToggleUnlock then hooksecurefunc(ns, "ToggleUnlock", function() pcall(D.SyncLive) end) end
    if ns.SetGroupUnlocked then hooksecurefunc(ns, "SetGroupUnlocked", function() pcall(D.SyncLive) end) end
    if ns.SetMoveUnlocked then hooksecurefunc(ns, "SetMoveUnlocked", function() pcall(D.SyncLive) end) end
    if ns.MarkDirty then hooksecurefunc(ns, "MarkDirty", QueueBuild) end
end
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(0.25, function() pcall(D.SyncLive) end)
    C_Timer.NewTicker(5, function() pcall(GuardCheck) end)
end

-- Blizzard's container does not follow a new target / focus on its own: Blizzard_AuraContainer.lua says UpdateAllAuras is
-- "exposed to allow external events to trigger refreshes where needed (e.g. target changes)", and its own target frame calls it on
-- PLAYER_TARGET_CHANGED. Without this a "Target Debuff (yours)" slot kept showing the previous target's debuff.
local function RefreshUnit(unit)
    for _, store in ipairs(STORES) do
        for _, s in pairs(store) do
            if s.ok and s.frame and s.unit == unit and s.frame.UpdateAllAuras then pcall(s.frame.UpdateAllAuras, s.frame) end
        end
    end
end
D.RefreshUnit = RefreshUnit

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("TRAIT_CONFIG_UPDATED")   -- a talent change can change which displays load (gap 9); talents cannot change in combat
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then RefreshUnit("target"); return end
    if event == "PLAYER_FOCUS_CHANGED" then RefreshUnit("focus"); return end
    if event == "PLAYER_REGEN_ENABLED" and not pendingBuild then return end
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
    pcall(D.Build)
end)

-- for tests
D._groups, D._singles, D._owned, D._extras, D._guard = groups, singles, owned, extras, guard
function D._Left() return left end
-- Does the game's aura container draw this rule's display? true + where, false + the reason it stays with XayaUI, nil = not an aura
-- display. Status screens only (Conditions.lua ns.HiddenAuraNote): a linear look through the last build's lists.
function D.OwnerOf(rule)
    if type(rule) ~= "table" then return nil end
    local p = ParentOf(rule) or rule
    local slot = owned[p]
    if slot and slot.ok ~= false then
        return true, slot.single and "its own slot on XayaUI's icon" or "its dynamic group's container"
    end
    for _, e in ipairs(left) do if e[1] == p then return false, e[2] end end
    local db = DB()
    if db and db.auto == false then return false, "automatic engine drawing is off (/xuiengine auto on)" end
    if guard.off then return false, "automatic engine drawing is off for this session (performance guard)" end
    return nil
end
