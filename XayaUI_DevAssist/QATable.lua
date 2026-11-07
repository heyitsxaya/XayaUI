-------------------------------------------------------------------------------
-- QATable.lua (XayaUI_DevAssist 0.7.52): the walkthrough table with a search box and tag chips, used by both lists of walkthroughs:
-- the review popup ("Review: what's new to test", QAReview.lua) and "All walkthroughs" (/xui dev qa, QAWalk.lua).
-- Xaya 2026-11-07 (her words): "an issue search bar and issues tags here to be able to navigate more easily"; "some of these also are
-- not exactly human-readable"; then "the codes are fine to keep, all of this data just needs to be clearly put into tables with clear
-- sortable rows and columns (think excel style navigation)". Her choices (relayed by the coordinating session):
--  - search: title, walkthrough id, QA codes, area and step text (colour codes stripped); case-insensitive substring, as she types;
--  - tag chips: Baseline (the 10), one per area, Not run / Passed / Failed, New or changed. Within a group (areas; statuses) chips
--    combine with OR, groups combine with AND, the search ANDs with the chips; a count of matching walkthroughs; Clear resets both;
--  - columns Codes | Title | Area | Status | New | Open. Codes = the codes in the title's leading [ ... ] / trailing ( ... ) group plus
--    the qa field, de-duplicated, in full. Title = the title without those groups (only a group made entirely of codes is taken out:
--    ordinary words in brackets stay). A header click sorts by that column, a second click reverses it; default = area, then the
--    list's own order; ties keep the default order (stable).
--  - nothing of the search, chips or sort is saved (no saved-variable key: the suite is about to be restructured). Each window's table
--    keeps them in memory for the rest of the session (0.7.53, #465: also across opening a walkthrough and coming back).
-- No existing table helper fitted: the auto-populate table (XayaUI_Options/AutoPicker.lua) is AceGUI inside the load-on-demand
-- settings addon, which Dev Assist does not load; XayaDataBlocks-1.0 lays out data-panel blocks, not rows. Own code, own design.
-- V14: nothing here is made until one of the two windows opens. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end
local TB = {}
QA.Table = TB

-- Baseline: the 10 walkthroughs of the baseline list (docs/plans/PLATFORM-SPLIT-2026-11-07.md, section 8.1). The one place to change it.
QA.BASELINE = { "settings-toplevel", "perf-settings-click", "audit-engine", "audit-opt-bin", "audit-backup-replace", "bars-cues",
    "chat-improved-split", "reskin-switches", "audit-shopping-list", "statcalc-rows" }
local isBase = {}
for _, id in ipairs(QA.BASELINE) do isBase[id] = true end
function QA.IsBaseline(id) return isBase[id] == true end

local function Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function Esc(s) return (tostring(s or ""):gsub("|", "||")) end
local function StripColour(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-------------------------------------------------------------------------------
-- Codes and plain titles
-------------------------------------------------------------------------------
-- a code: letters and digits starting with a letter (B263, J31, E1z195, UI-19, H6-H9, CHATREV-10), or #n (#210)
local function IsCode(tok)
    if tok:match("^#%d+$") then return true end
    return tok:match("^%a[%w%-]*$") ~= nil and tok:find("%d") ~= nil and tok:sub(-1) ~= "-"
end
-- the text inside one [ ] / ( ) group -> its codes, or nil when anything in it is not a code (separators: commas, slashes, spaces)
local function GroupCodes(s)
    local out = {}
    for tok in tostring(s or ""):gmatch("[^,/%s]+") do
        if not IsCode(tok) then return nil end
        out[#out + 1] = tok
    end
    return #out > 0 and out or nil
end
-- "Engine: a, b (D28, D56, D57)" -> "Engine: a, b", { "D28", "D56", "D57" }; "Looks (no effect on use) (1 of 7)" stays as it is
function QA.SplitTitle(title)
    local t, codes = Trim(title), {}
    local lead, rest = t:match("^%[([^%[%]]*)%]%s*(.-)$")
    local c = lead and rest ~= "" and GroupCodes(lead)
    if c then
        for _, x in ipairs(c) do codes[#codes + 1] = x end
        t = rest
    end
    local head, tail = t:match("^(.-)%s*%(([^()]*)%)$")
    c = tail and head ~= "" and GroupCodes(tail)
    if c then
        for _, x in ipairs(c) do codes[#codes + 1] = x end
        t = head
    end
    return t, codes
end
-- every code of a walkthrough: the title's, then the qa field's, each once
function QA.Codes(def)
    local _, tc = QA.SplitTitle(def and def.title)
    local seen, list = {}, {}
    local function add(x) x = Trim(x); if x ~= "" and not seen[x] then seen[x] = true; list[#list + 1] = x end end
    for _, x in ipairs(tc) do add(x) end
    if def and def.qa then for tok in tostring(def.qa):gmatch("[^,/]+") do add(tok) end end
    return list
end

-------------------------------------------------------------------------------
-- Entries, filter and sort (no frames: the tests drive these directly too)
-------------------------------------------------------------------------------
local STATUS_LABEL = { notrun = "Not run", passed = "Passed", failed = "Failed", skipped = "Skipped" }
local STATUS_COLOUR = { notrun = "999999", passed = "60ff60", failed = "ff6060", skipped = "cccccc" }
TB.STATUS_LABEL = STATUS_LABEL
-- the result of a walkthrough's last run: "notrun", "failed" (a step failed), "passed" (a step passed, none failed) or (0.7.53)
-- "skipped" (no step passed or failed: every step skipped, or done without a verdict); stale = run against an older text
function TB.Status(id)
    local r = QA.DB().results[id]
    if not r then return "notrun", false end
    local stale = (r.fp ~= nil and r.fp ~= QA.Fingerprint(QA.walks[id])) and true or false
    local p, f = 0, 0
    for _, s in ipairs(r.steps or {}) do if s.r == "F" then f = f + 1 elseif s.r == "P" then p = p + 1 end end
    if f > 0 then return "failed", stale end
    if p > 0 then return "passed", stale end
    return "skipped", stale
end
local function AreaOf(def)
    if QA.Review and QA.Review.Area then return QA.Review.Area(def) end
    return tostring(def.area or "Other")
end
-- one row's data; state = "new" | "changed" | nil
function TB.Entry(id, state)
    local def = QA.walks[id]
    if not def then return nil end
    local title = QA.SplitTitle(def.title)
    local codes = QA.Codes(def)
    local area = AreaOf(def)
    local status, stale = TB.Status(id)
    local hay = { tostring(def.title or ""), id, table.concat(codes, " "), area }
    for _, st in ipairs(def.steps) do if type(st) == "table" then hay[#hay + 1] = StripColour(st.text) end end
    return { id = id, title = title, codes = table.concat(codes, ", "), area = area, status = status, stale = stale, state = state,
        baseline = isBase[id] == true, hay = table.concat(hay, "\n"):lower() }
end
-- the new / changed state of every walkthrough (the review popup's own reading), or {} without it
function TB.States()
    local t = {}
    if QA.Review and QA.Review.Changed then for _, e in ipairs((QA.Review.Changed())) do t[e.id] = e.state end end
    return t
end
-- entries for a list of { id, state }, ranked in the default order: area, then the list's own order
function TB.Entries(list)
    local out = {}
    for i, x in ipairs(list) do
        local e = TB.Entry(x.id, x.state)
        if e then e.pos = i; out[#out + 1] = e end
    end
    table.sort(out, function(a, b) if a.area ~= b.area then return a.area < b.area end; return a.pos < b.pos end)
    for i, e in ipairs(out) do e.rank = i end
    return out
end
function TB.NewFilter() return { q = "", base = false, new = false, areas = {}, status = {} } end
local function AnyOn(set) for _, v in pairs(set) do if v then return true end end return false end
-- does an entry pass the search and the chips? (OR within areas, OR within statuses, AND across groups, AND with the search)
function TB.Match(e, f)
    if f.q ~= "" and not e.hay:find(f.q, 1, true) then return false end
    if f.base and not e.baseline then return false end
    if f.new and not e.state then return false end
    if AnyOn(f.areas) and not f.areas[e.area] then return false end
    if AnyOn(f.status) and not f.status[e.status] then return false end
    return true
end
local LAST = "\255"   -- empty cells sort after every text (and first when reversed)
local SORTVAL = {
    codes = function(e) return e.codes ~= "" and e.codes:lower() or LAST end,
    title = function(e) return e.title:lower() end,
    area = function(e) return e.area:lower() end,
    status = function(e) return STATUS_LABEL[e.status]:lower() end,
    new = function(e) return e.state or LAST end,
}
TB.SORTVAL = SORTVAL
-- entries -> the rows to draw: filtered, then sorted by key (nil = the default order), reversed when desc; ties keep the default order
function TB.View(entries, f, key, desc)
    local vis = {}
    for _, e in ipairs(entries) do if TB.Match(e, f) then vis[#vis + 1] = e end end
    local val = key and SORTVAL[key]
    table.sort(vis, function(a, b)
        if val then
            local va, vb = val(a), val(b)
            if va ~= vb then if desc then return va > vb end return va < vb end
        end
        return a.rank < b.rank
    end)
    return vis
end

-------------------------------------------------------------------------------
-- The widget: search row, chips, header, scrolling rows
-------------------------------------------------------------------------------
local ACC = { 0.55, 0.35, 0.95 }
local function Btn(parent, label, w, onClick, flat)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 90, 22); b:SetText(label)
    local cns = rawget(_G, "XayaUI_NS")
    if flat ~= false and cns and cns.FlatButton then cns.FlatButton(b) end   -- (#286: XayaUI's flat look)
    b:SetScript("OnClick", onClick)
    return b
end
-- columns, left to right (Xaya's list); Title takes the width the others leave
TB.COLUMNS = {
    { key = "codes", label = "Codes", w = 150, wrap = true },
    { key = "title", label = "Title", wrap = true },
    { key = "area", label = "Area", w = 160, wrap = true },
    { key = "status", label = "Status", w = 104 },
    { key = "new", label = "New", w = 64 },
    { key = "open", label = "Open", w = 60, fixed = true },   -- (a button: not a sort key)
}
local CHIP_H, ROW_MIN, PAD = 20, 22, 4

local T = {}
T.__index = T

-- TB.Create(parent, { left, top, right, bottom, width, onOpen = function(id) }): top / bottom are distances from the parent's edges
function TB.Create(parent, cfg)
    local t = setmetatable({ parent = parent, cfg = cfg, f = TB.NewFilter(), entries = {}, visible = {}, rows = {}, chips = {},
        chipPool = {}, headers = {}, cols = {} }, T)
    local x, fixed = 0, 0
    for _, c in ipairs(TB.COLUMNS) do fixed = fixed + (c.w or 0) end
    for i, c in ipairs(TB.COLUMNS) do
        local w = c.w or math.max(120, cfg.width - fixed)
        t.cols[i] = { key = c.key, label = c.label, x = x, w = w, wrap = c.wrap, fixed = c.fixed }
        x = x + w
    end
    t.searchLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t.searchLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.left, -cfg.top - 3); t.searchLabel:SetText("Search")
    t.search = CreateFrame("EditBox", nil, parent, "InputBoxTemplate"); t.search:SetSize(260, 20); t.search:SetAutoFocus(false)
    t.search:SetPoint("LEFT", t.searchLabel, "RIGHT", 12, 0)
    t.search:SetScript("OnTextChanged", function(self) t:SetSearch(self:GetText()) end)
    t.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    t.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    t.clear = Btn(parent, "Clear", 70, function() t:Clear() end); t.clear:SetPoint("LEFT", t.search, "RIGHT", 8, 0)
    t.count = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable"); t.count:SetPoint("LEFT", t.clear, "RIGHT", 10, 0)
    -- header row (stays put; only the rows under it scroll)
    t.head = CreateFrame("Frame", nil, parent); t.head:SetSize(cfg.width, 20)
    t.headBg = t.head:CreateTexture(nil, "BACKGROUND"); t.headBg:SetAllPoints(t.head); t.headBg:SetColorTexture(ACC[1], ACC[2], ACC[3], 0.30)
    for i, c in ipairs(t.cols) do
        local h = CreateFrame("Button", nil, t.head); h:SetSize(c.w, 20); h:SetPoint("TOPLEFT", t.head, "TOPLEFT", c.x, 0)
        h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); h.text:SetPoint("LEFT", h, "LEFT", PAD, 0)
        h.text:SetJustifyH("LEFT"); h.text:SetText(c.label)
        h.key = c.key
        if not c.fixed then
            local hl = h:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(h); hl:SetColorTexture(1, 1, 1, 0.08)
            h:SetScript("OnClick", function() t:SortBy(c.key) end)
        end
        t.headers[i] = h
    end
    t.scroll = CreateFrame("ScrollFrame", nil, parent)
    t.child = CreateFrame("Frame", nil, t.scroll); t.child:SetSize(cfg.width, 10); t.scroll:SetScrollChild(t.child)
    t.scroll:EnableMouseWheel(true)
    t.scroll:SetScript("OnMouseWheel", function(self, d)
        local maxS = math.max(0, (t.child:GetHeight() or 0) - (self:GetHeight() or 0))
        self:SetVerticalScroll(math.max(0, math.min(maxS, (self:GetVerticalScroll() or 0) - d * 48)))
    end)
    return t
end

-- (0.7.53, #466 / #481) move the search row (and the chips and rows under it, at the next SetEntries) to start `top` px below the
-- window's top: the windows measure the text above the table and call this, so nothing overlaps at any text size
function T:SetTop(top)
    top = math.floor(tonumber(top) or self.cfg.top)
    self.cfg.top = top
    self.searchLabel:ClearAllPoints(); self.searchLabel:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.cfg.left, -top - 3)
end
local PARTS = { "searchLabel", "search", "clear", "count", "head", "scroll" }
function T:SetShown(on)
    for _, k in ipairs(PARTS) do self[k]:SetShown(on and true or false) end
    for _, b in ipairs(self.chipPool) do b:SetShown((on and b.inUse) and true or false) end
end

-- a chip's look: on = the theme's primary button and green text (green also shows with XayaUI's skin off)
local function PaintChip(b, on)
    b.on = on and true or false
    local cns = rawget(_G, "XayaUI_NS")
    if cns and cns.PaintFlatButton then pcall(cns.PaintFlatButton, b, b.on) end
    b:SetText(b.on and ("|cff60ff60" .. b.label .. "|r") or b.label)
end
function T:ChipOn(key)
    local f = self.f
    if key == "baseline" then return f.base end
    if key == "new" then return f.new end
    local a = key:match("^area:(.*)$"); if a then return f.areas[a] == true end
    local s = key:match("^status:(.*)$"); if s then return f.status[s] == true end
    return false
end
-- the chips for the entries shown: Baseline, one per area, Not run / Passed / Failed, New or changed
function T:BuildChips()
    local specs, areas, seen = { { key = "baseline", label = "Baseline" } }, {}, {}
    for _, e in ipairs(self.entries) do if not seen[e.area] then seen[e.area] = true; areas[#areas + 1] = e.area end end
    table.sort(areas)
    for _, a in ipairs(areas) do specs[#specs + 1] = { key = "area:" .. a, label = a } end
    -- an area chip whose area has no walkthrough left is dropped from the filter (it would match nothing)
    for a in pairs(self.f.areas) do if not seen[a] then self.f.areas[a] = nil end end
    specs[#specs + 1] = { key = "status:notrun", label = "Not run" }
    specs[#specs + 1] = { key = "status:passed", label = "Passed" }
    specs[#specs + 1] = { key = "status:failed", label = "Failed" }
    specs[#specs + 1] = { key = "new", label = "New or changed" }
    self.chips = {}
    local left, width = self.cfg.left, self.cfg.width
    local x, y = 0, self.cfg.top + 28
    for i, s in ipairs(specs) do
        local b = self.chipPool[i]
        if not b then
            b = Btn(self.parent, "", 60, nil, false); b:SetHeight(CHIP_H)
            self.chipPool[i] = b
        end
        b.key, b.label, b.inUse = s.key, s.label, true
        b:SetText(s.label)
        local fs = b.GetFontString and b:GetFontString()
        local w = math.floor(((fs and fs.GetStringWidth and fs:GetStringWidth()) or (#s.label * 6)) + 18)
        b:SetWidth(w)
        if x > 0 and x + w > width then x = 0; y = y + CHIP_H + 4 end
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", self.parent, "TOPLEFT", left + x, -y)
        x = x + w + 6
        b:SetScript("OnClick", function() self:ToggleChip(s.key) end)
        PaintChip(b, self:ChipOn(s.key))
        b:Show()
        self.chips[s.key] = b
    end
    for i = #specs + 1, #self.chipPool do self.chipPool[i].inUse = false; self.chipPool[i]:Hide() end
    -- the header sits under the last row of chips; the rows fill the rest of the window
    local headY = y + CHIP_H + 8
    self.head:ClearAllPoints(); self.head:SetPoint("TOPLEFT", self.parent, "TOPLEFT", left, -headY)
    self.scroll:ClearAllPoints()
    self.scroll:SetPoint("TOPLEFT", self.head, "BOTTOMLEFT", 0, -2)
    self.scroll:SetPoint("BOTTOMRIGHT", self.parent, "BOTTOMRIGHT", -(self.cfg.right or self.cfg.left), self.cfg.bottom)
end

-- (re)load the rows' data: list = { { id = "...", state = "new" | "changed" | nil }, ... }. Search, chips and sort stay as they are.
function T:SetEntries(list)
    self.entries = TB.Entries(list)
    self:BuildChips()
    self:Refresh()
end
function T:SetSearch(text)
    local q = Trim(text):lower()
    if q == self.f.q then return end
    self.f.q = q
    self:Refresh()
end
-- type into the search box (the walkthrough's "Do it for me" and the tests use this)
function T:Type(text)
    self.search:SetText(text or "")
    self:SetSearch(text or "")
end
function T:ToggleChip(key)
    local f = self.f
    if key == "baseline" then f.base = not f.base
    elseif key == "new" then f.new = not f.new
    else
        local a = key:match("^area:(.*)$")
        local s = key:match("^status:(.*)$")
        if a then f.areas[a] = (not f.areas[a]) or nil
        elseif s then f.status[s] = (not f.status[s]) or nil end
    end
    local b = self.chips[key]
    if b then PaintChip(b, self:ChipOn(key)) end
    self:Refresh()
end
function T:Clear()
    self.f = TB.NewFilter()
    self.search:SetText("")
    for _, b in pairs(self.chips) do PaintChip(b, false) end
    self:Refresh()
end
function T:SortBy(key)
    if self.sortKey == key then self.sortDesc = not self.sortDesc else self.sortKey, self.sortDesc = key, false end
    self:Refresh()
end

local function Row(t, i)
    local r = t.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, t.child); r:SetSize(t.cfg.width, ROW_MIN)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(r)
    r.cells = {}
    for _, c in ipairs(t.cols) do
        if c.key == "open" then
            r.open = Btn(r, "Open", 52, function() if t.cfg.onOpen and r.id then t.cfg.onOpen(r.id) end end); r.open:SetHeight(20)
            r.open:SetPoint("TOPLEFT", r, "TOPLEFT", c.x + PAD, -1)
        else
            local fs = r:CreateFontString(nil, "OVERLAY", c.key == "title" and "GameFontHighlight" or (c.key == "status" or c.key == "new") and "GameFontNormalSmall" or "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", r, "TOPLEFT", c.x + PAD, -PAD - 1); fs:SetWidth(c.w - 2 * PAD); fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP")
            fs:SetWordWrap(c.wrap and true or false)
            if c.key == "codes" then fs:SetTextColor(0.75, 0.75, 0.75) end
            r.cells[c.key] = fs
            r[c.key] = fs
        end
    end
    t.rows[i] = r
    return r
end
-- draw the rows that pass the filter, in the sort order; header arrows; the count
function T:Refresh()
    local vis = TB.View(self.entries, self.f, self.sortKey, self.sortDesc)
    self.visible = vis
    for _, h in ipairs(self.headers) do
        local arrow = (h.key == self.sortKey) and (self.sortDesc and "  v" or "  ^") or ""
        h.text:SetText(h.key ~= "open" and (self:Label(h.key) .. arrow) or self:Label(h.key))
    end
    local y = 0
    for i, e in ipairs(vis) do
        local r = Row(self, i)
        r.id, r.entry = e.id, e
        r.codes:SetText(Esc(e.codes))
        r.title:SetText(Esc(e.title) .. (e.baseline and "  |cffffd100Baseline|r" or ""))
        r.area:SetText(Esc(e.area))
        r.status:SetText(("|cff%s%s|r%s"):format(STATUS_COLOUR[e.status], STATUS_LABEL[e.status], e.stale and " |cffffaa00(rerun)|r" or ""))
        r.new:SetText(e.state == "new" and "|cff60c0ffnew|r" or e.state == "changed" and "|cffffd100changed|r" or "")
        local h = 0
        for _, c in ipairs(self.cols) do
            local fs = r.cells[c.key]
            if fs and c.wrap then h = math.max(h, (fs.GetStringHeight and fs:GetStringHeight()) or 12) end
        end
        local rh = math.max(ROW_MIN, math.ceil(h) + 2 * PAD + 2)
        r:SetHeight(rh)
        r.bg:SetColorTexture(1, 1, 1, (i % 2 == 1) and 0.05 or 0)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
        r:Show()
        y = y + rh
    end
    for i = #vis + 1, #self.rows do self.rows[i].id = nil; self.rows[i]:Hide() end
    self.child:SetHeight(math.max(10, y)); self.scroll:SetVerticalScroll(0)
    self.count:SetText(("Showing %d of %d"):format(#vis, #self.entries))
end
function T:Label(key) for _, c in ipairs(self.cols) do if c.key == key then return c.label end end return key end
-- the ids in the order drawn (tests and the walkthrough read this)
function T:Ids() local o = {}; for i, e in ipairs(self.visible) do o[i] = e.id end; return o end
