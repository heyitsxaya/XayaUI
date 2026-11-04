-------------------------------------------------------------------------------
-- DebugRecord.lua : what "Advanced Debugging" (Settings > Debugging) turns on (core 0.6.20, Xaya 2026-11-04: "enabling advanced
-- [should] facilitate automatic tracking ... (some sort of dump file) of what you would need so a user doesn't have to remember
-- console lines", and "the messages should also print to their own frame either like bug sack or in their own dedicated chat panel").
--
--  * Where XayaUI's messages go (ns.MessageDest): "chat" (as before), "console" (the XayaUI console window, Console.lua: its own
--    movable frame that keeps collecting in combat) or "both". Default: the console window while Advanced Debugging is on, chat while
--    it is off. With "console" the window opens by itself when a message arrives (after combat, if one arrives in combat).
--  * The record (ns.RecordOn): while Advanced Debugging is on, every console line, every XayaUI message and every XayaUI error is kept
--    in CueRulesDB.debugRecord (newest MAX lines, oldest dropped and counted). At the end of each combat the combat engine's status is
--    added (what /xuiengine would print), and other files add what only they know (aura answer changes, glow sightings, aura-sound
--    set-up). The game writes it to the SavedVariables file at /reload or logout; "Create debug report" shows it as copyable text.
--  * The game-data probe (XayaUI Game Data Capture, a separate addon): when it is installed it provides the "gameDataProbe" service
--    (Modules.lua); Advanced Debugging switches it on (and off again only if it was the one that switched it on).
-- Nothing here names another addon: the console window is core (Console.lua), the probe is a service.
-------------------------------------------------------------------------------
local _, ns = ...

local MAX = 3000

local function Ui()
    if type(CueRulesDB) ~= "table" then return {} end
    CueRulesDB.ui = CueRulesDB.ui or {}
    return CueRulesDB.ui
end
local function Plain(s)
    s = tostring(s or "")
    return (s:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Version()
    local ok, v = pcall(function() return C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("XayaUI", "Version") end)
    return (ok and v) or "?"
end
function ns.AdvancedDebugOn() return Ui().advancedDebug and true or false end

-- "chat" | "console" | "both"
function ns.MessageDest()
    local u = Ui()
    local d = u.msgDest
    if d == "chat" or d == "console" or d == "both" then return d end
    return u.advancedDebug and "console" or "chat"
end

function ns.RecordOn()
    local u = Ui()
    return (u.advancedDebug and u.recordOff ~= true) and true or false
end

local function Rec()
    if type(CueRulesDB) ~= "table" then return nil end
    local r = CueRulesDB.debugRecord
    if type(r) ~= "table" or type(r.lines) ~= "table" then
        r = { lines = {}, dropped = 0, started = date and date("%Y-%m-%d %H:%M:%S") or "?" }
        CueRulesDB.debugRecord = r
    end
    return r
end

-- kind: a short word ("log", "msg", "error", "engine", "aura", "glow", "sound" ...); text: one line (colours are dropped)
function ns.RecordLine(kind, text)
    if not ns.RecordOn() then return end
    local r = Rec()
    if not r then return end
    local l = r.lines
    l[#l + 1] = ("%s %s %s"):format(date and date("%H:%M:%S") or "?", tostring(kind or "?"), Plain(text))
    local n = #l
    if n > MAX + 200 then   -- trim in one pass (down to MAX), counting what is dropped
        local cut = n - MAX
        for i = 1, MAX do l[i] = l[i + cut] end
        for i = MAX + 1, n do l[i] = nil end
        r.dropped = (r.dropped or 0) + cut
    end
end

function ns.ClearRecord()
    if type(CueRulesDB) == "table" then CueRulesDB.debugRecord = nil end
end

function ns.RecordSummary()
    local r = type(CueRulesDB) == "table" and CueRulesDB.debugRecord
    if type(r) ~= "table" or type(r.lines) ~= "table" then return 0, 0, nil end
    return #r.lines, r.dropped or 0, r.started
end

-- A message into the console window (and its event log), opening the window when the player chose "console" and it is closed.
-- private (ns.PrintPrivate, e.g. a message naming another player): drawn in the open window and tray only, never put in ns.logBuf,
-- which the bug report, "Copy" and a reopened window read.
local pendingOpen = false
function ns.ConsoleMessage(text, isError, private)
    local line = (isError and "|cffff5555[XayaUI error]|r " or "|cff33ccffXayaUI|r: ") .. tostring(text)
    local b = (not private) and ns.logBuf or nil
    if b then
        b[#b + 1] = line
        local n = #b
        if n > 350 then for i = 1, 300 do b[i] = b[n - 300 + i] end; for i = 301, n do b[i] = nil end end
    end
    if ns.Fire then ns.Fire("LOG", line) end
    if ns.ConsoleSink then ns.ConsoleSink(line) end
    if ns.MessageDest() == "console" and Ui().consoleAutoOpen ~= false and ns.ConsoleWindowOn and not ns.ConsoleWindowOn() then
        if InCombatLockdown and InCombatLockdown() then pendingOpen = true
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

-- The game-data probe (separate addon) follows Advanced Debugging when the player wants it (default: yes, when it is installed)
local function SyncProbe()
    local svc = ns.Service and ns.Service("gameDataProbe")
    if not (svc and type(svc.On) == "function" and type(svc.Active) == "function") then return end
    local u = Ui()
    local want = u.advancedDebug and u.debugProbe ~= false
    local okA, active = pcall(svc.Active)
    active = okA and active
    if want and not active then
        if pcall(svc.On) then u.probeByDebug = true end
    elseif not want and active and u.probeByDebug then
        pcall(svc.Off); u.probeByDebug = nil
    end
end
ns.SyncDebugProbe = SyncProbe
function ns.ProbeInstalled()
    local svc = ns.Service and ns.Service("gameDataProbe")
    return (svc and type(svc.On) == "function") and true or false
end

-- Settings > Debugging calls this after a change
function ns.DebugSettingsChanged()
    SyncProbe()
    if ns.RecordOn() then
        ns.RecordLine("note", "recording on: XayaUI " .. Version() .. ", messages to " .. ns.MessageDest())
    end
end

if CreateFrame then
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do pcall(f.RegisterEvent, f, e) end
    if f.SetScript then
        f:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_LOGIN" then
                SyncProbe()
                if ns.RecordOn() then
                    local okB, ver, build = pcall(GetBuildInfo)
                    ns.RecordLine("session", ("login: XayaUI %s, game %s (%s)"):format(Version(), okB and tostring(ver) or "?", okB and tostring(build) or "?"))
                end
            elseif event == "PLAYER_REGEN_DISABLED" then
                if ns.RecordOn() then ns.RecordLine("combat", "combat start") end
            elseif event == "PLAYER_REGEN_ENABLED" then
                if ns.RecordOn() then
                    ns.RecordLine("combat", "combat end")
                    -- the combat engine's status, as /xuiengine prints it (collected, not shown)
                    if ns.AuraDisplay and ns.AuraDisplay.Status then
                        for _, l in ipairs(ns.CaptureOutput(ns.AuraDisplay.Status)) do ns.RecordLine("engine", l) end
                    end
                end
                if pendingOpen then
                    pendingOpen = false
                    if ns.ConsoleWindow then pcall(ns.ConsoleWindow, true) end
                end
            end
        end)
    end
end
