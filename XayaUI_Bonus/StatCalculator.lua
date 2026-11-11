-------------------------------------------------------------------------------
-- StatCalculator.lua : Bonus Features > Stat Calculator (XayaUI QoL 0.7.0; XayaUI Bonus Features since Bonus 0.6.37). The panel
-- docked to the character window, its compact stat sheet (the Stat Calculator: a stat map, a gear comparison, spells), and the settings
-- page. OFF by default; while off nothing is created, registered or read.
-- (Bonus 0.6.37 / QoL 0.7.53, character pane split stage 2; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 4.2) Xaya's Q5 answer: "The
-- Advanced Character Stats pane window is a Bonus feature"; PS-54: "the Stat Calculator which is a bonus feature as already established".
-- This file began in XayaUI_QoL and was moved and renamed with git mv (V25 R3; git log --follow keeps its history). What stayed with
-- QoL: the slot overlays and their settings (XayaUI_QoL/ImprovedCharacterDisplay.lua, QoL > Improved Character Display); the extra
-- lines on the character window's own stat tooltips are Enhanced Tooltips' since V25 R4 (XayaUI_Bonus/Tooltips.lua section 5); the
-- model's flat list and line hover are StatModel.lua's (CM.Flat, CM.TooltipLines). The one model stays XayaUI QoL's: this file reads
-- it only through the "statModel" service (CM below), so with XayaUI QoL off there is no panel, no page, no command and nothing is made.
-- Saved settings: XayaUIBonusDB.characterToolkit (the panel's keys and its own switch `enabled`), copied once from
-- XayaUIQoLDB.characterToolkit (CueRulesDB.characterToolkit before P5) by core (Modules.lua section 0c, the key move; copy, never move).
-- (V25 R3) the saved key keeps its old internal name: core's key move copies a key under one name only, so a rename needs core.
-- NOT RUN IN GAME when written (2026-11-04): every number needs an in-game check.
--
-- Every number comes from the one model in StatModel.lua (the game's own reads; what the game does not give is marked, never
-- guessed; secret values show as "hidden in combat"). This file only draws it:
--   Tabs: Stats | Gear | Ability Scaling (the Spells tab until QoL 0.7.28; the Sheet tab was removed in QoL 0.7.14: the character window itself is restyled instead,
--   QoL Character Reskin; the What If tab in 0.7.14: its numbers are the stat map's boxes, its item compare the Gear comparison).
--   Stats is the stat map: one card per stat with a box holding the number itself (the Change column, far right, QoL 0.7.20) and
--   what it feeds, "now -> with your number"; an ability list is one nested line per ability.
--   Gear: the equipped items as icons; click one to list what you own for that slot, pick one, and see the two side by side and
--   everything the change does through the stat map. The Spells tab lists the spells added by hand and every spell of the
--   spellbook with numbers in its description, under All / Offense / Defense filter buttons (spells only since 0.7.14).
--   Each tab is made of sections with a header (click a header to fold it). The stat sections (every Stats section, the Gear
--   comparison's "What it changes") are tables since QoL 0.7.15: Stat | Rating | Current value | Pt value | Note | Change (the box,
--   since 0.7.20) under a column head, each card's "»" lines in the same columns (RenderGrid); the Gear Summary and Side by side
--   are Gear | Character | Elsewhere and Equipped | this item | Change. Other lines are label and value, with their detail pairs
--   under them. Hovering a line shows where the number comes from (the conversion hover: rating through the game's converter, base
--   and buffs, linked conversions such as crit to parry where the game reports them, thresholds).
--   (Until QoL 0.7.39 rating lines could show a percent or a rating, by a title-row button, a click on one line or a setting; that
--   toggle is gone since 0.7.40, REQUEST-LOG B2.)
--   QoL 0.7.40 (Xaya 2026-11-06, REQUEST-LOG #87-#91): under each stat of the Stats tab, one row per contribution that feeds it with its
--   number ("from Agility +2,616"); each stat folds (folded by default, remembered per stat), folded rows are in its hover; the
--   Influences column is "Modifies" (names only). The picked compare items' frames show again (#89: named-colour links). The Gear
--   "Changes" numbers are left-aligned with the difference in brackets beside them (#90). The header shows the equipped item level on
--   the left and the max item level (in bags) on the right, no name, class or spec (#91).
--   QoL 0.7.23 (Xaya 2026-11-05): the Stats tab is one "Character Stats" section (Core Stats > Primary / General / Offensive /
--   Defensive, then Secondaries, Tertiaries and the Gear Summary, drawn as headings inside it) and the "Stat Weights" pane under it;
--   the All ratings box and the Durability and repair section are gone. The window: a "Stat Calc" button on the character window
--   opens / closes it and its open state is kept for the next time; a "Stat Calculator" row in XayaUI's minimap button list and
--   /xui stats open it on its own (at its own place; docked beside the character window while that is open); a Max / Min button in
--   its title row switches between two heights set on the settings page; the corner grip still resizes (and sets the current height).
--   QoL 0.7.24 (Xaya 2026-11-05): the Spells tab's filters are a menu on a filter icon at the right of its top row (None / Offense /
--   Defense / Utility), its spell data button is a real button centred above the sections (at most 250 wide), and each spell is a row
--   of columns: Spell Name (Spell ID under it) | % PSV ("1 Agility = N" under it) | Talent Modifiers | Computed Value (her answer
--   2026-11-06: "Fourth column - computed Value"); "Usable now" is gone.
--   QoL 0.7.28 (Xaya 2026-11-06, REQUEST-LOG #60-#64): the Spells tab is the Ability Scaling tab (her answer "Spells tab -> Ability
--   Scaling"); no stray Refresh row in its lists; no column head is cut (widths from the heads as the game measures them); Stat Weights
--   titles centred, cells from their column's left edge, T/L in two lines; a typed number's new value, with its sign, under the value
--   (Bonus 0.6.38: green when better, red when worse, blue / orange with a XayaUI colour-blind theme; was the accent colour) (no
--   "now -> then" on the Stats tab); Primary / General / Offensive / Defensive are bucket bars and every Stats line
--   is indented by its depth (one step); the Gear Summary is at the top of the Stats tab as a graphic in a chosen style.
--   Gear: the selected equipped item's box is highlighted (a click on it again lets it go); the items you own for the slot are icons
--   (click to pick, several at once, up to 3; the box shows the last one's name); one "Changes" section (Stat | Pt value | Equipped |
--   each picked item, DR threshold and true / lost rating under each secondary that changes, Stat effects, Spell Changes, on-use and
--   proc effects with the RPPM wording) replaces Side by side and What it changes; slots are named Ring slot #1 ... Main-hand, Off-hand.
--   Look: the XayaUI theme's colors and font (ns.Theme): window, border, tab, button and text classes; nothing from another addon.
--   (The slot overlays, the Stat Calc button and the other changes to the character window itself are Improved Character Display's,
--   XayaUI QoL's ImprovedCharacterDisplay.lua, since V25 R2; Xaya A24 #3: the Stat Calculator is only the side window.)
--   Combat (V26, Xaya A24 #3 "Hide silently"): in combat the panel and the Stat Calc button are hidden with no message, nothing opens
--   the panel, and no model is built, nothing is drawn and no stat event is handled; after combat both come back as they would be.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local BonusS = ns.Settings("bonus")   -- (Bonus 0.6.37: Bonus's own XayaUIBonusDB; Modules.lua section 0b)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("bonus", "XayaUI_Bonus", "XayaUIBonusDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)
-- (Bonus 0.6.37, stage 3) the one model, XayaUI QoL's, through its "statModel" service: every CM.x reads the service's model at the time
-- (XayaUI QoL loads after this addon; with it off every CM.x is nil and nothing below runs: Cfg() is nil without the model)
local function Model() local s = ns.Service and ns.Service("statModel"); return s and s.CM or nil end
local CM = setmetatable({}, { __index = function(_, k) local m = Model(); if m then return m[k] end end,
    __newindex = function(_, k, v) local m = Model(); if m then m[k] = v end end })

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function isSecret(v) return CM.IsSecret(v) end

-- (V26, Xaya A24 #3 "Hide silently") in combat the panel and the Stat Calc button are hidden with no message, and nothing opens it:
-- `combatHidden` is set at PLAYER_REGEN_DISABLED (the game fires it just before its combat lockdown begins) and cleared at
-- PLAYER_REGEN_ENABLED; InCombatLockdown() covers the time this file was not listening (switched on, or the login, in combat).
-- Plain frames only (nothing protected), so hiding them in combat is allowed; the character window itself is never touched.
-- (SC-001 / SC-045) Every way in (the draw, ns.StatCalc_Render, and every input: a typed number, a picked item, a fold, a tab, a
-- filter, the Min / Max button, the statCalc service's wrappers) checks this first: in combat nothing here builds the stat model,
-- draws, or changes the saved settings, and nothing is said. The stat model itself (StatModel.lua) has no such gate: Enhanced
-- Tooltips' character-stat lines read it in combat.
local combatHidden = false
local function InCombat() return combatHidden or (type(InCombatLockdown) == "function" and InCombatLockdown() and true) or false end
-- (QAWalks-statcalc-fixes.lua) how many stat models this file has built (ns.StatCalc_Render); read only, through statCalcDebug.Builds
local modelBuilds = 0

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------
ns.STATCALC_DEFAULTS = {
    enabled = false,
    panel = true,          -- the docked panel
    side = "right",        -- right | left of the character window
    detail = "all",        -- all | short (detail pairs under each line)
    -- (tooltips: the character window's stat tooltip lines, Enhanced Tooltips' option since V25 R4: Tooltips.lua section 5)
    fontSize = 11,
    opacity = 0.92,
    advanced = false,      -- spell math
    spells = {},           -- added by hand: { { id = spellID, coeff = number|nil, base = "ap"|"sp", kind = nil|"offense"|"defense"|"both" } }
    spellFilter = "all",   -- the Spells tab's filter: all (None) | offense | defense | utility (QoL 0.7.7: these were the Defense and Offense tabs; utility QoL 0.7.24)
    spellsAll = false,     -- list spellbook spells whose description has no numbers too
    free = { x = 0, y = 0 }, -- position when shown on its own (the character window closed)
    panelOpen = true,      -- the panel's open / closed state, kept for the next time (QoL 0.7.23; Xaya: "remember the last-left state")
    sizeMode = "small",    -- small | large: the Min / Max button's two heights (QoL 0.7.23)
    heightSmall = 440, heightLarge = 760,
    tab = "stats",         -- the panel tab last shown ("spells" is the Ability Scaling tab since QoL 0.7.28)
    gearSumStyle = "bars", -- the Gear Summary's look (QoL 0.7.28): bars | tiles | stacked | columns | share | table (CM.GEAR_SUM_STYLES)
    whatIf = 0,            -- (the All ratings amount; removed in QoL 0.7.23, always 0)
    whatIfStats = {},      -- What If: rating added to one stat, by stat key
    -- (valueMode and lineModes, the "% / rating" toggle, are gone since QoL 0.7.40: REQUEST-LOG B2; Cfg clears them from saved settings)
    collapsed = {},        -- folded section headers, by section key
    statOpen = {},         -- (QoL 0.7.40, #88) the Stats tab's stats opened to show their rows, by card key; folded is the default
    -- (overlays, ovIlvl, ovSockets, ovEnchants, ovSize, enchantSlots, enchantSlotsSet: XayaUI QoL's, ImprovedCharacterDisplay.lua, since Bonus 0.6.37)
}
-- the size limits of the panel's corner grip (#381, Xaya: "resize from the bottom right"; QoL 0.7.14)
local MIN_W, MAX_W, MIN_H, MAX_H = 340, 760, 300, 1100
local OLD_TABS = { overview = "stats", ratings = "stats", sheet = "stats", whatif = "stats" }   -- (Sheet and What If: removed in QoL 0.7.14)

local function CopyVal(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyVal(x) end
    return t
end
local function Cfg()
    -- (Bonus 0.6.37) Bonus's store open and the model there (XayaUI QoL on, its store open: the key move from it has run then)
    if not (ns.SettingsReady("bonus") and ns.SettingsReady("qol") and Model()) then return nil end
    local c = BonusS.characterToolkit
    if type(c) ~= "table" then c = {}; BonusS.characterToolkit = c end
    -- (QoL 0.7.23) a height dragged before the Min / Max heights existed becomes the smaller one
    if c.heightSmall == nil and type(c.size) == "table" and num(c.size.h) then c.heightSmall = c.size.h end
    for k, v in pairs(ns.STATCALC_DEFAULTS) do
        if c[k] == nil then c[k] = CopyVal(v) end
    end
    if c.side ~= "left" then c.side = "right" end
    if c.detail ~= "short" then c.detail = "all" end
    -- (QoL 0.7.40; REQUEST-LOG B2, reading taken: the "% / rating" toggle is removed in all three places, since the columns already show
    -- rating, current value and Pt value side by side) its two saved keys are dropped; nothing reads them any more
    c.valueMode, c.lineModes = nil, nil
    c.fontSize = math.max(8, math.min(16, tonumber(c.fontSize) or 11))
    c.opacity = math.max(0, math.min(1, tonumber(c.opacity) or 0.92))
    if type(c.spells) ~= "table" then c.spells = {} end
    for i = #c.spells, 1, -1 do
        local s = c.spells[i]
        if type(s) ~= "table" or type(s.id) ~= "number" then table.remove(c.spells, i)
        else
            if s.coeff ~= nil and not num(s.coeff) then s.coeff = nil end
            if s.base ~= "sp" then s.base = "ap" end
            if s.kind ~= "offense" and s.kind ~= "defense" and s.kind ~= "both" and s.kind ~= "utility" then s.kind = nil end
        end
    end
    if type(c.free) ~= "table" then c.free = { x = 0, y = 0 } end
    -- the width the corner grip left (the height is the Min / Max mode's, QoL 0.7.23)
    if type(c.size) == "table" and num(c.size.w) then
        c.size = { w = math.floor(math.max(MIN_W, math.min(MAX_W, c.size.w)) + 0.5) }
    else c.size = nil end
    c.heightSmall = math.floor(math.max(MIN_H, math.min(MAX_H, tonumber(c.heightSmall) or 440)) + 0.5)
    c.heightLarge = math.floor(math.max(MIN_H, math.min(MAX_H, tonumber(c.heightLarge) or 760)) + 0.5)
    if c.sizeMode ~= "large" then c.sizeMode = "small" end
    c.panelOpen = c.panelOpen ~= false
    c.tab = OLD_TABS[c.tab] or c.tab
    -- QoL 0.7.7: the Defense and Offense tabs became the Spells tab's filters (Xaya 2026-11-04)
    if c.tab == "defense" or c.tab == "offense" then c.spellFilter = c.tab; c.tab = "spells" end
    if not CM.TAB_OK[c.tab] then c.tab = "stats" end
    c.spellFilter = CM.FilterOf(c)
    c.gearSumStyle = CM.GearSumStyle(c)
    c.spellsAll = c.spellsAll == true
    c.whatIf = 0   -- (QoL 0.7.23; Xaya 2026-11-05: "remove "all ratings" as an entry option": a saved amount no longer applies)
    for _, k in ipairs({ "whatIfStats", "collapsed", "statOpen" }) do
        if type(c[k]) ~= "table" then c[k] = {} end
    end
    for k, v in pairs(c.statOpen) do if v ~= true or type(k) ~= "string" then c.statOpen[k] = nil end end
    for k, v in pairs(c.whatIfStats) do
        local n = math.floor(tonumber(v) or 0)
        c.whatIfStats[k] = (n ~= 0) and math.max(-100000, math.min(100000, n)) or nil
    end
    do local n = math.floor(tonumber(c.whatIfPrimary) or 0); c.whatIfPrimary = (n ~= 0) and math.max(-100000, math.min(100000, n)) or nil end
    return c
end
ns.StatCalc_Cfg = Cfg

-- (QoL 0.7.40; REQUEST-LOG B2, reading taken) the value modes are gone: the "Show: % / rating" button in the title row, the click on a
-- rating line that flipped it, and Settings > Panel > Layout "Rating lines" with Your numbers "Reset line flips". Every line shows its
-- value; the columns give rating, current value and Pt value side by side.

-- (QoL 0.7.40; Xaya 2026-11-06, REQUEST-LOG #88: "make each stat collapsible"; her answer "Collapsed (Recommended)") open or fold one stat
-- of the Stats tab (its rows: what feeds it, with the number); remembered per stat in the saved settings (statOpen), folded by default
function ns.StatCalc_ToggleStat(key)
    if InCombat() then return end   -- (V26) nothing changes or draws in combat
    local c = Cfg(); if not (c and type(key) == "string") then return end
    c.statOpen[key] = (not c.statOpen[key]) and true or nil
    ns.StatCalc_Render()
end
function ns.StatCalc_StatOpen(key)
    local c = Cfg()
    return (c and c.statOpen[key]) and true or false
end

-------------------------------------------------------------------------------
-- The model, flat (one list of { section = title } markers and items with "label: value" lines), with the panel's settings; used by
-- the tests. tab = a panel tab key, or nil for Stats, Defense and Offense. (Bonus 0.6.37: the code is StatModel.lua's CM.Flat.)
-------------------------------------------------------------------------------
function ns.StatCalc_Model(tab)
    local c = Cfg()
    if not c then return {}, nil end
    return CM.Flat(c, OLD_TABS[tab] or tab)
end
ns.StatCalc_ClearCache = function() CM.ClearCache() end
ns.StatCalc_Numbers = function(text) return CM.Numbers(text) end
ns.StatCalc_SpellName = function(id) return CM.SpellName(id) end
ns.StatCalc_ItemStats = function(link) return CM.ItemStats(link) end

-------------------------------------------------------------------------------
-- Theme (XayaUI's own style sheet, ns.Theme; plain fallbacks when it is missing)
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
-- the theme's accent colour (core's resolved "accent" token, ns.Theme.cur.accent, as core's game menu and the cursor highlight read it;
-- XayaUI's default accent when the theme is missing). The bucket bars and the picked items' frame. (QoL 0.7.28 to 0.7.53 / Bonus 0.6.37:
-- also the new value a typed number gives; Bonus 0.6.38: those have their own colours, ChangeColor below.)
local function Accent()
    local T = ns.Theme
    local c = T and T.cur and T.cur.accent
    if type(c) == "table" and num(c[1]) and num(c[2]) and num(c[3]) then return { c[1], c[2], c[3], c[4] or 1 } end
    return { 0.75, 0.25, 1, 1 }
end
ns.StatCalc_Accent = Accent   -- (tests)

-- Bonus 0.6.38 (Xaya 2026-11-08, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #5 / #6 / #15, her words: "stat calculator colors need to
-- ignore themeing colors"; "xayaui theme is fine for everything except change numbers and stat colors"; change values by direction: "1 or
-- adjust for color blind mode" (option 1 = "Green up, red down"); the colour-blind switch: "XayaUI theme only"). The new value a typed
-- number gives is coloured by what it means (the model's newTone, StatModel.lua CM.ChangeDir / SplitChanges): better = the game's
-- green, worse = the game's red; when XayaUI's base theme is one of its three colour-blind themes (XayaUI/Theme.lua T.BUILTIN colorblind,
-- protan, tritan; the game's own colour-blind setting is not read), better = blue and worse = orange, the pair the colour-blind theme
-- already uses: its accent (sky blue, Okabe-Ito) and its danger colour (orange), read from T.BUILTIN.colorblind.pal (XayaUI/Theme.lua,
-- the "colorblind" entry of T.BUILTIN, line 174 accent = { 0.337, 0.706, 0.914 }, line 179 danger = { 1.00, 0.55, 0.10 }, at core
-- 0.6.83). The same = the theme's text colour.
-- The base theme is the global one (Settings > Theme, T.EffBase: a Custom theme looks through to the theme it starts from; a saved
-- theme to its own base): the Stat Calculator registers no theme scope of its own (Theme.lua T.RegisterScope), so it paints with the
-- global theme.
-- GREEN_FONT_COLOR / RED_FONT_COLOR: the game's own colour objects (Blizzard's shared UI code, ColorMixin, read with :GetRGB() as
-- XayaUI_Reskin/BlizzardSkins.lua reads the game's colours). They are not in the generated API documentation (INFERENCE: present in
-- every client, as Blizzard's UI uses them); when one is missing or does not answer, the fallback is XayaUI's own "good" green and the
-- theme's danger colour (else a plain red).
local CB_BASES = { colorblind = true, protan = true, tritan = true }
local function ColorBlindBase()
    local T = ns.Theme
    if not (T and T.EffBase) then return false end
    local ok, b = pcall(T.EffBase)
    if not ok or type(b) ~= "string" then return false end
    if CB_BASES[b] then return true end
    local P = ns.Settings and ns.Settings("platform")   -- (the saved themes, through the Platform's settings view: never CueRulesDB directly)
    local themes = P and P.themes
    local sv = type(themes) == "table" and themes[b]
    if type(sv) ~= "table" then return false end
    local sb = (sv.base == "custom") and sv.under or sv.base
    return CB_BASES[sb] == true
end
ns.StatCalc_ColorBlindBase = ColorBlindBase   -- (tests, the QA walkthrough)
local function GameColor(name)
    local c = rawget(_G, name)
    if type(c) ~= "table" or type(c.GetRGB) ~= "function" then return nil end
    local ok, r, g, b = pcall(c.GetRGB, c)
    if ok and num(r) and num(g) and num(b) then return { r, g, b, 1 } end
end
local function CBPal(key)
    local T = ns.Theme
    local pal = T and type(T.BUILTIN) == "table" and type(T.BUILTIN.colorblind) == "table" and T.BUILTIN.colorblind.pal
    local c = type(pal) == "table" and pal[key]
    if type(c) == "table" and num(c[1]) and num(c[2]) and num(c[3]) then return { c[1], c[2], c[3], 1 } end
end
local function ChangeColor(dir)
    if dir == "better" or dir == "worse" then
        if ColorBlindBase() then
            local c = CBPal(dir == "better" and "accent" or "danger")
            if c then return c end
        end
        local c = GameColor(dir == "better" and "GREEN_FONT_COLOR" or "RED_FONT_COLOR")
        if c then return c end
        if dir == "better" then return { TONES.good[1], TONES.good[2], TONES.good[3], 1 } end
        local T = ns.Theme
        local d = T and T.cur and T.cur.danger
        if type(d) == "table" and num(d[1]) and num(d[2]) and num(d[3]) then return { d[1], d[2], d[3], 1 } end
        return { 1, 0.25, 0.25, 1 }
    end
    return TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })   -- the same (or no direction known): the theme's text colour
end
ns.StatCalc_ChangeColor = ChangeColor   -- (tests, the QA walkthrough)
local function ToneColor(tone, fb)
    if tone == "mute" then return TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 }) end
    if tone == "better" or tone == "worse" or tone == "same" or tone == "change" then return ChangeColor(tone) end
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
local function Paint(fs, col) if fs and col then fs:SetTextColor(col[1], col[2], col[3], col[4] or 1) end end

-------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------
local panel, scroll, content
-- (SC-081 / SC-020) the panel's own show / hide: which events it listens to while it is shown (below, "Events"); declared here because
-- the panel is made (Build) before that part of the file
local OnPanelShown, OnPanelHidden, NoteWantedItems, SyncPanelEvents
-- (SC-085 / SC-049, round 2) the bag list and the talent scan the model keeps (StatModel.lua: KC.owned until CM.ForgetOwned, the talent
-- scan until CM.ClearTalents) are kept right by BAG_UPDATE_DELAYED / the talent events only while their tab is shown (TAB_EVENTS). While
-- those events are not heard (panel closed, another tab, combat) a change is missed, so the tab's first draw after that reads them again,
-- once. Set whenever the panel's events stop covering that tab (RegisterPanelEvents); used by ns.StatCalc_Render before the model build.
local bagsStale, talentsStale = true, true
-- spacing from core (#351 phase 2, XayaUI/Modules.lua): PAD = the margin inside the panel, GUT = the gutter between two controls
local PANEL_W, PAD, GUT = 450, ns.UI_MARGIN, ns.UI_GUTTER   -- 450 (QoL 0.7.21, Xaya: "up to 450px" so every column fits; was 380)
local TITLE_H = 18            -- the title row (the mode button is 18 tall)
-- the header (QoL 0.7.40, REQUEST-LOG #91): one line, the equipped item level on the left and the max item level (in bags) on the right
-- (until 0.7.39: name and item level (15), spec and class (11) under them, 32 tall)
local NAME_H = 18
local HEADER = TITLE_H + GUT + NAME_H + GUT + 20 + GUT  -- title row, header, the tab row (20 tall), a gutter before the content
local W = PANEL_W - 2 * PAD   -- content width (changes when the panel is resized: B10, #381)
ns.STATCALC_LAYOUT = { width = PANEL_W, pad = PAD, header = HEADER, content = W, minW = MIN_W, maxW = MAX_W, minH = MIN_H, maxH = MAX_H }

local function Owner() return _G.PaperDollFrame or _G.CharacterFrame end
local function Docked() local cf = _G.CharacterFrame; return cf and cf.IsShown and cf:IsShown() end

-- pools: font strings, line buttons (hover / click), header buttons, edit boxes (What If)
local fsPool, btnPool, hdrPool, boxes = {}, {}, {}, {}
local nFS, nBtn, nHdr
-- (QoL 0.7.28) flat textures for the bucket bars and the Gear Summary's graphics, pooled like the font strings (made while the panel draws)
local texPool, nTex = {}, 0
local function Tex()
    nTex = nTex + 1
    local t = texPool[nTex]
    if not t then
        t = content:CreateTexture(nil, "ARTWORK")
        texPool[nTex] = t
    end
    t:ClearAllPoints()
    t:Show()
    return t
end
local function FS()
    nFS = nFS + 1
    local f = fsPool[nFS]
    if not f then
        f = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fsPool[nFS] = f
    end
    f:Show()
    return f
end

local function ShowTooltip(owner, it)
    if not GameTooltip or not it then return end
    local mode = nil   -- (QoL 0.7.40, B2: no value modes)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    -- a spell: the game's own spell tooltip first (#377, Xaya: "hovering a spell name shows the spell's tooltip"), then our lines.
    -- GameTooltip:SetSpellByID is the tooltip's own method (not in the generated widget docs; INFERENCE until seen in game), with the
    -- spell link as the fallback.
    if it.spellID then
        local ok = GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, it.spellID)
        if not ok and GameTooltip.SetHyperlink then ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. tostring(it.spellID)) end
        if ok then GameTooltip:AddLine(" ") end
    end
    local text = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local muted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local label = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    for _, l in ipairs(CM.TooltipLines(it, mode)) do   -- (Bonus 0.6.37: the model's, StatModel.lua)
        if l[2] ~= nil then
            -- (Bonus 0.6.38, "Yes, everywhere") a label that is a stat's name in the stat's colour (the model's lc, CM.STAT_COLORS);
            -- other labels keep the theme. The new value's colour: its tone (better / worse / same, ToneColor -> ChangeColor).
            local lc = l.lc or (l.title and label or muted)
            local rc = ToneColor(l[3], text)
            if GameTooltip.AddDoubleLine then
                GameTooltip:AddDoubleLine(l[1], l[2], lc[1], lc[2], lc[3], rc[1], rc[2], rc[3])
            else
                GameTooltip:AddLine(l[1] .. ": " .. l[2], lc[1], lc[2], lc[3])
            end
        else
            local col = l.hint and muted or text
            GameTooltip:AddLine(l[1], col[1], col[2], col[3], true)
        end
    end
    GameTooltip:Show()
end
ns.StatCalc_ShowTooltip = ShowTooltip

local function Btn()
    nBtn = nBtn + 1
    local b = btnPool[nBtn]
    if not b then
        b = CreateFrame("Button", nil, content)
        b:EnableMouse(true)
        if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp") end
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(b)
        hl:SetColorTexture(1, 1, 1, 0.06)
        b:SetScript("OnEnter", function(self) ShowTooltip(self, self.item) end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b:SetScript("OnClick", function(self)
            local it = self.item
            if self.spellKey then   -- (QoL 0.7.36, UI-39) a spell row of the Ability Scaling table: fold / open it
                ns.StatCalc_ToggleSpell(self.spellKey)
            elseif self.statKey then   -- (QoL 0.7.40, #88) a stat of the Stats tab with rows under it: open / fold it
                ns.StatCalc_ToggleStat(self.statKey)
            elseif it and it.kind == "action" and it.action then
                ns.StatCalc_Action(it.action)
            elseif it and it.kind == "choice" and it.pick then
                ns.StatCalc_PickItem(it.pick, it.slot)
            elseif it and it.kind == "choice" and it.slot then
                ns.StatCalc_SetCompareSlot(it.slot)
            end
        end)
        b:SetScript("OnMouseWheel", function(_, d) if panel and panel.Scroll then panel.Scroll(d) end end)
        btnPool[nBtn] = b
    end
    if b.bg then b.bg:Hide() end   -- (only an action row shows its background)
    b.spellKey = nil               -- (QoL 0.7.36: set again by the spell table for its rows)
    b.statKey = nil                -- (QoL 0.7.40: set again by the Stats grid for a stat that has rows)
    b:Show()
    return b
end

-- (QoL 0.7.36, UI-39) fold or open one spell of the Ability Scaling table ("spell:<item key>"), then draw again
function ns.StatCalc_ToggleSpell(key)
    if InCombat() then return end   -- (V26)
    local c = Cfg(); if not (c and key) then return end
    c.collapsed = c.collapsed or {}
    c.collapsed[key] = (not c.collapsed[key]) and true or nil
    ns.StatCalc_Render()
end

local function Hdr()
    nHdr = nHdr + 1
    local h = hdrPool[nHdr]
    if not h then
        h = CreateFrame("Button", nil, content)
        h:EnableMouse(true)
        if h.RegisterForClicks then h:RegisterForClicks("LeftButtonUp") end
        h.line = h:CreateTexture(nil, "ARTWORK")
        h.line:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 0)
        h.line:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0)
        h.line:SetHeight(1)
        h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h.text:SetPoint("LEFT", h, "LEFT", 0, 1)
        h.text:SetJustifyH("LEFT")
        h:SetScript("OnClick", function(self)
            if InCombat() then return end   -- (V26)
            local c = Cfg(); if not (c and self.key) then return end
            -- (a section folded by default, the Inactive spells, keeps an explicit false once opened)
            if self.defaultFolded then c.collapsed[self.key] = not self.folded
            else c.collapsed[self.key] = (not c.collapsed[self.key]) and true or nil end
            ns.StatCalc_Render()
        end)
        h:SetScript("OnMouseWheel", function(_, d) if panel and panel.Scroll then panel.Scroll(d) end end)
        hdrPool[nHdr] = h
    end
    h:Show()
    return h
end

-- The Spells tab's top row (QoL 0.7.24): the spell data button and the filter icon. Xaya 2026-11-05, her words: "refresh spell data or
-- load spell data should be a button above the spell segments and more clearly clickable / defined. put it as a centered button that is
-- no more than 250px wide"; "Filter tabs should be indicated by a filter icon on the right hand side with "none" by default (therefore
-- showing all)". (Before: All / Offense / Defense buttons across the top, and the data button a dim bar inside the first section.)
local SPELL_BTN_MAX, FILTER_ICON = 250, 20
-- the button: Blizzard's UIPanelButtonTemplate in XayaUI's flat look (core's ns.FlatButton: the theme's button colours and border, the
-- text turning white on hover; Blizzard's own look and highlight when the settings addon's skin is off). Its label and action are the
-- section's action item's (Configure spell data while Spell Math is off, else Refresh spell data), as before.
local function SpellDataButton()
    if panel.spellBtn then return panel.spellBtn end
    local ok, b = pcall(CreateFrame, "Button", nil, content, "UIPanelButtonTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, content) end
    if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp") end
    b:SetScript("OnClick", function(self) if self.item and self.item.action then ns.StatCalc_Action(self.item.action) end end)
    b:SetScript("OnEnter", function(self) ShowTooltip(self, self.item) end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnMouseWheel", function(_, d) if panel and panel.Scroll then panel.Scroll(d) end end)
    if ns.FlatButton then ns.FlatButton(b) end
    panel.spellBtn = b
    return b
end
-- the filter menu: None (shows all), Offense, Defense, Utility; the chosen one is saved (c.spellFilter) and marked
function ns.StatCalc_SetSpellFilter(f)
    if InCombat() then return end   -- (V26)
    local c = Cfg(); if not c then return end
    c.spellFilter = f
    c.spellFilter = CM.FilterOf(c)
    if panel and panel.filterMenu then panel.filterMenu:Hide() end
    if scroll then scroll:SetVerticalScroll(0) end
    ns.StatCalc_Render()
end
local function FilterMenu()
    if panel.filterMenu then return panel.filterMenu end
    local f = CreateFrame("Frame", nil, panel)
    f:SetFrameLevel((panel:GetFrameLevel() or 1) + 20)   -- above the panel's content
    f:EnableMouse(true)
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(f)
    f.edges = {}
    for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0 }, { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
        local e = f:CreateTexture(nil, "BORDER")
        e:SetPoint(pts[1]); e:SetPoint(pts[2])
        if pts[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
        f.edges[i] = e
    end
    f.rows = {}
    for i, fl in ipairs(CM.SPELL_FILTERS) do
        local r = CreateFrame("Button", nil, f)
        r:EnableMouse(true)
        if r.RegisterForClicks then r:RegisterForClicks("LeftButtonUp") end
        r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(r)
        local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(r); hl:SetColorTexture(1, 1, 1, 0.1)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", r, "LEFT", 8, 0); r.text:SetJustifyH("LEFT")
        r.filter, r.label = fl[1], fl[2]
        r.item = { kind = "filter", key = "filter:" .. fl[1], label = fl[2], value = "", tip = { fl[3] } }
        r:SetScript("OnClick", function(self) ns.StatCalc_SetSpellFilter(self.filter) end)
        r:SetScript("OnEnter", function(self) ShowTooltip(self, self.item) end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        f.rows[i] = r
    end
    f:Hide()
    panel.filterMenu = f
    return f
end
-- the icon: a funnel drawn from four flat bars (XayaUI's own drawing, no game art): muted while no filter is on, in the theme's accent
-- colour with a dot when one is; a click opens or closes the menu under it
local function FilterIcon()
    if panel.filterIcon then return panel.filterIcon end
    local b = CreateFrame("Button", nil, content)
    b:EnableMouse(true)
    if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp") end
    b:SetFrameLevel((content:GetFrameLevel() or 1) + 5)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b)
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.15)
    b.parts = {}
    for i, d in ipairs({ { 14, 2, 5 }, { 10, 2, 8 }, { 6, 2, 11 }, { 2, 4, 13 } }) do
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetSize(d[1], d[2]); t:SetPoint("TOP", b, "TOP", 0, -d[3])
        b.parts[i] = t
    end
    b.dot = b:CreateTexture(nil, "OVERLAY"); b.dot:SetSize(5, 5); b.dot:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -1)
    b:SetScript("OnClick", function(self)
        if InCombat() then return end   -- (V26)
        local m = FilterMenu()
        if m:IsShown() then m:Hide() else m:Show(); ns.StatCalc_Render() end
    end)
    b:SetScript("OnEnter", function(self) ShowTooltip(self, self.item) end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnMouseWheel", function(_, d) if panel and panel.Scroll then panel.Scroll(d) end end)
    panel.filterIcon = b
    return b
end

-- the Gear tab's icons of the equipped items: the game's item tooltip on hover, the game's modified click (link in chat, dressing room)
local iconBtns, nIcon = {}, 0
local ICON_SIZE, ICON_CELL = 30, 44
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local function IconBtn()
    nIcon = nIcon + 1
    local b = iconBtns[nIcon]
    if not b then
        b = CreateFrame("Button", nil, content)
        b:EnableMouse(true)
        if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp") end
        b.border = b:CreateTexture(nil, "BACKGROUND"); b.border:SetAllPoints(b)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1); b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
        if b.tex.SetTexCoord then b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.15)
        -- the selected box (QoL 0.7.24; Xaya: "should highlight the box to indicate its selection"). QoL 0.7.28 (Xaya 2026-11-06: "gear
        -- pane request for gear highlight dropped"; REQUEST-LOG #68): the 0.7.24 frame was painted in the selected TAB's background colour
        -- (theme class xui-tab-selected, token tabSelBg), which the class theme makes the class colour x 0.28 (Theme.lua: pal.tabSelBg),
        -- a near-black tint on the panel's dark window, 2 px wide outside the icon: there, but not visible. Now: SEL_EDGE px (thicker
        -- than the 1 px quality border) in the theme's ACCENT colour (Accent(): the bright "accent" token), on the button's top draw
        -- layer (OVERLAY, sublevel 7) over the icon and its quality border, inside the button's edges (nothing under it moves).
        b.selEdges = {}
        local SEL_EDGE = 3
        for i, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 0 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0 }, { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
            local t = b:CreateTexture(nil, "OVERLAY", nil, 7)
            t:SetPoint(e[1], b, e[1], 0, 0); t:SetPoint(e[2], b, e[2], 0, 0)
            if e[3] == 1 then t:SetWidth(SEL_EDGE) else t:SetHeight(SEL_EDGE) end
            t:Hide()
            b.selEdges[i] = t
        end
        b:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            if self.cand then
                -- an item in the bags: the game's tooltip for that bag slot (GameTooltip:SetBagItem, the tooltip's own method, not in the
                -- generated widget docs: INFERENCE, so the item link is the fallback)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local ok = self.bag and GameTooltip.SetBagItem and pcall(GameTooltip.SetBagItem, GameTooltip, self.bag, self.index)
                if not ok and type(self.link) == "string" and GameTooltip.SetHyperlink then pcall(GameTooltip.SetHyperlink, GameTooltip, self.link) end
                GameTooltip:Show()
                return
            end
            if not self.slot then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local ok = GameTooltip.SetInventoryItem and pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", self.slot)
            if not ok and type(self.link) == "string" and GameTooltip.SetHyperlink then pcall(GameTooltip.SetHyperlink, GameTooltip, self.link) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        -- a plain click picks the slot for the comparison (QoL 0.7.14; Xaya: "click-select gear options"); shift or ctrl keeps the
        -- game's own modified click (link in chat, dressing room). IsShiftKeyDown / IsControlKeyDown: globals.md:394, 340.
        b:SetScript("OnClick", function(self)
            local mod = (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown())
            if mod then
                if type(self.link) == "string" and type(HandleModifiedItemClick) == "function" then pcall(HandleModifiedItemClick, self.link) end
            elseif self.cand then
                ns.StatCalc_PickItem(self.link, self.slot)   -- a bag item: picked, or let go when it was picked (QoL 0.7.24)
            elseif self.slot then
                ns.StatCalc_SelectGearSlot(self.slot)   -- an equipped item: selected, or let go when it was (QoL 0.7.24)
            end
        end)
        -- an item dropped on an equipped icon is compared with that slot (plan item 6: "drag and drop")
        b:SetScript("OnReceiveDrag", function(self)
            local ok, kind, id, link = pcall(GetCursorInfo)
            if not ok or kind ~= "item" or not self.slot or self.cand then return end
            local text = (type(link) == "string" and not isSecret(link)) and link or ((type(id) == "number" and not isSecret(id)) and tostring(id) or nil)
            if not text then return end
            if ClearCursor then pcall(ClearCursor) end
            ns.StatCalc_PickItem(text, self.slot, true)
        end)
        b:SetScript("OnMouseWheel", function(_, d) if panel and panel.Scroll then panel.Scroll(d) end end)
        iconBtns[nIcon] = b
    end
    b:Show()
    return b
end

local function Box(key)
    local b = boxes[key]
    if not b then
        local ok, eb = pcall(CreateFrame, "EditBox", nil, content, "InputBoxTemplate")
        if not ok or not eb then eb = CreateFrame("EditBox", nil, content) end
        eb:SetAutoFocus(false)
        if eb.SetFontObject then eb:SetFontObject("GameFontHighlightSmall") end
        eb.key = key
        -- Enter commits the typed value; letting go of the keyboard is core's (V29, gate G-024): KeyFocusGuard with enterLetsGo clears
        -- the focus after this script (core KeyCatch.lua), and installs its own Esc (the box has none of its own: the template's Esc
        -- handler, if InputBoxTemplate carries one in the game, is removed here so core's runs. INFERENCE: not checked against the live
        -- template). Core also lets go on a click outside (GLOBAL_MOUSE_DOWN) and when the panel hides.
        eb:SetScript("OnEnterPressed", function(self) ns.StatCalc_SetInput(self.key, self:GetText()) end)
        eb:SetScript("OnEscapePressed", nil)
        if ns.KeyFocusGuard then
            ns.KeyFocusGuard(eb, { enterLetsGo = true })
        else
            -- (only with a core without KeyFocusGuard; tests/statcalc_keys_run.py fails then) Enter and Esc still let go
            eb:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
            eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        end
        if key == "item" then
            -- an item dropped on the box (dragged from the bags, or carried on the cursor and clicked) is compared at once.
            -- GetCursorInfo (globals.md:158) is documented without returns; "item", itemID, itemLink is the form other UI code
            -- reads. INFERENCE until seen in game.
            local function TakeCursorItem(self)
                local ok, kind, id, link = pcall(GetCursorInfo)
                if not ok or kind ~= "item" then return end
                local text = (type(link) == "string" and not isSecret(link)) and link or ((type(id) == "number" and not isSecret(id)) and tostring(id) or nil)
                if not text then return end
                if ClearCursor then pcall(ClearCursor) end
                self:SetText(text)
                ns.StatCalc_SetInput("item", text)
            end
            eb:SetScript("OnReceiveDrag", TakeCursorItem)
            if eb.GetScript and eb:GetScript("OnMouseUp") and eb.HookScript then eb:HookScript("OnMouseUp", TakeCursorItem)
            else eb:SetScript("OnMouseUp", TakeCursorItem) end
        end
        boxes[key] = eb
        b = eb
    end
    return b
end

-- Panel input: a stat map box ("sv:" + stat key), a What If stat key, "primary", or "item" (the Gear comparison's
-- item: a link or an ID). (QoL 0.7.14: a compared item no longer fills the map's boxes; the Gear tab shows what it changes itself.)
function ns.StatCalc_SetInput(key, text)
    if InCombat() then return end   -- (V26, SC-001) a typed number or a compared item in combat changes nothing and builds nothing
    local c = Cfg(); if not c then return end
    if key == "item" then
        local t = tostring(text or "")
        CM.compareText = (t:gsub("^%s+", ""):gsub("%s+$", ""))
        CM.compareSlot = CM.gearSlot   -- the slot you picked, when the item fits it; else the lower item level of two
        -- (QoL 0.7.24) the item joins the picked ones (up to CM.MAX_COMPARE); an empty box lets them all go, as an empty box did before
        if CM.compareText == "" then CM.compareLinks = {}
        else
            local link = CM.ResolveItemLink(CM.compareText)
            if link then CM.AddCompare(link) end
        end
    elseif key == "primary" then
        local n = math.max(-100000, math.min(100000, math.floor(tonumber(text) or 0)))
        c.whatIfPrimary = (n ~= 0) and n or nil
    elseif key:sub(1, 3) == "sv:" then
        -- the stat map's boxes (QoL 0.7.14): the number itself; what it differs from yours is the What If amount (empty = yours)
        local k = key:sub(4)
        local base, n = CM.svBase and CM.svBase[k], tonumber((tostring(text or ""):gsub(",", "")))
        local d = (num(base) and n) and math.max(-100000, math.min(100000, math.floor(n - base + 0.5))) or 0
        if k == "primary" then c.whatIfPrimary = (d ~= 0) and d or nil
        else c.whatIfStats[k] = (d ~= 0) and d or nil end
    else
        local n = math.max(-100000, math.min(100000, math.floor(tonumber(text) or 0)))
        if key ~= "all" then c.whatIfStats[key] = (n ~= 0) and n or nil end   -- ("all": the All ratings box, gone since QoL 0.7.23)
    end
    ns.StatCalc_Render()
end
-- the equipped item to compare against when two could be replaced (Gear > "Replace instead")
function ns.StatCalc_SetCompareSlot(slot)
    if InCombat() then return end   -- (V26)
    local c = Cfg(); if not c then return end
    CM.compareSlot, CM.gearSlot = slot, slot
    ns.StatCalc_Render()
end
-- the Spells tab's buttons: Configure spell data (turns Spell Math on and reads everything, #377) and Refresh spell data
function ns.StatCalc_Action(action)
    if InCombat() then return end   -- (V26)
    local c = Cfg(); if not c then return end
    if action == "configureSpells" then c.advanced = true end
    if action == "configureSpells" or action == "refreshSpells" then
        -- (QoL 0.7.48, P4) XayaUI Rules' cached spellbook and talent lists (Conditions.lua) are read again. (G-028, V30) through the
        -- model, which owns the Rules tie-in (read once at load and once at the first options-window open): this file never looks it up
        if CM.ForgetRulesLists then CM.ForgetRulesLists() end
        CM.ClearTalents(); CM.ResetSpellRequests()
    end
    ns.StatCalc_Render()
end
-- Gear: a clicked equipped item picks its slot; an item compared before that does not fit the slot is let go. QoL 0.7.24 (Xaya:
-- "clicking it again should deselect it"): a click on the selected one lets it go and clears the comparison.
function ns.StatCalc_SelectGearSlot(slot)
    if InCombat() then return end   -- (V26)
    local c = Cfg(); if not c then return end
    local st = CM.CompareState and CM.CompareState()
    if slot ~= nil and st and st.slot == slot then
        CM.gearSlot, CM.compareSlot, CM.compareText, CM.compareLinks = nil, nil, nil, {}
        if boxes.item then boxes.item:SetText("") end
        ns.StatCalc_Render()
        return
    end
    CM.gearSlot, CM.compareSlot = slot, slot
    local keep = {}
    for _, l in ipairs(CM.compareLinks or {}) do if CM.FitsSlot(l, slot) then keep[#keep + 1] = l end end
    CM.compareLinks = keep
    local link = (CM.compareText or "") ~= "" and CM.ResolveItemLink(CM.compareText) or nil
    if link and not CM.FitsSlot(link, slot) then CM.compareText = nil end
    if boxes.item and CM.compareText == nil then boxes.item:SetText("") end
    ns.StatCalc_Render()
end
-- Gear: compare this item (a link or an ID) with the given slot (a bag item clicked in the list, or an item dropped on an icon).
-- QoL 0.7.24: a bag item clicked again is let go (several can be picked: CM.compareLinks); the box shows the last one picked. add:
-- never let go (a dropped item).
function ns.StatCalc_PickItem(text, slot, add)
    if InCombat() then return end   -- (V26)
    local c = Cfg(); if not c then return end
    local t = tostring(text or "")
    if slot then CM.gearSlot, CM.compareSlot = slot, slot end
    CM.compareLinks = type(CM.compareLinks) == "table" and CM.compareLinks or {}
    local link = CM.ResolveItemLink(t) or t
    local at = CM.InList(CM.compareLinks, link)
    if at and not add then
        table.remove(CM.compareLinks, at)
        if CM.compareText == t or CM.compareText == link then CM.compareText = CM.compareLinks[#CM.compareLinks] end
    else
        CM.AddCompare(link)
        CM.compareText = t
    end
    if boxes.item then boxes.item:SetText(CM.compareText or "") end
    ns.StatCalc_Render()
end

local function Build()
    if panel then return end
    panel = CreateFrame("Frame", "XayaUIStatCalculator", UIParent)
    panel:SetSize(PANEL_W, 400)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) if not Docked() then self:StartMoving() end end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local c = Cfg(); if not c or Docked() then return end
        local x, y = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if num(x) and num(ux) then c.free.x, c.free.y = math.floor(x - ux + 0.5), math.floor(y - uy + 0.5) end
    end)
    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints(panel)
    panel.edges = {}
    for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0 }, { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
        local e = panel:CreateTexture(nil, "BORDER")
        e:SetPoint(pts[1]); e:SetPoint(pts[2])
        if pts[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
        panel.edges[i] = e
    end
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", PAD, -PAD)
    panel.title:SetText("Stat Calculator")   -- Xaya 2026-11-04: the panel's title (the settings page has the same name: Bonus Features > Stat Calculator)
    -- the header (QoL 0.7.40; Xaya 2026-11-06, REQUEST-LOG #91, her words: "name, class, and spec not needed on stat calculator. Instead,
    -- set this section to display currently equipped ilvl and on the right side max ilvl (in bags)"): one line, "Equipped 332.9" on the
    -- left, "Max (bags) 334.6" on the right; a thin rule under it. (Before: the name, the spec and class in the class colour, the item
    -- level with "item level (overall ...)" under it.)
    local hy = PAD + TITLE_H + GUT
    panel.hEq = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.hEq:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -hy); panel.hEq:SetJustifyH("LEFT")
    panel.hMax = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.hMax:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -hy); panel.hMax:SetJustifyH("RIGHT")
    panel.hRule = panel:CreateTexture(nil, "BORDER")
    panel.hRule:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(hy + NAME_H + math.floor(GUT / 2)))
    panel.hRule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -(hy + NAME_H + math.floor(GUT / 2)))
    panel.hRule:SetHeight(1)
    -- the corner grip (B10, #381): drag to resize; the size is remembered and the content reflows to the new width
    panel:SetResizable(true)
    if panel.SetResizeBounds then pcall(panel.SetResizeBounds, panel, MIN_W, MIN_H, MAX_W, MAX_H) end
    local grip = CreateFrame("Button", nil, panel)
    grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel((panel:GetFrameLevel() or 1) + 10)
    grip.xuiEdge = true   -- a corner resize grip sits at the edge on purpose (#351)
    grip.lines = {}   -- six small squares in a corner triangle
    for _, xy in ipairs({ { 2, 2 }, { 6, 2 }, { 10, 2 }, { 2, 6 }, { 6, 6 }, { 2, 10 } }) do
        local d = grip:CreateTexture(nil, "OVERLAY")
        d:SetSize(2, 2)
        d:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -xy[1], xy[2])
        grip.lines[#grip.lines + 1] = d
    end
    grip:SetScript("OnMouseDown", function() panel:StartSizing("BOTTOMRIGHT"); panel.sizing = true end)
    grip:SetScript("OnMouseUp", function()
        panel:StopMovingOrSizing(); panel.sizing = nil
        local c = Cfg(); if not c then return end
        local w, h = panel:GetWidth(), panel:GetHeight()
        -- the width is kept; the height becomes the current mode's (Min or Max) height (QoL 0.7.23)
        if num(w) then c.size = { w = math.floor(math.max(MIN_W, math.min(MAX_W, w)) + 0.5) } end
        if num(h) then
            local hh = math.floor(math.max(MIN_H, math.min(MAX_H, h)) + 0.5)
            if c.sizeMode == "large" then c.heightLarge = hh else c.heightSmall = hh end
        end
        ns.StatCalc_Render()
    end)
    grip:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Drag to resize", 1, 0.82, 0)
        GameTooltip:AddLine("The width is kept; the height becomes the current Min / Max height. Bonus Features > Stat Calculator > Panel: Reset size goes back to the defaults.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    panel.grip = grip
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(24, 24)   -- the template's own size (UIPanelCloseButtonNoScripts, SharedUIPanelTemplates.xml:135, live 12.1.5)
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() ns.StatCalc_SetOpen(false) end)
    -- (QoL 0.7.40, REQUEST-LOG B2: the "Show: % / rating" value mode button, hidden since 0.7.14, is no longer made)
    -- the Min / Max button (QoL 0.7.23; Xaya 2026-11-05: "a min/max window toggle that toggles between two configured sizes -- one
    -- smaller and one larger (NOT full screen, just longer) -- as well as the free resize option in the bottom corner"): in the title
    -- row, a gutter left of the close button (where the hidden value-mode button sat). Max: the larger height; Min: the smaller one.
    local sb = CreateFrame("Button", nil, panel)
    sb:SetSize(40, 18)
    sb:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(22 + GUT), -PAD)
    sb.bg = sb:CreateTexture(nil, "BACKGROUND"); sb.bg:SetAllPoints(sb)
    sb.text = sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); sb.text:SetPoint("CENTER")
    sb:SetScript("OnClick", function() ns.StatCalc_SizeMode() end)
    sb:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local c = Cfg()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine((c and c.sizeMode == "large") and "Smaller" or "Larger", 1, 0.82, 0)
        GameTooltip:AddLine(("Switches between the two heights set in Bonus Features > Stat Calculator > Panel (now %d and %d). Drag the bottom-right corner to resize freely; that sets the current one."):format(
            c and c.heightSmall or 440, c and c.heightLarge or 760), 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    sb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    panel.sizeBtn = sb

    panel.tabs = {}
    local tw = W / #CM.TABS
    for i, t in ipairs(CM.TABS) do
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(tw - 2, 20)
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + (i - 1) * tw, -(PAD + TITLE_H + GUT + NAME_H + GUT))
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.text:SetPoint("CENTER")
        b.key, b.label = t[1], t[2]
        b:SetScript("OnClick", function()
            if InCombat() then return end   -- (V26)
            local c = Cfg(); if not c then return end
            c.tab = t[1]
            if scroll then scroll:SetVerticalScroll(0) end
            ns.StatCalc_Render()
        end)
        panel.tabs[i] = b
    end

    scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", PAD, -(PAD + HEADER))
    scroll:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    scroll:EnableMouseWheel(true)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(W, 10)
    scroll:SetScrollChild(content)
    panel.Scroll = function(delta)
        local maxS = math.max(0, (content:GetHeight() or 0) - (scroll:GetHeight() or 0))
        local v = math.max(0, math.min(maxS, (scroll:GetVerticalScroll() or 0) - delta * 40))
        scroll:SetVerticalScroll(v)
    end
    scroll:SetScript("OnMouseWheel", function(_, d) panel.Scroll(d) end)
    -- a shift-clicked item goes into the Gear tab's item box and is compared at once (post-hook on the game's own link insert, where
    -- Compat.lua says it lives: ChatFrameUtil.InsertLink in 12.x, and the old global ChatEdit_InsertLink, which is a separate copy
    -- that other addons' bags still call; Compat is the only file that may name it). Xaya 2026-11-04: "I can't drop or shift+click
    -- an item into the item comparison". The box takes the link while it has focus, or while the What If tab is shown and no chat
    -- box is open to take it (the Gear tab since QoL 0.7.14; What If before). INFERENCE: not run in game yet.
    local lastLink, lastAt
    local function InsertLink(link)
        -- (gate G-020, V28) the hook stays until /reload: with the panel closed (or the Stat Calculator off) it returns at once, before
        -- any work on the link
        local eb = boxes.item
        if not (eb and eb.xuiUsed and panel and panel:IsShown()) then return end
        if type(link) ~= "string" or isSecret(link) or not link:find("|Hitem:", 1, true) then return end
        local c = Cfg()
        local focused = eb.HasFocus and eb:HasFocus()
        if not focused then
            if not (c and c.tab == "gear") then return end
            local active = ns.Compat and ns.Compat.ActiveChatEditBox and ns.Compat.ActiveChatEditBox()
            if active and active.IsShown and active:IsShown() then return end   -- an open chat box takes the link, as usual
        end
        local now = GetTime and GetTime() or 0
        if link == lastLink and now == lastAt then return end   -- the same click seen through both hooks
        lastLink, lastAt = link, now
        eb:SetText(link)
        ns.StatCalc_SetInput("item", link)
    end
    local hookTargets = ns.Compat and ns.Compat.ChatHookTargets
    if type(hooksecurefunc) == "function" and type(hookTargets) == "function" then
        for _, t in ipairs(hookTargets("InsertLink")) do pcall(hooksecurefunc, t[1], t[2], InsertLink) end
    end
    -- (SC-081 / SC-020) our own frame's show and hide (HookScript on the panel itself, never on a Blizzard frame): the events that matter
    -- only while it is shown (the cooldown read, bags on Gear, talents on Ability Scaling) are listened to then, and let go when it hides
    panel:HookScript("OnShow", function() if OnPanelShown then OnPanelShown() end end)
    panel:HookScript("OnHide", function(self)
        -- (gate G-006) a drag or resize cut off by the hide (combat, the character window closing) ends here: no OnMouseUp / OnDragStop
        -- may come, and a set panel.sizing would stop every later draw from setting the size
        self:StopMovingOrSizing(); self.sizing = nil
        if OnPanelHidden then OnPanelHidden() end
    end)
    panel:Hide()
end

-- (gate U2 round 2, V27 cost) Place() runs on every redraw: the strata is only set when it differs from the one the panel has
local function SetStrata(want)
    if panel:GetFrameStrata() ~= want then panel:SetFrameStrata(want) end
end
local function Place()
    local c = Cfg(); if not c or not panel then return end
    panel:ClearAllPoints()
    local cf = _G.CharacterFrame
    if Docked() then
        -- (gate G-003) docked, the panel sits in the character window's own strata (MEDIUM when it cannot be read), so another of the
        -- game's windows opened over the character window (Group Finder, the bags) is not covered by it. On its own it stays HIGH
        -- (her call on the stand-alone panel is open). INFERENCE: in-game stacking UNVERIFIED IN GAME.
        local st = cf.GetFrameStrata and cf:GetFrameStrata()
        SetStrata((type(st) == "string" and not isSecret(st) and st ~= "") and st or "MEDIUM")
        if c.side == "left" then panel:SetPoint("TOPRIGHT", cf, "TOPLEFT", -GUT, 0)
        else panel:SetPoint("TOPLEFT", cf, "TOPRIGHT", GUT, 0) end
    else
        SetStrata("HIGH")
        panel:SetPoint("CENTER", UIParent, "CENTER", c.free.x or 0, c.free.y or 0)
    end
end

-- one placed element, kept for the layout checks in the tests (x, y from the content's top left, y grows downwards)
local layout
local function Rec(kind, x, y, w, h, text, size) layout[#layout + 1] = { kind = kind, x = x, y = y, w = w, h = h, text = text, size = size } end

local function PlaceFS(f, x, y, w, size, text, col, justify, wrap, kind)
    SetFont(f, size, "")
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
    f:SetWidth(w)
    f:SetJustifyH(justify or "LEFT")
    if f.SetWordWrap then f:SetWordWrap(wrap and true or false) end
    f:SetText(text or "")
    Paint(f, col)
    local h = (wrap and f:GetStringHeight()) or size
    if isSecret(h) or not num(h) or h < size then h = size end
    -- (gate G-010, V27 whole pixels) the game's measured height can be fractional; every next y stays whole. Rounded up (round 2), so
    -- the next row never starts inside a wrapped line's real height (13.4 -> 14)
    h = math.ceil(h)
    Rec(kind or "text", x, y, w, h, text, size)
    layout[#layout].justify = justify or "LEFT"   -- (QoL 0.7.36: the tests read a column's alignment)
    layout[#layout].wrap = wrap and true or false   -- (gate U2 round 2: the tests read which heights were measured)
    return h
end
-- (QoL 0.7.28) a text with line breaks ("T: 1,430\nL: 12.2"): each line its own font string, one under the other; returns the height
local function PlaceLines(x, y, w, size, text, col, justify, kind)
    local h, first = 0, true
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        if not first then h = h + 1 end
        h = h + PlaceFS(FS(), x, y + h, w, size, line, col, justify, true, kind)
        first = false
    end
    return h
end
-- a filled rectangle at x, y (from the content's top left) in a colour; kept as a "fill" record for the tests
local function PlaceTex(x, y, w, h, col, alpha, kind, text)
    local t = Tex()
    t:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
    t:SetSize(math.max(1, w), math.max(1, h))
    t:SetColorTexture(col[1], col[2], col[3], alpha or col[4] or 1)
    Rec(kind or "fill", x, y, math.max(1, w), math.max(1, h), text)
    return t
end

-- The width a text takes on one line at a text size, measured by the game (QoL 0.7.28; in game "Rating (P / %)" wrapped, "DR Thres..."
-- and "Comput..." were cut, because the widths came from a fixed estimate of 0.55 x size per character). FontString:GetUnboundedStringWidth
-- () -> width: uiUnit (SecretWhenAnchoringSecret, widgets.md:1463), with GetStringWidth() (widgets.md:1458) as the fallback, on one hidden
-- font string of the panel in the panel's font. INFERENCE (not documented): a hidden font string measures like a shown one. A missing,
-- secret or zero answer for a non-empty text falls back to the old estimate.
local measureFS
local function TextW(text, size)
    text = tostring(text or "")
    if text == "" then return 0 end
    if not measureFS then
        measureFS = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        measureFS:Hide()
    end
    SetFont(measureFS, size, "")
    if measureFS.SetWordWrap then measureFS:SetWordWrap(false) end
    measureFS:SetText(text)
    local w = measureFS.GetUnboundedStringWidth and measureFS:GetUnboundedStringWidth() or nil
    if not num(w) or (isSecret and isSecret(w)) or w <= 0 then w = measureFS.GetStringWidth and measureFS:GetStringWidth() or nil end
    if not num(w) or (isSecret and isSecret(w)) or w <= 0 then w = #text * size * 0.55 end
    return math.ceil(w) + 1
end
ns.StatCalc_TextW = TextW   -- (tests)
-- the widest word of a text (a column narrower than this would cut that word: the game wraps only at spaces)
local function WordW(text, size)
    local m = 0
    for word in tostring(text or ""):gmatch("%S+") do m = math.max(m, TextW(word, size)) end
    return m
end
-- Column widths that fit `avail` (QoL 0.7.28). Each column c = { min, line, want }: every column gets its min first (the widest word of
-- its title and cells: nothing is cut), then each title on one line (line), then each column's wanted width (its widest cell: want),
-- smallest need first, while there is room; what is left goes to column `rest`. Only when even the mins do not fit (the narrowest panel
-- at the largest text sizes) are the columns scaled down to fit. `levels` (optional, A24 #7) replaces { "line", "want" } for one
-- table: the Stat Weights pane puts "two" (each title on at most two lines) before "line"; every other table passes none.
local FIT_LEVELS = { "line", "want" }
local function FitCols(cols, avail, rest, levels)
    local w, used = {}, 0
    for i, c in ipairs(cols) do w[i] = c.min or 0; used = used + w[i] end
    for _, lvl in ipairs(levels or FIT_LEVELS) do
        local order = {}
        for i, c in ipairs(cols) do
            local need = math.max(0, (c[lvl] or 0) - w[i])
            if need > 0 then order[#order + 1] = { i, need } end
        end
        table.sort(order, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end; return a[1] < b[1] end)
        local short = false
        for _, o in ipairs(order) do
            local give = math.min(o[2], math.max(0, avail - used))
            w[o[1]] = w[o[1]] + give
            used = used + give
            if give < o[2] then short = true end
        end
        if short then break end
    end
    if rest and avail > used then w[rest] = w[rest] + (avail - used); used = avail end
    if used > avail and used > 0 then
        local f = avail / used
        for i = 1, #w do w[i] = w[i] * f end
    end
    for i = 1, #w do w[i] = math.floor(w[i]) end
    return w
end
ns.StatCalc_FitCols = FitCols   -- (tests)

-- The stat grid (QoL 0.7.15; Xaya 2026-11-05: "do multiple columns: for cleaner presentation * Stat | Current Value | Pt Value | etc";
-- before, each line was label | value with the Pt value and the note glued into the value, "+2,671  (1 = 1.00)"). Every Stats-tab
-- section and the Gear comparison's "What it changes" draw their cells at one set of x positions, worked out from the panel's width
-- (the #351 gutter between columns). QoL 0.7.20 (Xaya 2026-11-05: "put the input box on the far right under a new column "Change""):
-- Stat | Rating | Current value | Pt value | (Note) | Change. The box is the last cell of its row, at the content's right edge; Rating
-- shows a rating card's rating as text where the box sat before. The note is a column of its own (between Pt value and Change) once
-- the panel is wide enough for it (drag the corner: content 564 or wider since QoL 0.7.21), else it goes under its line, from the Current
-- value column to the right edge; a line that has only a note puts it on the line itself. A line with no rating lets its name run on
-- over the Rating column. Every cell wraps inside its own column, so nothing overlaps at any width or text size, and nothing is cut.
-- (Replaces the stat map's MapCols of QoL 0.7.14: name | rating box | percent | rating per 1%, #382.)
-- Widths (by the estimate the layout test uses, 0.55 x text size per character, at text size 11): Rating holds "1,287 +1,000"; Current
-- value "22.63% -> 26.22%" and "hidden in combat" (16 characters); Pt value "46.0 / 1%"; the box five digits in its own font. On the
-- default panel (QoL 0.7.20: content 360) that left Stat 86 and a "»" line's name 120; see QoL 0.7.21 below.
-- QoL 0.7.21 (Xaya 2026-11-05: the Rating cell "should show alongside the +/- stat amount"): Rating is 80 wide so "1,287 +1,000"
-- (12 characters, 72.6 by the estimate) fits; the default panel is 450 (content 430), which leaves Stat 112, so "Critical Strike"
-- (90.75) and "» Abilities (per 100)" fit on one line.
-- QoL 0.7.24 (Xaya 2026-11-05: "I did not ask for notes. I gave you explicit column instructions about what I wanted the columns to be";
-- her answer 2026-11-06: "Remove it entirely"): the Note column and every note's text are gone from the grid and its hover. The columns
-- are exactly Stat | Rating | Current value | Pt value | Change; Stat takes the room the Note column had on a wide panel. A detail line
-- whose only content was its note (a "Read: cast any spell to read it" line) is not drawn.
local GRID_RAT, GRID_VAL, GRID_PER, GRID_BOX = 80, 98, 56, 44
-- hasBox false: no line of the tab has a box (the Gear tab), so it has no Rating and no Change column: Current value takes the
-- Rating column's room ("now -> then" fits on one line); Stat and Pt value keep their x, the note runs to the right edge
local GRID_STAT_KEEP = 86   -- QoL 0.7.21: below the default width Rating gives up its room first (down to 36, its 0.7.20 width; "528 +172"
                            -- then wraps inside its cell) so Stat keeps 86 as long as it can and the narrowest panel (340) still fits
-- QoL 0.7.28 (Xaya 2026-11-06, her words: "all currently nested influence callouts should be put into a column of their own for
-- readability and vertical line reduction (e.g. agility influences [ ... ]"; her answers "Names only, values on hover" and, for the
-- "From Agility" / "From Mastery" lines, "Same Influences column"; REQUEST-LOG #66-#67): a sixth column, Influences, between Pt value and
-- Change. The widths are measured like the Stat Weights pane's (TextW, FitCols): every head on one line where the width allows and never
-- cut, then the ratings, values and Pt values on one line; Influences takes the rest after the Stat column has room for its widest word.
-- (The constants above were the fixed widths of QoL 0.7.20 - 0.7.24.)
local INDENT   -- (set below, with the indentation rule)
-- what a line under a card is in the grid: "infl" (a "»" line: what the stat feeds), "feed" (a "From <stat>" line: what feeds it; not
-- "From rating", the card's own rating, which stays a line), else nil (a line of its own: Diminishing returns, Off hand, ...)
local function InflKind(p)
    local l = tostring(p and p.label or "")
    if l:find("^» ") then return "infl", (l:gsub("^» ", "")) end
    local who = l:match("^From (.+)$")
    if who and who ~= "rating" and not who:find("^the item") then return "feed", "from " .. who end
end
ns.StatCalc_InflKind = InflKind   -- (tests)
local function GridCols(hasBox, items, size)
    size = size or 11
    local hs = size - 1
    local function S(t) return { min = WordW(t, hs), line = TextW(t, hs), want = TextW(t, hs) } end
    local spec = { S("Stat"), S("Rating"), S("Current value"), S("Pt value"), S("Modifies") }   -- ("Influences" until QoL 0.7.39, #88)
    local ind = INDENT or 12
    spec[1].min, spec[1].line = spec[1].min + ind, spec[1].line + ind
    local anyR = false
    local function Cells(i, text, sz)
        text = tostring(text or "")
        if text == "" then return end
        spec[i].min = math.max(spec[i].min, WordW(text, sz))
        spec[i].want = math.max(spec[i].want, TextW(text, sz))
    end
    for _, it in ipairs(items or {}) do
        if it.kind == "input" or it.kind == "stat" or it.kind == "rating" then
            spec[1].min = math.max(spec[1].min, ind + WordW(it.label, size))
            if (it.ratingText or "") ~= "" then anyR = true; Cells(2, it.ratingText, size) end
            Cells(3, CM.ValueFor(it, nil), size); Cells(3, it.newValue, size); Cells(4, it.per, size)
            local psz = it.bigPairs and size or size - 1
            for _, p in ipairs(it.pairs or {}) do
                local k, name = InflKind(p)
                if k == "infl" then   -- (QoL 0.7.40, #88: only what the stat modifies is in the column; a "feed" is a row of its own)
                    spec[5].min = math.max(spec[5].min, WordW(name .. ",", psz))   -- (with the comma that follows it)
                    spec[5].want = math.max(spec[5].want, TextW(name .. ",", psz))
                elseif not p.nested then
                    Cells(3, p.value, psz); Cells(3, p.newValue, psz); Cells(4, p.per, psz)
                end
            end
        end
    end
    local g = { box = (hasBox == false) and 0 or math.max(GRID_BOX, TextW("Change", hs)) }
    if not anyR or hasBox == false then spec[2] = { min = 0, line = 0, want = 0 }
    else spec[2].line = math.max(spec[2].line, spec[2].want) end   -- (her 0.7.21 "528 +172" on one line: kept before the other cells)
    spec[4].line = math.max(spec[4].line, spec[4].want)   -- (and "46.0 / 1%": the rating per 1% on one line, #382)
    local gaps = (spec[2].want > 0 and 4 or 3) * GUT + ((g.box > 0) and GUT or 0)
    -- the Influences column's want is not asked for here: what is left is shared after the other columns' wants
    local inflWant = spec[5].want
    spec[5].want = spec[5].line
    local w = FitCols(spec, W - g.box - gaps, 5)
    g.stat, g.rat, g.val, g.per, g.iw = w[1], w[2], w[3], w[4], w[5]
    g.inflWant = inflWant
    g.rx = g.stat + GUT
    g.vx = g.rx + ((g.rat > 0) and (g.rat + GUT) or 0)
    g.px = g.vx + g.val + GUT
    g.ix = g.px + g.per + GUT
    g.label = g.vx - GUT
    g.cx = W - g.box   -- Change: the box, the last cell of its row
    return g
end
ns.StatCalc_GridCols = GridCols   -- (tests: the x positions the cells must sit at)

-- the Gear comparison's columns (QoL 0.7.14): name | equipped | this item | change
local function CmpCols()
    local lw = math.floor(W * 0.30)
    local cw = math.floor((W - lw - 3 * 4) / 3)
    local x1 = lw + 4
    return lw, cw, x1, x1 + cw + 4, x1 + 2 * (cw + 4)
end

-- one line of the grid: its cells at the grid's x positions; returns the line's height
-- o: x0 (indent), label, labelCol, size, rating (a rating card's rating text), value, valueCol, per, perCol, box (the line has a box),
-- boxH, kind (the layout records' prefix: "" for a card's own line, "pair" for a line under it). (No note: QoL 0.7.24.)
local function GridLine(g, y, o)
    local k = o.kind or ""
    local function K(s) return (k == "") and s or (k .. s:sub(1, 1):upper() .. s:sub(2)) end
    local hasR = (o.rating or "") ~= "" and g.rat > 0
    local h = PlaceFS(FS(), o.x0, y, (hasR and g.stat or g.label) - o.x0, o.size, o.label, o.labelCol, "LEFT", true, K("label"))
    local hasV, hasP = (o.value or "") ~= "", (o.per or "") ~= ""
    if o.boxH then h = math.max(h, o.boxH) end
    if hasR then h = math.max(h, PlaceFS(FS(), g.rx, y, g.rat, o.size, o.rating, o.ratingCol, "RIGHT", true, K("rating"))) end
    if hasV or o.newValue then
        local vh = hasV and PlaceFS(FS(), g.vx, y, g.val, o.size, o.value, o.valueCol, "RIGHT", true, K("value")) or o.size
        -- (QoL 0.7.28; Xaya: "input changes should show changed values underneath them in a color change with a +/- before"; her answer
        -- "New value with sign") a typed number's new value, with its sign, under the current value. Bonus 0.6.38: coloured by what it
        -- means (green better / red worse, blue / orange with a XayaUI colour-blind theme, the text colour when the same; ChangeColor)
        if o.newValue then vh = vh + 1 + PlaceFS(FS(), g.vx, y + vh + 1, g.val, o.size, o.newValue, ChangeColor(o.newTone), "RIGHT", true, K("change")) end
        h = math.max(h, vh)
    end
    if hasP then h = math.max(h, PlaceFS(FS(), g.px, y, g.per, o.size, o.per, o.perCol, "RIGHT", true, K("per"))) end
    return h
end

-- the Gear Summary's table (Gear | Character | Elsewhere; QoL 0.7.14): its column head and one row. Shared by the Gear comparison's
-- Side by side (RenderSections) and the Gear Summary inside Character Stats (RenderGrid, QoL 0.7.23). Each returns the y under it.
local function CmpHead(it, y, size, cMuted)
    local lw, cw, x1, x2, x3 = CmpCols()
    local cs = it.cols or {}
    PlaceFS(FS(), x1, y, cw, size - 1, cs[1] or "", cMuted, "RIGHT", false, "colhead")
    PlaceFS(FS(), x2, y, cw, size - 1, cs[2] or "", cMuted, "RIGHT", false, "colhead")
    PlaceFS(FS(), x3, y, cw, size - 1, cs[3] or "", cMuted, "RIGHT", false, "colhead")
    local hb = Btn()   -- hover: where the numbers come from
    hb.item = it
    hb:ClearAllPoints()
    hb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    hb:SetSize(W, size + 1)
    Rec("hit", 0, y, W, size + 1, it.key)
    return y + size + 1
end
local function CmpRow(it, y, size, cText)
    -- (QoL 0.7.15: cells wrap inside their column rather than being cut, and each may carry its own tone)
    local lw, cw, x1, x2, x3 = CmpCols()
    local cs, ct = it.cells or {}, it.cellTones or {}
    local rowH = PlaceFS(FS(), 0, y, lw - 4, size, it.label, it.labelColor or cText, "LEFT", false, "label")
    rowH = math.max(rowH, PlaceFS(FS(), x1, y, cw, size, cs[1] or "", ToneColor(ct[1], cText), "RIGHT", true, "cmpcell"))
    rowH = math.max(rowH, PlaceFS(FS(), x2, y, cw, size, cs[2] or "", ToneColor(ct[2], cText), "RIGHT", true, "cmpcell"))
    rowH = math.max(rowH, PlaceFS(FS(), x3, y, cw, size, cs[3] or "", ToneColor(ct[3] or it.cellTone, cText), "RIGHT", true, "cmpcell"))
    return y + rowH + 1
end

-- a grid section's lines (sec.grid: the stat map's sections, the Gear comparison's "What it changes"); returns the y under them.
-- QoL 0.7.23: Character Stats' headings (kind "subhead": level 1 at x 0, level 2 one indent in) and its Gear Summary table.
-- QoL 0.7.28 (Xaya 2026-11-06, her words: "General Stats is not appropriately flagged as Category-level Stat bucket, nor is Offensive nor
-- Defensive"; her answer: "bucket bar, with the following note: currently indentations are all over the place. be sure to review all
-- elements nested under each bucket and make sure indentations follow sub- and sub-sub- nesting rules"): Primary, General, Offensive and
-- Defensive are bucket bars (a thin band in the theme's accent colour across the pane with the bucket's name on it), and every line's
-- left edge is its nesting depth times ONE step (INDENT): depth 0 the headings (Core Stats, Secondaries, Tertiaries) and the bucket bars,
-- depth 1 a stat (Agility, Health, Attack Power, Critical Strike) and the "Stat" column head over them, depth 2 its lines ("» Attack
-- power", "From Agility", "Off hand"), depth 3 a line nested under one of those (an ability under "» Abilities (their text names Haste)").
-- Before: the level-2 headings sat at 8, the stats at 0 (left of their heading), their lines at 12 and 24.
INDENT = 12
local BUCKET_ALPHA = 0.35   -- the bucket bar's band: the accent colour at this opacity, so its name (body text colour) reads on it
ns.STATCALC_INDENT = INDENT   -- (tests)
local function RenderGrid(c, items, y, hasBox)
    local size = c.fontSize
    local cText = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local cMuted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local short = c.detail == "short"
    local g = GridCols(hasBox, items, size)
    for _, it in ipairs(items) do
        local top = y
        if it.kind == "colhead" and not it.cmp then
            local cs, hs = it.cols or {}, size - 1
            local h = PlaceFS(FS(), INDENT, y, g.stat - INDENT, hs, cs[1] or "", cMuted, "LEFT", true, "colhead")
            if (cs[2] or "") ~= "" and g.rat > 0 then h = math.max(h, PlaceFS(FS(), g.rx, y, g.rat, hs, cs[2], cMuted, "RIGHT", true, "colhead")) end
            h = math.max(h, PlaceFS(FS(), g.vx, y, g.val, hs, cs[3] or "", cMuted, "RIGHT", true, "colhead"))
            h = math.max(h, PlaceFS(FS(), g.px, y, g.per, hs, cs[4] or "", cMuted, "RIGHT", true, "colhead"))
            if (cs[5] or "") ~= "" and g.box > 0 then h = math.max(h, PlaceFS(FS(), g.cx, y, g.box, hs, cs[5], cMuted, "LEFT", true, "colhead")) end
            if (cs[6] or "") ~= "" then h = math.max(h, PlaceFS(FS(), g.ix, y, g.iw, hs, cs[6], cMuted, "LEFT", true, "colhead")) end
            local hb = Btn()   -- hover: what each column holds
            hb.item = it
            hb:ClearAllPoints()
            hb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            hb:SetSize(W, h + 1)
            Rec("hit", 0, y, W, h + 1, it.key)
            y = y + h + 3
        elseif it.kind == "colhead" and it.cmp then
            y = CmpHead(it, y, size, cMuted) + 2
        elseif it.kind == "cmprow" then
            y = CmpRow(it, y, size, cText)
        elseif it.kind == "subhead" then
            -- a heading of the tree: level 1 (Core Stats, Secondaries, Tertiaries, Gear Summary) in the label colour, level 2 (Primary,
            -- General, Offensive, Defensive) one indent in; a little room above each but the first
            local l1 = it.level == 1
            if it ~= items[1] then y = y + (l1 and 4 or 2) end
            if l1 then
                local h = PlaceFS(FS(), 0, y, W, size, it.label, TC("xui-label", "text", { 1, 0.82, 0, 1 }), "LEFT", true, "subhead")
                y = y + h + 3
            else
                -- a bucket bar (depth 0): the band across the pane's width, the bucket's name on it
                local th = TextW(it.label, size - 1)
                local lines = math.max(1, math.ceil(th / math.max(1, W - 8)))
                local bh = lines * (size - 1) + 4
                PlaceTex(0, y, W, bh, Accent(), BUCKET_ALPHA, "bucketbar", it.label)
                PlaceFS(FS(), 4, y + 2, W - 8, size - 1, it.label, cText, "LEFT", true, "subhead")
                y = y + bh + 3
            end
        elseif it.kind == "note" then
            local h = PlaceFS(FS(), 0, y, W, size, it.label, it.minor and cMuted or cText, "LEFT", true, "label")
            y = y + h + 5
        else
            local v, tone = CM.ValueFor(it, nil)
            local boxed = it.kind == "input" and it.input ~= nil
            local boxH = boxed and (size + 6) or nil
            if boxed then
                -- the box: the Change column, the last cell of its row (QoL 0.7.20; it sat under Rating before)
                local eb = Box(it.input)
                eb:ClearAllPoints()
                eb:SetPoint("TOPLEFT", content, "TOPLEFT", g.cx, -y + 2)
                eb:SetSize(g.box, size + 6)
                if not (eb.HasFocus and eb:HasFocus()) then
                    local amt = num(it.amount) and it.amount or 0
                    -- a stat map box holds the number itself (yours, or the one typed); All ratings holds its amount
                    eb:SetText(it.absolute and tostring(math.floor(it.absolute + amt + 0.5)) or (amt ~= 0 and tostring(amt) or ""))
                end
                eb:Show()
                eb.xuiUsed = true
                Rec("input", g.cx, y, g.box, size + 6, it.input, size)
            end
            local h = GridLine(g, y, { x0 = INDENT, label = it.label, labelCol = it.labelColor or (it.minor and cMuted or cText), size = size,
                rating = it.ratingText, ratingCol = cText,
                value = v, valueCol = ToneColor(tone, cText), per = it.per, perCol = cText, box = boxed, boxH = boxH, newValue = it.newValue, newTone = it.newTone })
            -- the lines under it: one size smaller and muted, except a card that asks for full-size ones (#378: "way too tiny")
            local big = it.bigPairs == true
            local psz, pcol = big and size or size - 1, big and cText or cMuted
            -- (QoL 0.7.28) what the stat feeds ("»" lines) and what feeds it ("From <stat>") are names in the Influences column on the card's
            -- own row, comma-separated, wrapping inside the column ("Names only, values on hover"); a line nested under a "»" line goes in
            -- that name's hover. Every other line stays a line of its own under the card (depth 2).
            -- QoL 0.7.40 (Xaya 2026-11-06, REQUEST-LOG #87 / #88, her words: "changes "Modified By" column and "Modifies" columns to
            -- separate the from and applies to elements"; "put the numerical contributions on a row for each stat -- make each stat
            -- collapsible, in which case the rows bundle neatly into the tooltip"; her answers: rows "\"Modified By\" only", default
            -- "Collapsed", columns "Only \"Modifies\" column"): the column holds only what the stat applies to ("»" lines, now headed
            -- Modifies); what feeds it ("From Agility", "From Mastery") is a row under the stat with its number ("from Agility +2,616"),
            -- with the stat's other lines. Each stat with rows folds: folded (the default) only its own row shows, with "+" in the indent
            -- left of its name, and its rows are in its hover (StatCalc_TooltipLines lists every line); a click on the stat opens it
            -- ("-") and the choice is kept per stat (c.statOpen). A typed number's new value shows under a row's value as before.
            local infl, rows, last = {}, {}, nil
            for _, p in ipairs(it.pairs or {}) do
                if (not short or p.short) and not CM.NoteOnly(p) then
                    local k, name = InflKind(p)
                    if k == "infl" then
                        last = { kind = k, name = name, p = p, nested = {} }
                        infl[#infl + 1] = last
                    elseif p.nested and last then
                        last.nested[#last.nested + 1] = p
                    else
                        last = nil
                        rows[#rows + 1] = p
                    end
                end
            end
            local open = c.statOpen[it.key] == true
            if #rows > 0 then
                it.foldable = open and "open" or "folded"
                -- the fold mark: in the indent left of the stat's name (depth 0 of this row; nothing else is drawn there)
                PlaceFS(FS(), 0, y, INDENT, size, open and "-" or "+", cMuted, "LEFT", false, "fold")
            else it.foldable = nil end
            local ih, nameBtns = 0, {}
            if #infl > 0 then
                local fx, fy, lineMax = 0, y, 0
                local sp = math.max(3, TextW(" ", psz) - 1)
                for i, e in ipairs(infl) do
                    local text = e.name .. ((i < #infl) and "," or "")
                    local tw = math.min(g.iw, TextW(text, psz) + 1)
                    if fx > 0 and fx + tw > g.iw then fx = 0; fy = fy + lineMax + 1; lineMax = 0 end
                    local nh = PlaceFS(FS(), g.ix + fx, fy, tw, psz, text, e.p.labelColor or pcol, "LEFT", true, "infl")
                    lineMax = math.max(lineMax, nh)
                    local p = e.p
                    nameBtns[#nameBtns + 1] = { x = g.ix + fx, y = fy, w = tw, h = nh, item = { kind = "infl", key = it.key .. ":" .. tostring(p.label),
                        label = p.label, value = p.value, per = p.per, perPoint = p.perPoint, perText = p.perText, newValue = p.newValue, newTone = p.newTone, tone = p.tone,
                        labelColor = p.labelColor,
                        pairs = e.nested, tip = {} } }
                    fx = fx + tw + sp
                end
                ih = fy + lineMax - y
            end
            y = y + math.max(h, ih) + 2
            local headEnd = y
            for _, p in ipairs(open and rows or {}) do
                local pv = (p.value ~= nil) and tostring(p.value) or ""
                -- (QoL 0.7.40) a contribution reads "from Agility" as in her words (the model's "From ..." with a small f)
                local lbl = tostring(p.label or ""):gsub("^From ", "from ")
                local ph = GridLine(g, y, { x0 = 2 * INDENT, label = lbl, labelCol = p.labelColor or pcol, size = psz, value = pv,
                    valueCol = ToneColor(p.tone, cText), per = p.per, perCol = pcol, kind = "pair", newValue = p.newValue, newTone = p.newTone })
                y = y + ph + 1
            end
            -- the hover (where the numbers come from): the card's row up to the Influences column (a box stays clickable), the lines
            -- under it, and each name in Influences on its own: that line's value, Pt value and, with a typed number, the new value
            local lb = Btn()
            lb.item = it
            if it.foldable then lb.statKey = it.key end   -- (QoL 0.7.40) a click on the stat opens / folds its rows
            lb:ClearAllPoints()
            lb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
            lb:SetSize(g.ix - GUT, headEnd - top)
            Rec("hit", 0, top, g.ix - GUT, headEnd - top, it.key)
            if y > headEnd then
                local pb = Btn()
                pb.item = it
                pb.statKey = lb.statKey   -- (a click on its rows folds them too)
                pb:ClearAllPoints()
                pb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -headEnd)
                pb:SetSize(W, y - headEnd)
                Rec("hit", 0, headEnd, W, y - headEnd, it.key)
            end
            for _, nb in ipairs(nameBtns) do
                local b = Btn()
                b.item = nb.item
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", content, "TOPLEFT", nb.x, -nb.y)
                b:SetSize(nb.w, nb.h)
                if b.SetFrameLevel and lb.GetFrameLevel then b:SetFrameLevel((lb:GetFrameLevel() or 1) + 1) end
                Rec("hit", nb.x, nb.y, nb.w, nb.h, nb.item.key)
            end
            y = y + 4
        end
    end
    return y
end

-- The Stat Weights pane (QoL 0.7.23): Stat | Rating (P / %) | PPP | DR Threshold | T/L Rating | Influences. Influences is a column of
-- its own at every width and text size (SC-102 and A24 #7, below). Every
-- cell wraps inside its column. A row's hover is the whole row: "{stat} increases / decreases {other stat} by {amount}", one line per
-- influence (CM: it.tip).
-- QoL 0.7.28 (Xaya 2026-11-06, her words: "center columns under stat weights and make sure titles do not get clipped; numbers should be
-- left-aligned; T/L rating should be T: # [line break] L: "; her answer "Titles centred over columns"; in game "Rating (P / %)" wrapped
-- and "DR Thres..." was cut at the default width): the widths come from the titles and cells as the game measures them (TextW), not
-- from fixed numbers: every column is at least as wide as the widest word of its title and cells (nothing is cut), then wide enough
-- for its title on one line, then for its widest cell (FitCols); Influences takes the rest (SC-102). Titles are centred over their
-- columns; every cell starts at its column's left edge; the T/L cell is two lines.
local WT_TITLES = { "Stat", "Rating (P / %)", "PPP", "DR Threshold", "T/L Rating", "Influences" }
-- (SC-102; Xaya S1 #36, her exact columns "Stat | Rating (P / %) | PPP | | DR Threshold | T/L Rating | Influences") Influences is the sixth
-- column. (A24 #7, Xaya 2026-11-11, her words: "2 but make sure all headings (top row) are vertically middle-aligned or bottom-aligned
-- and all rows beneath are uniformly vertically aligned amongst themselves"; option 2 was "Influences is always its own column, and
-- titles wrap onto two lines when needed") it is a column at every width and text size: the labeled line under each row (round 2) is
-- gone, and a column title wraps at its spaces where its column is narrower than the title (#60's one-line titles give way in this pane
-- only). It takes the width the other five leave, its names wrap at their spaces, and its cell is the model's text without the leading
-- "Influences: " (the column's title says it). The model still writes that label into it.influences (StatModel.lua); this strips that
-- one leading label only.
local INFL_LABEL = "Influences: "
local function InflText(t)
    t = tostring(t or "")
    if t:sub(1, #INFL_LABEL) == INFL_LABEL then return t:sub(#INFL_LABEL + 1) end
    return t
end
ns.StatCalc_InflText = InflText   -- (tests)
-- (A24 #7, option 2: "titles wrap onto two lines when needed") the narrowest width at which a title wraps onto at most two lines: the
-- best place to break it at a space, measured like TextW (the game wraps at spaces, filling each line first, so at this width the
-- first line takes at least the words before that break and the rest fits the second). A one-word title: its own width.
local function TwoLineW(text, size)
    local words = {}
    for word in tostring(text or ""):gmatch("%S+") do words[#words + 1] = word end
    if #words < 2 then return TextW(text, size) end
    local best
    for k = 1, #words - 1 do
        local wk = math.max(TextW(table.concat(words, " ", 1, k), size), TextW(table.concat(words, " ", k + 1), size))
        if not best or wk < best then best = wk end
    end
    return best
end
local WT_LEVELS = { "two", "line", "want" }
local function WeightCols(items, size)
    size = size or 11
    local hs = size - 1
    local titles = WT_TITLES
    for _, it in ipairs(items or {}) do if it.kind == "weighthead" and type(it.cols) == "table" then titles = it.cols end end
    local spec = {}
    for i = 1, 6 do
        local t = titles[i] or ""
        spec[i] = { min = WordW(t, hs), two = TwoLineW(t, hs), line = TextW(t, hs), want = TextW(t, hs) }
    end
    local function Cell(i, text, sz)
        for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
            spec[i].min = math.max(spec[i].min, WordW(line, sz))
            spec[i].want = math.max(spec[i].want, TextW(line, sz))
        end
    end
    for _, it in ipairs(items or {}) do
        if it.kind ~= "weighthead" then
            Cell(1, it.label, size)
            local cs = it.cells or {}
            for j = 1, 4 do Cell(j + 1, cs[j], size) end
            if it.pppDR then Cell(3, it.pppDR, size - 1) end
            -- (the names wrap at their spaces: only the widest word is a must; the rest of the width goes to this column)
            spec[6].min = math.max(spec[6].min, WordW(InflText(it.influences), size - 1))
        end
    end
    spec[6].want = spec[6].min
    -- (A24 #7) always six columns. FitCols gives every column its widest word first (title and cells: nothing cut), then each title
    -- on at most two lines (her option 2's words), then each title on one line, then each column's widest cell, while there is room;
    -- Influences takes what is left. A title whose column stays narrower than it wraps at its spaces (RenderWeights bottom-aligns the
    -- titles). KNOWN LIMITS, reported to Xaya with the full case list (tests/char_stat_round_run.py section L), what gives there is her
    -- choice and none is built: (1) where the widest words alone do not fit, FitCols scales the columns down and a word can be cut
    -- (with Influences always a column this reaches more widths and text sizes than before); (2) where the widest words fit but not
    -- every title on two lines, a title can wrap onto three lines.
    local g = { titles = titles }
    local w = FitCols(spec, W - 5 * GUT, 6, WT_LEVELS)
    g.w = w
    g.stat, g.rat, g.ppp, g.dr, g.tl = w[1], w[2], w[3], w[4], w[5]
    g.rx = g.stat + GUT
    g.px = g.rx + g.rat + GUT
    g.dx = g.px + g.ppp + GUT
    g.tx = g.dx + g.dr + GUT
    g.ix = g.tx + g.tl + GUT
    g.iw = math.max(0, W - g.ix)
    g.w[6] = g.iw
    g.xs = { 0, g.rx, g.px, g.dx, g.tx, g.ix }
    return g
end
ns.StatCalc_WeightCols = WeightCols   -- (tests)
local function RenderWeights(c, items, y)
    local size = c.fontSize
    local cText = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local cMuted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local g = WeightCols(items, size)
    for _, it in ipairs(items) do
        local top = y
        if it.kind == "weighthead" then
            local cs, hs = it.cols or {}, size - 1
            -- (A24 #7, bottom-aligned: her words allow "middle-aligned or bottom-aligned"; bottom chosen) every title is placed, then
            -- each one shorter than the tallest is moved down by the difference, so all six titles end on the same line. Heights are
            -- whole pixels (PlaceFS rounds up), so every moved y stays whole (V27). One pass of six, only when the pane is drawn.
            local h, placed = 0, {}
            for i = 1, 6 do
                local f = FS()
                local fh = PlaceFS(f, g.xs[i], y, g.w[i], hs, cs[i] or "", cMuted, "CENTER", true, "wcolhead")
                placed[i] = { f = f, h = fh, rec = layout[#layout] }
                h = math.max(h, fh)
            end
            for i = 1, 6 do
                local p = placed[i]
                local dy = h - p.h
                if dy > 0 then
                    p.f:ClearAllPoints()
                    p.f:SetPoint("TOPLEFT", content, "TOPLEFT", g.xs[i], -(y + dy))
                    p.rec.y = y + dy
                end
            end
            local hb = Btn()
            hb.item = it
            hb:ClearAllPoints()
            hb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            hb:SetSize(W, h + 1)
            Rec("hit", 0, y, W, h + 1, it.key)
            y = y + h + 3
        else
            local cs = it.cells or {}
            local h = PlaceFS(FS(), 0, y, g.stat, size, it.label, it.labelColor or cText, "LEFT", true, "wlabel")
            h = math.max(h, PlaceLines(g.rx, y, g.rat, size, cs[1] or "", cText, "LEFT", "wrating"))
            local ph = PlaceLines(g.px, y, g.ppp, size, cs[2] or "", cText, "LEFT", "wppp")
            if it.pppDR then ph = ph + 1 + PlaceFS(FS(), g.px, y + ph + 1, g.ppp, size - 1, it.pppDR, ToneColor("warn", cMuted), "LEFT", true, "wpppdr") end
            h = math.max(h, ph)
            h = math.max(h, PlaceLines(g.dx, y, g.dr, size, cs[3] or "", cText, "LEFT", "wdr"))
            h = math.max(h, PlaceLines(g.tx, y, g.tl, size, cs[4] or "", cText, "LEFT", "wtl"))
            -- (A24 #7) Influences is always on the row, in its column. Every cell of a row is top-aligned at the row's y, and the row
            -- is as tall as its tallest cell: one alignment for every row of the pane.
            h = math.max(h, PlaceFS(FS(), g.ix, y, g.iw, size - 1, InflText(it.influences), cMuted, "LEFT", true, "winfl"))
            y = y + h + 1
            local b = Btn()   -- the whole row hovers: what the stat feeds, in words
            b.item = it
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
            b:SetSize(W, math.max(1, y - top))
            Rec("hit", 0, top, W, y - top, it.key)
            y = y + 4
        end
    end
    return y
end

-- The Ability Scaling tab's spell table (the Spells tab until QoL 0.7.28; QoL 0.7.24; Xaya 2026-11-05: "add columns to help clarity in
-- info displays: Spell Name (spell id underneath) | % PSV (underneath each entry show "1 agility = {value}") | Talent Modifiers"; her
-- answer 2026-11-06: "Fourth column - computed Value"): exactly Spell Name | % PSV | Talent Modifiers | Computed Value. Under the name its
-- "Spell ID: N"; per number of the description: its percent in % PSV with "1 <primary stat> = <value>" under it, and the number itself
-- (38,011) in Computed Value on the same line. Nothing else is drawn in the table (the hover keeps the rest).
-- QoL 0.7.28: (Xaya 2026-11-06: "refresh spell data still present") the section's action item (the Refresh spell data button above the
-- table) is no longer drawn as a row under the head: since 0.7.24 only the plain sections left it out, and this table drew every item
-- that was not a spell as a line, the action item too. (Her "Comput..." cut: no head may be cut) the widths come from the heads and
-- the values as the game measures them (TextW, FitCols): every head fits its column on one line where the width allows, and never
-- loses a word; then the percents and the values fit on one line; Spell Name takes the rest (Talent Modifiers up to 22% of it). Under the
-- percents, one line per other stat that changes the number (Versatility, Mastery: CM SpellItem, her answer "Only stats that change the
-- number"); under the first Computed Value, the new value a typed number gives, with its sign, coloured as on the Stats tab (Bonus
-- 0.6.38: better / worse, ChangeColor; was the accent colour).
-- (QoL 0.7.36; REQUEST-LOG UI-39, Xaya 2026-11-06: "put talent modifiers before % PSV for clarity / spell names should be collapsible
-- and there should be divider lines between each ability to segmenrt more clearly / put the numbers to left-align to be closer to their
-- %PSV calculations") Spell Name | Talent Modifiers | % PSV | Computed Value; a click on a spell's row folds it to its name ("- " open,
-- "+ " folded, as the section heads; every spell open until folded, kept in c.collapsed["spell:<key>"]); a 1 px line between two spells;
-- Computed Value left-aligned. The column widths are worked out as before (by meaning: spec[2] is still % PSV, spec[3] Talent Modifiers).
local SPELL_HEADS = { "Spell Name", "% PSV", "Talent Modifiers", "Computed Value" }
local function SpellCols(size, items)
    local hs = size - 1
    local spec = {}
    for i, t in ipairs(SPELL_HEADS) do spec[i] = { min = WordW(t, hs), line = TextW(t, hs), want = TextW(t, hs) } end
    for _, it in ipairs(items or {}) do
        local r = it.row
        for _, e in ipairs(r and r.entries or {}) do
            spec[4].min = math.max(spec[4].min, TextW(e.value, size), TextW(e.newValue, size))
            spec[4].want = math.max(spec[4].want, spec[4].min)
            spec[2].want = math.max(spec[2].want, TextW(e.pct, size), TextW(e.per, hs))
        end
        for _, sm in ipairs(r and r.statMods or {}) do spec[2].want = math.max(spec[2].want, TextW(sm, hs)) end
    end
    -- heads on one line first, then the percents and values on one line; Spell Name takes the rest, and gives Talent Modifiers what it
    -- has beyond 27% of the content until Talent Modifiers has 22% (their shares before QoL 0.7.28)
    local w = FitCols(spec, W - 3 * GUT, 1)
    local nameKeep, tmWant = math.floor(W * 0.27), math.floor(W * 0.22)
    if w[1] > nameKeep and w[3] < tmWant then
        local move = math.min(w[1] - nameKeep, tmWant - w[3])
        w[1], w[3] = w[1] - move, w[3] + move
    end
    local g = { name = w[1], psv = w[2], tm = w[3], val = w[4] }
    g.tx = g.name + GUT          -- Talent Modifiers right after the name (QoL 0.7.36)
    g.px = g.tx + g.tm + GUT     -- then % PSV
    g.vx = g.px + g.psv + GUT    -- then Computed Value
    return g
end
ns.StatCalc_SpellCols = SpellCols   -- (tests)
local SPELL_HEAD = { kind = "spellhead", key = "spellCols", label = "Columns", value = "", pairs = {}, tip = {
    "Spell Name: the spell, and its spell ID under it.",
    "% PSV: each number in the spell's description as a percent of your attack power (spell power for Intellect specs), and under it what one point of your primary stat adds to it; then the other stats that change the number (Versatility; Mastery where your mastery's own text names the spell or its school).",
    "Talent Modifiers: the talents you picked whose own text names the spell.",
    "Computed Value: the number itself, as the game computes it in the spell's description (durations, distances and counts left out); under the first one, the new value a number typed on the Stats tab gives, with its sign." } }
local function RenderSpells(c, items, y)
    local size = c.fontSize
    local cText = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local cMuted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local g = SpellCols(size, items)
    local hs = size - 1
    local h = PlaceFS(FS(), 0, y, g.name, hs, SPELL_HEADS[1], cMuted, "LEFT", true, "spellhead")
    h = math.max(h, PlaceFS(FS(), g.tx, y, g.tm, hs, SPELL_HEADS[3], cMuted, "LEFT", true, "spellhead"))
    h = math.max(h, PlaceFS(FS(), g.px, y, g.psv, hs, SPELL_HEADS[2], cMuted, "LEFT", true, "spellhead"))
    h = math.max(h, PlaceFS(FS(), g.vx, y, g.val, hs, SPELL_HEADS[4], cMuted, "LEFT", true, "spellhead"))
    local hb = Btn()
    hb.item = SPELL_HEAD
    hb:ClearAllPoints(); hb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y); hb:SetSize(W, h + 1)
    Rec("hit", 0, y, W, h + 1, "spellCols")
    y = y + h + 4
    local cLine = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
    local spellsDrawn = 0
    for _, it in ipairs(items) do
        local top = y
        local folded = false
        if it.kind == "action" then
            -- (QoL 0.7.28) the Configure / Refresh spell data item is the button above the sections: no row here
        elseif it.row then
            local r = it.row
            if spellsDrawn > 0 then   -- the divider between this spell and the one above
                local ln = Tex(); ln:SetColorTexture(cLine[1], cLine[2], cLine[3], 0.6)
                ln:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(y - 3)); ln:SetSize(W, 1)
                Rec("divider", 0, y - 3, W, 1, it.key)
            end
            spellsDrawn = spellsDrawn + 1
            folded = (c.collapsed and c.collapsed["spell:" .. tostring(it.key)]) and true or false
            local hn = PlaceFS(FS(), 0, y, g.name, size, (folded and "+ " or "- ") .. tostring(it.label), it.labelColor or cText, "LEFT", true, "spellname")
            if folded then y = y + hn + 2 else
            hn = hn + 1 + PlaceFS(FS(), 0, y + hn + 1, g.name, hs, r.idText, cMuted, "LEFT", true, "spellid")
            local hm = 0
            for _, e in ipairs(r.entries) do
                local ey = y + hm
                local hp = PlaceFS(FS(), g.px, ey, g.psv, size, e.pct, cText, "LEFT", true, "spellpct")
                if e.per then hp = hp + 1 + PlaceFS(FS(), g.px, ey + hp + 1, g.psv, hs, e.per, cMuted, "LEFT", true, "spellper") end
                local hv = PlaceFS(FS(), g.vx, ey, g.val, size, e.value, cText, "LEFT", true, "spellvalue")
                if e.newValue then hv = hv + 1 + PlaceFS(FS(), g.vx, ey + hv + 1, g.val, size, e.newValue, ChangeColor(e.newTone), "LEFT", true, "spellchange") end
                hm = hm + math.max(hv, hp) + 2
            end
            for i, sm in ipairs(r.statMods or {}) do
                local fs = FS()
                local sh = PlaceFS(fs, g.px, y + hm, g.psv, hs, sm, cMuted, "LEFT", true, "spellstat")
                -- (Bonus 0.6.38, "Yes, everywhere") the stat's name ("Versatility" of "Versatility: +2.61%") in the stat's colour, the
                -- number after it as before: a colour code around the name only (the game draws no width for the code; the layout above
                -- measured the plain text)
                local sc = r.statModColors and r.statModColors[i]
                local name, rest = tostring(sm):match("^([^:]+)(:.*)$")
                if sc and name then
                    fs:SetText(("|cff%02x%02x%02x%s|r%s"):format(math.floor(sc[1] * 255 + 0.5), math.floor(sc[2] * 255 + 0.5), math.floor(sc[3] * 255 + 0.5), name, rest))
                end
                hm = hm + sh + 1
            end
            local mods = (#(r.mods or {}) > 0) and table.concat(r.mods, ", ") or (r.notPicked and "" or "none")
            local ht = 0
            if mods ~= "" then ht = PlaceFS(FS(), g.tx, y, g.tm, size, mods, (#r.mods > 0) and ToneColor("good", cText) or cMuted, "LEFT", true, "spellmods") end
            y = y + math.max(hn, hm, ht) + 2
            end
        else
            -- a note (spells without numbers, still loading, none in this filter): its label left, its value right
            local v = it.value or ""
            local lw = (v ~= "") and math.floor(W * 0.5) or W
            local lh = PlaceFS(FS(), 0, y, lw - ((v ~= "") and 4 or 0), size, it.label, it.minor and cMuted or cText, "LEFT", true, "label")
            local vh = (v ~= "") and PlaceFS(FS(), lw, y, W - lw, size, v, ToneColor(it.tone, cMuted), "RIGHT", true, "value") or 0
            y = y + math.max(lh, vh) + 1
        end
        if it.kind ~= "action" then
            local b = Btn()
            b.item = it
            if it.row then b.spellKey = "spell:" .. tostring(it.key) end   -- (QoL 0.7.36) a click folds / opens the spell
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top); b:SetSize(W, math.max(1, y - top))
            Rec("hit", 0, top, W, y - top, it.key)
            y = y + 4
        end
    end
    return y
end

-- The Gear tab's Changes table (QoL 0.7.24): Stat | Pt value | Equipped | each picked item. Widths: Pt value holds "46.0 / 1%" (9.5
-- characters at the text size), each item column eight characters ("+12,345", "T 12,345"), Stat 22% of the content (at least 64).
-- DECISION (the limit): up to 3 items are picked (CM.MAX_COMPARE); as many item columns are drawn as fit at the panel's width and text
-- size (3 at the default 450 panel up to text size 12; 2 at the narrowest panel or a larger text), never fewer than one; a line under
-- the head says how many more are picked and that a wider panel shows them. Every cell wraps in its column; a cell's change (or the
-- lost rating) is a second, smaller line under it.
-- QoL 0.7.40 (Xaya 2026-11-06, REQUEST-LOG #90: "+/- signs should be in () to the right of the compared values -- set the number values
-- to left-align to make space"): every number starts at its column's left edge, and an item's difference from the equipped one follows
-- it on the same line in brackets, "1,405 (-12)" (it was the second line under the number). need: the widest "number (difference)" of the
-- table as the game measures it (TextW); a column is at least that wide where the panel allows, so fewer item columns may fit side by
-- side (the line under the head says how many more are picked). Only where even one column is narrower than that (the narrowest panel at
-- a large text size) does a difference go under its number. Other second lines (DR threshold's "crosses ...", True / lost's "L ...")
-- stay under the number.
local function MultiCols(size, nv, need, needEq)
    local g = { pt = math.ceil(size * 0.55 * 9.5), stat = math.max(64, math.floor(W * 0.22)) }
    local minCol = math.max(math.ceil(size * 0.55 * 8), need or 0)
    local avail = W - g.stat - g.pt - 2 * GUT
    if needEq then
        -- (QoL 0.7.40) the Equipped column has no difference beside its numbers: it takes only what they need (at most an item
        -- column's width), so the room goes to the item columns
        local eq = math.min(minCol, math.max(needEq, math.ceil(size * 0.55 * 5)))
        local fitItems = math.max(1, math.floor((avail - eq) / (minCol + GUT)))
        g.n = math.max(1, math.min(nv, 1 + fitItems))
        local items = g.n - 1
        g.col1 = eq
        g.col = (items > 0) and math.min(math.max(120, need or 0), math.floor((avail - eq - items * GUT) / items)) or eq
    else
        local fit = math.max(2, math.floor((avail + GUT) / (minCol + GUT)))
        g.n = math.max(1, math.min(nv, fit))
        g.col = math.min(math.max(120, need or 0), math.floor((avail - (g.n - 1) * GUT) / g.n))
        g.col1 = g.col
    end
    g.px = g.stat + GUT
    g.vx = g.px + g.pt + GUT
    g.CX = function(i) if i == 1 then return g.vx end; return g.vx + g.col1 + GUT + (i - 2) * (g.col + GUT) end
    g.CW = function(i) return (i == 1) and g.col1 or g.col end
    return g
end
ns.StatCalc_MultiCols = MultiCols   -- (tests)
local function RenderMulti(c, items, y)
    local size = c.fontSize
    local cText = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local cMuted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local cLabel = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    local nv = 1
    for _, it in ipairs(items) do if it.kind == "mhead" then nv = math.max(1, #(it.cols or {}) - 2) end end
    -- (QoL 0.7.40, #90) the widest number with its difference beside it, measured in the font the cells use
    local need, needEq, space = 0, 0, TextW(" ", size)
    local function DiffText(d) return "(" .. tostring(d) .. ")" end
    for _, it in ipairs(items) do
        if it.kind == "mrow" then
            local lsz = it.sub and (size - 1) or size
            for i, txt in pairs(it.cells or {}) do
                local d = it.diffs and it.diffs[i]
                local w = TextW(tostring(txt), lsz) + (d and (space + TextW(DiffText(d), lsz)) or 0)
                if i == 1 then needEq = math.max(needEq, w) else need = math.max(need, w) end
            end
        end
    end
    local g = MultiCols(size, nv, need, needEq)
    local CX, CW = g.CX, g.CW
    local function Hover(it, top, h)
        local b = Btn()
        b.item = it
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top); b:SetSize(W, math.max(1, h))
        Rec("hit", 0, top, W, h, it.key)
    end
    for _, it in ipairs(items) do
        local top = y
        if it.kind == "mhead" then
            local hs, cs = size - 1, it.cols or {}
            local h = PlaceFS(FS(), 0, y, g.stat, hs, cs[1] or "", cMuted, "LEFT", true, "mhead")
            h = math.max(h, PlaceFS(FS(), g.px, y, g.pt, hs, cs[2] or "", cMuted, "RIGHT", true, "mhead"))
            for i = 1, g.n do
                h = math.max(h, PlaceFS(FS(), CX(i), y, CW(i), hs, cs[i + 2] or "", (it.colColors and it.colColors[i + 2]) or cMuted, "RIGHT", true, "mhead"))
            end
            Hover(it, top, h + 1)
            y = y + h + 3
            if nv > g.n then
                y = y + PlaceFS(FS(), 0, y, W, hs, ("%d more picked: drag the panel's corner wider (or choose a smaller text size) to see them side by side."):format(nv - g.n),
                    ToneColor("warn", cMuted), "LEFT", true, "mmore") + 3
            end
        elseif it.kind == "msubhead" then
            y = y + 4
            local h = PlaceFS(FS(), 0, y, W, size, it.label, cLabel, "LEFT", true, "msubhead")
            Hover(it, y, h)
            y = y + h + 3
        elseif it.kind == "mrow" then
            -- (it.sub: a line under the one above, one indent in; 2: a line nested under that one, two indents in)
            local x0, lsz = (it.sub == 2 and 16) or (it.sub and 8) or 0, it.sub and (size - 1) or size
            local h = PlaceFS(FS(), x0, y, g.stat - x0, lsz, it.label, it.labelColor or (it.sub and cMuted or cText), "LEFT", true, "mlabel")
            if (it.per or "") ~= "" then h = math.max(h, PlaceFS(FS(), g.px, y, g.pt, lsz, it.per, cMuted, "RIGHT", true, "mper")) end
            for i = 1, g.n do
                local txt = it.cells and it.cells[i]
                if txt ~= nil then
                    -- (QoL 0.7.40, #90) the number from the column's left edge, as wide as it is (the whole column when it wraps), and its
                    -- difference in brackets right after it on the same line, in the better / worse colour
                    local t, cw = tostring(txt), CW(i)
                    local d = it.diffs and it.diffs[i]
                    local tw = math.min(cw, TextW(t, lsz))
                    local dt = d and DiffText(d) or nil
                    local dw = dt and TextW(dt, lsz) or 0
                    local inline = dt and (tw + space + dw <= cw)
                    local ch = PlaceFS(FS(), CX(i), y, inline and tw or cw, lsz, t, ToneColor((it.cellTones and it.cellTones[i]) or it.tone, cText), "LEFT", true, "mcell")
                    if dt then
                        local dc = ToneColor(it.diffTones and it.diffTones[i], cMuted)
                        if inline then ch = math.max(ch, PlaceFS(FS(), CX(i) + tw + space, y, cw - tw - space, lsz, dt, dc, "LEFT", false, "mdiff"))
                        else ch = ch + 1 + PlaceFS(FS(), CX(i), y + ch + 1, cw, lsz, dt, dc, "LEFT", true, "mdiff") end   -- (too narrow: under it)
                    end
                    local sub = it.subs and it.subs[i]
                    if sub then ch = ch + 1 + PlaceFS(FS(), CX(i), y + ch + 1, cw, size - 1, sub, ToneColor(it.subTones and it.subTones[i], cMuted), "LEFT", true, "msub") end
                    h = math.max(h, ch)
                end
            end
            y = y + h + 2
            Hover(it, top, y - top)
        else
            local v = it.value or ""
            local h = PlaceFS(FS(), 0, y, W, size - 1, it.label .. ((v ~= "") and (": " .. v) or ""), ToneColor(it.tone, it.minor and cMuted or cText), "LEFT", true, "mnote")
            y = y + h + 3
            if #(it.tip or {}) > 0 then Hover(it, top, y - top) end
        end
    end
    return y
end

-- The Gear Summary (QoL 0.7.28; Xaya 2026-11-06, her words: "Gear Summary should be at the top of the pane in a prettified graphic of
-- sorts"; her answer: "provide all three visual options this round for me to consider; volunteer more if possible"): the Stats tab's
-- first section, drawn in the style chosen on the settings page (Panel > Layout > Gear Summary style; CM.GEAR_SUM_STYLES):
--   Split bars (the default; DECISION, the first design she was shown): one bar per stat in its colour, as long as the character's
--     rating (the longest bar fills the room), the part from gear solid, the part from elsewhere lighter; "544 (gear 489 +55)" at its end;
--   Stat tiles: a tile per stat, its name in its colour, the total large, "gear 489" and "+55" small under it; tiles wrap to more rows;
--   One stacked bar: one bar split by each stat's share of the ratings listed, in the stats' colours; a legend "Crit 544 (489 +55)";
--   Columns (volunteered): one upright column per stat, gear solid at the bottom, elsewhere lighter on top, the total above, the name under;
--   Gear share (volunteered): one full-width bar per stat, the gear part's share solid, the rest lighter, "90% gear (489 of 544)";
--   Table: the table as before (Gear | Character | Elsewhere).
-- Only flat textures and font strings (no art files), the theme's colours and the stat colours (CM.STAT_COLORS). A stat the game hides
-- right now (in combat) and the empty sockets are a line under the graphic. Each stat hovers with its three numbers.
local GS_LIGHT = 0.4   -- the lighter part (elsewhere): the stat colour at this opacity
local function SBig(v) return ((v or 0) >= 0 and "+" or "") .. CM.Big(v or 0) end
local function RenderGearSum(c, sec, y)
    local size = c.fontSize
    local cText = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local cMuted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local style = sec.style or CM.GEAR_SUM_DEFAULT
    local head, sockets, shown, hidden = nil, nil, {}, {}
    for _, it in ipairs(sec.items) do
        if it.kind == "colhead" then head = it
        elseif it.sockets then sockets = it
        elseif it.stat then
            if it.hidden or not num(it.char) then hidden[#hidden + 1] = it else shown[#shown + 1] = it end
        end
    end
    local function Hover(it, x, top, w, h)
        local b = Btn()
        b.item = it
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", content, "TOPLEFT", x, -top); b:SetSize(math.max(1, w), math.max(1, h))
        Rec("hit", x, top, math.max(1, w), math.max(1, h), it.key)
    end
    local function Col(r) return r.labelColor or cText end
    local function Share(r) if r.char <= 0 then return 1 end; return math.min(1, math.max(0, r.gear / r.char)) end
    if style == "table" then
        if head then y = CmpHead(head, y, size, cMuted) + 2 end
        for _, it in ipairs(sec.items) do if it.kind == "cmprow" then y = CmpRow(it, y, size, cText) end end
        return y
    end
    local maxC = 0
    for _, r in ipairs(shown) do maxC = math.max(maxC, r.char) end
    if style == "bars" or style == "share" then
        local nameW = 0
        for _, r in ipairs(shown) do nameW = math.max(nameW, TextW(r.label, size)) end
        nameW = math.min(nameW, math.floor(W * 0.4))
        local function Nums(r)
            if style == "share" then return ("%d%% gear (%s of %s)"):format(math.floor(Share(r) * 100 + 0.5), CM.Big(r.gear), CM.Big(r.char)) end
            return ("%s (gear %s%s)"):format(CM.Big(r.char), CM.Big(r.gear), (r.diff or 0) ~= 0 and (" " .. SBig(r.diff)) or "")
        end
        local numW = 0
        for _, r in ipairs(shown) do numW = math.max(numW, TextW(Nums(r), size - 1)) end
        local bx = nameW + GUT
        local barMax = W - bx - GUT - numW
        local under = barMax < 40   -- too narrow for the numbers beside the bar: they go under it
        if under then barMax = W - bx end
        local bh = math.max(6, size - 2)
        for _, r in ipairs(shown) do
            local top = y
            local lh = PlaceFS(FS(), 0, y, nameW, size, r.label, Col(r), "LEFT", true, "gslabel")
            local len = barMax
            if style == "bars" then len = (maxC > 0) and math.max(1, math.floor(barMax * r.char / maxC)) or 1 end
            local solid = math.floor(len * Share(r) + 0.5)
            local by = y + math.floor((size - bh) / 2)
            if solid > 0 then PlaceTex(bx, by, solid, bh, Col(r), 1, "gsbar", r.label) end
            if len - solid > 0 then PlaceTex(bx + solid, by, len - solid, bh, Col(r), GS_LIGHT, "gsbar", r.label) end
            local nh
            if under then nh = size + 1 + PlaceFS(FS(), bx, y + size + 1, W - bx, size - 1, Nums(r), cMuted, "LEFT", true, "gsnum")
            else
                local nx = bx + len + GUT
                nh = PlaceFS(FS(), nx, y, W - nx, size - 1, Nums(r), cMuted, "LEFT", true, "gsnum")
            end
            y = y + math.max(lh, nh, size) + 3
            Hover(r, 0, top, W, y - top)
        end
    elseif style == "tiles" then
        local pad, tw = 4, 0
        local function Diff(r) return SBig(r.diff or 0) end
        for _, r in ipairs(shown) do
            tw = math.max(tw, TextW(r.label, size - 1), TextW(CM.Big(r.char), size + 4), TextW("gear " .. CM.Big(r.gear), size - 2), TextW(Diff(r), size - 2))
        end
        tw = math.min(W, tw + 2 * pad)
        local per = math.max(1, math.floor((W + GUT) / (tw + GUT)))
        local th = pad + (size - 1) + 2 + (size + 4) + 2 + (size - 2) + 1 + (size - 2) + pad
        local bg = TC("xui-pane", "bg", { 0.04, 0.04, 0.04, 1 })
        for i, r in ipairs(shown) do
            local col, row = (i - 1) % per, math.floor((i - 1) / per)
            local x, ty = col * (tw + GUT), y + row * (th + GUT)
            PlaceTex(x, ty, tw, th, bg, 0.9, "gstile", r.label)
            local ly = ty + pad
            ly = ly + PlaceFS(FS(), x + pad, ly, tw - 2 * pad, size - 1, r.label, Col(r), "CENTER", true, "gstname") + 2
            ly = ly + PlaceFS(FS(), x + pad, ly, tw - 2 * pad, size + 4, CM.Big(r.char), cText, "CENTER", true, "gsttotal") + 2
            ly = ly + PlaceFS(FS(), x + pad, ly, tw - 2 * pad, size - 2, "gear " .. CM.Big(r.gear), cMuted, "CENTER", true, "gstgear") + 1
            PlaceFS(FS(), x + pad, ly, tw - 2 * pad, size - 2, Diff(r), cMuted, "CENTER", true, "gstdiff")
            Hover(r, x, ty, tw, th)
        end
        if #shown > 0 then y = y + math.ceil(#shown / per) * (th + GUT) end
    elseif style == "stacked" then
        local total = 0
        for _, r in ipairs(shown) do total = total + math.max(0, r.char) end
        if total > 0 then
            local bh = size + 4
            local x = 0
            local list = {}
            for _, r in ipairs(shown) do if r.char > 0 then list[#list + 1] = r end end
            for i, r in ipairs(list) do
                local w = (i == #list) and (W - x) or math.floor(W * r.char / total + 0.5)
                if w > 0 then PlaceTex(x, y, w, bh, Col(r), 1, "gsseg", r.short) end
                x = x + w
            end
            if head then Hover(head, 0, y, W, bh) end
            y = y + bh + 4
            local lx, sw = 0, math.max(6, size - 3)
            for _, r in ipairs(list) do
                local text = ("%s %s (%s %s)"):format(r.short, CM.Big(r.char), CM.Big(r.gear), SBig(r.diff or 0))
                local tw = math.min(TextW(text, size - 1), W - sw - 3)
                local ew = sw + 3 + tw
                if lx > 0 and lx + ew > W then lx = 0; y = y + size + 3 end
                PlaceTex(lx, y + math.floor((size - 1 - sw) / 2), sw, sw, Col(r), 1, "gsswatch", r.short)
                PlaceFS(FS(), lx + sw + 3, y, tw, size - 1, text, Col(r), "LEFT", true, "gslegend")
                Hover(r, lx, y, ew, size)
                lx = lx + ew + GUT
            end
            y = y + size + 3
        end
    elseif style == "columns" then
        local n = #shown
        if n > 0 then
            local cw = 16
            for _, r in ipairs(shown) do cw = math.max(cw, TextW(r.short, size - 1), TextW(CM.Big(r.char), size - 1)) end
            local per = math.max(1, math.min(n, math.floor((W + GUT) / (cw + GUT))))
            local slot = math.floor(W / per)
            local ch = 4 * size   -- the chart's height
            local rowH = (size - 1) + 2 + ch + 2 + (size - 1) + 4
            for i, r in ipairs(shown) do
                local col, row = (i - 1) % per, math.floor((i - 1) / per)
                local sx, ty = col * slot, y + row * rowH
                PlaceFS(FS(), sx, ty, slot, size - 1, CM.Big(r.char), cText, "CENTER", true, "gsctotal")
                local bw = math.max(4, math.min(cw, slot - 6))
                local bxx = sx + math.floor((slot - bw) / 2)
                local bTop = ty + (size - 1) + 2
                local hgt = (maxC > 0) and math.max(1, math.floor(ch * r.char / maxC)) or 1
                local solid = math.floor(hgt * Share(r) + 0.5)
                if hgt - solid > 0 then PlaceTex(bxx, bTop + ch - hgt, bw, hgt - solid, Col(r), GS_LIGHT, "gscol", r.short) end
                if solid > 0 then PlaceTex(bxx, bTop + ch - solid, bw, solid, Col(r), 1, "gscol", r.short) end
                PlaceFS(FS(), sx, bTop + ch + 2, slot, size - 1, r.short, Col(r), "CENTER", true, "gscname")
                Hover(r, sx, ty, slot, rowH - 4)
            end
            y = y + math.ceil(n / per) * rowH
        end
    end
    for _, r in ipairs(hidden) do
        y = y + PlaceFS(FS(), 0, y, W, size - 1, r.label .. ": " .. tostring((r.cells and r.cells[2]) or ""), cMuted, "LEFT", true, "gshidden") + 2
    end
    if sockets then
        y = y + PlaceFS(FS(), 0, y, W, size - 1, "Empty sockets: " .. tostring(sockets.sockets), ToneColor("warn", cText), "LEFT", true, "gssockets") + 2
    end
    return y
end

-- detail tabs: sections with headers; a grid section draws its lines in columns (RenderGrid), any other each line as label | value
-- with its pairs under it
local function RenderSections(c, m, tab, y0)
    local size = c.fontSize
    local cText = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local cMuted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local cLabel = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    local cLine = TC("xui-window", "border", { 0.3, 0.3, 0.3, 1 })
    local short = c.detail == "short"
    local y = y0 or 0
    -- the grid's Rating and Change (box) columns exist when a grid line of this tab has a box (one set of columns per tab)
    local gridBox = false
    for _, sec in ipairs(m.sections) do
        if sec.tab == tab and sec.grid then
            for _, it in ipairs(sec.items) do if it.kind == "input" then gridBox = true end end
        end
    end
    for _, sec in ipairs(m.sections) do
        if sec.tab == tab and #sec.items > 0 then
            if y > (y0 or 0) then y = y + 6 end
            local folded = c.collapsed[sec.key]
            if folded == nil then folded = sec.defaultFolded == true end
            local h = Hdr()
            h.key, h.folded, h.defaultFolded = sec.key, folded, sec.defaultFolded == true
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            h:SetSize(W, size + 7)
            SetFont(h.text, size + 1, "")
            h.text:SetText((folded and "+ " or "- ") .. sec.title)
            Paint(h.text, cLabel)
            h.line:SetColorTexture(cLine[1], cLine[2], cLine[3], 0.8)
            Rec("header", 0, y, W, size + 7, (folded and "+ " or "- ") .. sec.title, size + 1)
            y = y + size + 9
            if not folded and sec.gearsum then
                y = RenderGearSum(c, sec, y)
            elseif not folded and sec.weights then
                y = RenderWeights(c, sec.items, y)
            elseif not folded and sec.spells then
                y = RenderSpells(c, sec.items, y)
            elseif not folded and sec.multi then
                y = RenderMulti(c, sec.items, y)
            elseif not folded and sec.grid then
                y = RenderGrid(c, sec.items, y, gridBox)
            elseif not folded then
                -- (QoL 0.7.24) a section's action item (Configure / Refresh spell data) is drawn as the button above the sections
                local list = {}
                for _, it in ipairs(sec.items) do if it.kind ~= "action" then list[#list + 1] = it end end
                for _, it in ipairs(list) do
                    local top = y
                    local v, tone = CM.ValueFor(it, nil)   -- (QoL 0.7.40, B2: no value modes)
                    local rowH
                    if it.kind == "icons" then
                        local cols = math.max(1, math.floor(W / ICON_CELL))
                        local cw = W / cols
                        local rowStep = ICON_SIZE + size + 4
                        for i, ic in ipairs(it.icons or {}) do
                            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
                            local cx = math.floor(col * cw)
                            local x, yy = math.floor(col * cw + (cw - ICON_SIZE) / 2), y + row * rowStep
                            local b = IconBtn()
                            b.slot, b.link, b.label = ic.slot, ic.link, ic.label
                            b.cand, b.bag, b.index = ic.cand, ic.bag, ic.index
                            b:ClearAllPoints()
                            b:SetPoint("TOPLEFT", content, "TOPLEFT", x, -yy)
                            b:SetSize(ICON_SIZE, ICON_SIZE)
                            b.tex:SetTexture(ic.tex or QUESTION_MARK)
                            local bc = ic.color or cLine
                            b.border:SetColorTexture(bc[1], bc[2], bc[3], 1)
                            -- the selected box: the slot being compared, a picked bag item (QoL 0.7.24; QoL 0.7.28: a 3 px frame in the
                            -- theme's accent colour over the icon's edges, see IconBtn). The quality border stays.
                            local acc = Accent()   -- (QoL 0.7.28: was the selected tab's dark background colour)
                            for _, e in ipairs(b.selEdges or {}) do
                                if ic.selected then e:SetColorTexture(acc[1], acc[2], acc[3], 1); e:Show() else e:Hide() end
                            end
                            b.selected = ic.selected == true
                            Rec("icon", x, yy, ICON_SIZE, ICON_SIZE, ic.label)
                            PlaceFS(FS(), cx, yy + ICON_SIZE + 3, math.floor(cw), size - 1, ic.ilvl and tostring(math.floor(ic.ilvl + 0.5)) or "",
                                ic.color or cText, "CENTER", false, "iconText")
                        end
                        y = y + math.ceil(#(it.icons or {}) / cols) * rowStep
                    elseif it.kind == "wide" then
                        rowH = PlaceFS(FS(), 0, y, W, size, it.label, cText, "LEFT", false, "label")
                        y = y + rowH + 1
                        rowH = PlaceFS(FS(), 6, y, W - 6, size - 1, v, ToneColor(tone, cMuted), "LEFT", true, "wide")
                        y = y + rowH + 1
                    elseif it.kind == "colhead" and it.cmp then
                        y = CmpHead(it, y, size, cMuted)
                    elseif it.kind == "cmprow" then
                        y = CmpRow(it, y, size, cText)
                    elseif it.kind == "input" then
                        local lw, bw = math.floor(W * 0.36), 64
                        rowH = PlaceFS(FS(), 0, y, lw, size, it.label, cText, "LEFT", false, "label")
                        local eb = Box(it.input)
                        eb:ClearAllPoints()
                        eb:SetPoint("TOPLEFT", content, "TOPLEFT", lw + GUT, -y + 2)
                        local ew = it.input == "item" and (W - lw - GUT) or bw
                        eb:SetSize(ew, size + 6)
                        if not (eb.HasFocus and eb:HasFocus()) then
                            if it.input == "item" then eb:SetText(it.text or "")
                            elseif it.absolute then   -- the stat map's boxes hold the number itself (yours, or the one typed)
                                eb:SetText(tostring(math.floor(it.absolute + (num(it.amount) and it.amount or 0) + 0.5)))
                            else eb:SetText((num(it.amount) and it.amount ~= 0) and tostring(it.amount) or "") end
                        end
                        eb:Show()
                        eb.xuiUsed = true
                        Rec("input", lw + GUT, y, ew, size + 6, it.input, size)
                        if it.input ~= "item" then
                            local vx = lw + GUT + bw + GUT
                            local vh = PlaceFS(FS(), vx, y, W - vx, size, v, ToneColor(tone, cText), "RIGHT", true, "value")
                            rowH = math.max(rowH, vh)
                        end
                        local lb = Btn()   -- hover on the label: what the box does
                        lb.item = it
                        lb:ClearAllPoints()
                        lb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                        lb:SetSize(lw, size + 6)
                        Rec("hit", 0, y, lw, size + 6, it.key)
                        y = y + math.max(rowH, size + 6) + 2
                    elseif v == nil or v == "" then
                        -- a line with no value (a spell: its name and ID, #380) uses the whole width
                        local lh = PlaceFS(FS(), 0, y, W, size, it.label, it.minor and cMuted or cText, "LEFT", true, "label")
                        y = y + lh + 1
                    else
                        local lw = math.floor(W * 0.5)
                        local lh = PlaceFS(FS(), 0, y, lw - 4, size, it.label, it.labelColor or (it.minor and cMuted or cText), "LEFT", true, "label")
                        local vh = PlaceFS(FS(), lw, y, W - lw, size, v, ToneColor(tone, cText), "RIGHT", true, "value")
                        y = y + math.max(lh, vh) + 1
                    end
                    -- detail lines: one size smaller and muted, except an item that asks for full-size ones (spell math, #378: Xaya
                    -- found them "way too tiny"); those also give the value 70% of the width so "83.1% of attack power; 1 Agility = +0.83"
                    -- stays on one line
                    local big = it.bigPairs == true
                    local psz, pcol, frac = big and size or size - 1, big and cText or cMuted, big and 0.3 or 0.5
                    for _, p in ipairs(it.pairs or {}) do
                        if not short or p.short then
                            local x0 = 12
                            local lw = math.floor((W - x0) * frac)
                            local lh = PlaceFS(FS(), x0, y, lw - 4, psz, p.label, p.labelColor or pcol, "LEFT", true, "pairLabel")
                            local vh = PlaceFS(FS(), x0 + lw, y, W - x0 - lw, psz, tostring(p.value), ToneColor(p.tone, cText), "RIGHT", true, "pairValue")
                            y = y + math.max(lh, vh) + 1
                        end
                    end
                    if it.kind ~= "input" and it.kind ~= "icons" and it.kind ~= "colhead" and it.kind ~= "cmprow" and it.kind ~= "action" then
                        local b = Btn()
                        b.item = it
                        b:ClearAllPoints()
                        b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
                        b:SetSize(W, math.max(1, y - top))
                        Rec("hit", 0, top, W, y - top, it.key)
                    end
                    y = y + 4
                end
            end
        end
    end
    return y
end

-- the Spells tab's top row: the spell data button centred (at most 250 wide, and clear of the icon), the filter icon at the right, the
-- menu under the icon while it is open; returns the height it took
local function RenderSpellBar(c, m)
    local size = c.fontSize
    local h = size + 12
    local act
    for _, sec in ipairs(m.sections) do
        if sec.key == "spellmath" then for _, it in ipairs(sec.items) do if it.kind == "action" and not act then act = it end end end
    end
    local b = SpellDataButton()
    if act then
        local bw = math.min(SPELL_BTN_MAX, W - 2 * (FILTER_ICON + GUT))
        local x = math.floor((W - bw) / 2)
        b.item = act
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", content, "TOPLEFT", x, 0)
        b:SetSize(bw, h)
        b:SetText(act.label)
        local fs = b.GetFontString and b:GetFontString()
        if fs then SetFont(fs, size, "") end
        b:Show()
        Rec("spellbtn", x, 0, bw, h, act.label, size)
    else b:Hide() end
    local fi = FilterIcon()
    local filter = CM.FilterOf(c)
    local on = filter ~= "all"
    local fy = math.floor((h - FILTER_ICON) / 2)
    fi:ClearAllPoints()
    fi:SetPoint("TOPLEFT", content, "TOPLEFT", W - FILTER_ICON, -fy)
    fi:SetSize(FILTER_ICON, FILTER_ICON)
    local acc = TC("xui-tab-selected", "bg", { 0.55, 0.3, 0.8, 1 })
    local muted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local bg = TC("xui-button", "bg", { 0.04, 0.04, 0.04, 0.7 })
    fi.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
    local col = on and TC("xui-label", "text", { 1, 0.82, 0, 1 }) or muted
    for _, t in ipairs(fi.parts) do t:SetColorTexture(col[1], col[2], col[3], 1) end
    fi.dot:SetColorTexture(acc[1], acc[2], acc[3], 1)
    if on then fi.dot:Show() else fi.dot:Hide() end
    local label
    for _, f in ipairs(CM.SPELL_FILTERS) do if f[1] == filter then label = f[2] end end
    fi.active, fi.filterLabel = on, label
    fi.item = { kind = "filter", key = "filterIcon", label = "Filter: " .. (label or ""), value = "", pairs = {},
        tip = { on and ("Showing " .. (label or "") .. " spells only.") or "No filter: every spell is shown.", "Click to choose: None, Offense, Defense or Utility. The choice is kept." } }
    fi:Show()
    Rec("filtericon", W - FILTER_ICON, fy, FILTER_ICON, FILTER_ICON, label, size)
    -- the menu (a child of the panel, so the scroll frame does not cut it): its rows painted for the current choice
    local menu = panel.filterMenu
    panel.menuRecs = {}
    if menu and menu:IsShown() then
        local rh = size + 8
        local mw = math.max(120, math.ceil(size * 0.55 * 16) + 16)
        menu:ClearAllPoints()
        menu:SetPoint("TOPRIGHT", fi, "BOTTOMRIGHT", 0, -2)
        menu:SetSize(mw, #menu.rows * rh + 4)
        local wbg = TC("xui-window", "bg", { 0.04, 0.04, 0.06, 1 })
        menu.bg:SetColorTexture(wbg[1], wbg[2], wbg[3], 0.97)
        local bc = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
        for _, e in ipairs(menu.edges) do e:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 1) end
        for i, r in ipairs(menu.rows) do
            local sel = r.filter == filter
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -(2 + (i - 1) * rh))
            r:SetSize(mw - 4, rh)
            local cls = sel and "xui-tab-selected" or "xui-tab"
            local tb = TC(cls, "bg", sel and { 0.22, 0.1, 0.3, 0.9 } or { 0.03, 0.03, 0.03, 0 })
            r.bg:SetColorTexture(tb[1], tb[2], tb[3], sel and (tb[4] or 1) or 0)
            SetFont(r.text, size, "")
            r.text:SetText(r.label)
            Paint(r.text, TC(cls, "text", sel and { 1, 1, 1, 1 } or { 1, 0.82, 0, 1 }))
            r.selected = sel
            r:Show()
            panel.menuRecs[i] = { label = r.label, selected = sel, w = mw - 4, h = rh, size = size }
        end
    end
    return h + GUT
end
local function HideSpellBar()
    if panel.spellBtn then panel.spellBtn:Hide() end
    if panel.filterIcon then panel.filterIcon:Hide() end
    if panel.filterMenu then panel.filterMenu:Hide() end
end

-- the panel's width from the saved size (B10): the content width and the tab row follow
local function ApplyWidth(c)
    local pw = (type(c.size) == "table" and num(c.size.w)) and c.size.w or PANEL_W
    W = pw - 2 * PAD
    ns.STATCALC_LAYOUT.width, ns.STATCALC_LAYOUT.content = pw, W
    if not panel.sizing then panel:SetWidth(pw) end
    content:SetWidth(W)
    local tw = W / #CM.TABS
    for i, b in ipairs(panel.tabs or {}) do
        b:SetSize(tw - 2, 20)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + (i - 1) * tw, -(PAD + TITLE_H + GUT + NAME_H + GUT))
    end
end

-- the header's text (QoL 0.7.40, REQUEST-LOG #91): "Equipped <equipped item level>" on the left, "Max (bags) <overall item level>" on
-- the right (CM.HeaderInfo: GetAverageItemLevel's equipped and overall returns; reading taken: her "max ilvl (in bags)" is the overall
-- one). Each half gets half the width less half a gutter, so the two never meet; a value the game does not give leaves its half empty.
local HEADER_SIZE = 14
ns.StatCalc_HeaderText = function(h)
    h = h or {}
    return h.ilvlEquipped and ("Equipped %.1f"):format(h.ilvlEquipped) or "", h.ilvlOverall and ("Max (bags) %.1f"):format(h.ilvlOverall) or ""
end
local function RenderHeader(c)
    local h = CM.HeaderInfo()
    local muted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local label = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    local left, right = ns.StatCalc_HeaderText(h)
    local half = math.floor((W - GUT) / 2)
    for _, fs in ipairs({ panel.hEq, panel.hMax }) do
        SetFont(fs, HEADER_SIZE, "")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        fs:SetWidth(half)
        Paint(fs, label)
    end
    panel.hEq:SetText(left); panel.hMax:SetText(right)
    local rc = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
    panel.hRule:SetColorTexture(rc[1], rc[2], rc[3], 0.6)
    for _, l in ipairs(panel.grip and panel.grip.lines or {}) do l:SetColorTexture(muted[1], muted[2], muted[3], 0.9) end
    panel.headerInfo = h
end

function ns.StatCalc_Render()
    -- (V26, SC-001 / SC-045) the one gate for every draw: in combat no stat model is built and nothing is drawn, whoever asks (an input,
    -- an event, the theme, the character window's hooks, a walkthrough); the panel is hidden then and is drawn again after combat
    if InCombat() then return end
    local c = Cfg(); if not c or not panel then return end
    ApplyWidth(c)
    RenderHeader(c)
    local bgc = TC("xui-window", "bg", { 0.04, 0.04, 0.06, 1 })
    panel.bg:SetColorTexture(bgc[1], bgc[2], bgc[3], 1)
    panel.bg:SetAlpha(c.opacity)
    local bc = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
    for _, e in ipairs(panel.edges) do e:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 1) end
    SetFont(panel.title, c.fontSize + 2, "")
    Paint(panel.title, TC("xui-titlebar", "text", { 1, 0.82, 0, 1 }))
    layout = {}
    local mbg, mbb = TC("xui-button", "bg", { 0.04, 0.04, 0.04, 0.7 }), TC("xui-button", "text", { 1, 0.82, 0, 1 })
    local sb = panel.sizeBtn
    sb.bg:SetColorTexture(mbg[1], mbg[2], mbg[3], mbg[4] or 1)
    sb.text:SetText(c.sizeMode == "large" and "Min" or "Max")
    Paint(sb.text, mbb)
    panel.sizeText = sb.text:GetText()
    for _, b in ipairs(panel.tabs or {}) do
        local on = b.key == c.tab
        local cls = on and "xui-tab-selected" or "xui-tab"
        local tb = TC(cls, "bg", on and { 0.22, 0.1, 0.3, 0.9 } or { 0.03, 0.03, 0.03, 0.7 })
        b.bg:SetColorTexture(tb[1], tb[2], tb[3], tb[4] or 1)
        b.text:SetText(b.label)
        Paint(b.text, TC(cls, "text", on and { 1, 1, 1, 1 } or { 1, 0.82, 0, 1 }))
    end
    nFS, nBtn, nHdr, nIcon, nTex = 0, 0, 0, 0, 0
    for _, eb in pairs(boxes) do eb.xuiUsed = false end
    if c.tab == "gear" and bagsStale then
        bagsStale = false
        if CM.ForgetOwned then CM.ForgetOwned() end
    elseif c.tab == "spells" and talentsStale then
        talentsStale = false
        if CM.ClearTalents then CM.ClearTalents() end
    end
    modelBuilds = modelBuilds + 1
    local m = CM.Build(c, c.tab)
    panel.model = m
    local y
    if c.tab == "spells" then y = RenderSections(c, m, c.tab, RenderSpellBar(c, m))
    else HideSpellBar(); y = RenderSections(c, m, c.tab) end
    for i = nIcon + 1, #iconBtns do iconBtns[i]:Hide(); iconBtns[i].slot, iconBtns[i].link, iconBtns[i].cand = nil, nil, nil end
    for i = nFS + 1, #fsPool do fsPool[i]:Hide() end
    for i = nTex + 1, #texPool do texPool[i]:Hide() end
    for i = nBtn + 1, #btnPool do btnPool[i]:Hide(); btnPool[i].item = nil end
    for i = nHdr + 1, #hdrPool do hdrPool[i]:Hide() end
    for _, eb in pairs(boxes) do if not eb.xuiUsed then eb:Hide() end end
    panel.layoutRecs = layout
    content:SetHeight(math.max(10, y))
    -- the height: the Min / Max mode's (QoL 0.7.23; before, the content's height up to the character window's, or the dragged one)
    if not panel.sizing then panel:SetHeight(c.sizeMode == "large" and c.heightLarge or c.heightSmall) end
    Place()
    if NoteWantedItems then NoteWantedItems(c, m) end   -- (SC-020) the items this draw shows: GET_ITEM_INFO_RECEIVED redraws only for them
    if SyncPanelEvents then SyncPanelEvents(c) end       -- (SC-020) a new tab listens to its own events (Gear: bags; Ability Scaling: talents)
end

-- what the panel drew last: { model, layout records, mode button text }; for the tests
function ns.StatCalc_Drawn()
    if not panel then return nil end
    return { model = panel.model, layout = panel.layoutRecs, sizeText = panel.sizeText, buttons = btnPool, headers = hdrPool, boxes = boxes,
        fonts = fsPool, icons = iconBtns, spellBtn = panel.spellBtn, filterIcon = panel.filterIcon, filterMenu = panel.filterMenu,
        menuRecs = panel.menuRecs, textures = texPool }
end

-- (QoL 0.7.40) the Stat Calculator through core's service list (Modules.lua ns.Provide), for XayaUI Dev Assist's QA walkthroughs
-- (QAWalks-statcalc.lua: REQUEST-LOG #88-#91, B2): they read what the panel drew and press its controls, never its own tables. Only a
-- table of functions is registered when this file loads; nothing is built, registered or read until a walkthrough calls one (V14: with
-- the Stat Calculator off, Open says so and does nothing).
-- (V25 R2) who wants to know when the panel opens or closes, or when it is switched on or off: fn(open, available). Improved Character
-- Display's Stat Calc button registers here (statCalc.OnState) once, while it is on; nothing else does. Told at the same moments the
-- button was repainted before the move (the window's show, Apply, SetOpen).
local stateListeners = {}
-- (V26) combatHidden and InCombat(): at the top of this file
local function PanelAvailable()
    local c = Cfg()
    return (c and c.enabled and c.panel and not InCombat()) and true or false
end
local function TellState()
    if #stateListeners == 0 then return end
    local open, available = panel ~= nil and panel:IsShown() or false, PanelAvailable()
    for _, fn in ipairs(stateListeners) do pcall(fn, open, available) end
end
if ns.Provide then
    ns.Provide("statCalc", {
        Cfg = function() return Cfg() end,
        -- (V25 R2, for Improved Character Display's Stat Calc button) the panel can open (the Stat Calculator and its panel on); open or
        -- close it as the button did; tell fn(open, available) whenever that changes
        -- (V26) false in combat too: the button hides with the panel
        Available = function() return PanelAvailable() end,
        Toggle = function() ns.StatCalc_Toggle() end,
        OnState = function(fn) if type(fn) == "function" then stateListeners[#stateListeners + 1] = fn end end,
        -- open the panel on a tab ("stats" | "gear" | "spells"); false and why when the Stat Calculator or its panel is off
        Open = function(tab)
            local c = Cfg()
            if not c then return false, "no saved settings yet" end
            if not c.enabled then return false, "Stat Calculator is off (Bonus Features > Stat Calculator)" end
            if not c.panel then return false, "the Stat Calculator panel is off (Bonus Features > Stat Calculator > Panel)" end
            if InCombat() then return false, "in combat (the Stat Calculator opens again after combat)" end
            if tab then c.tab = tab end
            ns.StatCalc_SetOpen(true)
            return panel ~= nil and panel:IsShown()
        end,
        Shown = function() return panel ~= nil and panel:IsShown() end,
        Close = function() if panel and panel:IsShown() then ns.StatCalc_SetOpen(false) end end,
        Drawn = function() return ns.StatCalc_Drawn() end,
        -- (Bonus 0.6.38) type in a box as the player does ("crit" with "100": 100 more crit rating; "" clears it) and redraw; for the
        -- change-colour walkthrough (QAWalks-stat-colors.lua)
        SetInput = function(key, text) ns.StatCalc_SetInput(key, text) end,
        ToggleStat = function(key) ns.StatCalc_ToggleStat(key) end,
        SelectGearSlot = function(slot) ns.StatCalc_SelectGearSlot(slot) end,
        PickItem = function(link, slot) ns.StatCalc_PickItem(link, slot) end,
        -- the header as drawn: left text, right text, and the game's two item levels it came from
        Header = function()
            if not panel then return nil end
            return panel.hEq:GetText(), panel.hMax:GetText(), CM.HeaderInfo()
        end,
        HasModeButton = function() return panel ~= nil and panel.modeBtn ~= nil end,
        Page = function() return ns.BuildStatCalcPage and ns.BuildStatCalcPage(function() end) end,
        TextW = function(text, size) return panel and TextW(text, size) or nil end,
    })
end

-- (Bonus 0.6.37: the slot overlays on the character window are XayaUI QoL's, XayaUI_QoL/ImprovedCharacterDisplay.lua)

-------------------------------------------------------------------------------
-- Events: only while the Stat Calculator is on. Refresh is throttled to one per 0.25 s and only while the panel is up.
-------------------------------------------------------------------------------
local ev, pending
local STAT_EVENTS = { "COMBAT_RATING_UPDATE", "MASTERY_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "SPEED_UPDATE", "LIFESTEAL_UPDATE", "AVOIDANCE_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "PLAYER_LEVEL_UP", "PLAYER_TARGET_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE",
    "CHALLENGE_MODE_MAPS_UPDATE", "GET_ITEM_INFO_RECEIVED", "SOCKET_INFO_UPDATE", "ENCHANT_SPELL_COMPLETED",
    "SPELL_DATA_LOAD_RESULT", "SPELLS_CHANGED" }
local UNIT_EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGEDDAMAGE", "UNIT_RANGED_ATTACK_POWER", "UNIT_ATTACK_SPEED", "UNIT_DAMAGE",
    "UNIT_MAXHEALTH", "UNIT_RESISTANCES", "UNIT_SPELL_HASTE" }
-- (QoL 0.7.23: durability, repair and the vendor events left with the Durability and repair section)
-- (SC-081) only while the panel is shown, out of combat: the cooldown read (SPELL_UPDATE_COOLDOWN fires on every cast; with the panel
-- closed a cast costs this file nothing). (SC-085 / SC-049, event side) and per tab: the bags while Gear is shown (an item looted with
-- the tab open shows at once), the talents while Ability Scaling is shown (BAG_UPDATE_DELAYED, events.md:146; TRAIT_CONFIG_UPDATED,
-- events.md:1536; PLAYER_TALENT_UPDATE, events.md:1222).
-- (gate G-023) ADDON_RESTRICTION_STATE_CHANGED (type: AddOnRestrictionType, state: AddOnRestrictionState) · SynchronousEvent ·
-- RestrictedActions (events.md:37); Enum.AddOnRestrictionState Inactive = 0, Activating = 1, Active = 2 (enums.md:485)
local SHOWN_EVENTS = { "SPELL_UPDATE_COOLDOWN", "ADDON_RESTRICTION_STATE_CHANGED" }
-- (gate G-012 / G-014) the panel closed: only what does work then (see RegisterPanelEvents). PLAYER_REGEN_ENABLED stays too (once per
-- combat end): it clears the model's "GCD hidden in combat" mark (CM.gcdHidden), which Enhanced Tooltips' lines also read, when the
-- lockdown was seen without this frame hearing PLAYER_REGEN_DISABLED (tests/char_statcalc2_run.py plays that case)
local CLOSED_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_LEVEL_UP" }
local TAB_EVENTS = { gear = { "BAG_UPDATE_DELAYED" }, spells = { "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE" } }

-- one redraw at most every 0.25 s, only while the panel is up and out of combat (SC-020: one function for the whole file, not a new
-- closure per call)
local function RunRefresh()
    pending = false
    if panel and panel:IsShown() and not InCombat() then ns.StatCalc_Render() end
end
local function Refresh()
    if pending then return end
    pending = true
    if C_Timer and C_Timer.After then C_Timer.After(0.25, RunRefresh) else RunRefresh() end
end

local function ReadGCD()
    if CM.ReadGCD() and panel and panel:IsShown() then Refresh() end
end
ns.StatCalc_ReadGCD = ReadGCD

-- (SC-020) the items the last draw shows or asked for: every equipped slot (1-19, INVSLOT_FIRST_EQUIPPED to INVSLOT_LAST_EQUIPPED, read
-- as Blizzard's PaperDollFrame.lua reads them: GetInventoryItemLink, undocumented in docs/reference/api, INFERENCE), the compared items
-- (their links, or the typed item ID the model asked the game to load), and on the Gear tab every item icon it drew (the equipped
-- icons and the bag items for the picked slot). GET_ITEM_INFO_RECEIVED (itemID: number, success: bool; events.md:673) redraws only
-- for one of these, so the Auction House or a bag sort does not redraw the panel. Kept in one table, refilled per draw.
local wantItems = {}
local function ItemIdOf(x)
    if x == nil or isSecret(x) then return nil end
    if type(x) == "number" then return x end
    if type(x) ~= "string" then return nil end
    local id = x:match("item:(%d+)") or x:match("^%s*(%d+)%s*$")
    return id and tonumber(id) or nil
end
local function Want(x) local id = ItemIdOf(x); if id then wantItems[id] = true end end   -- (one function for the file, SC-020)
NoteWantedItems = function(c, m)
    for k in pairs(wantItems) do wantItems[k] = nil end
    if type(GetInventoryItemLink) == "function" then
        for slot = 1, 19 do Want(GetInventoryItemLink("player", slot)) end   -- (not protected: a plain call)
    end
    for _, l in ipairs(type(CM.compareLinks) == "table" and CM.compareLinks or {}) do Want(l) end
    Want(CM.compareText)
    if c and c.tab == "gear" and type(m) == "table" then
        for _, sec in ipairs(m.sections or {}) do
            for _, it in ipairs(sec.items or {}) do
                for _, ic in ipairs(type(it.icons) == "table" and it.icons or {}) do Want(ic.link) end
            end
        end
    end
end
local function WantsItem(id)
    if id == nil or isSecret(id) or type(id) ~= "number" then return false end
    return wantItems[id] == true
end
-- (SC-020) the tabs whose model reads the target (StatModel.lua: HasAttackableTarget / C_PaperDollInfo.GetArmorEffectivenessAgainstTarget,
-- "» Against your target"): the stat map, so the Stats tab, and the Gear tab while it compares an item (its "Changes" build the stat
-- map once per compared item, CM.StatMapSections). Ability Scaling reads no target: tab-targeting does not redraw it.
local function ReadsTarget(c)
    if not c then return false end
    if c.tab == "stats" then return true end
    if c.tab == "gear" then
        return (type(CM.compareLinks) == "table" and #CM.compareLinks > 0) or (type(CM.compareText) == "string" and CM.compareText ~= "")
    end
    return false
end

-- the character window opened: the panel docks beside it when it was left open (c.panelOpen, kept between sessions; QoL 0.7.23, Xaya
-- 2026-11-05: "remember the last-left state on next open")
local function ShowIfDocked()
    if InCombat() then return end   -- (V26) nothing is built, drawn or shown in combat; it comes back after combat (LeaveCombat)
    local c = Cfg()
    if not (c and c.enabled and c.panel) then return end
    if not c.panelOpen then
        if panel and panel:IsShown() then panel:Hide() end
        TellState()
        return
    end
    Build()
    if not panel:IsShown() then panel.standalone = false end
    panel:Show()
    ns.StatCalc_Render()
    TellState()
end

-- the panel's events (D17, V14: only while the Stat Calculator and its "Show the panel" part are on). (V26) In combat the frame listens
-- to PLAYER_REGEN_ENABLED only: no stat, unit or cooldown event reaches this file until combat ends. (SC-081 / SC-020) What it listens
-- to follows one key: off (nothing), combat, closed, or open on a tab. (gate G-012 / G-014, V27 / V28) Closed: only the start and end of
-- combat (V26: the Stat Calc button is told) and the spec / level change (the model's kept spec data is dropped); no stat or unit event, since
-- every open draws a fresh model (CM.Build in ns.StatCalc_Render) and bags / talents are read again through bagsStale / talentsStale.
-- Open on a tab: the stat and unit events, the cooldown read, that tab's own events, and the addon restriction change (V29: a Change
-- box lets go of the keyboard when a Mythic+ / encounter / PvP restriction starts, gate G-023). The frame's events change only when
-- the key changes: at the panel's show and hide, a tab change, combat, and Apply (force).
local evKey
local function EventsKey(c)
    if not (c and c.enabled and c.panel) then return nil end
    if InCombat() then return "combat" end
    if not (panel and panel:IsShown()) then return "closed" end
    return "open:" .. tostring(c.tab)
end
local function RegisterPanelEvents(c, force)
    if not ev then return end
    local key = EventsKey(c)
    if key == evKey and not force then return end
    evKey = key
    -- (round 2) a tab whose own events stop being heard here may miss a change: its next first draw reads again (bagsStale / talentsStale)
    if key ~= "open:gear" then bagsStale = true end
    if key ~= "open:spells" then talentsStale = true end
    ev:UnregisterAllEvents()
    if key == nil then return end
    if key == "combat" then pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED"); return end
    if key == "closed" then
        for _, e in ipairs(CLOSED_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
        return
    end
    for _, e in ipairs(STAT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
    for _, e in ipairs(UNIT_EVENTS) do
        if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, e, "player") else pcall(ev.RegisterEvent, ev, e) end
    end
    for _, e in ipairs(SHOWN_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
    for _, e in ipairs(TAB_EVENTS[c.tab] or {}) do pcall(ev.RegisterEvent, ev, e) end
end
SyncPanelEvents = function(c) RegisterPanelEvents(c) end
-- (SC-081) the panel shows (never in combat: nothing shows it then): one GCD read, so the last readable GCD is there without listening
-- to every cast while the panel is closed; then its shown-only events
OnPanelShown = function()
    if InCombat() then return end
    CM.ReadGCD()
    RegisterPanelEvents(Cfg())
end
OnPanelHidden = function() RegisterPanelEvents(Cfg()) end

-- (V26, "Hide silently") combat starts: the panel hides (its saved open state, c.panelOpen, is kept), the Stat Calc button is told
-- (TellState: not available), and the events stop. No message. (SC-002 / SC-019) First every Change box lets go of the keyboard
-- (EditBox:ClearFocus), so a box never keeps the keys when combat starts, whatever core's KeyFocusGuard version does on hide.
local combatWas, combatAlone = false, false
-- every Change box lets go of the keyboard (combat starts, or an addon restriction becomes active: V29)
local function LetGoOfKeys()
    for _, eb in pairs(boxes) do if eb.ClearFocus then eb:ClearFocus() end end
end
-- (gate G-023) a restriction (combat, encounter, Mythic+, PvP: Enum.AddOnRestrictionType) is activating or active: the boxes let go.
-- A state that is not a plain number (missing, or secret) counts as active (fail safe). The type is not read: every kind lets go.
local RESTRICTION_INACTIVE = (Enum and Enum.AddOnRestrictionState and Enum.AddOnRestrictionState.Inactive) or 0
local function OnRestriction(state)
    if state ~= nil and not isSecret(state) and type(state) == "number" and state == RESTRICTION_INACTIVE then return end
    LetGoOfKeys()
end
local function EnterCombat()
    if combatHidden then return end
    combatHidden = true
    LetGoOfKeys()
    combatWas = panel ~= nil and panel:IsShown() or false
    combatAlone = combatWas and panel.standalone == true
    if panel then panel:StopMovingOrSizing(); panel.sizing = nil end   -- (gate G-006) a drag or resize in progress ends now
    if combatWas then panel:Hide() end
    RegisterPanelEvents(Cfg())
    TellState()
end
-- combat ended: everything comes back in the state it would otherwise have: the panel reopens when it is still wanted (c.panelOpen)
-- and its trigger still holds: on its own when it was open on its own, docked when the character window is open now
local function LeaveCombat()
    combatHidden = false
    local was, alone = combatWas, combatAlone
    combatWas, combatAlone = false, false
    local c = Cfg()
    RegisterPanelEvents(c)
    if c and c.enabled and c.panel and c.panelOpen and not InCombat() then
        if was and alone then
            Build()
            panel.standalone = true
            panel:Show()
            ns.StatCalc_Render()
        elseif Docked() then
            ShowIfDocked()
        end
    end
    TellState()
end

local function OnEvent(_, event, unit, arg2)
    if event == "PLAYER_REGEN_DISABLED" then EnterCombat(); return end
    if event == "ADDON_RESTRICTION_STATE_CHANGED" then OnRestriction(arg2); return end   -- (type, state): the state is the second
    if event == "PLAYER_REGEN_ENABLED" then
        -- out of combat the last readable GCD shows again. (SC-081, round 2) No read here: the panel reads it when it shows again
        -- (OnPanelShown, from LeaveCombat when it reopens); a closed panel reads it at its next open.
        CM.gcdHidden = false
        LeaveCombat()
        return
    end
    if InCombat() then return end
    if event == "SPELL_UPDATE_COOLDOWN" then ReadGCD(); return end
    -- the Spells tab: a description it asked for arrived, or the spellbook changed (core resets its spell list on SPELLS_CHANGED)
    if event == "SPELL_DATA_LOAD_RESULT" or event == "SPELLS_CHANGED" then
        local c = Cfg()
        if c and c.tab == "spells" and panel and panel:IsShown() and (event == "SPELLS_CHANGED" or CM.SpellRequested(unit)) then Refresh() end
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LEVEL_UP" then CM.ClearCache() end
    -- (Bonus 0.6.37: the slot overlays' refresh is XayaUI QoL's own, ImprovedCharacterDisplay.lua)
    if not (panel and panel:IsShown()) then return end   -- (gate G-014) the cheap check first
    if unit and unit ~= "player" and event:find("^UNIT_") then return end
    local c = Cfg()
    -- (SC-020) busy events redraw only when what the panel shows changed
    if event == "GET_ITEM_INFO_RECEIVED" then if WantsItem(unit) then Refresh() end; return end
    if event == "PLAYER_TARGET_CHANGED" then if ReadsTarget(c) then Refresh() end; return end
    -- (SC-085, event side) bags changed while Gear is shown: the model's bag list is read again (CM.ForgetOwned, when the model has it)
    if event == "BAG_UPDATE_DELAYED" then
        if c and c.tab == "gear" then
            if CM.ForgetOwned then CM.ForgetOwned() end
            Refresh()
        end
        return
    end
    -- (SC-049, event side) talents changed while Ability Scaling is shown: the model's talent scan is read again
    if event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_TALENT_UPDATE" then
        if c and c.tab == "spells" then
            CM.ClearTalents()
            Refresh()
        end
        return
    end
    Refresh()
end

-- (the extra lines on the character window's own stat tooltips: Enhanced Tooltips' option since V25 R4, XayaUI_Bonus/Tooltips.lua section 5)

-------------------------------------------------------------------------------
-- On / off
-------------------------------------------------------------------------------
local ownerHooked, themeOn = false, false
-- (gate G-019, V14) the theme listener: in while the Stat Calculator and its panel are on, taken out (core Theme.OffResolve) when
-- either is switched off, as Improved Character Display does (ImprovedCharacterDisplay.lua SetThemeListener). One function for the file.
local function OnTheme() if panel and panel:IsShown() then ns.StatCalc_Render() end end
local function SetThemeListener(on)
    local T = ns.Theme
    if not (T and T.OnResolve) then return end
    if on and not themeOn then T.OnResolve(OnTheme); themeOn = true
    elseif not on and themeOn and T.OffResolve then T.OffResolve(OnTheme); themeOn = false end
end

-------------------------------------------------------------------------------
-- The Stat Calculator row in XayaUI's minimap button list (QoL 0.7.23; Xaya 2026-11-05, her words: "it should also have its own open
-- button on the minimap and should be openable as its own standalone window without opening the character sheet"). It exists only
-- while the Stat Calculator and its panel are on (V14): the row (ns.RegisterLauncher, core Modules.lua) is registered once and its
-- available() keeps it out of the list while either is off (core 0.6.48; the entry itself stays registered so the settings window's
-- options tree does not change with the switch: tests/sidebar_switches_run.py).
-- (V25 R2; Xaya A24 #3: "NOTHING that directly touches the character pane is part of the stat calculator") the Stat Calc button on the
-- character window is Improved Character Display's (XayaUI QoL, ImprovedCharacterDisplay.lua): it calls this file through the
-- "statCalc" service (Toggle, Available, Shown) and learns the panel's state from TellState (its OnState listener, above); no polling.
-------------------------------------------------------------------------------
local function RegisterLauncher()   -- (Bonus 0.6.37: called by RegisterAll, only with XayaUI QoL on)
    if type(ns.RegisterLauncher) == "function" then
        ns.RegisterLauncher({ "stats", "Stat Calculator", "Show or hide the Stat Calculator on its own, without the character window (also /xui stats)",
            function() ns.StatCalc_Toggle() end, nil, order = 12,   -- O-100 (QoL 0.7.42, her answer "No word at all"): no "on" / "off" for shown / hidden
            available = function() local c = Cfg(); return (c and c.enabled and c.panel) and true or false end })
    end
end
function ns.StatCalc_Apply()
    local c = Cfg(); if not c then return end
    if not c.enabled then
        if ev then ev:UnregisterAllEvents() end
        evKey = nil
        SetThemeListener(false)
        if panel then panel:Hide() end
        TellState()
        return
    end
    -- (Bonus 0.6.37) with the panel off this file has nothing to listen to (the overlays and the tooltip lines are XayaUI QoL's)
    SetThemeListener(c.panel and true or false)
    if not c.panel and not ev then
        if panel then panel:Hide() end
        TellState()
        return
    end
    if not ev then
        ev = CreateFrame("Frame")
        ev:SetScript("OnEvent", OnEvent)
    end
    -- (D17, V14) the panel's stat / unit events and the GCD read only while its "Show the panel" part is on; with it off, nothing
    -- (Bonus 0.6.37: the slot overlays' events and the cache reset for the overlays are XayaUI QoL's, ImprovedCharacterDisplay.lua).
    -- (V26) switched on in combat: it listens for the end of combat only, and shows nothing until then.
    -- The flag is read again from the game here: it may be stale when the events were off while combat ended.
    combatHidden = (type(InCombatLockdown) == "function" and InCombatLockdown()) and true or false
    RegisterPanelEvents(c, true)
    if not ownerHooked then
        local owner = Owner()
        if owner and owner.HookScript then
            ownerHooked = true
            owner:HookScript("OnShow", function() ShowIfDocked() end)
            -- the character window closed: a panel that docked with it closes with it (its open state is kept for next time); one
            -- opened on its own stays open and goes back to its own place (QoL 0.7.23)
            owner:HookScript("OnHide", function()
                if not panel or not panel:IsShown() then return end
                local cc = Cfg()
                if panel.standalone and cc and cc.enabled and cc.panel then ns.StatCalc_Render() else panel:Hide() end
            end)
        end
    end
    if panel then
        if not c.panel then panel:Hide()
        elseif InCombat() then
            -- (V26) applied in combat: hidden now, back after combat as it was
            if panel:IsShown() then combatWas, combatAlone = true, panel.standalone == true; panel:Hide() end
        elseif panel:IsShown() then ns.StatCalc_Render()
        elseif Docked() and c.panelOpen then ShowIfDocked() end
    elseif c.panel and Docked() then
        ShowIfDocked()   -- (does nothing in combat)
    end
    TellState()
end

-- Open or close the panel (QoL 0.7.23): the character window's Stat Calc button, the minimap list's Stat Calculator row, /xui stats
-- and the panel's own close button. The state is saved (c.panelOpen) and the character window opens with it next time. Opened while
-- the character window is closed, the panel stands on its own at its own place (c.free, kept when you drag it) and stays open when
-- the character window opens and closes again; opened with the character window, it docks beside it and closes with it.
function ns.StatCalc_SetOpen(open)
    if InCombat() then return end   -- (V26 "Hide silently") in combat nothing opens or closes it, and nothing is said
    local c = Cfg(); if not c then return end
    if not c.enabled then
        ns.Print("Stat Calculator is off. Turn it on in Bonus Features > Stat Calculator (or /xui stats on).")
        return
    end
    if not c.panel then
        ns.Print("The Stat Calculator panel is off. Turn it on in Bonus Features > Stat Calculator > Panel.")
        return
    end
    c.panelOpen = open and true or false
    if open then
        Build()
        if not panel:IsShown() then panel.standalone = not Docked() end
        panel:Show()
        ns.StatCalc_Render()
    elseif panel then
        panel:Hide()
    end
    TellState()
end
function ns.StatCalc_Toggle()
    ns.StatCalc_SetOpen(not (panel and panel:IsShown()))
end
-- the Min / Max button: the other of the two heights
function ns.StatCalc_SizeMode(mode)
    if InCombat() then return end   -- (V26)
    local c = Cfg(); if not c then return end
    c.sizeMode = mode or ((c.sizeMode == "large") and "small" or "large")
    if c.sizeMode ~= "large" then c.sizeMode = "small" end
    ns.StatCalc_Render()
end

-- (Bonus 0.6.37) once both stores are open: Bonus's at this addon's ADDON_LOADED, XayaUI QoL's at that addon's (it loads after this one;
-- core copies the panel's settings from it then, once: Modules.lua section 0c). With XayaUI QoL off this never runs: nothing is made.
local registered = false
local RegisterAll   -- (below: the page, the command, the minimap row and the services, only with XayaUI QoL on)
ns.WhenSettingsReady("bonus", function()
    ns.WhenSettingsReady("qol", function()
        if not registered and RegisterAll then registered = true; RegisterAll() end
        if Cfg() then ns.StatCalc_Apply() end
    end)
end)
-- (audit QA walkthrough, D17) which of the Stat Calculator's events are registered now; its settings, and Apply after changing them
-- (QAWalks-statcalc-fixes.lua) Builds: how many stat models the panel has built since the reload (a number, read only: nothing can set it);
-- InCombat: whether the panel counts the player as in combat (V26)
if ns.Provide then ns.Provide("statCalcDebug", { Cfg = function() return Cfg() end, Apply = function() return ns.StatCalc_Apply() end,
    Registered = function(e) return (ev and ev.IsEventRegistered and ev:IsEventRegistered(e)) and true or false end,
    Builds = function() return modelBuilds end,
    InCombat = function() return InCombat() end,
    -- (gate G-006, QAWalks-statcalc-fixes.lua) a resize under way (the corner grip held), and the panel's size now (read only)
    Sizing = function() return (panel ~= nil and panel.sizing == true) and true or false end,
    PanelSize = function() if panel then return panel:GetWidth(), panel:GetHeight() end end,
    -- (gate G-003) the panel's strata and the character window's (read only)
    Strata = function()
        local cf = _G.CharacterFrame
        return panel and panel:GetFrameStrata() or nil, (cf and cf.GetFrameStrata) and cf:GetFrameStrata() or nil
    end,
    -- the Change boxes the panel made and whether any has the keyboard (EditBox:HasFocus)
    BoxFocus = function()
        local n, focused = 0, false
        for _, eb in pairs(boxes) do n = n + 1; if eb.HasFocus and eb:HasFocus() then focused = true end end
        return focused, n
    end }) end

-------------------------------------------------------------------------------
-- Settings: Bonus Features > Stat Calculator (a feature node; its parts Panel and Spell Math are nodes under it, and each
-- part's sections are tabs). A dropdown always shares its row; labels are short and the explanation is in the tooltip.
-------------------------------------------------------------------------------
local function ResolveSpell(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    local link = text:match("|Hspell:(%d+)")
    if link then return tonumber(link) end
    local id = tonumber(text)
    if id then return id end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = CM.R(C_Spell.GetSpellInfo, text)
        if type(info) == "table" and num(info.spellID) and not isSecret(info.spellID) then return info.spellID end
    end
end
ns.StatCalc_ResolveSpell = ResolveSpell

-- (SC-050, tie-in side; Xaya: a tie-in is read once at load and once at the first options-window open after a reload, no repeated
-- checks) the page's first build after a reload asks the model to read its tie-ins (which other XayaUI parts are on) once more, when
-- the model offers that (CM.ReadTieIns); later builds do not.
local pageBuilt = false
function ns.BuildStatCalcPage(Notify)
    if not Cfg() then return nil end   -- (Bonus 0.6.37) no page without XayaUI QoL's model (nothing extra while it is off)
    if not pageBuilt then
        pageBuilt = true
        if CM.ReadTieIns then pcall(CM.ReadTieIns, true) end
    end
    local function C() return Cfg() or CopyVal(ns.STATCALC_DEFAULTS) end
    local function Changed() ns.StatCalc_Apply(); if Notify then Notify() end end
    local isOff = function() return not C().enabled end
    local addBuf = ""
    local function Toggle(key, order, name, desc, width, hidden, tip)
        return { type = "toggle", order = order, width = width, name = name, desc = desc, hidden = hidden, tip = tip,
            get = function() return C()[key] and true or false end,
            set = function(_, v) C()[key] = v and true or false; Changed() end }
    end

    -- each part's on/off (and the Stat Calculator's own) is the tick box on its row in the left pane: xuiSwitch (QoL 0.7.18; Xaya 2026-11-05:
    -- "move all enable/disable toggles onto the sidebar instead"), the same Toggle as the switch the page had
    local spells = {
        type = "group", name = "Spell Math", order = 30, hidden = isOff,
        xuiSwitch = Toggle("advanced", 1, "Spell Math", "Shows the Ability Scaling tab's spell math in the panel (advanced).", nil, nil, "Shows the spell math on the Stat Calculator's Ability Scaling tab."),
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "The Ability Scaling tab lists every active spell of your current spec's spellbook that has numbers in its description, and the spells you add here first (any spell ID). For each: every number in its current description divided by your current attack power (or spell power), and what one point of your primary stat adds. This is the ratio right now, with talents and buffs already applied; it is not Blizzard's base coefficient. You can type a coefficient from a database such as Wowhead to compare." },
            spellsAll = Toggle("spellsAll", 1.5, "List spells without numbers",
                "Also lists spellbook spells with no numbers in their description.", "full"),
            add = { type = "input", order = 2, width = "double", name = "Add a spell",
                desc = "Adds a spell by ID, name or shift-clicked link. Up to 20.",
                get = function() return addBuf end,
                set = function(_, v)
                    local id = ResolveSpell(v)
                    if not id then ns.Print("Stat Calculator: no spell found for \"" .. tostring(v) .. "\"."); return end
                    local c = Cfg(); if not c then return end
                    for _, s in ipairs(c.spells) do if s.id == id then return end end
                    if #c.spells >= 20 then ns.Print("Stat Calculator: up to 20 spells."); return end
                    c.spells[#c.spells + 1] = { id = id, base = (CM.PrimaryStatIndex() == 4) and "sp" or "ap" }
                    addBuf = ""
                    Changed()
                end },
        },
    }
    for i = 1, 20 do
        local function S() return C().spells[i] end
        spells.args["s" .. i] = {
            type = "group", inline = true, order = 10 + i,
            name = function() local s = S(); return s and (CM.SpellName(s.id) .. "  (#" .. s.id .. ")") or "" end,
            hidden = function() return S() == nil end,
            args = {
                base = { type = "select", order = 1, name = "Scales with", values = { ap = "Attack power", sp = "Spell power" },
                    desc = "What the spell's numbers are divided by.",
                    get = function() local s = S(); return s and s.base or "ap" end,
                    set = function(_, v) local s = S(); if s then s.base = v; Changed() end end },
                coeff = { type = "input", order = 2, name = "Coefficient %",
                    desc = "Optional: the spell's percent of attack or spell power, from a database such as Wowhead. Leave empty to show only what the game measures.",
                    get = function() local s = S(); return (s and num(s.coeff)) and tostring(s.coeff) or "" end,
                    set = function(_, v)
                        local s = S(); if not s then return end
                        local n = tonumber((tostring(v or ""):gsub("%%", ""):gsub(",", ".")))
                        s.coeff = (n and n > 0) and n or nil
                        Changed()
                    end },
                kind = { type = "select", order = 2.5, name = "Filter",
                    values = { auto = "From its description", offense = "Offense", defense = "Defense", both = "Offense and Defense", utility = "Utility" },
                    sorting = { "auto", "offense", "defense", "both", "utility" },
                    desc = "Sets which Ability Scaling filters show this spell. \"From its description\" sorts it by its wording.",
                    get = function() local s = S(); return (s and s.kind) or "auto" end,
                    set = function(_, v) local s = S(); if s then s.kind = (v ~= "auto") and v or nil; Changed() end end },
                remove = { type = "execute", order = 3, width = "half", name = "Remove",
                    func = function() table.remove(C().spells, i); Changed() end },
            },
        }
    end

    local panelPart = {
        type = "group", name = "Panel", order = 10, childGroups = "tab", hidden = isOff,
        xuiSwitch = Toggle("panel", 1, "Show the panel", "The Stat Calculator: the Stat Calc button on the character window opens and closes it beside the window (it opens the same way next time); the button shows only while QoL > Improved Character Display is on. The XayaUI minimap button's Stat Calculator row and /xui stats open it on its own. Hidden in combat; it comes back after combat. Off: no panel, no minimap row, and the Stat Calc button stays hidden.", nil, nil, "Shows the Stat Calculator beside the character window."),
        args = {
            layout = { type = "group", name = "Layout", order = 1, args = {
                side = { type = "select", order = 2, name = "Side", values = { right = "Right", left = "Left" },
                    desc = "Which side of the character window the panel docks to.",
                    get = function() return C().side end, set = function(_, v) C().side = v; Changed() end },
                detail = { type = "select", order = 3, name = "Detail", values = { all = "Every line", short = "Key lines" },
                    desc = "How many detail lines show under each stat. The hover always shows all of them.",
                    get = function() return C().detail end, set = function(_, v) C().detail = v; Changed() end },
                -- (QoL 0.7.40, REQUEST-LOG B2: "Rating lines", order 4, is gone with the % / rating toggle)
                fontSize = { type = "range", order = 5, name = "Text size", min = 8, max = 16, step = 1,
                    get = function() return C().fontSize end, set = function(_, v) C().fontSize = v; Changed() end },
                resetSize = { type = "execute", order = 5.5, name = "Reset size",
                    desc = "Resets the panel to its default width and heights (440 and 760).",
                    func = function() local c = C(); c.size = nil; c.heightSmall = 440; c.heightLarge = 760; Changed() end },
                -- the Min / Max button's two heights (QoL 0.7.23; Xaya: "two configured sizes -- one smaller and one larger (NOT full
                -- screen, just longer)")
                heightSmall = { type = "range", order = 5.6, name = "Smaller height", min = MIN_H, max = MAX_H, step = 10,
                    desc = "Sets the panel's height after Min. Dragging the corner while it is small sets it too.",
                    get = function() return C().heightSmall end, set = function(_, v) C().heightSmall = v; Changed() end },
                heightLarge = { type = "range", order = 5.7, name = "Larger height", min = MIN_H, max = MAX_H, step = 10,
                    desc = "Sets the panel's height after Max. Dragging the corner while it is large sets it too.",
                    get = function() return C().heightLarge end, set = function(_, v) C().heightLarge = v; Changed() end },
                -- (QoL 0.7.28; Xaya 2026-11-06: "provide all three visual options this round for me to consider; volunteer more if
                -- possible") how the Stats tab's Gear Summary is drawn
                gearSumStyle = { type = "select", order = 5.8, name = "Gear Summary style",
                    values = (function() local t = {}; for _, st in ipairs(CM.GEAR_SUM_STYLES) do t[st[1]] = st[2] end; return t end)(),
                    sorting = (function() local t = {}; for _, st in ipairs(CM.GEAR_SUM_STYLES) do t[#t + 1] = st[1] end; return t end)(),
                    desc = (function()
                        local t = { "Sets how the Gear Summary at the top of the Stats tab is drawn." }
                        for _, st in ipairs(CM.GEAR_SUM_STYLES) do t[#t + 1] = st[2] .. ": " .. st[3] end
                        return table.concat(t, "\n")
                    end)(),
                    get = function() return CM.GearSumStyle(C()) end, set = function(_, v) C().gearSumStyle = v; Changed() end },
                opacity = { type = "range", order = 6, name = "Background", min = 0, max = 1, step = 0.05, isPercent = true,
                    desc = "Sets the panel background's opacity.",
                    get = function() return C().opacity end, set = function(_, v) C().opacity = v; Changed() end },
            } },
            values = { type = "group", name = "Your numbers", order = 2, args = {
                -- (QoL 0.7.23: the All ratings amount is gone; Xaya 2026-11-05: "remove "all ratings" as an entry option")
                clear = { type = "execute", order = 2, name = "Clear all",
                    desc = "Resets every number you typed in a Change box on the Stats tab.",
                    func = function() local c = C(); c.whatIf = 0; c.whatIfStats = {}; c.whatIfPrimary = nil; Changed() end },
                -- (QoL 0.7.40, B2: "Reset line flips" is gone with the per-line flip)
            } },
        },
    }
    -- (Bonus 0.6.37: the Slot Overlays part stays XayaUI QoL's: QoL > Improved Character Display, XayaUI_QoL/ImprovedCharacterDisplay.lua; the Tooltip lines
    -- are Bonus Features > Enhanced Tooltips > Character stats since V25 R4)

    return {
        -- (Bonus 0.6.38, Xaya 2026-11-08, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #37: "these are \"Stat Calculator\"") the Bonus
        -- Features node and its switch are titled Stat Calculator; the slot overlays and tooltip lines are on QoL's Improved Character Display page
        type = "group", name = "Stat Calculator", order = 3, childGroups = "tree",
        xuiSwitch = Toggle("enabled", 1, "Stat Calculator", "Turns the Stat Calculator on. While it is off nothing is created, registered or read.", nil, nil, "Turns on the Stat Calculator."),
        args = {
            -- (Bonus 0.6.37) the parts' list names the two that came to Bonus Features (the slot overlays and tooltip lines stay QoL's)
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "The Stat Calculator: a panel beside the character window (its Stat Calc button shows while QoL > Improved Character Display is on) or on its own (the XayaUI minimap button, /xui stats): every stat the game gives in one Character Stats section, where each number comes from, what the next point buys, what each stat feeds (type your own numbers to see the change), the Stat Weights pane, and a gear comparison. What the game does not give is marked, never guessed. Hidden in combat; it comes back after combat. Turn it on with the tick box on its row on the left; its parts (Panel, Spell Math) then show under it, each with its own tick box. Off by default." },
            panelPart = panelPart,
            spells = spells,
        },
    }
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua: core never calls this file by name. (Bonus 0.6.37) only once XayaUI QoL's settings are open
-- (RegisterAll, from the start-up above): with XayaUI QoL off there is no page, no /xui stats and no minimap row.
-------------------------------------------------------------------------------
RegisterAll = function()
RegisterLauncher()
ns.RegisterSettingsPage("bonus", "statcalc", ns.BuildStatCalcPage)
ns.RegisterCommand("stats", function(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local c = Cfg()
    if arg == "options" or arg == "settings" then ns.OpenSettingsPage("bonus", "statcalc"); return end
    if arg == "help" then
        ns.Print("/xui stats: show or hide the Stat Calculator (on its own when the character window is closed). /xui stats on | off | options | status")
        return
    end
    if arg == "status" then
        if not c then ns.Print("Stat Calculator: settings not ready."); return end
        -- (V25 R2) the slot overlays and tooltip lines are Improved Character Display's (XayaUI QoL): /xui reskin status prints them
        ns.Print(("Stat Calculator: %s, panel %s, spell math %s (%d spells), converter %s."):format(
            c.enabled and "on" or "off", c.panel and "on" or "off",
            c.advanced and "on" or "off", #c.spells,
            type(GetCombatRatingBonusForCombatRatingValue) == "function" and "present" or "MISSING"))
        return
    end
    if not c then return end
    if arg == "on" then c.enabled = true; ns.StatCalc_Apply(); ns.Print("Stat Calculator on."); return end
    if arg == "off" then c.enabled = false; ns.StatCalc_Apply(); ns.Print("Stat Calculator off."); return end
    ns.StatCalc_Toggle()
end, "/xui stats [on|off|options|status] (Stat Calculator panel)")
end
-- (/xui debug widthprobe and its file, CharacterWidthProbe.lua, are XayaUI Dev Assist's since QoL 0.7.33; REQUEST-LOG #81)
