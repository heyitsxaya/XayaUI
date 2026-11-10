-------------------------------------------------------------------------------
-- RuleDefaults.lua : XayaUI Rules' share of what Core.lua held before the platform split (P4, docs/plans/PLATFORM-SPLIT-2026-11-07.md
-- section 4.1): rule defaults and the rule shape upgrade, buff bar defaults, group ids and sources, the engine's step index, folder load
-- overrides, the default categories, the folder-enforced sound channel, and the set-up of the rules, groups and buff bars at load.
-- Moved unchanged from XayaUI/Core.lua (core 0.6.75); only the start-up is new: it runs at XayaUI Rules' own ADDON_LOADED, after every
-- file of this addon has run (the Platform's CueRulesDB is set up by then: XayaUI is this addon's dependency and loads first).
-------------------------------------------------------------------------------
local addonName, ns = ...; ns = XayaUI_NS or ns   -- the Platform's namespace (XayaUI/Core.lua)
local Copy, Merge = ns.Copy, ns.Merge
-- (P4) the saved data through the settings seam (Modules.lua section 0b): the same CueRulesDB keys as before, read and written through
-- their owners' views (rules, folders, bars, barGroup: core; ui: platform) instead of CueRulesDB directly, as every module does
local CoreS, PlatS = ns.Settings("core"), ns.Settings("platform")
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("core", "XayaUI_Rules", "XayaUIRulesDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)

ns.rules = nil -- set at XayaUI Rules' ADDON_LOADED to CoreS.rules (InitRules below)

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
    talentMode = nil,       -- (blank) | none | all | any   blank and none = no talent requirement (Conditions.lua CheckTalents); all = every talent must match, any = at least one
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
        if f.cGroup ~= nil and map[f.cGroup] then f.cGroup = map[f.cGroup] end   -- (a group that follows another group: B, 0.6.82)
        if map[f.id] then f.id = map[f.id] end
    end
    for _, r in ipairs(ns.rules or {}) do if r.folder and map[r.folder] then r.folder = map[r.folder] end end
    return n
end
-- Where a group came from (#372 / CHAT-3d, Xaya: "config includes folder name, folder type, and original character / source of
-- creation"): origin = { by = "Name-Realm" of the character that made it, how = "made" | "default" | "imported" | ..., at = time() }.
-- Shown on the group page's Config tab; groups made before this have none ("not recorded").
function ns.CharacterKey()
    local n = UnitName and UnitName("player")
    local r = GetRealmName and GetRealmName()
    if type(n) ~= "string" or n == "" then return nil end
    return (type(r) == "string" and r ~= "") and (n .. "-" .. r) or n
end
-- an origin read from saved or imported data: plain text only (it is shown as text), short, or nil
function ns.CleanOrigin(o)
    if type(o) ~= "table" then return nil end
    local function txt(v, max) if type(v) ~= "string" then return nil end; v = v:gsub("|", ""):sub(1, max); return v ~= "" and v or nil end
    local out = { by = txt(o.by, 64), how = txt(o.how, 24), at = (type(o.at) == "number" and o.at > 0) and math.floor(o.at) or nil }
    return (out.by or out.how or out.at) and out or nil
end
function ns.NewFolder(name, parent, how)
    local id
    repeat
        id = "f" .. tostring(time()) .. tostring(math.random(1000, 9999))
        local dup
        for _, x in ipairs(ns.folders) do if x.id == id then dup = true; break end end
    until not dup
    local f = { id = id, name = name or "Folder", parent = parent }   -- parent = id of the folder this one is nested in (nil = top level)
    f.origin = { by = ns.CharacterKey(), how = how or "made", at = time and time() or nil }
    ns.folders[#ns.folders + 1] = f
    if ns.perf and ns.perf.show and debugstack then   -- /xui debug perf ui: say who created a group (finds groups that appear on their own)
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

-- #309: one step table, emptied at every step start (no new table per step); the folder and rule indexes below are kept between
-- steps and reused only while the lists they were built from are unchanged (checked entry by entry, no edit signal needed).
local stepTable = {}
function ns.BeginStepIndex() for k in pairs(stepTable) do stepTable[k] = nil end; stepIdx = stepTable end
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

-- Kept-index check (#309): an index built from a list is reused while the list still holds the same entries, in the same order, with
-- the same identifying fields. Any difference (an entry added, removed, moved, or a uid / parentUid / id / cue flag changed, whether or
-- not the edit announced itself) rebuilds the index exactly as a fresh build would.
-- (review R18 follow-up) the entry-by-entry walk runs at most once a second while the same list table keeps its length and no setting
-- changed (ns.configVersion, ns.MarkDirty); in between, steps (routed re-checks up to 30 a second) reuse the last verdict. An added or
-- removed entry changes the length; moves and uid rewrites call ns.MarkDirty; anything else is caught by the once-a-second walk.
local function WalkDue(list, kList, kVer, kSec)
    if list ~= kList or (ns.configVersion or 0) ~= kVer then return true end
    return math.floor(GetTime()) ~= kSec
end
local fiKept, fiN, fiF, fiId = nil, -1, {}, {}
local fiList, fiVer, fiSec
local function FolderIndexValid(list)
    local n = #list
    if not fiKept or n ~= fiN then return false end
    if not WalkDue(list, fiList, fiVer, fiSec) then return true end
    for i = 1, n do local f = list[i]; if fiF[i] ~= f or fiId[i] ~= f.id then return false end end
    fiList, fiVer, fiSec = list, ns.configVersion or 0, math.floor(GetTime())
    return true
end
local function FolderIndex()
    local fi = stepIdx.folders
    if not fi then
        local list = ns.folders or EMPTY
        if FolderIndexValid(list) then
            fi = fiKept
        else
            fi = {}
            local n = #list
            for i = 1, n do
                local f = list[i]
                if f.id ~= nil and fi[f.id] == nil then fi[f.id] = f end
                fiF[i], fiId[i] = f, f.id
            end
            for i = n + 1, fiN do fiF[i], fiId[i] = nil, nil end
            fiKept, fiN = fi, n
            fiList, fiVer, fiSec = list, ns.configVersion or 0, math.floor(GetTime())
        end
        stepIdx.folders = fi
    end
    return fi
end

-- parents[uid] = first parent rule with that uid; kids[uid] = every rule whose parentUid is uid, in rule order
local riKept, riN, riR, riU, riP, riC = nil, -1, {}, {}, {}, {}
local riList, riVer, riSec
local function RuleIndexValid(list)
    local n = #list
    if not riKept or n ~= riN then return false end
    if not WalkDue(list, riList, riVer, riSec) then return true end   -- (review R18 follow-up, see WalkDue)
    for i = 1, n do
        local r = list[i]
        if riR[i] ~= r or riU[i] ~= r.uid or riP[i] ~= r.parentUid or riC[i] ~= (r.isCue and true or false) then return false end
    end
    riList, riVer, riSec = list, ns.configVersion or 0, math.floor(GetTime())
    return true
end
local function RuleIndex()
    local ri = stepIdx.rules
    if not ri then
        local list = ns.rules or EMPTY
        if RuleIndexValid(list) then
            ri = riKept   -- same rules, same order, same uid / parentUid / cue flags: the kept index (and its cue / condition lists) still holds
        else
            local parents, kids = {}, {}
            local n = #list
            for i = 1, n do
                local r = list[i]
                local pu = r.parentUid
                if pu ~= nil then
                    local l = kids[pu]
                    if not l then l = {}; kids[pu] = l end
                    l[#l + 1] = r
                elseif type(r.uid) == "string" and parents[r.uid] == nil then
                    parents[r.uid] = r
                end
                riR[i], riU[i], riP[i], riC[i] = r, r.uid, pu, (r.isCue and true or false)
            end
            for i = n + 1, riN do riR[i], riU[i], riP[i], riC[i] = nil, nil, nil, nil end
            ri = { parents = parents, kids = kids, cues = {}, conds = {} }
            riKept, riN = ri, n
            riList, riVer, riSec = list, ns.configVersion or 0, math.floor(GetTime())
        end
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
    local ui = CoreS   -- (P5) the rules' own one-time flags: XayaUI Rules' store (CueRulesDB.ui before)
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
            local nf = ns.NewFolder(d.name, nil, "default")
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
    local ui = CoreS   -- (P5) the rules' own one-time flags: XayaUI Rules' store (CueRulesDB.ui before)
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
    local ui = CoreS   -- (P5) the rules' own one-time flags: XayaUI Rules' store (CueRulesDB.ui before)
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

function ns.NewRule()
    local r = Copy(ns.RULE_DEFAULTS)
    return r
end

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
    -- built-in Buff / Aura "seconds left" (0.6.4): a comparison and a number, or nothing
    if not (r.buffTimeOp == ">=" or r.buffTimeOp == "<=" or r.buffTimeOp == ">" or r.buffTimeOp == "<") then r.buffTimeOp = nil end
    if r.buffTimeSec ~= nil then r.buffTimeSec = tonumber(r.buffTimeSec) end
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

local function InitRules()
    CoreS.rules = CoreS.rules or {}
    for _, r in ipairs(CoreS.rules) do ns.NormalizeRule(r) end
    ns.rules = CoreS.rules
    if ns.MigrateCues then
        local ok, n = pcall(ns.MigrateCues)
        if not ok and ns.RecordError then pcall(ns.RecordError, "XayaUI cue migration: " .. tostring(n), nil, "XayaUI", "XUI-E011") end   -- (audit D57)
        if ok and n and n > 0 then ns.Print(n .. " existing sounds / displays were moved into Cues (each condition now lists them under THEN; a full backup of your rules was saved first).") end
    end
    CoreS.folders = CoreS.folders or {}
    ns.folders = CoreS.folders
    ns.EnsureDefaultFolders()
    do   -- group ids must be "f" + digits (the tree, previews and menus find groups by that form); an import once kept ids like "feui1"
        local n = ns.FixFolderIds and ns.FixFolderIds()
        if n and n > 0 then ns.Print(n .. " imported group(s) were given standard ids so they can be previewed, renamed, and moved.") end
    end
    local nHyb = ns.MigrateToHybrid()
    if nHyb and nHyb > 0 then ns.Print(nHyb .. " existing rules are now under Hybrid Cues (they keep both their display and sound options).") end
    local nProg = ns.MigrateToProgress()
    if nProg and nProg > 0 then ns.Print(nProg .. " active display(s) were converted to progress textures (base and overlay wipe together).") end
    -- (0.6.82, fix A "Nothing moves": Visual.lua ns.MigrateGroupAnchors; once per profile)
    if ns.MigrateGroupAnchors then
        local okA, nA = pcall(ns.MigrateGroupAnchors)
        if not okA and ns.RecordError then pcall(ns.RecordError, "XayaUI group anchor update: " .. tostring(nA), nil, "XayaUI", "XUI-E011") end
        if okA and nA and nA > 0 then ns.Print(nA .. " group(s) with an anchor point other than Center had their X / Y adjusted once, so they stay where they were: the anchor point now names that point of what the group holds.") end
    end
    CoreS.bars = CoreS.bars or {}
    for _, b in ipairs(CoreS.bars) do Merge(b, ns.BAR_DEFAULTS) end
    ns.bars = CoreS.bars
    CoreS.barGroup = CoreS.barGroup or {}
    Merge(CoreS.barGroup, ns.BAR_GROUP_DEFAULTS)
    ns.barGroup = CoreS.barGroup
    ns.SettingsChanged()   -- hot-path caches of settings tables re-read them (the Platform did the same after its own set-up)
end

-- Rules ready: the rules, groups and the engine are set up. ns.WhenRulesReady(fn) runs fn then, or at once when it already happened (a
-- file of this addon asks while it loads, before the set-up). Before the split this was the Platform's ns.WhenReady, which now fires
-- before this addon's files run.
local rulesQueue, rulesReady = {}, false
function ns.WhenRulesReady(fn)
    if type(fn) ~= "function" then return end
    if rulesReady then fn() else rulesQueue[#rulesQueue + 1] = fn end
end
function ns.RulesReady() return rulesReady end

-- The "rules" service (Modules.lua ns.Provide / ns.Service): what the Platform asks of XayaUI Rules (the /xui commands Core.lua keeps
-- for it, the bug report's rule counts, a theme change redrawing the displays). With this addon switched off the service is absent and
-- the Platform leaves those out or says the command needs XayaUI Rules. Each entry calls the function as it is when asked (the files
-- that define them load after this one).
if ns.Provide then
    ns.Provide("rules", {
        Rules = function() return ns.rules end,
        PrintStatus = function(...) if ns.PrintStatus then return ns.PrintStatus(...) end end,
        PerfCommand = function(...) if ns.PerfCommand then return ns.PerfCommand(...) end end,
        TalentCommand = function(...) if ns.TalentCommand then return ns.TalentCommand(...) end end,
        ToggleUnlock = function(...) if ns.ToggleUnlock then return ns.ToggleUnlock(...) end end,
        MarkDirty = function(...) if ns.MarkDirty then return ns.MarkDirty(...) end end,
        CurrentSpecID = function(...) if ns.CurrentSpecID then return ns.CurrentSpecID(...) end end,
        -- the spellbook and talent lists the rule editor's pickers use (Conditions.lua), read by XayaUI QoL's Character Toolkit
        BuildSpellList = function(...) return ns.BuildSpellList(...) end,
        BuildTalentList = function(...) return ns.BuildTalentList(...) end,
        ForgetSpellLists = function() ns.spellList, ns.talentList = nil, nil end,
        -- the damage school / dispel type words coloured (BarCue.lua), used by XayaUI Bonus Features' tooltips
        BarColorizeTypes = function(...) return ns.BarColorizeTypes(...) end,
    })
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name ~= addonName then return end
    f:UnregisterEvent("ADDON_LOADED")
    if not ns.SettingsReady() then return end   -- the Platform did not set up its saved data (its own error is recorded)
    -- (P5) this addon's own store first (Modules.lua section 0c: copied once from CueRulesDB, with a backup and the counts checked,
    -- RuleShare.lua); the Platform opens it at this same event, whichever handler runs first
    if ns.SettingsOpen then ns.SettingsOpen("core") end
    if not ns.SettingsReady("core") then return end
    InitRules()
    if ns.OnDBReady then ns.OnDBReady() end   -- the rule engine (Engine.lua)
    rulesReady = true
    local q = rulesQueue; rulesQueue = {}
    for _, fn in ipairs(q) do local ok, err = pcall(fn); if not ok then local h = geterrorhandler and geterrorhandler(); if h then h(err) end end end
end)
