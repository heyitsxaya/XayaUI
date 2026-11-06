-------------------------------------------------------------------------------
-- DebugRecord.lua : XayaUI's error record and the debug report (Settings > Debugging, "Advanced Debugging"; /xui report).
-- core 0.6.56 (REQUEST-LOG #82; Xaya 2026-11-06, her words: the debug record is "only there to catch errors and bugs that might be
-- expected within a live, user-facing version of the addon. these should have error codes built out, auto detection, and auto
-- documenting with a simple debug report that someone can directly send to me -- either via import/export string or screenshot").
-- Her answers (question box, 2026-11-06): default "On, errors only"; kinds "Errors + warnings only"; report "Both: string and
-- screenshot view".
--
--  * The record: XayaUI's errors and warnings, each with a code (ns.ERROR_CODES below: XUI-E001 ...), found on their own:
--      - Lua errors raised in a XayaUI file (Core.lua chains the game's error handler: the handler set before is always called too;
--        an error from another addon's file is not recorded);
--      - failures XayaUI already catches (a rule, an engine step, a display, the settings window, the ESC menu: E010-E014);
--      - warnings: an action the game blocked (W001), the combat engine's own safety stops and failed aura containers (W002-W004), a
--        Chat Panel part that could not be applied (W005).
--    Kept in CueRulesDB.errorLog (saved between sessions; the same list the bug report reads), newest first, one entry per code and
--    message with a count, at most MAX_ENTRIES. On by default (Advanced Debugging); off records nothing.
--    Cost while nothing goes wrong: none. Nothing is created per frame or per event: the error handler runs only on an error, and the
--    one event frame (made only while Advanced Debugging is on) listens to the two events the game raises when it blocks an action.
--  * The debug report (/xui report, and the button on Settings > Debugging): a window with a readable summary for a screenshot (codes,
--    what happened, addon versions, game build, when) and a "Copy string" box with the same entries as one text (XUIREP1:...), which
--    XayaUI Dev Assist reads back (/xuidev report).
--  * Where XayaUI's messages go (ns.MessageDest): "chat", "console" (the XayaUI console window, Console.lua) or "both".
--  * What to send (ns.SendText / ns.SavedFilePath): the saved-data files to upload and where they are, as copyable text.
-- The detailed record (the 11 kinds of line: rules firing, snapshots, auras, game state, performance ...) is XayaUI Dev Assist's since
-- core 0.6.56 (her answer "Errors + warnings only"): XayaUI_DevAssist/DevRecord.lua puts ns.RecordLine and the other hand-in points in
-- place when it loads; without it they are nil, and every caller tests that first (one nil test, no text built).
-------------------------------------------------------------------------------
local _, ns = ...
local issecret = ns.IsSecret or issecretvalue or function() return false end

local MAX_ENTRIES = 50   -- (her design asked for "a capped list (e.g. last 50)"; the cap is one of the questions in the report)
local DR = {}
ns.DebugRecordInfo = DR

local function Ui()
    if type(CueRulesDB) ~= "table" then return {} end
    CueRulesDB.ui = CueRulesDB.ui or {}
    return CueRulesDB.ui
end
local function Plain(s)
    s = tostring(s or "")
    return (s:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
DR.Plain = Plain
local function Version(name)
    local ok, v = pcall(function() return C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(name or "XayaUI", "Version") end)
    return (ok and type(v) == "string" and v) or "?"
end
DR.Version = Version
function ns.AdvancedDebugOn() return Ui().advancedDebug and true or false end

-- "chat" | "console" | "both"
function ns.MessageDest()
    local u = Ui()
    local d = u.msgDest
    if d == "chat" or d == "console" or d == "both" then return d end
    return u.advancedDebug and "console" or "chat"
end

-- (ns.RecordOn(kind), ns.RecordLine and the other hand-in points of the detailed record are XayaUI Dev Assist's: nil without it, and
-- every caller tests that first. The error record below is kept while Advanced Debugging is on: ns.AdvancedDebugOn.)

-------------------------------------------------------------------------------
-- The codes. One line each says what it means (the same list is in the USER-GUIDE, "Debug report").
-------------------------------------------------------------------------------
ns.ERROR_CODES = {
    { code = "XUI-E001", kind = "error", folder = "XayaUI",          text = "Lua error in XayaUI (core: rules, displays, sounds, the combat engine)" },
    { code = "XUI-E002", kind = "error", folder = "XayaUI_Options",  text = "Lua error in the settings window (XayaUI Options)" },
    { code = "XUI-E003", kind = "error", folder = "XayaUI_Chat",     text = "Lua error in XayaUI Chat" },
    { code = "XUI-E004", kind = "error", folder = "XayaUI_QoL",      text = "Lua error in XayaUI QoL (Character Toolkit, Shopping List, cursor)" },
    { code = "XUI-E005", kind = "error", folder = "XayaUI_Bonus",    text = "Lua error in XayaUI Bonus Features (tooltips, notepad, data panels, calculator)" },
    { code = "XUI-E006", kind = "error", folder = "XayaUI_Reskin",   text = "Lua error in XayaUI Blizzard Reskin" },
    { code = "XUI-E007", kind = "error", folder = "XayaUI_DevAssist", text = "Lua error in XayaUI Dev Assist (the developer tool)" },
    { code = "XUI-E008", kind = "error", folder = "XayaUI_Media",    text = "Lua error in XayaUI Media (the player's own pictures and sounds list)" },
    { code = "XUI-E009", kind = "error",                              text = "Lua error in another XayaUI folder" },
    { code = "XUI-E010", kind = "error", text = "A rule's action, sound or test failed; XayaUI caught it and the other rules kept running" },
    { code = "XUI-E011", kind = "error", text = "An engine step failed; XayaUI caught it and the engine kept running" },
    { code = "XUI-E012", kind = "error", text = "A display could not be drawn or refreshed; XayaUI caught it" },
    { code = "XUI-E013", kind = "error", text = "Moving a display or group in the settings window failed; XayaUI caught it" },
    { code = "XUI-E014", kind = "error", text = "The ESC menu button or its look failed; XayaUI caught it" },
    { code = "XUI-W001", kind = "warning", text = "The game blocked or forbade an action of XayaUI (ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN)" },
    { code = "XUI-W002", kind = "warning", text = "The combat engine could not set up an aura display; XayaUI draws that display itself" },
    { code = "XUI-W003", kind = "warning", text = "Engine safety stop: Blizzard's aura containers cost too much, so only this spec's displays are drawn by the engine (lean mode)" },
    { code = "XUI-W004", kind = "warning", text = "Engine safety stop: still too costly in lean mode, so automatic engine drawing is off until /reload" },
    { code = "XUI-W005", kind = "warning", text = "A part of the Chat Panel could not be applied" },
}
local CODE, FOLDER_CODE = {}, {}
for _, c in ipairs(ns.ERROR_CODES) do
    CODE[c.code] = c
    if c.folder then FOLDER_CODE[c.folder] = c.code end
end
function ns.ErrorCodeInfo(code) return CODE[code] end
-- the code of a Lua error from this XayaUI folder
function DR.CodeOfFolder(folder) return FOLDER_CODE[folder] or "XUI-E009" end

-------------------------------------------------------------------------------
-- The list (CueRulesDB.errorLog). Entry: { code, kind = "error" | "warning", msg, stack, first, last, n, ver, combat }
-------------------------------------------------------------------------------
local function List()
    if type(CueRulesDB) ~= "table" then return nil end
    if type(CueRulesDB.errorLog) ~= "table" then CueRulesDB.errorLog = {} end
    return CueRulesDB.errorLog
end
-- every entry, newest first; an entry saved before 0.6.56 (no code) is given the code of the folder its text names
function ns.ErrorEntries()
    local l = List() or {}
    for _, e in ipairs(l) do
        if type(e) == "table" and not e.code then
            local folder = ns.ErrorFolder and ns.ErrorFolder(e.msg, e.stack)
            e.code = folder and DR.CodeOfFolder(folder) or "XUI-E001"
            e.kind = "error"
        end
    end
    return l
end
local function InCombat()
    local ok, v = pcall(function() return UnitAffectingCombat and UnitAffectingCombat("player") end)
    return (ok and v == true) or nil
end
-- One entry, or one more count on an equal one. Must never raise an error itself (it runs inside the error handler).
local function Add(code, kind, msg, stack, folder)
    if not ns.AdvancedDebugOn() then return end
    local l = List()
    if not l then return end
    local text = Plain(msg):sub(1, 700)
    local now = time and time() or 0
    for i, e in ipairs(l) do
        if type(e) == "table" and e.code == code and e.msg == text then
            e.n = (e.n or 1) + 1; e.last = now; e.combat = e.combat or InCombat()
            if i > 1 then table.remove(l, i); table.insert(l, 1, e) end   -- newest first
            return e
        end
    end
    local e = { code = code, kind = kind, msg = text, stack = (stack and stack ~= "") and Plain(stack):sub(1, 900) or nil,
        first = now, last = now, n = 1, ver = Version(folder or "XayaUI"), combat = InCombat() }
    table.insert(l, 1, e)
    while #l > MAX_ENTRIES do table.remove(l) end
    if ns.Log then pcall(ns.Log, ("|cffff5555%s|r %s (/xui report): %s"):format(code, kind == "warning" and "warning" or "error", text:sub(1, 120))) end
    return e
end
-- A Lua error. folder: the XayaUI folder it came from (Core.lua ns.ErrorFolder), or nil; code: a fixed code (E010-E014), or nil for
-- the folder's code.
function ns.RecordError(msg, stack, folder, code)
    if not code then
        folder = folder or (ns.ErrorFolder and ns.ErrorFolder(msg, stack)) or "XayaUI"
        code = DR.CodeOfFolder(folder)
    end
    return Add(code, "error", msg, stack, folder)
end
-- A warning: code (XUI-W...) and one line of detail
function ns.RecordWarn(code, detail)
    return Add(code, "warning", (CODE[code] and CODE[code].text or code) .. (detail and detail ~= "" and (": " .. tostring(detail)) or ""), nil, nil)
end
-- (kept for the callers that existed before 0.6.56: Visual.lua, GameMenu.lua, Options.lua, GameMenuSkin.lua)
function ns.CaptureError(msg, stack, code) return ns.RecordError(msg, stack, nil, code) end
-- errors and warnings, counted: total occurrences, different entries, errors, warnings
function ns.ErrorCount()
    local n, err, warn = 0, 0, 0
    local l = ns.ErrorEntries()
    for _, e in ipairs(l) do
        n = n + (e.n or 1)
        if e.kind == "warning" then warn = warn + 1 else err = err + 1 end
    end
    return n, #l, err, warn
end
function ns.ClearErrorLog() if type(CueRulesDB) == "table" then CueRulesDB.errorLog = {} end end

-------------------------------------------------------------------------------
-- What to send, and where it is
-------------------------------------------------------------------------------
-- The game's folder for this client: _retail_, or a test / beta client's own folder.
function DR.GameFolder()
    local okB, beta = pcall(function() return IsBetaBuild and IsBetaBuild() end)
    if okB and beta == true then return "_beta_" end
    local okP, ptr = pcall(function() return IsPublicTestClient and IsPublicTestClient() end)
    if okP and ptr == true then return "_ptr_" end
    return "_retail_"
end
-- The full path of an account-wide saved-data file. The game gives addons no way to read the account folder's name, so that part is a
-- placeholder the player replaces (the text from ns.SendText says how to find it).
function ns.SavedFilePath(fileName)
    return ("World of Warcraft\\%s\\WTF\\Account\\<YOUR ACCOUNT FOLDER>\\SavedVariables\\%s"):format(DR.GameFolder(), tostring(fileName))
end
-- Every file to send: XayaUI's own, plus the developer addon's when it is installed (it says its file name through its service).
function DR.Files()
    local files = { { file = "XayaUI.lua", what = "your rules and settings, and XayaUI's saved errors and warnings" } }
    local svc = ns.Service and ns.Service("gameDataProbe")
    if svc and type(svc.savedFile) == "string" and svc.savedFile ~= "" then
        files[#files + 1] = { file = svc.savedFile, what = svc.savedWhat or "the developer captures (probe, data pulls)" }
    end
    return files
end
function ns.SendText()
    local t = {}
    local function add(s) t[#t + 1] = s end
    add("WHAT TO SEND")
    add("Quickest: /xui report, then send a screenshot of it, or press Copy string and paste the text to Xaya.")
    add("The files (when Xaya asks for them):")
    add("1. Type /reload (or log out). The game writes the files only then.")
    add("2. Open this folder (copy the path, then replace <YOUR ACCOUNT FOLDER>):")
    add("   " .. ns.SavedFilePath(""))
    add("   <YOUR ACCOUNT FOLDER> is the folder inside WTF\\Account with your account's name, often a number such as 12345678#1. If")
    add("   there are several, use the one whose SavedVariables folder holds the newest XayaUI.lua.")
    if DR.GameFolder() == "_ptr_" then add("   (On a test client the game folder can also be called _xptr_.)") end
    add("3. Send these files to Xaya (attach them to a Discord message or a GitHub issue):")
    for _, f in ipairs(DR.Files()) do add(("   - %s  (%s)"):format(f.file, f.what)) end
    add("They hold no password, no character name, no realm and no chat text. XayaUI.lua holds your rule names and settings.")
    return table.concat(t, "\n")
end

-------------------------------------------------------------------------------
-- Messages into the console window
-------------------------------------------------------------------------------
-- private (ns.PrintPrivate, e.g. a message naming another player): drawn in the open window and tray only, never put in ns.logBuf,
-- which the bug report, "Copy" and a reopened window read.
local pendingOpen = false
function ns.ConsoleMessage(text, isError, private)
    local line = (isError and "|cffff5555[XayaUI error]|r " or "|cff33ccffXayaUI|r: ") .. tostring(text)
    if not private then ns.LogAppend(line) end   -- (Core.lua: ns.logBuf, trimmed to its last 300 lines past 350)
    if ns.Fire then ns.Fire("LOG", line) end
    if ns.ConsoleSink then ns.ConsoleSink(line, private) end
    if ns.MessageDest() == "console" and Ui().consoleAutoOpen ~= false and ns.ConsoleWindowOn and not ns.ConsoleWindowOn() then
        if InCombatLockdown and InCombatLockdown() then
            pendingOpen = true
            if DR.SyncEvents then DR.SyncEvents() end   -- (the end of combat opens it: PLAYER_REGEN_ENABLED, registered for that only)
        elseif ns.ConsoleWindow then pcall(ns.ConsoleWindow, true) end
    end
end

-- What a function prints, collected instead of shown (Core.lua ns.Print reads ns._capture)
function ns.CaptureOutput(fn, ...)
    local prev = ns._capture
    local out = {}
    ns._capture = out
    local ok, err = pcall(fn, ...)
    ns._capture = prev
    if not ok then out[#out + 1] = "(error: " .. tostring(err) .. ")" end
    return out
end

-------------------------------------------------------------------------------
-- Events (rule V14). One frame, made the first time something needs an event, holding only what is needed now:
--   ADDON_ACTION_BLOCKED, ADDON_ACTION_FORBIDDEN  while Advanced Debugging is on (the game raises them only when it blocks an action
--                                                 of an addon: nothing arrives while nothing goes wrong)
--   PLAYER_REGEN_ENABLED                          only while a console window waits for the end of combat (ns.ConsoleMessage above)
-- XayaUI Dev Assist adds its own detailed-record events through DR.extraEvents / DR.extraHandlers (XayaUI_DevAssist/DevRecord.lua).
-- Game API (docs/reference/api/events.md): ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN (isTainted: cstring, function: cstring);
-- widgets.md, Frame: RegisterEvent(eventName) -> registered: bool; UnregisterEvent(eventName) -> registered: bool.
-------------------------------------------------------------------------------
local handlers = {}
local function Blocked(event, tainted, func)
    if type(tainted) ~= "string" or issecret(tainted) or not tainted:find("^XayaUI") then return end
    ns.RecordWarn("XUI-W001", ("the game %s %s's call to %s"):format(event == "ADDON_ACTION_FORBIDDEN" and "forbade" or "blocked",
        tainted, (func ~= nil and not issecret(func)) and tostring(func) or "?"))
    if ns.RecordLine then pcall(ns.RecordLine, "blocked", ("the game %s %s's call to %s (%s)"):format(event == "ADDON_ACTION_FORBIDDEN" and "forbade" or "blocked",
        tainted, tostring(func), event)) end
end
function handlers.ADDON_ACTION_BLOCKED(t, f) Blocked("ADDON_ACTION_BLOCKED", t, f) end
function handlers.ADDON_ACTION_FORBIDDEN(t, f) Blocked("ADDON_ACTION_FORBIDDEN", t, f) end
function handlers.PLAYER_REGEN_ENABLED()
    if DR.extraHandlers and DR.extraHandlers.PLAYER_REGEN_ENABLED then pcall(DR.extraHandlers.PLAYER_REGEN_ENABLED) end
    if pendingOpen then
        pendingOpen = false
        if ns.ConsoleWindow then pcall(ns.ConsoleWindow, true) end
        DR.SyncEvents()
    end
end
DR.handlers = handlers
local RECORD_EVENTS = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }
DR.RECORD_EVENTS = RECORD_EVENTS
local evFrame
local evOn = {}   -- [event] = true while registered on evFrame
local function OnEvent(_, event, ...)
    local h = handlers[event] or (DR.extraHandlers and DR.extraHandlers[event])
    if h then
        local ok, err = pcall(h, ...)
        if not ok then pcall(ns.RecordError, "debug record: " .. tostring(err), nil, "XayaUI") end
    end
end
local function Wanted()
    local want = {}
    if ns.AdvancedDebugOn() then for _, e in ipairs(RECORD_EVENTS) do want[e] = true end end
    if pendingOpen then want.PLAYER_REGEN_ENABLED = true end
    if DR.extraEvents then for e in pairs(DR.extraEvents() or {}) do want[e] = true end end
    return want
end
function DR.SyncEvents()
    local want = Wanted()
    if not evFrame then
        if next(want) == nil or not CreateFrame then return end
        evFrame = CreateFrame("Frame")
        if evFrame.SetScript then evFrame:SetScript("OnEvent", OnEvent) end
    end
    for e in pairs(evOn) do
        if not want[e] then pcall(evFrame.UnregisterEvent, evFrame, e); evOn[e] = nil end
    end
    for e in pairs(want) do
        if not evOn[e] then pcall(evFrame.RegisterEvent, evFrame, e); evOn[e] = true end
    end
end
-- (tests) the events registered now, as a set
function DR.EventsOn() local t = {}; for e in pairs(evOn) do t[e] = true end; return t end

-- Settings > Debugging calls this after a change (and XayaUI Dev Assist's settings after theirs)
function ns.DebugSettingsChanged()
    DR.SyncEvents()
    if ns.DevRecordChanged then pcall(ns.DevRecordChanged) end   -- (XayaUI Dev Assist's detailed record and probe switch)
end
if ns.WhenReady then ns.WhenReady(function() DR.SyncEvents() end) end

-------------------------------------------------------------------------------
-- The debug report: the same entries as a readable summary (for a screenshot) and as one string (to paste to Xaya)
-------------------------------------------------------------------------------
local REPORT_PREFIX, REPORT_V = "XUIREP1", 1
DR.REPORT_PREFIX = REPORT_PREFIX
local function Clock(t) return (type(t) == "number" and date) and date("%m-%d %H:%M", t) or "?" end
-- The data both views are made from (also what the string carries).
function ns.DebugReportData()
    local d = { v = REPORT_V, made = date and date("%Y-%m-%d %H:%M:%S") or "?", on = ns.AdvancedDebugOn(), entries = {}, addons = {} }
    local okB, ver, build = pcall(GetBuildInfo)
    d.game, d.build = okB and tostring(ver) or "?", okB and tostring(build) or "?"
    local okL, loc = pcall(function() return GetLocale and GetLocale() end)
    d.locale = okL and tostring(loc) or "?"
    d.client = DR.GameFolder() == "_retail_" and "live" or (DR.GameFolder() == "_beta_" and "beta" or "test realm")
    if C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo then
        local okN, total = pcall(C_AddOns.GetNumAddOns)
        for i = 1, (okN and tonumber(total)) or 0 do
            local okI, name = pcall(C_AddOns.GetAddOnInfo, i)
            if okI and type(name) == "string" and name:find("^XayaUI") then
                local okD, _, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
                d.addons[#d.addons + 1] = { name = name, ver = Version(name), loaded = (okD and loaded) and true or false }
            end
        end
    end
    for _, e in ipairs(ns.ErrorEntries()) do
        d.entries[#d.entries + 1] = { code = e.code, kind = e.kind, msg = tostring(e.msg or ""):sub(1, 300),
            stack = e.stack and tostring(e.stack):sub(1, 600) or nil, first = e.first, last = e.last, n = e.n or 1, ver = e.ver,
            combat = e.combat and true or nil }
    end
    return d
end
-- The readable summary. expanded: also each error's stack (XayaUI Dev Assist shows an imported report this way).
function ns.DebugReportText(d, expanded)
    d = d or ns.DebugReportData()
    local t = {}
    local function add(s) t[#t + 1] = s end
    add(("XayaUI debug report  -  made %s (local time)"):format(tostring(d.made)))
    add(("Game %s (build %s), %s client, locale %s"):format(tostring(d.game), tostring(d.build), tostring(d.client), tostring(d.locale)))
    local a = {}
    for _, x in ipairs(type(d.addons) == "table" and d.addons or {}) do
        a[#a + 1] = ("%s %s%s"):format(tostring(x.name):gsub("^XayaUI_", ""), tostring(x.ver), x.loaded and "" or " (off)")
    end
    add("XayaUI addons: " .. (#a > 0 and table.concat(a, ", ") or "?"))
    local entries = type(d.entries) == "table" and d.entries or {}
    local ne, nw = 0, 0
    for _, e in ipairs(entries) do if e.kind == "warning" then nw = nw + 1 else ne = ne + 1 end end
    if d.on == false then add("Advanced Debugging is OFF: nothing new is recorded (Settings > Debugging).") end
    add(("%d entr%s: %d error%s, %d warning%s (the newest %d are kept)"):format(#entries, #entries == 1 and "y" or "ies", ne,
        ne == 1 and "" or "s", nw, nw == 1 and "" or "s", MAX_ENTRIES))
    if #entries == 0 then add(""); add("No errors or warnings recorded.") end
    for _, e in ipairs(entries) do
        local info = CODE[e.code]
        add("")
        add(("%s  x%d  %s"):format(tostring(e.code), tonumber(e.n) or 1, info and info.text or "(unknown code)"))
        add(("   first %s, last %s%s, version %s"):format(Clock(e.first), Clock(e.last), e.combat and ", in combat" or "", tostring(e.ver or "?")))
        add("   " .. tostring(e.msg or ""):gsub("\n", " / "))
        if expanded and e.stack and e.stack ~= "" then add("   stack: " .. tostring(e.stack):gsub("\n", " / ")) end
    end
    return table.concat(t, "\n")
end
-- The string: XUIREP1:<checksum>:<base64 of JSON> (Share.lua's codec; not importable as rules or a theme)
function ns.DebugReportString(d)
    if not (ns.Share and ns.Share.Pack) then return nil, "the share codec is not loaded" end
    return ns.Share.Pack(REPORT_PREFIX, d or ns.DebugReportData())
end
-- The string back to the data (XayaUI Dev Assist's import); nil, message when it cannot be read. Only plain fields are kept.
function ns.DebugReportRead(str)
    if not (ns.Share and ns.Share.Unpack) then return nil, "the share codec is not loaded" end
    local d, err = ns.Share.Unpack(str, REPORT_PREFIX)
    if not d then return nil, err end
    if tonumber(d.v) ~= REPORT_V then return nil, ("Unsupported debug report format (version %s)."):format(tostring(d.v)) end
    local function str_(v, n) return type(v) == "string" and v:sub(1, n or 1000) or (type(v) == "number" and tostring(v)) or nil end
    local out = { v = REPORT_V, made = str_(d.made, 40), game = str_(d.game, 40), build = str_(d.build, 40), locale = str_(d.locale, 10),
        client = str_(d.client, 20), on = d.on ~= false, addons = {}, entries = {} }
    for _, x in ipairs(type(d.addons) == "table" and d.addons or {}) do
        if type(x) == "table" then out.addons[#out.addons + 1] = { name = str_(x.name, 60) or "?", ver = str_(x.ver, 30) or "?", loaded = x.loaded == true } end
    end
    for _, e in ipairs(type(d.entries) == "table" and d.entries or {}) do
        if type(e) == "table" then
            out.entries[#out.entries + 1] = { code = str_(e.code, 12) or "?", kind = e.kind == "warning" and "warning" or "error",
                msg = str_(e.msg, 300) or "", stack = str_(e.stack, 600), first = tonumber(e.first), last = tonumber(e.last),
                n = tonumber(e.n) or 1, ver = str_(e.ver, 30), combat = e.combat == true or nil }
        end
    end
    return out
end

-- The window (made the first time it opens). Top: the summary, framed for a screenshot. Bottom: the string, and "Copy string".
local win
local function BuildWindow()
    local f = CreateFrame("Frame", "XayaUIDebugReport", UIParent, "BackdropTemplate")
    local M, G = ns.UI_MARGIN or 10, ns.UI_GUTTER or 10
    f:SetSize(680, 460)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.06, 0.06, 0.07, 0.97)
    f:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", M, -M)
    f.title:SetText("XayaUI debug report")
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.hint:SetPoint("RIGHT", f, "RIGHT", -(M + 24), 0)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetText("Send Xaya a screenshot of this window, or press Copy string and paste the text to her.")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    -- the string row along the bottom: a one-line box with the string and the button
    local copy = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copy:SetSize(110, 24); copy:SetPoint("BOTTOMRIGHT", -M, M); copy:SetText("Copy string")
    if ns.FlatButton then ns.FlatButton(copy, true) end
    local sbox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    sbox:SetHeight(24)
    sbox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", M, M); sbox:SetPoint("RIGHT", copy, "LEFT", -G, 0)
    sbox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    sbox:SetBackdropColor(0, 0, 0, 0.5); sbox:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    sbox:SetFontObject(ChatFontNormal); sbox:SetTextInsets(6, 6, 0, 0)
    sbox:SetAutoFocus(false); sbox:SetMaxLetters(0)
    sbox:SetScript("OnEscapePressed", function() f:Hide() end)
    sbox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    copy:SetScript("OnClick", function() sbox:SetFocus(); sbox:HighlightText() end)
    f.str, f.copy = sbox, copy
    -- the summary
    local sf = CreateFrame("ScrollFrame", "XayaUIDebugReportScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", M, -50); sf:SetPoint("BOTTOMRIGHT", -(M + 22), M + 24 + G)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(680 - 2 * M - 30); eb:SetMaxLetters(0)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    sf:SetScrollChild(eb)
    f.text = eb
    if UISpecialFrames then table.insert(UISpecialFrames, "XayaUIDebugReport") end
    return f
end
function ns.ShowDebugReport()
    if not CreateFrame then return end
    win = win or BuildWindow()
    local d = ns.DebugReportData()
    win.text:SetText(ns.DebugReportText(d))
    win.str:SetText(ns.DebugReportString(d) or "")
    win:Show()
    return win
end
function ns.DebugReportWindow() return win end   -- (tests)
