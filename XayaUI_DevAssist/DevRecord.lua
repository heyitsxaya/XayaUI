-------------------------------------------------------------------------------
-- DevRecord.lua (XayaUI Dev Assist 0.7.5): the detailed debug record and Dev Assist's own settings, moved out of XayaUI core.
-- Xaya, 2026-11-06 (REQUEST-LOG #82, her answer "Errors + warnings only"): players keep error and warning entries (core DebugRecord.lua,
-- with codes and /xui report); the 11 kinds of line (rules, snapshots, auras, triggers, displays, glows, sounds, game state, engine,
-- performance, messages) are recorded only while this addon is enabled. REQUEST-LOG #81, row A20: the switch "Also run the game-data
-- probe" moves to Dev Assist's own settings. Both show on XayaUI's Settings > Debugging, under "Dev Assist settings", registered here
-- (ns.RegisterSettingsPage("debugging", ...)); without this addon nothing of them exists.
-- The record works as it did in core 0.6.54 (same saved data: CueRulesDB.debugRecord, CueRulesDB.ui.recCats / recordOff / recordMax /
-- recFocus / debugProbe), and only while Advanced Debugging is on and "Keep the detailed record" is ticked: every hand-in point checks
-- its category first, and its events are registered only while their category is on (V14).
-- Also here: reading a debug report string back (/xuidev report): the same entries, expanded (with each error's stack).
-------------------------------------------------------------------------------
local ns = rawget(_G, "XayaUI_NS")
if type(ns) ~= "table" or type(ns.DebugRecordInfo) ~= "table" or type(ns.SetDebugHooks) ~= "function" then return end   -- XayaUI is off or older than 0.6.56
local DR = ns.DebugRecordInfo
local issecret = ns.IsSecret or issecretvalue or function() return false end
local Plain, Version = DR.Plain, DR.Version

local DEFAULT_MAX = 3000
local SIZES = { [1000] = true, [3000] = true, [10000] = true }

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
local function S(v)   -- any game value as text; a hidden (secret) one says so instead of erroring
    if v == nil then return "?" end
    if issecret(v) then return "<hidden>" end
    return tostring(v)
end

-- Is the detailed record kept? (Advanced Debugging on and "Keep the detailed record" ticked)
local function Kept() local u = Ui(); return (u.advancedDebug and u.recordOff ~= true) and true or false end
-- Is this category on? (the record kept, and the category on: its own setting, else its default)
function ns.RecCatOn(key)
    if not Kept() then return false end
    local c = Ui().recCats
    -- (not `type(c) == "table" and c[key] or nil`: a stored false would turn into nil and read as the default)
    local v
    if type(c) == "table" then v = c[key] end
    if v == nil then local d = CAT[key]; return d and d.default or false end
    return v and true or false
end
-- The category's own setting, whatever Advanced Debugging is (for the Settings tick boxes)
function ns.RecCatSetting(key)
    local c = Ui().recCats
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
    DR.SyncEvents()   -- (V14: a category's events are registered only while it is on)
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
-- Is a line of this kind kept now? (no kind: is the record kept at all)
local function RecordOn(kind)
    if not Kept() then return false end
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
local function RecordLine(kind, text)
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
local function RecordSummary()
    local r = type(CueRulesDB) == "table" and CueRulesDB.debugRecord
    if type(r) ~= "table" or type(r.lines) ~= "table" then return 0, 0, nil end
    return #r.lines, r.dropped or 0, r.started
end
-- The record as one readable text: what each category means, then the lines (for the "View the detailed record" box).
function ns.RecordText()
    local n, drop, start = ns.RecordSummary()
    local t = {}
    local function add(s) t[#t + 1] = s end
    add(("XayaUI detailed debug record: %d lines since %s%s. Newest at the bottom."):format(n, tostring(start or "-"),
        drop > 0 and (", " .. drop .. " older lines dropped") or ""))
    add("Each line: time, what it is about, what happened. Categories:")
    for _, c in ipairs(DR.CATS) do add(("  %-8s %s%s"):format(c.label, c.name, ns.RecCatOn(c.key) and "" or "  (off now)")) end
    add("  BLOCKED  an action the game refused XayaUI;  Combat  combat start and end;  Session  login and /reload")
    add("  (XayaUI's errors and warnings, with their codes, are in /xui report)")
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
local function RecTrigger(rule, result, info)
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
local function RecDisplay(rule, shown, byEngine)
    if not ns.RecCatOn("displays") then return end
    ns.RecordLine("display", ("'%s' display %s%s"):format(tostring(rule and rule.name), shown and "shown" or "hidden",
        shown and (byEngine and " (drawn by the combat engine)" or " (drawn by XayaUI)") or ""))
end
-- A sound a rule played (Engine.lua).
local function RecSound(rule, how, result, note)
    if not ns.RecCatOn("sounds") then return end
    ns.RecordLine("sound", ("'%s': %s%s%s"):format(tostring(rule and rule.name), tostring(how or "?"),
        result ~= nil and (" | the game returned " .. S(result)) or "", note and (" | " .. note) or ""))
end
-- Recompute what other files test on their hot paths (after any change to the debugging settings)
function DR.Refresh()
    local f = Ui().recFocus
    triggerWatch = ns.RecCatOn("triggers") and type(f) == "table" and next(f) ~= nil or false
end

-------------------------------------------------------------------------------
-- The game-data probe follows Advanced Debugging when wanted (row A20: its switch is Dev Assist's now)
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

local function OnList()
    local on = {}
    for _, c in ipairs(DR.CATS) do if ns.RecCatOn(c.key) then on[#on + 1] = c.label end end
    return #on > 0 and table.concat(on, ", ") or "nothing but combat marks"
end
-- core's ns.DebugSettingsChanged calls this after any change on Settings > Debugging
local function DevRecordChanged()
    DR.Refresh()
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
-- their category is on, Wanted below)
local handlers = {}
function handlers.PLAYER_ENTERING_WORLD(isLogin, isReload)
    if not ns.RecCatOn("game") then return end
    if isLogin or isReload then
        for _, l in ipairs(SessionLines(isLogin and "login" or "/reload")) do ns.RecordLine("session", l) end
    end
    Game("now in: " .. Where())
end
function handlers.ZONE_CHANGED_NEW_AREA() if ns.RecCatOn("game") then Game("zone: " .. Where()) end end
function handlers.PLAYER_SPECIALIZATION_CHANGED(unit)
    if unit ~= nil and unit ~= "player" then return end
    if not ns.RecCatOn("game") then return end
    Game("specialization now " .. S(ns.CurrentSpecID and ns.CurrentSpecID()))
end
function handlers.TRAIT_CONFIG_UPDATED(configID) if ns.RecCatOn("game") then Game("talents changed (talent loadout " .. S(configID) .. ")") end end
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
function handlers.PLAYER_REGEN_DISABLED()
    if not ns.RecordOn() then return end
    combatN = combatN + 1
    combatT0 = GetTime and GetTime() or nil
    ns.RecordLine("combat", ("---------- combat %d starts | %s%s ----------"):format(combatN, Where(),
        ns.RecCatOn("game") and (" | " .. Hides()) or ""))
    -- the engine's timer runs for this combat only, unless the player started it (/xui debug perf)
    if ns.RecCatOn("perf") and ns.PerfCommand and not ns.perfOn then
        ns.CaptureOutput(ns.PerfCommand, "on"); perfByDebug = true
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
    if perfByDebug and ns.PerfCommand then ns.CaptureOutput(ns.PerfCommand, "off"); perfByDebug = false; DR.SyncEvents() end
end
DR.devHandlers = handlers
local GAME_EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED",
    "PLAYER_EQUIPMENT_CHANGED", "ENCOUNTER_START", "ENCOUNTER_END", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED",
    "GROUP_ROSTER_UPDATE" }
DR.GAME_EVENTS = GAME_EVENTS
-- what core's one event frame should hold for the detailed record now (core DebugRecord.lua DR.SyncEvents asks)
DR.extraHandlers = handlers
function DR.extraEvents()
    local want = {}
    if ns.RecordOn() then
        want.PLAYER_REGEN_DISABLED, want.PLAYER_REGEN_ENABLED = true, true
        if ns.RecCatOn("game") then for _, e in ipairs(GAME_EVENTS) do want[e] = true end end
    end
    if perfByDebug then want.PLAYER_REGEN_ENABLED = true end
    return want
end
-- at login (XayaUI's settings are ready by then: this addon loads after XayaUI)
local function Start()
    DR.Refresh(); DR.SyncEvents()
    local u = Ui()
    if (u.advancedDebug or u.probeByDebug) and ns.AtLogin then ns.AtLogin(SyncProbe) end
end
-- the hand-in points core's files call (each tests for nil first), put in place through core's contract (Modules.lua ns.SetDebugHooks)
ns.SetDebugHooks({ RecordOn = RecordOn, RecordLine = RecordLine, RecordSummary = RecordSummary, RecTrigger = RecTrigger,
    RecDisplay = RecDisplay, RecSound = RecSound, DevRecordChanged = DevRecordChanged })
if ns.WhenReady then ns.WhenReady(Start) end

-------------------------------------------------------------------------------
-- Dev Assist's settings on XayaUI's Settings > Debugging (shown only while this addon is loaded)
-------------------------------------------------------------------------------
local function Changed() if ns.DebugSettingsChanged then ns.DebugSettingsChanged() end end
if ns.RegisterSettingsPage then
    -- row A20: the game-data probe follows Advanced Debugging (it was a switch on core's page)
    ns.RegisterSettingsPage("debugging", "devprobe", function()
        return { type = "group", inline = true, name = "Game-data probe", order = 1, args = {
            debugProbe = { type = "toggle", name = "Also run the game-data probe (XayaUI Dev Assist)", order = 1, width = "full",
                desc = "Switch Dev Assist's event probe on together with Advanced Debugging (it records what the game lets addons read, for the run sheet in docs/process). It goes off again with Advanced Debugging if this switched it on.",
                disabled = function() return not Ui().advancedDebug end,
                get = function() return Ui().debugProbe ~= false end,
                set = function(_, v) if v then Ui().debugProbe = nil else Ui().debugProbe = false end; SyncProbe() end },
        } }
    end)
    ns.RegisterSettingsPage("debugging", "devrecord", function(Notify)
        Notify = Notify or function() end
        local a = {
            recordOn = { type = "toggle", name = "Keep the detailed record", order = 1, width = "full",
                desc = "On (default with Advanced Debugging): the kinds of line chosen below are kept. Off: none is (XayaUI's errors and warnings are still kept for /xui report).",
                disabled = function() return not Ui().advancedDebug end,
                get = function() return Ui().recordOff ~= true end,
                set = function(_, v) Ui().recordOff = (not v) and true or nil; Changed(); Notify() end },
            recIntro = { type = "description", order = 2, width = "full", fontSize = "medium",
                hidden = function() return not Kept() end,
                name = "Each switch adds one kind of line; one that is off costs nothing. Combat start and end and any action the game blocked are always kept while the record is. The cost is in grey." },
            presetLight = { type = "execute", name = "Light set", order = 90, width = "normal",
                hidden = function() return not Kept() end,
                desc = "Only rules firing and clearing, game state and messages: the cheapest record that still says what happened.",
                func = function() ns.SetRecPreset("light"); Changed(); Notify() end },
            presetAll = { type = "execute", name = "Everything", order = 91, width = "normal",
                hidden = function() return not Kept() end,
                desc = "Every kind of line, including trigger detail (for the rules chosen above), displays and performance timing.",
                func = function() ns.SetRecPreset("all"); Changed(); Notify() end },
            presetDefault = { type = "execute", name = "Defaults", order = 92, width = "normal",
                hidden = function() return not Kept() end,
                func = function() ns.SetRecPreset("default"); Changed(); Notify() end },
            recordMax = { type = "select", name = "Lines kept", order = 95,
                hidden = function() return not Kept() end,
                desc = "The newest lines are kept; older ones are dropped and counted. More lines make a bigger saved file.",
                values = { [1000] = "1000", [3000] = "3000 (default)", [10000] = "10000 (a bigger file)" }, sorting = { 1000, 3000, 10000 },
                get = function() local n = tonumber(Ui().recordMax); return (n == 1000 or n == 10000) and n or 3000 end,
                set = function(_, v) v = tonumber(v); Ui().recordMax = (v == 1000 or v == 10000) and v or nil end },
            recFocus = { type = "multiselect", name = "Rules for trigger detail", order = 4.5, width = "full", dialogControl = "Dropdown",
                desc = "The rules whose every trigger change is recorded (their cues and conditions too). Pick only the rules you are looking into.",
                hidden = function() return not (Kept() and ns.RecCatSetting("triggers")) end,
                values = function()
                    local v = {}
                    for _, r in ipairs(ns.rules or {}) do
                        if not r.isCue and not r.parentUid then
                            if not r.uid and ns.NewUID then r.uid = ns.NewUID() end
                            if r.uid then v[r.uid] = tostring(r.name or "?") end
                        end
                    end
                    return v
                end,
                get = function(_, key) local f = Ui().recFocus; return type(f) == "table" and f[key] and true or false end,
                set = function(_, key, val)
                    local u = Ui()
                    u.recFocus = type(u.recFocus) == "table" and u.recFocus or {}
                    u.recFocus[key] = val and true or nil
                    if next(u.recFocus) == nil then u.recFocus = nil end
                    Changed()
                end },
            recordInfo = { type = "description", order = 96, width = "full", fontSize = "medium",
                name = function()
                    local n, drop, start = ns.RecordSummary()
                    if n == 0 then return "Detailed record: empty so far (it fills as you play)." end
                    return ("Detailed record: %d lines since %s%s. It holds rule names, spell IDs and XayaUI's messages; no character name or realm. Messages that name another player are shown but never kept."):format(
                        n, tostring(start), drop > 0 and (" (" .. drop .. " older lines dropped)") or "")
                end },
            recordView = { type = "execute", name = "View the detailed record", order = 97,
                desc = "Opens the whole record as text you can read and copy: what each kind of line means, the lines (newest at the bottom), and what to send.",
                func = function() if ns.ShowCopyBox then ns.ShowCopyBox("XayaUI detailed debug record", ns.RecordText()) end end },
            recordClear = { type = "execute", name = "Clear the detailed record", order = 98,
                confirm = true, confirmText = "Delete every line of the detailed debug record?",
                func = function() ns.ClearRecord(); Notify() end },
            reportRead = { type = "execute", name = "Read a debug report string", order = 99,
                desc = "Paste a player's debug report string (from /xui report) and see its entries in full. Also: /xuidev report.",
                func = function() if ns.DevAssistReportWindow then ns.DevAssistReportWindow() end end },
        }
        for i, c in ipairs(DR.CATS) do
            local key = c.key
            a["cat_" .. key] = { type = "toggle", order = 2 + i / 100, width = "full",
                hidden = function() return not Kept() end,
                name = c.name .. "  |cff888888(" .. c.cost .. ")|r", desc = c.desc,
                get = function() return ns.RecCatSetting(key) end,
                set = function(_, v) ns.SetRecCat(key, v); Changed(); Notify() end }
            if key == "triggers" then a.recFocus.order = 2 + i / 100 + 0.005 end
        end
        return { type = "group", inline = true, name = "Detailed debug record", order = 2, args = a }
    end)
end

-------------------------------------------------------------------------------
-- Reading a debug report string (from a player's /xui report): /xuidev report, or the button above
-------------------------------------------------------------------------------
local GD = rawget(_G, "XayaUIDevAssist")
-- the string -> the readable text with every stack, or nil, message
local function Expand(str)
    if not ns.DebugReportRead then return nil, "XayaUI is older than 0.6.56: it cannot read a debug report." end
    local d, err = ns.DebugReportRead(str)
    if not d then return nil, err end
    return ns.DebugReportText(d, true), d
end
if type(GD) == "table" then GD.ReadReport = Expand end
local rwin
function ns.DevAssistReportWindow()
    if not CreateFrame then return end
    if not rwin then
        local f = CreateFrame("Frame", "XayaUIDevAssistReportRead", UIParent, "BackdropTemplate")
        f:SetSize(620, 260); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.07, 0.06, 0.1, 0.97); f:SetBackdropBorderColor(0.4, 0.35, 0.55, 1)
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); t:SetPoint("TOPLEFT", 10, -10)
        t:SetText("XayaUI Dev Assist: read a debug report string")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -2, -2)
        f.msg = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.msg:SetPoint("BOTTOMLEFT", 10, 16)
        f.msg:SetPoint("RIGHT", f, "RIGHT", -130, 0); f.msg:SetJustifyH("LEFT")
        f.msg:SetText("Paste the string (XUIREP1:...) above, then Read.")
        local sf = CreateFrame("ScrollFrame", "XayaUIDevAssistReportReadScroll", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 10, -34); sf:SetPoint("BOTTOMRIGHT", -32, 46)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal); eb:SetWidth(570); eb:SetMaxLetters(0)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.box = eb
        local go = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        go:SetSize(110, 24); go:SetPoint("BOTTOMRIGHT", -10, 10); go:SetText("Read")
        go:SetScript("OnClick", function()
            local text, err = Expand(eb:GetText())
            if not text then f.msg:SetText("|cffff5555" .. tostring(err) .. "|r"); return end
            f.msg:SetText("Read. The entries are open in their own box.")
            if ns.ShowCopyBox then ns.ShowCopyBox("XayaUI debug report (read by Dev Assist)", text) end
        end)
        if ns.FlatButton then ns.FlatButton(go, true) end
        if UISpecialFrames then table.insert(UISpecialFrames, "XayaUIDevAssistReportRead") end
        rwin = f
    end
    rwin:Show()
    return rwin
end
