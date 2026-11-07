-------------------------------------------------------------------------------
-- QAWalks-perf.lua (XayaUI_DevAssist 0.7.17): in-game QA walkthroughs for the performance test, stage 1 (REQUEST-LOG A15 P-1, P-4, P-5).
-- Standing rule V22 (Xaya, 2026-11-07, her words): "As a standing rule, make sure every feature or significant change to the codebase /
-- bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing".
--   J17 "Record this run?" (RunRecord.lua), in two walkthroughs (the second runs after Confirm's reload): prefill = true. Each check reads the prompt window, the run state and the settings, and offers
--       its verdict on Accept; nothing is recorded without her click. ONE-PUSH: remove both J17 walkthroughs with RunRecord.lua.
--   J20 rule log only while read (core 0.6.63 ns.LogWanted): counts the lines that reached the log, before and after the console opens.
--   J19 settings window memory (below): four readings of XayaUI_Options memory, data capture.
--   J18 what the run recorded (DevRecord.lua meter lines; tools/perf_report.py): prefill = true; the check counts what is in the saved
--       record (fights, boss lines, meter lines, dropped lines) and writes the counts into the note (data capture). The upload step is a
--       question for the person (noVerdict). Stays after the prompt is removed (it works with a record started by hand too).
-- Read-only except J17's first step ("Do it for me" remembers the Debugging settings, so the last step can compare them after the reload).
-- J19's fourth step runs a full Lua cleanup (collectgarbage "collect") on "Do it for me"; its readings are kept in XayaUIDevAssistDB.qa.optionsMem.
-- Listed in XayaUI_DevAssist.toc after QAWalks-chat.lua; does nothing without the framework (QAWalk.lua). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function DRI() local ns = NS(); return ns and ns.DebugRecordInfo end
local function RR() local d = DRI(); return d and d.RunRecord end
local function Ui() return (type(CueRulesDB) == "table" and type(CueRulesDB.ui) == "table") and CueRulesDB.ui or {} end
local function Lines() local r = type(CueRulesDB) == "table" and CueRulesDB.debugRecord; return (type(r) == "table" and type(r.lines) == "table") and r.lines or {}, r end
local function Title() local rr = RR(); local w = rr and rr.Window and rr.Window(); return (w and w:IsShown()) and w.title:GetText() or nil end
local function CatOn(k) local ns = NS(); return ns and ns.RecCatSetting and ns.RecCatSetting(k) and true or false end

-- the Debugging settings J17 compares before Accept and after Confirm (kept in Dev Assist's own saved table, so a /reload keeps them)
local KEYS = { "advancedDebug", "recordOff", "recordMax", "debugProbe" }
local function Snapshot()
    local u, s = Ui(), { cats = {} }
    for _, k in ipairs(KEYS) do s[k] = u[k] == nil and "nil" or u[k] end
    local rr = RR()
    for _, k in ipairs((rr and rr.CATS) or {}) do s.cats[k] = CatOn(k) end
    return s
end
local function Saved() local db = QA.DB(); return db.perfBefore end
local function Remember() local db = QA.DB(); db.perfBefore = Snapshot() end

-- lines of the record since the newest "recorded run starts" marker (or the whole record)
local function RunLines()
    local l = Lines()
    local from = 1
    for i = #l, 1, -1 do if l[i]:find("recorded run starts:", 1, true) then from = i; break end end
    local out = {}
    for i = from, #l do out[#out + 1] = l[i] end
    return out
end
local function Count(lines, text) local n = 0; for _, s in ipairs(lines) do if s:find(text, 1, true) then n = n + 1 end end; return n end
-- (a fight writes a start and an end line, a boss a start and an end line, a meter reading one line per addon plus "(all addons)")
local function Fights(lines) local n = 0; for _, s in ipairs(lines) do if s:find("---------- combat", 1, true) and s:find(" starts", 1, true) then n = n + 1 end end; return n end
local function Bosses(lines) local n = 0; for _, s in ipairs(lines) do if s:find("boss encounter", 1, true) and s:find(" ends:", 1, true) then n = n + 1 end end; return n end
local function Readings(lines, tag) local n = 0; for _, s in ipairs(lines) do if s:find("meter " .. tag, 1, true) and s:find("(all addons)", 1, true) then n = n + 1 end end; return n end

local function InDungeon()
    local rr = RR(); if not rr then return false, "XayaUI Dev Assist's run prompt is not loaded" end
    local kind, _, name = rr.Place()
    if not kind then return false, "you are not in a Mythic 0 or Mythic+ dungeon right now" end
    return true, ("in %s (%s)"):format(tostring(name or "?"), kind == "mplus" and "Mythic+" or "Mythic 0")
end

QA.Register("perf-run-prompt", { title = "Performance: the \"Record this run?\" prompt (J17)", area = "Dev Assist", qa = "J17", order = 300, prefill = true, steps = {
    { text = "Out of a dungeon, press |cffffd100Do it for me|r: XayaUI remembers your Settings > Debugging choices, so part 2 (after the reload) can check they come back.\n\n|cffffd100Expect:|r the addon's check says they are remembered.",
        setup = Remember,
        check = function()
            local s = Saved(); if not s then return false, "press Do it for me first" end
            local rr = RR(); if rr and rr.State and rr.State() then return false, "a recorded run is already on; finish it first (leave the dungeon and Confirm)" end
            return true, ("remembered: Advanced Debugging %s, lines kept %s"):format(tostring(s.advancedDebug), tostring(s.recordMax))
        end },
    { text = "Enter a |cffffd100Mythic 0|r dungeon (or a Mythic+ key's dungeon) out of combat.\n\n|cffffd100Expect:|r a window \"Record this run?\" naming the dungeon and what stays off.",
        check = function()
            local ok, why = InDungeon(); if not ok then return false, why end
            local t = Title()
            if t == "Record this run?" then return true, why .. "; the window is showing" end
            return false, why .. "; no \"Record this run?\" window (" .. tostring(t or "nothing shown") .. ")"
        end },
    { text = "Press |cffffd100Not now|r in that window, then wait a moment (or change zone inside).\n\n|cffffd100Expect:|r the window goes and does not come back in this visit.",
        check = function()
            local rr = RR(); if not rr then return false, "not loaded" end
            if Title() == "Record this run?" then return false, "the window is still showing" end
            if rr.State() then return false, "a run is being recorded (Accept was pressed?)" end
            if rr.Declined() == nil then return false, "no \"Not now\" seen for this dungeon" end
            return true, "hidden, nothing recorded, and this visit is marked \"Not now\""
        end },
    { text = "Leave the dungeon, enter it again and press |cffffd100Accept|r.\n\n|cffffd100Expect:|r \"Recording this run\" listing what it turned on.",
        check = function()
            local rr = RR(); if not rr then return false, "not loaded" end
            local st = rr.State(); if not st then return false, "no run is being recorded" end
            local u, off = Ui(), {}
            if not u.advancedDebug then off[#off + 1] = "Advanced Debugging" end
            if u.recordOff == true then off[#off + 1] = "the detailed record" end
            for _, k in ipairs(rr.CATS) do if not CatOn(k) then off[#off + 1] = k end end
            if tonumber(u.recordMax) ~= rr.MAX_LINES then off[#off + 1] = "10000 lines" end
            if #off > 0 then return false, "still off: " .. table.concat(off, ", ") end
            local svc = NS().Service and NS().Service("gameDataProbe")
            local okA, active = pcall(function() return svc and svc.Active and svc.Active() end)
            local before = Saved()
            if okA and active and not (before and before.advancedDebug == true and before.debugProbe ~= false) then
                return false, "the game-data probe is running, but it should stay off"
            end
            return true, ("recording %s; every dungeon kind on, 10000 lines, probe %s"):format(tostring(st.name), (okA and active) and "on (yours)" or "off")
        end },
    { text = "Play: a few pulls and at least one boss. Out of combat afterwards, press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the check counts fights, boss lines and meter lines in the record.",
        check = function()
            local l = RunLines()
            local meters = Readings(l, "combat")
            local note = ("this run so far: %d fight(s), %d boss(es) ended, %d meter reading(s) after fights, %d after bosses"):format(
                Fights(l), Bosses(l), meters, Readings(l, "boss"))
            if meters == 0 then return false, note .. " (no meter reading: Perf off, or the game's meter is unavailable)" end
            return true, note
        end },
    { text = "Leave the dungeon.\n\n|cffffd100Expect:|r a window \"Done with instance?\". Press |cffffd100Not yet|r first. This walkthrough ends here: record this step, then change zone until the window shows again and press |cffffd100Confirm|r (the interface reloads). After the reload run \"Performance: after Confirm (J17 part 2)\".",
        check = function()
            local rr = RR(); if not rr then return false, "not loaded" end
            if Title() == "Done with instance?" then return false, "the window is showing: press Not yet" end
            if not rr.State() then return false, "the run is no longer recorded (Confirm was pressed?)" end
            return true, "Not yet: still recording, window gone"
        end },
} })

QA.Register("perf-run-prompt-after", { title = "Performance: after Confirm (J17 part 2)", area = "Dev Assist", qa = "J17", order = 300.5, prefill = true, steps = {
    { text = "After you pressed |cffffd100Confirm|r in \"Done with instance?\" and the interface reloaded, press |cffffd100Check again|r.\n\n|cffffd100Expect:|r your Debugging settings are back as they were before Accept, and the record ends with \"recorded run ends\".",
        check = function()
            local rr = RR(); if not rr then return false, "not loaded" end
            if rr.State() then return false, "still recording: Confirm has not run" end
            local s = Saved(); if not s then return false, "nothing was remembered in the first step" end
            local now, diff = Snapshot(), {}
            for _, k in ipairs(KEYS) do if tostring(now[k]) ~= tostring(s[k]) then diff[#diff + 1] = ("%s %s (was %s)"):format(k, tostring(now[k]), tostring(s[k])) end end
            for k, v in pairs(s.cats or {}) do if now.cats[k] ~= v then diff[#diff + 1] = ("%s %s (was %s)"):format(k, tostring(now.cats[k]), tostring(v)) end end
            if Count(Lines(), "recorded run ends:") == 0 then diff[#diff + 1] = "no \"recorded run ends\" line" end
            if #diff > 0 then return false, "not as before: " .. table.concat(diff, "; ") end
            return true, "every Debugging setting is back as before Accept; the run's end is in the record"
        end },
} })

QA.Register("perf-run-data", { title = "Performance: send back a recorded run (J18)", area = "Dev Assist", qa = "J18", order = 301, prefill = true, steps = {
    { text = "After a recorded run (J17, or Perf switched on by hand in Settings > Debugging) and its reload, press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the check lists what the saved record holds for the newest run.",
        check = function()
            local l, r = Lines()
            if #l == 0 then return false, "the detailed record is empty" end
            local run = RunLines()
            local readings = Readings(run, "")
            local note = ("record: %d lines, %d dropped; newest run: %s, %d fight(s), %d boss(es) ended, %d meter reading(s), %s"):format(
                #l, (r and r.dropped) or 0, Count(run, "recorded run starts:") > 0 and "has a start marker" or "no start marker",
                Fights(run), Bosses(run), readings, Count(run, "recorded run ends:") > 0 and "has an end marker" or "no end marker")
            local good = readings > 0 and Fights(run) > 0
            return good, note
        end },
    { text = "Upload the file |cff88ccffWTF/Account/<your account>/SavedVariables/XayaUI.lua|r (in the World of Warcraft _retail_ folder) to Xaya or the chat. Developers turn it into a report with |cff88ccffpython3 tools/perf_report.py XayaUI.lua|r.\n\nPass when it is sent.",
        noVerdict = true },
} })

-------------------------------------------------------------------------------
-- J19: settings window memory (REQUEST-LOG A15 P-7 / P-8). Her screenshot showed XayaUI_Options at 380.8 MB of 679.0 MB; her answer
-- "Quick check + fix". Four readings of XayaUI_Options' memory (and all Lua memory): after a /reload without opening the settings,
-- with the window used, 30 s after closing it, and after a forced full cleanup. Leftover garbage = reading 3 - reading 4; kept by the
-- addon = reading 4. Data capture: every reading goes into the step's note and into XayaUIDevAssistDB.qa.optionsMem.
-- API 12.1.5 (docs/reference/api/api.json, no documentation text): UpdateAddOnMemoryUsage() (no returns);
-- GetAddOnMemoryUsage(name: uiAddon) -> result: number [SecretArguments=AllowedWhenUntainted]; C_AddOns.IsAddOnLoaded(name: uiAddon)
-- -> loadedOrLoading: bool, loaded: bool. INFERENCE: GetAddOnMemoryUsage is in KB (the game's own memory lists show it that way) and
-- counts garbage not yet collected. collectgarbage is Lua's own; INFERENCE: "count" and "collect" are allowed for addons (pcall'd).
-------------------------------------------------------------------------------
local OPT = "XayaUI_Options"
local function MemDB() local db = QA.DB(); db.optionsMem = type(db.optionsMem) == "table" and db.optionsMem or {}; return db.optionsMem end
local function Read()
    local okL, _, loaded = pcall(function() return C_AddOns.IsAddOnLoaded(OPT) end)
    local kb
    if okL and loaded then
        pcall(UpdateAddOnMemoryUsage)
        local ok, v = pcall(GetAddOnMemoryUsage, OPT)
        if ok and type(v) == "number" and not (issecretvalue and issecretvalue(v)) then kb = v end
    end
    local okC, all = pcall(collectgarbage, "count")
    return { loaded = (okL and loaded) and true or false, kb = kb, allKB = (okC and type(all) == "number") and all or nil,
        at = date and date("%H:%M:%S") or "?" }
end
local function MB(kb) return type(kb) == "number" and ("%.1f MB"):format(kb / 1024) or "?" end
local function Reading(key, label, want)
    return function()
        local r = Read()
        MemDB()[key] = r
        local note = ("%s: XayaUI_Options %s, all addons' Lua %s (%s)"):format(label, r.loaded and MB(r.kb) or "not loaded", MB(r.allKB), r.at)
        if want == "unloaded" then return not r.loaded, note .. (r.loaded and " (the settings addon is already loaded: /reload first)" or "") end
        if not r.loaded then return false, note .. " (open the settings window first)" end
        return r.kb ~= nil, note
    end
end
QA.Register("perf-options-memory", { title = "Performance: settings window memory (J19)", area = "Dev Assist", qa = "J19", order = 302, prefill = true, steps = {
    { text = "Type |cff88ccff/reload|r and do NOT open XayaUI's settings. Open |cff88ccff/xui dev qa|r, pick this walkthrough and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the settings addon is not loaded yet; the note keeps the total Lua memory.",
        check = Reading("a", "1 after /reload", "unloaded") },
    { text = "Open XayaUI's settings (|cff88ccff/xui|r) and use it for about a minute: Rules, open two or three rules, QoL, Bonus Features, a few switches on and back off. Leave it open, then press |cffffd100Check again|r here.\n\n|cffffd100Expect:|r a reading for the settings addon.",
        check = Reading("b", "2 window used") },
    { text = "Close the settings window, wait 30 seconds, press |cffffd100Check again|r.\n\n|cffffd100Expect:|r a reading 30 s after closing.",
        check = Reading("c", "3 closed 30 s") },
    { text = "Press |cffffd100Do it for me|r: a full Lua cleanup (the game may stop for a moment), then the reading.\n\n|cffffd100Expect:|r the reading after the cleanup.",
        setup = function() pcall(collectgarbage, "collect") end,
        check = Reading("d", "4 after a full cleanup") },
    { text = "Press |cffffd100Check again|r for the summary, then Accept. Send the summary (or the result code from the end screen) to Xaya.",
        check = function()
            local m = MemDB()
            local a, b, c, d = m.a, m.b, m.c, m.d
            if not (a and b and c and d) then return false, "a reading is missing; run steps 1-4 in order" end
            local garbage = (c.kb and d.kb) and (c.kb - d.kb) or nil
            return (b.kb and c.kb and d.kb) and true or false,
                ("Options: used %s, closed 30 s %s, after cleanup %s; leftover garbage %s (3 - 4), kept %s (4). All Lua: %s -> %s -> %s -> %s")
                    :format(MB(b.kb), MB(c.kb), MB(d.kb), MB(garbage), MB(d.kb), MB(a.allKB), MB(b.allKB), MB(c.allKB), MB(d.allKB))
        end },
} })

-------------------------------------------------------------------------------
-- J20: rule and snapshot log lines only while read (core 0.6.63 ns.LogWanted; REQUEST-LOG A15 P-9). Data capture: each check counts
-- the "status snapshot" and FIRED / cleared lines that reached the log since its mark (ns.logSerial counts every line ns.logBuf takes).
-------------------------------------------------------------------------------
local function LogNS() return NS() or {} end
local function Since(mark)
    local n = LogNS()
    local buf, now = n.logBuf or {}, n.logSerial or 0
    local new = math.min(now - (mark or now), #buf)
    local snap, rule = 0, 0
    for i = #buf - new + 1, #buf do
        local l = buf[i] or ""
        if l:find("status snapshot", 1, true) then snap = snap + 1 end
        if l:find("FIRED", 1, true) or l:find("cleared ", 1, true) or l:find("repeat  ", 1, true) then rule = rule + 1 end
    end
    return snap, rule, new
end
local function Readers()
    local n, on = LogNS(), {}
    if n.ConsoleWindowOn and n.ConsoleWindowOn() then on[#on + 1] = "the console window" end
    if n.LogTrayOn and n.LogTrayOn() then on[#on + 1] = "the settings window's debug strip" end
    if n.RecordOn and n.RecordOn("snapshot") then on[#on + 1] = "Dev Assist's record (Rule snapshots in combat)" end
    if n.RecordOn and n.RecordOn("rule") then on[#on + 1] = "Dev Assist's record (Rules firing and clearing)" end
    return on
end
local logMark
QA.Register("perf-log-gate", { title = "Performance: rule log only while it is read (J20)", area = "Dev Assist", qa = "J20", order = 303, prefill = true, steps = {
    { text = "Close the console window and XayaUI's settings window. In Settings > Debugging (Dev Assist settings), untick |cffffd100Rule snapshots in combat|r and |cffffd100Rules firing and clearing|r for this check (tick them again after). Press |cffffd100Check again|r.\n\n|cffffd100Expect:|r nothing reads the rule log now.",
        check = function()
            local n = LogNS(); if not n.LogWanted then return false, "this XayaUI is older than core 0.6.63" end
            local on = Readers()
            if #on > 0 then return false, "still read by: " .. table.concat(on, ", ") end
            return true, "nothing reads the rule log: rule and snapshot lines are not built"
        end },
    { text = "Press |cffffd100Do it for me|r (marks the log), then fight a training dummy or a mob for about 15 seconds and leave combat. Press |cffffd100Check again|r.\n\n|cffffd100Expect:|r no snapshot and no FIRED / cleared lines were added.",
        setup = function() logMark = LogNS().logSerial or 0 end,
        check = function()
            if not logMark then return false, "press Do it for me first" end
            local snap, rule, new = Since(logMark)
            local note = ("since the mark: %d log line(s), %d snapshot line(s), %d FIRED / cleared line(s)"):format(new, snap, rule)
            return (snap == 0 and rule == 0), note
        end },
    { text = "Open the console window (|cff88ccff/xui console|r), press |cffffd100Do it for me|r here, fight again for about 15 seconds and leave combat. Press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the snapshot lines are back (combat start and end), and FIRED / cleared lines if a rule fired.",
        setup = function() logMark = LogNS().logSerial or 0 end,
        check = function()
            if not logMark then return false, "press Do it for me first" end
            local snap, rule, new = Since(logMark)
            local note = ("console open, since the mark: %d log line(s), %d snapshot line(s), %d FIRED / cleared line(s)"):format(new, snap, rule)
            return snap > 0, note
        end },
} })

-------------------------------------------------------------------------------
-- J21: memory growth in combat (core 0.6.64: fewer closures per rule read; REQUEST-LOG A15 P-10). Data capture: all Lua memory
-- (collectgarbage "count": every addon's, not XayaUI's alone) and XayaUI core's own (GetAddOnMemoryUsage "XayaUI") at the mark and
-- after a fight, as KB per second. INFERENCE: a garbage collection in between lowers the numbers; the check says when memory fell.
-------------------------------------------------------------------------------
local growMark
local function CoreKB()
    pcall(UpdateAddOnMemoryUsage)
    local ok, v = pcall(GetAddOnMemoryUsage, "XayaUI")
    if ok and type(v) == "number" and not (issecretvalue and issecretvalue(v)) then return v end
end
QA.Register("perf-combat-memory", { title = "Performance: memory growth in combat (J21)", area = "Dev Assist", qa = "J21", order = 304, prefill = true, steps = {
    { text = "Out of combat, press |cffffd100Do it for me|r (marks memory and time), then fight a training dummy for about 30 seconds and leave combat. Press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the note gives XayaUI's memory growth in KB per second. Send it to Xaya.",
        setup = function()
            local ok, all = pcall(collectgarbage, "count")
            growMark = { t = GetTime(), all = ok and all or nil, core = CoreKB() }
        end,
        check = function()
            if not growMark then return false, "press Do it for me first" end
            local secs = GetTime() - growMark.t
            if secs < 10 then return false, ("only %.0f s since the mark; fight about 30 s"):format(secs) end
            local ok, all = pcall(collectgarbage, "count")
            local core = CoreKB()
            local function Rate(a, b) return (type(a) == "number" and type(b) == "number") and ((b - a) / secs) or nil end
            local rc, ra = Rate(growMark.core, core), Rate(growMark.all, ok and all or nil)
            local note = ("over %.0f s: XayaUI core %s KB/s, all Lua %s KB/s"):format(secs, rc and ("%+.1f"):format(rc) or "?", ra and ("%+.1f"):format(ra) or "?")
            if rc and rc < 0 then note = note .. " (memory fell: a garbage collection ran in between; repeat for a clean reading)" end
            return rc ~= nil and rc >= 0, note
        end },
} })

-------------------------------------------------------------------------------
-- J22: other addons' errors cost XayaUI almost nothing (core 0.6.65: no stack read for them; REQUEST-LOG A15 P-11). Data capture:
-- core counts the errors it passes on for other addons (ns.otherErrors); /xui report's entries are checked for any other addon's error.
-------------------------------------------------------------------------------
QA.Register("perf-other-errors", { title = "Performance: other addons' errors (J22)", area = "Dev Assist", qa = "J22", order = 305, prefill = true, steps = {
    { text = "Play as usual (a Mythic+ key, or wherever another addon shows errors, for example a Plater mod in a key). Afterwards press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the note says how many errors other addons raised this session; XayaUI passed them on and did not record or show them.",
        check = function()
            local n = NS() or {}
            if n.otherErrors == nil and not n.ErrorFolder then return false, "this XayaUI is older than core 0.6.65" end
            local other = n.otherErrors or 0
            local mine = 0
            local d = type(n.DebugReportData) == "function" and select(2, pcall(n.DebugReportData)) or nil
            if type(d) == "table" and type(d.entries) == "table" then
                -- (an entry whose message names another addon's file, by core's own rule ns.ErrorFolder, should never be recorded)
                for _, e in ipairs(d.entries) do
                    local msg = type(e) == "table" and tostring(e.msg or "") or ""
                    if msg:match("^%s*[^\n]-%.lua:%d+:") and n.ErrorFolder and n.ErrorFolder(msg, nil) == nil then mine = mine + 1 end
                end
            end
            local note = ("other addons' errors this session: %d (passed on to the game's error display, not recorded by XayaUI)"):format(other)
            if mine > 0 then return false, note .. ("; but %d recorded entries name a non-XayaUI folder"):format(mine) end
            return true, note
        end },
} })

-------------------------------------------------------------------------------
-- J23: rules that are not loaded cost (almost) nothing (core 0.6.66 load first; REQUEST-LOG A15 P-12). Data capture: switched-on and
-- loaded rule counts, then the engine timer's own lines (/xui debug perf: ms per step, Lua memory KB/s) after a fight.
-------------------------------------------------------------------------------
local function RuleCounts()
    local n = NS() or {}
    local on, loaded = 0, 0
    local ctx = n.ReadContext and n.ReadContext()
    for _, r in ipairs(n.rules or {}) do
        if not r.parentUid and r.enabled then
            on = on + 1
            if n.IsLoaded and n.IsLoaded(r, ctx) then loaded = loaded + 1 end
        end
    end
    return on, loaded
end
local perfByWalk
QA.Register("perf-load-first", { title = "Performance: rules that are not loaded (J23)", area = "Dev Assist", qa = "J23", order = 306, prefill = true, steps = {
    { text = "Out of combat, press |cffffd100Do it for me|r: the engine's timer starts (|cff88ccff/xui debug perf on|r). Then fight a training dummy for about 30 seconds and leave combat.\n\n|cffffd100Expect:|r the check counts your switched-on and loaded rules.",
        setup = function()
            local n = NS() or {}
            if n.PerfCommand and not n.perfOn and n.CaptureOutput then n.CaptureOutput(n.PerfCommand, "on"); perfByWalk = true end
        end,
        check = function()
            local n = NS() or {}
            if not n.PerfCommand then return false, "the engine timer is not available" end
            local on, loaded = RuleCounts()
            return n.perfOn and true or false, ("%d rules switched on, %d loaded here; timer %s"):format(on, loaded, n.perfOn and "running" or "not running (press Do it for me)")
        end },
    { text = "After the fight, press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the note gives the engine's milliseconds per step and Lua memory per second. Send it to Xaya. (With load first, rules that are not loaded add almost nothing: the numbers should follow the loaded count, not the switched-on count.)",
        check = function()
            local n = NS() or {}
            if not (n.PerfCommand and n.CaptureOutput) then return false, "the engine timer is not available" end
            local lines = n.CaptureOutput(n.PerfCommand, "") or {}
            local avg, worst, mem
            for _, l in ipairs(lines) do
                l = tostring(l)
                avg = avg or l:match("([%d%.]+) ms avg"); worst = worst or l:match("([%d%.]+) ms worst")
                mem = mem or l:match("([%+%-]?[%d%.]+) KB/s since start")
            end
            local on, loaded = RuleCounts()
            if not avg then return false, "no timing yet: fight with the timer on (step 1)" end
            return true, ("%d switched on, %d loaded: engine %s ms per step on average, %s ms worst; Lua memory %s KB/s"):format(on, loaded, avg, tostring(worst), tostring(mem))
        end },
    { text = "Press |cffffd100Do it for me|r to stop the timer again (if this walkthrough started it), then Pass.",
        setup = function() local n = NS() or {}; if perfByWalk and n.PerfCommand and n.CaptureOutput then n.CaptureOutput(n.PerfCommand, "off"); perfByWalk = nil end end,
        noVerdict = true },
} })
