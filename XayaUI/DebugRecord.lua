-------------------------------------------------------------------------------
-- DebugRecord.lua : XayaUI's error record, Settings > Debugging's "Advanced Debugging", and the loader of the debug tools (XayaUI_Debug).
-- core 0.6.56 (REQUEST-LOG #82; Xaya 2026-11-06, her words: the debug record is "only there to catch errors and bugs that might be
-- expected within a live, user-facing version of the addon. these should have error codes built out, auto detection, and auto
-- documenting with a simple debug report that someone can directly send to me -- either via import/export string or screenshot").
-- Her answers (question box, 2026-11-06): kinds "Errors + warnings only"; report "Both: string and screenshot view".
-- Round 7 (REQUEST-LOG A23 SD-58: the debug tools load only while "Debugging" is on; SD-61: Advanced Debugging "Off by default
-- (Recommended)"; SD-64: a saved "on" is kept, and every login or /reload while it is on prints one chat line; V34).
--
--  * The record: XayaUI's errors and warnings, each with a code (ns.ERROR_CODES below: XUI-E001 ...), found on their own:
--      - Lua errors raised in a XayaUI file (Core.lua chains the game's error handler: the handler set before is always called too;
--        an error from another addon's file is not recorded);
--      - failures XayaUI already catches (a rule, an engine step, a display, the settings window, the ESC menu: E010-E014);
--      - warnings: an action the game blocked (W001), the combat engine's own safety stops and failed aura containers (W002-W004), a
--        Chat Panel part that could not be applied (W005).
--    Kept in CueRulesDB.errorLog (saved between sessions; the same list the bug report reads), newest first, one entry per code and
--    message with a count, at most MAX_ENTRIES, while Advanced Debugging is on; off records nothing. The record stays here in core,
--    so it works whether or not the debug tools have loaded (turned on during a session, it records at once; the tools load at the
--    next /reload and show what was recorded).
--    Cost while nothing goes wrong: none. Nothing is created per frame or per event: the error handler runs only on an error, and the
--    one event frame (made only while Advanced Debugging is on) listens to the two events the game raises when it blocks an action.
--  * The debug tools (XayaUI_Debug, load-on-demand): the console window, the bug report (/xui bug) and the debug report window
--    (/xui report). Loaded once per login or /reload, at the login, only while Advanced Debugging is on; nothing else loads them.
--    While they are not loaded, each of them, /xui status, /xui auras and the /xui debug words in the debug folder print one plain line
--    saying what they need (ns.DebugToolsNeeded); /xui debug loader and talents, which stay in core, still run (Core.lua DEBUG_UNGATED).
--  * Where XayaUI's messages go (ns.MessageDest): "chat", "console" (the console window, XayaUI_Debug) or "both"; always chat while
--    the console window's addon is not loaded.
--  * What to send (ns.SendText / ns.SavedFilePath): the saved-data files to upload and where they are, as copyable text.
-- The detailed record (the 11 kinds of line: rules firing, snapshots, auras, game state, performance ...) is XayaUI Dev Assist's since
-- core 0.6.56 (her answer "Errors + warnings only"): XayaUI_DevAssist/DevRecord.lua puts ns.RecordLine and the other hand-in points in
-- place when it loads; without it they are nil, and every caller tests that first (one nil test, no text built).
-------------------------------------------------------------------------------
local _, ns = ...
local issecret = issecretvalue or function() return false end   -- (P4: was ns.IsSecret first, which is this same function, from XayaUI Rules)

local MAX_ENTRIES = 50   -- (her design asked for "a capped list (e.g. last 50)"; the cap is one of the questions in the report)
local DR = { MAX_ENTRIES = MAX_ENTRIES }
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

-- "chat" | "console" | "both". (round 7) Always "chat" while the debug tools are not loaded (Advanced Debugging off at login, the
-- default): the console window is theirs, so a saved "console" or "both" would send messages nowhere. The saved choice is kept and
-- counts again once they load.
local toolsLoaded = false
function ns.MessageDest()
    if not toolsLoaded then return "chat" end
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
    -- (P4) the rules, displays, sounds and the combat engine are the folder XayaUI_Rules now: their errors keep this code
    { code = "XUI-E001", kind = "error", folder = "XayaUI", alsoFolders = { "XayaUI_Rules" }, text = "Lua error in XayaUI (core: rules, displays, sounds, the combat engine)" },
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
    -- (P5 settings migration, Modules.lua section 0c) a module's settings copy differed from CueRulesDB: the module keeps reading CueRulesDB
    { code = "XUI-W006", kind = "warning", text = "A module's settings could not be copied to their new saved place unchanged; it keeps using the old place" },
}
local CODE, FOLDER_CODE = {}, {}
for _, c in ipairs(ns.ERROR_CODES) do
    CODE[c.code] = c
    if c.folder then FOLDER_CODE[c.folder] = c.code end
    for _, f in ipairs(c.alsoFolders or {}) do FOLDER_CODE[f] = c.code end
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
    add("Quickest: /xui report, then send a screenshot of it, or press Select string, then Ctrl+C (Cmd+C on Mac), and paste the text to Xaya.")
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
-- (round 7) Messages into the console window (ns.ConsoleMessage) are XayaUI_Debug/Console.lua's: core's ns.Print and error handler send
-- a message there only while ns.MessageDest says so, which needs that addon loaded.
-------------------------------------------------------------------------------

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
-- (round 7) The console window's wait for the end of combat is XayaUI_Debug's own (XayaUI_Debug/Console.lua); the hand-in for XayaUI
-- Dev Assist's extra events (DR.extraEvents / DR.extraHandlers) served only that retired addon and was removed.
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
DR.handlers = handlers
local RECORD_EVENTS = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }
DR.RECORD_EVENTS = RECORD_EVENTS
local evFrame
local evOn = {}   -- [event] = true while registered on evFrame
local function OnEvent(_, event, ...)
    local h = handlers[event]
    if h then
        local ok, err = pcall(h, ...)
        if not ok then pcall(ns.RecordError, "debug record: " .. tostring(err), nil, "XayaUI") end
    end
end
local function Wanted()
    local want = {}
    if ns.AdvancedDebugOn() then for _, e in ipairs(RECORD_EVENTS) do want[e] = true end end
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

-- Settings > Debugging calls this after a change. (round 7) The record's two events follow the switch at once; the debug tools
-- (XayaUI_Debug) load or go only at the next login or /reload (V34: on / off is detected once per reload; the game cannot unload code).
function ns.DebugSettingsChanged()
    DR.SyncEvents()
end
if ns.WhenReady then ns.WhenReady(function() DR.SyncEvents() end) end

-- (round 6; REQUEST-LOG A23 SD-55, Xaya's answer on the memory cuts: "Dead logs (0.2 MB)") two saved texts that nothing on main reads
-- are let go once, at the login, so they no longer sit in memory every session and in XayaUI.lua:
--   * the detailed debug record an earlier XayaUI Dev Assist left in CueRulesDB.debugRecord. While Dev Assist is installed and on it is
--     that addon's own record and stays: Dev Assist puts its hand-in points (ns.RecordSummary ...) in place when it loads, before the login;
--   * the last bug report's text (CueRulesDB.lastBugReport). /xui bug builds the report fresh each time and no longer keeps it (Console.lua).
-- One check at the login; nothing runs after it.
if ns.AtLogin then
    ns.AtLogin(function()
        if type(CueRulesDB) ~= "table" then return end
        if not ns.RecordSummary then CueRulesDB.debugRecord = nil end
        CueRulesDB.lastBugReport = nil
    end)
end

-------------------------------------------------------------------------------
-- The debug tools: XayaUI_Debug (bundle 1 round 7). REQUEST-LOG A23 SD-58, her answer: "1 but nothing loads unless "Debugging" is
-- enabled"; SD-61: Advanced Debugging "Off by default (Recommended)"; SD-64, her words: "any time a user has debugging on, logging in or
-- reloading should print to the chat pane "advanced debugging is on. to turn this off ...""; V34: off means not read, detected once per
-- reload. So: at the login (PLAYER_LOGIN, which the game raises at every login and every /reload), and only while Advanced Debugging is
-- on, core loads XayaUI_Debug (C_AddOns.LoadAddOn) once, and prints her line in chat. Nothing else loads it: with Advanced Debugging off
-- none of its files is read, and the console window, /xui bug, /xui report, /xui status, /xui auras and the debug folder's /xui debug
-- words answer with one plain line instead (ns.DebugToolsNeeded; /xui debug loader and talents still run, Core.lua DEBUG_UNGATED).
-- Turned on during a session, the tools load at the next /reload; turned off, they stay until then.
-- Game API (docs/reference/api/namespaces.md, C_AddOns, 12.1.5; each has SecretArguments=AllowedWhenUntainted, and XayaUI passes only
-- its own literal addon name):
--   C_AddOns.LoadAddOn(name: uiAddon) -> loaded: bool?, value: string?                                       (namespaces.md:164)
--   C_AddOns.GetAddOnInfo(name: uiAddon) -> name, title, notes, loadable: bool, reason: cstring, security     (namespaces.md:148)
-- INFERENCE (not documented there): reason "MISSING" means the folder is not installed and "DISABLED" that it is switched off in the
-- AddOns list (the same reading Modules.lua ns.ModuleState uses); and LoadAddOn may be called during combat lockdown (it is not marked
-- protected): a /reload in a fight still loads the tools, whose windows are exempt from the combat lock (V26).
-- V24 / V25 cost: one setting read at the login; with Advanced Debugging off nothing else, ever.
-------------------------------------------------------------------------------
DR.TOOLS_ADDON = "XayaUI_Debug"
-- her line (SD-64), with the ending she left open completed (INFERENCE, REQUEST-LOG SD-64)
DR.ON_LINE = "Advanced debugging is on. To turn this off, open /xui > Settings > Debugging."
-- (XayaUI_Debug/Tools.lua, its first file) the debug tools are here: core's debug words run them from now on
function ns.DebugToolsArrived() toolsLoaded = true end
function ns.DebugToolsLoaded() return toolsLoaded end
local toolsTried, toolsWhy = false, nil
local function LoadTools()
    if toolsLoaded or toolsTried then return end
    toolsTried = true   -- (once per reload: a refused load is not retried until the next /reload)
    local A = C_AddOns
    if not (A and A.LoadAddOn) then return end
    local ok, loaded, why = pcall(A.LoadAddOn, DR.TOOLS_ADDON)
    if not (ok and loaded) then toolsWhy = tostring((ok and why) or loaded or "?") end
end
-- One plain line saying what a debug tool needs while XayaUI_Debug is not loaded. what: "The bug report (/xui bug)" ...
function ns.DebugToolsNeeded(what)
    what = tostring(what or "This debug command")
    local reason
    local A = C_AddOns
    if A and A.GetAddOnInfo then
        local ok, name, _, _, _, why = pcall(A.GetAddOnInfo, DR.TOOLS_ADDON)
        if ok and (why == "MISSING" or not name) then reason = "missing"
        elseif ok and why == "DISABLED" then reason = "disabled" end
    end
    if reason == "missing" then
        ns.Print(what .. " is one of the debug tools (XayaUI Debug), which is not installed: the XayaUI_Debug folder belongs next to XayaUI in Interface\\AddOns.")
    elseif reason == "disabled" then
        ns.Print(what .. " is one of the debug tools (XayaUI Debug), which is switched off in the game's AddOns list. Turn it on, then type /reload.")
    elseif toolsTried then   -- (on at the login, and the game refused to load them: its reason, e.g. an out-of-date or broken folder)
        ns.Print(what .. " is one of the debug tools (XayaUI Debug), which could not load (" .. tostring(toolsWhy) .. "). Type /reload to try again.")
    elseif ns.AdvancedDebugOn() then
        ns.Print(what .. " needs a /reload: the debug tools load at the next login or /reload while Advanced Debugging is on.")
    else
        ns.Print(what .. " needs Advanced Debugging: turn it on in /xui > Settings > Debugging, then type /reload.")
    end
end
-- in chat, whatever "XayaUI's messages" says (her words: "print to the chat pane")
local function ChatLine(text)
    local prev = ns.chatRunning
    ns.chatRunning = true
    pcall(ns.Print, text)
    ns.chatRunning = prev
end
if ns.AtLogin then
    ns.AtLogin(function()
        if not ns.AdvancedDebugOn() then return end
        LoadTools()
        ChatLine(DR.ON_LINE)
    end)
end
