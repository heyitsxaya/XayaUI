-------------------------------------------------------------------------------
-- QAWalks-perf.lua (XayaUI_DevAssist 0.7.12): in-game QA walkthroughs for the performance test, stage 1 (REQUEST-LOG A15 P-1, P-4, P-5).
-- Standing rule V22 (Xaya, 2026-11-07, her words): "As a standing rule, make sure every feature or significant change to the codebase /
-- bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing".
--   J17 "Record this run?" (RunRecord.lua), in two walkthroughs (the second runs after Confirm's reload): prefill = true. Each check reads the prompt window, the run state and the settings, and offers
--       its verdict on Accept; nothing is recorded without her click. ONE-PUSH: remove both J17 walkthroughs with RunRecord.lua.
--   J18 what the run recorded (DevRecord.lua meter lines; tools/perf_report.py): prefill = true; the check counts what is in the saved
--       record (fights, boss lines, meter lines, dropped lines) and writes the counts into the note (data capture). The upload step is a
--       question for the person (noVerdict). Stays after the prompt is removed (it works with a record started by hand too).
-- Read-only except J17's first step ("Do it for me" remembers the Debugging settings, so the last step can compare them after the reload).
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
