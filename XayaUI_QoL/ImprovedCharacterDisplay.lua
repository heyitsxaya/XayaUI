-------------------------------------------------------------------------------
-- ImprovedCharacterDisplay.lua : QoL > Improved Character Display (Stat Calculator V25 step R2; Xaya, REQUEST-LOG A24 #3-#6). Everything
-- XayaUI changes or draws on Blizzard's character window itself, in one place with one page and one switch:
--   * one item level per slot, colored by upgrade track and step, and each slot's enchant: one "Item level" option and one "Enchants"
--     option, each with a style, "On the slot" or "Beside the slot" (Xaya, REQUEST-LOG A24 #7, her answer "1 with the caveat needs
--     review in game"; option 1: "One 'Item level' option and one 'Enchants' option, each with a style choice: on the slot or beside it.
--     The overlap is gone."). They replace the two sets that drew the same things twice (the Slot Overlays marks: item level, "2S",
--     "E?" / "E"; and the item details: the item level on the slot, the enchant beside it). Beside each slot a block with the item level
--     (style Beside the slot), the enchant and the embellishment (Enchants beside the slot) and each gem (was the features half of
--     CharacterReskin.lua, QoL > Character Pane). UNVERIFIED IN GAME: the whole layout of the merged options waits for her in-game
--     review (Dev Assist walkthrough "slot-options");
--   * the full stat list over the stats pane: every Character Stats line, in her order, names and colors (same origin);
--   * the marks on the slots: the enchant check E? / E (Enchants, style On the slot) and the empty-socket count "2S" (its existing
--     tick box Empty sockets; the gems and sockets were left as they were: their placement is a choice for Xaya);
--   * the Stat Calc button in the window's title row: opens or closes the Stat Calculator (Bonus Features > Stat Calculator) through its
--     "statCalc" service, with its own switch here (was the Stat Calculator file's own, XayaUI Bonus Features).
-- The extra lines on the window's own stat tooltips are XayaUI Bonus Features' (Enhanced Tooltips > Character stats, XayaUI_Bonus/
-- Tooltips.lua section 5; V25 step R4, Xaya A24 #5 / #6): off by default there, and only while this is on. This file tells them when its
-- switch changes (the "charDisplay" service's On / OnChange); they read the numbers from the "statModel" service.
-- Her words: "the stat calculator is ONLY the window that appears by the side of the character pane. NOTHING that directly touches the
-- character pane is part of the stat calculator"; "call the character functionality modifications Improved Character Display" (A24 #3,
-- #4). Earlier ones the features came from: "prettify the character window"; "ilvl colored based on ilv tier (track ... AND upgrade tier
-- (color gradient))"; "enchants + gems should show to the side of the character pane"; "stat calculator should have a toggle open/close
-- button on the character menu and remember the last-left state on next open" (S1 #34).
-- The look of the window (border, background, the wider window and the extra height) is the Character Reskin's (CharacterReskin.lua). The
-- two run on their own; the seam between them is small and explicit: the reskin tells this file when the window's size changes and when
-- its look was laid out (ns.CharReskin_OnWindowSize, registered once while this is on), this file reads its extra height's slot gap
-- (ns.CharReskin_TallGap) and, once, its switch for the settings merge (ns.CharReskin_LookSavedOn).
-- Off by default (V14): while it is off nothing is created, hooked, registered or read. Plain frames only (nothing protected): it works in
-- and out of combat. Own frames only; Blizzard's are read and post-hooked (HookScript / hooksecurefunc), never changed.
-- Saved settings (internal keys, kept: see "Settings" below): XayaUIQoLDB.characterReskin (the switch `features`, the item level /
-- enchant / gem / stat list parts, the two styles and the stat list's choices) and XayaUIQoLDB.characterToolkit (QoL's half: the
-- empty-socket mark, the marks' text size, the old slot marks' keys, the tooltip lines' old switch, the enchant slots, the Stat Calc
-- button's switch). NOT RUN IN GAME: everything here is UNVERIFIED IN GAME.
-- Reverse read (diagnostic only, V25 G-029): the Character Reskin's "characterReskin" service Drawn reads this file's "charDisplay"
-- service Drawn (read only, for its /xui reskin status and Dev Assist counts); nothing else of the reskin reads this file's state.
-- (V27 gate fixes, U1 G-001 to G-034) the rows beside the slots and the full stat list are hover only: clicks and camera drags pass
-- through (SetMouseClickEnabled(false) + SetMouseMotionEnabled(true), set out of combat); item events are listened to only while the
-- window is open and only for the equipped items and their gems; the stat list is rebuilt only when a number it shows changed, and
-- not in combat (once when combat ends); positions are whole pixels.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local QolS = ns.Settings("qol")   -- (QoL's own XayaUIQoLDB; Modules.lua section 0b)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("qol", "XayaUI_QoL", "XayaUIQoLDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)
local CM = ns.StatModel

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
-- (V27 "Whole-pixel", U1 G-010) every position, size and offset this file stores or sets is a whole pixel: halves and the game's
-- rectangle / text-height reads are rounded once, where they are taken
local function Px(v) return math.floor(v + 0.5) end
local function CopyVal(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyVal(x) end
    return t
end

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------
-- The saved keys stay where they were (XayaUIQoLDB.characterToolkit's QoL half and XayaUIQoLDB.characterReskin's QoL half): both are
-- split keys core shares with another module (Modules.lua LEGACY_SPLIT: characterToolkit with the Stat Calculator's store, including
-- the `both` key `enabled`; characterReskin with Blizzard Reskin's), and the profile parts write them under these names, so renaming
-- them would change every profile string and break older ones. Players never see these names. One view, Cfg(), reads and writes each
-- field in its table; its `enabled` (the page's switch) is characterReskin's `features`.
local SHARED_KEYS = { overlays = true, ovIlvl = true, ovSockets = true, ovEnchants = true, ovSize = true, enchantSlots = true,
    enchantSlotsSet = true, statCalcButton = true, socketMark = true, ilvlStyle = true, enchantStyle = true }
local SHARED_DEFAULTS = {
    -- (tooltips: the extra lines on the stat tooltips' switch until V25 R4; they are Enhanced Tooltips' option now, XayaUI Bonus
    -- Features' tooltips.charStats, off by default. A value saved here before is no longer read.)
    -- (A24 #7) the old Slot Overlays switch and its three marks: no longer read except by the one-time move to the two options
    -- (MigrateSlotOptions below); their defaults are still saved, as `enabled` and `tooltips` are, so a profile string made with every
    -- default stays byte for byte what it was
    overlays = false,
    ovIlvl = true, ovSockets = true, ovEnchants = true,
    ovSize = 11,           -- the text size of the marks on the slots (E? / E and the empty-socket count)
    enchantSlots = {},     -- slot IDs the player ticked to flag when they have no enchant; empty = this expansion's slots (CM.EnchantSlots)
    -- enchantSlotsSet: true once the player has changed a tick (then enchantSlots is used even when empty)
    -- statCalcButton: false only once the player switches the Stat Calc button off (nil = on; never saved at its default)
    -- socketMark: true while the empty-socket count ("2S") on the slots is ticked (nil = off; never saved at its default)
    -- ilvlStyle / enchantStyle: the two options' styles (A24 #7; below, at PANE_DEFAULTS). Kept in this table, QoL's own profile part,
    -- so that importing a profile string sets them both ways (ProfilePart.lua: an absent style in a format-3 string is the default)
}
-- (A24 #7) ilvl: the Item level option; enchants: the Enchants option (the enchant, and beside the slot the embellishment); gems: the
-- gems and sockets beside the slots (unchanged). The styles (characterToolkit, above): ilvlStyle "beside" (nil = "On the slot", where
-- the item level showed before) and enchantStyle "slot" (nil = "Beside the slot", where the enchant showed before); neither is saved at
-- its default, so a profile string made with every default stays byte for byte what it was. DECISION for Xaya: these defaults for a new
-- player.
local PANE_DEFAULTS = { ilvl = true, enchants = true, gems = true, statList = true }
local STYLE_SLOT, STYLE_BESIDE = "slot", "beside"
-- the stat list's own choices (QoL 0.7.31; her answer "Show / hide each stat, Order, % / rating / both, Groups and colours"), by Character
-- Stats key: statHide[key] = true (hidden), statOrder[group key] = { stat keys }, statMode[key] = "percent" | "rating" | "both",
-- statName[key] / groupName[group key] = text, statColor[key] / groupColor[group key] = { r, g, b }
local LIST_TABLES = { "statHide", "statOrder", "statMode", "statName", "statColor", "groupName", "groupColor" }
ns.CHARDISPLAY_DEFAULTS = { enabled = false, statCalcButton = true }
for k, v in pairs(SHARED_DEFAULTS) do ns.CHARDISPLAY_DEFAULTS[k] = v end
for k, v in pairs(PANE_DEFAULTS) do ns.CHARDISPLAY_DEFAULTS[k] = v end

local sharedT, paneT
local view = setmetatable({}, {
    __index = function(_, k)
        if k == "enabled" then return paneT.features == true end
        if SHARED_KEYS[k] then return sharedT[k] end
        return paneT[k]
    end,
    __newindex = function(_, k, v)
        if k == "enabled" then paneT.features = v and true or false
        elseif SHARED_KEYS[k] then sharedT[k] = v
        else paneT[k] = v end
    end,
})
local function Tables()
    local t = QolS.characterToolkit
    if type(t) ~= "table" then t = {}; QolS.characterToolkit = t end
    local p = QolS.characterReskin
    if type(p) ~= "table" then p = {}; QolS.characterReskin = p end
    sharedT, paneT = t, p
end

-- The tie-ins (Xaya A24 #6: "Tie-ins between elements/addons cost nothing unless the other element is on; whether it is on is read
-- once at load, and once at the first options-window open after a reload; no repeated checks"). The Stat Calculator's service is read
-- here once when this is first on (at the login, or when it is switched on) and once more the first time this page is built. At the
-- first read made while this is ON (ns.CharDisplay_Apply) this file also gives the Stat Calculator its one callback (OnState): from then
-- on the Stat Calculator tells this file itself when its panel opens or closes, is switched on or off, or hides for combat (V26), so it
-- is never read again. (V14, U1 G-017) the page build's read only reads (Available, Shown): while this is off nothing is subscribed, so
-- the Stat Calculator's combat start / end and panel changes call nothing here.
local statCalc, scAvail, scOpen, tieRead, pageRead, subscribed = nil, false, false, false, false, false
local OnStatCalcState   -- (below, at the button)
local function ReadTieIns(again, subscribe)
    if tieRead and not again then return end
    tieRead = true
    statCalc = ns.Service and ns.Service("statCalc") or nil
    if statCalc then
        local okA, a = pcall(function() return statCalc.Available and statCalc.Available() end)
        local okS, o = pcall(function() return statCalc.Shown and statCalc.Shown() end)
        scAvail, scOpen = (okA and a == true), (okS and o == true)
        if subscribe and not subscribed and statCalc.OnState then
            subscribed = true
            pcall(statCalc.OnState, function(open, available) OnStatCalcState(open, available) end)
        end
    else
        scAvail, scOpen = false, false
    end
end

-- (V25 R2) the one-time merge of the two switches the character window's parts had before (QoL 0.7.53 - 0.7.55): the QoL page Character
-- Pane (`features`: item level, enchants, gems, the full stat list; while never saved it took the Character Reskin switch's value) and
-- the QoL page of the slot marks and tooltip lines (its switch is the saved key characterToolkit.enabled), plus the Stat Calc button
-- (shown while the Stat Calculator and its panel were on). Improved Character Display has one switch; so that nobody sees anything appear or go at the update,
-- it starts on when any of the three showed something, and each part that did NOT show is switched off (item level / enchants / gems /
-- stat list when Character Pane was off; slot marks when their page's switch was off; V25 R4: the tooltip lines are Enhanced
-- Tooltips' now and not touched here). Nothing showed: it stays off and
-- no part is changed. The Stat Calc button's switch is never changed (it shows only while the Stat Calculator's panel is on, as before).
-- Done once, at the login (every addon's settings are open then) or at the first read after it; the mark `_merged` starts with "_",
-- so profiles never carry it (core Modules.lua StripUnderscore). The keys stay where they are and nothing is deleted; the only values
-- written are `features` (on) and the part switches named above (off). DECISION (session, to confirm with Xaya): how the two switches
-- become one.
local function OldFeatures()
    if paneT.features ~= nil then return paneT.features == true end
    local r = ns.CharReskin_LookSavedOn and ns.CharReskin_LookSavedOn()
    if r ~= nil then return r == true end
    -- XayaUI Blizzard Reskin switched off: the copy CueRulesDB still keeps from before P5 (INFERENCE, as QoL 0.7.53 read it)
    if ns.SettingsOldValue then
        local old = ns.SettingsOldValue("reskin", "characterReskin")
        if type(old) == "table" then return old.enabled == true end
    end
    return false
end
-- (V32, U1 G-034) whether the Stat Calc button showed is read from the Stat Calculator's SAVED settings (its service's Cfg(): the Stat
-- Calculator and its panel on), not from Available(), which is false in combat (V26): a first login on the new version in combat
-- merges the same as one out of combat. Nothing is subscribed here (the merge can run while this stays off). A service without Cfg
-- (an older Stat Calculator) falls back to Available().
local function ButtonShowedSaved()
    local sc = ns.Service and ns.Service("statCalc") or nil
    if not sc then return false end
    if type(sc.Cfg) == "function" then
        local ok, c = pcall(sc.Cfg)
        return (ok and type(c) == "table" and c.enabled == true and c.panel == true) and true or false
    end
    local ok, a = pcall(function() return sc.Available and sc.Available() end)
    return (ok and a == true) and true or false
end
local function Merge()
    if paneT._merged then return end
    local feat, sharedOn, btn = OldFeatures(), sharedT.enabled == true, ButtonShowedSaved()
    if feat or sharedOn or btn then
        if not feat then paneT.ilvl, paneT.enchants, paneT.gems, paneT.statList = false, false, false, false end
        if not sharedOn then sharedT.overlays = false end
        paneT.features = true
    end
    paneT._merged = true
end
ns.CharDisplay_Merge = function() if ns.SettingsReady("qol") then Tables(); Merge() end end   -- (tests)
-- (V25) a profile string made before the merge (its QoL part is format 1; XayaUI_QoL/ProfilePart.lua calls this after the import wrote
-- its values): the same reading as the merge above, for the slot marks' old page that string carries (its switch `enabled` and
-- `overlays`). Marks showed in it: Improved Character Display is switched on (with the item details off when it was off, as the merge
-- does: that string's QoL part says nothing about them); no marks showed in it: the imported `overlays` is switched off. Before the
-- login's merge has run, nothing is done here: the merge reads the imported values itself. Nothing else is changed.
function ns.CharDisplay_MergeOlder(oldTk)
    if type(oldTk) ~= "table" or not ns.SettingsReady("qol") then return end
    if oldTk.enabled == nil and oldTk.overlays == nil then return end   -- (the string holds nothing of the slot marks' page)
    Tables()
    if not paneT._merged then return end
    if oldTk.enabled == true and oldTk.overlays == true then
        if paneT.features ~= true then
            paneT.ilvl, paneT.enchants, paneT.gems, paneT.statList = false, false, false, false
            paneT.features = true
        end
    else
        sharedT.overlays = false
    end
    if ns.CharDisplay_Apply then ns.CharDisplay_Apply() end
end

-- (A24 #7) the one-time move of each player's settings from the two overlapping sets to the two options, so that each player sees
-- what they saw before. Before it: the Slot Overlays (switch `overlays`; marks ovIlvl, ovEnchants, ovSockets) drew a mark only where the
-- item details (ilvl, enchants, gems) did not draw the same thing (one of each per slot). The move, read from the saved values:
--   * Item level: on when either item level showed (the item details' `ilvl`, or the Slot Overlays' item level); style On the slot in
--     both cases, because both drew their item level on the slot (the old mark's own look, white at the Text size, is not kept: the
--     item level keeps the item details' look, colored by its track);
--   * Enchants: the item details' enchant beside the slot on -> Enchants on, Beside the slot (where both were ticked, only that one
--     showed, so Beside the slot is kept); else the Slot Overlays' enchant check on -> Enchants on, On the slot; else off;
--   * the empty-socket count "2S": ticked (socketMark) when the Slot Overlays and its Empty sockets were both on; it still shows only
--     while the gems beside the slots are off, as before.
-- Runs after the switch merge above (it reads what that merge left), once: the mark `_slotOpts` starts with "_", so profiles never
-- carry it. The old keys are kept as they are (nothing is deleted); a profile string made before (its QoL part older than format 3)
-- runs the move again over what it imported (ns.CharDisplay_RemapOlder).
-- `cur` (only from ns.CharDisplay_RemapOlder, below): the Item level / Enchants settings as they are now (already the two options),
-- read in place of the item details' old keys when an older profile string brought the old slot marks' keys without the item details'
-- ones; an option that is on keeps its style then.
local function MigrateSlotOptions(cur)
    if paneT._slotOpts then return end
    local marks = sharedT.overlays == true
    local markIlvl, markEnch, markSock = marks and sharedT.ovIlvl ~= false, marks and sharedT.ovEnchants ~= false, marks and sharedT.ovSockets ~= false
    local src = cur or paneT
    local detIlvl, detEnch = src.ilvl ~= false, src.enchants ~= false   -- (nil: the default, on)
    paneT.ilvl = (detIlvl or markIlvl) and true or false
    sharedT.ilvlStyle = (cur and detIlvl and cur.ilvlStyle == STYLE_BESIDE) and STYLE_BESIDE or nil   -- (nil: On the slot)
    if detEnch then   -- (nil: Beside the slot)
        paneT.enchants, sharedT.enchantStyle = true, (cur and cur.enchantStyle == STYLE_SLOT) and STYLE_SLOT or nil
    elseif markEnch then paneT.enchants, sharedT.enchantStyle = true, STYLE_SLOT  -- On the slot
    else paneT.enchants, sharedT.enchantStyle = false, nil end
    sharedT.socketMark = markSock or nil
    paneT._slotOpts = true
end
ns.CharDisplay_MigrateSlotOptions = function() if ns.SettingsReady("qol") then Tables(); if paneT._merged then MigrateSlotOptions() end end end   -- (tests)
-- (A24 #7) a profile string made before the two options (its QoL part is format 1 or 2; XayaUI_QoL/ProfilePart.lua calls this after
-- the import wrote its values): its old keys are read the way the one-time move reads saved settings. The QoL part is applied before
-- the Blizzard Reskin part that carries the item details' keys (core Modules.lua: order 40 and 60, in one pass), so the move runs on
-- the next frame, once both are in. Only when the string holds the old slot marks' keys.
-- (review round 2) When the string's Blizzard Reskin part is not imported with it (ProfilePart.lua tells ns.CharDisplay_NoteDetailsImport
-- when that part carries the item details' keys), the item level / enchant values saved now already mean the two options: they are
-- read as they were here (each option that is on keeps its style), never as the old keys, so an Enchants On the slot does not turn into
-- Beside the slot and an Item level beside the slot stays there; the string's old slot marks are added the same way as at the move.
local remapArmed, remapNow, detailsImported = false, nil, false
function ns.CharDisplay_RemapOlder(oldTk)
    if type(oldTk) ~= "table" or not ns.SettingsReady("qol") or remapArmed then return end
    if oldTk.overlays == nil and oldTk.ovIlvl == nil and oldTk.ovEnchants == nil and oldTk.ovSockets == nil then return end
    Tables()
    remapArmed, detailsImported = true, false
    remapNow = { ilvl = paneT.ilvl, enchants = paneT.enchants, ilvlStyle = sharedT.ilvlStyle, enchantStyle = sharedT.enchantStyle }
    local function run()
        local cur = (not detailsImported) and remapNow or nil
        remapArmed, remapNow, detailsImported = false, nil, false
        if not ns.SettingsReady("qol") then return end
        Tables()
        if not paneT._merged then return end   -- (the login's merge and move have not run yet: they read the imported values themselves)
        paneT._slotOpts = nil
        MigrateSlotOptions(cur)
        if ns.CharDisplay_Apply then ns.CharDisplay_Apply() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, run) else run() end
end
-- (review round 2) called by XayaUI_QoL/ProfilePart.lua just before the Blizzard Reskin part of an import is written: whether it carries
-- the item details' old keys (characterReskin's ilvl / enchants), while an older QoL part's move above waits for the next frame
function ns.CharDisplay_NoteDetailsImport(rk)
    if remapArmed and type(rk) == "table" and (rk.ilvl ~= nil or rk.enchants ~= nil) then detailsImported = true end
end

-- (A24 #7) a profile string made with the two options (its QoL part is format 3 or later; ProfilePart.lua calls this after the import
-- wrote its values): the merge import writes only the keys a string holds, and a style at its default is not saved, so a style the
-- string does not hold is its default. Same for the Empty sockets mark. Only when the string holds QoL's character settings at all.
function ns.CharDisplay_ImportStyles(tk)
    if type(tk) ~= "table" or not ns.SettingsReady("qol") then return end
    Tables()
    sharedT.ilvlStyle = (tk.ilvlStyle == STYLE_BESIDE) and STYLE_BESIDE or nil
    sharedT.enchantStyle = (tk.enchantStyle == STYLE_SLOT) and STYLE_SLOT or nil
    sharedT.socketMark = (tk.socketMark == true) or nil
    if ns.CharDisplay_Apply then ns.CharDisplay_Apply() end
end

local function Cfg()
    if not ns.SettingsReady("qol") then return nil end
    Tables()
    if not paneT._merged and ns.LoggedIn and ns.LoggedIn() then Merge() end
    if paneT._merged and not paneT._slotOpts then MigrateSlotOptions() end
    for k, v in pairs(SHARED_DEFAULTS) do if sharedT[k] == nil then sharedT[k] = CopyVal(v) end end
    -- the old page's switch: no longer read (only by the merge above), but its default is still saved as before so that a profile
    -- string made with every default stays byte for byte what it was (tests/profile_parts_run.py, share_strings_presplit_run.py)
    if sharedT.enabled == nil then sharedT.enabled = false end
    -- (V25 R4) the old Tooltip lines switch: no longer read (the lines are Enhanced Tooltips' option now, XayaUI Bonus Features'
    -- tooltips.charStats), but its old default is still saved, for the same reason as `enabled` above (profile strings and saved data
    -- stay byte for byte what they were)
    if sharedT.tooltips == nil then sharedT.tooltips = true end
    sharedT.ovSize = math.max(8, math.min(16, tonumber(sharedT.ovSize) or 11))
    if type(sharedT.enchantSlots) ~= "table" then sharedT.enchantSlots = {} end
    if sharedT.enchantSlotsSet ~= true then sharedT.enchantSlotsSet = nil end
    if sharedT.socketMark ~= true then sharedT.socketMark = nil end
    if sharedT.ilvlStyle ~= STYLE_BESIDE then sharedT.ilvlStyle = nil end
    if sharedT.enchantStyle ~= STYLE_SLOT then sharedT.enchantStyle = nil end
    for _, k in ipairs(LIST_TABLES) do if type(paneT[k]) ~= "table" then paneT[k] = {} end end
    for k, v in pairs(PANE_DEFAULTS) do
        if paneT[k] == nil then paneT[k] = v end
        paneT[k] = paneT[k] == true
    end
    return view
end
ns.CharDisplay_Cfg = Cfg
-- the enchant slots (the Shopping List's missing-enchant list reads them, ShoppingList.lua)
ns.CharDisplay_EnchantCfg = Cfg

-------------------------------------------------------------------------------
-- Theme: the slot marks and the Stat Calc button use the global theme (as before); the item details and the stat list the character
-- window's theme scope (Blizzard Reskin > Theme > Character Reskin), as before the split
-------------------------------------------------------------------------------
local function TCG(class, prop, fb)
    local T = ns.Theme
    if T and T.Col then
        local ok, col = pcall(T.Col, class, prop, fb)
        if ok and type(col) == "table" then return col end
    end
    return fb
end
local SCOPE = "reskin.charreskin"
local function TC(class, prop, fb)
    local T = ns.Theme
    if T and T.Col then local ok, c = pcall(T.Col, class, prop, SCOPE, fb); if ok and type(c) == "table" then return c end end
    return fb
end
local TONES = { good = { 0.5, 1, 0.5, 1 }, warn = { 1, 0.56, 0.25, 1 } }
local GOOD, WARN = TONES.good, TONES.warn
local function ToneColor(tone, fb)
    if tone == "mute" then return TCG("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 }) end
    return TONES[tone] or fb
end
local function WindowShown() local cf = _G.CharacterFrame; return (type(cf) == "table" and cf.IsShown and cf:IsShown()) and true or false end
local function Owner() return _G.PaperDollFrame or _G.CharacterFrame end

-------------------------------------------------------------------------------
-- State, own pieces, on / off
-------------------------------------------------------------------------------
local diag = { applied = false, failed = false, lastError = nil, slots = 0 }
ns.CharDisplayDiag = diag
-- our own pieces (made once, shown while this is on)
local own = { all = {} }
ns.CharDisplayParts = own   -- (for the tests)
local function Own(t) own.all[#own.all + 1] = t; return t end
local function SetOwnShown(on) for _, t in ipairs(own.all) do if t.SetShown then t:SetShown(on) end end end

-- On: the page's switch. Active: On, and the item details (the slot blocks, the item level, the full stat list) have not stopped after an
-- error this session (Guard below). The slot marks and the Stat Calc button need On only: an error in the item
-- details does not take them away (before V25 R2 they were other files').
-- (V14 / V27, U1 G-016) the lasting hooks call On() on every Blizzard redraw: Cfg()'s default-filling loops run again only when the
-- settings changed (core's ns.settingsEpoch moved) or after ns.CharDisplay_Apply; otherwise the switch is one read of the saved table.
local cfgEpoch = nil
local function CfgFast()
    local e = ns.settingsEpoch
    if e ~= nil and cfgEpoch == e and paneT then return view end
    local c = Cfg()
    if c then cfgEpoch = ns.settingsEpoch end
    return c
end
local function On() local c = CfgFast(); return (c ~= nil and paneT.features == true) and true or false end
local function Active() return On() and not diag.failed end
ns.CharDisplay_On = function() return On() end
ns.CharDisplay_Active = function() return Active() end
-- what the drawing code reads: the settings while this is on, nil while it is off
local function Eff() if not Active() then return nil end return CfgFast() end
local Guard, UpdateButton, GeoSig   -- (below)
-- (A24 #7) what each option draws where (c: the settings view). The Item level: on the slot (the item details' font string) or as the
-- first row of the block beside the slot. The Enchants: the enchant check E? / E on the slot (a mark), or the enchant and the
-- embellishment rows beside the slot. The gems and sockets beside the slots and the empty-socket mark are unchanged.
local function IlvlOnSlot(c) return c.ilvl == true and c.ilvlStyle ~= STYLE_BESIDE end
local function IlvlBeside(c) return c.ilvl == true and c.ilvlStyle == STYLE_BESIDE end
local function EnchOnSlot(c) return c.enchants == true and c.enchantStyle == STYLE_SLOT end
local function EnchBeside(c) return c.enchants == true and c.enchantStyle ~= STYLE_SLOT end
-- a block beside the slots (item level beside, enchant beside or gems): the layout, the camera buttons and the second pass need it
local function BlockOn(c) return IlvlBeside(c) or EnchBeside(c) or c.gems == true end
-- the item details: anything drawn by the slot layout (UpdateSlots)
local function DetailsOn(c) return c.ilvl == true or BlockOn(c) end
-- the marks on the slots: the enchant check (Enchants on the slot) or the empty-socket count, which shows only while the gems beside
-- the slots do not (one of each per slot; QoL 0.7.14, 0.7.19)
local function MarksOn(c) return EnchOnSlot(c) or (c.socketMark == true and not (c.gems == true and Active())) end
ns.CharDisplay_Draws = function()   -- (tests, Dev Assist: read only) where each option draws now
    local c = CfgFast()
    if not (c and On()) then return nil end
    return { ilvl = c.ilvl == true and (IlvlBeside(c) and STYLE_BESIDE or STYLE_SLOT) or nil,
        enchants = c.enchants == true and (EnchOnSlot(c) and STYLE_SLOT or STYLE_BESIDE) or nil, gems = c.gems == true,
        socketMark = c.socketMark == true and not (c.gems == true and Active()) }
end

-------------------------------------------------------------------------------
-- Marks on the character window's slots: the enchant check E? / E (Enchants, style On the slot; slots the player ticks) and the
-- empty-socket count "2S". (Was the old CharacterPane.lua's Slot Overlays, QoL 0.7.0 - 0.7.55; its item level mark went in A24 #7: the
-- Item level option draws the one item level on the slot.)
-------------------------------------------------------------------------------
local overlays = setmetatable({}, { __mode = "k" })   -- slot button -> our marks frame (own data, keyed by Blizzard's frame)
-- (own data, keyed by Blizzard's frame; V25 standard: never a field on Blizzard's slot button) slot button -> what the item details
-- drew on it: ilvl (our item level font string), ilvlText, ilvlDup, track, label (the block's layout), enchant, enchantRow, emb, embRow,
-- sockets (rows)
local slotData = setmetatable({}, { __mode = "k" })
local function SD(btn)
    local d = slotData[btn]
    if not d then d = {}; slotData[btn] = d end
    return d
end
ns.CharDisplay_SlotData = function(btn) return slotData[btn] end   -- (tests, Dev Assist: read only; nil when nothing was drawn on it)
local function SlotButton(slotName) return _G["Character" .. slotName] end
local function OvFontPath(fs)
    local T = ns.Theme
    if T and T.FontPath then local ok, p = pcall(T.FontPath); if ok and type(p) == "string" then return p end end
    return fs and fs.GetFont and fs:GetFont()
end
local function OvSetFont(fs, size, flags)
    local path = OvFontPath(fs)
    if path then pcall(fs.SetFont, fs, path, size, flags or "") end
end
-- the gems beside the slots draw the sockets: the empty-socket mark leaves its count out (one per slot; QoL 0.7.14). After an error in
-- the item details (Guard) they no longer draw, and the mark shows its count again.
local function DrawsSockets() local c = Eff(); return (c and c.gems == true) and true or false end
local function UpdateOverlay(button)
    local c = Cfg()
    if not (button and c) then return end
    local o = overlays[button]
    local sock, ench = c.socketMark == true and not DrawsSockets(), EnchOnSlot(c)
    if not (On() and (sock or ench)) then
        if o then o:Hide() end
        return
    end
    local slot = button.GetID and button:GetID()
    if not num(slot) or slot <= 0 then return end
    if not o then
        o = CreateFrame("Frame", nil, button)
        o:SetAllPoints(button)
        if o.SetFrameLevel and button.GetFrameLevel then o:SetFrameLevel((button:GetFrameLevel() or 1) + 3) end
        o.marks = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        o.marks:SetPoint("TOP", o, "TOP", 0, -2)
        o.marks.xuiOwn = true   -- (our own font string: the duplicate check lists only other addons' text)
        overlays[button] = o
    end
    local eSlots, eDefault = CM.EnchantSlots(c)
    local data = CM.SlotOverlay(slot, { sockets = sock, enchants = ench, enchantSlots = eSlots, enchantDefault = eDefault })
    OvSetFont(o.marks, math.max(8, c.ovSize - 2), "OUTLINE")
    local parts = {}
    for _, mk in ipairs(data.marks) do
        local col = ToneColor(mk[2], { 1, 1, 1, 1 })
        parts[#parts + 1] = ("|cff%02x%02x%02x%s|r"):format(math.floor(col[1] * 255 + 0.5), math.floor(col[2] * 255 + 0.5), math.floor(col[3] * 255 + 0.5), mk[1])
    end
    o.marks:SetText(table.concat(parts, " "))
    o.data = data
    o:Show()
end
local function UpdateOverlays()
    local c = Cfg()
    if not (c and On() and MarksOn(c)) and next(overlays) == nil then return end   -- off and never drawn: nothing to do (V14)
    for _, s in ipairs(CM.SLOTS) do
        local b = SlotButton(s[4])
        if b then UpdateOverlay(b) end
    end
end
ns.CharDisplay_UpdateOverlays = UpdateOverlays
-- the marks drawn on one slot (their text, with its color codes), or nil when none shows there (tests, Dev Assist)
function ns.CharDisplay_SlotMarks(slotName)
    local o = overlays[SlotButton(slotName)]
    if not o or not o:IsShown() then return nil end
    return o.marks:GetText()
end
local overlayPending
-- (V27, U1 G-011) one run function for the file (no closure per event), armed only while the window is open
local function RunOverlays() overlayPending = false; if WindowShown() then UpdateOverlays() end end
local function RefreshOverlays()
    if overlayPending or not WindowShown() then return end
    overlayPending = true
    if C_Timer and C_Timer.After then C_Timer.After(0.2, RunOverlays) else RunOverlays() end
end

-------------------------------------------------------------------------------
-- Slots: one item level, track-coloured; the enchant, the embellishment and the gems beside it
-------------------------------------------------------------------------------
-- Blizzard's layout (live 12.1.5 source, read 2026-11-05: PaperDollFrame.xml, ItemButtonTemplate.xml, ModelSceneControlFrame.xml /
-- .lua, ModelSceneMixin.lua): slot buttons 37 x 37, 4 px apart; the left column ends 7 px before the model scene (231 x 320 at 52, -66),
-- the right column starts 8 px after it; the model's camera buttons (its ControlFrame, TOP -10) are 32 high and 2 + n x (32 - 6) wide
-- for n <= 5 buttons, shown only while the mouse is over the model (ModelSceneMixin:OnEnter / OnLeave); the weapon slots sit at the
-- bottom between the columns; the game's own socket display (11 px sockets, 7 px beside the slot) shows only for Timerunning characters.
-- Our layout (QoL 0.7.22):
--   * beside each slot, toward the model, a block of rows: the enchant (its own name, without the "Enchant <slot> - " every enchant
--     name starts with), the embellishment, then one row per socket: a 16 px icon (12 when the block does not fit otherwise) and the
--     gem's name, or the socket's type when it is empty. The block stays inside its slot's band (the slot plus half the 4 px gap above
--     and below it, so two blocks never overlap), 6 px from the slot;
--   * with the wider window the block ends 4 px before the model scene, so nothing lies over the model or its camera buttons; at
--     Blizzard's width (7-8 px between the columns and the model) it runs toward the middle, over the model's sides, as in QoL 0.7.19;
--   * the weapons' blocks sit under the side columns, beside the weapons; a block never covers the weapon slots and their frame art;
--   * font 10, then 9, then 8 when a block does not fit its band; then each row on one line, cut at a word with "..."; then the gems
--     as icons in one row. Nothing is cut in the middle of a word. Hover a row: its whole text and what it does;
--   * a block that cannot clear the camera buttons (only at Blizzard's width: the head and hands rows) hides while they show.
local LEFT_SLOTS = { HeadSlot = true, NeckSlot = true, ShoulderSlot = true, BackSlot = true, ChestSlot = true, ShirtSlot = true,
    TabardSlot = true, WristSlot = true }
local WEAPON_SLOTS = { MainHandSlot = true, SecondaryHandSlot = true }
local NO_ENCHANT_TEXT = "No enchant"
local NO_EFFECT_TEXT = "Effect text not given by the game."
local FRIZ = "Fonts\\FRIZQT__.TTF"
local GUT = ns.UI_GUTTER or 10
local SLOT_PAD = 2                          -- half the 4 px between two slots: a slot's band reaches this far above and below it
local BLOCK_OFF, MODEL_GAP = 6, 4           -- the block starts 6 px from the slot and ends 4 px before the model scene
local MIN_COL = 40                          -- narrower than this beside the model at Blizzard's width: the 0.7.19 layout, toward the middle
-- (QoL 0.7.24 kept a block beside the model with the wider window on, hiding it when it did not fit; QoL 0.7.28 undoes that, her
-- answer "Over the model": below MIN_COL the block runs toward the middle at any width, see LabelBoxes.)
local ROW_GAP, ICON_GAP, COMPACT_GAP = 1, 3, 2
local ICON_SIZES = { 16, 12 }               -- the gem / socket icon (the game's own socket is 11 px; Xaya: "much too small"; QoL 0.7.24,
                                            -- her answer 2026-11-06: "16 px"; 12 only where a block does not fit at 16)
local CAM_TOP, CAM_H, CAM_W = 10, 32, 2 + 5 * (32 - 6)   -- the camera buttons, all five shown (the widest they get)
local ART_X, ART_TOP, ART_BOTTOM = 10, 8, 9 -- the weapon slots' frame art past the slot (Char-BottomSlot 42 x 53 at -4, 8; side pieces 6-7)
local LABEL_SIZES = { 10, 9, 8 }
local EMPTY_SOCKET_ATLAS = "character-emptysocket"   -- the game's own empty-socket art (PaperDollItemSocketSlotTemplate)
local GEM_COL, EMB_COL, GREY, EFFECT_COL = { 0.92, 0.92, 0.95, 1 }, { 0.55, 0.8, 1, 1 }, { 0.62, 0.62, 0.66, 1 }, { 0, 1, 0, 1 }

local function SlotName(slotID)
    for _, s in ipairs(CM.SLOTS) do if s[1] == slotID then return s[4] end end
end
local function FontPath() return ns.Theme and ns.Theme.FontPath and ns.Theme.FontPath() or FRIZ end
local function SetSize(fs, size, flags)
    if not fs:SetFont(FontPath(), size, flags or "") then fs:SetFont(FRIZ, size, flags or "") end
end
local function Mine(fs) fs.xuiOwn = true; return Own(fs) end

-- live rectangles (the game's coordinates: y grows upward); nil when a frame is not laid out or a value is secret
local function Rect(f)
    if type(f) ~= "table" or type(f.GetLeft) ~= "function" then return nil end
    local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
    local function bad(v) return CM.IsSecret(v) or not num(v) end
    if bad(l) or bad(r) or bad(t) or bad(b) or r <= l or t <= b then return nil end
    return { l = l, r = r, t = t, b = b }
end
local function Overlaps(a, b) return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t end
local function SlotBtn(name) return _G["Character" .. name] end
local function Justify(name) return (name == "MainHandSlot" or not (LEFT_SLOTS[name] or name == "SecondaryHandSlot")) and "RIGHT" or "LEFT" end

-- where the columns, the model, its camera buttons and the weapons are now
local function Geometry()
    local head, hands = Rect(SlotBtn("HeadSlot")), Rect(SlotBtn("HandsSlot"))
    if not (head and hands) then return nil end
    local g = { mid = Px((head.r + hands.l) / 2), colL = head.l, colR = hands.r }
    local model = Rect(_G.CharacterModelScene)
    if model then
        g.model = model
        local cx, hw = Px((model.l + model.r) / 2), Px(CAM_W / 2)
        g.cam = { l = cx - hw, r = cx + hw, t = model.t - CAM_TOP, b = model.t - CAM_TOP - CAM_H }
    end
    local mh, oh = Rect(SlotBtn("MainHandSlot")), Rect(SlotBtn("SecondaryHandSlot"))
    if mh and oh then
        g.weap = { l = math.min(mh.l, oh.l) - ART_X, r = math.max(mh.r, oh.r) + ART_X, t = math.max(mh.t, oh.t) + ART_TOP, b = math.min(mh.b, oh.b) - ART_BOTTOM }
        local cf = _G.CharacterFrame
        local inset = type(cf) == "table" and Rect(cf.Inset) or nil
        g.bottom = inset and inset.b or (math.min(mh.b, oh.b) - 12)   -- (the Inset's bottom is 12 below the weapons')
        g.leftLast, g.rightLast = Rect(SlotBtn("WristSlot")), Rect(SlotBtn("Trinket1Slot"))
    end
    return g
end

-- the rectangles a slot's block may use, best first
local function LabelBoxes(g, name, r)
    if WEAPON_SLOTS[name] then
        if not g.weap then return {} end
        local box
        if name == "MainHandSlot" then
            box = { l = g.colL, r = g.weap.l - GUT, t = (g.leftLast and g.leftLast.b or g.weap.t) - SLOT_PAD, b = g.bottom + SLOT_PAD }
        else
            box = { l = g.weap.r + GUT, r = g.colR, t = (g.rightLast and g.rightLast.b or g.weap.t) - SLOT_PAD, b = g.bottom + SLOT_PAD }
        end
        return { box }
    end
    local left, m = LEFT_SLOTS[name], g.model
    -- (QoL 0.7.31) with Extra height the slots are further apart: a block may use half the gap above and below its slot (not above the
    -- first slot of a column or below its last)
    local eg = Px((tonumber(ns.CharReskin_TallGap and ns.CharReskin_TallGap()) or 0) / 2)
    local hg = Px(GUT / 2)
    local box = { t = r.t + SLOT_PAD + ((name == "HeadSlot" or name == "HandsSlot") and 0 or eg),
        b = r.b - SLOT_PAD - ((name == "WristSlot" or name == "Trinket1Slot") and 0 or eg) }
    -- (QoL 0.7.28; Xaya 2026-11-06 at 0.7.27's 380 px window: "character pane now missing all previous information around gems,
    -- enchangs, embellishments, etc"; her answer "Over the model"; REQUEST-LOG #69 / #71) the 0.7.24 rule that a block never goes over
    -- the model with the wider window on is undone: whenever the room beside the model is narrower than MIN_COL, the block runs toward
    -- the middle, over the model's sides, at any window width (the 0.7.19 layout), so no block is hidden for lack of room
    if left then
        box.l = r.r + BLOCK_OFF
        box.r = (m and m.l - MODEL_GAP - box.l >= MIN_COL) and (m.l - MODEL_GAP) or (g.mid - hg)
        if box.r - box.l < 1 then return {} end
    else
        box.r = r.l - BLOCK_OFF
        box.l = (m and box.r - (m.r + MODEL_GAP) >= MIN_COL) and (m.r + MODEL_GAP) or (g.mid + hg)
        if box.r - box.l < 1 then return {} end
    end
    local w = g.weap
    if not (w and Overlaps(box, w)) then return { box } end
    local out = {}
    if box.t - (w.t + 1) >= 8 then out[#out + 1] = { l = box.l, r = box.r, t = box.t, b = w.t + 1 } end   -- above the weapons
    local n = { l = box.l, r = box.r, t = box.t, b = box.b }                                                 -- beside them
    if left then n.r = math.min(n.r, w.l - GUT) else n.l = math.max(n.l, w.r + GUT) end
    if n.r - n.l >= 20 then out[#out + 1] = n end
    return out
end

-- (QoL 0.7.24) every word must fit the width: at the 380 px window the room beside the model is about 18 px, and a word wider than
-- its line would run past it (the game truncates it). GetUnboundedStringWidth() -> width · SecretWhenAnchoringSecret (widgets.md:1463):
-- the text's width on one line, whatever the font string's width. Without it (or a secret answer) the word does not count as fitting.
local function WordsFit(fs, text, w)
    if type(fs.GetUnboundedStringWidth) ~= "function" then return true end
    local ok = true
    for wd in tostring(text):gmatch("%S+") do
        fs:SetText(wd)
        local ww = fs:GetUnboundedStringWidth()
        if CM.IsSecret(ww) or not num(ww) or ww > w + 0.5 then ok = false; break end
    end
    fs:SetText(text)
    return ok
end
local function Measure(fs, text, size, w, words)
    SetSize(fs, size)
    fs:SetWidth(w)
    fs:SetText(text)
    local h = fs:GetStringHeight()
    if CM.IsSecret(h) or not num(h) then return nil end
    if words and not WordsFit(fs, text, w) then return nil end
    return Px(h)
end

-- the top edge for a block of height h in box: level with the slot's middle, kept inside the box; moved above or below the camera
-- buttons when there is room. Returns the top and whether the block still meets the camera buttons.
local function PlaceTop(g, box, h, cy)
    local top = Px(math.min(box.t, math.max(box.b + h, cy + Px(h / 2))))
    local cam = g.cam
    if not (cam and Overlaps({ l = box.l, r = box.r, t = top, b = top - h }, cam)) then return top, false end
    local below = math.min(top, cam.b - 1)
    if below - h >= box.b then return below, false end
    local above = math.max(top, cam.t + 1 + h)
    if above <= box.t then return above, false end
    return top, true
end

-- (V27 "Hover only, clicks pass"; U1 G-001 / G-002 / G-005) our display over Blizzard's window (the rows beside the slots, which run
-- over the model's sides at Blizzard's width; the full stat list over the stats pane) shows a hover tooltip but never takes a click or
-- a camera drag: SetMouseClickEnabled(false) + SetMouseMotionEnabled(true). Both are IsProtectedFunction (widgets.md:283-284); these
-- frames are not protected, so the calls are probably allowed in combat (INFERENCE), but as her reading says they are set out of
-- combat: a frame made or changed in combat keeps the game's default until PLAYER_REGEN_ENABLED (a plain new Frame takes no mouse at
-- all, INFERENCE), then gets its setting once. The queue is filled only by such a frame and emptied at that event.
local NeedRegen   -- (below, at the events: registers PLAYER_REGEN_ENABLED while something waits for it)
local function InCombat() return (type(InCombatLockdown) == "function" and InCombatLockdown()) and true or false end
local HoverOnly, FlushMouse
do
    local mouseWant = setmetatable({}, { __mode = "k" })   -- own frame -> motion wanted, waiting for combat to end
    local function ApplyMouse(f, motion)
        if f.SetMouseClickEnabled then pcall(f.SetMouseClickEnabled, f, false) end
        if f.SetMouseMotionEnabled then pcall(f.SetMouseMotionEnabled, f, motion and true or false) end
    end
    HoverOnly = function(f, motion)
        motion = motion ~= false
        f.xuiMotion = motion
        if InCombat() then mouseWant[f] = motion; if NeedRegen then NeedRegen() end; return end
        mouseWant[f] = nil
        ApplyMouse(f, motion)
    end
    FlushMouse = function() for f, m in pairs(mouseWant) do mouseWant[f] = nil; ApplyMouse(f, m) end end
    ns.CharDisplay_MouseQueued = function() return next(mouseWant) ~= nil end   -- (tests, Dev Assist)
end

-- rows: a hover-only frame (only the row's own rectangle, never the slot) with its text; socket rows also an icon
local function RowEnter(f)
    local tt, d = _G.GameTooltip, f.tip
    if not (tt and d) or f.xuiFaded then return end   -- (G-002) a row faded out under the camera buttons shows no tooltip
    tt:SetOwner(f, "ANCHOR_RIGHT")
    if d.link and tt.SetHyperlink and pcall(tt.SetHyperlink, tt, d.link) then tt:Show(); return end
    for _, l in ipairs(d) do local c = l[2] or GEM_COL; tt:AddLine(l[1], c[1], c[2], c[3], true) end
    tt:Show()
end
local function RowLeave() if _G.GameTooltip then _G.GameTooltip:Hide() end end
local function NewRow(btn, justify, socket)
    local f = Own(CreateFrame("Frame", nil, btn))
    HoverOnly(f, true)   -- (G-001) hover tooltip only: a click or a camera drag that starts on a row reaches the model
    f:SetScript("OnEnter", RowEnter); f:SetScript("OnLeave", RowLeave)
    local fs = Mine(f:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
    if fs.SetJustifyV then fs:SetJustifyV("TOP") end
    fs:SetJustifyH(justify)
    f.text = fs
    if socket then
        f.bg = f:CreateTexture(nil, "BORDER")
        local atlas = C_Texture and C_Texture.GetAtlasExists and CM.R(C_Texture.GetAtlasExists, EMPTY_SOCKET_ATLAS) == true
        if atlas then f.bg:SetAtlas(EMPTY_SOCKET_ATLAS) else f.bg:SetColorTexture(0.12, 0.12, 0.14, 0.95) end
        f.gem = f:CreateTexture(nil, "ARTWORK")
        f.gem:SetPoint("TOPLEFT", f.bg, "TOPLEFT", 1, -1); f.gem:SetPoint("BOTTOMRIGHT", f.bg, "BOTTOMRIGHT", -1, 1)
    end
    return f
end
-- fn(row, arg) for each row of a slot's block (no table made per call)
local function EachRow(btn, fn, arg)
    local d = slotData[btn]
    if not d then return end
    if d.ilvlRow then fn(d.ilvlRow, arg) end
    if d.enchantRow then fn(d.enchantRow, arg) end
    if d.embRow then fn(d.embRow, arg) end
    if d.sockets then for _, f in ipairs(d.sockets) do fn(f, arg) end end
end
local function ShowRow(f, on)
    f:SetShown(on); f.text:SetShown(on)
    if not on then f.tip = nil; f.text:SetText("") end
end
-- (G-002) a row faded to alpha 0 (it meets the camera buttons) also lets go of the mouse: no hover, no tooltip, clicks pass to the
-- camera buttons; shown again, it takes hover again. Changed only when its state changes.
local function RowAlpha(f, a)
    f:SetAlpha(a); f.text:SetAlpha(a)
    local faded = a <= 0
    f.xuiFaded = faded
    if f.xuiMotion ~= (not faded) then HoverOnly(f, not faded) end
end
local function HideRow(f) ShowRow(f, false) end
local function SetBlockAlpha(btn, a) EachRow(btn, RowAlpha, a) end

-- one layout try: every row wrapped to the box's width at one font size and icon size; nil when it does not fit the box's height.
-- oneLine: each row cut to one line at a word; compact: the sockets as icons in one row, no names.
local function Fit(box, items, size, S, oneLine, compact)
    local rows, off, sockOff = {}, 0, nil
    if compact then   -- (QoL 0.7.24) the icons in one row must fit the box's width too (they never run over the model)
        local n = 0
        for _, it in ipairs(items) do if it.socket then n = n + 1 end end
        if n > 0 and n * S + (n - 1) * COMPACT_GAP > box.r - box.l + 0.01 then return nil end
    end
    for i, it in ipairs(items) do
        local gap = (i > 1) and ROW_GAP or 0
        if compact and it.socket then
            if not sockOff then sockOff = off + gap; off = sockOff + S end
            rows[i] = { text = "", h = 0, rh = S, w = 0, off = sockOff, compact = true }
        else
            local w = math.floor(box.r - box.l - (it.socket and (S + ICON_GAP) or 0))
            if w < 12 then return nil end
            local fs, text, h = it.row.text, it.text, 0
            if text ~= "" then
                h = Measure(fs, text, size, w, not oneLine)
                if not h then return nil end
                if oneLine then
                    local one = Measure(fs, "Ag", size, w)
                    if not one then return nil end
                    if h > one + 0.5 or not WordsFit(fs, text, w) then
                        local words, cutOk = {}, false
                        for wd in it.text:gmatch("%S+") do words[#words + 1] = wd end
                        for k = #words - 1, 1, -1 do
                            local cut = table.concat(words, " ", 1, k) .. "..."
                            local hc = Measure(fs, cut, size, w, true)
                            if hc and hc <= one + 0.5 then text, h, cutOk = cut, hc, true; break end
                        end
                        if not cutOk then return nil end
                    end
                end
            end
            local rh = math.max(h, it.socket and S or 0)
            rows[i] = { text = text, h = h, rh = rh, w = w, off = off + gap, cut = text ~= it.text }
            off = off + gap + rh
        end
    end
    if off > box.t - box.b + 0.01 then return nil end
    return { rows = rows, h = off, box = box, size = size, S = S }
end

-- lay one slot's block out: the largest icon and font that fit a box (one that clears the camera buttons first), else cut rows
local function LayoutBlock(btn, name, items)
    SD(btn).label = nil
    if #items == 0 then return end
    local g, r = Geometry(), Rect(btn)
    local boxes = (g and r) and LabelBoxes(g, name, r) or {}
    if #boxes == 0 then if not (g and r) then diag.noGeometry = true end; return end   -- not laid out yet: UpdateSlots retries
    local cy = Px(WEAPON_SLOTS[name] and (boxes[1].t + boxes[1].b) / 2 or (r.t + r.b) / 2)
    local pick
    local function try(p)
        if not p then return false end
        p.top, p.camHit = PlaceTop(g, p.box, p.h, cy)
        if not p.camHit then pick = p; return true end
        pick = pick or p
        return false
    end
    for _, S in ipairs(ICON_SIZES) do
        for _, size in ipairs(LABEL_SIZES) do
            for _, box in ipairs(boxes) do if try(Fit(box, items, size, S)) then break end end
            if pick and not pick.camHit then break end
        end
        if pick and not pick.camHit then break end
    end
    if not pick then
        local box, S, size = boxes[#boxes], ICON_SIZES[#ICON_SIZES], LABEL_SIZES[#LABEL_SIZES]
        try(Fit(box, items, size, S, true))
        if not pick then try(Fit(box, items, size, S, true, true)) end
        if pick then pick.cut = true end
    end
    if not pick then return end
    local box, S, just = pick.box, pick.S, Justify(name)
    local bw, sockX = math.floor(box.r - box.l), 0
    local ox, oy = Px(box.l - r.l), Px(box.r - r.l)   -- (whole-pixel offsets from the slot's corner)
    for i, it in ipairs(items) do
        local rw, f = pick.rows[i], it.row
        local fs, y = f.text, pick.top - rw.off
        f.tip = it.tip
        f:ClearAllPoints(); fs:ClearAllPoints()
        if rw.compact then
            f:SetSize(S, S)
            if just == "LEFT" then f:SetPoint("TOPLEFT", btn, "TOPLEFT", ox + sockX, Px(y - r.t))
            else f:SetPoint("TOPRIGHT", btn, "TOPLEFT", oy - sockX, Px(y - r.t)) end
            sockX = sockX + S + COMPACT_GAP
            fs:SetText(""); fs:SetWidth(1)
            fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        else
            SetSize(fs, pick.size); fs:SetWidth(rw.w); fs:SetText(rw.text)
            f:SetSize(bw, rw.rh)
            f:SetPoint("TOPLEFT", btn, "TOPLEFT", ox, Px(y - r.t))
            local ty = -Px((rw.rh - rw.h) / 2)
            if it.socket then
                if just == "LEFT" then fs:SetPoint("TOPLEFT", f, "TOPLEFT", S + ICON_GAP, ty)
                else fs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(S + ICON_GAP), ty) end
            else
                fs:SetPoint(just == "LEFT" and "TOPLEFT" or "TOPRIGHT", f, just == "LEFT" and "TOPLEFT" or "TOPRIGHT", 0, ty)
            end
        end
        if it.socket then
            f.bg:ClearAllPoints(); f.bg:SetSize(S, S)
            local iy = rw.compact and 0 or -Px((rw.rh - S) / 2)
            f.bg:SetPoint(just == "LEFT" and "TOPLEFT" or "TOPRIGHT", f, just == "LEFT" and "TOPLEFT" or "TOPRIGHT", 0, iy)
            if it.gemID then f.gem:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); f.gem:Show() else f.gem:Hide() end
        end
        local c = it.col
        fs:SetTextColor(c[1], c[2], c[3], 1)
        ShowRow(f, true)
        if rw.compact then fs:Hide() end
    end
    SD(btn).label = pick
end

-- the camera buttons show: the blocks that meet them hide until they go (alpha 0, and those rows let go of the mouse: no hover, no
-- tooltip, the camera buttons get the clicks; G-002)
local function CamShown()
    local m = _G.CharacterModelScene
    local cf = type(m) == "table" and m.ControlFrame or nil
    return (type(cf) == "table" and cf.IsShown and cf:IsShown()) and true or false
end
local function UpdateCamHide()
    local hide = CamShown()
    for _, s in ipairs(CM.SLOTS) do
        local btn = SlotBtn(s[4])
        if type(btn) == "table" then SetBlockAlpha(btn, (hide and SD(btn).label and SD(btn).label.camHit) and 0 or 1) end
    end
end

-- text on the slot buttons that is not XayaUI's (another addon's item level, for example): each visible font string, two levels deep
local function ScanForeign(btn, fn)
    local function scan(f, depth)
        if type(f) ~= "table" or type(f.GetRegions) ~= "function" then return end
        for _, rg in ipairs({ f:GetRegions() }) do
            if type(rg) == "table" and not rg.xuiOwn and rg.GetObjectType and rg:GetObjectType() == "FontString" and rg.IsVisible and rg:IsVisible() then
                local t = CM.PlainText(rg.GetText and rg:GetText() or nil)
                if t and t ~= "" then fn(t, rg) end
            end
        end
        if depth < 2 and type(f.GetChildren) == "function" then for _, ch in ipairs({ f:GetChildren() }) do scan(ch, depth + 1) end end
    end
    scan(btn, 0)
end
-- (QoL 0.7.22) our item level stays hidden on a slot where another addon's text already shows the same number (her pane: a large
-- purple "334" plus ours); the other addon's text is never touched
local function ShowIlvl(btn)
    local fs, t = SD(btn).ilvl, SD(btn).ilvlText
    if not fs then return end
    local dup = false
    if t and t ~= "" then ScanForeign(btn, function(other) if other == t then dup = true end end) end
    SD(btn).ilvlDup = dup
    fs:SetText(t or "")
    fs:SetShown(t ~= nil and t ~= "" and not dup)
end

local tipCache = {}   -- slot -> what its tooltip says (CM.SlotTip) or false; read only while the enchant part is on
-- (V27, U1 G-008) a slot's tooltip read (C_TooltipInfo + ParseTip, CM.SlotTip) kept per slot, keyed by the slot's item link, as
-- CM.SlotInfo keeps its item read: read again only when the link changes, or after an item event or a window open (DropTips: the
-- tooltip can carry text the game had not loaded yet, or a set count that other slots change)
local DropTips, SlotLink, SlotTipCached, WantInfo, NoteWanted, WantsItem, ClearWanted
do
local tipByLink = {}
DropTips = function() for k in pairs(tipByLink) do tipByLink[k] = nil end end
SlotLink = function(slot)
    local link = CM.R(GetInventoryItemLink, "player", slot)
    if type(link) ~= "string" or CM.IsSecret(link) then return nil end
    return link
end
SlotTipCached = function(slot)
    local link = SlotLink(slot)
    if not link then tipByLink[slot] = nil; return nil end
    local k = tipByLink[slot]
    if k and k.link == link then return k.tip or nil end
    local t = CM.SlotTip(slot)
    diag.tipReads = (diag.tipReads or 0) + 1
    tipByLink[slot] = { link = link, tip = t or false }
    return t
end
-- (G-008) the item IDs the slots show (each equipped item and each gem in it): GET_ITEM_INFO_RECEIVED (itemID: number, success: bool;
-- events.md:673) redraws only for one of these (the Stat Calculator's SC-020 rule), not for loot, the Auction House or chat links.
-- Refilled at each full pass over the slots (window open, settings, item events), one table for the file.
local wantItems = {}
ClearWanted = function() for k in pairs(wantItems) do wantItems[k] = nil end end
local function ItemIdOf(link)
    if type(link) ~= "string" or CM.IsSecret(link) then return nil end
    local id = link:match("item:(%d+)")
    return id and tonumber(id) or nil
end
WantInfo = function(info)
    if type(info) ~= "table" then return end
    local id = ItemIdOf(info.link)
    if id then wantItems[id] = true end
    for _, g in ipairs(info.gems or {}) do if num(g.gemID) then wantItems[g.gemID] = true end end
end
NoteWanted = function()
    ClearWanted()
    for _, s in ipairs(CM.SLOTS) do
        local link = SlotLink(s[1])
        if link then
            local id = ItemIdOf(link)
            if id then wantItems[id] = true end
            WantInfo(CM.SlotInfo(s[1]))   -- (kept per link by the model: no new read for a loaded slot)
        end
    end
end
WantsItem = function(id)
    if id == nil or CM.IsSecret(id) or type(id) ~= "number" then return false end
    return wantItems[id] == true
end
end
ns.CharDisplay_WantsItem = WantsItem   -- (tests)
local function EmbCount() local n = 0; for _, t in pairs(tipCache) do if t and t.embellished then n = n + 1 end end; return n end

-- the rows of one slot's block, from the item (each part only while its option is on, in its style Beside the slot): the item level,
-- the enchant, the embellishment, the gems
local function BlockItems(btn, slot, info, tip, c)
    local items = {}
    local just = Justify(SlotName(slot))
    local function row(key)
        local d = SD(btn)
        if not d[key] then d[key] = NewRow(btn, just, false) end
        return d[key]
    end
    local enchBeside = EnchBeside(c)
    if enchBeside then SD(btn).enchant = row("enchantRow").text end
    if not info then return items end
    -- (A24 #7) the Item level, style Beside the slot: the first row, the same number and track color it has on the slot. INFERENCE /
    -- DECISION for Xaya: its place in the block (first) and its hover (the item level and, when the game gives one, its upgrade track).
    local d0 = SD(btn)
    if IlvlBeside(c) and d0.ilvlText then
        local col = d0.ilvlCol or { 1, 1, 1, 1 }
        local lines = { { "Item level " .. d0.ilvlText, col } }
        local tr = d0.track
        if type(tr) == "table" and type(tr.track) == "string" and num(tr.step) and num(tr.max) then
            lines[2] = { ("%s %d/%d"):format(tr.track, tr.step, tr.max), GREY }
        end
        items[#items + 1] = { text = d0.ilvlText, col = col, tip = lines, row = row("ilvlRow") }
    end
    if enchBeside then
        local slotsWanted = CM.EnchantSlots(c)   -- (this page's Enchant Slots)
        local ench = tip and tip.enchant
        local it
        if ench then
            -- the hover: the whole line as the game gives it; a stat kit's line is its effect, any other line is a name only
            local lines = { { tip.enchantLine or ench, GOOD } }
            if not ench:find("%d") then lines[2] = { NO_EFFECT_TEXT, GREY } end
            it = { text = CM.ShortEnchant(ench), col = GOOD, tip = lines }
        elseif info.enchanted == false and slotsWanted[slot] then
            it = { text = NO_ENCHANT_TEXT, col = WARN, tip = { { NO_ENCHANT_TEXT, WARN }, { "This slot takes an enchant (Improved Character Display > Enchant Slots).", GREY } } }
        elseif info.enchanted == true then
            it = { text = "Enchanted", col = GOOD, tip = { { "Enchanted", GOOD }, { NO_EFFECT_TEXT, GREY } } }
        end
        if it then it.row = row("enchantRow"); items[#items + 1] = it end
        local e = tip and tip.embellished
        if e then
            -- (QoL 0.7.24; Xaya 2026-11-05: "put Embellished - Name: ______ and a line break before the description of the embellishment.
            -- Detect if it is (1/2) or (2/2) embellishments on the character"; 2026-11-06: "pane line says embellished (2/2): name — the
            -- rest goes in tooltip"). The pane line "Embellished (n/limit): <name>"; the hover "Embellished - Name: <name>", then on the
            -- next line the description as the game gives it (the item's Use / Equip / proc lines). <name>: the item's own name from its
            -- link (GetInventoryItemLink); no documented call or tooltip line type names the embellishment itself (CM.SlotTip), so the
            -- name shown is the embellished item's (question to Xaya in the debug log of QoL 0.7.24).
            local n = EmbCount()
            local name = CM.LinkName and CM.LinkName(info.link) or nil
            local lines = { { "Embellished - Name: " .. (name or "?"), EMB_COL } }
            for _, l in ipairs(tip.effects or {}) do lines[#lines + 1] = { l, EFFECT_COL } end
            if #lines == 1 then lines[2] = { NO_EFFECT_TEXT, GREY } end
            local r = row("embRow"); SD(btn).emb = r.text
            local head = e.max and ("Embellished (%d/%d)"):format(n, e.max) or "Embellished"
            items[#items + 1] = { text = head .. ": " .. (name or "?"), col = EMB_COL, tip = lines, row = r }
        end
    end
    if c.gems and info.gems then
        -- one socket type in the item's stat table: its name for an empty socket (the key is also the game's string, "Prismatic Socket")
        local typeName, nTypes = nil, 0
        for k in pairs(info.socketTypes or {}) do nTypes = nTypes + 1; typeName = (type(_G[k]) == "string" and not CM.IsSecret(_G[k])) and _G[k] or nil end
        if nTypes ~= 1 then typeName = nil end
        local d = SD(btn)
        d.sockets = d.sockets or {}
        for i, gd in ipairs(info.gems) do
            d.sockets[i] = d.sockets[i] or NewRow(btn, just, true)
            local f, it = d.sockets[i], nil
            if gd.gemID then
                -- the gem's name in one colour; none yet when the game has not loaded it (icon only; GET_ITEM_INFO_RECEIVED redraws)
                it = { text = gd.name or "", col = GEM_COL, gemID = gd.gemID, icon = gd.icon,
                    tip = gd.link and { link = gd.link } or { { gd.name or "Gem (its name is not loaded yet)", GEM_COL } } }
            else
                local t = typeName or "Empty socket"
                it = { text = t, col = WARN, tip = { { t, WARN }, { "Empty socket.", GREY } } }
            end
            it.socket, it.row = true, f
            items[#items + 1] = it
        end
    end
    return items
end

-- where a slot and the model are now (left, top; the model's left), rounded; nil for a value not readable or secret
do
    local function PxRead(f, m)
        if type(f) ~= "table" or type(f[m]) ~= "function" then return nil end
        local v = f[m](f)
        if CM.IsSecret(v) or not num(v) then return nil end
        return Px(v)
    end
    GeoSig = function(btn) return PxRead(btn, "GetLeft"), PxRead(btn, "GetTop"), PxRead(_G.CharacterModelScene, "GetLeft") end
end
-- the slot shows what its last layout was made for (same item link, same place): nothing to redo
local function LaidSame(btn)
    local d = slotData[btn]
    local lay = d and d.lay
    if not lay then return false end
    local slot = btn.GetID and btn:GetID()
    if not num(slot) or lay.link ~= SlotLink(slot) then return false end
    local l, t, ml = GeoSig(btn)
    return l ~= nil and t ~= nil and l == lay.l and t == lay.t and ml == lay.ml
end
local function UpdateSlot(btn, c, tips)
    if type(btn) ~= "table" then return end
    local slot = btn.GetID and btn:GetID()
    local name = num(slot) and SlotName(slot)
    if not name then return end
    -- the item is read only for the parts that are on (V14)
    local info = DetailsOn(c) and CM.SlotInfo(slot) or nil
    -- item level (none on the shirt and the tabard: theirs is 1), colored by its track; drawn on the slot or beside it (A24 #7)
    local d = SD(btn)
    d.ilvlText, d.ilvlCol, d.track = nil, nil, nil
    if c.ilvl and info and info.ilvl and not CM.NO_ILVL[slot] then
        local q = CM.N(GetInventoryItemQuality, "player", slot)
        local col, track = CM.TrackColor(info.link, q)
        d.ilvlText, d.ilvlCol, d.track = tostring(math.floor(info.ilvl + 0.5)), col or { 1, 1, 1, 1 }, track
    end
    if IlvlOnSlot(c) then
        if not d.ilvl and btn.CreateFontString then
            d.ilvl = Mine(btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
            d.ilvl:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
            SetSize(d.ilvl, 12, "OUTLINE")
        end
        if d.ilvl then
            local col = d.ilvlCol
            if col then d.ilvl:SetTextColor(col[1], col[2], col[3], 1) end
            ShowIlvl(btn)
        end
    elseif d.ilvl then d.ilvl:Hide() end
    -- the block beside the slot: item level, enchant, embellishment, gems (LayoutBlock)
    local tip
    if EnchBeside(c) then
        if tips then tip = tips[slot] or nil else tip = info and SlotTipCached(slot) or nil end
        tipCache[slot] = tip or false
    end
    EachRow(btn, HideRow)
    if BlockOn(c) then
        local items = BlockItems(btn, slot, info, tip, c)
        LayoutBlock(btn, name, items)
        SetBlockAlpha(btn, (d.label and d.label.camHit and CamShown()) and 0 or 1)
    else d.label = nil end
    if DetailsOn(c) then
        WantInfo(info)
        -- (G-008) what this layout was made for: the slot's item link (nil: an empty slot) and where the slot and the model are
        -- (whole-pixel reads). The slot hook lays a slot out again only when one of these changed.
        local lay = d.lay or {}
        d.lay = lay
        lay.link = info and info.link or nil
        lay.l, lay.t, lay.ml = GeoSig(btn)
    else d.lay = nil end
end

local retries = 0
local dupPending = false
-- (G-008) which slots to look at again: every slot (a full pass) or only the ones Blizzard redrew (the slot hook)
local dupQ = { all = false, only = setmetatable({}, { __mode = "k" }) }
local function RecheckDup()
    dupPending = false
    local all = dupQ.all
    dupQ.all = false
    local c = Eff()
    if not (Active() and IlvlOnSlot(c)) then for k in pairs(dupQ.only) do dupQ.only[k] = nil end; return end
    local n = 0
    for _, s in ipairs(CM.SLOTS) do
        local b = SlotBtn(s[4])
        local d = type(b) == "table" and slotData[b] or nil
        if d and d.ilvl then
            if all or dupQ.only[b] then ShowIlvl(b) end
            if d.ilvlDup then n = n + 1 end
        end
    end
    for k in pairs(dupQ.only) do dupQ.only[k] = nil end
    diag.dupes = n
end
-- another addon may write its text after ours: look again on the next frame (once per frame at most; only while the item level is on);
-- btn: only that slot (another addon's hook on Blizzard's slot redraw), else every slot
local function RunDupCheck() if Active() then Guard(RecheckDup) else dupPending = false end end
local function QueueDupCheck(c, btn)
    if not (c and IlvlOnSlot(c)) or not (C_Timer and C_Timer.After) then return end
    if btn then dupQ.only[btn] = true else dupQ.all = true end
    if dupPending then return end
    dupPending = true
    C_Timer.After(0, RunDupCheck)
end

-- (QoL 0.7.33; Insivius via Xaya: "Text breaks if you make the window wider and then bring it back down"; her answer "Fix + diagnostic",
-- REQUEST-LOG UI-4.) In the test stand-in a widen (120, 300 px) and back to 42 gives exactly the same blocks, so the layout keeps no state
-- between widths. INFERENCE, not seen in the game: right after the window's width or height changes, the live client may still report
-- the old positions to GetLeft / GetRight in that same moment, so the blocks are sized for the wider window. So whenever the window's size
-- is changed (here or by Blizzard's UpdateSize), the slots are laid out once more on the next frame, and /xui reskin status says whether the positions the
-- two passes read differed (that answer settles the inference). Runs only while the reskin and a slot part are on (V14: nothing while off).
local relayout = { pending = false }
local function GeoKey(g)
    if not g then return nil end
    return { g.colL, g.colR, g.mid, g.model and g.model.l or 0, g.model and g.model.r or 0, g.weap and g.weap.l or 0, g.weap and g.weap.r or 0 }
end
local function MaxDiff(a, b)
    if not (a and b) then return nil end
    local d = 0
    for i = 1, #a do d = math.max(d, math.abs((a[i] or 0) - (b[i] or 0))) end
    return d
end
local UpdateSlots
local function QueueRelayout(c)
    if not relayout.want then return end
    if relayout.pending or not (c and BlockOn(c)) or not (C_Timer and C_Timer.After) then return end
    relayout.want, relayout.pending = false, true
    local before = GeoKey(Geometry())
    C_Timer.After(0, function()
        relayout.pending = false
        if not Active() then return end
        local d = MaxDiff(before, GeoKey(Geometry()))
        if not d then diag.relayout = "the window's size changed; positions not readable in one of the two passes"
        elseif d > 0.5 then diag.relayout = ("the window's size changed; the positions read right after it differed by %.1f px from the next frame's: laid out again"):format(d)
        else diag.relayout = "the window's size changed; the same positions in both passes (laid out again anyway)" end
        local c2 = Eff()
        if c2 and BlockOn(c2) then Guard(UpdateSlots, c2) end
    end)
end
-- the window's width or height was changed by this file or by Blizzard's UpdateSize: the next slot layout queues a second pass
local function SizeChanged() relayout.want = true end

UpdateSlots = function(c)
    local n, labels, cut, cam, socks = 0, 0, 0, 0, 0
    diag.noGeometry = false
    -- every equipped item's tooltip first (the embellishment line counts them), only while the enchants show beside the slots
    local tips = nil
    if EnchBeside(c) then
        tips = {}
        tipCache = {}
        for _, s in ipairs(CM.SLOTS) do
            local t = SlotTipCached(s[1])
            if t then tips[s[1]] = t; tipCache[s[1]] = t end
        end
    end
    ClearWanted()   -- (refilled by each slot below, WantInfo)
    for _, s in ipairs(CM.SLOTS) do
        local btn = SlotBtn(s[4])
        if type(btn) == "table" then
            UpdateSlot(btn, c, tips); n = n + 1
            local L = SD(btn).label
            if L then labels = labels + 1; if L.cut then cut = cut + 1 end; if L.camHit then cam = cam + 1 end end
            if c.gems then for _, f in ipairs(SD(btn).sockets or {}) do if f:IsShown() then socks = socks + 1 end end end
        end
    end
    diag.slots, diag.labels, diag.cut, diag.camHit, diag.sockets = n, labels, cut, cam, socks
    diag.embellished = EnchBeside(c) and EmbCount() or 0
    QueueDupCheck(c)
    -- the window is open but its slots had no position yet (INFERENCE: possible in the frame it opens): try again next frame, 3 times at most
    local cf = _G.CharacterFrame
    if diag.noGeometry and retries < 3 and C_Timer and C_Timer.After and type(cf) == "table" and cf.IsShown and cf:IsShown() then
        retries = retries + 1
        C_Timer.After(0, function() local c2 = Eff(); if Active() and BlockOn(c2) then Guard(UpdateSlots, c2) end end)
    elseif not diag.noGeometry then retries = 0 end
    QueueRelayout(c)
end

-- for /xui reskin status
local function OtherText()
    local found = {}
    for _, s in ipairs(CM.SLOTS) do
        ScanForeign(SlotBtn(s[4]), function(t, rg) found[#found + 1] = ("%s %s (%s)"):format(s[3], t, tostring(rg.GetDebugName and rg:GetDebugName() or "?")) end)
    end
    return found
end

-------------------------------------------------------------------------------
-- The full stat list (QoL 0.7.31; Xaya 2026-11-06, her words: "missing details about about all possible stats / the ability to customize
-- how to display stats in the primary character window"; her answers: stats "2 but customizable and prettified with colors" (option 2:
-- exactly the lines of the Stat Calculator's Character Stats, Core Stats / Secondaries / Tertiaries); customise "Show / hide each stat,
-- Order, % / rating / both, Groups and colours"; default "Everything on"; REQUEST-LOG #70, #71, #74).
-------------------------------------------------------------------------------
-- Our own frames over Blizzard's stats pane (a scroll frame, child of CharacterStatsPane, so it shows and hides with the pane; an opaque
-- fill in the theme's pane colour under it, so Blizzard's rows neither show nor take the mouse). Blizzard's frames are not changed. The
-- numbers are the stat model's (CM.Build "stats", with the Stat Calculator's typed numbers left out, as the character
-- window's own stat tooltips read them): no new game call. Every group heading (Core Stats, Primary, General, Offensive, Defensive,
-- Secondaries, Tertiaries) and every stat line of Character Stats, in her order and colours: a stat's name in its stat colour (the
-- Stat Calculator's), headings in the label colour, unless she picked others. A rating stat shows its percent, its rating, or both
-- ("528 / 22.48%", the Stat Weights' "Rating (P / %)" form). Hover a line: the Stat Calculator's hover for it. Built only while the
-- reskin and this part are on (V14); redrawn after Blizzard's PaperDollFrame_UpdateStats (the hook the stat list already has), at
-- most once per frame, and only when a number it shows changed (U1 G-007); in combat it keeps its numbers and is drawn once when combat
-- ends (PLAYER_REGEN_ENABLED; DECISION to confirm with Xaya). Opening the window draws it, in or out of combat. Plain frames only (nothing
-- protected), hover only (G-005); values the game hides show "hidden in combat".
local LIST_CLEAN = { whatIf = 0, whatIfStats = {}, whatIfPrimary = false, detail = "all", collapsed = {} }
local LIST_ROW, LIST_HEAD, LIST_SIZE, LIST_PAD = 14, 17, 11, 4
local RATING_STAT = { map_crit = true, map_haste = true, map_mastery = true, map_vers = true, map_avoidance = true, map_leech = true, map_speed2 = true }
-- the groups and their stat lines as Character Stats has them now: { { key, label, level, stats = { item, ... } } }, and the items by key
-- buf (the stat list's own, UpdateStatList): its tables are emptied and refilled instead of new ones made per update (V25(2)); without
-- it (the settings page, which keeps what it gets) new tables are returned
function ns.CharDisplay_ListModel(buf)
    local groups, items, pool, ng = nil, nil, nil, 0
    if buf then
        groups, items, pool = buf.groups, buf.items, buf.pool
        for i = #groups, 1, -1 do groups[i] = nil end
        for k in pairs(items) do items[k] = nil end
    else
        groups, items = {}, {}
    end
    if not (CM and CM.Build) then return groups, items end
    local ok, m = pcall(CM.Build, LIST_CLEAN, "stats")
    if not ok or type(m) ~= "table" then return groups, items end
    local cur = nil
    for _, sec in ipairs(m.sections or {}) do
        if sec.key == "map_character" then
            for _, it in ipairs(sec.items) do
                if it.kind == "subhead" then
                    ng = ng + 1
                    if pool then
                        cur = pool[ng] or { stats = {} }
                        pool[ng] = cur
                        for i = #cur.stats, 1, -1 do cur.stats[i] = nil end
                        cur.key, cur.label, cur.level = it.key, it.label, it.level
                    else
                        cur = { key = it.key, label = it.label, level = it.level, stats = {} }
                    end
                    groups[#groups + 1] = cur
                elseif cur and (it.kind == "input" or it.kind == "stat" or it.kind == "rating") then
                    cur.stats[#cur.stats + 1] = it
                    items[it.key] = it
                end
            end
        end
    end
    return groups, items
end
-- a group's stat keys in her order: the saved order (keys the list still has), then any new ones in Character Stats' order
function ns.CharDisplay_ListOrder(c, g)
    local out, seen, have = {}, {}, {}
    for _, it in ipairs(g.stats) do have[it.key] = true end
    for _, k in ipairs((c and c.statOrder and c.statOrder[g.key]) or {}) do if have[k] and not seen[k] then out[#out + 1] = k; seen[k] = true end end
    for _, it in ipairs(g.stats) do if not seen[it.key] then out[#out + 1] = it.key; seen[it.key] = true end end
    return out
end
function ns.CharDisplay_HasRating(key) return RATING_STAT[key] == true end
-- the value a line shows in its mode
function ns.CharDisplay_ListValue(c, it)
    local v = tostring(it.value or "")
    if RATING_STAT[it.key] and num(it.absolute) and not it.hidden and v ~= "" then
        local mode = (c and c.statMode and c.statMode[it.key]) or "percent"
        if mode == "rating" then return CM.Big(it.absolute) end
        if mode == "both" then return CM.Big(it.absolute) .. " / " .. v end
    end
    return v
end
local function ListColor(t, fb) if type(t) == "table" and num(t[1]) and num(t[2]) and num(t[3]) then return { t[1], t[2], t[3], 1 } end; return fb end
local listPending = false
local UpdateStatList
do
-- (V27, U1 G-007) a stat line's font string, placed and filled (one function for the file, no closure per update); returns its
-- whole-pixel height
local function ListFS(L, x, y, width, s, col, justify, size)
    L.nFs = L.nFs + 1
    local f = L.fs[L.nFs]
    if not f then f = L.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); L.fs[L.nFs] = f end
    SetSize(f, size or LIST_SIZE, "")
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", L.content, "TOPLEFT", x, -y); f:SetWidth(width)
    if f.SetJustifyH then f:SetJustifyH(justify or "LEFT") end
    if f.SetWordWrap then f:SetWordWrap(true) end
    f:SetText(s or ""); f:SetTextColor(col[1], col[2], col[3], col[4] or 1); f:Show()
    local h = f.GetStringHeight and f:GetStringHeight() or LIST_SIZE
    if CM.IsSecret(h) or not (num(h) and h > 0) then h = LIST_SIZE end
    return Px(h), f
end
local function RowBtnEnter(self)
    if not (GameTooltip and self.item) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.name or "", 1, 1, 1)
    local lines = CM.TooltipLines(self.item)   -- (QoL 0.7.53: the model's, StatModel.lua)
    for i, l in ipairs(lines) do
        if i > 1 then
            if l[2] ~= nil and GameTooltip.AddDoubleLine then GameTooltip:AddDoubleLine(l[1], l[2], 0.75, 0.75, 0.8, 0.95, 0.95, 0.95)
            else GameTooltip:AddLine(l[1], 0.85, 0.85, 0.85, true) end
        end
    end
    GameTooltip:Show()
end
local function RowBtnLeave() if GameTooltip then GameTooltip:Hide() end end
local function ListWheel(self, d)
    local cur = (self.GetVerticalScroll and self:GetVerticalScroll()) or 0
    local maxS = math.max(0, (self.contentH or 0) - ((self.GetHeight and self:GetHeight()) or 0))
    if self.SetVerticalScroll then self:SetVerticalScroll(math.max(0, math.min(maxS, cur - d * LIST_ROW * 2))) end
end
local function RowBtnWheel(self, d) local L = own.statList; if L then ListWheel(L, d) end end
-- (G-007, round 2) what the list shows, compared field by field against the last layout's values kept in one reused array: the width,
-- then each group's key and label and each stat line's key, label, value, rating, hidden state and tone. No string or table is made
-- per update (V25(2)). All the same as the last layout: nothing it shows changed, so it is not laid out again. A secret value (the
-- game's restricted numbers) is never compared: it counts as changed (fail safe: the list is laid out).
local lastVals, lastN = {}, 0
local function Put(n, v)
    if CM.IsSecret(v) then lastVals[n] = false; return true end
    if lastVals[n] ~= v then lastVals[n] = v; return true end
    return false
end
local function ListChanged(groups, w)
    local n, ch = 1, Put(1, w)
    for _, g in ipairs(groups) do
        n = n + 1; if Put(n, g.key) then ch = true end
        n = n + 1; if Put(n, g.label) then ch = true end
        for _, it in ipairs(g.stats) do
            n = n + 1; if Put(n, it.key) then ch = true end
            n = n + 1; if Put(n, it.label) then ch = true end
            n = n + 1; if Put(n, it.value) then ch = true end
            n = n + 1; if Put(n, num(it.absolute) and it.absolute or false) then ch = true end
            n = n + 1; if Put(n, it.hidden == true) then ch = true end
            n = n + 1; if Put(n, it.tone) then ch = true end
        end
    end
    if n ~= lastN then
        ch = true
        for i = n + 1, lastN do lastVals[i] = nil end
        lastN = n
    end
    return ch
end
-- the list's model tables, reused from update to update (the settings page builds its own: it keeps them)
local listBuf = { groups = {}, items = {}, pool = {} }
diag.listBuilds, diag.listLayouts = 0, 0
-- force: lay the list out even when its numbers did not change (a settings, theme or window change: ApplyNow)
UpdateStatList = function(c, force)
    local pane = _G.CharacterStatsPane
    if type(pane) ~= "table" or not pane.CreateTexture then return end
    local L = own.statList
    if not L then
        L = Own(CreateFrame("ScrollFrame", nil, pane))
        L:SetAllPoints(pane)
        if L.SetFrameLevel and pane.GetFrameLevel then L:SetFrameLevel((pane:GetFrameLevel() or 1) + 10) end
        HoverOnly(L, true)   -- (G-005) hover and the wheel only: a click passes through
        if L.EnableMouseWheel then L:EnableMouseWheel(true) end
        L.fill = L:CreateTexture(nil, "BACKGROUND"); L.fill:SetAllPoints(L)
        L.content = CreateFrame("Frame", nil, L)
        L.content:SetSize(1, 1)
        if L.SetScrollChild then L:SetScrollChild(L.content) end
        L:SetScript("OnMouseWheel", ListWheel)
        L.fs, L.btns, L.rules, L.recs, L.keys, L.nFs = {}, {}, {}, {}, {}, 0
        own.statList = L
    end
    local w = (L.GetWidth and L:GetWidth()) or 0
    if CM.IsSecret(w) or not num(w) or w <= 0 then w = (pane.GetWidth and pane:GetWidth()) or 190 end
    if CM.IsSecret(w) or not num(w) or w <= 0 then w = 190 end
    w = Px(w)
    -- the rating -> percent reads (the Stat Calculator's model): INFERENCE pending Xaya's confirmation that this math is allowed under
    -- V27 when it runs once per actual change (here: once per Blizzard stat update while the window is open, out of combat)
    local groups, items = ns.CharDisplay_ListModel(listBuf)
    diag.listBuilds = diag.listBuilds + 1
    local changed = ListChanged(groups, w)
    if not force and not changed and L:IsShown() then return end
    diag.listLayouts = diag.listLayouts + 1
    local pbg = TC("xui-pane", "bg", { 0.04, 0.04, 0.04, 1 })
    L.fill:SetColorTexture(pbg[1], pbg[2], pbg[3], 1)
    L.content:SetWidth(w)
    local label = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    local text = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local mute = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local line = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
    local nBtn, nRule = 0, 0
    L.nFs = 0
    local recs = L.recs
    for i = #recs, 1, -1 do recs[i] = nil end
    -- each group's shown keys in her order, once (reused tables); Core Stats shows when one of its level-2 groups has a line
    local keysBy, anyL2 = L.keys, false
    for gi, g in ipairs(groups) do
        local keys = keysBy[gi] or {}
        keysBy[gi] = keys
        for i = #keys, 1, -1 do keys[i] = nil end
        for _, k in ipairs(ns.CharDisplay_ListOrder(c, g)) do if not c.statHide[k] then keys[#keys + 1] = k end end
        if g.level == 2 and #keys > 0 then anyL2 = true end
    end
    local lw = math.floor((w - 2 * LIST_PAD - 10) * 0.58)
    local y = LIST_PAD
    for gi, g in ipairs(groups) do
        local keys = keysBy[gi]
        -- a heading shows when it has a line to show under it (Core Stats: when one of its four groups has one)
        local show = #keys > 0
        if g.key == "sub_core" then show = anyL2 end
        if show then
            local name = (c.groupName[g.key] and c.groupName[g.key] ~= "") and c.groupName[g.key] or g.label
            local col = ListColor(c.groupColor[g.key], label)
            local x = (g.level == 2) and 6 or LIST_PAD
            local h, f = ListFS(L, x, y + 2, w - x - LIST_PAD, name, col, "LEFT", g.level == 2 and LIST_SIZE or LIST_SIZE + 1)
            nRule = nRule + 1
            local r = L.rules[nRule]
            if not r then r = L.content:CreateTexture(nil, "ARTWORK"); L.rules[nRule] = r end
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", L.content, "TOPLEFT", x, -(y + 2 + h + 1)); r:SetSize(math.max(1, w - x - LIST_PAD), 1)
            r:SetColorTexture(line[1], line[2], line[3], 0.8); r:Show()
            recs[#recs + 1] = { kind = "group", key = g.key, text = name, color = col, x = x, y = y, fs = f }
            y = y + math.max(LIST_HEAD, h + 5)
            for _, k in ipairs(keys) do
                local it = items[k]
                local sname = (c.statName[k] and c.statName[k] ~= "") and c.statName[k] or it.label
                local scol = ListColor(c.statColor[k], it.labelColor or text)
                local lx = 10
                local lh, lf = ListFS(L, lx, y, lw, sname, scol, "LEFT")
                local val = ns.CharDisplay_ListValue(c, it)
                local vh, vf = ListFS(L, lx + lw + 4, y, w - (lx + lw + 4) - LIST_PAD, val, (it.hidden or it.tone == "mute") and mute or text, "RIGHT")
                local rowH = math.max(LIST_ROW, lh + 2, vh + 2)
                nBtn = nBtn + 1
                local b = L.btns[nBtn]
                if not b then
                    b = CreateFrame("Button", nil, L.content)
                    HoverOnly(b, true)   -- (G-005) hover tooltip and highlight only: a click passes through
                    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.06)
                    b:SetScript("OnEnter", RowBtnEnter)
                    b:SetScript("OnLeave", RowBtnLeave)
                    b:SetScript("OnMouseWheel", RowBtnWheel)
                    L.btns[nBtn] = b
                end
                b.item, b.name = it, sname
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", L.content, "TOPLEFT", 0, -y); b:SetSize(w, rowH); b:Show()
                recs[#recs + 1] = { kind = "stat", key = k, text = sname, value = val, color = scol, x = lx, y = y, w = lw, h = rowH, fs = lf, vfs = vf }
                y = y + rowH
            end
            y = y + 3
        end
    end
    for i = L.nFs + 1, #L.fs do L.fs[i]:Hide() end
    for i = nBtn + 1, #L.btns do L.btns[i]:Hide(); L.btns[i].item = nil end
    for i = nRule + 1, #L.rules do L.rules[i]:Hide() end
    L.content:SetHeight(math.max(1, y))
    L.contentH = y
    L:Show()
    diag.statList = ("%d lines shown"):format(#recs)
end
end
local function HideStatList() if own.statList then own.statList:Hide() end end
-- (G-007) Blizzard's stat update asks for a redraw: at most once per frame, and not in combat (the list is marked stale and drawn once
-- when combat ends, PLAYER_REGEN_ENABLED). DECISION to confirm with Xaya: in combat the list keeps its last numbers until combat ends
-- (the alternative is a redraw at most every N seconds, compared against a stored time).
local listStale = false
local function RunStatList()
    listPending = false
    local c = Eff()
    if c and c.statList and WindowShown() then Guard(UpdateStatList, c, false) end
end
local function QueueStatList()
    if InCombat() then listStale = true; if NeedRegen then NeedRegen() end; return end
    if listPending then return end
    listPending = true
    if C_Timer and C_Timer.After then C_Timer.After(0, RunStatList) else RunStatList() end
end
function ns.CharDisplay_StatListRecs() return own.statList and own.statList:IsShown() and own.statList.recs or nil end   -- (tests)

-------------------------------------------------------------------------------
-- The Stat Calc button (moved here from the Stat Calculator's file, XayaUI Bonus Features, in V25 R2; QoL 0.7.23; Xaya 2026-11-05, her words: "stat
-- calculator should have a toggle open/close button on the character menu and remember the last-left state on next open"). It is ours
-- (made the first time it is wanted), a child of the character window; it shows while this is on, its own switch is on and the Stat
-- Calculator says its panel is available (XayaUI Bonus Features loaded, the Stat Calculator and its panel on). A click asks the Stat
-- Calculator to open or close (its "statCalc" service); the Stat Calculator tells this file when its panel opens or closes
-- (OnState), so the button is never polled.
-- Placement (DECISION, unchanged from QoL 0.7.23): the character window's title row, a gutter left of Blizzard's close button, 64 x 18.
-- INFERENCE (Blizzard's ButtonFrameTemplate, not re-read for this change): the close button is the window's CloseButton key (global
-- CharacterFrameCloseButton) in its top-right corner, the title text is centered, and nothing else of Blizzard's sits in that row. The
-- reskin's wider window moves the right edge, and the close button and this button with it. Without a close button, the same place
-- from the window's top-right corner.
-------------------------------------------------------------------------------
local charBtn
local function CharButton()
    if charBtn then return charBtn end
    local cf = _G.CharacterFrame
    if not (cf and CreateFrame) then return nil end
    local b = CreateFrame("Button", "XayaUIStatCalcButton", cf)
    b:SetSize(64, 18)
    local close = (type(cf.CloseButton) == "table" and cf.CloseButton) or _G.CharacterFrameCloseButton
    if close then b:SetPoint("RIGHT", close, "LEFT", -4, 0) else b:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -28, -3) end
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.text:SetPoint("CENTER")
    b.text:SetText("Stat Calc")
    if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp") end
    b:SetScript("OnClick", function() if statCalc and statCalc.Toggle then pcall(statCalc.Toggle) end end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Stat Calculator", 1, 0.82, 0)
        GameTooltip:AddLine("Opens or closes the Stat Calculator beside this window; it opens the same way next time. It also opens on its own from the XayaUI minimap button or /xui stats.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    charBtn = b
    return b
end
-- the button's look follows the panel: the theme's selected-tab colors while the panel is open
UpdateButton = function()
    local c = Cfg()
    if not (c and On() and c.statCalcButton ~= false and statCalc and scAvail) then if charBtn then charBtn:Hide() end; return end
    local b = CharButton(); if not b then return end
    local cls = scOpen and "xui-tab-selected" or "xui-button"
    local bg = TCG(cls, "bg", scOpen and { 0.22, 0.1, 0.3, 0.9 } or { 0.04, 0.04, 0.04, 0.7 })
    b.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
    local tc = TCG(cls, "text", scOpen and { 1, 1, 1, 1 } or { 1, 0.82, 0, 1 })
    b.text:SetTextColor(tc[1], tc[2], tc[3], tc[4] or 1)
    b.open = scOpen
    b:Show()
end
ns.CharDisplay_Button = function() return charBtn end   -- (tests)
-- the Stat Calculator's panel opened or closed, or its panel was switched on or off
OnStatCalcState = function(open, available)
    scOpen, scAvail = open == true, available == true
    if charBtn or On() then UpdateButton() end
end

-------------------------------------------------------------------------------
-- On / off
-------------------------------------------------------------------------------
Guard = function(fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then return true end
    local first = not diag.failed
    diag.failed, diag.lastError = true, tostring(err)
    SetOwnShown(false)
    pcall(UpdateOverlays)   -- the empty-socket mark shows its count again (the gems beside the slots no longer draw)
    if first and ns.Print then ns.Print("Improved Character Display hit an error and is off until /reload: " .. tostring(err)) end   -- (said once)
    return false
end

-- the events: the spec / level (the model's cache), and the item events only while the slot marks or an item detail part is on AND the
-- character window is open (V27 / V28, U1 G-011: registered in the window's OnShow, let go in its OnHide); off, the frame listens to
-- nothing (V14). Item data that arrives later (an item level, a gem's name or a tooltip line the game had not sent yet) redraws the
-- slots once per frame at most, only for an item the slots show (G-008). PLAYER_REGEN_ENABLED only while something waits for the end
-- of combat (a row's mouse setting, the stat list marked stale).
local SLOT_EVENTS = { "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "SOCKET_INFO_UPDATE", "ENCHANT_SPELL_COMPLETED" }
local ev, slotPending
local pageGroups   -- (G-015) the settings page's stat list groups, kept until the spec or level changes (below, at the page)
local regenWanted = false
-- (G-008) one queue for the slots, run once per frame: every slot (an item event, the window's size) or only the slots Blizzard redrew
-- whose item link or place changed since their last layout (the slot hook)
local ClearSlotQ, QueueAllSlots, QueueSlot
do
local slotQ, slotAll = {}, false
ClearSlotQ = function() for k in pairs(slotQ) do slotQ[k] = nil end end
local function RunSlots()
    slotPending = false
    local all = slotAll
    slotAll = false
    local c = Eff()
    if not (c and DetailsOn(c) and WindowShown()) then ClearSlotQ(); return end
    if all then ClearSlotQ(); Guard(UpdateSlots, c); return end
    for btn in pairs(slotQ) do   -- (the slot hook also queued each one's duplicate check)
        slotQ[btn] = nil
        if not Guard(UpdateSlot, btn, c) then ClearSlotQ(); return end
    end
end
local function ArmSlots()
    if slotPending then return end
    slotPending = true
    if C_Timer and C_Timer.After then C_Timer.After(0, RunSlots) else RunSlots() end
end
QueueAllSlots = function() slotAll = true; ArmSlots() end
QueueSlot = function(btn)
    if slotAll or LaidSame(btn) then return end
    slotQ[btn] = true
    ArmSlots()
end
end
local SetEvents
local function OnRegen()
    regenWanted = false
    FlushMouse()
    local stale = listStale
    listStale = false
    SetEvents(CfgFast())
    if stale and WindowShown() then QueueStatList() end
end
local function OnEvent(_, event, arg1)
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LEVEL_UP" then CM.ClearCache(); pageGroups = nil; return end
    if event == "PLAYER_REGEN_ENABLED" then OnRegen(); return end
    if not WindowShown() or not On() then return end
    if event == "GET_ITEM_INFO_RECEIVED" and not WantsItem(arg1) then return end   -- (G-008) not an item the slots show
    DropTips()
    local c = CfgFast()
    local details = Active() and DetailsOn(c)
    if event ~= "GET_ITEM_INFO_RECEIVED" and not details then NoteWanted() end   -- (the slots changed; the full pass below refills it)
    if MarksOn(c) then RefreshOverlays() end
    if details then QueueAllSlots() end
end
-- open: whether the window is open (nil: read it); the item events only while it is
SetEvents = function(c, open)
    if not ev then return end
    ev:UnregisterAllEvents()
    if regenWanted then pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED") end
    if not (c and On()) then return end
    pcall(ev.RegisterEvent, ev, "PLAYER_SPECIALIZATION_CHANGED")
    pcall(ev.RegisterEvent, ev, "PLAYER_LEVEL_UP")
    if open == nil then open = WindowShown() end
    if open and (MarksOn(c) or DetailsOn(c)) then for _, e in ipairs(SLOT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end end
end
NeedRegen = function()
    if regenWanted then return end
    regenWanted = true
    if ev then pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED") end
end

-- a theme change repaints; the listener is there only while this is on (V14)
local function OnTheme() if On() then Guard(function() ns.CharDisplay_Apply() end) end end
local function SetThemeListener(on)
    local T = ns.Theme
    if not (T and T.OnResolve) then return end
    if on and not own.themeOn then T.OnResolve(OnTheme); own.themeOn = true
    elseif not on and own.themeOn and T.OffResolve then T.OffResolve(OnTheme); own.themeOn = false end
end

local function ApplyNow()
    local c = Cfg()
    if not c then return end
    cfgEpoch = nil
    if not On() then
        pageGroups = nil   -- (switched on again later: the page's stat list is read afresh)
        SetOwnShown(false); diag.applied = false; SetEvents(nil); SetThemeListener(false)
        for _, o in pairs(overlays) do o:Hide() end
        UpdateButton()
        return
    end
    -- a part switched off gives its pieces back: hide every piece, then draw the parts that are on
    SetOwnShown(false)
    DropTips()   -- (a window open or a settings change: every slot's tooltip is read once more)
    -- (round 2: deferring this to the window's OnShow while it is closed was tried and left out: tests/char_reskin_run.py and
    -- tests/char_reskin_noreskin_run.py, outside this unit, expect the slots drawn at an Apply with the window closed; open question)
    local details = Active() and DetailsOn(c)
    if Active() then
        UpdateSlots(c)
        if c.statList then UpdateStatList(c, true); listStale = false end   -- (QoL 0.7.31) our full stat list over Blizzard's pane
    end
    UpdateOverlays()
    if MarksOn(c) and not details then NoteWanted() end
    SetEvents(c)
    SetThemeListener(true)
    diag.applied = true
    UpdateButton()
end

-- (the seam) the Character Reskin's window size: "size" = it is changing (the next slot layout queues a second pass), "applied" = its
-- look is laid out (the wider window and the extra height are in place or put back): the slot blocks are laid out again
local function OnWindowSize(what)
    if what == "size" then SizeChanged(); return end
    local c = Eff()
    if c and DetailsOn(c) then Guard(UpdateSlots, c) end
end
local listening = false
local function Listen()
    if listening then return end
    listening = true
    if ns.CharReskin_OnWindowSize then ns.CharReskin_OnWindowSize(OnWindowSize) end
    -- (the Stat Calculator's callback was given at the first read of its service made while this is on, ReadTieIns)
end

-- the hooks: each is placed the first time a part that needs it is on, and returns at its first line while the character window is
-- closed (WindowShown first, the cheapest test: G-016), then while this (or that part) is off (a /reload removes them; V14 limit 2)
local hooked, ownerHooked, slotHooked, camHooked, statsHooked = false, false, false, false, false
local function OnCam() if not WindowShown() then return end; local c2 = Eff(); if c2 and BlockOn(c2) then Guard(UpdateCamHide) end end
local function Hook(c)
    if not hooked then
        hooked = true
        local cf = _G.CharacterFrame
        if type(cf) == "table" and cf.HookScript then
            cf:HookScript("OnShow", function() if On() then Guard(ApplyNow) end end)
            -- (G-011) the window closed: the item events are let go (the spec / level ones stay while this is on)
            cf:HookScript("OnHide", function() if ev then SetEvents(CfgFast(), false); ClearSlotQ() end end)
        end
        ev = CreateFrame("Frame")
        ev:SetScript("OnEvent", OnEvent)
        if regenWanted then pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED") end
    end
    -- the slot marks follow the Character tab (the window's own OnShow above covers the rest)
    if MarksOn(c) and not ownerHooked then
        local owner = Owner()
        if owner and owner.HookScript then
            ownerHooked = true
            owner:HookScript("OnShow", function() if not (WindowShown() and On()) then return end; local c2 = CfgFast(); if MarksOn(c2) then UpdateOverlays() end end)
        end
    end
    -- Blizzard redraws one slot button at a time; the marks and the item details follow (post-hook, Blizzard's code runs unchanged
    -- first). (G-008) the item details: queued into the once-per-frame slot pass, and only for a slot whose item link or place changed
    -- since its last layout
    if (MarksOn(c) or DetailsOn(c)) and not slotHooked and type(hooksecurefunc) == "function"
        and type(_G.PaperDollItemSlotButton_Update) == "function" then
        slotHooked = true
        hooksecurefunc("PaperDollItemSlotButton_Update", function(btn)
            if not (WindowShown() and On()) then return end
            local c2 = CfgFast()
            if MarksOn(c2) then UpdateOverlay(btn) end
            if Active() and DetailsOn(c2) and type(btn) == "table" then
                QueueSlot(btn)
                QueueDupCheck(c2, btn)   -- (another addon's text on this slot may have changed with it: this slot only)
            end
        end)
    end
    -- the model's camera buttons: the blocks that meet them hide while they show
    if BlockOn(c) and not camHooked then
        local m = _G.CharacterModelScene
        local camf = type(m) == "table" and m.ControlFrame or nil
        if type(camf) == "table" and camf.HookScript then
            camHooked = true
            camf:HookScript("OnShow", OnCam)
            camf:HookScript("OnHide", OnCam)
        end
    end
    -- the full stat list is redrawn after Blizzard's own stat update, at most once per frame, only when a number it shows changed, and
    -- not in combat (G-007: once when combat ends)
    if c.statList and not statsHooked and type(hooksecurefunc) == "function" and type(_G.PaperDollFrame_UpdateStats) == "function" then
        statsHooked = true
        hooksecurefunc("PaperDollFrame_UpdateStats", function()
            if not WindowShown() then return end
            local c2 = Eff()
            if c2 and c2.statList then QueueStatList() end
        end)
    end
end

-- (V25 R4) tells Enhanced Tooltips' stat lines (the one listener, set through the service) when this is switched on or off
local onListener, toldOn = nil, nil
local wasOn = false   -- (round 2) whether this was on at the last Apply: the tie-ins are read only when it switches on
local function TellOn()
    if not onListener then return end
    local now = On()
    if now == toldOn then return end
    toldOn = now
    pcall(onListener, now)
end
function ns.CharDisplay_Apply()
    local c = Cfg()
    if not c then return end
    cfgEpoch = nil
    -- (G-017) the Stat Calculator is read and subscribed to the first time this is on (read again then if only the page read it).
    -- (round 2) read only when this is switched on (off -> on, the login included), never on a settings or theme change while it stays
    -- on: with the Stat Calculator missing (XayaUI Bonus Features off) or without OnState nothing is read again until the next switch-on
    local on = On()
    if on and not wasOn then ReadTieIns(not subscribed, true) end
    wasOn = on
    if on then Listen(); Hook(c) end
    if hooked then Guard(ApplyNow) else UpdateButton() end
    TellOn()
end

-- at the login (every addon's settings are open then: the one-time merge can read what each part showed before), and only while on
ns.WhenSettingsReady("qol", function()
    if ns.AtLogin then
        ns.AtLogin(function() if Cfg() then Merge(); MigrateSlotOptions(); if On() then ns.CharDisplay_Apply() end end end)
    end
end)

-- (Dev Assist, read only) what is drawn on the character window now, counted from our own pieces; and the debug answers the audit
-- walkthrough reads (which events are registered)
ns.Provide("charDisplay", {
    -- (V25 R4) for XayaUI Bonus Features' Enhanced Tooltips (the character window's stat lines; Tooltips.lua section 5): whether this
    -- is on, read by it once at the login and once at its page's first build; OnChange(fn): the one callback it gives, called with the
    -- new value when this is switched on or off (from ns.CharDisplay_Apply), so nothing polls
    On = function() return On() end,
    OnChange = function(fn)
        if type(fn) ~= "function" then return end
        onListener = fn
        toldOn = On()
    end,
    Drawn = function()
        local il, en, so = 0, 0, 0
        for _, s in ipairs(CM.SLOTS) do
            local b = _G["Character" .. s[4]]
            local d = type(b) == "table" and slotData[b] or nil   -- (read only: nothing is made for a slot nothing was drawn on)
            if d then
                if d.ilvl and d.ilvl.IsShown and d.ilvl:IsShown() then il = il + 1 end
                if d.ilvlRow and d.ilvlRow.IsShown and d.ilvlRow:IsShown() then il = il + 1 end   -- (A24 #7: Item level beside the slot)
                if d.enchant and d.enchant.IsShown and d.enchant:IsShown() then en = en + 1 end
                for _, f in ipairs(d.sockets or {}) do if f.IsShown and f:IsShown() then so = so + 1 end end
            end
        end
        local marks = 0   -- (V25) slots with a mark shown on them (E? / E, 2S), for the Improved Character Display walkthroughs
        for _, o in pairs(overlays) do if o.IsShown and o:IsShown() then marks = marks + 1 end end
        local L = own.statList
        return { ilvl = il, enchants = en, sockets = so, marks = marks, statList = (L ~= nil and L:IsShown()) and true or false,
            features = Active() == true, featuresSaved = paneT and paneT.features, button = (charBtn ~= nil and charBtn:IsShown()) and true or false }
    end,
})
ns.Provide("charDisplayDebug", { Cfg = function() return Cfg() end, Apply = function() return ns.CharDisplay_Apply() end,
    -- (A24 #7, read only, for the walkthrough "slot-options") where each option draws now, and the marks on one slot
    Draws = function() return ns.CharDisplay_Draws() end, SlotMarks = function(slotName) return ns.CharDisplay_SlotMarks(slotName) end,
    Registered = function(e) return (ev and ev.IsEventRegistered and ev:IsEventRegistered(e)) and true or false end,
    -- (U1, read only, for the walkthrough) the rows beside the slots and the stat list: how many take clicks (should be 0), how many
    -- take hover, how many are faded out under the camera buttons and still take hover (should be 0); the stat list's builds / layouts
    Mouse = function()
        local rows, clicks, hover, faded, fadedHover = 0, 0, 0, 0, 0
        local function look(f)
            if not (f.IsShown and f:IsShown()) then return end
            rows = rows + 1
            local ck = f.IsMouseClickEnabled and f:IsMouseClickEnabled()
            local mv = f.IsMouseMotionEnabled and f:IsMouseMotionEnabled()
            if ck then clicks = clicks + 1 end
            if mv then hover = hover + 1 end
            if f.xuiFaded then faded = faded + 1; if mv then fadedHover = fadedHover + 1 end end
        end
        for _, s in ipairs(CM.SLOTS) do local b = _G["Character" .. s[4]]; if type(b) == "table" then EachRow(b, look) end end
        local L = own.statList
        if L then look(L); for _, b in ipairs(L.btns) do look(b) end end
        return { rows = rows, clicks = clicks, hover = hover, faded = faded, fadedHover = fadedHover, queued = ns.CharDisplay_MouseQueued() }
    end,
    ListCounts = function() return { builds = diag.listBuilds or 0, layouts = diag.listLayouts or 0, stale = listStale == true } end })

-------------------------------------------------------------------------------
-- Settings page: QoL > Improved Character Display (V25 R2; her A24 #5: one page). It joins QoL > Character Pane (the item level,
-- enchants, gems, the full stat list and its Stat list page), the QoL page of the slot marks and the Stat Calc button's own switch. (Its
-- part Tooltip lines moved to Bonus Features > Enhanced Tooltips > Character stats in V25 R4.) Its on / off is the tick box on its row.
-- (A24 #7) the Slot Overlays part (its own switch, the Item level / Empty sockets / Enchant check marks greyed while the item details
-- drew the same thing) and the item details' "Item level on each slot" / "Enchants beside the slots" are replaced by one "Item level"
-- option and one "Enchants" option, each with a Style: "On the slot" / "Beside the slot" (her words). The Empty sockets mark, the
-- marks' Text size and the Enchant Slots tab stay (the Enchant Slots as a page of its own). UNVERIFIED IN GAME.
-------------------------------------------------------------------------------
function ns.BuildCharDisplayPage(Notify)
    -- (the tie-in rule) the first time this page is built after a reload, the Stat Calculator's service is read once more (read only:
    -- nothing is subscribed while this is off; G-017)
    if not pageRead then pageRead = true; ReadTieIns(true, false) end
    local function C() return Cfg() or CopyVal(ns.CHARDISPLAY_DEFAULTS) end
    local function Changed() ns.CharDisplay_Apply(); if Notify then Notify() end end
    -- a check box that reads and writes one key; disabled (the item detail rows) or hidden (the parts) while the page's switch is off
    local function T(key, order, name, desc, width, disabled, hidden, tip)
        return { type = "toggle", order = order, name = name, desc = desc, width = width, disabled = disabled, hidden = hidden, tip = tip,
            get = function() return C()[key] and true or false end, set = function(_, v) C()[key] = v and true or false; Changed() end }
    end
    local function isOff() return not C().enabled end
    -- (QoL 0.7.31) the full stat list's own page (her answer "Show / hide each stat, Order, % / rating / both, Groups and colours"): every
    -- group heading and stat line of Character Stats as the game gives them for this character now (other classes' resources differ)
    local listOff = function() return isOff() or not C().statList end
    -- (V14 / V27, U1 G-015) the settings window rebuilds every page on any change: the stat model is built for this page only while
    -- Improved Character Display and its Stat list part are on, once, and kept until the spec or level changes (OnEvent drops it);
    -- off, the Stat list page lists no stats (it shows again once the part is ticked).
    -- (release gate integration) the rows are not added while the tree is built: the tree's shape must not depend on a switch, because
    -- a click on a sidebar tick box redraws the tree drawn last (XayaUI_Options TreePaint.lua Tree.SwitchClick / Tree.Keep;
    -- tests/sidebar_switches_run.py). FillList adds them, once per built tree, from the Stat list page's own `hidden` (read by
    -- AceConfigDialog's BuildSubGroups before that page's args are walked), so a tree built while this was off gets its rows when it
    -- is drawn again after the switch is ticked on. Read only while the options window draws the tree.
    local function Col(t) if type(t) == "table" then return t[1], t[2], t[3], 1 end end
    local listArgs = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Every Character Stats line in the character window's stats pane (XayaUI's own list over Blizzard's), colored. For each stat: show or hide it, move it up or down in its group, show its percent, its rating or both (the secondary and tertiary stats), and its name and color; for each group: its heading's name and color. An empty name or \"Default color\" gives the default back." },
        reset = { type = "execute", order = 1, name = "Reset the list", disabled = listOff,
            desc = "Shows every stat again in Character Stats' order as a percent, and resets every name and color.",
            func = function() local c = C(); for _, k in ipairs(LIST_TABLES) do c[k] = {} end; Changed() end },
    }
    local filled = false
    local function FillList()
        if filled then return end
        local cNow = Cfg()
        if not (cNow and cNow.enabled and cNow.statList) then return end
        filled = true
        if not pageGroups then pageGroups = ns.CharDisplay_ListModel() end
        local groups = pageGroups
        for gi, g in ipairs(groups) do
            local gk = g.key
            listArgs["g" .. gi] = { type = "group", inline = true, order = gi * 100, name = function() local n = C().groupName[gk]; return (n and n ~= "") and n or g.label end,
                args = {
                    name = { type = "input", order = 1, name = "Heading", disabled = listOff, desc = "The heading's text (empty: '" .. g.label .. "').",
                        get = function() return C().groupName[gk] or "" end, set = function(_, v) v = tostring(v or ""); C().groupName[gk] = (v ~= "") and v or nil; Changed() end },
                    color = { type = "color", order = 2, name = "Color", disabled = listOff,
                        get = function() local t = C().groupColor[gk]; if t then return Col(t) end; local l = TC("xui-label", "text", { 1, 0.82, 0, 1 }); return l[1], l[2], l[3], 1 end,
                        set = function(_, r, gg, b) C().groupColor[gk] = { r, gg, b }; Changed() end },
                    plain = { type = "execute", order = 3, name = "Default color", width = "half", disabled = listOff,
                        func = function() C().groupColor[gk] = nil; Changed() end },
                } }
            for i = 1, #g.stats do
                local function Key() return ns.CharDisplay_ListOrder(C(), g)[i] end
                local function Item() local k = Key(); for _, it in ipairs(g.stats) do if it.key == k then return it end end end
                local function Move(d)
                    local c = C()
                    local list = ns.CharDisplay_ListOrder(c, g)
                    local j = i + d
                    if j < 1 or j > #list then return end
                    list[i], list[j] = list[j], list[i]
                    c.statOrder[gk] = list
                    Changed()
                end
                listArgs["g" .. gi .. "s" .. i] = { type = "group", inline = true, order = gi * 100 + i,
                    name = function() local it = Item(); if not it then return "" end; local n = C().statName[it.key]; return "    " .. ((n and n ~= "") and n or it.label) end,
                    args = {
                        show = { type = "toggle", order = 1, name = "Show", width = "half", disabled = listOff,
                            get = function() local k = Key(); return k and not C().statHide[k] end,
                            set = function(_, v) local k = Key(); if k then C().statHide[k] = (not v) and true or nil; Changed() end end },
                        mode = { type = "select", order = 2, name = "Shows", disabled = listOff,
                            values = { percent = "Percent", rating = "Rating", both = "Both (rating / percent)" }, sorting = { "percent", "rating", "both" },
                            hidden = function() return not ns.CharDisplay_HasRating(Key()) end,
                            get = function() return C().statMode[Key()] or "percent" end,
                            set = function(_, v) local k = Key(); if k then C().statMode[k] = (v ~= "percent") and v or nil; Changed() end end },
                        up = { type = "execute", order = 3, name = "Up", width = "half", disabled = function() return listOff() or i == 1 end, func = function() Move(-1) end },
                        down = { type = "execute", order = 4, name = "Down", width = "half", disabled = function() return listOff() or i == #g.stats end, func = function() Move(1) end },
                        name = { type = "input", order = 5, name = "Name", disabled = listOff,
                            get = function() local k = Key(); return (k and C().statName[k]) or "" end,
                            set = function(_, v) local k = Key(); if k then v = tostring(v or ""); C().statName[k] = (v ~= "") and v or nil; Changed() end end },
                        color = { type = "color", order = 6, name = "Color", disabled = listOff,
                            get = function()
                                local k, it = Key(), Item()
                                local t = k and C().statColor[k]
                                if t then return Col(t) end
                                local d = (it and it.labelColor) or TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
                                return d[1], d[2], d[3], 1
                            end,
                            set = function(_, r, gg, b) local k = Key(); if k then C().statColor[k] = { r, gg, b }; Changed() end end },
                        plain = { type = "execute", order = 7, name = "Default color", width = "half", disabled = listOff,
                            func = function() local k = Key(); if k then C().statColor[k] = nil; Changed() end end },
                    } }
            end
        end
    end
    -- the enchant slots (QoL 0.7.0; was the Slot Overlays' Enchant Slots tab, same labels): the slots the Enchants option checks, in
    -- either style, and the Shopping List's missing-enchant list reads
    local slotToggles = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Ticked to start with: the slots this expansion's enchants cover (head, shoulders, chest, legs, feet, both rings, main hand, and off hand when it holds a weapon). Change any tick and your own choice is kept. With Enchants on the slot, a ticked slot with no enchant shows E? (orange) and an enchanted one E (green); beside the slot, a ticked slot with no enchant shows \"No enchant\" (orange)." },
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
    -- (A24 #7) each option's Style: "On the slot" / "Beside the slot" (her words); greyed while its option (or the page) is off. The
    -- option's tick box and its Style share one row (the page's rule: no dropdown alone on a row, tests/char_statcalc2_run.py).
    local STYLE_VALUES, STYLE_ORDER = { [STYLE_SLOT] = "On the slot", [STYLE_BESIDE] = "Beside the slot" }, { STYLE_SLOT, STYLE_BESIDE }
    local function Style(key, order, optKey, default, desc)
        return { type = "select", order = order, name = "Style", desc = desc, values = STYLE_VALUES, sorting = STYLE_ORDER,
            disabled = function() return isOff() or not C()[optKey] end,
            get = function() local v = C()[key]; return (v == STYLE_SLOT or v == STYLE_BESIDE) and v or default end,
            set = function(_, v) if v ~= STYLE_SLOT and v ~= STYLE_BESIDE then return end; C()[key] = (v ~= default) and v or nil; Changed() end }
    end
    -- the empty-socket count "2S" on the slots (QoL 0.7.0, the Slot Overlays' Empty sockets, same label; kept as it was, A24 #7 did not
    -- decide the gems and sockets): it shows only while "Gems and sockets beside the slots" is off; until then its box is greyed and
    -- unticked and its hover names that option (SC-069). The test is the drawing code's own (DrawsSockets, read by UpdateOverlay), so
    -- the box and the slot never disagree (after an error stops the item details, the mark shows again and the box is live). The saved
    -- choice is kept.
    local function gemsBeside() return DrawsSockets() end
    local sockMark = T("socketMark", 5.5, "Empty sockets", "Shows how many sockets have no gem (for example 2S) at the top of the slot.", "full")
    sockMark.disabled = function() return isOff() or gemsBeside() end
    sockMark.get = function() if gemsBeside() then return false end; return C().socketMark == true end
    sockMark.set = function(_, v) C().socketMark = v and true or nil; Changed() end
    sockMark.desc = function()
        if not gemsBeside() then return "Shows how many sockets have no gem (for example 2S) at the top of the slot." end
        return "Greyed: \"Gems and sockets beside the slots\" already shows this; turn it off to use this mark."
    end
    -- (review round 2) the Text size slider is greyed while no mark shows on the slots (Enchants on the slot, or Empty sockets), so it
    -- never looks live while changing nothing
    local function noMark() local c = C(); return isOff() or not (EnchOnSlot(c) or (c.socketMark == true and not DrawsSockets())) end
    local markSize = { type = "range", order = 5.6, name = "Text size", min = 8, max = 16, step = 1, disabled = noMark,
        desc = function() if noMark() then return "Greyed: no mark shows on the slots." end; return "Size of the marks' text on the slots (E?, E and the empty-socket count)." end,
        get = function() return C().ovSize end, set = function(_, v) C().ovSize = v; Changed() end }
    -- the Stat Calc button's own switch (V25 R2; A24 #3: the button is this page's and "has its own on/off"). On by default: it shows
    -- only while the Stat Calculator's panel is on, as before.
    local button = { type = "toggle", order = 7, width = "full", disabled = isOff, name = "Stat Calc button",
        desc = "Shows the Stat Calc button in the character window's title row; it opens or closes the Stat Calculator beside the window. It shows only while the Stat Calculator and its panel are on (Bonus Features > Stat Calculator).",
        get = function() return C().statCalcButton ~= false end,
        set = function(_, v) if v then C().statCalcButton = nil else C().statCalcButton = false end; Changed() end }
    local switch = { type = "toggle", order = 1, name = "Improved Character Display",
        desc = "Turns on what XayaUI adds to the character window: item levels, enchants, gems, the full stat list and the Stat Calc button. While it is off nothing is created, registered or read.",
        tip = "Item levels, enchants, gems, the full stat list and the Stat Calc button on the character window.",
        get = function() return C().enabled end,
        set = function(_, v) if not ns.SettingsReady("qol") then return end; C().enabled = v and true or false; Changed() end }
    return {
        type = "group", name = "Improved Character Display", order = 2, childGroups = "tree", xuiSwitch = switch,
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "What XayaUI adds to the character window: one item level per slot and each slot's enchant, on the slot or beside it; the embellishment and gems beside each slot; the full stat list in the stats pane; the Stat Calc button. Extra lines on the stat tooltips are an option of Bonus Features > Enhanced Tooltips (Character stats). Its look (border, colors, the wider window) is Blizzard Reskin > Character Reskin. Off by default." },
            statListPage = { type = "group", name = "Stat list", order = 50, args = listArgs,
                hidden = function() if isOff() then return true end; FillList(); return false end },
            ilvl = T("ilvl", 3, "Item level", "Shows one item level per slot, colored by its upgrade track and brighter with each upgrade step. On the slot it is hidden where another addon already shows the same number.", nil, isOff),
            ilvlStyle = Style("ilvlStyle", 3.5, "ilvl", STYLE_SLOT, "On the slot: at the bottom of the slot. Beside the slot: the first line beside it."),
            enchants = T("enchants", 4, "Enchants", "Shows each slot's enchant: on the slot, E? (orange) where a slot from Enchant Slots has none and E (green) where it has one. Beside the slot, the enchant's name and the embellishment, or \"No enchant\" in orange; hover a line for what it does.", nil, isOff),
            enchantStyle = Style("enchantStyle", 4.5, "enchants", STYLE_BESIDE, "On the slot: E? or E at the top of the slot. Beside the slot: the enchant's name and the embellishment beside it."),
            gems = T("gems", 5, "Gems and sockets beside the slots", "Shows each socket under the enchant: the gem's icon and name, or the empty socket's type in orange. Hover a gem for its tooltip.", "full", isOff),
            socketMark = sockMark,
            markSize = markSize,
            statList = T("statList", 6.5, "Full stat list (every Character Stats line)", "Shows every Character Stats line in the stats pane, in XayaUI's own list. Pick what shows, the order, names and colors on its Stat list page.", "full", isOff),
            statCalcButton = button,
            enchantSlotsPage = { type = "group", name = "Enchant Slots", order = 20, args = slotToggles, hidden = isOff },
        },
    }
end
ns.RegisterSettingsPage("qol", "chardisplay", ns.BuildCharDisplayPage)

-- /xui reskin status: the lines about what this file draws (the Character Reskin's handler prints the look's; ns.RegisterCommand
-- keeps every handler of a name). Only status and the bare command print here.
local function OtherTextLines()
    local other = OtherText()
    if #other == 0 then ns.Print("No other text on the slot buttons (another addon can still draw over them from frames of its own)."); return end
    local shown = {}
    for i = 1, math.min(#other, 8) do shown[i] = other[i] end
    ns.Print(("Text on the slots that is not XayaUI's (%d): %s%s"):format(#other, table.concat(shown, "; "), #other > 8 and "; ..." or ""))
    ns.Print(("XayaUI's item level is hidden on %d slot(s) where that text shows the same number. To keep one: turn the other addon's item level off, or \"Item level\" in Improved Character Display (or its Style: Beside the slot)."):format(diag.dupes or 0))
end
ns.RegisterCommand("reskin", function(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if arg ~= "status" and arg ~= "" then return end
    local c = Cfg()
    if not c then return end
    local function opt(on, style) if not (c.enabled and on) then return "off" end; return style == STYLE_SLOT and "on the slot" or "beside the slot" end
    ns.Print(("Improved Character Display: %s%s%s; %d slots; item level %s; enchants %s; empty sockets mark %s."):format(c.enabled and "on" or "off",
        diag.failed and " (stopped after an error)" or "", diag.lastError and (", last error: " .. diag.lastError) or "", diag.slots or 0,
        opt(c.ilvl, IlvlBeside(c) and STYLE_BESIDE or STYLE_SLOT), opt(c.enchants, EnchOnSlot(c) and STYLE_SLOT or STYLE_BESIDE),
        (c.enabled and MarksOn(c) and c.socketMark) and "on" or "off"))
    ns.Print(("Size change: %s."):format(diag.relayout or "none seen since login"))
    ns.Print(("Full stat list: %s."):format((c.enabled and c.statList) and tostring(diag.statList or "drawn when the stats pane shows") or "off"))
    ns.Print(("Slot blocks: %d (%d cut to fit, %d hidden while the camera buttons show); sockets drawn: %d; embellished items: %d."):format(
        diag.labels or 0, diag.cut or 0, diag.camHit or 0, diag.sockets or 0, diag.embellished or 0))
    -- (QoL 0.7.19) who else draws text on the slots: Xaya's screenshot of 2026-11-05 had a second item level on every slot
    OtherTextLines()
end)
