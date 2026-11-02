-------------------------------------------------------------------------------
-- Notepad.lua : QoL "Notepad" - a floating, movable, resizable box you can type reminders into.
--   * Notes (memos): any number of notes; the toolbar adds, duplicates, deletes, and flips between them.
--   * Nothing typed is lost: the text is saved as you type, and earlier versions of each note are kept automatically (a new
--     version after a pause in typing, and always right before a big chunk of text disappears). Deleted notes go to a trash.
--     Toolbar "Hist" (or the options page) opens the Restore list: earlier versions of this note + deleted notes.
--   * Toolbar: at the top, bottom, left, or right of the box; always visible, or only while the mouse is over the box.
--   * Open / close: /xui notepad, the x on the box, or QoL UI Updates > Notepad. Whether it is open is remembered.
--   * Drag the title bar to move, drag the bottom-right corner to resize. "Lock" stops both.
-- Own code, written against Blizzard's frame API only (no other addon's code or data). UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local TITLE_H = 20
local TB_H, TB_W, BTN_W = 20, 38, 32   -- toolbar thickness (horizontal), width (vertical), button width (horizontal)
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

local function SetEditText(text)
    frame.settingText = true
    frame.eb:SetText(text or "")
    frame.settingText = false
    frame.sf:SetVerticalScroll(0)
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
end

function ns.Notepad_New(text, after)
    local db = DB(); if not db then return end
    Flush()
    local n = NewNoteTable(text)
    local at = after and ((IndexOf(db.current) or #db.notes) + 1) or (#db.notes + 1)
    table.insert(db.notes, at, n)
    Select(n.id)
    if frame and frame:IsShown() and not text then frame.eb:SetFocus() end
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
}

local function BuildToolbar(f)
    local tb = CreateFrame("Frame", nil, f)
    tb.bg = tb:CreateTexture(nil, "BACKGROUND"); tb.bg:SetAllPoints(); tb.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    tb.btns = {}
    for i, def in ipairs(BUTTONS) do
        local b = CreateFrame("Button", nil, tb)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(0.18, 0.18, 0.18, 0.9)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.35)
        b.fs = b:CreateFontString(nil, "OVERLAY"); b.fs:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE"); b.fs:SetPoint("CENTER"); b.fs:SetText(def[1])
        b:SetScript("OnClick", def[3])
        b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(def[2]); GameTooltip:Show() end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tb.btns[i] = b
    end
    return tb
end

local function Layout()
    local db = DB(); if not (db and frame) then return end
    local f, tb, sf = frame, frame.tb, frame.sf
    local pos = db.toolbarPos or "TOP"
    local vert = (pos == "LEFT" or pos == "RIGHT")
    tb:ClearAllPoints(); sf:ClearAllPoints()
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
    sf:SetPoint("TOPLEFT", L, -T); sf:SetPoint("BOTTOMRIGHT", -R, B)
    if f.SetResizeBounds then f:SetResizeBounds(vert and 150 or (db.toolbar and 6 * (BTN_W + 2) + 6 or 140), 90, 900, 900) end
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
        f:SetSize(math.max(150, db.w or 280), math.max(90, db.h or 220))
    end

    local path = ns.FontPath and ns.FontPath(db.font) or STANDARD_TEXT_FONT
    local size = math.max(8, math.min(40, tonumber(db.fontSize) or 13))
    if not f.eb:SetFont(path, size, "") then f.eb:SetFont(STANDARD_TEXT_FONT, size, "") end
    local n = Cur()
    if n and f.eb:GetText() ~= (n.text or "") then SetEditText(n.text) end
    UpdateTitle()
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
    if db.shown and frame then frame.eb:SetFocus() end
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
            name = "A small floating box for typed reminders. It holds any number of notes, and nothing you type is lost: your text is saved as you type, earlier versions of each note are kept automatically, and deleted notes go to a trash. The Hist button on the toolbar (or the button below) opens the Restore list. Open or close the box here, with the x on it, or with /xui notepad." },
        show = { type = "toggle", order = 1, name = "Show Notepad", get = g("shown"), set = function(_, v) ns.Notepad_SetShown(v) end },
        lock = { type = "toggle", order = 2, name = "Lock position and size", desc = "Also the Lock button on the box's title bar.", get = g("locked"), set = s("locked") },
        restore = { type = "execute", order = 3, name = "Open Restore list", desc = "Earlier versions of the current note, and deleted notes.", func = function() ns.Notepad_ToggleRestore() end },
        tbar = { type = "group", name = "Toolbar", order = 4, inline = true, args = {
            on = { type = "toggle", order = 1, name = "Show toolbar", desc = "New, duplicate, delete, previous, next, and history/restore buttons.", get = g("toolbar"), set = s("toolbar") },
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
