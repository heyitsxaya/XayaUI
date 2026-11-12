-------------------------------------------------------------------------------
-- XayaUI Debug: the console window (/xui console). Moved from XayaUI/Console.lua in bundle 1 round 7 (REQUEST-LOG A23 SD-58: the console
-- window is one of the debug tools, read only while Advanced Debugging is on; Tools.lua says how this addon loads).
--  * The console window: the same event log as the strip under the options window, but in its own movable, resizable window that keeps
--    collecting lines while the options window is closed and during combat (the log buffer lives in XayaUI/Core.lua and the line feed in
--    XayaUI/Console.lua; neither depends on the window).
--  * The command line (core 0.6.50; Xaya 2026-11-05: "XUI Console does nothing and has no input options"): a line at the bottom of the
--    console window runs any /xui command (typed with or without "/xui"); what it prints shows in the window, whatever "XayaUI's
--    messages" (Settings > Debugging) is set to. Up / Down bring back this session's commands. While the window has no lines, a hint
--    says what to type and where XayaUI's other messages go.
-- Opened with /xui console and from Settings > Debugging. V26: exempt from the combat lock (her words: "the console window"); it opens
-- and runs typed commands in combat (a locked command typed in it is still locked by its own owner).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI)

-- the Platform's settings, through its view (Modules.lua section 0b: only the Platform's own files name its saved variable)
local PlatS = ns.Settings and ns.Settings("platform")
local function Ui()
    if not (PlatS and ns.SettingsReady()) then return {} end
    local u = PlatS.ui
    if type(u) ~= "table" then u = {}; PlatS.ui = u end
    return u
end

-------------------------------------------------------------------------------
-- Console window (moved from XayaUI/Console.lua in round 7). The line feed (ns.ConsoleSink) and its queue of private lines stay in core,
-- so lines keep arriving while this window is closed; the window hands core its draw function and says when it opens and closes.
-------------------------------------------------------------------------------
local win
local drawnSerial = 0    -- ns.logSerial when the window was last up to date (Core.lua counts every line put in ns.logBuf)
local NONE = {}
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
    ns.ConsoleSetShown(true)
    if not (win and win.log) then return end
    local held = ns.ConsoleTakeHeld() or NONE   -- (the private lines core kept while the window was closed, oldest first)
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
    f:SetScript("OnHide", function() ns.ConsoleSetShown(false); drawnSerial = ns.logSerial or 0 end)
    ns.ConsoleAttach(Draw)   -- (core's line feed draws here from now on)
    ns.ConsoleSetShown(true); drawnSerial = ns.logSerial or 0
    return f
end
-- (the log hands every new line to core's ns.ConsoleSink, XayaUI/Console.lua, which draws it here while the window is up)
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

-------------------------------------------------------------------------------
-- Messages into the console window (moved from XayaUI/DebugRecord.lua in round 7; core's ns.Print and error handler call this only
-- while XayaUI's messages go to the console window, which they can only do while this addon is loaded: DebugRecord.lua ns.MessageDest).
-- private (ns.PrintPrivate, e.g. a message naming another player): drawn in the open window and tray only, never put in ns.logBuf,
-- which the bug report, "Copy" and a reopened window read.
-------------------------------------------------------------------------------
local pendingOpen, regenFrame = false, nil
-- the end of combat opens the window a message asked for in the fight (PLAYER_REGEN_ENABLED, registered only while one waits)
local function OpenAfterCombat()
    pendingOpen = true
    if not regenFrame then
        regenFrame = CreateFrame("Frame")
        regenFrame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            if pendingOpen then pendingOpen = false; pcall(ns.ConsoleWindow, true) end
        end)
    end
    regenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end
function ns.ConsoleMessage(text, isError, private)
    local line = (isError and "|cffff5555[XayaUI error]|r " or "|cff33ccffXayaUI|r: ") .. tostring(text)
    if not private then ns.LogAppend(line) end   -- (Core.lua: ns.logBuf, trimmed to its last 300 lines past 350)
    if ns.Fire then ns.Fire("LOG", line) end
    ns.ConsoleSink(line, private)
    if ns.MessageDest() == "console" and Ui().consoleAutoOpen ~= false and not ns.ConsoleWindowOn() then
        if InCombatLockdown and InCombatLockdown() then OpenAfterCombat()
        else pcall(ns.ConsoleWindow, true) end
    end
end

-- reopened at login when it was open at logout (this addon loads at the login, so both run at once). A window saved closed makes no
-- frame and waits for nothing.
ns.WhenReady(function()
    if not Ui().consoleOpen then return end
    ns.AtLogin(function() if Ui().consoleOpen then ns.ConsoleWindow(true) end end)
end)
