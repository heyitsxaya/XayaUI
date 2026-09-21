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

local function Notify() AceConfigRegistry:NotifyChange(APP) end

local function Changed(rule)
    if rule then ns.RefreshVisual(rule) end
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
local IMPORT_MODE = { add = "Add to what I have", replace = "Replace what I have (the parts included)" }
local IMPORT_MODE_ORDER = { "add", "replace" }
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
local TEX_KIND = { none = "(none)", file = "Texture ID / path", atlas = "Atlas name", spellicon = "Spell icon (of the cooldown spell)" }
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
local texValues, texSorting
local function EnsureTextures()
    if texValues then return end
    texValues, texSorting = {}, {}
    for i, t in ipairs(ns.TextureList or {}) do
        local k = tostring(t[1])
        texValues[k] = ("|T%d:22|t  %s"):format(t[1], t[2])
        texSorting[i] = k
    end
    texValues["0"] = "(none)"
    table.insert(texSorting, 1, "0")
    -- local graphics (Media\\Graphics, from LocalGraphics.lua); the stored value is the file path
    for _, g in ipairs(ns.LocalGraphics or {}) do
        texValues[g[2]] = ("|T%s:22:22|t  %s"):format(g[2], g[1])
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
-- Status text (used by the Rule tab and the debug tray)
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
    local o = { type = "range", name = name, order = order, min = min, max = max, step = step,
        get = function() return t[k] or min end, set = function(_, v) t[k] = v; on() end }
    if extra then for kk, vv in pairs(extra) do o[kk] = vv end end
    return o
end
local function Tog(t, k, name, order, on, extra)
    local o = { type = "toggle", name = name, order = order,
        get = function() return t[k] and true or false end, set = function(_, v) t[k] = v; on() end }
    if extra then for kk, vv in pairs(extra) do o[kk] = vv end end
    return o
end
local function Sel(t, k, name, order, vals, ord, on, extra)
    local o = { type = "select", name = name, order = order, values = vals, sorting = ord,
        get = function() return t[k] end, set = function(_, v) t[k] = v; on() end }
    if extra then for kk, vv in pairs(extra) do o[kk] = vv end end
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

-- Shared text styling controls (font, size, outline, placement, offsets, colour)
local function TextStyleArgs(t, on, base, opts)
    opts = opts or {}
    local a = {}
    a.font = FontSel(t, base + 1, on)
    a.size = Rng(t, "size", "Text size", base + 2, 6, 96, 1, on)
    a.outline = Sel(t, "outline", "Outline", base + 3, TEXT_OUTLINE, TEXT_OUTLINE_ORDER, on)
    a.color = Col(t, "color", "Text colour", base + 4, on)
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
local function FolderPath(f)
    local p = { "cooldowns", "all" }
    for _, c in ipairs(FolderChain(f)) do p[#p + 1] = c.id end
    return unpack(p)
end

local function FolderValues()
    local v, o = { none = "(none - top level)" }, { "none" }
    for _, f in ipairs(ns.folders or {}) do
        local names = {}
        for _, c in ipairs(FolderChain(f)) do names[#names + 1] = c.name end
        v[f.id] = table.concat(names, " / "); o[#o + 1] = f.id
    end
    return v, o
end

local function RulePath(rule)
    for idx, r in ipairs(ns.rules) do
        if r == rule then
            local p = { "cooldowns", "all" }
            local f = rule.folder and FolderById(rule.folder)
            if f then for _, c in ipairs(FolderChain(f)) do p[#p + 1] = c.id end end
            p[#p + 1] = "rule" .. idx
            return unpack(p)
        end
    end
    return "cooldowns", "all"
end

-------------------------------------------------------------------------------
-- Copy / paste settings between rules (choose exactly which sections; nothing is pasted by default)
-------------------------------------------------------------------------------
local ruleClip = nil          -- { name = "...", data = <deep copy of the source rule> }
local pasteSel = {}           -- section key -> true (shared by the Rule tab, folder pages and the right-click menu)
local PASTE_ORDER = { "ids", "states", "talents", "load", "display", "position", "textDur", "textCnt", "textAbs", "sound" }
local PASTE_LABELS = {
    ids = "Trigger: Spell ID, Max Charges and Aura ID",
    states = "Conditions: Cooldown State and Buff State",
    talents = "Talents (Requirement Mode and List)",
    load = "Load Conditions (Never / Always / Match, Combat, Group, Raid...)",
    display = "Display: Texture, Overlay, Opacity, Fade, Glow, Outline, Border (not Position or Text)",
    position = "Display: Position (X / Y)",
    textDur = "Text: Buff Duration",
    textCnt = "Text: Stacks / Charges Count",
    textAbs = "Text: Shield / Absorb Amount",
    sound = "Audio: Sound, Channel and Repeat",
}
local function PasteApply(key, dst, src)
    local C = ns.Copy
    if key == "ids" then dst.spellID, dst.maxCharges, dst.buffID = src.spellID, src.maxCharges, src.buffID
    elseif key == "states" then dst.cdState, dst.buffState = src.cdState, src.buffState
    elseif key == "talents" then dst.talents, dst.talentMode = C(src.talents or {}), src.talentMode
    elseif key == "load" then dst.load = C(src.load or {})
    elseif key == "display" then
        for k, val in pairs(src.visual or {}) do
            if k ~= "text" and k ~= "count" and k ~= "absorb" and k ~= "x" and k ~= "y" then dst.visual[k] = C(val) end
        end
    elseif key == "position" then dst.visual.x, dst.visual.y = src.visual.x, src.visual.y
    elseif key == "textDur" then dst.visual.text = C(src.visual.text)
    elseif key == "textCnt" then dst.visual.count = C(src.visual.count)
    elseif key == "textAbs" then dst.visual.absorb = C(src.visual.absorb)
    elseif key == "sound" then dst.sound, dst.repeatSec = C(src.sound), src.repeatSec end
end
local function PasteSelectedLabels()
    local l = {}
    for _, k in ipairs(PASTE_ORDER) do if pasteSel[k] then l[#l + 1] = PASTE_LABELS[k]:match("^[^:(]+:?%s*[^(]*") or PASTE_LABELS[k] end end
    return l
end
local function PasteCount() local n = 0; for _, k in ipairs(PASTE_ORDER) do if pasteSel[k] then n = n + 1 end end return n end
-- returns true if something was pasted
local function PasteInto(dst)
    if not ruleClip or PasteCount() == 0 then return false end
    for _, k in ipairs(PASTE_ORDER) do if pasteSel[k] then PasteApply(k, dst, ruleClip.data) end end
    pcall(ns.RefreshVisual, dst)
    ns.MarkDirty()
    return true
end
local function PasteSummary()
    local names = {}
    for _, k in ipairs(PASTE_ORDER) do if pasteSel[k] then names[#names + 1] = PASTE_LABELS[k] end end
    return table.concat(names, "; ")
end

-- which banners (Display Options / Text / Sound) are expanded, per rule; everything starts collapsed
local bannerOpen = setmetatable({}, { __mode = "k" })

local function BuildRule(i, rule)
    local V = rule.visual
    local function on() Changed(rule) end

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
            cdState = Sel(rule, "cdState", "State", 4, CD_VALUES, CD_ORDER, on, { width = "double" }),
            maxCharges = Rng(rule, "maxCharges", "Max charges override (0 = auto)", 5, 0, 6, 1, on,
                { desc = "Only used if the game reports no charge data. Auto-detection normally wins." }),
            detected = { type = "description", order = 6, width = "full", name = function() return DetectedMax(rule.spellID) end },
            buffHeader = { type = "header", name = "Buff / Aura", order = 10 },
            buffID = {
                type = "input", name = "Aura spell ID", order = 11, width = "half",
                get = function() return tostring(rule.buffID) end,
                set = function(_, v) rule.buffID = tonumber(v) or 0; Changed(rule); Notify() end,
            },
            buffName = { type = "description", order = 12, width = "double", fontSize = "medium",
                name = function() return SpellName(rule.buffID) end },
            buffState = Sel(rule, "buffState", "State", 13, BUFF_VALUES, BUFF_ORDER, on, { width = "double" }),
        },
    }

    ------------------------------------------------------------ Conditions
    local function noMatch() local m = rule.load.mode; return m == "never" or m == "always" end
    local loadArgs = {
        talentUse = { type = "toggle", name = "Talents", order = 1, width = "double",
            desc = "Tick to require certain talents. Unticked = talents are ignored. The talent list appears below once ticked.",
            get = function() return rule.talentMode == "all" or rule.talentMode == "any" end,
            set = function(_, v)
                if v then
                    if rule.talentMode ~= "all" and rule.talentMode ~= "any" then rule.talentMode = "any" end
                    bannerOpen[rule] = bannerOpen[rule] or {}; bannerOpen[rule].talents = true
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
            open = { type = "toggle", name = "Show options", order = 1,
                desc = "Expand or collapse the talent list. Collapsing never changes any setting.",
                get = function() return bannerOpen[rule] and bannerOpen[rule].talents and true or false end,
                set = function(_, v) bannerOpen[rule] = bannerOpen[rule] or {}; bannerOpen[rule].talents = v and true or nil; Notify() end },
            body = { type = "group", inline = true, name = "", order = 2,
                hidden = function() return not (bannerOpen[rule] and bannerOpen[rule].talents) end, args = talentBody },
        } }
    loadArgs.loadHeader = { type = "header", name = "When Should This Rule Load?", order = 0 }
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
    loadArgs.classHeader = { type = "header", name = "Specialization / Role", order = 70, hidden = noMatch }
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
                open = { type = "toggle", name = "Show options", order = 1,
                    desc = "Expand or collapse the instance options. Collapsing never changes any setting.",
                    get = function() return bannerOpen[rule] and bannerOpen[rule].instance and true or false end,
                    set = function(_, v) bannerOpen[rule] = bannerOpen[rule] or {}; bannerOpen[rule].instance = v and true or nil; Notify() end },
                body = { type = "group", inline = true, name = "", order = 2,
                    hidden = function() return not (bannerOpen[rule] and bannerOpen[rule].instance) end, args = instBody },
            } }
        -- ticking Instance (green "In An Instance") opens the group, like ticking Talents
        local prevSet = loadArgs.tri_instance.set
        loadArgs.tri_instance.set = function(info, v)
            prevSet(info, v)
            if rule.load.instance == "yes" then bannerOpen[rule] = bannerOpen[rule] or {}; bannerOpen[rule].instance = true end
        end
    end
    loadArgs.specs = TriGroup("Specialization", 71, noMatch, specSet, SpecChoices(), onSpecRole)
    loadArgs.roles = TriGroup("Role", 72, noMatch, roleSet, RoleChoices(), onSpecRole)
    -- A folder's Never / Always overrides this rule's load mode and match conditions (talents still apply). Values stay stored.
    local function folderLoadOv() return ns.FolderLoadOverride(rule) end
    loadArgs.folderOv = { type = "description", order = 0.2, width = "full", fontSize = "medium",
        hidden = function() return not folderLoadOv() end,
        name = function()
            local ov, of = folderLoadOv()
            if not ov then return "" end
            return "|cffffd100Overridden by folder " .. tostring(of and of.name) .. "|r: " .. (ov == "never" and "Never" or "Always")
                .. ". Your own load settings below are kept and apply again if this rule leaves the folder. Talents still apply."
        end }
    local lockKeys = { "instanceTypes", "specs", "roles" }
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
    local tex = {
        type = "group", inline = true, name = "Texture", order = 10, args = {
            kind = Sel(V, "kind", "Source", 1, TEX_KIND, TEX_KIND_ORDER, function() Changed(rule); Notify() end, { width = "double" }),
            tex = { type = "input", name = "Texture ID / path / atlas name", order = 2, width = "double",
                hidden = function() return V.kind == "spellicon" end,
                get = function() return tostring(V.tex or "") end,
                set = function(_, v) V.tex = v; Changed(rule) end },
            preset = { type = "select", name = "Or pick art (Blizzard alerts + your Media\\Graphics)", order = 3, width = "double",
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
            w = Rng(V, "w", "Width", 11, 8, 512, 1, on),
            h = Rng(V, "h", "Height", 12, 8, 512, 1, on),
            rotation = Rng(V, "rotation", "Rotation (degrees)", 14, 0, 360, 1, on,
                { desc = "Rotates the art about its centre. Works best on square sizes; a square image shrinks slightly at diagonal angles so it is never cropped." }),
            flipH = Tog(V, "flipH", "Mirror (flip horizontally)", 15, on),
            flipV = Tog(V, "flipV", "Flip vertically", 16, on),
            zoom = Rng(V, "zoom", "Zoom / crop edges", 17, 0, 0.3, 0.01, on),
            colorH = { type = "header", name = "Colour & Blend", order = 20 },
            additive = Tog(V, "additive", "Additive blend", 21, on),
            desaturate = Tog(V, "desaturate", "Desaturate the base texture", 22, on,
                { width = "double", desc = "Removes the art's own colours first. On its own this greys it; with a tint below it gives an even, precise recolour (the tint multiplies the grey art)." }),
            recolor = Tog(V, "recolor", "Tint the base texture", 23, on,
                { desc = "Multiplies the (optionally desaturated) art by this colour. With 'Additive blend' on, the colour is tinted before it is added to the screen." }),
            tint = Col(V, "tint", "Tint colour", 23.5, on, { disabled = function() return not V.recolor end }),
            fadeH = { type = "header", name = "Fade, Opacity & Flash as the Buff Runs Out", order = 30 },
            fadeGrey = Tog(V, "fadeGrey", "Fade gradually as the buff runs out", 31, on, { width = "double",
                desc = "Uses the Aura spell ID from the Trigger tab. Uses readable aura times; when Blizzard hides them (combat) it tries Blizzard's duration-object curves (experimental). Needs the aura present, so set Show to 'While the buff is present'. Preview shows a sample cycle." }),
            fadeMode = Sel(V, "fadeMode", "Fade to", 32, { none = "(none - grey)", color = "A colour", transparent = "Transparent" }, { "none", "color", "transparent" }, on,
                { disabled = function() return not V.fadeGrey end }),
            fadeColor = Col(V, "fadeColor", "Fade colour", 33, on,
                { disabled = function() return not (V.fadeGrey and ns.Val(V.fadeMode) == "color") end }),
            flashOn = Tog(V.flash, "enabled", "Flash when about to expire", 34, on, { width = "double" }),
            flashAt = Rng(V.flash, "threshold", "Start flashing at (seconds left)", 35, 1, 15, 0.5, on,
                { disabled = function() return not V.flash.enabled end }),
            flashSpeed = Rng(V.flash, "speed", "Flash speed (pulses per second)", 36, 1, 8, 0.5, on,
                { disabled = function() return not V.flash.enabled end }),
            desatOnCD = Tog(V, "desatOnCD", "Grey out while the spell is on cooldown", 37, on, { width = "double" }),
            fxH = { type = "header", name = "Glow & Outline", order = 40 },
            glow = Tog(V, "glow", "Pulsing glow", 41, on),
            olOn = Tog(V.outline, "enabled", "Outline glow (follows the shape)", 42, on, { width = "double" }),
            olWidth = Rng(V.outline, "width", "Outline width (px)", 43, 1, 10, 1, on, { disabled = function() return not V.outline.enabled end }),
            olColor = Col(V.outline, "color", "Outline colour", 44, on, { disabled = function() return not V.outline.enabled end }),
            olPulse = Tog(V.outline, "pulse", "Pulse the outline", 45, on, { disabled = function() return not V.outline.enabled end }),
            frameH = { type = "header", name = "Border & Background", order = 50 },
            bdOn = Tog(V.border, "enabled", "Border", 51, on),
            bdSize = Rng(V.border, "size", "Border size (px)", 52, 1, 8, 1, on, { disabled = function() return not V.border.enabled end }),
            bdColor = Col(V.border, "color", "Border colour", 53, on, { disabled = function() return not V.border.enabled end }),
            bgOn = Tog(V.bg, "enabled", "Background fill", 54, on),
            bgColor = Col(V.bg, "color", "Background colour", 55, on, { disabled = function() return not V.bg.enabled end }),
        },
    }
    local OV = V.overlay
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
                hidden = function() return not (OV.enabled and ns.Val(OV.source) == "other") or OV.kind == "spellicon" end,
                values = function() EnsureTextures(); return texValues end,
                sorting = function() EnsureTextures(); return texSorting end,
                get = function() if OV.kind == "file" then return tostring(OV.tex) end end,
                set = function(_, k)
                    if k == "0" then OV.tex = "" else OV.kind, OV.tex = "file", k end
                    Changed(rule); Notify()
                end },
            tint = Col(OV, "tint", "Overlay tint colour", 6, on, { disabled = function() return not OV.enabled end }),
            desaturate = Tog(OV, "desaturate", "Desaturate the overlay first", 7, on,
                { width = "double", disabled = function() return not OV.enabled end }),
            additive = Tog(OV, "additive", "Additive blend for the overlay", 8, on,
                { width = "double", disabled = function() return not OV.enabled end }),
            note = { type = "description", order = 9, width = "full", fontSize = "small",
                name = "The overlay shares the base's size, rotation, mirror and zoom. Tint the base underneath (or desaturate it) on the Colour & blend line above; opacity of each layer is set under Opacity & fill." },
        },
    }
    local FL = V.fill
    local FILL_DIR = { none = "(none - shrinks toward the bottom)", bottom = "Shrinks toward the bottom", top = "Shrinks toward the top",
        left = "Shrinks toward the left", right = "Shrinks toward the right" }
    local opacity = {
        type = "group", inline = true, name = "Opacity & Fill", order = 12, args = {
            alpha = Rng(V, "alpha", "Overall opacity (everything)", 1, 0, 1, 0.05, on),
            texAlpha = Rng(V, "texAlpha", "Base texture opacity", 2, 0, 1, 0.05, on),
            ovAlpha = Rng(OV, "alpha", "Overlay opacity", 3, 0, 1, 0.05, on, { disabled = function() return not OV.enabled end }),
            oocAlpha = Rng(V, "oocAlpha", "Opacity multiplier out of combat", 4, 0, 1, 0.05, on, { width = "double" }),
            fadeH = { type = "header", name = "Fade Opacity as the Buff Runs Out", order = 10 },
            fadeAlpha = Tog(V, "fadeAlpha", "Fade opacity", 11, on, { width = "double",
                desc = "Opacity multiplier goes from the value at full duration to the value at expiry. Independent of the grey / colour fade. Needs the aura present: set 'Show' to 'While the buff is present'." }),
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
        },
    }
    local pos = {
        type = "group", inline = true, name = "Position (Offset From Screen Centre)", order = 20, args = {
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
    local cntArgs = TextStyleArgs(C, on, 10)
    cntArgs.enabled = Tog(C, "enabled", "Show a count", 1, on, { desc = "Aura stacks or spell charges. Experimental under Midnight secrecy: the number can only be displayed, not compared." })
    cntArgs.source = Sel(C, "source", "Count of", 2, COUNT_SOURCE, COUNT_SOURCE_ORDER, on)
    local AB = V.absorb
    local absArgs = TextStyleArgs(AB, on, 10)
    absArgs.enabled = Tog(AB, "enabled", "Show shield / absorb amount", 1, on, { desc = "Experimental under Midnight secrecy: the amount can only be displayed, not compared or used as a condition." })
    absArgs.source = Sel(AB, "source", "Amount from", 2, ABSORB_SOURCE, ABSORB_SOURCE_ORDER, on)
    absArgs.abbreviate = Tog(AB, "abbreviate", "Abbreviate (12.3K / 1.2M)", 3, on)
    absArgs.hideZero = Tog(AB, "hideZero", "Hide when zero", 4, on, { desc = "Only works when the number is readable; a secret amount is shown as-is." })
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

    -- Collapsible banners: an enable tick box + a "Show options" tick box; the options only render while open.
    local function Banner(key, name, order, enableArg, bodyArgs)
        local function st() bannerOpen[rule] = bannerOpen[rule] or {}; return bannerOpen[rule] end
        enableArg.order = 1
        return {
            type = "group", inline = true, name = name, order = order, args = {
                enable = enableArg,
                open = { type = "toggle", name = "Show options", order = 2,
                    desc = "Expand or collapse this banner's options. Collapsing never changes any setting.",
                    get = function() return st()[key] and true or false end,
                    set = function(_, v) st()[key] = v and true or nil; Notify() end },
                body = { type = "group", inline = true, name = "", order = 10,
                    hidden = function() return not st()[key] end, args = bodyArgs },
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
                hdr = { type = "execute", order = 1, width = "full",
                    name = function() return (subst()[key] and ARROW_OPEN or ARROW_CLOSED) .. "  " .. title end,
                    desc = "Expand or collapse this section. Collapsing never changes any setting.",
                    func = function() subst()[key] = (not subst()[key]) or nil; Notify() end },
                body = { type = "group", inline = true, name = "", order = 2,
                    hidden = function() return not subst()[key] end, args = args },
            },
        }
    end
    -- Texture box: position sits above Size & Orientation; "Add Overlay Layer" lives here and reveals the overlay
    tex.args.addOverlay = Tog(OV, "enabled", "Add Overlay Layer", 4, function() Changed(rule); Notify() end, { width = "double",
        desc = "Adds a second texture layer directly below this box that you can tint separately." })
    overlay.args.enabled = nil
    tex.args.posH = { type = "header", name = "Position (Offset From Screen Centre)", order = 4.5 }
    pos.args.x.order, pos.args.y.order, pos.args.unlock.order = 4.6, 4.7, 4.8
    tex.args.x, tex.args.y, tex.args.unlock = pos.args.x, pos.args.y, pos.args.unlock
    display.args.trigger.order = 0
    local dispBody = { trigger = display.args.trigger,
        pausePv = { type = "toggle", name = "Pause preview animations", order = 0.5, width = "double",
            desc = "Freezes the sample countdown, the fades and the flash in every preview while the images stay on screen. Untick to resume.",
            get = function() return ns.previewPaused end,
            set = function(_, v) ns.SetPreviewPaused(v); Notify() end },
        texture = Sub("texture", "Texture", 1, tex.args),
        overlay = Sub("overlay", "Overlay Layer", 2, overlay.args, function() return not OV.enabled end),
        opacity = Sub("opacity", "Opacity & Fill", 3, opacity.args) }
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
    local actions = { type = "group", name = "Conditions", order = 3, args = {
        display = Banner("display", "Display Options", 1, display.args.enabled, dispBody),
        text = Banner("text", "Text", 2, textEnable, {
            dur = Sub("dur", "Buff Duration Text", 1, durArgs),
            cnt = Sub("cnt", "Stacks / Charges Count", 2, cntArgs),
            abs = Sub("abs", "Shield / Absorb Amount", 3, absArgs),
        }),
        sound = Banner("sound", "Sound", 3, soundEnable, soundBody),
    } }

    ---------------------------------------------------------------- Rule tab
    local ruleTab = {
        type = "group", name = "Rule", order = 1, args = {
            name = { type = "input", name = "Name", order = 1, width = "double",
                get = function() return rule.name end,
                set = function(_, v) if v ~= "" then rule.name = v end; Notify() end },
            enabled = { type = "toggle", name = "Enabled", order = 2,
                get = function() return rule.enabled end,
                set = function(_, v) rule.enabled = v; Changed(rule); Notify() end },
            folder = {
                type = "select", name = "Folder", order = 3, width = "double",
                values = function() local v = FolderValues(); return v end,
                sorting = function() local _, o = FolderValues(); return o end,
                get = function() return rule.folder or "none" end,
                set = function(_, v)
                    rule.folder = (v ~= "none") and v or nil
                    Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, RulePath(rule))
                end,
            },
            status = { type = "description", order = 4, width = "full", fontSize = "medium", name = function() return StatusText(rule) end },
            refresh = { type = "execute", name = "Refresh status", order = 5, func = Notify },
            delete = {
                type = "execute", name = "Delete this rule", order = 9,
                confirm = true, confirmText = "Delete this rule?",
                func = function()
                    for idx, r in ipairs(ns.rules) do
                        if r == rule then table.remove(ns.rules, idx); break end
                    end
                    ns.DropVisual(rule)
                    ns.MarkDirty()
                    Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "all")
                end,
            },
        },
    }

    return {
        type = "group", childGroups = "tab", order = 1000 + i,
        name = function() return (rule.enabled and "" or "|cff888888") .. rule.name end,
        args = { rule = ruleTab, trigger = trigger, load = load, actions = actions },
    }
end

local function TokenHelp()
    local t = { "Tokens you can use (case-insensitive):" }
    for _, k in ipairs(ns.QOL_STAT_ORDER) do t[#t + 1] = "{" .. k .. "}  " .. ns.QOL_STATS[k].desc end
    t[#t + 1] = "WoW colour codes also work in the format, e.g. typing |cffffd100||cffffd100gold||r|r shows |cffffd100gold|r."
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
            color = { type = "color", name = "Colour", order = 14, hasAlpha = true,
                get = function() local c = box.color or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] or 1 end,
                set = function(_, r, g, b, a) box.color = { r, g, b, a }; ns.QoL_Refresh(box) end },
            alpha = { type = "range", name = "Opacity", order = 15, min = 0.05, max = 1, step = 0.05,
                get = function() return box.alpha end, set = function(_, v) box.alpha = v; ns.QoL_Refresh(box) end },
            decimals = { type = "range", name = "Decimals on percentages", order = 16, min = 0, max = 2, step = 1,
                get = function() return box.decimals end, set = function(_, v) box.decimals = v; ns.QoL_Refresh(box) end },
            showCombat = { type = "select", name = "Show", order = 17, values = SHOW_COMBAT, sorting = SHOW_COMBAT_ORDER,
                get = function() return box.showCombat end, set = function(_, v) box.showCombat = v; ns.QoL_Refresh(box) end },
            posHeader = { type = "header", name = "Position (Offset From Screen Centre)", order = 20 },
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
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "bars", "allbars")
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
            colH = { type = "header", name = "Texture & Colours", order = 10 },
            texture = Sel(bar, "texture", "Bar texture", 11, function() local v = ns.BarTextureList(); return v end,
                function() local _, o = ns.BarTextureList(); return o end, on, { width = "double" }),
            fill = Col(bar, "fillColor", "Fill colour", 12, on),
            bg = Col(bar, "bgColor", "Background colour", 13, on),
            spark = Tog(bar, "spark", "Show spark", 14, on),
            borderH = { type = "header", name = "Border", order = 20 },
            borderSize = Rng(bar, "borderSize", "Border size (px, 0 = none)", 21, 0, 8, 1, on),
            borderColor = Col(bar, "borderColor", "Border colour", 22, on),
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
local importText, importMode, importSnap, importErr = "", nil, nil, nil
local profileName, profileMsg = "", ""

local function ParseImport()
    importSnap, importErr = nil, nil
    if (importText or ""):match("%S") then
        importSnap, importErr = ns.Profile_Decode(importText)
    end
end

local function BuildProfiles()
    local a = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Your rules are personal. Nothing is shared unless you export it, and a fresh install starts empty. Export produces a text string you can paste to a friend; they paste it under 'Import' to add it to their own setup." },
        exportH = { type = "header", name = "Export What You Have", order = 1 },
        incRules = Tog(exportInc, "rules", "Cooldown + Aura rules (with their folders)", 2, function() end, { width = "double" }),
        incBars = Tog(exportInc, "bars", "Buff bars (and their group layout)", 3, function() end, { width = "double" }),
        incQol = Tog(exportInc, "qol", "QoL elements", 4, function() end, { width = "double" }),
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
        importMode = { type = "select", name = "How to import", order = 13, width = "double",
            values = IMPORT_MODE, sorting = IMPORT_MODE_ORDER,
            get = function() return importMode end, set = function(_, v) importMode = v end },
        importGo = { type = "execute", name = "Import", order = 14, width = "half",
            disabled = function() return not (importSnap and importMode) end,
            confirm = function() return importMode == "replace" end,
            confirmText = "Replace the included parts of your current setup? This cannot be undone.",
            func = function()
                local c = ns.Profile_Apply(importSnap, importMode)
                profileMsg = ("Imported %d rule(s), %d folder(s), %d bar(s), %d QoL box(es)."):format(c.rules, c.folders, c.bars, c.qol)
                ns.Print(profileMsg)
                Notify()
            end },
        msg = { type = "description", order = 15, width = "full", name = function() return profileMsg end },
        savedH = { type = "header", name = "Profiles Saved on This Computer", order = 20 },
        saveName = { type = "input", name = "Profile name", order = 21, width = "double",
            get = function() return profileName end, set = function(_, v) profileName = v or "" end },
        save = { type = "execute", name = "Save current setup", order = 22, width = "double",
            desc = "Saves a snapshot of the parts ticked under Export. Saving with an existing name updates it.",
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
    return { type = "group", name = "Profiles", order = 6, args = a }
end

-------------------------------------------------------------------------------
-- Top level: horizontal tabs. Each of the first three has a tree with an "All" node.
-------------------------------------------------------------------------------
local newOpts = { sound = false, visual = false } -- what "+ New rule" turns on

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
        name = "Apply Text Settings to All Rules in This Folder",
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Choose which text elements to change and what to change, then press Apply. A blank choice (or 0) leaves that setting alone. Includes rules in subfolders. Nothing is changed until you press Apply." },
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
                confirm = true, confirmText = "Overwrite the chosen text settings on every rule in this folder (and its subfolders)?",
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
                    ns.Print(("applied text settings to %d rule(s) in folder '%s'"):format(n, f.name))
                end },
        },
    }
end

local LOAD_OV_VALUES = {
    none = "Don't Override (Each Rule Uses Its Own Load Conditions)",
    never = "Never (No Rule in This Folder Loads)",
    always = "Always (Ignore Each Rule's Load Conditions)",
}
local LOAD_OV_ORDER = { "none", "never", "always" }
local function FolderLoadGroup(f)
    local g = {
        type = "group", inline = true, order = 5.5, name = "Load Conditions for This Folder",
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Overrides the Load tab of every rule in this folder and its subfolders while they are inside it. Nothing on the rules is changed: a rule that leaves the folder uses its own load conditions again. Talent requirements still apply. A subfolder's own choice beats the folder above it." },
            inherited = { type = "description", order = 2, width = "full", fontSize = "medium",
                hidden = function() if f.loadOverride then return true end; return not ns.FolderLoadOverrideFrom(f.parent) end,
                name = function()
                    local ov, of = ns.FolderLoadOverrideFrom(f.parent)
                    if not ov then return "" end
                    return "Inherited from folder |cffffd100" .. tostring(of and of.name) .. "|r: " .. (ov == "never" and "Never" or "Always")
                end },
        },
    }
    AddSquareRadio(g.args, "mode", 0.9, LOAD_OV_VALUES, LOAD_OV_ORDER,
        function() return f.loadOverride or "none" end,
        function(v) f.loadOverride = (v == "never" or v == "always") and v or nil; ns.MarkDirty(); Notify() end)
    return g
end

local function BuildFolder(k, f)
    local dinfo, dpos = ns.DefaultFolderInfo(f.default)
    return {
        type = "group", order = dpos and (10 + dpos) or (100 + k),
        name = function() return (f.parent and f.name or tostring(f.name):upper()) .. " (" .. FolderRuleCount(f) .. ")" end,
        args = {
            name = { type = "input", name = "Folder name", order = 1, width = "double",
                get = function() return f.name end, set = function(_, v) if v ~= "" then f.name = v end; Notify() end },
            newRule = { type = "execute", name = "+ New rule in this folder", order = 2, width = "double",
                func = function()
                    local r = ns.NewRule()
                    r.name = "Rule " .. (#ns.rules + 1)
                    r.folder = f.id
                    r.sound.enabled = newOpts.sound and true or false
                    r.visual.enabled = newOpts.visual and true or false
                    ns.rules[#ns.rules + 1] = r
                    Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, RulePath(r))
                end },
            newSub = { type = "execute", name = "+ New subfolder", order = 2.5, width = "double",
                func = function()
                    local nf = ns.NewFolder("Folder " .. (#ns.folders + 1), f.id)
                    Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, FolderPath(nf))
                end },
            enableAll = { type = "execute", name = "Enable all rules in this folder (and subfolders)", order = 3, width = "double",
                func = function() for _, r in ipairs(FolderRules(f.id)) do r.enabled = true; ns.RefreshVisual(r) end; ns.MarkDirty(); Notify() end },
            disableAll = { type = "execute", name = "Disable all rules in this folder (and subfolders)", order = 4, width = "double",
                func = function() for _, r in ipairs(FolderRules(f.id)) do r.enabled = false; ns.RefreshVisual(r) end; ns.MarkDirty(); Notify() end },
            note = { type = "description", order = 5, width = "full", fontSize = "small",
                name = "Use the eye and headphone icons next to this folder in the sidebar to preview every rule inside it at once." },
            defaultNote = { type = "description", order = 5.2, width = "full", fontSize = "small",
                hidden = function() return not dinfo end, name = dinfo and dinfo.note or "" },
            loadOverride = FolderLoadGroup(f),
            applyText = FolderApplyGroup(f),
            delete = { type = "execute", name = "Delete folder (contents move up one level)", order = 9, width = "double",
                confirm = true, confirmText = "Delete this folder? The rules and subfolders inside are kept and move up one level.",
                func = function()
                    for _, r in ipairs(ns.rules) do if r.folder == f.id then r.folder = f.parent end end
                    for _, ff in ipairs(ns.folders) do if ff.parent == f.id then ff.parent = f.parent end end
                    for idx, ff in ipairs(ns.folders) do if ff == f then table.remove(ns.folders, idx); break end end
                    Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "all")
                end },
        },
    }
end

local function BuildOptions()
    ---------------------------------------------------------- Cooldown + Aura Tracking
    local all = {
        type = "group", name = "ALL RULES", order = 1, childGroups = "tree",
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Rules that watch a cooldown, a buff and your talents, then play a sound and/or show a texture. Pick a rule on the left, or add one. The eye and headphone icons in the sidebar preview a rule (or a whole folder / everything) without changing it." },
            newRule = { type = "execute", name = "+ New rule", order = 1,
                func = function()
                    local r = ns.NewRule()
                    r.name = "Rule " .. (#ns.rules + 1)
                    r.sound.enabled = newOpts.sound and true or false
                    r.visual.enabled = newOpts.visual and true or false
                    ns.rules[#ns.rules + 1] = r
                    Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, RulePath(r))
                end },
            newFolder = { type = "execute", name = "+ New folder", order = 2,
                func = function()
                    local f = ns.NewFolder("Folder " .. (#ns.folders + 1))
                    Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "all", f.id)
                end },
            newSound = { type = "toggle", name = "New rules play a sound", order = 3, width = "double",
                desc = "Applied when you press + New rule. Off by default; you can still change it on the rule's Conditions tab.",
                get = function() return newOpts.sound end, set = function(_, v) newOpts.sound = v end },
            newVisual = { type = "toggle", name = "New rules show a texture / icon", order = 4, width = "double",
                desc = "Applied when you press + New rule. Off by default; you can still change it on the rule's Conditions tab.",
                get = function() return newOpts.visual end, set = function(_, v) newOpts.visual = v end },
            unlock = { type = "execute", order = 5, width = "double",
                name = function() return ns.unlocked and "Lock visuals" or "Unlock visuals (drag on screen)" end,
                func = function() ns.ToggleUnlock(); Notify() end },
            pausePv = { type = "toggle", name = "Pause preview animations", order = 5.2, width = "double",
                desc = "Freezes the sample countdown, the fades and the flash in every preview and unlocked display while the images stay on screen. Untick to resume.",
                get = function() return ns.previewPaused end,
                set = function(_, v) ns.SetPreviewPaused(v); Notify() end },
            defaults = { type = "execute", name = "Add Default Categories", order = 5.5, width = "double",
                desc = "Adds any of Display Cues, Sound Cues and Advanced Rule Tracking that are missing at the top level. Existing folders and rules are not touched.",
                func = function()
                    local n = ns.EnsureDefaultFolders(true)
                    ns.Print(n > 0 and ("added " .. n .. " default categor" .. (n == 1 and "y" or "ies")) or "the default categories are already there")
                    Notify()
                end },
            seed = { type = "execute", name = "Add Vengeance DH test rules", order = 6, width = "double",
                func = function() ns.SeedRules() end },
        },
    }
    local groups = {}
    for k, f in ipairs(ns.folders or {}) do groups[f.id] = BuildFolder(k, f) end
    for _, f in ipairs(ns.folders or {}) do
        local parent = f.parent and groups[f.parent]
        if parent and (f.parent == f.id or IsInFolder(f.parent, f.id)) then f.parent = nil; parent = nil end  -- break cycles
        if parent then parent.args[f.id] = groups[f.id] else all.args[f.id] = groups[f.id] end
    end
    local okc, ctx = pcall(ns.ReadContext)
    local loadedArgs, notArgs, nLoaded, nNot = {}, {}, 0, 0
    for i, rule in ipairs(ns.rules or {}) do
        local g = BuildRule(i, rule)
        local fld = rule.folder and groups[rule.folder]
        if fld then fld.args["rule" .. i] = g else all.args["rule" .. i] = g end
        if okc and ns.IsLoaded(rule, ctx) then loadedArgs["rule" .. i] = g; nLoaded = nLoaded + 1
        else notArgs["rule" .. i] = g; nNot = nNot + 1 end
    end
    loadedArgs.info = { type = "description", order = 0, width = "full", fontSize = "medium",
        name = "Rules that are enabled and whose load conditions and talents match right now (cooldown / buff state is not part of this). Same rules as under All Rules; this list updates as your situation changes." }
    notArgs.info = { type = "description", order = 0, width = "full", fontSize = "medium",
        name = "Rules that are disabled, or whose load conditions or talents do not match right now." }
    -- Loaded / Not Loaded are the topmost root rows of the All Rules tree (siblings above ALL RULES)
    all.order = 3
    local track = { type = "group", name = "All Rules", order = 1, childGroups = "tree", args = {
        loaded = { type = "group", order = 1, childGroups = "tree",
            name = function() return "LOADED (" .. nLoaded .. ")" end, args = loadedArgs },
        notloaded = { type = "group", order = 2, childGroups = "tree",
            name = function() return "NOT LOADED (" .. nNot .. ")" end, args = notArgs },
        all = all } }

    ---------------------------------------------------------- Buff Bars
    local allBars = {
        type = "group", name = "ALL BARS", order = 1, childGroups = "tree",
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Timer bars for buffs on you. Layout options below apply to the whole group. The eye icon in the sidebar previews a bar (or all of them)." },
            pausePv = { type = "toggle", name = "Pause preview animations", order = 1.5, width = "double",
                desc = "Freezes the sample countdown, the fades and the flash in every preview and unlocked display while the images stay on screen. Untick to resume.",
                get = function() return ns.previewPaused end,
                set = function(_, v) ns.SetPreviewPaused(v); Notify() end },
            newBar = { type = "execute", name = "+ New buff bar", order = 1, width = "double",
                func = function()
                    ns.Bars_NewBar(); Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "bars", "allbars", "bar" .. #ns.bars)
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
    for i, bar in ipairs(ns.bars or {}) do allBars.args["bar" .. i] = BuildBar(i, bar) end
    local bars = { type = "group", name = "Buff Bars", order = 4, childGroups = "tree", args = { allbars = allBars } }

    ---------------------------------------------------------- QoL
    local allQol = {
        type = "group", name = "ALL BOXES", order = 1, childGroups = "tree",
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
    for i, box in ipairs(ns.qolBoxes or {}) do allQol.args["box" .. i] = BuildBox(i, box) end
    local qol = { type = "group", name = "QoL Elements", order = 5, childGroups = "tree", args = { allqol = allQol } }

    return { type = "group", name = "XayaUI", childGroups = "tab",
        args = { cooldowns = track, bars = bars, qol = qol, profiles = BuildProfiles() } }
end

AceConfigRegistry:RegisterOptionsTable(APP, BuildOptions)
AceConfigDialog:SetDefaultSize(APP, 1000, 680)

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
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "all")
        end
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
local function Resolve(uv)
    if not uv then return nil end
    local last = uv:match("([^\001]+)$") or uv
    if last == "all" then
        local l = {}
        for _, r in ipairs(ns.rules or {}) do l[#l + 1] = r end
        return l, l
    elseif last == "allbars" then
        local l = {}
        for _, b in ipairs(ns.bars or {}) do l[#l + 1] = b end
        return l, nil
    end
    local n = last:match("^rule(%d+)$")
    if n then local r = ns.rules and ns.rules[tonumber(n)]; if r then return { r }, { r } end return nil end
    n = last:match("^bar(%d+)$")
    if n then local b = ns.bars and ns.bars[tonumber(n)]; if b then return { b }, nil end return nil end
    if last:match("^f%d") then
        local l = FolderRules(last)
        return l, l
    end
    if last == "loaded" or last == "notloaded" then
        local l = {}
        local okc, ctx = pcall(ns.ReadContext)
        for _, r in ipairs(ns.rules or {}) do
            if (okc and ns.IsLoaded(r, ctx) or false) == (last == "loaded") then l[#l + 1] = r end
        end
        return l, l
    end
end

local function GroupState(objs, kind)
    local on = 0
    for _, o in ipairs(objs) do if ns.IsPreview(o, kind) then on = on + 1 end end
    if on == 0 then return 0 elseif on == #objs then return 1 end
    return 0.5
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
        ns.SetPreview(objs, self.kind, on)
        if ns.DecorateTrees then ns.DecorateTrees() end
        Notify()
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
        if obj.folder == target then return end
        obj.folder = target
        ns.MarkDirty(); Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, RulePath(obj))
    else
        if obj.parent == target then return end
        obj.parent = target
        ns.MarkDirty(); Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, FolderPath(obj))
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

local function SelectRoot() pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "all") end

local function DeleteRule(rule)
    for idx, r in ipairs(ns.rules) do if r == rule then table.remove(ns.rules, idx); break end end
    ns.DropVisual(rule); ns.MarkDirty(); Notify(); SelectRoot()
end
local function DuplicateRule(rule)
    local c = ns.Copy(rule)
    c.name = ((rule.name and rule.name ~= "") and rule.name or "Rule") .. " Copy"
    ns.rules[#ns.rules + 1] = c
    pcall(ns.RefreshVisual, c)
    ns.MarkDirty(); Notify()
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, RulePath(c))
end
-- copies a folder with its rules and subfolders (children keep their names; the top copy gets " Copy")
local function DuplicateFolder(f, parentId, top)
    local nf = ns.NewFolder(f.name .. (top and " Copy" or ""), parentId)
    for _, r in ipairs(ns.rules) do
        if r.folder == f.id then
            local c = ns.Copy(r); c.folder = nf.id
            ns.rules[#ns.rules + 1] = c
            pcall(ns.RefreshVisual, c)
        end
    end
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

local function AddMoveMenu(root, obj, kind)
    local sub = root:CreateButton("Move To")
    sub:CreateButton("Top Level (All Rules)", function()
        if kind == "rule" then obj.folder = nil else obj.parent = nil end
        ns.MarkDirty(); Notify()
    end)
    for _, f in ipairs(ns.folders or {}) do
        if not (kind == "folder" and IsInFolder(f.id, obj.id)) then
            local depth = #FolderChain(f) - 1
            sub:CreateButton(string.rep("    ", depth) .. f.name, function()
                if kind == "rule" then obj.folder = f.id else obj.parent = f.id end
                ns.MarkDirty(); Notify()
                if kind == "rule" then pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, RulePath(obj))
                else pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, FolderPath(obj)) end
            end)
        end
    end
end

-- Copy / paste lives only in the right-click menu. Ticks are session-only; nothing is ticked by default, so nothing is overwritten
-- until sections are chosen. Returning MenuResponse.Refresh keeps the submenu open while ticking (unverified in game: if the
-- game ignores it, the menu simply closes after each tick).
local PASTE_MENU_LABELS = {
    ids = "Trigger: Spell ID, Max Charges, Aura ID", states = "Conditions: Cooldown + Buff State", talents = "Talents",
    load = "Load Conditions", display = "Display (Not Position or Text)", position = "Display: Position (X / Y)",
    textDur = "Text: Buff Duration", textCnt = "Text: Stacks / Charges Count", textAbs = "Text: Shield / Absorb Amount",
    sound = "Audio: Sound, Channel and Repeat",
}
local function AddPasteMenu(root, label, getTargets, describe)
    local sub = root:CreateButton(label)
    local refresh = MenuResponse and MenuResponse.Refresh
    sub:CreateTitle(ruleClip and ("Copied: " .. tostring(ruleClip.name)) or "Nothing copied yet (use Copy Settings)")
    for _, k in ipairs(PASTE_ORDER) do
        sub:CreateCheckbox(PASTE_MENU_LABELS[k] or k,
            function() return pasteSel[k] and true or false end,
            function() pasteSel[k] = (not pasteSel[k]) or nil; return refresh end)
    end
    sub:CreateDivider()
    sub:CreateButton("Select All Sections", function() for _, k in ipairs(PASTE_ORDER) do pasteSel[k] = true end; return refresh end)
    sub:CreateButton("Clear Selection", function() for _, k in ipairs(PASTE_ORDER) do pasteSel[k] = nil end; return refresh end)
    sub:CreateDivider()
    sub:CreateButton("Paste Selected Sections", function()
        if not ruleClip then ns.Print("nothing copied yet: right-click a rule and choose Copy Settings first") return end
        if PasteCount() == 0 then ns.Print("no sections selected: tick the sections to paste in the Paste Settings menu first") return end
        local targets = getTargets()
        local warn = (pasteSel.ids and #targets > 1) and "\n|cffff8040Trigger IDs are selected: every one of these rules will track the same spell and aura.|r" or ""
        AskConfirm("Overwrite these sections on " .. describe() .. " with settings from '" .. tostring(ruleClip.name) .. "'?\n" .. PasteSummary() .. warn,
            function()
                local n = 0
                for _, r in ipairs(targets) do if PasteInto(r) then n = n + 1 end end
                Notify(); ns.Print(("pasted into %d rule(s)"):format(n))
            end)
    end)
end

local function RowMenu(button, root)
    local last = LastKey(button.uniquevalue) or ""
    local n = last:match("^rule(%d+)$")
    local rule = n and ns.rules and ns.rules[tonumber(n)]
    if rule then
        root:CreateTitle((rule.name and rule.name ~= "") and rule.name or "Rule")
        root:CreateButton("Rename", function() AskRename(rule.name, function(t) rule.name = t; pcall(ns.RefreshVisual, rule); ns.MarkDirty(); Notify() end) end)
        root:CreateButton("Duplicate", function() DuplicateRule(rule) end)
        root:CreateButton("Copy Settings", function() ruleClip = { name = rule.name, data = ns.Copy(rule) }; Notify(); ns.Print("copied settings of '" .. tostring(rule.name) .. "'") end)
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
        root:CreateButton("Rename", function() AskRename(fold.name, function(t) fold.name = t; ns.MarkDirty(); Notify() end) end)
        root:CreateButton("New Rule Here", function()
            local r = ns.NewRule()
            r.name = "Rule " .. (#ns.rules + 1)
            r.folder = fold.id
            r.sound.enabled = newOpts.sound and true or false
            r.visual.enabled = newOpts.visual and true or false
            ns.rules[#ns.rules + 1] = r
            Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, RulePath(r))
        end)
        root:CreateButton("New Subfolder", function()
            local nf = ns.NewFolder("Folder " .. (#ns.folders + 1), fold.id)
            Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, FolderPath(nf))
        end)
        root:CreateButton("Duplicate", function()
            local nf = DuplicateFolder(fold, fold.parent, true)
            ns.MarkDirty(); Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, FolderPath(nf))
        end)
        root:CreateButton("Enable All Rules Inside", function() for _, r in ipairs(FolderRules(fold.id)) do r.enabled = true; pcall(ns.RefreshVisual, r) end; ns.MarkDirty(); Notify() end)
        root:CreateButton("Disable All Rules Inside", function() for _, r in ipairs(FolderRules(fold.id)) do r.enabled = false; pcall(ns.RefreshVisual, r) end; ns.MarkDirty(); Notify() end)
        AddPasteMenu(root, "Paste Settings Into Rules Here", function() return FolderRules(fold.id) end,
            function() return "every rule in '" .. tostring(fold.name) .. "' (and its subfolders)" end)
        AddMoveMenu(root, fold, "folder")
        root:CreateDivider()
        root:CreateButton("Delete Folder (Contents Move Up)", function()
            AskConfirm("Delete the folder '" .. fold.name .. "'? Its rules and subfolders are kept and move up one level.", function() DeleteFolder(fold) end)
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
                pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "bars", "allbars")
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
        root:CreateTitle("All Rules")
        root:CreateButton("New Rule", function()
            local r = ns.NewRule()
            r.name = "Rule " .. (#ns.rules + 1)
            r.sound.enabled = newOpts.sound and true or false
            r.visual.enabled = newOpts.visual and true or false
            ns.rules[#ns.rules + 1] = r
            Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, RulePath(r))
        end)
        root:CreateButton("New Folder", function()
            local nf = ns.NewFolder("Folder " .. (#ns.folders + 1))
            Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, FolderPath(nf))
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

-- Header rows (the root row and every top-level folder) get a tinted banner so each reads as its own group.
local BANNER_TINT = {
    root = { 1, 0.78, 0 }, loaded = { 0.1, 0.85, 0.75 }, notloaded = { 0.95, 0.2, 0.2 }, display = { 0.1, 0.5, 1 }, sound = { 0.1, 0.75, 0.3 }, advanced = { 0.75, 0.25, 1 }, other = { 0.7, 0.7, 0.75 },
}
local function BannerTint(uv)
    local last = uv and tostring(uv):match("([^\001]*)$")
    if last == "all" or last == "allbars" or last == "allboxes" then return BANNER_TINT.root end
    if last == "loaded" then return BANNER_TINT.loaded end
    if last == "notloaded" then return BANNER_TINT.notloaded end
    local f = last and ns.FolderById and ns.FolderById(last)
    if f and not f.parent then
        return (type(f.default) == "string" and BANNER_TINT[f.default]) or BANNER_TINT.other
    end
end
local function PaintBanner(button)
    local c = BannerTint(button.uniquevalue)
    -- Root rows (ALL RULES, LOADED, NOT LOADED, ALL BARS, ALL BOXES): one shared soft style, white text, thin outline,
    -- 15% smaller than the earlier bold look, drawn in small caps. WoW fonts have no small-caps feature, so the label is
    -- rebuilt from separate font strings: first letter of each word full size, the rest capitals at 80% size.
    local fs = button.text
    if fs and fs.GetFont then
        if not button.xuiFont then local f, sz, fl = fs:GetFont(); button.xuiFont = { f, sz, fl } end
        local uv = button.uniquevalue and tostring(button.uniquevalue)
        local isRoot = uv and (uv == "all" or uv == "allbars" or uv == "allboxes" or uv == "loaded" or uv == "notloaded") or false
        if isRoot then
            local text = fs:GetText() or ""
            local size = math.floor((button.xuiFont[2] + 2) * 0.85 * 10 + 0.5) / 10
            local sc = button.xuiSC
            if not sc then sc = { segs = {} }; button.xuiSC = sc end
            if sc.text ~= text or sc.size ~= size then
                sc.text, sc.size = text, size
                -- split into runs
                local runs = {}
                local function push(str, small)
                    local r = runs[#runs]
                    if r and r.small == small then r.str = r.str .. str else runs[#runs + 1] = { str = str, small = small } end
                end
                local newWord = true
                for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                    if ch == " " then push(ch, false); newWord = true
                    elseif ch:match("%a") then
                        if newWord then push(ch:upper(), false); newWord = false else push(ch:upper(), true) end
                    else push(ch, false); newWord = false end
                end
                for i, r in ipairs(runs) do
                    local seg = sc.segs[i]
                    if not seg then seg = button:CreateFontString(nil, "OVERLAY"); sc.segs[i] = seg end
                    seg:SetFont(button.xuiFont[1], r.small and size * 0.8 or size, "OUTLINE")
                    seg:SetTextColor(1, 1, 1, 1)
                    seg:SetText(r.str)
                    seg:ClearAllPoints()
                    if i == 1 then seg:SetPoint("BOTTOMLEFT", fs, "BOTTOMLEFT", 0, 0)
                    else seg:SetPoint("BOTTOMLEFT", sc.segs[i - 1], "BOTTOMRIGHT", 0, 0) end
                    seg:Show()
                end
                for i = #runs + 1, #sc.segs do sc.segs[i]:Hide() end
            end
            fs:SetAlpha(0)
            button.xuiIsSC = true
        elseif button.xuiIsSC then
            fs:SetAlpha(1)
            for _, seg in ipairs(button.xuiSC and button.xuiSC.segs or {}) do seg:Hide() end
            if button.xuiSC then button.xuiSC.text = nil end
            button.xuiIsSC = nil
        end
    end
    if not c then
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
    b:SetColorTexture(c[1], c[2], c[3], 0.5)
    pcall(b.SetGradient, b, "HORIZONTAL", CreateColor(c[1], c[2], c[3], 0.85), CreateColor(c[1], c[2], c[3], 0.2))
    bar:SetColorTexture(c[1], c[2], c[3], 1)
    b:Show(); bar:Show()
end

-- Tree-chart guide bars: every row inside a top-level folder repeats that folder's colour as a vertical bar at the
-- left edge (a continuation of the folder's own banner bar), and each deeper folder level adds one more, lighter
-- and thinner bar, indented one step. Rows directly under the Loaded / Not Loaded roots continue that root's colour.
local function PaintGuides(button)
    local guides = button.xuiGuides
    local bars = {}
    local uv = button.uniquevalue
    if uv then
        local segs = {}
        for seg in tostring(uv):gmatch("[^\001]+") do segs[#segs + 1] = seg end
        local L = #segs
        local c = L >= 2 and BannerTint(segs[2]) or nil
        if c then
            for j = 2, L - 1 do
                local depth = j - 2
                local mix = 0.22 * depth
                bars[#bars + 1] = { x = (j == 2) and 0 or 8 * depth, w = (j == 2) and 6 or 4,
                    r = c[1] + (1 - c[1]) * mix, g = c[2] + (1 - c[2]) * mix, b = c[3] + (1 - c[3]) * mix,
                    a = math.max(0.5, 1 - 0.12 * depth) }
            end
        elseif L == 2 and (segs[1] == "loaded" or segs[1] == "notloaded") then
            local rc = BannerTint(segs[1])
            if rc then bars[1] = { x = 0, w = 6, r = rc[1], g = rc[2], b = rc[3], a = 1 } end
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

-- Left cluster, in order:  [collapse arrow] [eye] [headphone]  text
local function DecorateButton(button)
    PaintBanner(button)
    PaintGuides(button)
    local vis, snd = Resolve(button.uniquevalue)
    local tree = button.obj
    if not button.xuiDrag then
        button.xuiDrag = true
        button:RegisterForDrag("LeftButton")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:HookScript("OnClick", function(self, mouse) if mouse == "RightButton" then ShowRowMenu(self) end end)
        button:HookScript("OnDragStart", StartDrag)
        button:HookScript("OnDragStop", StopDrag)
    end
    local level = button.level or 1
    local canExpand = button.toggle and button.toggle:IsShown() and true or false
    local hasIcons = vis and #vis > 0
    if button.text then
        button.text:SetWordWrap(false)
        button.text:SetPoint("RIGHT", button, "RIGHT", -4, 2)
    end
    -- Every row of a level uses the same fixed slots: [arrow 16][eye 17][headphone 17][text]. A row without an arrow or
    -- without icons keeps its (empty) slots, so the text of all rows on one level lines up. Blizzard's tiny +/- is hidden
    -- (still "shown", so canExpand stays readable) because our arrow replaces it on every expandable row.
    local CHEV_W, ICON_W = 16, 17
    local x0 = 8 * level - 6
    if button.toggle then
        button.toggle:SetAlpha(canExpand and 0 or 1)
        button.toggle:EnableMouse(not canExpand)
    end
    if canExpand then
        if not button.xuiChev then button.xuiChev = MakeChevron(button) end
        local st = tree and (tree.status or tree.localstatus)
        local expanded = st and st.groups and st.groups[button.uniquevalue]
        button.xuiChev:SetNormalTexture(expanded and 130821 or 130838)
        button.xuiChev:SetPushedTexture(expanded and 130820 or 130836)
        button.xuiChev:ClearAllPoints()
        button.xuiChev:SetPoint("LEFT", button, "LEFT", x0, 0)
        button.xuiChev:Show()
    elseif button.xuiChev then
        button.xuiChev:Hide()
    end
    if hasIcons then
        if not button.xuiEye then
            button.xuiEye = MakeToggle(button, "visual")
            button.xuiHead = MakeToggle(button, "sound")
        end
        local function paint(b, objs, kind, sx)
            if not objs or #objs == 0 then b:Hide(); return end
            b.objs = objs
            b:ClearAllPoints()
            b:SetPoint("LEFT", button, "LEFT", sx, 0)
            local st = GroupState(objs, kind)
            b.tex:SetDesaturated(st == 0)
            b.tex:SetAlpha(st == 1 and 1 or (st == 0.5 and 0.7 or 0.35))
            b:Show()
        end
        paint(button.xuiEye, vis, "visual", x0 + CHEV_W)
        paint(button.xuiHead, snd, "sound", x0 + CHEV_W + ICON_W)
    elseif button.xuiEye then
        button.xuiEye:Hide(); button.xuiHead:Hide()
    end
    if button.text then button.text:SetPoint("LEFT", button, "LEFT", x0 + CHEV_W + ICON_W * 2 + 3, 2) end
end

local function DecorateTree(tree)
    if not tree.xuiHooked then
        tree.xuiHooked = true
        local orig = tree.RefreshTree
        tree.RefreshTree = function(self, ...)
            orig(self, ...)
            for _, b in ipairs(self.buttons or {}) do if b:IsShown() then DecorateButton(b) end end
        end
        local status = tree.status or tree.localstatus
        if status and not status.xuiWide then
            status.xuiWide = true
            if (status.treewidth or 0) <= 175 then pcall(tree.SetTreeWidth, tree, 270, true) end
        end
    end
    for _, b in ipairs(tree.buttons or {}) do
        if b:IsShown() then DecorateButton(b)
        else
            if b.xuiEye then b.xuiEye:Hide(); b.xuiHead:Hide() end
            if b.xuiBanner then b.xuiBanner:Hide(); b.xuiBannerBar:Hide() end
        end
    end
end

-- Full Blizzard spell tooltip on the talent icon (an AceGUI Icon whose option carries arg.xuiSpell = the talent row).
-- AceGUI clears callbacks when a widget is recycled, so this re-checks on every pass instead of flagging the widget.
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

local function Walk(w, depth)
    if not w or depth > 14 then return end
    if w.type == "Icon" then AttachSpellTip(w) end
    if w.type == "TreeGroup" then DecorateTree(w) end
    for _, c in ipairs(w.children or {}) do Walk(c, depth + 1) end
end

function ns.DecorateTrees(root)
    root = root or (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP])
    if root then pcall(Walk, root, 0) end
end

local function SelectedRule()
    if not AceConfigDialog.GetStatusTable then return nil end
    local root = AceConfigDialog:GetStatusTable(APP)
    local tab = root and root.groups and root.groups.selected
    if tab ~= "cooldowns" and tab ~= "loadedTab" and tab ~= "notloadedTab" then return nil end
    local st = AceConfigDialog:GetStatusTable(APP, { tab })
    local sel = st and st.groups and st.groups.selected
    local idx = sel and tonumber(tostring(sel):match("rule(%d+)"))
    return idx and ns.rules and ns.rules[idx]
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
        c.close:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -6, -6)
        c.close:Show()
        c.arrow.tex:SetTexture(ARROW_OPEN)
        c.arrow:ClearAllPoints()
        c.arrow:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -36, -6)
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
        c.close:SetSize(26, 26)
        c.close:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -6, -6)
        c.close:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.close:SetScript("OnClick", function() AceConfigDialog:Close(APP) end)

        -- boxed button (same skin as the Close button), just left of the X
        c.arrow = CreateFrame("Button", nil, fr, "UIPanelButtonTemplate")
        c.arrow:SetSize(26, 26)
        c.arrow:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -36, -6)
        c.arrow:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.arrow.tex = c.arrow:CreateTexture(nil, "OVERLAY")
        c.arrow.tex:SetSize(16, 16)
        c.arrow.tex:SetPoint("CENTER", 0, 0)
        c.arrow.tex:SetTexture(ARROW_OPEN)
        c.arrow:SetScript("OnClick", function() SetCollapsed(of, not c.collapsed) end)
        c.arrow:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(c.collapsed and "Expand the window" or "Collapse to the banner")
            GameTooltip:Show()
        end)
        c.arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- AceGUI recycles Frame widgets: undo everything on release so other addons' windows stay untouched
        local orig = of.OnRelease
        of.OnRelease = function(self, ...)
            SetCollapsed(self, false)
            c.close:Hide()
            c.arrow:Hide()
            if orig then return orig(self, ...) end
        end
    end
    c.arrow:Show()
    c.close:Show()
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
    if fr and fr:IsShown() and not (of.xuiChrome and of.xuiChrome.collapsed) then
        if not tray then tray = BuildTray(); ApplyTrayState() end
        if tray.anchoredTo ~= fr then
            tray:ClearAllPoints()
            tray:SetPoint("TOPLEFT", fr, "BOTTOMLEFT", 0, 0)
            tray:SetPoint("TOPRIGHT", fr, "BOTTOMRIGHT", 0, 0)
            tray.anchoredTo = fr
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
    sub:SetText("Sound cues and on-screen alerts driven by rules: buff, cooldown, talent and conditions.\nSlash commands: /xui (or /xayaui)  |  /xui status  |  /xui probe <spellID>  |  /xui unlock")

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
