-------------------------------------------------------------------------------
-- Notepad.lua : QoL "Notepad" - a floating, movable, resizable box you can type reminders into.
--   * Notes (memos): any number of notes; the toolbar adds, duplicates, deletes, and flips between them.
--   * Nothing typed is lost: the text is saved as you type, and earlier versions of each note are kept automatically (a new
--     version after a pause in typing, and always right before a big chunk of text disappears). Deleted notes go to a trash.
--     Toolbar history (clock) button (or the options page) opens the Restore list: earlier versions of this note + deleted notes.
--   * List: the toolbar's list button shows every note in the box (click one to open it).
--   * Formatting (toolbar underlined-A button, off by default): a format bar (heading, bullet, checkbox, colors, spell icon) and a formatted view.
--     Markup is plain text: '# heading', '- bullet', '[ ] / [x] checkbox', |cffRRGGBBtext|r colors, {spell:ID} -> the spell's link ([Name] in the link colour).
--   * Toolbar: at the top, bottom, left, or right of the box; always visible, or only while the mouse is over the box.
--   * On / off (Bonus 0.6.14; Xaya 2026-11-06: "It should only enable or disable notepad functionality in its entirety"): the tick box on
--     its row in Bonus Features > Utilities. Off: nothing of the Notepad is built or runs, its sharing included (V14).
--   * Open / close (while it is on): /xui notepad, the x on the box, or "Show Notepad" on its page. Whether it is open is remembered.
--   * Drag the title bar to move, drag the bottom-right corner to resize. "Lock" stops both.
-- Own code, written against Blizzard's frame API only (no other addon's code or data). UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local BonusS = ns.Settings("bonus")   -- (Bonus 0.6.31, P2 settings seam; Bonus 0.6.33, P5: Bonus's own XayaUIBonusDB; Modules.lua section 0b)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("bonus", "XayaUI_Bonus", "XayaUIBonusDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)

local TITLE_H = 20
local TB_H, TB_W, BTN_W = 20, 38, 26   -- toolbar thickness (horizontal), width (vertical), button width (horizontal)
local NAME_H, NAME_MAX = 22, 40          -- height of the note-name row under the title bar; longest note name
local HDR = TITLE_H + NAME_H              -- title bar + name row: everything below starts here
local REF_W, REF_H = 280, 220             -- default box size; the toolbar grows with the box beyond this (up to 2x)
local ICON_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\UI\\Notepad\\"   -- icon images (PNG, 64x64; SVG sources are in src/)
local FB_H, FMT_MINW = 20, 262         -- format bar height, minimum box width while it is shown
local MAX_CHARS = 8000                 -- per note
local IDLE_SECS = 4                    -- pause in typing that saves a version
local BIG_DROP = 20                    -- characters removed in one edit that save the old text first
local MAX_TRASH = 30

ns.NOTEPAD_DEFAULTS = {
    enabled = true,          -- (Bonus 0.6.14) the feature as a whole; on by default as it always was (question to Xaya)
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
    iconLines = false,       -- true: simple drawn line icons instead of the image icons
    maxHistory = 20,         -- earlier versions kept per note
    current = 0, nextId = 1,
}

local function DB() return ns.notepadDB end
-- (Bonus 0.6.14) the Notepad feature is on (its row's tick box)
local function On() local db = ns.notepadDB; return (db and db.enabled ~= false) and true or false end
ns.Notepad_On = On
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

local function NoteName(n, idx)   -- a note's own name, or "Note N" (its position) until it is renamed
    if n and type(n.name) == "string" and n.name ~= "" then return n.name end
    return "Note " .. (idx or 1)
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
    BonusS.notepad = BonusS.notepad or {}
    local db = BonusS.notepad
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
-- What a {spell:...} token names: a spell ID, a spell name, or a pasted spell link. Returns id, name, icon (nil when the game cannot say).
local function SpellInfo(arg)
    arg = tostring(arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "" then return nil end
    local query = tonumber(arg) or tonumber(arg:match("|Hspell:(%d+)")) or tonumber(arg:match("^spell:(%d+)$"))
    if not query then query = (arg:gsub("^|c%x%x%x%x%x%x%x%x", ""):gsub("|r$", ""):gsub("^%[(.-)%]$", "%1"):gsub("^%s+", ""):gsub("%s+$", "")) end
    if query == "" then return nil end
    local id, name, icon
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, query)
        if ok and type(info) == "table" then id, name, icon = info.spellID, info.name, info.iconID end
    end
    if not id and type(query) == "number" then id = query end
    if id and not icon and C_Spell and C_Spell.GetSpellTexture then local ok, t = pcall(C_Spell.GetSpellTexture, id); if ok then icon = t end end
    if id and not name and C_Spell and C_Spell.GetSpellName then local ok, nm = pcall(C_Spell.GetSpellName, id); if ok then name = nm end end
    if not (id and name) then return nil end
    return id, name, icon
end
ns.Notepad_SpellInfo = SpellInfo
-- FA-9 (Bonus 0.6.27; Xaya 2026-11-07: "[Name] in link colour", like a spell shift-clicked into chat): the game's own spell link
-- (C_Spell.GetSpellLink, the same text a shift-click puts in chat: [Name] in the link colour). No icon. Without a link: plain [Name].
local function SpellToken(arg)
    local id, name = SpellInfo(arg)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellLink then
        local ok, link = pcall(C_Spell.GetSpellLink, id)
        if ok and type(link) == "string" and link ~= "" then return link end
    end
    return "[" .. name .. "]"
end
local function RenderLine(line)
    line = line:gsub("{spell:([^}]*)}", function(a) return SpellToken(a) or ("|cff888888{spell:" .. a .. "}|r") end)
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
local RefreshView, ApplyMode, PopulateList, BuildFormatBar     -- assigned below

-- Undo and redo (Ctrl+Z, Ctrl+Y or Ctrl+Shift+Z in the typing box). One stack per note, this session only: quick typing is one step, a pause
-- or a big paste / delete is its own step, clearing a note or restoring an older version is a step too (so Ctrl+Z brings it back).
local undo = {}
local UNDO_MAX, UNDO_GROUP = 200, 1.0
local function UndoSync(n, text)   -- the stack follows the note's text; a change that did not come from typing becomes a step
    if not n then return end
    text = text or ""
    local u = undo[n.id]
    if not u then undo[n.id] = { s = { text }, pos = 1, t = 0 }; return end
    if u.s[u.pos] ~= text then
        for i = #u.s, u.pos + 1, -1 do u.s[i] = nil end
        u.s[#u.s + 1] = text; u.pos = #u.s; u.t = 0
    end
end
local function UndoRecord(n, old, new)   -- typed change: old text -> new text
    UndoSync(n, old)
    local u = undo[n.id]
    for i = #u.s, u.pos + 1, -1 do u.s[i] = nil end   -- typing after an undo drops the redo steps
    local now = GetTime()
    local big = math.abs(#new - #old) >= BIG_DROP
    if u.pos > 1 and not big and now - u.t < UNDO_GROUP then u.s[u.pos] = new
    else u.s[#u.s + 1] = new; u.pos = #u.s end
    u.t = big and 0 or now
    if #u.s > UNDO_MAX then table.remove(u.s, 1); u.pos = u.pos - 1 end
end
local function UndoBreak() local n = Cur(); local u = n and undo[n.id]; if u then u.t = 0 end end   -- the next typing starts a new step
local function CharCount(t) local c = 0; for _ in t:gmatch("[%z\1-\127\194-\244][\128-\191]*") do c = c + 1 end; return c end
local function ChangedEnd(old, new)   -- cursor position (in characters) just after the part of `new` that differs from `old`
    local p = 0
    local m = math.min(#old, #new)
    while p < m and old:byte(p + 1) == new:byte(p + 1) do p = p + 1 end
    local q = 0
    while q < m - p and old:byte(#old - q) == new:byte(#new - q) do q = q + 1 end
    local cb = #new - q
    while cb > 0 and cb < #new and (new:byte(cb + 1) or 0) >= 128 and (new:byte(cb + 1) or 0) < 192 do cb = cb - 1 end
    return CharCount(new:sub(1, cb))
end

local function SetEditText(text)
    UndoSync(Cur(), text)
    frame.settingText = true
    frame.eb:SetText(text or "")
    frame.settingText = false
    frame.sf:SetVerticalScroll(0)
    if RefreshView then RefreshView() end
end

local function UpdateTitle()   -- fills the note-name row: the name box, its grey default ("Note N"), and the position count
    local db = DB(); if not (db and frame and frame.nr) then return end
    local n = Cur(); if not n then return end
    local idx = IndexOf(db.current) or 1
    local nr = frame.nr
    nr.count:SetText(("%d/%d"):format(idx, #db.notes))
    nr.ph:SetText("Note " .. idx)
    if not nr.edit:HasFocus() then   -- never overwrite a name that is being typed
        frame.settingName = true; nr.edit:SetText(n.name or ""); frame.settingName = nil
    end
    nr.ph:SetShown((nr.edit:GetText() or "") == "")
end

local function UndoApply(dir)   -- dir -1 = undo, +1 = redo
    local n = Cur(); if not (n and frame) then return end
    UndoSync(n, n.text)
    local u = undo[n.id]
    local np = u.pos + dir
    if np < 1 or np > #u.s then return end
    u.pos, u.t = np, 0
    local old, new = n.text or "", u.s[np]
    frame.restoring = true
    frame.eb:SetText(new)
    frame.restoring = nil
    n.text, n.modified = new, time()
    pendingAt, pendingNote = GetTime(), n
    frame.eb:SetCursorPosition(ChangedEnd(old, new))
    UpdateTitle()
    if RefreshView then RefreshView() end
end
ns.Notepad_Undo, ns.Notepad_Redo = function() UndoApply(-1) end, function() UndoApply(1) end

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
-- (D53) the Share window keeps the note it named when it opened, by its id, and sends that one
function ns.Notepad_CurrentID() local n = Cur(); return n and n.id end
function ns.Notepad_TextOf(id)   -- the note's text, or nil when no note has that id (deleted)
    if id == nil then return nil end
    local _, n = IndexOf(id)
    return n and (n.text or "") or nil
end
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
    local name = n.name
    ns.Notepad_New(n.text, true)
    local c = Cur()
    if c and name and name ~= "" then c.name = (name .. " (copy)"):sub(1, NAME_MAX); UpdateTitle(); if PopulateList then PopulateList() end end
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
    ns.Print("note deleted. The toolbar history (clock) button > Deleted notes brings it back.")
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
    Flush(); Snapshot(n)   -- Clear is undoable: the old text is in the history list
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
            -- audit D48 (Bonus 0.6.27): the Restore list opens from the settings page before the box was ever shown (no frame yet)
            if frame then SetEditText(n.text) end
            UpdateTitle(); Populate()
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
    local M, G = ns.UI_MARGIN, ns.UI_GUTTER   -- spacing from core (#351 phase 2, XayaUI/Modules.lua)
    local t = p:CreateFontString(nil, "OVERLAY"); t:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); t:SetPoint("TOPLEFT", M, -M); t:SetTextColor(1, 0.82, 0)
    t:SetText("Notepad - Restore")
    local x = CreateFrame("Button", nil, p); x:SetSize(20, 20); x:SetPoint("TOPRIGHT", -2, -2)
    x.xuiEdge = true   -- a title-bar close sits at the edge on purpose (#351)
    x.t = x:CreateFontString(nil, "OVERLAY"); x.t:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE"); x.t:SetPoint("CENTER"); x.t:SetText("x")
    x:SetScript("OnClick", function() p:Hide() end)
    local sf = CreateFrame("ScrollFrame", nil, p)
    sf:SetPoint("TOPLEFT", M, -(2 + 20 + G)); sf:SetPoint("BOTTOMRIGHT", -M, M); sf:EnableMouseWheel(true)   -- G under the close x
    local child = CreateFrame("Frame", nil, sf); child:SetSize(260, 1); sf:SetScrollChild(child)
    sf:SetScript("OnMouseWheel", function(self, d)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * ROW_H * 3)))
    end)
    p.sf, p.child = sf, child
    p:SetScript("OnShow", function() Populate() end)
    return p
end

function ns.Notepad_ToggleRestore()
    if not On() then return end
    local p = BuildPopup()
    if p:IsShown() then p:Hide(); return end
    p:ClearAllPoints()
    if frame and frame:IsShown() then p:SetPoint("TOPLEFT", frame, "TOPRIGHT", ns.UI_GUTTER, 0) else p:SetPoint("CENTER") end
    p:Show()
    Populate()
end

-------------------------------------------------------------------------------
-- toolbar
-------------------------------------------------------------------------------
-- { key, tooltip title, tooltip description, click handler }. The icons carry no words, so every button explains itself on hover.
local BUTTONS = {
    { "New",  "New note (+)",               "Creates an empty note and opens it.",                                  function() ns.Notepad_New(nil, true) end },
    { "Dup",  "Duplicate note",             "Makes a copy of this note and opens the copy.",                        function() ns.Notepad_Duplicate() end },
    { "Del",  "Delete note (trash bin)",    "Removes this note. It stays recoverable under the history button (clock).", function() ns.Notepad_Delete() end },
    { "<",    "Previous note",              "Opens the previous note in the list.",                                 function() ns.Notepad_Prev() end },
    { ">",    "Next note",                  "Opens the next note in the list.",                                     function() ns.Notepad_Next() end },
    { "Hist", "History (clock)",            "Restore an earlier version of this note, or a note you deleted.",      function() ns.Notepad_ToggleRestore() end },
    { "List", "All notes (list)",           "Shows every note at once; click one to open it. Click this again to return to your note.", function() ns.Notepad_ToggleList() end },
    { "Fmt",  "Formatting tools (underlined A)", "Turns the format bar and formatted view on or off: heading, bullet, checkbox, colors, spell icons.", function() ns.Notepad_ToggleFormat() end },
    { "More", "Menu (three lines)",         "Share this note to chat, export notes as text, or import notes.",      function(self) if ns.NotepadShare_Menu then ns.NotepadShare_Menu(self) end end },
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
        local back = math.rad(150 - 90)                                                                   -- the direction from the tip back along the arc (the arc runs clockwise from here)
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

local ICON_FILES = { New = "plus", Dup = "pages", Del = "trash", ["<"] = "left", [">"] = "right", Hist = "history", List = "list", Fmt = "format", More = "menu" }
local ICON_PX = 13   -- icon image size on a 1x toolbar; it scales with the toolbar

local function ApplyIconScale(b, u)   -- sizes the image icon and re-aims the line icons for toolbar scale u
    if b.tex then b.tex:ClearAllPoints(); b.tex:SetPoint("CENTER", b, "CENTER", 0, 0); b.tex:SetSize(ICON_PX * u, ICON_PX * u) end
    for _, p in ipairs(b.icon) do
        local c = p.c
        if p.isLine then
            p:SetThickness(c[5] * u); p:SetStartPoint("CENTER", b, c[1] * u, c[2] * u); p:SetEndPoint("CENTER", b, c[3] * u, c[4] * u)
        else
            p:SetSize(c[3] * u, c[3] * u); p:ClearAllPoints(); p:SetPoint("CENTER", b, "CENTER", c[1] * u, c[2] * u)
        end
    end
end

local function ApplyIconStyle(tb, lines)   -- image icons (default) or the simple drawn line icons
    for _, b in ipairs(tb.btns) do
        if b.tex then b.tex:SetShown(not lines) end
        for _, p in ipairs(b.icon) do p:SetShown(lines and true or false) end
    end
end

local function BuildToolbar(f)
    local tb = CreateFrame("Frame", nil, f)
    tb.xuiEdge = true   -- the toolbar is a band along one side; its icons are a segmented row (2 px seams; #351)
    tb.bg = tb:CreateTexture(nil, "BACKGROUND"); tb.bg:SetAllPoints(); tb.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    tb.btns = {}; tb.byName = {}
    for i, def in ipairs(BUTTONS) do
        local b = CreateFrame("Button", nil, tb)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(0.18, 0.18, 0.18, 0.9)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.35)
        b.icon = {}   -- the line-icon pieces (fallback style)
        b.tex = b:CreateTexture(nil, "OVERLAY")
        b.tex:SetTexture(ICON_DIR .. (ICON_FILES[def[1]] or "menu") .. ".png"); b.tex:SetVertexColor(0.92, 0.92, 0.92)
        local function L(x1, y1, x2, y2, th)
            local ln = b:CreateLine(nil, "OVERLAY")
            ln:SetColorTexture(0.92, 0.92, 0.92, 1)
            ln.isLine, ln.c = true, { x1, y1, x2, y2, th or 1.2 }
            b.icon[#b.icon + 1] = ln
        end
        local function Sq(x, y, size)
            local t = b:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(0.92, 0.92, 0.92, 1); t.c = { x, y, size }
            b.icon[#b.icon + 1] = t
        end
        if ICONS[def[1]] then ICONS[def[1]](L, Sq) end
        ApplyIconScale(b, 1)
        b:SetScript("OnClick", def[4])
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(def[2], 1, 0.82, 0); GameTooltip:AddLine(def[3], 1, 1, 1, true); GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tb.btns[i] = b; tb.byName[def[1]] = b
    end
    ApplyIconStyle(tb, false)
    tb.u = 1
    return tb
end

local function Layout()
    local db = DB(); if not (db and frame) then return end
    if db.toolbar and not frame.tb then frame.tb = BuildToolbar(frame) end   -- built the first time it is shown (V14, Bonus 0.6.12)
    local f, tb, sf = frame, frame.tb, frame.sf
    local pos = db.toolbarPos or "TOP"
    local vert = (pos == "LEFT" or pos == "RIGHT")
    local fw, fh = f:GetWidth(), f:GetHeight()
    if not fw or fw < 1 then fw = db.w or REF_W end
    if not fh or fh < 1 then fh = db.h or REF_H end
    -- The toolbar grows with the box: its buttons and icons scale from 1x (the default size, or any smaller box) up to 2x.
    local u = math.max(1, math.min(2, vert and fh / REF_H or fw / REF_W))
    f.nr:ClearAllPoints(); f.nr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -TITLE_H); f.nr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -TITLE_H)
    if tb then tb:ClearAllPoints() end
    -- #351 phase 2: the text area M from the sides (it was 6), G under the name row, the toolbar and the format bar (they were 2-4);
    -- 14 at the bottom (the resize grip's corner)
    local M, G = ns.UI_MARGIN, ns.UI_GUTTER
    local L, T, R, B = M, HDR + G, M, math.max(14, M)
    -- A top or bottom toolbar also wraps: when the box is too narrow for one row, the icons flow onto more rows and the text area gives up the room.
    local cols, tbH, tbW = #BUTTONS, TB_H, TB_W
    local bw, gap, pad, step = BTN_W * u, 2 * u, 2 * u, (TB_H - 2) * u
    if db.toolbar then
        if vert then tbW = TB_W * u
        else
            cols = math.max(1, math.floor((fw - (pos == "BOTTOM" and 16 or 0) - pad + gap) / (bw + gap)))
            tbH = math.ceil(#BUTTONS / cols) * step + pad
        end
        if pos == "TOP" then
            tb:SetPoint("TOPLEFT", 0, -HDR); tb:SetPoint("TOPRIGHT", 0, -HDR); tb:SetHeight(tbH); T = HDR + tbH + G
        elseif pos == "BOTTOM" then
            tb:SetPoint("BOTTOMLEFT", 0, 0); tb:SetPoint("BOTTOMRIGHT", -16, 0); tb:SetHeight(tbH); B = tbH + G
        elseif pos == "LEFT" then
            tb:SetPoint("TOPLEFT", 0, -HDR); tb:SetPoint("BOTTOMLEFT", 0, 0); tb:SetWidth(tbW); L = tbW + G
        else
            tb:SetPoint("TOPRIGHT", 0, -HDR); tb:SetPoint("BOTTOMRIGHT", 0, 0); tb:SetWidth(tbW); R = tbW + G
        end
        if tb.u ~= u then tb.u = u; for _, b in ipairs(tb.btns) do ApplyIconScale(b, u) end end
        for i, b in ipairs(tb.btns) do
            b:ClearAllPoints()
            if vert then b:SetSize((TB_W - 4) * u, 18 * u); b:SetPoint("TOP", tb, "TOP", 0, -(pad + (i - 1) * 20 * u))
            else
                local r, c = math.floor((i - 1) / cols), (i - 1) % cols
                b:SetSize(bw, (TB_H - 4) * u); b:SetPoint("TOPLEFT", tb, "TOPLEFT", pad + c * (bw + gap), -(pad + r * step))
            end
        end
        ApplyIconStyle(tb, db.iconLines)
    end
    if tb then tb:SetShown(db.toolbar and true or false) end
    local fb = f.fb
    if fb then
        fb:ClearAllPoints()
        if db.format and not mode.list then
            fb:SetPoint("TOPLEFT", f, "TOPLEFT", L, -T); fb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -R, -T); fb:SetHeight(FB_H)
            T = T + FB_H + G
        end
    end
    for _, area in ipairs({ sf, f.vf, f.lf }) do   -- typing area, formatted view, and note list share one spot
        area:ClearAllPoints(); area:SetPoint("TOPLEFT", f, "TOPLEFT", L, -T); area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -R, B)
    end
    local minW = vert and math.max(150, tbW + 100) or math.max(150, db.format and FMT_MINW or 0)
    f.minW = minW
    local minH = (vert and db.toolbar) and (#BUTTONS * 20 + HDR + 8) or 90   -- a side toolbar stacks its buttons
    if db.toolbar and not vert then   -- keep about 30 pixels of typing room under a toolbar that has wrapped to several rows
        minH = math.max(minH, HDR + tbH + 3 + (db.format and FB_H + 2 or 0) + 14 + 30)
    end
    f.minH = minH
    if f.SetResizeBounds then f:SetResizeBounds(minW, minH, 900, 900) end
    if f.GetHeight and f:GetHeight() < minH then f:SetHeight(minH) end   -- narrowing the box can add a toolbar row; make room for it
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
        out[i] = { id = n.id, index = i, name = NoteName(n, i), text = Preview(n.text, 60), modified = n.modified, chars = #(n.text or ""), current = (n.id == db.current) }
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
        GameTooltip:SetText(NoteName(n, self.idx), 1, 0.82, 0)
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
        b.fs:SetText(("|cffffd100%s|r  |cff999999%s|r"):format(e.name:gsub("|", "||"), e.text))
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
    if db.format and not f.fb then f.fb = BuildFormatBar(f) end   -- built the first time "Formatting tools" is on (V14, Bonus 0.6.12)
    Layout()
    f.sf:SetShown(not list and not view)
    f.vf:SetShown(view)
    f.lf:SetShown(list)
    if f.fb then f.fb:SetShown(db.format and not list and true or false) end
    if list or view then f.eb:ClearFocus() end
    if list then PopulateList() end
    if view then RefreshView() end
    if f.fb then f.fb.btns[1].fs:SetText(view and "Edit" or "View") end
    local function Tint(b, on) if b then b.bg:SetColorTexture(on and 0.1 or 0.18, on and 0.45 or 0.18, on and 0.7 or 0.18, 0.9) end end
    if f.tb then Tint(f.tb.byName.List, list); Tint(f.tb.byName.Fmt, db.format) end
    if f.fb then Tint(f.fb.btns[1], view) end
end

function ns.Notepad_ToggleList()
    if not frame or not On() then return end
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
-- UI-59 (Bonus 0.6.20): the game's EditBox:Insert replaces highlighted text, and the API has no way to read the highlighted
-- range (docs/reference/api: HighlightText / ClearHighlightText only). So Wrap lets Insert put `open` in place of the
-- selection, works out from the text before and after what it replaced, and puts that text back between open and close.
-- With nothing highlighted it is the old insert: open + close at the cursor, cursor between them.
local function Wrap(open, close, lineStart)
    local db = DB(); if not (db and frame and db.format) then return end
    ToEdit()
    local eb = frame.eb
    UndoBreak()
    eb:SetFocus()
    local before = eb:GetText() or ""
    if #before + #open + #close + 1 > MAX_CHARS then   -- the edit box would cut the end off: change nothing
        if ns.Print then ns.Print("Notepad: this note is full, so the format button did nothing.") end
        return
    end
    eb:Insert(open)
    local after = eb:GetText() or ""
    local L = #before - #after + #open                 -- bytes the insert replaced (the highlighted text)
    local p = 0
    while p < #before and p < #after and before:byte(p + 1) == after:byte(p + 1) do p = p + 1 end
    local s
    if L >= 0 then
        for i = p, 0, -1 do
            if after:sub(i + 1, i + #open) == open and after:sub(i + #open + 1) == before:sub(i + L + 1) then s = i; break end
        end
    end
    if not s then   -- could not tell what was replaced: put the note back exactly as it was
        frame.eb:SetText(before)
        if ns.Print then ns.Print("Notepad: could not apply the format, the note was left unchanged.") end
        return
    end
    local sel = before:sub(s + 1, s + L)
    local nl = (lineStart and s > 0 and before:sub(s, s) ~= "\n") and "\n" or ""
    if L == 0 and nl == "" then   -- nothing highlighted: the old behaviour
        eb:Insert(close)
        if #close > 0 then eb:SetCursorPosition(math.max(0, eb:GetCursorPosition() - CharCount(close))) end
        return
    end
    local head = before:sub(1, s) .. nl .. open .. sel .. close
    local text = head .. before:sub(s + L + 1)
    eb:SetText(text)                                   -- fires OnTextChanged: the note and the undo steps follow it
    eb:SetCursorPosition(L == 0 and (CharCount(head) - CharCount(close)) or CharCount(head))
end
local function Ins(text, back)   -- kept for callers that insert one piece: back = characters to step back into it
    back = back or 0
    local cut = #text - back
    Wrap(text:sub(1, cut), text:sub(cut + 1))
end
local function LineStart(prefix) Wrap(prefix, "", true) end
ns.Notepad_LineStart, ns.Notepad_Insert = LineStart, Ins

-- Hovers (UI-65, Xaya 2026-11-07: "briefer, more direct, more user-legible tooltips"): a title plus at most two plain sentences.
local FMT = {
    { w = 34, label = "View", title = "View / Edit", tip = "Switches between typing and the formatted view.", act = function() ns.Notepad_SetView(not mode.view) end },
    { w = 24, label = "H", title = "Heading", tip = "Starts the line with # (gold in the formatted view). Highlighted text is kept.", act = function() LineStart("# ") end },
    { w = 24, label = "|cff99ccff-|r", title = "Bullet", tip = "Starts the line with - (a bullet in the formatted view). Highlighted text is kept.", act = function() LineStart("- ") end },
    { w = 24, label = "[ ]", title = "Checkbox", tip = "Starts the line with [ ]. Change it to [x] when done.", act = function() LineStart("[ ] ") end },
    { w = 24, label = "|cffff5555R|r", title = "Red text", tip = "Turns the highlighted text red. With nothing highlighted, type between the color code and ||r.", act = function() Wrap("|cffff5555", "|r") end },
    { w = 24, label = "|cffffd100Y|r", title = "Yellow text", tip = "Turns the highlighted text yellow. With nothing highlighted, type between the color code and ||r.", act = function() Wrap("|cffffd100", "|r") end },
    { w = 24, label = "|cff55dd55G|r", title = "Green text", tip = "Turns the highlighted text green. With nothing highlighted, type between the color code and ||r.", act = function() Wrap("|cff55dd55", "|r") end },
    { w = 24, label = "|cff66b3ffB|r", title = "Blue text", tip = "Turns the highlighted text blue. With nothing highlighted, type between the color code and ||r.", act = function() Wrap("|cff66b3ff", "|r") end },
    { w = 34, label = "Spell", title = "Spell link", tip = "Turns the highlighted spell name into a spell link. With nothing highlighted, type a spell ID, name or link between the braces.", act = function() Wrap("{spell:", "}") end },
}

BuildFormatBar = function(f)
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
        b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(def.title, 1, 0.82, 0); GameTooltip:AddLine(def.tip, 1, 1, 1, true); GameTooltip:Show() end)
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
    bar.xuiEdge = true   -- the title bar spans the window (#351)
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

    f.title = bar:CreateFontString(nil, "OVERLAY")   -- the bar is the notepad's own: centered name, Lock and x at the right
    f.title:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    f.title:SetPoint("CENTER", bar, "CENTER", 0, 0); f.title:SetText("Notepad"); f.title:SetTextColor(1, 0.82, 0)

    -- Name row under the bar: the note's title. It reads as an input box (pencil icon, border, grey default name) so it is clear it can be renamed.
    local nr = CreateFrame("Frame", nil, f); nr:SetHeight(NAME_H)
    nr.bg = nr:CreateTexture(nil, "BACKGROUND"); nr.bg:SetAllPoints(); nr.bg:SetColorTexture(0.09, 0.09, 0.09, 0.95)
    nr.xuiEdge = true   -- a band across the window, like the title bar (#351: its contents keep M from its sides)
    nr.count = nr:CreateFontString(nil, "OVERLAY"); nr.count:SetFont(STANDARD_TEXT_FONT, 10, ""); nr.count:SetPoint("RIGHT", -ns.UI_MARGIN, 0); nr.count:SetTextColor(0.55, 0.55, 0.55)
    local box = CreateFrame("Frame", nil, nr, "BackdropTemplate")
    box:SetPoint("LEFT", ns.UI_MARGIN, 0); box:SetPoint("RIGHT", nr.count, "LEFT", -ns.UI_GUTTER, 0); box:SetHeight(NAME_H - 6)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    box:SetBackdropColor(0.02, 0.02, 0.02, 0.9); box:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    local pen = box:CreateTexture(nil, "OVERLAY"); pen:SetTexture(ICON_DIR .. "pencil.png"); pen:SetSize(12, 12); pen:SetPoint("LEFT", 4, 0); pen:SetVertexColor(0.7, 0.7, 0.7)
    local ne = CreateFrame("EditBox", nil, box)
    ne:SetAllPoints(box); ne:SetAutoFocus(false); ne:SetMaxLetters(NAME_MAX); ne:SetTextInsets(21, 4, 0, 0)
    ne:SetFont(STANDARD_TEXT_FONT, 12, ""); ne:SetTextColor(1, 0.82, 0)
    local ph = box:CreateFontString(nil, "OVERLAY"); ph:SetFont(STANDARD_TEXT_FONT, 12, ""); ph:SetPoint("LEFT", box, "LEFT", 21, 0); ph:SetTextColor(0.55, 0.55, 0.55)
    ne:SetScript("OnTextChanged", function(self, user)
        ph:SetShown((self:GetText() or "") == "")
        if user and not f.settingName then local n = Cur(); if n then n.name = self:GetText() end end
    end)
    ne:SetScript("OnEditFocusGained", function(self)
        local n = Cur(); self.orig = n and n.name or ""
        box:SetBackdropBorderColor(0.2, 0.7, 1, 1); pen:SetVertexColor(0.2, 0.7, 1); self:HighlightText()
    end)
    ne:SetScript("OnEditFocusLost", function(self)
        box:SetBackdropBorderColor(0.4, 0.4, 0.4, 1); pen:SetVertexColor(0.7, 0.7, 0.7); self:HighlightText(0, 0)
        local n = Cur()
        if n then local t = (n.name or ""):match("^%s*(.-)%s*$"); n.name = (t ~= "") and t or nil end
        UpdateTitle(); if PopulateList then PopulateList() end
    end)
    ne:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    ne:SetScript("OnEscapePressed", function(self)   -- cancel: back to the name it had when you started
        local n = Cur(); if n then n.name = (self.orig ~= "") and self.orig or nil end
        f.settingName = true; self:SetText(self.orig or ""); f.settingName = nil
        self:ClearFocus()
    end)
    ne:SetScript("OnEnter", function(self)
        local db = DB(); local idx = db and IndexOf(db.current) or 1
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText("Rename this note", 1, 0.82, 0)
        GameTooltip:AddLine("Click the name, type your own, and press Enter. Esc cancels. Leave it empty to go back to \"Note " .. idx .. "\".", 1, 1, 1, true); GameTooltip:Show()
    end)
    ne:SetScript("OnLeave", function() GameTooltip:Hide() end)
    nr.edit, nr.ph, nr.box = ne, ph, box
    f.nr = nr

    -- the toolbar (f.tb) and the format bar (f.fb) are built the first time they are shown (Layout, ApplyMode; V14, Bonus 0.6.12)

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
    eb:SetScript("OnKeyDown", function(_, key)
        if IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown()) then
            if key == "Z" then UndoApply(IsShiftKeyDown() and 1 or -1)
            elseif key == "Y" then UndoApply(1) end
        end
    end)
    eb:SetScript("OnTextChanged", function(self)
        if f.settingText or f.restoring then return end
        local n = Cur(); if not n then return end
        local new, old = self:GetText(), n.text or ""
        if new ~= old then UndoRecord(n, old, new) end
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

    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(14, 14); grip:SetPoint("BOTTOMRIGHT", -1, 1)
    grip.xuiEdge = true   -- a corner resize grip (#351)
    grip.t = grip:CreateTexture(nil, "OVERLAY"); grip.t:SetAllPoints(); grip.t:SetColorTexture(0.2, 0.7, 1, 0.7)
    grip:SetScript("OnMouseDown", function() local db = DB(); if db and not db.locked then f:StartSizing("BOTTOMRIGHT"); f.sizing = true end end)
    grip:SetScript("OnMouseUp", function() if f.sizing then f.sizing = false; f:StopMovingOrSizing(); SavePosition(f) end end)
    f.grip = grip
    f:SetScript("OnSizeChanged", function(self, w)   -- re-flow the toolbar icons when the width changes
        if w and w ~= self.lastLayoutW then self.lastLayoutW = w; Layout() end
    end)

    -- timer: saves a version after a pause in typing; hover-reveals the toolbar
    local acc = 0
    f:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.2 then return end
        acc = 0
        if pendingAt and GetTime() - pendingAt >= IDLE_SECS then Flush(); Populate() end
        local db = DB()
        if db and db.toolbar and f.tb then
            local show = (not db.toolbarHover) or f:IsMouseOver() or f.eb:HasFocus() or f.nr.edit:HasFocus() or (popup and popup:IsShown() and popup:IsMouseOver())
            f.tb:SetAlpha(show and 1 or 0)
        end
    end)
    return f
end

-------------------------------------------------------------------------------
-- refresh
-------------------------------------------------------------------------------
-- V14 "off costs nothing" (Bonus 0.6.12; Xaya 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD
-- or contribute to performance cost / demand in any way"). "Show Notepad" off: the box is not built (it is built the first time it is
-- shown) and its combat / logout events are not registered; closed after it was open, it is hidden and the events are let go. Up to
-- 0.6.11 the whole box (about 34 frames) was built at login while hidden, and every combat start and end restyled it.
local ev
local function OnEvent(_, e)
    local db = DB(); if not db or not frame then return end
    if e == "PLAYER_LOGOUT" then Flush(); return end
    if e == "PLAYER_REGEN_DISABLED" and db.dropFocusInCombat and (frame.eb:HasFocus() or frame.nr.edit:HasFocus()) then frame.eb:ClearFocus(); frame.nr.edit:ClearFocus() end
    ns.Notepad_Refresh()
end
local function WatchEvents(on)
    if on then
        if not ev then ev = CreateFrame("Frame"); ev:SetScript("OnEvent", OnEvent) end
        ev:RegisterEvent("PLAYER_REGEN_DISABLED")
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        ev:RegisterEvent("PLAYER_LOGOUT")
    elseif ev then
        ev:UnregisterAllEvents()
    end
end

function ns.Notepad_Refresh()
    local db = DB(); if not db then return end
    -- (Bonus 0.6.14, V14) the Notepad switched off: its box and its Restore list are hidden, its events let go, nothing more runs
    local show = On() and db.shown and true or false
    WatchEvents(show)
    if not show then
        if frame then frame:Hide() end
        if not On() and popup then popup:Hide() end
        return
    end
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
    if not db.toolbarHover and f.tb then f.tb:SetAlpha(1) end

    local hide = db.hideInCombat and InCombat()
    f:SetShown((db.shown and not hide) and true or false)
end

function ns.Notepad_SetShown(v)
    local db = DB(); if not db or not On() then return end
    db.shown = v and true or false
    if not db.shown then Flush() end
    ns.Notepad_Refresh()
    if ns.Notepad_Changed then ns.Notepad_Changed() end
end

function ns.Notepad_Toggle()
    local db = DB(); if not db then ns.Print("Notepad is not ready yet."); return end
    if not On() then ns.Print("Notepad is off: tick it in Bonus Features > Utilities > Notepad."); return end
    ns.Notepad_SetShown(not db.shown)
    if db.shown and frame and not mode.list and not mode.view then frame.eb:SetFocus() end
end

-- (Bonus 0.6.14; Xaya 2026-11-06, about the Notepad's tick box: "It should only enable or disable notepad functionality in its
-- entirety") on / off for the whole feature: off hides the box and every window of it, lets go of its events and of shared notes
-- (NotepadShare_Sync), and nothing of it is built until it is on again (V14). Its notes are kept.
function ns.Notepad_SetEnabled(v)
    local db = DB(); if not db then return end
    db.enabled = v and true or false
    if not db.enabled then Flush() end
    ns.Notepad_Refresh()
    if ns.NotepadShare_Sync then ns.NotepadShare_Sync() end
    if ns.Utilities_SyncSlash then ns.Utilities_SyncSlash() end   -- (Bonus 0.6.17) /notes, only once it is on (Utilities.lua)
    if ns.Notepad_Changed then ns.Notepad_Changed() end
end

-------------------------------------------------------------------------------
-- options page: Bonus Features > Utilities > "Notepad" (a part of the Utilities node since Bonus 0.6.11: Utilities.lua)
-- The tick box on this page's row in the left pane (xuiSwitch; Xaya 2026-11-05: "move all enable/disable toggles onto the sidebar
-- instead") turns the Notepad on or off as a whole (Bonus 0.6.14); "Show Notepad" (the box shown or not) is back on the page, as it was
-- before Bonus 0.6.11. While the Notepad is off every control of the page is greyed out (nothing of it may be opened or run).
-------------------------------------------------------------------------------
function ns.BuildNotepadTab(Notify)
    local db = DB()
    if not db then return nil end
    ns.Notepad_Changed = function() if Notify then Notify() end end
    local function g(k) return function() return db[k] end end
    local function s(k) return function(_, v) db[k] = v; ns.Notepad_Refresh() end end
    local function off() return db.enabled == false end
    return { type = "group", name = "Notepad", order = 11,
      xuiSwitch = { type = "toggle", name = "Notepad", tip = "A small floating notepad for your notes.",
          desc = "Turns the Notepad on or off as a whole. Off: no box, no list or Restore window, no sharing, and nothing of it is built or runs; your notes are kept.",
          get = function() return db.enabled ~= false end, set = function(_, v) ns.Notepad_SetEnabled(v) end },
      args = {
        n = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "A small floating box for typed reminders. It holds any number of notes, and nothing you type is lost: your text is saved as you type, earlier versions of each note are kept automatically, and deleted notes go to a trash. The history (clock) button on the toolbar (or the button below) opens the Restore list, and the list button shows all your notes at once. Turn the Notepad on or off with the tick box next to it on the left; open or close the box with Show Notepad below, the x on it, or /xui notepad." },
        show = { type = "toggle", order = 1, name = "Show Notepad", desc = "Opens or closes the notepad box (also the x on the box, and /xui notepad).",
            get = g("shown"), set = function(_, v) ns.Notepad_SetShown(v) end, disabled = off },
        lock = { type = "toggle", order = 2, name = "Lock position and size", desc = "Also the Lock button on the box's title bar.", get = g("locked"), set = s("locked"), disabled = off },
        fmt = { type = "toggle", order = 2.5, disabled = off, name = "Formatting tools", desc = "Adds a format bar (heading, bullet, checkbox, colors, spell icon), a formatted view and the underlined-A toolbar button. Notes stay plain text: the formatting is markup you can read and edit.",
            get = g("format"), set = function(_, v) db.format = v and true or false; if not db.format then mode.view = false end; ns.Notepad_Refresh() end },
        list = { type = "execute", order = 2.6, name = "Show / hide the list of all notes", desc = "Also the list button on the toolbar.", func = function() ns.Notepad_ToggleList() end, disabled = off },
        restore = { type = "execute", order = 3, name = "Open Restore list", desc = "Earlier versions of the current note, and deleted notes.", func = function() ns.Notepad_ToggleRestore() end, disabled = off },
        share = { type = "group", name = "Share, export, and import", order = 3.5, inline = true, disabled = off, args = {
            note = { type = "description", order = 0, width = "full", name = "The menu (three lines) button on the toolbar shares the current note to chat for other XayaUI users, or exports and imports notes as text you can copy and paste." },
            accept = { type = "toggle", order = 1, name = "Accept notes shared by other XayaUI users", width = "double",
                desc = "A shared note never saves by itself: a small window offers it and you choose Save or Dismiss. Off, nothing listens for shared notes (the game keeps the message name registered until you /reload, unused).",
                get = g("acceptShares"), set = function(_, v) db.acceptShares = v; if ns.NotepadShare_Sync then ns.NotepadShare_Sync() end end },
            share = { type = "execute", order = 2, name = "Share this note...", func = function() if ns.NotepadShare_OpenShare then ns.NotepadShare_OpenShare() end end },
            exp = { type = "execute", order = 3, name = "Export notes...", func = function() if ns.NotepadShare_OpenIO then ns.NotepadShare_OpenIO("all") end end },
            imp = { type = "execute", order = 4, name = "Import notes...", func = function() if ns.NotepadShare_OpenIO then ns.NotepadShare_OpenIO("import") end end },
        } },
        tbar = { type = "group", name = "Toolbar", order = 4, inline = true, disabled = off, args = {
            on = { type = "toggle", order = 1, name = "Show toolbar", desc = "New, duplicate, delete, previous, next, history/restore, list, formatting, and share / import / export (More) buttons.", get = g("toolbar"), set = s("toolbar") },
            hover = { type = "toggle", order = 2, name = "Only show on mouseover", desc = "The toolbar stays hidden until the mouse is over the box (or you are typing in it). Its space stays reserved so the text does not jump.",
                disabled = function() return off() or not db.toolbar end, get = g("toolbarHover"), set = s("toolbarHover") },
            pos = { type = "select", order = 3, name = "Toolbar position", disabled = function() return off() or not db.toolbar end,
                values = { TOP = "Top", BOTTOM = "Bottom", LEFT = "Left", RIGHT = "Right" }, sorting = { "TOP", "BOTTOM", "LEFT", "RIGHT" },
                get = g("toolbarPos"), set = s("toolbarPos") },
            lines = { type = "toggle", order = 3.5, name = "Use simple line icons", width = "double",
                desc = "Draws the toolbar icons as plain lines instead of using the icon images. Try this if the image icons do not show.",
                disabled = function() return off() or not db.toolbar end, get = g("iconLines"), set = s("iconLines") },
        } },
        hist = { type = "group", name = "Versions", order = 5, inline = true, disabled = off, args = {
            max = { type = "range", order = 1, name = "Earlier versions kept per note", desc = "A version is saved when you pause typing, and always right before a large amount of text is removed. Oldest versions drop off first.",
                min = 5, max = 50, step = 1, get = g("maxHistory"), set = function(_, v) db.maxHistory = v end },
        } },
        combat = { type = "group", name = "Combat", order = 6, inline = true, disabled = off, args = {
            hide = { type = "toggle", order = 1, name = "Hide in combat", get = g("hideInCombat"), set = s("hideInCombat") },
            drop = { type = "toggle", order = 2, name = "Release the keyboard when combat starts",
                desc = "While you are typing in the box, your keybinds do not work. With this on, entering combat takes the cursor out of the box so they do.",
                get = g("dropFocusInCombat"), set = s("dropFocusInCombat") },
        } },
        look = { type = "group", name = "Look", order = 7, inline = true, disabled = off, args = {
            font = { type = "select", order = 1, name = "Font",
                values = function() local v = ns.FontList(); return v end, sorting = function() local _, o = ns.FontList(); return o end,
                get = g("font"), set = s("font") },
            size = { type = "range", order = 2, name = "Font Size", min = 8, max = 40, step = 1, get = g("fontSize"), set = s("fontSize") },
            alpha = { type = "range", order = 3, name = "Backdrop opacity (%)", min = 0, max = 100, step = 1, get = g("bgAlpha"), set = s("bgAlpha") },
            strata = { type = "select", order = 4, name = "Frame strata",
                values = { BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium", HIGH = "High", DIALOG = "Dialog" },
                sorting = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }, get = g("strata"), set = s("strata") },
        } },
        reset = { type = "group", name = "Reset", order = 8, inline = true, disabled = off, args = {
            pos = { type = "execute", order = 1, name = "Reset position and size",
                func = function() db.anchor, db.x, db.y, db.w, db.h = "CENTER", 300, 0, 280, 220; ns.Notepad_Refresh() end },
            clear = { type = "execute", order = 2, name = "Clear the current note", confirm = true, confirmText = "Clear the text of the current note? The old text stays in its version list (the history button).",
                func = function() ns.Notepad_Clear() end },
        } },
    } }
end

function ns.Notepad_OpenSettings()
    ns.OpenSettingsPage("bonus", "utilities", "notepad")   -- Bonus Features > Utilities > Notepad (Bonus 0.6.11)
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
ns.WhenSettingsReady("bonus", ns.Notepad_OnDBReady)   -- (P5: once XayaUIBonusDB is open, at this addon's ADDON_LOADED; Modules.lua section 0c)
ns.RegisterCommand({ "notes", "notepad", "note" }, function() ns.Notepad_Toggle() end, "/xui notes (show / hide the notepad)")
-- O-100 (Bonus 0.6.27; Xaya: "calculator isn't "off" -- it's just not displayed. same with stat calculator and notes", her answer "No
-- word at all"): no state text; the row exists only while the Notepad is on, and a click shows / hides the box.
ns.RegisterLauncher({ "notes", "Notes", "Show or hide the notepad (also /xui notes)", function() ns.Notepad_Toggle() end,
    nil, order = 10,
    available = function() return On() end })   -- (Bonus 0.6.14) no row while the Notepad is off (core 0.6.49: available())
-- its settings page is a part of Bonus Features > Utilities (registered by Utilities.lua, Bonus 0.6.11), not a page of its own
-- (Bonus 0.6.27) the Notepad's service for XayaUI Dev Assist's QA walkthroughs (QAWalks-audit.lua), through XayaUI's service list
-- (Modules.lua ns.Provide / ns.Service), so Dev Assist never calls this addon by name. Nothing here runs until a walkthrough asks.
if ns.Provide then
    ns.Provide("notepadDebug", {
        DB = function() return ns.notepadDB end, On = function() return On() end, Frame = function() return frame end,
        SetShown = ns.Notepad_SetShown, ToggleFormat = ns.Notepad_ToggleFormat, New = ns.Notepad_New, Delete = ns.Notepad_Delete,
        Next = ns.Notepad_Next, SetView = ns.Notepad_SetView, Render = ns.Notepad_Render, CurrentText = ns.Notepad_CurrentText,
        -- (audit QA walkthroughs, D53) the Share window: open it, read the note it will send, and what it sent
        OpenShare = function() if ns.NotepadShare_OpenShare then ns.NotepadShare_OpenShare() end end,
        ShareNoteText = function() return ns.NotepadShare_ShareText and ns.NotepadShare_ShareText() end,
        Prev = ns.Notepad_Prev,
    })
end
