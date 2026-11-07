-------------------------------------------------------------------------------
-- QAWalks-perf.lua (XayaUI_DevAssist 0.7.18): in-game QA walkthroughs for the performance test (REQUEST-LOG A15).
-- Standing rule V22 (Xaya, 2026-11-07, her words): "As a standing rule, make sure every feature or significant change to the codebase /
-- bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing".
--   J18 what a recorded run holds (DevRecord.lua meter lines; tools/perf_report.py): counts fights, bosses, meter readings (data capture);
--       the upload step is a question for the person (noVerdict).
--   J19 settings window memory: four readings of XayaUI_Options memory (data capture); step 4 runs a full Lua cleanup on "Do it for me".
--   J20 rule log only while read (core ns.LogWanted). J21 memory growth in combat. J22 other addons' errors. J23 rules not loaded.
-- (J17, the one-push "Record this run?" prompt, and its two walkthroughs were removed with RunRecord.lua, as Xaya asked: "Ships once,
-- then removed".) All prefill = true: the addon's verdict is offered on Accept; nothing is recorded without the person's click.
-- Listed in XayaUI_DevAssist.toc after QAWalks-display.lua; does nothing without the framework (QAWalk.lua). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function DRI() local ns = NS(); return ns and ns.DebugRecordInfo end
local function Lines() local r = type(CueRulesDB) == "table" and CueRulesDB.debugRecord; return (type(r) == "table" and type(r.lines) == "table") and r.lines or {}, r end


-- lines of the record since the newest "recorded run starts" marker (written by the removed prompt), else the whole record
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


QA.Register("perf-run-data", { title = "Performance: send back a recorded run (J18)", area = "Dev Assist", qa = "J18", order = 301, prefill = true, steps = {
    { text = "With Dev Assist's record keeping |cffffd100Performance|r (Settings > Debugging), play (a key, or a few fights), then |cff88ccff/reload|r and, press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the check lists what the saved record holds for the newest run.",
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

-------------------------------------------------------------------------------
-- J24: a still cursor (QoL 0.7.41: the Cursor Highlight is re-anchored only when the cursor moved; the trail skips its dot loop
-- while nothing is live; REQUEST-LOG A15 P-13). Data capture: the game's meter for XayaUI_QoL (RecentAverageTime, ms per frame:
-- INFERENCE on units) after 10 s with the mouse still, then after 10 s of moving it.
-------------------------------------------------------------------------------
local function QoLRecent()
    local P = C_AddOnProfiler
    local M = Enum and Enum.AddOnProfilerMetric
    if not (P and P.GetAddOnMetric and M) then return nil end
    local ok, v = pcall(P.GetAddOnMetric, "XayaUI_QoL", M.RecentAverageTime)
    if ok and type(v) == "number" and not (issecretvalue and issecretvalue(v)) then return v end
end
local stillRead
QA.Register("perf-still-cursor", { title = "Performance: a still cursor (J24)", area = "Dev Assist", qa = "J24", order = 307, prefill = true, steps = {
    { text = "With the Cursor Highlight and / or the cursor trail on, leave the mouse completely still for 10 seconds, out of combat, then press |cffffd100Check again|r with the keyboard focus (or move only to click and keep it still again for 10 s and press it).\n\n|cffffd100Expect:|r the note gives XayaUI_QoL's CPU per frame while still.",
        check = function()
            local v = QoLRecent()
            if not v then return false, "the game's addon meter is not available" end
            stillRead = v
            return true, ("XayaUI_QoL while still: %.4f ms per frame (recent average)"):format(v)
        end },
    { text = "Now move the mouse around for 10 seconds and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r a higher reading while moving; the still one should be close to nothing. Send both to Xaya.",
        check = function()
            local v = QoLRecent()
            if not v then return false, "the game's addon meter is not available" end
            if not stillRead then return false, "do step 1 first" end
            return v >= stillRead, ("XayaUI_QoL still %.4f ms per frame, moving %.4f ms per frame"):format(stillRead, v)
        end },
} })

-------------------------------------------------------------------------------
-- J25: the usage tooltip reads addon memory once per hover (XayaDataBlocks-1.0 MINOR 2, Chat 0.6.32 / Bonus 0.6.26; REQUEST-LOG
-- A15 P-14). Data capture: the library's own count of memory reads (B.memReads) over a 20 s hover; Pass when the hover made one.
-------------------------------------------------------------------------------
local function DataBlocks() local LS = rawget(_G, "LibStub"); local ok, B = pcall(function() return LS and LS("XayaDataBlocks-1.0", true) end); return ok and B or nil end
local hoverMark
QA.Register("perf-usage-tooltip", { title = "Performance: the addon usage tooltip (J25)", area = "Dev Assist", qa = "J25", order = 308, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r (marks the count), then hover the Chat Bar's (or a data panel's) frame rate or latency block for about 20 seconds, move the mouse away and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the tooltip ends with a grey line \"Includes the cost of reading these numbers.\"; the check says the hover read addon memory once.",
        setup = function() local B = DataBlocks(); hoverMark = B and (B.memReads or 0) or nil end,
        check = function()
            local B = DataBlocks()
            if not B then return false, "the data blocks library is not loaded (XayaUI Chat or Bonus Features off)" end
            if hoverMark == nil then return false, "press Do it for me first" end
            local n = (B.memReads or 0) - hoverMark
            if n == 0 then return false, "no memory read since the mark: hover a frame rate or latency block" end
            return n == 1, ("memory read %d time(s) during the hover (once is right; it was every 15 s before)"):format(n)
        end },
} })

-------------------------------------------------------------------------------
-- J27: the settings window's speed and memory (Options 0.6.68; REQUEST-LOG A15 P-16). Before, measured by Xaya in game with
-- /xui debug perf ui: first open 3 full builds ("XayaUI open: 2603 ms", + 739 + 650 ms), reopen 776 + 1211 ms, one switch 2 builds =
-- 1,362 ms, XayaUI_Options 528.5 MB. Data capture: the window's own redraw count and times (ns.perf: one per full redraw, build and
-- skin milliseconds of the last) and XayaUI_Options' memory (GetAddOnMemoryUsage).
-------------------------------------------------------------------------------
local optMark
local function Perf() local n = NS() or {}; return n.perf end
local function OptMB() pcall(UpdateAddOnMemoryUsage); local ok, v = pcall(GetAddOnMemoryUsage, "XayaUI_Options"); return (ok and type(v) == "number") and v / 1024 or nil end
local function Redraws(label)
    local p = Perf()
    if not (p and optMark) then return false, "press Do it for me first" end
    local n = (p.n or 0) - optMark
    return n, ("%s: %d full redraw(s); the last took %.0f ms build + %.0f ms skin"):format(label, n, p.build or 0, p.skin or 0)
end
QA.Register("perf-settings-window", { title = "Performance: the settings window (J27)", area = "Dev Assist", qa = "J27", order = 309, prefill = true, steps = {
    { text = "Close XayaUI's settings window if it is open. Press |cffffd100Do it for me|r (marks the count), then open the window (|cff88ccff/xui|r) and press |cffffd100Check again|r here.\n\n|cffffd100Expect:|r ONE full redraw. Before this fix: 3 on the first open (2603 + 739 + 650 ms), about 2 s on a reopen.",
        setup = function() local p = Perf(); optMark = p and p.n or 0 end,
        check = function()
            local n, note = Redraws("opening")
            if n == false then return false, note end
            return n == 1, note
        end },
    { text = "Press |cffffd100Do it for me|r again, then click one switch on and off once (for example Bonus Features > Tooltips > IDs) and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r one redraw per click (two clicks: 2). Before: 2 per click, 1,362 ms.",
        setup = function() local p = Perf(); optMark = p and p.n or 0 end,
        check = function()
            local n, note = Redraws("two clicks")
            if n == false then return false, note end
            return n <= 2, note
        end },
    { text = "Leave the window open on the Rules tab for a minute without touching it: press |cffffd100Do it for me|r (marks the memory), wait 60 s, press |cffffd100Check again|r.\n\n|cffffd100Expect:|r XayaUI_Options grows little in that minute and makes no redraw.",
        setup = function() local p = Perf(); optMark = p and p.n or 0; QA.DB().optIdle = { mb = OptMB(), t = GetTime() } end,
        check = function()
            local m, p = QA.DB().optIdle, Perf()
            if not (m and m.mb) then return false, "press Do it for me first" end
            local secs, now = GetTime() - m.t, OptMB()
            if secs < 30 then return false, ("only %.0f s; wait about 60 s"):format(secs) end
            local redraws = p and ((p.n or 0) - (optMark or 0)) or 0
            return redraws == 0, ("open and idle %.0f s: XayaUI_Options %.1f -> %.1f MB (%.1f MB per minute), %d redraw(s)"):format(secs, m.mb, now or 0, ((now or 0) - m.mb) / secs * 60, redraws)
        end },
    { text = "Close the window, then press |cffffd100Do it for me|r (a full Lua cleanup; the game may stop for a moment) and |cffffd100Check again|r.\n\n|cffffd100Expect:|r XayaUI_Options keeps only a few MB once closed and cleaned up. Before: about 83 MB kept (your screenshot after a cleanup).",
        setup = function() pcall(collectgarbage, "collect") end,
        check = function()
            local n = NS() or {}
            if n.OptionsApi and n.OptionsApi.IsOpen and n.OptionsApi.IsOpen() then return false, "close the settings window first" end
            local mb = OptMB()
            if not mb then return false, "the settings addon is not loaded (open /xui once first)" end
            return mb < 30, ("closed and cleaned up: XayaUI_Options %.1f MB"):format(mb)
        end },
} })
