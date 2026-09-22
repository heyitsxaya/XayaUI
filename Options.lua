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

-- A text box that suggests spells by name (popup list with icons, wired up by AttachSearch in the widget walker).
-- pick(id) is called with the chosen spell ID. get() is always empty so the box clears after a pick.
local function SearchBox(order, pick, name)
    return { type = "input", name = name or "Search by spell name", order = order, width = "double",
        desc = "Type part of a spell name. A list with icons pops up; click one (or press Enter for the first) to fill in its spell ID. Also accepts an ID.",
        arg = { xuiSearch = pick },
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
-- Specialization / Role: a tick box heading that reveals square single-choice boxes (click the chosen one again to
-- clear it) with "All" at the bottom. Nothing chosen = no restriction, same as before. `ld()` returns rule.load;
-- useKey (specUse / roleUse) = false makes the saved choice ignored without deleting it.
-- rule + bannerKey are optional: when given, the choice list opens/closes exactly like the Talent list (the same
-- bannerOpen table and ns.ArrowToggle +/- button), and unticking "use" clears the choices below instead of only
-- disabling them - so a rule that shows "All" really has nothing recorded, not a hidden leftover pick.
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
                hdr = { type = "execute", order = 1, width = "full", arg = { xuiLeft = true },
                    name = function() return (isShut() and CLOSED or OPEN) .. "  " .. title end,
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
            spellSearch = SearchBox(3.2, function(id) rule.spellID = id; Changed(rule); Notify() end),
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
            buffState = Sel(rule, "buffState", "State", 11, BUFF_VALUES, BUFF_ORDER, on, { width = "double" }),
            buffSearch = SearchBox(11.5, function(id) rule.buffID = id; Changed(rule); Notify() end),
            buffID = {
                type = "input", name = "Aura spell ID", order = 12, width = "half",
                get = function() return tostring(rule.buffID) end,
                set = function(_, v) rule.buffID = tonumber(v) or 0; Changed(rule); Notify() end,
            },
            buffName = { type = "description", order = 13, width = "double", fontSize = "medium",
                name = function() return SpellName(rule.buffID) end },
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
            w = Rng(V, "w", "Width", 11, 8, 512, 1, on, { set = ns.AspectSet(V, "w", "h", on) }),
            h = Rng(V, "h", "Height", 12, 8, 512, 1, on, { set = ns.AspectSet(V, "h", "w", on) }),
            keepAspect = { type = "toggle", name = "Maintain aspect ratio", order = 12.5, width = "double",
                desc = "On (default): changing Width or Height changes the other one too, keeping the proportions they have when you move the slider. Off: they move independently.",
                get = function() return V.keepAspect ~= false end,
                set = function(_, v) V.keepAspect = v and true or false; on() end },
            rotation = Rng(V, "rotation", "Rotation (degrees)", 14, 0, 360, 1, on,
                { desc = "Rotates the art about its center. Works best on square sizes; a square image shrinks slightly at diagonal angles so it is never cropped." }),
            flipH = Tog(V, "flipH", "Mirror (flip horizontally)", 15, on),
            flipV = Tog(V, "flipV", "Flip vertically", 16, on),
            zoom = Rng(V, "zoom", "Zoom / crop edges", 17, 0, 0.3, 0.01, on),
            colorH = { type = "header", name = "Color & Blend", order = 20 },
            additive = Tog(V, "additive", "Additive blend", 21, on),
            desaturate = Tog(V, "desaturate", "Desaturate the base texture", 22, on,
                { width = "double", desc = "Removes the art's own colors first. On its own this grays it; with a tint below it gives an even, precise recolor (the tint multiplies the gray art). Progress textures grey the base automatically whenever it's tinted (see Advanced customization under Opacity & Fill) and lock this control while that's on.",
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
            requireOnBar = Tog(V, "requireOnBar", "Only show while this ability is on an action bar", 37.5, on, { width = "double",
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
                  desc = "Progress textures keep the top layer ungreyed by default (Advanced customization under Opacity & Fill overrides this).",
                  get = function() if ProgLocked() then return false end return OV.desaturate and true or false end }),
            additive = Tog(OV, "additive", "Additive blend for the overlay", 8, on,
                { width = "double", disabled = function() return not OV.enabled end }),
            note = { type = "description", order = 9, width = "full", fontSize = "small",
                name = "The overlay shares the base's size, rotation, mirror and zoom. Tint the base underneath (or desaturate it) on the Color & blend line above; opacity of each layer is set under Opacity & fill." },
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
                  desc = "Progress textures link this to Overlay opacity below, preserving their ratio, unless Advanced customization (bottom of this section) is on." }),
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
            oocAlpha = Rng(V, "oocAlpha", "Opacity multiplier out of combat", 4, 0, 1, 0.05, on, { width = "double" }),
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
                  desc = "Progress textures default to a locked base+overlay layering: the base opens at a reduced opacity tied to Overlay opacity above, greys automatically only when tinted, and the overlay never greys or dims. Tick this to set the base opacity, base grey and overlay grey independently instead." }),
        },
    }
    ns.GatePane(rule, opacity.args, "fadeAlpha", "Fade opacity options", 11.5, function() return V.fadeAlpha end, { "fadeAlphaMax", "fadeAlphaMin" })
    ns.GatePane(rule, opacity.args, "fill", "Wipe options", 21.5, function() return FL.enabled end, { "fillDir", "fillRev", "fillMax", "fillMin" })
    opacity.args.ovAlpha.disabled = nil
    opacity.args.ovAlpha.hidden = function() return not OV.enabled end   -- belongs to the overlay switch, which lives in the Texture section
    local pos = {
        type = "group", inline = true, name = "Position (Offset From Screen Center)", order = 20, args = {
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
    -- Texture box: position sits above Size & Orientation; "Add Overlay Layer" lives here and reveals the overlay
    tex.args.addOverlay = Tog(OV, "enabled", "Add Overlay Layer", 4, function() Changed(rule); Notify() end, { width = "double",
        desc = "Adds a second texture layer directly below this box that you can tint separately." })
    overlay.args.enabled = nil
    tex.args.posH = { type = "header", name = "Position (Offset From Screen Center)", order = 4.5 }
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
        display = Banner("display", "Display Options", 1, display.args.enabled, dispBody, function() return V.enabled and true or false end),
        text = Banner("text", "Text", 2, textEnable, {
            dur = Sub("dur", "Buff Duration Text", 1, durArgs),
            cnt = Sub("cnt", "Stacks / Charges Count", 2, cntArgs),
            abs = Sub("abs", "Shield / Absorb Amount", 3, absArgs),
        }, function() return (T.enabled or C.enabled or AB.enabled) and true or false end),
        sound = Banner("sound", "Sound", 3, soundEnable, soundBody, function() return rule.sound.enabled and true or false end),
    } }
    -- cue kinds: a Display rule has no sound banner, a Sound rule has no display / text banners
    actions.args.display.hidden = function() return not ns.KindHas(rule, "visual") end
    actions.args.text.hidden = function() return not ns.KindHas(rule, "visual") end
    actions.args.sound.hidden = function() return not ns.KindHas(rule, "sound") end

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

    for _, g in ipairs({ ruleTab, trigger, load, actions }) do
        ns.LockArgs(g.args, function() return ns.IsEditLocked(rule) end)
    end
    return {
        type = "group", childGroups = "tab", order = 1000 + i,
        name = function() return (rule.enabled and "" or "|cff888888") .. rule.name end,
        args = { rule = ruleTab, trigger = trigger, load = load, actions = actions },
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
            buffSearch = SearchBox(2.9, function(id) bar.buffID = id; on(); Notify() end),
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
local importText, importMode, importSnap, importErr = "", nil, nil, nil
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

-- Addon Settings: the addon's own behavior, as opposed to any one rule's. Sits last (far right) in the tab bar.
local function BuildAddonSettings()
    return { type = "group", name = "Addon Settings", order = 7, args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = function() return "XayaUI v" .. AddonVersion() .. ". Settings here affect the whole addon, not any one rule." end },
        debugHeader = { type = "header", name = "Debugging", order = 10 },
        advancedDebug = { type = "toggle", name = "Advanced Debugging (recommended)", order = 11, width = "full",
            desc = "When a Lua error happens inside XayaUI, print it to the chat window as a system message (in addition to whatever BugSack or the default Lua-error UI already does). Off: XayaUI stays silent about its own errors in chat.",
            get = function() return CueRulesDB and CueRulesDB.ui and CueRulesDB.ui.advancedDebug and true or false end,
            set = function(_, v)
                CueRulesDB.ui = CueRulesDB.ui or {}
                CueRulesDB.ui.advancedDebug = v and true or false
            end },
    } }
end

local function BuildProfiles()
    local a = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Your rules are personal. Nothing is shared unless you export it, and a fresh install starts empty. Export produces a text string you can paste to a friend; they paste it under 'Import' to add it to their own setup." },
        exportTotal = { type = "execute", name = "Export total profile  (everything, one click)", order = 0.5, width = "full",
            desc = "Bundles ALL rules with their folders and container settings, all buff bars and all QoL elements into one export string, ignoring the ticks below. The text appears just under this button.",
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
    return { type = "group", name = "Profiles", order = 6, args = a }
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

-- "+ New rule" opens an intermediate page (like WeakAuras' display-type list) instead of creating a blank rule.
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
    if key == "smart_sound" then
        return (rule.sound and rule.sound.enabled and ns.KindHas(rule, "sound")) and true or false
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
    r.name = "Rule " .. (#ns.rules + 1)
    r.folder = fid
    ApplyNewOpts(r)
    local v = r.visual
    if typ and ns.KindHas(r, "visual") then
        v.enabled = true
        if typ == "icon" then v.kind = "spellicon"; v.w, v.h = 64, 64; v.desatOnCD = true
        elseif typ == "progresstex" then
            v.fill.enabled = true
            v.overlay.enabled = true      -- progress textures are two-layered by default: base (reduced opacity below) + overlay (full)
            v.texAlpha = 0.35              -- reduced base opacity; ratio to Overlay opacity (1) is preserved while locked (see ProgLocked)
        elseif typ == "text" then v.text.enabled = true; v.texAlpha = 0 end
    end
    ns.rules[#ns.rules + 1] = r
    Notify()
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, RulePath(r))
end
local function StartNewRule(fid)
    if ns.RuleKind({ folder = fid }) == "sound" then CreateRuleOfType(nil, fid); return end
    picker = { folder = fid }
    Notify()
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "all")
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
    autoMsg.last = ("Added %d rule(s); %d already in that folder were skipped."):format(made, skipped)
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
    elseif typ == "import" then
        Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "profiles")
    else
        CreateRuleOfType(typ, p and p.folder)
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
    local RV = { screen = "Screen center (or the parent folder)", player = "Player frame", target = "Target frame", focus = "Focus frame",
        minimap = "Minimap", chat = "Main chat frame", custom = "Another frame (type its name)" }
    local function isDyn() return f.cType == "dynamic" end
    local g = { type = "group", inline = true, order = 5.4, name = "Group Type & Container",
        hidden = function() return not ns.KindHas({ folder = f.id }, "visual") end,
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Every folder is a container for the displays inside it (and inside its subfolders). Static: each display keeps its own position. Dynamic: the addon lays the visible displays out itself and ignores their own X / Y. The container settings below apply to everything inside. Width / height give the container a fixed box (also what the anchor point refers to); a dynamic group wraps onto a new row / column when its items would exceed that size." },
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
    g.args.alpha = { type = "range", name = "Group opacity", order = 3, width = "double", min = 0, max = 1, step = 0.05,
        get = function() return f.cAlpha or 1 end, set = function(_, v) f.cAlpha = (v < 1) and v or nil; apply() end }
    g.args.scale = { type = "range", name = "Group scale", order = 3.1, width = "double", min = 0.25, max = 3, step = 0.05,
        get = function() return f.cScale or 1 end, set = function(_, v) f.cScale = (v ~= 1) and v or nil; apply() end }
    g.args.width = { type = "range", name = "Container width (0 = automatic)", order = 3.05, width = "double", min = 0, max = 1500, step = 1,
        get = function() return f.cW or 0 end, set = function(_, v) f.cW = (v > 0) and v or nil; apply() end }
    g.args.height = { type = "range", name = "Container height (0 = automatic)", order = 3.06, width = "double", min = 0, max = 1500, step = 1,
        get = function() return f.cH or 0 end, set = function(_, v) f.cH = (v > 0) and v or nil; apply() end }
    g.args.clip = { type = "toggle", name = "Clip contents to the container size (hide anything outside it)", order = 3.07, width = "full",
        get = function() return f.cClip and true or false end, set = function(_, v) f.cClip = v and true or nil; apply() end }
    g.args.strata = { type = "select", name = "Layer (strata)", order = 3.2, width = "double", values = SV, sorting = STRATA,
        get = function() return f.cStrata or "inherit" end, set = function(_, v) f.cStrata = (v ~= "inherit") and v or nil; apply() end }
    g.args.level = { type = "range", name = "Z-index within the layer (0 = automatic)", order = 3.3, width = "double", min = 0, max = 200, step = 1,
        get = function() return f.cLevel or 0 end, set = function(_, v) f.cLevel = (v > 0) and v or nil; apply() end }
    g.args.relH = { type = "header", name = "Position", order = 4 }
    g.args.rel = { type = "select", name = "Relative to", order = 4.1, width = "double", values = RV, sorting = RELS,
        get = function() return f.cRel or "screen" end, set = function(_, v) f.cRel = (v ~= "screen") and v or nil; apply() end }
    g.args.relName = { type = "input", name = "Frame name", order = 4.2, width = "double", hidden = function() return f.cRel ~= "custom" end,
        desc = "The global name of any frame, e.g. PlayerFrame or MultiBarBottomLeft. If it does not exist the group falls back to the screen.",
        get = function() return f.cFrame or "" end, set = function(_, v) f.cFrame = (v ~= "") and v or nil; apply() end }
    g.args.point = { type = "select", name = "This group's anchor point", order = 4.3, values = PV, sorting = POINTS,
        get = function() return f.cPoint or "CENTER" end, set = function(_, v) f.cPoint = (v ~= "CENTER") and v or nil; apply() end }
    g.args.relPoint = { type = "select", name = "Point on the frame it is relative to", order = 4.4, values = PV, sorting = POINTS,
        get = function() return f.cRelPoint or f.cPoint or "CENTER" end, set = function(_, v) f.cRelPoint = v; apply() end }
    g.args.x = { type = "range", name = "X offset", order = 4.5, width = "double", min = -1500, max = 1500, step = 1, softMin = -600, softMax = 600,
        get = function() return f.cX or 0 end, set = function(_, v) f.cX = (v ~= 0) and v or nil; apply() end }
    g.args.y = { type = "range", name = "Y offset", order = 4.6, width = "double", min = -1500, max = 1500, step = 1, softMin = -600, softMax = 600,
        get = function() return f.cY or 0 end, set = function(_, v) f.cY = (v ~= 0) and v or nil; apply() end }
    return g
end

local function FolderSoundGroup(f)
    return {
        type = "group", inline = true, order = 5.6, name = "Sound Channel for This Folder",
        hidden = function() return ns.RuleKind({ folder = f.id }) == "display" end,
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Forces every rule in this folder and its subfolders to play on this channel, whatever the rule itself says. Nothing on the rules is changed: a rule that leaves the folder uses its own channel again. A subfolder's own choice beats the folder above it." },
            channel = { type = "select", name = "Enforced sound channel", order = 1, width = "double",
                values = CHANNEL_VALUES, sorting = CHANNEL_ORDER,
                get = function() return f.soundChannel or "none" end,
                set = function(_, v) f.soundChannel = (v ~= "none") and v or nil; ns.MarkDirty(); Notify() end },
            inherited = { type = "description", order = 2, width = "full", fontSize = "medium",
                hidden = function() if f.soundChannel then return true end; return not ns.FolderSoundChannelFrom(f.parent) end,
                name = function()
                    local ch, of = ns.FolderSoundChannelFrom(f.parent)
                    if not ch then return "" end
                    return "Inherited from folder |cffffd100" .. tostring(of and of.name) .. "|r: " .. tostring(ch)
                end },
        },
    }
end

local function BuildFolder(k, f)
    local dinfo, dpos = ns.DefaultFolderInfo(f.default)
    if f.default == "cursor" and not f.parent then
        -- Mouse Cursor Cues: no folder tools here; the only content is a jump to the Cursor Tracker settings
        return {
            type = "group", order = dpos and (10 + dpos) or (100 + k),
            name = function() return tostring(f.name):upper() .. " (" .. FolderRuleCount(f) .. ")" end,
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
        type = "group", order = dpos and (10 + dpos) or (100 + k),
        name = function() return (f.parent and f.name or tostring(f.name):upper()) .. " (" .. FolderRuleCount(f) .. ")" end,
        args = {
            name = { type = "input", name = "Folder name", order = 1, width = "double",
                get = function() return f.name end, set = function(_, v) if v ~= "" then f.name = v end; Notify() end },
            newRule = { type = "execute", name = "+ New rule in this folder", order = 2, width = "double",
                func = function()
                    StartNewRule(f.id)
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
            pausePv = { type = "toggle", name = "Pause preview animations", order = 4.5, width = "double",
                hidden = function() return not ns.KindHas({ folder = f.id }, "visual") end,
                desc = "Freezes the sample countdown, the fades and the flash in every preview while the images stay on screen. Untick to resume. This is the same switch as on All Rules and on each rule, so it pauses every preview, not only this folder's.",
                get = function() return ns.previewPaused end,
                set = function(_, v) ns.SetPreviewPaused(v); Notify() end },
            note = { type = "description", order = 5, width = "full", fontSize = "small",
                name = "Use the eye and headphone icons next to this folder in the sidebar to preview every rule inside it at once." },
            defaultNote = { type = "description", order = 5.2, width = "full", fontSize = "small",
                hidden = function() return not dinfo end, name = dinfo and dinfo.note or "" },
            loadOverride = FolderLoadGroup(f),
            soundChannel = FolderSoundGroup(f),
            container = ns.FolderContainerGroup(f),
            applyText = (function()
                local g = FolderApplyGroup(f)
                g.hidden = function() return not ns.KindHas({ folder = f.id }, "visual") end
                return g
            end)(),
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
    ns.LockArgs(g.args, function() return ns.IsEditLocked({ folder = f.id }) end)
    return g
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
                    StartNewRule(nil)
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
            askSounds = { type = "toggle", name = "Ask before previewing many sounds at once", order = 4.5, width = "double",
                desc = "When on, the headphone icon on a row that covers several sounds asks first. Turned off by ticking 'Don't ask me again' in that box.",
                get = function() local u = CueRulesDB and CueRulesDB.ui; return not (u and u.skipSoundAllPrompt) end,
                set = function(_, v) local u = CueRulesDB and CueRulesDB.ui; if u then u.skipSoundAllPrompt = (not v) or nil end end },
            unlock = { type = "execute", order = 5, width = "double",
                name = function() return ns.unlocked and "Lock visuals" or "Unlock visuals (drag on screen)" end,
                func = function() ns.ToggleUnlock(); Notify() end },
            pausePv = { type = "toggle", name = "Pause preview animations", order = 5.2, width = "double",
                desc = "Freezes the sample countdown, the fades and the flash in every preview and unlocked display while the images stay on screen. Untick to resume.",
                get = function() return ns.previewPaused end,
                set = function(_, v) ns.SetPreviewPaused(v); Notify() end },
            defaults = { type = "execute", name = "Add Default Categories", order = 5.5, width = "double",
                desc = "Adds any of Display Cues, Sound Cues, Hybrid Cues and Advanced Cue Tracking that are missing at the top level. Existing folders and rules are not touched.",
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
    local ruleGroups = {}
    for i, rule in ipairs(ns.rules or {}) do
        local g = BuildRule(i, rule)
        ruleGroups[i] = g
        local fld = rule.folder and groups[rule.folder]
        if fld then fld.args["rule" .. i] = g else all.args["rule" .. i] = g end
        if okc and ns.IsLoaded(rule, ctx) then loadedArgs["rule" .. i] = g; nLoaded = nLoaded + 1
        else notArgs["rule" .. i] = g; nNot = nNot + 1 end
    end
    loadedArgs.info = { type = "description", order = 0, width = "full", fontSize = "medium",
        name = "Rules that are enabled and whose load conditions and talents match right now (cooldown / buff state is not part of this). Same rules as under All Rules; this list updates as your situation changes." }
    notArgs.info = { type = "description", order = 0, width = "full", fontSize = "medium",
        name = "Rules that are disabled, or whose load conditions or talents do not match right now." }
    -- All Rules is the first root row; a blank divider row follows its tree, then the Loaded / Not Loaded filters
    all.order = 1
    -- type picker (shown in place of the All Rules page while `picker` is set)
    do
        local function Entry(order, icon, title, desc, typ)
            return { type = "execute", order = order, width = "full",
                name = "|TInterface\\Icons\\" .. icon .. ":28|t  |cffffd100" .. title .. "|r  -  " .. desc,
                func = function() PickType(typ) end }
        end
        for _, k in ipairs({ "intro", "newRule", "newFolder", "newSound", "newVisual", "askSounds", "unlock", "pausePv", "defaults", "seed" }) do
            local a = all.args[k]
            if a then
                local orig = a.hidden
                a.hidden = function(...) if picker then return true end; if type(orig) == "function" then return orig(...) end; return orig end
            end
        end
        all.args.pickerHdr = { type = "header", order = 0.1, name = "Choose what this rule shows", hidden = function() return not picker end }
        all.args.pickIcon = Entry(0.2, "Spell_Holy_PowerWordShield", "Icon", "Shows a spell icon with an optional cooldown overlay", "icon")
        all.args.pickBar = Entry(0.3, "Ability_Rogue_Sprint", "Progress Bar", "Shows a progress bar with name, timer, and icon (creates a Buff Bar)", "bar")
        all.args.pickProg = Entry(0.4, "Spell_Nature_TimeStop", "Progress Texture", "Shows a texture that changes based on duration", "progresstex")
        all.args.pickText = Entry(0.5, "INV_Misc_Note_01", "Text", "Shows one or more lines of text, which can include dynamic information", "text")
        all.args.pickTex = Entry(0.6, "INV_Misc_Gem_Variety_01", "Texture", "Shows a custom texture", "texture")
        all.args.pickExtH = { type = "header", order = 0.7, name = "External", hidden = function() return not picker end }
        all.args.pickImport = Entry(0.8, "INV_Scroll_03", "Import", "Import from an encoded string (opens the Profiles tab)", "import")
        all.args.pickCancel = { type = "execute", order = 0.9, name = "Cancel", width = "half", func = function() picker = nil; Notify() end }
        for _, k in ipairs({ "pickIcon", "pickBar", "pickProg", "pickText", "pickTex", "pickImport", "pickCancel" }) do
            all.args[k].hidden = function() return not picker end
        end
    end
    local track = { type = "group", name = "All Rules", order = 1, childGroups = "tree", args = {
        loaded = { type = "group", order = 3, childGroups = "tree",
            name = function() return "LOADED (" .. nLoaded .. ")" end, args = loadedArgs },
        spacer = { type = "group", order = 2, name = " ", disabled = true, args = {} },
        notloaded = { type = "group", order = 4, childGroups = "tree",
            name = function() return "NOT LOADED (" .. nNot .. ")" end, args = notArgs },
        autopop = { type = "group", order = 5, name = "AUTO-POPULATE RULES", args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Creates one rule per spell of your current class and specialization whose base cooldown is at least the number of seconds below (rule: fires when the spell comes off cooldown). Spells that are talents also require that talent. Spells already in the chosen folder are skipped, so you can run it again after a respec." },
            run = { type = "execute", name = "Auto-populate rules now", order = 1, width = "double",
                func = function() AutoPopulate() end },
            minCD = { type = "input", name = "Minimum cooldown (seconds)", order = 2, width = "normal",
                desc = "Uses each spell's BASE cooldown (talent and haste reductions are not applied). For charge spells it uses the recharge time per charge when the game exposes it.",
                get = function() return tostring(ns.AutoCfg().minCD) end,
                set = function(_, v) local n = tonumber(v); if n and n >= 0 then ns.AutoCfg().minCD = n end; ns.MarkDirty(); Notify() end },
            dest = { type = "select", name = "Add the rules to this folder", order = 3, width = "double",
                values = function() local v = FolderValues(); return v end,
                sorting = function() local _, o = FolderValues(); return o end,
                get = function() local a = ns.AutoCfg(); return a.dest or ns.AutoDest(a) or "none" end,
                set = function(_, v) ns.AutoCfg().dest = v; ns.MarkDirty(); Notify() end },
            scope = { type = "select", name = "Specialization", order = 4, width = "double",
                values = AUTO_SCOPE_VALUES, sorting = { "spec", "any" },
                get = function() return ns.AutoCfg().scope end,
                set = function(_, v) ns.AutoCfg().scope = v; ns.MarkDirty(); Notify() end },
            talents = { type = "toggle", name = "Include talents I have not picked (rule only loads when the talent is known)", order = 5, width = "full",
                get = function() return ns.AutoCfg().talents ~= false end,
                set = function(_, v) ns.AutoCfg().talents = v and true or false; ns.MarkDirty(); Notify() end },
            enabled = { type = "toggle", name = "Create the rules already enabled", order = 6, width = "full",
                get = function() return ns.AutoCfg().enabled ~= false end,
                set = function(_, v) ns.AutoCfg().enabled = v and true or false; ns.MarkDirty(); Notify() end },
            preview = { type = "description", order = 7, width = "full", fontSize = "small", name = function() return AutoPreview() end },
        } },
        all = all } }

    ---------------------------------------------------------- Buff Bars
    local allBars = {
        type = "group", name = "Buff Bars", order = 2, childGroups = "tree",
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
    for i, bar in ipairs(ns.bars or {}) do allBars.args["bar" .. i] = BuildBar(i, bar) end

    ---------------------------------------------------------- Smart Categories (virtual root under All Rules)
    do
        local smartArgs, total = {}, 0
        smartArgs.info = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Collects rules by what they actually do, without moving them out of their own folders. A rule that shows an icon and text appears under both. Buff bars are listed under Progress Bars. Lists update as you change rules; empty ones are hidden." }
        for k, cat in ipairs(ns.SMART_CATS) do
            local args, n = {}, 0
            if cat.key == "smart_bar" then
                for j = 1, #(ns.bars or {}) do
                    local bg = allBars.args["bar" .. j]
                    if bg then args["bar" .. j] = bg; n = n + 1 end
                end
                total = total + n
            else
                for i, rule in ipairs(ns.rules or {}) do
                    if ns.SmartMatch(rule, cat.key) then args["rule" .. i] = ruleGroups[i]; n = n + 1 end
                end
            end
            smartArgs[cat.key] = { type = "group", order = k, childGroups = "tree",
                name = function() return cat.name .. " (" .. n .. ")" end,
                hidden = function() return n == 0 end, args = args }
        end
        for _, rule in ipairs(ns.rules or {}) do if ns.SmartAny(rule) then total = total + 1 end end
        track.args.smart = { type = "group", order = 5, childGroups = "tree",
            name = function() return "SMART CATEGORIES (" .. total .. ")" end, args = smartArgs }
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
    for i, box in ipairs(ns.qolBoxes or {}) do allQol.args["box" .. i] = BuildBox(i, box) end
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
    local qol = { type = "group", name = "QoL Elements", order = 5, childGroups = "tree", args = { allqol = allQol, allcursor = (ns.CursorTrackerGroup and ns.CursorTrackerGroup(Notify)) or nil, allbars = allBars } }

    return { type = "group", name = "XayaUI", childGroups = "tab",
        args = { cooldowns = track, qol = qol, profiles = BuildProfiles(), settings = BuildAddonSettings() } }
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
    if last == "smart" or last:match("^smart_") then
        if last == "smart_bar" then
            local l = {}
            for _, b in ipairs(ns.bars or {}) do l[#l + 1] = b end
            return l, nil
        end
        local l = {}
        for _, r in ipairs(ns.rules or {}) do
            if (last == "smart" and ns.SmartAny(r)) or (last ~= "smart" and ns.SmartMatch(r, last)) then l[#l + 1] = r end
        end
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
            Notify()
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

-- Display <-> Sound: build equivalent rules in the other bucket from what each rule tracks (spell, aura, talents, states).
-- Load conditions start blank and the new rule starts disabled with its one output ticked, so turning it on is a single switch.
local function ConvertFolder(src, mode)
    local toKey = (src.default == "display") and "sound" or "display"
    local dst
    for _, f in ipairs(ns.folders) do if not f.parent and f.default == toKey then dst = f; break end end
    if not dst then ns.Print("that category is missing - press 'Add Default Categories' on All Rules first"); return end
    local rules = FolderRules(src.id)
    if #rules == 0 then ns.Print("nothing inside '" .. tostring(src.name) .. "' to " .. mode); return end
    local sub = ns.NewFolder((mode == "copy" and "Copied from " or "Moved from ") .. tostring(src.name), dst.id)
    for _, r in ipairs(rules) do
        local n = ns.NewRule()
        n.name = r.name
        for _, k in ipairs({ "spellID", "maxCharges", "cdState", "buffID", "buffState", "talentMode" }) do n[k] = r[k] end
        n.talents = ns.Copy(r.talents or {})
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
        if ns.IsEditLocked(rule) then
            root:CreateTitle("|cffff6060Edits blocked|r")
            root:CreateButton("Duplicate", function() DuplicateRule(rule) end)
            root:CreateButton("Copy Settings", function() ruleClip = { name = rule.name, data = ns.Copy(rule) }; Notify() end)
            return true
        end
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
            StartNewRule(fold.id)
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
        root:CreateTitle("All Rules")
        root:CreateButton("New Rule", function()
            StartNewRule(nil)
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
    root = { 1, 0.78, 0 }, loaded = { 0.1, 0.85, 0.75 }, notloaded = { 0.95, 0.2, 0.2 }, display = { 0.1, 0.5, 1 }, sound = { 0.1, 0.75, 0.3 }, hybrid = { 1, 0.5, 0.1 }, advanced = { 0.75, 0.25, 1 }, smart = { 0.3, 0.8, 1 }, cursor = { 0.95, 0.35, 0.75 }, other = { 0.7, 0.7, 0.75 },
}
local function BannerTint(uv)
    local last = uv and tostring(uv):match("([^\001]*)$")
    if last == "all" or last == "allbars" or last == "allqol" or last == "allcursor" or last == "autopop" then return BANNER_TINT.root end
    if last == "loaded" then return BANNER_TINT.loaded end
    if last == "notloaded" then return BANNER_TINT.notloaded end
    if last == "smart" then return BANNER_TINT.smart end
    local f = last and ns.FolderById and ns.FolderById(last)
    if f and not f.parent then
        return (type(f.default) == "string" and BANNER_TINT[f.default]) or BANNER_TINT.other
    end
end
local function PaintBanner(button)
    local c = BannerTint(button.uniquevalue)
    -- Root rows (ALL RULES, LOADED, NOT LOADED, ALL BARS, ALL BOXES): one shared soft style, white text, thin outline,
    -- 15% smaller than the earlier bold look, drawn in capitals.
    local fs = button.text
    if fs and fs.GetFont then
        if not button.xuiFont then local f, sz, fl = fs:GetFont(); local r, g, b, a = fs:GetTextColor(); button.xuiFont = { f, sz, fl, r, g, b, a } end
        local uv = button.uniquevalue and tostring(button.uniquevalue)
        local isRoot = uv and (uv == "all" or uv == "allbars" or uv == "allqol" or uv == "allcursor" or uv == "loaded" or uv == "notloaded" or uv == "smart" or uv == "autopop") or false
        -- Sizes (all relative to the default row font): sub-categories (nested folders, Smart Categories lists) +20%;
        -- categories / cue types (top-level folders) +15% then +20%; primary categories (root rows) 15% above the categories.
        local lastKey = uv and uv:match("([^\001]+)$") or ""
        local fld = lastKey:match("^f%d") and ns.FolderById and ns.FolderById(lastKey) or nil
        local isSub = (fld and fld.parent and true) or lastKey:match("^smart_") ~= nil
        local base = button.xuiFont[2]
        -- 2026-09-21: an extra x0.85 across the board - the previous +20% pass ran text into the row below.
        local catSize = math.floor(base * 1.15 * 1.2 * 0.85 * 10 + 0.5) / 10
        local subSize = math.floor(base * 1.2 * 0.85 * 10 + 0.5) / 10
        local cueSize = catSize
        local isCue = (not isRoot) and (not isSub) and c ~= nil
        if not button.xuiH0 then button.xuiH0 = button:GetHeight() end
        local want = button.xuiH0
        if isRoot then want = math.max(button.xuiH0, math.floor(catSize * 1.15 + 8)) elseif isCue then want = math.max(button.xuiH0, math.floor(catSize + 8)) elseif isSub then want = math.max(button.xuiH0, math.floor(subSize + 8)) end
        if math.abs(button:GetHeight() - want) > 0.5 then button:SetHeight(want) end
        if isSub then
            for _, seg in ipairs(button.xuiSC and button.xuiSC.segs or {}) do seg:Hide() end
            fs:SetFont(button.xuiFont[1], subSize, button.xuiFont[3])
            fs:SetTextColor(button.xuiFont[4] or 1, button.xuiFont[5] or 0.82, button.xuiFont[6] or 0, button.xuiFont[7] or 1)
            fs:SetAlpha(1)
            button.xuiIsSC = true
        elseif isCue then
            for _, seg in ipairs(button.xuiSC and button.xuiSC.segs or {}) do seg:Hide() end
            fs:SetFont(button.xuiFont[1], cueSize, button.xuiFont[3])
            fs:SetTextColor(button.xuiFont[4] or 1, button.xuiFont[5] or 0.82, button.xuiFont[6] or 0, button.xuiFont[7] or 1)
            fs:SetAlpha(1)
            button.xuiIsSC = true
        elseif isRoot then
            -- One font string, all capitals, one size: the earlier small-caps version stitched separate font strings
            -- together and left a visible gap after every capital and every space.
            local size = math.floor(cueSize * 1.15 * 10 + 0.5) / 10
            for _, seg in ipairs(button.xuiSC and button.xuiSC.segs or {}) do seg:Hide() end
            fs:SetFont(button.xuiFont[1], size, "OUTLINE")
            fs:SetTextColor(1, 1, 1, 1)
            local text = fs:GetText() or ""
            local up = text:upper()
            if up ~= text then fs:SetText(up) end
            fs:SetAlpha(1)
            button.xuiIsSC = true
        elseif button.xuiIsSC then
            fs:SetFont(button.xuiFont[1], button.xuiFont[2], button.xuiFont[3])
            fs:SetTextColor(button.xuiFont[4] or 1, button.xuiFont[5] or 0.82, button.xuiFont[6] or 0, button.xuiFont[7] or 1)
            fs:SetAlpha(1)
            for _, seg in ipairs(button.xuiSC and button.xuiSC.segs or {}) do seg:Hide() end
            if button.xuiSC then button.xuiSC.text = nil end
            button.xuiIsSC = nil
        end
    end
    -- blank divider row between All Rules and the Loaded / Not Loaded filters: a thin line, no text
    local isSpacer = button.uniquevalue and tostring(button.uniquevalue):match("([^\001]+)$") == "spacer"
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

-- Tree-chart guide bars: every row inside a top-level folder repeats that folder's color as a vertical bar at the
-- left edge (a continuation of the folder's own banner bar), and each deeper folder level adds one more, lighter
-- and thinner bar, indented one step. Rows directly under the Loaded / Not Loaded roots continue that root's color.
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
        elseif segs[1] == "smart" and L >= 2 then
            local rc = BANNER_TINT.smart
            bars[1] = { x = 0, w = 6, r = rc[1], g = rc[2], b = rc[3], a = 1 }
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
        if self.kind == "move" then
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
            GameTooltip:AddLine(self.xuiOn and "Drag the displays on screen. Click to lock them again." or "Click to unlock this row's on-screen displays so you can drag them.", 1, 1, 1, true)
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
        b:ClearAllPoints(); b:SetPoint("RIGHT", button, "RIGHT", -off, 0)
        b:Show()
        off = off + 19
    elseif button.xuiEdit then button.xuiEdit:Hide() end
    if showMove then
        if not button.xuiMove then button.xuiMove = ns.MakeSideToggle(button, "move") end
        local b = button.xuiMove
        local n = 0
        for _, r in ipairs(vis) do if ns.IsMoveUnlocked(r) then n = n + 1 end end
        b.xuiOn, b.xuiObjs = (n == #vis), vis
        b.tex:SetTexture(n == 0 and "Interface\\PetBattles\\PetBattle-LockIcon" or "Interface\\CURSOR\\UI-Cursor-Move")
        b.tex:SetAlpha(n == 0 and 0.85 or (n == #vis and 1 or 0.6))
        b:ClearAllPoints(); b:SetPoint("RIGHT", button, "RIGHT", -off, 0)
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
local function DecorateButton(button)
    PaintBanner(button)
    PaintGuides(button)
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
    local hasIcons = (vis and #vis > 0) or (snd and #snd > 0)
    -- top-level roots (All Rules / Loaded / Not Loaded) carry no eye or headphone; their lock icons stay
    do
        local rootKey = tostring(button.uniquevalue or ""):match("([^\001]+)$")
        if rootKey == "all" or rootKey == "loaded" or rootKey == "notloaded" or rootKey == "smart" then hasIcons = false end
    end
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
            b:SetPoint("RIGHT", button, "RIGHT", -sx, 0)
            local st = GroupState(objs, kind)
            b.tex:SetDesaturated(st == 0)
            b.tex:SetAlpha(st == 1 and 1 or (st == 0.5 and 0.7 or 0.35))
            b:Show()
        end
        -- eye and headphone live in fixed columns on the RIGHT, just left of the movement / edit locks
        paint(button.xuiEye, vis, "visual", 4 + 19 * 3)
        paint(button.xuiHead, snd, "sound", 4 + 19 * 2)
        button.xuiIconR = (vis and #vis > 0) and (4 + 19 * 3 + ICON_W + 3) or ((snd and #snd > 0) and (4 + 19 * 2 + ICON_W + 3) or 0)
    elseif button.xuiEye then
        button.xuiEye:Hide(); button.xuiHead:Hide()
    end
    do
        local rk = tostring(button.uniquevalue or ""):match("([^\001]+)$")
        local iconSlots = toggleCfg and 26 or 0   -- only the on / off tick box sits left of the label now
        if button.text then button.text:SetPoint("LEFT", button, "LEFT", x0 + CHEV_W + iconSlots + 3, 2) end
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
            if b.xuiEdit then b.xuiEdit:Hide() end
            if b.xuiMove then b.xuiMove:Hide() end
            if b.xuiBanner then b.xuiBanner:Hide(); b.xuiBannerBar:Hide() end
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
local siFrame
local function SI_Start()
    if SI.running or SI.nextId > SI_MAX then return end
    SI.running = true
    siFrame = siFrame or CreateFrame("Frame")
    siFrame:SetScript("OnUpdate", function(self)
        local ok = pcall(function()
            local t0 = debugprofilestop()
            local getn = C_Spell.GetSpellName
            while SI.nextId <= SI_MAX and debugprofilestop() - t0 < 4 do
                local last = math.min(SI.nextId + 499, SI_MAX)
                for id = SI.nextId, last do
                    local nm = getn(id)
                    if nm and nm ~= "" then local n = SI.n + 1; SI.n = n; SI.names[n] = nm:lower(); SI.ids[n] = id end
                end
                SI.nextId = last + 1
            end
        end)
        if not ok or SI.nextId > SI_MAX then SI.running = false; self:SetScript("OnUpdate", nil) end
    end)
end

local function SearchSpells(q)
    local res, seen = {}, {}
    q = (q or ""):lower():match("^%s*(.-)%s*$")
    if q == "" then return res end
    local num = tonumber(q)
    if num then
        local ok, nm = pcall(C_Spell.GetSpellName, num)
        if ok and nm then res[1] = num; seen[num] = true end
    end
    for _, sp in ipairs(ns.BuildSpellList() or {}) do
        if sp.name and sp.name:lower():find(q, 1, true) and not seen[sp.id] then res[#res + 1] = sp.id; seen[sp.id] = true end
    end
    local names, ids = SI.names, SI.ids
    for pass = 1, 2 do
        for i = 1, SI.n do
            if #res >= 80 then break end
            local st = names[i]:find(q, 1, true)
            if st and ((pass == 1) == (st == 1)) and not seen[ids[i]] then res[#res + 1] = ids[i]; seen[ids[i]] = true end
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
            row.icon:SetTexture(SpellTex(id))
            local okn, nm = pcall(C_Spell.GetSpellName, id)
            row.text:SetText(((okn and nm) or "?") .. "  |cff888888[" .. id .. "]|r")
            row:Show()
        else row:Hide() end
    end
    local msg = ""
    if SI.running then msg = ("Indexing spell names... %d%%  "):format(math.floor(SI.nextId / SI_MAX * 100)) end
    if total == 0 then msg = msg .. "No match yet"
    elseif total > SP_ROWS then msg = msg .. total .. " results - scroll for more" end
    SP.footer:SetText(msg)
end
local function SP_Hide() if SP then SP:Hide(); SP.owner = nil end end
local function SP_Pick(id)
    local eb = SP and SP.owner
    if not (eb and eb.xuiSearchFn and id) then return end
    local fn = eb.xuiSearchFn
    SP_Hide()
    eb:SetText(""); eb:ClearFocus()
    fn(id)
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
            if not pcall(GameTooltip.SetSpellByID, GameTooltip, self.id) then GameTooltip:SetText("Spell " .. tostring(self.id)) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
        if SI.running then
            acc = acc + e
            if acc > 0.6 and self.owner then acc = 0; self.results = SearchSpells(self.owner:GetText()); SP_Render() end
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
    SP.results, SP.offset = SearchSpells(q), 0
    SP:ClearAllPoints()
    SP:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", -4, -2)
    SP:SetWidth(math.max(340, eb:GetWidth() + 8))
    SP:Show()
    SP_Render()
end
AttachSearch = function(w)
    local eb = w.editbox
    if not eb then return end
    local opt = w.GetUserData and w:GetUserData("option")
    eb.xuiSearchFn = opt and type(opt.arg) == "table" and opt.arg.xuiSearch or nil
    if eb.xuiSearchFn and not eb.xuiSearchHooked then
        eb.xuiSearchHooked = true
        eb:HookScript("OnEditFocusGained", function(self) if self.xuiSearchFn then SI_Start() end end)
        eb:HookScript("OnTextChanged", function(self, user)
            if not (self.xuiSearchFn and user) then return end
            SI_Start()
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
    ns.origOpen = AceConfigDialog.Open
    AceConfigDialog.Open = function(self, app, ...)
        local a, b, c = ns.origOpen(self, app, ...)
        if app == APP then pcall(ns.DecorateTrees) end
        return a, b, c
    end
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
