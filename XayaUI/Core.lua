-------------------------------------------------------------------------------
-- Core.lua : namespace, saved variables, rule defaults, slash commands.
-------------------------------------------------------------------------------
local addonName, ns = ...

ns.name = addonName; XayaUI_NS = ns -- deliberate global: sibling addons (XayaUI_Chat, XayaUI_QoL, XayaUI_Bonus, XayaUI_Reskin, XayaUI_Options) share this namespace; they plug in through Modules.lua
-- #286: a button built from Blizzard's red UIPanelButtonTemplate takes XayaUI's flat look now and every time it is shown, so it also
-- follows the skin switch. UI-77 (O-139, core 0.6.68): the look itself lives here in core (ns.PaintFlatButton), so core's windows
-- (console, copy box, debug report) are flat after a /reload even though the settings addon (LoadOnDemand) is not loaded; the settings
-- addon's ns.SkinPlainButton calls this same function, so there is one copy of the look.
local FLAT_GOLD = { 1, 0.82, 0, 1 }
local function FlatCol(class, prop, fb) local T = ns.Theme; if T and T.Col then return T.Col(class, prop, fb) end return fb end
local function FlatSkinOn() return not (CueRulesDB and CueRulesDB.ui and CueRulesDB.ui.skinOff) end
-- the 1px-bordered box drawn with plain textures (the same fields as the settings addon's Skin.lua Flat, so both can repaint it)
local function FlatBox(f, bg, border, grad)   -- grad (#460, core 0.6.81): the border's gradient (Theme.lua T.Grad), nil = solid
    local t = f.xuiFlat
    if not t then
        t = { bg = f:CreateTexture(nil, "BACKGROUND", nil, -3), e = {} }
        for i = 1, 4 do t.e[i] = f:CreateTexture(nil, "BACKGROUND", nil, -2) end
        f.xuiFlat = t
    end
    t.bg:ClearAllPoints(); t.bg:SetPoint("TOPLEFT", 0, 0); t.bg:SetPoint("BOTTOMRIGHT", 0, 0)
    t.e[1]:ClearAllPoints(); t.e[1]:SetPoint("TOPLEFT", 0, 0); t.e[1]:SetPoint("TOPRIGHT", 0, 0); t.e[1]:SetHeight(1)
    t.e[2]:ClearAllPoints(); t.e[2]:SetPoint("BOTTOMLEFT", 0, 0); t.e[2]:SetPoint("BOTTOMRIGHT", 0, 0); t.e[2]:SetHeight(1)
    t.e[3]:ClearAllPoints(); t.e[3]:SetPoint("TOPLEFT", 0, 0); t.e[3]:SetPoint("BOTTOMLEFT", 0, 0); t.e[3]:SetWidth(1)
    t.e[4]:ClearAllPoints(); t.e[4]:SetPoint("TOPRIGHT", 0, 0); t.e[4]:SetPoint("BOTTOMRIGHT", 0, 0); t.e[4]:SetWidth(1)
    t.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1); t.bg:Show()
    local T = ns.Theme
    if (grad or f.xuiGradE) and T and T.PaintEdges then T.PaintEdges(f, t.e, border, grad, "BACKGROUND", -2); return end
    for _, e in ipairs(t.e) do e:SetColorTexture(border[1], border[2], border[3], border[4] or 1); e:Show() end
end
-- hide the Blizzard art (remembered in f.xuiHidden, so skin-off can put it back); the box's own textures are kept
local function FlatHideArt(f)
    if f.xuiHidden then return end
    f.xuiHidden = {}
    local own = {}
    if f.xuiFlat then own[f.xuiFlat.bg] = true; for _, e in ipairs(f.xuiFlat.e) do own[e] = true end end
    for _, rg in ipairs({ f:GetRegions() }) do
        if rg.GetObjectType and rg:GetObjectType() == "Texture" and not own[rg] and not rg.xuiOwn then   -- (#460: xuiOwn = a gradient piece)
            f.xuiHidden[#f.xuiHidden + 1] = { rg, rg:GetAlpha() }; rg:SetAlpha(0)
        end
    end
end
local function FlatShowArt(f)
    if not f.xuiHidden then return end
    for _, p in ipairs(f.xuiHidden) do p[1]:SetAlpha(p[2]) end
    f.xuiHidden = nil
end
-- Flat look for a plain Blizzard-template Button: the red art hidden, the theme's "xui-button" (or "xui-button-primary") colors
-- painted, text gold and white on hover. Safe to call again (colors are re-read, so a theme change shows); skin off restores Blizzard's.
function ns.PaintFlatButton(b, primary)
    if not b or not b.GetFontString then return end
    if not FlatSkinOn() then
        if b.xuiFlatBtn then
            FlatShowArt(b)
            local t = b.xuiFlat; if t then t.bg:Hide(); for _, e in ipairs(t.e) do e:Hide() end end
            local T = ns.Theme; if b.xuiGradE and T and T.HideGrad then T.HideGrad(b) end   -- (#460)
            local ht = b:GetHighlightTexture(); if ht then ht:SetAlpha(1) end
        end
        return
    end
    if not b.xuiFlatBtn then
        b.xuiFlatBtn = true
        FlatHideArt(b)
        local ht = b:GetHighlightTexture(); if ht then ht:SetAlpha(0) end
        local fs = b:GetFontString(); if fs then fs:ClearAllPoints(); fs:SetPoint("CENTER") end
        b:HookScript("OnEnter", function(self)
            local f = self:GetFontString()
            if f and self.xuiFlatBtn then local c = FlatCol("xui-list-selected", "text", { 1, 1, 1, 1 }); f:SetTextColor(c[1], c[2], c[3]) end
        end)
        b:HookScript("OnLeave", function(self)
            local f = self:GetFontString()
            if f and self.xuiFlatBtn then local c = self.xuiBtnText or FLAT_GOLD; f:SetTextColor(c[1], c[2], c[3]) end
        end)
    elseif b.xuiHidden == nil then
        FlatHideArt(b)   -- returning from skin-off: hide the Blizzard art again
        local ht = b:GetHighlightTexture(); if ht then ht:SetAlpha(0) end
    end
    local cl = primary and "xui-button-primary" or "xui-button"
    local T = ns.Theme
    FlatBox(b, FlatCol(cl, "bg", { 0.04, 0.04, 0.04, 0.7 }), FlatCol(cl, "border", { 0.25, 0.25, 0.25, 1 }), T and T.Grad and T.Grad(cl, "border") or nil)
    local fs = b:GetFontString()
    if fs then
        local c = FlatCol(cl, "text", FLAT_GOLD)
        b.xuiBtnText = c
        fs:SetTextColor(c[1], c[2], c[3])
        local T = ns.Theme; if T and T.Style then pcall(T.Style, fs, nil) end
    end
end
-- the flat buttons made so far (weak keys: a button that is gone is not held) -> primary; Theme.lua T.Resolve calls
-- ns.RepaintFlatButtons, so a window built before the theme was applied at login (the console reopened after a /reload) takes the
-- theme's colors at once. A direct call, not a theme listener: with no flat button it is an empty loop, and the listener list is unchanged.
local flatButtons = setmetatable({}, { __mode = "k" })
function ns.RepaintFlatButtons()
    for b, primary in pairs(flatButtons) do
        if b.IsShown and b:IsShown() then pcall(ns.PaintFlatButton, b, primary) end   -- hidden ones repaint on their next show
    end
end
function ns.FlatButton(b, primary)
    if not b then return b end
    local function apply(self) pcall(ns.PaintFlatButton, self, primary) end
    apply(b)
    if b.HookScript then b:HookScript("OnShow", apply) end
    flatButtons[b] = primary and true or false
    return b
end
-- the settings window's rebuild timing switch: { show = bool } (XayaUI Dev Assist's /xui debug perf ui sets it; XayaUI_Options and
-- ns.NewFolder below read it). Core 0.6.56: declared here, as the command that made it moved to Dev Assist.
ns.perf = nil

-- "Not chosen / none" helpers. Dropdowns start blank (nil) so a choice is forced;
-- "none" (or legacy "any") is an explicit "ignore this".
function ns.Ignored(s) return s == nil or s == "" or s == "none" or s == "any" end
function ns.Val(v) if v == nil or v == "" or v == "none" then return nil end return v end

-- A message that names another player (or anything else personal): shown like ns.Print, but never kept anywhere a report reads:
-- not in the debug record, not in the console's line buffer (the bug report and "Copy" read it), not in collected output.
local privateMsg = false
function ns.PrintPrivate(...)
    privateMsg = true
    local ok, err = pcall(ns.Print, ...)
    privateMsg = false
    if not ok then error(err, 0) end
end
function ns.Print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    local text = table.concat(parts, " ")
    if ns._capture and not privateMsg then ns._capture[#ns._capture + 1] = text; return end   -- (DebugRecord.lua ns.CaptureOutput)
    if ns.RecordLine and not privateMsg then ns.RecordLine("msg", text) end
    -- where messages go (DebugRecord.lua, Settings > Debugging): chat, the XayaUI console window, or both. core 0.6.50, whatever the
    -- setting: a command typed in the console window, and any /xui debug command, prints in the console window (ns.consoleRunning,
    -- Console.lua ns.RunInConsole); the /xui status and /xui auras shortcuts print in chat (ns.chatRunning, RunInChat below). The
    -- console wins when both are set (a shortcut typed in the console window prints there).
    local dest = (ns.consoleRunning and "console") or (ns.chatRunning and "chat") or (ns.MessageDest and ns.MessageDest() or "chat")
    -- (Xaya 2026-11-06, asked whether messages set to the chat window should also show in the open console window: "Only xui console
    -- messages should display". So the console window shows only what is sent to it.)
    if dest ~= "chat" and ns.ConsoleMessage and pcall(ns.ConsoleMessage, text, false, privateMsg) and dest == "console" then return end
    print("|cff33ccffXayaUI|r: " .. text)
end

-------------------------------------------------------------------------------
-- XayaUI's own Lua errors (core 0.6.56; REQUEST-LOG #82, Xaya 2026-11-06: the debug record is "only there to catch errors and bugs
-- that might be expected within a live, user-facing version of the addon. these should have error codes built out, auto detection, and
-- auto documenting with a simple debug report that someone can directly send to me"). The game's error handler is chained, never
-- replaced: whatever handler was set before (the game's own error frame, BugSack, another addon's) is still called with the same
-- message, every time. Only an error raised in a XayaUI file (the file named at the start of the message, else the first file the stack
-- names: Interface/AddOns/XayaUI*/...) is recorded, with its code (DebugRecord.lua ns.RecordError: XUI-E001 for core, E002 the settings
-- window, ...). Nothing here runs unless an error happens: no event, no timer, no per-frame work.
-- With Advanced Debugging on (Settings > Debugging, on by default) the error is also shown where XayaUI's messages go.
-------------------------------------------------------------------------------
-- The XayaUI folder an error came from, or nil: the message's own location ("Interface/AddOns/XayaUI_Chat/Core.lua:12: ...") decides;
-- a message without one (error(msg, 0)) is decided by the first addon file in the stack.
function ns.ErrorFolder(text, stack)
    text = tostring(text or "")
    local loc = text:match("^%s*([^\n]-%.lua):%d+:")
    if loc then
        local folder = loc:match("AddOns[/\\](XayaUI[%w_]*)[/\\]")
        return folder
    end
    for path in tostring(stack or ""):gmatch("([^\n%[%]\"']-%.lua)") do
        local addon = path:match("AddOns[/\\]([%w_%-]+)[/\\]")
        if addon then return addon:match("^XayaUI[%w_]*$") and addon or nil end
    end
    return nil
end
do
    local prevHandler = geterrorhandler()
    seterrorhandler(function(msg)
        local text = tostring(msg)
        -- (core 0.6.65, REQUEST-LOG A15 P-11) a message that names its own file decides the folder from the text alone; the stack is
        -- read only for XayaUI's own errors (it is recorded with them) or when the text names no file. Another addon's error, even
        -- one repeated on every nameplate update, costs a match and the previous handler, never a debugstack.
        local stack, folder
        if text:match("^%s*[^\n]-%.lua:%d+:") then
            local okF, f = pcall(ns.ErrorFolder, text, nil)
            folder = okF and f or nil
            if folder then local okS, s = pcall(debugstack, 2, 12, 0); stack = (okS and type(s) == "string") and s or "" end
        else
            local okS, s = pcall(debugstack, 2, 12, 0)
            stack = (okS and type(s) == "string") and s or ""
            local okF, f = pcall(ns.ErrorFolder, text, stack)
            folder = okF and f or nil
        end
        if not folder then ns.otherErrors = (ns.otherErrors or 0) + 1 end   -- other addons' errors this session (Dev Assist walkthrough J22)
        if folder and ns.RecordError then pcall(ns.RecordError, text, stack, folder) end   -- (DebugRecord.lua; nothing while it is off)
        local ok, on = pcall(function() return CueRulesDB and CueRulesDB.ui and CueRulesDB.ui.advancedDebug end)
        local mine = ok and on and folder ~= nil
        -- (core 0.6.50) an error while a command typed in the console window runs (Console.lua ns.ConsoleRun) is that command's:
        -- shown in the console window, Advanced Debugging on or off
        local typed = ns.consoleRunning
        if mine or typed then
            -- the same place as XayaUI's messages (DebugRecord.lua): the console window, chat, or both
            local dest = typed and "console" or (ns.MessageDest and ns.MessageDest() or "chat")
            local shown = dest ~= "chat" and ns.ConsoleMessage and pcall(ns.ConsoleMessage, text, true)
            if (dest ~= "console" or not shown) and DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[XayaUI Error]|r " .. text, 1, 0.35, 0.35)
            end
        end
        if prevHandler then return prevHandler(msg) end
    end)
end

-- In-game event log (shown in the settings window's debug console tray).
ns.logBuf = {}
-- ns.LogWanted(kind): is a "rule" (fired / repeat / cleared) or "snapshot" line wanted now? Only while something shows or keeps it:
-- the console window is open, the settings window's debug strip is shown (XayaUI_Options sets ns.LogTrayOn), or XayaUI Dev Assist's
-- detailed record keeps that kind (ns.RecordOn). Otherwise the engine builds no such line (REQUEST-LOG A15 P-9; Xaya 2026-11-07, her
-- console showed hundreds of these lines: "why do I have so much already in it?"; she was not asked, by her 06:00 rule: READING, the
-- conservative one: nothing is lost that was being read). /xui debug status still prints every rule's state on demand.
-- (the settings window's debug strip: XayaUI_Options replaces this when it loads; core's default says no strip is shown, so core never
-- reaches into the other addon by name: the harness boundary rule)
function ns.LogTrayOn() return false end
function ns.LogWanted(kind)
    if ns.ConsoleWindowOn and ns.ConsoleWindowOn() then return true end
    if ns.LogTrayOn and ns.LogTrayOn() then return true end
    if ns.RecordOn and ns.RecordOn(kind) then return true end
    return false
end
-- ns.LogKind(kind, fmt, ...): the same, with the debug record's category for the line ("rule", "snapshot" ...; DebugRecord.lua)
local logKind = "log"
function ns.LogKind(kind, fmt, ...)
    logKind = kind or "log"
    local ok, err = pcall(ns.Log, fmt, ...)
    logKind = "log"
    if not ok then error(err, 0) end
end
-- one line into ns.logBuf (the console window, its Copy button, the bug report and the settings window's strip read it)
function ns.LogAppend(line)
    local b = ns.logBuf
    b[#b + 1] = line
    ns.logSerial = (ns.logSerial or 0) + 1   -- (Console.lua: which lines a closed console window has not drawn yet)
    local n = #b
    if n > 350 then   -- trim in one pass (down to 300) instead of shifting the whole array on every line
        for i = 1, 300 do b[i] = b[n - 300 + i] end
        for i = 301, n do b[i] = nil end
    end
end
function ns.Log(fmt, ...)
    local kind = logKind
    local msg = (select("#", ...) > 0) and fmt:format(...) or fmt
    local line = ("|cff888888%.1f|r %s"):format(GetTime() % 10000, msg)
    ns.LogAppend(line)
    ns.Fire("LOG", line)   -- the window's debug tray listens (XayaUI_Options)
    if ns.ConsoleSink then ns.ConsoleSink(line) end   -- the separate console window (Console.lua)
    if ns.RecordLine then ns.RecordLine(kind, msg) end   -- the saved debug record (DebugRecord.lua, Advanced Debugging)
end

-- Deep-copy helper for defaults.
local function Copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = Copy(v) end
    return o
end
ns.Copy = Copy

-- Fill missing keys from defaults without overwriting saved values.
local function Merge(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = Copy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" then
            Merge(dst[k], v)
        end
    end
end

-- (P5) the QoL "stats text" box defaults and their saved list moved to XayaUI QoL (XayaUI_QoL/StatsText.lua)

-- Fonts: blank/none = the game's default font. Built-ins plus every LibSharedMedia font that is loaded.
local BUILTIN_FONTS = {
    frizqt = { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    arialn = { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    skurri = { "Skurri", "Fonts\\SKURRI.TTF" },
    morpheus = { "Morpheus", "Fonts\\MORPHEUS.TTF" },
    -- bundled open-source fonts (SIL OFL, see Media\\Fonts\\OFL-*.txt). A new font file needs a full game restart to load.
    firasans = { "Fira Sans", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\FiraSans-Regular.ttf" },
    lato = { "Lato", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\Lato-Regular.ttf" },
    ptsans = { "PT Sans", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\PT_Sans-Web-Regular.ttf" },
    barlow = { "Barlow", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\Barlow-Regular.ttf" },
    firamono = { "Fira Mono", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\FiraMono-Regular.ttf" },
}
local BUILTIN_FONT_ORDER = { "frizqt", "arialn", "skurri", "morpheus", "firasans", "lato", "ptsans", "barlow", "firamono" }
function ns.FontList()
    local values, order = { none = "(none - game default)" }, { "none" }
    for _, k in ipairs(BUILTIN_FONT_ORDER) do values[k] = BUILTIN_FONTS[k][1]; order[#order + 1] = k end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm then
        local names = {}
        for n in pairs(lsm:HashTable("font")) do names[#names + 1] = n end
        table.sort(names)
        for _, n in ipairs(names) do values["lsm:" .. n] = n; order[#order + 1] = "lsm:" .. n end
    end
    return values, order
end
function ns.FontPath(key)
    key = ns.Val(key)
    if key then
        if BUILTIN_FONTS[key] then return BUILTIN_FONTS[key][2] end
        local n = key:match("^lsm:(.+)$")
        local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
        local p = n and lsm and lsm:Fetch("font", n, true)
        if p then return p end
    end
    return STANDARD_TEXT_FONT
end

ns.Merge = Merge

local function InitDB()
    CueRulesDB = CueRulesDB or {}
    CueRulesDB.version = CueRulesDB.version or 1
    CueRulesDB.ui = CueRulesDB.ui or {}
    if CueRulesDB.ui.trayOpen == nil then CueRulesDB.ui.trayOpen = true end
    -- Advanced Debugging defaults ON (recommended): XayaUI's own Lua errors print to chat as a system message.
    if CueRulesDB.ui.advancedDebug == nil then CueRulesDB.ui.advancedDebug = true end
    -- (P4) the rules, groups and buff bars are set up by XayaUI Rules at its own load (XayaUI_Rules/RuleDefaults.lua InitRules). (P5) The
    -- shelved QoL "stats text" boxes are XayaUI QoL's (XayaUI_QoL/StatsText.lua, its own store): nothing of them is made while it is off.
end
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")   -- (Modules.lua ns.AtLogin: one frame for every feature that waits for the login; let go once fired)
f:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" then
        f:UnregisterEvent("PLAYER_LOGIN")
        f:UnregisterEvent("ADDON_LOADED")   -- (P5) every module addon has loaded by now (none is load-on-demand)
        if ns.FireLogin then ns.FireLogin() end
        return
    end
    -- (P5) a module addon loaded: the game has set its saved variable, so its settings store opens (Modules.lua section 0c)
    if name ~= addonName then if ns.SettingsAddonLoaded then ns.SettingsAddonLoaded(name) end; return end
    InitDB()
    ns.FireReady()   -- every feature that asked through ns.WhenReady (Modules.lua), in load order (P4: the rule engine starts at XayaUI Rules' own load)
end)

-------------------------------------------------------------------------------
-- Slash commands
-- core 0.6.50 (Xaya 2026-11-05: "can't some of these be consolidated into a /xui debug _____ ? this is a LOT of noise"): /xui help
-- lists only what a player uses (16 lines, was 29); the diagnostic commands are under /xui debug <name>, and /xui debug alone lists
-- them. Their old forms (/xui perf ...) no longer run (Xaya 2026-11-06: "let's move to /xui debug ____", "7. Retire"): an unknown
-- word prints /xui help. Xaya's answers of 2026-11-06 (request log row 7): any /xui debug command opens the console window and prints
-- there ("Debug cmds open console"); /xui status and /xui auras stay as shortcuts that print in chat ("Debug + shortcut", "/xui auras
-- prints to chat instead", status "Yes, same as auras"); the old /xui debug (can the settings window load) is /xui debug loader.
-------------------------------------------------------------------------------
-- the diagnostic commands core owns: { name, fn(arg), help }. help is "name [args] (what it does)", without "/xui debug".
-- core 0.6.56 (Xaya 2026-11-06, REQUEST-LOG #81, her answers: developer diagnostics "Move all of them"; edge cases "Yes, as
-- recommended"): only these stay in core for players: status (the console form of /xui status), perf (the engine meter; "perf ui" is
-- XayaUI Dev Assist's), talents (rule creation uses the scan) and loader (for when /xui will not open the window). auras is AuraList.lua's.
-- Every other diagnostic (probe, timing, model, tracker, mods, groups, icons, media, seed, map, debuffs, loc, gamemenu, chatprobe,
-- widthprobe, perf ui) is registered by XayaUI Dev Assist (XayaUI_DevAssist/CoreDebug.lua); without it they and their help lines do
-- not exist, and core does not load their code.
-- (P4) status, perf (the engine meter) and talents are XayaUI Rules' (rules = true): they run through its "rules" service
-- (XayaUI_Rules/RuleDefaults.lua); with XayaUI Rules switched off their help lines are left out and the command says which addon it
-- needs (ns.ModuleMissingText, the same line as for any other module's command).
local function RulesSvc() return ns.Service and ns.Service("rules") end
local CORE_DEBUG = {
    { "status", function() local R = RulesSvc(); if R and R.PrintStatus then R.PrintStatus() end end, "status (every rule's answer right now, and why)", rules = true },
    { "perf", function(arg)
        if tostring(arg or ""):lower():match("^ui") then   -- settings-window rebuild timing: XayaUI Dev Assist's (it registers "perf")
            if not (ns.RunDebugCommand and ns.RunDebugCommand("perf", arg)) then
                ns.Print(("there is no debug command \"perf %s\"."):format((tostring(arg):gsub("|", "||"))))
                ns.PrintDebugHelp()
            end
        else   -- engine timing on this machine (XayaUI Rules: Engine.lua)
            local R = RulesSvc()
            if R and R.PerfCommand then R.PerfCommand(arg) else ns.Print(ns.ModuleMissingText("perf", true)) end
        end
    end, "perf [on|off] (engine timing)", rules = true },
    { "talents", function(arg) local R = RulesSvc(); if R and R.TalentCommand then R.TalentCommand(arg) end end, "talents [status|<name>] (scan every class's talents; find one by name)", rules = true },
    { "loader", function()   -- (was /xui debug window; Xaya 2026-11-06: "Rename it" -> "/xui debug loader")
        local function yn(v) return v and "yes" or "NO" end
        ns.Print(("debug: ToggleUI=%s rules=%s AceConfigDialog=%s AceConfigRegistry=%s AceGUI=%s"):format(
            yn(ns.ToggleUI), yn(RulesSvc() and RulesSvc().Rules()), yn(LibStub and LibStub("AceConfigDialog-3.0", true)),
            yn(LibStub and LibStub("AceConfigRegistry-3.0", true)), yn(LibStub and LibStub("AceGUI-3.0", true))))
        ns.Print("debug: settings window " .. (ns.Options and "loaded" or ("not loaded yet (" .. ns.ModuleState(ns.OPTIONS_ADDON) .. ")")))
    end, "loader (whether the settings window's code can load)" },
    -- (REQUEST-LOG A23 SD-34) the right-click tracker (MouseTracker.lua): off after every /reload; read-only, so it runs in combat too
    { "mouse", function(arg) if ns.MouseTrackerCommand then ns.MouseTrackerCommand(arg) end end,
        "mouse on|off (while on, each right-click that lands on a frame instead of the game world names that frame; off after every /reload)" },
}
local coreDebug, rulesDebug = {}, {}
for _, d in ipairs(CORE_DEBUG) do coreDebug[d[1]] = d[2]; rulesDebug[d[1]] = d.rules end

-- the player's commands core owns (/xui help); features add theirs through ns.RegisterCommand (Modules.lua)
local CORE_HELP = { "/xui (settings)", "/xui console (the XayaUI console: its messages, and a line to type these commands in)",
    "/xui bug (bug report)", "/xui report (debug report: XayaUI's errors and warnings with their codes, to send to Xaya)",
    "/xui unlock (drag displays and groups; again to lock)",
    "/xui status (every rule's answer right now, and why; in chat)",
    "/xui auras [target|focus|pet] [debuffs] or <spellID> (aura IDs, and whether XayaUI can follow them in combat; in chat)",
    "/xui debug (diagnostic commands, shown in the console window: lists them)",
    -- (V26) the emergency off, which works in combat, and its way back
    "/xui disable (turn every rule off right away, even in combat; they stay off until you turn them on again or reload)",
    "/xui enable (turn rules back on; in combat it waits until combat ends)" }
-- (P4) the lines above that are XayaUI Rules' commands: left out of /xui help while it is switched off
local RULES_HELP = { [CORE_HELP[5]] = true, [CORE_HELP[6]] = true, [CORE_HELP[7]] = true, [CORE_HELP[9]] = true, [CORE_HELP[10]] = true }

-- one command per line (core 0.6.46; Xaya 2026-11-05: "console print is difficult to read"): the command in the theme's accent text
-- color, what it does after it. An entry that holds two commands (" | /xui ...") is split. Pipes in the text (option lists such as
-- [on|off]) are doubled ("||"), which the game shows as one "|" (Xaya 2026-11-06 chose "Back to '|'" over "[on/off]"; the chat history
-- window, which lost a "|" and the letter after it, shows them right since Chat 0.6.17).
local function PrintCommandList(header, list, prefix)
    local items = {}
    for _, h in ipairs(list) do
        local rest = h
        while true do
            local a = rest:find(" | /xui", 1, true)
            if not a then items[#items + 1] = rest; break end
            items[#items + 1] = rest:sub(1, a - 1); rest = rest:sub(a + 3)
        end
    end
    local c = (ns.Theme and ns.Theme.cur and ns.Theme.cur.accentText) or { 0.78, 0.62, 1 }
    local hex = ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
    ns.Print(header:format(#items))
    for _, h in ipairs(items) do
        local cmdText, desc = h:match("^(.-)%s*(%b())$")
        if not cmdText or cmdText == "" then cmdText, desc = h, nil end
        local line = "  " .. hex .. (prefix or "") .. (cmdText:gsub("|", "||")) .. "|r"
        if desc then line = line .. "  " .. (desc:sub(2, -2):gsub("|", "||")) end
        ns.Print(line)
    end
end
function ns.PrintHelp()
    local help = {}
    local rulesOn = RulesSvc() ~= nil
    for _, h in ipairs(CORE_HELP) do if rulesOn or not RULES_HELP[h] then help[#help + 1] = h end end
    for _, h in ipairs(ns.CommandHelp()) do help[#help + 1] = h end
    PrintCommandList("commands (%d):", help)
end
function ns.PrintDebugHelp()
    local help = {}
    local rulesOn = RulesSvc() ~= nil
    for _, d in ipairs(CORE_DEBUG) do
        if rulesOn or not d.rules then
            for _, h in ipairs(type(d[3]) == "table" and d[3] or { d[3] }) do help[#help + 1] = h end
        end
    end
    for _, h in ipairs(ns.DebugCommandHelp and ns.DebugCommandHelp() or {}) do help[#help + 1] = h end
    PrintCommandList("debug commands (%d), each typed as /xui debug <name>:", help, "/xui debug ")
end
-- /xui debug <name> [args]
local function RunDebug(arg)
    local sub, rest = tostring(arg or ""):match("^(%S*)%s*(.-)$")
    if sub == "" or sub == "help" then ns.PrintDebugHelp()
    elseif coreDebug[sub] and rulesDebug[sub] and not RulesSvc() and sub ~= "perf" then ns.Print(ns.ModuleMissingText(sub, true))
    elseif coreDebug[sub] then coreDebug[sub](rest)
    elseif ns.RunDebugCommand and ns.RunDebugCommand(sub, rest) then   -- a feature's own (Modules.lua ns.RegisterDebugCommand)
    elseif ns.ModuleMissingText(sub, true) then ns.Print(ns.ModuleMissingText(sub, true))   -- a feature's, whose addon is off
    else
        ns.Print(("there is no debug command \"%s\"."):format((sub:gsub("|", "||"))))
        ns.PrintDebugHelp()
    end
end

-- /xui status and /xui auras: their /xui debug command, printed in chat (Xaya 2026-11-06). An error goes to the game's error handler
-- with ns.chatRunning still set, then it is cleared.
local SHORTCUTS = { status = true, auras = true }
local function RunInChat(fn, ...)
    local prev, args, n = ns.chatRunning, { ... }, select("#", ...)
    ns.chatRunning = true
    xpcall(function() fn(unpack(args, 1, n)) end, function(e) local h = geterrorhandler and geterrorhandler(); if h then pcall(h, e) end end)
    ns.chatRunning = prev
end
local function RunShortcut(name, arg)
    if coreDebug[name] and rulesDebug[name] and not RulesSvc() then ns.Print(ns.ModuleMissingText(name))
    elseif coreDebug[name] then coreDebug[name](arg)
    elseif ns.RunDebugCommand and ns.RunDebugCommand(name, arg) then
    elseif ns.ModuleMissingText(name) then ns.Print(ns.ModuleMissingText(name))   -- (P4) /xui auras with XayaUI Rules off
    else ns.PrintHelp() end
end

-- (V26) /xui disable and /xui enable: the Rules on-off switch (XayaUI_Rules/Engine.lua ns.SetRulesDisabled, through the "rules" service).
-- disable is exempt from the combat lock (Modules.lua section 6b: her words, "The only thing that can be allowed in combat ... is
-- /disable"); enable is locked (it changes combat tracking): in combat it says so in one line and runs when combat ends.
local function RulesEnableNow()
    local R = RulesSvc()
    if not (R and R.SetDisabled) then return end
    -- (V26) rules start fresh, as after a /reload (Engine.lua ns.SetRulesDisabled cleared each rule's state): said in the same line
    if R.SetDisabled(false) then ns.Print("rules are on again. They start fresh, as after a /reload, so each rule's On Initialization actions run again.") end
end
local function RulesSwitch(cmd)
    local R = RulesSvc()
    if not (R and R.SetDisabled) then ns.Print(ns.ModuleMissingText(cmd)); return end
    if cmd == "disable" then
        if ns.CombatLockCancel then ns.CombatLockCancel("enable") end   -- a waiting /xui enable is dropped: the newest word wins
        if R.SetDisabled(true) then
            -- (V26) only what is true: the engine stops checking (Engine.lua), every XayaUI display hides (Visual.lua; the game's aura
            -- containers fade in a fight and hide when it ends, Combat/AuraDisplay.lua), glows stop (Actions.lua), the game-played aura
            -- sounds are taken back (AuraSound.lua). A sound or spoken line already playing is not cut off: it finishes.
            ns.Print("every rule is off now: rules stop checking, and their displays, glows and sounds stop (a sound already playing finishes). Type /xui enable to turn them back on (a /reload also does).")
        else
            ns.Print("rules are already off. Type /xui enable to turn them back on.")
        end
    elseif not R.Disabled() then
        if ns.CombatLockCancel then ns.CombatLockCancel("enable") end
        ns.Print("rules are already on.")
    else
        ns.CombatLock("enable", RulesEnableNow, "rules can't be turned back on during combat. They will turn on when combat ends.")
    end
end

SLASH_XAYAUI1 = "/xui"
SLASH_XAYAUI2 = "/xayaui"
SlashCmdList["XAYAUI"] = function(msg)
    msg = (msg or ""):lower()
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "config" or cmd == "options" then
        ns.ToggleUI()   -- loads XayaUI_Options on first use (Modules.lua section 7)
    elseif cmd == "debug" then
        -- (Xaya 2026-11-06: "Debug cmds open console") opens the console window and prints there; Console.lua ns.RunInConsole
        if ns.RunInConsole then ns.RunInConsole(true, RunDebug, arg) else RunDebug(arg) end
    elseif SHORTCUTS[cmd] then
        RunInChat(RunShortcut, cmd, arg)
    elseif cmd == "unlock" then
        local R = RulesSvc()
        if not (R and R.ToggleUnlock) then ns.Print(ns.ModuleMissingText("unlock"))
        -- (V26) only OPENING the mover is locked in combat: one line, and it opens when combat ends (opens, never toggles shut: it may be
        -- open by then). Closing is never held back: an open mover view closes at once, as out of combat (Visual.lua ns.ToggleUnlock).
        elseif ns.InCombatLock and ns.InCombatLock() and not (R.Unlocked and R.Unlocked()) then
            ns.CombatLock("unlock", function() if not (R.Unlocked and R.Unlocked()) then R.ToggleUnlock() end end,
                "the mover (/xui unlock) can't open during combat. It will open when combat ends.")
        else R.ToggleUnlock() end
    elseif cmd == "disable" or cmd == "enable" then
        RulesSwitch(cmd)
    elseif cmd == "console" then
        if ns.ConsoleWindow then ns.ConsoleWindow() end
    elseif cmd == "bug" then
        if ns.ShowBugReport then ns.ShowBugReport() end
    elseif cmd == "report" then   -- (core 0.6.56; REQUEST-LOG #82: the debug report window, DebugRecord.lua)
        if ns.ShowDebugReport then ns.ShowDebugReport() end
    elseif ns.RunCommand(cmd, arg) then   -- a feature's own command (Modules.lua: ns.RegisterCommand)
    elseif ns.ModuleMissingText(cmd) then   -- a feature's command whose addon is off or failed to load
        ns.Print(ns.ModuleMissingText(cmd))
    else
        ns.PrintHelp()
    end
end
