-------------------------------------------------------------------------------
-- CharacterPane.lua : QoL > Character Toolkit, the character window's own tools (XayaUI QoL 0.7.53). The item level / socket / enchant
-- overlays on the character window's slots, and extra lines on the character window's own stat tooltips. OFF by default; while off
-- nothing is created, registered or read.
-- (QoL 0.7.53, character pane split stage 2; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 4.2) Xaya's Q5 answer: "The Advanced
-- Character Stats pane window is a Bonus feature; ... the simple character/dressing room UI with the ability to customize stat display
-- overhaul is a qol feature". These parts were in CharacterToolkit.lua until QoL 0.7.52; that file, the Stat Calculator's panel and its
-- tabs, is XayaUI Bonus Features' now (XayaUI_Bonus/CharacterToolkit.lua, git history kept there). The code below is the old file's, moved
-- unchanged except where a comment says otherwise. Which part went where: debug-log/2026-11-08-0915-character-split-0.7.53.md.
-- Saved settings: XayaUIQoLDB.characterToolkit (the switch `enabled`, the overlays' and the tooltip lines' keys; the panel's keys are
-- XayaUIBonusDB.characterToolkit's since QoL 0.7.53, Modules.lua LEGACY_SPLIT). The tooltip lines are kept here although they show the
-- Stat Calculator's numbers: they are on the character window's own stat tooltips (an ambiguous piece, kept with QoL and listed for Xaya).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local QolS = ns.Settings("qol")   -- (QoL 0.7.47, P2 settings seam; QoL 0.7.49, P5: QoL's own XayaUIQoLDB; Modules.lua section 0b)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("qol", "XayaUI_QoL", "XayaUIQoLDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)
local CM = ns.CharModel

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local isSecret = CM.IsSecret

-------------------------------------------------------------------------------
-- Settings (QoL's half of characterToolkit; the switch `enabled` is in both halves: Modules.lua LEGACY_SPLIT `both`)
-------------------------------------------------------------------------------
ns.CHARPANE_TOOLKIT_DEFAULTS = {
    enabled = false,
    tooltips = true,       -- extra lines on the character window's stat tooltips
    overlays = false,      -- item level / socket / enchant marks on the character window's slots
    ovIlvl = true, ovSockets = true, ovEnchants = true,
    ovSize = 11,
    enchantSlots = {},     -- slot IDs the player ticked to flag when they have no enchant; empty = this expansion's slots (CM.EnchantSlots)
    -- enchantSlotsSet: true once the player has changed a tick (then enchantSlots is used even when empty)
}
local function CopyVal(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyVal(x) end
    return t
end
local function Cfg()
    if not ns.SettingsReady("qol") then return nil end
    local c = QolS.characterToolkit
    if type(c) ~= "table" then c = {}; QolS.characterToolkit = c end
    for k, v in pairs(ns.CHARPANE_TOOLKIT_DEFAULTS) do
        if c[k] == nil then c[k] = CopyVal(v) end
    end
    c.ovSize = math.max(8, math.min(16, tonumber(c.ovSize) or 11))
    if type(c.enchantSlots) ~= "table" then c.enchantSlots = {} end
    if c.enchantSlotsSet ~= true then c.enchantSlotsSet = nil end
    return c
end
ns.CharPane_ToolkitCfg = Cfg   -- (the enchant slots: the Character Reskin's blocks and the Shopping List read them)

-- (QoL 0.7.53) the hover of one line, for the tests that read it here before (the code is CM.TooltipLines, CharacterModel.lua)
ns.CharToolkit_TooltipLines = function(it, mode) return CM.TooltipLines(it, mode) end

-------------------------------------------------------------------------------
-- Theme (the parts the overlays use; the same as the panel's, CharacterToolkit.lua)
-------------------------------------------------------------------------------
local function TC(class, prop, fb)
    local T = ns.Theme
    if T and T.Col then
        local ok, col = pcall(T.Col, class, prop, fb)
        if ok and type(col) == "table" then return col end
    end
    return fb
end
local TONES = { good = { 0.5, 1, 0.5, 1 }, warn = { 1, 0.56, 0.25, 1 } }
local function ToneColor(tone, fb)
    if tone == "mute" then return TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 }) end
    return TONES[tone] or fb
end
local function FontPath(fs)
    local T = ns.Theme
    if T and T.FontPath then local ok, p = pcall(T.FontPath); if ok and type(p) == "string" then return p end end
    local p = fs and fs.GetFont and fs:GetFont()
    return p
end
local function SetFont(fs, size, flags)
    local path = FontPath(fs)
    if path then pcall(fs.SetFont, fs, path, size, flags or "") end
end
local function Docked() local cf = _G.CharacterFrame; return cf and cf.IsShown and cf:IsShown() end
local function Owner() return _G.PaperDollFrame or _G.CharacterFrame end

-------------------------------------------------------------------------------
-- Slot overlays on the character window: item level, empty sockets, missing enchant (slots the player ticks)
-------------------------------------------------------------------------------
local overlays = {}
local function SlotButton(slotName) return _G["Character" .. slotName] end
local function UpdateOverlay(button)
    local c = Cfg()
    if not (button and c) then return end
    local o = overlays[button]
    if not (c.enabled and c.overlays) then
        if o then o:Hide() end
        return
    end
    local slot = button.GetID and button:GetID()
    if not num(slot) or slot <= 0 then return end
    if not o then
        o = CreateFrame("Frame", nil, button)
        o:SetAllPoints(button)
        if o.SetFrameLevel and button.GetFrameLevel then o:SetFrameLevel((button:GetFrameLevel() or 1) + 3) end
        o.ilvl = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        o.ilvl:SetPoint("BOTTOM", o, "BOTTOM", 0, 2)
        o.marks = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        o.marks:SetPoint("TOP", o, "TOP", 0, -2)
        o.ilvl.xuiOwn, o.marks.xuiOwn = true, true   -- (the reskin's /xui reskin status lists only other addons' text)
        overlays[button] = o
    end
    local eSlots, eDefault = CM.EnchantSlots(c)
    -- (QoL 0.7.14) while the Character Reskin draws its own item level / enchant on the slot, these leave theirs out: one of each per slot
    -- (QoL 0.7.19) and the empty-socket mark while it draws the sockets
    local rIlvl = ns.CharReskin_DrawsIlvl and ns.CharReskin_DrawsIlvl()
    local rEnch = ns.CharReskin_DrawsEnchants and ns.CharReskin_DrawsEnchants()
    local rSock = ns.CharReskin_DrawsSockets and ns.CharReskin_DrawsSockets()
    local data = CM.SlotOverlay(slot, { ilvl = c.ovIlvl and not rIlvl, sockets = c.ovSockets and not rSock, enchants = c.ovEnchants and not rEnch,
        enchantSlots = eSlots, enchantDefault = eDefault })
    SetFont(o.ilvl, c.ovSize, "OUTLINE")
    SetFont(o.marks, math.max(8, c.ovSize - 2), "OUTLINE")
    o.ilvl:SetText(data.ilvl or "")
    local parts = {}
    for _, mk in ipairs(data.marks) do
        local col = ToneColor(mk[2], { 1, 1, 1, 1 })
        parts[#parts + 1] = ("|cff%02x%02x%02x%s|r"):format(math.floor(col[1] * 255 + 0.5), math.floor(col[2] * 255 + 0.5), math.floor(col[3] * 255 + 0.5), mk[1])
    end
    o.marks:SetText(table.concat(parts, " "))
    o.data = data
    o:Show()
end
function ns.CharToolkit_UpdateOverlays()
    local c = Cfg()
    if not (c and c.enabled and c.overlays) and next(overlays) == nil then return end   -- off and never drawn: nothing to do (V14)
    for _, s in ipairs(CM.SLOTS) do
        local b = SlotButton(s[4])
        if b then UpdateOverlay(b) end
    end
end
-- the overlay drawn on one slot: { ilvl text, marks text } (tests)
function ns.CharToolkit_OverlayText(slotName)
    local o = overlays[SlotButton(slotName)]
    if not o or not o:IsShown() then return nil end
    return o.ilvl:GetText(), o.marks:GetText()
end


-------------------------------------------------------------------------------
-- Events: only while the overlays are on (and the cache reset on a spec change / level up while the toolkit is on: the overlays and
-- the tooltip lines read the model). (QoL 0.7.53: the panel's own events went with it to XayaUI Bonus Features.)
-------------------------------------------------------------------------------
local ev
local OVERLAY_EVENTS = { PLAYER_EQUIPMENT_CHANGED = true, GET_ITEM_INFO_RECEIVED = true, SOCKET_INFO_UPDATE = true, ENCHANT_SPELL_COMPLETED = true }
local overlayPending
local function RefreshOverlays()
    if overlayPending then return end
    overlayPending = true
    local run = function() overlayPending = false; if Docked() then ns.CharToolkit_UpdateOverlays() end end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, run) else run() end
end
local function OnEvent(_, event)
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LEVEL_UP" then CM.ClearCache() end
    if OVERLAY_EVENTS[event] then local c = Cfg(); if c and c.overlays then RefreshOverlays() end end
end

-------------------------------------------------------------------------------
-- Extra lines on the character window's own stat tooltips (post-hooks only; Blizzard's code runs unchanged first).
-------------------------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" })
local function Plain(s)
    if type(s) ~= "string" or isSecret(s) then return nil end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[:：]%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return s:lower()
end
local LABEL_KEYS = {
    { "STAT_CRITICAL_STRIKE", "crit" }, { "STAT_HASTE", "haste" }, { "STAT_MASTERY", "mastery" }, { "STAT_VERSATILITY", "vers" },
    { "STAT_AVOIDANCE", "avoidance" }, { "STAT_LIFESTEAL", "leech" }, { "STAT_SPEED", "speed2" }, { "STAT_ARMOR", "armor" },
    { "STAT_DODGE", "dodge" }, { "STAT_PARRY", "parry" }, { "STAT_BLOCK", "block" }, { "STAT_ATTACK_POWER", "ap" },
    { "WEAPON_SPEED", "speed" }, { "STAT_ATTACK_SPEED", "speed" }, { "DAMAGE", "damage" }, { "SPELL_STAT3_NAME", "stamina" },
    { "STAT_STAGGER", "stagger" }, { "STAT_SPELLPOWER", "sp" }, { "STAT_AVERAGE_ITEM_LEVEL", "ilvl" },
}
local function KeyForLabel(text)
    local p = Plain(text)
    if not p then return nil end
    for _, e in ipairs(LABEL_KEYS) do
        local g = Plain(_G[e[1]])
        if g and g == p then return e[2] end
    end
    for i = 1, 4 do
        local g = Plain(_G["SPELL_STAT" .. i .. "_NAME"])
        if g and g == p and i ~= 3 then return "stat" .. i end
    end
    if p:find("global cooldown", 1, true) then return "gcd" end
end
ns.CharToolkit_KeyForLabel = KeyForLabel

-- the stat map card each character-window stat row shows in its tooltip (A8)
local MAP_KEY = { crit = "map_crit", haste = "map_haste", mastery = "map_mastery", vers = "map_vers", avoidance = "map_avoidance",
    leech = "map_leech", speed2 = "map_speed2", armor = "map_armor", dodge = "map_dodge", parry = "map_parry", block = "map_block",
    ap = "map_ap", speed = "map_aspeed", damage = "map_damage", stamina = "map_stamina", stagger = "map_stagger", sp = "map_sp", gcd = "map_gcd" }
local function AppendTooltip(frame)
    local c = Cfg()
    if not (c and c.enabled and c.tooltips) or not GameTooltip then return end
    if GameTooltip.IsOwned and not GameTooltip:IsOwned(frame) then return end
    local label = frame.Label and frame.Label.GetText and frame.Label:GetText()
    local key = KeyForLabel(label)
    if not key then return end
    -- (QoL 0.7.14, requirements A8; Xaya: "do you see how these tooltips behave?", "no. I don't want a bar next to the threshold")
    -- a compact block under Blizzard's own text: the stat map's lines for this stat at your real numbers (your typed numbers are left
    -- out here): rating and what it gives, rating per 1%, diminishing returns and the next threshold in words, then what it feeds (the
    -- "»" lines: parry from crit, armor from mastery, ...). No bars. Our own wording.
    local mk = MAP_KEY[key] or ((key == "stat1" or key == "stat2" or key == "stat4") and "map_primary") or nil
    -- (QoL 0.7.53) the Stat Calculator's settings are XayaUI Bonus Features' now: the model is read with the panel's defaults
    local clean = setmetatable({ whatIf = 0, whatIfStats = {}, whatIfPrimary = false, detail = "all", collapsed = {}, statOpen = {}, spells = {} }, { __index = c })
    local card = mk and CM.Build(clean, "stats").byKey[mk] or nil
    if key:match("^stat%d$") and card and card.label ~= (label and label:gsub("[:：]%s*$", "")) then card = nil end   -- not your primary stat
    local lines = {}
    if card then
        if card.absolute then
            local from
            for _, p in ipairs(card.pairs or {}) do if p.label == "From rating" then from = tostring(p.value) end end
            lines[#lines + 1] = { "Rating", CM.Big(card.absolute) .. (from and (" = " .. from) or "") }
            if card.per and card.per ~= "" then lines[#lines + 1] = { "Rating per 1%", (card.per:gsub(" / 1%%$", "")) } end
        end
        for _, p in ipairs(card.pairs or {}) do
            -- (one text column: the Pt value and the note follow the value, QoL 0.7.15; a nested ability line is indented, 0.7.20)
            if p.label ~= "From rating" then lines[#lines + 1] = { CM.PairLabel(p), CM.PairText(p) } end
        end
    else
        local it = CM.Build(clean, nil).byKey[key]   -- (QoL 0.7.53: with the panel's defaults, as above; before, with its settings)
        if not it then return end
        for _, line in ipairs(CM.PairLines(it, true)) do lines[#lines + 1] = { line } end
    end
    if #lines == 0 then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("XayaUI", 0.2, 0.8, 1)
    for _, l in ipairs(lines) do
        if l[2] ~= nil and GameTooltip.AddDoubleLine then GameTooltip:AddDoubleLine(l[1], l[2], 0.75, 0.75, 0.8, 0.95, 0.95, 0.95)
        elseif l[2] ~= nil then GameTooltip:AddLine(l[1] .. ": " .. l[2], 0.85, 0.85, 0.85, true)
        else GameTooltip:AddLine(l[1], 0.85, 0.85, 0.85, true) end
    end
    GameTooltip:Show()
end

local function HookStatFrames()
    local pane = _G.CharacterStatsPane
    if not (pane and pane.GetChildren) then return end
    for _, child in ipairs({ pane:GetChildren() }) do
        if not hooked[child] and child.Label and child.HookScript then
            hooked[child] = true
            child:HookScript("OnEnter", AppendTooltip)
        end
    end
end
ns.CharToolkit_HookStatFrames = HookStatFrames

-------------------------------------------------------------------------------
-- On / off
-------------------------------------------------------------------------------
local ownerHooked, slotHooked, statHooked = false, false, false
-- (QoL 0.7.24, V14) the Tooltip lines' hooks (PaperDollFrame_UpdateStats and each stat row's OnEnter) are placed only once the Tooltip
-- lines are on; before, they came with the toolkit even while the lines were off. Placed, they return at once while it is off.
local function TooltipLinesOn() local c = Cfg(); return (c and c.enabled and c.tooltips) and true or false end

function ns.CharPane_ToolkitApply()
    local c = Cfg(); if not c then return end
    if not c.enabled then
        if ev then ev:UnregisterAllEvents() end
        for _, o in pairs(overlays) do o:Hide() end
        return
    end
    if not ev then
        ev = CreateFrame("Frame")
        ev:SetScript("OnEvent", OnEvent)
    end
    ev:UnregisterAllEvents()
    pcall(ev.RegisterEvent, ev, "PLAYER_SPECIALIZATION_CHANGED")
    pcall(ev.RegisterEvent, ev, "PLAYER_LEVEL_UP")
    if c.overlays then for e in pairs(OVERLAY_EVENTS) do pcall(ev.RegisterEvent, ev, e) end end
    if not ownerHooked then
        local owner = Owner()
        if owner and owner.HookScript then
            ownerHooked = true
            owner:HookScript("OnShow", function() if TooltipLinesOn() then HookStatFrames() end; ns.CharToolkit_UpdateOverlays() end)
        end
    end
    if c.tooltips and not statHooked and type(hooksecurefunc) == "function" and type(_G.PaperDollFrame_UpdateStats) == "function" then
        statHooked = true
        hooksecurefunc("PaperDollFrame_UpdateStats", function() if TooltipLinesOn() then HookStatFrames() end end)
    end
    if c.tooltips then HookStatFrames() end
    -- Blizzard redraws one slot button at a time; the overlay follows (post-hook, Blizzard's code runs unchanged first). Placed only once
    -- the overlays are on (QoL 0.7.19, V14: before, it was placed with the toolkit even while the overlays were off).
    if c.overlays and not slotHooked and type(hooksecurefunc) == "function" and type(_G.PaperDollItemSlotButton_Update) == "function" then
        slotHooked = true
        hooksecurefunc("PaperDollItemSlotButton_Update", UpdateOverlay)
    end
    ns.CharToolkit_UpdateOverlays()
end
ns.WhenSettingsReady("qol", function() if Cfg() then ns.CharPane_ToolkitApply() end end)   -- (P5: once XayaUIQoLDB is open, at this addon's ADDON_LOADED; Modules.lua section 0c)
-- (audit QA walkthrough, D17) which of these events are registered now
if ns.Provide then ns.Provide("charPaneDebug", { Cfg = function() return Cfg() end, Apply = function() return ns.CharPane_ToolkitApply() end,
    Registered = function(e) return (ev and ev.IsEventRegistered and ev:IsEventRegistered(e)) and true or false end }) end

-------------------------------------------------------------------------------
-- Settings: QoL > Character Toolkit (a feature node; its parts Slot Overlays and Tooltip lines are nodes under it). (QoL 0.7.53: the
-- Panel and Spell Math parts are XayaUI Bonus Features > Stat Calculator's now.)
-------------------------------------------------------------------------------
function ns.BuildCharToolkitPage(Notify)
    local function C() return Cfg() or CopyVal(ns.CHARPANE_TOOLKIT_DEFAULTS) end
    local function Changed() ns.CharPane_ToolkitApply(); if Notify then Notify() end end
    local isOff = function() return not C().enabled end
    local function Toggle(key, order, name, desc, width, hidden, tip)
        return { type = "toggle", order = order, width = width, name = name, desc = desc, hidden = hidden, tip = tip,
            get = function() return C()[key] and true or false end,
            set = function(_, v) C()[key] = v and true or false; Changed() end }
    end

    -- (QoL 0.7.24; Xaya 2026-11-06, asked whether the Character Toolkit's "Tooltip lines" get their own row and tick box: "Assume yes for
    -- now") the tooltip lines are a part of their own in the left pane, its tick box the switch that sat on Panel > Tooltips before
    local TIP_TEXT = "Adds the toolkit's lines under the character window's own stat tooltips. The panel's own hover does not need this."
    local tipsPart = {
        type = "group", name = "Tooltip lines", order = 40, hidden = isOff,
        xuiSwitch = Toggle("tooltips", 1, "Tooltip lines", TIP_TEXT, nil, nil, "Adds Stat Calculator lines to the character window's stat tooltips."),
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium", name = TIP_TEXT },
        },
    }

    local slotToggles = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Ticked to start with: the slots this expansion's enchants cover (head, shoulders, chest, legs, feet, both rings, main hand, and off hand when it holds a weapon). Change any tick and your own choice is kept. A ticked slot with no enchant shows E? (orange); an enchanted one shows E (green)." },
        reset = { type = "execute", order = 99, name = "This expansion's slots",
            desc = "Resets to the slots this expansion's enchants cover.",
            func = function() local c = C(); c.enchantSlots = {}; c.enchantSlotsSet = nil; Changed() end },
    }
    for i, s in ipairs(CM.SLOTS) do
        local slot = s[1]
        slotToggles["slot" .. slot] = { type = "toggle", order = i, name = CM.SlotLabel(slot),
            desc = "Flags this slot on the character window when its item has no enchant.",
            get = function() return CM.EnchantSlots(C())[slot] and true or false end,
            set = function(_, v)
                local c = C()
                if c.enchantSlotsSet ~= true then   -- the first change keeps every slot that shows ticked now
                    local now = {}
                    for k in pairs((CM.EnchantSlots(c))) do now[k] = true end
                    c.enchantSlots, c.enchantSlotsSet = now, true
                end
                c.enchantSlots[slot] = v and true or nil
                Changed()
            end }
    end
    local overlayPart = {
        type = "group", name = "Slot Overlays", order = 20, childGroups = "tab", hidden = isOff,
        xuiSwitch = Toggle("overlays", 1, "Slot overlays", "Marks on the character window's item slots. Off by default.", nil, nil, "Shows marks on the character window's item slots."),
        args = {
            show = { type = "group", name = "Show", order = 1, args = {
                ovIlvl = Toggle("ovIlvl", 2, "Item level", "Shows the item level at the bottom of the slot."),
                ovSockets = Toggle("ovSockets", 3, "Empty sockets", "Shows how many sockets have no gem (for example 2S) at the top. Hidden while the Character Reskin draws sockets."),
                ovEnchants = Toggle("ovEnchants", 4, "Enchant check", "Shows E? on a ticked slot with no enchant, E when it has one. Pick the slots on the Enchant Slots tab."),
                ovSize = { type = "range", order = 5, name = "Text size", min = 8, max = 16, step = 1,
                    get = function() return C().ovSize end, set = function(_, v) C().ovSize = v; Changed() end },
            } },
            enchants = { type = "group", name = "Enchant Slots", order = 2, args = slotToggles },
        },
    }

    return {
        type = "group", name = "Character Toolkit", order = 3, childGroups = "tree",
        -- (QoL 0.7.53) the tip named the Stat Calculator, which is XayaUI Bonus Features' now (wording listed for Xaya)
        xuiSwitch = Toggle("enabled", 1, "Character Toolkit", "Turns the toolkit on. While it is off nothing is created, registered or read.", nil, nil, "Turns on the character window's slot overlays and tooltip lines."),
        args = {
            -- (QoL 0.7.53) the intro described the Stat Calculator's panel, which is XayaUI Bonus Features' now (wording listed for Xaya)
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "The character window's own tools: marks on its item slots and extra lines on its stat tooltips. The Stat Calculator is in Bonus Features > Stat Calculator. Turn it on with the tick box on its row on the left; its parts (Slot Overlays, Tooltip lines) then show under it, each with its own tick box. Off by default." },
            overlayPart = overlayPart,
            tipsPart = tipsPart,
        },
    }
end
ns.RegisterSettingsPage("qol", "chartoolkit", ns.BuildCharToolkitPage)
