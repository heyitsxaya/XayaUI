-------------------------------------------------------------------------------
-- XayaUI_Options/RuleEditor/Editor.lua : The rule editor: value tables, choice lists, the shared rule-row builders, the live status text, and BuildRule (one rule's
-- tabs: Display / Trigger / Cues / Conditions / Actions / Load / Info).
-- Part of the rule editor, moved out of Options.lua unchanged in the platform split P3 (Options 0.6.83;
-- docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7, Q1: the rule module owns its editor). This folder talks to the rest of the
-- settings window only through ns.OptionsApi: ns.OptionsApi.Shared (what Options.lua lends it) in, ns.OptionsApi.RuleEditor (what
-- Options.lua asks of it) out; its files share their own parts through ns.OptionsApi.RuleEditorParts.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (XayaUI Options depends on it: ## Dependencies: XayaUI)
-- (bundle 1 round 7, REQUEST-LOG A23 SD-57, her words: "editor is an 'options' pane so 3"; V34) This file is part of XayaUI Options
-- (it was XayaUI_Rules/Editor/, read at login with Rules). The game reads it only when the settings window's code loads, after the
-- window's own files (XayaUI_Options.toc). With XayaUI Rules switched off it stops on the next line and builds nothing.
if not (ns.OptionsApi and ns.Service and ns.Service("rules")) then return end   -- (and nothing while the window's code could not load: Options.lua)
if not (ns.OptionsApi and ns.OptionsApi.Shared) then return end   -- Options.lua stopped early (its Ace3 libraries are missing)
local O = ns.OptionsApi.Shared
local APP, AceConfigDialog, Notify, Col, Rng, Tog = O.APP, O.AceConfigDialog, O.Notify, O.Col, O.Rng, O.Tog
local Sel = O.Sel
local P = ns.OptionsApi.RuleEditorParts
local FolderValues, RulePath = P.FolderValues, P.RulePath

local function Changed(rule)
    if rule then
        if type(rule.visual) == "table" and ns.KeepArtAspect then ns.KeepArtAspect(rule.visual) end   -- swapped art keeps its own proportions
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
        desc = item and "Type part of an item name (* matches anything) and pick from the list, or type an ID. Finds items you own or your game has already seen; type the ID for any other."
            or "Type part of a name and pick from the list, or type an ID. Your class's matches come first; when several share the name, pick the right kind.",
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
-- #336: every preview sits in one fixed-width column (two icons wide), centred, so every row's text starts at the same place. The
-- padding is a transparent image (Media\UI\xui_blank.tga, 8 x 8, alpha 0) drawn at the width that is left over.
ns.TEX_PICK_SPACER = "Interface\\AddOns\\XayaUI\\Media\\UI\\xui_blank.tga"
local function PickRow(tex, w, label)
    local box, h = ns.TEX_PICK_ICON * 2, ns.TEX_PICK_ICON
    local left = math.floor((box - w) / 2)
    local right = box - w - left
    local function pad(n) return (n > 0) and ("|T%s:%d:%d|t"):format(ns.TEX_PICK_SPACER, h, n) or "" end
    return pad(left) .. ("|T%s:%d:%d|t"):format(tostring(tex), h, w) .. pad(right) .. "  " .. tostring(label)
end
ns.TexPickRow = PickRow
local function EnsureTextures()
    if texValues then return end
    texValues, texSorting = {}, {}
    for i, t in ipairs(ns.TextureList or {}) do
        local k = tostring(t[1])
        texValues[k] = PickRow(t[1], ns.TEX_PICK_ICON, t[2])
        texSorting[i] = k
    end
    texValues["0"] = "(none)"
    table.insert(texSorting, 1, "0")
    -- local graphics (Media\\Graphics, from LocalGraphics.lua); the stored value is the file path. Only folders the game can find
    -- (UserMedia.lua ns.AvailableLocalGraphics, #333): a picture only Xaya has is not offered as a blank row to everyone else.
    for _, g in ipairs((ns.AvailableLocalGraphics and ns.AvailableLocalGraphics()) or ns.LocalGraphics or {}) do
        local gw = math.min(ns.TEX_PICK_ICON * 2, math.max(8, math.floor(ns.TEX_PICK_ICON * (g[3] or 1) / math.max(1, g[4] or 1) + 0.5)))   -- keep the picture's proportions
        texValues[g[2]] = PickRow(g[2], gw, g[1])
        texSorting[#texSorting + 1] = g[2]
    end
end

-- the sound and art lists, for the auto-populate table's Cue set-up column (AutoPicker.lua, Options 0.6.53): the same lists the cue
-- editor offers, and the same way a picked art is applied (ns.ApplyArtPick, used by the editor's "Or pick art" below)
function ns.SoundChoices() EnsureSounds(); return soundList, soundValues, soundSorting end
function ns.TexChoices() EnsureTextures(); return texValues, texSorting end
function ns.ApplyArtPick(V, k)
    if k == "0" then V.tex = "" else V.kind, V.tex = "file", k end
    local follows = (tonumber(V.iconW) or 0) <= 0 and (tonumber(V.iconH) or 0) <= 0
    for _, g in ipairs(ns.LocalGraphics or {}) do   -- art that follows the display: shape the display like the picture (capped at 256)
        if follows and g[2] == k then
            local sc = math.min(1, 256 / math.max(g[3], g[4]))
            V.w, V.h = math.max(8, math.floor(g[3] * sc)), math.max(8, math.floor(g[4] * sc))
        end
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
-- Classes and specializations are ALWAYS offered in full, whatever character is logged in, so a rule or group can be set up
-- for any class from any character. Class files are the game's own constants; names come from the game (localized).
local SpecChoices   -- assigned in the block below (a block keeps the helpers off this file's 200-local limit)
do
local CLASS_FILES = { "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
local CLASS_NAME_FALLBACK = { DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter", DRUID = "Druid", EVOKER = "Evoker", HUNTER = "Hunter",
    MAGE = "Mage", MONK = "Monk", PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman", WARLOCK = "Warlock", WARRIOR = "Warrior" }
local function ClassName(file)
    local n = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or CLASS_NAME_FALLBACK[file] or file
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if c and c.colorStr then return "|c" .. c.colorStr .. n .. "|r", n end
    return n, n
end
function ns.ClassChoices()
    local list = {}
    for _, file in ipairs(CLASS_FILES) do list[#list + 1] = { key = file, id = file, text = (ClassName(file)) } end
    return list
end
local specCache
-- (Rules_Options 0.6.79; #476, debug W1: "missing devourer") Each class's specs come from the game's own count,
-- C_SpecializationInfo.GetNumSpecializationsForClassID(classID) -> specCount (12.1.5 docs), read index by index with
-- GetSpecializationInfoForClassID(classID, index: luaIndex, gender) -> id, name, description, icon, role, ... (12.1.5 docs).
-- An index the game answers with nothing is skipped, never the end of the list (it was `for si = 1, 4` stopping at the first empty
-- index, which left out Demon Hunter - Devourer, spec 1480). The same count-and-skip loop is what Game Data Capture used in game on
-- 2026-11-01 (docs/reference/spells/: Devourer 1480, Havoc 577, Vengeance 581). No count from the game: indexes 1 to 4, skipping gaps.
-- The game's "Initial" specs (before a spec is chosen; Blizzard's client data, docs/reference/content/classes.json, build 12.1.5.70783)
-- are never offered. Neither API entry marks them, so they are left out by spec ID.
local INITIAL_SPECS = { [1444] = true, [1446] = true, [1447] = true, [1448] = true, [1449] = true, [1450] = true, [1451] = true,
    [1452] = true, [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1465] = true }
local function SpecChoicesAll()
    if specCache then return specCache end
    local list = {}
    local nClasses = (GetNumClasses and GetNumClasses()) or 0
    local infoFn = GetSpecializationInfoForClassID
    local countFn = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID
    if infoFn and nClasses > 0 and GetClassInfo then
        for ci = 1, nClasses do
            local okC, cname, cfile, cid = pcall(GetClassInfo, ci)
            if okC and cid and cfile then
                local colored = (ClassName(cfile))
                local okN, n = false, nil
                if countFn then okN, n = pcall(countFn, cid) end
                n = (okN and type(n) == "number" and n > 0) and n or 4
                for si = 1, n do
                    local ok, id, name, _, icon = pcall(infoFn, cid, si)
                    if ok and type(id) == "number" and id > 0 and not INITIAL_SPECS[id] then
                        list[#list + 1] = { key = cfile .. ":" .. id, id = tostring(id), class = cfile,
                            text = (icon and ("|T" .. icon .. ":18:18|t  ") or "") .. colored .. "  -  " .. (name or tostring(id)) }
                    end
                end
            end
        end
    end
    if #list > 0 then specCache = list end
    return list
end
SpecChoices = function()
    local all = SpecChoicesAll()
    if #all > 0 then return all end
    -- the game gave no class list (should not happen): fall back to the logged-in character's own specs
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
-- alwaysKey (Class / Specialization rows, #319): a tick box on the row itself, shown while the load mode is "Always load": ticked,
-- Always load still keeps to this row (Conditions.lua AlwaysKeeps). Stored as ld()[alwaysKey] = true; unticked = nothing stored.
function ns.RadioGroup(name, order, hiddenFn, getSet, choices, onChange, ld, useKey, rule, bannerKey, multi, alwaysKey, alwaysWord)
    local function isOn()
        local u = ld()[useKey]
        if u == nil then return ns.SetActive(getSet()) end
        return u and true or false
    end
    local body = {}
    for i, ch in ipairs(choices) do
        body["c" .. i] = { type = "toggle", order = i, width = "full", name = ch.text,
            desc = multi and "Click to add or remove this one. Tick several to allow any of them."
                or "Click to choose only this one. Click it again to clear the choice.",
            get = function() return getSet()[ch.id] == true end,
            set = function(_, v)
                local s = getSet()
                if multi then s["*"] = nil; s[ch.id] = v and true or nil
                else wipe(s); if v then s[ch.id] = true end end
                onChange()
            end }
    end
    body.all = { type = "toggle", order = 100, width = "full", name = "All",
        desc = "Allows any (no restriction), the same as choosing nothing.",
        get = function() return getSet()["*"] == true end,
        set = function(_, v) local s = getSet(); wipe(s); if v then s["*"] = true end; onChange() end }
    local useArg = { type = "toggle", order = 1, width = "full", name = name,
        desc = "Restricts this rule by " .. name:lower() .. "; the choices open below. Unticking clears them and removes the restriction.",
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
    local alwaysArg
    if alwaysKey then
        useArg.width = "normal"   -- the row's own tick box sits beside it
        alwaysArg = { type = "toggle", order = 1.2, width = "normal",
            name = "Always load: only this " .. (alwaysWord or name:lower()),
            desc = "Keeps this condition under Always load: the rule loads only for the " ..
                (alwaysWord or name:lower()) .. " ticked here.",
            hidden = function() return ld().mode ~= "always" or not isOn() end,
            get = function() return ld()[alwaysKey] == true end,
            set = function(_, v) ld()[alwaysKey] = v and true or nil; onChange() end }
    end
    if rule and bannerKey then
        local arrow = ns.ArrowToggle(rule, bannerKey, 1.5)
        arrow.hidden = function() return not isOn() end
        return { type = "group", inline = true, name = "", order = order, hidden = hiddenFn, args = {
            use = useArg,
            always = alwaysArg,
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

-- ID-list load conditions (Xaya 2026-11-04: "more load conditions we should include if they're supported by the current api"; core
-- 0.6.28, Conditions.lua). Each list is a set of IDs as text keys: true = one of these, "not" = never here. In the settings it is one
-- text box: IDs separated by commas or spaces, a minus before an ID for "not" (e.g. "2339, -2552").
function ns.LoadIdText(set)
    local on, off = {}, {}
    for k, st in pairs(set or {}) do
        local n = tonumber(k)
        if n then if st == "not" then off[#off + 1] = n elseif st == true then on[#on + 1] = n end end
    end
    table.sort(on); table.sort(off)
    local out = {}
    for _, n in ipairs(on) do out[#out + 1] = tostring(n) end
    for _, n in ipairs(off) do out[#out + 1] = "-" .. n end
    return table.concat(out, ", ")
end
function ns.LoadIdParse(text)
    local set = {}
    for neg, d in tostring(text or ""):gmatch("(%-?)(%d+)") do
        local n = tonumber(d)
        if n then set[tostring(n)] = (neg == "-") and "not" or true end
    end
    return next(set) and set or nil
end
-- The game's difficulties by name, for the "Add a difficulty" menu: every ID from 1 to 300 that GetDifficultyInfo names (read once).
local diffChoices
function ns.DifficultyChoices()
    if diffChoices then return diffChoices[1], diffChoices[2] end
    local v, o = {}, {}
    if type(GetDifficultyInfo) == "function" then
        for id = 1, 300 do
            local ok, name, itype = pcall(GetDifficultyInfo, id)
            if ok and type(name) == "string" and name ~= "" then
                local kind = type(itype) == "string" and ns.INSTANCE_TYPES and ns.INSTANCE_TYPES[itype]
                v[tostring(id)] = name .. "  (" .. id .. (kind and (", " .. kind) or "") .. ")"
                o[#o + 1] = tostring(id)
            end
        end
    end
    diffChoices = { v, o }
    return v, o
end
ns.LOAD_ID_ROWS = {
    { field = "mapIDs", name = "Zones (map IDs)",
      desc = "Loads only in these zones. A zone's ID covers the maps inside it.",
      cur = function(p) return p.mapID, p.mapName end },
    { field = "instanceIDs", name = "Instances (instance IDs)",
      desc = "Loads only in these dungeons, raids or other instances, by the game's instance ID (in the open world it is the continent's).",
      cur = function(p) return p.instanceID, p.instanceName end },
    { field = "difficulties", name = "Difficulties (difficulty IDs)",
      desc = "Loads only on these difficulties (0 is the open world). The menu beside it adds one by name.",
      cur = function(p) return p.difficultyID, p.difficultyName end },
    { field = "sizes", name = "Instance sizes (largest group)",
      desc = "Loads only in instances of these sizes: the largest group the instance allows, as the game reports it. 0 is the open world.",
      cur = function(p) return p.size end },
    { field = "encounterIDs", name = "Boss encounters (encounter IDs)",
      desc = "Loads only during these boss encounters; after a /reload mid-pull it waits for the next pull. Add current adds the boss you are fighting, or the last one.",
      cur = function(p)
          if p.encounterID and p.encounterID > 0 then return p.encounterID, p.encounterName end
          local last = ns.LastEncounter and ns.LastEncounter()
          if last then return last.id, (last.name or "?") .. ", last pulled" end
      end },
    { field = "equipped", name = "Items equipped (item IDs)",
      desc = "Loads while one of these items is equipped; a minus before an ID means NOT equipped. Use the search next to it to add an item you own.",
      cur = nil },
}
-- The rows of the "Zones, Instances, Bosses and Items" box. ld() returns the load table, changed() saves and redraws, locked() greys
-- every row out (a group's Never / Always), searchBox is Options' item search.
function ns.LoadIdRows(ld, changed, locked, searchBox)
    local placeAt, place
    local function Place()
        local t = GetTime and GetTime() or 0
        if placeAt ~= t then placeAt, place = t, (ns.LoadPlaceNow and ns.LoadPlaceNow()) or {} end
        return place
    end
    local function add(field, id)
        if not id then return end
        local l = ld()
        l[field] = l[field] or {}
        l[field][tostring(id)] = true
        changed()
    end
    local args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "small",
            name = function()
                if not ns.LoadPlaceNow then
                    return "|cffff6060These need XayaUI core 0.6.28 or newer. Copy every XayaUI folder again, then restart the game.|r"
                end
                return "IDs separated by commas or spaces. A minus before an ID (-1234) means NOT there. An empty box restricts nothing."
            end },
    }
    for i, r in ipairs(ns.LOAD_ID_ROWS) do
        local f = r.field
        args["ids_" .. f] = { type = "input", name = r.name, order = i, width = "double", desc = r.desc, disabled = locked,
            get = function() return ns.LoadIdText(ld()[f]) end,
            set = function(_, v) ld()[f] = ns.LoadIdParse(v); changed() end }
        if r.cur then
            args["now_" .. f] = { type = "description", order = i + 0.1, width = "normal", fontSize = "small",
                name = function()
                    local id, nm = r.cur(Place())
                    if id == nil then return "Here: unknown" end
                    return "Here: " .. (nm and (nm .. " (" .. id .. ")") or tostring(id))
                end }
            args["add_" .. f] = { type = "execute", name = "Add current", order = i + 0.2,
                disabled = function() return locked() or r.cur(Place()) == nil end,
                func = function() add(f, (r.cur(Place()))) end }
        end
        if f == "difficulties" then
            args.pick_difficulties = { type = "select", name = "Add a difficulty", order = i + 0.3, width = "normal", disabled = locked,
                values = function() local v = ns.DifficultyChoices(); return v end,
                sorting = function() local _, o = ns.DifficultyChoices(); return o end,
                get = function() return nil end,
                set = function(_, v) add(f, tonumber(v)) end }
        elseif f == "equipped" and searchBox then
            local sb = searchBox(i + 0.3, function(id) add(f, id) end, "Add an item", "item")
            if sb then sb.disabled = locked; args.search_equipped = sb end
        end
    end
    return args
end

-- Each choice cycles selected -> NOT -> cleared (AceGUI's tri-state goes true -> nil -> false). An unset choice reads false (unticked);
-- "none ticked = any" is shown by the All box. Audit D20: an unset box read true, so the first click stored NOT and "selected" could never
-- be stored.
local function TriGroup(name, order, hiddenFn, getSet, choices, onChange)
    local args = {
        all = { type = "toggle", name = "All", order = 0, width = "double",
            desc = "No restriction. Click a box below once to select it, twice for NOT, a third time to clear it.",
            get = function() return next(getSet()) == nil end,
            set = function(_, v) if v then wipe(getSet()) end onChange() end },
    }
    for i, ch in ipairs(choices) do
        args["c" .. i] = { type = "toggle", tristate = true, order = i, width = "double",
            desc = "Click to select it; click again for NOT (must not be this). A third click clears it.",
            name = function()
                if getSet()[ch.id] == "not" then return "|cffff5555NOT|r  " .. ch.text end
                return ch.text
            end,
            get = function()
                local set = getSet()
                local st = set[ch.id]
                if st == true then return true end
                if st == "not" then return nil end
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
                    arg = { xuiLeft = true, xuiChevron = function() return not isShut() end },   -- open / close button at the left (Skin.lua)
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
        "buff " .. tf(info.buffOK) .. "  present=" .. tostring(info.present) .. "  via " .. tostring(info.buffSource)
            .. ((ns.HiddenAuraNote and ns.HiddenAuraNote(rule, info)) and ("\n|cffffaa00" .. ns.HiddenAuraNote(rule, info) .. "|r") or ""),
        "talent " .. tf(info.talentOK) .. "  (" .. tostring(info.talentDetail) .. ")   load " .. tf(info.ctxOK)
            .. (info.ctxFail and ("  failed: " .. info.ctxFail) or ""),
        ("ctx: combat=%s group=%s raid=%s instance=%s(%s) M+=%s encounter=%s mounted=%s spec=%s role=%s"):format(
            tostring(c.combat), tostring(c.group), tostring(c.raid), tostring(c.instance), tostring(c.instanceType),
            tostring(c.mythicPlus), tostring(c.encounter), tostring(c.mounted), tostring(c.specID), tostring(c.role)),
    }, "\n")
end
-- "Maintain aspect ratio" (V.keepAspect, on by default) is about the ART inside a display (icon, texture, progress texture): it
-- keeps the picture's own proportions. The display box (Display width / height) is never touched by it, so a box of another shape
-- crops the art instead of stretching it.
--   turning it on      -> the art snaps back to its own proportions (its current width kept, height recomputed)
--   while it is on     -> Icon width / height move together at those proportions; new art snaps to its own proportions
-- When the game cannot tell the art's size (a Blizzard file ID), the art's current proportions are kept.
local artSeen = setmetatable({}, { __mode = "k" })   -- display -> the art it showed last time we looked (no saved field)
local function ArtSig(V) return tostring(V.kind) .. "|" .. tostring(V.tex) .. "|" .. tostring(V.iconSrc) .. "|" .. tostring(V.iconPath) end
local function ArtPx(x) return math.max(1, math.floor(x + 0.5)) end
local function ArtRatio(V)
    local r = ns.ArtNativeRatio and ns.ArtNativeRatio(V)
    if r then return r, true end
    local W, H = math.max(8, V.w or 128), math.max(8, V.h or 128)
    local iw, ih = tonumber(V.iconW) or 0, tonumber(V.iconH) or 0
    return (iw > 0 and iw or W) / (ih > 0 and ih or H), false
end
-- Returns false when the art's own size is unknown (nothing changed).
function ns.ResetArtAspect(V)
    artSeen[V] = ArtSig(V)
    local r, native = ArtRatio(V)
    if not native then return false end
    local W, H = math.max(8, V.w or 128), math.max(8, V.h or 128)
    local iw, ih = tonumber(V.iconW) or 0, tonumber(V.iconH) or 0
    if iw <= 0 and ih <= 0 and math.abs(W / r - H) < 1 then return true end   -- follows a display that already has the art's shape
    local aw = iw > 0 and iw or W
    local ah = aw / r
    if ah > 512 then ah = 512; aw = ah * r end
    if aw > 512 then aw = 512; ah = aw / r end
    V.iconW, V.iconH = ArtPx(aw), ArtPx(ah)
    return true
end
function ns.SeedArtAspect(V) if type(V) == "table" and artSeen[V] == nil then artSeen[V] = ArtSig(V) end end
-- From every edit (Changed): art that was swapped while the toggle is on snaps to its own proportions.
function ns.KeepArtAspect(V)
    if type(V) ~= "table" or V.keepAspect == false then return end
    local sig = ArtSig(V)
    if artSeen[V] == nil then artSeen[V] = sig elseif artSeen[V] ~= sig then ns.ResetArtAspect(V) end
end
-- Icon width / height sliders: linked at the art's proportions while the toggle is on (0 = follow the display, both axes).
function ns.ArtAspectSet(V, key, on)
    return function(_, val)
        if V.keepAspect ~= false then
            if val <= 0 then V.iconW, V.iconH = 0, 0
            else
                local r = ArtRatio(V)
                local w, h = val, val / r
                if key == "iconH" then w, h = val * r, val end
                local s = math.min(1, 512 / math.max(w, h))
                V.iconW, V.iconH = ArtPx(w * s), ArtPx(h * s)
            end
        else
            V[key] = val
        end
        on()
    end
end
-- (P3) the rule editor's part of the shared option builders; Options.lua makes ns.UI with the window's own (Sel, Rng, Tog, Notify)
ns.UI.Changed, ns.UI.SpellName, ns.UI.SpellTex, ns.UI.SearchBox = Changed, SpellName, SpellTex, SearchBox

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
-- the same builders for DisplayTab.lua (the group Display tab edits every display with the cue editor's own controls)
ns.UI.Col, ns.UI.TextStyleArgs = Col, TextStyleArgs
ns.UI.COUNT_SOURCE, ns.UI.COUNT_SOURCE_ORDER, ns.UI.ABSORB_SOURCE, ns.UI.ABSORB_SOURCE_ORDER = COUNT_SOURCE, COUNT_SOURCE_ORDER, ABSORB_SOURCE, ABSORB_SOURCE_ORDER


-- which banners (Display Options / Text / Sound) are expanded, per rule; everything starts collapsed
-- A group's options are open unless the user collapsed them (bannerOpen[rule][key] == false). The +/- button flips that.
function ns.ArrowOpen(rule, key) local b = bannerOpen[rule]; return not (b and b[key] == false) end
function ns.ArrowToggle(rule, key, order)
    return { type = "execute", order = order, width = "normal",
        name = function()
            if ns.SkinRows and ns.SkinRows() then return "Options" end   -- skin on: the open / close button is drawn at the left (Skin.lua)
            return (ns.ArrowOpen(rule, key) and "|TInterface\\Buttons\\UI-MinusButton-Up:16:16|t" or "|TInterface\\Buttons\\UI-PlusButton-Up:16:16|t") .. "  Options"
        end,
        desc = "Open or close the options below. Closing never changes any setting.",
        arg = { xuiLeft = true, xuiChevron = function() return ns.ArrowOpen(rule, key) end },
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

-- A rule's row in the sidebar: hidden while the search box has text the name does not contain; grey name while switched off. Shared by
-- the full editor (BuildRule) and the row-only entry the window builds for rules not on screen (Options 0.6.69, ns.OptionsApi.RuleStub).
function ns.OptionsApi.RuleRowHidden(rule)
    return function() local q = ns.treeFilter; return q and q ~= "" and not tostring(rule.name or ""):lower():find(q, 1, true) end
end
function ns.OptionsApi.RuleRowName(rule)
    return function()
        local nm = tostring(rule.name or "")
        if nm == "" then return "|cff888888Unnamed rule|r" end
        return (rule.enabled and "" or "|cff888888") .. nm
    end
end
-- What building a rule's editor writes into the rule's own data (BuildRule below), done also when only its row is built, so the saved
-- data is the same either way (tests/options_click_cost_run.py compares them): the outline glow's defaults, icon cues always use the
-- spell icon, and the art the rule shows now is noted for Maintain aspect ratio.
function ns.OptionsApi.RuleDataFixes(rule)
    local V = rule.visual
    if type(V) ~= "table" then return end
    local o = V.outline
    if type(o) == "table" then
        if o.style == nil then o.style = "auto" end
        for k, dv in pairs({ borderOn = true, glowOn = true, glowSame = true, gap = 0, glowSize = 8, glowAlpha = 0.6 }) do if o[k] == nil then o[k] = dv end end
        if not o.glowColor then o.glowColor = { 1, 0.82, 0, 1 } end
    end
    if rule.cueKind == "icon" and V.kind ~= "spellicon" then V.kind = "spellicon" end
    ns.SeedArtAspect(V)
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
        type = "group", name = "Trigger", order = 2, args = {   -- tab order (0.6.3): Display | Trigger | Cues | Conditions | Actions | Load | Info
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
            countGCD = Tog(rule, "countGCD", "Count the global cooldown", 4.5, on,
                { desc = "Counts the spell as on cooldown during the global cooldown. Off by default." }),
            countLOC = Tog(rule, "countLOC", "Count a lockout as cooldown", 4.55, on,
                { desc = "Counts the spell as on cooldown while an interrupt or silence locks it out. Off by default." }),
            exactSpell = Tog(rule, "exactSpell", "Exact spell ID", 4.56, on,
                { desc = "Reads exactly this spell ID, even when a talent replaces it on your bar. Off by default (follows the replacement)." }),
            -- "Seconds left" / "Charges" comparisons on the trigger itself (B2): a dropdown with its number box beside it
            cdTimeOp = Sel(rule, "cdTimeOp", "Seconds left", 4.6, ns.CMP_OPS and ns.CMP_OPS.values or { any = "Any" }, ns.CMP_OPS and ns.CMP_OPS.order or { "any" },
                function() Changed(rule); Notify() end,
                { get = function() return rule.cdTimeOp or "any" end,
                  desc = "True only while the cooldown has this much time left. In combat this can be an estimate; with none yet the trigger is unknown." }),
            cdTimeSec = { type = "input", name = "Seconds", order = 4.61, width = "half",
                hidden = function() return not ns.CooldownUsed(rule) or not rule.cdTimeOp or rule.cdTimeOp == "any" end,
                get = function() return rule.cdTimeSec ~= nil and tostring(rule.cdTimeSec) or "" end,
                set = function(_, v) rule.cdTimeSec = tonumber(v); Changed(rule) end },
            cdChargeOp = Sel(rule, "cdChargeOp", "Charges", 4.7, ns.CMP_OPS and ns.CMP_OPS.values or { any = "Any" }, ns.CMP_OPS and ns.CMP_OPS.order or { "any" },
                function() Changed(rule); Notify() end,
                { get = function() return rule.cdChargeOp or "any" end,
                  desc = "True only while the spell has this many charges. In combat the count comes from your casts." }),
            cdChargeVal = { type = "input", name = "Charges", order = 4.71, width = "half",
                hidden = function() return not ns.CooldownUsed(rule) or not rule.cdChargeOp or rule.cdChargeOp == "any" end,
                get = function() return rule.cdChargeVal ~= nil and tostring(rule.cdChargeVal) or "" end,
                set = function(_, v) rule.cdChargeVal = tonumber(v); Changed(rule) end },
            maxCharges = Rng(rule, "maxCharges", "Max charges override (0 = auto)", 5, 0, 6, 1, on,
                { desc = "Only used if the game reports no charge data. Auto-detection normally wins." }),
            detected = { type = "description", order = 6, width = "full", name = function() return DetectedMax(rule.spellID) end },
            buffHeader = { type = "header", name = "Buff / Aura", order = 10 },
            buffState = Sel(rule, "buffState", "State", 11, BUFF_VALUES, BUFF_ORDER, function() Changed(rule); Notify() end),
            -- "with N seconds left" (0.6.4, #173 / #278 / #314): only while State is "present"; unknown time keeps the trigger unknown
            buffTimeOp = Sel(rule, "buffTimeOp", "Seconds left", 11.1, ns.TIME_OPS and ns.TIME_OPS.values or { any = "Any time left" }, ns.TIME_OPS and ns.TIME_OPS.order or { "any" },
                function() Changed(rule); Notify() end,
                { get = function() return rule.buffTimeOp or "any" end,
                  hidden = function() return not ns.BuffUsed(rule) or rule.buffState ~= "present" end,
                  desc = "True only while the buff has this much time left. In combat this can be an estimate; with none yet the rule waits." }),
            buffTimeSec = { type = "input", name = "Seconds", order = 11.2, width = "half",
                hidden = function() return not ns.BuffUsed(rule) or rule.buffState ~= "present" or not rule.buffTimeOp or rule.buffTimeOp == "any" end,
                get = function() return rule.buffTimeSec ~= nil and tostring(rule.buffTimeSec) or "" end,
                set = function(_, v) rule.buffTimeSec = tonumber(v); Changed(rule) end },
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
                for _, x in ipairs(type(rule.buffAlt) == "table" and rule.buffAlt or {}) do if x == id then return end end
                local out, over = ns.AuraIDList(rule.buffID, rule.buffAlt, { id })   -- the shared list rule (TreeHelpers.lua)
                if over > 0 then ns.Print("a trigger can watch at most " .. ns.AURA_ALT_MAX .. " extra aura IDs"); return end
                rule.buffAlt = out; Changed(rule); Notify()
            end, "Also count these auras: search to add another", "aura"),
            buffAlt = {
                type = "input", name = "Extra aura IDs (comma separated; any one counts)", order = 13.2, width = "full",
                desc = "Other aura IDs that count as this same buff: present if any is on you, missing only if all are absent. Delete an ID from the box to remove it.",
                get = function() local t = type(rule.buffAlt) == "table" and rule.buffAlt or {}; local o = {}; for i, v in ipairs(t) do o[i] = tostring(v) end; return table.concat(o, ", ") end,
                set = function(_, v)
                    rule.buffAlt = ns.AuraIDList(rule.buffID, tostring(v or ""))   -- numbers, no repeats, not the main ID, at most 30 (TreeHelpers.lua)
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
    for _, k in ipairs({ "cdHeader", "spellID", "spellName", "spellSearch", "spellPick", "cdState", "countGCD", "countLOC", "exactSpell", "cdTimeOp", "cdChargeOp", "maxCharges", "detected" }) do
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
        func = function()
            if ns.IsEditLocked(rule) then return end
            if ns.RecycleTrigger then ns.RecycleTrigger(rule, "cd") end   -- FA-11: to the Recycle Bin (no prompt), restorable
            rule.useCooldown = false; rule.spellID = 0; rule.maxCharges = 0; rule.cdState = nil
            rule.countGCD, rule.countLOC, rule.cdTimeOp, rule.cdTimeSec, rule.cdChargeOp, rule.cdChargeVal = nil, nil, nil, nil, nil, nil
            rule.exactSpell = nil
            Changed(rule); Notify()
        end }
    trigger.args.buffRemove = { type = "execute", name = "Remove", order = 14, width = "half",
        desc = "Remove the Buff / Aura trigger: clears this rule's aura ID and state.",
        hidden = function() return not ns.BuffUsed(rule) end,
        func = function()
            if ns.IsEditLocked(rule) then return end
            if ns.RecycleTrigger then ns.RecycleTrigger(rule, "buff") end   -- FA-11: to the Recycle Bin (no prompt), restorable
            rule.useBuff = false; rule.buffID = 0; rule.buffAlt = nil; rule.buffState = nil
            rule.buffTimeOp, rule.buffTimeSec = nil, nil   -- audit D25: re-adding the trigger no longer brings back an old "Seconds left" filter
            Changed(rule); Notify()
        end }
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
            desc = "Requires certain talents; the talent list appears below once ticked.",
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
        { desc = "ALL: every listed talent must match; ANY: one match is enough. Add talents below." })
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
                and "|cffffd100Always load is ticked:|r the options below are kept but not used, except a Class or Specialization row whose \"Always load: only this ...\" box is ticked. Tick Match ALL or Match ANY to make them all count."
                or "|cffffd100Never load is ticked:|r this rule does not load, so the options below are kept but not used. Tick Match ALL or Match ANY to make them count."
        end }
    local loadModeKeys = AddSquareRadio(loadArgs, "loadMode", 0.5, LOAD_MODE, LOAD_MODE_ORDER,
        function() return rule.load.mode or "all" end,
        function(v) rule.load.mode = v; Changed(rule); Notify() end,
        { desc = "Sets when the rule loads: Never, Always (ignores load conditions), or Match the conditions you set below (ALL or ANY)." })
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
                -- #2 (Xaya: "three-click toggle (Known green / Not known red / not set)"): the same click pattern as the load conditions
                -- below: click once Known (green), again Not known (red), a third time not set (no bearing on loading)
                state = { type = "toggle", tristate = true, order = 2, width = 1.2, name = function()
                        if t.state == "none" then return "Not set" end
                        if t.state == "notKnown" then return "|cffff5555Not known|r" end
                        return "|cff55ff55Known|r"
                    end,
                    desc = "Click: Known (green) -> Not known (red) -> Not set (this talent has no bearing on loading) -> Known.",
                    get = function()
                        if t.state == "none" then return false end
                        if t.state == "notKnown" then return nil end
                        return true
                    end,
                    set = function(_, v)
                        if v == true then t.state = "known" elseif v == nil then t.state = "notKnown" else t.state = "none" end
                        Changed(rule); Notify()
                    end },
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
    loadArgs.classHeader = { type = "header", name = "Class / Specialization / Role", order = 0.55, hidden = noMatch }
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
    local function classSet() rule.load.classes = rule.load.classes or {}; return rule.load.classes end
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
    loadArgs.classes = ns.RadioGroup("Class", 0.57, noMatch, classSet, ns.ClassChoices(), onSpecRole, function() return rule.load end, "classUse", rule, "classes", true, "alwaysClass", "class")
    loadArgs.specs = ns.RadioGroup("Specialization", 0.6, noMatch, specSet, SpecChoices(), onSpecRole, function() return rule.load end, "specUse", rule, "specs", true, "alwaysSpec", "spec")
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
    -- Zones, instances, difficulties, sizes, boss encounters and equipped items (core 0.6.28): one ID list each, in a box that starts
    -- closed unless a list holds IDs. A folder's Never / Always locks them like the other rows.
    do
        local ld = rule.load
        local anyIds = false
        for _, r in ipairs(ns.LOAD_ID_ROWS) do if ns.SetActive(ld[r.field]) then anyIds = true end end
        bannerOpen[rule] = bannerOpen[rule] or {}
        local bo = bannerOpen[rule]
        if bo.loadIdsInit == nil then bo.loadIdsInit = true; if not anyIds then bo.loadIds = false end end
        local body = ns.LoadIdRows(function() return rule.load end, function() Changed(rule); Notify() end,
            function() return folderLoadOv() ~= nil end, SearchBox)
        loadArgs.loadIds = { type = "group", inline = true, name = "Zones, Instances, Bosses and Items", order = 50, xuiRule = rule,
            args = {
                open = ns.ArrowToggle(rule, "loadIds", 1),
                body = { type = "group", inline = true, name = "", order = 2,
                    hidden = function() return not ns.ArrowOpen(rule, "loadIds") end, args = body },
            } }
    end
    local lockKeys = { "instanceTypes", "classes", "specs", "roles", "heroes" }
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
    local load = { type = "group", name = "Load", order = 6, args = loadArgs }

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
    ns.SeedArtAspect(V)   -- the art shown now: a later swap is detected against it (Maintain aspect ratio)
    local tex = {
        type = "group", inline = true, name = "Texture", order = 10, args = {
            kind = Sel(V, "kind", "Source", 1, TEX_KIND, TEX_KIND_ORDER, function() Changed(rule); Notify() end,
                { width = "double", hidden = function() return V.kind == "spellicon" end,
                  desc = "Picks where the art comes from. Atlas (Blizzard UI art by name) is advanced; most people use 'Texture ID / path' or the art list." }),
            iconSrc = Sel(V, "iconSrc", "Icon source", 1, ns.ICON_SRC, ns.ICON_SRC_ORDER, function() Changed(rule); Notify() end,
                { width = "double", hidden = function() return V.kind ~= "spellicon" end, get = function() return V.iconSrc or "auto" end,
                  desc = "Automatic takes the icon from the rule's first trigger with a spell or item. Or pick a spell, an item, or your own icon file." }),
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
                desc = "Path to your icon, e.g. Interface\\AddOns\\XayaUI_Media\\Icons\\myicon.png. It must be square, at most 200x200, with power-of-two sides (32, 64, 128).",
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
                    ns.ApplyArtPick(V, k)   -- shared with the auto-populate table's picture picker
                    Changed(rule); Notify()
                end },
            sizeH = { type = "header", name = "Size & Orientation", order = 10 },
            w = Rng(V, "w", "Display width", 11, 8, 512, 1, on,
                { desc = "Sets the width of the display's box (border, swipe, glow, click area). Art of another shape is cropped to it; the art has its own size below." }),
            h = Rng(V, "h", "Display height", 12, 8, 512, 1, on,
                { desc = "Sets the height of the display's box (border, swipe, glow, click area). Art of another shape is cropped to it; the art has its own size below." }),
            keepAspect = { type = "toggle", name = "Maintain aspect ratio (art)", order = 12.5, width = "double",
                desc = "Keeps the art in its own proportions: Icon width and height move together. The display box is not changed, so it can crop the art.",
                get = function() return V.keepAspect ~= false end,
                set = function(_, v)
                    V.keepAspect = v and true or false
                    if v and not ns.ResetArtAspect(V) then
                        ns.Print("The game cannot report this art's own size (it is a file ID), so its current proportions are kept and locked.")
                    end
                    on(); Notify()
                end },
            iconW = Rng(V, "iconW", "Icon width (0 = same as display)", 13, 0, 512, 1, on, { set = ns.ArtAspectSet(V, "iconW", on),
                desc = "Sets the art's width inside the display; wider than the display crops the sides. 0 follows the display." }),
            iconH = Rng(V, "iconH", "Icon height (0 = same as display)", 13.2, 0, 512, 1, on, { set = ns.ArtAspectSet(V, "iconH", on),
                desc = "Sets the art's height inside the display; taller than the display crops the top and bottom. 0 follows the display." }),
            rotation = Rng(V, "rotation", "Rotation (degrees)", 14, 0, 360, 1, on,
                { desc = "Rotates the art about its center. Works best on square art." }),
            flipH = Tog(V, "flipH", "Mirror (flip horizontally)", 15, on),
            flipV = Tog(V, "flipV", "Flip vertically", 16, on),
            zoom = Rng(V, "zoom", "Zoom / crop edges", 17, 0, 0.3, 0.01, on),
            colorH = { type = "header", name = "Color & Blend", order = 20 },
            additive = Tog(V, "additive", "Additive blend", 21, on),
            desaturate = Tog(V, "desaturate", "Desaturate the base texture", 22, on,
                { width = "double", desc = "Greys the art; with a tint below it gives an even recolor. Locked on progress textures unless Advanced customization (Opacity & Fill) is on.",
                  disabled = function() return ProgLocked() end,
                  get = function() if ProgLocked() then return V.recolor and true or false end return V.desaturate and true or false end }),
            recolor = Tog(V, "recolor", "Tint the base texture", 23, on,
                { desc = "Tints the art with this color." }),
            tint = Col(V, "tint", "Tint color", 23.5, on, { disabled = function() return not V.recolor end }),
            fadeH = { type = "header", name = "Fade, Opacity & Flash as the Buff Runs Out", order = 30 },
            fadeGrey = Tog(V, "fadeGrey", "Fade gradually as the buff runs out", 31, on, { width = "double",
                desc = "Fades the art as the Trigger tab's aura runs out (experimental in combat). Needs Show set to 'While the buff is present'." }),
            fadeMode = Sel(V, "fadeMode", "Fade to", 32, { none = "(none - grey)", color = "A color", transparent = "Transparent" }, { "none", "color", "transparent" }, on,
                { disabled = function() return not V.fadeGrey end }),
            fadeColor = Col(V, "fadeColor", "Fade color", 33, on,
                { disabled = function() return not (V.fadeGrey and ns.Val(V.fadeMode) == "color") end }),
            flashOn = Tog(V.flash, "enabled", "Flash when about to expire", 34, on, { width = "double" }),
            flashAt = Rng(V.flash, "threshold", "Start flashing at (seconds left)", 35, 1, 15, 0.5, on,
                { disabled = function() return not V.flash.enabled end }),
            flashSpeed = Rng(V.flash, "speed", "Flash speed (pulses per second)", 36, 1, 8, 0.5, on,
                { disabled = function() return not V.flash.enabled end }),
            desatOnCD = Tog(V, "desatOnCD", "Grey out while the spell is on cooldown", 37, on, { width = "double" }),
            hoverTip = Tog(V, "hoverTip", "Show tooltip on hover", 9.6, on, { width = "double", hidden = true,   -- set on the rule's Display tab (0.6.3)
                desc = "Shows the spell or item's tooltip when you hover this cue. Clicks still pass through." }),
            requireOnBar = Tog(V, "requireOnBar", "Only show while this ability is on an action bar", 9.5, on, { width = "double",
                desc = "Hides the display while the rule's spell is not on any of your action bars. Off by default." }),
            fxH = { type = "header", name = "Glow & Outline", order = 40 },
            glow = Tog(V, "glow", "Pulsing glow", 41, on),
            olOn = Tog(V.outline, "enabled", "Outline glow (pixel border + glow)", 42, on, { width = "double",
                desc = "Draws a crisp pixel border with an optional soft glow. On by default for spell icons." }),
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
                  desc = "Greys the overlay layer. Progress textures keep it ungreyed unless Advanced customization (Overlay Layer) is on.",
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
                  desc = "On progress textures this follows Overlay opacity below, unless Advanced customization (Overlay Layer) is on." }),
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
                desc = "Fades the opacity from the full-duration value to the expiry value. Needs 'Show' set to 'While the buff is present'." }),
            fadeAlphaMax = Rng(V, "fadeAlphaMax", "Opacity at full duration", 12, 0, 1, 0.05, on,
                { width = "double", disabled = function() return not V.fadeAlpha end }),
            fadeAlphaMin = Rng(V, "fadeAlphaMin", "Opacity at expiry", 13, 0, 1, 0.05, on,
                { width = "double", disabled = function() return not V.fadeAlpha end }),
            fillH = { type = "header", name = "Progress-Bar Wipe (Fill)", order = 20 },
            fillOn = Tog(FL, "enabled", "Wipe the art like a progress bar as the buff runs out", 21, on, { width = "full",
                desc = "Wipes the art away as the buff runs out. Stays full while the game hides aura times." }),
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
                  desc = "Lets you set a progress texture's base opacity, base grey and overlay grey on their own. Off: they stay linked." }),
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
            -- P1 (#268; Xaya 2026-11-06, her labels: "Anchor point" -> "Anchored to" -> "To <target>'s point")
            point = { type = "select", name = "Anchor point", order = 0.4, width = "double",
                desc = "Sets which point of this display is placed; the display stays put. Ignored when snapped to a game frame or in dynamic groups.",
                values = ANCHOR_VALUES, sorting = ANCHOR_ORDER,
                get = function() local _, f = ns.VisualPoints(rule); return f end,
                set = function(_, val) ns.SetVisualPoints(rule, val, nil); ns.MarkDirty(); Notify() end },
            anchoredTo = { type = "description", order = 0.45, width = "full", fontSize = "medium",
                name = function()
                    local kind, nm = ns.VisualAnchorTarget(rule)
                    local what = kind == "screen" and "The screen" or kind == "frame" and (nm .. " (snapped)")
                        or kind == "dynamic" and ("Group: " .. nm .. " (a dynamic group places its displays itself)") or ("Group: " .. nm)
                    return "|cffffd100Anchored to:|r " .. what
                end },
            anchor = { type = "select", order = 0.5, width = "double",
                name = function()
                    local kind, nm = ns.VisualAnchorTarget(rule)
                    return kind == "screen" and "To the screen's point" or ("To " .. nm .. "'s point")
                end,
                desc = "Sets the point of the screen or group box that X and Y are measured from; the display stays put. Ignored when snapped to a game frame or in dynamic groups.",
                values = ANCHOR_VALUES, sorting = ANCHOR_ORDER,
                get = function() local a = ns.VisualPoints(rule); return a end,
                set = function(_, val) ns.SetVisualPoints(rule, nil, val); ns.MarkDirty(); Notify() end },
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
    cntArgs.enabled = Tog(C, "enabled", "Show a count", 1, on, { desc = "Shows aura stacks or spell charges. Experimental: the number can only be shown, not compared." })
    cntArgs.source = Sel(C, "source", "Count of", 2, COUNT_SOURCE, COUNT_SOURCE_ORDER, on)
    -- #300: only counts the rule's triggers can have (stacks of an aura that stacks, charges of a spell with more than one); the choice in use stays
    local function CountSup() local okc, cs = pcall(ns.CountSupport or function() return { any = true, stacks = true, charges = true } end, rule); return okc and cs or { any = true, stacks = true, charges = true } end
    cntArgs.source.values = function()
        local cs, v = CountSup(), {}
        for k, label in pairs(COUNT_SOURCE) do
            if k == C.source or (k == "none" and cs.stacks) or (k == "stacks" and cs.stacks) or (k == "charges" and cs.charges) then v[k] = label end
        end
        if not next(v) then v.none = COUNT_SOURCE.none end
        return v
    end
    -- (Rules Options 0.6.82, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #26 "visual cuts off"): the option is kept in a local, because
    -- ns.GateRest below moves it into the "Count options" pane (cntArgs.source is nil after that); reading cntArgs.source here raised
    -- a Lua error while the pane was drawn, so the pane and every section after it stayed empty
    local srcOpt = cntArgs.source
    srcOpt.sorting = function()
        local v, o = srcOpt.values(), {}
        for _, k in ipairs(COUNT_SOURCE_ORDER) do if v[k] then o[#o + 1] = k end end
        return o
    end
    local function CountHidden() return not (C.enabled or CountSup().any) end
    ns.GateRest(rule, cntArgs, "cnt", "Count options", 5, function() return C.enabled end, { enabled = true })
    local AB = V.absorb
    local absArgs = TextStyleArgs(AB, on, 10)
    absArgs.enabled = Tog(AB, "enabled", "Show shield / absorb amount", 1, on, { desc = "Shows the shield amount. Experimental: it can only be shown, not compared or used as a condition." })
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
                get = function() return rule.sound.enabled end, set = function(_, v) rule.sound.enabled = v; ns.MarkDirty() end },
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
                    if v == "0" then rule.sound.value = ""; ns.MarkDirty(); return end
                    local it = soundList[tonumber(v)]
                    if it then rule.sound.source, rule.sound.value = it.source, it.value; ns.MarkDirty() end
                end,
            },
            test = { type = "execute", name = "Test sound", order = 3, width = "half", func = function() ns.PlaySoundPreview(rule.sound) end },
            soundPath = { type = "input", name = "Or type a sound file path  (.ogg or .mp3, inside Interface\\AddOns)", order = 3.5, width = "full",
                desc = "Plays your own .ogg or .mp3; keep it in XayaUI_Media so an update never deletes it. The file must exist before you log in or /reload; leave empty to use the list.",
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
                get = function() return rule.repeatSec or 0 end, set = function(_, v) rule.repeatSec = v; ns.MarkDirty() end },
            channel = { type = "select", name = "Sound channel", order = 5, values = CHANNEL_VALUES, sorting = CHANNEL_ORDER,
                get = function() return rule.sound.channel end, set = function(_, v) rule.sound.channel = v; ns.MarkDirty() end },
            -- #334 (Insivius): a volume on the cue's own sound, like Speech volume. The game allows it only for its own sound kits.
            cueVolume = { type = "range", order = 5.5, width = "double", min = 0, max = 100, step = 5,
                name = function()
                    if rule.sound.source == "kit" then return "This cue's volume" end
                    return "This cue's volume (only for [Game] sounds)"
                end,
                desc = "Sets this cue's volume, for [Game] sounds only. Sound files play at the channel volume below.",
                disabled = function() return rule.sound.source ~= "kit" end,
                get = function() return tonumber(rule.sound.cueVolume) or 100 end,
                set = function(_, v) rule.sound.cueVolume = (tonumber(v) and v < 100) and v or nil; ns.MarkDirty() end },
            volume = {
                type = "range", name = function()
                    return "Volume of the '" .. (ns.Val(rule.sound.channel) or "Master") .. "' channel (game setting, shared)"
                end,
                order = 6, width = "double", min = 0, max = 1, step = 0.05, isPercent = true,
                desc = "Sets the game's volume for this channel, which changes everything else on it too (same as Options > Sound).",
                get = function() return ns.GetChannelVolume(rule.sound.channel) end,
                set = function(_, v) ns.SetChannelVolume(rule.sound.channel, v) end,
            },
            note = { type = "description", order = 9, fontSize = "small",
                name = "Sounds you add to Media\\Audio need a full game restart before they can play. Use the headphone icon in the sidebar to loop this sound while you edit." },
            -- Decision D2 (AuraSound.lua): the game plays the sound on the aura itself, so it works while the aura is hidden in combat
            gameSoundOn = { type = "toggle", order = 10, width = "full",
                name = "Let the game play this sound on the aura itself (works in combat while the aura is hidden)",
                desc = "Plays this sound file when the trigger's aura is gained or lost, even in combat; the rule's other triggers, conditions and Repeat are ignored. Set up out of combat only.",
                hidden = function() return not (ns.AuraSound and ns.AuraSound.Available()) end,
                get = function() return type(rule.gameSound) == "table" and rule.gameSound.enabled == true end,
                set = function(_, v)
                    rule.gameSound = type(rule.gameSound) == "table" and rule.gameSound or { channel = "Ambience", throttle = 1, when = "auto" }
                    rule.gameSound.enabled = v and true or false
                    ns.MarkDirty(); Notify()
                end },
            gameSoundWhen = { type = "select", order = 11, name = "Game plays it", width = "double",
                hidden = function() return not (type(rule.gameSound) == "table" and rule.gameSound.enabled) end,
                values = function() return ns.AuraSound and ns.AuraSound.WHEN_VALUES or {} end,
                sorting = function() return ns.AuraSound and ns.AuraSound.WHEN_ORDER or {} end,
                get = function() return rule.gameSound.when or "auto" end,
                set = function(_, v) rule.gameSound.when = v; ns.MarkDirty(); Notify() end },
            gameSoundChannel = { type = "select", order = 12, name = "Channel for the game's copy", values = CHANNEL_VALUES, sorting = CHANNEL_ORDER,
                desc = "Its own channel (default Ambience), so you can lower or mute it on its own in the game's sound settings.",
                hidden = function() return not (type(rule.gameSound) == "table" and rule.gameSound.enabled) end,
                get = function() return rule.gameSound.channel or "Ambience" end,
                set = function(_, v) rule.gameSound.channel = v; ns.MarkDirty(); Notify() end },
            gameSoundThrottle = { type = "range", order = 13, name = "At most once every (seconds)", min = 0, max = 10, step = 0.5,
                hidden = function() return not (type(rule.gameSound) == "table" and rule.gameSound.enabled) end,
                get = function() return tonumber(rule.gameSound.throttle) or 1 end,
                set = function(_, v) rule.gameSound.throttle = v; ns.MarkDirty() end },
            gameSoundAlso = { type = "toggle", order = 14, width = "full",
                name = "Also play it from XayaUI when the rule fires (two sounds out of combat)",
                hidden = function() return not (type(rule.gameSound) == "table" and rule.gameSound.enabled) end,
                get = function() return rule.gameSound.alsoXayaUI == true end,
                set = function(_, v) rule.gameSound.alsoXayaUI = v and true or nil; ns.MarkDirty() end },
            gameSoundStatus = { type = "description", order = 15, width = "full", fontSize = "small",
                hidden = function() return not (type(rule.gameSound) == "table" and rule.gameSound.enabled) end,
                name = function()
                    -- Insivius 2026-11-04: "attempt to index field 'AuraSound' (a nil value)" here broke the whole cue pane. AuraSound.lua
                    -- is part of XayaUI core (0.6.13+); a core folder without it (older, or copied without a game restart) must not break this.
                    if not (ns.AuraSound and ns.AuraSound.StatusLine) then
                        return "|cffff6060The game-played sound needs XayaUI core 0.6.13 or newer. Copy every XayaUI folder again, then restart the game (a /reload does not load new files).|r"
                    end
                    local ok, s = pcall(ns.AuraSound.StatusLine, rule); return ok and s or ""
                end },
        },
    }

    -- 3b) Speech (text-to-speech cue): a sound whose source is "tts"; shown only on Speech cues (see Outcomes.lua)
    local speechBody = {
        text = { type = "input", name = "Text to speak", order = 1, width = "full",
            desc = "Spoken when the cue fires. Plain text; no tokens yet.",
            get = function() return rule.sound.value or "" end,
            set = function(_, v) rule.sound.source = "tts"; rule.sound.value = tostring(v or ""):sub(1, 200); ns.MarkDirty() end },
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
            set = function(_, v) v = tonumber(v); rule.sound.voice = (v and v ~= 0) and v or nil; ns.MarkDirty() end },
        test = { type = "execute", name = "Test speech", order = 3, width = "half", func = function() ns.PlaySoundPreview(rule.sound) end },
        rate = { type = "range", name = "Speed", order = 4, width = "double", min = -10, max = 10, step = 1,
            get = function() return rule.sound.rate or 0 end, set = function(_, v) rule.sound.rate = v; ns.MarkDirty() end },
        vol = { type = "range", name = "Speech volume", order = 5, width = "double", min = 0, max = 100, step = 5,
            get = function() return rule.sound.ttsVolume or 100 end, set = function(_, v) rule.sound.ttsVolume = v; ns.MarkDirty() end },
        repeatSec = { type = "range", name = "Repeat every (seconds, 0 = once)", order = 6, width = "double", min = 0, max = 10, step = 0.1,
            get = function() return rule.repeatSec or 0 end, set = function(_, v) rule.repeatSec = v; ns.MarkDirty() end },
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
                hdr = { type = "execute", order = 1, width = "full", arg = { xuiLeft = true, xuiChevron = function() return subst()[key] and true or false end },
                    name = function()
                        if ns.SkinRows and ns.SkinRows() then return title end   -- skin on: the open / close button is drawn at the left
                        return (subst()[key] and ARROW_OPEN or ARROW_CLOSED) .. "  " .. title
                    end,
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
    local posArgs = { point = pos.args.point, anchoredTo = pos.args.anchoredTo, anchor = pos.args.anchor, x = pos.args.x, y = pos.args.y, unlock = pos.args.unlock }
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
    local conditionsTab = { type = "group", name = "Conditions", order = 4, args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "IF the checks are met, THEN the chosen cues play. Add one condition per situation you care about." },
    } }
    local cuesTab = { type = "group", name = "Cues", order = 3, args = {} }
    local actions = { type = "group", name = "Actions", order = 3.5, args = {
        display = Banner("display", "Display Options", 1, display.args.enabled, dispBody, function() return V.enabled and true or false end),
        text = Banner("text", "Text", 2, textEnable, {
            dur = Sub("dur", "Buff Duration Text", 1, durArgs),
            cnt = Sub("cnt", "Stacks / Charges Count", 2, cntArgs, CountHidden),
            abs = Sub("abs", "Shield / Absorb Amount", 3, absArgs),
        }, function() return (T.enabled or C.enabled or AB.enabled) and true or false end),
        sound = Banner("sound", "Sound", 3, soundEnable, soundBody, function() return rule.sound.enabled and true or false end),
    } }
    -- A Bar cue's own options (BarCue.lua; RM-BARS, Xaya 2026-11-06, docs/process/REQUEST-LOG.md S8-1 .. S8-4). Built only for a Bar cue.
    local barArgs, barTextArgs
    if V.kind == "bar" and ns.BarCueSettings then
        local B = ns.BarCueSettings(V)
        -- bon (with a window redraw) only for the choices that show or hide other rows; sliders and colors use `on`: AceConfigDialog
        -- calls their set on every drag step and redraws by itself on mouse up / picker close (review R5: a full rebuild per drag step)
        local function bon() Changed(rule); Notify() end
        local SRC = { auto = "Automatic", aura = "Aura time left", cooldown = "Spell cooldown / recharge", stacks = "Stacks", charges = "Charges" }
        local SRC_ORDER = { "auto", "aura", "cooldown", "stacks", "charges" }
        local DIR = { left = "Left (drains right to left)", right = "Right (drains left to right)", bottom = "Bottom (drains top to bottom)", top = "Top (drains bottom to top)" }
        local DIR_ORDER = { "left", "right", "bottom", "top" }
        local function counting() local sr = ns.BarCueSource(rule); return sr == "stacks" or sr == "charges" end
        local function hdr(name, order) return { type = "header", name = name, order = order } end
        barArgs = {
            sizeH = hdr("Size", 1),
            w = Rng(V, "w", "Width", 1.1, 20, 800, 1, on),
            h = Rng(V, "h", "Height", 1.2, 4, 200, 1, on),
            trackH = hdr("Tracks", 2),
            source = Sel(B, "source", "Tracks", 2.1, SRC, SRC_ORDER, bon, { width = "double",
                desc = "Sets what the bar tracks. Automatic: the aura's time left when the rule watches an aura, else the spell's cooldown." }),
            srcNow = { type = "description", order = 2.2, width = "full", fontSize = "medium",
                name = function()
                    local sr, id = ns.BarCueSource(rule), ns.BarCueSpell(rule)
                    if id <= 0 then return "|cffffd100The rule has no " .. ((sr == "cooldown" or sr == "charges") and "cooldown spell" or "aura") .. " yet.|r Add one on the Trigger tab." end
                    return "Now: " .. SRC[sr] .. " of " .. SpellName(id)
                end },
            max = Rng(B, "max", "Maximum (0 = what the game says)", 2.3, 0, 50, 1, on, { width = "double", hidden = function() return not counting() end,
                desc = "The value at which the bar is full. 0 uses the game's maximum: the aura's maximum stacks, or the spell's maximum charges." }),
            maxNow = { type = "description", order = 2.4, width = "full", fontSize = "medium", hidden = function() return not counting() end,
                name = function()
                    local okc, cd = pcall(ns.ReadCooldown, rule)
                    local m = ns.BarCueMax(rule, okc and cd or nil)
                    if m then return "Full at " .. m end
                    return "|cffffd100The game gives no maximum here: set Maximum.|r Until then the bar stays empty."
                end },
            fillH = hdr("Fill", 3),
            dir = Sel(B, "dir", "Drains toward", 3.1, DIR, DIR_ORDER, bon, { width = "double" }),
            reverse = Tog(B, "reverse", "Fill up instead of draining", 3.2, bon, { width = "double", desc = "Time bars only. A stacks / charges bar always fills by the count." }),
            texture = { type = "select", name = "Bar texture", order = 3.3, width = "double",
                desc = "Sets the bar texture: built-in, the game's power-bar art, other addons' shared textures, or your own file. Power-bar art is already colored; Fixed white shows it as drawn.",
                values = function() local vv = ns.BarTextureList(); return vv end,
                sorting = function() local _, o = ns.BarTextureList(); return o end,
                get = function() return B.texture or "flat" end, set = function(_, x) B.texture = x; bon() end },
            texFile = { type = "input", name = "Texture ID / path", order = 3.4, width = "double", hidden = function() return B.texture ~= "file" end,
                get = function() return tostring(B.texFile or "") end, set = function(_, x) B.texFile = tostring(x or ""); bon() end },
            colH = hdr("Color", 4),
            colorMode = Sel(B, "colorMode", "Color", 4.1, { auto = "Automatic (the type the tooltip names, then the dispel type, then blue)", fixed = "Fixed color" },
                { "auto", "fixed" }, bon, { width = "double" }),
            color = Col(B, "color", "Bar color", 4.2, on, { hidden = function() return B.colorMode ~= "fixed" end }),
            colorNow = { type = "description", order = 4.3, width = "full", fontSize = "medium", hidden = function() return B.colorMode == "fixed" end,
                name = function()
                    local okc, r, g, b2, a, why, t, d = pcall(ns.BarCueColor, rule, nil)
                    if not okc then return "" end
                    local sw = ("|TInterface\\Buttons\\WHITE8X8:12:28:0:0:8:8:0:8:0:8:%d:%d:%d|t"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b2 * 255 + 0.5))
                    local st, cu = ns.BarCueStyle(rule)
                    local what = (why == "tooltip") and (ns.BarTypeLabel(t, d, st, cu) .. ", named in the tooltip")
                        or (why == "dispel") and (ns.BarTypeLabel(t, nil, st, cu) .. ", the aura's dispel type")
                        or "the fixed blue (no type found yet; an aura's dispel type is read while it is up)"
                    return "Now: " .. sw .. "  " .. what .. "."
                end },
            -- the colour style of THIS bar (Xaya S8-10: "Cue sets it, group overrides if forcibly set")
            styleForced = { type = "description", order = 4.4, width = "full", fontSize = "medium",
                hidden = function() local _, _, gf = ns.BarCueStyle(rule); return B.colorMode == "fixed" or gf == nil end,
                name = function()
                    local st, _, gf = ns.BarCueStyle(rule)
                    return gf and ("|cffffd100Color style: " .. (ns.BAR_STYLE_LABEL[st] or st) .. ", forced by the group '" .. tostring(gf.name) .. "'.|r Untick 'Force on every bar in this group' on that group's Display tab to set this bar's own.") or ""
                end },
            style = Sel(B, "style", "Color style", 4.5, ns.BAR_STYLE_LABEL, ns.BAR_STYLES, bon, { width = "double",
                hidden = function() return B.colorMode == "fixed" end,
                disabled = function() local _, _, gf = ns.BarCueStyle(rule); return gf ~= nil end,
                desc = "Sets the colors: Blizzard's own, a Neon, Pastel or Muted / Dark take on them, or Custom colors below." }),
            cusMagic = { type = "color", name = "Magic", order = 4.60, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Magic", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Magic"] = { r, g, b2, 1 }; on() end },
            cusCurse = { type = "color", name = "Curse", order = 4.61, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Curse", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Curse"] = { r, g, b2, 1 }; on() end },
            cusDisease = { type = "color", name = "Disease", order = 4.62, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Disease", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Disease"] = { r, g, b2, 1 }; on() end },
            cusPoison = { type = "color", name = "Poison", order = 4.63, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Poison", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Poison"] = { r, g, b2, 1 }; on() end },
            cusBleed = { type = "color", name = "Bleed", order = 4.64, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Bleed", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Bleed"] = { r, g, b2, 1 }; on() end },
            cusPhysical = { type = "color", name = "Physical", order = 4.65, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Physical", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Physical"] = { r, g, b2, 1 }; on() end },
            cusHoly = { type = "color", name = "Holy", order = 4.66, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Holy", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Holy"] = { r, g, b2, 1 }; on() end },
            cusFire = { type = "color", name = "Fire", order = 4.67, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Fire", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Fire"] = { r, g, b2, 1 }; on() end },
            cusNature = { type = "color", name = "Nature", order = 4.68, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Nature", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Nature"] = { r, g, b2, 1 }; on() end },
            cusFrost = { type = "color", name = "Frost", order = 4.69, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Frost", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Frost"] = { r, g, b2, 1 }; on() end },
            cusShadow = { type = "color", name = "Shadow", order = 4.70, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Shadow", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Shadow"] = { r, g, b2, 1 }; on() end },
            cusArcane = { type = "color", name = "Arcane", order = 4.71, hasAlpha = false,
                hidden = function() return B.colorMode == "fixed" or B.style ~= "custom" or select(3, ns.BarCueStyle(rule)) ~= nil end,
                get = function() local r, g, b2 = ns.BarTypeColor("Arcane", "custom", B.custom); if not r then local f = ns.BAR_FALLBACK_COLOR; return f[1], f[2], f[3], 1 end return r, g, b2, 1 end,
                set = function(_, r, g, b2) B.custom = B.custom or {}; B.custom["Arcane"] = { r, g, b2, 1 }; on() end },
            iconH = hdr("Icon and spark", 5),
            icon = Sel(B, "icon", "Icon", 5.1, { left = "Left", right = "Right", none = "None" }, { "left", "right", "none" }, bon,
                { desc = "On a vertical bar, left is the top end and right the bottom end." }),
            spark = Tog(B.spark, "enabled", "Spark", 5.2, bon, { desc = "A bright mark on the moving edge of the fill." }),
            sparkColor = Col(B.spark, "color", "Spark color", 5.3, on, { hidden = function() return not B.spark.enabled end }),
            sparkW = Rng(B.spark, "w", "Spark width", 5.4, 1, 64, 1, on, { hidden = function() return not B.spark.enabled end }),
            bgH = hdr("Background and border", 6),
            bg = Tog(V.bg, "enabled", "Background", 6.1, bon),
            bgColor = Col(V.bg, "color", "Background color", 6.2, on, { hidden = function() return not V.bg.enabled end }),
            border = Tog(V.border, "enabled", "Border", 6.3, bon),
            borderSize = Rng(V.border, "size", "Border size", 6.4, 1, 10, 1, on, { hidden = function() return not V.border.enabled end }),
            borderColor = Col(V.border, "color", "Border color", 6.5, on, { hidden = function() return not V.border.enabled end }),
            alpha = Rng(V, "alpha", "Opacity", 6.6, 0, 1, 0.05, on),
        }
        local nameArgs = TextStyleArgs(B.name, on, 10)
        nameArgs.enabled = Tog(B.name, "enabled", "Show the spell / aura name", 1, bon)
        barTextArgs = { name = Sub("cq_barname", "Name Text", 0.5, nameArgs) }
    end
    -- Pieces the Cues tab re-uses, without the on/off tick boxes and +/- banners (a cue IS the thing, so it is always on)
    actions.xuiParts = {
        tex = tex.args,
        colorSub = Sub("cq_color", "Color & Transparency", 1, colorArgs),
        posSub = Sub("cq_pos", "Position (Offset From the Anchor)", 1, posArgs),
        animSub = Sub("cq_anim", "Animation Options", 1, animArgs),
        textBody = { dur = Sub("cq_dur", "Buff Duration Text", 1, durArgs), cnt = Sub("cq_cnt", "Stacks / Charges Count", 2, cntArgs, CountHidden), abs = Sub("cq_abs", "Shield / Absorb Amount", 3, absArgs) },
        soundBody = soundBody,
        speechBody = speechBody,
        ensureText = function() if not (T.enabled or C.enabled or AB.enabled) then T.enabled = true end end,
        barArgs = barArgs, barTextArgs = barTextArgs,
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
    local actionsTab = { type = "group", name = "Actions", order = 5, args = ns.ActionsPane and ns.ActionsPane(rule, Notify, { finishSound = finishSound }) or {} }
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
    if ns.CdmWarnArg then cuesTab.args.cdmWarn = ns.CdmWarnArg(rule, -1) end   -- Cooldown Manager limits of this rule's auras / debuffs

    ---------------------------------------------------------------- Info tab (was "Rule")
    local ruleTab = {
        type = "group", name = "Info", order = 7, args = {
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
                    ns.MarkDirty(); pcall(ns.RefreshAllVisuals)   -- audit D24: as right-click > Move To (an undo step; displays follow the new group)
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
                desc = "Sets this rule's icon in the left-hand list. Automatic uses the tracked spell or buff's icon.",
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
                confirm = function() return "Delete this rule? " .. ns.RecycleBinNote() end,
                func = function()
                    ns.RecycleRule(rule)   -- with its cues and conditions (XayaUI/RecycleBin.lua)
                    ns.MarkDirty()
                    local tab = ns.CurrentTab()
                    Notify()
                    if ns.MultiPrune then ns.MultiPrune() end   -- (0.6.82, request row 20) out of the multi-selection too
                    ns.GoHomeKeepScroll(tab)   -- (0.6.82, request row 20) the list keeps its place (TreeHelpers.lua)
                end,
            },
        },
    }

    -- The unsaved-changes bar (Save changes / Add to drafts / Discard) is a strip under the window (ns.SaveBarUpdate), not part of the tabs.
    -- Display tab (0.6.3, DisplayTab.lua): the rule as the container of its cues. Not on cues / conditions themselves.
    local displayTab = (ns.BuildDisplayTab and not rule.isCue and not rule.parentUid) and ns.BuildDisplayTab(rule, Notify, Changed) or nil
    local function locked() return ns.IsEditLocked(rule) end
    for _, g in ipairs({ ruleTab, trigger, load, conditionsTab, cuesTab, actionsTab, displayTab }) do
        ns.LockArgs(g.args, locked)
    end
    -- (review R6) a cue is edited in its rule's Cues tab with the parts below (OutcomesEditor.lua EmbedCue), which sit in no tab:
    -- lock them too (IsEditLocked follows the parent rule's lock). Only a cue's parts are shown anywhere.
    if rule.isCue then
        local xp = actions.xuiParts
        ns.LockArgs({ xp.colorSub, xp.posSub, xp.animSub }, locked)
        for _, t in ipairs({ xp.tex, xp.textBody, xp.soundBody, xp.speechBody, xp.barArgs or false, xp.barTextArgs or false }) do
            if t then ns.LockArgs(t, locked) end
        end
    end
    local rg = {
        type = "group", childGroups = "tab", order = 1000 + i,
        hidden = ns.OptionsApi.RuleRowHidden(rule),
        name = ns.OptionsApi.RuleRowName(rule),
        args = { display = displayTab, trigger = trigger, cues = cuesTab, conditions = conditionsTab, actions = actionsTab, load = load, rule = ruleTab },
    }
    -- a search box above the tabs (RuleSearch.lua; Xaya 2026-11-04). Not on cues / conditions, which show inside their rule.
    if ns.RuleSearchArgs and not rule.isCue and not rule.parentUid then
        local okS, sa = pcall(ns.RuleSearchArgs, rule, rg, Notify)
        if okS and type(sa) == "table" then for k, v in pairs(sa) do rg.args[k] = v end end
    end
    return rg
end
-- open one tab of the rule that is selected in the sidebar (RuleSearch.lua results)
function ns.SelectRuleTab(tabKey)
    local S = ns.RulesTreeStatus()
    local sel = S and S.selected
    if type(sel) ~= "string" or not tabKey then return end
    local sub = ns.CurrentSub()
    if sub ~= "smartTab" and sub ~= "disabledTab" then sub = "enabledTab" end
    local segs = { "cooldowns", sub }
    for seg in sel:gmatch("[^\001]+") do segs[#segs + 1] = seg end
    local st = AceConfigDialog:GetStatusTable(APP, segs)
    st.groups = st.groups or {}
    st.groups.selected = tabKey
    Notify()
end

-- Edit lock: a rule (or a folder, which covers everything inside it) can be made read-only from the sidebar. A cue or condition follows
-- its rule's lock too (audit D41: the rule row's lock covers the rule and everything shown inside it).
function ns.IsEditLocked(x)
    if x and x.editLocked then return true end
    if x and x.parentUid and ns.FindParentRule then
        local p = ns.FindParentRule(x)
        if p and p ~= x and p.editLocked then return true end
    end
    local id, guard = x and x.folder, 0
    while id and guard < 32 do
        local f = ns.FolderById(id)
        if not f then return false end
        if f.editLocked then return true end
        id, guard = f.parent, guard + 1
    end
    return false
end
-- A header's own controls (Skin.lua: arg.xuiActions = Move up / Move down / Duplicate / Remove, arg.xuiEdit = the name box) are not
-- AceConfig options, so `disabled` never reached them (audit D26 / D44). While locked() is true the action icons are drawn grayed out
-- (false) and do nothing, and the name box refuses the edit. Wrapping twice is harmless.
function ns.LockHeaderArg(a, locked)
    if type(a) ~= "table" then return end
    local acts = a.xuiActions
    if acts ~= nil and not a.xuiLockWrapped then
        a.xuiLockWrapped = true
        a.xuiActions = function(...)
            local spec = acts
            if type(spec) == "function" then spec = spec(...) end
            if type(spec) ~= "table" or not locked() then return spec end
            local out = {}
            for k, v in pairs(spec) do if v ~= nil then out[k] = false end end
            return out
        end
    end
    local ed = a.xuiEdit
    if type(ed) == "table" and not ed.xuiLockWrapped then
        ed.xuiLockWrapped = true
        local set = ed.set
        ed.locked = locked
        ed.set = function(...) if locked() then return end; if set then return set(...) end end
    end
end
-- disables every leaf option while locked() is true (collapse / expand controls stay usable; groups are left alone
-- because a disabled group would also disable those controls)
function ns.LockArgs(args, locked)
    for _, o in pairs(args or {}) do
        if type(o) == "table" and o.arg then ns.LockHeaderArg(o.arg, locked) end
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

-- for the other files of this folder (ns.OptionsApi.RuleEditorParts)
P.AddSquareRadio, P.BAR_ANCHOR, P.BAR_ANCHOR_ORDER, P.BAR_ICON, P.BAR_ICON_ORDER, P.BAR_LAYOUT = AddSquareRadio, BAR_ANCHOR, BAR_ANCHOR_ORDER, BAR_ICON, BAR_ICON_ORDER, BAR_LAYOUT
P.BAR_LAYOUT_ORDER, P.BAR_NAME, P.BAR_NAME_ORDER, P.BAR_SHOW, P.BAR_SHOW_ORDER, P.BuildRule = BAR_LAYOUT_ORDER, BAR_NAME, BAR_NAME_ORDER, BAR_SHOW, BAR_SHOW_ORDER, BuildRule
P.CHANNEL_ORDER, P.CHANNEL_VALUES, P.FontSel, P.JUSTIFY, P.JUSTIFY_ORDER, P.RoleChoices = CHANNEL_ORDER, CHANNEL_VALUES, FontSel, JUSTIFY, JUSTIFY_ORDER, RoleChoices
P.SHOW_COMBAT, P.SHOW_COMBAT_ORDER, P.SearchBox, P.SpecChoices, P.SpellName, P.SpellTex = SHOW_COMBAT, SHOW_COMBAT_ORDER, SearchBox, SpecChoices, SpellName, SpellTex
P.StatusText, P.TEXT_OUTLINE, P.TEXT_OUTLINE_ORDER, P.TRI_ORDER, P.tf = StatusText, TEXT_OUTLINE, TEXT_OUTLINE_ORDER, TRI_ORDER, tf
-- for Options.lua (ns.OptionsApi.RuleEditor): the live status line of the debug console strip
ns.OptionsApi.RuleEditor.StatusText = StatusText
