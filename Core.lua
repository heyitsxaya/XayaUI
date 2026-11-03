-------------------------------------------------------------------------------
-- Core.lua : namespace, saved variables, rule defaults, slash commands.
-------------------------------------------------------------------------------
local addonName, ns = ...

ns.name = addonName; XayaUI_NS = ns -- deliberate global: the sibling addon XayaUI_CombatEngine shares this namespace (interim bridge; to be narrowed to XayaUI_API)
ns.rules = nil -- set at ADDON_LOADED to CueRulesDB.rules

-- "Not chosen / none" helpers. Dropdowns start blank (nil) so a choice is forced;
-- "none" (or legacy "any") is an explicit "ignore this".
function ns.Ignored(s) return s == nil or s == "" or s == "none" or s == "any" end
function ns.Val(v) if v == nil or v == "" or v == "none" then return nil end return v end

function ns.Print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    print("|cff33ccffXayaUI|r: " .. table.concat(parts, " "))
end

-------------------------------------------------------------------------------
-- Addon Settings > Advanced Debugging: when CueRulesDB.ui.advancedDebug is on, XayaUI's own Lua errors are also
-- printed to the chat window as a system-style message, on top of whatever BugSack / the default UI error frame
-- already does. The previous error handler is chained (never replaced), so other addons are unaffected. Filters
-- on the addon's own folder name in the error text so other addons' errors are not spammed into chat.
-------------------------------------------------------------------------------
do
    local prevHandler = geterrorhandler()
    seterrorhandler(function(msg)
        local text = tostring(msg)
        if text:find(addonName, 1, true) and ns.CaptureError then   -- kept in the error log for the bug report (Console.lua)
            local okS, stack = pcall(debugstack, 2, 10, 0)
            pcall(ns.CaptureError, text, okS and stack or "")
        end
        local ok, on = pcall(function() return CueRulesDB and CueRulesDB.ui and CueRulesDB.ui.advancedDebug end)
        if ok and on and text:find(addonName, 1, true) and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[XayaUI Error]|r " .. text, 1, 0.35, 0.35)
        end
        if prevHandler then return prevHandler(msg) end
    end)
end

-- In-game event log (shown in the settings window's debug console tray).
ns.logBuf = {}
function ns.Log(fmt, ...)
    local msg = (select("#", ...) > 0) and fmt:format(...) or fmt
    local line = ("|cff888888%.1f|r %s"):format(GetTime() % 10000, msg)
    local b = ns.logBuf
    b[#b + 1] = line
    local n = #b
    if n > 350 then   -- trim in one pass (down to 300) instead of shifting the whole array on every line
        for i = 1, 300 do b[i] = b[n - 300 + i] end
        for i = 301, n do b[i] = nil end
    end
    if ns.LogSink then ns.LogSink(line) end
    if ns.ConsoleSink then ns.ConsoleSink(line) end   -- the separate console window (Console.lua)
end

-- Deep-copy helper for defaults.
local function Copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = Copy(v) end
    return o
end
ns.Copy = Copy

-- Fill missing keys from defaults without overwriting saved values.
local function Merge(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = Copy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" then
            Merge(dst[k], v)
        end
    end
end

ns.RULE_DEFAULTS = {
    name = "New rule",
    enabled = true,

    -- Cooldown side
    spellID = 0,            -- spell whose cooldown/charges are checked (0 = ignore)
    maxCharges = 0,         -- manual override; used only if the game reports none
    cdState = nil,          -- (blank) | none | hasCharge | ready | notReady | empty   [required]

    -- Buff side
    buffID = 0,             -- aura spell ID (0 = ignore)
    buffState = nil,        -- (blank) | none | missing | present   [required]

    -- Talent requirements: a list of { id = spellID, state = "known" | "notKnown" } combined by talentMode
    talents = {},
    talentMode = nil,       -- (blank) | none | all | any   [required]  (all = every talent must match, any = at least one)
    -- Additional triggers (Triggers.lua): typed rows combined by extra.mode (blank / all = every row, any = one is enough),
    -- then ANDed with the cooldown, buff, talent and load settings. Plain data only: no code is ever stored here.
    extra = { list = {} },
    uid = nil,              -- set when the rule first gets an outcome (Outcomes.lua)
    parentUid = nil,        -- set on an outcome: the uid of the rule whose triggers it follows
    when = { list = {} },   -- outcome combination rows: { ref, neg, op = "and" | "or" }
    useCooldown = false,    -- the Cooldown trigger section was added by hand (also shown whenever it holds data)
    useBuff = false,        -- same for Buff / Aura
    folder = nil,           -- id of the user folder this rule sits in (nil = top level)

    -- Load conditions (context): tri-state (blank/none = ignore) | yes | no
    load = {
        mode = nil,           -- (blank/all) = every active condition must match | any = at least one
        instanceTypes = {},   -- set of instance types; empty = any
        -- combat, group, raid, instance, mythicPlus, encounter, mounted, resting, specID, role: blank until chosen
    },

    sound = {
        enabled = false,    -- chosen per rule (see "+ New rule")
        source = "kit",     -- kit | lsm | file | tts (tts: value = the text, voice / rate / ttsVolume beside it)
        value = "",
        -- channel: blank until chosen (Master is used when blank)
    },
    repeatSec = 0,          -- 0 = play once per false->true transition

    visual = {
        enabled = false,
        -- trigger: blank until chosen (condition | buffActive); nothing shows while blank
        -- kind: blank until chosen (file | atlas | spellicon)
        tex = "",
        w = 128, h = 128,
        x = 0, y = 0,
        alpha = 1,
        additive = false,
        glow = false,
        -- outline glow: style auto | border | shape. border = pixel border (width / gap / color) + optional soft glow; shape = follows the art
        outline = { enabled = false, style = "auto", width = 2, gap = 0, color = { 1, 0.82, 0, 1 }, pulse = false,
            borderOn = true, glowOn = true, glowSize = 8, glowAlpha = 0.6, glowSame = true, glowColor = { 1, 0.82, 0, 1 } },
        keepAspect = true,     -- Width and Height change together (the ratio at the moment you move a slider)
        iconW = 0, iconH = 0,  -- size of the art inside the display (0 = same as the display; larger crops it)
        fadeGrey = false,      -- fade gradually as the buff runs out (gray by default, or to fadeColor)
        -- fadeMode: blank/none = gray (desaturate) | color | transparent
        fadeColor = { 1, 0.1, 0.1, 1 },
        fadeAlpha = false,     -- also fade the opacity as the buff runs out (down to fadeAlphaMin x opacity)
        fadeAlphaMin = 0.15,
        fadeAlphaMax = 1,      -- opacity multiplier at full duration (fade goes fadeAlphaMax -> fadeAlphaMin)
        texAlpha = 1,          -- opacity of the BASE texture on its own (alpha = overall opacity of everything)
        overlay = {            -- optional second texture layer on top of the base
            enabled = false,
            -- source: blank/none = same art as the base | other (pick kind + tex below)
            tex = "",
            tint = { 1, 1, 1, 1 }, desaturate = false, additive = false,
            alpha = 1,         -- opacity of the overlay on its own
            -- Progress-texture rules (visual.fill.enabled) link the base's opacity/graying to this layer by
            -- default: the overlay never grays and never dims below 1, the base opens at a reduced opacity that
            -- tracks Overlay opacity to keep their original ratio, and the base grays automatically iff a tint is
            -- selected (desaturate mirrors recolor). advanced=true breaks that link so all of those are manual again.
            advanced = false,
        },
        fill = {               -- progress-bar style wipe as the buff runs out (readable aura times only)
            enabled = false,
            -- dir (bottom|top|left|right): which edge the art shrinks toward; blank = bottom
            reverse = false,   -- fill up instead of drain
            min = 0, max = 1,  -- fraction of the art shown at 0% / 100% time remaining
        },
        flash = { enabled = false, threshold = 3, speed = 3 },  -- pulse the opacity when <= threshold seconds remain
        desatOnCD = false,     -- desaturate while the cooldown spell is on cooldown
        requireOnBar = false,  -- only show while this rule's spell/buff is currently placed on an action bar
        oocAlpha = 1,          -- opacity multiplier while out of combat (1 = same)
        border = { enabled = false, size = 1, color = { 0, 0, 0, 1 } },
        bg = { enabled = false, color = { 0, 0, 0, 0.5 } },
        zoom = 0,              -- extra crop 0-0.3 (spell icons keep their default crop)
        count = {              -- aura stacks / spell charges text (experimental under Midnight secrecy)
            enabled = false,
            -- source (stacks|charges), place, anchor: blank until chosen (fallback stacks / inner / bottom right)
            x = 0, y = 0, size = 14, color = { 1, 1, 1, 1 },
        },
        absorb = {             -- shield / absorb amount text (experimental under Midnight secrecy)
            enabled = false,
            -- source (total|aura), place, anchor, outline, font: blank until chosen (fallback total / inner / top)
            abbreviate = true, hideZero = true,
            x = 0, y = 0, size = 18, color = { 0.9, 0.9, 1, 1 },
        },
        rotation = 0,          -- degrees, 0-360
        flipH = false, flipV = false,
        recolor = false, desaturate = false, tint = { 1, 1, 1, 1 },
        text = {               -- buff duration text
            enabled = false,
            -- place (inner|outer), anchor (CENTER TOP ...), outline: blank until chosen (fallbacks: inner / center / outline)
            x = 0, y = 0,
            size = 20, color = { 1, 1, 1, 1 },
            decimals = true,
            decimalBelow = 5,      -- show tenths only below this many seconds
        },
    },
}

-- QoL "stats text" box defaults (see QoL.lua)
ns.QOL_BOX_DEFAULTS = {
    name = "Stats",
    enabled = true,
    format = "Crit {crit}   Haste {haste}\nMastery {mastery}   Vers {vers}",
    size = 14,   -- outline / justify / showCombat: blank until chosen (fallbacks: outline / left / always)
    color = { 1, 1, 1, 1 }, alpha = 1,
    decimals = 1,
    x = 0, y = -250,
}

-- Buff bars (own umbrella in the UI). Dropdown-backed fields stay blank until chosen.
ns.BAR_DEFAULTS = {
    name = "Buff bar",
    enabled = true,
    buffID = 0,
    width = 220, height = 22,
    x = 0, y = -120,
    alpha = 1,
    fillColor = { 0.25, 0.62, 1, 1 },
    bgColor = { 0, 0, 0, 0.55 },
    reverse = false,          -- false: bar drains as time runs out; true: bar fills up
    spark = false,
    vertical = false,
    borderSize = 1, borderColor = { 0, 0, 0, 1 },
    -- visibility (always|hideInactive|combat|noCombat), icon (none|left|right), texture,
    -- nameMode (aura|custom|none), timer/name anchors: blank until chosen (fallbacks documented in Bars.lua)
    customName = "",
    nameSize = 12, timerSize = 12, stackSize = 12,
    showName = true, showTimer = true, showStacks = false,
    decimals = true, decimalBelow = 5,
}
ns.BAR_GROUP_DEFAULTS = { spacing = 3, x = 0, y = -120 }   -- layout blank = manual positions

function ns.NewBar() return Copy(ns.BAR_DEFAULTS) end

-- Rename every group whose id is not "f" + digits to one that is, and re-point rules and child groups. Returns how many were renamed.
function ns.FixFolderIds()
    local used, map, n = {}, {}, 0
    for _, f in ipairs(ns.folders) do used[f.id] = true end
    for _, f in ipairs(ns.folders) do
        if type(f.id) == "string" and not f.id:match("^f%d+$") then
            local id
            repeat id = "f" .. tostring(time()) .. tostring(math.random(1000, 9999)) until not used[id]
            used[id] = true; map[f.id] = id; n = n + 1
        end
    end
    if n == 0 then return 0 end
    for _, f in ipairs(ns.folders) do
        if f.parent and map[f.parent] then f.parent = map[f.parent] end
        if map[f.id] then f.id = map[f.id] end
    end
    for _, r in ipairs(ns.rules or {}) do if r.folder and map[r.folder] then r.folder = map[r.folder] end end
    return n
end
function ns.NewFolder(name, parent)
    local id
    repeat
        id = "f" .. tostring(time()) .. tostring(math.random(1000, 9999))
        local dup
        for _, x in ipairs(ns.folders) do if x.id == id then dup = true; break end end
    until not dup
    local f = { id = id, name = name or "Folder", parent = parent }   -- parent = id of the folder this one is nested in (nil = top level)
    ns.folders[#ns.folders + 1] = f
    if ns.perf and ns.perf.show and debugstack then   -- /xui perf: say who created a group (finds groups that appear on their own)
        local src = (debugstack(2, 1, 0) or ""):match("([^\n]+)") or "?"
        print("|cffffd100XayaUI|r group created: '" .. tostring(f.name) .. "' by " .. src)
    end
    return f
end

-------------------------------------------------------------------------------
-- Step index. While the engine runs one step (ns.BeginStepIndex .. ns.EndStepIndex), the hot lookups below (group by id,
-- rule by uid, a rule's cues / conditions / outcomes) answer from maps built once for that step instead of scanning the
-- whole rule or group list on every call; with a few hundred rules that scan, repeated for every rule, was most of the
-- engine's time. Outside a step (the options window, slash commands) every lookup scans as before, so edits are seen at
-- once. Lists handed out during a step are shared: callers read them, never change them.
-------------------------------------------------------------------------------
local stepIdx   -- nil outside a step
local EMPTY = setmetatable({}, { __newindex = function() error("XayaUI: the step index lists are read-only") end })
ns.EMPTY_LIST = EMPTY

function ns.BeginStepIndex() stepIdx = {} end
function ns.EndStepIndex() stepIdx = nil end
-- true while the engine runs a step: per-step caches may be used (and reused tables handed out)
function ns.InStep() return stepIdx ~= nil end
-- Per-step memo tables: one table per name, emptied at the start of every step (reused, so no garbage). Outside a step: nil.
local memos, memoStep = {}, {}
local stepSerial = 0
function ns.StepMemo(name)
    if not stepIdx then return nil end
    local t = memos[name]
    if not t then t = {}; memos[name] = t end
    if memoStep[name] ~= stepSerial then
        for k in pairs(t) do t[k] = nil end
        memoStep[name] = stepSerial
    end
    return t
end
local BeginStepIndex0 = ns.BeginStepIndex
function ns.BeginStepIndex() stepSerial = stepSerial + 1; BeginStepIndex0() end

local function FolderIndex()
    local fi = stepIdx.folders
    if not fi then
        fi = {}
        for _, f in ipairs(ns.folders or {}) do if f.id ~= nil and fi[f.id] == nil then fi[f.id] = f end end
        stepIdx.folders = fi
    end
    return fi
end

-- parents[uid] = first parent rule with that uid; kids[uid] = every rule whose parentUid is uid, in rule order
local function RuleIndex()
    local ri = stepIdx.rules
    if not ri then
        local parents, kids = {}, {}
        for _, r in ipairs(ns.rules or {}) do
            local pu = r.parentUid
            if pu ~= nil then
                local l = kids[pu]
                if not l then l = {}; kids[pu] = l end
                l[#l + 1] = r
            elseif type(r.uid) == "string" and parents[r.uid] == nil then
                parents[r.uid] = r
            end
        end
        ri = { parents = parents, kids = kids, cues = {}, conds = {} }
        stepIdx.rules = ri
    end
    return ri
end

-- During a step: the parent rule for a parentUid (nil when not in a step: the caller scans).
function ns.StepParentOf(rule)
    if not stepIdx then return nil, false end
    local uid = rule.parentUid
    if type(uid) ~= "string" or uid == "" then return nil, true end
    local p = RuleIndex().parents[uid]
    if p == rule then p = nil end
    return p, true
end

-- During a step: a parent's children, filtered by kind ("all" / "cues" / "conds"); nil when not in a step.
function ns.StepChildrenOf(p, kind)
    if not stepIdx then return nil end
    local uid = p.uid
    if type(uid) ~= "string" then return EMPTY end
    if p.parentUid == uid then return nil end   -- a rule naming itself as parent: rare, let the caller scan
    local ri = RuleIndex()
    local all = ri.kids[uid]
    if not all then return EMPTY end
    if kind == "all" then return all end
    local cache = (kind == "cues") and ri.cues or ri.conds
    local l = cache[uid]
    if not l then
        l = {}
        local wantCue = kind == "cues"
        for i = 1, #all do local r = all[i]; if (r.isCue and true or false) == wantCue then l[#l + 1] = r end end
        cache[uid] = l
    end
    return l
end

function ns.FolderById(id)
    if not id then return nil end
    if stepIdx then return FolderIndex()[id] end
    for _, f in ipairs(ns.folders or {}) do if f.id == id then return f end end
end

function ns.FolderOf(rule)
    return ns.FolderById(rule.folder)
end

-- Folder load override. folder.loadOverride = nil | "never" | "always". The nearest folder (starting at the given id, then its
-- parents) that sets one wins. Nothing is written to the rules, so a rule that leaves the folder is back to its own load settings.
-- Returns the override and the folder that sets it.
function ns.FolderLoadOverrideFrom(folderId)
    local id, guard = folderId, 0
    while id and guard < 32 do
        local f = ns.FolderById(id)
        if not f then return nil end
        if f.loadOverride == "never" or f.loadOverride == "always" then return f.loadOverride, f end
        id, guard = f.parent, guard + 1
    end
    return nil
end
function ns.FolderLoadOverride(rule)
    return ns.FolderLoadOverrideFrom(rule and rule.folder)
end

-- Default top-level categories. Created once per profile (flag ui.defaultFolders); a top-level folder that already has the same
-- name is adopted rather than duplicated; a deleted default is not brought back unless force is true (the All Rules page button).
-- The category a rule sits in decides its KIND: Display Cues = visual only, Sound Cues = sound only, everything else
-- (Hybrid Cues, Advanced Cue Tracking, custom folders, unfiled rules) = both.
ns.DEFAULT_FOLDERS = {
    { key = "display",  name = "Display Cues",           note = "Default category. Visual-only rules: texture, icon, or text. No sound options." },
    { key = "sound",    name = "Sound Cues",             note = "Default category. Sound-only rules. No display options." },
    { key = "hybrid",   name = "Hybrid Cues",            note = "Default category. Rules with both a display and a sound." },
    { key = "advanced", name = "Advanced Cue Tracking",  note = "Default category. Rules that combine several conditions (cooldown state, buff, talents, load conditions). Also the intended home for combination rules once they exist." },
    { key = "cursor",   name = "Mouse Cursor Cues",      note = "Default category. Its settings live in QoL Elements > Cursor Tracker (QoL Elements is switched off for now)." },
}
local OLD_DEFAULT_NAMES = { advanced = "Advanced Rule Tracking", cursor = "Mouse Cursor" }
function ns.DefaultFolderInfo(key)
    for i, d in ipairs(ns.DEFAULT_FOLDERS) do if d.key == key then return d, i end end
end
local DEFAULTS_VERSION = 3
function ns.EnsureDefaultFolders(force)
    local ui = CueRulesDB and CueRulesDB.ui
    if not ui or not ns.folders then return 0 end
    if (ui.defaultFoldersV or 0) >= DEFAULTS_VERSION and not force then return 0 end
    -- profiles that already had the three original defaults only gain the new Hybrid category (a default the user deleted stays deleted)
    local upgrading = ui.defaultFolders and not force
    ui.defaultFolders = true
    ui.defaultFoldersV = DEFAULTS_VERSION
    local added = 0
    for _, d in ipairs(ns.DEFAULT_FOLDERS) do
        local have
        for _, f in ipairs(ns.folders) do
            if not f.parent and (f.default == d.key
                or (not f.default and type(f.name) == "string" and (f.name:lower() == d.name:lower()
                    or (OLD_DEFAULT_NAMES[d.key] and f.name:lower() == OLD_DEFAULT_NAMES[d.key]:lower())))) then
                have = f; break
            end
        end
        if have then
            have.default = d.key
            if OLD_DEFAULT_NAMES[d.key] and have.name == OLD_DEFAULT_NAMES[d.key] then have.name = d.name end   -- renamed default
        elseif not upgrading or d.key == "hybrid" or d.key == "cursor" then
            local nf = ns.NewFolder(d.name)
            nf.default = d.key
            added = added + 1
        end
    end
    return added
end

-- Top-level ancestor folder of a folder id (or nil).
function ns.TopFolder(folderId)
    local id, guard, top = folderId, 0, nil
    while id and guard < 32 do
        local f = ns.FolderById(id)
        if not f then return top end
        top, id, guard = f, f.parent, guard + 1
    end
    return top
end
-- "display" | "sound" | "hybrid": decided by the top-level category the rule sits in; everything else counts as hybrid.
function ns.RuleKind(rule)
    local top = ns.TopFolder(rule and rule.folder)
    local d = top and top.default
    if d == "display" or d == "sound" then return d end
    if d == "cursor" then return "display" end   -- Mouse Cursor category: visual-only
    return "hybrid"
end
-- what = "visual" | "sound"
function ns.KindHas(rule, what)
    if rule.isCue then   -- a cue is exactly one kind of thing, whatever folder its rule is in
        if what == "sound" then return rule.cueKind == "sound" or rule.cueKind == "speech" end   -- speech plays through the sound pipeline
        return rule.cueKind ~= "sound" and rule.cueKind ~= "speech" and rule.cueKind ~= "custom"
    end
    -- a rule that has outcomes has no sound / display of its own: its outcomes carry them
    if ns.HasOutcomes and ns.HasOutcomes(rule) then return false end
    local k = ns.RuleKind(rule)
    if k == "hybrid" then return true end
    return (k == "display") == (what == "visual")
end

-- Sound channel enforced by a folder (nearest ancestor wins). Nothing is written to the rules.
function ns.FolderSoundChannelFrom(folderId)
    local id, guard = folderId, 0
    while id and guard < 32 do
        local f = ns.FolderById(id)
        if not f then return nil end
        if f.soundChannel and f.soundChannel ~= "" and f.soundChannel ~= "none" then return f.soundChannel, f end
        id, guard = f.parent, guard + 1
    end
end
-- The sound table the engine plays: the rule's own, with the folder-enforced channel applied.
function ns.EffectiveSound(rule)
    local s = rule and rule.sound
    if not s then return s end
    local ch = ns.FolderSoundChannelFrom(rule.folder)
    if not ch then return s end
    local c = {}
    for k, v in pairs(s) do c[k] = v end
    c.channel = ch
    return c
end

-- One-time: every rule that existed before the cue kinds counts as Hybrid. Whatever sat under Display Cues or Sound Cues
-- moves under Hybrid Cues (same-named subfolders are merged, nothing is deleted).
local function MergeFolderInto(src, dstParentId)
    local existing
    for _, f in ipairs(ns.folders) do
        if f ~= src and f.parent == dstParentId and f.name == src.name then existing = f; break end
    end
    if not existing then src.parent = dstParentId; return end
    for _, r in ipairs(ns.rules or {}) do if r.folder == src.id then r.folder = existing.id end end
    local kids = {}
    for _, f in ipairs(ns.folders) do if f.parent == src.id then kids[#kids + 1] = f end end
    for _, k in ipairs(kids) do MergeFolderInto(k, existing.id) end
    for i, f in ipairs(ns.folders) do if f == src then table.remove(ns.folders, i); break end end
end
function ns.MigrateToHybrid()
    local ui = CueRulesDB and CueRulesDB.ui
    if not ui or ui.hybridMigrated or not ns.folders or not ns.rules then return 0 end
    local hybrid
    for _, f in ipairs(ns.folders) do if not f.parent and f.default == "hybrid" then hybrid = f; break end end
    if not hybrid then return 0 end
    ui.hybridMigrated = true
    local moved = 0
    for _, key in ipairs({ "display", "sound" }) do
        local src
        for _, f in ipairs(ns.folders) do if not f.parent and f.default == key then src = f; break end end
        if src then
            for _, r in ipairs(ns.rules) do if r.folder == src.id then r.folder = hybrid.id; moved = moved + 1 end end
            local kids = {}
            for _, f in ipairs(ns.folders) do if f.parent == src.id then kids[#kids + 1] = f end end
            for _, k in ipairs(kids) do MergeFolderInto(k, hybrid.id) end
        end
    end
    -- count everything now under Hybrid for the message
    local n = 0
    for _, r in ipairs(ns.rules) do if ns.RuleKind(r) == "hybrid" and r.folder then n = n + 1 end end
    if n > 0 then ns.hybridMigratedCount = n end
    return n
end

-- One-time: every currently ACTIVE display (rule on + display on + a visual kind) becomes a progress texture
-- (visual.fill.enabled). Base art and the overlay layer are cropped together by that wipe, so they act as one unit.
-- The previous fill switch is kept in rule.progressBackup so it can be restored.
function ns.MigrateToProgress()
    local ui = CueRulesDB and CueRulesDB.ui
    if not ui or ui.progressMigrated or not ns.rules then return 0 end
    ui.progressMigrated = true
    local n = 0
    for _, r in ipairs(ns.rules) do
        local v = r.visual
        if r.enabled and type(v) == "table" and v.enabled and ns.KindHas(r, "visual") then
            if type(v.fill) ~= "table" then v.fill = { enabled = false, reverse = false, min = 0, max = 1 } end
            if not v.fill.enabled then
                r.progressBackup = { fillEnabled = false }
                v.fill.enabled = true
                n = n + 1
            end
        end
    end
    return n
end

-- Fonts: blank/none = the game's default font. Built-ins plus every LibSharedMedia font that is loaded.
local BUILTIN_FONTS = {
    frizqt = { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    arialn = { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    skurri = { "Skurri", "Fonts\\SKURRI.TTF" },
    morpheus = { "Morpheus", "Fonts\\MORPHEUS.TTF" },
    -- bundled open-source fonts (SIL OFL, see Media\\Fonts\\OFL-*.txt). A new font file needs a full game restart to load.
    firasans = { "Fira Sans", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\FiraSans-Regular.ttf" },
    lato = { "Lato", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\Lato-Regular.ttf" },
    ptsans = { "PT Sans", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\PT_Sans-Web-Regular.ttf" },
    barlow = { "Barlow", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\Barlow-Regular.ttf" },
    firamono = { "Fira Mono", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\FiraMono-Regular.ttf" },
}
local BUILTIN_FONT_ORDER = { "frizqt", "arialn", "skurri", "morpheus", "firasans", "lato", "ptsans", "barlow", "firamono" }
function ns.FontList()
    local values, order = { none = "(none - game default)" }, { "none" }
    for _, k in ipairs(BUILTIN_FONT_ORDER) do values[k] = BUILTIN_FONTS[k][1]; order[#order + 1] = k end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm then
        local names = {}
        for n in pairs(lsm:HashTable("font")) do names[#names + 1] = n end
        table.sort(names)
        for _, n in ipairs(names) do values["lsm:" .. n] = n; order[#order + 1] = "lsm:" .. n end
    end
    return values, order
end
function ns.FontPath(key)
    key = ns.Val(key)
    if key then
        if BUILTIN_FONTS[key] then return BUILTIN_FONTS[key][2] end
        local n = key:match("^lsm:(.+)$")
        local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
        local p = n and lsm and lsm:Fetch("font", n, true)
        if p then return p end
    end
    return STANDARD_TEXT_FONT
end

function ns.NewRule()
    local r = Copy(ns.RULE_DEFAULTS)
    return r
end

ns.Merge = Merge

-- Bring a rule table (saved or imported) up to the current shape.
function ns.NormalizeRule(r)
    -- migrate v0.1/0.2 flat context fields into r.load
    if type(r.load) ~= "table" then r.load = {} end
    for _, k in ipairs({ "combat", "group", "instance" }) do
        if r[k] ~= nil then r.load[k] = r[k]; r[k] = nil end
    end
    Merge(r, ns.RULE_DEFAULTS)
    if ns.NormalizeExtra then ns.NormalizeExtra(r) end
    if ns.NormalizeWhen then ns.NormalizeWhen(r) end
    if ns.NormalizeCues then ns.NormalizeCues(r) end
    if ns.NormalizeActions then ns.NormalizeActions(r) end
    -- legacy "any" -> "none" (explicit "ignore")
    for _, k in ipairs({ "cdState", "buffState", "talentState" }) do if r[k] == "any" then r[k] = "none" end end
    for k, v in pairs(r.load) do if v == "any" and k ~= "mode" then r.load[k] = "none" end end
    -- talents: single talentID/talentState -> list + mode
    if type(r.talents) ~= "table" then r.talents = {} end
    if r.talentID ~= nil or r.talentState ~= nil then
        local ts = r.talentState
        if (r.talentID or 0) ~= 0 and (ts == "known" or ts == "notKnown") then
            if #r.talents == 0 then r.talents[1] = { id = r.talentID, state = ts } end
            r.talentMode = r.talentMode or "all"
        elseif ts == "none" or ts == "any" or ts == "known" or ts == "notKnown" then
            r.talentMode = r.talentMode or "none"
        end
        r.talentID, r.talentState = nil, nil
    end
end

local function InitDB()
    CueRulesDB = CueRulesDB or {}
    CueRulesDB.rules = CueRulesDB.rules or {}
    CueRulesDB.version = CueRulesDB.version or 1
    CueRulesDB.ui = CueRulesDB.ui or {}
    if CueRulesDB.ui.trayOpen == nil then CueRulesDB.ui.trayOpen = true end
    -- Advanced Debugging defaults ON (recommended): XayaUI's own Lua errors print to chat as a system message.
    if CueRulesDB.ui.advancedDebug == nil then CueRulesDB.ui.advancedDebug = true end
    for _, r in ipairs(CueRulesDB.rules) do ns.NormalizeRule(r) end
    ns.rules = CueRulesDB.rules
    if ns.MigrateCues then
        local ok, n = pcall(ns.MigrateCues)
        if ok and n and n > 0 then ns.Print(n .. " existing sounds / displays were moved into Cues (each condition now lists them under THEN; a full backup of your rules was saved first).") end
    end
    CueRulesDB.qol = CueRulesDB.qol or {}
    CueRulesDB.qol.boxes = CueRulesDB.qol.boxes or {}
    for _, b in ipairs(CueRulesDB.qol.boxes) do
        Merge(b, ns.QOL_BOX_DEFAULTS)
        if b.showCombat == "any" then b.showCombat = "none" end
    end
    ns.qolBoxes = CueRulesDB.qol.boxes
    CueRulesDB.folders = CueRulesDB.folders or {}
    ns.folders = CueRulesDB.folders
    ns.EnsureDefaultFolders()
    do   -- group ids must be "f" + digits (the tree, previews and menus find groups by that form); an import once kept ids like "feui1"
        local n = ns.FixFolderIds and ns.FixFolderIds()
        if n and n > 0 then ns.Print(n .. " imported group(s) were given standard ids so they can be previewed, renamed, and moved.") end
    end
    local nHyb = ns.MigrateToHybrid()
    if nHyb and nHyb > 0 then ns.Print(nHyb .. " existing rules are now under Hybrid Cues (they keep both their display and sound options).") end
    local nProg = ns.MigrateToProgress()
    if nProg and nProg > 0 then ns.Print(nProg .. " active display(s) were converted to progress textures (base and overlay wipe together).") end
    CueRulesDB.bars = CueRulesDB.bars or {}
    for _, b in ipairs(CueRulesDB.bars) do Merge(b, ns.BAR_DEFAULTS) end
    ns.bars = CueRulesDB.bars
    CueRulesDB.barGroup = CueRulesDB.barGroup or {}
    Merge(CueRulesDB.barGroup, ns.BAR_GROUP_DEFAULTS)
    ns.barGroup = CueRulesDB.barGroup
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name ~= addonName then return end
    InitDB()
    f:UnregisterEvent("ADDON_LOADED")
    if ns.OnDBReady then ns.OnDBReady() end
    if ns.QoL_OnDBReady then ns.QoL_OnDBReady() end
    if ns.Cursor_OnDBReady then ns.Cursor_OnDBReady() end
    if ns.Chat_OnDBReady then ns.Chat_OnDBReady() end
    if ns.DataPanels_OnDBReady then ns.DataPanels_OnDBReady() end
    if ns.Notepad_OnDBReady then ns.Notepad_OnDBReady() end
    if ns.Minimap_OnDBReady then ns.Minimap_OnDBReady() end
end)

-------------------------------------------------------------------------------
-- Seed rules (Xaya's Vengeance DH test set). Usage: /xui seed
-------------------------------------------------------------------------------
function ns.SeedRules()
    local kit = SOUNDKIT and SOUNDKIT.RAID_WARNING and tostring(SOUNDKIT.RAID_WARNING) or ""
    local function base(name, spell, buff)
        local r = ns.NewRule()
        r.name = name
        r.spellID, r.buffID = spell, buff
        r.cdState, r.buffState, r.talentMode = "ready", "missing", "none"
        r.load.combat = "yes"
        r.sound.enabled = true
        r.sound.source, r.sound.value = "kit", kit
        return r
    end
    -- 1) Infernal Strike: FILO talent known, in combat, 2 charges, FILO shield NOT up -> sound + icon glow
    local a = base("Infernal Strike (FILO)", 189110, 1266619)
    a.talents, a.talentMode = { { id = 1266497, state = "known" } }, "all"
    a.visual.enabled, a.visual.kind, a.visual.glow, a.visual.trigger = true, "spellicon", true, "condition"
    a.visual.w, a.visual.h, a.visual.y, a.visual.additive = 64, 64, 120, false
    -- 2) Demon Spikes: 2 charges, buff missing, in combat -> repeat 1/s
    local b = base("Demon Spikes 2 charges", 203720, 203819)
    b.repeatSec = 1
    -- 3) Fiery Brand: 2 charges, buff missing, in combat -> repeat 1/s
    --    buffID 204021 is a PLACEHOLDER: confirm the player-buff spell ID in game.
    local c = base("Fiery Brand 2 charges", 204021, 204021)
    c.repeatSec = 1
    for _, r in ipairs({ a, b, c }) do ns.rules[#ns.rules + 1] = r end
    ns.RefreshAllVisuals()
    ns.MarkDirty()
    if ns.OnRulesChanged then ns.OnRulesChanged() end
    ns.Print("seeded 3 rules. Pick your sounds in /xui. Fiery Brand buff ID is a placeholder.")
end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
SLASH_XAYAUI1 = "/xui"
SLASH_XAYAUI2 = "/xayaui"
SlashCmdList["XAYAUI"] = function(msg)
    msg = (msg or ""):lower()
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "config" or cmd == "options" then
        if ns.ToggleUI then ns.ToggleUI()
        else ns.Print("settings window code did not load (Options.lua hit a Lua error at startup). Type /console scriptErrors 1 then /reload to see it, or run /xui debug.") end
    elseif cmd == "debug" then
        local function yn(v) return v and "yes" or "NO" end
        ns.Print(("debug: ToggleUI=%s rules=%s AceConfigDialog=%s AceConfigRegistry=%s AceGUI=%s"):format(
            yn(ns.ToggleUI), yn(ns.rules), yn(LibStub and LibStub("AceConfigDialog-3.0", true)),
            yn(LibStub and LibStub("AceConfigRegistry-3.0", true)), yn(LibStub and LibStub("AceGUI-3.0", true))))
        ns.Print("debug: OptionsLoaded=" .. tostring(ns.optionsLoaded) .. " OptionsError=" .. tostring(ns.optionsError))
    elseif cmd == "perf" and tostring(arg or ""):lower():match("^ui") then   -- settings-window rebuild timing (/xui perf ui); plain /xui perf is the engine meter below
        ns.perf = ns.perf or { n = 0 }; ns.perf.show = not ns.perf.show
        ns.Print("rebuild timing " .. (ns.perf.show and "ON: every window rebuild prints build + skin milliseconds" or "OFF"))
    elseif cmd == "icons" then
        if ns.IconReport then ns.IconReport() end
    elseif cmd == "status" then
        if ns.PrintStatus then ns.PrintStatus() end
    elseif cmd == "debuffs" then
        if ns.ProbeDebuffs then ns.ProbeDebuffs(arg) end
    elseif cmd == "probe" then
        if arg:match("^ids") then
            if ns.IDProbe then ns.IDProbe((arg:gsub("^ids%s*", ""))) end
        elseif ns.Probe then ns.Probe(tonumber(arg)) end
    elseif cmd == "talents" then
        if ns.TalentCommand then ns.TalentCommand(arg) end
    elseif cmd == "model" then
        if ns.ModelCommand then ns.ModelCommand(arg) end
    elseif cmd == "tracker" then
        if ns.TrackerCommand then ns.TrackerCommand(arg) end
    elseif cmd == "mods" then
        if ns.ProbeMods then ns.ProbeMods() end
    elseif cmd == "groups" then
        if ns.ProbeGroups then ns.ProbeGroups() end
    elseif cmd == "loc" then
        if ns.ProbeLossOfControl then ns.ProbeLossOfControl() end
    elseif cmd == "seed" then
        if ns.rules then ns.SeedRules() end
    elseif cmd == "cursor" then
        if ns.Cursor_Toggle then
            local on = ns.Cursor_Toggle()
            ns.Print("cursor tracker " .. (on and "ON" or "OFF"))
        end
    elseif cmd == "chat" then
        if ns.Chat and ns.Chat.Command then ns.Chat.Command(arg) end
    elseif cmd == "timing" then   -- how every time / stack dependent cue gets its numbers in combat (Timing.lua)
        if ns.Timing then ns.Timing.Report() end
    elseif cmd == "perf" then   -- engine timing on this machine (Engine.lua)
        if ns.PerfCommand then ns.PerfCommand(arg) end
    elseif cmd == "chatprobe" then   -- read-only look at Blizzard's chat frames (Chat Panel rebuild, stage S0)
        if ns.ChatProbe then ns.ChatProbe() end
    elseif cmd == "privacy" then
        if ns.ChatPrivacy_Set and ns.chatDB then ns.ChatPrivacy_Set(not ns.chatDB.privOn); ns.Print("chat privacy cover " .. (ns.chatDB.privOn and "ON" or "OFF")) end
    elseif cmd == "data" then
        if ns.DataPanels_OpenSettings then ns.DataPanels_OpenSettings() end
    elseif cmd == "notepad" or cmd == "note" or cmd == "notes" then   -- show / hide the notepad
        if ns.Notepad_Toggle then ns.Notepad_Toggle() end
    elseif cmd == "panel" then
        if ns.Chat and ns.Chat.OpenSettings then ns.Chat.OpenSettings("bar") end
    elseif cmd == "gamemenu" then
        if ns.GameMenu_Diagnostics then ns.GameMenu_Diagnostics() end
        if ns.GameMenuSkin_Diagnostics then ns.GameMenuSkin_Diagnostics() end
    elseif cmd == "unlock" then
        if ns.ToggleUnlock then ns.ToggleUnlock() end
    elseif cmd == "media" then
        if ns.UserMediaReport then ns.UserMediaReport() end
    elseif cmd == "console" then
        if ns.ConsoleWindow then ns.ConsoleWindow() end
    elseif cmd == "bug" then
        if ns.ShowBugReport then ns.ShowBugReport() end
    else
        ns.Print((("commands: /xui (settings) | /xui console (event log window) | /xui bug (bug report) | /xui status | /xui probe <spellID|ids> | /xui debuffs [target|focus] [spellID] | /xui unlock | /xui cursor | /xui chat (Chat Panel: on, off, reset, move, history, settings) | /xui chatprobe (read-only chat frame report) | /xui perf [on|off] (engine timing) | /xui perf ui (settings window rebuild timing) | /xui timing (how every cue gets time in combat) | /xui notes (show / hide the notepad) | /xui panel (Chat Bar settings) | /xui data (custom data panels and bars) | /xui privacy (cover or show the chat) | /xui seed | /xui talents [status|<name>] | /xui model [setup|<spellID>] | /xui tracker [shadow|status] | /xui loc | /xui media"):gsub("|", "||")))
    end
end
