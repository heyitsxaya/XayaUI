-------------------------------------------------------------------------------
-- QAWalks-keys.lua (XayaUI_DevAssist 0.7.72): in-game QA walkthrough for "keys reach the game" (XayaUI 0.6.85, XayaUI/KeyCatch.lua;
-- QA steps B390 to B395). Her words (docs/process/REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md row 56, 2026-11-08):
--   "WHY DOES THE ADDON KEEP PREVENTING ME FROM SCREENSHOTTING".
--   B390 the settings window open: the screenshot key works, also right after Ctrl+Z (a key the window uses);
--   B391 the mover view open: after an arrow key (it nudges the QA test group) the screenshot key works;
--   B392 in combat with the settings window open: the screenshot key works and you can walk;
--   B393 the version pane: Esc closes the pane only (the settings window stays open);
--   B394 the Calculator: a click on the game world takes the cursor out of its line, and the screenshot key works again;
--   B395 the rule search box: Enter leaves the search in place and gives the keyboard back (you can walk).
-- (2026-11-09, the review's should-fix items; XayaUI 0.6.85, Options 0.6.106, Bonus 0.6.38, Dev Assist 0.7.72; QA steps B396-B398)
--   B396 a settings window text box (AceGUI's: a rule's name): Enter gives the keyboard back; the screenshot key, whatever key it is
--        bound to, works with the window open (the check names her screenshot key, GetBindingKey("SCREENSHOT"));
--   B397 the Calculator: Enter works the sum out and gives the keyboard back (you can walk at once);
--   B398 in combat with the settings window open, Ctrl+Z does one thing only: the editor's undo when the game has no binding on it,
--        her binding when it has one (the check reads what core decided for that key: ns.KeyCatchList's last key).
-- Standing rule V22 (Xaya 2026-11-07): each check reads what the addon and the game report (SCREENSHOT_SUCCEEDED and
-- PLAYER_STARTED_MOVING, events.md 1351 and 1217, listened to only while this walkthrough runs; the windows' key state through core's
-- ns.KeyCatchList) and offers its verdict (prefill = true; recorded only on her click), with what it read in the note. The Done step
-- closes what the walkthrough opened (the mover view with Cancel moves). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local st = { shots = {}, moves = {} }
local function NS() return rawget(_G, "XayaUI_NS") end
local function Fighting() return InCombatLockdown and InCombatLockdown() and true or false end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames.CueRules end
-- the version pane through core's service list (Modules.lua ns.Service; XayaUI_Options/InfoPane.lua provides "infoPane")
local function Pane() local ns = NS(); return ns and ns.Service and ns.Service("infoPane") or nil end
local function PaneShown() local p = Pane(); return p and p.IsShown() and true or false end
local function Calc() return rawget(_G, "XayaUICalculator") end

-- what the game reports, while the walkthrough runs (V14: nothing is registered before its first step)
local ev
local function Watch()
    if not ev then
        ev = CreateFrame("Frame")
        ev:SetScript("OnEvent", function(_, e)
            local ns = NS()
            local c = Calc()
            local rec = { t = GetTime(), combat = Fighting(), settings = Root() ~= nil, mover = ns and ns.unlocked and true or false,
                calcFocus = c and c.edit and c.edit:HasFocus() or false }
            if e == "SCREENSHOT_SUCCEEDED" then st.shots[#st.shots + 1] = rec else st.moves[#st.moves + 1] = rec end
        end)
    end
    ev:RegisterEvent("SCREENSHOT_SUCCEEDED")
    ev:RegisterEvent("PLAYER_STARTED_MOVING")
end
local function Since(list, t, pred)
    local n = 0
    for _, r in ipairs(list) do if r.t >= (t or 0) and (not pred or pred(r)) then n = n + 1 end end
    return n
end
-- the settings window's key state as core reports it
local function SettingsKeys()
    local ns, root = NS(), Root()
    if not (ns and ns.KeyCatchList) then return nil end
    for _, e in ipairs(ns.KeyCatchList()) do if root and e.frame == root.frame then return e end end
end
local function OpenSettings()
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then error("the settings window (XayaUI_Options) could not be loaded") end
    if not ns.KeyCatchList then error("XayaUI is older than 0.6.85 (no shared key handling)") end
    if not Root() and ns.OptionsApi and ns.OptionsApi.Toggle then ns.OptionsApi.Toggle() end
end

-- B390
local function Setup1() Watch(); OpenSettings(); st.t1 = GetTime() end
local function Check1()
    if not st.t1 then return nil, "press Do it for me first" end
    local k = SettingsKeys()
    if not k then return nil, "the settings window is not open: press Do it for me" end
    local n = Since(st.shots, st.t1, function(r) return r.settings end)
    local note = ("Settings window: keyboard %s, keys passed on to the game: %s. Screenshots taken with it open: %d.")
        :format(k.keyboard and "on" or "off", tostring(k.propagate), n)
    if k.keyboard and k.propagate == false and not k.held then return false, note .. " (the window keeps every key)" end
    if n == 0 then return nil, note .. " Press Print Screen, then Check." end
    if n < 2 then return nil, note .. " Now open a rule, press Ctrl+Z, then Print Screen again, then Check." end
    return true, note
end
-- B391
local function Setup2()
    local ns = NS()
    if not (ns and QA.MakeTestGroup and ns.MoverSelect) then error("XayaUI Dev Assist or XayaUI Rules is too old for this step") end
    Watch()
    local f = QA.MakeTestGroup(true)
    if not ns.unlocked and ns.ToggleUnlock then ns.ToggleUnlock(); st.unlockedByUs = true end
    ns.MoverSelect("group", f)
    st.group, st.from, st.t2 = f, { f.cX or 0, f.cY or 0 }, GetTime()
end
local function Check2()
    local ns, f = NS(), st.group
    if not (f and st.t2) then return nil, "press Do it for me first" end
    if not ns.unlocked then return nil, "the mover view is closed: press Do it for me" end
    local moved = (f.cX or 0) ~= st.from[1] or (f.cY or 0) ~= st.from[2]
    local n = Since(st.shots, st.t2, function(r) return r.mover end)
    local note = ("QA test group moved by X %+d, Y %+d. Screenshots taken in the mover view: %d."):format((f.cX or 0) - st.from[1], (f.cY or 0) - st.from[2], n)
    if not moved then return nil, note .. " Press an arrow key once, then Print Screen, then Check." end
    if n == 0 then return nil, note .. " Press Print Screen, then Check." end
    return true, note
end
-- B392
local function Setup3() Watch(); OpenSettings(); st.t3 = GetTime() end
local function Check3()
    if not st.t3 then return nil, "press Do it for me first" end
    local shots = Since(st.shots, st.t3, function(r) return r.combat and r.settings end)
    local walks = Since(st.moves, st.t3, function(r) return r.combat and r.settings end)
    local note = ("In combat with the settings window open: %d screenshot(s), %d time(s) you started walking."):format(shots, walks)
    if shots == 0 or walks == 0 then return nil, note .. " Start a fight with the window open, press Print Screen and walk, then Check." end
    return true, note
end
-- B393
local function Setup4()
    OpenSettings()
    local p = Pane()
    if not (p and p.Open) then error("XayaUI Options has no version pane") end
    p.Open()
    st.t4 = GetTime()
end
local function Check4()
    if not st.t4 then return nil, "press Do it for me first" end
    local settings, pane = Root() ~= nil, PaneShown()
    local note = ("Version pane %s; settings window %s."):format(pane and "open" or "closed", settings and "open" or "closed")
    if pane then return nil, note .. " Press Esc once, then Check." end
    return settings, note .. (settings and "" or " (Esc closed the settings window too)")
end
-- B394
local function Setup5()
    local ns = NS()
    if not (ns and ns.Calculator_Open) then error("XayaUI Bonus Features (Calculator) is off or not loaded") end
    Watch(); ns.Calculator_Open(); st.t5 = GetTime()
end
local function Check5()
    local c = Calc()
    if not (st.t5 and c and c.edit) then return nil, "press Do it for me first" end
    local focus = c.edit:HasFocus()
    local n = Since(st.shots, st.t5)
    local note = ("Calculator line has the cursor: %s. Screenshots since: %d."):format(focus and "yes" or "no", n)
    if focus and n > 0 then return false, note .. " (the line kept the keyboard)" end
    if focus then return nil, note .. " Click once on the game world (outside the Calculator), then Print Screen, then Check." end
    if n == 0 then return nil, note .. " Press Print Screen, then Check." end
    return true, note
end
-- B395
local function Setup6() Watch(); OpenSettings(); st.t6 = GetTime() end
local function Check6()
    local ns = NS()
    if not st.t6 then return nil, "press Do it for me first" end
    local api = ns and ns.OptionsApi
    if not (api and api.TreeFilter) then return nil, "XayaUI Options is too old for this step" end
    local q = api.TreeFilter() or ""
    local walks = Since(st.moves, st.t6)
    local note = ("Search text: '%s'. Times you started walking since: %d."):format(q, walks)
    if q == "" then return nil, note .. " Type a few letters in Search rules, press Enter, then walk (W), then Check." end
    if walks == 0 then return nil, note .. " Press Enter in the search box, then walk (W), then Check." end
    return true, note
end
-- B396
local function ScreenshotKey()
    if not GetBindingKey then return nil end
    local ok, k = pcall(GetBindingKey, "SCREENSHOT")
    return ok and type(k) == "string" and k ~= "" and k or nil
end
local function Setup7()
    local ns = NS()
    if not (ns and ns.KeyFocusLastLetGo) then error("XayaUI is older than the 2026-11-09 key fixes (no text box record)") end
    Watch(); OpenSettings(); st.t7 = GetTime()
end
local function Check7()
    local ns, root = NS(), Root()
    if not st.t7 then return nil, "press Do it for me first" end
    if not root then return nil, "the settings window is not open: press Do it for me" end
    local lg = ns.KeyFocusLastLetGo and ns.KeyFocusLastLetGo()
    local byEnter = lg and lg.how == "enter" and lg.t >= st.t7 and lg.win == root.frame
    local walks = byEnter and Since(st.moves, lg.t) or 0
    local shots = Since(st.shots, st.t7, function(r) return r.settings end)
    local key = ScreenshotKey()
    local note = ("Your screenshot key: %s. A settings text box let go on Enter: %s. Walks since: %d. Screenshots with the window open: %d.")
        :format(key or "none bound", byEnter and "yes" or "not yet", walks, shots)
    if not byEnter then return nil, note .. " Click in a rule's Name box, press Enter, then walk (W), then Check." end
    if walks == 0 then return nil, note .. " Walk (W), then Check." end
    if key and shots == 0 then return nil, note .. " Press your screenshot key (" .. key .. "), then Check." end
    return true, note
end
-- B397
local function Setup8()
    local ns = NS()
    if not (ns and ns.Calculator_Open) then error("XayaUI Bonus Features (Calculator) is off or not loaded") end
    Watch(); ns.Calculator_Open()
    local c = Calc()
    if c and c.edit then c.edit:SetText("12*3"); c.edit:SetCursorPosition(4); c.edit:SetFocus() end
    if c and c.result then c.result:SetText("") end
    st.t8 = GetTime()
end
local function Check8()
    local c = Calc()
    if not (st.t8 and c and c.edit) then return nil, "press Do it for me first" end
    local res = c.result and c.result:GetText() or ""
    local focus = c.edit:HasFocus()
    local walks = Since(st.moves, st.t8)
    local note = ("Answer shown: '%s'. The line has the cursor: %s. Walks since: %d."):format(res, focus and "yes" or "no", walks)
    if res ~= "36" then return nil, note .. " Press Enter in the Calculator's line (12*3), then walk (W), then Check." end
    if focus then return false, note .. " (the line kept the keyboard after Enter)" end
    if walks == 0 then return nil, note .. " Walk (W), then Check." end
    return true, note
end
-- B398
local function Setup9() Watch(); OpenSettings(); st.t9 = GetTime() end
local function Check9()
    if not st.t9 then return nil, "press Do it for me first" end
    local k = SettingsKeys()
    if not k then return nil, "the settings window is not open: press Do it for me" end
    local last = k.last
    if not (last and last.fight and last.key == "Z") then
        return nil, "Start a fight with the settings window open, press Ctrl+Z once during the fight, then Check (after the fight is fine)."
    end
    local bound = type(last.binding) == "string" and last.binding or nil
    local note = ("Ctrl+Z in combat: your game binding %s; the editor %s."):format(bound and ("'" .. bound .. "' ran") or "(none)",
        last.used and "undid" or "did not act")
    if bound and last.used then return false, note .. " (both: the key did two things)" end
    if last.binding == nil then return true, note .. " (the binding could not be read, so the key was left to the game)" end
    return true, note
end
local function Done()
    local ns = NS()
    local c = Calc(); if c then c:Hide() end
    local p = Pane(); if p and p.Close then p.Close() end
    if st.unlockedByUs and ns and ns.unlocked then
        if ns.MoverExit then ns.MoverExit("cancel") elseif ns.ToggleUnlock then ns.ToggleUnlock() end
    end
    if ev then ev:UnregisterAllEvents() end
    st.unlockedByUs, st.group, st.from = nil, nil, nil
    st.t1, st.t2, st.t3, st.t4, st.t5, st.t6, st.t7, st.t8, st.t9 = nil, nil, nil, nil, nil, nil, nil, nil, nil
    wipe(st.shots); wipe(st.moves)
end
QA.KeysTest = { State = st, Done = Done, EventFrame = function() return ev end }   -- (tests)

QA.Register("keys", { title = "Keys reach the game: screenshots, walking, Esc, text boxes (B390-B398)",
    qa = "B390, B391, B392, B393, B394, B395, B396, B397, B398", order = 560, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens.\n\nPress |cffffd100Print Screen|r (your screenshot key). Then open any rule in the list, press |cffffd100Ctrl+Z|r (with nothing changed it says there is nothing to undo) and press |cffffd100Print Screen|r again. Then |cffffd100Check|r.\n\n|cffffd100Expect:|r both times the game says it saved a screenshot. The check counts the screenshots the game reports and reads whether the window passes keys on.",
        setup = Setup1, check = Check1 },
    { text = "Press |cffffd100Do it for me|r: the mover view opens with the QA test group selected.\n\nPress an |cffffd100arrow key|r once (the group moves 1 pixel), then |cffffd100Print Screen|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r the group moves and the screenshot is saved.",
        setup = Setup2, check = Check2 },
    { text = "Press |cffffd100Do it for me|r: the settings window opens.\n\nWith it open, start a fight (attack a training dummy). During the fight press |cffffd100Print Screen|r and |cffffd100walk|r a few steps (W). Then |cffffd100Check|r.\n\n|cffffd100Expect:|r the screenshot is saved and you walk, as without XayaUI.",
        setup = Setup3, check = Check3 },
    { text = "Out of combat, press |cffffd100Do it for me|r: the settings window and the version pane open.\n\nPress |cffffd100Esc|r once, then |cffffd100Check|r.\n\n|cffffd100Expect:|r the version pane closes; the settings window stays open.",
        setup = Setup4, check = Check4 },
    { text = "Press |cffffd100Do it for me|r: the Calculator opens with the cursor in its line.\n\nClick once on the |cffffd100game world|r (outside the Calculator), then press |cffffd100Print Screen|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r the click takes the cursor out of the line, and the screenshot is saved.",
        setup = Setup5, check = Check5 },
    { text = "Press |cffffd100Do it for me|r: the settings window opens.\n\nType a few letters in |cffffd100Search rules|r (above the rule list), press |cffffd100Enter|r, then walk (W). Then |cffffd100Check|r.\n\n|cffffd100Expect:|r the search stays, the cursor leaves the box, and W walks (it does not type a w).",
        setup = Setup6, check = Check6 },
    { text = "Press |cffffd100Do it for me|r: the settings window opens.\n\nOpen any rule, click in its |cffffd100Name|r box, press |cffffd100Enter|r (the name stays), then walk (W). Then press your |cffffd100screenshot key|r (the check names it; it need not be Print Screen). Then |cffffd100Check|r.\n\n|cffffd100Expect:|r after Enter the cursor leaves the box and W walks (it does not type a w); the screenshot is saved.",
        setup = Setup7, check = Check7 },
    { text = "Press |cffffd100Do it for me|r: the Calculator opens with 12*3 in its line and the cursor in it.\n\nPress |cffffd100Enter|r, then walk (W). Then |cffffd100Check|r.\n\n|cffffd100Expect:|r the answer 36 shows, the cursor leaves the line, and W walks at once (no Esc or click needed). A click in the line carries on from 36.",
        setup = Setup8, check = Check8 },
    { text = "Press |cffffd100Do it for me|r: the settings window opens.\n\nWith it open, start a fight (a training dummy) and press |cffffd100Ctrl+Z|r once during the fight. Then |cffffd100Check|r (after the fight is fine).\n\n|cffffd100Expect:|r Ctrl+Z does one thing only: if your key bindings use Ctrl+Z, that binding runs and nothing is undone; if not, the editor's undo runs (with nothing changed it says there is nothing to undo). Out of combat Ctrl+Z is always the editor's.",
        setup = Setup9, check = Check9 },
    { text = "Press |cffffd100Do it for me|r to close the Calculator, the version pane and the mover view (if this walkthrough opened it), then |cffffd100Done|r.", done = true, setup = Done },
} })
