-------------------------------------------------------------------------------
-- DebugRecord.lua : what "Advanced Debugging" (Settings > Debugging) turns on.
-- core 0.6.20 (Xaya 2026-11-04: "enabling advanced [should] facilitate automatic tracking ... (some sort of dump file) of what you
-- would need so a user doesn't have to remember console lines", "the messages should also print to their own frame either like bug
-- sack or in their own dedicated chat panel"); core 0.6.22 (Xaya 2026-11-04: "user-readable and cpu friendly (perhaps discrete
-- functionality toggles ...) and a notation with a copy/paste file path so users know what to upload", "configurable to cover every
-- single thing you need to properly debug something from game-side").
--
--  * Where XayaUI's messages go (ns.MessageDest): "chat", "console" (the XayaUI console window, Console.lua) or "both". Default: the
--    console window while Advanced Debugging is on, chat while it is off.
--  * The record (CueRulesDB.debugRecord): kept while Advanced Debugging is on, in CATEGORIES the player switches on and off one by one
--    (DR.CATS: what each holds and what it costs). A category that is off costs nothing beyond one settings read where its lines would
--    start. Errors, combat marks and actions the game blocked are always kept. Each line reads "time  Category  what happened".
--  * What to send (ns.SendText / ns.SavedFilePath): the saved-data files to upload and where they are, as copyable text.
--  * The game-data probe (separate developer addon, service "gameDataProbe", Modules.lua): follows Advanced Debugging when wanted.
-- Nothing here names another addon: the console window is core (Console.lua), the developer addon is a service.
-------------------------------------------------------------------------------
local _, ns = ...
local issecret = ns.IsSecret or issecretvalue or function() return false end

local DEFAULT_MAX = 3000
local SIZES = { [1000] = true, [3000] = true, [10000] = true }

local DR = {}
ns.DebugRecordInfo = DR

-- The categories, in the order Settings shows them. cost: what switching it on costs, in words the player can weigh.
DR.CATS = {
    { key = "rules", label = "Rule", name = "Rules firing and clearing", default = true, cost = "tiny",
      desc = "One line when a rule fires, repeats or clears, with the reason it cleared." },
    { key = "snapshots", label = "Snapshot", name = "Rule snapshots in combat", default = true, cost = "small",
      desc = "Every switched-on rule's answer at the start and end of each combat, and the ones that changed, every 5 seconds in combat." },
    { key = "auras", label = "Aura", name = "Aura answers", default = true, cost = "small",
      desc = "One line when an aura's answer (present, missing, unknown) or the source that gave it changes: the aura list, the Cooldown Manager, a proc glow, a set bonus, an estimate." },
    { key = "triggers", label = "Trigger", name = "Trigger detail for chosen rules", default = false, cost = "small for each chosen rule",
      desc = "For the rules you pick below: one line each time the rule's answer or any part of it changes (cooldown, aura and its source, talent, extra triggers, combination, load), with why it does not fire." },
    { key = "displays", label = "Display", name = "Displays shown and hidden", default = false, cost = "small",
      desc = "One line each time a rule's display appears or goes, and whether XayaUI or the combat engine draws it." },
    { key = "glows", label = "Glow", name = "Proc glows", default = true, cost = "tiny",
      desc = "Each proc-glow sighting used to pair a button's glow with an aura, and what the aura was at that moment." },
    { key = "sounds", label = "Sound", name = "Sounds", default = true, cost = "tiny",
      desc = "Each sound a rule plays (which sound, channel, volume, what the game answered) and the set-up of sounds the game plays itself." },
    { key = "game", label = "Game", name = "Game state", default = true, cost = "tiny",
      desc = "Login and /reload (versions, game build, screen size, UI scale), spec, talent and gear changes, zone and instance (difficulty, instance ID, map ID), boss encounters (ID, difficulty, group size, kill or wipe), Mythic+ start and end (map and level), group size, and what the game hides from addons at each combat start." },
    { key = "engine", label = "Engine", name = "Combat engine status at combat end", default = true, cost = "tiny",
      desc = "What /xuiengine prints, collected at the end of each combat." },
    { key = "perf", label = "Perf", name = "Performance", default = false, cost = "a small timer on every engine step, in combat only",
      desc = "Times XayaUI's engine during each combat and records, at its end, the cost per second (rules, displays, bars, effects), the slowest rules, memory, and the game's own per-addon CPU meter." },
    { key = "messages", label = "Message", name = "XayaUI's messages", default = true, cost = "tiny",
      desc = "Every message XayaUI shows you. Messages that name another player are never kept." },
}
local CAT = {}
for _, c in ipairs(DR.CATS) do CAT[c.key] = c end

-- line kind -> category (kinds not listed are always kept while recording: error, blocked, combat, note)
local KIND_CAT = { rule = "rules", log = "rules", snapshot = "snapshots", aura = "auras", trigger = "triggers", display = "displays",
    glow = "glows", sound = "sounds", game = "game", session = "game", engine = "engine", perf = "perf", msg = "messages" }
local LABEL = { rule = "Rule", log = "Rule", snapshot = "Snapshot", aura = "Aura", trigger = "Trigger", display = "Display",
    glow = "Glow", sound = "Sound", game = "Game", session = "Session", engine = "Engine", perf = "Perf", msg = "Message",
    error = "ERROR", blocked = "BLOCKED", combat = "Combat", note = "Note" }
DR.KIND_CAT, DR.LABEL = KIND_CAT, LABEL

local function Ui()
    if type(CueRulesDB) ~= "table" then return {} end
    CueRulesDB.ui = CueRulesDB.ui or {}
    return CueRulesDB.ui
end
local function Plain(s)
    s = tostring(s or "")
    return (s:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
local function S(v)   -- any game value as text; a hidden (secret) one says so instead of erroring
    if v == nil then return "?" end
    if issecret(v) then return "<hidden>" end
    return tostring(v)
end

local function Version(name)
    local ok, v = pcall(function() return C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(name or "XayaUI", "Version") end)
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

-- Is this category on? (Advanced Debugging on, the record kept, and the category on: its own setting, else its default)
function ns.RecCatOn(key)
    local u = Ui()
    if not (u.advancedDebug and u.recordOff ~= true) then return false end
    local c = u.recCats
    -- (not `type(c) == "table" and c[key] or nil`: a stored false would turn into nil and read as the default)
    local v
    if type(c) == "table" then v = c[key] end
    if v == nil then local d = CAT[key]; return d and d.default or false end
    return v and true or false
end
-- The category's own setting, whatever Advanced Debugging is (for the Settings tick boxes)
function ns.RecCatSetting(key)
    local c = Ui().recCats
    -- (not `type(c) == "table" and c[key] or nil`: a stored false would turn into nil and read as the default)
    local v
    if type(c) == "table" then v = c[key] end
    if v == nil then local d = CAT[key]; return d and d.default or false end
    return v and true or false
end
function ns.SetRecCat(key, on)
    if not CAT[key] then return end
    local u = Ui()
    u.recCats = type(u.recCats) == "table" and u.recCats or {}
    if (on and true or false) == CAT[key].default then u.recCats[key] = nil else u.recCats[key] = on and true or false end
    if next(u.recCats) == nil then u.recCats = nil end
    if DR.SyncEvents then DR.SyncEvents() end   -- (V14: a category's events are registered only while it is on)
end
-- presets: "light" (rules, game state, messages: the cheapest useful set), "all", "default"
function ns.SetRecPreset(which)
    for _, c in ipairs(DR.CATS) do
        local on
        if which == "all" then on = true
        elseif which == "light" then on = (c.key == "rules" or c.key == "game" or c.key == "messages")
        else on = c.default end
        ns.SetRecCat(c.key, on)
    end
end

-- Is a line of this kind kept now? (no kind: is the record on at all)
function ns.RecordOn(kind)
    local u = Ui()
    if not (u.advancedDebug and u.recordOff ~= true) then return false end
    local cat = kind and KIND_CAT[kind]
    if not cat then return true end
    return ns.RecCatOn(cat)
end

function DR.MaxLines()
    local n = tonumber(Ui().recordMax)
    return (n and SIZES[n]) and n or DEFAULT_MAX
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

-- kind: a short word (see LABEL); text: one line (colours are dropped). Each line reads "HH:MM:SS  Category  text".
function ns.RecordLine(kind, text)
    if not ns.RecordOn(kind) then return end
    local r = Rec()
    if not r then return end
    local l = r.lines
    l[#l + 1] = ("%s  %-8s %s"):format(date and date("%H:%M:%S") or "?", LABEL[kind] or tostring(kind or "?"), Plain(text))
    local n, max = #l, DR.MaxLines()
    if n > max + 200 then   -- trim in one pass (down to max), counting what is dropped
        local cut = n - max
        for i = 1, max do l[i] = l[i + cut] end
        for i = max + 1, n do l[i] = nil end
        r.dropped = (r.dropped or 0) + cut
    end
end

function ns.ClearRecord()
    if type(CueRulesDB) == "table" then CueRulesDB.debugRecord = nil end
    if ns.ResetRecordedAuras then ns.ResetRecordedAuras() end
end

function ns.RecordSummary()
    local r = type(CueRulesDB) == "table" and CueRulesDB.debugRecord
    if type(r) ~= "table" or type(r.lines) ~= "table" then return 0, 0, nil end
    return #r.lines, r.dropped or 0, r.started
end

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
    local files = { { file = "XayaUI.lua", what = "your rules and settings, XayaUI's saved errors and the debug record" } }
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

-- The record as one readable text: what each category means, then the lines (for the "View the debug record" box).
function ns.RecordText()
    local n, drop, start = ns.RecordSummary()
    local t = {}
    local function add(s) t[#t + 1] = s end
    add(("XayaUI debug record: %d lines since %s%s. Newest at the bottom."):format(n, tostring(start or "-"),
        drop > 0 and (", " .. drop .. " older lines dropped") or ""))
    add("Each line: time, what it is about, what happened. Categories:")
    for _, c in ipairs(DR.CATS) do add(("  %-8s %s%s"):format(c.label, c.name, ns.RecCatOn(c.key) and "" or "  (off now)")) end
    add("  ERROR    XayaUI's own Lua errors;  BLOCKED  an action the game refused XayaUI;  Combat  combat start and end;  Session  login and /reload")
    add("")
    local r = type(CueRulesDB) == "table" and CueRulesDB.debugRecord
    if type(r) == "table" and type(r.lines) == "table" and #r.lines > 0 then
        for _, l in ipairs(r.lines) do add(l) end
    else
        add("(empty so far: it fills as you play)")
    end
    add("")
    add(ns.SendText())
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
-- Lines other files hand in (each checks its category first, so an off category builds no text)
-------------------------------------------------------------------------------
-- Trigger detail for the chosen rules (Engine.lua calls this for every rule on every step: the first test is one upvalue).
local triggerWatch = false   -- true while the category is on and at least one rule is chosen (DR.Refresh)
local trigLast = setmetatable({}, { __mode = "k" })
local function Focused(rule)
    local f = Ui().recFocus
    if type(f) ~= "table" then return false end
    if rule.uid and f[rule.uid] then return true end
    return rule.parentUid ~= nil and f[rule.parentUid] and true or false
end
local function SourceKind(src)   -- "aura API | time: ..." -> "aura API" (the part that names where the answer came from)
    local k = tostring(src or ""):match("^([^%(:|]+)") or tostring(src)
    return (k:gsub("%s+$", ""))
end
function ns.RecTrigger(rule, result, info)
    if not triggerWatch or type(rule) ~= "table" or not Focused(rule) then return end
    if not ns.RecCatOn("triggers") then return end
    local i = type(info) == "table" and info or {}
    local key = table.concat({ tostring(result), tostring(i.cdOK), tostring(i.buffOK), SourceKind(i.buffSource), tostring(i.talentOK),
        tostring(i.extraOK), tostring(i.whenOK), tostring(i.ctxOK), tostring(i.ctxFail) }, "|")
    if trigLast[rule] == key then return end
    trigLast[rule] = key
    local name = ("'%s'%s"):format(tostring(rule.name), rule.isCue and " (cue)" or (rule.parentUid and " (condition)" or ""))
    if result then
        ns.RecordLine("trigger", ("%s fires | aura %s via %s | cooldown %s | extra %s"):format(name, S(i.buffOK), S(i.buffSource), S(i.cdOK),
            S(i.extraOK)))
    else
        local why = (ns.WhyNot and type(info) == "table") and ns.WhyNot(info) or "no answer"
        ns.RecordLine("trigger", ("%s does not fire: %s"):format(name, why ~= "" and why or "(every part holds, but the rule did not fire)"))
    end
end
-- A display appeared or went (Engine.lua, only on a change).
function ns.RecDisplay(rule, shown, byEngine)
    if not ns.RecCatOn("displays") then return end
    ns.RecordLine("display", ("'%s' display %s%s"):format(tostring(rule and rule.name), shown and "shown" or "hidden",
        shown and (byEngine and " (drawn by the combat engine)" or " (drawn by XayaUI)") or ""))
end
-- A sound a rule played (Engine.lua).
function ns.RecSound(rule, how, result, note)
    if not ns.RecCatOn("sounds") then return end
    ns.RecordLine("sound", ("'%s': %s%s%s"):format(tostring(rule and rule.name), tostring(how or "?"),
        result ~= nil and (" | the game returned " .. S(result)) or "", note and (" | " .. note) or ""))
end

-------------------------------------------------------------------------------
-- The game-data probe (developer addon) follows Advanced Debugging when the player wants it
-------------------------------------------------------------------------------
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

-- Recompute what other files test on their hot paths (call after any change to the debugging settings)
function DR.Refresh()
    local f = Ui().recFocus
    triggerWatch = ns.RecCatOn("triggers") and type(f) == "table" and next(f) ~= nil or false
end

local function OnList()
    local on = {}
    for _, c in ipairs(DR.CATS) do if ns.RecCatOn(c.key) then on[#on + 1] = c.label end end
    return #on > 0 and table.concat(on, ", ") or "nothing but errors and combat marks"
end

-- Settings > Debugging calls this after a change
function ns.DebugSettingsChanged()
    DR.Refresh()
    if DR.SyncEvents then DR.SyncEvents() end
    SyncProbe()
    if ns.ResetRecordedAuras then ns.ResetRecordedAuras() end
    if ns.RecordOn() then
        ns.RecordLine("note", ("recording: %s | messages to %s | keeps %d lines | XayaUI %s"):format(OnList(), ns.MessageDest(),
            DR.MaxLines(), Version()))
    end
end

-------------------------------------------------------------------------------
-- Game state (category "game") and the combat marks
-------------------------------------------------------------------------------
local function Where()
    local ok, name, itype, diffID, diffName, _, _, _, instID = pcall(GetInstanceInfo)
    if not ok then return "?" end
    local s = S(name)
    if itype and not issecret(itype) and itype ~= "none" then
        s = s .. (" (%s, %s, difficulty %s, instance %s)"):format(S(itype), S(diffName), S(diffID), S(instID))
    end
    local okM, map = pcall(function() return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") end)
    if okM and type(map) == "number" and not issecret(map) then s = s .. ", map " .. map end
    return s
end
local function Hides()
    local function B(fn)
        local f = C_Secrets and C_Secrets[fn]
        if not f then return "?" end
        local ok, v = pcall(f)
        if not ok or issecret(v) then return "?" end
        return v and "yes" or "no"
    end
    return ("the game hides auras: %s, cooldowns: %s"):format(B("ShouldAurasBeSecret"), B("ShouldCooldownsBeSecret"))
end
local function GroupSize()
    local okN, n = pcall(function() return GetNumGroupMembers and GetNumGroupMembers() end)
    local okR, raid = pcall(function() return IsInRaid and IsInRaid() end)
    n = (okN and type(n) == "number" and not issecret(n)) and n or nil
    return n, (okR and raid == true)
end
local function SessionLines(why)
    local out = {}
    local okB, ver, build = pcall(GetBuildInfo)
    local client = DR.GameFolder() == "_retail_" and "live" or (DR.GameFolder() == "_beta_" and "beta" or "test realm")
    local okL, loc = pcall(function() return GetLocale and GetLocale() end)
    out[#out + 1] = ("%s | game %s (build %s), %s client, locale %s"):format(why, okB and S(ver) or "?", okB and S(build) or "?", client,
        okL and S(loc) or "?")
    local parts = {}
    if C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo then
        local okN, total = pcall(C_AddOns.GetNumAddOns)
        for i = 1, (okN and tonumber(total)) or 0 do
            local okI, name = pcall(C_AddOns.GetAddOnInfo, i)
            if okI and type(name) == "string" and name:find("^XayaUI") then
                local okD, _, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
                local okE, err = pcall(function() return C_AddOns.DoesAddOnHaveLoadError and C_AddOns.DoesAddOnHaveLoadError(name) end)
                parts[#parts + 1] = ("%s %s%s%s"):format(name, Version(name), (okD and loaded) and "" or " (not loaded)",
                    (okE and err == true) and " LOAD ERROR" or "")
            end
        end
    end
    out[#out + 1] = "XayaUI addons: " .. (#parts > 0 and table.concat(parts, ", ") or "?")
    local okS, w, h = pcall(function() return GetPhysicalScreenSize() end)
    local okU, sc = pcall(function() return UIParent:GetEffectiveScale() end)
    local nr, on, nc, ncond = 0, 0, 0, 0
    for _, r in ipairs(ns.rules or {}) do
        if r.isCue then nc = nc + 1 elseif r.parentUid then ncond = ncond + 1 else nr = nr + 1; if r.enabled then on = on + 1 end end
    end
    out[#out + 1] = ("screen %sx%s, UI scale %s | rules %d (%d on), cues %d, conditions %d | spec %s"):format(okS and S(w) or "?",
        okS and S(h) or "?", (okU and type(sc) == "number") and ("%.3f"):format(sc) or "?", nr, on, nc, ncond,
        S(ns.CurrentSpecID and ns.CurrentSpecID()))
    out[#out + 1] = "recording: " .. OnList()
    return out
end
DR.SessionLines = SessionLines

local combatN, combatT0, perfByDebug, lastGroup = 0, nil, false, nil
local function Game(text) if ns.RecCatOn("game") then ns.RecordLine("game", text) end end

-- (V14: every handler checks its switch before it reads the game or builds text; the events themselves are registered only while
-- their category is on, DR.SyncEvents below)
local handlers = {}
-- at login (not an event of this file since core 0.6.47: core's start-up frame runs it, Modules.lua ns.AtLogin, and only when Advanced
-- Debugging is on or a probe it started has to be stopped)
function handlers.PLAYER_LOGIN()
    DR.Refresh()
    SyncProbe()
end
function handlers.PLAYER_ENTERING_WORLD(isLogin, isReload)
    if not ns.RecordOn() then return end
    if not ns.RecCatOn("game") then return end
    if isLogin or isReload then
        for _, l in ipairs(SessionLines(isLogin and "login" or "/reload")) do ns.RecordLine("session", l) end
    end
    Game("now in: " .. Where())
end
function handlers.ZONE_CHANGED_NEW_AREA()
    if not ns.RecCatOn("game") then return end
    Game("zone: " .. Where())
end
function handlers.PLAYER_SPECIALIZATION_CHANGED(unit)
    if unit ~= nil and unit ~= "player" then return end
    if not ns.RecCatOn("game") then return end
    Game("specialization now " .. S(ns.CurrentSpecID and ns.CurrentSpecID()))
end
function handlers.TRAIT_CONFIG_UPDATED(configID)
    if not ns.RecCatOn("game") then return end
    Game("talents changed (talent loadout " .. S(configID) .. ")")
end
function handlers.PLAYER_EQUIPMENT_CHANGED(slot, hasCurrent)
    if not ns.RecCatOn("game") then return end
    local okI, item = pcall(function() return GetInventoryItemID and GetInventoryItemID("player", slot) end)
    Game(("gear: slot %s now %s"):format(S(slot), (hasCurrent and okI and item) and ("item " .. S(item)) or "empty"))
end
function handlers.ENCOUNTER_START(id, name, diff, size)
    if not ns.RecCatOn("game") then return end
    Game(("boss encounter %s '%s' starts (difficulty %s, %s players)"):format(S(id), S(name), S(diff), S(size)))
end
function handlers.ENCOUNTER_END(id, name, diff, size, success)
    if not ns.RecCatOn("game") then return end
    local res = (success == 1) and "kill" or ((success == 0) and "wipe" or S(success))
    Game(("boss encounter %s '%s' ends: %s (difficulty %s, %s players)"):format(S(id), S(name), res, S(diff), S(size)))
end
function handlers.CHALLENGE_MODE_START(mapID)
    if not ns.RecCatOn("game") then return end
    local okK, level = pcall(function() return C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo and C_ChallengeMode.GetActiveKeystoneInfo() end)
    Game(("Mythic+ starts: challenge map %s, keystone level %s | %s"):format(S(mapID), okK and S(level) or "?", Where()))
end
function handlers.CHALLENGE_MODE_COMPLETED() Game("Mythic+ completed") end
function handlers.GROUP_ROSTER_UPDATE()
    if not ns.RecCatOn("game") then return end
    local n, raid = GroupSize()
    local k = tostring(n) .. (raid and "r" or "")
    if k == lastGroup then return end
    lastGroup = k
    Game(("group: %s members%s"):format(S(n), raid and " (raid)" or ""))
end
local function Blocked(event, tainted, func)
    if not ns.RecordOn() then return end
    if type(tainted) ~= "string" or issecret(tainted) or not tainted:find("^XayaUI") then return end
    ns.RecordLine("blocked", ("the game %s %s's call to %s (%s)"):format(event == "ADDON_ACTION_FORBIDDEN" and "forbade" or "blocked",
        tainted, S(func), event))
end
function handlers.ADDON_ACTION_BLOCKED(t, f) Blocked("ADDON_ACTION_BLOCKED", t, f) end
function handlers.ADDON_ACTION_FORBIDDEN(t, f) Blocked("ADDON_ACTION_FORBIDDEN", t, f) end
function handlers.PLAYER_REGEN_DISABLED()
    if ns.RecordOn() then
        combatN = combatN + 1
        combatT0 = GetTime and GetTime() or nil
        ns.RecordLine("combat", ("---------- combat %d starts | %s%s ----------"):format(combatN, Where(),
            ns.RecCatOn("game") and (" | " .. Hides()) or ""))
        -- the engine's timer runs for this combat only, unless the player started it (/xui perf)
        if ns.RecCatOn("perf") and ns.PerfCommand and not ns.perfOn then
            ns.CaptureOutput(ns.PerfCommand, "on"); perfByDebug = true
        end
    end
end
function handlers.PLAYER_REGEN_ENABLED()
    if ns.RecordOn() then
        local secs = (combatT0 and GetTime) and (GetTime() - combatT0) or nil
        ns.RecordLine("combat", ("---------- combat %d ends%s ----------"):format(combatN, secs and (" after %.0f s"):format(secs) or ""))
        if ns.RecCatOn("engine") and ns.AuraDisplay and ns.AuraDisplay.Status then
            for _, l in ipairs(ns.CaptureOutput(ns.AuraDisplay.Status)) do ns.RecordLine("engine", l) end
        end
        if ns.RecCatOn("perf") and ns.perfOn and ns.PerfCommand then
            for _, l in ipairs(ns.CaptureOutput(ns.PerfCommand, "")) do ns.RecordLine("perf", l) end
        end
    end
    local extra = perfByDebug or pendingOpen   -- (this event was registered for them too: let it go now if nothing else needs it)
    if perfByDebug and ns.PerfCommand then ns.CaptureOutput(ns.PerfCommand, "off"); perfByDebug = false end
    if pendingOpen then
        pendingOpen = false
        if ns.ConsoleWindow then pcall(ns.ConsoleWindow, true) end
    end
    if extra then DR.SyncEvents() end
end
DR.handlers = handlers

-------------------------------------------------------------------------------
-- The record's events (core 0.6.47, rule V14; Xaya 2026-11-05: "anything that is disabled in the addon through a tick box should
-- NEVER LOAD or contribute to performance cost / demand in any way"). One frame, made the first time something needs an event, holding
-- only what is switched on now:
--   blocked actions, combat start and end  while the record is kept (Advanced Debugging on and "Keep the debug record" ticked)
--   the game-state events                  while the record is kept and its "Game state" category is on
--   PLAYER_REGEN_ENABLED                   also while a performance timer started by the record, or a console window waiting for the
--                                          end of combat (message routing, ns.ConsoleMessage above), needs the end of combat
-- Advanced Debugging off: no frame and no event (the frame, once made, stays without events: the game cannot delete a frame).
-- Called at login (settings ready), after every Settings > Debugging change (ns.DebugSettingsChanged, ns.SetRecCat) and from the
-- handlers above. Game API (docs/reference/api/widgets.md, Frame): RegisterEvent(eventName) -> registered: bool;
-- UnregisterEvent(eventName) -> registered: bool.
-------------------------------------------------------------------------------
local GAME_EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED",
    "PLAYER_EQUIPMENT_CHANGED", "ENCOUNTER_START", "ENCOUNTER_END", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED",
    "GROUP_ROSTER_UPDATE" }
local RECORD_EVENTS = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
DR.GAME_EVENTS, DR.RECORD_EVENTS = GAME_EVENTS, RECORD_EVENTS
local evFrame
local evOn = {}   -- [event] = true while registered on evFrame
local function OnEvent(_, event, ...)
    local h = handlers[event]
    if h then
        local ok, err = pcall(h, ...)
        if not ok and ns.RecordLine then pcall(ns.RecordLine, "error", "debug record: " .. tostring(err)) end
    end
end
local function Wanted()
    local want = {}
    if ns.RecordOn() then
        for _, e in ipairs(RECORD_EVENTS) do want[e] = true end
        if ns.RecCatOn("game") then for _, e in ipairs(GAME_EVENTS) do want[e] = true end end
    end
    if perfByDebug or pendingOpen then want.PLAYER_REGEN_ENABLED = true end
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
-- at login the saved settings decide (ns.WhenReady runs at XayaUI's ADDON_LOADED, after Core.lua set the defaults); the login itself
-- (the game-data probe follows Advanced Debugging: its addon is loaded by then) only when Advanced Debugging is on, or when a probe it
-- started is still to be stopped
if ns.WhenReady then
    ns.WhenReady(function()
        DR.Refresh(); DR.SyncEvents()
        local u = Ui()
        if (u.advancedDebug or u.probeByDebug) and ns.AtLogin then ns.AtLogin(handlers.PLAYER_LOGIN) end
    end)
end
