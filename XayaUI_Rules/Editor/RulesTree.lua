-------------------------------------------------------------------------------
-- XayaUI_Rules/Editor/RulesTree.lua : The Rules tab: Auto-Generate Rules, + New rule and the type picker, group pages, the sidebar search filter, the tab builder,
-- the row-only rules drawn on demand, and opening a rule or group from outside the window.
-- Part of the rule editor, moved out of Options.lua unchanged in the platform split P3 (Options 0.6.83;
-- docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7, Q1: the rule module owns its editor). This folder talks to the rest of the
-- settings window only through ns.OptionsApi: ns.OptionsApi.Shared (what Options.lua lends it) in, ns.OptionsApi.RuleEditor (what
-- Options.lua asks of it) out; its files share their own parts through ns.OptionsApi.RuleEditorParts.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (XayaUI Rules depends on it: ## Dependencies: XayaUI)
-- (Rules 0.7.0, REQUEST-LOG A23 SD-6) This file is part of XayaUI Rules (it was the load-on-demand addon XayaUI_Rules_Options). The game
-- reads it at login with Rules; everything below only runs when the settings window first opens with Rules on: it is one set-up
-- function, run once by XayaUI_Options (Options.lua ns.OptionsApi.LoadRuleEditor) in the .toc order. Nothing is built before then.
local function EditorFileInit()
local function QoLBoxes() local s = ns.Service and ns.Service("statsText"); return s and s.Boxes() end   -- (P5) XayaUI QoL's stats-text boxes (XayaUI_QoL/StatsText.lua), nil while it is off
if not (ns.OptionsApi and ns.OptionsApi.Shared) then return end   -- Options.lua stopped early (its Ace3 libraries are missing)
local O = ns.OptionsApi.Shared
local CoreS, PlatS, APP, AceConfigDialog, Tree, Notify = O.CoreS, O.PlatS, O.APP, O.AceConfigDialog, O.Tree, O.Notify
local Rng, Sel = O.Rng, O.Sel
local P = ns.OptionsApi.RuleEditorParts
local AddSquareRadio, BAR_LAYOUT, BAR_LAYOUT_ORDER, BuildBar, BuildBox, BuildRule = P.AddSquareRadio, P.BAR_LAYOUT, P.BAR_LAYOUT_ORDER, P.BuildBar, P.BuildBox, P.BuildRule
local CHANNEL_ORDER, CHANNEL_VALUES, FolderById, FolderChain, FolderRules, FolderTopRules = P.CHANNEL_ORDER, P.CHANNEL_VALUES, P.FolderById, P.FolderChain, P.FolderRules, P.FolderTopRules
local IsInFolder, RoleChoices, RulePath, SearchBox, SpecChoices, TokenHelp = P.IsInFolder, P.RoleChoices, P.RulePath, P.SearchBox, P.SpecChoices, P.TokenHelp

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
    CoreS.creatorIDs = CoreS.creatorIDs or {}   -- IDs she typed (kept with the profile); 0 = cleared (P5: XayaUI Rules' store)
    return CoreS.creatorIDs or {}
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
    ns.MarkDirty(); ns.Fire("CONFIG_CHANGED")
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
        if made > 0 then ns.MarkDirty(); ns.Fire("CONFIG_CHANGED") end
    end
    ns.Print("rule creator: " .. (creatorMsg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
    Notify()
end
function BuildClassCreator()
    local function shown() return not creatorOpen end
    local args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Press one of a spec's Generate buttons (or one of the buttons for your whole class) to load the cooldowns, auras or target debuffs it names in a table below. Tick the ones you want, set each one's trigger, cue and combat load, then press Populate: each becomes a rule with its cue, in Class > Spec > cue type." },
        apHdr = { type = "header", order = 0.1, name = "Auto-populate my class / spec" },
        apInfo = { type = "description", order = 0.2, width = "full", fontSize = "medium",
            name = function()
                local specID = ns.CurrentSpecID and ns.CurrentSpecID()
                local okS, _, specName = pcall(GetSpecializationInfoByID, specID or 0)
                return "Detected: |cffffd100" .. (UnitClass("player") or "?") .. " - " .. ((okS and specName) or "unknown spec") .. "|r. Cooldowns are read from this game client (the addon remembers each spec once you have played it); auras and target debuffs from your Cooldown Manager, for the spec you are in now. Nothing is made until you press Populate under the table." end },
        apTalents = { type = "toggle", order = 0.3, width = "full", name = "Include talents I have not picked (rule only loads when the talent is known)",
            get = function() return ns.AutoCfg().talents ~= false end,
            set = function(_, v)
                ns.AutoCfg().talents = v and true or false; ns.MarkDirty()
                local AP = ns.AutoPicker
                if AP and AP.view then AP.Load(AP.view.spec, AP.view.filter) end   -- the table shown follows the option at once
                Notify()
            end },
        -- "All talents (every class and spec)" (the talent scan) moved to Settings > UI Options > Rule Creation (Options 0.6.40; Xaya,
        -- 2026-11-05: "scan belongs in Settings"): BuildAddonSettings, rules.args.talHdr.
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
    -- Xaya, 2026-11-06: four buttons per spec (All / CD Tracking / Aura Tracking / Target Debuff Tracking) and the same four for the whole
    -- class; each loads its own list into the table below and nothing is listed before one is pressed. Spec buttons keep the spec's own
    -- icon (specs come from the game, so any class works). Width 3.0 (about 460 px; ESTIMATE from the old 1.6-wide button, about 246 px in her screenshot) holds the longest label, a Target Debuff label with an 11-letter spec; buttons wrap to the next line when the pane is narrow.
    local FILTER_DESC = { all = "cooldowns, auras and target debuffs", cd = "cooldowns", aura = "auras on you", debuff = "target debuffs" }
    -- (Options 0.6.65; REQUEST-LOG UI-71, Xaya 2026-11-07: "this needs work, it's too noisy. one icon, four buttons"; her answer UI-72
    -- "icon | four lines") per spec: its icon once, at the left, and its four buttons as four lines beside it (each button has her
    -- label, verbatim, GEN-3; before: the icon on every button and two buttons per line). The class's four the same, with no icon.
    local ICON_W, BTN_W = 0.08, 0.88   -- (icon column; the button wide enough for the longest label at the default window width, ESTIMATE)
    local function GenButtons(prefix, base, target, icon, specID)
        for j, f in ipairs(ns.AutoPicker.FILTERS) do
            local o = base + j * 0.001
            args[prefix .. "Ic" .. j] = { type = "description", order = o - 0.0005, width = "relative", relWidth = ICON_W, name = " ",
                image = (j == 1) and icon or nil, imageWidth = 24, imageHeight = 24, arg = { xuiKeep = true } }
            args[prefix .. f.filter] = { type = "execute", order = o, width = "relative", relWidth = BTN_W,
                name = ns.AutoPicker.ButtonLabel(f.filter, target),
                desc = "Lists the " .. FILTER_DESC[f.filter] .. " of " .. (specID == "all" and "every spec of your class" or (tostring(target) .. " (" .. (UnitClass("player") or "your class") .. ")"))
                    .. " in the table below (nothing is made yet).",
                func = function() ns.AutoPicker.Load(specID, f.filter); Notify() end }
            args[prefix .. "Br" .. j] = { type = "description", order = o + 0.0004, width = "full", name = "", fontSize = "small", arg = { xuiKeep = true } }
        end
    end
    for i = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
        local sid, sname, _, sicon = GetSpecializationInfo(i)
        if sid then
            GenButtons("apSpec" .. i, 0.47 + i * 0.01, sname, sicon, sid)
            args["apBrk" .. i] = { type = "description", order = 0.47 + i * 0.01 + 0.005, width = "full", fontSize = "small", name = " " }
        end
    end
    GenButtons("apClass", 0.58, "my class", nil, "all")
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
    -- Xaya 2026-11-05: the auto-populate table (AutoPicker.lua): the list of the button pressed, ticked and set up before anything is made
    if ns.AutoPicker and ns.AutoPicker.Args then for k, v in pairs(ns.AutoPicker.Args(Notify, Tree.Keep)) do args[k] = v end end
    return { type = "group", name = "Auto-Generate Rules", order = 2, hidden = ns.PageHidden("creator"), args = args }
end
end   -- do (class/spec creator)
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
    local isBar = v.kind == "bar"   -- a Bar cue (BarCue.lua, RM-BARS)
    local fill = v.fill and v.fill.enabled and true or false
    if key == "smart_bar" then return isBar end
    if key == "smart_icon" then return isIcon end
    if key == "smart_progtex" then return fill end
    if key == "smart_text" then return (v.text and v.text.enabled) and true or false end
    if key == "smart_tex" then return (not isIcon) and (not isBar) and (not fill) and (v.texAlpha == nil or v.texAlpha > 0) end
    return false
end
function ns.SmartAny(rule)
    for _, c in ipairs(ns.SMART_CATS) do
        if ns.SmartMatch(rule, c.key) then return true end
    end
    return false
end

local picker = nil   -- { folder = id|nil, sub = Rules sub-tab key } while the page is open
-- (Rules_Options 0.6.79; #487, debug W1) The type picker belongs to the Rules sub-tab "+ New Rule" was pressed in (picker.sub). Its rows
-- (and the page entries they replace) look at the option path AceConfigDialog passes (info[2] = the sub-tab): on any other sub-tab the
-- picker is not drawn, and ns.PickerSync (run with ns.SaveRulesSub: every redraw, every 0.25 s while the window is open, and when it
-- closes) forgets it once another sub-tab is open or the window is closed. Before, `picker` was cleared only by a pick or Cancel, so a
-- picker left open was drawn again at the top of Drafts (Xaya, 2026-11-07: "????????????????????????").
local function PickerShown(info)
    if not picker then return false end
    local sub = type(info) == "table" and info[2] or nil
    if sub == nil then return true end   -- called without an option path (a direct call): the picker is open
    return sub == (picker.sub or "smartTab")
end
ns.PickerShown = PickerShown
function ns.PickerSync()
    if not picker then return end
    local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
    local open = of and of.frame and of.frame:IsShown()
    local top = AceConfigDialog.GetStatusTable and AceConfigDialog:GetStatusTable(APP)
    top = top and top.groups and top.groups.selected
    if not open or (top == "cooldowns" and ns.CurrentSub() ~= (picker.sub or "smartTab")) then picker = nil end
end
-- The first set-up of a rule type's cue, shared by the "+ New rule" type list (CreateRuleOfType below) and the auto-populate table
-- (AutoPicker.lua, Options 0.6.45): Icon -> icon cue (spell icon, 64 x 64, gray while on cooldown); Texture -> texture cue; Progress
-- Texture -> texture cue with fill and overlay, base at 0.35; Text -> text cue (the duration text, no art); Sound / Speech -> that cue.
-- One explicit cue kind per type. Returns the cue (nil when the rule holds the most cues it may) and its kind.
-- (Progress Bar -> a Bar cue since Options 0.6.59 / core 0.6.58, RM-BARS; before, it made a Buff Bar, whose code is shelved and drew nothing)
ns.CUE_FOR_TYPE = { icon = "icon", text = "text", sound = "sound", speech = "speech", texture = "texture", progresstex = "texture", bar = "bar" }
function ns.NewTypedCue(r, typ)
    local kind = ns.CUE_FOR_TYPE[typ] or "texture"
    r.uid = r.uid or ns.NewUID()
    local cue = ns.NewCueRule(r, kind)
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
    return cue, kind
end
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
        -- one explicit cue kind per picker row (ns.NewTypedCue above, shared with the auto-populate table)
        local cue, kind = ns.NewTypedCue(r, typ)
        if ns.Log then ns.Log("new rule: picker row '%s' -> cue kind '%s' (cue made: %s)", tostring(typ), kind, tostring(cue ~= nil)) end
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
    picker = { folder = fid, sub = ns.pickSub or "smartTab" }
    ns.GoPicker()   -- (0.6.79) the sub-tab first, so the redraw below (and its ns.PickerSync) already sees the picker's own sub-tab
    Notify()
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
    local a = CoreS.auto   -- (P5: XayaUI Rules' store; CueRulesDB.ui.auto before)
    if not a then a = {}; CoreS.auto = a end
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
    ns.Fire("CONFIG_CHANGED")
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

-- The class / spec auto-populate (one skeleton rule per cooldown, made at once, in "<Class> <Spec> - autorule population" >
-- Defensive / Offensive / Utility / Unsorted) was replaced in Options 0.6.44 by the table in AutoPicker.lua: the spec buttons on the
-- Class/Spec Rule Creator page load a list you tick and set up first (Xaya, 2026-11-05). Rules made by the old buttons are kept as they are.

ns.UI.NewRule = function() StartNewRule(nil) end
local function PickType(typ)
    local p = picker
    picker = nil
    if typ == "dgroup" or typ == "sgroup" then
        -- a rule group is a folder (the container): nested inside the folder the picker was opened from, top level otherwise
        local nf = ns.NewFolder((typ == "dgroup" and "Dynamic Group" or "Static Group"), p and p.folder)
        if typ == "dgroup" then nf.cType = "dynamic" end
        local path = { ns.PlaceNewGroup(nf, nf.parent and ns.CurrentScope() or "loaded") }
        ns.MarkDirty(); Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, unpack(path))
    elseif typ == "import" then
        Notify()   -- closes the type picker where it is; Import is a window of its own and does not change tabs
        if ns.OpenImportWindow then ns.OpenImportWindow() end
    elseif typ == "profiles" then   -- Profiles > Export
        ns.infoOpen = false
        Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "profiles", "export")
    else
        CreateRuleOfType(typ, p and p.folder)
    end
end
ns.UI.Import = function() PickType("import") end
-- (Options 0.6.72) the toolbar is gone; these stay for the right-click menus, /xui commands and the type picker: Import opens its own
-- window; Export opens Profiles > Export
ns.UI.Export = function() PickType("profiles") end
local function FolderRuleCount(f)
    return #FolderRules(f.id)
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
    -- (review R8) A slider (and a colour swatch) calls set on every step of a drag. Each step now redraws this group only (its frame, the
    -- displays in it and their group border / background, SD-17); the window redraws once at the end, by itself (AceConfigDialog re-opens
    -- the page on the slider's mouse up and on the colour picker's confirm). apply() redrew every display and rebuilt the whole window on
    -- each step: the drag stuttered.
    local function applyStep()
        ns.MarkDirty()
        local rt = ns.runtime   -- (each display redrawn places the group's frame again from its settings: Visual.lua ParentFor)
        for _, r in ipairs(FolderRules(f.id)) do
            if (r.visual and r.visual.enabled) or (ns.IsPreview and ns.IsPreview(r, "visual")) then
                if pcall(ns.RefreshVisual, r) then pcall(ns.SetVisualShown, r, rt and rt[r] and rt[r].visualWanted) end
            end
        end
        if ns.RefreshGroupDeco then pcall(ns.RefreshGroupDeco, f) end   -- (SD-17) its border / background, on each display
        if ns.unlocked and ns.RefreshGroupTags then pcall(ns.RefreshGroupTags) end
    end
    local POINTS = { "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
    local PV = {}
    for _, p in ipairs(POINTS) do PV[p] = p:sub(1, 1) .. p:sub(2):lower() end
    PV.TOPLEFT, PV.TOPRIGHT, PV.BOTTOMLEFT, PV.BOTTOMRIGHT = "Top left", "Top right", "Bottom left", "Bottom right"
    local STRATA = { "inherit", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
    local SV = { inherit = "(default - High)", BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium", HIGH = "High", DIALOG = "Dialog",
        FULLSCREEN = "Fullscreen", FULLSCREEN_DIALOG = "Fullscreen dialog", TOOLTIP = "Tooltip" }
    -- "group" (Rules 0.6.82, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #18, her words: "I should be able to anchor to another rule
    -- group's position"; her decision: an "Another group" entry here with a group list): f.cRel = "group", f.cGroup = that group's id
    local RELS = { "screen", "player", "target", "focus", "minimap", "chat", "custom", "group" }
    local RV = { screen = "Screen center (or the parent group)", player = "Player frame", target = "Target frame", focus = "Focus frame",
        minimap = "Minimap", chat = "Main chat frame", custom = "Another frame (type its name)", group = "Another group" }
    local function isDyn() return f.cType == "dynamic" end
    local g = { type = "group", inline = true, order = 5.4, name = "Group Type & Container",
        hidden = function() return not ns.KindHas({ folder = f.id }, "visual") end,
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Every group is a container for the displays inside it (and inside its nested groups). Static: each display keeps its own position. Dynamic: the addon lays the visible displays out itself and ignores their own X / Y. The container settings below apply to everything inside. Width / height give the container a fixed box, and the anchor point is that box's point. In Auto size the anchor point is that point of what the group holds: the whole grid of a dynamic group, or the outline of every switched-on display of a static group (also ones not showing now); Center, Centered row and Centered column keep the group's center. A dynamic group wraps onto a new row / column when its items would exceed that size, or after the number of items you set in Items per row / column." },
        } }
    AddSquareRadio(g.args, "ctype", 1, { static = "Static group  (items keep their own positions)", dynamic = "Dynamic group  (positions its items automatically)" },
        { "static", "dynamic" }, function() return isDyn() and "dynamic" or "static" end,
        function(v) f.cType = (v == "dynamic") and "dynamic" or nil; apply() end)
    -- Dynamic layout (0.6.4): every dropdown shares its row (Grow + Sort, Spacing + Wrap, Per row + New rows go), and wrapping is an
    -- explicit tick box with its count beside it (Xaya: "dynamic groups should have row / column wrap options"; the old "Items per row /
    -- column (0 = no limit)" slider was easy to miss). Saved fields are unchanged: cGrowth, cSort, cSpacing, cWrapN (nil = no wrap), cWrapRev.
    local function growsAcross() local d = f.cGrowth or "RIGHT"; return d == "RIGHT" or d == "LEFT" or d == "HCENTER" or d == "ANCHOR_ROW" end
    local function fromAnchor() local d = f.cGrowth; return d == "ANCHOR_ROW" or d == "ANCHOR_COL" end
    local function wrapOn() return (tonumber(f.cWrapN) or 0) > 0 end
    g.args.growth = { type = "select", name = "Grow direction", order = 2, hidden = function() return not isDyn() end,
        values = { RIGHT = "Right (left to right)", LEFT = "Left (right to left)", DOWN = "Down (top to bottom)", UP = "Up (bottom to top)",
            HCENTER = "Centered row", VCENTER = "Centered column",
            ANCHOR_ROW = "From anchor point, rows", ANCHOR_COL = "From anchor point, columns" },
        sorting = { "RIGHT", "LEFT", "DOWN", "UP", "HCENTER", "VCENTER", "ANCHOR_ROW", "ANCHOR_COL" },
        desc = "Sets which way the group adds items. Centered keeps them centered on the group's position; From anchor point grows them away from the group's anchor point.",
        get = function() return f.cGrowth or "RIGHT" end, set = function(_, v) f.cGrowth = v; apply() end }
    -- Sort (0.6.6, Xaya: "default, expiration, name, important, manual"): one setting for XayaUI's own layout and the engine
    -- (ns.GroupSortOf in Visual.lua; saved as cSort = nil for Manual, plus cSortRev; old "asc" / "desc" read as Name / Name reversed)
    local function sortOf() if ns.GroupSortOf then return ns.GroupSortOf(f) end return "manual", false end
    g.args.sort = { type = "select", name = "Sort", order = 2.05, hidden = function() return not isDyn() end,
        -- (Options 0.6.50: her list as she wrote it, in her order and with her words; S1's cross-chat review B5)
        values = { manual = "Manual", default = "Default", expiration = "Expiration", name = "Name", important = "Important" },
        sorting = { "default", "expiration", "name", "important", "manual" },
        desc = "Manual uses this group's sidebar order (arrows or drag). Default, Expiration, Name and Important are the game's own sorts.",
        get = function() return (sortOf()) end,
        set = function(_, v) local _, rev = sortOf(); f.cSort = (v ~= "manual") and v or nil; f.cSortRev = rev or nil; apply() end }
    g.args.sortRev = { type = "toggle", name = "Reverse", order = 2.06, width = "relative", relWidth = 0.22, hidden = function() return not isDyn() end,
        desc = "Turn the sort around (Manual: last rule first).",
        get = function() local _, rev = sortOf(); return rev end,
        set = function(_, v) local mode = sortOf(); f.cSort = (mode ~= "manual") and mode or nil; f.cSortRev = v and true or nil; apply() end }
    g.args.sortSave = { type = "execute", name = "Save order and reload", order = 2.07, width = "relative", relWidth = 0.3,
        hidden = function() return not isDyn() or sortOf() ~= "manual" end,
        desc = "Saves your settings and reloads the interface, so the new order is written to disk.",
        func = function() if ReloadUI then ReloadUI() end end }
    -- G10 (Xaya 2026-11-06, question flow: "Limit (Recommended),Align (Recommended)"; WeakAuras' dynamic group has both, CHAT-3d)
    g.args.limit = { type = "range", name = "Limit (show at most)", order = 2.101, min = 0, max = 40, step = 1,
        desc = "Shows at most this many items after sorting; the rest appear as shown ones go. 0 = no limit.",
        hidden = function() return not isDyn() end,
        get = function() return tonumber(f.cLimit) or 0 end, set = function(_, v) f.cLimit = (v > 0) and v or nil; applyStep() end }
    g.args.align = { type = "select", name = "Align", order = 2.102, arg = { xuiSide = true },
        desc = "Sets which side items of different sizes line up on.",
        hidden = function() return not isDyn() end,
        values = function()
            if growsAcross() then return { start = "Top", center = "Center", ["end"] = "Bottom" } end
            return { start = "Left", center = "Center", ["end"] = "Right" }
        end,
        sorting = { "start", "center", "end" },
        get = function()
            if f.cAlign then return f.cAlign end
            if ns.DynamicBlock and ns.DynamicBlock(f) then return nil end   -- (a Centered / From anchor group lines up from its corner: none picked)
            return "center"
        end,
        set = function(_, v) f.cAlign = v; apply() end }
    g.args.spacing = { type = "range", name = "Spacing", order = 2.1, min = 0, max = 200, step = 1,
        desc = "Space between items, in pixels.",
        hidden = function() return not isDyn() end,
        get = function() return f.cSpacing or 4 end, set = function(_, v) f.cSpacing = v; applyStep() end }
    g.args.wrapOn = { type = "toggle", order = 2.11,
        name = function() return growsAcross() and "Wrap into rows" or "Wrap into columns" end,
        desc = "Starts a new row or column after a set number of items. A box width or height below also wraps when items would not fit.",
        hidden = function() return not isDyn() end,
        get = function() return wrapOn() end,
        set = function(_, v) if v then f.cWrapN = wrapOn() and f.cWrapN or 6 else f.cWrapN = nil end; apply() end }
    g.args.wrapN = { type = "range", order = 2.115, min = 1, max = 50, step = 1,
        name = function() return growsAcross() and "Items per row" or "Items per column" end,
        hidden = function() return not (isDyn() and wrapOn()) end,
        get = function() return tonumber(f.cWrapN) or 6 end, set = function(_, v) f.cWrapN = (v > 0) and v or nil; applyStep() end }
    g.args.wrapDir = { type = "select", order = 2.12,
        hidden = function() return fromAnchor() or not (isDyn() and (wrapOn() or (tonumber(f.cW) or 0) > 0 or (tonumber(f.cH) or 0) > 0)) end,
        name = function() return growsAcross() and "New rows go" or "New columns go" end,
        desc = "Which side of the first row / column the extra ones are added on.",
        values = function()
            if growsAcross() then return { fwd = "Below", rev = "Above" } end
            return { fwd = "To the right", rev = "To the left" }
        end,
        sorting = { "fwd", "rev" },
        get = function() return f.cWrapRev and "rev" or "fwd" end, set = function(_, v) f.cWrapRev = (v == "rev") or nil; apply() end }
    g.args.alpha = { type = "range", name = "Group opacity", order = 3, min = 0, max = 1, step = 0.05,
        get = function() return f.cAlpha or 1 end, set = function(_, v) f.cAlpha = (v < 1) and v or nil; applyStep() end }
    g.args.scale = { type = "range", name = "Group scale", order = 3.01, min = 0.25, max = 3, step = 0.05,
        get = function() return f.cScale or 1 end, set = function(_, v) f.cScale = (v ~= 1) and v or nil; applyStep() end }
    -- Size (G5; Xaya 2026-11-06: "size = auto or set + clip / wrap tick boxes; auto fits the showing items, border follows"). Auto (the
    -- default) fits what is showing; Set gives the box a width and height, and only then can it clip. Wrap is the dynamic group's
    -- "Wrap into rows / columns" tick box above.
    local function setSize() return ns.GroupSizeMode and ns.GroupSizeMode(f) == "set" end
    g.args.sizeMode = { type = "select", name = "Size", order = 3.04, width = "full", arg = { xuiSide = true },
        values = { auto = "Auto (fits what is showing)", set = "Set (width and height below)" }, sorting = { "auto", "set" },
        desc = "Auto fits the group's box to the items showing. Set uses the width and height you give it, and can clip what falls outside.",
        get = function() return ns.GroupSizeMode and ns.GroupSizeMode(f) or "auto" end,
        set = function(_, v) if ns.SetGroupSizeMode then ns.SetGroupSizeMode(f, v) end; apply() end }
    -- G9 (Xaya 2026-11-06: "Toggle + ask on resize"): with the tick box off, making a static group's box smaller than its items asks
    -- once "Scale the items to fit?" (Yes ticks it); asked again only after the items fit again
    local function askFit()
        if f.cFit or f.cType == "dynamic" or not ns.GroupFitNeeded then return end
        ns.fitAsked = ns.fitAsked or setmetatable({}, { __mode = "k" })
        if ns.GroupFitNeeded(f) >= 1 then ns.fitAsked[f] = nil; return end
        if ns.fitAsked[f] then return end
        ns.fitAsked[f] = true
        StaticPopupDialogs["XAYAUI_GROUP_FIT"] = StaticPopupDialogs["XAYAUI_GROUP_FIT"] or {
            text = "%s", button1 = YES or "Yes", button2 = NO or "No", timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            OnAccept = function(self, data) if data and data.cb then data.cb() end end }
        local dlg = StaticPopup_Show("XAYAUI_GROUP_FIT", "Scale the items to fit?", nil, { cb = function() f.cFit = true; apply() end })
        if dlg and dlg.SetFrameStrata then dlg:SetFrameStrata("TOOLTIP") end
    end
    g.args.width = { type = "range", name = "Width", order = 3.05, min = 1, max = 1500, step = 1, hidden = function() return not setSize() end,
        get = function() return f.cW or 1 end, set = function(_, v) f.cW = math.max(1, v); applyStep(); askFit() end }
    g.args.height = { type = "range", name = "Height", order = 3.06, min = 1, max = 1500, step = 1, hidden = function() return not setSize() end,
        get = function() return f.cH or 1 end, set = function(_, v) f.cH = math.max(1, v); applyStep(); askFit() end }
    g.args.fit = { type = "toggle", name = "Scale items to fit the box", order = 3.065, width = "full",
        hidden = function() return not setSize() or isDyn() end,
        desc = "Shrinks (never enlarges) this group's displays to fit the width and height above. Their saved positions and sizes do not change.",
        get = function() return f.cFit and true or false end, set = function(_, v) f.cFit = v and true or nil; apply() end }
    g.args.clip = { type = "toggle", name = "Clip (hide anything outside the box)", order = 3.07, width = "full", hidden = function() return not setSize() end,
        get = function() return f.cClip and true or false end, set = function(_, v) f.cClip = v and true or nil; apply() end }
    -- Border and background (G5, G11 #372 "a property for group display: background (puts an assigned color / texture under the
    -- aura)"; WeakAuras' group tab has a border, CHAT-3d). (SD-17, Xaya 2026-11-10: "Make it apply to individual auras, not the whole
    -- container"; "Every group has this same behavior") Drawn on each display of the group (Visual.lua ns.PaintGroupDeco), the
    -- labels say so. Same saved keys as before.
    local function col(key, dflt) return function() local c = f[key] or dflt; return c[1], c[2], c[3], c[4] end end
    local function setCol(key) return function(_, r, gg, b, a) f[key] = { r, gg, b, a }; applyStep() end end
    g.args.boxH = { type = "header", name = "Border and background on each display", order = 3.08 }
    g.args.boxNote = { type = "description", order = 3.0805, width = "full", fontSize = "small",
        name = "|cff999999These are drawn around every display in this group, one by one, not as one box around the whole group. Groups inside this one use them too, unless they turn on their own.|r" }
    g.args.border = { type = "toggle", name = "Border", order = 3.081, get = function() return f.cBorder and true or false end,
        desc = "Draws a border around each display in this group.",
        set = function(_, v) f.cBorder = v and true or nil; apply() end }
    g.args.borderColor = { type = "color", name = "Border color", order = 3.082, hasAlpha = true, hidden = function() return not f.cBorder end,
        desc = "The color of the border around each display.",
        get = col("cBdColor", { 0.6, 0.6, 0.65, 1 }), set = setCol("cBdColor") }
    g.args.bg = { type = "toggle", name = "Background", order = 3.083, get = function() return f.cBg and true or false end,
        desc = "Puts a color or texture behind each display in this group.",
        set = function(_, v) f.cBg = v and true or nil; apply() end }
    g.args.bgColor = { type = "color", name = "Background color", order = 3.084, hasAlpha = true, hidden = function() return not f.cBg end,
        desc = "The color behind each display.",
        get = col("cBgColor", { 0, 0, 0, 0.45 }), set = setCol("cBgColor") }
    g.args.bgTex = { type = "input", name = "Background texture (file path or ID; empty = the color only)", order = 3.085, width = "full",
        desc = "A picture to put behind each display instead of the plain color.",
        hidden = function() return not f.cBg end,
        get = function() return f.cBgTex and tostring(f.cBgTex) or "" end,
        set = function(_, v) v = tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", ""); f.cBgTex = (v ~= "") and (tonumber(v) or v) or nil; apply() end }
    g.args.pad = { type = "range", name = "Padding around each display", order = 3.086, min = 0, max = 40, step = 1,
        desc = "How far the border and background reach past the edge of each display, in pixels.",
        hidden = function() return not (f.cBorder or f.cBg) end,
        get = function() return tonumber(f.cPad) or 4 end, set = function(_, v) f.cPad = v; applyStep() end }
    g.args.strata = { type = "select", name = "Layer (strata)", order = 3.2, values = SV, sorting = STRATA,
        get = function() return f.cStrata or "inherit" end, set = function(_, v) f.cStrata = (v ~= "inherit") and v or nil; apply() end }
    g.args.level = { type = "range", name = "Z-index within the layer (0 = automatic)", order = 3.3, min = 0, max = 200, step = 1,
        get = function() return f.cLevel or 0 end, set = function(_, v) f.cLevel = (v > 0) and v or nil; applyStep() end }
    -- #372: "the relative / point on the frame should both be left-hand put into two columns with labels on the left and right-hand side
    -- with dropdown menus": each of Relative to, this group's point and the frame's point is one row, its label on the left and its
    -- dropdown on the right (the skin's label-left mode, arg.xuiSide)
    g.args.relH = { type = "header", name = "Group position", order = 4 }
    g.args.moveOn = { type = "execute", order = 4.05, width = "double",
        name = function() return ns.IsGroupUnlocked and ns.IsGroupUnlocked(f) and "Lock group (stop dragging)" or "Move group on screen (drag its outline)" end,
        desc = "Shows one outline around this group's displays; drag it to set the X / Y offset below. The lock icon on the group's row in the sidebar does the same.",
        func = function() if ns.SetGroupUnlocked then ns.SetGroupUnlocked(f, not ns.IsGroupUnlocked(f)) end; Notify() end }
    g.args.anchorTo = { type = "select", name = "Anchored to", order = 4.09, width = "full", arg = { xuiSide = true },
        hidden = function() return not f.parent end,
        values = { parent = "The parent group", screen = "The screen" }, sorting = { "parent", "screen" },
        desc = "Places this nested group from its parent (moves with it) or from the screen (stays put). The parent's opacity, scale and layer still apply.",
        get = function() return f.cAnchorTo == "screen" and "screen" or "parent" end,
        set = function(_, v) f.cAnchorTo = (v == "screen") and "screen" or nil; apply() end }
    g.args.rel = { type = "select", name = "Relative to", order = 4.1, width = "full", arg = { xuiSide = true }, values = RV, sorting = RELS,
        get = function() return f.cRel or "screen" end,
        set = function(_, v) f.cRel = (v ~= "screen") and v or nil; if v ~= "group" then f.cGroup = nil end; apply() end }
    -- the groups this one may follow: not itself, none that would make a loop (Visual.lua ns.GroupAnchorAllowed), by their path
    local function groupList()
        local vals, order = {}, {}
        for _, o in ipairs(ns.folders or {}) do
            if ns.GroupAnchorAllowed and ns.GroupAnchorAllowed(f, o) then
                local k = tostring(o.id)
                vals[k] = ns.FolderPathText and ns.FolderPathText(o.id) or tostring(o.name)
                order[#order + 1] = k
            end
        end
        return vals, order
    end
    g.args.relGroup = { type = "select", name = "Group", order = 4.25, width = "full", arg = { xuiSide = true },
        hidden = function() return f.cRel ~= "group" end,
        values = function() return (groupList()) end,
        sorting = function() local _, order = groupList(); return order end,
        get = function()
            if f.cGroup == nil then return nil end
            local k = tostring(f.cGroup)
            return (groupList())[k] and k or nil
        end,
        set = function(_, v)
            local o = ns.FolderById(v) or ns.FolderById(tonumber(v))
            f.cGroup = o and o.id or nil
            apply()
        end }
    g.args.relName = { type = "input", name = "Frame name", order = 4.2, width = "double", hidden = function() return f.cRel ~= "custom" end,
        desc = "The global name of any frame, e.g. PlayerFrame or MultiBarBottomLeft. If it does not exist the group falls back to the screen.",
        get = function() return f.cFrame or "" end, set = function(_, v) f.cFrame = (v ~= "") and v or nil; apply() end }
    g.args.point = { type = "select", name = "This group's anchor point", order = 4.3, width = "full", arg = { xuiSide = true }, values = PV, sorting = POINTS,
        get = function() return f.cPoint or "CENTER" end, set = function(_, v) f.cPoint = (v ~= "CENTER") and v or nil; apply() end }
    g.args.relPoint = { type = "select", name = "Point on the frame it is relative to", order = 4.4, width = "full", arg = { xuiSide = true }, values = PV, sorting = POINTS,
        get = function() return f.cRelPoint or f.cPoint or "CENTER" end, set = function(_, v) f.cRelPoint = v; apply() end }
    g.args.x = { type = "range", name = "X offset", order = 4.5, min = -1500, max = 1500, step = 1, softMin = -600, softMax = 600,
        get = function() return f.cX or 0 end, set = function(_, v) f.cX = (v ~= 0) and v or nil; applyStep() end }
    g.args.y = { type = "range", name = "Y offset", order = 4.6, min = -1500, max = 1500, step = 1, softMin = -600, softMax = 600,
        get = function() return f.cY or 0 end, set = function(_, v) f.cY = (v ~= 0) and v or nil; applyStep() end }
    return g
end

-- Static group arrangement (G7; Xaya 2026-11-06: "align / distribute / spacing saved and kept applying"; a dragged display: "Arrangement
-- wins"). One choice per direction is saved on the group (f.cArrX / f.cArrY / f.cArrGap) and core applies it again whenever a display in
-- the group changes (ns.ApplyGroupArrangement). The values keep the names of the former one-time buttons.
-- ns function (not a local) to stay under Lua's 200-locals-per-chunk limit.
function ns.FolderArrangeGroup(f)
    local X = { none = "None", left = "Align left", center = "Align center", right = "Align right", distribute = "Distribute horizontally", space = "Space horizontally" }
    local Y = { none = "None", top = "Align top", middle = "Align middle", bottom = "Align bottom", distribute = "Distribute vertically", space = "Space vertically" }
    local function apply()
        ns.ApplyGroupArrangement(f)
        ns.MarkDirty(); Notify()
    end
    return { type = "group", inline = true, order = 5.45, name = "Align & Arrange (Static Group)",
        hidden = function() return f.cType == "dynamic" or not ns.KindHas({ folder = f.id }, "visual") end,
        args = {
            note = { type = "description", order = 0, width = "full", fontSize = "small",
                name = "Kept for this group: its displays (not those of nested groups) stay lined up this way. A display you drag, nudge, add or resize goes back into line; pick None to place them freely." },
            arrX = { type = "select", order = 1, name = "Horizontal", values = X,
                sorting = { "none", "left", "center", "right", "distribute", "space" }, arg = { xuiSide = true },
                get = function() return f.cArrX or "none" end,
                set = function(_, v) f.cArrX = (v ~= "none") and v or nil; apply() end },
            arrY = { type = "select", order = 2, name = "Vertical", values = Y,
                sorting = { "none", "top", "middle", "bottom", "distribute", "space" }, arg = { xuiSide = true },
                get = function() return f.cArrY or "none" end,
                set = function(_, v) f.cArrY = (v ~= "none") and v or nil; apply() end },
            gap = { type = "range", order = 3, width = "double", name = "Gap for Space (pixels)", min = 0, max = 200, step = 1,
                hidden = function() return f.cArrX ~= "space" and f.cArrY ~= "space" end,
                get = function() return f.cArrGap or 8 end,
                -- (review R8) a slider step: the displays only; the window redraws itself on mouse up
                set = function(_, v) f.cArrGap = (v ~= 8) and v or nil; ns.ApplyGroupArrangement(f); ns.MarkDirty() end },
        } }
end

local function FolderSoundGroup(f)
    return {
        type = "group", inline = true, order = 5.6, name = "Sound Channel Override",   -- (her label, #372)
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
            deleteTop = { type = "execute", name = "|cffff6060Delete group|r", order = 1.5,
                desc = "Deletes this group only; its rules and nested groups move up one level. Keyboard: Delete while the group is open.",
                confirm = function() return "Delete this group? The rules and nested groups inside are kept and move up one level. " .. ns.RecycleBinNote() end,
                func = function() ns.DeleteFolderById(f.id) end },
            deleteAllTop = { type = "execute", name = "|cffff6060Delete with contents|r", order = 1.6,
                desc = "Deletes this group, every nested group, and every rule inside them. They go to the Recycle Bin together as one item.",
                confirm = function() return "Delete this group AND all rules and nested groups inside it? They go to the Recycle Bin together as one item, for " .. ns.RecycleKeepLabel() .. "." end,
                func = function() ns.DeleteFolderAllById(f.id) end },
            newRule = { type = "execute", name = "+ New rule", order = 2, desc = "Adds a new rule to this group.",
                func = function()
                    StartNewRule(f.id)
                end },
            newSub = { type = "execute", name = "+ Nested group", order = 2.5, desc = "Adds a new group inside this one.",
                func = function()
                    local nf = ns.NewFolder("Group", f.id)
                    local scope = ns.CurrentScope()
                    local path = { ns.PlaceNewGroup(nf, scope) }
                    Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, unpack(path))
                end },
            enableAll = { type = "execute", name = "Enable all", order = 3, desc = "Switches on every rule in this group and its nested groups.",
                func = function() for _, r in ipairs(FolderTopRules(f.id)) do r.enabled = true; ns.RefreshVisual(r) end; ns.MarkDirty(); Notify() end },
            disableAll = { type = "execute", name = "Disable all", order = 4, desc = "Switches off every rule in this group and its nested groups.",
                func = function() for _, r in ipairs(FolderTopRules(f.id)) do r.enabled = false; ns.RefreshVisual(r) end; ns.MarkDirty(); Notify() end },
            pausePv = { type = "toggle", name = "Pause preview animations", order = 4.5, width = "double",
                hidden = function() return not ns.KindHas({ folder = f.id }, "visual") end,
                desc = "Freezes the sample countdown, fades and flash in every preview, not only this group's. Untick to resume.",
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
        },
    }
    -- Tabs (like a rule): Group | Display | Load. The pieces above are sorted into them here.
    local function take(keys)
        local t = {}
        for _, k in ipairs(keys) do if g.args[k] then t[k] = g.args[k]; g.args[k] = nil end end
        return t
    end
    local container = g.args.container
    local isVisual = function() return ns.KindHas({ folder = f.id }, "visual") end
    -- Config (#372; Xaya 2026-11-06: "tabs Group | Display | Load | Config (Group first)", "Delete / New / Enable on Config"; CHAT-3d:
    -- "config includes folder name, folder type, and original character / source of creation. Also includes enable/disable toggle"):
    -- the name, the type, one Enabled toggle (it replaces Enable all / Disable all), the Sound Channel Override, New, Delete and where
    -- the group came from. Opacity, scale and layer stay on the Group tab with the container now ("strata / opacity / scale on Group").
    local configArgs = take({ "name", "newRule", "newSub", "deleteTop", "deleteAllTop", "soundChannel" })
    take({ "enableAll", "disableAll" })
    if configArgs.name then configArgs.name.order = 1 end
    for k, o in pairs({ newRule = 6, newSub = 6.1, deleteTop = 7, deleteAllTop = 7.1 }) do if configArgs[k] then configArgs[k].order = o end end
    if configArgs.soundChannel then configArgs.soundChannel.order = 5 end
    configArgs.enabled = { type = "toggle", order = 1.5, width = "full", name = "Enabled",
        desc = "Switches every rule in this group and its nested groups on or off.",
        get = function()
            local any = false
            for _, r in ipairs(FolderTopRules(f.id)) do any = true; if not r.enabled then return false end end
            return any
        end,
        set = function(_, v) for _, r in ipairs(FolderTopRules(f.id)) do r.enabled = v and true or false; ns.RefreshVisual(r) end; ns.MarkDirty(); Notify() end }
    if container and container.args then
        local any = false
        for k, v in pairs(container.args) do
            if type(k) == "string" and k:match("^ctype_") then configArgs[k] = v; container.args[k] = nil; v.order = 2 + (v.order % 1); v.hidden = function() return not isVisual() end; any = true end
        end
        if any then configArgs.typeHdr = { type = "header", order = 2, name = "Group type", hidden = function() return not isVisual() end } end
    end
    configArgs.origin = { type = "description", order = 8, width = "full", fontSize = "medium",
        name = function()
            local o = ns.CleanOrigin and ns.CleanOrigin(f.origin)
            if not o then return "Made by: not recorded (this group is older than the record)." end
            local how = ({ made = "made here", default = "a built-in category", imported = "imported" })[o.how or ""] or tostring(o.how or "made")
            local when = (o.at and date) and date("%Y-%m-%d", o.at) or nil
            return ("Made by: %s (%s%s)"):format(o.by or "unknown character", how, when and (", " .. when) or "")
        end }
    local groupArgs = g.args
    local dispArgs = take({ "pausePv" })   -- (Align & Arrange stays on the Group tab: Xaya 2026-11-06, "Move to Group tab")
    -- Xaya, 2026-11-04: "Pause preview animations" belongs on the Display tab (as on a rule's Display tab), not on the Group tab
    if dispArgs.pausePv then dispArgs.pausePv.order = 0.5 end
    dispArgs.note = { type = "description", order = 0, width = "full", fontSize = "small",
        name = "The settings of every display cue in this group and its nested groups. The group's own position, size, opacity, scale, layer and Align & Arrange are on the Group tab; its name, type and Enabled switch on the Config tab." }
    if ns.GroupDisplayArgs then for k, v in pairs(ns.GroupDisplayArgs(f, FolderRules, Notify)) do dispArgs[k] = v end end
    -- "icon size on Group" (Xaya 2026-11-06): the every-display size section moves to the Group tab
    if dispArgs.size then groupArgs.size = dispArgs.size; dispArgs.size = nil; groupArgs.size.order = 5.45 end
    local loadArgs = { override = take({ "loadOverride" }).loadOverride, conds = ns.FolderLoadConditions(f) }
    local lock = function() return ns.IsEditLocked({ folder = f.id }) end
    ns.LockArgs(groupArgs, lock); ns.LockArgs(dispArgs, lock); ns.LockArgs(loadArgs, lock); ns.LockArgs(configArgs, lock)
    -- A group page can't use AceConfig's own tabs (its rules and nested groups are the tree children below it), so the tab strip
    -- is a row of buttons and each tab's content is an unframed box shown only while its tab is picked.
    ns.folderTab = ns.folderTab or setmetatable({}, { __mode = "k" })
    local function cur()
        local t = ns.folderTab[f] or "group"
        if t == "display" and not isVisual() then t = "group" end
        return t
    end
    -- #370: drawn as tabs by the skin (arg.xuiTab: the same flat box and colors as a real tab, the picked one in the selected
    -- tab's colors). The gold label marks the picked tab only while the skin is off (a color code would override the theme's).
    local function Tab(key, label, order, hiddenFn)
        local function sel() return cur() == key end
        return { type = "execute", order = order, width = 0.8, hidden = hiddenFn,
            arg = { xuiTab = true, xuiTabSel = sel },
            name = function()
                local skinOff = PlatS.ui and PlatS.ui.skinOff
                return (sel() and skinOff) and ("|cffffd100" .. label .. "|r") or label
            end,
            func = function() ns.folderTab[f] = key; Notify() end }
    end
    local function Page(key, args)
        return { type = "group", inline = true, name = "", order = 0.2, hidden = function() return cur() ~= key end, args = args }
    end
    g.args = {
        tabGroup = Tab("group", "Group", 0.01),
        tabDisplay = Tab("display", "Display", 0.02, function() return not isVisual() end),
        tabLoad = Tab("load", "Load", 0.03),
        tabConfig = Tab("config", "Config", 0.04),
        pageGroup = Page("group", groupArgs),
        pageDisplay = Page("display", dispArgs),
        pageLoad = Page("load", loadArgs),
        pageConfig = Page("config", configArgs),
    }
    return g
end

-- Real load conditions for a group (class / spec / role / instance type). They are checked on top of every rule's own Load tab and cannot be
-- loosened by it (Conditions.lua ns.FolderLoadGate). Empty = no restriction. Never / Always above still wins.
function ns.FolderLoadConditions(f)
    local function setOf(field) f[field] = f[field] or {}; return f[field] end
    local function Multi(order, name, field, choices, sorting)
        return { type = "multiselect", name = name, order = order, width = "full", values = choices, sorting = sorting,
            get = function(_, k) return setOf(field)[k] and true or false end,
            set = function(_, k, v) setOf(field)[k] = v and true or nil; if next(f[field]) == nil then f[field] = nil end; ns.MarkDirty(); Notify() end }
    end
    -- #319: while this group loads "Always" (its own setting or a parent's), a list can still count: "Always load: only this class / spec"
    local function AlwaysRow(order, word, field, key)
        return { type = "toggle", order = order, width = "full", name = "Always load: only this " .. word,
            desc = "Keeps the " .. word .. " list above under Always: the group's rules load only for the " .. word .. " ticked there.",
            hidden = function() return ns.FolderLoadOverrideFrom(f.id) ~= "always" or not (f[field] and next(f[field])) end,
            get = function() return f[key] == true end,
            set = function(_, v) f[key] = v and true or nil; ns.MarkDirty(); Notify() end }
    end
    local classV, classO = {}, {}
    for _, c in ipairs(ns.ClassChoices()) do classV[c.id] = c.text; classO[#classO + 1] = c.id end
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
            classes = Multi(0.5, "Class", "loadClasses", classV, classO),
            classAlways = AlwaysRow(0.55, "class", "loadClasses", "alwaysClass"),
            specs = Multi(1, "Specialization", "loadSpecs", specV, specO),
            specAlways = AlwaysRow(1.05, "spec", "loadSpecs", "alwaysSpec"),
            roles = Multi(2, "Role", "loadRoles", roleV, roleO),
            inst = Multi(3, "Instance type", "loadInst", instV, ns.INSTANCE_TYPE_ORDER),
            -- the zone / instance / difficulty / size / encounter / item lists, as on a rule's Load tab (core 0.6.33; kept in f.loadIds)
            loadIds = { type = "group", inline = true, order = 4, name = "Zones, Instances, Bosses and Items",
                args = ns.LoadIdRows(function() f.loadIds = f.loadIds or {}; return f.loadIds end,
                    function() ns.MarkDirty(); Notify() end, function() return false end, SearchBox) },
        } }
end

-- Sidebar search: while the box has text, every group / category row (not a box on a page) that holds no matching rule is hidden, the (n) counts show
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
            -- (review R9) inline groups are boxes on a page (a group's Group / Display / Load / Config bodies), not sidebar rows: they hold
            -- no rule, so wrapping them hid the open group's whole page while the box had text
            if type(v) == "table" and v.type == "group" and not (v.inline or v.guiInline or v.dialogInline) then
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

-- (Options 0.6.83, P3 options split) The Rules tab: the rule lists (Enabled / Smart Categories / Disabled / Drafts), the type picker
-- and Auto-Generate Rules, plus the shelved QoL Elements' Stat Tracking and Buff Bars groups (their files are not loaded: ns.QoLOn is
-- nil). Moved unchanged out of Options.lua BuildOptions, which calls it first and draws the rest of the window.
function ns.OptionsApi.RuleEditor.BuildRulesTab()
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
                desc = "Asks first when the headphone icon on a row covers several sounds.",
                get = function() return not CoreS.skipSoundAllPrompt end,   -- (P5: XayaUI Rules' store)
                set = function(_, v) CoreS.skipSoundAllPrompt = (not v) or nil end },
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
    -- (Options 0.6.69, REQUEST-LOG A15 P-16) Drawn in the window (Tree.lazy): a rule's full editor is built only when it is on screen
    -- or asked for by a SelectGroup path; every other rule gets its sidebar row only (ns.OptionsApi.RuleStub), filled in place the
    -- moment the window draws it (the FeedGroup hook below). Called directly (tests, other files): every rule in full, as before.
    local lazy, want = Tree.lazy, Tree.want
    for i, rule in ipairs(ns.rules or {}) do
        local g
        if lazy and not (want and want["rule" .. i]) then g = ns.OptionsApi.RuleStub(i, rule) else g = BuildRule(i, rule) end
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
                -- a parent drawn as its row only: its outcomes / cues are built and embedded when it is filled (ns.OptionsApi.FillRule)
                if pg.xuiStub then pg.xuiStub.nested[#pg.xuiStub.nested + 1] = { rule = o.rule, n = cnt[par], g = o.g } end
                local oke, err = true, nil
                if not pg.xuiStub then
                    if o.g.xuiStub then o.g = BuildRule(o.g.xuiStub.i, o.rule) end
                    oke, err = pcall(ns.EmbedOutcome, pg, o.g, o.rule, cnt[par])
                end
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
                a.hidden = function(info, ...) if PickerShown(info) then return true end; if type(orig) == "function" then return orig(info, ...) end; return orig end
            end
        end
        -- Picker descriptions are kept to ONE line (about 55 characters) on purpose: a row that wraps to 2-3 lines was measured before
        -- its real width was known and came out too short, so the next row / the External header / Cancel drew over it.
        all.args.pickerHdr = { type = "header", order = 0.1, name = "Choose what this rule shows", hidden = function(info) return not PickerShown(info) end }
        local TI = ns.TypeIcon or function(_, f) return f end
        all.args.pickIcon = Entry(0.2, TI("icon", "Spell_Holy_PowerWordShield"), "Icon", "Shows a spell icon with an optional cooldown overlay", "icon")
        all.args.pickBar = Entry(0.4, TI("progressbar", "Ability_Rogue_Sprint"), "Progress Bar", "A bar with name, timer, and icon", "bar")
        all.args.pickProg = Entry(0.5, TI("progresstex", "Spell_Nature_TimeStop"), "Progress Texture", "Shows a texture that changes based on duration", "progresstex")
        all.args.pickText = Entry(0.6, TI("text", "INV_Misc_Note_01"), "Text", "One or more lines of text, with dynamic information", "text")
        all.args.pickTex = Entry(0.3, TI("sttexture", "INV_Misc_Gem_Variety_01"), "Texture", "Shows a custom texture", "texture")
        all.args.pickDGroup = Entry(0.65, TI("dyngroup", "INV_Misc_Bag_10_Blue"), "Dynamic Group", "A container whose elements move to fit what is detected", "dgroup")
        all.args.pickSound = Entry(0.62, TI("sound", "INV_Misc_Note_01"), "Sound Cue", "Plays a sound when its conditions are met, with no display", "sound")
        all.args.pickSGroup = Entry(0.63, TI("stgroup", "INV_Misc_Bag_10"), "Static Group", "A container with fixed X / Y positions for its elements", "sgroup")
        all.args.pickCustom = Entry(0.64, 1669494, "Custom", "A blank rule with no display, sound, or cues", "custom")
        all.args.pickImport = Entry(0.66, TI("import", "INV_Scroll_03"), "Import", "Import from an encoded string (opens the Import window)", "import")
        all.args.pickGap = { type = "description", order = 0.85, width = "full", fontSize = "large", name = " \n ", hidden = function(info) return not PickerShown(info) end }   -- empty rows: keeps Cancel clear of the last row
        all.args.pickCancel = { type = "execute", order = 0.9, name = "Cancel", width = "half", func = function() picker = nil; local o = ns.pickOrigin; ns.pickOrigin = nil; Notify(); if ns.pickSub then ns.GoPicker() else ns.GoHome(o) end; ns.pickSub = nil end }
        for _, k in ipairs({ "pickIcon", "pickBar", "pickProg", "pickText", "pickTex", "pickSound", "pickDGroup", "pickSGroup", "pickCustom", "pickImport", "pickCancel" }) do
            all.args[k].hidden = function(info) return not PickerShown(info) end
        end
    end
    -- The picker also lives on the Loaded, Disabled and Drafts pages, so New Rule keeps the tab it was pressed in. The same row tables are
    -- shared (their hidden functions look at `picker` and the page's sub-tab); the page's other non-group entries hide while the picker is open.
    -- (0.6.79; #487) withBoxes: also hide the page's inline boxes (the Drafts list is one inline box per draft) while the picker is open
    ns.PickerInto = function(args, withBoxes)
        if not (args and all.args.pickIcon) then return end
        for _, k in ipairs({ "pickerHdr", "pickIcon", "pickBar", "pickProg", "pickText", "pickTex", "pickDGroup", "pickSound", "pickSGroup", "pickCustom", "pickImport", "pickGap", "pickCancel" }) do
            args[k] = all.args[k]
        end
        for k, a in pairs(args) do
            if type(a) == "table" and (a.type ~= "group" or (withBoxes and a.inline)) and not tostring(k):match("^pick") and not a.xuiPickWrap then
                a.xuiPickWrap = true
                local orig = a.hidden
                a.hidden = function(info, ...) if PickerShown(info) then return true end; if type(orig) == "function" then return orig(info, ...) end; return orig end
            end
        end
    end
    ns.PickerInto(loadedArgs); ns.PickerInto(disabledArgs)
    -- Rules is a tab group with its own row of sub-tabs (2026-11-01). Each sub-tab keeps the same root rows as before (Loaded / Not Loaded,
    -- All Rules, a Disabled root), so every row path below the sub-tab is unchanged.
    -- Rules sub-tab order (Xaya, 0.6.4): Smart Categories | Enabled | Disabled | Drafts (Class/Spec Rule Creator pinned right). Enabled is
    -- the default tab: the window opens on it unless another sub-tab was open when the window was last closed (ui.rulesSub, saved while open).
    local enabledTab = { type = "group", name = "Enabled", order = 2, childGroups = "tree", args = {
        loaded = { type = "group", order = 1, childGroups = "tree",
            name = function() return "LOADED (" .. nLoaded .. ")" end, args = loadedArgs },
        spacer = { type = "group", order = 2.5, name = " ", disabled = true, args = {} },
        spacer1 = { type = "group", order = 1.5, name = " ", disabled = true, args = {} },
        spacer0 = { type = "group", order = 0.5, name = " ", disabled = true, args = {} },
        notloaded = { type = "group", order = 2, childGroups = "tree",
            name = function() return "NOT LOADED (" .. nNot .. ")" end, args = notArgs },
        -- AUTO-POPULATE RULES moved to the Class/Spec Rule Creator tab (2026-10-31)
        } }
    local smartTab = { type = "group", name = "Smart Categories", order = 1, childGroups = "tree", args = { all = all } }
    local draftsTab = ns.BuildDraftsPage and ns.BuildDraftsPage() or nil
    if draftsTab then
        draftsTab.order = 4; draftsTab.name = "Drafts"; ns.PickerInto(draftsTab.args, true)
        -- 0.6.4 (Xaya): always shown; with drafts off it explains them and offers the switch (Drafts.lua BuildDraftsPage)
        draftsTab.hidden = nil
    end
    -- (Options 0.6.68, REQUEST-LOG A15 P-16) ns.PickerInto holds `all` (the whole rule tree) in its closure; kept in ns it kept the last
    -- tree alive after the window closed (measured in the stand-in, 313 rules: 136.5 MB after a full collect, 0.0 MB once released).
    -- It is only used while this build runs.
    ns.PickerInto = nil
    local disabledTab = { type = "group", name = "Disabled", order = 3, childGroups = "tree", args = {
        disabled = { type = "group", order = 1, childGroups = "tree",
            name = function() return "DISABLED (" .. nDisabled .. ")" end, args = disabledArgs },
        } }
    -- Class/Spec Rule Creator is the last sub-tab; Skin.lua pins it to the far right of the tab row (2026-11-01)
    local creatorTab = BuildClassCreator()
    creatorTab.order = 9; creatorTab.hidden = nil; creatorTab.name = "Auto-Generate Rules"   -- (Options 0.6.63, UI-45: her name; was "Class/Spec Rule Creator")
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
            layout = Sel(CoreS.barGroup, "layout", "Arrange the bars", 3, BAR_LAYOUT, BAR_LAYOUT_ORDER,
                function() ns.MarkDirty(); Notify() end, { width = "double" }),
            spacing = Rng(CoreS.barGroup, "spacing", "Spacing", 4, 0, 40, 1, function() ns.MarkDirty() end,
                { disabled = function() return not ns.Val(CoreS.barGroup.layout) end }),
            gx = Rng(CoreS.barGroup, "x", "Group X", 5, -1500, 1500, 1, function() ns.MarkDirty() end,
                { disabled = function() return not ns.Val(CoreS.barGroup.layout) end }),
            gy = Rng(CoreS.barGroup, "y", "Group Y", 6, -900, 900, 1, function() ns.MarkDirty() end,
                { disabled = function() return not ns.Val(CoreS.barGroup.layout) end }),
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
                name = "Collects rules by what they actually do, without moving them out of their own groups. A rule that shows an icon and text appears under both. Rules with a Bar cue are listed under Progress Bars. Lists update as you change rules; empty ones are hidden." }
            for k, cat in ipairs(ns.SMART_CATS) do
                local args, n = {}, 0
                if cat.key == "smart_bar" and scope == "all" then   -- buff bars saved before Bars.lua was shelved (#103) stay listed
                    local nb = 0
                    for j = 1, #(ns.bars or {}) do
                        local bg = allBars.args["bar" .. j]
                        if bg then args["bar" .. j] = bg; n = n + 1; nb = nb + 1 end
                    end
                    total = total + nb
                end
                for i, rule in ipairs(ns.rules or {}) do
                    if inScope(i) and ns.SmartMatch(rule, cat.key) then args["rule" .. i] = ruleGroups[i]; n = n + 1 end
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
        local nIn = P.FolderRuleCounts()   -- (review R17) each group's rule count, nested groups included, counted once for this build
        -- (review R17) the listed rules directly in each group (their indexes, in rule order): each group below reads its own, not every rule
        local inFolder, NONE = {}, {}
        for i, rule in ipairs(ns.rules or {}) do
            if ruleGroups[i] and rule.folder ~= nil then
                local l = inFolder[rule.folder]
                if not l then l = {}; inFolder[rule.folder] = l end
                l[#l + 1] = i
            end
        end
        -- is the group drawn as a row of its own here (it exists, and is not a cue category)? Once per group, not once per rule
        local drawn = {}
        local function Drawn(id)
            if id == nil or not groups[id] then return false end
            local v = drawn[id]
            if v == nil then local f = FolderById(id); v = (f and not ns.CueTransparent(f)) and true or false; drawn[id] = v end
            return v
        end
        local function Scoped(f, scopeArgs, allowEmpty)
            local g = groups[f.id]
            if not g then return nil end
            local kids, count = {}, 0
            for _, i in ipairs(inFolder[f.id] or NONE) do
                if scopeArgs["rule" .. i] then kids["rule" .. i] = ruleGroups[i]; count = count + 1 end
            end
            for _, sf in ipairs(ns.folders or {}) do
                if sf.parent == f.id and sf.id ~= f.id then
                    local n, c = Scoped(sf, scopeArgs, allowEmpty)
                    if n then kids[sf.id] = n; count = count + c end
                end
            end
            if count == 0 and not next(kids) and not ((nIn[f.id] or 0) == 0 and ((allowEmpty == "loaded" and f.xuiScope ~= "notloaded" and f.xuiScope ~= "disabled") or ((allowEmpty == "notloaded" or allowEmpty == "disabled") and f.xuiScope == allowEmpty))) then return nil end   -- an empty group is listed in the list it was created from (Loaded by default)
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
                if scopeArgs[key] and Drawn(rule.folder) then moved[#moved + 1] = key end
            end
            for _, key in ipairs(moved) do scopeArgs[key] = nil end   -- listed under their group instead
            for id, n in pairs(top) do scopeArgs[id] = n end
        end
        Apply(loadedArgs, "loaded")
        Apply(notArgs, "notloaded")
        -- Disabled list (2026-11-03): a group is listed only when it directly holds a disabled rule (or is a new, still-empty group made
        -- here), straight under the list, with only those rules in it. No parent, grandparent or sibling groups are drawn around it, and
        -- the count is its own rules. (Loaded / Not Loaded keep the nested layout above.)
        local function ApplyFlat(scopeArgs, allowEmpty)
            local top, moved, listed = {}, {}, {}
            local function Label(f)   -- two listed groups can share a name (e.g. "Defensives" under two specs): then say which parent
                local nm = tostring(f.name)
                local clash = false
                for id, o in pairs(listed) do if id ~= f.id and tostring(o.name) == nm then clash = true; break end end
                if not clash then return nm end
                local p, seen = f.parent and FolderById(f.parent), {}
                while p and not seen[p.id] and ns.CueTransparent(p) do seen[p.id] = true; p = p.parent and FolderById(p.parent) or nil end
                return p and (nm .. " - in " .. tostring(p.name)) or nm
            end
            for _, f in ipairs(ns.folders or {}) do
                local g = groups[f.id]
                if g and not ns.CueTransparent(f) then
                    local kids, count = {}, 0
                    for _, i in ipairs(inFolder[f.id] or NONE) do
                        if scopeArgs["rule" .. i] then kids["rule" .. i] = ruleGroups[i]; count = count + 1 end
                    end
                    if count > 0 or ((nIn[f.id] or 0) == 0 and f.xuiScope == allowEmpty) then
                        local args = {}
                        for k, v in pairs(g.args or {}) do
                            if not (type(k) == "string" and (k:match("^rule%d+$") or k:match("^f%d+$"))) then args[k] = v end
                        end
                        for k, v in pairs(kids) do args[k] = v end
                        listed[f.id] = f
                        top[f.id] = { type = "group", order = g.order, childGroups = "tree",
                            name = function() return Label(f) .. " (" .. count .. ")" end, args = args }
                    end
                end
            end
            for i, rule in ipairs(ns.rules or {}) do
                local key = "rule" .. i
                if scopeArgs[key] and Drawn(rule.folder) then moved[#moved + 1] = key end
            end
            for _, key in ipairs(moved) do scopeArgs[key] = nil end   -- listed under their own group instead
            for id, n in pairs(top) do scopeArgs[id] = n end
            ns.DisabledListed = listed   -- which groups the Disabled list shows (row selection falls back to the list for any other)
        end
        ApplyFlat(disabledArgs, "disabled")
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
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allqol", "box" .. #QoLBoxes())
                end },
            tokens = { type = "description", order = 2, width = "full", fontSize = "small", name = TokenHelp },
        },
    }
    for i, box in ipairs(ns.QoLOn and QoLBoxes() or {}) do allQol.args["box" .. i] = BuildBox(i, box) end
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
    return track, allQol, allBars
end
-- (Options 0.6.69, REQUEST-LOG A15 P-16: a click took one full build, 0.5-0.9 s and ~165 MB of garbage with 313 rules in the stand-in,
-- nine tenths of it the 313 rule editors) The window builds each rule's sidebar row only; the editor of the rule on screen is built
-- when the window draws it. RuleStub: the row (the same name / hidden / order as the full editor's group) and the rule data fixes the
-- full build makes. FillRule: builds the editor into that same table (every list holding the row sees it), with the outcomes / cues
-- that show inside it and the same after-passes the full build runs over the whole tree (info icons, half-width inputs).
function ns.OptionsApi.RuleStub(i, rule)
    ns.OptionsApi.RuleDataFixes(rule)
    return { type = "group", childGroups = "tab", order = 1000 + i,
        hidden = ns.OptionsApi.RuleRowHidden(rule), name = ns.OptionsApi.RuleRowName(rule),
        args = {}, xuiStub = { i = i, rule = rule, nested = {} } }
end
function ns.OptionsApi.FillRule(stub)
    local s = type(stub) == "table" and stub.xuiStub
    if not s then return false end
    stub.xuiStub = nil
    local full = ns.OptionsApi.WithCueMemo(function()
        local g = BuildRule(s.i, s.rule)
        for _, o in ipairs(s.nested) do
            local og = o.g
            if og.xuiStub then og = BuildRule(og.xuiStub.i, o.rule) end
            local oke, err = pcall(ns.EmbedOutcome, g, og, o.rule, o.n)
            if not oke and not ns.embedErr then ns.embedErr = true; ns.Print("outcome embed error: " .. tostring(err)) end
        end
        return g
    end)
    if ns.SkinRows and ns.SkinRows() then pcall(ns.InfoPass, full) end
    pcall(ns.OptionsApi.HalfInputs, full)
    for k in pairs(stub) do stub[k] = nil end
    for k, v in pairs(full) do stub[k] = v end
    -- the window's narrowest width follows the widest dropdown in what it has drawn (Skin.lua ScanDropdowns): look again
    local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
    if of then of.xuiDD = nil end
    return true
end
-- AceConfigDialog draws a group through FeedGroup(appName, options, container, rootframe, path) (AceConfigDialog-3.0.lua, the copy in
-- Libs/; a method looked up on the library table at each call): every row-only rule on the path is filled first. Other addons' windows
-- pass straight through, as the first and cheapest check (A23 SD-12).
do
    local FeedGroup0 = AceConfigDialog.FeedGroup
    AceConfigDialog.FeedGroup = function(self, appName, options, container, rootframe, path, ...)
        if appName ~= APP then return FeedGroup0(self, appName, options, container, rootframe, path, ...) end
        if type(options) == "table" and type(path) == "table" then
            local g = options
            for n = 1, #path do
                g = type(g) == "table" and type(g.args) == "table" and g.args[path[n]] or nil
                if type(g) ~= "table" then break end
                if g.xuiStub then pcall(ns.OptionsApi.FillRule, g) end
            end
        end
        return FeedGroup0(self, appName, options, container, rootframe, path, ...)
    end
    -- SelectGroup(appName, ...path) walks a tree it builds itself: the rules named in the path are built in full for that walk, so a
    -- path into a rule's tab (the rule search's results, the QA walkthroughs) finds every level
    local SelectGroup0 = AceConfigDialog.SelectGroup
    AceConfigDialog.SelectGroup = function(self, appName, ...)
        if appName ~= APP then return SelectGroup0(self, appName, ...) end
        local want = {}
        for n = 1, select("#", ...) do local k = select(n, ...); if type(k) == "string" then want[k] = true end end
        local prev = Tree.want
        Tree.want = want
        local res = { pcall(SelectGroup0, self, appName, ...) }
        Tree.want = prev
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2, table.maxn(res))
    end
end
-- open the window (if needed) and jump to a rule; used by clicking an aura on screen while unlocked
-- (review R10) A display on screen mostly belongs to a cue, and a cue (or condition) has no row of its own: it is shown inside its rule.
-- So the rule's row is opened, on its Cues (Conditions) tab, in the list that is open (Enabled / Disabled stay; Smart Categories keeps
-- the type row). Before, the cue's own Smart Categories path was asked for: no such row, so the window fell back to the Smart
-- Categories front page, and any rule with a type switched the window to Smart Categories.
function ns.OptionsApi.EditRule(rule)
    if not ns.rules or not rule then return end
    if not (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]) then
        local ok, err = pcall(AceConfigDialog.Open, AceConfigDialog, APP)
        if not ok then ns.Print("could not open the window: " .. tostring(err)) return end
    end
    local top, tab = rule, nil
    local par = rule.parentUid and ns.FindParentRule and ns.FindParentRule(rule)
    if par then top, tab = par, (rule.isCue and "cues" or "conditions") end
    local path
    if ns.CurrentTab() == "smartcat" then path = { RulePath(top) }   -- (no type: RulePath gives its Enabled / Disabled row)
    else
        local okc, ctx = pcall(ns.ReadContext)
        path = { ns.ScopePath(top, okc and ctx or nil) }
    end
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, unpack(path))
    if tab and AceConfigDialog.GetStatusTable then   -- the rule's own tab row: its status lives at its full path
        local st = AceConfigDialog:GetStatusTable(APP, path)
        if st then st.groups = st.groups or {}; st.groups.selected = tab end
    end
    Notify()
end

-- open the window (if needed) and jump to a group's page; used by the group name tabs of the mover view (Visual.lua)
-- (review R11) A group's row is in Enabled > Loaded / Not Loaded or Disabled (Smart Categories lists types only: its group rows are
-- hidden, so the old Smart Categories path fell back to that tab's front page). The list that is open is tried first.
function ns.OptionsApi.EditFolder(f)
    if not (f and ns.FolderById and ns.FolderById(f.id)) then return end
    if not (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]) then
        local ok, err = pcall(AceConfigDialog.Open, AceConfigDialog, APP)
        if not ok then ns.Print("could not open the window: " .. tostring(err)) return end
    end
    if ns.CueTransparent(f) then Notify(); return end   -- a built-in category / cue-type folder has no row of its own: stay where it is
    -- where it is listed (as BuildRulesTab lists it): Loaded / Not Loaded when it or a nested group holds such a rule, Disabled when it
    -- holds a disabled rule itself; an empty group in the list it was made in
    local okc, ctx = pcall(ns.ReadContext)
    local has, any = {}, false
    for _, r in ipairs(FolderTopRules(f.id)) do
        any = true
        local sc = ns.RuleScope(r, okc and ctx or nil)
        if sc ~= "disabled" or r.folder == f.id then has[sc] = true end
    end
    if not any then has[f.xuiScope == "notloaded" and "notloaded" or (f.xuiScope == "disabled" and "disabled" or "loaded")] = true end
    local order = { "loaded", "notloaded", "disabled" }
    local sub, cur = ns.CurrentSub(), ns.CurrentScope()
    if sub == "disabledTab" then order = { "disabled", "loaded", "notloaded" }
    elseif sub == "enabledTab" and cur == "notloaded" then order = { "notloaded", "loaded", "disabled" } end
    local scope
    for _, sc in ipairs(order) do if has[sc] then scope = sc; break end end
    if not scope then Notify(); return end   -- (only disabled rules, all in nested groups: no row anywhere)
    local p
    if scope == "disabled" then p = { "cooldowns", "disabledTab", "disabled", f.id }   -- the Disabled list is flat
    else
        p = { "cooldowns", "enabledTab", scope }
        for _, c in ipairs(FolderChain(f)) do if not ns.CueTransparent(c) then p[#p + 1] = c.id end end
    end
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, unpack(p))
    Notify()
end

-- for the other files of this folder (ns.OptionsApi.RuleEditorParts)
P.StartNewRule = StartNewRule
end
ns.RuleEditorFiles = ns.RuleEditorFiles or {}
ns.RuleEditorFiles[#ns.RuleEditorFiles + 1] = EditorFileInit
