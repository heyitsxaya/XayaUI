-------------------------------------------------------------------------------
-- Notepad.lua : QoL "Notepad" - a floating, movable, resizable box you can type reminders into.
--   * Notes (memos): any number of notes; the toolbar adds, duplicates, deletes, and flips between them.
--   * Nothing typed is lost: the text is saved as you type, and earlier versions of each note are kept automatically (a new
--     version after a pause in typing, and always right before a big chunk of text disappears). Deleted notes go to a trash.
--     Toolbar "Hist" (or the options page) opens the Restore list: earlier versions of this note + deleted notes.
--   * List: the toolbar's List button shows every note in the box (click one to open it).
--   * Formatting (toolbar Fmt, off by default): a format bar (heading, bullet, checkbox, colors, spell icon) and a formatted view.
--     Markup is plain text: '# heading', '- bullet', '[ ] / [x] checkbox', |cffRRGGBBtext|r colors, {spell:ID} icon + name.
--   * Toolbar: at the top, bottom, left, or right of the box; always visible, or only while the mouse is over the box.
--   * Open / close: /xui notepad, the x on the box, or QoL UI Updates > Notepad. Whether it is open is remembered.
--   * Drag the title bar to move, drag the bottom-right corner to resize. "Lock" stops both.
-- Own code, written against Blizzard's frame API only (no other addon's code or data). UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local TITLE_H = 20
local TB_H, TB_W, BTN_W = 20, 38, 26   -- toolbar thickness (horizontal), width (vertical), button width (horizontal)
local FB_H, FMT_MINW = 20, 262         -- format bar height, minimum box width while it is shown
local MAX_CHARS = 8000                 -- per note
local IDLE_SECS = 4                    -- pause in typing that saves a version
local BIG_DROP = 20                    -- characters removed in one edit that save the old text first
local MAX_TRASH = 30

ns.NOTEPAD_DEFAULTS = {
    shown = false,
    locked = false,
    anchor = "CENTER", x = 300, y = 0,
    w = 280, h = 220,
    bgAlpha = 85,
    fontSize = 13,
    font = "none",
    strata = "MEDIUM",
    hideInCombat = false,
    dropFocusInCombat = true,
    format = false,          -- formatting tools: format bar + formatted view
    acceptShares = true,     -- offer notes shared by other XayaUI users (NotepadShare.lua)
    toolbar = true,
    toolbarPos = "TOP",      -- TOP | BOTTOM | LEFT | RIGHT
    toolbarHover = false,    -- true: toolbar only shows while the mouse is over the box
    maxHistory = 20,         -- earlier versions kept per note
    current = 0, nextId = 1,
}

local function DB() return ns.notepadDB end
local function InCombat() return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) end

-------------------------------------------------------------------------------
-- data
-------------------------------------------------------------------------------
local function NewNoteTable(text)
    local db = DB()
    local n = { id = db.nextId, text = text or "", hist = {}, created = time(), modified = time() }
    db.nextId = db.nextId + 1
    return n
end

local function IndexOf(id)
    local db = DB()
    for i, n in ipairs(db.notes) do if n.id == id then return i, n end end
end

local function Cur()
    local db = DB(); if not db then return end
    local _, n = IndexOf(db.current)
    if not n then
        if #db.notes == 0 then db.notes[1] = NewNoteTable("") end
        n = db.notes[1]; db.current = n.id
    end
    return n
end

local pendingAt, pendingNote   -- typing pause tracker

local function Snapshot(n, text)
    local db = DB(); if not (db and n) then return end
    text = text or n.text
    if not text or not text:match("%S") then return end
    local h = n.hist
    if h[1] and h[1].text == text then return end
    table.insert(h, 1, { t = time(), text = text })
    for i = #h, math.max(1, db.maxHistory or 20) + 1, -1 do h[i] = nil end
end

local function Flush()
    if pendingNote then Snapshot(pendingNote) end
    pendingAt, pendingNote = nil, nil
end

function ns.Notepad_OnDBReady()
    CueRulesDB.notepad = CueRulesDB.notepad or {}
    local db = CueRulesDB.notepad
    ns.Merge(db, ns.NOTEPAD_DEFAULTS)
    db.notes = db.notes or {}
    db.trash = db.trash or {}
    ns.notepadDB = db
    if db.text then   -- 0.5.39 stored one text; it becomes the first note
        if db.text:match("%S") then db.notes[#db.notes + 1] = NewNoteTable(db.text) end
        db.text = nil
    end
    Cur()
    ns.Notepad_Refresh()
end

-------------------------------------------------------------------------------
-- frame
-------------------------------------------------------------------------------
local frame, popup

local function SavePosition(self)
    local db = DB(); if not db then return end
    local l, t = self:GetLeft(), self:GetTop()
    if not (l and t) then return end
    -- top-left corner relative to UIParent's top-left, so resizing never shifts the box
    db.anchor, db.x, db.y = "TOPLEFT", math.floor(l + 0.5), math.floor(t - UIParent:GetHeight() + 0.5)
    db.w, db.h = math.floor(self:GetWidth() + 0.5), math.floor(self:GetHeight() + 0.5)
end

-- formatted view: plain-text markup -> WoW escape codes (a FontString has one font, so no bold or mixed sizes: color, bullets, icons only)
local function CharBefore(text, pos)   -- the UTF-8 character just before cursor position pos (the cursor counts characters, not bytes)
    local last, i = nil, 0
    for ch in (text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if i >= pos then break end
        i = i + 1; last = ch
    end
    return last
end
local function SpellToken(id)
    id = tonumber(id); if not id then return nil end
    local name, icon
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(info) == "table" then name, icon = info.name, info.iconID end
    end
    if not icon and C_Spell and C_Spell.GetSpellTexture then local ok, t = pcall(C_Spell.GetSpellTexture, id); if ok then icon = t end end
    if not name then return nil end
    return ("|T%s:14|t %s"):format(tostring(icon or 134400), name)
end
local function RenderLine(line)
    line = line:gsub("{spell:(%d+)}", function(id) return SpellToken(id) or ("|cff888888{spell:" .. id .. "}|r") end)
    local h = line:match("^#+%s*(.*)$")
    if h then return "|cffffd100" .. h .. "|r" end
    local d = line:match("^%s*%[[xX]%]%s?(.*)$")
    if d then return "|cff55dd55[x]|r |cff8a8a8a" .. d .. "|r" end
    local t = line:match("^%s*%[ %]%s?(.*)$")
    if t then return "|cffffd100[ ]|r " .. t end
    local b = line:match("^%s*[-*]%s+(.*)$")
    if b then return "  |cff99ccff\226\128\162|r " .. b end
    return line
end
function ns.Notepad_Render(text)
    local out = {}
    for line in ((text or "") .. "\n"):gmatch("(.-)\r?\n") do out[#out + 1] = RenderLine(line) end
    if out[#out] == "" then out[#out] = nil end
    return table.concat(out, "\n")
end
ns.Notepad_CharBefore = CharBefore

local mode = { list = false, view = false }   -- this session only: list of all notes / formatted view
local RefreshView, ApplyMode, PopulateList     -- assigned below

local function SetEditText(text)
    frame.settingText = true
    frame.eb:SetText(text or "")
    frame.settingText = false
    frame.sf:SetVerticalScroll(0)
    if RefreshView then RefreshView() end
end

local function UpdateTitle()
    local db = DB(); if not (db and frame) then return end
    local n = Cur()
    local idx = IndexOf(db.current) or 1
    local first = (n.text or ""):match("[^\r\n]+") or "(empty)"
    if #first > 40 then first = first:sub(1, 40) .. "..." end
    first = first:gsub("|", "||")
    frame.title:SetText(("Notepad %d/%d  |cff999999%s|r"):format(idx, #db.notes, first))
end

local Populate   -- restore list refresher (defined below)

local function Select(id)
    local db = DB(); if not db then return end
    local _, n = IndexOf(id); if not n then return end
    Flush()
    db.current = id
    if frame then SetEditText(n.text); UpdateTitle() end
    if Populate then Populate() end
    if PopulateList then PopulateList() end
end

function ns.Notepad_New(text, after)
    local db = DB(); if not db then return end
    Flush()
    local n = NewNoteTable(text)
    local at = after and ((IndexOf(db.current) or #db.notes) + 1) or (#db.notes + 1)
    table.insert(db.notes, at, n)
    Select(n.id)
    if (mode.list or mode.view) and ApplyMode then mode.list, mode.view = false, false; ApplyMode() end
    if frame and frame:IsShown() and not text then frame.eb:SetFocus() end
end

-- small API for NotepadShare.lua (share, export, import) ---------------------------------------------------------------------
ns.Notepad_MAX_CHARS = MAX_CHARS
function ns.Notepad_CurrentText() local n = Cur(); return n and n.text or "" end
function ns.Notepad_AllTexts() local db = DB(); local out = {}; if db then for i, n in ipairs(db.notes) do out[i] = n.text or "" end end; return out end
function ns.Notepad_AddNote(text)   -- adds a note at the end without switching to it; returns its position, or nil
    local db = DB(); if not db then return nil end
    Flush()
    local n = NewNoteTable((tostring(text or "")):sub(1, MAX_CHARS))
    db.notes[#db.notes + 1] = n
    if PopulateList then PopulateList() end
    if Populate then Populate() end
    return #db.notes
end

function ns.Notepad_Duplicate()
    local n = Cur(); if not n then return end
    ns.Notepad_New(n.text, true)
end

function ns.Notepad_Delete()
    local db = DB(); if not db then return end
    local n = Cur(); if not n then return end
    Flush()
    local i = IndexOf(n.id)
    Snapshot(n)
    if n.text:match("%S") or #n.hist > 0 then   -- empty untouched notes are not worth keeping
        table.insert(db.trash, 1, { note = n, deleted = time() })
        for k = #db.trash, MAX_TRASH + 1, -1 do db.trash[k] = nil end
    end
    table.remove(db.notes, i)
    if #db.notes == 0 then db.notes[1] = NewNoteTable("") end
    Select(db.notes[math.min(i, #db.notes)].id)
    ns.Print("note deleted. Notepad > Hist > Deleted notes brings it back.")
end

local function Step(d)
    local db = DB(); if not db or #db.notes < 2 then return end
    local i = IndexOf(db.current) or 1
    Select(db.notes[((i - 1 + d) % #db.notes) + 1].id)
end
function ns.Notepad_Next() Step(1) end
function ns.Notepad_Prev() Step(-1) end

function ns.Notepad_Clear()
    local db = DB(); if not db then return end
    local n = Cur(); if not n then return end
    Flush(); Snapshot(n)   -- Clear is undoable: the old text is in Hist
    n.text = ""; n.modified = time()
    if frame then SetEditText(""); UpdateTitle() end
    if Populate then Populate() end
end

-------------------------------------------------------------------------------
-- restore list: earlier versions of this note + deleted notes
-------------------------------------------------------------------------------
local ROW_H = 20
local rows = {}

local function Preview(text, n)
    local s = (text or ""):gsub("[\r\n]+", " "):gsub("|", "||")
    if #s > n then s = s:sub(1, n) .. "..." end
    return s == "" and "(empty)" or s
end

local function Row(i)
    if rows[i] then return rows[i] end
    local b = CreateFrame("Button", nil, popup.child)
    b:SetHeight(ROW_H)
    b:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H); b:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.25)
    b.fs = b:CreateFontString(nil, "OVERLAY"); b.fs:SetFont(STANDARD_TEXT_FONT, 11, ""); b.fs:SetPoint("LEFT", 4, 0); b.fs:SetPoint("RIGHT", -4, 0)
    b.fs:SetJustifyH("LEFT"); b.fs:SetWordWrap(false)
    b:SetScript("OnClick", function(self) if self.act then self.act() end end)
    b:SetScript("OnEnter", function(self)
        if not self.full then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tipTitle or "", 1, 0.82, 0)
        GameTooltip:AddLine(Preview(self.full, 300), 1, 1, 1, true)
        GameTooltip:AddLine("Click to restore", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = b
    return b
end

Populate = function()
    if not (popup and popup:IsShown()) then return end
    local db, n = DB(), Cur()
    if not (db and n) then return end
    local used = 0
    local function Add(text, full, tipTitle, act, header)
        used = used + 1
        local b = Row(used)
        b:Show()
        b.fs:SetText(text)
        b.full, b.tipTitle, b.act = (not header) and full or nil, tipTitle, (not header) and act or nil
        b:EnableMouse(not header)
        b.hl:SetShown(not header)
    end
    Add("|cffffd100Earlier versions of this note|r", nil, nil, nil, true)
    if #n.hist == 0 then Add("|cff999999(none yet - versions are saved when you pause typing)|r", nil, nil, nil, true) end
    for _, h in ipairs(n.hist) do
        Add(("%s  %s"):format(date("%b %d %H:%M:%S", h.t), Preview(h.text, 40)), h.text, "Version from " .. date("%b %d %H:%M:%S", h.t), function()
            Flush(); Snapshot(n)   -- what is there now stays recoverable too
            n.text = h.text; n.modified = time()
            SetEditText(n.text); UpdateTitle(); Populate()
        end)
    end
    Add("|cffffd100Deleted notes|r", nil, nil, nil, true)
    if #db.trash == 0 then Add("|cff999999(none)|r", nil, nil, nil, true) end
    for ti, tr in ipairs(db.trash) do
        Add(("%s  %s"):format(date("%b %d %H:%M", tr.deleted), Preview(tr.note.text, 40)), tr.note.text, "Deleted note from " .. date("%b %d %H:%M", tr.deleted), function()
            table.remove(db.trash, ti)
            db.notes[#db.notes + 1] = tr.note
            Select(tr.note.id)
        end)
    end
    for i = used + 1, #rows do rows[i]:Hide() end
    popup.child:SetHeight(math.max(1, used * ROW_H))
    popup.child:SetWidth(popup.sf:GetWidth() > 0 and popup.sf:GetWidth() or 260)
end

local function BuildPopup()
    if popup then return popup end
    local p = CreateFrame("Frame", "XayaUINotepadRestore", UIParent, "BackdropTemplate")
    popup = p
    p:SetSize(300, 300); p:SetFrameStrata("DIALOG"); p:SetClampedToScreen(true); p:EnableMouse(true); p:Hide()
    p:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    p:SetBackdropColor(0.04, 0.04, 0.04, 0.96); p:SetBackdropBorderColor(0.2, 0.7, 1, 1)
    local t = p:CreateFontString(nil, "OVERLAY"); t:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); t:SetPoint("TOPLEFT", 8, -6); t:SetTextColor(1, 0.82, 0)
    t:SetText("Notepad - Restore")
    local x = CreateFrame("Button", nil, p); x:SetSize(20, 20); x:SetPoint("TOPRIGHT", -2, -2)
    x.t = x:CreateFontString(nil, "OVERLAY"); x.t:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE"); x.t:SetPoint("CENTER"); x.t:SetText("x")
    x:SetScript("OnClick", function() p:Hide() end)
    local sf = CreateFrame("ScrollFrame", nil, p)
    sf:SetPoint("TOPLEFT", 6, -26); sf:SetPoint("BOTTOMRIGHT", -6, 6); sf:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, sf); child:SetSize(260, 1); sf:SetScrollChild(child)
    sf:SetScript("OnMouseWheel", function(self, d)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * ROW_H * 3)))
    end)
    p.sf, p.child = sf, child
    p:SetScript("OnShow", function() Populate() end)
    return p
end

function ns.Notepad_ToggleRestore()
    local p = BuildPopup()
    if p:IsShown() then p:Hide(); return end
    p:ClearAllPoints()
    if frame and frame:IsShown() then p:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, 0) else p:SetPoint("CENTER") end
    p:Show()
    Populate()
end

-------------------------------------------------------------------------------
-- toolbar
-------------------------------------------------------------------------------
local BUTTONS = {
    { "New",  "Add a new note",                         function() ns.Notepad_New(nil, true) end },
    { "Dup",  "Duplicate this note",                    function() ns.Notepad_Duplicate() end },
    { "Del",  "Delete this note (kept under Hist)",     function() ns.Notepad_Delete() end },
    { "<",    "Previous note",                          function() ns.Notepad_Prev() end },
    { ">",    "Next note",                              function() ns.Notepad_Next() end },
    { "Hist", "Restore: earlier versions and deleted notes", function() ns.Notepad_ToggleRestore() end },
    { "List", "List of all notes (click one to open it)", function() ns.Notepad_ToggleList() end },
    { "Fmt",  "Formatting tools on / off: heading, bullet, checkbox, colors, spell icons, and a formatted view", function() ns.Notepad_ToggleFormat() end },
    { "More", "Share this note to chat, export notes as text, import notes", function(self) if ns.NotepadShare_Menu then ns.NotepadShare_Menu(self) end end },
}

-- Toolbar icons are drawn with lines and small squares (no font glyphs and no texture files, so they look the same on every client).
-- Coordinates are pixels from the middle of the button; each icon fits in about 10 x 10.
local function Pt(a, r) return r * math.cos(math.rad(a)), r * math.sin(math.rad(a)) end
local ICONS = {
    New = function(L) L(-4, 0, 4, 0, 1.6); L(0, -4, 0, 4, 1.6) end,                                       -- plus sign
    Dup = function(L)                                                                                     -- two pages
        L(-4, -2, -4, 5); L(-4, 5, 1, 5); L(1, 5, 1, 2)                                                   -- the page behind (its visible edges)
        L(-1, 2, 5, 2); L(5, 2, 5, -5); L(5, -5, -1, -5); L(-1, -5, -1, 2)                                -- the page in front
    end,
    Del = function(L)                                                                                     -- trash bin
        L(-5, 3, 5, 3, 1.4); L(-2, 3, -2, 5); L(-2, 5, 2, 5); L(2, 5, 2, 3)                               -- lid and handle
        L(-4, 3, -3, -5); L(-3, -5, 3, -5); L(3, -5, 4, 3); L(-1, 1, -1, -3); L(1, 1, 1, -3)              -- body and slats
    end,
    ["<"] = function(L) L(1.5, 3.5, -1.5, 0, 1.4); L(-1.5, 0, 1.5, -3.5, 1.4) end,                        -- small arrows
    [">"] = function(L) L(-1.5, 3.5, 1.5, 0, 1.4); L(1.5, 0, -1.5, -3.5, 1.4) end,
    Hist = function(L)                                                                                    -- clock with a counter-clockwise arrow (as in Chrome's history icon)
        local r, px, py = 5, nil, nil
        for i = 0, 10 do
            local x, y = Pt(150 - i * 30, r)
            if px then L(px, py, x, y) end
            px, py = x, y
        end
        local tx, ty = Pt(150, r)                                                                         -- arrowhead at the start of the arc
        local back = math.rad(150 - 90 + 180)                                                             -- the direction back along the arc
        for _, d in ipairs({ -40, 40 }) do
            local a = back + math.rad(d)
            L(tx, ty, tx + 3 * math.cos(a), ty + 3 * math.sin(a))
        end
        L(0, 3, 0, 0); L(0, 0, 2.5, 0)                                                                    -- clock hands
    end,
    List = function(L, Sq)                                                                                -- bullet list
        for _, y in ipairs({ 3, 0, -3 }) do Sq(-5, y, 2); L(-2, y, 5, y, 1.4) end
    end,
    Fmt = function(L)                                                                                     -- underlined A
        L(-4, -3, 0, 4.5, 1.4); L(0, 4.5, 4, -3, 1.4); L(-2.2, -1, 2.2, -1, 1.2); L(-5, -5.5, 5, -5.5, 1.2)
    end,
    More = function(L) L(-4.5, 3, 4.5, 3, 1.6); L(-4.5, 0, 4.5, 0, 1.6); L(-4.5, -3, 4.5, -3, 1.6) end,   -- hamburger menu
}

local function BuildToolbar(f)
    local tb = CreateFrame("Frame", nil, f)
    tb.bg = tb:CreateTexture(nil, "BACKGROUND"); tb.bg:SetAllPoints(); tb.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    tb.btns = {}; tb.byName = {}
    for i, def in ipairs(BUTTONS) do
        local b = CreateFrame("Button", nil, tb)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(0.18, 0.18, 0.18, 0.9)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.35)
        b.icon = {}
        local function L(x1, y1, x2, y2, th)
            local ln = b:CreateLine(nil, "OVERLAY")
            ln:SetThickness(th or 1.2); ln:SetColorTexture(0.92, 0.92, 0.92, 1)
            ln:SetStartPoint("CENTER", b, x1, y1); ln:SetEndPoint("CENTER", b, x2, y2)
            b.icon[#b.icon + 1] = ln
        end
        local function Sq(x, y, size)
            local t = b:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(0.92, 0.92, 0.92, 1); t:SetSize(size, size); t:SetPoint("CENTER", b, "CENTER", x, y)
            b.icon[#b.icon + 1] = t
        end
        if ICONS[def[1]] then ICONS[def[1]](L, Sq) end
        b:SetScript("OnClick", def[3])
        b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(def[2]); GameTooltip:Show() end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tb.btns[i] = b; tb.byName[def[1]] = b
    end
    return tb
end

local function Layout()
    local db = DB(); if not (db and frame) then return end
    local f, tb, sf = frame, frame.tb, frame.sf
    local pos = db.toolbarPos or "TOP"
    local vert = (pos == "LEFT" or pos == "RIGHT")
    tb:ClearAllPoints()
    local L, T, R, B = 6, TITLE_H + 4, 6, 14
    if db.toolbar then
        if pos == "TOP" then
            tb:SetPoint("TOPLEFT", 0, -TITLE_H); tb:SetPoint("TOPRIGHT", 0, -TITLE_H); tb:SetHeight(TB_H); T = TITLE_H + TB_H + 3
        elseif pos == "BOTTOM" then
            tb:SetPoint("BOTTOMLEFT", 0, 0); tb:SetPoint("BOTTOMRIGHT", -16, 0); tb:SetHeight(TB_H); B = TB_H + 3
        elseif pos == "LEFT" then
            tb:SetPoint("TOPLEFT", 0, -TITLE_H); tb:SetPoint("BOTTOMLEFT", 0, 0); tb:SetWidth(TB_W); L = TB_W + 4
        else
            tb:SetPoint("TOPRIGHT", 0, -TITLE_H); tb:SetPoint("BOTTOMRIGHT", 0, 0); tb:SetWidth(TB_W); R = TB_W + 4
        end
        for i, b in ipairs(tb.btns) do
            b:ClearAllPoints()
            if vert then b:SetSize(TB_W - 4, 18); b:SetPoint("TOP", tb, "TOP", 0, -2 - (i - 1) * 20)
            else b:SetSize(BTN_W, TB_H - 4); b:SetPoint("LEFT", tb, "LEFT", 2 + (i - 1) * (BTN_W + 2), 0) end
        end
    end
    tb:SetShown(db.toolbar and true or false)
    local fb = f.fb
    if fb then
        fb:ClearAllPoints()
        if db.format and not mode.list then
            fb:SetPoint("TOPLEFT", f, "TOPLEFT", L, -T); fb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -R, -T); fb:SetHeight(FB_H)
            T = T + FB_H + 2
        end
    end
    for _, area in ipairs({ sf, f.vf, f.lf }) do   -- typing area, formatted view, and note list share one spot
        area:ClearAllPoints(); area:SetPoint("TOPLEFT", f, "TOPLEFT", L, -T); area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -R, B)
    end
    local minW = vert and 150 or math.max(db.toolbar and #BUTTONS * (BTN_W + 2) + 6 or 140, db.format and FMT_MINW or 0)
    f.minW = minW
    local minH = (vert and db.toolbar) and (#BUTTONS * 20 + TITLE_H + 8) or 90   -- a side toolbar stacks its buttons
    f.minH = minH
    if f.SetResizeBounds then f:SetResizeBounds(minW, minH, 900, 900) end
end

-------------------------------------------------------------------------------
-- list of all notes, formatted view, format bar
-------------------------------------------------------------------------------
local LROW = 20
local lrows = {}

function ns.Notepad_ListEntries()   -- pure data: one entry per note, in order
    local db = DB(); local out = {}
    if not db then return out end
    for i, n in ipairs(db.notes) do
        out[i] = { id = n.id, index = i, text = Preview(n.text, 60), modified = n.modified, chars = #(n.text or ""), current = (n.id == db.current) }
    end
    return out
end

local function ListRow(i)
    if lrows[i] then return lrows[i] end
    local b = CreateFrame("Button", nil, frame.lc)
    b:SetHeight(LROW)
    b:SetPoint("TOPLEFT", 0, -(i - 1) * LROW); b:SetPoint("TOPRIGHT", 0, -(i - 1) * LROW)
    b.cur = b:CreateTexture(nil, "BACKGROUND"); b.cur:SetAllPoints(); b.cur:SetColorTexture(0.2, 0.7, 1, 0.18)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.3)
    b.date = b:CreateFontString(nil, "OVERLAY"); b.date:SetFont(STANDARD_TEXT_FONT, 10, ""); b.date:SetPoint("RIGHT", -4, 0); b.date:SetTextColor(0.55, 0.55, 0.55)
    b.fs = b:CreateFontString(nil, "OVERLAY"); b.fs:SetFont(STANDARD_TEXT_FONT, 11, "")
    b.fs:SetPoint("LEFT", 4, 0); b.fs:SetPoint("RIGHT", b.date, "LEFT", -6, 0); b.fs:SetJustifyH("LEFT"); b.fs:SetWordWrap(false)
    b:SetScript("OnClick", function(self) if self.id then Select(self.id); mode.list = false; ApplyMode() end end)
    b:SetScript("OnEnter", function(self)
        local _, n = IndexOf(self.id); if not n then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Note " .. (self.idx or "?"), 1, 0.82, 0)
        GameTooltip:AddLine(Preview(n.text, 300), 1, 1, 1, true)
        GameTooltip:AddLine(("%d characters. Click to open."):format(#(n.text or "")), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lrows[i] = b
    return b
end

PopulateList = function()
    if not (frame and frame.lf and frame.lf:IsShown()) then return end
    local entries = ns.Notepad_ListEntries()
    for i, e in ipairs(entries) do
        local b = ListRow(i)
        b:Show(); b.id, b.idx = e.id, e.index
        b.fs:SetText(("|cff888888%d|r  %s"):format(e.index, e.text))
        b.date:SetText(e.modified and date("%b %d", e.modified) or "")
        b.cur:SetShown(e.current and true or false)
    end
    for i = #entries + 1, #lrows do lrows[i]:Hide() end
    frame.lc:SetHeight(math.max(1, #entries * LROW))
    frame.lc:SetWidth(frame.lf:GetWidth() > 0 and frame.lf:GetWidth() or 200)
end

RefreshView = function()
    if not (frame and frame.vfs) then return end
    local n = Cur()
    frame.vfs:SetText(ns.Notepad_Render(n and n.text or ""))
    frame.vc:SetHeight(math.max(frame.vfs:GetStringHeight() + 6, 10))
end

ApplyMode = function()
    local db = DB(); if not (db and frame) then return end
    local f = frame
    if not db.format then mode.view = false end
    local list = mode.list and true or false
    local view = (db.format and mode.view and not list) and true or false
    Layout()
    f.sf:SetShown(not list and not view)
    f.vf:SetShown(view)
    f.lf:SetShown(list)
    f.fb:SetShown(db.format and not list and true or false)
    if list or view then f.eb:ClearFocus() end
    if list then PopulateList() end
    if view then RefreshView() end
    f.fb.btns[1].fs:SetText(view and "Edit" or "View")
    local function Tint(b, on) if b then b.bg:SetColorTexture(on and 0.1 or 0.18, on and 0.45 or 0.18, on and 0.7 or 0.18, 0.9) end end
    Tint(f.tb.byName.List, list); Tint(f.tb.byName.Fmt, db.format); Tint(f.fb.btns[1], view)
end

function ns.Notepad_ToggleList()
    if not frame then return end
    mode.list = not mode.list
    if mode.list then Flush() end
    ApplyMode()
end

function ns.Notepad_SetView(v)
    local db = DB(); if not (db and frame and db.format) then return end
    mode.view, mode.list = v and true or false, false
    ApplyMode()
    if not mode.view then frame.eb:SetFocus() end
end

function ns.Notepad_ToggleFormat()
    local db = DB(); if not (db and frame) then return end
    db.format = not db.format
    if not db.format then mode.view = false end
    ApplyMode()
    if ns.Notepad_Changed then ns.Notepad_Changed() end
end

local function ToEdit() if mode.list or mode.view then mode.list, mode.view = false, false; ApplyMode() end end
local function Ins(text, back)   -- insert at the cursor, then step back so the cursor sits inside the pair
    local db = DB(); if not (db and frame and db.format) then return end
    ToEdit()
    local eb = frame.eb
    eb:SetFocus(); eb:Insert(text)
    if back and back > 0 then eb:SetCursorPosition(math.max(0, eb:GetCursorPosition() - back)) end
end
local function LineStart(prefix)
    local db = DB(); if not (db and frame and db.format) then return end
    ToEdit()
    local eb = frame.eb
    local pos = eb:GetCursorPosition()
    local before = CharBefore(eb:GetText(), pos)
    Ins(((pos == 0 or before == "\n") and "" or "\n") .. prefix)
end
ns.Notepad_LineStart, ns.Notepad_Insert = LineStart, Ins

local FMT = {
    { w = 34, label = "View", tip = "Switch between typing (plain text) and the formatted view. Click the formatted text to edit it again.", act = function() ns.Notepad_SetView(not mode.view) end },
    { w = 24, label = "H", tip = "Heading: starts the line with # (gold in the formatted view).", act = function() LineStart("# ") end },
    { w = 24, label = "|cff99ccff-|r", tip = "Bullet: starts the line with - (a bullet in the formatted view).", act = function() LineStart("- ") end },
    { w = 24, label = "[ ]", tip = "Checkbox: starts the line with [ ]. Change it to [x] when done (grey with a green mark in the formatted view).", act = function() LineStart("[ ] ") end },
    { w = 24, label = "|cffff5555R|r", tip = "Red text: type between the color code and the closing ||r.", act = function() Ins("|cffff5555|r", 2) end },
    { w = 24, label = "|cffffd100Y|r", tip = "Yellow text: type between the color code and the closing ||r.", act = function() Ins("|cffffd100|r", 2) end },
    { w = 24, label = "|cff55dd55G|r", tip = "Green text: type between the color code and the closing ||r.", act = function() Ins("|cff55dd55|r", 2) end },
    { w = 24, label = "|cff66b3ffB|r", tip = "Blue text: type between the color code and the closing ||r.", act = function() Ins("|cff66b3ff|r", 2) end },
    { w = 34, label = "Spell", tip = "Inserts {spell:} - type a spell ID between the braces and the formatted view shows its icon and name.", act = function() Ins("{spell:}", 1) end },
}

local function BuildFormatBar(f)
    local fb = CreateFrame("Frame", nil, f)
    fb.bg = fb:CreateTexture(nil, "BACKGROUND"); fb.bg:SetAllPoints(); fb.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    fb.btns = {}
    local x = 2
    for i, def in ipairs(FMT) do
        local b = CreateFrame("Button", nil, fb)
        b:SetSize(def.w, FB_H - 4); b:SetPoint("LEFT", fb, "LEFT", x, 0); x = x + def.w + 2
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(0.18, 0.18, 0.18, 0.9)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.35)
        b.fs = b:CreateFontString(nil, "OVERLAY"); b.fs:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE"); b.fs:SetPoint("CENTER"); b.fs:SetText(def.label)
        b:SetScript("OnClick", def.act)
        b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(def.tip, 1, 1, 1, 1, true); GameTooltip:Show() end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        fb.btns[i] = b
    end
    fb:Hide()
    return fb
end

local function Build()
    if frame then return frame end
    local f = CreateFrame("Frame", "XayaUINotepad", UIParent, "BackdropTemplate")
    frame = f
    f:SetClampedToScreen(true); f:SetMovable(true); f:SetResizable(true); f:EnableMouse(true); f:Hide()

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(TITLE_H)
    bar:EnableMouse(true); bar:RegisterForDrag("LeftButton")
    bar.bg = bar:CreateTexture(nil, "BACKGROUND"); bar.bg:SetAllPoints(); bar.bg:SetColorTexture(0.13, 0.13, 0.13, 0.95)
    bar:SetScript("OnDragStart", function() local db = DB(); if db and not db.locked then f:StartMoving(); f.moving = true end end)
    bar:SetScript("OnDragStop", function() if f.moving then f.moving = false; f:StopMovingOrSizing(); SavePosition(f) end end)
    f.bar = bar

    local close = CreateFrame("Button", nil, bar)
    close:SetSize(TITLE_H, TITLE_H); close:SetPoint("RIGHT")
    close.t = close:CreateFontString(nil, "OVERLAY"); close.t:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE"); close.t:SetPoint("CENTER"); close.t:SetText("x")
    close:SetScript("OnEnter", function(self) self.t:SetTextColor(1, 0.3, 0.3) end)
    close:SetScript("OnLeave", function(self) self.t:SetTextColor(1, 1, 1) end)
    close:SetScript("OnClick", function() ns.Notepad_SetShown(false) end)

    local lock = CreateFrame("Button", nil, bar)
    lock:SetSize(TITLE_H + 14, TITLE_H); lock:SetPoint("RIGHT", close, "LEFT")
    lock.t = lock:CreateFontString(nil, "OVERLAY"); lock.t:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE"); lock.t:SetPoint("CENTER")
    lock:SetScript("OnClick", function() local db = DB(); if db then db.locked = not db.locked; ns.Notepad_Refresh(); if ns.Notepad_Changed then ns.Notepad_Changed() end end end)
    lock:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText("Lock / unlock"); GameTooltip:AddLine("Locked: the box cannot be moved or resized.", 1, 1, 1); GameTooltip:Show()
    end)
    lock:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.lock = lock

    f.title = bar:CreateFontString(nil, "OVERLAY")
    f.title:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    f.title:SetPoint("LEFT", 6, 0); f.title:SetPoint("RIGHT", lock, "LEFT", -4, 0)
    f.title:SetJustifyH("LEFT"); f.title:SetWordWrap(false); f.title:SetTextColor(1, 0.82, 0)

    f.tb = BuildToolbar(f)

    local sf = CreateFrame("ScrollFrame", nil, f)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, d)
        local step = (DB() and DB().fontSize or 13) * 2
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * step)))
    end)
    f.sf = sf

    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetMaxLetters(MAX_CHARS)
    eb:SetFontObject(ChatFontNormal or GameFontHighlight)
    eb:SetTextInsets(2, 2, 2, 2); eb:SetWidth(100)
    sf:SetScrollChild(eb)
    f.eb = eb
    sf:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then eb:SetWidth(w) end end)
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function() eb:SetFocus() end)

    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", function() Flush() end)
    eb:SetScript("OnTextChanged", function(self)
        if f.settingText then return end
        local n = Cur(); if not n then return end
        local new, old = self:GetText(), n.text or ""
        if #old - #new >= BIG_DROP then Snapshot(n, old) end   -- a big deletion: the text before it is kept
        n.text, n.modified = new, time()
        pendingAt, pendingNote = GetTime(), n
        UpdateTitle()
    end)
    eb:SetScript("OnCursorChanged", function(_, _, y, _, h)
        local top, viewH = sf:GetVerticalScroll(), sf:GetHeight()
        y = -y
        if y < top then sf:SetVerticalScroll(y)
        elseif y + h > top + viewH then sf:SetVerticalScroll(math.max(0, y + h - viewH)) end
    end)

    -- formatted view (read-only, click to edit), note list, format bar: all share the typing area's spot (see Layout)
    local vf = CreateFrame("ScrollFrame", nil, f)
    vf:EnableMouseWheel(true); vf:EnableMouse(true); vf:Hide()
    local vc = CreateFrame("Frame", nil, vf); vc:SetSize(100, 10); vf:SetScrollChild(vc)
    local vfs = vc:CreateFontString(nil, "OVERLAY")
    vfs:SetFontObject(ChatFontNormal or GameFontHighlight)
    vfs:SetPoint("TOPLEFT", 2, -2); vfs:SetPoint("TOPRIGHT", -2, -2); vfs:SetJustifyH("LEFT"); vfs:SetJustifyV("TOP")
    vf:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then vc:SetWidth(w); if RefreshView then RefreshView() end end end)
    vf:SetScript("OnMouseWheel", function(self, d)
        local step = (DB() and DB().fontSize or 13) * 2
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * step)))
    end)
    vf:SetScript("OnMouseDown", function() ns.Notepad_SetView(false) end)
    f.vf, f.vc, f.vfs = vf, vc, vfs

    local lf = CreateFrame("ScrollFrame", nil, f)
    lf:EnableMouseWheel(true); lf:Hide()
    local lc = CreateFrame("Frame", nil, lf); lc:SetSize(100, 1); lf:SetScrollChild(lc)
    lf:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then lc:SetWidth(w) end end)
    lf:SetScript("OnMouseWheel", function(self, d)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * LROW * 3)))
    end)
    f.lf, f.lc = lf, lc

    f.fb = BuildFormatBar(f)

    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(14, 14); grip:SetPoint("BOTTOMRIGHT", -1, 1)
    grip.t = grip:CreateTexture(nil, "OVERLAY"); grip.t:SetAllPoints(); grip.t:SetColorTexture(0.2, 0.7, 1, 0.7)
    grip:SetScript("OnMouseDown", function() local db = DB(); if db and not db.locked then f:StartSizing("BOTTOMRIGHT"); f.sizing = true end end)
    grip:SetScript("OnMouseUp", function() if f.sizing then f.sizing = false; f:StopMovingOrSizing(); SavePosition(f) end end)
    f.grip = grip

    -- timer: saves a version after a pause in typing; hover-reveals the toolbar
    local acc = 0
    f:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.2 then return end
        acc = 0
        if pendingAt and GetTime() - pendingAt >= IDLE_SECS then Flush(); Populate() end
        local db = DB()
        if db and db.toolbar then
            local show = (not db.toolbarHover) or f:IsMouseOver() or f.eb:HasFocus() or (popup and popup:IsShown() and popup:IsMouseOver())
            f.tb:SetAlpha(show and 1 or 0)
        end
    end)
    return f
end

-------------------------------------------------------------------------------
-- refresh
-------------------------------------------------------------------------------
function ns.Notepad_Refresh()
    local db = DB(); if not db then return end
    local f = Build()
    f:SetFrameStrata(db.strata or "MEDIUM")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.04, 0.04, 0.04, (db.bgAlpha or 85) / 100)
    if db.locked then f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) else f:SetBackdropBorderColor(0.2, 0.7, 1, 1) end
    f.lock.t:SetText(db.locked and "|cffffd100Locked|r" or "|cff99ccffLock|r")
    f.grip:SetShown(not db.locked)

    Layout()
    if not f.moving and not f.sizing then
        f:ClearAllPoints()
        f:SetPoint(db.anchor or "CENTER", UIParent, db.anchor or "CENTER", db.x or 0, db.y or 0)
        f:SetSize(math.max(f.minW or 150, db.w or 280), math.max(f.minH or 90, db.h or 220))
    end

    local path = ns.FontPath and ns.FontPath(db.font) or STANDARD_TEXT_FONT
    local size = math.max(8, math.min(40, tonumber(db.fontSize) or 13))
    if not f.eb:SetFont(path, size, "") then f.eb:SetFont(STANDARD_TEXT_FONT, size, "") end
    if not f.vfs:SetFont(path, size, "") then f.vfs:SetFont(STANDARD_TEXT_FONT, size, "") end
    local n = Cur()
    if n and f.eb:GetText() ~= (n.text or "") then SetEditText(n.text) end
    UpdateTitle()
    ApplyMode()
    if not db.toolbarHover then f.tb:SetAlpha(1) end

    local hide = db.hideInCombat and InCombat()
    f:SetShown((db.shown and not hide) and true or false)
end

function ns.Notepad_SetShown(v)
    local db = DB(); if not db then return end
    db.shown = v and true or false
    if not db.shown then Flush() end
    ns.Notepad_Refresh()
    if ns.Notepad_Changed then ns.Notepad_Changed() end
end

function ns.Notepad_Toggle()
    local db = DB(); if not db then ns.Print("Notepad is not ready yet."); return end
    ns.Notepad_SetShown(not db.shown)
    if db.shown and frame and not mode.list and not mode.view then frame.eb:SetFocus() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, e)
    local db = DB(); if not db or not frame then return end
    if e == "PLAYER_LOGOUT" then Flush(); return end
    if e == "PLAYER_REGEN_DISABLED" and db.dropFocusInCombat and frame.eb:HasFocus() then frame.eb:ClearFocus() end
    ns.Notepad_Refresh()
end)

-------------------------------------------------------------------------------
-- options page: QoL UI Updates > "Notepad"
-------------------------------------------------------------------------------
function ns.BuildNotepadTab(Notify)
    local db = DB()
    if not db then return nil end
    ns.Notepad_Changed = function() if Notify then Notify() end end
    local function g(k) return function() return db[k] end end
    local function s(k) return function(_, v) db[k] = v; ns.Notepad_Refresh() end end
    return { type = "group", name = "Notepad", order = 11, args = {
        n = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "A small floating box for typed reminders. It holds any number of notes, and nothing you type is lost: your text is saved as you type, earlier versions of each note are kept automatically, and deleted notes go to a trash. The Hist button on the toolbar (or the button below) opens the Restore list, and the List button shows all your notes at once. Open or close the box here, with the x on it, or with /xui notepad." },
        show = { type = "toggle", order = 1, name = "Show Notepad", get = g("shown"), set = function(_, v) ns.Notepad_SetShown(v) end },
        lock = { type = "toggle", order = 2, name = "Lock position and size", desc = "Also the Lock button on the box's title bar.", get = g("locked"), set = s("locked") },
        fmt = { type = "toggle", order = 2.5, name = "Formatting tools", desc = "Adds a format bar (heading, bullet, checkbox, colors, spell icon) and a formatted view. Also the Fmt button on the toolbar. Notes stay plain text: the formatting is markup you can read and edit.",
            get = g("format"), set = function(_, v) db.format = v and true or false; if not db.format then mode.view = false end; ns.Notepad_Refresh() end },
        list = { type = "execute", order = 2.6, name = "Show / hide the list of all notes", desc = "Also the List button on the toolbar.", func = function() ns.Notepad_ToggleList() end },
        restore = { type = "execute", order = 3, name = "Open Restore list", desc = "Earlier versions of the current note, and deleted notes.", func = function() ns.Notepad_ToggleRestore() end },
        share = { type = "group", name = "Share, export, and import", order = 3.5, inline = true, args = {
            note = { type = "description", order = 0, width = "full", name = "The More button on the toolbar shares the current note to chat for other XayaUI users, or exports and imports notes as text you can copy and paste." },
            accept = { type = "toggle", order = 1, name = "Accept notes shared by other XayaUI users", width = "double",
                desc = "A shared note never saves by itself: a small window offers it and you choose Save or Dismiss. Off: shared notes are ignored.",
                get = g("acceptShares"), set = s("acceptShares") },
            share = { type = "execute", order = 2, name = "Share this note...", func = function() if ns.NotepadShare_OpenShare then ns.NotepadShare_OpenShare() end end },
            exp = { type = "execute", order = 3, name = "Export notes...", func = function() if ns.NotepadShare_OpenIO then ns.NotepadShare_OpenIO("all") end end },
            imp = { type = "execute", order = 4, name = "Import notes...", func = function() if ns.NotepadShare_OpenIO then ns.NotepadShare_OpenIO("import") end end },
        } },
        tbar = { type = "group", name = "Toolbar", order = 4, inline = true, args = {
            on = { type = "toggle", order = 1, name = "Show toolbar", desc = "New, duplicate, delete, previous, next, history/restore, list, formatting, and share / import / export (More) buttons.", get = g("toolbar"), set = s("toolbar") },
            hover = { type = "toggle", order = 2, name = "Only show on mouseover", desc = "The toolbar stays hidden until the mouse is over the box (or you are typing in it). Its space stays reserved so the text does not jump.",
                disabled = function() return not db.toolbar end, get = g("toolbarHover"), set = s("toolbarHover") },
            pos = { type = "select", order = 3, name = "Toolbar position", disabled = function() return not db.toolbar end,
                values = { TOP = "Top", BOTTOM = "Bottom", LEFT = "Left", RIGHT = "Right" }, sorting = { "TOP", "BOTTOM", "LEFT", "RIGHT" },
                get = g("toolbarPos"), set = s("toolbarPos") },
        } },
        hist = { type = "group", name = "Versions", order = 5, inline = true, args = {
            max = { type = "range", order = 1, name = "Earlier versions kept per note", desc = "A version is saved when you pause typing, and always right before a large amount of text is removed. Oldest versions drop off first.",
                min = 5, max = 50, step = 1, get = g("maxHistory"), set = function(_, v) db.maxHistory = v end },
        } },
        combat = { type = "group", name = "Combat", order = 6, inline = true, args = {
            hide = { type = "toggle", order = 1, name = "Hide in combat", get = g("hideInCombat"), set = s("hideInCombat") },
            drop = { type = "toggle", order = 2, name = "Release the keyboard when combat starts",
                desc = "While you are typing in the box, your keybinds do not work. With this on, entering combat takes the cursor out of the box so they do.",
                get = g("dropFocusInCombat"), set = s("dropFocusInCombat") },
        } },
        look = { type = "group", name = "Look", order = 7, inline = true, args = {
            font = { type = "select", order = 1, name = "Font",
                values = function() local v = ns.FontList(); return v end, sorting = function() local _, o = ns.FontList(); return o end,
                get = g("font"), set = s("font") },
            size = { type = "range", order = 2, name = "Font Size", min = 8, max = 40, step = 1, get = g("fontSize"), set = s("fontSize") },
            alpha = { type = "range", order = 3, name = "Backdrop opacity (%)", min = 0, max = 100, step = 1, get = g("bgAlpha"), set = s("bgAlpha") },
            strata = { type = "select", order = 4, name = "Frame strata",
                values = { BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium", HIGH = "High", DIALOG = "Dialog" },
                sorting = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }, get = g("strata"), set = s("strata") },
        } },
        reset = { type = "group", name = "Reset", order = 8, inline = true, args = {
            pos = { type = "execute", order = 1, name = "Reset position and size",
                func = function() db.anchor, db.x, db.y, db.w, db.h = "CENTER", 300, 0, 280, 220; ns.Notepad_Refresh() end },
            clear = { type = "execute", order = 2, name = "Clear the current note", confirm = true, confirmText = "Clear the text of the current note? The old text stays in its version list (Hist).",
                func = function() ns.Notepad_Clear() end },
        } },
    } }
end

function ns.Notepad_OpenSettings()
    if ns.UI and ns.UI.Notepad then ns.UI.Notepad() end
end
