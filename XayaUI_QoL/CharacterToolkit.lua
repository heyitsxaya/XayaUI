-------------------------------------------------------------------------------
-- CharacterToolkit.lua : QoL > Character Toolkit (XayaUI QoL 0.7.0). The panel docked to the character window, its compact stat sheet,
-- (the Stat Calculator: a stat map, a gear comparison, spells), the item level / socket / enchant overlays on the character window's slots, extra lines on the character
-- window's own stat tooltips, and the settings page. OFF by default; while off nothing is created, registered or read.
-- Saved settings: CueRulesDB.characterToolkit. NOT RUN IN GAME when written (2026-11-04): every number needs an in-game check.
--
-- Every number comes from the one model in CharacterModel.lua (the game's own reads; what the game does not give is marked, never
-- guessed; secret values show as "hidden in combat"). This file only draws it:
--   Tabs: Stats | Gear | Spells (the Sheet tab was removed in QoL 0.7.14: the character window itself is restyled instead,
--   QoL Character Reskin; the What If tab in 0.7.14: its numbers are the stat map's boxes, its item compare the Gear comparison).
--   Stats is the stat map: one card per stat with a box holding the number itself and what it feeds, "now -> with your number".
--   Gear: the equipped items as icons; click one to list what you own for that slot, pick one, and see the two side by side and
--   everything the change does through the stat map. The Spells tab lists the spells added by hand and every spell of the
--   spellbook with numbers in its description, under All / Offense / Defense filter buttons (spells only since 0.7.14).
--   Each tab is made of sections with a header (click a header to fold it). Each stat line is label and value, with its detail
--   pairs under it; hovering a line shows where the number comes from (the conversion hover: rating through the game's converter,
--   base and buffs, linked conversions such as crit to parry where the game reports them, thresholds).
--   Rating lines show a percent or a rating: the "%" / "rating" button in the title row sets it for every line, and clicking a
--   rating line flips that line alone.
--   Look: the XayaUI theme's colors and font (ns.Theme): window, border, tab, button and text classes; nothing from another addon.
--   Slot overlays (off by default): item level, empty sockets, and "no enchant" on the slots the player ticks (the game does not say
--   which slots take an enchant).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
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
    spellFilter = "all",   -- the Spells tab's filter: all | offense | defense (QoL 0.7.7: these were the Defense and Offense tabs)
    spellsAll = false,     -- list spellbook spells whose description has no numbers too
    free = { x = 0, y = 0 }, -- position when shown with /xui stats and the character window closed
    tab = "stats",         -- the panel tab last shown
    whatIf = 0,            -- What If: rating added to every stat (0 = off)
    whatIfStats = {},      -- What If: rating added to one stat, by stat key
    valueMode = "percent", -- rating lines show their percent or their rating
    lineModes = {},        -- one line flipped away from valueMode, by stat key
    collapsed = {},        -- folded section headers, by section key
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
    if not CueRulesDB then return nil end
    local c = CueRulesDB.characterToolkit
    if type(c) ~= "table" then c = {}; CueRulesDB.characterToolkit = c end
    for k, v in pairs(ns.CHARTOOLKIT_DEFAULTS) do
        if c[k] == nil then c[k] = CopyVal(v) end
    end
    if c.side ~= "left" then c.side = "right" end
    if c.detail ~= "short" then c.detail = "all" end
    if c.valueMode ~= "rating" then c.valueMode = "percent" end
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
            if s.kind ~= "offense" and s.kind ~= "defense" and s.kind ~= "both" then s.kind = nil end
        end
    end
    if type(c.free) ~= "table" then c.free = { x = 0, y = 0 } end
    if type(c.size) == "table" and num(c.size.w) and num(c.size.h) then
        c.size.w = math.floor(math.max(MIN_W, math.min(MAX_W, c.size.w)) + 0.5)
        c.size.h = math.floor(math.max(MIN_H, math.min(MAX_H, c.size.h)) + 0.5)
    else c.size = nil end
    c.tab = OLD_TABS[c.tab] or c.tab
    -- QoL 0.7.7: the Defense and Offense tabs became the Spells tab's filters (Xaya 2026-11-04)
    if c.tab == "defense" or c.tab == "offense" then c.spellFilter = c.tab; c.tab = "spells" end
    if not CM.TAB_OK[c.tab] then c.tab = "stats" end
    c.spellFilter = CM.FilterOf(c)
    c.spellsAll = c.spellsAll == true
    c.whatIf = math.max(-100000, math.min(100000, math.floor(tonumber(c.whatIf) or 0)))
    for _, k in ipairs({ "whatIfStats", "lineModes", "collapsed", "enchantSlots" }) do
        if type(c[k]) ~= "table" then c[k] = {} end
    end
    for k, v in pairs(c.whatIfStats) do
        local n = math.floor(tonumber(v) or 0)
        c.whatIfStats[k] = (n ~= 0) and math.max(-100000, math.min(100000, n)) or nil
    end
    do local n = math.floor(tonumber(c.whatIfPrimary) or 0); c.whatIfPrimary = (n ~= 0) and math.max(-100000, math.min(100000, n)) or nil end
    for k, v in pairs(c.lineModes) do if v ~= "rating" and v ~= "percent" then c.lineModes[k] = nil end end
    if c.enchantSlotsSet ~= true then c.enchantSlotsSet = nil end
    return c
end
ns.CharToolkit_Cfg = Cfg

-- the value mode one rating line uses: its own flip, else the panel's setting
local function ModeFor(c, key) return (c and c.lineModes[key]) or (c and c.valueMode) or "percent" end
ns.CharToolkit_ModeFor = ModeFor
-- click on a rating line: flip that line; a flip back to the panel's setting clears it
function ns.CharToolkit_FlipLine(key)
    local c = Cfg(); if not c then return end
    local nxt = ModeFor(c, key) == "rating" and "percent" or "rating"
    c.lineModes[key] = (nxt ~= c.valueMode) and nxt or nil
end
-- the "%" / "rating" button: every line, and every single-line flip is cleared
function ns.CharToolkit_SetValueMode(mode)
    local c = Cfg(); if not c then return end
    c.valueMode = (mode == "rating") and "rating" or "percent"
    c.lineModes = {}
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

-- The hover of one line: { { left, right, tone } or { text } }. Used by the panel, the sheet and the tests.
function ns.CharToolkit_TooltipLines(it, mode)
    local out = {}
    local v, tone = CM.ValueFor(it, mode)
    out[#out + 1] = { it.label or "", v or "", tone, title = true }
    for _, p in ipairs(it.pairs or {}) do out[#out + 1] = { p.label, tostring(p.value), p.tone } end
    if #(it.tip or {}) > 0 then
        out[#out + 1] = { " " }
        for _, l in ipairs(it.tip) do out[#out + 1] = { l } end
    end
    if it.kind == "rating" then
        out[#out + 1] = { " " }
        out[#out + 1] = { mode == "rating" and "Click: show the percent on this line." or "Click: show the rating on this line.", hint = true }
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
local function Paint(fs, col) if fs and col then fs:SetTextColor(col[1], col[2], col[3], col[4] or 1) end end

-------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------
local panel, scroll, content
-- spacing from core (#351 phase 2, XayaUI/Modules.lua): PAD = the margin inside the panel, GUT = the gutter between two controls
local PANEL_W, PAD, GUT = 380, ns.UI_MARGIN, ns.UI_GUTTER
local TITLE_H = 18            -- the title row (the mode button is 18 tall)
local NAME_H = 32             -- the header: name and item level (15), spec and class (11) under them (B2)
local HEADER = TITLE_H + GUT + NAME_H + GUT + 20 + GUT  -- title row, header, the tab row (20 tall), a gutter before the content
local W = PANEL_W - 2 * PAD   -- content width (changes when the panel is resized: B10, #381)
ns.CHARTOOLKIT_LAYOUT = { width = PANEL_W, pad = PAD, header = HEADER, content = W, minW = MIN_W, maxW = MAX_W, minH = MIN_H, maxH = MAX_H }

local function Owner() return _G.PaperDollFrame or _G.CharacterFrame end
local function Docked() local cf = _G.CharacterFrame; return cf and cf.IsShown and cf:IsShown() end

-- pools: font strings, line buttons (hover / click), header buttons, edit boxes (What If)
local fsPool, btnPool, hdrPool, boxes = {}, {}, {}, {}
local nFS, nBtn, nHdr
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
    local c = Cfg()
    local mode = it.kind == "rating" and ModeFor(c, it.key) or nil
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
            if it and it.kind == "rating" then
                ns.CharToolkit_FlipLine(it.key)
                ns.CharToolkit_Render()
                if self.IsMouseOver and self:IsMouseOver() then ShowTooltip(self, self.item) end
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
    b:Show()
    return b
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

-- the Spells tab's filter buttons (All / Offense / Defense): own buttons with their label on them, so the label draws above the fill
local filterBtns = {}
local function FilterBtn(i)
    local b = filterBtns[i]
    if not b then
        b = CreateFrame("Button", nil, content)
        b:EnableMouse(true)
        if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp") end
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.08)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.text:SetPoint("CENTER")
        b:SetScript("OnEnter", function(self) ShowTooltip(self, self.item) end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b:SetScript("OnClick", function(self)
            local c = Cfg(); if not (c and self.filter) then return end
            c.spellFilter = self.filter
            if scroll then scroll:SetVerticalScroll(0) end
            ns.CharToolkit_Render()
        end)
        b:SetScript("OnMouseWheel", function(_, d) if panel and panel.Scroll then panel.Scroll(d) end end)
        filterBtns[i] = b
    end
    b:Show()
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
        b:SetScript("OnEnter", function(self)
            if not (GameTooltip and self.slot) then return end
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
            elseif self.slot then
                ns.CharToolkit_SelectGearSlot(self.slot)
            end
        end)
        -- an item dropped on an equipped icon is compared with that slot (plan item 6: "drag and drop")
        b:SetScript("OnReceiveDrag", function(self)
            local ok, kind, id, link = pcall(GetCursorInfo)
            if not ok or kind ~= "item" or not self.slot then return end
            local text = (type(link) == "string" and not isSecret(link)) and link or ((type(id) == "number" and not isSecret(id)) and tostring(id) or nil)
            if not text then return end
            if ClearCursor then pcall(ClearCursor) end
            ns.CharToolkit_PickItem(text, self.slot)
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

-- Panel input: a stat map box ("sv:" + stat key), "all" (every rating), a What If stat key, "primary", or "item" (the Gear comparison's
-- item: a link or an ID). (QoL 0.7.14: a compared item no longer fills the map's boxes; the Gear tab shows what it changes itself.)
function ns.CharToolkit_SetInput(key, text)
    local c = Cfg(); if not c then return end
    if key == "item" then
        local t = tostring(text or "")
        CM.compareText = (t:gsub("^%s+", ""):gsub("%s+$", ""))
        CM.compareSlot = CM.gearSlot   -- the slot you picked, when the item fits it; else the lower item level of two
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
        if key == "all" then c.whatIf = n else c.whatIfStats[key] = (n ~= 0) and n or nil end
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
        ns.spellList, ns.talentList = nil, nil   -- core's cached spellbook and talent lists (Conditions.lua) are read again
        CM.ClearTalents(); CM.ResetSpellRequests()
    end
    ns.CharToolkit_Render()
end
-- Gear: a clicked equipped item picks its slot; an item compared before that does not fit the slot is let go
function ns.CharToolkit_SelectGearSlot(slot)
    local c = Cfg(); if not c then return end
    CM.gearSlot, CM.compareSlot = slot, slot
    local link = (CM.compareText or "") ~= "" and CM.ResolveItemLink(CM.compareText) or nil
    if link and not CM.FitsSlot(link, slot) then CM.compareText = nil end
    if boxes.item and CM.compareText == nil then boxes.item:SetText("") end
    ns.CharToolkit_Render()
end
-- Gear: compare this item (a link or an ID) with the given slot (a bag item clicked in the list, or an item dropped on an icon)
function ns.CharToolkit_PickItem(text, slot)
    local c = Cfg(); if not c then return end
    CM.compareText = tostring(text or "")
    if slot then CM.gearSlot, CM.compareSlot = slot, slot end
    if boxes.item then boxes.item:SetText(CM.compareText) end
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
    -- the header (B2): name and item level on one line, spec and class in the class colour under the name, "equipped (overall)" under
    -- the item level; a thin rule under it
    local hy = PAD + TITLE_H + GUT
    panel.hName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.hName:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -hy); panel.hName:SetJustifyH("LEFT")
    panel.hSpec = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.hSpec:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(hy + 17)); panel.hSpec:SetJustifyH("LEFT")
    panel.hIlvl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.hIlvl:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -hy); panel.hIlvl:SetJustifyH("RIGHT")
    panel.hIlvlSub = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.hIlvlSub:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -(hy + 17)); panel.hIlvlSub:SetJustifyH("RIGHT")
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
        if num(w) and num(h) then
            c.size = { w = math.floor(math.max(MIN_W, math.min(MAX_W, w)) + 0.5), h = math.floor(math.max(MIN_H, math.min(MAX_H, h)) + 0.5) }
        end
        ns.CharToolkit_Render()
    end)
    grip:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Drag to resize", 1, 0.82, 0)
        GameTooltip:AddLine("The size is kept. QoL > Character Toolkit > Panel: Reset size goes back to the default.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    panel.grip = grip
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(24, 24)   -- the template's own size (UIPanelCloseButtonNoScripts, SharedUIPanelTemplates.xml:135, live 12.1.5)
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() panel.userHidden = true; panel:Hide() end)
    -- the value mode button: every rating line shows its percent or its rating
    local mb = CreateFrame("Button", nil, panel)
    mb:SetSize(74, 18)
    mb:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(22 + GUT), -PAD)   -- a gutter left of the close button (24 wide, 2 px out: 22 px in)
    mb.bg = mb:CreateTexture(nil, "BACKGROUND"); mb.bg:SetAllPoints(mb)
    mb.text = mb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); mb.text:SetPoint("CENTER")
    mb:SetScript("OnClick", function()
        local c = Cfg(); if not c then return end
        ns.CharToolkit_SetValueMode(c.valueMode == "rating" and "percent" or "rating")
        ns.CharToolkit_Render()
    end)
    mb:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Rating lines show", 1, 0.82, 0)
        GameTooltip:AddLine("Switches every rating line between its percent and its rating. Click one line to flip it alone.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    mb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    panel.modeBtn = mb

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
    return h
end

-- the stat map's columns (QoL 0.7.14): name | rating box | percent | rating per 1% (#382: side by side, no toggle)
local function MapCols()
    local lw, bw, pw = math.floor(W * 0.30), 56, 64
    local bx = lw + GUT
    local vx = bx + bw + GUT
    local px = W - pw
    return lw, bw, bx, vx, px - GUT - vx, px, pw
end

-- the Gear comparison's columns (QoL 0.7.14): name | equipped | this item | change
local function CmpCols()
    local lw = math.floor(W * 0.30)
    local cw = math.floor((W - lw - 3 * 4) / 3)
    local x1 = lw + 4
    return lw, cw, x1, x1 + cw + 4, x1 + 2 * (cw + 4)
end

-- detail tabs: sections with headers; each line is label | value, its pairs under it
local function RenderSections(c, m, tab, y0)
    local size = c.fontSize
    local cText = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local cMuted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local cLabel = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    local cLine = TC("xui-window", "border", { 0.3, 0.3, 0.3, 1 })
    local short = c.detail == "short"
    local y = y0 or 0
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
            if not folded then
                for _, it in ipairs(sec.items) do
                    local top = y
                    local mode = it.kind == "rating" and ModeFor(c, it.key) or nil
                    local v, tone = CM.ValueFor(it, mode)
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
                            b:ClearAllPoints()
                            b:SetPoint("TOPLEFT", content, "TOPLEFT", x, -yy)
                            b:SetSize(ICON_SIZE, ICON_SIZE)
                            b.tex:SetTexture(ic.tex or QUESTION_MARK)
                            local bc = ic.color or cLine
                            b.border:SetColorTexture(bc[1], bc[2], bc[3], 1)
                            -- the slot being compared: a theme-coloured mark under its item level (the quality border stays)
                            if ic.selected then
                                local acc = TC("xui-tab-selected", "bg", { 0.55, 0.3, 0.8, 1 })
                                if not b.sel then b.sel = b:CreateTexture(nil, "OVERLAY") end
                                b.sel:ClearAllPoints()
                                b.sel:SetPoint("TOPLEFT", b, "BOTTOMLEFT", -2, -(size + 2))
                                b.sel:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 2, -(size + 2))
                                b.sel:SetHeight(2)
                                b.sel:SetColorTexture(acc[1], acc[2], acc[3], 1)
                                b.sel:Show()
                            elseif b.sel then b.sel:Hide() end
                            b.selected = ic.selected
                            Rec("icon", x, yy, ICON_SIZE, ICON_SIZE, ic.label)
                            PlaceFS(FS(), cx, yy + ICON_SIZE + 1, math.floor(cw), size - 1, ic.ilvl and tostring(math.floor(ic.ilvl + 0.5)) or "",
                                ic.color or cText, "CENTER", false, "iconText")
                        end
                        y = y + math.ceil(#(it.icons or {}) / cols) * rowStep
                    elseif it.kind == "wide" then
                        rowH = PlaceFS(FS(), 0, y, W, size, it.label, cText, "LEFT", false, "label")
                        y = y + rowH + 1
                        rowH = PlaceFS(FS(), 6, y, W - 6, size - 1, v, ToneColor(tone, cMuted), "LEFT", true, "wide")
                        y = y + rowH + 1
                    elseif it.kind == "colhead" and it.cmp then
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
                        y = y + size + 1
                    elseif it.kind == "action" then
                        -- a button (Spells: Configure / Refresh spell data): the theme's button colours, its label centred
                        local bw = math.min(W, math.floor(W * 0.6))
                        local bh = size + 10
                        local b = Btn()
                        b.item = it
                        b:ClearAllPoints()
                        b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                        b:SetSize(bw, bh)
                        if not b.bg then b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b) end
                        local bg = TC("xui-button", "bg", { 0.04, 0.04, 0.04, 0.7 })
                        b.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
                        b.bg:Show()
                        PlaceFS(FS(), 0, y + 5, bw, size, it.label, TC("xui-button", "text", { 1, 0.82, 0, 1 }), "CENTER", false, "action")
                        Rec("hit", 0, y, bw, bh, it.key)
                        y = y + bh + 2
                    elseif it.kind == "cmprow" then
                        local lw, cw, x1, x2, x3 = CmpCols()
                        local cs = it.cells or {}
                        rowH = PlaceFS(FS(), 0, y, lw - 4, size, it.label, it.labelColor or cText, "LEFT", false, "label")
                        PlaceFS(FS(), x1, y, cw, size, cs[1] or "", cText, "RIGHT", false, "cmpcell")
                        PlaceFS(FS(), x2, y, cw, size, cs[2] or "", cText, "RIGHT", false, "cmpcell")
                        PlaceFS(FS(), x3, y, cw, size, cs[3] or "", ToneColor(it.cellTone, cText), "RIGHT", false, "cmpcell")
                        y = y + rowH + 1
                    elseif it.kind == "colhead" then
                        local lw, bw, bx, vx, vw, px, pw = MapCols()
                        local cs = it.cols or {}
                        PlaceFS(FS(), bx, y, bw, size - 1, cs[1] or "", cMuted, "LEFT", false, "colhead")
                        PlaceFS(FS(), vx, y, vw, size - 1, cs[2] or "", cMuted, "RIGHT", false, "colhead")
                        PlaceFS(FS(), px, y, pw, size - 1, cs[3] or "", cMuted, "RIGHT", false, "colhead")
                        y = y + size + 1
                    elseif it.kind == "input" and it.mapCard then
                        local lw, bw, bx, vx, vw, px, pw = MapCols()
                        rowH = PlaceFS(FS(), 0, y, lw - 4, size, it.label, it.labelColor or cText, "LEFT", false, "label")
                        local eb = Box(it.input)
                        eb:ClearAllPoints()
                        eb:SetPoint("TOPLEFT", content, "TOPLEFT", bx, -y + 2)
                        eb:SetSize(bw, size + 6)
                        if not (eb.HasFocus and eb:HasFocus()) then
                            eb:SetText(it.absolute and tostring(math.floor(it.absolute + (num(it.amount) and it.amount or 0) + 0.5)) or "")
                        end
                        eb:Show()
                        eb.xuiUsed = true
                        Rec("input", bx, y, bw, size + 6, it.input, size)
                        local vh = PlaceFS(FS(), vx, y, vw, size, v, ToneColor(tone, cText), "RIGHT", true, "value")
                        if it.per and it.per ~= "" then PlaceFS(FS(), px, y, pw, size - 1, it.per, cMuted, "RIGHT", false, "per") end
                        local lb = Btn()   -- hover on the name: where the numbers come from
                        lb.item = it
                        lb:ClearAllPoints()
                        lb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                        lb:SetSize(lw, size + 6)
                        Rec("hit", 0, y, lw, size + 6, it.key)
                        y = y + math.max(rowH, vh, size + 6) + 2
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

-- the filter row at the top of the Spells tab; returns the height it took
local function RenderFilters(c)
    local size = c.fontSize
    local n = #CM.SPELL_FILTERS
    local fw = math.floor(W / n)
    local h = size + 8
    for i, f in ipairs(CM.SPELL_FILTERS) do
        local on = c.spellFilter == f[1]
        local cls = on and "xui-tab-selected" or "xui-tab"
        local b = FilterBtn(i)
        b.filter = f[1]
        b.item = { kind = "filter", key = "filter:" .. f[1], label = f[2], value = on and "shown" or "", tip = { f[3] } }
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", content, "TOPLEFT", (i - 1) * fw, 0)
        b:SetSize(fw - 2, h)
        local tb = TC(cls, "bg", on and { 0.22, 0.1, 0.3, 0.9 } or { 0.03, 0.03, 0.03, 0.7 })
        b.bg:SetColorTexture(tb[1], tb[2], tb[3], tb[4] or 1)
        SetFont(b.text, size, "")
        b.text:SetText(f[2])
        Paint(b.text, TC(cls, "text", on and { 1, 1, 1, 1 } or { 1, 0.82, 0, 1 }))
        Rec("filter", (i - 1) * fw, 0, fw - 2, h, f[2], size)
    end
    return h + 6
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

-- the header's text (B2)
local function RenderHeader(c)
    local h = CM.HeaderInfo()
    local text = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local muted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    SetFont(panel.hName, 15, ""); panel.hName:SetText(h.name or ""); Paint(panel.hName, text)
    local spec = table.concat({ h.spec or "", h.className or "" }, " "):gsub("^%s+", ""):gsub("%s+$", "")
    SetFont(panel.hSpec, 11, ""); panel.hSpec:SetText(spec); Paint(panel.hSpec, h.color or text)
    SetFont(panel.hIlvl, 15, "")
    panel.hIlvl:SetText(h.ilvlEquipped and ("%.1f"):format(h.ilvlEquipped) or "")
    Paint(panel.hIlvl, TC("xui-label", "text", { 1, 0.82, 0, 1 }))
    SetFont(panel.hIlvlSub, 10, "")
    panel.hIlvlSub:SetText(h.ilvlEquipped and ("item level" .. (h.ilvlOverall and (" (overall %.1f)"):format(h.ilvlOverall) or "")) or "")
    Paint(panel.hIlvlSub, muted)
    -- the name and spec stop short of the item level column
    local right = 120
    panel.hName:SetWidth(math.max(40, W - right - GUT)); panel.hSpec:SetWidth(math.max(40, W - right - GUT))
    panel.hIlvl:SetWidth(right); panel.hIlvlSub:SetWidth(right)
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
    local mb = panel.modeBtn
    local mbg, mbb = TC("xui-button", "bg", { 0.04, 0.04, 0.04, 0.7 }), TC("xui-button", "text", { 1, 0.82, 0, 1 })
    mb.bg:SetColorTexture(mbg[1], mbg[2], mbg[3], mbg[4] or 1)
    mb.text:SetText(c.valueMode == "rating" and "Show: rating" or "Show: %")
    Paint(mb.text, mbb)
    panel.modeText = mb.text:GetText()
    -- (QoL 0.7.14) no tab draws rating lines any more (the stat map shows the percent and the rating together), so the "Show: %"
    -- button would do nothing (#382: "the Show: % toggle doesn't do anything"): it is hidden
    mb:Hide()
    for _, b in ipairs(panel.tabs or {}) do
        local on = b.key == c.tab
        local cls = on and "xui-tab-selected" or "xui-tab"
        local tb = TC(cls, "bg", on and { 0.22, 0.1, 0.3, 0.9 } or { 0.03, 0.03, 0.03, 0.7 })
        b.bg:SetColorTexture(tb[1], tb[2], tb[3], tb[4] or 1)
        b.text:SetText(b.label)
        Paint(b.text, TC(cls, "text", on and { 1, 1, 1, 1 } or { 1, 0.82, 0, 1 }))
    end
    nFS, nBtn, nHdr, nIcon = 0, 0, 0, 0
    for _, eb in pairs(boxes) do eb.xuiUsed = false end
    local m = CM.Build(c, c.tab)
    panel.model = m
    local y
    local nFilters = 0
    if c.tab == "spells" then nFilters = #CM.SPELL_FILTERS; y = RenderSections(c, m, c.tab, RenderFilters(c))
    else y = RenderSections(c, m, c.tab) end
    for i = nFilters + 1, #filterBtns do filterBtns[i]:Hide() end
    for i = nIcon + 1, #iconBtns do iconBtns[i]:Hide(); iconBtns[i].slot, iconBtns[i].link = nil, nil end
    for i = nFS + 1, #fsPool do fsPool[i]:Hide() end
    for i = nBtn + 1, #btnPool do btnPool[i]:Hide(); btnPool[i].item = nil end
    for i = nHdr + 1, #hdrPool do hdrPool[i]:Hide() end
    for _, eb in pairs(boxes) do if not eb.xuiUsed then eb:Hide() end end
    panel.layoutRecs = layout
    content:SetHeight(math.max(10, y))
    local cf = _G.CharacterFrame
    local maxH = (Docked() and cf.GetHeight and cf:GetHeight()) or 560
    if not num(maxH) or maxH < 300 then maxH = 560 end
    if type(c.size) == "table" and num(c.size.h) then
        if not panel.sizing then panel:SetHeight(c.size.h) end   -- the size you dragged it to (B10)
    else
        panel:SetHeight(math.min(maxH, y + PAD * 2 + HEADER))
    end
    Place()
end

-- what the panel drew last: { model, layout records, mode button text }; for the tests
function ns.CharToolkit_Drawn()
    if not panel then return nil end
    return { model = panel.model, layout = panel.layoutRecs, modeText = panel.modeText, buttons = btnPool, headers = hdrPool, boxes = boxes,
        fonts = fsPool, filters = filterBtns, icons = iconBtns }
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
        overlays[button] = o
    end
    local eSlots, eDefault = CM.EnchantSlots(c)
    local data = CM.SlotOverlay(slot, { ilvl = c.ovIlvl, sockets = c.ovSockets, enchants = c.ovEnchants, enchantSlots = eSlots, enchantDefault = eDefault })
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
    "PLAYER_LEVEL_UP", "UPDATE_INVENTORY_DURABILITY", "PLAYER_TARGET_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE", "MERCHANT_SHOW",
    "MERCHANT_CLOSED", "CHALLENGE_MODE_MAPS_UPDATE", "GET_ITEM_INFO_RECEIVED", "SOCKET_INFO_UPDATE", "ENCHANT_SPELL_COMPLETED",
    "SPELL_DATA_LOAD_RESULT", "SPELLS_CHANGED" }
local UNIT_EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGEDDAMAGE", "UNIT_RANGED_ATTACK_POWER", "UNIT_ATTACK_SPEED", "UNIT_DAMAGE",
    "UNIT_MAXHEALTH", "UNIT_RESISTANCES", "UNIT_SPELL_HASTE" }
local OVERLAY_EVENTS = { PLAYER_EQUIPMENT_CHANGED = true, GET_ITEM_INFO_RECEIVED = true, SOCKET_INFO_UPDATE = true, ENCHANT_SPELL_COMPLETED = true,
    UPDATE_INVENTORY_DURABILITY = true }

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

local function ShowIfDocked()
    local c = Cfg()
    if not (c and c.enabled and c.panel) then return end
    Build()
    panel.userHidden = nil
    panel:Show()
    ns.CharToolkit_Render()
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
    if OVERLAY_EVENTS[event] then RefreshOverlays() end
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

local function AppendTooltip(frame)
    local c = Cfg()
    if not (c and c.enabled and c.tooltips) or not GameTooltip then return end
    if GameTooltip.IsOwned and not GameTooltip:IsOwned(frame) then return end
    local label = frame.Label and frame.Label.GetText and frame.Label:GetText()
    local key = KeyForLabel(label)
    if not key then return end
    local m = CM.Build(c, nil)
    local it = m.byKey[key]
    if not it then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("XayaUI Character Toolkit", 0.2, 0.8, 1)
    for _, line in ipairs(CM.PairLines(it, c.detail == "short")) do GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true) end
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
local ownerHooked, themeHooked = false, false
function ns.CharToolkit_Apply()
    local c = Cfg(); if not c then return end
    if not c.enabled then
        if ev then ev:UnregisterAllEvents() end
        if panel then panel:Hide() end
        for _, o in pairs(overlays) do o:Hide() end
        return
    end
    if not ev then
        ev = CreateFrame("Frame")
        ev:SetScript("OnEvent", OnEvent)
    end
    ev:UnregisterAllEvents()
    for _, e in ipairs(STAT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
    for _, e in ipairs(UNIT_EVENTS) do
        if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, e, "player") else pcall(ev.RegisterEvent, ev, e) end
    end
    pcall(ev.RegisterEvent, ev, "SPELL_UPDATE_COOLDOWN")
    if not ownerHooked then
        local owner = Owner()
        if owner and owner.HookScript then
            ownerHooked = true
            owner:HookScript("OnShow", function() ShowIfDocked(); HookStatFrames(); ns.CharToolkit_UpdateOverlays() end)
            owner:HookScript("OnHide", function() if panel then panel:Hide() end end)
        end
        if type(hooksecurefunc) == "function" then
            if type(_G.PaperDollFrame_UpdateStats) == "function" then hooksecurefunc("PaperDollFrame_UpdateStats", HookStatFrames) end
            -- Blizzard redraws one slot button at a time; the overlay follows (post-hook, Blizzard's code runs unchanged first)
            if type(_G.PaperDollItemSlotButton_Update) == "function" then hooksecurefunc("PaperDollItemSlotButton_Update", UpdateOverlay) end
        end
    end
    if not themeHooked and ns.Theme and ns.Theme.OnResolve then
        themeHooked = true
        ns.Theme.OnResolve(function() if panel and panel:IsShown() then ns.CharToolkit_Render() end end)
    end
    ns.CharToolkit_UpdateOverlays()
    if panel then
        if not c.panel then panel:Hide()
        elseif panel:IsShown() then ns.CharToolkit_Render()
        elseif Docked() and not panel.userHidden then ShowIfDocked() end
    elseif c.panel and Docked() then
        ShowIfDocked()
    end
end

-- /xui stats: show or hide the panel on its own (docked when the character window is open)
function ns.CharToolkit_Toggle()
    local c = Cfg(); if not c then return end
    if not c.enabled then
        ns.Print("Character Toolkit is off. Turn it on in QoL > Character Toolkit (or /xui stats on).")
        return
    end
    Build()
    if panel:IsShown() then panel.userHidden = true; panel:Hide()
    else panel.userHidden = nil; panel:Show(); ns.CharToolkit_Render() end
end

ns.WhenReady(function() if Cfg() then ns.CharToolkit_Apply() end end)

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
    local function Toggle(key, order, name, desc, width, hidden)
        return { type = "toggle", order = order, width = width, name = name, desc = desc, hidden = hidden,
            get = function() return C()[key] and true or false end,
            set = function(_, v) C()[key] = v and true or false; Changed() end }
    end

    local spells = {
        type = "group", name = "Spell Math", order = 30, hidden = isOff,
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "The Spells tab lists every active spell of your current spec's spellbook that has numbers in its description, and the spells you add here first (any spell ID). For each: every number in its current description divided by your current attack power (or spell power), and what one point of your primary stat adds. This is the ratio right now, with talents and buffs already applied; it is not Blizzard's base coefficient. You can type a coefficient from a database such as Wowhead to compare." },
            advanced = Toggle("advanced", 1, "Spell Math", "Shows the Spells tab's spell math in the panel (advanced).", "full"),
            spellsAll = Toggle("spellsAll", 1.5, "List spells without numbers",
                "Also list spellbook spells whose description has no amount to measure (they show \"none in the description\").", "full"),
            add = { type = "input", order = 2, width = "double", name = "Add a spell",
                desc = "A spell ID, a spell name you know, or a shift-clicked spell link.",
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
                    desc = "Optional. From a database such as Wowhead: the spell's percent of attack power or spell power. Leave empty to show only what the game measures.",
                    get = function() local s = S(); return (s and num(s.coeff)) and tostring(s.coeff) or "" end,
                    set = function(_, v)
                        local s = S(); if not s then return end
                        local n = tonumber((tostring(v or ""):gsub("%%", ""):gsub(",", ".")))
                        s.coeff = (n and n > 0) and n or nil
                        Changed()
                    end },
                kind = { type = "select", order = 2.5, name = "Filter",
                    values = { auto = "From its description", offense = "Offense", defense = "Defense", both = "Offense and Defense" },
                    sorting = { "auto", "offense", "defense", "both" },
                    desc = "Which of the Spells tab's filters show this spell. \"From its description\" sorts by its words (damage, or absorb / heal / armor / damage taken).",
                    get = function() local s = S(); return (s and s.kind) or "auto" end,
                    set = function(_, v) local s = S(); if s then s.kind = (v ~= "auto") and v or nil; Changed() end end },
                remove = { type = "execute", order = 3, width = "half", name = "Remove",
                    func = function() table.remove(C().spells, i); Changed() end },
            },
        }
    end

    local panelPart = {
        type = "group", name = "Panel", order = 10, childGroups = "tab", hidden = isOff,
        args = {
            layout = { type = "group", name = "Layout", order = 1, args = {
                panel = Toggle("panel", 1, "Show the panel", "Beside the character window whenever it opens. /xui stats shows it on its own."),
                side = { type = "select", order = 2, name = "Side", values = { right = "Right", left = "Left" },
                    desc = "Which side of the character window the panel docks to.",
                    get = function() return C().side end, set = function(_, v) C().side = v; Changed() end },
                detail = { type = "select", order = 3, name = "Detail", values = { all = "Every line", short = "Key lines" },
                    desc = "How many detail lines show under each stat. The hover always shows all of them.",
                    get = function() return C().detail end, set = function(_, v) C().detail = v; Changed() end },
                valueMode = { type = "select", order = 4, name = "Rating lines", values = { percent = "Percent", rating = "Rating" },
                    desc = "What every rating line shows (the % / rating button in the panel does the same). Clicking one line flips it alone.",
                    get = function() return C().valueMode end,
                    set = function(_, v) ns.CharToolkit_SetValueMode(v); Changed() end },
                fontSize = { type = "range", order = 5, name = "Text size", min = 8, max = 16, step = 1,
                    get = function() return C().fontSize end, set = function(_, v) C().fontSize = v; Changed() end },
                resetSize = { type = "execute", order = 5.5, name = "Reset size",
                    desc = "The panel goes back to its default width, and its height follows its content again (drag its bottom-right corner to resize it).",
                    func = function() C().size = nil; Changed() end },
                opacity = { type = "range", order = 6, name = "Background", min = 0, max = 1, step = 0.05, isPercent = true,
                    desc = "Opacity of the panel's background. Colors and font follow the XayaUI theme.",
                    get = function() return C().opacity end, set = function(_, v) C().opacity = v; Changed() end },
            } },
            values = { type = "group", name = "Your numbers", order = 2, args = {
                whatIf = { type = "input", order = 1, name = "All ratings +",
                    desc = "Adds this much rating to every stat and shows what each would gain, thresholds included (the game's own converter). 0 turns it off. The Stats tab has the same box (All ratings) and a box per stat holding the number itself.",
                    get = function() return tostring(C().whatIf or 0) end,
                    set = function(_, v) C().whatIf = math.max(-100000, math.min(100000, math.floor(tonumber(v) or 0))); Changed() end },
                clear = { type = "execute", order = 2, name = "Clear all",
                    desc = "Every number on the Stats tab goes back to yours, and the All ratings amount to 0.",
                    func = function() local c = C(); c.whatIf = 0; c.whatIfStats = {}; c.whatIfPrimary = nil; Changed() end },
                resetLines = { type = "execute", order = 3, name = "Reset line flips",
                    desc = "Every rating line goes back to the Rating lines setting.",
                    func = function() C().lineModes = {}; Changed() end },
            } },
            tips = { type = "group", name = "Tooltips", order = 3, args = {
                tooltips = Toggle("tooltips", 1, "Character window lines",
                    "Adds the toolkit's lines under the character window's own stat tooltips. The panel's own hover does not need this.", "double"),
            } },
        },
    }

    local slotToggles = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Ticked to start with: the slots this expansion's enchants cover (head, shoulders, chest, legs, feet, both rings, main hand, and off hand when it holds a weapon). Change any tick and your own choice is kept. A ticked slot with no enchant shows E? (orange); an enchanted one shows E (green)." },
        reset = { type = "execute", order = 99, name = "This expansion's slots",
            desc = "Back to the slots this expansion's enchants cover: head, shoulders, chest, legs (spellthread or armor kit), feet, both rings, main hand, and off hand when it holds a weapon. Taken from the expansion's enchant items in Blizzard's game data; the game has no call that says it.",
            func = function() local c = C(); c.enchantSlots = {}; c.enchantSlotsSet = nil; Changed() end },
    }
    for i, s in ipairs(CM.SLOTS) do
        local slot = s[1]
        slotToggles["slot" .. slot] = { type = "toggle", order = i, name = CM.SlotLabel(slot),
            desc = "Flag this slot on the character window when its item has no enchant (read from the item link).",
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
        args = {
            show = { type = "group", name = "Show", order = 1, args = {
                overlays = Toggle("overlays", 1, "Slot overlays", "Marks on the character window's item slots. Off by default.", "full"),
                ovIlvl = Toggle("ovIlvl", 2, "Item level", "The item's level, at the bottom of the slot."),
                ovSockets = Toggle("ovSockets", 3, "Empty sockets", "How many empty sockets the item's stat table lists (for example 2S), at the top."),
                ovEnchants = Toggle("ovEnchants", 4, "Enchant check", "E? on a ticked slot with no enchant, E when it has one. This expansion's enchantable slots are ticked until you pick your own on the Enchant Slots tab."),
                ovSize = { type = "range", order = 5, name = "Text size", min = 8, max = 16, step = 1,
                    get = function() return C().ovSize end, set = function(_, v) C().ovSize = v; Changed() end },
            } },
            enchants = { type = "group", name = "Enchant Slots", order = 2, args = slotToggles },
        },
    }

    return {
        type = "group", name = "Character Toolkit", order = 3, childGroups = "tree",
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "A panel beside the character window: every stat the game gives, where each number comes from, what the next point buys, what each stat feeds (type your own numbers to see the change), and a gear comparison. What the game does not give is marked, never guessed. Turn it on here, then pick a part on the left. Off by default." },
            enabled = Toggle("enabled", 1, "Character Toolkit", "Turns the toolkit on. While it is off nothing is created, registered or read.", "full"),
            panelOn = Toggle("panel", 2, "Panel", "The stat panel beside the character window.", nil, isOff),
            overlaysOn = Toggle("overlays", 3, "Slot overlays", "Item level, empty sockets and enchant marks on the character window's slots.", nil, isOff),
            tooltipsOn = Toggle("tooltips", 4, "Tooltip lines", "The toolkit's lines under the character window's own stat tooltips.", nil, isOff),
            panelPart = panelPart,
            overlayPart = overlayPart,
            spells = spells,
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
    -- the in-game test for the planned wider character window (CharacterWidthProbe.lua); runs only when typed
    local probeArg = arg:match("^widthprobe%s*(.*)$")
    if probeArg and ns.CharWidthProbe_Run then ns.CharWidthProbe_Run(probeArg); return end
    if arg == "help" then
        ns.Print("/xui stats: show or hide the Character Toolkit panel. /xui stats on | off | options | status")
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
end, "/xui stats [on|off|options|status|widthprobe [px|off]] (Character Toolkit stat panel)")
