-------------------------------------------------------------------------------
-- Options.lua : tabbed settings window built on AceConfig-3.0 / AceGUI-3.0,
-- plus an attached debug-console tray (status + event log) under the window.
--
-- Layout:  rule list (tree, left)  |  tabs: Rule / Trigger / Conditions (display, text, sound) / Load
-------------------------------------------------------------------------------
local addonName, ns = ...

local APP = "CueRules"
local AceConfigRegistry = LibStub and LibStub("AceConfigRegistry-3.0", true)
local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)
if not (AceConfigRegistry and AceConfigDialog) then
    function ns.ToggleUI() ns.Print("Ace3 libraries not found - check the Libs folder.") end
    return
end

local function Notify() if ns.SaveRulesSub then pcall(ns.SaveRulesSub) end if ns.SmartOpen then pcall(ns.SmartOpen) end if ns.FixSelection then pcall(ns.FixSelection) end AceConfigRegistry:NotifyChange(APP) end

local function Changed(rule)
    if rule then
        ns.RefreshVisual(rule)
        -- an edit on a parent rule (aura / spell ID, triggers) changes what its cues resolve (the "automatic" icon comes from the parent's
        -- first trigger), but each cue is its own frame: repaint them too, or the icon stays a "?" until something else refreshes it
        if not rule.isCue and rule.uid and ns.CuesOf then
            for _, c in ipairs(ns.CuesOf(rule)) do
                if type(c.visual) == "table" and (not ns.KindHas or ns.KindHas(c, "visual")) then pcall(ns.RefreshVisual, c) end
            end
        end
    end
    ns.MarkDirty()
end

-------------------------------------------------------------------------------
-- Value tables
-------------------------------------------------------------------------------
local CD_VALUES = {
    none = "(none - ignore cooldown)",
    hasCharge = "Has a charge / available",
    ready = "Fully ready (max charges / off cooldown)",
    notReady = "Not fully ready",
    empty = "Empty / on cooldown  (experimental for multi-charge)",
}
local CD_ORDER = { "none", "hasCharge", "ready", "notReady", "empty" }
local BUFF_VALUES = { none = "(none - ignore buff)", missing = "Buff is MISSING", present = "Buff is present" }
local BUFF_ORDER = { "none", "missing", "present" }
local TRI_ORDER = { "none", "yes", "no" }
local TALENT_STATE = { known = "must be KNOWN", notKnown = "must NOT be known" }
local TALENT_STATE_ORDER = { "known", "notKnown" }
local TALENT_MODE_USED = { all = "ALL listed talents must match", any = "ANY one listed talent is enough" }
local TALENT_MODE_USED_ORDER = { "all", "any" }
local TALENT_MODE = { none = "(none - ignore talents)", all = "ALL listed talents must match", any = "ANY one listed talent is enough" }
local TALENT_MODE_ORDER = { "none", "all", "any" }
local LOAD_MODE = { never = "Never load", always = "Always load", all = "Match ALL of the conditions below", any = "Match ANY of the conditions below" }
local LOAD_MODE_ORDER = { "never", "always", "all", "any" }
local COUNT_SOURCE = { none = "(none - aura stacks)", stacks = "Aura stacks", charges = "Spell charges" }
local COUNT_SOURCE_ORDER = { "none", "stacks", "charges" }
local ABSORB_SOURCE = { none = "(none - total absorb on you)", total = "Total absorb on you", aura = "This aura's shield value" }
local ABSORB_SOURCE_ORDER = { "none", "total", "aura" }
local BAR_SHOW = { none = "(none - always show)", active = "Only while the buff is active" }
local BAR_SHOW_ORDER = { "none", "active" }
local BAR_ICON = { none = "(none - no icon)", left = "Icon on the left", right = "Icon on the right" }
local BAR_ICON_ORDER = { "none", "left", "right" }
local BAR_NAME = { none = "(none - aura name)", aura = "Aura name", custom = "Custom text" }
local BAR_NAME_ORDER = { "none", "aura", "custom" }
local BAR_LAYOUT = { none = "(none - manual positions)", down = "Stack downward", up = "Stack upward", right = "Line up to the right", left = "Line up to the left" }
local BAR_LAYOUT_ORDER = { "none", "down", "up", "right", "left" }
local BAR_ANCHOR = { none = "(none - default)", LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
local BAR_ANCHOR_ORDER = { "none", "LEFT", "CENTER", "RIGHT" }
local ROLE_VALUES = { none = "(none - any role)", TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }
local ROLE_ORDER = { "none", "TANK", "HEALER", "DAMAGER" }
local CHANNEL_VALUES = { none = "(none - Master)", Master = "Master", SFX = "SFX", Music = "Music", Ambience = "Ambience", Dialog = "Dialog" }
local CHANNEL_ORDER = { "none", "Master", "SFX", "Music", "Ambience", "Dialog" }
local VIS_TRIGGER = { none = "(none - do not show)", condition = "When the rule fires", buffActive = "While the buff is present" }
local VIS_TRIGGER_ORDER = { "none", "condition", "buffActive" }
local TEXT_PLACE = { none = "(none - inner)", inner = "Inner (inside the edge)", outer = "Outer (outside the edge)" }
local TEXT_PLACE_ORDER = { "none", "inner", "outer" }
local TEXT_ANCHOR = { none = "(none - center)", CENTER = "Center", TOP = "Top", BOTTOM = "Bottom", LEFT = "Left", RIGHT = "Right",
    TOPLEFT = "Top left", TOPRIGHT = "Top right", BOTTOMLEFT = "Bottom left", BOTTOMRIGHT = "Bottom right" }
local TEXT_ANCHOR_ORDER = { "none", "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local TEXT_OUTLINE = { none = "None", outline = "Outline", thick = "Thick outline" }
local TEXT_OUTLINE_ORDER = { "none", "outline", "thick" }
local JUSTIFY = { none = "(none - left)", LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
local JUSTIFY_ORDER = { "none", "LEFT", "CENTER", "RIGHT" }
local SHOW_COMBAT = { none = "(none - always)", yes = "Only in combat", no = "Only out of combat" }
local SHOW_COMBAT_ORDER = { "none", "yes", "no" }
local TEX_KIND = { none = "(none)", file = "Texture ID / path", atlas = "Atlas name (advanced)", spellicon = "Icon (from a spell or item)" }
ns.ICON_SRC = { auto = "Automatic: the icon of the first trigger", spell = "A spell (search or ID)", item = "An item (search or ID)", file = "My own icon file" }
ns.ICON_SRC_ORDER = { "auto", "spell", "item", "file" }
local TEX_KIND_ORDER = { "none", "file", "atlas", "spellicon" }

local function SpellName(id)
    if not id or id == 0 then return "" end
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and n then return n end
    return "|cffff5555(unknown spell ID)|r"
end

local function SpellTex(id)
    if not id or id == 0 then return 134400 end
    local ok, tx = pcall(C_Spell.GetSpellTexture, id)
    return (ok and tx) or 134400
end

-- A text box that suggests spells by name (popup list with icons, wired up by AttachSearch in the widget walker).
-- pick(id) is called with the chosen spell ID. get() is always empty so the box clears after a pick.
local function SearchBox(order, pick, name, kind)
    local item = kind == "item"
    return { type = "input", name = name or (item and "Search by item name" or "Search by spell name"), order = order, width = "double",
        desc = item and "Type part of an item name (every word, any order; * matches anything). A list with icons pops up; click one (or press Enter for the first) to fill in its item ID. Also accepts an ID. Finds items in your bags, bank, and worn gear, plus every item your game client has already seen; an item it has never loaded will not appear, so type its ID instead (Wowhead shows it in the URL)."
            or "Type part of a name. A list with icons pops up; click one (or press Enter for the first) to fill in its ID. Also accepts an ID. Matches that belong to your class (every spec and hero tree) are listed first, each with what it is; small typos, missing spaces and words in any order still find them. Every spell ID that shares the name is listed, so pick the one that is the right kind.",
        arg = { xuiSearch = pick, xuiSearchKind = kind },
        get = function() return "" end, set = function() end }
end

local function SpellTip(id)
    if not id or id == 0 then return "Type a spell ID to see its icon and description." end
    local txt = SpellName(id) .. "  [" .. id .. "]"
    local ok, d = pcall(C_Spell.GetSpellDescription, id)
    if ok and type(d) == "string" and d ~= "" then txt = txt .. "\n\n" .. d end
    return txt
end

local function DetectedMax(id)
    if not id or id == 0 then return "" end
    local ok, ch = pcall(C_Spell.GetSpellCharges, id)
    if ok and type(ch) == "table" then
        local m = ch.maxCharges
        if m ~= nil and not ns.IsSecret(m) then return "Detected max charges: " .. tostring(m) end
    end
    return "Detected: not a charge spell"
end

-- Sounds (built once; restart the client after adding files)
local soundList, soundValues, soundSorting
local function EnsureSounds()
    if soundList then return end
    soundList, soundValues, soundSorting = ns.BuildSoundList(), {}, {}
    for i, it in ipairs(soundList) do
        local k = tostring(i)
        soundValues[k] = it.label
        soundSorting[i] = k
    end
    soundValues["0"] = "(none)"
    table.insert(soundSorting, 1, "0")
end

-- Texture presets (Blizzard alert art, with inline preview icons)
-- Preview size in the "Or pick art" lists (was 22 px): icon height, and the row is a little taller. Skin.lua lays the rows out.
ns.TEX_PICK_ICON, ns.TEX_PICK_ROW = 56, 60
local texValues, texSorting
local function EnsureTextures()
    if texValues then return end
    texValues, texSorting = {}, {}
    for i, t in ipairs(ns.TextureList or {}) do
        local k = tostring(t[1])
        texValues[k] = ("|T%d:%d:%d|t  %s"):format(t[1], ns.TEX_PICK_ICON, ns.TEX_PICK_ICON, t[2])
        texSorting[i] = k
    end
    texValues["0"] = "(none)"
    table.insert(texSorting, 1, "0")
    -- local graphics (Media\\Graphics, from LocalGraphics.lua); the stored value is the file path
    for _, g in ipairs(ns.LocalGraphics or {}) do
        local gw = math.min(ns.TEX_PICK_ICON * 2, math.max(8, math.floor(ns.TEX_PICK_ICON * (g[3] or 1) / math.max(1, g[4] or 1) + 0.5)))   -- keep the picture's proportions
        texValues[g[2]] = ("|T%s:%d:%d|t  %s"):format(g[2], ns.TEX_PICK_ICON, gw, g[1])
        texSorting[#texSorting + 1] = g[2]
    end
end

-- Specs of the current class
local function SpecValues()
    local v, order = { ["0"] = "(none - any spec)" }, { "0" }
    local n = (GetNumSpecializations and GetNumSpecializations()) or 0
    for i = 1, n do
        local id, name
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
            id, name = C_SpecializationInfo.GetSpecializationInfo(i)
        elseif GetSpecializationInfo then
            id, name = GetSpecializationInfo(i)
        end
        if id then v[tostring(id)] = name or tostring(id); order[#order + 1] = tostring(id) end
    end
    return v, order
end

-- Multi-select tick boxes for Specialization / Role. Storage: rule.load.specs {[specID]=true} and
-- rule.load.roles {[ROLE]=true}; an EMPTY set means "All" (no restriction). The "All" box shows every box ticked.
local function SpecChoices()
    local list = {}
    local n = (GetNumSpecializations and GetNumSpecializations()) or 0
    for i = 1, n do
        local id, name, icon, _
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
            id, name, _, icon = C_SpecializationInfo.GetSpecializationInfo(i)
        elseif GetSpecializationInfo then
            id, name, _, icon = GetSpecializationInfo(i)
        end
        if id then
            list[#list + 1] = { key = i .. ":" .. id, id = tostring(id),
                text = (icon and ("|T" .. icon .. ":18:18|t  ") or "") .. (name or tostring(id)) }
        end
    end
    return list
end
-- Hero talent specializations of the character's class (every spec's trees, de-duplicated). Needs the talent data to be loaded;
-- right after the first login it can be empty until a /reload.
function ns.HeroChoices()
    local list, seen = {}, {}
    if not (C_ClassTalents and C_ClassTalents.GetHeroTalentSpecsForClassSpec) then return list end
    local cfg = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    local n = (GetNumSpecializations and GetNumSpecializations()) or 0
    for i = 1, n do
        local sid
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then sid = C_SpecializationInfo.GetSpecializationInfo(i)
        elseif GetSpecializationInfo then sid = GetSpecializationInfo(i) end
        local okH, ids = pcall(C_ClassTalents.GetHeroTalentSpecsForClassSpec, cfg, sid)
        if okH and type(ids) == "table" then
            for _, id in ipairs(ids) do
                if not seen[id] then
                    seen[id] = true
                    local info = cfg and C_Traits and C_Traits.GetSubTreeInfo and C_Traits.GetSubTreeInfo(cfg, id)
                    local icon = info and info.iconElementID
                    list[#list + 1] = { key = "h" .. id, id = tostring(id),
                        text = ((type(icon) == "string" and icon ~= "") and ("|A:" .. icon .. ":18:18|a  ") or "") .. ((info and info.name) or ("Hero talents " .. id)) }
                end
            end
        end
    end
    return list
end
local ROLE_TEX = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:18:18:0:0:64:64:%s|t  %s"
local function RoleChoices()
    return {
        { key = "1_TANK",    id = "TANK",    text = ROLE_TEX:format("0:19:22:41", "Tank") },
        { key = "2_HEALER",  id = "HEALER",  text = ROLE_TEX:format("20:39:1:20", "Healer") },
        { key = "3_DAMAGER", id = "DAMAGER", text = ROLE_TEX:format("20:39:22:41", "Damage") },
    }
end
-- Three-click tick boxes: click 1 = selected, click 2 = NOT (must NOT be this), click 3 = back to unselected.
-- Stored per key in a set: true = selected, "not" = NOT. Nothing stored anywhere = "All" (no restriction); while
-- no box is selected, every box (bar the NOT ones) displays as ticked.
-- Specialization / Role: a tick box heading that reveals square single-choice boxes (click the chosen one again to
-- clear it) with "All" at the bottom. Nothing chosen = no restriction, same as before. `ld()` returns rule.load;
-- useKey (specUse / roleUse) = false makes the saved choice ignored without deleting it.
-- rule + bannerKey are optional: when given, the choice list opens/closes exactly like the Talent list (the same
-- bannerOpen table and ns.ArrowToggle +/- button), and unticking "use" clears the choices below instead of only
-- disabling them - so a rule that shows "All" really has nothing recorded, not a hidden leftover pick.
local bannerOpen = setmetatable({}, { __mode = "k" })   -- hoisted: ns.RadioGroup below uses it
function ns.RadioGroup(name, order, hiddenFn, getSet, choices, onChange, ld, useKey, rule, bannerKey)
    local function isOn()
        local u = ld()[useKey]
        if u == nil then return ns.SetActive(getSet()) end
        return u and true or false
    end
    local body = {}
    for i, ch in ipairs(choices) do
        body["c" .. i] = { type = "toggle", order = i, width = "full", name = ch.text,
            desc = "Click to choose only this one. Click it again to clear the choice.",
            get = function() return getSet()[ch.id] == true end,
            set = function(_, v) local s = getSet(); wipe(s); if v then s[ch.id] = true end; onChange() end }
    end
    body.all = { type = "toggle", order = 100, width = "full", name = "All",
        desc = "Any is fine (no restriction). Nothing chosen means the same; this just states it.",
        get = function() return getSet()["*"] == true end,
        set = function(_, v) local s = getSet(); wipe(s); if v then s["*"] = true end; onChange() end }
    local useArg = { type = "toggle", order = 1, width = "full", name = name,
        desc = "Tick to restrict this rule by " .. name:lower() .. ". The choices open below once ticked, same as the Talent list. Unticking clears them and removes the restriction: this rule then fires for any " .. name:lower() .. ".",
        get = isOn,
        set = function(_, v)
            ld()[useKey] = v and true or false
            if v then
                if rule and bannerKey then bannerOpen[rule] = bannerOpen[rule] or {}; bannerOpen[rule][bannerKey] = nil end
            else
                wipe(getSet())
            end
            onChange()
        end }
    if rule and bannerKey then
        local arrow = ns.ArrowToggle(rule, bannerKey, 1.5)
        arrow.hidden = function() return not isOn() end
        return { type = "group", inline = true, name = "", order = order, hidden = hiddenFn, args = {
            use = useArg,
            open = arrow,
            pane = { type = "group", inline = true, name = "", order = 2,
                hidden = function() return not (isOn() and ns.ArrowOpen(rule, bannerKey)) end, args = body },
        } }
    end
    return { type = "group", inline = true, name = "", order = order, hidden = hiddenFn, args = {
        use = useArg,
        pane = ns.GatedPane(ld(), "radio_" .. useKey, name .. " choices", 2, isOn, body),
    } }
end

local function TriGroup(name, order, hiddenFn, getSet, choices, onChange)
    local function hasOn(set) for _, v in pairs(set) do if v == true then return true end end return false end
    local args = {
        all = { type = "toggle", name = "All", order = 0, width = "double",
            desc = "No restriction. Click a box below once to select it, twice for NOT, a third time to clear it.",
            get = function() return next(getSet()) == nil end,
            set = function(_, v) if v then wipe(getSet()) end onChange() end },
    }
    for i, ch in ipairs(choices) do
        args["c" .. i] = { type = "toggle", tristate = true, order = i, width = "double",
            desc = "Click: selected. Click again: NOT (must not be this). Click again: cleared.",
            name = function()
                if getSet()[ch.id] == "not" then return "|cffff5555NOT|r  " .. ch.text end
                return ch.text
            end,
            get = function()
                local set = getSet()
                local st = set[ch.id]
                if st == true then return true end
                if st == "not" then return nil end
                if not hasOn(set) then return true end
                return false
            end,
            set = function(_, v)
                local set = getSet()
                if v == true then set[ch.id] = true
                elseif v == nil then set[ch.id] = "not"
                else set[ch.id] = nil end
                onChange()
            end }
    end
    return { type = "group", inline = true, name = name, order = order, hidden = hiddenFn, args = args }
end

-------------------------------------------------------------------------------
-- Gated panes. Options that only matter while something is switched on live in a collapsible pane that is not
-- drawn at all until that switch is on (arrow header = expand / collapse; open by default; session-only; never
-- changes a setting). ns.GatedPane builds one, ns.GatePane moves named options of an existing args table into
-- one, ns.GateRest moves everything except the listed keys. `owner` is any table that identifies whose pane it
-- is (a rule, a bar, ns), so every rule / bar remembers its own open / closed state.
-- The header's desc must keep starting with "Expand or collapse": ns.LockArgs leaves those controls usable.
-- Moving an option into a pane drops its old `disabled` (the pane not being drawn replaces it).
-------------------------------------------------------------------------------
do
    local shut = setmetatable({}, { __mode = "k" })
    local OPEN = "|TInterface\\Buttons\\Arrow-Down-Up:16:16|t"
    local CLOSED = "|TInterface\\ChatFrame\\ChatFrameExpandArrow:16:16|t"
    function ns.GatedPane(owner, id, title, order, gate, args)
        local function isShut() return shut[owner] and shut[owner][id] and true or false end
        return { type = "group", inline = true, name = "", order = order,
            hidden = function() return not gate() end,
            args = {
                hdr = { type = "execute", order = 1, width = "full",
                    arg = { xuiLeft = true, xuiArrowLeft = true, xuiArrow = function() return not isShut() end },
                    name = function()
                        if ns.SkinRows and ns.SkinRows() then return title end   -- skin draws a vertically centered arrow itself
                        return (isShut() and CLOSED or OPEN) .. "  " .. title
                    end,
                    desc = "Expand or collapse this section. Collapsing never changes any setting.",
                    func = function()
                        shut[owner] = shut[owner] or {}
                        shut[owner][id] = (not isShut()) or nil
                        Notify()
                    end },
                body = { type = "group", inline = true, name = "", order = 2, hidden = isShut, args = args },
            } }
    end
    local function Move(owner, args, id, title, order, gate, keys)
        local body = {}
        for _, k in ipairs(keys) do
            local opt = args[k]
            if opt then opt.disabled = nil; body[k] = opt; args[k] = nil end
        end
        args["pane_" .. id] = ns.GatedPane(owner, id, title, order, gate, body)
    end
    function ns.GatePane(owner, args, id, title, order, gate, keys) Move(owner, args, id, title, order, gate, keys) end
    function ns.GateRest(owner, args, id, title, order, gate, keep)
        local keys = {}
        for k in pairs(args) do if not keep[k] then keys[#keys + 1] = k end end
        Move(owner, args, id, title, order, gate, keys)
    end
end

-------------------------------------------------------------------------------
-- Status text (used by the Info tab and the debug tray)
-------------------------------------------------------------------------------
local function tf(v) if v == nil then return "|cffffaa00unknown|r" end return v and "|cff55ff55OK|r" or "|cffff5555no|r" end

local function StatusText(rule)
    local rt = ns.runtime and ns.runtime[rule]
    local info = rt and rt.info
    if not info then return "not evaluated yet (is the rule enabled?)" end
    local c = info.ctx or {}
    local cdWhy = info.cd and info.cd.why or "?"
    local pvw = (ns.IsPreview(rule, "visual") or ns.IsPreview(rule, "sound")) and "|cff33ccffPREVIEW ON (temporary)|r\n" or ""
    local warn = ""
    if info.missing and #info.missing > 0 then
        warn = "|cffffaa00Choose before this rule can fire: " .. table.concat(info.missing, ", ") .. "|r\n"
    end
    warn = pvw .. warn
    return warn .. table.concat({
        (info.result and "|cff55ff55FIRING|r" or "idle") .. "   " .. rule.name,
        "cooldown " .. tf(info.cdOK) .. "  (" .. cdWhy .. ")",
        "buff " .. tf(info.buffOK) .. "  present=" .. tostring(info.present) .. "  via " .. tostring(info.buffSource),
        "talent " .. tf(info.talentOK) .. "  (" .. tostring(info.talentDetail) .. ")   load " .. tf(info.ctxOK)
            .. (info.ctxFail and ("  failed: " .. info.ctxFail) or ""),
        ("ctx: combat=%s group=%s raid=%s instance=%s(%s) M+=%s encounter=%s mounted=%s spec=%s role=%s"):format(
            tostring(c.combat), tostring(c.group), tostring(c.raid), tostring(c.instance), tostring(c.instanceType),
            tostring(c.mythicPlus), tostring(c.encounter), tostring(c.mounted), tostring(c.specID), tostring(c.role)),
    }, "\n")
end

-------------------------------------------------------------------------------
-- Small option builders
-------------------------------------------------------------------------------
local function Col(t, k, name, order, on, extra)
    local o = { type = "color", name = name, order = order, hasAlpha = true,
        get = function() local c = t[k] or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] or 1 end,
        set = function(_, r, g, b, a) t[k] = { r, g, b, a }; on() end }
    if extra then for kk, vv in pairs(extra) do o[kk] = vv end end
    return o
end
local function Rng(t, k, name, order, min, max, step, on, extra)
    local o; o = { type = "range", name = name, order = order, min = min, max = max, step = step,
        get = function() if t[k] ~= nil then return t[k] end if o.def ~= nil then return o.def end return min end, set = function(_, v) t[k] = v; on() end }   -- def: what the engine uses when the value was never set
    if extra then for kk, vv in pairs(extra) do o[kk] = vv end end
    return o
end
local function Tog(t, k, name, order, on, extra)
    local o = { type = "toggle", name = name, order = order,
        get = function() return t[k] and true or false end, set = function(_, v) t[k] = v; on() end }
    if extra then for kk, vv in pairs(extra) do o[kk] = vv end end
    return o
end
-- width / height sliders that move together while "Maintain aspect ratio" (V.keepAspect, on by default) is not switched off
function ns.AspectSet(V, key, other, on)
    return function(_, val)
        local kw, ow = V[key] or 128, V[other] or 128
        if V.keepAspect ~= false and kw > 0 then
            local ratio = ow / kw
            local nv = val * ratio
            if nv > 512 then nv = 512; val = nv / ratio elseif nv < 8 then nv = 8; val = nv / ratio end
            V[key], V[other] = math.min(512, math.max(8, math.floor(val + 0.5))), math.floor(nv + 0.5)
        else
            V[key] = val
        end
        on()
    end
end
local function Sel(t, k, name, order, vals, ord, on, extra)
    local o = { type = "select", name = name, order = order, values = vals, sorting = ord,
        get = function() return t[k] end, set = function(_, v) t[k] = v; on() end }
    if extra then for kk, vv in pairs(extra) do o[kk] = vv end end
    return o
end
-- Shared option builders for other files (Triggers.lua builds its rows with these). A table, so no new top-level local.
-- a rebuild that grows or shrinks the page needs a second pass a moment later, or the scroll area keeps its old height (content clips, no scrollbar)
ns.UI = { NotifyTwice = function() Notify() end, Sel = Sel, Rng = Rng, Tog = Tog, Changed = Changed, Notify = Notify, SpellName = SpellName, SpellTex = SpellTex, SearchBox = SearchBox }

-- Cooldown "State" dropdown. For a spell the game positively reports as having NO charges, the list is shortened to
-- the two states that exist for it ("Cooldown ready" / "On cooldown"). They are the same stored values as before
-- (ready / empty), so saved rules, exports and outcomes are unchanged. Charge spells, spells whose charge data
-- cannot be read, and an unset spell keep the full list.
function ns.IsNoChargeSpell(rule)
    local id = tonumber(rule.spellID) or 0
    if id == 0 or (tonumber(rule.maxCharges) or 0) > 1 then return false end
    local ok, ch = pcall(C_Spell.GetSpellCharges, id)
    if not ok then return false end
    if ch == nil then return true end                      -- the game returns nothing for a spell without charges
    if type(ch) ~= "table" then return false end
    local okm, m = pcall(function() return ch.maxCharges end)
    if not okm or m == nil or ns.IsSecret(m) or type(m) ~= "number" then return false end
    return m < 2
end
function ns.CdStateSelect(rule, on)
    local single = {
        none = CD_VALUES.none,
        ready = "Cooldown ready  (off cooldown)",
        empty = "On cooldown",
        hasCharge = "Has a charge / available  (same as 'Cooldown ready' for this spell)",
        notReady = "Not fully ready  (same as 'On cooldown' for this spell)",
    }
    local o = Sel(rule, "cdState", "State", 4,
        function() return ns.IsNoChargeSpell(rule) and single or CD_VALUES end,
        function()
            if not ns.IsNoChargeSpell(rule) then return CD_ORDER end
            local ord = { "none", "ready", "empty" }
            -- an older rule may still hold one of the two redundant values: keep it visible so the box is not blank
            if rule.cdState == "hasCharge" or rule.cdState == "notReady" then ord[#ord + 1] = rule.cdState end
            return ord
        end,
        on, { width = "double" })
    o.desc = "For a spell WITHOUT charges: 'Cooldown ready' = its cooldown is not running (the global cooldown is ignored); " ..
             "'On cooldown' = its own cooldown is running. Spells with charges show the full list."
    return o
end
-- Mutually exclusive choice drawn as SQUARE check boxes (AceConfig's own radio style draws round buttons).
-- Adds one toggle per choice to `args` as <prefix>_<i>; ticking one unticks the others; clicking the ticked one does nothing.
-- Returns the list of generated keys.
local function AddSquareRadio(args, prefix, order, values, ord, getV, setV, opts)
    opts = opts or {}
    local keys = {}
    for i, k in ipairs(ord) do
        local key = prefix .. "_" .. i
        keys[#keys + 1] = key
        args[key] = { type = "toggle", order = order + i * 0.01, width = "full", name = values[k], desc = opts.desc,
            hidden = opts.hidden,
            get = function() return getV() == k end,
            set = function(_, v) if v then setV(k) end end }
    end
    return keys
end
local function FontSel(t, order, on)
    return { type = "select", name = "Font", order = order,
        values = function() local v = ns.FontList(); return v end,
        sorting = function() local _, o = ns.FontList(); return o end,
        get = function() return t.font end, set = function(_, v) t.font = v; on() end }
end

-- Shared text styling controls (font, size, outline, placement, offsets, color)
local function TextStyleArgs(t, on, base, opts)
    opts = opts or {}
    local a = {}
    a.font = FontSel(t, base + 1, on)
    a.size = Rng(t, "size", "Text size", base + 2, 6, 96, 1, on)
    a.outline = Sel(t, "outline", "Outline", base + 3, TEXT_OUTLINE, TEXT_OUTLINE_ORDER, on)
    a.color = Col(t, "color", "Text color", base + 4, on)
    a.place = Sel(t, "place", "Placement", base + 5, TEXT_PLACE, TEXT_PLACE_ORDER, on,
        { desc = "Inner: inside the texture edge. Outer: outside it (not applicable to Center)." })
    a.anchor = Sel(t, "anchor", "Position", base + 6, TEXT_ANCHOR, TEXT_ANCHOR_ORDER, on)
    a.x = Rng(t, "x", "X offset", base + 7, -200, 200, 1, on)
    a.y = Rng(t, "y", "Y offset", base + 8, -200, 200, 1, on)
    return a
end

-------------------------------------------------------------------------------
-- Rule group
-------------------------------------------------------------------------------
local function FolderById(id)
    for _, f in ipairs(ns.folders or {}) do if f.id == id then return f end end
end
-- folders from the top level down to f (cycle-safe)
local function FolderChain(f)
    local chain, seen = {}, {}
    while f and not seen[f.id] do
        seen[f.id] = true
        table.insert(chain, 1, f)
        f = f.parent and FolderById(f.parent) or nil
    end
    return chain
end
-- is folder fid equal to, or nested anywhere inside, folder ancestorId?
local function IsInFolder(fid, ancestorId)
    local f, seen = FolderById(fid), {}
    while f and not seen[f.id] do
        if f.id == ancestorId then return true end
        seen[f.id] = true
        f = f.parent and FolderById(f.parent) or nil
    end
    return false
end
local function FolderRules(fid)
    local l = {}
    for _, r in ipairs(ns.rules or {}) do if r.folder and IsInFolder(r.folder, fid) then l[#l + 1] = r end end
    return l
end
-- Display / Sound / Hybrid / Advanced Cue Tracking default folders are sub-sections of Smart Categories inside All Rules
function ns.CueTop(c)
    return c and not c.parent and (c.default == "display" or c.default == "sound" or c.default == "hybrid" or c.default == "advanced") and true or false
end
-- Loaded / Not Loaded show only the user's own groups. The default cue categories (Display Cues, Sound Cues, ...) and the cue-type
-- folders directly inside them (Icons, Progress Textures, ...) are not drawn there: rules in them are listed in the group that is left.
function ns.CueTransparent(f)
    if not f then return false end
    if ns.CueTop(f) then return true end
    if f.default == "display" or f.default == "sound" or f.default == "hybrid" or f.default == "advanced" or f.default == "cursor" then return true end
    do   -- a default category that lost its flag (renamed / re-created) is still recognized by its name
        local nm0 = tostring(f.name or ""):lower()
        if not f.parent then
            for _, d in ipairs(ns.DEFAULT_FOLDERS or {}) do if d.name:lower() == nm0 then return true end end
        end
    end
    local p = f.parent and ns.FolderById and ns.FolderById(f.parent)
    if p and ns.CueTop(p) then
        local nm = tostring(f.name or ""):lower()
        for _, c in ipairs(ns.SMART_CATS or {}) do if c.name:lower() == nm then return true end end
        if nm == "sounds" or nm == "sound cues" or nm == "display cues" then return true end
    end
    return false
end
-- Rules sub-tabs (2026-11-01): Rules > Enabled | Smart Categories | Drafts | Disabled | Recycle Bin.
-- Disabled = the rule's enabled box is unticked, or its load mode is "never". Everything else is Enabled and is split into Loaded / Not Loaded.
function ns.RuleDisabled(r) return (not r.enabled) or (r.load and r.load.mode == "never") or false end
function ns.RuleScope(r, ctx)   -- "disabled" | "loaded" | "notloaded"
    if ns.RuleDisabled(r) then return "disabled" end
    return (ctx and ns.IsLoaded(r, ctx)) and "loaded" or "notloaded"
end
function ns.CurrentSub()   -- the open sub-tab under Rules
    if not AceConfigDialog.GetStatusTable then return "enabledTab" end
    local rt = AceConfigDialog:GetStatusTable(APP, { "cooldowns" })
    return (rt and rt.groups and rt.groups.selected) or "enabledTab"
end
function ns.SaveRulesSub()   -- remembered for next time the window opens
    local ui = CueRulesDB and CueRulesDB.ui
    if ui and AceConfigDialog.GetStatusTable then ui.rulesSub = ns.CurrentSub() end
end
function ns.ScopePath(r, ctx)   -- where a rule's row is in the Enabled / Disabled lists
    local sc = ns.RuleScope(r, ctx)
    local p = { "cooldowns", sc == "disabled" and "disabledTab" or "enabledTab", sc }
    local f = r.folder and FolderById(r.folder)
    if f then for _, c in ipairs(FolderChain(f)) do if not ns.CueTransparent(c) then p[#p + 1] = c.id end end end
    for idx, rr in ipairs(ns.rules or {}) do if rr == r then p[#p + 1] = "rule" .. idx; break end end
    return unpack(p)
end
-- Smart Categories shows only the types: its root row and the "by type" row are drawn collapsed to nothing (Options.lua DecorateButton),
-- so both must stay open or the type rows would vanish.
function ns.SmartOpen()
    if not AceConfigDialog.GetStatusTable then return end
    local st = AceConfigDialog:GetStatusTable(APP, { "cooldowns", "smartTab" })
    if not st then return end
    st.groups = st.groups or {}
    st.groups.groups = st.groups.groups or {}
    st.groups.groups["all"] = true
    st.groups.groups["all\001smart"] = true
end
-- Where the tree status of the Rules tab lives (selection + which rows are open)
function ns.RulesTreeStatus()
    if not AceConfigDialog.GetStatusTable then return nil end
    local sub = ns.CurrentSub()
    if sub ~= "smartTab" and sub ~= "disabledTab" then sub = "enabledTab" end
    local t = AceConfigDialog:GetStatusTable(APP, { "cooldowns", sub })
    return t and t.groups
end
-- When a rule's loaded state changes while it is selected in Loaded / Not Loaded, its row moves to the other list. Move the selection
-- with it BEFORE the tree is rebuilt, so the editing pane stays open instead of falling back to the first row of the list.
function ns.FixSelection()
    local S = ns.RulesTreeStatus()
    local sel = S and S.selected
    if type(sel) ~= "string" then return end
    local segs = {}
    for seg in sel:gmatch("[^\001]+") do segs[#segs + 1] = seg end
    if segs[1] ~= "loaded" and segs[1] ~= "notloaded" and segs[1] ~= "disabled" then return end
    local rn = tostring(segs[#segs]):match("^rule(%d+)$")
    local r = rn and ns.rules and ns.rules[tonumber(rn)]
    if not r then return end
    local okc, ctx = pcall(ns.ReadContext)
    if not okc then return end
    local now = ns.RuleScope(r, ctx)
    if now == segs[1] then return end
    if now == "disabled" or segs[1] == "disabled" then
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, ns.ScopePath(r, ctx))   -- the rule moved to the other sub-tab: follow it
    else segs[1] = now; S.selected = table.concat(segs, "\001") end
end
-- Select a row after an edit / move WITHOUT touching the sidebar's open / closed state and without leaving the list the user is in.
-- (AceConfigDialog:SelectGroup normally opens every group on the way, which popped All Rules open.) Takes the same path
-- RulePath / FolderPath return.
function ns.SelectKeep(...)
    local args = { ... }
    local S = ns.RulesTreeStatus()
    local open = S and S.groups
    local snap = {}
    if open then for kk, vv in pairs(open) do snap[kk] = vv end end
    local scope = (ns.CurrentSub() == "smartTab") and "all" or (ns.ScopeOfUV and ns.ScopeOfUV(S and S.selected) or "all")
    if (scope == "loaded" or scope == "notloaded" or scope == "disabled") and args[1] == "cooldowns" and args[2] == "smartTab" and args[3] == "all" then
        local newScope = scope
        local rn = tostring(args[#args]):match("^rule(%d+)$")
        local r = rn and ns.rules and ns.rules[tonumber(rn)]
        if r then
            local okc, ctx = pcall(ns.ReadContext)
            if okc then newScope = ns.RuleScope(r, ctx) end
        end
        local p = { "cooldowns", newScope == "disabled" and "disabledTab" or "enabledTab", newScope }
        for i = 4, #args do
            local a = args[i]
            local f = tostring(a):match("^f%d") and ns.FolderById(a)
            if a ~= "smart" and not (f and ns.CueTransparent(f)) then p[#p + 1] = a end
        end
        args = p
    end
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, unpack(args))
    if open then
        for kk in pairs(open) do if snap[kk] == nil then open[kk] = nil end end   -- close what SelectGroup opened
        for kk, vv in pairs(snap) do open[kk] = vv end
    end
end
local function FolderPath(f)
    local p = { "cooldowns", "smartTab", "all" }
    local chain = FolderChain(f)
    if ns.CueTop(chain[1]) then p[#p + 1] = "smart" end
    for _, c in ipairs(chain) do p[#p + 1] = c.id end
    return unpack(p)
end

-- Which list a sidebar row belongs to: "loaded", "notloaded" or "all" (first path segment under the Rules tab)
function ns.ScopeOfUV(uv)
    local seg = uv and tostring(uv):match("^([^\001]+)")
    return (seg == "notloaded" or seg == "all" or seg == "disabled") and seg or "loaded"
end
function ns.CurrentScope()
    if not AceConfigDialog.GetStatusTable then return "loaded" end
    local g = ns.RulesTreeStatus()
    return ns.ScopeOfUV(g and g.selected)
end
-- A new, still-empty group is listed in the list it was created from (empty groups default to Loaded)
function ns.PlaceNewGroup(f, scope)
    f.xuiScope = (scope == "notloaded" or scope == "disabled") and scope or nil
    local root = (scope == "notloaded" or scope == "all" or scope == "disabled") and scope or "loaded"
    local p = { "cooldowns", (root == "all") and "smartTab" or (root == "disabled" and "disabledTab" or "enabledTab"), root }
    local chain = FolderChain(f)
    if root == "all" and ns.CueTop(chain[1]) then p[#p + 1] = "smart" end
    for _, c in ipairs(chain) do if root == "all" or not ns.CueTransparent(c) then p[#p + 1] = c.id end end
    return unpack(p)
end
-- Same group, reached through the Loaded list (new groups open here so they show highlighted under Loaded)
function ns.FolderLoadedPath(f)
    local p = { "cooldowns", "enabledTab", "loaded" }
    for _, c in ipairs(FolderChain(f)) do if not ns.CueTransparent(c) then p[#p + 1] = c.id end end
    return unpack(p)
end

-- The built-in category folders (Display Cues, Sound Cues, ...) are Smart Categories' territory: nothing may be placed into them by hand.
function ns.IsCategoryRoot(f) return f and f.default ~= nil and not f.parent end

local function FolderValues()
    -- depth-first: every group is listed right under its parent, indented one step per level; category buckets and cue-type
    -- folders are never listed (their children are shown as if they sat one level up)
    local v, o = { none = "(none - top level)" }, { "none" }
    local kids = {}
    for _, f in ipairs(ns.folders or {}) do
        local p = f.parent or false
        kids[p] = kids[p] or {}
        kids[p][#kids[p] + 1] = f
    end
    local seen = {}
    local function walk(pid, depth)
        for _, f in ipairs(kids[pid] or {}) do
            if not seen[f.id] then
                seen[f.id] = true
                local hidden = ns.IsCategoryRoot(f) or ns.CueTransparent(f)
                if not hidden then
                    v[f.id] = string.rep("      ", depth) .. (depth > 0 and "|cff888888-|r " or "") .. tostring(f.name)
                    o[#o + 1] = f.id
                end
                walk(f.id, hidden and depth or depth + 1)
            end
        end
    end
    walk(false, 0)
    return v, o
end

-- Which top tab is open now ("cooldowns" = Rules, "smartcat" = Smart Categories ...), and "go back to where I was".
function ns.CurrentTab()   -- "smartcat" stands for Rules > Smart Categories, "cooldowns" for the Enabled / Disabled lists
    local root = AceConfigDialog.GetStatusTable and AceConfigDialog:GetStatusTable(APP)
    local top = root and root.groups and root.groups.selected
    if top == "cooldowns" and ns.CurrentSub() == "smartTab" then return "smartcat" end
    return top
end
function ns.GoHome(tab)
    tab = tab or ns.CurrentTab()
    if tab == "cooldowns" then pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "enabledTab", "loaded")
    else pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "smartTab", "all") end
end

local function RulePath(rule)
    for idx, r in ipairs(ns.rules) do
        if r == rule then
            -- Smart Categories lists a rule under each type it matches (the tree has no folder rows there)
            if ns.pickOrigin ~= "cooldowns" then
                for _, c in ipairs(ns.SMART_CATS) do
                    if c.key ~= "smart_bar" and ns.SmartMatch(r, c.key) then return "cooldowns", "smartTab", "all", "smart", c.key, "rule" .. idx end
                end
            end
            -- no display type: it lives in Loaded / Not Loaded, nested under its (non-transparent) groups
            local okc, ctx = pcall(ns.ReadContext)
            return ns.ScopePath(r, okc and ctx or nil)
        end
    end
    return "cooldowns", "smartTab", "all"
end

-- Keep the editing pane open on a rule after its list row may have moved or vanished. A rule's row in Smart Categories comes from
-- its cues, so deleting its last cue of a type removes the row it was selected through; without this the pane falls back to another page.
function ns.ReselectRule(rule)
    if not rule then return end
    pcall(function()
        local S = ns.RulesTreeStatus()
        local oldSel = S and S.selected
        local newPath = { RulePath(rule) }
        if oldSel == table.concat(newPath, "\001") then return end   -- the row did not move: the pane stays exactly as it is
        -- the row moved (deleting a rule's last cue of a type removes the row it was selected through): follow it, and keep the same tab open
        local tab
        if type(oldSel) == "string" then
            local segs = {}
            for seg in oldSel:gmatch("[^\001]+") do segs[#segs + 1] = seg end
            local st = AceConfigDialog:GetStatusTable(APP, segs)
            tab = st and st.groups and st.groups.selected
        end
        ns.SelectKeep(unpack(newPath))
        if tab then
            local st2 = AceConfigDialog:GetStatusTable(APP, newPath)
            if st2 then st2.groups = st2.groups or {}; st2.groups.selected = tab end
        end
    end)
end

-------------------------------------------------------------------------------
-- Copy / paste settings between rules (choose exactly which sections; nothing is pasted by default)
-------------------------------------------------------------------------------
local ruleClip = nil          -- { name = "...", data = <deep copy of the source rule> }
local pasteSel = {}           -- section key -> true (shared by the Info tab, folder pages and the right-click menu)
-- Paste Settings is a tree: every leaf is one section (a tick box); a branch has "All of ..." plus its leaves. Leaves keep short keys.
-- Visual leaves list the cue-display keys they copy; "vTex" is the catch-all for every other display key (texture art etc.).
ns.PASTE_VIS = {
    vSize    = { "w", "h", "iconW", "iconH", "keepAspect", "zoom" },
    vColor   = { "alpha", "texAlpha", "oocAlpha", "recolor", "desaturate", "tint", "additive", "desatOnCD" },
    vRotate  = { "rotation", "flipH", "flipV" },
    vFade    = { "fadeGrey", "fadeMode", "fadeColor", "fadeAlpha", "fadeAlphaMin", "fadeAlphaMax" },
    vFlash   = { "flash" },
    vFill    = { "fill" },
    vOverlay = { "overlay" },
    vGlow    = { "glow" },
    vOutline = { "outline" },
    vBorder  = { "border", "bg" },
    vOnBar   = { "requireOnBar" },
}
ns.PASTE_VIS_SKIP = { text = true, count = true, absorb = true, x = true, y = true, anchor = true, anchorPlace = true }
ns.PASTE_TREE = {
    { "Triggers", {
        { "Cooldown trigger", {
            { "idsCd", "Spell ID and Max Charges" }, { "stCd", "Cooldown State" } } },
        { "Buff / Aura trigger", {
            { "idsBuff", "Aura ID" }, { "stBuff", "Buff State" } } },
        { "extra", "Additional Triggers (whole list + combine mode)" },
        { "XROWS" },
        { "activation", "Activation mode + trigger order" },
        { "talents", "Talents (requirement mode + list)" },
    } },
    { "load", "Load Conditions" },
    { "actions", "Actions (chat message, glow, custom code)" },
    { "conditions", "Conditions (list + the cues each fires)" },
    { "Cues", {
        { "cues", "Cue list (replaces the rule's cues)" },
        { "Display", {
            { "vTex", "Texture / art" }, { "vSize", "Size, aspect, zoom" }, { "vColor", "Color, tint, opacity" },
            { "vRotate", "Rotation and flip" }, { "vFade", "Fade (as the buff runs out)" }, { "vFlash", "Flash" },
            { "vFill", "Progress-bar wipe" }, { "vOverlay", "Overlay layer" }, { "vGlow", "Glow" },
            { "vOutline", "Outline" }, { "vBorder", "Border and background" }, { "vOnBar", "Only show while on an action bar" } } },
        { "position", "Position (X / Y)" },
        { "Text", {
            { "textDur", "Buff Duration" }, { "textCnt", "Stacks / Charges Count" }, { "textAbs", "Shield / Absorb Amount" } } },
        { "Audio", {
            { "sound", "Sound and Channel" }, { "sndRep", "Repeat" } } },
    } },
}
local PASTE_ORDER, PASTE_LABELS = {}, {}
do
    local function walk(list)
        for _, n in ipairs(list) do
            if type(n[2]) == "table" then walk(n[2])
            elseif n[2] then PASTE_ORDER[#PASTE_ORDER + 1] = n[1]; PASTE_LABELS[n[1]] = n[2] end
        end
    end
    walk(ns.PASTE_TREE)
end
local function PasteApply(key, dst, src)
    local C = ns.Copy
    if key == "idsCd" then
        dst.spellID, dst.maxCharges, dst.useCooldown, dst.cdName = src.spellID, src.maxCharges, src.useCooldown, src.cdName
    elseif key == "idsBuff" then
        dst.buffID, dst.useBuff, dst.buffName = src.buffID, src.useBuff, src.buffName
        dst.buffAlt = src.buffAlt and ns.Copy(src.buffAlt) or nil
    elseif key == "activation" then dst.trigMode, dst.trigOrder = src.trigMode, src.trigOrder and C(src.trigOrder) or nil
    elseif key == "actions" then dst.actions = src.actions and C(src.actions) or nil
    elseif key == "stCd" then dst.cdState = src.cdState
    elseif key == "stBuff" then dst.buffState = src.buffState
    elseif key == "talents" then dst.talents, dst.talentMode = C(src.talents or {}), src.talentMode
    elseif key == "extra" then dst.extra = C(src.extra or { list = {} })
    elseif key == "load" then dst.load = C(src.load or {})
    elseif key == "vTex" then
        local claimed = {}
        for _, ks in pairs(ns.PASTE_VIS) do for _, k in ipairs(ks) do claimed[k] = true end end
        for k, val in pairs(src.visual or {}) do
            if not claimed[k] and not ns.PASTE_VIS_SKIP[k] and not (dst.isCue and (k == "enabled" or k == "trigger")) then dst.visual[k] = C(val) end
        end
    elseif ns.PASTE_VIS[key] then
        for _, k in ipairs(ns.PASTE_VIS[key]) do
            if src.visual then dst.visual[k] = (src.visual[k] ~= nil) and C(src.visual[k]) or nil end
        end
    elseif key == "position" then dst.visual.x, dst.visual.y = src.visual.x, src.visual.y
    elseif key == "textDur" then dst.visual.text = C(src.visual.text)
    elseif key == "textCnt" then dst.visual.count = C(src.visual.count)
    elseif key == "textAbs" then dst.visual.absorb = C(src.visual.absorb)
    elseif key == "sound" then dst.sound = C(src.sound)
    elseif key == "sndRep" then dst.repeatSec = src.repeatSec end
end
local function PasteSelectedLabels()
    local l = {}
    for _, k in ipairs(PASTE_ORDER) do if pasteSel[k] then l[#l + 1] = PASTE_LABELS[k] end end
    for k in pairs(pasteSel) do if type(k) == "string" and k:match("^xr%d+$") then l[#l + 1] = "Additional trigger " .. k:sub(3) end end
    return l
end
local function PasteCount() local n = 0; for _, v in pairs(pasteSel) do if v then n = n + 1 end end return n end
-- Rules are split into a trigger side (the rule), CONDITIONS and CUES (hidden child rules, see Cues.lua / Outcomes.lua). A clip keeps all
-- three. ns functions, not locals: this file is near Lua's 200-locals limit.
function ns.MakeClip(rule)
    local clip = { name = rule.name, data = ns.Copy(rule), cues = {}, conds = {} }
    if rule.uid and not rule.parentUid and not rule.isCue then
        for _, c in ipairs(ns.CuesOf(rule)) do clip.cues[#clip.cues + 1] = ns.Copy(c) end
        for _, c in ipairs(ns.ConditionsOf(rule)) do clip.conds[#clip.conds + 1] = ns.Copy(c) end
    end
    return clip
end
function ns.PasteDropChildren(list)
    for _, c in ipairs(list) do
        for i, r in ipairs(ns.rules) do if r == c then table.remove(ns.rules, i); break end end
        pcall(ns.DropVisual, c)
    end
end
function ns.PasteCues(dst, clip)
    dst.uid = dst.uid or ns.NewUID()
    ns.PasteDropChildren(ns.CuesOf(dst))
    for _, c in ipairs(clip.cues) do
        local n = ns.Copy(c)
        n.uid, n.parentUid, n.folder = nil, dst.uid, dst.folder
        n.name = tostring(dst.name or "") .. " (cue)"
        ns.rules[#ns.rules + 1] = n
        pcall(ns.RefreshVisual, n)
    end
end
function ns.PasteConditions(dst, clip)
    dst.uid = dst.uid or ns.NewUID()
    ns.PasteDropChildren(ns.ConditionsOf(dst))
    for _, c in ipairs(clip.conds) do
        local n = ns.Copy(c)
        n.uid, n.parentUid, n.folder = nil, dst.uid, dst.folder
        ns.rules[#ns.rules + 1] = n
    end
end
-- a condition may only fire cues the rule really has; returns how many references had to be dropped
function ns.PasteCleanRefs(dst)
    local keys, dropped = {}, 0
    for _, c in ipairs(ns.CuesOf(dst)) do if c.cueKey then keys[c.cueKey] = true end end
    for _, cond in ipairs(ns.ConditionsOf(dst)) do
        if type(cond.thenCues) == "table" then
            local keep = {}
            for _, k in ipairs(cond.thenCues) do if keys[k] then keep[#keep + 1] = k else dropped = dropped + 1 end end
            cond.thenCues = (#keep > 0) and keep or nil
            ns.NormalizeCues(cond)
        end
    end
    return dropped
end
-- Appearance / audio sections go onto the cues of the target: each copied cue is matched with a cue of the SAME KIND in list order.
-- A rule with no cues (older rule) counts as one display / one sound. Returns pairs applied, copied parts left without a partner.
function ns.PasteLook(dst, clip, sel, apply)
    local VIS = { "vTex", "vSize", "vColor", "vRotate", "vFade", "vFlash", "vFill", "vOverlay", "vGlow", "vOutline", "vBorder", "vOnBar", "position", "textDur", "textCnt", "textAbs" }
    local wantVis = false
    for _, k in ipairs(VIS) do if sel[k] then wantVis = true end end
    if not wantVis and not sel.sound and not sel.sndRep then return 0, 0 end
    local function isSnd(c) return c.cueKind == "sound" or c.cueKind == "speech" end
    local function isVis(c) return c.cueKind ~= "sound" and c.cueKind ~= "speech" and c.cueKind ~= "custom" end
    local dCues = dst.uid and ns.CuesOf(dst) or {}
    local done, skipped = 0, 0
    local function run(pred, keys)
        local srcs, byKind = {}, {}
        for _, c in ipairs(clip.cues) do if pred(c) then srcs[#srcs + 1] = c end end
        if #clip.cues == 0 then srcs[1] = clip.data end
        for _, c in ipairs(dCues) do if pred(c) then local k = c.cueKind or "?"; byKind[k] = byKind[k] or {}; table.insert(byKind[k], c) end end
        local used = {}
        for _, s in ipairs(srcs) do
            local d
            if #clip.cues == 0 then   -- an older rule: its own display / sound goes to the target's first matching cue, or to the target itself
                if #dCues == 0 then d = dst else for _, c in ipairs(dCues) do if pred(c) then d = c; break end end end
            else
                local list = byKind[s.cueKind or "?"]
                local n = used[s.cueKind or "?"] or 0
                d = list and list[n + 1]
                used[s.cueKind or "?"] = n + 1
            end
            if not d and #clip.cues > 0 and dst.uid and not dst.isCue and s.cueKind and ns.NewCueRule then
                -- the copied rule has more cues of this kind than the target (a second / third texture layer): make the missing cue, carrying the
                -- source cue's name and key so conditions copied later can still point at it
                d = ns.NewCueRule(dst, s.cueKind)
                if d then
                    d.cueName = s.cueName
                    ns.pasteCreated = (ns.pasteCreated or 0) + 1
                end
            end
            if d then
                for _, k in ipairs(keys) do if sel[k] then apply(k, d, s) end end
                pcall(ns.RefreshVisual, d)
                done = done + 1
            else skipped = skipped + 1 end
        end
    end
    if wantVis then run(isVis, VIS) end
    if sel.sound or sel.sndRep then run(isSnd, { "sound", "sndRep" }) end
    return done, skipped
end
-- returns true if something was pasted
local function PasteInto(dst)
    if not ruleClip or PasteCount() == 0 or dst.parentUid or dst.isCue then return false end
    if ns.IsEditLocked and ns.IsEditLocked(dst) then ns.pasteNotes[#ns.pasteNotes + 1] = "'" .. tostring(dst.name) .. "' is edit-locked, skipped"; return false end
    local sel, clip = pasteSel, ruleClip
    for _, k in ipairs({ "idsCd", "idsBuff", "stCd", "stBuff", "talents", "extra", "activation", "load", "actions" }) do if sel[k] then PasteApply(k, dst, clip.data) end end
    if not sel.extra then   -- single additional triggers are ADDED to the target's list (its own triggers stay)
        local src = clip.data.extra and clip.data.extra.list
        for i = 1, (src and #src or 0) do
            if sel["xr" .. i] then
                dst.extra = type(dst.extra) == "table" and dst.extra or { list = {} }
                dst.extra.list = dst.extra.list or {}
                dst.extra.list[#dst.extra.list + 1] = ns.Copy(src[i])
            end
        end
    end
    if sel.cues then ns.PasteCues(dst, clip) end
    if sel.conditions then ns.PasteConditions(dst, clip) end
    if sel.cues or sel.conditions then
        local dropped = ns.PasteCleanRefs(dst)
        if dropped > 0 then ns.pasteNotes[#ns.pasteNotes + 1] = dropped .. " condition link(s) to cues this rule does not have were removed (tick Cues too to bring the cues along)" end
    end
    ns.pasteCreated = 0
    local _, skipped = ns.PasteLook(dst, clip, sel, PasteApply)
    if ns.pasteCreated > 0 then ns.pasteNotes[#ns.pasteNotes + 1] = ns.pasteCreated .. " extra cue(s) were created on '" .. tostring(dst.name) .. "' to hold the copied layers (no condition fires them yet: tick Conditions + Cues to copy those too)" end
    if skipped > 0 then ns.pasteNotes[#ns.pasteNotes + 1] = skipped .. " copied display / sound part(s) had no cue of the same kind on '" .. tostring(dst.name) .. "' (tick Cues to copy the cues themselves)" end
    pcall(ns.RefreshVisual, dst)
    ns.MarkDirty()
    return true
end
ns.pasteNotes = {}
local function PasteSummary()
    return table.concat(PasteSelectedLabels(), "; ")
end

-- which banners (Display Options / Text / Sound) are expanded, per rule; everything starts collapsed
-- A group's options are open unless the user collapsed them (bannerOpen[rule][key] == false). The +/- button flips that.
function ns.ArrowOpen(rule, key) local b = bannerOpen[rule]; return not (b and b[key] == false) end
function ns.ArrowToggle(rule, key, order)
    return { type = "execute", order = order, width = "normal",
        name = function()
            return (ns.ArrowOpen(rule, key) and "|TInterface\\Buttons\\UI-MinusButton-Up:16:16|t" or "|TInterface\\Buttons\\UI-PlusButton-Up:16:16|t") .. "  Options"
        end,
        desc = "Open or close the options below. Closing never changes any setting.",
        arg = { xuiLeft = true },
        func = function()
            bannerOpen[rule] = bannerOpen[rule] or {}
            local b = bannerOpen[rule]
            if b[key] == false then b[key] = nil else b[key] = false end
            Notify()
        end }
end

-- Every sub header (a "header" line) in an options table gets a + / - at its far right end (drawn by Skin.lua). Collapsing hides the
-- options under it, up to the next header. Session only; nothing is saved and no setting changes. `tag` keeps the keys of different
-- tables apart. Options above the first header are never hidden.
function ns.CollapsibleHeaders(rule, args, tag)
    local keys = {}
    for k, o in pairs(args) do if type(o) == "table" then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b)
        local oa, ob = tonumber(args[a].order) or 0, tonumber(args[b].order) or 0
        if oa ~= ob then return oa < ob end
        return tostring(a) < tostring(b)
    end)
    local cur
    for _, k in ipairs(keys) do
        local o = args[k]
        if o.type == "header" and type(o.name) == "string" and o.name ~= "" and not o.arg then
            local key = "h:" .. tag .. ":" .. k
            cur = key
            o.arg = { xuiCollapse = true,
                xuiCollapsed = function() return not ns.ArrowOpen(rule, key) end,
                xuiToggle = function()
                    bannerOpen[rule] = bannerOpen[rule] or {}
                    local b = bannerOpen[rule]
                    if b[key] == false then b[key] = nil else b[key] = false end
                    Notify()
                end }
        elseif cur and o.type ~= "header" then
            local orig, ck = o.hidden, cur
            o.hidden = function(...)
                if not ns.ArrowOpen(rule, ck) then return true end
                if type(orig) == "function" then return orig(...) end
                return orig
            end
        end
    end
end

local function BuildRule(i, rule)
    local V = rule.visual
    local function on() Changed(rule) end
    -- Progress-texture (visual.fill.enabled) base/overlay layers are opacity+tint linked by default; see Core.lua
    -- visual.overlay.advanced and the "Advanced customization" toggle at the bottom of Opacity & Fill.
    local OV, FL = V.overlay, V.fill
    local function ProgLocked() return FL.enabled and not OV.advanced end

    ---------------------------------------------------------------- Trigger
    local trigger = {
        type = "group", name = "Trigger", order = 2, args = {
            cdHeader = { type = "header", name = "Cooldown", order = 1 },
            spellID = {
                type = "input", name = "Spell ID", order = 2, width = "half",
                get = function() return tostring(rule.spellID) end,
                set = function(_, v) rule.spellID = tonumber(v) or 0; Changed(rule); Notify() end,
            },
            spellName = { type = "description", order = 3, width = "double", fontSize = "medium",
                name = function() return SpellName(rule.spellID) end },
            spellSearch = SearchBox(1.5, function(id) rule.spellID = id; Changed(rule); Notify() end, nil, "cd"),   -- before Spell ID (2)
            spellPick = {
                type = "select", name = "Or pick from your spellbook (current spec, active spells)", order = 3.5, width = "double",
                values = function()
                    local v = {}
                    for _, s in ipairs(ns.BuildSpellList()) do
                        v[tostring(s.id)] = (s.icon and ("|T%s:16|t "):format(tostring(s.icon)) or "") .. s.name .. "  [" .. s.id .. "]"
                    end
                    return v
                end,
                sorting = function()
                    local o = {}
                    for _, s in ipairs(ns.BuildSpellList()) do o[#o + 1] = tostring(s.id) end
                    return o
                end,
                get = function()
                    local k = tostring(rule.spellID)
                    for _, s in ipairs(ns.BuildSpellList()) do if tostring(s.id) == k then return k end end
                end,
                set = function(_, v) rule.spellID = tonumber(v) or 0; Changed(rule); Notify() end,
            },
            cdState = ns.CdStateSelect(rule, on),
            maxCharges = Rng(rule, "maxCharges", "Max charges override (0 = auto)", 5, 0, 6, 1, on,
                { desc = "Only used if the game reports no charge data. Auto-detection normally wins." }),
            detected = { type = "description", order = 6, width = "full", name = function() return DetectedMax(rule.spellID) end },
            buffHeader = { type = "header", name = "Buff / Aura", order = 10 },
            buffState = Sel(rule, "buffState", "State", 11, BUFF_VALUES, BUFF_ORDER, on, { width = "double" }),
            buffSearch = SearchBox(11.5, function(id) rule.buffID = id; Changed(rule); Notify() end, nil, "aura"),
            buffID = {
                type = "input", name = "Aura spell ID", order = 12, width = "half",
                get = function() return tostring(rule.buffID) end,
                set = function(_, v) rule.buffID = tonumber(v) or 0; Changed(rule); Notify() end,
            },
            buffName = { type = "description", order = 13, width = "double", fontSize = "medium",
                name = function() return SpellName(rule.buffID) end },
            -- more aura IDs that count as the same buff (Well Fed variants, Demon Spikes IDs): present = ANY of them, missing = ALL absent
            buffAltSearch = SearchBox(13.1, function(id)
                id = tonumber(id) or 0
                if id == 0 or id == (tonumber(rule.buffID) or 0) then return end
                rule.buffAlt = type(rule.buffAlt) == "table" and rule.buffAlt or {}
                for _, x in ipairs(rule.buffAlt) do if x == id then return end end
                if #rule.buffAlt >= 30 then ns.Print("a trigger can watch at most 30 extra aura IDs"); return end
                rule.buffAlt[#rule.buffAlt + 1] = id; Changed(rule); Notify()
            end, "Also count these auras: search to add another", "aura"),
            buffAlt = {
                type = "input", name = "Extra aura IDs (comma separated; any one counts)", order = 13.2, width = "full",
                desc = "Other aura spell IDs that mean the same buff to this rule. The trigger is PRESENT when any listed aura is on you and MISSING only when all are absent. If none is present and the game hides one of them (combat), the answer is UNKNOWN and the rule does not fire. Delete an ID from the box to remove it.",
                get = function() local t = type(rule.buffAlt) == "table" and rule.buffAlt or {}; local o = {}; for i, v in ipairs(t) do o[i] = tostring(v) end; return table.concat(o, ", ") end,
                set = function(_, v)
                    local out, seen = {}, { [tonumber(rule.buffID) or 0] = true }
                    for n in tostring(v or ""):gmatch("%d+") do
                        local id = tonumber(n)
                        if id and id > 0 and not seen[id] and #out < 30 then seen[id] = true; out[#out + 1] = id end
                    end
                    rule.buffAlt = (#out > 0) and out or nil
                    Changed(rule); Notify()
                end,
            },
            buffAltNames = { type = "description", order = 13.3, width = "full", fontSize = "medium",
                hidden = function() return type(rule.buffAlt) ~= "table" or #rule.buffAlt == 0 end,
                name = function()
                    local o = {}
                    for _, id in ipairs(rule.buffAlt or {}) do o[#o + 1] = SpellName(id) .. "  [" .. id .. "]" end
                    return table.concat(o, "\n")
                end },
        },
    }

    -- Triggers are added by hand: Cooldown and Buff / Aura only show once added (or while they hold data).
    -- Hiding never changes saved values; "Remove" resets that section.
    for _, k in ipairs({ "cdHeader", "spellID", "spellName", "spellSearch", "spellPick", "cdState", "maxCharges", "detected" }) do
        local o = trigger.args[k]
        if o then o.hidden = function() return not ns.CooldownUsed(rule) end end
    end
    for _, k in ipairs({ "buffHeader", "buffState", "buffSearch", "buffID", "buffName", "buffAltSearch", "buffAlt", "buffAltNames" }) do
        local o = trigger.args[k]
        if o then o.hidden = function() return not ns.BuffUsed(rule) end end
    end
    trigger.args.cdRemove = { type = "execute", name = "Remove", order = 7, width = "half",
        desc = "Remove the Cooldown trigger: clears this rule's Cooldown spell, max charges, and state.",
        hidden = function() return not ns.CooldownUsed(rule) end,
        func = function() rule.useCooldown = false; rule.spellID = 0; rule.maxCharges = 0; rule.cdState = nil; Changed(rule); Notify() end }
    trigger.args.buffRemove = { type = "execute", name = "Remove", order = 14, width = "half",
        desc = "Remove the Buff / Aura trigger: clears this rule's aura ID and state.",
        hidden = function() return not ns.BuffUsed(rule) end,
        func = function() rule.useBuff = false; rule.buffID = 0; rule.buffAlt = nil; rule.buffState = nil; Changed(rule); Notify() end }
    -- Additional trigger rows (Triggers.lua). A failure there must never take the whole options tree down.
    if ns.BuildExtraTriggerArgs then
        local okx, xa = pcall(ns.BuildExtraTriggerArgs, rule, ns.UI)
        if okx then for k, v in pairs(xa) do trigger.args[k] = v end
        elseif not ns.extraUiErr then ns.extraUiErr = true; ns.Print("additional triggers UI error: " .. tostring(xa)) end
    end
    if ns.DecorateBuiltinTriggers then   -- numbering, order and Move up / Move down for Cooldown and Buff / Aura
        local okd, errd = pcall(ns.DecorateBuiltinTriggers, rule, trigger.args)
        if not okd and not ns.decorErr then ns.decorErr = true; ns.Print("trigger order UI error: " .. tostring(errd)) end
    end
    -- Outcomes (Outcomes.lua). An outcome rule follows its parent's triggers: its own trigger sections are hidden and the
    -- combination row builder takes their place. A normal rule gets the Outcomes list instead, on its Conditions tab (below).
    local outcomeArgs, cueArgs
    if rule.parentUid then
        for _, o in pairs(trigger.args) do o.hidden = function() return true end end
        if ns.BuildWhenArgs then
            local okw, whenArgs = pcall(ns.BuildWhenArgs, rule, ns.UI)
            if okw then for k, v in pairs(whenArgs) do trigger.args[k] = v end
            elseif not ns.whenUiErr then ns.whenUiErr = true; ns.Print("outcome UI error: " .. tostring(whenArgs)) end
        end
    elseif ns.BuildOutcomeArgs then
        local oko, oa = pcall(ns.BuildOutcomeArgs, rule, ns.UI)
        if oko then outcomeArgs = oa
        elseif not ns.outcomeUiErr then ns.outcomeUiErr = true; ns.Print("outcomes UI error: " .. tostring(oa)) end
        if ns.BuildCueArgs then
            local okq, qa = pcall(ns.BuildCueArgs, rule, ns.UI)
            if okq then cueArgs = qa
            elseif not ns.cueUiErr then ns.cueUiErr = true; ns.Print("cues UI error: " .. tostring(qa)) end
        end
    end

    ------------------------------------------------------------ Conditions
    local function noMatch() return false end   -- every load option stays visible in every mode (0.5.77); Always / Never only decide whether they are used (note below)
    local loadArgs = {
        talentUse = { type = "toggle", name = "Talents", order = 1, width = "double",
            desc = "Tick to require certain talents. Unticked = talents are ignored. The talent list appears below once ticked.",
            get = function() return rule.talentMode == "all" or rule.talentMode == "any" end,
            set = function(_, v)
                if v then
                    if rule.talentMode ~= "all" and rule.talentMode ~= "any" then rule.talentMode = "any" end
                    bannerOpen[rule] = bannerOpen[rule] or {}; bannerOpen[rule].talents = nil   -- ticking shows the list
                else
                    rule.talentMode = "none"
                end
                Changed(rule); Notify()
            end },
        ctxHeader = { type = "header", name = "Match Conditions (Party, Raid, Instance, Resting...)", order = 20, hidden = noMatch },
    }
    -- Talent list: only rendered once Talents is ticked, as a collapsible attachment (starts collapsed)
    local talentBody = {
        talentAdd = {
            type = "select", name = "Add a talent from your current build", order = 3, width = "double",
            values = function()
                local v = {}
                for _, t in ipairs(ns.BuildTalentList()) do
                    v[tostring(t.id)] = "|T" .. SpellTex(t.id) .. ":16|t " .. t.name .. (t.choice and "  (choice node)" or "") .. "  [" .. t.id .. "]"
                end
                return v
            end,
            sorting = function()
                local o = {}
                for _, t in ipairs(ns.BuildTalentList()) do o[#o + 1] = tostring(t.id) end
                return o
            end,
            get = function() return nil end,
            set = function(_, v)
                rule.talents[#rule.talents + 1] = { id = tonumber(v) or 0, state = "known" }
                Changed(rule); Notify()
            end,
        },
        talentAddBlank = {
            type = "execute", name = "Add an empty talent row (type an ID)", order = 4, width = "double",
            func = function() rule.talents[#rule.talents + 1] = { id = 0, state = "known" }; Changed(rule); Notify() end,
        },
    }
    AddSquareRadio(talentBody, "talentMode", 2, TALENT_MODE_USED, TALENT_MODE_USED_ORDER,
        function() return rule.talentMode end,
        function(v) rule.talentMode = v; Changed(rule); Notify() end,
        { desc = "ALL: every listed talent must match. ANY: one match is enough. Add talents below." })
    local function talentsOn() return rule.talentMode == "all" or rule.talentMode == "any" end
    loadArgs.talents = { type = "group", inline = true, name = "Talent List", order = 1.5, hidden = function() return not talentsOn() end,
        args = {
            open = ns.ArrowToggle(rule, "talents", 1),
            body = { type = "group", inline = true, name = "", order = 2,
                hidden = function() return not ns.ArrowOpen(rule, "talents") end, args = talentBody },
        } }
    -- Hero talents: same pattern as Specialization / Role, sits right under the Talent List
    do
        local function heroSet() rule.load.heroes = rule.load.heroes or {}; return rule.load.heroes end
        loadArgs.heroes = ns.RadioGroup("Hero Talents", 1.6, noMatch,
            heroSet, ns.HeroChoices(), function() Changed(rule); Notify() end, function() return rule.load end, "heroUse", rule, "heroes")
    end
    loadArgs.loadHeader = { type = "header", name = "When Should This Rule Load?", order = 0 }
    loadArgs.modeNote = { type = "description", order = 0.52, width = "full", fontSize = "medium",
        hidden = function() local m = rule.load.mode; return m ~= "never" and m ~= "always" end,
        name = function()
            return rule.load.mode == "always"
                and "|cffffd100Always load is ticked:|r the options below are kept but not used. Tick Match ALL or Match ANY to make them count."
                or "|cffffd100Never load is ticked:|r this rule does not load, so the options below are kept but not used. Tick Match ALL or Match ANY to make them count."
        end }
    local loadModeKeys = AddSquareRadio(loadArgs, "loadMode", 0.5, LOAD_MODE, LOAD_MODE_ORDER,
        function() return rule.load.mode or "all" end,
        function(v) rule.load.mode = v; Changed(rule); Notify() end,
        { desc = "Never: the rule never loads. Always: ignore every load condition. Match: use the conditions below (ALL must be true, or ANY one is enough). Only conditions you set count." })
    for j, t in ipairs(rule.talents) do
        talentBody["talent" .. j] = {
            type = "group", inline = true, order = 5 + j * 0.01,
            name = function() return "Talent " .. j .. ": " .. SpellName(t.id) end,
            args = {
                icon = { type = "execute", name = "", order = 0, width = 0.35,
                    image = function() return SpellTex(t.id) end,
                    imageWidth = 28, imageHeight = 28,
                    arg = { xuiSpell = t },   -- read by the widget walker below, which attaches the full Blizzard spell tooltip
                    func = function() end },
                id = { type = "input", name = "Spell ID", order = 1, width = "half",
                    get = function() return tostring(t.id) end,
                    set = function(_, v) t.id = tonumber(v) or 0; Changed(rule); Notify() end },
                state = Sel(t, "state", "Requirement", 2, TALENT_STATE, TALENT_STATE_ORDER, on),
                remove = { type = "execute", name = "Remove", order = 3, width = "half",
                    func = function() table.remove(rule.talents, j); Changed(rule); Notify() end },
            },
        }
    end
    -- One three-click toggle per condition: unselected (ignored) -> green "yes" text -> red "not" text -> unselected
    local TRI_TEXT = {
        combat     = { "In Combat", "Not In Combat" },
        group      = { "In A Group", "Not In A Group" },
        raid       = { "In A Raid Group", "Not In A Raid Group" },
        instance   = { "In An Instance", "Not In An Instance" },
        mythicPlus = { "In A Mythic+", "Not In A Mythic+" },
        encounter  = { "In A Boss Encounter", "Not In A Boss Encounter" },
        mounted    = { "Mounted", "Not Mounted" },
        resting    = { "In A Resting Area", "Not In A Resting Area" },
    }
    for n, c in ipairs(ns.LOAD_TRI) do
        local txt = TRI_TEXT[c.key] or { c.yes, c.no }
        loadArgs["tri_" .. c.key] = {
            type = "toggle", tristate = true, order = 30 + n, width = "double", hidden = noMatch,
            desc = "Click once: " .. c.yes .. ". Click again: " .. c.no .. ". Click a third time: ignored (unselected).",
            name = function()
                local st = rule.load[c.key]
                if st == "yes" then return "|cff55ff55" .. txt[1] .. "|r" end
                if st == "no" then return "|cffff5555" .. txt[2] .. "|r" end
                return c.label
            end,
            get = function()
                local st = rule.load[c.key]
                if st == "yes" then return true end
                if st == "no" then return nil end
                return false
            end,
            set = function(_, v)
                if v == true then rule.load[c.key] = "yes"
                elseif v == nil then rule.load[c.key] = "no"
                else rule.load[c.key] = "none" end
                Changed(rule)
            end,
        }
    end
    loadArgs.instTypeHeader = { type = "header", name = "Instance Type (None Ticked = Any)", order = 60, hidden = noMatch }
    local instChoices = {}
    for _, k in ipairs(ns.INSTANCE_TYPE_ORDER) do instChoices[#instChoices + 1] = { id = k, text = ns.INSTANCE_TYPES[k] } end
    loadArgs.instanceTypes = TriGroup("Instance Type", 61, noMatch,
        function() rule.load.instanceTypes = rule.load.instanceTypes or {}; return rule.load.instanceTypes end,
        instChoices, function() Changed(rule); Notify() end)
    loadArgs.classHeader = { type = "header", name = "Specialization / Role", order = 0.55, hidden = noMatch }
    local function LoadSet(field, legacy, legacyOK)
        local ld = rule.load
        ld[field] = ld[field] or {}
        -- one-time migration of the old single-choice value
        if next(ld[field]) == nil and ld[legacy] ~= nil and legacyOK(ld[legacy]) then
            ld[field][tostring(ld[legacy])] = true
        end
        ld[legacy] = nil
        return ld[field]
    end
    local function specSet() return LoadSet("specs", "specID", function(v) return type(v) == "number" and v > 0 end) end
    local function roleSet() return LoadSet("roles", "role", function(v) return v ~= "none" and v ~= "" end) end
    local function onSpecRole() Changed(rule); Notify() end
    -- Instance Options: types + Mythic+ + Boss encounter sit right under "Instance" and only show when Instance is
    -- "Only inside an instance", or when any of them already holds a setting (so an active restriction is never hidden).
    local function instSubActive()
        local ld = rule.load
        if next(ld.instanceTypes or {}) then return true end
        return not ns.Ignored(ld.mythicPlus) or not ns.Ignored(ld.encounter)
    end
    local function instHidden()
        return noMatch() or not (rule.load.instance == "yes" or instSubActive())
    end
    local instOrder
    for n, c in ipairs(ns.LOAD_TRI) do if c.key == "instance" then instOrder = 30 + n end end
    if instOrder then
        -- mirror of the Talents attachment: a collapsible "Instance Options" group with a "Show options" tick
        local instBody = { instanceTypes = loadArgs.instanceTypes, tri_mythicPlus = loadArgs.tri_mythicPlus, tri_encounter = loadArgs.tri_encounter }
        loadArgs.instanceTypes, loadArgs.tri_mythicPlus, loadArgs.tri_encounter, loadArgs.instTypeHeader = nil, nil, nil, nil
        instBody.instanceTypes.order = 1
        instBody.tri_mythicPlus.order = 2
        instBody.tri_encounter.order = 3
        loadArgs.instanceOptions = { type = "group", inline = true, name = "Instance Options", order = instOrder + 0.1, hidden = instHidden,
            args = {
                open = ns.ArrowToggle(rule, "instance", 1),
                body = { type = "group", inline = true, name = "", order = 2,
                    hidden = function() return not ns.ArrowOpen(rule, "instance") end, args = instBody },
            } }
        -- ticking Instance (green "In An Instance") opens the group, like ticking Talents
        local prevSet = loadArgs.tri_instance.set
        loadArgs.tri_instance.set = function(info, v)
            prevSet(info, v)
            if rule.load.instance == "yes" then bannerOpen[rule] = bannerOpen[rule] or {}; bannerOpen[rule].instance = nil end
        end
    end
    loadArgs.specs = ns.RadioGroup("Specialization", 0.6, noMatch, specSet, SpecChoices(), onSpecRole, function() return rule.load end, "specUse", rule, "specs")
    loadArgs.roles = ns.RadioGroup("Role", 0.7, noMatch, roleSet, RoleChoices(), onSpecRole, function() return rule.load end, "roleUse", rule, "roles")
    -- A folder's Never / Always overrides this rule's load mode and match conditions (talents still apply). Values stay stored.
    local function folderLoadOv() return ns.FolderLoadOverride(rule) end
    loadArgs.folderOv = { type = "description", order = 0.2, width = "full", fontSize = "medium",
        hidden = function() return not folderLoadOv() end,
        name = function()
            local ov, of = folderLoadOv()
            if not ov then return "" end
            return "|cffffd100Overridden by group " .. tostring(of and of.name) .. "|r: " .. (ov == "never" and "Never" or "Always")
                .. ". Your own load settings below are kept and apply again if this rule leaves the group. Talents still apply."
        end }
    local lockKeys = { "instanceTypes", "specs", "roles", "heroes" }
    for _, k in ipairs(loadModeKeys) do lockKeys[#lockKeys + 1] = k end
    for _, c in ipairs(ns.LOAD_TRI) do lockKeys[#lockKeys + 1] = "tri_" .. c.key end
    for _, k in ipairs(lockKeys) do
        local a = loadArgs[k]
        if a then
            local prev = a.disabled
            a.disabled = function(...)
                if folderLoadOv() then return true end
                if type(prev) == "function" then return prev(...) end
                return prev
            end
        end
    end
    local load = { type = "group", name = "Load", order = 4, args = loadArgs }

    ---------------------------------------------------------------- Actions
    -- 1) Display Options  (texture -> position)
    -- outline glow: its options only show while it is on (borderless "shape" style has no border / glow settings)
    do
        local o = V.outline
        if o.style == nil then o.style = "auto" end
        for k, dv in pairs({ borderOn = true, glowOn = true, glowSame = true, gap = 0, glowSize = 8, glowAlpha = 0.6 }) do if o[k] == nil then o[k] = dv end end
        if not o.glowColor then o.glowColor = { 1, 0.82, 0, 1 } end
    end
    local OL_STYLE = { auto = "Automatic (border for icons, art shape for textures)", border = "Pixel border + glow", shape = "Follow the art's shape" }
    local OL_STYLE_ORDER = { "auto", "border", "shape" }
    local function olStyleNow() local st = V.outline.style or "auto"; if st == "auto" then st = (V.kind == "spellicon") and "border" or "shape" end return st end
    local function olHide() return not V.outline.enabled end
    local function olBorderHide() return not V.outline.enabled or olStyleNow() ~= "border" end
    local function olGlowHide() return olBorderHide() or V.outline.glowOn == false end
    if rule.cueKind == "icon" and V.kind ~= "spellicon" then V.kind = "spellicon" end   -- icon cues never use texture sources
    local tex = {
        type = "group", inline = true, name = "Texture", order = 10, args = {
            kind = Sel(V, "kind", "Source", 1, TEX_KIND, TEX_KIND_ORDER, function() Changed(rule); Notify() end,
                { width = "double", hidden = function() return V.kind == "spellicon" end,
                  desc = "An atlas is a named piece of Blizzard's built-in UI art, looked up by name instead of by file. Advanced: most people can ignore it and use 'Texture ID / path' or the art list." }),
            iconSrc = Sel(V, "iconSrc", "Icon source", 1, ns.ICON_SRC, ns.ICON_SRC_ORDER, function() Changed(rule); Notify() end,
                { width = "double", hidden = function() return V.kind ~= "spellicon" end, get = function() return V.iconSrc or "auto" end,
                  desc = "Automatic follows the rule's triggers: the first one that has a spell or an item supplies the icon. Or search a spell or item yourself, or point at your own icon file." }),
            iconAuto = { type = "description", order = 1.1, width = "full", fontSize = "medium",
                hidden = function() return V.kind ~= "spellicon" or (V.iconSrc or "auto") ~= "auto" end,
                name = function()
                    local owner = (rule.parentUid and ns.FindParentRule and ns.FindParentRule(rule)) or rule
                    local tx, what = ns.TriggerIcon(owner)
                    if tx then return "|T" .. tostring(tx) .. ":24|t  Using the icon from " .. tostring(what) end
                    return "|cffffd100No trigger has a spell or item yet.|r Add one on the Trigger tab, or choose another icon source."
                end },
            iconSpell = { type = "input", name = "Spell ID", order = 1.21, width = "half",
                hidden = function() return V.kind ~= "spellicon" or V.iconSrc ~= "spell" end,
                get = function() return tostring(V.iconSpell or 0) end,
                set = function(_, x) V.iconSpell = tonumber(x) or 0; Changed(rule); Notify() end },
            iconSpellName = { type = "description", order = 1.22, width = "double", fontSize = "medium",
                hidden = function() return V.kind ~= "spellicon" or V.iconSrc ~= "spell" end,
                name = function() return SpellName(tonumber(V.iconSpell) or 0) end },
            iconSpellSearch = (function()
                local sb = SearchBox(1.2, function(id) V.iconSpell = id; Changed(rule); Notify() end)
                sb.hidden = function() return V.kind ~= "spellicon" or V.iconSrc ~= "spell" end
                return sb
            end)(),
            iconItem = { type = "input", name = "Item ID", order = 1.3, width = "half",
                hidden = function() return V.kind ~= "spellicon" or V.iconSrc ~= "item" end,
                get = function() return tostring(V.iconItem or 0) end,
                set = function(_, x) V.iconItem = tonumber(x) or 0; Changed(rule); Notify() end },
            iconItemName = { type = "description", order = 1.31, width = "double", fontSize = "medium",
                hidden = function() return V.kind ~= "spellicon" or V.iconSrc ~= "item" end,
                name = function()
                    local id = tonumber(V.iconItem) or 0
                    if id == 0 then return "" end
                    local ok, nm = pcall(C_Item.GetItemNameByID, id)
                    if ok and nm then return nm end
                    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
                    return "|cffaaaaaa(item name not loaded yet)|r"
                end },
            iconItemSearch = (function()
                local sb = SearchBox(1.32, function(id) V.iconItem = id; Changed(rule); Notify() end, nil, "item")
                sb.hidden = function() return V.kind ~= "spellicon" or V.iconSrc ~= "item" end
                return sb
            end)(),
            iconMine = { type = "select", name = "Pick one of my icons (XayaUI_Media\\Icons)", order = 1.4, width = "double",
                hidden = function() return V.kind ~= "spellicon" or V.iconSrc ~= "file" end,
                values = function()
                    local vals = { [""] = "(none picked)" }
                    for _, g in ipairs(ns.LocalGraphics or {}) do if g[1]:find("^%[User icon%]") then vals[g[2]] = g[1] end end
                    return vals
                end,
                sorting = function()
                    local keys = {}
                    for _, g in ipairs(ns.LocalGraphics or {}) do if g[1]:find("^%[User icon%]") then keys[#keys + 1] = g[2] end end
                    table.sort(keys); table.insert(keys, 1, ""); return keys
                end,
                get = function() return V.iconPath or "" end,
                set = function(_, x) V.iconPath = x; Changed(rule); Notify() end },
            iconPath = { type = "input", name = "Or a file path (inside an AddOns folder), or a file ID", order = 1.5, width = "double",
                hidden = function() return V.kind ~= "spellicon" or V.iconSrc ~= "file" end,
                desc = "Example: Interface\\AddOns\\XayaUI_Media\\Icons\\myicon.png. The picture must be SQUARE and no bigger than 200x200 pixels (sizes like 32, 64 or 128 work best; the game needs powers of two). The game cannot report a file's size to XayaUI, so a wrong size is not detected here. The art is shown whole (no edge crop).",
                get = function() return tostring(V.iconPath or "") end,
                set = function(_, x) V.iconPath = tostring(x or ""):gsub("^%s+", ""):gsub("%s+$", ""); Changed(rule); Notify() end },
            iconPathNote = { type = "description", order = 1.6, width = "full", fontSize = "small",
                hidden = function() return V.kind ~= "spellicon" or V.iconSrc ~= "file" end,
                name = function()
                    local p = tostring(V.iconPath or "")
                    if p == "" or tonumber(p) then return "|cff888888Square, at most 200x200 pixels. Put icons in Interface\\AddOns\\XayaUI_Media\\Icons and run Update-UserMedia.py to check them.|r" end
                    if not p:lower():find("^interface[\\/]") then return "|cffff5555That path does not start with Interface\\ - the game only loads files from inside its Interface folder.|r" end
                    return "|T" .. p .. ":24|t  |cff888888Preview. Square, at most 200x200.|r"
                end },
            tex = { type = "input", name = "Texture ID / path / atlas name", order = 2, width = "double",
                hidden = function() return V.kind == "spellicon" end,
                get = function() return tostring(V.tex or "") end,
                set = function(_, v) V.tex = v; Changed(rule) end },
            preset = { type = "select", name = "Or pick art (Blizzard alerts + your Media\\Graphics)", order = 3, width = "double",
                arg = { xuiTexPick = true },
                hidden = function() return V.kind == "spellicon" end,
                values = function() EnsureTextures(); return texValues end,
                sorting = function() EnsureTextures(); return texSorting end,
                get = function() if V.kind == "file" then return tostring(V.tex) end end,
                set = function(_, k)
                    if k == "0" then V.tex = "" else V.kind, V.tex = "file", k end
                    for _, g in ipairs(ns.LocalGraphics or {}) do   -- keep the picture's proportions (capped at 256)
                        if g[2] == k then
                            local sc = math.min(1, 256 / math.max(g[3], g[4]))
                            V.w, V.h = math.max(8, math.floor(g[3] * sc)), math.max(8, math.floor(g[4] * sc))
                        end
                    end
                    Changed(rule); Notify()
                end },
            sizeH = { type = "header", name = "Size & Orientation", order = 10 },
            w = Rng(V, "w", "Display width", 11, 8, 512, 1, on, { set = ns.AspectSet(V, "w", "h", on),
                desc = "The size of the display itself: its box on screen, its border, cooldown swipe, glow, and the area you click to move it. The icon art has its own size below." }),
            h = Rng(V, "h", "Display height", 12, 8, 512, 1, on, { set = ns.AspectSet(V, "h", "w", on),
                desc = "The size of the display itself: its box on screen, its border, cooldown swipe, glow, and the area you click to move it. The icon art has its own size below." }),
            keepAspect = { type = "toggle", name = "Maintain aspect ratio", order = 12.5, width = "double",
                desc = "On (default): changing Width or Height changes the other one too, keeping the proportions they have when you move the slider. Off: they move independently.",
                get = function() return V.keepAspect ~= false end,
                set = function(_, v) V.keepAspect = v and true or false; on() end },
            iconW = Rng(V, "iconW", "Icon width (0 = same as display)", 13, 0, 512, 1, on,
                { desc = "The size of the icon art inside the display, centered. Larger than the display width: the sides are cropped. Smaller: the icon is drawn smaller than the display. 0 follows the display width." }),
            iconH = Rng(V, "iconH", "Icon height (0 = same as display)", 13.2, 0, 512, 1, on,
                { desc = "The size of the icon art inside the display, centered. Larger than the display height: the top and bottom are cropped. Smaller: the icon is drawn smaller than the display. 0 follows the display height." }),
            rotation = Rng(V, "rotation", "Rotation (degrees)", 14, 0, 360, 1, on,
                { desc = "Rotates the art about its center. Works best on square sizes; a square image shrinks slightly at diagonal angles so it is never cropped." }),
            flipH = Tog(V, "flipH", "Mirror (flip horizontally)", 15, on),
            flipV = Tog(V, "flipV", "Flip vertically", 16, on),
            zoom = Rng(V, "zoom", "Zoom / crop edges", 17, 0, 0.3, 0.01, on),
            colorH = { type = "header", name = "Color & Blend", order = 20 },
            additive = Tog(V, "additive", "Additive blend", 21, on),
            desaturate = Tog(V, "desaturate", "Desaturate the base texture", 22, on,
                { width = "double", desc = "Removes the art's own colors first. On its own this grays it; with a tint below it gives an even, precise recolor (the tint multiplies the gray art). Progress textures gray the base automatically whenever it's tinted (see Advanced customization under Opacity & Fill) and lock this control while that's on.",
                  disabled = function() return ProgLocked() end,
                  get = function() if ProgLocked() then return V.recolor and true or false end return V.desaturate and true or false end }),
            recolor = Tog(V, "recolor", "Tint the base texture", 23, on,
                { desc = "Multiplies the (optionally desaturated) art by this color. With 'Additive blend' on, the color is tinted before it is added to the screen." }),
            tint = Col(V, "tint", "Tint color", 23.5, on, { disabled = function() return not V.recolor end }),
            fadeH = { type = "header", name = "Fade, Opacity & Flash as the Buff Runs Out", order = 30 },
            fadeGrey = Tog(V, "fadeGrey", "Fade gradually as the buff runs out", 31, on, { width = "double",
                desc = "Uses the Aura spell ID from the Trigger tab. Uses readable aura times; when Blizzard hides them (combat) it tries Blizzard's duration-object curves (experimental). Needs the aura present, so set Show to 'While the buff is present'. Preview shows a sample cycle." }),
            fadeMode = Sel(V, "fadeMode", "Fade to", 32, { none = "(none - gray)", color = "A color", transparent = "Transparent" }, { "none", "color", "transparent" }, on,
                { disabled = function() return not V.fadeGrey end }),
            fadeColor = Col(V, "fadeColor", "Fade color", 33, on,
                { disabled = function() return not (V.fadeGrey and ns.Val(V.fadeMode) == "color") end }),
            flashOn = Tog(V.flash, "enabled", "Flash when about to expire", 34, on, { width = "double" }),
            flashAt = Rng(V.flash, "threshold", "Start flashing at (seconds left)", 35, 1, 15, 0.5, on,
                { disabled = function() return not V.flash.enabled end }),
            flashSpeed = Rng(V.flash, "speed", "Flash speed (pulses per second)", 36, 1, 8, 0.5, on,
                { disabled = function() return not V.flash.enabled end }),
            desatOnCD = Tog(V, "desatOnCD", "Gray out while the spell is on cooldown", 37, on, { width = "double" }),
            hoverTip = Tog(V, "hoverTip", "Show tooltip on hover", 9.6, on, { width = "double",
                desc = "Hover this cue to see the tooltip of the spell or item it is about (the icon source chosen above, else the rule's first trigger). While on, the cue also sees the mouse pointer, but clicks still pass through to what is behind it." }),
            requireOnBar = Tog(V, "requireOnBar", "Only show while this ability is on an action bar", 9.5, on, { width = "double",
                desc = "Uses the Cooldown Spell ID (or the Aura spell ID if no Cooldown Spell ID is set). Hides the display whenever that spell is not currently placed on any of your 12 action bars, even if the rule would otherwise fire. Off by default so existing rules are unaffected." }),
            fxH = { type = "header", name = "Glow & Outline", order = 40 },
            glow = Tog(V, "glow", "Pulsing glow", 41, on),
            olOn = Tog(V.outline, "enabled", "Outline glow (pixel border + glow)", 42, on, { width = "double",
                desc = "A crisp pixel border with an optional soft glow around it. Spell icons use this by default; other art can pick it under Outline style." }),
            olStyle = Sel(V.outline, "style", "Outline style", 42.1, OL_STYLE, OL_STYLE_ORDER, on, { width = "double", hidden = olHide }),
            olBorderOn = Tog(V.outline, "borderOn", "Pixel border", 42.2, on, { hidden = olHide }),
            olWidth = Rng(V.outline, "width", "Border thickness (px)", 43, 1, 10, 1, on, { hidden = olHide }),
            olGap = Rng(V.outline, "gap", "Gap between the art and the border (px)", 43.5, 0, 8, 1, on, { hidden = olBorderHide }),
            olColor = Col(V.outline, "color", "Border color", 44, on, { hidden = olHide }),
            olGlowOn = Tog(V.outline, "glowOn", "Glow around the border", 44.2, on, { hidden = olBorderHide }),
            olGlowSize = Rng(V.outline, "glowSize", "Glow size (px)", 44.3, 1, 24, 1, on, { hidden = olGlowHide }),
            olGlowAlpha = Rng(V.outline, "glowAlpha", "Glow strength", 44.4, 0.05, 1, 0.05, on, { isPercent = true, hidden = olGlowHide }),
            olGlowSame = Tog(V.outline, "glowSame", "Glow uses the border color", 44.5, on, { hidden = olGlowHide }),
            olGlowColor = Col(V.outline, "glowColor", "Glow color", 44.6, on, { hidden = function() return olGlowHide() or V.outline.glowSame ~= false end }),
            olPulse = Tog(V.outline, "pulse", "Pulse the outline", 45, on, { hidden = olHide }),
            frameH = { type = "header", name = "Border & Background", order = 50 },
            bdOn = Tog(V.border, "enabled", "Border", 51, on),
            bdSize = Rng(V.border, "size", "Border size (px)", 52, 1, 8, 1, on, { disabled = function() return not V.border.enabled end }),
            bdColor = Col(V.border, "color", "Border color", 53, on, { disabled = function() return not V.border.enabled end }),
            bgOn = Tog(V.bg, "enabled", "Background fill", 54, on),
            bgColor = Col(V.bg, "color", "Background color", 55, on, { disabled = function() return not V.bg.enabled end }),
        },
    }
    do   -- each switch's dependent options sit in a pane that is drawn only while the switch is on
        local a, fc = tex.args, tex.args.fadeColor
        ns.GatePane(rule, a, "recolor", "Tint options", 23.5, function() return V.recolor end, { "tint" })
        ns.GatePane(rule, a, "fadeGrey", "Fade options", 31.5, function() return V.fadeGrey end, { "fadeMode", "fadeColor" })
        fc.disabled = function() return ns.Val(V.fadeMode) ~= "color" end   -- a choice inside the pane, not an on/off switch
        ns.GatePane(rule, a, "flash", "Flash options", 34.5, function() return V.flash.enabled end, { "flashAt", "flashSpeed" })
        ns.GatePane(rule, a, "outline", "Outline options", 42.5, function() return V.outline.enabled end, { "olWidth", "olColor", "olPulse" })
        ns.GatePane(rule, a, "border", "Border options", 51.5, function() return V.border.enabled end, { "bdSize", "bdColor" })
        ns.GatePane(rule, a, "bg", "Background options", 54.5, function() return V.bg.enabled end, { "bgColor" })
    end
    local ovOn = function() return OV.enabled end
    local overlay = {
        type = "group", inline = true, name = "Overlay Texture (Second Layer, Drawn on Top of the Base)", order = 11, args = {
            enabled = Tog(OV, "enabled", "Show an overlay layer", 1, function() Changed(rule); Notify() end, { width = "double" }),
            source = Sel(OV, "source", "Overlay art", 2, { none = "(none - same art as the base)", other = "Pick different art" }, { "none", "other" },
                function() Changed(rule); Notify() end, { width = "double", disabled = function() return not OV.enabled end }),
            kind = Sel(OV, "kind", "Source", 3, TEX_KIND, TEX_KIND_ORDER, function() Changed(rule); Notify() end,
                { width = "double", hidden = function() return not (OV.enabled and ns.Val(OV.source) == "other") end }),
            tex = { type = "input", name = "Texture ID / path / atlas name", order = 4, width = "double",
                hidden = function() return not (OV.enabled and ns.Val(OV.source) == "other") or OV.kind == "spellicon" end,
                get = function() return tostring(OV.tex or "") end,
                set = function(_, val) OV.tex = val; Changed(rule) end },
            preset = { type = "select", name = "Or pick art (Blizzard alerts + your Media\\Graphics)", order = 5, width = "double",
                arg = { xuiTexPick = true },
                hidden = function() return not (OV.enabled and ns.Val(OV.source) == "other") or OV.kind == "spellicon" end,
                values = function() EnsureTextures(); return texValues end,
                sorting = function() EnsureTextures(); return texSorting end,
                get = function() if OV.kind == "file" then return tostring(OV.tex) end end,
                set = function(_, k)
                    if k == "0" then OV.tex = "" else OV.kind, OV.tex = "file", k end
                    Changed(rule); Notify()
                end },
            tint = Col(OV, "tint", "Overlay tint color", 6, on, { disabled = function() return not OV.enabled end }),
            desaturate = Tog(OV, "desaturate", "Desaturate the overlay first", 7, on,
                { width = "double", disabled = function() return not OV.enabled or ProgLocked() end,
                  desc = "Progress textures keep the top layer ungrayed by default (Advanced customization under Overlay Layer overrides this).",
                  get = function() if ProgLocked() then return false end return OV.desaturate and true or false end }),
            additive = Tog(OV, "additive", "Additive blend for the overlay", 8, on,
                { width = "double", disabled = function() return not OV.enabled end }),
            note = { type = "description", order = 9, width = "full", fontSize = "small",
                name = "The overlay shares the base's size, rotation, mirror, and zoom. Tint the base underneath (or desaturate it) on the Color & blend line above; opacity of each layer is set under Opacity & fill." },
        },
    }
    for _, k in ipairs({ "source", "tint", "desaturate", "additive" }) do overlay.args[k].disabled = nil end   -- the Overlay Layer section is not drawn while the overlay is off
    local FILL_DIR = { none = "(none - shrinks toward the bottom)", bottom = "Shrinks toward the bottom", top = "Shrinks toward the top",
        left = "Shrinks toward the left", right = "Shrinks toward the right" }
    local opacity = {
        type = "group", inline = true, name = "Opacity & Fill", order = 12, args = {
            alpha = Rng(V, "alpha", "Overall opacity (everything)", 1, 0, 1, 0.05, on),
            texAlpha = Rng(V, "texAlpha", "Base texture opacity", 2, 0, 1, 0.05, on,
                { disabled = function() return ProgLocked() end,
                  desc = "Progress textures link this to Overlay opacity below, preserving their ratio, unless Advanced customization (bottom of Overlay Layer) is on." }),
            ovAlpha = Rng(OV, "alpha", "Overlay opacity", 3, 0, 1, 0.05, on, { disabled = function() return not OV.enabled end,
                set = function(_, val)
                    if ProgLocked() then
                        local prevOv = OV.alpha or 1
                        if prevOv < 0.0001 then prevOv = 1 end
                        local ratio = (V.texAlpha or 1) / prevOv
                        OV.alpha = val
                        V.texAlpha = math.min(1, math.max(0, ratio * val))
                    else
                        OV.alpha = val
                    end
                    on()
                end }),
            oocAlpha = Rng(V, "oocAlpha", "Opacity multiplier out of combat", 4, 0, 1, 0.05, on, { width = "double", def = 1 }),
            fadeH = { type = "header", name = "Fade Opacity as the Buff Runs Out", order = 10 },
            fadeAlpha = Tog(V, "fadeAlpha", "Fade opacity", 11, on, { width = "double",
                desc = "Opacity multiplier goes from the value at full duration to the value at expiry. Independent of the gray / color fade. Needs the aura present: set 'Show' to 'While the buff is present'." }),
            fadeAlphaMax = Rng(V, "fadeAlphaMax", "Opacity at full duration", 12, 0, 1, 0.05, on,
                { width = "double", disabled = function() return not V.fadeAlpha end }),
            fadeAlphaMin = Rng(V, "fadeAlphaMin", "Opacity at expiry", 13, 0, 1, 0.05, on,
                { width = "double", disabled = function() return not V.fadeAlpha end }),
            fillH = { type = "header", name = "Progress-Bar Wipe (Fill)", order = 20 },
            fillOn = Tog(FL, "enabled", "Wipe the art like a progress bar as the buff runs out", 21, on, { width = "full",
                desc = "Shows only part of the picture, shrinking as time runs out. Works from readable aura times (and the preview sample cycle); while Blizzard hides the numbers the art simply stays full. Applies to the base and overlay layers, not the outline." }),
            fillDir = Sel(FL, "dir", "Direction", 22, FILL_DIR, { "none", "bottom", "top", "left", "right" }, on,
                { width = "double", disabled = function() return not FL.enabled end }),
            fillRev = Tog(FL, "reverse", "Reverse (fill up as time runs out)", 23, on,
                { width = "double", disabled = function() return not FL.enabled end }),
            fillMax = Rng(FL, "max", "Fill shown at full duration", 24, 0, 1, 0.05, on,
                { width = "double", disabled = function() return not FL.enabled end }),
            fillMin = Rng(FL, "min", "Fill shown at expiry", 25, 0, 1, 0.05, on,
                { width = "double", disabled = function() return not FL.enabled end }),
            advH = { type = "header", name = "Advanced", order = 29, hidden = function() return not FL.enabled end },
            advanced = Tog(OV, "advanced", "Advanced customization (override the linked base/overlay opacity and tint defaults)", 30,
                function() Changed(rule); Notify() end,
                { width = "full", hidden = function() return not FL.enabled end,
                  desc = "Progress textures default to a locked base+overlay layering: the base opens at a reduced opacity tied to Overlay opacity above, grays automatically only when tinted, and the overlay never grays or dims. Tick this to set the base opacity, base gray, and overlay gray independently instead." }),
        },
    }
    ns.GatePane(rule, opacity.args, "fadeAlpha", "Fade opacity options", 11.5, function() return V.fadeAlpha end, { "fadeAlphaMax", "fadeAlphaMin" })
    ns.GatePane(rule, opacity.args, "fill", "Wipe options", 21.5, function() return FL.enabled end, { "fillDir", "fillRev", "fillMax", "fillMin" })
    opacity.args.ovAlpha.disabled = nil
    opacity.args.ovAlpha.hidden = function() return not OV.enabled end   -- belongs to the overlay switch, which lives in the Texture section
    local ANCHOR_VALUES = { TOPLEFT = "Top left", TOP = "Top", TOPRIGHT = "Top right", LEFT = "Left", CENTER = "Center", RIGHT = "Right",
        BOTTOMLEFT = "Bottom left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom right" }
    local ANCHOR_ORDER = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
    local pos = {
        type = "group", inline = true, name = "Position (Offset From the Anchor)", order = 20, args = {
            anchor = { type = "select", name = "Anchor (X / Y are measured from this point)", order = 0.5, width = "double",
                desc = "The point of the screen, or of this rule's group container, that X and Y are measured from. Changing it keeps the display exactly where it is and recalculates X / Y. Ignored while the display is snapped to a game frame, and in dynamic groups.",
                values = ANCHOR_VALUES, sorting = ANCHOR_ORDER,
                get = function() return V.anchor or "CENTER" end,
                set = function(_, val) ns.SetVisualAnchor(rule, val, nil); ns.MarkDirty(); Notify() end },
            anchorPlace = { type = "select", name = "Place the display", order = 0.6, width = "double",
                desc = "Inside: the display's matching point sits on the anchor, flush inside the box (bottom left anchor: the display's bottom left corner). Outside: the display's opposite point sits on the anchor, so the display lies outside the box next to that edge or corner. Center is the same either way.",
                values = { inner = "Inside the anchor point", outer = "Outside the anchor point" }, sorting = { "inner", "outer" },
                get = function() return V.anchorPlace == "outer" and "outer" or "inner" end,
                set = function(_, val) ns.SetVisualAnchor(rule, nil, val); ns.MarkDirty(); Notify() end },
            x = Rng(V, "x", "X", 1, -1200, 1200, 1, on),
            y = Rng(V, "y", "Y", 2, -800, 800, 1, on),
            unlock = { type = "execute", order = 3, width = "double",
                name = function() return ns.unlocked and "Lock (stop dragging)" or "Unlock (drag on screen)" end,
                func = function() ns.ToggleUnlock(); Notify() end },
        },
    }
    local display = {
        type = "group", inline = true, name = "Display Options", order = 1, args = {
            enabled = Tog(V, "enabled", "Show a texture / icon", 1, on),
            trigger = Sel(V, "trigger", "Show", 2, VIS_TRIGGER, VIS_TRIGGER_ORDER, on, { width = "double" }),
            texture = tex,
            overlay = overlay,
            opacity = opacity,
            position = pos,
        },
    }

    -- 2) Text (own banner)
    local T, C = V.text, V.count
    local durArgs = TextStyleArgs(T, on, 10)
    durArgs.enabled = Tog(T, "enabled", "Show remaining buff time", 1, on, { desc = "Uses the Aura spell ID from the Trigger tab." })
    durArgs.decimals = Tog(T, "decimals", "Show tenths (decimals)", 2, on)
    durArgs.decimalBelow = Rng(T, "decimalBelow", "Show tenths only below (seconds)", 3, 1, 30, 1, on,
        { width = "double", disabled = function() return not T.decimals end,
          desc = "Default 5. At or above this many seconds the time shows as whole numbers." })
    durArgs.note = { type = "description", order = 40, fontSize = "small", width = "full",
        name = "While Blizzard hides aura numbers in combat, the time comes from Blizzard's own duration display, so it may be unavailable or styled slightly differently. Unlock visuals, or use the eye icon, to preview a sample and position the text." }
    ns.GatePane(rule, durArgs, "decimals", "Tenths options", 2.5, function() return T.decimals end, { "decimalBelow" })
    ns.GateRest(rule, durArgs, "dur", "Text options", 5, function() return T.enabled end, { enabled = true })
    local cntArgs = TextStyleArgs(C, on, 10)
    cntArgs.enabled = Tog(C, "enabled", "Show a count", 1, on, { desc = "Aura stacks or spell charges. Experimental under Midnight secrecy: the number can only be displayed, not compared." })
    cntArgs.source = Sel(C, "source", "Count of", 2, COUNT_SOURCE, COUNT_SOURCE_ORDER, on)
    ns.GateRest(rule, cntArgs, "cnt", "Count options", 5, function() return C.enabled end, { enabled = true })
    local AB = V.absorb
    local absArgs = TextStyleArgs(AB, on, 10)
    absArgs.enabled = Tog(AB, "enabled", "Show shield / absorb amount", 1, on, { desc = "Experimental under Midnight secrecy: the amount can only be displayed, not compared or used as a condition." })
    absArgs.source = Sel(AB, "source", "Amount from", 2, ABSORB_SOURCE, ABSORB_SOURCE_ORDER, on)
    absArgs.abbreviate = Tog(AB, "abbreviate", "Abbreviate (12.3K / 1.2M)", 3, on)
    absArgs.hideZero = Tog(AB, "hideZero", "Hide when zero", 4, on, { desc = "Only works when the number is readable; a secret amount is shown as-is." })
    ns.GateRest(rule, absArgs, "abs", "Absorb options", 5, function() return AB.enabled end, { enabled = true })
    local text = {
        type = "group", inline = true, name = "Text", order = 2, args = {
            dur = { type = "group", inline = true, name = "Buff Duration Text", order = 1, args = durArgs },
            cnt = { type = "group", inline = true, name = "Stacks / Charges Count", order = 2, args = cntArgs },
            abs = { type = "group", inline = true, name = "Shield / Absorb Amount", order = 3, args = absArgs },
        },
    }

    -- 3) Sound
    local sound = {
        type = "group", inline = true, name = "Sound", order = 3, args = {
            soundEnabled = { type = "toggle", name = "Play a sound", order = 1,
                get = function() return rule.sound.enabled end, set = function(_, v) rule.sound.enabled = v end },
            sound = {
                type = "select", name = "Sound", order = 2, width = "double",
                values = function() EnsureSounds(); return soundValues end,
                sorting = function() EnsureSounds(); return soundSorting end,
                get = function()
                    EnsureSounds()
                    for idx, it in ipairs(soundList) do
                        if it.source == rule.sound.source and it.value == rule.sound.value then return tostring(idx) end
                    end
                end,
                set = function(_, v)
                    if v == "0" then rule.sound.value = ""; return end
                    local it = soundList[tonumber(v)]
                    if it then rule.sound.source, rule.sound.value = it.source, it.value end
                end,
            },
            test = { type = "execute", name = "Test sound", order = 3, width = "half", func = function() ns.PlaySoundPreview(rule.sound) end },
            soundPath = { type = "input", name = "Or type a sound file path  (.ogg or .mp3, inside Interface\\AddOns)", order = 3.5, width = "full",
                desc = "For your own sound without editing any list. Example: Interface\\AddOns\\XayaUI_Media\\Sounds\\ding.ogg  (keep your sounds in XayaUI_Media, not in the XayaUI folder, so a XayaUI update never deletes them). The game accepts .ogg and .mp3 (warcraft.wiki.gg PlaySoundFile); .wav is not confirmed. The file must exist before you log in or /reload. Leave empty to use the list above.",
                get = function() if rule.sound.source == "file" then return tostring(rule.sound.value or "") end return "" end,
                set = function(_, v)
                    v = tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if v == "" then if rule.sound.source == "file" then rule.sound.value = "" end; ns.MarkDirty(); return end
                    local low = v:lower():gsub("/", "\\")
                    if not (low:match("%.ogg$") or low:match("%.mp3$")) then ns.Print("sound files must end in .ogg or .mp3 (not changed)"); return end
                    if not low:match("^interface\\addons\\") then ns.Print("the path must start with Interface\\AddOns\\ : WoW plays addon sound files only from there (not changed)"); return end
                    rule.sound.source, rule.sound.value = "file", (v:gsub("/", "\\"))
                    ns.MarkDirty(); Notify()
                end },
            repeatSec = { type = "range", name = "Repeat every (seconds, 0 = once)", order = 4, width = "double",
                min = 0, max = 10, step = 0.1,
                get = function() return rule.repeatSec or 0 end, set = function(_, v) rule.repeatSec = v end },
            channel = { type = "select", name = "Sound channel", order = 5, values = CHANNEL_VALUES, sorting = CHANNEL_ORDER,
                get = function() return rule.sound.channel end, set = function(_, v) rule.sound.channel = v end },
            volume = {
                type = "range", name = function()
                    return "Volume of the '" .. (ns.Val(rule.sound.channel) or "Master") .. "' channel (game setting, shared)"
                end,
                order = 6, width = "double", min = 0, max = 1, step = 0.05, isPercent = true,
                desc = "WoW has no per-sound volume. This sets the game's own volume for the selected channel, so it also changes everything else that plays on that channel (same as Options > Sound).",
                get = function() return ns.GetChannelVolume(rule.sound.channel) end,
                set = function(_, v) ns.SetChannelVolume(rule.sound.channel, v) end,
            },
            note = { type = "description", order = 9, fontSize = "small",
                name = "Sounds you add to Media\\Audio need a full game restart before they can play. Use the headphone icon in the sidebar to loop this sound while you edit." },
        },
    }

    -- 3b) Speech (text-to-speech cue): a sound whose source is "tts"; shown only on Speech cues (see Outcomes.lua)
    local speechBody = {
        text = { type = "input", name = "Text to speak", order = 1, width = "full",
            desc = "Spoken when the cue fires. Plain text; no tokens yet.",
            get = function() return rule.sound.value or "" end,
            set = function(_, v) rule.sound.source = "tts"; rule.sound.value = tostring(v or ""):sub(1, 200) end },
        voice = { type = "select", name = "Voice", order = 2, width = "double",
            desc = "Voices come from the voice packs installed on this computer, so other players may see a different list.",
            values = function()
                local v = { ["0"] = "(first available voice)" }
                for _, it in ipairs(ns.GetTtsVoices()) do v[tostring(it.voiceID)] = it.name end
                return v
            end,
            sorting = function()
                local s = { "0" }
                for _, it in ipairs(ns.GetTtsVoices()) do s[#s + 1] = tostring(it.voiceID) end
                return s
            end,
            get = function() return tostring(rule.sound.voice or 0) end,
            set = function(_, v) v = tonumber(v); rule.sound.voice = (v and v ~= 0) and v or nil end },
        test = { type = "execute", name = "Test speech", order = 3, width = "half", func = function() ns.PlaySoundPreview(rule.sound) end },
        rate = { type = "range", name = "Speed", order = 4, width = "double", min = -10, max = 10, step = 1,
            get = function() return rule.sound.rate or 0 end, set = function(_, v) rule.sound.rate = v end },
        vol = { type = "range", name = "Speech volume", order = 5, width = "double", min = 0, max = 100, step = 5,
            get = function() return rule.sound.ttsVolume or 100 end, set = function(_, v) rule.sound.ttsVolume = v end },
        repeatSec = { type = "range", name = "Repeat every (seconds, 0 = once)", order = 6, width = "double", min = 0, max = 10, step = 0.1,
            get = function() return rule.repeatSec or 0 end, set = function(_, v) rule.repeatSec = v end },
        none = { type = "description", order = 7, fontSize = "small",
            hidden = function() return #ns.GetTtsVoices() > 0 end,
            name = "|cffff8800No text-to-speech voice is installed on this computer, so nothing will be spoken.|r" },
        note = { type = "description", order = 9, fontSize = "small",
            name = "Speech plays through the game's text-to-speech settings. Use the headphone icon in the sidebar to loop it while you edit." },
    }

    -- Collapsible banners: the "Show ..." tick box turns the element on AND shows its options; a +/- button beside it
    -- closes or reopens them (open by default while the element is on). Nothing shows while it is off.
    local function Banner(key, name, order, enableArg, bodyArgs)
        local function isOn() local ok, v = pcall(enableArg.get, {}); return ok and v and true or false end
        enableArg.order = 1
        local prevSet = enableArg.set
        enableArg.set = function(info, v, ...)
            if prevSet then prevSet(info, v, ...) end
            if v then local b = bannerOpen[rule]; if b then b[key] = nil end end   -- ticking always shows the options
        end
        local arrow = ns.ArrowToggle(rule, key, 2)
        arrow.hidden = function() return not isOn() end
        return {
            type = "group", inline = true, name = name, order = order, args = {
                enable = enableArg,
                open = arrow,
                body = { type = "group", inline = true, name = "", order = 10,
                    hidden = function() return not (isOn() and ns.ArrowOpen(rule, key)) end, args = bodyArgs },
            },
        }
    end
    -- Collapsible sub-sections inside a banner: an arrow row that toggles its body (starts collapsed)
    local ARROW_OPEN, ARROW_CLOSED = "|TInterface\\Buttons\\Arrow-Down-Up:16:16|t", "|TInterface\\ChatFrame\\ChatFrameExpandArrow:16:16|t"
    local function Sub(key, title, order, args, hiddenFn)
        local function subst() bannerOpen[rule] = bannerOpen[rule] or {}; bannerOpen[rule].sub = bannerOpen[rule].sub or {}; return bannerOpen[rule].sub end
        return {
            type = "group", inline = true, name = "", order = order, hidden = hiddenFn,
            args = {
                hdr = { type = "execute", order = 1, width = "full", arg = { xuiLeft = true },
                    name = function() return (subst()[key] and ARROW_OPEN or ARROW_CLOSED) .. "  " .. title end,
                    desc = "Expand or collapse this section. Collapsing never changes any setting.",
                    func = function() subst()[key] = (not subst()[key]) or nil; Notify() end },
                body = { type = "group", inline = true, name = "", order = 2,
                    hidden = function() return not subst()[key] end, args = args },
            },
        }
    end
    -- "Add Overlay Layer" lives in the Animation Options section (not the Texture box) and reveals the overlay settings below it
    local addOverlay = Tog(OV, "enabled", "Add Overlay Layer", 1, function() Changed(rule); Notify() end, { width = "double",
        desc = "Adds a second texture layer on top of this one that you can tint separately." })
    overlay.args.enabled = nil
    -- Position is its own collapsible section (between Texture and Overlay Layer), no longer inside the Texture box
    pos.args.x.order, pos.args.y.order, pos.args.unlock.order = 3, 4, 5
    local posArgs = { anchor = pos.args.anchor, anchorPlace = pos.args.anchorPlace, x = pos.args.x, y = pos.args.y, unlock = pos.args.unlock }
    display.args.trigger.order = 0
    -- Color & Blend (20-29) goes to Color & Transparency; Fade / Opacity / Flash (30-39) and Glow & Outline (40-49) live under Animation Options
    -- Overlay Layer: no collapse arrow of its own any more (it sits inside Animation Options, which collapses), and it comes last,
    -- below Fade Opacity as the Buff Runs Out and the progress-bar fill. The tick box stays with its settings.
    addOverlay.order = 200
    -- "Advanced customization" (override the linked base / overlay opacity and tint) belongs with the overlay settings, at their bottom
    for _, k in ipairs({ "advH", "advanced" }) do if opacity.args[k] then overlay.args[k] = opacity.args[k]; opacity.args[k] = nil end end
    if overlay.args.advH then overlay.args.advH.order = 90 end
    if overlay.args.advanced then overlay.args.advanced.order = 91 end
    local animArgs = {
        ovHdr = { type = "header", name = "Overlay Layer", order = 199 },
        addOverlay = addOverlay,
        overlay = { type = "group", inline = true, name = "", order = 201, hidden = function() return not OV.enabled end, args = overlay.args },
    }
    local colorArgs = {}   -- Color & Blend (orders 20-29 of the texture box) + Opacity & Fill = "Color & Transparency"
    do
        local toColor, toAnim = {}, {}
        for k, v in pairs(tex.args) do
            local o = type(v) == "table" and tonumber(v.order)
            if o and o >= 20 and o < 30 then toColor[#toColor + 1] = k
            elseif o and o >= 30 and o < 50 then toAnim[#toAnim + 1] = k end   -- 40-49 = Glow & Outline, also an animation
        end
        for _, k in ipairs(toColor) do colorArgs[k] = tex.args[k]; tex.args[k] = nil end
        for _, k in ipairs(toAnim) do animArgs[k] = tex.args[k]; tex.args[k] = nil end
        -- the run-out fade and the progress-bar wipe are animations: they belong under Animation Options
        -- own keys and orders: "fadeH" already exists in the texture box (Fade, Opacity & Flash), and each header must own only its items
        -- (collapsing a header hides what sits under it). Fade opacity follows the fade options, the wipe follows the glow and outline.
        for k, ord in pairs({ fadeH = 38, fadeAlpha = 38.1, pane_fadeAlpha = 38.5, fillH = 46, fillOn = 46.1, pane_fill = 46.5 }) do
            local o = opacity.args[k]
            if o then
                o.order = ord
                animArgs[(animArgs[k] and ("o_" .. k)) or k] = o
                opacity.args[k] = nil
            end
        end
        colorArgs.opH = { type = "header", name = "Opacity & Fill", order = 99 }
        for k, v in pairs(opacity.args) do
            if type(v) == "table" then v.order = (tonumber(v.order) or 0) + 100 end
            colorArgs[colorArgs[k] and ("op_" .. k) or k] = v
        end
    end
    ns.CollapsibleHeaders(rule, tex.args, "tex")
    ns.CollapsibleHeaders(rule, animArgs, "anim")
    ns.CollapsibleHeaders(rule, colorArgs, "col")
    ns.CollapsibleHeaders(rule, overlay.args, "ov")
    local dispBody = { trigger = display.args.trigger,
        pausePv = { type = "toggle", name = "Pause preview animations", order = 0.5, width = "double",
            desc = "Freezes the sample countdown, the fades, and the flash in every preview while the images stay on screen. Untick to resume.",
            get = function() return ns.previewPaused end,
            set = function(_, v) ns.SetPreviewPaused(v); Notify() end },
        texture = Sub("texture", "Texture", 1, tex.args),
        position = Sub("position", "Position (Offset From the Anchor)", 1.5, posArgs),
        anim = Sub("anim", "Animation Options", 2, animArgs),
        opacity = Sub("opacity", "Color & Transparency", 3, colorArgs) }
    local soundEnable = sound.args.soundEnabled
    local soundBody = {}
    for k, v in pairs(sound.args) do if k ~= "soundEnabled" then soundBody[k] = v end end
    local textEnable = { type = "toggle", name = "Show text (duration / count / absorb)",
        desc = "Turns the three text elements below on or off together. Open the banner to enable or style each one.",
        get = function() return (T.enabled or C.enabled or AB.enabled) and true or false end,
        set = function(_, v)
            T.enabled, C.enabled, AB.enabled = v and true or false, false, false
            if v then T.enabled = true end
            Changed(rule); Notify()
        end }
    -- Tabs: Info | Trigger | Conditions | Actions | Load. "Conditions" holds the rule's conditions (its outcomes, each a named
    -- combination of triggers); "Actions" holds what happens: display, text and sound.
    local conditionsTab = { type = "group", name = "Conditions", order = 3, args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "IF the checks are met, THEN the chosen cues play. Add one condition per situation you care about." },
    } }
    local cuesTab = { type = "group", name = "Cues", order = 2.5, args = {} }
    local actions = { type = "group", name = "Actions", order = 3.5, args = {
        display = Banner("display", "Display Options", 1, display.args.enabled, dispBody, function() return V.enabled and true or false end),
        text = Banner("text", "Text", 2, textEnable, {
            dur = Sub("dur", "Buff Duration Text", 1, durArgs),
            cnt = Sub("cnt", "Stacks / Charges Count", 2, cntArgs),
            abs = Sub("abs", "Shield / Absorb Amount", 3, absArgs),
        }, function() return (T.enabled or C.enabled or AB.enabled) and true or false end),
        sound = Banner("sound", "Sound", 3, soundEnable, soundBody, function() return rule.sound.enabled and true or false end),
    } }
    -- Pieces the Cues tab re-uses, without the on/off tick boxes and +/- banners (a cue IS the thing, so it is always on)
    actions.xuiParts = {
        tex = tex.args,
        colorSub = Sub("cq_color", "Color & Transparency", 1, colorArgs),
        posSub = Sub("cq_pos", "Position (Offset From the Anchor)", 1, posArgs),
        animSub = Sub("cq_anim", "Animation Options", 1, animArgs),
        textBody = { dur = Sub("cq_dur", "Buff Duration Text", 1, durArgs), cnt = Sub("cq_cnt", "Stacks / Charges Count", 2, cntArgs), abs = Sub("cq_abs", "Shield / Absorb Amount", 3, absArgs) },
        soundBody = soundBody,
        speechBody = speechBody,
        ensureText = function() if not (T.enabled or C.enabled or AB.enabled) then T.enabled = true end end,
    }
    -- cue kinds: a Display rule has no sound banner, a Sound rule has no display / text banners
    actions.args.display.hidden = function() return not ns.KindHas(rule, "visual") end
    actions.args.text.hidden = function() return not ns.KindHas(rule, "visual") end
    actions.args.sound.hidden = function() return not ns.KindHas(rule, "sound") end
    -- The Actions tab (Actions.lua): On Initialization / During / After It Ends. The rule's own sound (with
    -- repeat) is the "During" sound; its own display / text from before cues existed stay available in a collapsed pane while they are on.
    local finishSound = function(getTbl)
        return { type = "group", inline = true, name = "Play a sound", order = 30, args = {
            on = { type = "toggle", name = "Play a sound", order = 1, width = "full",
                get = function() local t = getTbl(); return t.snd and t.snd.enabled and true or false end,
                set = function(_, v) local t = getTbl(); t.snd = t.snd or { enabled = false, source = "kit", value = "", channel = "Master" }; t.snd.enabled = v and true or false; ns.MarkDirty(); Notify() end },
            pick = { type = "select", name = "Sound", order = 2, width = "double",
                hidden = function() local t = getTbl(); return not (t.snd and t.snd.enabled) end,
                values = function() EnsureSounds(); return soundValues end,
                sorting = function() EnsureSounds(); return soundSorting end,
                get = function()
                    EnsureSounds()
                    local sn = getTbl().snd
                    if not sn then return nil end
                    for idx, it in ipairs(soundList) do if it.source == sn.source and it.value == sn.value then return tostring(idx) end end
                end,
                set = function(_, v)
                    local t = getTbl(); t.snd = t.snd or { enabled = true, source = "kit", value = "", channel = "Master" }
                    if v == "0" then t.snd.value = ""; return end
                    local it = soundList[tonumber(v)]
                    if it then t.snd.source, t.snd.value = it.source, it.value end
                    ns.MarkDirty()
                end },
            test = { type = "execute", name = "Test sound", order = 3, width = "half",
                hidden = function() local t = getTbl(); return not (t.snd and t.snd.enabled) end,
                func = function() ns.PlaySoundPreview(getTbl().snd) end },
            channel = { type = "select", name = "Sound channel", order = 4, values = CHANNEL_VALUES, sorting = CHANNEL_ORDER,
                hidden = function() local t = getTbl(); return not (t.snd and t.snd.enabled) end,
                get = function() local sn = getTbl().snd; return sn and sn.channel or "Master" end,
                set = function(_, v) local t = getTbl(); t.snd = t.snd or { enabled = true, source = "kit", value = "" }; t.snd.channel = v; ns.MarkDirty() end },
        } }
    end
    local actionsTab = { type = "group", name = "Actions", order = 3.5, args = ns.ActionsPane and ns.ActionsPane(rule, Notify, { finishSound = finishSound }) or {} }
    -- Older rules that show / play things directly (from before cues): listed read-only with a button that moves them into cues.
    local function legacyKinds()
        if rule.isCue or rule.parentUid or (ns.HasOutcomes and ns.HasOutcomes(rule)) then return nil end
        local vis = V.enabled and ns.KindHas(rule, "visual")
        local snd = rule.sound and rule.sound.enabled and ns.KindHas(rule, "sound")
        if not (vis or snd) then return nil end
        return vis, snd
    end
    actionsTab.args.legacy = { type = "group", inline = true, order = 0.1, name = "Older rule", hidden = function() return not legacyKinds() end, args = {
        note = { type = "description", order = 1, width = "full", fontSize = "medium",
            name = function()
                local vis, snd = legacyKinds()
                local what = {}
                if vis then what[#what + 1] = (T.enabled or C.enabled or AB.enabled) and "a display with text" or "a display" end
                if snd then what[#what + 1] = "a sound" end
                return "This rule still has " .. table.concat(what, " and ") .. " set directly on it, from before cues existed. Convert it to move that into the Cues tab with every setting kept."
            end },
        convert = { type = "execute", order = 2, width = "double", name = "Convert to cue",
            func = function()
                local vis, snd = legacyKinds()
                rule.uid = rule.uid or ns.NewUID()
                if vis then
                    local kind = (ns.Val(V.kind) == "spellicon") and "icon" or ((V.text and V.text.enabled and (V.texAlpha or 1) <= 0) and "text" or "texture")
                    local cue = ns.NewCueRule(rule, kind)
                    if cue then
                        cue.visual = ns.Copy(V)   -- everything, including when it shows
                        cue.visual.enabled = true
                        pcall(ns.RefreshVisual, cue)
                    end
                end
                if snd then
                    local cue = ns.NewCueRule(rule, "sound")
                    if cue then
                        cue.sound = ns.Copy(rule.sound); cue.sound.enabled = true
                        cue.repeatSec = rule.repeatSec
                    end
                end
                V.enabled = false
                rule.sound.enabled = false
                pcall(ns.RefreshVisual, rule)
                Changed(rule); ns.MarkDirty(); Notify()
            end },
    } }
    actionsTab.xuiParts = actions.xuiParts
    if outcomeArgs then for k, v in pairs(outcomeArgs) do conditionsTab.args[k] = v end end
    if cueArgs then for k, v in pairs(cueArgs) do cuesTab.args[k] = v end end

    ---------------------------------------------------------------- Info tab (was "Rule")
    local ruleTab = {
        type = "group", name = "Info", order = 1, args = {
            name = { type = "input", name = "Name", order = 1, width = "double",
                get = function() return rule.name end,
                set = function(_, v) rule.name = tostring(v or ""):sub(1, 60); pcall(ns.RefreshVisual, rule); ns.MarkDirty(); Notify() end },
            enabled = { type = "toggle", name = "Enabled", order = 2,
                get = function() return rule.enabled end,
                set = function(_, v) rule.enabled = v; Changed(rule); Notify() end },
            folder = {
                type = "select", name = "Group", order = 3, width = "double",
                values = function() local v = FolderValues(); return v end,
                sorting = function() local _, o = FolderValues(); return o end,
                get = function() return rule.folder or "none" end,
                set = function(_, v)
                    rule.folder = (v ~= "none") and v or nil
                    Notify()
                    ns.SelectKeep(RulePath(rule))
                end,
            },
            descH = { type = "header", order = 3.45, name = "Description" },
            description = { type = "input", multiline = 4, order = 3.5, width = "full", name = "",
                desc = "A short note for yourself on what this rule does. Shown only here; it does not affect the rule.",
                get = function() return rule.description or "" end,
                set = function(_, v) v = tostring(v or ""):sub(1, 500); rule.description = (v ~= "") and v or nil; ns.MarkDirty() end },
            sbHdr = { type = "header", name = "Sidebar icon", order = 3.6 },
            sbMode = { type = "select", name = "Icon in the rule list", order = 3.7, width = "double",
                values = { auto = "Automatic (spell / buff icon; texture rules show their own art)", type = "Rule type icon", custom = "Custom icon (file ID)" },
                sorting = { "auto", "type", "custom" },
                desc = "What the left-hand list shows for this rule. Automatic uses the icon of the spell or buff the rule tracks (rules that track neither show the rule type icon).",
                get = function() return rule.listIcon or "auto" end,
                set = function(_, v) rule.listIcon = v; Changed(rule); if ns.DecorateTrees then ns.DecorateTrees() end; Notify() end },
            sbId = { type = "input", name = "Icon file ID", order = 3.8, width = "double",
                hidden = function() return (rule.listIcon or "auto") ~= "custom" end,
                get = function() return rule.listIconID and tostring(rule.listIconID) or "" end,
                set = function(_, v) rule.listIconID = tonumber(v); Changed(rule); if ns.DecorateTrees then ns.DecorateTrees() end; Notify() end },
            refresh = { type = "execute", name = "Refresh status", order = 5, func = Notify },
            status = { type = "description", order = 10, width = "full", fontSize = "medium", name = function() return StatusText(rule) end },   -- last on the page
            delete = {
                type = "execute", name = "Delete this rule", order = 9,
                confirm = true, confirmText = "Delete this rule?",
                func = function()
                    if ns.DeleteOutcomesOf then ns.DeleteOutcomesOf(rule) end
                    for idx, r in ipairs(ns.rules) do
                        if r == rule then table.remove(ns.rules, idx); break end
                    end
                    ns.DropVisual(rule)
                    ns.MarkDirty()
                    local tab = ns.CurrentTab()
                    Notify()
                    ns.GoHome(tab)
                end,
            },
        },
    }

    -- The unsaved-changes bar (Save changes / Add to drafts / Discard) is a strip under the window (ns.SaveBarUpdate), not part of the tabs.
    for _, g in ipairs({ ruleTab, trigger, load, conditionsTab, cuesTab, actionsTab }) do
        ns.LockArgs(g.args, function() return ns.IsEditLocked(rule) end)
    end
    return {
        type = "group", childGroups = "tab", order = 1000 + i,
        hidden = function() local q = ns.treeFilter; return q and q ~= "" and not tostring(rule.name or ""):lower():find(q, 1, true) end,
        name = function()
            local nm = tostring(rule.name or "")
            if nm == "" then return "|cff888888Unnamed rule|r" end
            return (rule.enabled and "" or "|cff888888") .. nm
        end,
        args = { rule = ruleTab, trigger = trigger, cues = cuesTab, conditions = conditionsTab, actions = actionsTab, load = load },
    }
end

-- Edit lock: a rule (or a folder, which covers everything inside it) can be made read-only from the sidebar.
function ns.IsEditLocked(x)
    if x and x.editLocked then return true end
    local id, guard = x and x.folder, 0
    while id and guard < 32 do
        local f = ns.FolderById(id)
        if not f then return false end
        if f.editLocked then return true end
        id, guard = f.parent, guard + 1
    end
    return false
end
-- disables every leaf option while locked() is true (collapse / expand controls stay usable; groups are left alone
-- because a disabled group would also disable those controls)
function ns.LockArgs(args, locked)
    for _, o in pairs(args or {}) do
        if o.type == "group" then
            ns.LockArgs(o.args, locked)
        elseif not (type(o.desc) == "string" and o.desc:find("^Expand or collapse")) then
            local orig = o.disabled
            o.disabled = function(...)
                if locked() then return true end
                if type(orig) == "function" then return orig(...) end
                return orig
            end
        end
    end
end

local function TokenHelp()
    local t = { "Tokens you can use (case-insensitive):" }
    for _, k in ipairs(ns.QOL_STAT_ORDER) do t[#t + 1] = "{" .. k .. "}  " .. ns.QOL_STATS[k].desc end
    t[#t + 1] = "WoW color codes also work in the format, e.g. typing |cffffd100||cffffd100gold||r|r shows |cffffd100gold|r."
    t[#t + 1] = "Blizzard hides stats while auras are restricted (combat, M+, encounters): a stat then keeps its last readable value, or shows ? if it was never readable."
    return table.concat(t, "\n")
end

local function BuildBox(i, box)
    return {
        type = "group", order = 10 + i,
        name = function() return (box.enabled and "" or "|cff888888") .. box.name end,
        args = {
            name = { type = "input", name = "Name", order = 1, width = "double",
                get = function() return box.name end,
                set = function(_, v) if v ~= "" then box.name = v end; Notify() end },
            enabled = { type = "toggle", name = "Enabled", order = 2,
                get = function() return box.enabled end,
                set = function(_, v) box.enabled = v; ns.QoL_Refresh(box); Notify() end },
            format = { type = "input", name = "Format", order = 3, width = "full", multiline = 5,
                get = function() return box.format end,
                set = function(_, v) box.format = v; ns.QoL_Refresh(box); Notify() end },
            preview = { type = "description", order = 4, width = "full", fontSize = "large",
                name = function() return "Preview:\n" .. ns.QoL_Preview(box) end },
            tokens = { type = "description", order = 5, width = "full", fontSize = "small", name = TokenHelp },
            lookHeader = { type = "header", name = "Look", order = 10 },
            font = { type = "select", name = "Font", order = 10.5,
                values = function() local v = ns.FontList(); return v end,
                sorting = function() local _, o = ns.FontList(); return o end,
                get = function() return box.font end, set = function(_, v) box.font = v; ns.QoL_Refresh(box) end },
            size = { type = "range", name = "Text size", order = 11, min = 6, max = 64, step = 1,
                get = function() return box.size end, set = function(_, v) box.size = v; ns.QoL_Refresh(box) end },
            outline = { type = "select", name = "Outline", order = 12, values = TEXT_OUTLINE, sorting = TEXT_OUTLINE_ORDER,
                get = function() return box.outline end, set = function(_, v) box.outline = v; ns.QoL_Refresh(box) end },
            justify = { type = "select", name = "Alignment", order = 13, values = JUSTIFY, sorting = JUSTIFY_ORDER,
                get = function() return box.justify end, set = function(_, v) box.justify = v; ns.QoL_Refresh(box) end },
            color = { type = "color", name = "Color", order = 14, hasAlpha = true,
                get = function() local c = box.color or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] or 1 end,
                set = function(_, r, g, b, a) box.color = { r, g, b, a }; ns.QoL_Refresh(box) end },
            alpha = { type = "range", name = "Opacity", order = 15, min = 0.05, max = 1, step = 0.05,
                get = function() return box.alpha end, set = function(_, v) box.alpha = v; ns.QoL_Refresh(box) end },
            decimals = { type = "range", name = "Decimals on percentages", order = 16, min = 0, max = 2, step = 1,
                get = function() return box.decimals end, set = function(_, v) box.decimals = v; ns.QoL_Refresh(box) end },
            showCombat = { type = "select", name = "Show", order = 17, values = SHOW_COMBAT, sorting = SHOW_COMBAT_ORDER,
                get = function() return box.showCombat end, set = function(_, v) box.showCombat = v; ns.QoL_Refresh(box) end },
            posHeader = { type = "header", name = "Position (Offset From Screen Center)", order = 20 },
            x = { type = "range", name = "X", order = 21, min = -1500, max = 1500, step = 1,
                get = function() return box.x end, set = function(_, v) box.x = v; ns.QoL_Refresh(box) end },
            y = { type = "range", name = "Y", order = 22, min = -900, max = 900, step = 1,
                get = function() return box.y end, set = function(_, v) box.y = v; ns.QoL_Refresh(box) end },
            unlock = { type = "execute", order = 23, width = "double",
                name = function() return ns.unlocked and "Lock (stop dragging)" or "Unlock (drag on screen)" end,
                func = function() ns.ToggleUnlock(); Notify() end },
            delete = { type = "execute", name = "Delete this box", order = 30, confirm = true, confirmText = "Delete this stats box?",
                func = function()
                    for idx, b in ipairs(ns.qolBoxes) do
                        if b == box then table.remove(ns.qolBoxes, idx); break end
                    end
                    ns.QoL_Drop(box)
                    Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allqol")
                end },
        },
    }
end

-------------------------------------------------------------------------------
-- Buff bars
-------------------------------------------------------------------------------
local function BuildBar(i, bar)
    local function on() ns.Bars_Refresh(bar); ns.MarkDirty() end
    local function onN() on(); Notify() end
    local barTab = {
        type = "group", name = "Bar", order = 1, args = {
            name = { type = "input", name = "Name", order = 1, width = "double",
                get = function() return bar.name end, set = function(_, v) if v ~= "" then bar.name = v end; Notify() end },
            enabled = Tog(bar, "enabled", "Enabled", 2, onN),
            buffSearch = SearchBox(2.9, function(id) bar.buffID = id; on(); Notify() end, nil, "aura"),
            buffID = { type = "input", name = "Aura spell ID", order = 3, width = "half",
                get = function() return tostring(bar.buffID) end,
                set = function(_, v) bar.buffID = tonumber(v) or 0; on(); Notify() end },
            buffName = { type = "description", order = 4, width = "double", fontSize = "medium", name = function() return SpellName(bar.buffID) end },
            showWhen = Sel(bar, "showWhen", "Show", 5, BAR_SHOW, BAR_SHOW_ORDER, on, { width = "double" }),
            combat = Sel(bar, "combat", "Combat", 6, { none = "(none - any)", yes = "Only in combat", no = "Only out of combat" }, TRI_ORDER, on, { width = "double" }),
            icon = Sel(bar, "icon", "Icon", 7, BAR_ICON, BAR_ICON_ORDER, on, { width = "double" }),
            note = { type = "description", order = 8, fontSize = "small", width = "full",
                name = "Buff bars are display-only. While Blizzard hides aura times (combat), the bar uses an experimental Blizzard duration object and may show full or empty. Use the eye icon in the sidebar to preview." },
            delete = { type = "execute", name = "Delete this bar", order = 20, confirm = true, confirmText = "Delete this buff bar?",
                func = function()
                    for idx, b in ipairs(ns.bars) do if b == bar then table.remove(ns.bars, idx); break end end
                    ns.Bars_Drop(bar); ns.MarkDirty(); Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allbars")
                end },
        },
    }
    local look = {
        type = "group", name = "Look", order = 2, args = {
            sizeH = { type = "header", name = "Size & Orientation", order = 1 },
            width = Rng(bar, "width", "Width", 2, 8, 800, 1, on),
            height = Rng(bar, "height", "Height", 3, 4, 300, 1, on),
            vertical = Tog(bar, "vertical", "Vertical orientation", 4, on),
            reverse = Tog(bar, "reverse", "Fill up as time passes (instead of draining)", 5, on, { width = "double" }),
            alpha = Rng(bar, "alpha", "Opacity", 6, 0, 1, 0.05, on),
            colH = { type = "header", name = "Texture & Colors", order = 10 },
            texture = Sel(bar, "texture", "Bar texture", 11, function() local v = ns.BarTextureList(); return v end,
                function() local _, o = ns.BarTextureList(); return o end, on, { width = "double" }),
            fill = Col(bar, "fillColor", "Fill color", 12, on),
            bg = Col(bar, "bgColor", "Background color", 13, on),
            spark = Tog(bar, "spark", "Show spark", 14, on),
            borderH = { type = "header", name = "Border", order = 20 },
            borderSize = Rng(bar, "borderSize", "Border size (px, 0 = none)", 21, 0, 8, 1, on),
            borderColor = Col(bar, "borderColor", "Border color", 22, on),
            posH = { type = "header", name = "Position (Used When the Group Layout Is Manual)", order = 30 },
            x = Rng(bar, "x", "X", 31, -1500, 1500, 1, on),
            y = Rng(bar, "y", "Y", 32, -900, 900, 1, on),
            unlock = { type = "execute", order = 33, width = "double",
                name = function() return ns.unlocked and "Lock (stop dragging)" or "Unlock (drag on screen)" end,
                func = function() ns.ToggleUnlock(); Notify() end },
        },
    }
    local text = {
        type = "group", name = "Text", order = 3, args = {
            font = FontSel(bar, 1, on),
            nameH = { type = "header", name = "Name", order = 10 },
            showName = Tog(bar, "showName", "Show name", 11, on),
            nameMode = Sel(bar, "nameMode", "Name text", 12, BAR_NAME, BAR_NAME_ORDER, on),
            customName = { type = "input", name = "Custom text", order = 13, width = "double",
                disabled = function() return ns.Val(bar.nameMode) ~= "custom" end,
                get = function() return bar.customName or "" end, set = function(_, v) bar.customName = v; on() end },
            nameSize = Rng(bar, "nameSize", "Name size", 14, 6, 48, 1, on),
            nameAnchor = Sel(bar, "nameAnchor", "Name position", 15, BAR_ANCHOR, BAR_ANCHOR_ORDER, on),
            timerH = { type = "header", name = "Timer", order = 20 },
            showTimer = Tog(bar, "showTimer", "Show remaining time", 21, on),
            timerSize = Rng(bar, "timerSize", "Timer size", 22, 6, 48, 1, on),
            timerAnchor = Sel(bar, "timerAnchor", "Timer position", 23, BAR_ANCHOR, BAR_ANCHOR_ORDER, on),
            decimals = Tog(bar, "decimals", "Show tenths (decimals)", 24, on),
            decimalBelow = Rng(bar, "decimalBelow", "Show tenths only below (seconds)", 25, 1, 30, 1, on,
                { width = "double", disabled = function() return not bar.decimals end }),
            stackH = { type = "header", name = "Stacks", order = 30 },
            showStacks = Tog(bar, "showStacks", "Show stacks", 31, on),
            stackSize = Rng(bar, "stackSize", "Stacks size", 32, 6, 48, 1, on),
            stackAnchor = Sel(bar, "stackAnchor", "Stacks position", 33, BAR_ANCHOR, BAR_ANCHOR_ORDER, on),
        },
    }
    do   -- name / timer / stacks options are drawn only while that element is switched on
        local a, cn = text.args, text.args.customName
        ns.GatePane(bar, a, "decimals", "Tenths options", 24.5, function() return bar.decimals end, { "decimalBelow" })
        ns.GatePane(bar, a, "name", "Name options", 11.5, function() return bar.showName end, { "nameMode", "customName", "nameSize", "nameAnchor" })
        cn.disabled = function() return ns.Val(bar.nameMode) ~= "custom" end   -- a choice inside the pane, not an on/off switch
        ns.GatePane(bar, a, "timer", "Timer options", 21.5, function() return bar.showTimer end, { "timerSize", "timerAnchor", "decimals", "pane_decimals" })
        ns.GatePane(bar, a, "stacks", "Stacks options", 31.5, function() return bar.showStacks end, { "stackSize", "stackAnchor" })
    end
    return {
        type = "group", childGroups = "tab", order = 10 + i,
        name = function() return (bar.enabled and "" or "|cff888888") .. bar.name end,
        args = { bar = barTab, look = look, text = text },
    }
end

-------------------------------------------------------------------------------
-- Profiles tab (export / import / saved profiles)
-------------------------------------------------------------------------------
local exportInc = { rules = true, bars = true, qol = true }
local exportText = ""
local importText, importSnap, importErr = "", nil, nil
local profileName, profileMsg = "", ""

local function ParseImport()
    importSnap, importErr = nil, nil
    if (importText or ""):match("%S") then
        importSnap, importErr = ns.Profile_Decode(importText)
    end
end

local function AddonVersion()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(get, addonName, "Version")
    return (ok and v) or "?"
end

-- Page switching (2026-10-31 UI pass): Class/Spec Rule Creator, Profiles (Export / Import) and Settings are not in the tab strip
-- while the skin is on. The toolbar buttons open them (ns.pageOpen) and the tab goes away again as soon as another tab is picked.
-- With the skin off (/xuiskin) they stay ordinary tabs, because the toolbar does not exist then.
function ns.PageHidden(key)
    return function() return (ns.SkinRows and ns.SkinRows()) and ns.pageOpen ~= key or false end
end

-- Settings > Display Options / Debugging readers (used by the tree painting and the debug console tray)
function ns.SelStyle() local u = CueRulesDB and CueRulesDB.ui; return (u and u.selStyle == "bar") and "bar" or "text" end
function ns.ParentGradientOn() local u = CueRulesDB and CueRulesDB.ui; return not (u and u.parentGradient == false) end
function ns.SidebarSpellIcons() local u = CueRulesDB and CueRulesDB.ui; return not (u and u.sidebarSpellIcons == false) end
function ns.GridOn() return true end   -- two-column grid is always on (no longer an option)
function ns.CondensedOn() local u = CueRulesDB and CueRulesDB.ui; return u and u.condensedList == true or false end

-- Window size override (Settings > UI Options > Window Size, issue #223). 0 = automatic (the built-in 780 x 860). A saved value is clamped to
-- the screen and to a usable minimum. It is applied on the first open each session (see the Open hook) and immediately when changed.
ns.PANE_DEFAULT_W, ns.PANE_DEFAULT_H = 780, 860
ns.PANE_MIN_W, ns.PANE_MIN_H = 600, 400
function ns.PaneSize()
    local u = CueRulesDB and CueRulesDB.ui
    local w, h = tonumber(u and u.paneW) or 0, tonumber(u and u.paneH) or 0
    local sw = UIParent and UIParent:GetWidth() or 1920
    local sh = UIParent and UIParent:GetHeight() or 1080
    if w <= 0 then w = ns.PANE_DEFAULT_W else w = math.max(ns.PANE_MIN_W, w) end
    if h <= 0 then h = ns.PANE_DEFAULT_H else h = math.max(ns.PANE_MIN_H, h) end
    return math.min(w, sw), math.min(h, sh)
end
function ns.ApplyPaneSize()
    local w, h = ns.PaneSize()
    local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
    if not ACD then return end
    pcall(ACD.SetDefaultSize, ACD, APP, w, h)   -- the size the next open uses
    local of = ACD.OpenFrames and ACD.OpenFrames[APP]
    if of and of.frame then pcall(of.frame.SetSize, of.frame, w, h) end   -- and the open window, right now
end
function ns.DebugConsoleOn() local u = CueRulesDB and CueRulesDB.ui; return not (u and u.hideTray) end

-- Settings: the addon's own behavior, as opposed to any one rule's. Opened from the toolbar (cog, far right); has its own tabs.
local function BuildAddonSettings()
    local function Ui() CueRulesDB.ui = CueRulesDB.ui or {}; return CueRulesDB.ui end
    local function Repaint() if ns.DecorateTrees then pcall(ns.DecorateTrees) end; Notify() end
    return { type = "group", name = "Settings", order = 7, childGroups = "tab", hidden = ns.PageHidden("settings"), args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = function() return "XayaUI v" .. AddonVersion() .. ". Settings here affect the whole addon, not any one rule." end },
        ui = { type = "group", name = "UI Options", order = 1, args = {
            displayHeader = { type = "header", name = "Display Options", order = 20 },
            selStyle = { type = "select", name = "Selected item in the rule list", order = 21, width = "double",
                desc = "How the row you have selected stands out in the left-hand list.",
                values = { text = "Alternate text color (light purple)", bar = "Highlighted bar over the item" },
                sorting = { "text", "bar" },
                get = function() return ns.SelStyle() end,
                set = function(_, v) Ui().selStyle = (v == "bar") and "bar" or "text"; Repaint() end },
            parentGradient = { type = "toggle", name = "Gradient highlight on the top parent group of a selected nested item", order = 22, width = "full",
                desc = "When the selected rule or group sits inside other groups, the topmost group of that chain gets a dark purple to black gradient (left to right). Off: no highlight on parent groups.",
                get = function() return ns.ParentGradientOn() end,
                set = function(_, v) Ui().parentGradient = v and true or false; Repaint() end },
            condensedList = { type = "toggle", name = "Condensed rule list (no icons, compact rows)", order = 25, width = "full",
                desc = "Drops the icons and the taller rows from the left-hand rule list and shows plain, compact rows with the +/- toggle on the left.",
                get = function() return ns.CondensedOn() end,
                set = function(_, v) Ui().condensedList = v and true or false; Repaint() end },
            paneHeader = { type = "header", name = "Window Size", order = 30 },
            paneNote = { type = "description", order = 30.5, width = "full",
                name = "Sets the size of this window when it opens. 0 = automatic (780 wide by 860 tall). Values are kept on screen and no smaller than 600 by 400. Dragging the window's corner still resizes it for the current session." },
            paneW = { type = "range", name = "Window width (0 = automatic)", order = 31, min = 0, max = 2560, step = 10, width = "double",
                get = function() return tonumber(Ui().paneW) or 0 end,
                set = function(_, v) Ui().paneW = v; if ns.ApplyPaneSize then ns.ApplyPaneSize() end end },
            paneH = { type = "range", name = "Window height (0 = automatic)", order = 32, min = 0, max = 1600, step = 10, width = "double",
                get = function() return tonumber(Ui().paneH) or 0 end,
                set = function(_, v) Ui().paneH = v; if ns.ApplyPaneSize then ns.ApplyPaneSize() end end },
            paneReset = { type = "execute", name = "Reset window size to automatic", order = 33, width = "double",
                func = function() Ui().paneW = 0; Ui().paneH = 0; if ns.ApplyPaneSize then ns.ApplyPaneSize() end; Notify() end },
            menuBtnHeader = { type = "header", name = "Menu button (ESC menu)", order = 23.5 },
            gameMenuButton = { type = "toggle", name = "Show a XayaUI button in the Game Menu (ESC menu)", order = 24, width = "full",
                desc = "Adds a XayaUI entry to the ESC menu that opens this window. Off: the entry is removed the next time the menu opens. Also: /xui gamemenu prints diagnostics.",
                get = function() return not (CueRulesDB and CueRulesDB.ui and CueRulesDB.ui.hideGameMenuButton) end,
                set = function(_, v) Ui().hideGameMenuButton = (not v) or nil; if ns.GameMenu_OnOptionChanged then ns.GameMenu_OnOptionChanged() end end },
            gameMenuStyle = { type = "select", name = "Menu button style", order = 24.1, width = "double",
                desc = "Gradient button: a class-colored gradient fill with solid text. Standard button: the same flat button as the rest of the UI (inherits the theme's button colors) with class-colored gradient text.",
                values = { gradient = "Gradient button, solid text", standard = "Standard button, gradient text" },
                sorting = { "gradient", "standard" },
                get = function() return (CueRulesDB and CueRulesDB.ui and CueRulesDB.ui.gameMenuStyle) or "gradient" end,
                set = function(_, v) Ui().gameMenuStyle = v; if ns.GameMenu_Repaint then ns.GameMenu_Repaint() end end },
            sidebarSpellIcons = { type = "toggle", name = "Show a rule's spell / buff icon in the rule list", order = 23, width = "full",
                desc = "Rules that track a spell or buff show that spell's icon in the left-hand list instead of the generic type icon. Each rule can override this in its Display Options (Sidebar icon).",
                get = function() return ns.SidebarSpellIcons() end,
                set = function(_, v) Ui().sidebarSpellIcons = v and true or false; Repaint() end },
        } },
        theme = { type = "group", name = "Theme", order = 1.5, args = ns.Theme and ns.Theme.BuildArgs(Repaint) or {} },
        debug = { type = "group", name = "Debugging", order = 2, args = {
            debugHeader = { type = "header", name = "Debugging", order = 10 },
            advancedDebug = { type = "toggle", name = "Advanced Debugging (recommended)", order = 11, width = "full",
                desc = "When a Lua error happens inside XayaUI, print it to the chat window as a system message (in addition to whatever BugSack or the default Lua-error UI already does). Off: XayaUI stays silent about its own errors in chat.",
                get = function() return CueRulesDB and CueRulesDB.ui and CueRulesDB.ui.advancedDebug and true or false end,
                set = function(_, v) Ui().advancedDebug = v and true or false end },
            showConsole = { type = "toggle", name = "Show the debug console at the bottom of the window", order = 12, width = "full",
                desc = "The strip under the window with the live rule status and event log. Off: it is not drawn at all (turn it back on here).",
                get = function() return ns.DebugConsoleOn() end,
                set = function(_, v) Ui().hideTray = (not v) or nil; Notify() end },
            consoleWin = { type = "toggle", name = "Console window (separate from this window)", order = 13, width = "full",
                desc = "The same event log as the strip under this window, but in its own movable, resizable window. It keeps collecting lines while this window is closed and during combat. Also: /xui console.",
                get = function() return ns.ConsoleWindowOn and ns.ConsoleWindowOn() or false end,
                set = function(_, v) if ns.ConsoleWindow then ns.ConsoleWindow(v and true or false) end end },
            consoleCopy = { type = "execute", name = "Copy the console text", order = 13.5, width = "double",
                desc = "Opens a box with every console line as plain text, selected and ready for Ctrl+C.",
                func = function() if ns.CopyConsole then ns.CopyConsole() end end },
            bug = { type = "group", inline = true, name = "Bug report", order = 20, args = {
                bugInfo = { type = "description", order = 1, fontSize = "medium",
                    name = function()
                        local total, kinds = 0, 0
                        if ns.ErrorCount then total, kinds = ns.ErrorCount() end
                        return "XayaUI keeps its own Lua errors (" .. total .. " so far, " .. kinds .. " different) and saves them between sessions. The report holds the version, the game build, those errors and the last console lines. It never includes your character name, realm, or the contents of your rules. Send it to Xaya or paste it into a GitHub issue."
                    end },
                bugText = { type = "input", name = "What happened  (optional)", order = 2, width = "full", multiline = 4,
                    get = function() return Ui().bugText or "" end,
                    set = function(_, v) v = tostring(v or ""):sub(1, 600); Ui().bugText = (v ~= "") and v or nil end },
                bugAddons = { type = "toggle", name = "Also list my loaded addons", order = 3, width = "full",
                    desc = "Off by default: your addon list says a lot about you. Turn on if the problem may be a clash with another addon.",
                    get = function() return Ui().bugAddons and true or false end,
                    set = function(_, v) Ui().bugAddons = v and true or nil end },
                bugMake = { type = "execute", name = "Create bug report", order = 4, width = "double",
                    desc = "Opens a box with the report, selected and ready for Ctrl+C. Also: /xui bug.",
                    func = function() if ns.ShowBugReport then ns.ShowBugReport() end end },
                bugClear = { type = "execute", name = "Clear the error log", order = 5, width = "normal", confirm = true,
                    confirmText = "Clear XayaUI's saved Lua errors?",
                    func = function() if ns.ClearErrorLog then ns.ClearErrorLog() end; Notify() end },
            } },
            auraSetup = { type = "group", inline = true, name = "Combat Tracking Setup", order = 29, args = {
                asText = { type = "description", order = 1, fontSize = "medium",
                    name = "Scans YOUR class, spec and talents, reads the game's own spell text, and learns real buff durations from your own casts out of combat. Works for every class. Runs once per spec, and any time you change talents or gear." },
                asOpen = { type = "execute", name = "Open Combat Tracking Setup", order = 2, width = "double",
                    func = function() if ns.AuraSetup_Open then ns.AuraSetup_Open() else ns.Print("combat tracking setup is not loaded") end end },
                asPresence = { type = "toggle", name = "Estimate buffs the game hides in combat (from your own casts)", order = 3, width = "full",
                    get = function() return ns.AuraModel and ns.AuraModel.PresenceEnabled() end,
                    set = function(_, v) if ns.AuraModel then ns.AuraModel.SetSetting("presence", v and true or false) end end },
            } },
            gameDump = { type = "group", inline = true, name = "Game Data Capture (separate tool)", order = 30,
                hidden = function() return not _G.XayaUIGameDump end, args = {
                gdText = { type = "description", order = 1, fontSize = "medium",
                    name = "Pulls every class, spec, talent, spell description, spellbook entry, piece of gear, and set-bonus line the game will give an addon, and records which auras each ability you press causes and for how long. It is a separate addon (XayaUI_GameDump) with its own saved-data file, so nothing here touches your rules or profile." },
                gdOpen = { type = "execute", name = "Open Game Data Capture", order = 2, width = "double",
                    func = function()
                        local g = _G.XayaUIGameDump
                        if g and g.Toggle then g.Toggle()
                        else ns.Print("XayaUI_GameDump is not loaded. Enable the XayaUI_GameDump addon, then /reload.") end
                    end },
            } },
        } },
    } }
end

-------------------------------------------------------------------------------
-- Class / Spec Rule Creator tab. "Add Vengeance DH test rules" makes (or finds) the static group "VDH Test Rules" and opens a
-- tick list of auras; "Add ticked auras" then adds one SKELETON rule per tick to that group: aura present, nothing shown or
-- played yet (what each rule does is still to be defined, GitHub issue "Define what Class/Spec Rule Creator rules do").
-------------------------------------------------------------------------------
-- id = the buff aura's spell ID, filled in ONLY where it is confirmed by Xaya's own logs / screenshots (src says where).
-- nil = the ID box starts empty and she enters it; the "game says" text beside each box reads the name live from the game.
local BuildClassCreator   -- the only main-chunk local the creator adds (Lua allows 200); its helpers live inside the do-block
do
local VDH_AURAS = {
    { key = "demonspikes", name = "Demon Spikes", id = 203819, src = "from the old seed rule in Core.lua; NOT independently confirmed (203720 is the ability, not the buff). Check the 'game says' text." },
    { key = "fierybrand", name = "Fiery Brand", note = "204021 is the cast, not a buff ID" },
    { key = "metamorphosis", name = "Metamorphosis", id = 187827, src = "your debug log (Vengeance Metamorphosis buff)" },
    { key = "darkness", name = "Darkness", note = "196718 is the ability; buff ID not found" },
    { key = "soulbarrier", name = "Soul Barrier" },
    { key = "lastresort", name = "Last Resort" },
    { key = "calcifiedspikes", name = "Calcified Spikes", note = "389720 is the talent; buff ID not found" },
    { key = "incorruptible", name = "Incorruptible Spirit" },
    { key = "ruinousbulwark", name = "Ruinous Bulwark" },
    { key = "armyunto", name = "Army Unto Oneself" },
    { key = "evasiveaction", name = "Evasive Action" },
    { key = "immolationaura", name = "Immolation Aura", id = 258920, src = "your debug log (Immolation Aura)" },
    { key = "soulmonger", name = "Soulmonger", id = 391234, src = "your debug log / tooltip screenshot" },
    { key = "soulfragments", name = "Soul Fragments" },
    { key = "painbringer", name = "Painbringer" },
    { key = "untetheredrage", name = "Untethered Rage", id = 1270476, src = "your request tracker" },
    { key = "revelinpain", name = "Revel in Pain" },
    { key = "feastofsouls", name = "Feast of Souls" },
    { key = "furyaldrachi", name = "Fury of the Aldrachi" },
    { key = "artofglaive", name = "Art of the Glaive" },
    { key = "reaversmark", name = "Reaver's Mark" },
    { key = "seethinganger", name = "Seething Anger" },
    { key = "thrill1", name = "Thrill of the Fight", id = 442686, src = "your Tracked Buffs list (first entry)" },
    { key = "thrill2", name = "Thrill of the Fight", id = 1227062, src = "your Tracked Buffs list (second entry)" },
    { key = "voidfall", name = "Voidfall", note = "1253304 may be the talent, not an aura" },
    { key = "catastrophe", name = "Catastrophe" },
    { key = "doomsayer", name = "Doomsayer" },
    { key = "felfirefist", name = "Felfire Fist" },
    { key = "soulcarver", name = "Soul Carver" },
    { key = "sigilflame", name = "Sigil of Flame" },
    { key = "sigilmisery", name = "Sigil of Misery" },
    { key = "sigilchains", name = "Sigil of Chains" },
}
local VDH_GROUP, VDH_SPEC = "VDH Test Rules", 581   -- 581 = Vengeance
local creatorSel, creatorMsg, creatorOpen = {}, nil, false   -- ticks / message / list shown: this session only
local function CreatorIDs()
    CueRulesDB.ui = CueRulesDB.ui or {}
    CueRulesDB.ui.creatorIDs = CueRulesDB.ui.creatorIDs or {}   -- IDs she typed (kept with the profile); 0 = cleared
    return CueRulesDB.ui.creatorIDs
end
local function AuraID(a)
    local v = CreatorIDs()[a.key]
    if v == nil then return a.id end
    v = tonumber(v)
    return (v and v > 0) and v or nil
end
local function AuraStatus(a)
    local id = AuraID(a)
    if not id then return "|cffff8080ID needed|r" .. (a.note and ("  |cff999999" .. a.note .. "|r") or "") end
    local ok, nm = pcall(C_Spell.GetSpellName, id)
    if not ok or not nm then return "|cffff8080the game has no spell with this ID|r" end
    local want, have = a.name:lower(), nm:lower()
    if have == want or have:find(want, 1, true) or want:find(have, 1, true) then return "|cff80ff80game says: " .. nm .. "|r" end
    return "|cffffb040game says: " .. nm .. " (name differs - check the ID)|r"
end
local function FindVDHGroup()
    for _, f in ipairs(ns.folders or {}) do if not f.parent and f.name == VDH_GROUP then return f end end
end
local function OpenVDHList()
    local grp, made = FindVDHGroup(), false
    if not grp then grp = ns.NewFolder(VDH_GROUP); made = true end   -- no cType = static group
    creatorOpen = true
    creatorMsg = made and ("Created the static group |cffffd100" .. VDH_GROUP .. "|r (it shows under Smart Categories). Tick the auras below, then press Add ticked auras.")
        or ("The static group |cffffd100" .. VDH_GROUP .. "|r already exists; new rules are added to it.")
    ns.MarkDirty(); if ns.OnRulesChanged then pcall(ns.OnRulesChanged) end
    Notify()
end
local function AddTickedAuras()
    local grp = FindVDHGroup()
    if not grp then creatorMsg = "|cffffb040The group is missing - press Add Vengeance DH test rules again.|r"; Notify(); return end
    local have = {}
    for _, r in ipairs(ns.rules or {}) do if r.folder == grp.id and (tonumber(r.buffID) or 0) ~= 0 then have[r.buffID] = true end end
    local made, noID, dup, ticked = 0, {}, 0, 0
    for _, a in ipairs(VDH_AURAS) do
        if creatorSel[a.key] then
            ticked = ticked + 1
            local id = AuraID(a)
            if not id then noID[#noID + 1] = a.name
            elseif have[id] then dup = dup + 1
            else
                local r = ns.NewRule()
                r.name = a.name
                r.folder = grp.id
                r.useBuff, r.buffID, r.buffState = true, id, "present"
                r.cdState, r.talentMode = "none", "none"
                r.load.specs = { [tostring(VDH_SPEC)] = true }
                ns.rules[#ns.rules + 1] = r
                have[id] = true
                creatorSel[a.key] = nil
                made = made + 1
            end
        end
    end
    if ticked == 0 then creatorMsg = "|cffffb040Tick at least one aura first.|r"
    else
        local line = ("Added %d rule(s) to %s."):format(made, VDH_GROUP)
        if dup > 0 then line = line .. (" %d already in the group (same ID), skipped."):format(dup) end
        if #noID > 0 then line = line .. " |cffffb040No ID yet, skipped: " .. table.concat(noID, ", ") .. ".|r" end
        creatorMsg = line
        if made > 0 then ns.MarkDirty(); if ns.OnRulesChanged then pcall(ns.OnRulesChanged) end end
    end
    ns.Print("rule creator: " .. (creatorMsg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
    Notify()
end
function BuildClassCreator()
    local function shown() return not creatorOpen end
    local args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Pick a class / spec set, tick the auras to track, and XayaUI makes a skeleton rule for each one: it watches for the aura being present, and shows or plays nothing yet. Set what each rule does afterwards under Smart Categories." },
        apHdr = { type = "header", order = 0.1, name = "Auto-populate my class / spec" },
        apInfo = { type = "description", order = 0.2, width = "full", fontSize = "medium",
            name = function()
                local specID = ns.CurrentSpecID and ns.CurrentSpecID()
                local okS, _, specName = pcall(GetSpecializationInfoByID, specID or 0)
                return "Detected: |cffffd100" .. (UnitClass("player") or "?") .. " - " .. ((okS and specName) or "unknown spec") .. "|r. It makes one skeleton rule (cooldown ready) per spellbook or talent cooldown of that spec, read from this game client (the addon remembers each spec once you have played it), sorted into Defensive / Offensive / Utility / Unsorted inside the static group '<Class> <Spec> - autorule population' by the name list for that spec, and flags each rule (kind, role, talent, charges). The window jumps to the new group." end },
        apTalents = { type = "toggle", order = 0.3, width = "full", name = "Include talents I have not picked (rule only loads when the talent is known)",
            get = function() return ns.AutoCfg().talents ~= false end,
            set = function(_, v) ns.AutoCfg().talents = v and true or false; ns.MarkDirty(); Notify() end },
        apClass = { type = "execute", order = 0.58, width = 1.6, xuiCenter = true, name = "Auto-populate for my class (all specs)",
            desc = "Runs the auto-populate for every spec of your class in one go.",
            func = function()
                local _, m = ns.ClassAutoPopulateAllSpecs(ns.AutoCfg().talents ~= false)
                creatorMsg = m; ns.Print("auto-populate: " .. tostring(m)); Notify()
            end },
        talHdr = { type = "header", order = 0.6, name = "All talents (every class and spec)" },
        talInfo = { type = "description", order = 0.61, width = "full", fontSize = "medium",
            name = function() return (ns.TalentStatus and ns.TalentStatus() or "") .. " Reads every class, spec, and hero talent tree from the game (not from a fixed list), so it follows the current patch. In chat: /xui talents, /xui talents status, /xui talents <name>." end },
        talScan = { type = "execute", order = 0.62, width = "double", name = "Scan all talents now",
            func = function()
                local ok, m = ns.ScanAllTalents(function(_, msg) creatorMsg = msg; Notify() end)
                creatorMsg = m; ns.Print(m); Notify()
            end },
        -- the "Add Vengeance DH test rules" button is gone: every class and spec is supported by the auto-populate above (Xaya, 2026-11-01)
        msg = { type = "description", order = 0.5, width = "full", fontSize = "medium", name = function() return creatorMsg or "" end,
            hidden = function() return not creatorMsg end },
        idNote = { type = "description", order = 4, width = "full", fontSize = "small", hidden = shown,
            name = "ID = the aura's buff spell ID. Only IDs confirmed in your own logs are filled in; the rest are blank for you to enter (hover a name for the source). 'game says' is read live from the game, so a wrong ID shows up as a different name." },
        add = { type = "execute", order = 5, width = "double", name = "Add ticked auras", hidden = shown, func = AddTickedAuras },
        none = { type = "execute", order = 6, width = "normal", name = "Untick all", hidden = shown,
            func = function() wipe(creatorSel); Notify() end },
        close = { type = "execute", order = 7, width = "half", name = "Hide list", hidden = shown,
            func = function() creatorOpen = false; Notify() end },
    }
    -- one button per spec of the player's class, each with the spec's own icon (specs come from the game, so any class works)
    for i = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
        local sid, sname, _, sicon = GetSpecializationInfo(i)
        if sid then
            args["apBrk" .. i] = { type = "description", order = 0.47 + i * 0.01 + 0.005, width = "full", fontSize = "small", name = " " }
            args["apSpec" .. i] = { type = "execute", order = 0.47 + i * 0.01, width = 1.6, xuiCenter = true,
                name = (sicon and ("|T" .. sicon .. ":16|t ") or "") .. "Auto-populate " .. tostring(sname),
                desc = "Makes the skeleton rules for " .. tostring(sname) .. " (" .. (UnitClass("player") or "your class") .. "), whichever spec you are in now.",
                func = function()
                    local _, m = ns.ClassAutoPopulateSpec(sid, ns.AutoCfg().talents ~= false)
                    creatorMsg = m; ns.Print("auto-populate: " .. tostring(m)); Notify()
                end }
        end
    end
    for i, a in ipairs(VDH_AURAS) do
        local o = 100 + i * 3
        args["pick_" .. a.key] = { type = "toggle", order = o, width = 1.3, name = a.name, hidden = shown,
            desc = a.src and ("ID source: " .. a.src) or (a.note or "No confirmed ID yet - enter it in the box."),
            get = function() return creatorSel[a.key] and true or false end,
            set = function(_, v) creatorSel[a.key] = v and true or nil end }
        args["id_" .. a.key] = { type = "input", order = o + 1, width = 0.6, name = "", hidden = shown,
            get = function() local id = AuraID(a); return id and tostring(id) or "" end,
            set = function(_, v) local n = tonumber(v); CreatorIDs()[a.key] = (n and n > 0) and math.floor(n) or 0; ns.MarkDirty(); Notify() end }
        args["st_" .. a.key] = { type = "description", order = o + 2, width = 1.5, fontSize = "medium", hidden = shown,
            name = function() return AuraStatus(a) end }
    end
    return { type = "group", name = "Class/Spec Rule Creator", order = 2, hidden = ns.PageHidden("creator"), args = args }
end
end   -- do (class/spec creator)

local function BuildProfiles()
    local a = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Your rules are personal. Nothing is shared unless you export it, and a fresh install starts empty. Export produces a text string you can paste to a friend; they paste it under 'Import' to add it to their own setup." },
        exportTotal = { type = "execute", name = "Export total profile  (everything, one click)", order = 0.5, width = "full",
            desc = "Bundles ALL rules with their groups and container settings into one export string (buff bars and QoL elements too, when those are switched on), ignoring the ticks below. The text appears just under this button.",
            func = function()
                local all = { rules = true, bars = true, qol = true }
                local txt, err = ns.Profile_Encode(ns.Profile_Snapshot(all, (profileName ~= "" and profileName) or "Total profile"))
                exportText = txt or ("Could not export: " .. tostring(err))
                profileMsg = txt and ("Exported everything: " .. ns.Profile_Describe(ns.Profile_Snapshot(all, "")) .. ". Copy the text below.") or ""
                Notify()
            end },
        totalBox = { type = "input", name = "Total profile text  (click, Ctrl+A, Ctrl+C)", order = 0.6, width = "full", multiline = 4,
            hidden = function() return exportText == nil or exportText == "" end,
            get = function() return exportText end, set = function() end },
        exportH = { type = "header", name = "Export What You Have", order = 1 },
        incRules = Tog(exportInc, "rules", "Cooldown + Aura rules (with their groups)", 2, function() end, { width = "double" }),
        incBars = Tog(exportInc, "bars", "Buff bars (and their group layout)", 3, function() end, { width = "double", hidden = function() return not ns.BarsOn end }),
        incQol = Tog(exportInc, "qol", "QoL elements", 4, function() end, { width = "double", hidden = function() return not ns.QoLOn end }),
        gen = { type = "execute", name = "Generate export text", order = 5, width = "double",
            func = function()
                local txt, err = ns.Profile_Encode(ns.Profile_Snapshot(exportInc, profileName))
                exportText = txt or ("Could not export: " .. tostring(err))
                Notify()
            end },
        exportBox = { type = "input", name = "Export text  (click, Ctrl+A, Ctrl+C)", order = 6, width = "full", multiline = 6,
            get = function() return exportText end, set = function() end },
        importH = { type = "header", name = "Import From Text", order = 10 },
        importBox = { type = "input", name = "Paste a profile string here, then press Accept", order = 11, width = "full", multiline = 6,
            get = function() return importText end,
            set = function(_, v) importText = v or ""; ParseImport(); Notify() end },
        importInfo = { type = "description", order = 12, width = "full", fontSize = "medium",
            name = function()
                if importErr then return "|cffff5555" .. importErr .. "|r" end
                if importSnap then
                    local nm = (importSnap.name and importSnap.name ~= "") and ("Profile '" .. importSnap.name .. "': ") or ""
                    return "|cff55ff55Readable.|r " .. nm .. ns.Profile_Describe(importSnap)
                end
                return "Nothing pasted yet."
            end },
        importGo = { type = "execute", name = "Import", order = 14, width = "half",
            desc = "Adds everything in the string as one new folder of its own; your existing rules are not touched.",
            disabled = function() return not importSnap end,
            func = function()
                local c = ns.Profile_Apply(importSnap, "add")
                profileMsg = ("Imported %d rule(s), %d group(s), %d bar(s), %d QoL box(es)."):format(c.rules, c.folders, c.bars, c.qol)
                ns.Print(profileMsg)
                Notify()
            end },
        msg = { type = "description", order = 15, width = "full", name = function() return profileMsg end },
        savedH = { type = "header", name = "Profiles Saved on This Computer", order = 20 },
        saveName = { type = "input", name = "Profile name", order = 21, width = "double",
            get = function() return profileName end, set = function(_, v) profileName = v or "" end },
        savePick = { type = "select", name = "Or pick an existing profile to overwrite", order = 21.5, width = "double",
            values = function() local v = {}; for _, p in ipairs(ns.Profiles()) do v[p.name] = p.name end return v end,
            sorting = function() local o = {}; for _, p in ipairs(ns.Profiles()) do o[#o + 1] = p.name end table.sort(o, function(x, y) return tostring(x):lower() < tostring(y):lower() end) return o end,
            get = function() for _, p in ipairs(ns.Profiles()) do if p.name == profileName then return p.name end end end,
            set = function(_, v) profileName = v or ""; Notify() end },
        save = { type = "execute", order = 22, width = "double",
            name = function()
                for _, p in ipairs(ns.Profiles()) do if p.name == profileName then return "Save and overwrite '" .. profileName .. "'" end end
                return "Save current setup"
            end,
            desc = "Saves a snapshot of the parts ticked under Export. If the name matches an existing profile, that profile is replaced after you confirm.",
            confirm = function()
                for _, p in ipairs(ns.Profiles()) do if p.name == profileName then return true end end
                return false
            end,
            confirmText = "Overwrite the saved profile with your current setup? Its old contents are lost.",
            func = function()
                local ok, msg = ns.Profile_Save(profileName, exportInc)
                profileMsg = ok and ("Profile '" .. profileName .. "' " .. msg .. ".") or ("|cffff5555" .. msg .. "|r")
                Notify()
            end },
    }
    for idx, p in ipairs(ns.Profiles()) do
        a["p" .. idx] = {
            type = "group", inline = true, order = 30 + idx, name = p.name,
            args = {
                desc = { type = "description", order = 1, width = "full", name = ns.Profile_Describe(p.data) },
                add = { type = "execute", name = "Load (add)", order = 2, width = "half",
                    func = function() local c = ns.Profile_Apply(ns.Copy(p.data), "add"); profileMsg = ("Added %d rule(s), %d bar(s), %d QoL box(es)."):format(c.rules, c.bars, c.qol); Notify() end },
                replace = { type = "execute", name = "Load (replace)", order = 3, width = "half",
                    confirm = true, confirmText = "Replace the included parts of your current setup with this profile?",
                    func = function() local c = ns.Profile_Apply(ns.Copy(p.data), "replace"); profileMsg = ("Loaded '%s'."):format(p.name); Notify() end },
                export = { type = "execute", name = "Show export text", order = 4, width = "half",
                    func = function() exportText = ns.Profile_Encode(p.data) or ""; Notify() end },
                delete = { type = "execute", name = "Delete", order = 5, width = "half",
                    confirm = true, confirmText = "Delete this saved profile?",
                    func = function() ns.Profile_Delete(idx); Notify() end },
            },
        }
    end
    return { type = "group", name = "Profiles", order = 6, hidden = ns.PageHidden("profiles"), args = a }
end

-------------------------------------------------------------------------------
-- Top level: horizontal tabs. Each of the first three has a tree with an "All" node.
-------------------------------------------------------------------------------
local newOpts = { sound = false, visual = false } -- what "+ New rule" turns on
-- A Display Cues rule is display-only and a Sound Cues rule is sound-only: the one output it has starts on.
-- Everywhere else the two "New rules ..." tick boxes decide. (r.folder must already be set.)
local function ApplyNewOpts(r)
    local k = ns.RuleKind(r)
    if k == "display" then r.visual.enabled, r.sound.enabled = true, false
    elseif k == "sound" then r.sound.enabled, r.visual.enabled = true, false
    else
        r.sound.enabled = newOpts.sound and true or false
        r.visual.enabled = newOpts.visual and true or false
    end
end

-- "+ New rule" opens an intermediate page (a list of rule types) instead of creating a blank rule.
-- Sound Cues folders skip it: they only hold sound rules, so there is nothing to choose.
-- Smart Categories: a virtual root whose sub-lists are filled from what each rule actually does (nothing is moved or
-- forced into a folder; a rule that shows an icon AND text appears under both). Buff bars come from their own list.
ns.SMART_CATS = {
    { key = "smart_icon",    name = "Icons" },
    { key = "smart_progtex", name = "Progress Textures" },
    { key = "smart_bar",     name = "Progress Bars" },
    { key = "smart_tex",     name = "Textures" },
    { key = "smart_text",    name = "Text" },
    { key = "smart_sound",   name = "Sounds" },
}
function ns.SmartMatch(rule, key)
    if not rule then return false end
    if not rule.isCue and rule.uid and ns.CuesOf then   -- a rule counts under every type its cues have
        for _, c in ipairs(ns.CuesOf(rule)) do if ns.SmartMatch(c, key) then return true end end
    end
    if key == "smart_sound" then
        -- "Play a sound" ticked but no sound chosen is not a sound: it would play nothing
        local sv = rule.sound and rule.sound.value
        return (rule.sound and rule.sound.enabled and sv ~= nil and sv ~= "" and ns.KindHas(rule, "sound")) and true or false
    end
    local v = rule.visual
    if not (v and v.enabled and ns.KindHas(rule, "visual")) then return false end
    local isIcon = ns.Val(v.kind) == "spellicon"
    local fill = v.fill and v.fill.enabled and true or false
    if key == "smart_icon" then return isIcon end
    if key == "smart_progtex" then return fill end
    if key == "smart_text" then return (v.text and v.text.enabled) and true or false end
    if key == "smart_tex" then return (not isIcon) and (not fill) and (v.texAlpha == nil or v.texAlpha > 0) end
    return false
end
function ns.SmartAny(rule)
    for _, c in ipairs(ns.SMART_CATS) do
        if c.key ~= "smart_bar" and ns.SmartMatch(rule, c.key) then return true end
    end
    return false
end

local picker = nil   -- { folder = id|nil } while the page is open
local function CreateRuleOfType(typ, fid)
    local r = ns.NewRule()
    r.name = ""   -- new rules are not auto-named: the sidebar row opens a name box for it instead
    r.folder = fid
    ns.rules[#ns.rules + 1] = r
    if typ == "custom" then
        -- fully blank: no display, no sound, no cues, nothing pre-loaded
        r.visual.enabled, r.sound.enabled = false, false
    elseif typ then
        -- the chosen type becomes the rule's first cue (Cues tab), already set up for that type; the rule itself shows / plays nothing
        r.visual.enabled, r.sound.enabled = false, false
        -- one explicit cue kind per picker row: Icon -> icon cue, Texture / Progress Texture -> texture cue, Text -> text cue, Sound -> sound cue
        local CUE_FOR_TYPE = { icon = "icon", text = "text", sound = "sound", texture = "texture", progresstex = "texture" }
        local kind = CUE_FOR_TYPE[typ] or "texture"
        r.uid = r.uid or ns.NewUID()
        local cue = ns.NewCueRule(r, kind)
        if ns.Log then ns.Log("new rule: picker row '%s' -> cue kind '%s' (cue made: %s)", tostring(typ), kind, tostring(cue ~= nil)) end
        if cue then
            local v = cue.visual
            if kind ~= "icon" and ns.Val(v.kind) == "spellicon" then v.kind = nil end   -- only an Icon row may start as a spell icon
            if typ == "icon" then v.kind = "spellicon"; v.w, v.h = 64, 64; v.desatOnCD = true
            elseif typ == "progresstex" then
                v.fill.enabled = true
                v.overlay.enabled = true      -- progress textures are two-layered by default: base (reduced opacity below) + overlay (full)
                v.texAlpha = 0.35              -- reduced base opacity; ratio to Overlay opacity (1) is preserved while locked (see ProgLocked)
            elseif typ == "text" then v.text.enabled = true; v.texAlpha = 0 end
        end
    end
    ns.pendingRename = r
    if ns.DraftNew then ns.DraftNew(r) end   -- never saved yet: Save changes keeps it, closing the window first moves it to Drafts
    Notify()
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, RulePath(r))
    ns.pickOrigin = nil
end
function ns.GoPicker()   -- show the picker page of the sub-tab the New Rule button was pressed in
    local sub = ns.pickSub
    if sub == "enabledTab" then pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "enabledTab", "loaded")
    elseif sub == "disabledTab" then pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "disabledTab", "disabled")
    elseif sub == "draftsTab" then pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "draftsTab")
    else pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "smartTab", "all") end
end
local function StartNewRule(fid)
    if ns.RuleKind({ folder = fid }) == "sound" then CreateRuleOfType(nil, fid); return end
    if not picker then
        ns.pickOrigin = ns.CurrentTab()
        -- the picker opens in the Rules sub-tab that is open now (Enabled / Drafts / Disabled keep their tab; anything else uses Smart Categories)
        local sub = (ns.pickOrigin == "cooldowns" or ns.pickOrigin == "smartcat") and ns.CurrentSub() or nil
        ns.pickSub = (sub == "enabledTab" or sub == "draftsTab" or sub == "disabledTab" or sub == "smartTab") and sub or nil
    end
    picker = { folder = fid }
    if ns.pageOpen == "settings" then ns.pageOpen = nil; ns.infoOpen = false end   -- a toolbar button other than Settings leaves the Settings pages
    Notify()
    ns.GoPicker()
end
-- Auto-populate: one rule per spell of the current class / spec whose base cooldown is >= the folder's threshold.
-- Rules already in this folder (or its subfolders) for the same spell are skipped, so it is safe to run again after a
-- respec or a talent change.
local autoMsg = {}   -- folder id -> last result line
local AUTO_SCOPE_VALUES = {
    spec = "This specialization only (rules load only on this spec)",
    any  = "Any specialization (rules load on every spec)",
}
-- Settings live in CueRulesDB.ui.auto (one global set, used by the sidebar row "AUTO-POPULATE RULES"), not on each folder.
function ns.AutoCfg()
    CueRulesDB.ui = CueRulesDB.ui or {}
    local a = CueRulesDB.ui.auto
    if not a then a = {}; CueRulesDB.ui.auto = a end
    if a.minCD == nil then a.minCD = 30 end
    if a.scope == nil then a.scope = "spec" end
    if a.talents == nil then a.talents = true end
    if a.enabled == nil then a.enabled = true end
    return a
end
-- destination folder id (nil = top level). Default: the Hybrid Cues category.
function ns.AutoDest(a)
    if a.dest == "none" then return nil end
    if a.dest and ns.FolderById(a.dest) then return a.dest end
    for _, f in ipairs(ns.folders or {}) do
        if not f.parent and f.default == "hybrid" then return f.id end
    end
    return nil
end
function ns.AutoHave(fid)
    local have = {}
    local list = fid and FolderRules(fid) or {}
    if not fid then for _, r in ipairs(ns.rules or {}) do if not r.folder then list[#list + 1] = r end end end
    for _, r in ipairs(list) do if (tonumber(r.spellID) or 0) ~= 0 then have[r.spellID] = true end end
    return have
end
local function AutoPopulate()
    local a = ns.AutoCfg()
    local fid = ns.AutoDest(a)
    local minSec = tonumber(a.minCD) or 30
    local list = ns.CollectCooldownSpells(minSec, a.talents ~= false)
    local have = ns.AutoHave(fid)
    local specID = ns.CurrentSpecID and ns.CurrentSpecID()
    local specOnly = (a.scope or "spec") == "spec"
    local kit = SOUNDKIT and SOUNDKIT.RAID_WARNING and tostring(SOUNDKIT.RAID_WARNING) or ""
    local made, skipped = 0, 0
    for _, sp in ipairs(list) do
        if have[sp.id] then
            skipped = skipped + 1
        else
            local r = ns.NewRule()
            r.name = sp.name
            r.folder = fid
            ApplyNewOpts(r)
            if not r.sound.enabled and not r.visual.enabled then r.sound.enabled = true end   -- Hybrid folders: sound by default
            r.spellID = sp.id
            r.cdState, r.buffState, r.talentMode = "ready", "none", "none"
            if sp.talent then r.talents, r.talentMode = { { id = sp.id, state = "known" } }, "all" end
            if specOnly and specID then r.load.specs = { [tostring(specID)] = true } end
            r.enabled = a.enabled ~= false
            if r.sound.enabled then r.sound.source, r.sound.value = "kit", kit end
            if r.visual.enabled then
                local v = r.visual
                v.kind, v.trigger, v.w, v.h, v.desatOnCD = "spellicon", "condition", 64, 64, true
                v.x, v.y = ((made % 8) - 3.5) * 68, -60 * math.floor(made / 8)
            end
            ns.rules[#ns.rules + 1] = r
            made = made + 1
        end
    end
    for _, r in ipairs(ns.rules) do if r.folder == fid then pcall(ns.RefreshVisual, r) end end
    ns.MarkDirty()
    if ns.OnRulesChanged then pcall(ns.OnRulesChanged) end
    autoMsg.last = ("Added %d rule(s); %d already in that group were skipped."):format(made, skipped)
    ns.Print("auto-populate: " .. autoMsg.last)
    Notify()
end
local function AutoPreview()
    local a = ns.AutoCfg()
    local ok, list = pcall(ns.CollectCooldownSpells, tonumber(a.minCD) or 30, a.talents ~= false)
    if not ok or type(list) ~= "table" then return "Could not read your spellbook / talents right now." end
    local have = ns.AutoHave(ns.AutoDest(a))
    local fresh, names = 0, {}
    for _, sp in ipairs(list) do
        if not have[sp.id] then
            fresh = fresh + 1
            if #names < 12 then names[#names + 1] = ("%s (%ss)"):format(sp.name, (math.floor(sp.cd * 10 + 0.5) / 10)) end
        end
    end
    local line = ("%d spell(s) match, %d new."):format(#list, fresh)
    if #names > 0 then line = line .. " Next: " .. table.concat(names, ", ") .. (fresh > #names and ", ..." or "") end
    if autoMsg.last then line = line .. "\n|cff80ff80" .. autoMsg.last .. "|r" end
    return line
end

-- Class / spec auto-populate (Class/Spec Rule Creator tab): one skeleton rule per cooldown spell of the current spec, sorted into
-- Defensive / Offensive / Utility folders inside one parent folder "<Class> <Spec> - autorule population". The sorting tables are
-- curated by spell NAME (never by ID, so no ID is guessed; a name that is not in the spellbook is simply never matched). Spells
-- that are not in the spec's table go to "Unsorted". Only cooldown spells are found (auras cannot be listed from the spellbook).
local SPEC_SORT = {
    -- Demon Hunter / Vengeance. Curated by Claude from general class knowledge, NOT checked against game data: edit freely.
    [581] = {
        Defensive = { "Demon Spikes", "Fiery Brand", "Metamorphosis", "Darkness", "Soul Barrier", "Blur", "Netherwalk" },
        Offensive = { "Fel Devastation", "Soul Carver", "The Hunt", "Sigil of Flame", "Immolation Aura", "Fracture", "Soul Cleave", "Spirit Bomb", "Throw Glaive", "Felblade" },
        Utility   = { "Sigil of Misery", "Sigil of Chains", "Sigil of Silence", "Chaos Nova", "Disrupt", "Imprison", "Consume Magic", "Torment", "Infernal Strike", "Vengeful Retreat", "Spectral Sight", "Glide" },
    },
}
function ns.AutoPopulateSpellbook(includeUnpicked)   -- fallback: spellbook cooldowns only (a spec ClassLearn.lua has not learned yet)
    local specID = ns.CurrentSpecID and ns.CurrentSpecID()
    if not specID then return false, "Could not read your specialization right now." end
    local className = UnitClass("player") or "Class"
    local okS, _, specName = pcall(GetSpecializationInfoByID, specID)
    if not okS or not specName then specName = "spec " .. tostring(specID) end
    local ok, list = pcall(ns.CollectCooldownSpells, 0, includeUnpicked)
    if not ok or type(list) ~= "table" or #list == 0 then return false, "Found no cooldown spells in your spellbook right now." end
    local parentName = className .. " " .. specName .. " - autorule population"
    local parent
    for _, f in ipairs(ns.folders) do if not f.parent and f.name == parentName then parent = f; break end end
    parent = parent or ns.NewFolder(parentName)
    local function Sub(name)
        for _, f in ipairs(ns.folders) do if f.parent == parent.id and f.name == name then return f end end
        return ns.NewFolder(name, parent.id)
    end
    Sub("Defensive"); Sub("Offensive"); Sub("Utility")
    local lookup, curated = {}, SPEC_SORT[specID]
    if curated then for folder, names in pairs(curated) do for _, n in ipairs(names) do lookup[n:lower()] = folder end end end
    local have = {}
    for _, r in ipairs(FolderRules(parent.id)) do if (tonumber(r.spellID) or 0) ~= 0 then have[r.spellID] = true end end
    local made, skipped, counts = 0, 0, {}
    for _, sp in ipairs(list) do
        if have[sp.id] then skipped = skipped + 1
        else
            local fname = lookup[(sp.name or ""):lower()] or "Unsorted"
            local dest = Sub(fname)
            local r = ns.NewRule()
            r.name, r.folder, r.spellID = sp.name, dest.id, sp.id
            r.useCooldown = true
            r.cdState, r.buffState, r.talentMode = "ready", "none", "none"
            if sp.talent then r.talents, r.talentMode = { { id = sp.id, state = "known" } }, "all" end
            r.load.specs = { [tostring(specID)] = true }
            ns.rules[#ns.rules + 1] = r
            have[sp.id] = true
            made = made + 1; counts[fname] = (counts[fname] or 0) + 1
        end
    end
    if made > 0 then ns.MarkDirty(); if ns.OnRulesChanged then pcall(ns.OnRulesChanged) end end
    local parts = {}
    for _, k in ipairs({ "Defensive", "Offensive", "Utility", "Unsorted" }) do if counts[k] then parts[#parts + 1] = k .. " " .. counts[k] end end
    local msg = ("%s: added %d rule(s) (%s); %d already there."):format(parentName, made, #parts > 0 and table.concat(parts, ", ") or "none", skipped)
    if not curated then msg = msg .. " There is no curated Defensive / Offensive / Utility list for this spec yet, so everything went to Unsorted." end
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, FolderPath(parent))   -- show the new group right away
    return true, msg
end

-- Data-driven auto-populate (ClassLearn.lua: the cooldown list learned from this game client for each spec you have played). One skeleton rule per entry of the
-- CURRENT spec, in  "<Class> <Spec> - autorule population" > Cooldowns | Auras | Procs > Defensive | Offensive | Utility | Unsorted.
-- Every rule is also FLAGGED on the rule itself so it can be sorted later: r.autoKind ("cd" | "aura" | "proc"), r.autoRole, r.autoFlags
-- (talent, hero, glow, charges, rt, inferred, midnight) and r.autoSrc. Target debuffs are in the data and flagged "debuff" but get NO rule:
-- the rule engine only reads auras on YOU. IDs are checked against the live game; ones that no longer exist are skipped and counted.
do   -- block-scoped: Options.lua's main chunk is close to Lua's 200-local limit
local KIND_FOLDER = { cd = "Cooldowns", aura = "Auras", proc = "Procs" }
local function AutoPopulateData(specID, data, includeUnpicked)
    local className = UnitClass("player") or data.class or "Class"
    local okS, _, specName = pcall(GetSpecializationInfoByID, specID)
    if not okS or not specName then specName = data.spec or ("spec " .. tostring(specID)) end
    local parentName = className .. " " .. specName .. " - autorule population"
    local parent
    for _, f in ipairs(ns.folders) do if not f.parent and f.name == parentName then parent = f; break end end
    parent = parent or ns.NewFolder(parentName)
    local function Sub(name, pid)
        for _, f in ipairs(ns.folders) do if f.parent == pid and f.name == name then return f end end
        return ns.NewFolder(name, pid)
    end
    local have = { cd = {}, buff = {} }
    for _, r in ipairs(FolderRules(parent.id)) do
        if r.autoKind == "aura" or r.autoKind == "proc" then
            if (tonumber(r.buffID) or 0) ~= 0 then have.buff[r.buffID] = true end
        elseif (tonumber(r.spellID) or 0) ~= 0 then have.cd[r.spellID] = true end   -- cooldown rules, including ones from the old spellbook path
    end
    local cdName, dataCd = {}, {}
    for _, e in ipairs(data.entries) do if e.kind == "cd" then cdName[e.name] = true; dataCd[e.id] = true end end
    local counts, made, skipped, gone, noCd, talentOff, debuffs, extra = {}, 0, 0, 0, 0, 0, 0, 0
    local function Put(kind, role, r)
        local kf = Sub(KIND_FOLDER[kind], parent.id)
        r.folder = Sub(role, kf.id).id
        r.load.specs = { [tostring(specID)] = true }
        ns.rules[#ns.rules + 1] = r
        made = made + 1
        local k = KIND_FOLDER[kind] .. "/" .. role
        counts[k] = (counts[k] or 0) + 1
    end
    for _, e in ipairs(data.entries) do
        if e.kind == "debuff" then debuffs = debuffs + 1
        else
            local okN, nm = pcall(C_Spell.GetSpellName, e.id)
            if not okN or not nm then gone = gone + 1
            else
                local fl = {}
                for _, k in ipairs({ "talent", "hero", "glow", "charges", "rt", "totem", "selfBuff", "inferred" }) do if e[k] then fl[#fl + 1] = k end end
                if e.mn then fl[#fl + 1] = "midnight" end
                local function Tag(r)
                    r.autoKind, r.autoRole, r.autoFlags, r.autoSrc = e.kind, e.role, table.concat(fl, ","), "learned from this client"
                end
                if e.kind == "cd" then
                    if have.cd[e.id] then skipped = skipped + 1
                    elseif e.talent and not includeUnpicked and ns.ReadTalentKnown(e.id) == false then talentOff = talentOff + 1
                    else
                        local base = ns.BaseCooldownSec and ns.BaseCooldownSec(e.id) or 0
                        if base <= 0 and not e.charges then noCd = noCd + 1   -- no cooldown to watch: a "ready" rule would always be true
                        else
                            local r = ns.NewRule()
                            r.name, r.spellID, r.useCooldown = nm, e.id, true
                            r.cdState, r.buffState, r.talentMode = "ready", "none", "none"
                            if e.talent then r.talents, r.talentMode = { { id = e.id, state = "known" } }, "all" end
                            Tag(r); Put("cd", e.role, r); have.cd[e.id] = true
                        end
                    end
                else   -- aura / proc: a buff on you
                    if have.buff[e.id] then skipped = skipped + 1
                    else
                        local r = ns.NewRule()
                        r.name = cdName[nm] and (nm .. (e.kind == "proc" and " (proc)" or " (aura)")) or nm
                        r.buffID, r.useBuff, r.buffState = e.id, true, "present"
                        r.cdState, r.talentMode = "none", "none"
                        Tag(r); Put(e.kind, e.role, r); have.buff[e.id] = true
                    end
                end
            end
        end
    end
    -- spellbook cooldowns the data does not list (new patch spells, off-list talents) still come in, flagged "spellbook"
    local ok, list = pcall(ns.CollectCooldownSpells, 0, includeUnpicked)
    if ok and type(list) == "table" then
        local lookup = {}
        for folder, names in pairs(SPEC_SORT[specID] or {}) do for _, n in ipairs(names) do lookup[n:lower()] = folder end end
        for _, sp in ipairs(list) do
            if not dataCd[sp.id] and not have.cd[sp.id] then
                local r = ns.NewRule()
                r.name, r.spellID, r.useCooldown = sp.name, sp.id, true
                r.cdState, r.buffState, r.talentMode = "ready", "none", "none"
                if sp.talent then r.talents, r.talentMode = { { id = sp.id, state = "known" } }, "all" end
                r.autoKind, r.autoRole, r.autoFlags, r.autoSrc = "cd", lookup[(sp.name or ""):lower()] or "Unsorted", "spellbook" .. (sp.talent and ",talent" or ""), "spellbook scan"
                Put("cd", r.autoRole, r); have.cd[sp.id] = true; extra = extra + 1
            end
        end
    end
    if made > 0 then ns.MarkDirty(); if ns.OnRulesChanged then pcall(ns.OnRulesChanged) end end
    local keys = {}
    for k in pairs(counts) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. " " .. counts[k] end
    local msg = ("%s: added %d rule(s) (%s); %d already there."):format(parentName, made, #parts > 0 and table.concat(parts, ", ") or "none", skipped)
    if extra > 0 then msg = msg .. (" %d of them are spellbook cooldowns the data did not list."):format(extra) end
    if gone > 0 then msg = msg .. (" %d data entries skipped: no such spell in this game version."):format(gone) end
    if noCd > 0 then msg = msg .. (" %d abilities skipped: no cooldown to watch."):format(noCd) end
    if talentOff > 0 then msg = msg .. (" %d talent cooldowns skipped (talent not picked, option off)."):format(talentOff) end
    if debuffs > 0 then msg = msg .. (" %d target debuffs are listed in the data but no rules were made (rules only read auras on you)."):format(debuffs) end
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, FolderPath(parent))
    return true, msg
end
function ns.ClassAutoPopulate(includeUnpicked)
    local specID = ns.CurrentSpecID and ns.CurrentSpecID()
    local data = specID and ns.CLASS_AURA_DATA and ns.CLASS_AURA_DATA[specID]
    if data then return AutoPopulateData(specID, data, includeUnpicked) end
    return ns.AutoPopulateSpellbook(includeUnpicked)
end
-- One chosen spec of the player's class (any spec, not only the active one). Needs the spec to have been learned (played once); the spellbook fallback only knows the active spec.
function ns.ClassAutoPopulateSpec(specID, includeUnpicked)
    local data = specID and ns.CLASS_AURA_DATA and ns.CLASS_AURA_DATA[specID]
    if data then return AutoPopulateData(specID, data, includeUnpicked) end
    if specID == (ns.CurrentSpecID and ns.CurrentSpecID()) then return ns.AutoPopulateSpellbook(includeUnpicked) end
    return false, "That spec has not been learned yet: switch to it once (the addon reads its spellbook and talents a few seconds after you log in or change spec), then try again."
end
-- Every spec of the player's class, one after another (specs without data are named in the summary, not silently skipped).
function ns.ClassAutoPopulateAllSpecs(includeUnpicked)
    local made, skipped = 0, {}
    for i = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
        local id, name = GetSpecializationInfo(i)
        if id then
            local ok = ns.ClassAutoPopulateSpec(id, includeUnpicked)
            if ok then made = made + 1 else skipped[#skipped + 1] = tostring(name) end
        end
    end
    local msg = ("Auto-populated %d spec(s) of %s."):format(made, UnitClass("player") or "your class")
    if #skipped > 0 then msg = msg .. " Not learned yet (play each once): " .. table.concat(skipped, ", ") .. "." end
    return made > 0, msg
end
end   -- do

ns.UI.NewRule = function() StartNewRule(nil) end
local function PickType(typ)
    local p = picker
    picker = nil
    if typ == "bar" then
        local b = ns.NewBar()
        b.name = "Buff bar " .. (#ns.bars + 1)
        ns.bars[#ns.bars + 1] = b
        pcall(ns.Bars_Refresh, b)
        ns.MarkDirty(); Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allbars", "bar" .. #ns.bars)
    elseif typ == "dgroup" or typ == "sgroup" then
        -- a rule group is a folder (the container): nested inside the folder the picker was opened from, top level otherwise
        local nf = ns.NewFolder((typ == "dgroup" and "Dynamic Group" or "Static Group"), p and p.folder)
        if typ == "dgroup" then nf.cType = "dynamic" end
        local path = { ns.PlaceNewGroup(nf, nf.parent and ns.CurrentScope() or "loaded") }
        ns.MarkDirty(); Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, unpack(path))
    elseif typ == "import" then
        Notify()   -- closes the type picker where it is; Import is a window of its own and does not change tabs
        if ns.OpenImportWindow then ns.OpenImportWindow() end
    elseif typ == "profiles" then   -- the Profiles tab itself (Export button)
        ns.pageOpen = "profiles"; ns.infoOpen = false
        Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "profiles")
    else
        CreateRuleOfType(typ, p and p.folder)
    end
end
ns.UI.Import = function() PickType("import") end
-- toolbar buttons (Skin.lua): Import opens its own window; Export opens the Profiles page; Creator and Settings open their own page
ns.UI.Export = function() PickType("profiles") end
ns.UI.Refresh = Notify   -- redraw the options window in place (used by the Import window)
function ns.OpenPage(key)
    if key == "drafts" or key == "creator" then   -- Drafts and the Class/Spec Rule Creator are sub-tabs of Rules now, not pages of their own
        ns.pageOpen = nil; ns.infoOpen = false
        Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", key == "drafts" and "draftsTab" or "creatorTab")
        return
    end
    ns.pageOpen = key; ns.infoOpen = false
    Notify()
    local skinned = ns.SkinRows and ns.SkinRows()
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, (key == "settings" and skinned) and "set" or key)
end
ns.UI.Creator = function() ns.OpenPage("creator") end
ns.UI.Drafts = function() ns.OpenPage("drafts") end
ns.UI.RecycleBin = function() ns.OpenPage("recyclebin") end   -- toolbar button, next to Export
ns.UI.Cursor = function()   -- the Cursor options live under QoL UI Updates > Cursor now (no tab of their own)
    ns.pageOpen = nil; ns.infoOpen = false
    Notify()
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "cursor")
end
ns.UI.DataPanels = function(tab)   -- QoL UI Updates > Custom Data Panels and Bars (also /xui data, right-click on any strip); tab = a tab key such as "chatpanels"
    if not (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]) then pcall(ns.ToggleUI) end
    ns.pageOpen = nil; ns.infoOpen = false
    Notify()
    if tab then pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "datapanels", tab)
    else pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "datapanels") end
end
ns.UI.Notepad = function()   -- QoL UI Updates > Notepad (also /xui notepad opens the box itself)
    if not (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]) then pcall(ns.ToggleUI) end
    ns.pageOpen = nil; ns.infoOpen = false
    Notify()
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "notepad")
end
ns.UI.Settings = function()
    -- the Settings button is a switch: a second click leaves the settings pages and brings the Rules tabs back
    if ns.pageOpen == "settings" and ns.SkinRows and ns.SkinRows() then
        ns.pageOpen = nil
        Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns")
    else
        ns.OpenPage("settings")
    end
end

local function FolderRuleCount(f)
    return #FolderRules(f.id)
end

-- Session-only choices for "apply to all rules in this folder" (nothing here is saved).
local folderApply = setmetatable({}, { __mode = "k" })

local function FolderApplyGroup(f)
    local function st()
        local t = folderApply[f]
        if not t then t = { targets = { dur = true, cnt = true, abs = true } }; folderApply[f] = t end
        return t
    end
    local ch = setmetatable({}, { __index = function(_, k) return st()[k] end, __newindex = function(_, k, v) st()[k] = v end })
    local TARGETS = { dur = "Buff Duration Text", cnt = "Stacks / Charges Count", abs = "Shield / Absorb Amount" }
    local ONOFF = { on = "Turn On", off = "Turn Off" }
    local function nRules() return #FolderRules(f.id) end
    return {
        type = "group", inline = true, order = 6,
        name = "Apply Text Settings to All Rules in This Group",
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Choose which text elements to change and what to change, then press Apply. A blank choice (or 0) leaves that setting alone. Includes rules in nested groups. Nothing is changed until you press Apply." },
            targets = { type = "multiselect", name = "Text Elements to Change", order = 1, width = "full", values = TARGETS,
                get = function(_, k) return st().targets[k] and true or false end,
                set = function(_, k, v) st().targets[k] = v and true or nil end },
            font = { type = "select", name = "Font", order = 2,
                values = function() local v = ns.FontList(); return v end,
                sorting = function() local _, o = ns.FontList(); return o end,
                get = function() return st().font end, set = function(_, v) st().font = v end },
            size = { type = "range", name = "Text Size (0 = Leave As Is)", order = 3, min = 0, max = 96, step = 1,
                get = function() return st().size or 0 end, set = function(_, v) st().size = v > 0 and v or nil end },
            outline = Sel(ch, "outline", "Outline", 4, TEXT_OUTLINE, TEXT_OUTLINE_ORDER, function() end),
            place = Sel(ch, "place", "Placement", 5, TEXT_PLACE, TEXT_PLACE_ORDER, function() end),
            anchor = Sel(ch, "anchor", "Position", 6, TEXT_ANCHOR, TEXT_ANCHOR_ORDER, function() end),
            enable = { type = "select", name = "Show Selected Text Elements", order = 7, values = ONOFF, sorting = { "on", "off" },
                get = function() return st().enable end, set = function(_, v) st().enable = v end },
            decimals = { type = "select", name = "Tenths (Decimals) on Duration Text", order = 8, values = ONOFF, sorting = { "on", "off" },
                get = function() return st().decimals end, set = function(_, v) st().decimals = v end },
            decimalBelow = { type = "range", name = "Tenths Only Below (Seconds, 0 = Leave As Is)", order = 9, min = 0, max = 30, step = 1, width = "double",
                get = function() return st().decimalBelow or 0 end, set = function(_, v) st().decimalBelow = v > 0 and v or nil end },
            apply = { type = "execute", order = 20, width = "double",
                name = function() return "Apply to " .. nRules() .. " Rule(s)" end,
                confirm = true, confirmText = "Overwrite the chosen text settings on every rule in this group (and its nested groups)?",
                func = function()
                    local c = st()
                    local keys = { dur = "text", cnt = "count", abs = "absorb" }
                    local n = 0
                    for _, r in ipairs(FolderRules(f.id)) do
                        for tk, vk in pairs(keys) do
                            local t = c.targets[tk] and r.visual[vk]
                            if t then
                                if c.font then t.font = c.font end
                                if c.size then t.size = c.size end
                                if c.outline then t.outline = c.outline end
                                if c.place then t.place = c.place end
                                if c.anchor then t.anchor = c.anchor end
                                if c.enable then t.enabled = (c.enable == "on") end
                                if tk == "dur" then
                                    if c.decimals then t.decimals = (c.decimals == "on") end
                                    if c.decimalBelow then t.decimalBelow = c.decimalBelow end
                                end
                            end
                        end
                        ns.RefreshVisual(r)
                        n = n + 1
                    end
                    ns.MarkDirty(); Notify()
                    ns.Print(("applied text settings to %d rule(s) in group '%s'"):format(n, f.name))
                end },
        },
    }
end

local LOAD_OV_VALUES = {
    none = "Don't Override (Each Rule Uses Its Own Load Conditions)",
    never = "Never (No Rule in This Group Loads)",
    always = "Always (Ignore Each Rule's Load Conditions)",
}
local LOAD_OV_ORDER = { "none", "never", "always" }
local function FolderLoadGroup(f)
    local g = {
        type = "group", inline = true, order = 5.5, name = "Load Conditions for This Group",
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Overrides the Load tab of every rule in this group and its nested groups while they are inside it. Nothing on the rules is changed: a rule that leaves the group uses its own load conditions again. Talent requirements still apply. A nested group's own choice beats the group above it." },
            inherited = { type = "description", order = 2, width = "full", fontSize = "medium",
                hidden = function() if f.loadOverride then return true end; return not ns.FolderLoadOverrideFrom(f.parent) end,
                name = function()
                    local ov, of = ns.FolderLoadOverrideFrom(f.parent)
                    if not ov then return "" end
                    return "Inherited from group |cffffd100" .. tostring(of and of.name) .. "|r: " .. (ov == "never" and "Never" or "Always")
                end },
        },
    }
    AddSquareRadio(g.args, "mode", 0.9, LOAD_OV_VALUES, LOAD_OV_ORDER,
        function() return f.loadOverride or "none" end,
        function(v) f.loadOverride = (v == "never" or v == "always") and v or nil; ns.MarkDirty(); Notify() end)
    return g
end

-- Folder = container: group type (static / dynamic) plus alpha, scale, strata / level and screen position.
-- ns function (not a local) to stay under Lua's 200-locals-per-chunk limit.
function ns.FolderContainerGroup(f)
    local function apply() ns.MarkDirty(); pcall(ns.RefreshAllVisuals); Notify() end
    local POINTS = { "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
    local PV = {}
    for _, p in ipairs(POINTS) do PV[p] = p:sub(1, 1) .. p:sub(2):lower() end
    PV.TOPLEFT, PV.TOPRIGHT, PV.BOTTOMLEFT, PV.BOTTOMRIGHT = "Top left", "Top right", "Bottom left", "Bottom right"
    local STRATA = { "inherit", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
    local SV = { inherit = "(default - High)", BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium", HIGH = "High", DIALOG = "Dialog",
        FULLSCREEN = "Fullscreen", FULLSCREEN_DIALOG = "Fullscreen dialog", TOOLTIP = "Tooltip" }
    local RELS = { "screen", "player", "target", "focus", "minimap", "chat", "custom" }
    local RV = { screen = "Screen center (or the parent group)", player = "Player frame", target = "Target frame", focus = "Focus frame",
        minimap = "Minimap", chat = "Main chat frame", custom = "Another frame (type its name)" }
    local function isDyn() return f.cType == "dynamic" end
    local g = { type = "group", inline = true, order = 5.4, name = "Group Type & Container",
        hidden = function() return not ns.KindHas({ folder = f.id }, "visual") end,
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Every group is a container for the displays inside it (and inside its nested groups). Static: each display keeps its own position. Dynamic: the addon lays the visible displays out itself and ignores their own X / Y. The container settings below apply to everything inside. Width / height give the container a fixed box (also what the anchor point refers to); a dynamic group wraps onto a new row / column when its items would exceed that size." },
        } }
    AddSquareRadio(g.args, "ctype", 1, { static = "Static group  (items keep their own positions)", dynamic = "Dynamic group  (positions its items automatically)" },
        { "static", "dynamic" }, function() return isDyn() and "dynamic" or "static" end,
        function(v) f.cType = (v == "dynamic") and "dynamic" or nil; apply() end)
    g.args.growth = { type = "select", name = "Grow direction", order = 2, width = "double", hidden = function() return not isDyn() end,
        values = { RIGHT = "Right", LEFT = "Left", DOWN = "Down", UP = "Up", HCENTER = "Centered, horizontal", VCENTER = "Centered, vertical" },
        sorting = { "RIGHT", "LEFT", "DOWN", "UP", "HCENTER", "VCENTER" },
        get = function() return f.cGrowth or "RIGHT" end, set = function(_, v) f.cGrowth = v; apply() end }
    g.args.spacing = { type = "range", name = "Spacing between items", order = 2.1, width = "double", min = 0, max = 200, step = 1,
        hidden = function() return not isDyn() end,
        get = function() return f.cSpacing or 4 end, set = function(_, v) f.cSpacing = v; apply() end }
    g.args.sort = { type = "select", name = "Sort items", order = 2.2, width = "double", hidden = function() return not isDyn() end,
        values = { none = "None (in rule order)", asc = "By name, A to Z", desc = "By name, Z to A" },
        sorting = { "none", "asc", "desc" },
        get = function() return f.cSort or "none" end, set = function(_, v) f.cSort = (v ~= "none") and v or nil; apply() end }
    g.args.alpha = { type = "range", name = "Group opacity", order = 3, min = 0, max = 1, step = 0.05,
        get = function() return f.cAlpha or 1 end, set = function(_, v) f.cAlpha = (v < 1) and v or nil; apply() end }
    g.args.scale = { type = "range", name = "Group scale", order = 3.01, min = 0.25, max = 3, step = 0.05,
        get = function() return f.cScale or 1 end, set = function(_, v) f.cScale = (v ~= 1) and v or nil; apply() end }
    g.args.width = { type = "range", name = "Container width (0 = no fixed size)", order = 3.05, min = 0, max = 1500, step = 1,
        get = function() return f.cW or 0 end, set = function(_, v) f.cW = (v > 0) and v or nil; apply() end }
    g.args.height = { type = "range", name = "Container height (0 = no fixed size)", order = 3.06, min = 0, max = 1500, step = 1,
        get = function() return f.cH or 0 end, set = function(_, v) f.cH = (v > 0) and v or nil; apply() end }
    g.args.clip = { type = "toggle", name = "Clip contents to the container size (hide anything outside it)", order = 3.07, width = "full",
        get = function() return f.cClip and true or false end, set = function(_, v) f.cClip = v and true or nil; apply() end }
    g.args.strata = { type = "select", name = "Layer (strata)", order = 3.2, values = SV, sorting = STRATA,
        get = function() return f.cStrata or "inherit" end, set = function(_, v) f.cStrata = (v ~= "inherit") and v or nil; apply() end }
    g.args.level = { type = "range", name = "Z-index within the layer (0 = automatic)", order = 3.3, min = 0, max = 200, step = 1,
        get = function() return f.cLevel or 0 end, set = function(_, v) f.cLevel = (v > 0) and v or nil; apply() end }
    g.args.relH = { type = "header", name = "Group position", order = 4 }
    g.args.moveOn = { type = "execute", order = 4.05, width = "double",
        name = function() return ns.IsGroupUnlocked and ns.IsGroupUnlocked(f) and "Lock group (stop dragging)" or "Move group on screen (drag its outline)" end,
        desc = "Shows one outline around this group's displays; drag it to set the X / Y offset below. The lock icon on the group's row in the sidebar does the same.",
        func = function() if ns.SetGroupUnlocked then ns.SetGroupUnlocked(f, not ns.IsGroupUnlocked(f)) end; Notify() end }
    g.args.rel = { type = "select", name = "Relative to", order = 4.1, width = "double", values = RV, sorting = RELS,
        get = function() return f.cRel or "screen" end, set = function(_, v) f.cRel = (v ~= "screen") and v or nil; apply() end }
    g.args.relName = { type = "input", name = "Frame name", order = 4.2, width = "double", hidden = function() return f.cRel ~= "custom" end,
        desc = "The global name of any frame, e.g. PlayerFrame or MultiBarBottomLeft. If it does not exist the group falls back to the screen.",
        get = function() return f.cFrame or "" end, set = function(_, v) f.cFrame = (v ~= "") and v or nil; apply() end }
    g.args.point = { type = "select", name = "This group's anchor point", order = 4.3, values = PV, sorting = POINTS,
        get = function() return f.cPoint or "CENTER" end, set = function(_, v) f.cPoint = (v ~= "CENTER") and v or nil; apply() end }
    g.args.relPoint = { type = "select", name = "Point on the frame it is relative to", order = 4.4, values = PV, sorting = POINTS,
        get = function() return f.cRelPoint or f.cPoint or "CENTER" end, set = function(_, v) f.cRelPoint = v; apply() end }
    g.args.x = { type = "range", name = "X offset", order = 4.5, min = -1500, max = 1500, step = 1, softMin = -600, softMax = 600,
        get = function() return f.cX or 0 end, set = function(_, v) f.cX = (v ~= 0) and v or nil; apply() end }
    g.args.y = { type = "range", name = "Y offset", order = 4.6, min = -1500, max = 1500, step = 1, softMin = -600, softMax = 600,
        get = function() return f.cY or 0 end, set = function(_, v) f.cY = (v ~= 0) and v or nil; apply() end }
    return g
end

-- Static group tools: Align, Distribute and Space the displays inside the group by editing their own X / Y.
-- ns function (not a local) to stay under Lua's 200-locals-per-chunk limit.
function ns.FolderArrangeGroup(f)
    local gap = 8
    local function items()
        local l = {}
        for _, r in ipairs(FolderRules(f.id)) do
            local v = r.visual
            if type(v) == "table" and v.enabled then l[#l + 1] = r end
        end
        return l
    end
    local function R(n) return math.floor(n + 0.5) end
    local function done(n, what)
        for _, r in ipairs(items()) do pcall(ns.RefreshVisual, r) end
        ns.MarkDirty(); Notify()
        ns.Print(("%s: %d display(s) in group '%s'"):format(what, n, tostring(f.name)))
    end
    local function Act(what, fn)
        local l = items()
        if #l < 2 then ns.Print("a group needs at least two displays to " .. what:lower()); return end
        -- the tools work on center offsets; each display's own anchor is converted in and out so mixed anchors line up correctly
        for _, r in ipairs(l) do local cx, cy = ns.VisualCenterOffset(r); r.visual.x, r.visual.y = cx, cy end
        fn(l)
        for _, r in ipairs(l) do ns.SetVisualCenterOffset(r, r.visual.x, r.visual.y) end
        done(#l, what)
    end
    local function dims(r) local v = r.visual; return tonumber(v.x) or 0, tonumber(v.y) or 0, tonumber(v.w) or 0, tonumber(v.h) or 0 end
    local function alignX(mode) Act("Align", function(l)
        local lo, hi = math.huge, -math.huge
        for _, r in ipairs(l) do local x, _, w = dims(r); lo = math.min(lo, x - w / 2); hi = math.max(hi, x + w / 2) end
        for _, r in ipairs(l) do local _, _, w = dims(r)
            r.visual.x = R(mode == "left" and lo + w / 2 or mode == "right" and hi - w / 2 or (lo + hi) / 2) end
    end) end
    local function alignY(mode) Act("Align", function(l)
        local top, bot = -math.huge, math.huge
        for _, r in ipairs(l) do local _, y, _, h = dims(r); top = math.max(top, y + h / 2); bot = math.min(bot, y - h / 2) end
        for _, r in ipairs(l) do local _, _, _, h = dims(r)
            r.visual.y = R(mode == "top" and top - h / 2 or mode == "bottom" and bot + h / 2 or (top + bot) / 2) end
    end) end
    local function distribute(horiz) Act("Distribute", function(l)
        table.sort(l, function(a, b) local ax, ay = dims(a); local bx, by = dims(b); if horiz then return ax < bx end return ay > by end)
        local n = #l
        local ax, ay = dims(l[1]); local bx, by = dims(l[n])
        for i, r in ipairs(l) do
            if horiz then r.visual.x = R(ax + (bx - ax) * (i - 1) / (n - 1)) else r.visual.y = R(ay + (by - ay) * (i - 1) / (n - 1)) end
        end
    end) end
    local function space(horiz) Act("Space", function(l)
        table.sort(l, function(a, b) local ax, ay = dims(a); local bx, by = dims(b); if horiz then return ax < bx end return ay > by end)
        local cur
        for i, r in ipairs(l) do
            local x, y, w, h = dims(r)
            if horiz then
                if i == 1 then cur = x + w / 2 else r.visual.x = R(cur + gap + w / 2); cur = r.visual.x + w / 2 end
            else
                if i == 1 then cur = y - h / 2 else r.visual.y = R(cur - gap - h / 2); cur = r.visual.y - h / 2 end
            end
        end
    end) end
    local function B(order, name, fn) return { type = "execute", order = order, width = 1.1, name = name, func = fn } end
    return { type = "group", inline = true, order = 5.45, name = "Align & Arrange (Static Group)",
        hidden = function() return f.cType == "dynamic" or not ns.KindHas({ folder = f.id }, "visual") end,
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Group tools: these edit the X / Y of the displays inside this group (and nested groups) so they line up, spread out evenly, or sit a fixed gap apart. Use Unlock visuals to see the result." },
            l = B(1, "Align left", function() alignX("left") end), c = B(2, "Align center", function() alignX("center") end), r = B(3, "Align right", function() alignX("right") end),
            t = B(4, "Align top", function() alignY("top") end), m = B(5, "Align middle", function() alignY("middle") end), b = B(6, "Align bottom", function() alignY("bottom") end),
            dh = B(7, "Distribute horizontally", function() distribute(true) end), dv = B(8, "Distribute vertically", function() distribute(false) end),
            gap = { type = "range", order = 9, width = "double", name = "Gap for Space (pixels)", min = 0, max = 200, step = 1,
                get = function() return gap end, set = function(_, v) gap = v end },
            sh = B(10, "Space horizontally", function() space(true) end), sv = B(11, "Space vertically", function() space(false) end),
        } }
end

local function FolderSoundGroup(f)
    return {
        type = "group", inline = true, order = 5.6, name = "Sound Channel for This Group",
        hidden = function() return ns.RuleKind({ folder = f.id }) == "display" end,
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Forces every rule in this group and its nested groups to play on this channel, whatever the rule itself says. Nothing on the rules is changed: a rule that leaves the group uses its own channel again. A nested group's own choice beats the group above it." },
            channel = { type = "select", name = "Enforced sound channel", order = 1, width = "double",
                values = CHANNEL_VALUES, sorting = CHANNEL_ORDER,
                get = function() return f.soundChannel or "none" end,
                set = function(_, v) f.soundChannel = (v ~= "none") and v or nil; ns.MarkDirty(); Notify() end },
            inherited = { type = "description", order = 2, width = "full", fontSize = "medium",
                hidden = function() if f.soundChannel then return true end; return not ns.FolderSoundChannelFrom(f.parent) end,
                name = function()
                    local ch, of = ns.FolderSoundChannelFrom(f.parent)
                    if not ch then return "" end
                    return "Inherited from group |cffffd100" .. tostring(of and of.name) .. "|r: " .. tostring(ch)
                end },
        },
    }
end

local function BuildFolder(k, f)
    local dinfo, dpos = ns.DefaultFolderInfo(f.default)
    if f.default == "cursor" and not f.parent then
        -- Mouse Cursor Cues: no folder tools here; the only content is a jump to the Cursor Tracker settings
        return {
            type = "group", order = ns.FolderSortOrder(f, k, dpos),
            name = function() return tostring(f.name) .. " (" .. FolderRuleCount(f) .. ")" end,
            args = {
                note = { type = "description", order = 1, width = "full", fontSize = "medium",
                    name = "The mouse cursor texture and its at-cursor reminders are set up in QoL Elements." },
                configure = { type = "execute", order = 2, width = "double", name = "Configure in QoL settings",
                    func = function()
                        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allcursor")
                    end },
            },
        }
    end
    local g = {
        type = "group", order = ns.FolderSortOrder(f, k, dpos),
        hidden = function()
            local q = ns.treeFilter
            if not q or q == "" then return false end
            for _, r in ipairs(FolderRules(f.id)) do if tostring(r.name or ""):lower():find(q, 1, true) then return false end end
            return true
        end,
        name = function() return tostring(f.name) .. " (" .. FolderRuleCount(f) .. ")" end,
        args = {
            name = { type = "input", name = "Group name", order = 1, width = "double",
                get = function() return f.name end, set = function(_, v) if v ~= "" then f.name = v end; Notify() end },
            deleteTop = { type = "execute", name = "|cffff6060Delete this group|r", order = 1.5, width = 1,
                desc = "Its rules and nested groups are kept and move up one level. Keyboard: press Delete while this group is open.",
                confirm = true, confirmText = "Delete this group? The rules and nested groups inside are kept and move up one level.",
                func = function() ns.DeleteFolderById(f.id) end },
            deleteAllTop = { type = "execute", name = "|cffff6060Delete group and all contents|r", order = 1.6, width = 1,
                desc = "Deletes this group, every nested group, and every rule inside them. This cannot be undone.",
                confirm = true, confirmText = "Delete this group AND all rules and nested groups inside it? This cannot be undone.",
                func = function() ns.DeleteFolderAllById(f.id) end },
            newRule = { type = "execute", name = "+ New rule in this group", order = 2, width = "double",
                func = function()
                    StartNewRule(f.id)
                end },
            newSub = { type = "execute", name = "+ New nested group", order = 2.5, width = "double",
                func = function()
                    local nf = ns.NewFolder("Group", f.id)
                    local scope = ns.CurrentScope()
                    local path = { ns.PlaceNewGroup(nf, scope) }
                    Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, unpack(path))
                end },
            enableAll = { type = "execute", name = "Enable all rules in this group (and nested groups)", order = 3, width = "double",
                func = function() for _, r in ipairs(FolderRules(f.id)) do r.enabled = true; ns.RefreshVisual(r) end; ns.MarkDirty(); Notify() end },
            disableAll = { type = "execute", name = "Disable all rules in this group (and nested groups)", order = 4, width = "double",
                func = function() for _, r in ipairs(FolderRules(f.id)) do r.enabled = false; ns.RefreshVisual(r) end; ns.MarkDirty(); Notify() end },
            pausePv = { type = "toggle", name = "Pause preview animations", order = 4.5, width = "double",
                hidden = function() return not ns.KindHas({ folder = f.id }, "visual") end,
                desc = "Freezes the sample countdown, the fades, and the flash in every preview while the images stay on screen. Untick to resume. This is the same switch as on Smart Categories and on each rule, so it pauses every preview, not only this group's.",
                get = function() return ns.previewPaused end,
                set = function(_, v) ns.SetPreviewPaused(v); Notify() end },
            note = { type = "description", order = 5, width = "full", fontSize = "small",
                name = "Use the eye and headphone icons next to this group in the sidebar to preview every rule inside it at once." },
            defaultNote = { type = "description", order = 5.2, width = "full", fontSize = "small",
                hidden = function() return not dinfo end, name = dinfo and dinfo.note or "" },
            loadOverride = FolderLoadGroup(f),
            soundChannel = FolderSoundGroup(f),
            container = ns.FolderContainerGroup(f),
            arrange = ns.FolderArrangeGroup(f),
            applyText = (function()
                local g = FolderApplyGroup(f)
                g.hidden = function() return not ns.KindHas({ folder = f.id }, "visual") end
                return g
            end)(),
            delete = { type = "execute", name = "Delete group (contents move up one level)", order = 9, width = "double",
                confirm = true, confirmText = "Delete this group? The rules and nested groups inside are kept and move up one level.",
                func = function()
                    for _, r in ipairs(ns.rules) do if r.folder == f.id then r.folder = f.parent end end
                    for _, ff in ipairs(ns.folders) do if ff.parent == f.id then ff.parent = f.parent end end
                    for idx, ff in ipairs(ns.folders) do if ff == f then table.remove(ns.folders, idx); break end end
                    local tab = ns.CurrentTab()
                    Notify()
                    ns.GoHome(tab)
                end },
        },
    }
    -- Tabs (like a rule): Group | Display | Load. The pieces above are sorted into them here.
    local function take(keys)
        local t = {}
        for _, k in ipairs(keys) do if g.args[k] then t[k] = g.args[k]; g.args[k] = nil end end
        return t
    end
    local container = g.args.container
    local dispFromContainer = {}
    if container and container.args then
        for _, k in ipairs({ "alpha", "scale", "strata", "level" }) do   -- position (relative to, anchor, X / Y) stays on the Group tab with the container
            if container.args[k] then dispFromContainer[k] = container.args[k]; container.args[k] = nil end
        end
    end
    local isVisual = function() return ns.KindHas({ folder = f.id }, "visual") end
    local groupArgs = g.args
    local dispArgs = take({ "arrange", "applyText" })
    dispArgs.placement = { type = "group", inline = true, order = 1, name = "Opacity, Scale & Layer", args = dispFromContainer }
    dispArgs.note = { type = "description", order = 0, width = "full", fontSize = "small",
        name = "Display settings for every display inside this group and its nested groups: opacity, scale, layer (frame strata), alignment, and shared text formatting. The group's own position is on the Group tab. Tinting / color for a whole group is not built yet." }
    local loadArgs = { override = take({ "loadOverride" }).loadOverride, conds = ns.FolderLoadConditions(f) }
    local lock = function() return ns.IsEditLocked({ folder = f.id }) end
    ns.LockArgs(groupArgs, lock); ns.LockArgs(dispArgs, lock); ns.LockArgs(loadArgs, lock)
    -- A group page can't use AceConfig's own tabs (its rules and nested groups are the tree children below it), so the tab strip
    -- is a row of buttons and each tab's content is an unframed box shown only while its tab is picked.
    ns.folderTab = ns.folderTab or setmetatable({}, { __mode = "k" })
    local function cur()
        local t = ns.folderTab[f] or "group"
        if t == "display" and not isVisual() then t = "group" end
        return t
    end
    local function Tab(key, label, order, hiddenFn)
        return { type = "execute", order = order, width = 0.8, hidden = hiddenFn,
            name = function() return cur() == key and ("|cffffd100" .. label .. "|r") or label end,
            func = function() ns.folderTab[f] = key; Notify() end }
    end
    local function Page(key, args)
        return { type = "group", inline = true, name = "", order = 0.2, hidden = function() return cur() ~= key end, args = args }
    end
    g.args = {
        tabGroup = Tab("group", "Group", 0.01),
        tabDisplay = Tab("display", "Display", 0.02, function() return not isVisual() end),
        tabLoad = Tab("load", "Load", 0.03),
        pageGroup = Page("group", groupArgs),
        pageDisplay = Page("display", dispArgs),
        pageLoad = Page("load", loadArgs),
    }
    return g
end

-- Real load conditions for a group (spec / role / instance type). They are checked on top of every rule's own Load tab and cannot be
-- loosened by it (Conditions.lua ns.FolderLoadGate). Empty = no restriction. Never / Always above still wins.
function ns.FolderLoadConditions(f)
    local function setOf(field) f[field] = f[field] or {}; return f[field] end
    local function Multi(order, name, field, choices, sorting)
        return { type = "multiselect", name = name, order = order, width = "full", values = choices, sorting = sorting,
            get = function(_, k) return setOf(field)[k] and true or false end,
            set = function(_, k, v) setOf(field)[k] = v and true or nil; if next(f[field]) == nil then f[field] = nil end; ns.MarkDirty(); Notify() end }
    end
    local specV, specO = {}, {}
    for _, c in ipairs(SpecChoices()) do specV[c.id] = c.text; specO[#specO + 1] = c.id end
    local roleV, roleO = {}, {}
    for _, c in ipairs(RoleChoices()) do roleV[c.id] = c.text; roleO[#roleO + 1] = c.id end
    local instV = {}
    for k, v in pairs(ns.INSTANCE_TYPES) do instV[k] = v end
    return { type = "group", inline = true, order = 5.5, name = "Only Load This Group When",
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Checked before each rule's own Load tab, for every rule in this group and its nested groups: a rule only loads if it passes both. Leave a list with nothing ticked to allow anything. Nothing on the rules is changed." },
            specs = Multi(1, "Specialization", "loadSpecs", specV, specO),
            roles = Multi(2, "Role", "loadRoles", roleV, roleO),
            inst = Multi(3, "Instance type", "loadInst", instV, ns.INSTANCE_TYPE_ORDER),
        } }
end

-- Explanations (static description rows of 50+ characters) become an info icon: on the section heading above them, or on the title
-- of the inline box they sit in. Descriptions with no heading to attach to (page intros) and dynamic / conditional ones stay put.
function ns.InfoPass(root)
    local seen = {}
    local function ord(a) return tonumber(a and a.order) or 100 end
    local function walk(g)
        if type(g) ~= "table" or seen[g] then return end
        seen[g] = true
        if g.type ~= "group" or type(g.args) ~= "table" then return end
        local keys = {}
        for k, v in pairs(g.args) do if type(v) == "table" then keys[#keys + 1] = k end end
        table.sort(keys, function(a, b)
            local oa, ob = ord(g.args[a]), ord(g.args[b])
            if oa ~= ob then return oa < ob end
            return tostring(a) < tostring(b)
        end)
        local lastHeader
        for _, k in ipairs(keys) do
            local v = g.args[k]
            if v.type == "header" and type(v.name) == "string" and v.name ~= "" then
                lastHeader = v
            elseif v.type == "description" and type(v.name) == "string" and #v.name >= 50 and v.hidden == nil
                and not (type(v.arg) == "table" and v.arg.xuiKeep) then
                local owner = lastHeader or ((g.inline and type(g.name) == "string" and g.name ~= "") and g or nil)
                if owner then
                    owner.xuiInfo = owner.xuiInfo and (owner.xuiInfo .. "\n\n" .. v.name) or v.name
                    g.args[k] = nil
                end
            elseif v.type == "group" then
                lastHeader = nil
            end
        end
        for _, v in pairs(g.args) do if type(v) == "table" and v.type == "group" then walk(v) end end
    end
    walk(root)
end

-- Sidebar search: while the box has text, every group / category row that holds no matching rule is hidden, the (n) counts show
-- matches only, and the rows leading to a match are opened (once per change of the text, so you can still collapse them afterwards).
function ns.ApplyTreeFilter(out)
    local q = ns.treeFilter
    if not q or q == "" then return end
    local openIt = ns.treeFilterOpen
    ns.treeFilterOpen = nil
    local function hit(key)
        local i = tonumber(tostring(key):match("^rule(%d+)$"))
        if i then local r = ns.rules and ns.rules[i]; return r and tostring(r.name or ""):lower():find(q, 1, true) and true or false end
        local j = tonumber(tostring(key):match("^bar(%d+)$"))
        if j then local b = ns.bars and ns.bars[j]; return b and tostring(b.name or ("Bar " .. j)):lower():find(q, 1, true) and true or false end
        return nil
    end
    local function walk(g, path, st, depth)
        local total = 0
        if depth > 20 or type(g.args) ~= "table" then return 0 end
        for k, v in pairs(g.args) do
            if type(v) == "table" and v.type == "group" then
                local h = hit(k)
                if h ~= nil then
                    if h then total = total + 1 end
                else
                    path[#path + 1] = k
                    local n = walk(v, path, st, depth + 1)
                    if not v.xuiFilt then
                        v.xuiFilt = true
                        local oh, on = v.hidden, v.name
                        v.hidden = function(...)
                            if n == 0 then return true end
                            if type(oh) == "function" then return oh(...) end
                            return oh
                        end
                        v.name = function(...)
                            local nm = type(on) == "function" and on(...) or on
                            if type(nm) ~= "string" then return nm end
                            return (nm:gsub("%(%d+%)%s*$", "(" .. n .. ")"))
                        end
                    end
                    if n > 0 and openIt and st then st[table.concat(path, "\001")] = true end
                    path[#path] = nil
                    total = total + n
                end
            end
        end
        return total
    end
    local cd = out.args and out.args.cooldowns
    for _, tab in ipairs({ "enabledTab", "smartTab", "disabledTab" }) do
        local g = cd and cd.args and cd.args[tab]
        if g then
            local st
            if openIt and AceConfigDialog.GetStatusTable then
                local t = AceConfigDialog:GetStatusTable(APP, { "cooldowns", tab })
                if t then t.groups = t.groups or {}; t.groups.groups = t.groups.groups or {}; st = t.groups.groups end
            end
            walk(g, {}, st, 0)
        end
    end
end

local function BuildOptions()
    ---------------------------------------------------------- Cooldown + Aura Tracking
    local all = {
        type = "group", name = "SMART CATEGORIES", order = 1, childGroups = "tree",
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Rules that watch a cooldown, a buff, and your talents, then play a sound and/or show a texture. Pick a rule on the left, or add one. The eye and headphone icons in the sidebar preview a rule (or a whole group / everything) without changing it." },
            newRule = { type = "execute", name = "+ New rule", order = 1,
                func = function()
                    StartNewRule(nil)
                end },
            newSound = { type = "toggle", name = "New rules play a sound", order = 3, width = "double",
                desc = "Applied when you press + New rule. Off by default; you can still change it on the rule's Actions tab.",
                get = function() return newOpts.sound end, set = function(_, v) newOpts.sound = v end },
            newVisual = { type = "toggle", name = "New rules show a texture / icon", order = 4, width = "double",
                desc = "Applied when you press + New rule. Off by default; you can still change it on the rule's Actions tab.",
                get = function() return newOpts.visual end, set = function(_, v) newOpts.visual = v end },
            askSounds = { type = "toggle", name = "Ask before previewing many sounds at once", order = 4.5, width = "double",
                desc = "When on, the headphone icon on a row that covers several sounds asks first. Turned off by ticking 'Don't ask me again' in that box.",
                get = function() local u = CueRulesDB and CueRulesDB.ui; return not (u and u.skipSoundAllPrompt) end,
                set = function(_, v) local u = CueRulesDB and CueRulesDB.ui; if u then u.skipSoundAllPrompt = (not v) or nil end end },
            unlock = { type = "execute", order = 5, width = "double",
                name = function() return ns.unlocked and "Lock visuals" or "Unlock visuals (drag on screen)" end,
                func = function() ns.ToggleUnlock(); Notify() end },
            pausePv = { type = "toggle", name = "Pause preview animations", order = 5.2, width = "double",
                desc = "Freezes the sample countdown, the fades, and the flash in every preview and unlocked display while the images stay on screen. Untick to resume.",
                get = function() return ns.previewPaused end,
                set = function(_, v) ns.SetPreviewPaused(v); Notify() end },
            -- "Add Default Categories" button removed for now (2026-10-31): folders are the grouping tool; Smart Categories do the by-type sorting.
        },
    }
    local groups = {}
    for k, f in ipairs(ns.folders or {}) do
        -- Mouse Cursor Cues has nothing in it while QoL Elements is switched off: not listed anywhere
        if not (f.default == "cursor" and not f.parent and not ns.QoLOn) then groups[f.id] = BuildFolder(k, f) end
    end
    for _, f in ipairs(ns.folders or {}) do
        local parent = f.parent and groups[f.parent]
        if parent and (f.parent == f.id or IsInFolder(f.parent, f.id)) then f.parent = nil; parent = nil end  -- break cycles
        if parent then parent.args[f.id] = groups[f.id] else all.args[f.id] = groups[f.id] end
    end
    local okc, ctx = pcall(ns.ReadContext)
    local loadedArgs, notArgs, nLoaded, nNot = {}, {}, 0, 0
    local disabledArgs, nDisabled = {}, 0
    local ruleGroups = {}
    local byRule, nested = {}, {}
    for i, rule in ipairs(ns.rules or {}) do
        local g = BuildRule(i, rule)
        if rule.parentUid and ns.FindParentRule and ns.FindParentRule(rule) then
            -- an outcome is shown inside its parent rule (Conditions tab), not as its own list entry
            nested[#nested + 1] = { rule = rule, g = g }
        else
            byRule[rule] = g
            ruleGroups[i] = g
            local fld = rule.folder and groups[rule.folder]
            if fld then fld.args["rule" .. i] = g else all.args["rule" .. i] = g end
            if ns.RuleDisabled(rule) then disabledArgs["rule" .. i] = g; nDisabled = nDisabled + 1
            elseif okc and ns.IsLoaded(rule, ctx) then loadedArgs["rule" .. i] = g; nLoaded = nLoaded + 1
            else notArgs["rule" .. i] = g; nNot = nNot + 1 end
        end
    end
    if ns.EmbedOutcome then
        local cnt = {}
        for _, o in ipairs(nested) do
            local par = ns.FindParentRule(o.rule)
            local pg = par and byRule[par]
            if pg then
                cnt[par] = (cnt[par] or 0) + 1
                if o.rule.folder ~= par.folder then o.rule.folder = par.folder end
                local oke, err = pcall(ns.EmbedOutcome, pg, o.g, o.rule, cnt[par])
                if not oke and not ns.embedErr then ns.embedErr = true; ns.Print("outcome embed error: " .. tostring(err)) end
            end
        end
    end
    loadedArgs.info = { type = "description", order = 0, width = "full", fontSize = "medium",
        name = "Rules that are enabled and whose load conditions and talents match right now (cooldown / buff state is not part of this). Same rules as under Smart Categories; this list updates as your situation changes." }
    notArgs.info = { type = "description", order = 0, width = "full", fontSize = "medium",
        name = "Enabled rules whose load conditions or talents do not match right now. Rules that are switched off (or set to never load) are under the Disabled tab." }
    disabledArgs.info = { type = "description", order = 0, width = "full", fontSize = "medium",
        name = "Rules whose Enabled box is unticked, or whose load mode is Never. They never load and show nothing." }
    -- All Rules is the first root row; a blank divider row follows its tree, then the Loaded / Not Loaded filters
    all.order = 3   -- third section: folders + Smart Categories (Loaded / Not Loaded come first)
    -- type picker (shown in place of the All Rules page while `picker` is set)
    do
        local function Entry(order, icon, title, desc, typ)
            if ns.SkinRows and ns.SkinRows() then   -- big-icon row: big icon, gold title, description under it (clickable via Skin.lua)
                return { type = "description", order = order, width = "full", fontSize = "medium",
                    image = (type(icon) == "number" or icon:find("\\", 1, true)) and icon or ("Interface\\Icons\\" .. icon), imageWidth = 36, imageHeight = 36,
                    name = "|cffffd100" .. title .. "|r\n|cffffffff" .. desc .. "|r",
                    arg = { xuiRow = function() PickType(typ) end } }
            end
            return { type = "execute", order = order, width = "full",
                name = "|T" .. ((type(icon) == "number" or icon:find("\\", 1, true)) and icon or ("Interface\\Icons\\" .. icon)) .. ":28|t  |cffffd100" .. title .. "|r  -  " .. desc,
                func = function() PickType(typ) end }
        end
        for _, k in ipairs({ "intro", "newRule", "newFolder", "newSound", "newVisual", "askSounds", "unlock", "pausePv", "defaults", "seed" }) do
            local a = all.args[k]
            if a then
                local orig = a.hidden
                a.hidden = function(...) if picker then return true end; if type(orig) == "function" then return orig(...) end; return orig end
            end
        end
        -- Picker descriptions are kept to ONE line (about 55 characters) on purpose: a row that wraps to 2-3 lines was measured before
        -- its real width was known and came out too short, so the next row / the External header / Cancel drew over it.
        all.args.pickerHdr = { type = "header", order = 0.1, name = "Choose what this rule shows", hidden = function() return not picker end }
        local TI = ns.TypeIcon or function(_, f) return f end
        all.args.pickIcon = Entry(0.2, TI("icon", "Spell_Holy_PowerWordShield"), "Icon", "Shows a spell icon with an optional cooldown overlay", "icon")
        all.args.pickBar = Entry(0.4, TI("progressbar", "Ability_Rogue_Sprint"), "Progress Bar", "A bar with name, timer, and icon (creates a Buff Bar)", "bar")
        all.args.pickProg = Entry(0.5, TI("progresstex", "Spell_Nature_TimeStop"), "Progress Texture", "Shows a texture that changes based on duration", "progresstex")
        all.args.pickText = Entry(0.6, TI("text", "INV_Misc_Note_01"), "Text", "One or more lines of text, with dynamic information", "text")
        all.args.pickTex = Entry(0.3, TI("sttexture", "INV_Misc_Gem_Variety_01"), "Texture", "Shows a custom texture", "texture")
        all.args.pickDGroup = Entry(0.65, TI("dyngroup", "INV_Misc_Bag_10_Blue"), "Dynamic Group", "A container whose elements move to fit what is detected", "dgroup")
        all.args.pickSound = Entry(0.62, TI("sound", "INV_Misc_Note_01"), "Sound Cue", "Plays a sound when its conditions are met, with no display", "sound")
        all.args.pickSGroup = Entry(0.63, TI("stgroup", "INV_Misc_Bag_10"), "Static Group", "A container with fixed X / Y positions for its elements", "sgroup")
        all.args.pickCustom = Entry(0.64, 1669494, "Custom", "A blank rule with no display, sound, or cues", "custom")
        all.args.pickImport = Entry(0.66, TI("import", "INV_Scroll_03"), "Import", "Import from an encoded string (opens the Import window)", "import")
        all.args.pickGap = { type = "description", order = 0.85, width = "full", fontSize = "large", name = " \n ", hidden = function() return not picker end }   -- empty rows: keeps Cancel clear of the last row
        all.args.pickCancel = { type = "execute", order = 0.9, name = "Cancel", width = "half", func = function() picker = nil; local o = ns.pickOrigin; ns.pickOrigin = nil; Notify(); if ns.pickSub then ns.GoPicker() else ns.GoHome(o) end; ns.pickSub = nil end }
        for _, k in ipairs({ "pickIcon", "pickBar", "pickProg", "pickText", "pickTex", "pickSound", "pickDGroup", "pickSGroup", "pickCustom", "pickImport", "pickCancel" }) do
            all.args[k].hidden = function() return not picker end
        end
    end
    -- The picker also lives on the Loaded, Disabled and Drafts pages, so New Rule keeps the tab it was pressed in. The same row tables are
    -- shared (their hidden functions only look at `picker`); the page's other non-group entries hide while the picker is open.
    ns.PickerInto = function(args)
        if not (args and all.args.pickIcon) then return end
        for _, k in ipairs({ "pickerHdr", "pickIcon", "pickBar", "pickProg", "pickText", "pickTex", "pickDGroup", "pickSound", "pickSGroup", "pickCustom", "pickImport", "pickGap", "pickCancel" }) do
            args[k] = all.args[k]
        end
        for k, a in pairs(args) do
            if type(a) == "table" and a.type ~= "group" and not tostring(k):match("^pick") and not a.xuiPickWrap then
                a.xuiPickWrap = true
                local orig = a.hidden
                a.hidden = function(...) if picker then return true end; if type(orig) == "function" then return orig(...) end; return orig end
            end
        end
    end
    ns.PickerInto(loadedArgs); ns.PickerInto(disabledArgs)
    -- Rules is a tab group with its own row of sub-tabs (2026-11-01). Each sub-tab keeps the same root rows as before (Loaded / Not Loaded,
    -- All Rules, a Disabled root), so every row path below the sub-tab is unchanged.
    local enabledTab = { type = "group", name = "Enabled", order = 1, childGroups = "tree", args = {
        loaded = { type = "group", order = 1, childGroups = "tree",
            name = function() return "LOADED (" .. nLoaded .. ")" end, args = loadedArgs },
        spacer = { type = "group", order = 2.5, name = " ", disabled = true, args = {} },
        spacer1 = { type = "group", order = 1.5, name = " ", disabled = true, args = {} },
        spacer0 = { type = "group", order = 0.5, name = " ", disabled = true, args = {} },
        notloaded = { type = "group", order = 2, childGroups = "tree",
            name = function() return "NOT LOADED (" .. nNot .. ")" end, args = notArgs },
        -- AUTO-POPULATE RULES moved to the Class/Spec Rule Creator tab (2026-10-31)
        } }
    local smartTab = { type = "group", name = "Smart Categories", order = 3, childGroups = "tree", args = { all = all } }
    local draftsTab = ns.BuildDraftsPage and ns.BuildDraftsPage() or nil
    if draftsTab then draftsTab.order = 2; draftsTab.hidden = nil; draftsTab.name = "Drafts"; ns.PickerInto(draftsTab.args) end
    local disabledTab = { type = "group", name = "Disabled", order = 4, childGroups = "tree", args = {
        disabled = { type = "group", order = 1, childGroups = "tree",
            name = function() return "DISABLED (" .. nDisabled .. ")" end, args = disabledArgs },
        } }
    local binTab = { type = "group", name = "Recycle Bin", order = 6, hidden = ns.PageHidden("recyclebin"), args = {
        info = { type = "description", order = 1, width = "full", fontSize = "medium",
            name = "Recycle Bin: not built yet (GitHub issue #88). Deleted rules and groups are still removed for good when you confirm the delete." },
        } }
    -- Class/Spec Rule Creator is the last sub-tab; Skin.lua pins it to the far right of the tab row (2026-11-01)
    local creatorTab = BuildClassCreator()
    creatorTab.order = 9; creatorTab.hidden = nil; creatorTab.name = "Class/Spec Rule Creator"
    local track = { type = "group", name = "Rules", order = 1, childGroups = "tab", args = {
        enabledTab = enabledTab, draftsTab = draftsTab, smartTab = smartTab, disabledTab = disabledTab, creatorTab = creatorTab } }

    ---------------------------------------------------------- Buff Bars
    local allBars = {
        type = "group", name = "Buff Bars", order = 2, childGroups = "tree",
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Timer bars for buffs on you. Layout options below apply to the whole group. The eye icon in the sidebar previews a bar (or all of them)." },
            pausePv = { type = "toggle", name = "Pause preview animations", order = 1.5, width = "double",
                desc = "Freezes the sample countdown, the fades, and the flash in every preview and unlocked display while the images stay on screen. Untick to resume.",
                get = function() return ns.previewPaused end,
                set = function(_, v) ns.SetPreviewPaused(v); Notify() end },
            newBar = { type = "execute", name = "+ New buff bar", order = 1, width = "double",
                func = function()
                    ns.Bars_NewBar(); Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allbars", "bar" .. #ns.bars)
                end },
            layoutH = { type = "header", name = "Group Layout", order = 2 },
            layout = Sel(CueRulesDB.barGroup, "layout", "Arrange the bars", 3, BAR_LAYOUT, BAR_LAYOUT_ORDER,
                function() ns.MarkDirty(); Notify() end, { width = "double" }),
            spacing = Rng(CueRulesDB.barGroup, "spacing", "Spacing", 4, 0, 40, 1, function() ns.MarkDirty() end,
                { disabled = function() return not ns.Val(CueRulesDB.barGroup.layout) end }),
            gx = Rng(CueRulesDB.barGroup, "x", "Group X", 5, -1500, 1500, 1, function() ns.MarkDirty() end,
                { disabled = function() return not ns.Val(CueRulesDB.barGroup.layout) end }),
            gy = Rng(CueRulesDB.barGroup, "y", "Group Y", 6, -900, 900, 1, function() ns.MarkDirty() end,
                { disabled = function() return not ns.Val(CueRulesDB.barGroup.layout) end }),
            unlock = { type = "execute", order = 7, width = "double",
                name = function() return ns.unlocked and "Lock (stop dragging)" or "Unlock (drag on screen)" end,
                func = function() ns.ToggleUnlock(); Notify() end },
        },
    }
    for i, bar in ipairs(ns.BarsOn and ns.bars or {}) do allBars.args["bar" .. i] = BuildBar(i, bar) end

    ---------------------------------------------------------- Smart Categories (virtual root under All Rules)
    do
        -- scope: "all" (every rule, inside the All Rules section) | "loaded" | "not" (only rules in that state)
        local function MakeSmart(scope, order)
            local smartArgs, total = {}, 0
            local function inScope(i)
                if not ruleGroups[i] then return false end
                if scope == "all" then return true end
                local key = "rule" .. i
                return (scope == "loaded" and loadedArgs[key] ~= nil) or (scope == "not" and notArgs[key] ~= nil)
            end
            smartArgs.info = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Collects rules by what they actually do, without moving them out of their own groups. A rule that shows an icon and text appears under both. Buff bars are listed under Progress Bars. Lists update as you change rules; empty ones are hidden." }
            for k, cat in ipairs(ns.SMART_CATS) do
                local args, n = {}, 0
                if cat.key == "smart_bar" then
                    if scope == "all" then
                        for j = 1, #(ns.bars or {}) do
                            local bg = allBars.args["bar" .. j]
                            if bg then args["bar" .. j] = bg; n = n + 1 end
                        end
                        total = total + n
                    end
                else
                    for i, rule in ipairs(ns.rules or {}) do
                        if inScope(i) and ns.SmartMatch(rule, cat.key) then args["rule" .. i] = ruleGroups[i]; n = n + 1 end
                    end
                end
                for _, ak in ipairs({ "newRule", "pickerHdr", "pickIcon", "pickBar", "pickProg", "pickText", "pickTex", "pickSound", "pickDGroup", "pickSGroup", "pickCustom", "pickImport", "pickGap", "pickCancel" }) do
                    if all.args[ak] then args[ak] = all.args[ak] end
                end
                smartArgs[cat.key] = { type = "group", order = k, childGroups = "tree",
                    name = function() return cat.name .. " (" .. n .. ")" end,
                    hidden = function() return n == 0 end, args = args }
            end
            for i, rule in ipairs(ns.rules or {}) do
                if not rule.parentUid and inScope(i) and ns.SmartAny(rule) then total = total + 1 end
            end
            return { type = "group", order = order, childGroups = "tree",
                name = function() return "BY TYPE (" .. total .. ")" end,
                hidden = scope ~= "all" and function() return total == 0 end or nil, args = smartArgs }
        end
        -- Smart Categories also sit at the top of All Rules (collapsed until opened; the tree only expands what you open)
        all.args.smart = MakeSmart("all", 0.95)
        do   -- the default cue folders are sub-sections of Smart Categories
            local sm, mv = all.args.smart, {}
            for id in pairs(all.args) do
                local f = type(id) == "string" and id:match("^f%d") and FolderById(id)
                if f and ns.CueTop(f) then mv[#mv + 1] = id end
            end
            for _, id in ipairs(mv) do sm.args[id] = all.args[id]; all.args[id] = nil end
            -- Smart Categories lists types only: the folders are not shown here (they live in Loaded / Not Loaded)
            local function hideFolder(g) if type(g) == "table" and g.type == "group" then g.hidden = function() return true end end end
            for id, g in pairs(all.args) do if type(id) == "string" and id:match("^f%d") then hideFolder(g) end end
            for id, g in pairs(sm.args) do if type(id) == "string" and id:match("^f%d") then hideFolder(g) end end
        end
        -- (Smart Categories removed from Loaded / Not Loaded; they live under All Rules)
    end

    ---------------------------------------------------------- Groups inside Loaded / Not Loaded
    -- A rule that lives in a group is listed under that group (nested like in All Rules) in whichever of Loaded / Not Loaded it
    -- belongs to; groups with nothing in that state are left out. Ungrouped rules stay in the flat list. Moving a rule into a group
    -- therefore shows up in these lists on the next refresh.
    do
        local function Scoped(f, scopeArgs, allowEmpty)
            local g = groups[f.id]
            if not g then return nil end
            local kids, count = {}, 0
            for i, rule in ipairs(ns.rules or {}) do
                if ruleGroups[i] and rule.folder == f.id and scopeArgs["rule" .. i] then kids["rule" .. i] = ruleGroups[i]; count = count + 1 end
            end
            for _, sf in ipairs(ns.folders or {}) do
                if sf.parent == f.id and sf.id ~= f.id then
                    local n, c = Scoped(sf, scopeArgs, allowEmpty)
                    if n then kids[sf.id] = n; count = count + c end
                end
            end
            if count == 0 and not next(kids) and not (#FolderRules(f.id) == 0 and ((allowEmpty == "loaded" and f.xuiScope ~= "notloaded" and f.xuiScope ~= "disabled") or ((allowEmpty == "notloaded" or allowEmpty == "disabled") and f.xuiScope == allowEmpty))) then return nil end   -- an empty group is listed in the list it was created from (Loaded by default)
            local args = {}
            for k, v in pairs(g.args or {}) do
                if not (type(k) == "string" and (k:match("^rule%d+$") or k:match("^f%d+$"))) then args[k] = v end
            end
            for k, v in pairs(kids) do args[k] = v end
            return { type = "group", order = g.order, childGroups = "tree",
                name = function() return tostring(f.name) .. " (" .. count .. ")" end, args = args }, count
        end
        local function Apply(scopeArgs, allowEmpty)
            local top, moved = {}, {}
            local function Walk(f, depth)
                if depth > 16 then return end
                if ns.CueTransparent(f) then   -- not drawn: its rules stay in the flat list, its groups move up one level
                    for _, sf in ipairs(ns.folders or {}) do
                        if sf.parent == f.id and sf.id ~= f.id then Walk(sf, depth + 1) end
                    end
                else
                    local n = Scoped(f, scopeArgs, allowEmpty)
                    if n then top[f.id] = n end
                end
            end
            for _, f in ipairs(ns.folders or {}) do
                if not (f.parent and groups[f.parent]) then Walk(f, 0) end
            end
            for i, rule in ipairs(ns.rules or {}) do
                local key = "rule" .. i
                local rf = rule.folder and groups[rule.folder] and ns.FolderById(rule.folder)
                if scopeArgs[key] and rf and not ns.CueTransparent(rf) then moved[#moved + 1] = key end
            end
            for _, key in ipairs(moved) do scopeArgs[key] = nil end   -- listed under their group instead
            for id, n in pairs(top) do scopeArgs[id] = n end
        end
        Apply(loadedArgs, "loaded")
        Apply(notArgs, "notloaded")
        Apply(disabledArgs, "disabled")
    end

    ---------------------------------------------------------- QoL
    local allQol = {
        type = "group", name = "Stat Tracking", order = 1, childGroups = "tree",
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Small quality-of-life displays. Stats text boxes: build your own layout from {tokens}, then drag it where you want it." },
            newBox = { type = "execute", name = "+ New stats text box", order = 1, width = "double",
                func = function()
                    ns.QoL_NewBox(); Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allqol", "box" .. #ns.qolBoxes)
                end },
            tokens = { type = "description", order = 2, width = "full", fontSize = "small", name = TokenHelp },
        },
    }
    for i, box in ipairs(ns.QoLOn and ns.qolBoxes or {}) do allQol.args["box" .. i] = BuildBox(i, box) end
    -- Stat Tracking off (tick box on its sidebar row): nothing is listed or shown
    for k, v in pairs(allQol.args) do v.hidden = function() return not ns.QoLOn() end end
    for k, v in pairs(allBars.args) do
        local orig = v.hidden
        v.hidden = function(...)
            if not ns.BarsOn() then return true end
            if type(orig) == "function" then return orig(...) end
            return orig
        end
    end
    -- QoL Elements (stat boxes, cursor tracker, buff bars) are switched off for now: their files are not in XayaUI.toc, so ns.QoLOn is nil and the tab is skipped.
    -- Tab "QoL UI Updates": left tree, options in the right pane. The entries are sorted alphabetically (see below); the older
    -- QoL Elements entries (stat boxes, cursor tracker, buff bars) come last, and only exist while their files are loaded.
    local qolArgs = { chatreskin = ns.BuildChatTab and ns.BuildChatTab(Notify) or nil, cursor = ns.BuildCursorGroup and ns.BuildCursorGroup(Notify) or nil,
        datapanels = ns.BuildDataPanelsTab and ns.BuildDataPanelsTab(Notify) or nil,
        notepad = ns.BuildNotepadTab and ns.BuildNotepadTab(Notify) or nil,
        minimap = ns.BuildMinimapTab and ns.BuildMinimapTab(Notify) or nil,
        tooltips = ns.BuildTooltipsTab and ns.BuildTooltipsTab(Notify) or nil }   -- Tooltips.lua / TooltipsUI.lua, part of core since 0.5.51
    if ns.QoLOn then
        qolArgs.allqol = allQol
        qolArgs.allcursor = (ns.CursorTrackerGroup and ns.CursorTrackerGroup(Notify)) or nil
        qolArgs.allbars = allBars
    end
    -- The left list is sorted alphabetically by the entry's displayed name (Xaya, 2026-11-02, #274). Names are read once here; an
    -- entry whose name is a function is called, and one that fails sorts by its key. The older QoL Elements entries stay last.
    do
        local list = {}
        for key, ent in pairs(qolArgs) do
            local nm = ent.name
            if type(nm) == "function" then local ok, v = pcall(nm); nm = ok and v or nil end
            nm = (type(nm) == "string" and nm ~= "") and nm:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or key
            local old = (key == "allqol" or key == "allcursor" or key == "allbars") and 1 or 0
            list[#list + 1] = { key = key, name = nm:lower(), old = old }
        end
        table.sort(list, function(a, b)
            if a.old ~= b.old then return a.old < b.old end
            if a.name ~= b.name then return a.name < b.name end
            return a.key < b.key
        end)
        for i, e in ipairs(list) do qolArgs[e.key].order = i end
    end
    local qol = next(qolArgs) and { type = "group", name = "QoL UI Updates", order = 5, childGroups = "tree", args = qolArgs } or nil

    -- Addon Info is not in the tab strip: the "Addon Info" link in the window's bottom-left corner opens it (ns.infoOpen) and it
    -- goes away again as soon as another tab is picked.
    local infoGroup = ns.BuildAddonInfo and ns.BuildAddonInfo() or nil
    if infoGroup then infoGroup.order = 8; infoGroup.hidden = function() return not ns.infoOpen end end
    -- Settings (skin on): its pages REPLACE the Rules / Smart Categories tabs while the toolbar's Settings button is on:
    --   Settings page = left sidebar: UI Options (Display | Theme tabs), Debugging
    local function SettingsOn() return (ns.SkinRows and ns.SkinRows()) and ns.pageOpen == "settings" end
    local settings = BuildAddonSettings()
    local sa = settings.args
    local dispArgs = {}
    for k, v in pairs(sa.ui.args) do dispArgs[k] = v end
    dispArgs.intro = sa.intro
    local setUi = { type = "group", name = "UI Options", order = 1, childGroups = "tab", args = {
        display = { type = "group", name = "Display", order = 1, args = dispArgs },
        theme = { type = "group", name = "Theme", order = 2, args = sa.theme.args },
    } }
    local setDbg = { type = "group", name = "Debugging", order = 2, args = sa.debug.args }
    -- one top-level page with a left sidebar like the rest of the addon (UI Options, Debugging), instead of two top tabs (Xaya, 2026-11-02)
    local setPage = { type = "group", name = "Settings", order = 7, childGroups = "tree", hidden = function() return not SettingsOn() end,
        args = { ui = setUi, debug = setDbg } }
    settings.hidden = function() return ns.SkinRows and ns.SkinRows() and true or false end   -- skin off: the old single Settings tab
    track.hidden = function() return SettingsOn() and true or false end
    if qol then qol.hidden = function() return SettingsOn() and true or false end end   -- Settings open: QoL UI Updates tab goes away (Xaya, 2026-11-01)
    -- Game Menu look settings live on the Display page (UI Options > Display), under the ESC-menu button toggles. A separate "Game Menu"
    -- top tab closed the Settings pages when clicked (0.5.67 fix, Xaya). The group's children are copied in flat, not nested, so each
    -- keeps its own inline box.
    local setGm = ns.GameMenuSkin_Options and ns.GameMenuSkin_Options(Notify) or nil
    if setGm then
        dispArgs.gm_header = { type = "header", name = "Game Menu look (ESC menu)", order = 26, hidden = function() return not SettingsOn() end }
        for k, v in pairs(setGm.args) do
            v.order = 26.001 + (tonumber(v.order) or 0) / 1000
            dispArgs["gm_" .. k] = v
        end
    end
    local oldGm = ns.GameMenuSkin_Options and ns.GameMenuSkin_Options(Notify) or nil   -- same group inside the old single Settings tab (skin rows off)
    if oldGm then oldGm.order = 1.7; settings.args.gamemenu = oldGm end
    local out = { type = "group", name = "XayaUI", childGroups = "tab",
        args = { cooldowns = track, recyclebin = binTab, qol = qol, profiles = BuildProfiles(), info = infoGroup, settings = settings, set = setPage } }
    pcall(ns.SmartOpen)
    pcall(ns.ApplyTreeFilter, out)
    if ns.SkinRows and ns.SkinRows() then pcall(ns.InfoPass, out) end   -- the info icons are part of the skin
    return out
end
ns.BuildOptionsTable = BuildOptions

-- skipValidation: the options tree is very large (every rule repeats in several lists); Ace's one-off type check of it can exceed
-- the game's script time limit ("script ran too long") when the window first opens.
AceConfigRegistry:RegisterOptionsTable(APP, BuildOptions, true)
AceConfigDialog:SetDefaultSize(APP, 780, 860)   -- tall rectangle

function ns.OnRulesChanged() Notify() end
function ns.OnPositionChanged() Notify() end

-- open the window (if needed) and jump to a rule; used by clicking an aura on screen while unlocked
function ns.EditRule(rule)
    if not ns.rules then return end
    if not (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]) then
        local ok, err = pcall(AceConfigDialog.Open, AceConfigDialog, APP)
        if not ok then ns.Print("could not open the window: " .. tostring(err)) return end
    end
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, RulePath(rule))
    Notify()
end

local firstOpen = true
function ns.ToggleUI()
    if not ns.rules then ns.Print("saved data is not ready yet (rules table is nil).") return end
    if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP] then
        AceConfigDialog:Close(APP)
    else
        local ok, err = pcall(AceConfigDialog.Open, AceConfigDialog, APP)
        if not ok then ns.Print("could not open the window: " .. tostring(err)) return end
        if firstOpen then
            firstOpen = false
            local ui = CueRulesDB and CueRulesDB.ui
            local sub = ui and ui.rulesSub
            if sub ~= "smartTab" and sub ~= "draftsTab" and sub ~= "disabledTab" and sub ~= "creatorTab" then sub = "enabledTab" end   -- the last sub-tab used
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", sub)
        end
    end
end
-- Window strata: AceGUI opens its frame at FULLSCREEN_DIALOG, which covers Blizzard dialogs / alert boxes (StaticPopups are DIALOG).
-- Drop the options window to HIGH (still above the HUD and unlocked displays) so an alert box always shows over it. XayaUI's own
-- popups and menus set TOOLTIP strata themselves, so they stay above the window. (do-block: this chunk is near Lua's 200-local limit)
do
    local function LowerWindow()
        local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
        if of and of.frame and of.frame.SetFrameStrata then pcall(of.frame.SetFrameStrata, of.frame, "HIGH") end
    end
    ns.LowerWindowStrata = LowerWindow
    if hooksecurefunc then
        hooksecurefunc(AceConfigDialog, "Open", function(_, app)
            if app ~= APP then return end
            LowerWindow()
            if not ns.paneSizeApplied then ns.paneSizeApplied = true; if ns.ApplyPaneSize then pcall(ns.ApplyPaneSize) end end   -- saved size override, once per session
            if ns.DraftsOnOpen then pcall(ns.DraftsOnOpen) end   -- remember every rule's saved version
            local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
            if of and of.frame and not of.frame.xuiDraftHook then   -- window closed (button, Esc, toggle): unsaved rules go to Drafts
                of.frame.xuiDraftHook = true
                of.frame:HookScript("OnHide", function() if ns.DraftsOnClose then pcall(ns.DraftsOnClose) end end)
            end
        end)
    end
end
ns.optionsLoaded = true

-------------------------------------------------------------------------------
-- Debug console tray (attached under the window)
-------------------------------------------------------------------------------
local HEADER_H, BODY_H = 24, 190
local tray

local function TrayOpen()
    return not (CueRulesDB and CueRulesDB.ui) or CueRulesDB.ui.trayOpen ~= false
end

local function ApplyTrayState()
    if not tray then return end
    local open = TrayOpen()
    tray:SetHeight(open and (HEADER_H + BODY_H) or HEADER_H)
    tray.status:SetShown(open)
    tray.log:SetShown(open)
    tray.check:SetChecked(open)
end

local function BuildTray()
    local t = CreateFrame("Frame", "CueRulesTray", UIParent, "BackdropTemplate")
    t:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    t:SetBackdropColor(0.06, 0.06, 0.07, 0.96)
    t:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)

    t.check = CreateFrame("CheckButton", nil, t, "UICheckButtonTemplate")
    t.check:SetSize(22, 22)
    t.check:SetPoint("TOPLEFT", 6, -1)
    t.check.text = t.check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.check.text:SetPoint("LEFT", t.check, "RIGHT", 2, 0)
    t.check.text:SetText("Debug console")
    t.check:SetScript("OnClick", function(self)
        CueRulesDB.ui = CueRulesDB.ui or {}
        CueRulesDB.ui.trayOpen = self:GetChecked() and true or false
        ApplyTrayState()
    end)

    t.clear = CreateFrame("Button", nil, t, "UIPanelButtonTemplate")
    t.clear:SetSize(56, 18)
    t.clear:SetPoint("TOPRIGHT", -6, -3)
    t.clear:SetText("Clear")
    t.clear:SetScript("OnClick", function() t.log:Clear(); if ns.logBuf then wipe(ns.logBuf) end end)

    t.copy = CreateFrame("Button", nil, t, "UIPanelButtonTemplate")
    t.copy:SetSize(56, 18)
    t.copy:SetPoint("RIGHT", t.clear, "LEFT", -4, 0)
    t.copy:SetText("Copy")
    t.copy:SetScript("OnClick", function() if ns.CopyConsole then ns.CopyConsole() end end)

    t.status = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.status:SetPoint("TOPLEFT", 10, -(HEADER_H + 4))
    t.status:SetPoint("TOPRIGHT", -10, -(HEADER_H + 4))
    t.status:SetJustifyH("LEFT")
    t.status:SetJustifyV("TOP")
    t.status:SetHeight(84)

    t.log = CreateFrame("ScrollingMessageFrame", nil, t)
    t.log:SetPoint("TOPLEFT", 10, -(HEADER_H + 92))
    t.log:SetPoint("BOTTOMRIGHT", -10, 8)
    t.log:SetFontObject(GameFontHighlightSmall)
    t.log:SetJustifyH("LEFT")
    t.log:SetMaxLines(300)
    t.log:SetFading(false)
    t.log:SetInsertMode("BOTTOM")
    t.log:EnableMouseWheel(true)
    t.log:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
    for _, line in ipairs(ns.logBuf or {}) do t.log:AddMessage(line) end
    return t
end

function ns.LogSink(line)
    if tray and tray.log then tray.log:AddMessage(line) end
end

-------------------------------------------------------------------------------
-- Sidebar preview toggles: an eye (visual) and a headphone (sound) on tree rows.
-- Rows map to objects by their tree key: all / f<id> (folder) / rule<n>; allbars / bar<n>.
-- Preview is temporary: it never edits a rule, and it clears when the window closes.
-------------------------------------------------------------------------------
local EYE_ATLASES = { "socialqueuing-icon-eye" }
local EYE_FILE = "Interface\\Icons\\INV_Misc_Eye_01"
local HEAD_ATLASES = { "voicechat-icon-headphone-on" }
local HEAD_FILE = "Interface\\Common\\VoiceChat-Speaker"

local function AtlasOK(n)
    local ok, info = pcall(C_Texture.GetAtlasInfo, n)
    return ok and info and true or false
end
local function ApplyIcon(tex, atlases, file)
    for _, a in ipairs(atlases) do
        if AtlasOK(a) then tex:SetAtlas(a); return "atlas " .. a end
    end
    tex:SetTexture(file)
    return "file " .. file
end
function ns.IconReport()
    local function chk(list, file) for _, a in ipairs(list) do if AtlasOK(a) then return "atlas " .. a end end return "file " .. file end
    ns.Print("eye icon: " .. chk(EYE_ATLASES, EYE_FILE) .. " | headphone icon: " .. chk(HEAD_ATLASES, HEAD_FILE))
end

-- Returns visualObjs, soundObjs for a tree row (either may be nil)
-- What the eye / headphone on a RULE row previews: the rule's own display or sound (older rules) plus every cue it owns. A rule that
-- has cues and no display of its own is left out itself (previewing it would force-show an empty texture); without this a rule whose
-- cues are set but that has no condition yet previewed nothing. A function field, not a local: this file is near Lua's 200-locals limit.
function ns.PreviewTargets(r)
    local l, cues = {}, {}
    if r.uid and not r.isCue and not r.parentUid and ns.CuesOf then cues = ns.CuesOf(r) end
    local ownVisual = r.visual and r.visual.enabled
    local ownSound = r.sound and r.sound.enabled
    if #cues == 0 or ownVisual or ownSound then l[#l + 1] = r end
    for _, c in ipairs(cues) do l[#l + 1] = c end
    return l
end

-- Group previews (all / folder / smart / loaded / not loaded) skip what is switched off: a disabled rule (or a cue of one) is only
-- previewed from the Disabled list or from its own row. Inside Loaded / Not Loaded a group previews only the rules in that list.
function ns.PvScope(uv) local k = uv and uv:match("^([^\001]+)"); if k == "loaded" or k == "notloaded" or k == "disabled" then return k end end
function ns.PvKeep(r, scope, ctx)
    local owner = (r.parentUid and ns.FindParentRule and ns.FindParentRule(r)) or r
    local sc = ns.RuleScope(owner, ctx)
    if scope then return sc == scope end
    return sc ~= "disabled"
end
-- expand = true: the list holds rules by folder / scope, so cues are taken from their PARENT rule (a cue's own folder field is only
-- copied when it is made and can be stale or empty), and a parent that has cues but no display of its own is left out itself.
function ns.PvFilter(list, uv, expand)
    local scope = ns.PvScope(uv)
    local okc, ctx = false, nil
    if scope and scope ~= "disabled" then okc, ctx = pcall(ns.ReadContext); if not okc then ctx = nil end end
    local o = {}
    for _, r in ipairs(list) do
        if expand then
            if not r.parentUid and ns.PvKeep(r, scope, ctx) then
                for _, t in ipairs(ns.PreviewTargets(r)) do o[#o + 1] = t end
            end
        elseif ns.PvKeep(r, scope, ctx) then o[#o + 1] = r end
    end
    return o
end

local function Resolve(uv)
    if not uv then return nil end
    local last = uv:match("([^\001]+)$") or uv
    if last == "all" then
        local l = {}
        for _, r in ipairs(ns.rules or {}) do l[#l + 1] = r end
        l = ns.PvFilter(l, uv, true)
        return l, l
    elseif last == "allbars" then
        local l = {}
        for _, b in ipairs(ns.bars or {}) do l[#l + 1] = b end
        return l, nil
    end
    local n = last:match("^rule(%d+)$")
    if n then local r = ns.rules and ns.rules[tonumber(n)]; if r then local l = ns.PreviewTargets(r); return l, l end return nil end
    n = last:match("^bar(%d+)$")
    if n then local b = ns.bars and ns.bars[tonumber(n)]; if b then return { b }, nil end return nil end
    if last:match("^f%d") then
        local l = ns.PvFilter(FolderRules(last), uv, true)
        return l, l
    end
    if last == "smart" or last:match("^smart_") then
        if last == "smart_bar" then
            local l = {}
            for _, b in ipairs(ns.bars or {}) do l[#l + 1] = b end
            return l, nil
        end
        local l = {}
        local scope = uv:match("^(loaded)\001") or uv:match("^(notloaded)\001") or uv:match("^(disabled)\001")
        local okx, ctx2 = false, nil
        if scope then okx, ctx2 = pcall(ns.ReadContext) end
        for _, r in ipairs(ns.rules or {}) do
            if (last == "smart" and ns.SmartAny(r)) or (last ~= "smart" and ns.SmartMatch(r, last)) then
                if not scope or (okx and ns.RuleScope(r, ctx2) == scope) then l[#l + 1] = r end
            end
        end
        l = ns.PvFilter(l, uv)
        return l, l
    end
    if last == "loaded" or last == "notloaded" or last == "disabled" then
        local l = {}
        local okc, ctx = pcall(ns.ReadContext)
        for _, r in ipairs(ns.rules or {}) do
            if ns.RuleScope(r, okc and ctx or nil) == last then l[#l + 1] = r end
        end
        l = ns.PvFilter(l, uv, true)
        return l, l
    end
end

local function GroupState(objs, kind)
    local on = 0
    for _, o in ipairs(objs) do if ns.IsPreview(o, kind) then on = on + 1 end end
    if on == 0 then return 0 elseif on == #objs then return 1 end
    return 0.5
end

local soundAllDlg
local function ConfirmAllSounds(count, cb)
    local ui = CueRulesDB and CueRulesDB.ui
    if ui and ui.skipSoundAllPrompt then cb(); return end
    if not soundAllDlg then
        local f = CreateFrame("Frame", "XayaUISoundAllDialog", UIParent, "BackdropTemplate")
        f:SetSize(390, 170); f:SetPoint("CENTER"); f:SetFrameStrata("TOOLTIP"); f:EnableMouse(true)
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.text:SetPoint("TOP", 0, -24); f.text:SetWidth(340)
        f.check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        f.check:SetPoint("BOTTOMLEFT", 22, 52)
        f.checkLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.checkLabel:SetPoint("LEFT", f.check, "RIGHT", 2, 0)
        f.checkLabel:SetText("Don't ask me again")
        f.yes = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.yes:SetSize(110, 24); f.yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -8, 20); f.yes:SetText(YES)
        f.no = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.no:SetSize(110, 24); f.no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 8, 20); f.no:SetText(NO)
        f.no:SetScript("OnClick", function() f:Hide() end)
        f.yes:SetScript("OnClick", function()
            if f.check:GetChecked() and CueRulesDB and CueRulesDB.ui then CueRulesDB.ui.skipSoundAllPrompt = true end
            f:Hide()
            if f.cb then local c = f.cb; f.cb = nil; c() end
        end)
        tinsert(UISpecialFrames, "XayaUISoundAllDialog")
        soundAllDlg = f
    end
    soundAllDlg.cb = cb
    soundAllDlg.check:SetChecked(false)
    soundAllDlg.text:SetText("Play all " .. count .. " sounds at once? They will loop together until you switch the preview off.")
    soundAllDlg:Show()
end

local function MakeToggle(button, kind)
    local b = CreateFrame("Button", nil, button)
    b:SetSize(15, 15)
    b:SetFrameLevel(button:GetFrameLevel() + 3)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.kind = kind
    if kind == "visual" then ApplyIcon(b.tex, EYE_ATLASES, EYE_FILE) else ApplyIcon(b.tex, HEAD_ATLASES, HEAD_FILE) end
    b:SetScript("OnClick", function(self)
        local objs = self.objs
        if not objs or #objs == 0 then return end
        local on = GroupState(objs, self.kind) < 1
        local kindNow = self.kind
        local function go()
            ns.SetPreview(objs, kindNow, on)
            if ns.DecorateTrees then ns.DecorateTrees() end
            -- A full window refresh rebuilds the sidebar and throws its scroll position to the top, so the eye does not trigger one.
            -- Only the open rule's own pane ("PREVIEW ON" note) needs it, and then the scroll position is put back.
            local S = ns.RulesTreeStatus and ns.RulesTreeStatus()
            local rn = type(S and S.selected) == "string" and S.selected:match("rule(%d+)$")
            local open = rn and ns.rules and ns.rules[tonumber(rn)]
            local hit = false
            if open then for _, o in ipairs(objs) do if o == open or (o.parentUid and ns.FindParentRule and ns.FindParentRule(o) == open) then hit = true; break end end end
            if not hit then return end
            local tree = button.obj
            local st = tree and (tree.status or tree.localstatus)
            local sv = st and st.scrollvalue
            Notify()
            if st and sv then
                local function put() st.scrollvalue = sv; if tree.scrollbar and tree.scrollbar.SetValue then pcall(tree.scrollbar.SetValue, tree.scrollbar, sv) end end
                put(); if C_Timer then C_Timer.After(0, put) end
            end
        end
        if on and kindNow == "sound" and #objs > 1 then ConfirmAllSounds(#objs, go) else go() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local what = (self.kind == "visual") and "Preview the texture / bar" or "Loop the sound"
        GameTooltip:SetText(what .. " (temporary)")
        GameTooltip:AddLine("Applies to everything under this row. Ignores conditions; never changes the rule.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function MakeChevron(button)
    local b = CreateFrame("Button", nil, button)
    b:SetSize(16, 16)
    b:SetFrameLevel(button:GetFrameLevel() + 3)
    b:SetScript("OnClick", function(self)
        local tree = button.obj
        local st = tree and (tree.status or tree.localstatus)
        local uv = button.uniquevalue
        if st and st.groups and uv then
            st.groups[uv] = not st.groups[uv]
            tree:RefreshTree()
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Expand / collapse the list under this row")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Drag a rule row or a folder row (not "All rules") onto a folder row, "All rules", or a rule row to move it.
local drag, dragFrame = {}, nil
local function LastKey(uv) return uv and uv:match("([^\001]+)$") end
local function RowUnderCursor(tree)
    for _, b in ipairs(tree and tree.buttons or {}) do
        if b:IsShown() and b:IsMouseOver() then return b end
    end
end
-- returns ok, folderId (nil = top level)
local function DropTarget(b, kind, obj)
    local last = LastKey(b and b.uniquevalue)
    if not last then return false end
    if last == "all" then return true, nil end
    if last:match("^f%d") then
        if not FolderById(last) then return false end
        if kind == "folder" and IsInFolder(last, obj.id) then return false end  -- itself or its own subfolder
        return true, last
    end
    local n = last:match("^rule(%d+)$")
    local r = n and ns.rules and ns.rules[tonumber(n)]
    if r then
        local fid = (r.folder and FolderById(r.folder)) and r.folder or nil
        if kind == "folder" and fid and IsInFolder(fid, obj.id) then return false end
        return true, fid
    end
    return false
end
local function StartDrag(button)
    local last = LastKey(button.uniquevalue) or ""
    local kind, obj, label
    local n = last:match("^rule(%d+)$")
    if n then
        kind, obj = "rule", ns.rules and ns.rules[tonumber(n)]
        if obj then
            label = obj.name
            if not label or label == "" then local ok, sn = pcall(C_Spell.GetSpellName, obj.spellID); label = ok and sn or ("Rule " .. n) end
        end
    elseif last:match("^f%d") then
        kind, obj = "folder", FolderById(last)
        label = obj and obj.name
    end
    if not obj then return end
    drag.kind, drag.obj, drag.src, drag.hl = kind, obj, button, nil
    if not dragFrame then
        dragFrame = CreateFrame("Frame", nil, UIParent)
        dragFrame:SetFrameStrata("TOOLTIP")
        dragFrame:SetSize(200, 20)
        dragFrame.bg = dragFrame:CreateTexture(nil, "BACKGROUND")
        dragFrame.bg:SetAllPoints(); dragFrame.bg:SetColorTexture(0, 0, 0, 0.7)
        dragFrame.text = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dragFrame.text:SetPoint("CENTER")
    end
    dragFrame.text:SetText(label or "")
    dragFrame:SetWidth(math.max(80, dragFrame.text:GetStringWidth() + 16))
    dragFrame:Show()
    dragFrame:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / sc + 12, y / sc - 4)
        local tb = RowUnderCursor(drag.src and drag.src.obj)
        local ok = tb and tb ~= drag.src and DropTarget(tb, drag.kind, drag.obj)
        local want = ok and tb or nil
        if drag.hl ~= want then
            if drag.hl then drag.hl:UnlockHighlight() end
            if want then want:LockHighlight() end
            drag.hl = want
        end
    end)
end
local function StopDrag(button)
    local kind, obj = drag.kind, drag.obj
    if not obj then return end
    drag.kind, drag.obj = nil, nil
    if dragFrame then dragFrame:Hide(); dragFrame:SetScript("OnUpdate", nil) end
    if drag.hl then drag.hl:UnlockHighlight(); drag.hl = nil end
    local tb = RowUnderCursor(button.obj)
    if not tb or tb == button then return end
    local ok, target = DropTarget(tb, kind, obj)
    if not ok then return end
    if kind == "rule" then
        if ns.MultiHas and ns.MultiHas(obj) and ns.MultiCount() > 1 then ns.MultiMove(target); return end   -- dragging one selected rule moves them all
        if obj.folder == target then return end
        obj.folder = target
        ns.MarkDirty(); Notify()
        ns.SelectKeep(RulePath(obj))
    else
        if obj.parent == target then return end
        obj.parent = target
        ns.MarkDirty(); Notify()
        ns.SelectKeep(FolderPath(obj))
    end
end

-------------------------------------------------------------------------------
-- Reorder arrows: small up / down triangles at the left of every rule and folder row under All Rules.
-- A rule moves among the rules of its own folder (position in ns.rules); a folder moves among the folders that share its
-- parent (position in ns.folders). Folders are always listed above rules, as before. Nothing else about a row changes.
-------------------------------------------------------------------------------
ns.REORDER_W = 13
do   -- scoped: the main chunk is near Lua's 200-local limit
local function RuleGroupKey(r) return (r.folder and FolderById(r.folder)) and r.folder or false end
local function IsNestedOutcome(r) return (r.parentUid and ns.FindParentRule and ns.FindParentRule(r)) and true or false end
local function FolderParentKey(f) return (f.parent and FolderById(f.parent)) and f.parent or false end

-- Until the first move, top-level order is the legacy one (default categories fixed, the rest by list position). The first
-- move bakes that order into ns.folders and switches ui.folderOrdered on, so list position is the order from then on.
function ns.FolderSortOrder(f, k, dpos)
    local ui = CueRulesDB and CueRulesDB.ui
    if ui and ui.folderOrdered then return 100 + k end
    return dpos and (10 + dpos) or (100 + k)
end
local function NormalizeFolderOrder()
    local ui = CueRulesDB and CueRulesDB.ui
    if not ui or ui.folderOrdered then return end
    local keyed = {}
    for k, f in ipairs(ns.folders) do
        local _, dpos = ns.DefaultFolderInfo(f.default)
        keyed[#keyed + 1] = { f = f, k = k, key = dpos and (10 + dpos) or (100 + k) }
    end
    table.sort(keyed, function(a, b) if a.key ~= b.key then return a.key < b.key end return a.k < b.k end)
    for i, e in ipairs(keyed) do ns.folders[i] = e.f end
    ui.folderOrdered = true
end

-- returns kind, obj, list of sibling indices, position in that list
local function Siblings(uv)
    local last = LastKey(uv) or ""
    -- in the Loaded / Not Loaded views only the rows shown there count as neighbors (so an arrow always moves the row visibly)
    local first = tostring(uv or ""):match("^([^\001]+)")
    local scope = (first == "loaded" or first == "notloaded" or first == "disabled") and first or nil
    local okc, ctx
    if scope then okc, ctx = pcall(ns.ReadContext) end
    local function RuleInScope(r)
        if not scope then return true end
        return okc and ns.RuleScope(r, ctx) == scope or false
    end
    local function FolderInScope(f)
        if not scope then return true end
        local function has(fid, depth)
            if depth > 16 then return false end
            for _, r in ipairs(ns.rules or {}) do
                if r.folder == fid and not IsNestedOutcome(r) and RuleInScope(r) then return true end
            end
            for _, x in ipairs(ns.folders or {}) do
                if x.parent == fid and has(x.id, depth + 1) then return true end
            end
            return false
        end
        return has(f.id, 0)
    end
    local n = last:match("^rule(%d+)$")
    if n then
        local rule = ns.rules and ns.rules[tonumber(n)]
        if not rule or IsNestedOutcome(rule) then return end
        local key, list, pos = RuleGroupKey(rule), {}, nil
        for i, r in ipairs(ns.rules) do
            if not IsNestedOutcome(r) and RuleGroupKey(r) == key and RuleInScope(r) then list[#list + 1] = i; if r == rule then pos = #list end end
        end
        return "rule", rule, list, pos
    end
    local f = last:match("^f%d") and FolderById(last)
    if f then
        local key, list, pos = FolderParentKey(f), {}, nil
        for i, x in ipairs(ns.folders) do
            if FolderParentKey(x) == key and (x == f or FolderInScope(x)) then list[#list + 1] = i; if x == f then pos = #list end end
        end
        return "folder", f, list, pos
    end
end

local function ReorderRow(button, dir)
    local kind, obj, list, pos = Siblings(button.uniquevalue)
    if not obj or not pos then return end
    local tree = button.obj
    local st = tree and (tree.status or tree.localstatus)
    local selLast = LastKey(st and st.selected)
    local sn = selLast and selLast:match("^rule(%d+)$")
    local selRule = sn and ns.rules and ns.rules[tonumber(sn)] or nil   -- keep the current selection on the same rule
    if kind == "folder" then
        NormalizeFolderOrder()
        local _
        _, obj, list, pos = Siblings(button.uniquevalue)
        if not pos then return end
    end
    local other = list[pos + dir]
    if not other then return end
    local arr = (kind == "rule") and ns.rules or ns.folders
    local i = list[pos]
    arr[i], arr[other] = arr[other], arr[i]
    ns.MarkDirty(); Notify()
    if selRule then ns.SelectKeep(RulePath(selRule)) end
end

local function MakeReorderArrow(button, dir)
    local b = CreateFrame("Button", nil, button)
    b:SetSize(ns.REORDER_W, 9)
    b:SetFrameLevel(button:GetFrameLevel() + 3)
    b.dir = dir
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetSize(13, 13)
    b.tex:SetPoint("CENTER")
    local up, down = "Interface\\Buttons\\Arrow-Up-Up", "Interface\\Buttons\\Arrow-Down-Up"
    local base = dir < 0 and up or down
    b.tex:SetTexture(base)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.tex:SetPoint("CENTER", 0, -1) end end)
    b:SetScript("OnMouseUp", function(self) self.tex:SetPoint("CENTER", 0, 0) end)
    b:SetScript("OnClick", function(self) ReorderRow(button, self.dir) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self:IsEnabled() then
            GameTooltip:SetText(self.dir < 0 and "Move up" or "Move down")
            GameTooltip:AddLine("Changes the order within this list. Rules inside a group stay in that group.", 1, 1, 1, true)
        else
            GameTooltip:SetText(self.dir < 0 and "Already first" or "Already last")
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- called from DecorateButton; sets button.xuiReorderOn when the row reserves the arrow slot
function ns.PaintReorder(button, level, x)
    local uv = tostring(button.uniquevalue or "")
    local root0 = uv:match("^([^\001]+)")
    local slot = (root0 == "all" or root0 == "loaded" or root0 == "notloaded" or root0 == "disabled") and level >= 2 and not uv:find("\001smart", 1, true)
    button.xuiReorderOn = slot
    local kind, obj, list, pos
    if slot then kind, obj, list, pos = Siblings(uv) end
    if not (slot and obj and pos) then
        if button.xuiUp then button.xuiUp:Hide(); button.xuiDown:Hide() end
        return
    end
    if not button.xuiUp then button.xuiUp = MakeReorderArrow(button, -1); button.xuiDown = MakeReorderArrow(button, 1) end
    local function paint(b, can, anchor, dy)
        b:ClearAllPoints(); b:SetPoint("CENTER", button, "LEFT", x + 8, dy)
        b:SetEnabled(can)
        b.tex:SetDesaturated(not can)
        b.tex:SetAlpha(can and 1 or 0.3)
        b:Show()
    end
    paint(button.xuiUp, pos > 1, nil, 6)
    paint(button.xuiDown, pos < #list, nil, -6)
end
end

-------------------------------------------------------------------------------
-- Right-click context menu on sidebar rows (rename / duplicate / move to / delete ...)
-------------------------------------------------------------------------------
StaticPopupDialogs["XAYAUI_CONFIRM"] = {
    text = "%s", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    OnAccept = function(self, data) if data and data.cb then data.cb() end end,
}
local function PopupEditBox(self) return self.editBox or (self.GetEditBox and self:GetEditBox()) end
StaticPopupDialogs["XAYAUI_RENAME"] = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, maxLetters = 64, timeout = 0, whileDead = true,
    hideOnEscape = true, preferredIndex = 3,
    OnShow = function(self, data)
        local eb = PopupEditBox(self)
        if eb then eb:SetText((data and data.current) or ""); eb:HighlightText() end
    end,
    OnAccept = function(self, data)
        local eb = PopupEditBox(self)
        local t = eb and eb:GetText()
        if t and t ~= "" and data and data.cb then data.cb(t) end
    end,
    EditBoxOnEnterPressed = function(eb)
        local p = eb:GetParent()
        local t, data = eb:GetText(), p.data
        p:Hide()
        if t and t ~= "" and data and data.cb then data.cb(t) end
    end,
    EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
}
local function ShowPopup(which, text, data)
    local dlg = StaticPopup_Show(which, text, nil, data)
    if dlg then dlg:SetFrameStrata("TOOLTIP") end   -- the options window is FULLSCREEN_DIALOG; keep the popup above it
end
local function AskRename(current, cb) ShowPopup("XAYAUI_RENAME", "Rename", { current = current, cb = cb }) end
local function AskConfirm(text, cb) ShowPopup("XAYAUI_CONFIRM", text, { cb = cb }) end

-- Export one rule (right-click > Export): shows the export text in a popup, selected, ready for Ctrl+C.
StaticPopupDialogs["XAYAUI_EXPORT"] = {
    text = "%s", button1 = CLOSE, hasEditBox = true, editBoxWidth = 360, maxLetters = 0, timeout = 0, whileDead = true,
    hideOnEscape = true, preferredIndex = 3,
    OnShow = function(self, data)
        local eb = PopupEditBox(self)
        if eb then
            if eb.SetMaxLetters then eb:SetMaxLetters(0) end
            eb:SetText((data and data.text) or ""); eb:HighlightText(); eb:SetFocus()
        end
    end,
    EditBoxOnTextChanged = function(eb)
        local data = eb:GetParent().data
        if data and data.text and eb:GetText() ~= data.text then eb:SetText(data.text); eb:HighlightText() end   -- read-only
    end,
    EditBoxOnEnterPressed = function(eb) eb:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
}
ns.UI.ExportRule = function(rule)
    local snap = ns.Profile_SnapshotRule(rule, tostring(rule.name or "Rule"))
    local txt, err = ns.Profile_Encode(snap)
    if not txt then ns.Print("could not export '" .. tostring(rule.name) .. "': " .. tostring(err)); return end
    local n = #snap.rules - 1
    ShowPopup("XAYAUI_EXPORT", "Export of '" .. tostring(rule.name) .. "'" .. (n > 0 and (" (+" .. n .. " condition" .. (n > 1 and "s" or "") .. ")") or "")
        .. "\nCtrl+C to copy, then paste it into Profiles > Import on the other character or account.", { text = txt })
end

-- Display <-> Sound: build equivalent rules in the other bucket from what each rule tracks (spell, aura, talents, states).
-- Load conditions start blank and the new rule starts disabled with its one output ticked, so turning it on is a single switch.
local function ConvertFolder(src, mode)
    local toKey = (src.default == "display") and "sound" or "display"
    local dst
    for _, f in ipairs(ns.folders) do if not f.parent and f.default == toKey then dst = f; break end end
    if not dst then ns.Print("that category group is missing - create a group for it under Smart Categories first"); return end
    local rules = FolderRules(src.id)
    if #rules == 0 then ns.Print("nothing inside '" .. tostring(src.name) .. "' to " .. mode); return end
    local sub = ns.NewFolder((mode == "copy" and "Copied from " or "Moved from ") .. tostring(src.name), dst.id)
    for _, r in ipairs(rules) do
        local n = ns.NewRule()
        n.name = r.name
        for _, k in ipairs({ "spellID", "maxCharges", "cdState", "buffID", "buffState", "talentMode" }) do n[k] = r[k] end
        n.buffAlt = r.buffAlt and ns.Copy(r.buffAlt) or nil
        n.talents = ns.Copy(r.talents or {})
        n.extra = ns.Copy(r.extra or { list = {} })
        n.folder = sub.id
        n.enabled = false
        if toKey == "sound" then n.sound.enabled, n.visual.enabled = true, false
        else n.visual.enabled, n.sound.enabled = true, false end
        ns.rules[#ns.rules + 1] = n
        pcall(ns.RefreshVisual, n)
    end
    if mode == "transform" then
        for _, r in ipairs(rules) do
            for idx, x in ipairs(ns.rules) do if x == r then table.remove(ns.rules, idx); break end end
            pcall(ns.DropVisual, r)
        end
    end
    ns.MarkDirty(); Notify()
    ns.Print((mode == "copy" and "copied " or "moved ") .. #rules .. " rule(s) into '" .. tostring(dst.name) .. "' (disabled; turn them on and pick a " .. (toKey == "sound" and "sound" or "display") .. ")")
end

local function SelectRoot() ns.GoHome() end

local function DeleteRule(rule)
    if ns.DeleteOutcomesOf then ns.DeleteOutcomesOf(rule) end
    for idx, r in ipairs(ns.rules) do if r == rule then table.remove(ns.rules, idx); break end end
    ns.DropVisual(rule); ns.MarkDirty(); Notify(); SelectRoot()
end
local function DuplicateRule(rule)
    local c = ns.Copy(rule)
    c.name = ((rule.name and rule.name ~= "") and rule.name or "Rule") .. " Copy"
    if ns.CloneOutcomes then ns.CloneOutcomes(rule, c) end
    ns.rules[#ns.rules + 1] = c
    pcall(ns.RefreshVisual, c)
    ns.MarkDirty(); Notify()
    ns.SelectKeep(RulePath(c))
end
-- copies a folder with its rules and subfolders (children keep their names; the top copy gets " Copy")
local function DuplicateFolder(f, parentId, top)
    local nf = ns.NewFolder(f.name .. (top and " Copy" or ""), parentId)
    for _, r in ipairs(ns.rules) do
        if r.folder == f.id then
            local c = ns.Copy(r); c.folder = nf.id
            ns.rules[#ns.rules + 1] = c
            pcall(ns.RefreshVisual, c)
            if ns.RememberCopy then ns.RememberCopy(r, c) end
        end
    end
    if ns.RemapCopies then ns.RemapCopies() end
    local kids = {}
    for _, ff in ipairs(ns.folders) do if ff.parent == f.id and ff ~= nf then kids[#kids + 1] = ff end end
    for _, ff in ipairs(kids) do DuplicateFolder(ff, nf.id, false) end
    return nf
end
local function DeleteFolder(f)
    for _, r in ipairs(ns.rules) do if r.folder == f.id then r.folder = f.parent end end
    for _, ff in ipairs(ns.folders) do if ff.parent == f.id then ff.parent = f.parent end end
    for idx, ff in ipairs(ns.folders) do if ff == f then table.remove(ns.folders, idx); break end end
    ns.MarkDirty(); Notify(); SelectRoot()
end

function ns.DeleteFolderById(id) local f = FolderById(id); if f then DeleteFolder(f) end end
-- Deletes the group, every group nested in it and every rule inside them (and those rules' cues / conditions).
function ns.DeleteFolderAll(f)
    local ids, stack = { [f.id] = true }, { f.id }
    while #stack > 0 do
        local cur = table.remove(stack)
        for _, ff in ipairs(ns.folders) do
            if ff.parent == cur and not ids[ff.id] then ids[ff.id] = true; stack[#stack + 1] = ff.id end
        end
    end
    local doomed = {}
    for _, r in ipairs(ns.rules) do if r.folder and ids[r.folder] and not r.parentUid then doomed[#doomed + 1] = r end end
    for _, r in ipairs(doomed) do
        if ns.DeleteOutcomesOf then pcall(ns.DeleteOutcomesOf, r) end
        for idx, x in ipairs(ns.rules) do if x == r then table.remove(ns.rules, idx); break end end
        pcall(ns.DropVisual, r)
    end
    for _, r in ipairs(ns.rules) do if r.folder and ids[r.folder] then r.folder = nil end end   -- stray cue rows, if any
    for idx = #ns.folders, 1, -1 do if ids[ns.folders[idx].id] then table.remove(ns.folders, idx) end end
    ns.MarkDirty(); Notify(); SelectRoot()
    return #doomed
end
function ns.DeleteFolderAllById(id) local f = FolderById(id); if f then return ns.DeleteFolderAll(f) end end

local function AddMoveMenu(root, obj, kind)
    local multi = kind == "rule" and ns.MultiHas and ns.MultiHas(obj) and ns.MultiCount() > 1
    local sub = root:CreateButton(multi and ("Move " .. ns.MultiCount() .. " Selected To") or "Move To")
    sub:CreateButton("Top Level (Smart Categories)", function()
        if multi then ns.MultiMove(nil); return end
        if kind == "rule" then obj.folder = nil else obj.parent = nil end
        ns.MarkDirty(); Notify()
    end)
    local _, fOrder = FolderValues()
    for _, fid in ipairs(fOrder) do
        local f = fid ~= "none" and FolderById(fid)
        if f and not (kind == "folder" and IsInFolder(f.id, obj.id)) then
            local depth = 0
            for _, c in ipairs(FolderChain(f)) do if not ns.CueTransparent(c) then depth = depth + 1 end end
            depth = depth - 1
            sub:CreateButton(string.rep("    ", depth) .. f.name, function()
                if multi then ns.MultiMove(f.id); return end
                if kind == "rule" then obj.folder = f.id else obj.parent = f.id end
                ns.MarkDirty(); Notify()
                if kind == "rule" then ns.SelectKeep(RulePath(obj))
                else ns.SelectKeep(FolderPath(obj)) end
            end)
        end
    end
end

-- Copy / paste lives only in the right-click menu. Ticks are session-only; nothing is ticked by default, so nothing is overwritten
-- until sections are chosen. Returning MenuResponse.Refresh keeps the submenu open while ticking (unverified in game: if the
-- game ignores it, the menu simply closes after each tick).
function ns.PasteMenuBuild(menu, nodes, refresh)
    local function leaves(list, out)
        for _, n in ipairs(list) do
            if type(n[2]) == "table" then leaves(n[2], out) elseif n[2] then out[#out + 1] = n[1] end
        end
        return out
    end
    for _, n in ipairs(nodes) do
        if n[1] == "XROWS" then
            local rows = ruleClip and ruleClip.data.extra and ruleClip.data.extra.list or {}
            if #rows > 0 then
                local sm = menu:CreateButton("Single additional triggers (added to the target's)")
                for i, row in ipairs(rows) do
                    local def = ns.TRIGGER_TYPES and ns.TRIGGER_TYPES[row.type]
                    local nm = (type(row.name) == "string" and row.name:match("%S")) and (row.name .. ":  ") or ""
                    local key = "xr" .. i
                    sm:CreateCheckbox(("Trigger %d:  %s%s"):format(i + 2, nm, tostring((def and (def.label or def.name)) or row.type or "?")),
                        function() return pasteSel[key] and true or false end,
                        function() pasteSel[key] = (not pasteSel[key]) or nil; return refresh end)
                end
            end
        elseif type(n[2]) == "table" then
            local sm = menu:CreateButton(n[1])
            local ks = leaves(n[2], {})
            sm:CreateCheckbox("All of " .. n[1],
                function() for _, k in ipairs(ks) do if not pasteSel[k] then return false end end return true end,
                function()
                    local all = true
                    for _, k in ipairs(ks) do if not pasteSel[k] then all = false end end
                    for _, k in ipairs(ks) do pasteSel[k] = (not all) or nil end
                    return refresh
                end)
            sm:CreateDivider()
            ns.PasteMenuBuild(sm, n[2], refresh)
        else
            local k = n[1]
            menu:CreateCheckbox(n[2],
                function() return pasteSel[k] and true or false end,
                function() pasteSel[k] = (not pasteSel[k]) or nil; return refresh end)
        end
    end
end
local function AddPasteMenu(root, label, getTargets, describe)
    local sub = root:CreateButton(label)
    local refresh = MenuResponse and MenuResponse.Refresh
    sub:CreateTitle(ruleClip and ("Copied: " .. tostring(ruleClip.name)) or "Nothing copied yet (use Copy Settings)")
    local okP, errP = pcall(ns.PasteMenuBuild, sub, ns.PASTE_TREE, refresh)   -- a fault in the paste tree must never take the whole right-click menu down
    if not okP then ns.Print("paste menu error: " .. tostring(errP)) end
    sub:CreateDivider()
    sub:CreateButton("Paste Selected Sections", function()
        if not ruleClip then ns.Print("nothing copied yet: right-click a rule and choose Copy Settings first") return end
        if PasteCount() == 0 then ns.Print("no sections selected: tick the sections to paste in the Paste Settings menu first") return end
        local targets = getTargets()
        local warn = ((pasteSel.idsCd or pasteSel.idsBuff) and #targets > 1) and "\n|cffff8040Trigger IDs are selected: every one of these rules will track the same spell and aura.|r" or ""
        if pasteSel.conditions then warn = warn .. "\n|cffff8040Conditions replace the target's conditions. They refer to the rule's triggers and cues, so tick those sections too if the target's differ.|r" end
        if pasteSel.cues then warn = warn .. "\n|cffff8040Cues replace every cue of the target.|r" end
        AskConfirm("Overwrite these sections on " .. describe() .. " with settings from '" .. tostring(ruleClip.name) .. "'?\n" .. PasteSummary() .. warn,
            function()
                local n = 0
                wipe(ns.pasteNotes)
                for _, r in ipairs(targets) do if PasteInto(r) then n = n + 1 end end
                Notify(); ns.Print(("pasted into %d rule(s)"):format(n))
                for _, note in ipairs(ns.pasteNotes) do ns.Print("paste note: " .. note) end
            end)
    end)
end

local function RowMenu(button, root)
    local last = LastKey(button.uniquevalue) or ""
    local n = last:match("^rule(%d+)$")
    local rule = n and ns.rules and ns.rules[tonumber(n)]
    if rule then
        root:CreateTitle((rule.name and rule.name ~= "") and rule.name or "Rule")
        if ns.IsEditLocked(rule) then
            root:CreateTitle("|cffff6060Edits blocked|r")
            root:CreateButton("Duplicate", function() DuplicateRule(rule) end)
            root:CreateButton("Export", function() ns.UI.ExportRule(rule) end)
            root:CreateButton("Copy Settings", function() ruleClip = ns.MakeClip(rule); Notify() end)
            return true
        end
        root:CreateButton("Rename", function()   -- edits in the sidebar row; the popup is only the fallback when the row is gone
            if not (ns.SidebarRenameLater and ns.SidebarRenameLater(button)) then AskRename(rule.name, function(t) rule.name = t; pcall(ns.RefreshVisual, rule); ns.MarkDirty(); Notify() end) end
        end)
        root:CreateButton("Duplicate", function() DuplicateRule(rule) end)
        root:CreateButton("Export", function() ns.UI.ExportRule(rule) end)
        root:CreateButton("Copy Settings", function() ruleClip = ns.MakeClip(rule); Notify(); ns.Print("copied settings of '" .. tostring(rule.name) .. "'") end)
        AddPasteMenu(root, "Paste Settings", function() return { rule } end, function() return "'" .. tostring(rule.name) .. "'" end)
        root:CreateButton(rule.enabled and "Disable" or "Enable", function()
            rule.enabled = not rule.enabled; pcall(ns.RefreshVisual, rule); ns.MarkDirty(); Notify()
        end)
        AddMoveMenu(root, rule, "rule")
        root:CreateDivider()
        root:CreateButton("Delete", function() AskConfirm("Delete the rule '" .. tostring(rule.name) .. "'?", function() DeleteRule(rule) end) end)
        return true
    end
    local fold = last:match("^f%d") and FolderById(last)
    if fold then
        root:CreateTitle(fold.name)
        root:CreateButton("Rename", function()
            if not (ns.SidebarRenameLater and ns.SidebarRenameLater(button)) then AskRename(fold.name, function(t) fold.name = t; ns.MarkDirty(); Notify() end) end
        end)
        root:CreateButton("New Rule Here", function()
            StartNewRule(fold.id)
        end)
        root:CreateButton("New Nested Group", function()
            local nf = ns.NewFolder("Group", fold.id)
            local path = { ns.PlaceNewGroup(nf, ns.ScopeOfUV(button.uniquevalue)) }   -- same list as the parent row
            Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, unpack(path))
        end)
        root:CreateButton("Duplicate", function()
            local nf = DuplicateFolder(fold, fold.parent, true)
            ns.MarkDirty(); Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, FolderPath(nf))
        end)
        if not fold.parent and (fold.default == "display" or fold.default == "sound") then
            local to = (fold.default == "display") and "Sound" or "Display"
            root:CreateDivider()
            root:CreateButton("Copy " .. fold.name .. " to " .. to .. " Cues", function() ConvertFolder(fold, "copy") end)
            root:CreateButton("Transform " .. fold.name .. " to " .. to .. " Cues", function()
                AskConfirm("Transform every rule in '" .. tostring(fold.name) .. "' into " .. to .. " Cues? The originals are removed.", function() ConvertFolder(fold, "transform") end)
            end)
            root:CreateDivider()
        end
        root:CreateButton("Enable All Rules Inside", function() for _, r in ipairs(FolderRules(fold.id)) do r.enabled = true; pcall(ns.RefreshVisual, r) end; ns.MarkDirty(); Notify() end)
        root:CreateButton("Disable All Rules Inside", function() for _, r in ipairs(FolderRules(fold.id)) do r.enabled = false; pcall(ns.RefreshVisual, r) end; ns.MarkDirty(); Notify() end)
        AddPasteMenu(root, "Paste Settings Into Rules Here", function() return FolderRules(fold.id) end,
            function() return "every rule in '" .. tostring(fold.name) .. "' (and its nested groups)" end)
        AddMoveMenu(root, fold, "folder")
        root:CreateDivider()
        root:CreateButton("Delete Group (Contents Move Up)", function()
            AskConfirm("Delete the group '" .. fold.name .. "'? Its rules and nested groups are kept and move up one level.", function() DeleteFolder(fold) end)
        end)
        root:CreateButton("|cffff6060Delete Group and All Contents|r", function()
            local n = #FolderRules(fold.id)
            AskConfirm("Delete the group '" .. fold.name .. "' AND everything inside it: " .. n .. " rule(s) and all nested groups? This cannot be undone.", function() ns.DeleteFolderAll(fold) end)
        end)
        return true
    end
    n = last:match("^bar(%d+)$")
    local bar = n and ns.bars and ns.bars[tonumber(n)]
    if bar then
        root:CreateTitle(bar.name or "Buff Bar")
        root:CreateButton("Rename", function() AskRename(bar.name, function(t) bar.name = t; ns.Bars_Refresh(bar); ns.MarkDirty(); Notify() end) end)
        root:CreateButton("Duplicate", function()
            local c = ns.Copy(bar); c.name = (bar.name or "Buff bar") .. " Copy"
            ns.bars[#ns.bars + 1] = c; ns.Bars_Refresh(c); ns.MarkDirty(); Notify()
        end)
        root:CreateDivider()
        root:CreateButton("Delete", function()
            AskConfirm("Delete the bar '" .. tostring(bar.name) .. "'?", function()
                for idx, b in ipairs(ns.bars) do if b == bar then table.remove(ns.bars, idx); break end end
                ns.Bars_Drop(bar); ns.MarkDirty(); Notify()
                pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allbars")
            end)
        end)
        return true
    end
    n = last:match("^box(%d+)$")
    local box = n and ns.qolBoxes and ns.qolBoxes[tonumber(n)]
    if box then
        root:CreateTitle(box.name or "Stats Box")
        root:CreateButton("Rename", function() AskRename(box.name, function(t) box.name = t; ns.QoL_Refresh(box); ns.MarkDirty(); Notify() end) end)
        root:CreateButton("Duplicate", function()
            local c = ns.Copy(box); c.name = (box.name or "Stats") .. " Copy"; c.y = (c.y or 0) - 30
            ns.qolBoxes[#ns.qolBoxes + 1] = c; ns.QoL_Refresh(c); ns.MarkDirty(); Notify()
        end)
        root:CreateDivider()
        root:CreateButton("Delete", function()
            AskConfirm("Delete the box '" .. tostring(box.name) .. "'?", function()
                for idx, b in ipairs(ns.qolBoxes) do if b == box then table.remove(ns.qolBoxes, idx); break end end
                ns.QoL_Drop(box); ns.MarkDirty(); Notify()
                pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allqol")
            end)
        end)
        return true
    end
    if last == "all" then
        root:CreateTitle("Smart Categories")
        root:CreateButton("New Rule", function()
            StartNewRule(nil)
        end)
        root:CreateButton("New Group", function()
            local nf = ns.NewFolder("Group")
            Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, ns.FolderLoadedPath(nf))
        end)
        return true
    end
    return false
end

-- Blizzard's Menu code (Blizzard_Menu/Menu.lua) gives a menu the strata FULLSCREEN_DIALOG, or TOOLTIP when its owner region is
-- at TOOLTIP strata. The options window is also FULLSCREEN_DIALOG and sits higher in level, so the menu opened behind it.
-- Fix: use an invisible TOOLTIP-strata frame laid over the clicked row as the menu's owner region.
local menuOwner
local function MenuOwner(button)
    if not menuOwner then
        menuOwner = CreateFrame("Frame", nil, UIParent)
        menuOwner:SetFrameStrata("TOOLTIP")
        menuOwner:EnableMouse(false)
    end
    menuOwner:ClearAllPoints()
    menuOwner:SetPoint("TOPLEFT", button, "TOPLEFT")
    menuOwner:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
    menuOwner:Show()
    return menuOwner
end

local function ShowRowMenu(button)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then ns.Print("the context menu needs the game's MenuUtil, which is not available") return end
    local shown = false
    local ok, err = pcall(MenuUtil.CreateContextMenu, MenuOwner(button), function(_, root)
        -- Menu.lua runs root-registered acquired callbacks for every menu and submenu it opens, so submenus (e.g. Move To) are
        -- raised above the options window too.
        if root.AddMenuAcquiredCallback then
            root:AddMenuAcquiredCallback(function(menu)
                if menu and menu.SetFrameStrata then
                    pcall(menu.SetFrameStrata, menu, "TOOLTIP")
                    if menu.Raise then pcall(menu.Raise, menu) end
                end
            end)
        end
        shown = RowMenu(button, root)
    end)
    if not ok then ns.Print("context menu error: " .. tostring(err)) end
end

-- Right-click on EMPTY space in the Rules sidebar (below the last row, or between rows): New Rule / New Group / New Dynamic Group at the cursor.
-- Rows keep their own menu (RowMenu); this only fires when the click lands on the sidebar frame itself.
function ns.ShowBlankMenu(frame)
    local tab = ns.CurrentTab and ns.CurrentTab()
    if tab ~= "cooldowns" and tab ~= "smartcat" then return end   -- only the Rules sidebar; QoL and Settings trees have no rule list
    if not (MenuUtil and MenuUtil.CreateContextMenu) then ns.Print("the context menu needs the game's MenuUtil, which is not available") return end
    local function NewGroup(dynamic)
        local nf = ns.NewFolder(dynamic and "Dynamic Group" or "Group")
        if dynamic then nf.cType = "dynamic" end
        ns.MarkDirty(); Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, ns.FolderLoadedPath(nf))
    end
    local ok, err = pcall(MenuUtil.CreateContextMenu, MenuOwner(frame), function(_, root)
        if root.AddMenuAcquiredCallback then
            root:AddMenuAcquiredCallback(function(menu)
                if menu and menu.SetFrameStrata then
                    pcall(menu.SetFrameStrata, menu, "TOOLTIP")
                    if menu.Raise then pcall(menu.Raise, menu) end
                end
            end)
        end
        root:CreateTitle("Create")
        root:CreateButton("New Rule", function() StartNewRule(nil) end)
        root:CreateButton("New Group", function() NewGroup(false) end)
        root:CreateButton("New Dynamic Group", function() NewGroup(true) end)
    end)
    if not ok then ns.Print("context menu error: " .. tostring(err)) end
end
-- hook the sidebar frame of a tree once; called from the row decorator, which knows its tree (button.obj)
function ns.HookSidebarBlank(tree)
    local tf = tree and tree.treeframe
    if not tf or tf.xuiBlankHook then return end
    tf.xuiBlankHook = true
    tf:EnableMouse(true)   -- rows and the search box sit on top and take their own clicks; only free space reaches the frame
    tf:HookScript("OnMouseUp", function(self, mouse)
        if mouse == "RightButton" then pcall(ns.ShowBlankMenu, self) end
    end)
end

-- Header rows (the root row and every top-level folder) get a tinted banner so each reads as its own group.
local BANNER_TINT = {
    root = { 1, 0.78, 0 }, loaded = { 0.1, 0.85, 0.75 }, notloaded = { 0.95, 0.2, 0.2 }, disabled = { 0.55, 0.55, 0.6 }, display = { 0.1, 0.5, 1 }, sound = { 0.1, 0.75, 0.3 }, hybrid = { 1, 0.5, 0.1 }, advanced = { 0.75, 0.25, 1 }, smart = { 0.3, 0.8, 1 }, cursor = { 0.95, 0.35, 0.75 }, other = { 0.7, 0.7, 0.75 },
}
-- Sidebar highlight: every category / folder row is neutral gray; the selected row, its parent groups and the rows inside the
-- selected group take the purple of the Advanced Cue Tracking banner. (Row sizes and fonts still follow BannerTint.)
ns.NEUTRAL_TINT = { 0.2, 0.2, 0.24 }
function ns.SelectedUV(button)
    local tree = button and button.obj
    local st = tree and (tree.status or tree.localstatus)
    return st and st.selected and tostring(st.selected) or nil
end
function ns.HotPath(sel, prefix)   -- prefix is the selected path, above it, or inside it
    if not sel or not prefix then return false end
    -- only the selected row itself (never its parents or the rows inside it); the root rows (All Rules, Loaded, ...) never light up
    local last = sel:match("([^\001]+)$")
    if last == "all" or last == "loaded" or last == "notloaded" or last == "disabled" or last == "smart" or last == "autopop"
        or last == "allbars" or last == "allqol" or last == "allcursor" then return false end
    return sel == prefix
end
local function BannerTint(uv)
    local last = uv and tostring(uv):match("([^\001]*)$")
    if last == "all" or last == "allbars" or last == "allqol" or last == "allcursor" or last == "autopop" then return BANNER_TINT.root end
    if last == "loaded" then return BANNER_TINT.loaded end
    if last == "notloaded" then return BANNER_TINT.notloaded end
    if last == "disabled" then return BANNER_TINT.disabled end
    if last == "smart" then return BANNER_TINT.smart end
    local f = last and ns.FolderById and ns.FolderById(last)
    if f and not f.parent then
        return (type(f.default) == "string" and BANNER_TINT[f.default]) or BANNER_TINT.other
    end
end
-- Row text and selection look (2026-10-31 UI pass). One deterministic style per tier, re-applied on every pass, so rows can no
-- longer drift apart: AceGUI swaps the button's font object (gold normal / white highlight) on select and hover, and the old
-- code captured whichever one it saw first. Tiers: root headers (outlined), top-level categories, sub-categories, rules.
-- Capitals only on ALL RULES, LOADED, NOT LOADED and SMART CATEGORIES.
do
local TREE_TXT = { 0.96, 0.96, 0.98 }     -- unselected rows
local TREE_SEL = { 0.78, 0.62, 1.0 }      -- selected row, "alternate text color" style
ns.TREE_GRAD = { 0.30, 0.08, 0.45 }       -- parent-group gradient: dark purple (left) to black (right)
ns.TREE_BAR = { 0.34, 0.34, 0.40 }
do local TH = ns.Theme   -- style sheet: these tables are filled in place whenever the theme changes
   if TH then TH.Bind("text", TREE_TXT); TH.Bind("accentText", TREE_SEL); TH.Bind("gradStart", ns.TREE_GRAD); TH.Bind("treeBar", ns.TREE_BAR) end end        -- every folder-tree bar (banner edge bar and guide bars) shares this muted color
local ROOT_KEYS = { all = true, allbars = true, allqol = true, allcursor = true, loaded = true, notloaded = true, disabled = true, smart = true, autopop = true }
local UPPER_ROOTS = { all = true, loaded = true, notloaded = true, disabled = true, smart = true }

local function RowTier(button)
    local uv = button.uniquevalue and tostring(button.uniquevalue) or ""
    local lastKey = uv:match("([^\001]+)$") or ""
    local isRoot = ROOT_KEYS[uv] and true or false
    local fld = lastKey:match("^f%d") and ns.FolderById and ns.FolderById(lastKey) or nil
    local isSub = ((fld and fld.parent and true) or lastKey:match("^smart_") ~= nil or (fld and uv:find("\001smart\001", 1, true) ~= nil)) and true or false
    local isCue = (not isRoot) and (not isSub) and BannerTint(uv) ~= nil
    local base = select(2, GameFontNormal:GetFont()) or 12
    local catSize = math.floor(base * 1.15 * 1.2 * 0.85 * 10 + 0.5) / 10
    local subSize = math.floor(base * 1.2 * 0.85 * 10 + 0.5) / 10
    local size, flags = base, ""
    if isRoot then size = math.floor(catSize * 1.15 * 10 + 0.5) / 10; flags = "OUTLINE"
    elseif isCue then size = catSize
    elseif isSub then size = subSize end
    return { uv = uv, isRoot = isRoot, isCue = isCue, isSub = isSub, catSize = catSize, subSize = subSize, size = size, flags = flags }
end

function ns.PaintRowText(button)
    local fs = button.text
    if not (fs and fs.SetFont) then return end
    local t = RowTier(button)
    do
        local TH = ns.Theme
        local fp = TH and TH.FontPath()
        if fp and pcall(fs.SetFont, fs, fp, TH.Size(t.size), t.flags) then else fs:SetFont((GameFontNormal:GetFont()), TH and TH.Size(t.size) or t.size, t.flags) end
    end
    local sel = ns.SelectedUV(button)
    local col = (sel ~= nil and sel == t.uv and ns.SelStyle() == "text") and TREE_SEL or TREE_TXT
    fs:SetTextColor(col[1], col[2], col[3], 1)
    fs:SetAlpha(1)
    if t.isRoot and UPPER_ROOTS[t.uv] then
        local text = fs:GetText() or ""
        local up = text:upper()
        if up ~= text then fs:SetText(up) end
    end
    return t
end

-- hover swaps the button's font object (and with it the color) outside our passes: repaint right after
function ns.HookRowHover(button)
    if button.xuiTxtHook then return end
    button.xuiTxtHook = true
    local function again(self)
        if not (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]) or not self.xuiFontDone then return end
        ns.PaintRowText(self)
        C_Timer.After(0, function() if self.xuiFontDone then ns.PaintRowText(self) end end)
    end
    button:HookScript("OnEnter", again)
    button:HookScript("OnLeave", again)
end
end   -- do (row text helpers)

local function PaintBanner(button)
    local c = BannerTint(button.uniquevalue)
    local t = ns.PaintRowText(button)
    if t then
        button.xuiFontDone = true
        ns.HookRowHover(button)
        if not button.xuiH0 then button.xuiH0 = button:GetHeight() end
        local want = button.xuiH0
        if t.isRoot then want = math.max(button.xuiH0, math.floor(t.catSize * 1.15 + 8))
        elseif t.isCue then want = math.max(button.xuiH0, math.floor(t.catSize + 8))
        elseif t.isSub then want = math.max(button.xuiH0, math.floor(t.subSize + 8)) end
        if math.abs(button:GetHeight() - want) > 0.5 then button:SetHeight(want) end
        for _, seg in ipairs(button.xuiSC and button.xuiSC.segs or {}) do seg:Hide() end
    end
    -- selected row, "highlighted bar" style: purple fading to black toward the right. Never on mouse-over.
    do
        local su = ns.SelectedUV(button)
        local mine = su ~= nil and su == (button.uniquevalue and tostring(button.uniquevalue) or "")
        if mine and ns.SelStyle() == "bar" then
            if not button.xuiSelTex then
                button.xuiSelTex = button:CreateTexture(nil, "BACKGROUND", nil, 0)
                button.xuiSelTex:SetAllPoints()
            end
            local st = button.xuiSelTex
            st:SetColorTexture(0.75, 0.25, 1, 0.6)
            pcall(st.SetGradient, st, "HORIZONTAL", CreateColor(0.75, 0.25, 1, 0.6), CreateColor(0, 0, 0, 0.15))
            st:Show()
        elseif button.xuiSelTex then
            button.xuiSelTex:Hide()
        end
    end
    -- blank divider row between All Rules and the Loaded / Not Loaded filters: a thin line, no text
    local isSpacer = button.uniquevalue and (tostring(button.uniquevalue):match("([^\001]+)$") or ""):match("^spacer") ~= nil
    -- the two spacer rows around NOT LOADED keep their height but draw no line (Xaya, 2026-11-02)
    local spKey = button.uniquevalue and (tostring(button.uniquevalue):match("([^\001]+)$") or "") or ""
    if spKey == "spacer" or spKey == "spacer1" then isSpacer = false end
    if isSpacer then
        if not button.xuiDivider then
            button.xuiDivider = button:CreateTexture(nil, "ARTWORK")
            button.xuiDivider:SetHeight(1)
            button.xuiDivider:SetColorTexture(0.6, 0.6, 0.65, 0.45)
        end
        button.xuiDivider:ClearAllPoints()
        button.xuiDivider:SetPoint("LEFT", button, "LEFT", 6, 0)
        button.xuiDivider:SetPoint("RIGHT", button, "RIGHT", -6, 0)
        button.xuiDivider:Show()
    elseif button.xuiDivider then
        button.xuiDivider:Hide()
    end
    -- parent-group gradient: when the selection is nested (root > group > ... > item), only the TOPMOST group of the chain
    -- (the row right under the root) gets a dark purple to black left-to-right gradient. Settings > Display Options turns it off.
    local uvStr = button.uniquevalue and tostring(button.uniquevalue) or ""
    local selUV = ns.SelectedUV(button)
    local nestTop = false
    if selUV and ns.ParentGradientOn() then
        local s1, s2, s3 = selUV:match("^([^\001]+)\001([^\001]+)\001([^\001]+)")
        if s3 and uvStr == (s1 .. "\001" .. s2) then nestTop = true end
    end
    if not c and not nestTop then
        if button.xuiBanner then button.xuiBanner:Hide(); button.xuiBannerBar:Hide() end
        return
    end
    if not button.xuiBanner then
        button.xuiBanner = button:CreateTexture(nil, "BACKGROUND", nil, -2)
        button.xuiBanner:SetAllPoints()
        button.xuiBannerBar = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        button.xuiBannerBar:SetPoint("TOPLEFT"); button.xuiBannerBar:SetPoint("BOTTOMLEFT"); button.xuiBannerBar:SetWidth(6)
    end
    local b, bar = button.xuiBanner, button.xuiBannerBar
    if nestTop then
        local g = ns.TREE_GRAD
        b:SetColorTexture(g[1], g[2], g[3], 0.95)
        pcall(b.SetGradient, b, "HORIZONTAL", CreateColor(g[1], g[2], g[3], 0.95), CreateColor(0, 0, 0, 0.95))
    else
        local col = ns.NEUTRAL_TINT   -- selection is drawn by xuiSelTex / the text color, not by this banner
        local ba = 0.45
        b:SetColorTexture(col[1], col[2], col[3], 0.5 * ba)
        pcall(b.SetGradient, b, "HORIZONTAL", CreateColor(col[1], col[2], col[3], 0.85 * ba), CreateColor(col[1], col[2], col[3], 0.2 * ba))
    end
    bar:Hide()   -- the old edge bar clipped outside the sidebar; folder-tree bars are drawn under the +/- toggles (PaintGuides)
    b:Show()
end

-- Tree-chart guide bars: every row inside a top-level folder repeats that folder's color as a vertical bar at the
-- left edge (a continuation of the folder's own banner bar), and each deeper folder level adds one more, lighter
-- and thinner bar, indented one step. Rows directly under the Loaded / Not Loaded roots continue that root's color.
local function PaintGuides(button)
    local guides = button.xuiGuides
    local bars = {}
    local uv = button.uniquevalue and tostring(button.uniquevalue) or nil
    local tb = ns.TREE_BAR   -- one muted color for every bar
    if uv then
        -- ONE bar only, for the grandparent group of the selected item (e.g. Defensives for a rule inside HUD),
        -- drawn on the rows inside that group. No selection or a shallow selection = no bars.
        local segs = {}
        for seg in uv:gmatch("[^\001]+") do segs[#segs + 1] = seg end
        local sel = ns.TREE_BARS_ENABLED and ns.SelectedUV(button) or nil   -- vertical tree bars are switched off (set ns.TREE_BARS_ENABLED = true to bring them back)
        if sel then
            local ss = {}
            for seg in sel:gmatch("[^\001]+") do ss[#ss + 1] = seg end
            local g = #ss - 2
            if g >= 1 and #segs > g then
                local same = true
                for i = 1, g do if segs[i] ~= ss[i] then same = false; break end end
                if same then
                    local isAll, smart = (segs[1] == "all" or segs[1] == "loaded" or segs[1] == "notloaded" or segs[1] == "disabled"), false
                    for i = 1, g do if segs[i]:find("^smart") then smart = true end end
                    local shift = (isAll and g >= 2 and not smart) and ((ns.REORDER_W or 0) + 11) or 0
                    bars[#bars + 1] = { x = 8 * g - 6 + shift + 7, w = 2, r = tb[1], g = tb[2], b = tb[3], a = 1 }
                end
            end
        end
    end
    if #bars == 0 and not guides then return end
    guides = guides or {}
    button.xuiGuides = guides
    for i, bar in ipairs(bars) do
        local t = guides[i]
        if not t then
            t = button:CreateTexture(nil, "BACKGROUND", nil, -1)
            guides[i] = t
        end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", button, "TOPLEFT", bar.x, 0)
        t:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", bar.x, 0)
        t:SetWidth(bar.w)
        t:SetColorTexture(bar.r, bar.g, bar.b, bar.a)
        t:Show()
    end
    for i = #bars + 1, #guides do guides[i]:Hide() end
end

-- Right-hand pair on rule / folder rows: [movement lock] [edit lock]
function ns.MakeSideToggle(button, kind)
    local b = CreateFrame("Button", nil, button)
    b:SetSize(15, 15)
    b:SetFrameLevel(button:GetFrameLevel() + 3)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.kind = kind
    if kind == "edit" then
        b.tex:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
        b.slash = b:CreateTexture(nil, "OVERLAY")
        b.slash:SetColorTexture(1, 0.15, 0.15, 1)
        b.slash:SetSize(20, 2)
        b.slash:SetPoint("CENTER")
        b.slash:SetRotation(math.rad(45))
    end
    b:SetScript("OnClick", function(self)
        if self.kind == "move" and self.xuiMoveFolder then
            ns.SetGroupUnlocked(self.xuiMoveFolder, not self.xuiOn)   -- a group row moves the GROUP (one outline), not each display
        elseif self.kind == "move" then
            ns.SetMoveUnlocked(self.xuiObjs, not self.xuiOn)
        elseif self.xuiFolder then
            local f = self.xuiFolder
            f.editLocked = (not f.editLocked) or nil
        else
            for _, r in ipairs(self.xuiObjs or {}) do r.editLocked = (not self.xuiOn) or nil end
        end
        ns.MarkDirty()
        if ns.DecorateTrees then ns.DecorateTrees() end
        Notify()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.kind == "move" then
            GameTooltip:SetText(self.xuiOn and "Movement unlocked" or "Movement locked")
            if self.xuiMoveFolder then
                GameTooltip:AddLine(self.xuiOn and "Drag the orange outline on screen to move the whole group. Click to lock it again." or "Click to show one outline around this group so you can drag the whole group.", 1, 1, 1, true)
            else
                GameTooltip:AddLine(self.xuiOn and "Drag the displays on screen. Click to lock them again." or "Click to unlock this row's on-screen displays so you can drag them.", 1, 1, 1, true)
            end
        else
            GameTooltip:SetText(self.xuiOn and "Edits blocked" or "Editable")
            GameTooltip:AddLine(self.xuiOn and "Settings here are read-only. Click to allow edits again." or "Click to block edits: settings here become read-only.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

function ns.PaintSide(button, rules, vis, folder)
    local showEdit = folder ~= nil or #rules > 0
    local showMove = vis and #vis > 0
    local off = 4
    if showEdit then
        if not button.xuiEdit then button.xuiEdit = ns.MakeSideToggle(button, "edit") end
        local b = button.xuiEdit
        local locked
        if folder then locked = folder.editLocked and true or false
        else
            locked = true
            for _, r in ipairs(rules) do if not r.editLocked then locked = false; break end end
        end
        b.xuiOn, b.xuiObjs, b.xuiFolder = locked, rules, folder
        b.slash:SetShown(locked)
        b.tex:SetDesaturated(locked)
        b.tex:SetAlpha(locked and 0.7 or 1)
        b:ClearAllPoints(); b:SetPoint("RIGHT", button, "RIGHT", -off, button.xuiTwoRow and -9 or 0)
        b:Show()
        off = off + 19
    elseif button.xuiEdit then button.xuiEdit:Hide() end
    if showMove then
        if not button.xuiMove then button.xuiMove = ns.MakeSideToggle(button, "move") end
        local b = button.xuiMove
        local n = 0
        for _, r in ipairs(vis) do if ns.IsMoveUnlocked(r) then n = n + 1 end end
        b.xuiOn, b.xuiObjs = (n == #vis), vis
        b.xuiMoveFolder = folder
        if folder and ns.IsGroupUnlocked then n = ns.IsGroupUnlocked(folder) and #vis or 0; b.xuiOn = (n == #vis) end
        b.tex:SetTexture(n == 0 and "Interface\\PetBattles\\PetBattle-LockIcon" or "Interface\\CURSOR\\UI-Cursor-Move")
        b.tex:SetAlpha(n == 0 and 0.85 or (n == #vis and 1 or 0.6))
        b:ClearAllPoints(); b:SetPoint("RIGHT", button, "RIGHT", -off, button.xuiTwoRow and -9 or 0)
        b:Show()
        off = off + 19
    elseif button.xuiMove then button.xuiMove:Hide() end
    if button.text then button.text:SetPoint("RIGHT", button, "RIGHT", -math.max(off, button.xuiIconR or 0), 2) end
end

local ROW_TOGGLES = {
    allqol = { title = "Stat Tracking on / off",
        tip = "Unticked: every stats box is hidden on screen and nothing is listed here. Your boxes are kept.",
        get = function() return ns.QoLOn() end,
        set = function(v) CueRulesDB.qol = CueRulesDB.qol or {}; CueRulesDB.qol.enabled = v; pcall(ns.QoL_RefreshAll) end },
    allcursor = { title = "Cursor Tracker on / off",
        tip = "Ticked: a texture follows your mouse cursor (off by default). Your settings are kept when unticked.",
        get = function() return ns.CursorOn() end,
        set = function(v) CueRulesDB.cursor = CueRulesDB.cursor or {}; CueRulesDB.cursor.enabled = v; if ns.Cursor_Apply then ns.Cursor_Apply() end end },
    ["allcursor\001reminders"] = { title = "At-Cursor Reminders on / off",
        tip = "Ticked: the spell icons of your rules' displays are shown next to the mouse cursor (which rules: see this pane). Off by default; your choices are kept when unticked.",
        get = function() return CueRulesDB.cursor and CueRulesDB.cursor.remOn and true or false end,
        set = function(v) CueRulesDB.cursor = CueRulesDB.cursor or {}; CueRulesDB.cursor.remOn = v; if ns.CursorReminders_Apply then ns.CursorReminders_Apply() end end },
    allbars = { title = "Buff Bars on / off",
        tip = "Unticked: every buff bar is hidden on screen and nothing is listed here. Your bars are kept.",
        get = function() return ns.BarsOn() end,
        set = function(v) CueRulesDB.barGroup.enabled = v; pcall(ns.Bars_RefreshAll) end },
}

-- Left cluster, in order:  [collapse arrow] [eye] [headphone]  text
-- Multi-select delete: Ctrl+click toggles a rule row, Shift+click selects the visible rule rows between the last clicked row and
-- this one (either direction). Selected rows get a purple wash in every list they appear in. "Delete N selected" (bottom-left of the window) deletes them
-- after a confirmation. A plain click on any row, or "Clear selection", drops the selection.
do
    local sel, anchor = {}, nil   -- sel[rule] = true
    local function RuleOfButton(button)
        local last = tostring(button.uniquevalue or ""):match("([^\001]+)$") or ""
        local n = tonumber(last:match("^rule(%d+)$"))
        return n and ns.rules and ns.rules[n]
    end
    function ns.MultiCount() local n = 0; for _ in pairs(sel) do n = n + 1 end; return n end
    function ns.MultiReset() wipe(sel); anchor = nil end
    function ns.MultiHas(rule) return sel[rule] and true or false end
    -- move every selected rule into group fid (nil = top level)
    function ns.MultiMove(fid)
        local fo = fid and FolderById(fid)
        if fo and ns.IsCategoryRoot(fo) then ns.Print("rules cannot be placed into a Smart Category"); return end
        local n = 0
        for r in pairs(sel) do
            if r.folder ~= fid then r.folder = fid; n = n + 1 end
            -- outcomes embedded in a rule follow their parent's group (same rule as the single-rule move)
        end
        local keep = {}
        for r in pairs(sel) do keep[#keep + 1] = r end
        ns.MultiReset()
        ns.MarkDirty(); Notify()
        if ns.DecorateTrees then ns.DecorateTrees() end
        local g = fid and FolderById(fid)
        ns.Print(("moved %d rule(s) to %s"):format(#keep, g and tostring(g.name) or "the top level"))
    end
    -- "Move to..." menu for the selection bar
    function ns.MultiMoveMenu(owner)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        pcall(MenuUtil.CreateContextMenu, MenuOwner(owner), function(_, root)
            if root.AddMenuAcquiredCallback then
                root:AddMenuAcquiredCallback(function(menu)
                    if menu and menu.SetFrameStrata then pcall(menu.SetFrameStrata, menu, "TOOLTIP"); if menu.Raise then pcall(menu.Raise, menu) end end
                end)
            end
            root:CreateTitle("Move " .. ns.MultiCount() .. " selected rule(s) to")
            root:CreateButton("Top Level (no group)", function() ns.MultiMove(nil) end)
            local _, fOrder = FolderValues()
            for _, fid in ipairs(fOrder) do
                local f = fid ~= "none" and FolderById(fid)
                if f then
                    local depth = 0
                    for _, c in ipairs(FolderChain(f)) do if not ns.CueTransparent(c) then depth = depth + 1 end end
                    root:CreateButton(string.rep("    ", depth - 1) .. tostring(f.name), function() ns.MultiMove(f.id) end)
                end
            end
        end)
    end
    function ns.MultiClear() ns.MultiReset(); if ns.DecorateTrees then ns.DecorateTrees() end end
    function ns.MultiClick(button, mouse)
        if mouse ~= "LeftButton" then return end
        local ctrl, shift = IsControlKeyDown(), IsShiftKeyDown()
        local rule = RuleOfButton(button)
        if not (ctrl or shift) then
            -- a plain click drops the selection and becomes the start point for the next Shift+click (the row still opens as usual)
            if next(sel) then wipe(sel); if ns.DecorateTrees then ns.DecorateTrees() end end
            if rule then anchor = rule end
            return
        end
        if not rule then return end
        if shift and anchor and anchor ~= rule and button.obj and button.obj.buttons then
            -- range from the start point to this row, either direction; if the start rule is listed twice, take the nearer row
            local btns, hits, target = button.obj.buttons, {}, nil
            for i, b in ipairs(btns) do
                if b:IsShown() then
                    if RuleOfButton(b) == anchor then hits[#hits + 1] = i end
                    if b == button then target = i end
                end
            end
            if target and #hits > 0 then
                local from = hits[1]
                for _, i in ipairs(hits) do if math.abs(i - target) < math.abs(from - target) then from = i end end
                for i = math.min(from, target), math.max(from, target) do
                    local b = btns[i]
                    local r = b:IsShown() and RuleOfButton(b)
                    if r then sel[r] = true end
                end
                if ns.DecorateTrees then ns.DecorateTrees() end
                return
            end
        end
        sel[rule] = (not sel[rule]) or nil
        anchor = rule
        if ns.DecorateTrees then ns.DecorateTrees() end
    end
    function ns.MultiPaint(button)
        local rule = RuleOfButton(button)
        local on = rule and sel[rule]
        if on and not button.xuiMultiTex then
            button.xuiMultiTex = button:CreateTexture(nil, "BACKGROUND", nil, 1)
            button.xuiMultiTex:SetAllPoints()
            button.xuiMultiTex:SetColorTexture(0.75, 0.25, 1, 0.38)
        end
        if button.xuiMultiTex then button.xuiMultiTex:SetShown(on and true or false) end
    end
    function ns.MultiDelete()
        local list = {}
        for r in pairs(sel) do list[#list + 1] = r end
        if #list == 0 then return end
        StaticPopup_Show("XAYAUI_CONFIRM", ("Delete %d selected rule(s)? This cannot be undone."):format(#list), nil, { cb = function()
            for _, rule in ipairs(list) do
                if ns.DeleteOutcomesOf then pcall(ns.DeleteOutcomesOf, rule) end
                for idx, r in ipairs(ns.rules) do if r == rule then table.remove(ns.rules, idx); break end end
                pcall(ns.DropVisual, rule)
            end
            ns.MultiReset()
            ns.MarkDirty(); Notify(); SelectRoot()
        end })
    end
end

-- Rename a rule right in the sidebar: a text box over the row's name (double-click the row, or it opens by itself for a new rule).
function ns.SidebarRename(button)
    local rn = tostring(button.uniquevalue or ""):match("rule(%d+)$")
    local rule = rn and ns.rules and ns.rules[tonumber(rn)]
    local isFolder
    if not rule then   -- a group row: same box, renames the folder (an empty name keeps the old one)
        local fk = (LastKey(button.uniquevalue) or ""):match("^f%d") and LastKey(button.uniquevalue)
        rule = fk and FolderById(fk)
        isFolder = rule and true or nil
    end
    if not rule or (not isFolder and ns.IsEditLocked and ns.IsEditLocked(rule)) then return end
    local eb = button.xuiRenameEB
    if not eb then
        eb = CreateFrame("EditBox", nil, button)
        eb:SetAutoFocus(false); eb:SetHeight(22); eb:SetMaxLetters(60); eb:SetTextInsets(6, 6, 0, 0)
        eb:SetFontObject(GameFontHighlight)
        eb.bg = eb:CreateTexture(nil, "BACKGROUND"); eb.bg:SetAllPoints(); eb.bg:SetColorTexture(0, 0, 0, 1)
        eb.ln = eb:CreateTexture(nil, "ARTWORK"); eb.ln:SetHeight(1); eb.ln:SetPoint("BOTTOMLEFT"); eb.ln:SetPoint("BOTTOMRIGHT"); eb.ln:SetColorTexture(0.75, 0.25, 1, 1)
        eb:SetScript("OnEscapePressed", function(self) self.xuiCancel = true; self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEditFocusLost", function(self)
            local r = self.xuiRule
            self:Hide()
            if self.xuiCancel then self.xuiCancel = nil; return end
            if r then
                local t = tostring(self:GetText() or ""):sub(1, 60)
                if self.xuiIsFolder then
                    if t == "" then return end
                    r.name = t
                    ns.MarkDirty(); Notify()
                else
                    r.name = t
                    pcall(ns.RefreshVisual, r); ns.MarkDirty(); Notify()
                end
            end
        end)
        button.xuiRenameEB = eb
    end
    eb.xuiRule = rule; eb.xuiIsFolder = isFolder
    eb:SetFrameLevel(button:GetFrameLevel() + 8)
    eb:ClearAllPoints()
    local left = button.text and button.text:GetLeft() and button:GetLeft() and (button.text:GetLeft() - button:GetLeft() - 6) or 40
    eb:SetPoint("LEFT", button, "LEFT", math.max(4, left), 0)
    eb:SetPoint("RIGHT", button, "RIGHT", -52, 0)
    eb:SetText(tostring(rule.name or ""))
    eb:Show(); eb:SetFocus(); eb:HighlightText()
end

-- Called from the right-click menu: the menu closes after the click and takes keyboard focus with it, so the box opens a moment later.
function ns.SidebarRenameLater(button)
    if not (button and button.IsShown and button:IsShown() and C_Timer) then return false end
    C_Timer.After(0.1, function() if button:IsShown() then ns.SidebarRename(button) end end)
    return true
end

local function DecorateButton(button)
    PaintBanner(button)
    PaintGuides(button)
    ns.MultiPaint(button)
    local vis, snd = Resolve(button.uniquevalue)
    local rawObjs = vis
    -- cue kinds: the eye only covers rules that have a display, the headphone only rules that have a sound
    local function only(list, what)
        if not list then return list end
        local o = {}
        for _, x in ipairs(list) do if ns.KindHas(x, what) then o[#o + 1] = x end end
        return o
    end
    vis, snd = only(vis, "visual"), only(snd, "sound")
    local tree = button.obj
    local suv = tostring(button.uniquevalue or "")
    local inSC = (suv == "all" or suv:sub(1, 4) == "all\001")
    if inSC and (suv == "all" or suv == "all\001smart") then
        -- Smart Categories: the tab is the root, so its own row and the "by type" row are drawn as nothing
        button.xuiGone = true
        button:SetHeight(0.01); button:SetAlpha(0); button:EnableMouse(false)
        for _, k in ipairs({ "xuiChev", "xuiEye", "xuiHead", "xuiEdit", "xuiUp", "xuiDown", "xuiMove", "xuiBanner", "xuiBannerBar", "xuiSelTex", "xuiDivider", "xuiType", "xuiType2", "xuiSub", "xuiStatCheck" }) do
            if button[k] and button[k].Hide then button[k]:Hide() end
        end
        return
    end
    if button.xuiGone then
        button.xuiGone = nil
        button:SetHeight(18); button:SetAlpha(1); button:EnableMouse(true)
    end
    if button.obj and not (button.obj.treeframe and button.obj.treeframe.xuiBlankHook) then pcall(ns.HookSidebarBlank, button.obj) end
    if not button.xuiDrag then
        button.xuiDrag = true
        button:RegisterForDrag("LeftButton")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:HookScript("OnClick", function(self, mouse) ns.Trace("click"); if mouse == "RightButton" then ShowRowMenu(self) else ns.MultiClick(self, mouse) end end)
        button:HookScript("OnDragStart", StartDrag)
        button:HookScript("OnDragStop", StopDrag)
    end
    if not button.xuiDblHooked then
        button.xuiDblHooked = true
        button:HookScript("OnDoubleClick", function(self) if ns.SidebarRename then ns.SidebarRename(self) end end)
    end
    if button.xuiRenameEB and button.xuiRenameEB:IsShown() and not button.xuiRenameEB:HasFocus() then button.xuiRenameEB:Hide() end
    do   -- a rule that was just created (no name yet) opens its name box in the sidebar
        local pr = ns.pendingRename
        local rnum = tostring(button.uniquevalue or ""):match("rule(%d+)$")
        if pr and rnum and ns.rules[tonumber(rnum)] == pr and C_Timer then
            ns.pendingRename = nil
            C_Timer.After(0.15, function() if button:IsShown() and ns.SidebarRename then ns.SidebarRename(button) end end)
        end
    end
    local level = (button.level or 1) - (inSC and 2 or 0)
    if level < 1 then level = 1 end
    local canExpand = button.toggle and button.toggle:IsShown() and true or false
    local hasIcons = (vis and #vis > 0) or (snd and #snd > 0)
    -- top-level roots (All Rules / Loaded / Not Loaded) carry no eye or headphone; their lock icons stay
    do
        local rootKey = tostring(button.uniquevalue or ""):match("([^\001]+)$")
        if rootKey == "all" or rootKey == "loaded" or rootKey == "notloaded" or rootKey == "disabled" or rootKey == "smart" then hasIcons = false end
    end
    if button.text then
        button.text:SetWordWrap(false)
        button.text:SetPoint("RIGHT", button, "RIGHT", -4, 2)
    end
    -- Every row of a level uses the same fixed slots: [arrow 16][eye 17][headphone 17][text]. A row without an arrow or
    -- without icons keeps its (empty) slots, so the text of all rows on one level lines up. Blizzard's tiny +/- is hidden
    -- (still "shown", so canExpand stays readable) because our arrow replaces it on every expandable row.
    local CHEV_W, ICON_W = 16, 17
    -- left gutter (4px wider than before). Root headers and first-level groups start at the same x (flush with the sidebar wall);
    -- each deeper level steps in by 8px as before.
    local x0 = (level <= 1) and 6 or (8 * level - 9)
    ns.PaintReorder(button, level, x0)
    if button.xuiReorderOn then x0 = x0 + ns.REORDER_W + 11 end   -- chevron and text sit right of the arrows
    if button.toggle then
        button.toggle:SetAlpha(canExpand and 0 or 1)
        button.toggle:EnableMouse(not canExpand)
    end
    local tw = ns.PaintTypeIcon and ns.PaintTypeIcon(button, x0) or 0   -- icon at the left of the row (0 = none)
    button.xuiTwoRow = (tw > 0 and not (ns.CondensedOn and ns.CondensedOn())) and true or false
    local rk0 = tostring(button.uniquevalue or ""):match("([^\001]+)$") or ""
    local isRootRow = (rk0 == "all" or rk0 == "loaded" or rk0 == "notloaded" or rk0 == "disabled" or rk0 == "smart" or (inSC and rk0:match("^smart_") ~= nil))
    local chevMode = "left"
    if canExpand then
        if not button.xuiChev then button.xuiChev = MakeChevron(button) end
        local st = tree and (tree.status or tree.localstatus)
        local expanded = st and st.groups and st.groups[button.uniquevalue]
        button.xuiChev:SetNormalTexture(expanded and 130821 or 130838)
        button.xuiChev:SetPushedTexture(expanded and 130820 or 130836)
        button.xuiChev:ClearAllPoints()
        if isRootRow then          -- root headers: round toggle at the right end
            chevMode = "right"
            button.xuiChev:SetSize(16, 16)
            button.xuiChev:SetPoint("RIGHT", button, "RIGHT", -(4 + 19 * 2 + 4), 0)
        elseif tw > 0 then         -- groups: toggle sits under the group's icon
            chevMode = "icon"
            button.xuiChev:SetSize(14, 14)
            button.xuiChev:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", x0 - 2, 0)
        else
            button.xuiChev:SetSize(16, 16)
            button.xuiChev:SetPoint("LEFT", button, "LEFT", x0, 0)
        end
        button.xuiChev:SetFrameLevel(button:GetFrameLevel() + 4)
        button.xuiChev:Show()
    elseif button.xuiChev then
        button.xuiChev:Hide()
    end
    -- QoL rows (Stat Tracking, Buff Bars): a left-aligned tick box is the on/off switch for the whole element
    local toggleCfg = ROW_TOGGLES[tostring(button.uniquevalue or "")]
    if toggleCfg then
        if not button.xuiStatCheck then
            local cb = CreateFrame("CheckButton", nil, button, "UICheckButtonTemplate")
            cb:SetSize(22, 22)
            cb:SetFrameLevel(button:GetFrameLevel() + 3)
            cb:SetScript("OnClick", function(self)
                local cfg = ROW_TOGGLES[tostring(button.uniquevalue or "")]
                if not cfg then return end
                cfg.set(self:GetChecked() and true or false)
                ns.MarkDirty(); Notify()
            end)
            cb:SetScript("OnEnter", function(self)
                local cfg = ROW_TOGGLES[tostring(button.uniquevalue or "")]
                if not cfg then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(cfg.title)
                GameTooltip:AddLine(cfg.tip, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
            button.xuiStatCheck = cb
        end
        local cb = button.xuiStatCheck
        cb:ClearAllPoints()
        cb:SetPoint("LEFT", button, "LEFT", x0 + CHEV_W + 4, 0)
        cb:SetChecked(toggleCfg.get())
        cb:Show()
    elseif button.xuiStatCheck then
        button.xuiStatCheck:Hide()
    end
    button.xuiIconR = 0
    if hasIcons then
        if not button.xuiEye then
            button.xuiEye = MakeToggle(button, "visual")
            button.xuiHead = MakeToggle(button, "sound")
        end
        local function paint(b, objs, kind, sx)
            if not objs or #objs == 0 then b:Hide(); return end
            b.objs = objs
            b:ClearAllPoints()
            if button.xuiTwoRow then b:SetPoint("RIGHT", button, "RIGHT", -4, 9)   -- first row: the preview button at the right edge
            else b:SetPoint("RIGHT", button, "RIGHT", -sx, 0) end
            local st = GroupState(objs, kind)
            b.tex:SetDesaturated(st == 0)
            b.tex:SetAlpha(st == 1 and 1 or (st == 0.5 and 0.7 or 0.35))
            b:Show()
        end
        if button.xuiTwoRow then
            -- two rows: [preview] on top; [movement lock][edit lock] below it. The separate audio preview is gone;
            -- a rule that only plays a sound (no display) keeps one preview button, in the same place.
            paint(button.xuiEye, vis, "visual", 4 + 19 * 3)
            if vis and #vis > 0 then button.xuiHead:Hide() else paint(button.xuiHead, snd, "sound", 4 + 19 * 3) end
            button.xuiIconR = 4 + 17 + 3
        else
            -- eye and headphone live in fixed columns on the RIGHT, just left of the movement / edit locks
            paint(button.xuiEye, vis, "visual", 4 + 19 * 3)
            paint(button.xuiHead, snd, "sound", 4 + 19 * 2)
            button.xuiIconR = (vis and #vis > 0) and (4 + 19 * 3 + ICON_W + 3) or ((snd and #snd > 0) and (4 + 19 * 2 + ICON_W + 3) or 0)
        end
    elseif button.xuiEye then
        button.xuiEye:Hide(); button.xuiHead:Hide()
    end
    do
        local rk = tostring(button.uniquevalue or ""):match("([^\001]+)$")
        local iconSlots = toggleCfg and 26 or 0   -- only the on / off tick box sits left of the label now
        local lead = (tw > 0) and tw or ((chevMode == "right") and 0 or CHEV_W)   -- icon column, or the left chevron slot
        if tw > 0 then
            local h = math.max(button:GetHeight() or 0, ns.TYPE_ICON_SIDEBAR_H + 6)
            if math.abs((button:GetHeight() or 0) - h) > 0.5 then button:SetHeight(h) end
        end
        -- Smart Categories: a small note under the rule's name says which of the regular groups it is in
        local note
        local rn = inSC and rk:match("^rule(%d+)$")
        if rn then
            local rr = ns.rules and ns.rules[tonumber(rn)]
            local ff = rr and rr.folder and ns.FolderById(rr.folder)
            if ff then
                local names = {}
                for _, c in ipairs(FolderChain(ff)) do if not ns.CueTransparent(c) then names[#names + 1] = tostring(c.name) end end
                note = (#names > 0) and table.concat(names, " / ") or "Top level"
            elseif rr then note = "Top level" end
        end
        if button.text then button.text:SetPoint("LEFT", button, "LEFT", x0 + lead + iconSlots + 3, note and 8 or 2) end
        if note then
            if not button.xuiSub then
                button.xuiSub = button:CreateFontString(nil, "OVERLAY")
                button.xuiSub:SetFont((GameFontNormal:GetFont()), 10, "")
                button.xuiSub:SetJustifyH("LEFT"); button.xuiSub:SetWordWrap(false)
                button.xuiSub:SetTextColor(0.6, 0.6, 0.65)
            end
            local sf = button.xuiSub
            sf:SetText("in " .. note)
            sf:ClearAllPoints()
            sf:SetPoint("TOPLEFT", button.text, "BOTTOMLEFT", 0, -1)
            sf:SetPoint("RIGHT", button, "RIGHT", -((button.xuiIconR or 0) + 8), 0)
            sf:Show()
            if (button:GetHeight() or 0) < 30 then button:SetHeight(30); button.xuiNoteH = true end
        else
            if button.xuiSub then button.xuiSub:Hide() end
            if button.xuiNoteH and tw == 0 then button:SetHeight(18) end
            button.xuiNoteH = nil
        end
    end
    -- right side: movement lock + edit lock (rule, folder and all-rules rows only)
    do
        local rules = {}
        for _, o in ipairs(rawObjs or {}) do if o.visual then rules[#rules + 1] = o end end
        local lastKey = tostring(button.uniquevalue or ""):match("([^\001]+)$") or ""
        local folder = lastKey:match("^f%d") and ns.FolderById(lastKey) or nil
        local vr = {}
        for _, o in ipairs(vis or {}) do if o.visual then vr[#vr + 1] = o end end
        ns.PaintSide(button, rules, vr, folder)
    end
end

-- A decoration error must never abort AceGUI's tree layout (that blanks the whole window). Errors are kept, printed once per kind.
function ns.SafeDecorate(b)
    local ok, err = pcall(DecorateButton, b)
    if not ok then
        ns.lastTreeErr = tostring(err)
        if not ns.treeErrShown or ns.treeErrShown ~= ns.lastTreeErr then
            ns.treeErrShown = ns.lastTreeErr
            ns.Print("sidebar decoration error (please report): " .. ns.lastTreeErr)
        end
    end
end

local function DecorateTree(tree)
    if not tree.xuiHooked then
        tree.xuiHooked = true
        local orig = tree.RefreshTree
        tree.RefreshTree = function(self, ...)
            orig(self, ...)
            for _, b in ipairs(self.buttons or {}) do if b:IsShown() then ns.SafeDecorate(b) end end
        end
        local status = tree.status or tree.localstatus
        if status and not status.xuiWide then
            status.xuiWide = true
            if (status.treewidth or 0) <= 175 then pcall(tree.SetTreeWidth, tree, 270, true) end
        end
    end
    for _, b in ipairs(tree.buttons or {}) do
        if b:IsShown() then ns.SafeDecorate(b)
        else
            if b.xuiEye then b.xuiEye:Hide(); b.xuiHead:Hide() end
            if b.xuiEdit then b.xuiEdit:Hide() end
            if b.xuiUp then b.xuiUp:Hide(); b.xuiDown:Hide() end
            if b.xuiMove then b.xuiMove:Hide() end
            if b.xuiBanner then b.xuiBanner:Hide(); b.xuiBannerBar:Hide() end
            if b.xuiSelTex then b.xuiSelTex:Hide() end
            if b.xuiDivider then b.xuiDivider:Hide() end
        end
    end
end

-- Full Blizzard spell tooltip on the talent icon (an AceGUI Icon whose option carries arg.xuiSpell = the talent row).
-- AceGUI clears callbacks when a widget is recycled, so this re-checks on every pass instead of flagging the widget.
-------------------------------------------------------------------------------
-- Spell-name search: the game has no "search spells by name" call, so the first time a search box is used the addon
-- walks spell IDs 1..SI_MAX in small time slices (about 4 ms per frame) and remembers every ID that has a name.
-- The list stays in memory until /reload. Spellbook spells are listed first.
-------------------------------------------------------------------------------
local AttachSearch
do
local SI = { names = {}, ids = {}, n = 0, nextId = 1, running = false }
local SI_MAX = 1900000
local SX = {}   -- item-search helpers in one table (this file is close to Lua's 200-locals limit)
local function StartScan(S, max, getn)
    if S.running or S.nextId > max or not getn then return end
    S.running = true
    S.frame = S.frame or CreateFrame("Frame")
    S.frame:SetScript("OnUpdate", function(self)
        local ok = pcall(function()
            local t0 = debugprofilestop()
            while S.nextId <= max and debugprofilestop() - t0 < 4 do
                local last = math.min(S.nextId + 499, max)
                for id = S.nextId, last do
                    local nm = getn(id)
                    if nm and nm ~= "" then local n = S.n + 1; S.n = n; S.names[n] = nm:lower(); S.ids[n] = id end
                end
                S.nextId = last + 1
            end
        end)
        if not ok or S.nextId > max then S.running = false; self:SetScript("OnUpdate", nil) end
    end)
end
-- Item names: the client only knows the names of items it has already loaded (no way to list every item in the game), so this index
-- holds those; the items you carry / wear are added fresh on every search (OwnedItems).
SX.II = { names = {}, ids = {}, n = 0, nextId = 1, running = false }
SX.II_MAX = 300000
function SX.Start(kind)
    if kind == "talent" and not XayaUITalentDB and not SX.scanTried and ns.ScanAllTalents then
        SX.scanTried = true   -- once per session: lists every spec and hero tree of the class, not only the current build
        pcall(ns.ScanAllTalents)
    end
    if kind == "item" then StartScan(SX.II, SX.II_MAX, C_Item and C_Item.GetItemNameByID)
    else StartScan(SI, SI_MAX, C_Spell.GetSpellName) end
    if kind == "aura" and ns.AuraSources then   -- the "source" column needs the item index and a tooltip pass over it (AuraSources.lua)
        StartScan(SX.II, SX.II_MAX, C_Item and C_Item.GetItemNameByID)
        SX.II.max = SX.II_MAX
        local ids = {}
        for _, sp in ipairs(ns.BuildSpellList() or {}) do if sp.id then ids[#ids + 1] = sp.id end end
        pcall(ns.AuraSources.Start, SX.II, ids)
    end
end
function SX.OwnedItems()
    local out, seen = {}, {}
    local function addId(id)
        pcall(function()
            if type(id) == "number" and id > 0 and not seen[id] then
                local nm = C_Item.GetItemNameByID(id)
                if type(nm) == "string" and nm ~= "" then seen[id] = true; out[#out + 1] = { id = id, name = nm } end
            end
        end)
    end
    for slot = 1, 19 do local ok, id = pcall(GetInventoryItemID, "player", slot); if ok then addId(id) end end
    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 12 do
            local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
            if ok and type(n) == "number" then
                for s = 1, n do
                    local ok2, info = pcall(C_Container.GetContainerItemInfo, bag, s)
                    if ok2 and type(info) == "table" then addId(info.itemID) end
                end
            end
        end
    end
    return out
end

-- Class-scoped, typo-tolerant candidates. Sets ("talent", "cd", "aura", "any") hold every spell of the player's class that fits the kind:
-- the current build's talents + the last /xui talents scan (all specs and hero trees) + the class data (cooldowns, buffs, procs, debuffs of
-- every spec) + the spellbook. Every ID is kept, so a name shared by a talent, its buff and its debuff lists all of them, each labelled.
function SX.Norm(t)
    t = tostring(t or ""):lower():gsub("['\226\128\153]", ""):gsub("%p", " "):gsub("%s+", " ")
    return t:match("^%s*(.-)%s*$")
end
-- edit distance with swapped neighbours counted as one edit; gives up (returns maxd + 1) once it must exceed maxd
function SX.Dist(a, b, maxd)
    local la, lb = #a, #b
    if math.abs(la - lb) > maxd then return maxd + 1 end
    if la == 0 then return lb end
    if lb == 0 then return la end
    local p2, p1, cur = {}, {}, {}
    for j = 0, lb do p1[j] = j end
    for i = 1, la do
        cur[0] = i
        local ai, rowmin = a:byte(i), i
        for j = 1, lb do
            local bj = b:byte(j)
            local v = math.min(p1[j] + 1, cur[j - 1] + 1, p1[j - 1] + ((ai == bj) and 0 or 1))
            if i > 1 and j > 1 and ai == b:byte(j - 1) and a:byte(i - 1) == bj then v = math.min(v, p2[j - 2] + 1) end
            cur[j] = v
            if v < rowmin then rowmin = v end
        end
        if rowmin > maxd then return maxd + 1 end
        p2, p1, cur = p1, cur, p2
    end
    return p1[lb]
end
function SX.ClassSet(kind)
    local _, token, classID = UnitClass("player")
    if not token then return nil end
    local db = XayaUITalentDB
    local sig = table.concat({ token, tostring(GetSpecialization and GetSpecialization() or 0), tostring(db and db.built or ""),
        tostring(ns.talentList and #ns.talentList or 0), tostring(ns.spellList and #ns.spellList or 0) }, "|")
    if not (SX.cs and SX.cs.sig == sig) then
        local cs = { sig = sig, talent = {}, cd = {}, aura = {}, any = {} }
        local seen = { talent = {}, cd = {}, aura = {}, any = {} }
        local function add(which, id, name, tag)
            if not id or seen[which][id] then return end
            seen[which][id] = true
            local nn = SX.Norm(name)
            local words = {}
            for w in nn:gmatch("%S+") do words[#words + 1] = w end
            local l = cs[which]; l[#l + 1] = { id = id, name = name, tag = tag, norm = nn, words = words, cond = nn:gsub(" ", "") }
        end
        local function nameOf(id)
            local ok, n = pcall(C_Spell.GetSpellName, id)
            if ok and type(n) == "string" and n ~= "" then return n end
        end
        for _, tl in ipairs(ns.BuildTalentList and ns.BuildTalentList() or {}) do
            add("talent", tl.id, tl.name, "talent, your build"); add("any", tl.id, tl.name, "talent, your build")
        end
        local c = db and db.classes and classID and db.classes[classID]
        if c then
            for _, n in pairs(c.nodes or {}) do
                for _, e in ipairs(n.e or {}) do
                    local nm = e.spell and nameOf(e.spell)
                    if nm then
                        local where
                        if n.scope == "hero" then where = "hero talent"
                        elseif n.scope == "class" then where = "class talent"
                        else
                            local sp = {}
                            for sid in pairs(n.specs or {}) do sp[#sp + 1] = c.specs[sid] or tostring(sid) end
                            table.sort(sp)
                            where = "talent, " .. (#sp > 0 and table.concat(sp, "/") or "spec")
                        end
                        add("talent", e.spell, nm, where); add("any", e.spell, nm, where)
                        if not e.passive then add("cd", e.spell, nm, where) end
                    end
                end
            end
        end
        for _, d in pairs(ns.CLASS_AURA_DATA or {}) do
            if d.classToken == token then
                for _, e in ipairs(d.entries or {}) do
                    local nm = nameOf(e.id)
                    if nm then
                        local what = (e.kind == "cd") and "cooldown" or ((e.kind == "debuff") and "debuff" or ((e.kind == "proc") and "proc" or "buff"))
                        local tag = what .. ", " .. tostring(d.spec)
                        if e.kind == "cd" then add("cd", e.id, nm, tag) else add("aura", e.id, nm, tag) end
                        add("any", e.id, nm, tag)
                    end
                end
            end
        end
        for _, sp in ipairs(ns.BuildSpellList and ns.BuildSpellList() or {}) do
            if sp.name then add("cd", sp.id, sp.name, "spellbook"); add("any", sp.id, sp.name, "spellbook") end
        end
        SX.cs = cs
    end
    return SX.cs[(kind == "talent" or kind == "cd" or kind == "aura") and kind or "any"]
end
-- rank 1 exact, 2 starts with, 3 every word found, 4 found with typos / a missing space (closest first)
function SX.ClassMatches(set, q)
    local qn = SX.Norm(q)
    if qn == "" then return {} end
    local qw = {}
    for w in qn:gmatch("%S+") do qw[#qw + 1] = w end
    local qc = qn:gsub(" ", "")
    local out = {}
    for _, e in ipairs(set) do
        local rank, dist
        if e.norm == qn then rank, dist = 1, 0
        elseif e.norm:sub(1, #qn) == qn then rank, dist = 2, 0
        else
            local all, total = true, 0
            for _, w in ipairs(qw) do
                local best
                for _, x in ipairs(e.words) do
                    local d
                    if x:find(w, 1, true) then d = 0
                    else
                        local tol = (#w >= 8) and 2 or ((#w >= 4) and 1 or 0)
                        if tol > 0 then
                            d = math.min(SX.Dist(w, x, tol), SX.Dist(w, x:sub(1, #w), tol))
                            if d > tol then d = nil end
                        end
                    end
                    if d and (not best or d < best) then best = d end
                end
                if not best then all = false; break end
                total = total + best
            end
            if all then rank, dist = (total == 0) and 3 or 4, total
            elseif #qc >= 4 then   -- a missing or extra space, or a typo across the whole name
                local tol = (#qc >= 8) and 2 or 1
                local d = math.min(SX.Dist(qc, e.cond, tol), SX.Dist(qc, e.cond:sub(1, #qc), tol))
                if e.cond:find(qc, 1, true) then d = 0 end
                if d <= tol then rank, dist = 4, d end
            end
        end
        if rank then out[#out + 1] = { id = e.id, tag = e.tag, rank = rank, dist = dist, name = e.name } end
    end
    table.sort(out, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.dist ~= b.dist then return a.dist < b.dist end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return out
end

local function SearchSpells(q, kind)
    local item = kind == "item"
    local res, seen = {}, {}
    SX.tags = {}
    q = (q or ""):lower():match("^%s*(.-)%s*$")
    if q == "" then return res end
    local num = tonumber(q)
    if num then
        local ok, nm = pcall(item and C_Item.GetItemNameByID or C_Spell.GetSpellName, num)
        if ok and nm then res[1] = num; seen[num] = true end
    end
    if not item and not num then   -- this class first (typos tolerated), then the rest of the game
        local okS, set = pcall(SX.ClassSet, kind)
        if okS and set and #set > 0 then
            local okM, hits = pcall(SX.ClassMatches, set, q)
            for _, h in ipairs(okM and hits or {}) do
                if #res >= 80 then break end
                if not seen[h.id] then seen[h.id] = true; res[#res + 1] = h.id; SX.tags[h.id] = h.tag end
            end
            if kind == "talent" then return res end   -- a talent search lists this class's talents only
        end
    end
    -- No syntax to remember: every word must appear in the name, in any order; "*" matches anything. Exact names rank first,
    -- then names that start with the search, then the rest.
    local words = {}
    for w in q:gmatch("%S+") do
        words[#words + 1] = w:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0"):gsub("%*", ".*")
    end
    local function matches(nm)
        for i = 1, #words do if not nm:find(words[i]) then return false end end
        return true
    end
    local function rank(nm)
        if nm == q then return 1 end
        if nm:sub(1, #q) == q then return 2 end
        return 3
    end
    local buckets = { {}, {}, {} }
    local function consider(id, nm)
        if id and nm and not seen[id] and matches(nm) then
            seen[id] = true
            local t = buckets[rank(nm)]; t[#t + 1] = id
        end
    end
    if item then
        for _, it in ipairs(SX.OwnedItems()) do consider(it.id, it.name:lower()) end
    else
        for _, sp in ipairs(ns.BuildSpellList() or {}) do
            if sp.name then consider(sp.id, sp.name:lower()) end
        end
    end
    local S = item and SX.II or SI
    local names, ids = S.names, S.ids
    for i = 1, S.n do consider(ids[i], names[i]) end
    for _, t in ipairs(buckets) do
        for _, id in ipairs(t) do
            if #res >= 80 then return res end
            res[#res + 1] = id
        end
    end
    return res
end

local SP, SP_ROWS, SP_ROW_H = nil, 8, 24
local function SP_Render()
    if not SP then return end
    local r, total = SP.results or {}, #(SP.results or {})
    for i = 1, SP_ROWS do
        local row, id = SP.rows[i], r[SP.offset + i]
        if id then
            row.id = id
            if SP.kind == "item" then
                local oki, ic = pcall(C_Item.GetItemIconByID, id)
                row.icon:SetTexture((oki and ic) or 134400)
            else row.icon:SetTexture(SpellTex(id)) end
            local okn, nm = pcall(SP.kind == "item" and C_Item.GetItemNameByID or C_Spell.GetSpellName, id)
            local tg = SX.tags and SX.tags[id]
            local src = (SP.kind == "aura" and ns.AuraSources) and ns.AuraSources.Label(id) or nil
            row.text:SetText(((okn and nm) or "?") .. "  |cff888888[" .. id .. "]|r" .. (tg and ("  |cff7fb6e6" .. tg .. "|r") or "")
                .. (src and ("  |cffb4a06eFrom|r |cffc9c9c9" .. src .. "|r") or ""))
            row:Show()
        else row:Hide() end
    end
    local msg = ""
    local S, smax = (SP.kind == "item") and SX.II or SI, (SP.kind == "item") and SX.II_MAX or SI_MAX
    if S.running then msg = ("Indexing %s names... %d%%  "):format(SP.kind == "item" and "item" or "spell", math.floor(S.nextId / smax * 100)) end
    if SP.kind == "talent" and not (XayaUITalentDB and XayaUITalentDB.classes) then msg = msg .. "Your current build only; /xui talents adds every spec.  " end
    if SP.kind == "aura" and ns.AuraSources then
        local pr = ns.AuraSources.Progress()
        if pr then msg = msg .. ("Finding what applies each aura... %d%%  "):format(math.floor(pr * 100)) end
    end
    if total == 0 then msg = msg .. "No match yet"
    elseif total > SP_ROWS then msg = msg .. total .. " results - scroll for more" end
    SP.footer:SetText(msg)
end
local function SP_Hide() if SP then SP:Hide(); SP.owner = nil end end
local function SP_Pick(id)
    local eb = SP and SP.owner
    if not (eb and eb.xuiSearchFn and id) then return end
    local fn, kind = eb.xuiSearchFn, eb.xuiSearchKind
    SP_Hide()
    eb:SetText(""); eb:ClearFocus()
    local ok, err = pcall(fn, id)   -- an error in the pick handler used to vanish and leave the ID box unchanged
    if not ok then ns.Print("search pick failed: " .. tostring(err)) end
end

-- Hovering a result must never open the "compare with equipped gear" tooltips (Blizzard adds them on its own for items).
function SX.NoCompare()
    if GameTooltip_HideShoppingTooltips then pcall(GameTooltip_HideShoppingTooltips, GameTooltip) end
    for _, n in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do local f = _G[n]; if f and f.Hide then f:Hide() end end
end
function SX.HookCompare()
    if SX.compareHooked then return end
    SX.compareHooked = true
    if hooksecurefunc and type(GameTooltip_ShowCompareItem) == "function" then
        hooksecurefunc("GameTooltip_ShowCompareItem", function()
            if SP and SP.tipRow and GameTooltip:GetOwner() == SP.tipRow then SX.NoCompare() end
        end)
    end
end
local function SP_Build()
    if SP then return SP end
    SP = CreateFrame("Frame", "XayaUISpellSearch", UIParent, "BackdropTemplate")
    SP:SetFrameStrata("TOOLTIP"); SP:SetClampedToScreen(true); SP:EnableMouse(true); SP:EnableMouseWheel(true)
    SP:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    SP:SetBackdropColor(0.05, 0.05, 0.08, 0.97); SP:SetBackdropBorderColor(0.6, 0.5, 0.1, 1)
    SP:SetSize(340, SP_ROWS * SP_ROW_H + 22)
    SP.rows, SP.offset, SP.results = {}, 0, {}
    for i = 1, SP_ROWS do
        local b = CreateFrame("Button", nil, SP)
        b:SetHeight(SP_ROW_H)
        b:SetPoint("TOPLEFT", SP, "TOPLEFT", 2, -2 - (i - 1) * SP_ROW_H)
        b:SetPoint("TOPRIGHT", SP, "TOPRIGHT", -2, -2 - (i - 1) * SP_ROW_H)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 2, 0)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0); b.text:SetPoint("RIGHT", -4, 0); b.text:SetJustifyH("LEFT")
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 0.82, 0, 0.18)
        -- mouse DOWN so the pick lands before the edit box loses focus
        b:SetScript("OnMouseDown", function(self) SP_Pick(self.id) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            SX.HookCompare(); SP.tipRow = self
            GameTooltip.supportsItemComparison = false
            if SP.kind == "item" then
                if not pcall(GameTooltip.SetItemByID, GameTooltip, self.id) then GameTooltip:SetText("Item " .. tostring(self.id)) end
            elseif not pcall(GameTooltip.SetSpellByID, GameTooltip, self.id) then GameTooltip:SetText("Spell " .. tostring(self.id)) end
            GameTooltip:Show()
            SX.NoCompare()
            if C_Timer then C_Timer.After(0, function() if SP and SP.tipRow == self then SX.NoCompare() end end) end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide(); GameTooltip.supportsItemComparison = nil; if SP then SP.tipRow = nil end; SX.NoCompare() end)
        SP.rows[i] = b
    end
    SP.footer = SP:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    SP.footer:SetPoint("BOTTOMLEFT", 6, 5); SP.footer:SetJustifyH("LEFT")
    SP:SetScript("OnMouseWheel", function(self, d)
        local maxOff = math.max(0, #self.results - SP_ROWS)
        self.offset = math.max(0, math.min(maxOff, self.offset - d * 2))
        SP_Render()
    end)
    local acc = 0
    SP:SetScript("OnUpdate", function(self, e)
        if self.owner and not self.owner:IsVisible() then SP_Hide(); return end
        if ((self.kind == "item") and SX.II.running) or (self.kind ~= "item" and SI.running)
            or (self.kind == "aura" and ns.AuraSources and ns.AuraSources.Progress()) then
            acc = acc + e
            if acc > 0.6 and self.owner then acc = 0; self.results = SearchSpells(self.owner:GetText(), self.kind); SP_Render() end
        end
    end)
    SP:Hide()
    return SP
end
local function SP_Update(eb)
    local q = eb:GetText() or ""
    if #q < 2 and not tonumber(q) then SP_Hide(); return end
    SP_Build()
    SP.owner = eb
    SP.kind = eb.xuiSearchKind
    SP.results, SP.offset = SearchSpells(q, SP.kind), 0
    SP:ClearAllPoints()
    SP:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", -4, -2)
    SP:SetWidth(math.max(SP.kind == "aura" and 560 or 340, eb:GetWidth() + 8))
    SP:Show()
    SP_Render()
end
AttachSearch = function(w)
    local eb = w.editbox
    if not eb then return end
    local opt = w.GetUserData and w:GetUserData("option")
    eb.xuiSearchFn = opt and type(opt.arg) == "table" and opt.arg.xuiSearch or nil
    eb.xuiSearchKind = opt and type(opt.arg) == "table" and opt.arg.xuiSearchKind or nil
    if eb.xuiSearchFn and not eb.xuiSearchHooked then
        eb.xuiSearchHooked = true
        eb:HookScript("OnEditFocusGained", function(self) if self.xuiSearchFn then SX.Start(self.xuiSearchKind) end end)
        eb:HookScript("OnTextChanged", function(self, user)
            if not (self.xuiSearchFn and user) then return end
            SX.Start(self.xuiSearchKind)
            self.xuiStamp = (self.xuiStamp or 0) + 1
            local stamp = self.xuiStamp
            C_Timer.After(0.15, function() if self.xuiStamp == stamp and self:HasFocus() then SP_Update(self) end end)
        end)
        eb:HookScript("OnEnterPressed", function(self)
            if self.xuiSearchFn and SP and SP:IsShown() and SP.owner == self and SP.results[1] then SP_Pick(SP.results[1]) end
        end)
        eb:HookScript("OnEscapePressed", function(self) if SP and SP.owner == self then SP_Hide() end end)
        eb:HookScript("OnEditFocusLost", function(self)
            C_Timer.After(0.2, function() if SP and SP.owner == self and not self:HasFocus() then SP_Hide() end end)
        end)
    end
end

end

local function SpellIconLeave() GameTooltip:Hide() end
local function SpellIconEnter(widget)
    local opt = widget.GetUserData and widget:GetUserData("option")
    local row = opt and type(opt.arg) == "table" and opt.arg.xuiSpell
    local id = row and row.id
    GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
    if id and id > 0 then
        local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, id)
        if not ok then GameTooltip:SetText("Unknown spell ID " .. tostring(id)) end
    else
        GameTooltip:SetText("Type a spell ID to see its tooltip.")
    end
    GameTooltip:Show()
end
local function AttachSpellTip(w)
    local opt = w.GetUserData and w:GetUserData("option")
    if not (opt and type(opt.arg) == "table" and opt.arg.xuiSpell) then return end
    if not (w.events and w.events.OnEnter == SpellIconEnter) then
        w:SetCallback("OnEnter", SpellIconEnter)
        w:SetCallback("OnLeave", SpellIconLeave)
    end
end

-- Left-aligned section headers: AceGUI centers Heading text between two lines and Button text. Only widgets inside XayaUI's
-- own window are touched, and everything is put back when the widget is released (AceGUI recycles widgets across addons).
function ns.LeftRestore(w)
    if w.type == "Heading" and w.label then
        w.label:ClearAllPoints(); w.label:SetPoint("TOP"); w.label:SetPoint("BOTTOM"); w.label:SetJustifyH("CENTER")
        w.left:Show()
        w.left:ClearAllPoints(); w.left:SetPoint("LEFT", 3, 0); w.left:SetPoint("RIGHT", w.label, "LEFT", -5, 0)
        w.right:ClearAllPoints(); w.right:SetPoint("RIGHT", -3, 0); w.right:SetPoint("LEFT", w.label, "RIGHT", 5, 0)
        if w.frame and w.frame.xuiInfoIcon then w.frame.xuiInfoIcon:Hide() end
    elseif w.type == "Button" and w.text then
        w.text:SetJustifyH("CENTER")
    end
    w.xuiLeftOn = nil
end
function ns.HookRelease(w)
    if w.xuiRelHook then return end
    w.xuiRelHook = true
    local orig = w.OnRelease
    w.OnRelease = function(self, ...)
        if self.xuiLeftOn then ns.LeftRestore(self) end
        if orig then return orig(self, ...) end
    end
end
function ns.LeftAlign(w)
    if w.type == "Heading" and w.label and w.left and w.right then
        local t = w.label:GetText()
        if not t or t == "" then return end
        if w.xuiLeftOn and not w.right:IsShown() then w.xuiLeftOn = nil end   -- re-acquired with new text: lay it out again
        if w.xuiLeftOn then return end
        ns.HookRelease(w)
        w.xuiLeftOn = true
        w.label:ClearAllPoints()
        w.label:SetPoint("TOPLEFT", w.frame, "TOPLEFT", 4, 0); w.label:SetPoint("BOTTOMLEFT", w.frame, "BOTTOMLEFT", 4, 0)
        w.label:SetJustifyH("LEFT")
        w.left:Hide()
        w.right:ClearAllPoints()
        w.right:SetPoint("RIGHT", w.frame, "RIGHT", -3, 0); w.right:SetPoint("LEFT", w.label, "RIGHT", 8, 0)
        w.right:Show()
        local hopt = w.GetUserData and w:GetUserData("option")
        if hopt and hopt.xuiInfo and ns.GetInfoIcon then   -- (i) next to the heading: hover for the explanation, click to pin it
            local ic = ns.GetInfoIcon(w.frame)
            ic.xuiText = hopt.xuiInfo; ic.xuiTitle = t
            ic:ClearAllPoints(); ic:SetPoint("LEFT", w.label, "RIGHT", 6, 0); ic:Show()
            w.right:ClearAllPoints()
            w.right:SetPoint("RIGHT", w.frame, "RIGHT", -3, 0); w.right:SetPoint("LEFT", ic, "RIGHT", 8, 0)
        elseif w.frame.xuiInfoIcon then
            w.frame.xuiInfoIcon:Hide()
        end
    elseif w.type == "Button" and w.text then
        local opt = w.GetUserData and w:GetUserData("option")
        if opt and type(opt.arg) == "table" and opt.arg.xuiLeft then
            if not w.xuiLeftOn then ns.HookRelease(w); w.xuiLeftOn = true; w.text:SetJustifyH("LEFT") end
        elseif w.xuiLeftOn then
            ns.LeftRestore(w)
        end
    end
end

local function Walk(w, depth)
    if not w or depth > 14 then return end
    if w.type == "Heading" or w.type == "Button" then ns.LeftAlign(w) end
    if w.type == "Icon" then AttachSpellTip(w) end
    if w.type == "EditBox" then AttachSearch(w) end
    if w.type == "TreeGroup" then DecorateTree(w) end
    for _, c in ipairs(w.children or {}) do Walk(c, depth + 1) end
end

function ns.DecorateTrees(root)
    root = root or (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP])
    if root then pcall(Walk, root, 0) end
end
-- decorate right after every (re)draw of the window, so left-aligned headers do not flash centered before the next 0.25 s pass
do
    -- /xui perf: trace of what happens after a click, in FRAMES. Anything that lands on a later frame than the click is a visible
    -- intermediate state (the cause of a blink), so the trace shows exactly which step is late.
    local fno, fclick = 0, 0
    local tf = CreateFrame("Frame"); tf:SetScript("OnUpdate", function() fno = fno + 1 end)
    function ns.Trace(tag)
        if not (ns.perf and ns.perf.show) then return end
        if tag == "click" then fclick = fno end
        print(string.format("|cffffd100XayaUI|r trace +%d frame(s): %s", fno - fclick, tag))
    end
    ns.origOpen = AceConfigDialog.Open
    AceConfigDialog.Open = function(self, app, ...)
        if app == APP then ns.Trace("Open (full window rebuild)") end
        local t0 = debugprofilestop and debugprofilestop() or 0
        local a, b, c = ns.origOpen(self, app, ...)
        local t1 = debugprofilestop and debugprofilestop() or 0
        if app == APP then pcall(ns.DecorateTrees) end
        if app == APP and debugprofilestop then
            local t2 = debugprofilestop()
            ns.perf = ns.perf or { n = 0 }
            ns.perf.n = ns.perf.n + 1; ns.perf.build, ns.perf.skin = t1 - t0, t2 - t1
            if ns.perf.show then print(string.format("|cffffd100XayaUI|r rebuild #%d: build %.0f ms + skin %.0f ms", ns.perf.n, t1 - t0, t2 - t1)) end
        end
        return a, b, c
    end
end

local function SelectedRule()
    if not AceConfigDialog.GetStatusTable then return nil end
    local tab = ns.CurrentTab()
    if tab ~= "cooldowns" and tab ~= "smartcat" then return nil end
    local st = { groups = ns.RulesTreeStatus() }
    local sel = st and st.groups and st.groups.selected
    local idx = sel and tonumber(tostring(sel):match("rule(%d+)"))
    return idx and ns.rules and ns.rules[idx]
end

function ns.SelectedRuleForUndo() return SelectedRule() end   -- Drafts.lua undo (Ctrl+Z) edits the rule selected in the sidebar

-- Selected group in the sidebar (last path segment is a group id), or nil.
function ns.SelectedGroup()
    if not AceConfigDialog.GetStatusTable then return nil end
    local tab = ns.CurrentTab()
    if tab ~= "cooldowns" and tab ~= "smartcat" then return nil end
    local st = { groups = ns.RulesTreeStatus() }
    local sel = st and st.groups and st.groups.selected
    local last = sel and tostring(sel):match("([^\001]+)$")
    return last and FolderById(last) or nil
end
-- Del key: delete the multi-selected rules, else the open rule, else the open group. Always asks first.
function ns.DeleteKey()
    if ns.MultiCount() > 0 then ns.MultiDelete(); return true end
    local rule = SelectedRule()
    if rule then
        AskConfirm("Delete the rule '" .. tostring(rule.name) .. "'? This cannot be undone.", function()
            if ns.DeleteOutcomesOf then pcall(ns.DeleteOutcomesOf, rule) end
            for idx, r in ipairs(ns.rules) do if r == rule then table.remove(ns.rules, idx); break end end
            pcall(ns.DropVisual, rule)
            ns.MarkDirty(); Notify(); SelectRoot()
        end)
        return true
    end
    local g = ns.SelectedGroup()
    if g then
        AskConfirm("Delete the group '" .. tostring(g.name) .. "'? Its rules and nested groups are kept and move up one level.", function() ns.DeleteFolderById(g.id) end)
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- Window chrome: a close X (top right) and a collapse arrow (shrinks the window to
-- just the XayaUI banner). Collapse state is session-only and resets when the window closes.
-------------------------------------------------------------------------------
local ARROW_OPEN, ARROW_COLLAPSED = "Interface\\Buttons\\Arrow-Up-Up", "Interface\\Buttons\\Arrow-Down-Up"

local function SetCollapsed(of, collapsed)
    local c = of and of.xuiChrome
    local fr = of and of.frame
    if not (c and fr) then return end
    collapsed = collapsed and true or false
    if (c.collapsed or false) == collapsed then return end
    c.collapsed = collapsed
    if collapsed then
        c.hidden = {}
        for _, child in ipairs({ fr:GetChildren() }) do
            if child ~= c.title and child ~= c.arrow and child ~= c.close and child:IsShown() then
                c.hidden[#c.hidden + 1] = child
                child:Hide()
            end
        end
        fr:SetBackdropColor(0, 0, 0, 0)
        fr:SetBackdropBorderColor(0, 0, 0, 0)
        fr:EnableMouse(false)
        -- keep the X visible too, on the other side of the banner
        c.close:ClearAllPoints()
        c.close:SetPoint("LEFT", of.titlebg, "RIGHT", 36, 0)
        c.arrow.tex:SetTexture(ARROW_COLLAPSED)
        -- the window body is gone, so keep the button next to the banner instead of the (invisible) corner
        c.arrow:ClearAllPoints()
        c.arrow:SetPoint("RIGHT", of.titlebg, "LEFT", -36, 0)
    else
        for _, child in ipairs(c.hidden or {}) do child:Show() end
        c.hidden = nil
        fr:SetBackdropColor(0, 0, 0, 1)
        fr:SetBackdropBorderColor(1, 1, 1, 1)
        fr:EnableMouse(true)
        c.close:ClearAllPoints()
        c.close:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -6, -4)
        c.close:Show()
        c.arrow.tex:SetTexture(ARROW_OPEN)
        c.arrow:ClearAllPoints()
        c.arrow:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -32, -4)
    end
end

local function EnsureChrome(of)
    local fr = of and of.frame
    if not (fr and of.titlebg and of.titletext) then return end
    local c = of.xuiChrome
    if not c then
        c = {}
        of.xuiChrome = c
        c.title = of.titletext:GetParent()

        c.close = CreateFrame("Button", nil, fr, "UIPanelCloseButton")
        c.close:SetSize(22, 22)   -- the title ribbon is 28 px tall (Skin.lua); 22 px buttons centered in it
        c.close:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -6, -4)
        c.close:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.close:SetScript("OnClick", function() AceConfigDialog:Close(APP) end)

        -- boxed button (same skin as the Close button), just left of the X
        c.arrow = CreateFrame("Button", nil, fr, "UIPanelButtonTemplate")
        c.arrow:SetSize(22, 22)
        c.arrow:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -32, -4)
        c.arrow:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.arrow.tex = c.arrow:CreateTexture(nil, "OVERLAY")
        c.arrow.tex:SetSize(14, 14)
        c.arrow.tex:SetPoint("CENTER", 0, 0)
        c.arrow.tex:SetTexture(ARROW_OPEN)
        c.arrow:SetScript("OnClick", function() SetCollapsed(of, not c.collapsed) end)
        c.arrow:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(c.collapsed and "Expand the window" or "Collapse to the banner")
            GameTooltip:Show()
        end)
        c.arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Addon Info: a small muted link in the bottom-left corner, outside the normal interaction area
        c.info = CreateFrame("Button", nil, fr)
        c.info:SetSize(80, 16)
        ns.infoLink = c.info   -- Skin.lua keeps the rule list above this link
        c.info:SetPoint("BOTTOMLEFT", fr, "BOTTOMLEFT", 20, 11)
        c.info:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.info.text = c.info:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        c.info.text:SetPoint("LEFT", 0, 0); c.info.text:SetText("Addon Info")
        c.info:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.82, 0) end)
        c.info:SetScript("OnLeave", function(self) self.text:SetTextColor(0.5, 0.5, 0.5) end)
        c.info.text:SetTextColor(0.5, 0.5, 0.5)
        c.info:SetScript("OnClick", function()
            ns.infoOpen = true; ns.pageOpen = nil
            Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "info")
        end)

        if not fr.xuiDelKey then
            fr.xuiDelKey = true
            fr:EnableKeyboard(true)
            fr:HookScript("OnKeyDown", function(self, key)
                local handled = false
                if key == "DELETE" then handled = ns.DeleteKey()
                elseif (key == "Z" or key == "Y") and IsControlKeyDown() and ns.UndoKey then handled = ns.UndoKey(key == "Y" or IsShiftKeyDown()) end
                if self.SetPropagateKeyboardInput and not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
            end)
        end
        -- multi-select delete links (shown only while rules are selected)
        c.delSel = CreateFrame("Button", nil, fr)
        c.delSel:SetHeight(16)
        c.delSel:SetPoint("BOTTOMLEFT", fr, "BOTTOMLEFT", 110, 14)
        c.delSel:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.delSel.text = c.delSel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        c.delSel.text:SetPoint("LEFT", 0, 0); c.delSel.text:SetTextColor(1, 0.3, 0.3)
        c.delSel:SetScript("OnClick", function() ns.MultiDelete() end)
        c.delSel:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Ctrl+click rule rows to select, Shift+click for a range")
            GameTooltip:Show()
        end)
        c.delSel:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c.clr = CreateFrame("Button", nil, fr)
        c.clr:SetHeight(16); c.clr:SetWidth(70)
        c.clr:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.clr.text = c.clr:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        c.clr.text:SetPoint("LEFT", 0, 0); c.clr.text:SetText("Clear selection")
        c.clr:SetScript("OnClick", function() ns.MultiClear() end)
        c.delSel:Hide(); c.clr:Hide()

        -- AceGUI recycles Frame widgets: undo everything on release so other addons' windows stay untouched
        local orig = of.OnRelease
        of.OnRelease = function(self, ...)
            pcall(ns.SaveRulesSub)
            SetCollapsed(self, false)
            ns.infoOpen = false; ns.pageOpen = nil
            ns.MultiReset()
            c.delSel:Hide(); c.clr:Hide()
            c.info:Hide()
            c.close:Hide()
            c.arrow:Hide()
            if orig then return orig(self, ...) end
        end
    end
    c.arrow:Show()
    c.close:Show()
    if c.info and not c.collapsed then c.info:Show() end
    -- first time the window opens in a session: every top-level group / Smart Categories list under Rules, Loaded and Not Loaded starts collapsed
    if not ns.sessionCollapsed and AceConfigDialog.GetStatusTable then
        local anyTab = false
        for _, tk in ipairs({ "enabledTab", "smartTab", "disabledTab" }) do
            local st = AceConfigDialog:GetStatusTable(APP, { "cooldowns", tk })
            if st and st.groups then
                anyTab = true
                for uv, on in pairs(st.groups) do
                    if on and type(uv) == "string" then
                        local _, n = uv:gsub("\001", "\001")
                        if n == 1 then st.groups[uv] = nil end
                    end
                end
            end
        end
        if anyTab then ns.sessionCollapsed = true; Notify() end
    end
    if c.delSel then
        local n = ns.MultiCount and ns.MultiCount() or 0
        if n > 0 and not c.collapsed then
            c.delSel.text:SetText(("Delete %d selected rule%s"):format(n, n == 1 and "" or "s"))
            c.delSel:SetWidth(c.delSel.text:GetStringWidth() + 4)
            c.clr:ClearAllPoints(); c.clr:SetPoint("LEFT", c.delSel, "RIGHT", 12, 0)
            c.delSel:Hide(); c.clr:Hide()   -- bottom-left duplicate removed: the sidebar bar has Delete / Move to / Clear
        else c.delSel:Hide(); c.clr:Hide() end
    end
    -- the Addon Info page lasts only until another tab is picked
    if ns.infoOpen then
        local st = AceConfigDialog.GetStatusTable and AceConfigDialog:GetStatusTable(APP)
        local tab = st and st.groups and st.groups.selected
        if tab and tab ~= "info" then ns.infoOpen = false; Notify() end
    end
    -- Creator / Profiles / Settings pages last only until another tab is picked
    if ns.pageOpen then
        local st = AceConfigDialog.GetStatusTable and AceConfigDialog:GetStatusTable(APP)
        local tab = st and st.groups and st.groups.selected
        local isSettingsTab = ns.pageOpen == "settings" and tab == "set"
        if tab and tab ~= ns.pageOpen and not isSettingsTab then ns.pageOpen = nil; Notify() end
    end
end

-- Unsaved-changes strip, attached under the options window (above the debug console) so it takes no room from the editor tabs.
do
    local bar
    local LIST = {
        { "save",   "Save changes",             "DraftSave",             true,  true  },
        { "copy",   "Save as a copy",           "DraftSaveAsCopy",       false, true  },
        { "drafts", "Add to drafts",            "DraftAddToDrafts",      true,  true  },
        { "cdraft", "Add as a copy to drafts",  "DraftAddCopyToDrafts",  true,  true  },
        { "discard","Discard changes",          "DraftDiscard",          true,  true  },
    }
    local function Target()
        local r = SelectedRule()
        if r and r.parentUid and ns.FindParentRule then r = ns.FindParentRule(r) end
        if r and ns.DraftDirty and ns.DraftDirty(r) then return r end
    end
    local function Layout()
        local isNew = bar.rule and ns.DraftIsNew(bar.rule)
        local shown = {}
        for _, d in ipairs(LIST) do
            local b = bar.btn[d[1]]
            local on = (isNew and d[4]) or (not isNew and d[5])
            if on then shown[#shown + 1] = b end
            b:SetShown(on)
        end
        bar.btn.discard:SetText(bar.armed and "Click again to discard" or (isNew and "Discard new rule" or "Discard changes"))
        local n, gap = #shown, 4
        local w = ((bar:GetWidth() or 700) - 16 - (n - 1) * gap) / math.max(n, 1)
        for i, b in ipairs(shown) do
            b:ClearAllPoints(); b:SetSize(math.max(w, 40), 22)
            b:SetPoint("TOPLEFT", bar, "TOPLEFT", 8 + (i - 1) * (w + gap), -40)
        end
        bar.text:SetText(ns.DraftBarText(isNew))
    end
    local function Build()
        local f = CreateFrame("Frame", "XayaUISaveBar", UIParent, "BackdropTemplate")
        f:SetHeight(70)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.10, 0.05, 0.05, 0.97)
        f:SetBackdropBorderColor(0.6, 0.5, 0.1, 1)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.text:SetPoint("TOPLEFT", 8, -6); f.text:SetPoint("TOPRIGHT", -8, -6)
        f.text:SetJustifyH("LEFT"); f.text:SetJustifyV("TOP"); f.text:SetHeight(30)
        f.btn = {}
        for _, d in ipairs(LIST) do
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetText(d[2])
            f.btn[d[1]] = b
            b:SetScript("OnClick", function()
                local r = f.rule
                if not r then return end
                if d[1] == "discard" then
                    if not f.armed then
                        f.armed = true
                        f.armTok = (f.armTok or 0) + 1
                        local tok = f.armTok
                        if C_Timer then C_Timer.After(4, function() if f.armTok == tok then f.armed = false end end) end
                        return
                    end
                    f.armed = false
                end
                local fn = ns[d[3]]
                if fn then pcall(fn, r) end
                if ns.UI and ns.UI.Notify then ns.UI.Notify() end
            end)
        end
        -- the addon's own flat button look (Skin.lua); with the skin off, Save keeps the old red text on the Blizzard button
        f.btn.save:HookScript("OnShow", function(self)
            if ns.SkinPlainButton and not self.xuiFlatBtn then self:GetFontString():SetTextColor(1, 0.3, 0.3) end
        end)
        f.skinBtns = function()
            if not ns.SkinPlainButton then return end
            for key, btn in pairs(f.btn) do pcall(ns.SkinPlainButton, btn, key == "save") end
        end
        f.skinBtns()
        f:SetScript("OnSizeChanged", function() if f.rule then pcall(Layout) end end)
        return f
    end
    -- Returns the strip when it is shown (so the debug console can sit under it), else nil.
    function ns.SaveBarUpdate(fr)
        local r = fr and fr:IsShown() and Target()
        if not r then
            if bar then bar:Hide(); bar.rule = nil; bar.armed = false end
            return nil
        end
        if not bar then bar = Build() end
        if bar.anchoredTo ~= fr then
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", fr, "BOTTOMLEFT", 0, 0)
            bar:SetPoint("TOPRIGHT", fr, "BOTTOMRIGHT", 0, 0)
            bar.anchoredTo = fr
        end
        bar:SetFrameStrata(fr:GetFrameStrata()); bar:SetFrameLevel(fr:GetFrameLevel())
        if bar.rule ~= r then bar.armed = false end
        bar.rule = r
        local wasShown = bar:IsShown()
        bar:Show()
        if not wasShown and bar.skinBtns then bar.skinBtns() end   -- re-read the theme each time the strip appears
        pcall(Layout)
        return bar
    end
end

local driver, acc = CreateFrame("Frame"), 0
local sigAcc, lastSig = 0, nil
driver:SetScript("OnUpdate", function(_, e)
    acc = acc + e
    if acc < 0.25 then return end
    acc = 0
    local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
    local fr = of and of.frame
    if ns.AnyPreview() and not (fr and fr:IsShown()) then ns.ClearPreview() end
    if fr and fr:IsShown() then pcall(EnsureChrome, of) end
    if fr and fr:IsShown() and ns.DecorateTrees then ns.DecorateTrees(of) end
    if fr and fr:IsShown() and ns.rules then
        sigAcc = sigAcc + 1
        if sigAcc >= 4 then
            sigAcc = 0
            local okc, ctx = pcall(ns.ReadContext)
            if okc then
                local t = {}
                for i, r in ipairs(ns.rules) do t[i] = ns.IsLoaded(r, ctx) and "1" or "0" end
                local sig = table.concat(t)
                if lastSig and sig ~= lastSig then Notify() end
                lastSig = sig
            end
        end
    end
    local sbar = ns.SaveBarUpdate and ns.SaveBarUpdate(fr)
    if fr and fr:IsShown() and not (of.xuiChrome and of.xuiChrome.collapsed) and ns.DebugConsoleOn() then
        if not tray then tray = BuildTray(); ApplyTrayState() end
        local anc = sbar or fr
        if tray.anchoredTo ~= anc then
            tray:ClearAllPoints()
            tray:SetPoint("TOPLEFT", anc, "BOTTOMLEFT", 0, 0)
            tray:SetPoint("TOPRIGHT", anc, "BOTTOMRIGHT", 0, 0)
            tray.anchoredTo = anc
        end
        tray:SetFrameStrata(fr:GetFrameStrata())
        tray:SetFrameLevel(fr:GetFrameLevel())
        tray:Show()
        if TrayOpen() then
            local r = SelectedRule()
            tray.status:SetText(r and StatusText(r) or "Select a rule on the left to see its live status here.")
        end
    elseif tray then
        tray:Hide()
        tray.anchoredTo = nil
    end
end)

-------------------------------------------------------------------------------
-- Entry in Blizzard's Options > AddOns list (button that opens the real window)
-------------------------------------------------------------------------------
local function CloseBlizzardSettings()
    if SettingsPanel and SettingsPanel:IsShown() then
        if HideUIPanel then HideUIPanel(SettingsPanel) else SettingsPanel:Hide() end
    end
end

local function RegisterBlizzardPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "XayaUI"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("XayaUI")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    sub:SetWidth(560)
    sub:SetJustifyH("LEFT")
    sub:SetText("Sound cues and on-screen alerts driven by rules: buff, cooldown, talent, and conditions.\nSlash commands: /xui (or /xayaui)  |  /xui status  |  /xui probe <spellID>  |  /xui unlock")

    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(200, 28)
    btn:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -20)
    btn:SetText("Open XayaUI")
    btn:SetScript("OnClick", function()
        CloseBlizzardSettings()
        if not (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]) then ns.ToggleUI() end
    end)

    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "XayaUI")
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        ns.settingsCategory = category
    end
end
RegisterBlizzardPanel()

-- Addon compartment (minimap "addons" menu) click handler; named in the .toc
function XayaUI_OnCompartmentClick() ns.ToggleUI() end
