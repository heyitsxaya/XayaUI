-------------------------------------------------------------------------------
-- CharacterToolkit.lua : QoL > Character Toolkit (XayaUI QoL 0.7.0). The panel docked to the character window, its compact stat sheet,
-- (the Stat Calculator: a stat map, a gear comparison, spells), the item level / socket / enchant overlays on the character window's slots, extra lines on the character
-- window's own stat tooltips, and the settings page. OFF by default; while off nothing is created, registered or read.
-- Saved settings: XayaUIQoLDB.characterToolkit (CueRulesDB.characterToolkit before P5). NOT RUN IN GAME when written (2026-11-04): every number needs an in-game check.
--
-- Every number comes from the one model in CharacterModel.lua (the game's own reads; what the game does not give is marked, never
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
--   titles centred, cells from their column's left edge, T/L in two lines; a typed number's new value, with its sign, under the value in
--   the accent colour (no "now -> then" on the Stats tab); Primary / General / Offensive / Defensive are bucket bars and every Stats line
--   is indented by its depth (one step); the Gear Summary is at the top of the Stats tab as a graphic in a chosen style.
--   Gear: the selected equipped item's box is highlighted (a click on it again lets it go); the items you own for the slot are icons
--   (click to pick, several at once, up to 3; the box shows the last one's name); one "Changes" section (Stat | Pt value | Equipped |
--   each picked item, DR threshold and true / lost rating under each secondary that changes, Stat effects, Spell Changes, on-use and
--   proc effects with the RPPM wording) replaces Side by side and What it changes; slots are named Ring slot #1 ... Main-hand, Off-hand.
--   Look: the XayaUI theme's colors and font (ns.Theme): window, border, tab, button and text classes; nothing from another addon.
--   Slot overlays (off by default): item level, empty sockets, and "no enchant" on the slots the player ticks (the game does not say
--   which slots take an enchant).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local QolS = ns.Settings("qol")   -- (QoL 0.7.47, P2 settings seam; QoL 0.7.49, P5: QoL's own XayaUIQoLDB; Modules.lua section 0b)
local CM = ns.CharModel

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local isSecret = CM.IsSecret

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------
ns.CHARTOOLKIT_DEFAULTS = {
    enabled = false,
    panel = true,          -- the docked panel
    side = "right",        -- right | left of the character window
    detail = "all",        -- all | short (detail pairs under each line)
    tooltips = true,       -- extra lines on the character window's stat tooltips
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
    overlays = false,      -- item level / socket / enchant marks on the character window's slots
    ovIlvl = true, ovSockets = true, ovEnchants = true,
    ovSize = 11,
    enchantSlots = {},     -- slot IDs the player ticked to flag when they have no enchant; empty = this expansion's slots (CM.EnchantSlots)
    -- enchantSlotsSet: true once the player has changed a tick (then enchantSlots is used even when empty)
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
    if not ns.SettingsReady("qol") then return nil end
    local c = QolS.characterToolkit
    if type(c) ~= "table" then c = {}; QolS.characterToolkit = c end
    -- (QoL 0.7.23) a height dragged before the Min / Max heights existed becomes the smaller one
    if c.heightSmall == nil and type(c.size) == "table" and num(c.size.h) then c.heightSmall = c.size.h end
    for k, v in pairs(ns.CHARTOOLKIT_DEFAULTS) do
        if c[k] == nil then c[k] = CopyVal(v) end
    end
    if c.side ~= "left" then c.side = "right" end
    if c.detail ~= "short" then c.detail = "all" end
    -- (QoL 0.7.40; REQUEST-LOG B2, reading taken: the "% / rating" toggle is removed in all three places, since the columns already show
    -- rating, current value and Pt value side by side) its two saved keys are dropped; nothing reads them any more
    c.valueMode, c.lineModes = nil, nil
    c.fontSize = math.max(8, math.min(16, tonumber(c.fontSize) or 11))
    c.ovSize = math.max(8, math.min(16, tonumber(c.ovSize) or 11))
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
    for _, k in ipairs({ "whatIfStats", "collapsed", "statOpen", "enchantSlots" }) do
        if type(c[k]) ~= "table" then c[k] = {} end
    end
    for k, v in pairs(c.statOpen) do if v ~= true or type(k) ~= "string" then c.statOpen[k] = nil end end
    for k, v in pairs(c.whatIfStats) do
        local n = math.floor(tonumber(v) or 0)
        c.whatIfStats[k] = (n ~= 0) and math.max(-100000, math.min(100000, n)) or nil
    end
    do local n = math.floor(tonumber(c.whatIfPrimary) or 0); c.whatIfPrimary = (n ~= 0) and math.max(-100000, math.min(100000, n)) or nil end
    if c.enchantSlotsSet ~= true then c.enchantSlotsSet = nil end
    return c
end
ns.CharToolkit_Cfg = Cfg

-- (QoL 0.7.40; REQUEST-LOG B2, reading taken) the value modes are gone: the "Show: % / rating" button in the title row, the click on a
-- rating line that flipped it, and Settings > Panel > Layout "Rating lines" with Your numbers "Reset line flips". Every line shows its
-- value; the columns give rating, current value and Pt value side by side.

-- (QoL 0.7.40; Xaya 2026-11-06, REQUEST-LOG #88: "make each stat collapsible"; her answer "Collapsed (Recommended)") open or fold one stat
-- of the Stats tab (its rows: what feeds it, with the number); remembered per stat in the saved settings (statOpen), folded by default
function ns.CharToolkit_ToggleStat(key)
    local c = Cfg(); if not (c and type(key) == "string") then return end
    c.statOpen[key] = (not c.statOpen[key]) and true or nil
    ns.CharToolkit_Render()
end
function ns.CharToolkit_StatOpen(key)
    local c = Cfg()
    return (c and c.statOpen[key]) and true or false
end

-------------------------------------------------------------------------------
-- The model, flat (one list of { section = title } markers and items with "label: value" lines); used by the tooltip lines
-- on the character window and by tests. tab = a panel tab key, or nil for Stats, Defense and Offense.
-------------------------------------------------------------------------------
function ns.CharToolkit_Model(tab)
    local c = Cfg()
    tab = OLD_TABS[tab] or tab
    local m = CM.Build(c, tab)
    local out = {}
    for _, sec in ipairs(m.sections) do
        if tab == nil or tab == "sheet" or sec.tab == tab then
            out[#out + 1] = { section = sec.title, sectionKey = sec.key, tab = sec.tab }
            for _, it in ipairs(sec.items) do
                it.lines = CM.PairLines(it, c and c.detail == "short")
                out[#out + 1] = it
            end
        end
    end
    return out, m
end
ns.CharToolkit_ClearCache = function() CM.ClearCache() end
ns.CharToolkit_Numbers = function(text) return CM.Numbers(text) end
ns.CharToolkit_SpellName = function(id) return CM.SpellName(id) end
ns.CharToolkit_ItemStats = function(link) return CM.ItemStats(link) end

-- The hover of one line: { { left, right, tone } or { text } }. Used by the panel, the sheet and the tests. A tooltip has one text
-- column, so each line's Pt value follows its value (CM.PairText; the panel draws them in their own columns, QoL 0.7.15). QoL 0.7.24
-- (Xaya, the Note column: "Remove it entirely"): no note text here either, and a line that held only a note is left out.
function ns.CharToolkit_TooltipLines(it, mode)
    local out = {}
    local v, tone = CM.ValueFor(it, mode)
    out[#out + 1] = { it.label or "", CM.PairText({ value = v or "", per = it.per, perPoint = it.perPoint, perText = it.perText }), tone, title = true }
    -- (QoL 0.7.28) a typed number's new value, with its sign, on the line under the value it changes, in the accent colour
    if it.newValue then out[#out + 1] = { "", it.newValue, "change" } end
    for _, p in ipairs(it.pairs or {}) do
        if not CM.NoteOnly(p) then
            out[#out + 1] = { CM.PairLabel(p), CM.PairText(p, true), p.tone }   -- (nested: indented)
            if p.newValue then out[#out + 1] = { "", p.newValue, "change" } end
        end
    end
    if #(it.tip or {}) > 0 then
        out[#out + 1] = { " " }
        for _, l in ipairs(it.tip) do out[#out + 1] = { l } end
    end
    -- (QoL 0.7.40, B2: no "Click: show the rating on this line" any more; #88: a stat with rows says what a click does)
    if it.foldable ~= nil then
        out[#out + 1] = { " " }
        out[#out + 1] = { it.foldable == "open" and "Click: fold its rows into this hover." or "Click: show these rows under the stat.", hint = true }
    end
    return out
end

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
-- XayaUI's default accent when the theme is missing). QoL 0.7.28: the new value a typed number gives (tone "change") and the bucket bars.
local function Accent()
    local T = ns.Theme
    local c = T and T.cur and T.cur.accent
    if type(c) == "table" and num(c[1]) and num(c[2]) and num(c[3]) then return { c[1], c[2], c[3], c[4] or 1 } end
    return { 0.75, 0.25, 1, 1 }
end
ns.CharToolkit_Accent = Accent   -- (tests)
local function ToneColor(tone, fb)
    if tone == "mute" then return TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 }) end
    if tone == "change" then return Accent() end
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
-- spacing from core (#351 phase 2, XayaUI/Modules.lua): PAD = the margin inside the panel, GUT = the gutter between two controls
local PANEL_W, PAD, GUT = 450, ns.UI_MARGIN, ns.UI_GUTTER   -- 450 (QoL 0.7.21, Xaya: "up to 450px" so every column fits; was 380)
local TITLE_H = 18            -- the title row (the mode button is 18 tall)
-- the header (QoL 0.7.40, REQUEST-LOG #91): one line, the equipped item level on the left and the max item level (in bags) on the right
-- (until 0.7.39: name and item level (15), spec and class (11) under them, 32 tall)
local NAME_H = 18
local HEADER = TITLE_H + GUT + NAME_H + GUT + 20 + GUT  -- title row, header, the tab row (20 tall), a gutter before the content
local W = PANEL_W - 2 * PAD   -- content width (changes when the panel is resized: B10, #381)
ns.CHARTOOLKIT_LAYOUT = { width = PANEL_W, pad = PAD, header = HEADER, content = W, minW = MIN_W, maxW = MAX_W, minH = MIN_H, maxH = MAX_H }

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
    for _, l in ipairs(ns.CharToolkit_TooltipLines(it, mode)) do
        if l[2] ~= nil then
            local lc = l.title and label or muted
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
ns.CharToolkit_ShowTooltip = ShowTooltip

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
                ns.CharToolkit_ToggleSpell(self.spellKey)
            elseif self.statKey then   -- (QoL 0.7.40, #88) a stat of the Stats tab with rows under it: open / fold it
                ns.CharToolkit_ToggleStat(self.statKey)
            elseif it and it.kind == "action" and it.action then
                ns.CharToolkit_Action(it.action)
            elseif it and it.kind == "choice" and it.pick then
                ns.CharToolkit_PickItem(it.pick, it.slot)
            elseif it and it.kind == "choice" and it.slot then
                ns.CharToolkit_SetCompareSlot(it.slot)
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
function ns.CharToolkit_ToggleSpell(key)
    local c = Cfg(); if not (c and key) then return end
    c.collapsed = c.collapsed or {}
    c.collapsed[key] = (not c.collapsed[key]) and true or nil
    ns.CharToolkit_Render()
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
            local c = Cfg(); if not (c and self.key) then return end
            -- (a section folded by default, the Inactive spells, keeps an explicit false once opened)
            if self.defaultFolded then c.collapsed[self.key] = not self.folded
            else c.collapsed[self.key] = (not c.collapsed[self.key]) and true or nil end
            ns.CharToolkit_Render()
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
    b:SetScript("OnClick", function(self) if self.item and self.item.action then ns.CharToolkit_Action(self.item.action) end end)
    b:SetScript("OnEnter", function(self) ShowTooltip(self, self.item) end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnMouseWheel", function(_, d) if panel and panel.Scroll then panel.Scroll(d) end end)
    if ns.FlatButton then ns.FlatButton(b) end
    panel.spellBtn = b
    return b
end
-- the filter menu: None (shows all), Offense, Defense, Utility; the chosen one is saved (c.spellFilter) and marked
function ns.CharToolkit_SetSpellFilter(f)
    local c = Cfg(); if not c then return end
    c.spellFilter = f
    c.spellFilter = CM.FilterOf(c)
    if panel and panel.filterMenu then panel.filterMenu:Hide() end
    if scroll then scroll:SetVerticalScroll(0) end
    ns.CharToolkit_Render()
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
        r:SetScript("OnClick", function(self) ns.CharToolkit_SetSpellFilter(self.filter) end)
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
        local m = FilterMenu()
        if m:IsShown() then m:Hide() else m:Show(); ns.CharToolkit_Render() end
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
                ns.CharToolkit_PickItem(self.link, self.slot)   -- a bag item: picked, or let go when it was picked (QoL 0.7.24)
            elseif self.slot then
                ns.CharToolkit_SelectGearSlot(self.slot)   -- an equipped item: selected, or let go when it was (QoL 0.7.24)
            end
        end)
        -- an item dropped on an equipped icon is compared with that slot (plan item 6: "drag and drop")
        b:SetScript("OnReceiveDrag", function(self)
            local ok, kind, id, link = pcall(GetCursorInfo)
            if not ok or kind ~= "item" or not self.slot or self.cand then return end
            local text = (type(link) == "string" and not isSecret(link)) and link or ((type(id) == "number" and not isSecret(id)) and tostring(id) or nil)
            if not text then return end
            if ClearCursor then pcall(ClearCursor) end
            ns.CharToolkit_PickItem(text, self.slot, true)
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
        eb:SetScript("OnEnterPressed", function(self)
            ns.CharToolkit_SetInput(self.key, self:GetText())
            self:ClearFocus()
        end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
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
                ns.CharToolkit_SetInput("item", text)
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
function ns.CharToolkit_SetInput(key, text)
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
    ns.CharToolkit_Render()
end
-- the equipped item to compare against when two could be replaced (Gear > "Replace instead")
function ns.CharToolkit_SetCompareSlot(slot)
    local c = Cfg(); if not c then return end
    CM.compareSlot, CM.gearSlot = slot, slot
    ns.CharToolkit_Render()
end
-- the Spells tab's buttons: Configure spell data (turns Spell Math on and reads everything, #377) and Refresh spell data
function ns.CharToolkit_Action(action)
    local c = Cfg(); if not c then return end
    if action == "configureSpells" then c.advanced = true end
    if action == "configureSpells" or action == "refreshSpells" then
        local RS = ns.Service and ns.Service("rules")   -- (QoL 0.7.48, P4) XayaUI Rules' cached spellbook and talent lists (Conditions.lua) are read again
        if RS then RS.ForgetSpellLists() end
        CM.ClearTalents(); CM.ResetSpellRequests()
    end
    ns.CharToolkit_Render()
end
-- Gear: a clicked equipped item picks its slot; an item compared before that does not fit the slot is let go. QoL 0.7.24 (Xaya:
-- "clicking it again should deselect it"): a click on the selected one lets it go and clears the comparison.
function ns.CharToolkit_SelectGearSlot(slot)
    local c = Cfg(); if not c then return end
    local st = CM.CompareState and CM.CompareState()
    if slot ~= nil and st and st.slot == slot then
        CM.gearSlot, CM.compareSlot, CM.compareText, CM.compareLinks = nil, nil, nil, {}
        if boxes.item then boxes.item:SetText("") end
        ns.CharToolkit_Render()
        return
    end
    CM.gearSlot, CM.compareSlot = slot, slot
    local keep = {}
    for _, l in ipairs(CM.compareLinks or {}) do if CM.FitsSlot(l, slot) then keep[#keep + 1] = l end end
    CM.compareLinks = keep
    local link = (CM.compareText or "") ~= "" and CM.ResolveItemLink(CM.compareText) or nil
    if link and not CM.FitsSlot(link, slot) then CM.compareText = nil end
    if boxes.item and CM.compareText == nil then boxes.item:SetText("") end
    ns.CharToolkit_Render()
end
-- Gear: compare this item (a link or an ID) with the given slot (a bag item clicked in the list, or an item dropped on an icon).
-- QoL 0.7.24: a bag item clicked again is let go (several can be picked: CM.compareLinks); the box shows the last one picked. add:
-- never let go (a dropped item).
function ns.CharToolkit_PickItem(text, slot, add)
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
    ns.CharToolkit_Render()
end

local function Build()
    if panel then return end
    panel = CreateFrame("Frame", "XayaUICharacterToolkit", UIParent)
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
    panel.title:SetText("Stat Calculator")   -- Xaya 2026-11-04: the panel's title (the feature is still Character Toolkit in the settings)
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
        ns.CharToolkit_Render()
    end)
    grip:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Drag to resize", 1, 0.82, 0)
        GameTooltip:AddLine("The width is kept; the height becomes the current Min / Max height. QoL > Character Toolkit > Panel: Reset size goes back to the defaults.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    panel.grip = grip
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(24, 24)   -- the template's own size (UIPanelCloseButtonNoScripts, SharedUIPanelTemplates.xml:135, live 12.1.5)
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() ns.CharToolkit_SetOpen(false) end)
    -- (QoL 0.7.40, REQUEST-LOG B2: the "Show: % / rating" value mode button, hidden since 0.7.14, is no longer made)
    -- the Min / Max button (QoL 0.7.23; Xaya 2026-11-05: "a min/max window toggle that toggles between two configured sizes -- one
    -- smaller and one larger (NOT full screen, just longer) -- as well as the free resize option in the bottom corner"): in the title
    -- row, a gutter left of the close button (where the hidden value-mode button sat). Max: the larger height; Min: the smaller one.
    local sb = CreateFrame("Button", nil, panel)
    sb:SetSize(40, 18)
    sb:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(22 + GUT), -PAD)
    sb.bg = sb:CreateTexture(nil, "BACKGROUND"); sb.bg:SetAllPoints(sb)
    sb.text = sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); sb.text:SetPoint("CENTER")
    sb:SetScript("OnClick", function() ns.CharToolkit_SizeMode() end)
    sb:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local c = Cfg()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine((c and c.sizeMode == "large") and "Smaller" or "Larger", 1, 0.82, 0)
        GameTooltip:AddLine(("Switches between the two heights set in QoL > Character Toolkit > Panel (now %d and %d). Drag the bottom-right corner to resize freely; that sets the current one."):format(
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
            local c = Cfg(); if not c then return end
            c.tab = t[1]
            if scroll then scroll:SetVerticalScroll(0) end
            ns.CharToolkit_Render()
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
        if type(link) ~= "string" or isSecret(link) or not link:find("|Hitem:", 1, true) then return end
        local eb = boxes.item
        if not (eb and eb.xuiUsed and panel and panel:IsShown()) then return end
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
        ns.CharToolkit_SetInput("item", link)
    end
    local hookTargets = ns.Compat and ns.Compat.ChatHookTargets
    if type(hooksecurefunc) == "function" and type(hookTargets) == "function" then
        for _, t in ipairs(hookTargets("InsertLink")) do pcall(hooksecurefunc, t[1], t[2], InsertLink) end
    end
    panel:Hide()
end

local function Place()
    local c = Cfg(); if not c or not panel then return end
    panel:ClearAllPoints()
    local cf = _G.CharacterFrame
    if Docked() then
        if c.side == "left" then panel:SetPoint("TOPRIGHT", cf, "TOPLEFT", -GUT, 0)
        else panel:SetPoint("TOPLEFT", cf, "TOPRIGHT", GUT, 0) end
    else
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
    if not num(h) or h < size then h = size end
    Rec(kind or "text", x, y, w, h, text, size)
    layout[#layout].justify = justify or "LEFT"   -- (QoL 0.7.36: the tests read a column's alignment)
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
ns.CharToolkit_TextW = TextW   -- (tests)
-- the widest word of a text (a column narrower than this would cut that word: the game wraps only at spaces)
local function WordW(text, size)
    local m = 0
    for word in tostring(text or ""):gmatch("%S+") do m = math.max(m, TextW(word, size)) end
    return m
end
-- Column widths that fit `avail` (QoL 0.7.28). Each column c = { min, line, want }: every column gets its min first (the widest word of
-- its title and cells: nothing is cut), then each title on one line (line), then each column's wanted width (its widest cell: want),
-- smallest need first, while there is room; what is left goes to column `rest`. Only when even the mins do not fit (the narrowest panel
-- at the largest text sizes) are the columns scaled down to fit.
local function FitCols(cols, avail, rest)
    local w, used = {}, 0
    for i, c in ipairs(cols) do w[i] = c.min or 0; used = used + w[i] end
    for _, lvl in ipairs({ "line", "want" }) do
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
ns.CharToolkit_FitCols = FitCols   -- (tests)

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
ns.CharToolkit_InflKind = InflKind   -- (tests)
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
ns.CharToolkit_GridCols = GridCols   -- (tests: the x positions the cells must sit at)

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
        -- "New value with sign") a typed number's new value, with its sign, under the current value, in the theme's accent colour
        if o.newValue then vh = vh + 1 + PlaceFS(FS(), g.vx, y + vh + 1, g.val, o.size, o.newValue, Accent(), "RIGHT", true, K("change")) end
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
ns.CHARTOOLKIT_INDENT = INDENT   -- (tests)
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
                value = v, valueCol = ToneColor(tone, cText), per = it.per, perCol = cText, box = boxed, boxH = boxH, newValue = it.newValue })
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
            -- left of its name, and its rows are in its hover (CharToolkit_TooltipLines lists every line); a click on the stat opens it
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
                        label = p.label, value = p.value, per = p.per, perPoint = p.perPoint, perText = p.perText, newValue = p.newValue, tone = p.tone,
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
                    valueCol = ToneColor(p.tone, cText), per = p.per, perCol = pcol, kind = "pair", newValue = p.newValue })
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
-- its own once the panel is wide enough (content 560 or wider), else it goes under its row, from one indent in to the right edge. Every
-- cell wraps inside its column. A row's hover is the whole row: "{stat} increases / decreases {other stat} by {amount}", one line per
-- influence (CM: it.tip).
-- QoL 0.7.28 (Xaya 2026-11-06, her words: "center columns under stat weights and make sure titles do not get clipped; numbers should be
-- left-aligned; T/L rating should be T: # [line break] L: "; her answer "Titles centred over columns"; in game "Rating (P / %)" wrapped
-- and "DR Thres..." was cut at the default width): the widths come from the titles and cells as the game measures them (TextW), not
-- from fixed numbers: every column is at least as wide as the widest word of its title and cells (nothing is cut), then wide enough
-- for its title on one line, then for its widest cell (FitCols); the Stat column (narrow panel) or Influences (wide panel) takes the
-- rest. Titles are centred over their columns; every cell starts at its column's left edge; the T/L cell is two lines.
local WT_WIDE = 560
local WT_TITLES = { "Stat", "Rating (P / %)", "PPP", "DR Threshold", "T/L Rating", "Influences" }
local function WeightCols(items, size)
    size = size or 11
    local hs = size - 1
    local titles = WT_TITLES
    for _, it in ipairs(items or {}) do if it.kind == "weighthead" and type(it.cols) == "table" then titles = it.cols end end
    local g = { wide = W >= WT_WIDE, titles = titles }
    local n = g.wide and 6 or 5
    local spec = {}
    for i = 1, n do
        local t = titles[i] or ""
        spec[i] = { min = WordW(t, hs), line = TextW(t, hs), want = TextW(t, hs) }
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
            if g.wide then spec[6].min = math.max(spec[6].min, WordW(it.influences, size - 1)) end
        end
    end
    local w = FitCols(spec, W - (n - 1) * GUT, g.wide and 6 or 1)
    g.w = w
    g.stat, g.rat, g.ppp, g.dr, g.tl = w[1], w[2], w[3], w[4], w[5]
    g.rx = g.stat + GUT
    g.px = g.rx + g.rat + GUT
    g.dx = g.px + g.ppp + GUT
    g.tx = g.dx + g.dr + GUT
    if g.wide then g.ix = g.tx + g.tl + GUT; g.iw = w[6] else g.ix = 12; g.iw = W - 12 end
    g.xs = { 0, g.rx, g.px, g.dx, g.tx, g.wide and g.ix or nil }
    return g
end
ns.CharToolkit_WeightCols = WeightCols   -- (tests)
local function RenderWeights(c, items, y)
    local size = c.fontSize
    local cText = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local cMuted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local g = WeightCols(items, size)
    for _, it in ipairs(items) do
        local top = y
        if it.kind == "weighthead" then
            local cs, hs = it.cols or {}, size - 1
            local h = 0
            for i = 1, (g.wide and 6 or 5) do
                h = math.max(h, PlaceFS(FS(), g.xs[i], y, g.w[i], hs, cs[i] or "", cMuted, "CENTER", true, "wcolhead"))
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
            if g.wide then
                h = math.max(h, PlaceFS(FS(), g.ix, y, g.iw, size - 1, it.influences or "", cMuted, "LEFT", true, "winfl"))
            else
                h = h + 1 + PlaceFS(FS(), g.ix, y + h + 1, g.iw, size - 1, it.influences or "", cMuted, "LEFT", true, "winfl")
            end
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
-- number"); under the first Computed Value, the new value a typed number gives, with its sign, in the accent colour (as on the Stats tab).
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
ns.CharToolkit_SpellCols = SpellCols   -- (tests)
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
                if e.newValue then hv = hv + 1 + PlaceFS(FS(), g.vx, ey + hv + 1, g.val, size, e.newValue, Accent(), "LEFT", true, "spellchange") end
                hm = hm + math.max(hv, hp) + 2
            end
            for _, sm in ipairs(r.statMods or {}) do
                hm = hm + PlaceFS(FS(), g.px, y + hm, g.psv, hs, sm, cMuted, "LEFT", true, "spellstat") + 1
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
ns.CharToolkit_MultiCols = MultiCols   -- (tests)
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
    ns.CHARTOOLKIT_LAYOUT.width, ns.CHARTOOLKIT_LAYOUT.content = pw, W
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
ns.CharToolkit_HeaderText = function(h)
    h = h or {}
    return h.ilvlEquipped and ("Equipped %.1f"):format(h.ilvlEquipped) or "", h.ilvlOverall and ("Max (bags) %.1f"):format(h.ilvlOverall) or ""
end
local function RenderHeader(c)
    local h = CM.HeaderInfo()
    local muted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local label = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    local left, right = ns.CharToolkit_HeaderText(h)
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

function ns.CharToolkit_Render()
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
end

-- what the panel drew last: { model, layout records, mode button text }; for the tests
function ns.CharToolkit_Drawn()
    if not panel then return nil end
    return { model = panel.model, layout = panel.layoutRecs, sizeText = panel.sizeText, buttons = btnPool, headers = hdrPool, boxes = boxes,
        fonts = fsPool, icons = iconBtns, spellBtn = panel.spellBtn, filterIcon = panel.filterIcon, filterMenu = panel.filterMenu,
        menuRecs = panel.menuRecs, textures = texPool }
end

-- (QoL 0.7.40) the Stat Calculator through core's service list (Modules.lua ns.Provide), for XayaUI Dev Assist's QA walkthroughs
-- (QAWalks-statcalc.lua: REQUEST-LOG #88-#91, B2): they read what the panel drew and press its controls, never its own tables. Only a
-- table of functions is registered when this file loads; nothing is built, registered or read until a walkthrough calls one (V14: with
-- the Character Toolkit off, Open says so and does nothing).
if ns.Provide then
    ns.Provide("statCalc", {
        Cfg = function() return Cfg() end,
        -- open the panel on a tab ("stats" | "gear" | "spells"); false and why when the toolkit or its panel is off
        Open = function(tab)
            local c = Cfg()
            if not c then return false, "no saved settings yet" end
            if not c.enabled then return false, "Character Toolkit is off (QoL > Character Toolkit)" end
            if not c.panel then return false, "the Stat Calculator panel is off (QoL > Character Toolkit > Panel)" end
            if tab then c.tab = tab end
            ns.CharToolkit_SetOpen(true)
            return panel ~= nil and panel:IsShown()
        end,
        Shown = function() return panel ~= nil and panel:IsShown() end,
        Close = function() if panel and panel:IsShown() then ns.CharToolkit_SetOpen(false) end end,
        Drawn = function() return ns.CharToolkit_Drawn() end,
        ToggleStat = function(key) ns.CharToolkit_ToggleStat(key) end,
        SelectGearSlot = function(slot) ns.CharToolkit_SelectGearSlot(slot) end,
        PickItem = function(link, slot) ns.CharToolkit_PickItem(link, slot) end,
        -- the header as drawn: left text, right text, and the game's two item levels it came from
        Header = function()
            if not panel then return nil end
            return panel.hEq:GetText(), panel.hMax:GetText(), CM.HeaderInfo()
        end,
        HasModeButton = function() return panel ~= nil and panel.modeBtn ~= nil end,
        Page = function() return ns.BuildCharToolkitPage and ns.BuildCharToolkitPage(function() end) end,
        TextW = function(text, size) return panel and TextW(text, size) or nil end,
    })
end

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
-- Events: only while the toolkit is on. Refresh is throttled to one per 0.25 s and only while the panel is up.
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
local OVERLAY_EVENTS = { PLAYER_EQUIPMENT_CHANGED = true, GET_ITEM_INFO_RECEIVED = true, SOCKET_INFO_UPDATE = true, ENCHANT_SPELL_COMPLETED = true }

local function Refresh()
    if pending then return end
    pending = true
    local run = function() pending = false; if panel and panel:IsShown() then ns.CharToolkit_Render() end end
    if C_Timer and C_Timer.After then C_Timer.After(0.25, run) else run() end
end

local function ReadGCD()
    if CM.ReadGCD() and panel and panel:IsShown() then Refresh() end
end
ns.CharToolkit_ReadGCD = ReadGCD

-- the character window opened: the panel docks beside it when it was left open (c.panelOpen, kept between sessions; QoL 0.7.23, Xaya
-- 2026-11-05: "remember the last-left state on next open")
local function ShowIfDocked()
    local c = Cfg()
    if not (c and c.enabled and c.panel) then return end
    if not c.panelOpen then
        if panel and panel:IsShown() then panel:Hide() end
        ns.CharToolkit_UpdateButton()
        return
    end
    Build()
    if not panel:IsShown() then panel.standalone = false end
    panel:Show()
    ns.CharToolkit_Render()
    ns.CharToolkit_UpdateButton()
end

local overlayPending
local function RefreshOverlays()
    if overlayPending then return end
    overlayPending = true
    local run = function() overlayPending = false; if Docked() then ns.CharToolkit_UpdateOverlays() end end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, run) else run() end
end

local function OnEvent(_, event, unit)
    if event == "SPELL_UPDATE_COOLDOWN" then ReadGCD(); return end
    -- the Spells tab: a description it asked for arrived, or the spellbook changed (core resets its spell list on SPELLS_CHANGED)
    if event == "SPELL_DATA_LOAD_RESULT" or event == "SPELLS_CHANGED" then
        local c = Cfg()
        if c and c.tab == "spells" and panel and panel:IsShown() and (event == "SPELLS_CHANGED" or CM.SpellRequested(unit)) then Refresh() end
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LEVEL_UP" then CM.ClearCache() end
    if event == "PLAYER_REGEN_ENABLED" then CM.gcdHidden = false end   -- out of combat the last readable GCD shows again
    if OVERLAY_EVENTS[event] then local c = Cfg(); if c and c.overlays then RefreshOverlays() end end
    if unit and unit ~= "player" and event:find("^UNIT_") then return end
    if panel and panel:IsShown() then Refresh() end
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
    local clean = setmetatable({ whatIf = 0, whatIfStats = {}, whatIfPrimary = false }, { __index = c })
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
        local it = CM.Build(c, nil).byKey[key]
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
local ownerHooked, themeHooked, slotHooked, statHooked = false, false, false, false
-- (QoL 0.7.24, V14) the Tooltip lines' hooks (PaperDollFrame_UpdateStats and each stat row's OnEnter) are placed only once the Tooltip
-- lines are on; before, they came with the toolkit even while the lines were off. Placed, they return at once while it is off.
local function TooltipLinesOn() local c = Cfg(); return (c and c.enabled and c.tooltips) and true or false end

-------------------------------------------------------------------------------
-- The Stat Calc button on the character window and the Stat Calculator row in XayaUI's minimap button list (QoL 0.7.23; Xaya
-- 2026-11-05, her words: "stat calculator should have a toggle open/close button on the character menu and remember the last-left
-- state on next open; it should also have its own open button on the minimap and should be openable as its own standalone window
-- without opening the character sheet"). Both exist only while the toolkit and its panel are on (V14): the button is made the first
-- time they are on and hidden when either goes off; the minimap row (ns.RegisterLauncher, core Modules.lua) is registered once and
-- its available() keeps it out of the list while either is off (core 0.6.48; the entry itself stays registered so the settings
-- window's options tree does not change with the switch: tests/sidebar_switches_run.py).
-------------------------------------------------------------------------------
local charBtn
-- Placement (DECISION): the character window's title row, a gutter left of Blizzard's close button, 64 x 18. INFERENCE (Blizzard's
-- ButtonFrameTemplate, not re-read for this change): the close button is the window's CloseButton key (global CharacterFrameCloseButton)
-- in its top-right corner, the title text is centred, and nothing else of Blizzard's sits in that row; the item slots, the model and
-- the stats pane start below the title row. The reskin's wider window (QoL 0.7.21) moves the right edge, and the close button and this
-- button with it. Without a close button, the same place from the window's top-right corner.
local function CharButton()
    if charBtn then return charBtn end
    local cf = _G.CharacterFrame
    if not (cf and CreateFrame) then return nil end
    local b = CreateFrame("Button", "XayaUICharacterToolkitButton", cf)
    b:SetSize(64, 18)
    local close = (type(cf.CloseButton) == "table" and cf.CloseButton) or _G.CharacterFrameCloseButton
    if close then b:SetPoint("RIGHT", close, "LEFT", -4, 0) else b:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -28, -3) end
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.text:SetPoint("CENTER")
    b.text:SetText("Stat Calc")
    if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp") end
    b:SetScript("OnClick", function() ns.CharToolkit_Toggle() end)
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
-- the button's look follows the panel: the theme's selected-tab colours while the panel is open
function ns.CharToolkit_UpdateButton()
    local c = Cfg()
    if not (c and c.enabled and c.panel) then if charBtn then charBtn:Hide() end; return end
    local b = CharButton(); if not b then return end
    local open = panel ~= nil and panel:IsShown()
    local cls = open and "xui-tab-selected" or "xui-button"
    local bg = TC(cls, "bg", open and { 0.22, 0.1, 0.3, 0.9 } or { 0.04, 0.04, 0.04, 0.7 })
    b.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
    Paint(b.text, TC(cls, "text", open and { 1, 1, 1, 1 } or { 1, 0.82, 0, 1 }))
    b.open = open
    b:Show()
end
if type(ns.RegisterLauncher) == "function" then
    ns.RegisterLauncher({ "stats", "Stat Calculator", "Show or hide the Stat Calculator on its own, without the character window (also /xui stats)",
        function() ns.CharToolkit_Toggle() end, nil, order = 12,   -- O-100 (QoL 0.7.42, her answer "No word at all"): no "on" / "off" for shown / hidden
        available = function() local c = Cfg(); return (c and c.enabled and c.panel) and true or false end })
end
function ns.CharToolkit_Apply()
    local c = Cfg(); if not c then return end
    if not c.enabled then
        if ev then ev:UnregisterAllEvents() end
        if panel then panel:Hide() end
        for _, o in pairs(overlays) do o:Hide() end
        ns.CharToolkit_UpdateButton()
        return
    end
    if not ev then
        ev = CreateFrame("Frame")
        ev:SetScript("OnEvent", OnEvent)
    end
    ev:UnregisterAllEvents()
    -- (D17, V14) the panel's stat / unit events and the GCD read only while its "Show the panel" part is on; with it off, only what the
    -- slot overlays need (while they are on) and the cache reset on a spec change / level up (the overlays and tooltip lines read it)
    if c.panel then
        for _, e in ipairs(STAT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
        for _, e in ipairs(UNIT_EVENTS) do
            if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, e, "player") else pcall(ev.RegisterEvent, ev, e) end
        end
        pcall(ev.RegisterEvent, ev, "SPELL_UPDATE_COOLDOWN")
    else
        pcall(ev.RegisterEvent, ev, "PLAYER_SPECIALIZATION_CHANGED")
        pcall(ev.RegisterEvent, ev, "PLAYER_LEVEL_UP")
        if c.overlays then for e in pairs(OVERLAY_EVENTS) do pcall(ev.RegisterEvent, ev, e) end end
    end
    if not ownerHooked then
        local owner = Owner()
        if owner and owner.HookScript then
            ownerHooked = true
            owner:HookScript("OnShow", function() ShowIfDocked(); if TooltipLinesOn() then HookStatFrames() end; ns.CharToolkit_UpdateOverlays() end)
            -- the character window closed: a panel that docked with it closes with it (its open state is kept for next time); one
            -- opened on its own stays open and goes back to its own place (QoL 0.7.23)
            owner:HookScript("OnHide", function()
                if not panel or not panel:IsShown() then return end
                local cc = Cfg()
                if panel.standalone and cc and cc.enabled and cc.panel then ns.CharToolkit_Render() else panel:Hide() end
            end)
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
    if not themeHooked and ns.Theme and ns.Theme.OnResolve then
        themeHooked = true
        ns.Theme.OnResolve(function() if panel and panel:IsShown() then ns.CharToolkit_Render() end end)
    end
    ns.CharToolkit_UpdateOverlays()
    if panel then
        if not c.panel then panel:Hide()
        elseif panel:IsShown() then ns.CharToolkit_Render()
        elseif Docked() and c.panelOpen then ShowIfDocked() end
    elseif c.panel and Docked() then
        ShowIfDocked()
    end
    ns.CharToolkit_UpdateButton()
end

-- Open or close the panel (QoL 0.7.23): the character window's Stat Calc button, the minimap list's Stat Calculator row, /xui stats
-- and the panel's own close button. The state is saved (c.panelOpen) and the character window opens with it next time. Opened while
-- the character window is closed, the panel stands on its own at its own place (c.free, kept when you drag it) and stays open when
-- the character window opens and closes again; opened with the character window, it docks beside it and closes with it.
function ns.CharToolkit_SetOpen(open)
    local c = Cfg(); if not c then return end
    if not c.enabled then
        ns.Print("Character Toolkit is off. Turn it on in QoL > Character Toolkit (or /xui stats on).")
        return
    end
    if not c.panel then
        ns.Print("The Stat Calculator panel is off. Turn it on in QoL > Character Toolkit > Panel.")
        return
    end
    c.panelOpen = open and true or false
    if open then
        Build()
        if not panel:IsShown() then panel.standalone = not Docked() end
        panel:Show()
        ns.CharToolkit_Render()
    elseif panel then
        panel:Hide()
    end
    ns.CharToolkit_UpdateButton()
end
function ns.CharToolkit_Toggle()
    ns.CharToolkit_SetOpen(not (panel and panel:IsShown()))
end
-- the Min / Max button: the other of the two heights
function ns.CharToolkit_SizeMode(mode)
    local c = Cfg(); if not c then return end
    c.sizeMode = mode or ((c.sizeMode == "large") and "small" or "large")
    if c.sizeMode ~= "large" then c.sizeMode = "small" end
    ns.CharToolkit_Render()
end

ns.WhenSettingsReady("qol", function() if Cfg() then ns.CharToolkit_Apply() end end)   -- (P5: once XayaUIQoLDB is open, at this addon's ADDON_LOADED; Modules.lua section 0c)
-- (audit QA walkthrough, D17) which of the toolkit's events are registered now; its settings, and Apply after changing them
if ns.Provide then ns.Provide("charToolkitDebug", { Cfg = function() return Cfg() end, Apply = function() return ns.CharToolkit_Apply() end,
    Registered = function(e) return (ev and ev.IsEventRegistered and ev:IsEventRegistered(e)) and true or false end }) end

-------------------------------------------------------------------------------
-- Settings: QoL > Character Toolkit (a feature node; its parts Panel, Slot Overlays and Spell Math are nodes under it, and each
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
ns.CharToolkit_ResolveSpell = ResolveSpell

function ns.BuildCharToolkitPage(Notify)
    local function C() return Cfg() or CopyVal(ns.CHARTOOLKIT_DEFAULTS) end
    local function Changed() ns.CharToolkit_Apply(); if Notify then Notify() end end
    local isOff = function() return not C().enabled end
    local addBuf = ""
    local function Toggle(key, order, name, desc, width, hidden, tip)
        return { type = "toggle", order = order, width = width, name = name, desc = desc, hidden = hidden, tip = tip,
            get = function() return C()[key] and true or false end,
            set = function(_, v) C()[key] = v and true or false; Changed() end }
    end

    -- each part's on/off (and the toolkit's own) is the tick box on its row in the left pane: xuiSwitch (QoL 0.7.18; Xaya 2026-11-05:
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
                    if not id then ns.Print("Character Toolkit: no spell found for \"" .. tostring(v) .. "\"."); return end
                    local c = Cfg(); if not c then return end
                    for _, s in ipairs(c.spells) do if s.id == id then return end end
                    if #c.spells >= 20 then ns.Print("Character Toolkit: up to 20 spells."); return end
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
        xuiSwitch = Toggle("panel", 1, "Show the panel", "The Stat Calculator: the Stat Calc button on the character window opens and closes it beside the window (it opens the same way next time); the XayaUI minimap button's Stat Calculator row and /xui stats open it on its own. Off: no panel, no button, no minimap row.", nil, nil, "Shows the Stat Calculator beside the character window."),
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
        xuiSwitch = Toggle("enabled", 1, "Character Toolkit", "Turns the toolkit on. While it is off nothing is created, registered or read.", nil, nil, "Turns on the Stat Calculator and its character window tools."),
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "The Stat Calculator: a panel beside the character window (its Stat Calc button) or on its own (the XayaUI minimap button, /xui stats): every stat the game gives in one Character Stats section, where each number comes from, what the next point buys, what each stat feeds (type your own numbers to see the change), the Stat Weights pane, and a gear comparison. What the game does not give is marked, never guessed. Turn it on with the tick box on its row on the left; its parts (Panel, Slot Overlays, Spell Math, Tooltip lines) then show under it, each with its own tick box. Off by default." },
            panelPart = panelPart,
            overlayPart = overlayPart,
            spells = spells,
            tipsPart = tipsPart,
        },
    }
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua: core never calls this file by name.
-------------------------------------------------------------------------------
ns.RegisterSettingsPage("qol", "chartoolkit", ns.BuildCharToolkitPage)
ns.RegisterCommand("stats", function(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local c = Cfg()
    if arg == "options" or arg == "settings" then ns.OpenSettingsPage("qol", "chartoolkit"); return end
    if arg == "help" then
        ns.Print("/xui stats: show or hide the Stat Calculator (on its own when the character window is closed). /xui stats on | off | options | status")
        return
    end
    if arg == "status" then
        if not c then ns.Print("Character Toolkit: settings not ready."); return end
        ns.Print(("Character Toolkit: %s, panel %s, slot overlays %s, tooltips %s, spell math %s (%d spells), converter %s."):format(
            c.enabled and "on" or "off", c.panel and "on" or "off", c.overlays and "on" or "off", c.tooltips and "on" or "off",
            c.advanced and "on" or "off", #c.spells,
            type(GetCombatRatingBonusForCombatRatingValue) == "function" and "present" or "MISSING"))
        return
    end
    if not c then return end
    if arg == "on" then c.enabled = true; ns.CharToolkit_Apply(); ns.Print("Character Toolkit on."); return end
    if arg == "off" then c.enabled = false; ns.CharToolkit_Apply(); ns.Print("Character Toolkit off."); return end
    ns.CharToolkit_Toggle()
end, "/xui stats [on|off|options|status] (Character Toolkit stat panel)")
-- (/xui debug widthprobe and its file, CharacterWidthProbe.lua, are XayaUI Dev Assist's since QoL 0.7.33; REQUEST-LOG #81)
