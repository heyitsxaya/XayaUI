-- XayaUI: Console window, copy box and bug report.
--  * ns.ShowCopyBox(title, text): a small window with the text selected, ready for Ctrl+C.
--  * The console window: the same event log as the strip under the options window, but in its own movable, resizable window that keeps
--    collecting lines while the options window is closed and during combat (the log buffer lives in Core.lua and never depends on the window).
--  * The error log: XayaUI's own Lua errors are kept (de-duplicated, saved between sessions) so they can be shared.
--  * The bug report: version, game build, recent errors and console lines as plain text, with no character name, realm, or rule contents.
-- Opened with /xui console and /xui bug, and from Settings > Debugging. Not run in game when written (2026-11-01).
local addonName, ns = ...

local MAX_ERRORS = 40

local function Plain(s)
    s = tostring(s or "")
    s = s:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return s
end
ns.PlainText = Plain

local function Ui()
    if not CueRulesDB then return {} end
    CueRulesDB.ui = CueRulesDB.ui or {}
    return CueRulesDB.ui
end

-------------------------------------------------------------------------------
-- Copy box
-------------------------------------------------------------------------------
local copyBox
function ns.ShowCopyBox(title, text)
    if not copyBox then
        local f = CreateFrame("Frame", "XayaUICopyBox", UIParent, "BackdropTemplate")
        f:SetSize(620, 420)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.06, 0.06, 0.07, 0.97)
        f:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOPLEFT", 12, -10)
        f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.hint:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
        f.hint:SetText("The text is selected. Press Ctrl+C to copy it, then Esc to close.")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        local sf = CreateFrame("ScrollFrame", "XayaUICopyBoxScroll", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 12, -50); sf:SetPoint("BOTTOMRIGHT", -32, 44)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(560); eb:SetMaxLetters(0)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.eb = eb
        local sel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        sel:SetSize(110, 24); sel:SetPoint("BOTTOMLEFT", 12, 12); sel:SetText("Select all")
        sel:SetScript("OnClick", function() eb:SetFocus(); eb:HighlightText() end)
        if ns.FlatButton then ns.FlatButton(sel) end
        tinsert(UISpecialFrames, "XayaUICopyBox")
        copyBox = f
    end
    copyBox.title:SetText(title or "Copy")
    copyBox.eb:SetText(text or "")
    copyBox:Show()
    copyBox.eb:SetFocus()
    copyBox.eb:HighlightText()
end

-- every line of the event log as plain text (the strip under the options window and the console window both show this buffer)
function ns.ConsoleText()
    local out = {}
    for _, line in ipairs(ns.logBuf or {}) do out[#out + 1] = Plain(line) end
    return table.concat(out, "\n")
end
function ns.CopyConsole()
    local t = ns.ConsoleText()
    if t == "" then t = "(the console has no lines yet)" end
    ns.ShowCopyBox("XayaUI console", t)
end

-------------------------------------------------------------------------------
-- Error log (saved between sessions, de-duplicated)
-------------------------------------------------------------------------------
local function ErrList()
    if not CueRulesDB then return {} end
    CueRulesDB.errorLog = CueRulesDB.errorLog or {}
    return CueRulesDB.errorLog
end
local function AddonVersion()
    local f = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(f, addonName, "Version")
    return (ok and v) or "?"
end
-- Called from the error handler in Core.lua for errors that mention XayaUI. Must never raise an error itself.
function ns.CaptureError(msg, stack)
    if not CueRulesDB then return end
    local text = Plain(msg):sub(1, 700)
    local list = ErrList()
    local combat = (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false
    for _, e in ipairs(list) do
        if e.msg == text then e.n = (e.n or 1) + 1; e.last = time(); e.combat = e.combat or combat; return end
    end
    table.insert(list, 1, { msg = text, stack = Plain(stack or ""):sub(1, 900), first = time(), last = time(), n = 1, ver = AddonVersion(), combat = combat or nil })
    while #list > MAX_ERRORS do table.remove(list) end
    if ns.Log then pcall(ns.Log, "|cffff5555Lua error captured|r (see Settings > Debugging > Bug report): " .. text:sub(1, 120)) end
end
function ns.ErrorCount() local n = 0; for _, e in ipairs(ErrList()) do n = n + (e.n or 1) end return n, #ErrList() end
function ns.ClearErrorLog() if CueRulesDB then CueRulesDB.errorLog = {} end end

-------------------------------------------------------------------------------
-- Bug report
-------------------------------------------------------------------------------
function ns.BuildBugReport(description, includeAddons)
    local L = {}
    local function add(s) L[#L + 1] = s end
    local gv, gb, gd, toc = "?", "?", "?", "?"
    if GetBuildInfo then gv, gb, gd, toc = GetBuildInfo() end
    add("XayaUI bug report")
    add(("XayaUI version: %s | game %s (build %s, %s, interface %s)"):format(AddonVersion(), tostring(gv), tostring(gb), tostring(gd), tostring(toc)))
    add(("Report made: %s (local time)"):format(date("%Y-%m-%d %H:%M:%S")))
    local spec = ns.CurrentSpecID and ns.CurrentSpecID() or nil
    add(("Spec ID: %s | in combat: %s | locale: %s"):format(tostring(spec), tostring((UnitAffectingCombat and UnitAffectingCombat("player")) and true or false), tostring(GetLocale and GetLocale() or "?")))
    local nr, nc, ncond = 0, 0, 0
    for _, r in ipairs(ns.rules or {}) do
        if r.isCue then nc = nc + 1 elseif r.parentUid then ncond = ncond + 1 else nr = nr + 1 end
    end
    add(("Rules: %d | cues: %d | conditions: %d | skin on: %s"):format(nr, nc, ncond, (ns.Options and tostring(ns.Options.SkinOn()) or "window not loaded")))
    add("(No character name, realm, or rule contents are included.)")
    add("")
    add("What happened:")
    add((description and description:match("%S")) and description or "(not filled in)")
    add("")
    local total, kinds = ns.ErrorCount()
    add(("Lua errors from XayaUI: %d occurrence(s), %d different"):format(total, kinds))
    for i, e in ipairs(ErrList()) do
        if i > 15 then add("... " .. (kinds - 15) .. " more not shown"); break end
        add(("[%d] x%d | first %s | last %s | version %s%s"):format(i, e.n or 1, date("%m-%d %H:%M", e.first or 0), date("%m-%d %H:%M", e.last or 0), tostring(e.ver), e.combat and " | in combat" or ""))
        add("    " .. tostring(e.msg))
        if e.stack and e.stack ~= "" then add("    stack: " .. e.stack:gsub("\n", " / ")) end
    end
    add("")
    add("Last console lines:")
    local buf = ns.logBuf or {}
    for i = math.max(1, #buf - 59), #buf do add("  " .. Plain(buf[i])) end
    if includeAddons then
        add("")
        local names = {}
        local n = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or 0
        for i = 1, n do
            local nm = C_AddOns.GetAddOnInfo(i)
            if nm and C_AddOns.IsAddOnLoaded(nm) then names[#names + 1] = nm end
        end
        add("Loaded addons (" .. #names .. "): " .. table.concat(names, ", "))
    end
    return table.concat(L, "\n")
end
function ns.ShowBugReport()
    local u = Ui()
    local txt = ns.BuildBugReport(u.bugText, u.bugAddons)
    if CueRulesDB then CueRulesDB.lastBugReport = txt end
    ns.ShowCopyBox("XayaUI bug report", txt)
end

-------------------------------------------------------------------------------
-- Console window
-------------------------------------------------------------------------------
local win
local function SavePos()
    if not win then return end
    local u = Ui()
    local p, _, rp, x, y = win:GetPoint(1)
    u.console = u.console or {}
    u.console.point, u.console.rel, u.console.x, u.console.y = p, rp, x, y
    u.console.w, u.console.h = win:GetWidth(), win:GetHeight()
end
local function BuildWindow()
    if win then return win end
    local f = CreateFrame("Frame", "XayaUIConsoleWindow", UIParent, "BackdropTemplate")
    local c = Ui().console or {}
    f:SetSize(tonumber(c.w) or 460, tonumber(c.h) or 300)
    f:SetPoint(c.point or "RIGHT", UIParent, c.rel or "RIGHT", tonumber(c.x) or -20, tonumber(c.y) or 0)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.05, 0.06, 0.92)
    f:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    f:SetMovable(true); f:SetResizable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    pcall(f.SetResizeBounds, f, 280, 120, 900, 900)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos() end)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", 8, -7)
    f.title:SetText("XayaUI console")
    local function Btn(label, w, fn)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 18); b:SetText(label); b:SetScript("OnClick", fn)
        if ns.FlatButton then ns.FlatButton(b) end
        return b
    end
    local x = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    x:SetSize(20, 20); x:SetPoint("TOPRIGHT", -2, -2)
    x:SetScript("OnClick", function() ns.ConsoleWindow(false) end)
    local bug = Btn("Bug report", 70, function() ns.ShowBugReport() end)
    bug:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -4)
    local clr = Btn("Clear", 44, function() f.log:Clear(); if ns.logBuf then wipe(ns.logBuf) end end)
    clr:SetPoint("RIGHT", bug, "LEFT", -4, 0)
    local cp = Btn("Copy", 44, function() ns.CopyConsole() end)
    cp:SetPoint("RIGHT", clr, "LEFT", -4, 0)
    f.log = CreateFrame("ScrollingMessageFrame", nil, f)
    f.log:SetPoint("TOPLEFT", 8, -28); f.log:SetPoint("BOTTOMRIGHT", -8, 8)
    f.log:SetFontObject(GameFontHighlightSmall)
    f.log:SetJustifyH("LEFT"); f.log:SetMaxLines(350); f.log:SetFading(false); f.log:SetInsertMode("BOTTOM")
    f.log:EnableMouseWheel(true)
    f.log:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); SavePos() end)
    for _, line in ipairs(ns.logBuf or {}) do f.log:AddMessage(line) end
    win = f
    return f
end
-- the log hands every new line here as well (Core.lua ns.Log); nothing is drawn while the window does not exist
function ns.ConsoleSink(line)
    if win and win.log then win.log:AddMessage(line) end
end
function ns.ConsoleWindow(show)
    local u = Ui()
    if show == nil then show = not (win and win:IsShown()) end
    u.consoleOpen = show and true or nil
    if show then
        local f = BuildWindow()
        f:Show()
    elseif win then
        win:Hide()
    end
    ns.Fire("CONFIG_CHANGED")
end
function ns.ConsoleWindowOn() return (win and win:IsShown()) and true or false end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if Ui().consoleOpen then ns.ConsoleWindow(true) end
end)
