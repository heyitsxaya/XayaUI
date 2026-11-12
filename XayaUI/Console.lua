-- XayaUI: the copy box, the console's line feed and the debug tools' entry points.
--  * ns.ShowCopyBox(title, text): a small window with the text selected, ready for Ctrl+C.
--  * ns.ConsoleText / ns.CopyConsole: every line of the event log (ns.logBuf, Core.lua) as plain text.
--  * ns.ConsoleSink(line, private): every new log line is handed here; it draws it in the console window while that window is up, and
--    keeps the private lines (ns.PrintPrivate, never in ns.logBuf) that come while it is closed, for when it opens again.
-- (bundle 1 round 7; REQUEST-LOG A23 SD-58, her answer "1 but nothing loads unless "Debugging" is enabled"; SD-61 "Off by default";
-- V34 "off means not read") The console window itself (/xui console, its command line), the bug report (/xui bug) and the debug report
-- (/xui report) are the load-on-demand addon XayaUI_Debug, which core loads once per reload, at login, only while Settings > Debugging >
-- Advanced Debugging is on (DebugRecord.lua). What stays here is what must work either way: the log buffer and this line feed with its
-- private queue (so the window, when it exists, catches up on what came before it), the copy box (Settings > Debugging > What to send),
-- and one plain line for each debug tool asked for while XayaUI_Debug is not loaded (ns.DebugToolsNeeded, DebugRecord.lua).
local _, ns = ...


local function Plain(s)
    s = tostring(s or "")
    s = s:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return s
end
ns.PlainText = Plain

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
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        local sf = CreateFrame("ScrollFrame", "XayaUICopyBoxScroll", f, "UIPanelScrollFrameTemplate")
        -- (the bottom: Select all's 12 + 24, then the gutter; #351)
        sf:SetPoint("TOPLEFT", 12, -50); sf:SetPoint("BOTTOMRIGHT", -32, 12 + 24 + ns.UI_GUTTER)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(560); eb:SetMaxLetters(0)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.eb = eb
        if ns.KeyFocusGuard then ns.KeyFocusGuard(eb) end   -- (row 56) lets go of the keyboard: Enter / Esc / a click outside / hiding (core KeyCatch.lua)
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
    -- (review R23) opened in combat it does not take the keyboard: her movement and keybinds stay hers; Select all selects it then
    if InCombatLockdown and InCombatLockdown() then
        copyBox.hint:SetText("Press Select all, then Ctrl+C to copy the text. Esc closes this window.")
        return
    end
    copyBox.hint:SetText("The text is selected. Press Ctrl+C to copy it, then Esc to close.")
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
-- The console window's line feed (round 7: the window is XayaUI_Debug/Console.lua). Core.lua ns.Log and the console messages hand every
-- new line here. V14 (core 0.6.47; Xaya 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD or
-- contribute to performance cost / demand in any way"): nothing is drawn or held while the window does not exist (Advanced Debugging
-- off: it never does) or is closed; when it opens again it draws, in order, the lines of ns.logBuf it missed and the private lines
-- (ns.PrintPrivate, never in ns.logBuf) that came while it was closed (at most 100, the oldest dropped).
-------------------------------------------------------------------------------
local drawLine            -- the window's draw function, handed in when XayaUI_Debug builds the window; nil until then
local winShown = false    -- the window is up (its OnShow / OnHide say so)
local held = {}           -- { serial, line }: private lines that came while it was closed
function ns.ConsoleSink(line, private)
    if not drawLine then return end
    if winShown then drawLine(line)
    elseif private then
        held[#held + 1] = { ns.logSerial or 0, line }
        if #held > 100 then table.remove(held, 1) end
    end
end
-- (XayaUI_Debug/Console.lua) the window was built: draw(line) puts one line in it
function ns.ConsoleAttach(draw) if type(draw) == "function" then drawLine = draw end end
-- (XayaUI_Debug/Console.lua) the window opened (true) or closed (false)
function ns.ConsoleSetShown(on) winShown = on and true or false end
-- (XayaUI_Debug/Console.lua, when the window opens again) the private lines kept while it was closed, oldest first; the queue is emptied
function ns.ConsoleTakeHeld()
    if #held == 0 then return nil end
    local h = held
    held = {}
    return h
end
-- whether the console window is up. XayaUI_Debug replaces this with its window's state; until then there is no window (Core.lua
-- ns.LogWanted and Settings > Debugging read it).
function ns.ConsoleWindowOn() return false end

-- Hand-in points of the console window's addon, declared here so core may call them (the harness boundary rule); XayaUI_Debug replaces
-- them when it loads. Core calls them only while that addon is loaded (ns.MessageDest is "chat" until then; Core.lua's /xui debug asks
-- ns.DebugToolsLoaded first), so these defaults only keep a stray call harmless.
ns.consoleRunning = nil   -- true while a command typed in the console window (or any /xui debug command) runs: it prints there
function ns.ConsoleMessage() end
function ns.RunInConsole(_, fn, ...) return fn(...) end

-------------------------------------------------------------------------------
-- The debug tools' entry points while XayaUI_Debug is not loaded (Advanced Debugging off at login, or turned on since): /xui console,
-- /xui bug and /xui report, and the same buttons on Settings > Debugging, print one plain line saying what they need
-- (ns.DebugToolsNeeded, DebugRecord.lua). XayaUI_Debug replaces each of these with the real one when it loads.
-------------------------------------------------------------------------------
function ns.ConsoleWindow(show)
    if show == false then return end   -- (closing a window that does not exist: nothing to say)
    ns.DebugToolsNeeded("The console window (/xui console)")
end
function ns.ShowBugReport() ns.DebugToolsNeeded("The bug report (/xui bug)") end
function ns.ShowDebugReport() ns.DebugToolsNeeded("The debug report (/xui report)") end
