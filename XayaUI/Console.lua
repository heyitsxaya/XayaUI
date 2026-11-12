-- XayaUI: Console window, copy box and bug report.
--  * ns.ShowCopyBox(title, text): a small window with the text selected, ready for Ctrl+C.
--  * The console window: the same event log as the strip under the options window, but in its own movable, resizable window that keeps
--    collecting lines while the options window is closed and during combat (the log buffer lives in Core.lua and never depends on the window).
--  * The error log: XayaUI's own Lua errors are kept (de-duplicated, saved between sessions) so they can be shared.
--  * The bug report: version, game build, recent errors and console lines as plain text, with no character name, realm, or rule contents.
--  * The command line (core 0.6.50; Xaya 2026-11-05: "XUI Console does nothing and has no input options"): a line at the bottom of the
--    console window runs any /xui command (typed with or without "/xui"); what it prints shows in the window, whatever "XayaUI's
--    messages" (Settings > Debugging) is set to. Up / Down bring back this session's commands. While the window has no lines, a hint
--    says what to type and where XayaUI's other messages go.
-- Opened with /xui console and /xui bug, and from Settings > Debugging. Not run in game when written (2026-11-01).
local addonName, ns = ...


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
-- Error log: since core 0.6.56 the coded record in DebugRecord.lua (ns.RecordError, ns.ErrorEntries, ns.ErrorCount, ns.ClearErrorLog;
-- CueRulesDB.errorLog, the same saved list). The bug report below reads it.
-------------------------------------------------------------------------------
local function AddonVersion()
    local f = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(f, addonName, "Version")
    return (ok and v) or "?"
end

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
    local R = ns.Service and ns.Service("rules")   -- (P4) XayaUI Rules' "rules" service; nil while it is switched off
    local spec = R and R.CurrentSpecID() or nil
    add(("Spec ID: %s | in combat: %s | locale: %s"):format(tostring(spec), tostring((UnitAffectingCombat and UnitAffectingCombat("player")) and true or false), tostring(GetLocale and GetLocale() or "?")))
    local nr, nc, ncond = 0, 0, 0
    for _, r in ipairs(R and R.Rules() or {}) do
        if r.isCue then nc = nc + 1 elseif r.parentUid then ncond = ncond + 1 else nr = nr + 1 end
    end
    add(("Rules: %d | cues: %d | conditions: %d | skin on: %s"):format(nr, nc, ncond, (ns.Options and tostring(ns.Options.SkinOn()) or "window not loaded")))
    add("(No character name or realm, and no rule settings. Rule names appear in the console lines below, and in XayaUI Dev Assist's detailed record when it is on.)")
    add("")
    add("What happened:")
    add((description and description:match("%S")) and description or "(not filled in)")
    add("")
    local total, kinds = ns.ErrorCount()
    add(("Errors and warnings from XayaUI: %d occurrence(s), %d different (codes: /xui report)"):format(total, kinds))
    for i, e in ipairs(ns.ErrorEntries()) do
        if i > 15 then add("... " .. (kinds - 15) .. " more not shown"); break end
        add(("[%d] %s x%d | first %s | last %s | version %s%s"):format(i, tostring(e.code), e.n or 1, date("%m-%d %H:%M", e.first or 0), date("%m-%d %H:%M", e.last or 0), tostring(e.ver), e.combat and " | in combat" or ""))
        add("    " .. tostring(e.msg))
        if e.stack and e.stack ~= "" then add("    stack: " .. e.stack:gsub("\n", " / ")) end
    end
    add("")
    add("Last console lines:")
    local buf = ns.logBuf or {}
    for i = math.max(1, #buf - 59), #buf do add("  " .. Plain(buf[i])) end
    -- the saved debug record (DebugRecord.lua, kept while Advanced Debugging is on): the newest 1500 lines here, all of them in the
    -- SavedVariables file. It holds rule names, spell IDs and XayaUI's own messages. Messages that name another player (ns.PrintPrivate) are
    -- never kept: not in the record, and not in ns.logBuf, which the "Last console lines" above read.
    local rn, rdrop, rstart = 0, 0, nil
    if ns.RecordSummary then rn, rdrop, rstart = ns.RecordSummary() end
    if rn > 0 then
        local lines = CueRulesDB.debugRecord.lines
        add("")
        add(("Debug record: %d lines since %s%s (newest %d below; all of them are in XayaUI.lua, see WHAT TO SEND at the end):"):format(
            rn, tostring(rstart), rdrop > 0 and (", " .. rdrop .. " older lines dropped") or "", math.min(rn, 1500)))
        for i = math.max(1, rn - 1499), rn do add("  " .. tostring(lines[i])) end
    end
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
    if ns.SendText then add(""); add(ns.SendText()) end   -- the files to send and where they are (DebugRecord.lua)
    return table.concat(L, "\n")
end
function ns.ShowBugReport()
    local u = Ui()
    -- (round 6, SD-55 "Dead logs") shown, not kept: nothing read the saved copy (CueRulesDB.lastBugReport, let go at login: DebugRecord.lua)
    ns.ShowCopyBox("XayaUI bug report", ns.BuildBugReport(u.bugText, u.bugAddons))
end

-------------------------------------------------------------------------------
-- Console window
-------------------------------------------------------------------------------
local win
local winShown = false   -- the window is up (OnShow / OnHide); while not, ns.ConsoleSink draws nothing
local drawnSerial = 0    -- ns.logSerial when the window was last up to date (Core.lua counts every line put in ns.logBuf)
local held = {}          -- { serial, line }: private lines that came while it was closed (they are never in ns.logBuf)
-- the hint shown while the window has no lines (core 0.6.50): what to type, and where XayaUI's other messages go
local DEST_WORDS = { chat = "the chat window", console = "this window", both = "this window and the chat window" }
local function HintText()
    local d = ns.MessageDest and ns.MessageDest() or "chat"
    return "Nothing here yet. Type a XayaUI command in the line below and press Enter: help lists them, debug lists the diagnostic ones."
        .. " What a command prints shows here.\n\nXayaUI's other messages go to " .. (DEST_WORDS[d] or DEST_WORDS.chat)
        .. " (Settings > Debugging > XayaUI's messages)."
end
-- every line the window draws goes through here: the first one hides the hint
-- (Xaya 2026-11-06, of the hint: "yes as long as it doesn't negatively impact performance": its state is one local, so a drawn line
-- costs one boolean test, no widget call; nothing of it exists until the window is first opened)
local hintUp = false
local function SetHint(on)
    hintUp = on and true or false
    if on then win.empty:SetText(HintText()); win.empty:Show() else win.empty:Hide() end
end
local function Draw(line)
    win.log:AddMessage(line)
    if hintUp then SetHint(false) end
end
-- the window opens again: draw what it missed, in the order it came
local function CatchUp()
    winShown = true
    if not (win and win.log) then return end
    local now, buf = ns.logSerial or 0, ns.logBuf or {}
    local missed = now - drawnSerial
    local h = 1
    if missed > 0 then
        local n = #buf
        for i = math.max(1, n - missed + 1), n do
            local serial = now - (n - i)   -- (buf[n] is line number `now`; a trim only drops lines from the front)
            while held[h] and held[h][1] < serial do Draw(held[h][2]); h = h + 1 end
            Draw(buf[i])
        end
    end
    while held[h] do Draw(held[h][2]); h = h + 1 end
    if hintUp then SetHint(true) end   -- (the text again: the setting may have changed while it was closed)
    if #held > 0 then held = {} end
    drawnSerial = now
end
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
    -- (420 px at least: the title and the four buttons share the top row, a gutter between each; #351 phase 2)
    local M, G = ns.UI_MARGIN, ns.UI_GUTTER
    -- (160 px tall at least: the top row, the command line and the hint fit; core 0.6.50)
    f:SetSize(math.max(420, tonumber(c.w) or 460), math.max(160, tonumber(c.h) or 300))
    f:SetPoint(c.point or "RIGHT", UIParent, c.rel or "RIGHT", tonumber(c.x) or -20, tonumber(c.y) or 0)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.05, 0.06, 0.92)
    f:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    f:SetMovable(true); f:SetResizable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    pcall(f.SetResizeBounds, f, 420, 160, 900, 900)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos() end)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("LEFT", f, "TOPLEFT", M, -(M + 9))   -- level with the buttons' middle (18 px tall, M from the top)
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
    bug:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(2 + 20 + G), -M)   -- a gutter left of the close button (2 px from the edge, 20 wide)
    local clr = Btn("Clear", 44, function()
        f.log:Clear(); if ns.logBuf then wipe(ns.logBuf) end
        SetHint(true)
    end)
    clr:SetPoint("RIGHT", bug, "LEFT", -G, 0)
    local cp = Btn("Copy", 44, function() ns.CopyConsole() end)
    cp:SetPoint("RIGHT", clr, "LEFT", -G, 0)
    -- the files to send and the folder they are in, as copyable text (DebugRecord.lua ns.SendText)
    local send = Btn("What to send", 84, function() if ns.SendText then ns.ShowCopyBox("XayaUI: what to send", ns.SendText()) end end)
    send:SetPoint("RIGHT", cp, "LEFT", -G, 0)
    -- the command line along the bottom, clear of the resize grip in the corner (2 px from the edges, 16 px; a gutter between)
    local CMD_H = 20
    local cmd = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    cmd:SetHeight(CMD_H)
    cmd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", M, M); cmd:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(2 + 16 + G), M)
    cmd:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    cmd:SetBackdropColor(0, 0, 0, 0.5)
    cmd:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    cmd:SetFontObject(ChatFontNormal); cmd:SetTextInsets(6, 6, 0, 0)
    cmd:SetAutoFocus(false); cmd:SetMaxLetters(255)
    -- Up / Down bring back earlier commands: the edit box's own history (AddHistoryLine, SetHistoryLines, SetAltArrowKeyMode are
    -- SimpleEditBoxAPI in docs/reference/api/widgets.md; that the arrows walk it with alt-arrow mode off is INFERENCE from the chat
    -- edit box, not documented there; if they do not, typing and Enter still work)
    cmd:SetAltArrowKeyMode(false); cmd:SetHistoryLines(30)
    cmd.hint = cmd:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cmd.hint:SetPoint("LEFT", cmd, "LEFT", 6, 0); cmd.hint:SetPoint("RIGHT", cmd, "RIGHT", -6, 0)
    cmd.hint:SetJustifyH("LEFT"); cmd.hint:SetWordWrap(false)
    cmd.hint:SetText("Type a command, Enter to run it (help, debug, debug status)")
    local function HintShown() cmd.hint:SetShown(cmd:GetText() == "" and not cmd:HasFocus()) end
    cmd:SetScript("OnEditFocusGained", HintShown)
    cmd:SetScript("OnEditFocusLost", HintShown)
    cmd:SetScript("OnTextChanged", HintShown)
    cmd:SetScript("OnEnterPressed", function(self)
        local t = self:GetText() or ""
        self:SetText("")
        if ns.ConsoleRun(t) then self:AddHistoryLine(t) end
        -- (XayaUI 0.6.85 review, V24) Enter runs the command AND lets go of the keyboard: a line that kept the cursor kept every key,
        -- movement and the screenshot key included, until Esc or a click elsewhere. A click in the line types the next command.
        self:ClearFocus()
    end)
    cmd:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.cmd = cmd
    if ns.KeyFocusGuard then ns.KeyFocusGuard(cmd) end   -- (row 56) lets go of the keyboard: Enter / Esc / a click outside / hiding (core KeyCatch.lua)
    f.log = CreateFrame("ScrollingMessageFrame", nil, f)
    f.log:SetPoint("TOPLEFT", M, -(M + 18 + G)); f.log:SetPoint("BOTTOMRIGHT", -M, M + CMD_H + G)
    f.log:SetFontObject(GameFontHighlightSmall)
    f.log:SetJustifyH("LEFT"); f.log:SetMaxLines(350); f.log:SetFading(false); f.log:SetInsertMode("BOTTOM")
    f.log:EnableMouseWheel(true)
    f.log:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip.xuiEdge = true   -- a corner resize grip sits at the edge on purpose (#351: exempt from the margin)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); SavePos() end)
    f.empty = f.log:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")   -- (the log area's own text: shown only while it is empty)
    f.empty:SetPoint("TOPLEFT", f.log, "TOPLEFT", 0, 0); f.empty:SetPoint("TOPRIGHT", f.log, "TOPRIGHT", 0, 0)
    f.empty:SetJustifyH("LEFT"); f.empty:SetJustifyV("TOP"); f.empty:SetWordWrap(true)
    win = f
    SetHint(true)
    for _, line in ipairs(ns.logBuf or {}) do Draw(line) end
    f:SetScript("OnShow", CatchUp)
    f:SetScript("OnHide", function() winShown = false; drawnSerial = ns.logSerial or 0 end)
    winShown, drawnSerial = true, ns.logSerial or 0
    return f
end
-- the log hands every new line here as well (Core.lua ns.Log, DebugRecord.lua ns.ConsoleMessage). V14 (core 0.6.47; Xaya 2026-11-05:
-- "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to performance cost / demand in any way"):
-- nothing is drawn while the window does not exist or is closed ("Console window" off); when it opens again it draws, in order, the
-- lines of ns.logBuf it missed (CatchUp) and the private lines (ns.PrintPrivate, never in ns.logBuf) that came while it was closed.
function ns.ConsoleSink(line, private)
    if not win then return end
    if winShown then Draw(line)
    elseif private then
        held[#held + 1] = { ns.logSerial or 0, line }
        if #held > 100 then table.remove(held, 1) end
    end
end
-- fromSettings: the settings window's own switch made the change; that window redraws itself after the click, so no redraw is
-- asked for here. Any other caller (the close X, /xui console, a message opening it) asks for a "view" redraw: only the switch's
-- tick changes, so the settings window reuses its options tree instead of building it again (core 0.6.45; Xaya 2026-11-05:
-- "console toggle has a still long time"; a full build is 0.44-0.64 s of Lua with 229 rules in the test harness).
function ns.ConsoleWindow(show, fromSettings)
    local u = Ui()
    if show == nil then show = not (win and win:IsShown()) end
    u.consoleOpen = show and true or nil
    if show then
        local f = BuildWindow()
        f:Show()
    elseif win then
        win:Hide()
    end
    if not fromSettings then ns.Fire("CONFIG_CHANGED", "view") end
end
function ns.ConsoleWindowOn() return (win and win:IsShown()) and true or false end

-- Run what was typed in the console's command line (core 0.6.50). "/xui debug status", "/xayaui debug status" and "debug status" all
-- run /xui debug status; /save and /reload reload the interface; any other slash command, the game's or another addon's, is not run
-- (only XayaUI's own handler is called). The typed line is echoed into the
-- window; what the command prints goes to the window (ns.consoleRunning, read by Core.lua ns.Print), whatever "XayaUI's messages"
-- says. Messages a command prints later (after a timer, at the end of combat) go where the setting says. Returns true when a
-- command ran (the edit box keeps it in its history).
-- Run fn(...) with what it prints going to the console window, whatever "XayaUI's messages" says (ns.consoleRunning, read by Core.lua
-- ns.Print and its error handler). open: open the window first if it is closed (any /xui debug command; Xaya 2026-11-06: "Debug cmds
-- open console"). An error goes to the game's error handler while ns.consoleRunning is still set: XayaUI's handler (Core.lua) shows it
-- in the window and keeps it for the bug report, and BugSack or the game's error frame still get it; a feature's command reaches the
-- same handler from Modules.lua's own pcall. Messages printed later (after a timer, at the end of combat) go where the setting says.
function ns.RunInConsole(open, fn, ...)
    if open and not ns.ConsoleWindowOn() then ns.ConsoleWindow(true) end
    local prev, args, n = ns.consoleRunning, { ... }, select("#", ...)
    ns.consoleRunning = true
    xpcall(function() fn(unpack(args, 1, n)) end, function(e) local h = geterrorhandler and geterrorhandler(); if h then pcall(h, e) end end)
    ns.consoleRunning = prev
end
-- a line of the console's own (the typed command, a refusal): kept in ns.logBuf like a message, drawn in the window and the settings
-- window's strip, not put in chat or the debug record
local function Put(line)
    ns.LogAppend(line)
    if ns.Fire then ns.Fire("LOG", line) end
    ns.ConsoleSink(line)
end
function ns.ConsoleRun(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return false end
    local low, body = text:lower(), nil
    for _, p in ipairs({ "/xui", "/xayaui" }) do
        if low == p then body = "" elseif low:sub(1, #p + 1) == p .. " " then body = text:sub(#p + 2) end
        if body then break end
    end
    -- (Xaya 2026-11-06, of refusing other slash commands here: "Yes, but /save should trigger a reload"; of /reload: "Both work")
    -- /save and /reload reload the interface,
    -- which is when the game writes the saved settings to disk. C_UI.Reload is documented (docs/reference/api/namespaces.md, C_UI:
    -- "`C_UI.Reload()`", no flags, no returns); ReloadUI, the older global XayaUI already calls from buttons, if it is missing.
    -- INFERENCE (not documented): an addon may call it from a key press in its own edit box, as the game's own reload buttons do.
    if low == "/save" or low == "/reload" then
        Put("|cff888888> " .. low .. "|r  reloading the interface (that writes your settings to disk)")
        local reload = (C_UI and C_UI.Reload) or ReloadUI
        if type(reload) == "function" then reload() end
        return true
    end
    if not body and text:sub(1, 1) == "/" then
        Put("|cffff5555Only XayaUI's own commands run here|r (and /save or /reload, which reload the interface). Type them with or without /xui, "
            .. "for example: help, debug, debug status.")
        return false
    end
    body = (body or text):gsub("^%s+", "")
    Put("|cff888888> /xui " .. body .. "|r")   -- the typed line, as the console's own record of what ran
    local run = SlashCmdList and SlashCmdList["XAYAUI"]
    if type(run) ~= "function" then return false end
    ns.RunInConsole(false, run, body)
    return true
end

-- reopened at login when it was open at logout. V14: decided when the saved settings are ready; a window saved closed makes no frame
-- and waits for nothing (core's start-up frame runs it at PLAYER_LOGIN, Modules.lua ns.AtLogin; this file had its own frame for it).
ns.WhenReady(function()
    if not Ui().consoleOpen then return end
    ns.AtLogin(function() if Ui().consoleOpen then ns.ConsoleWindow(true) end end)
end)
