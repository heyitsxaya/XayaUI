-------------------------------------------------------------------------------
-- QAWalks-statcalc-fixes.lua (XayaUI Dev Assist): the in-game walkthrough for the Stat Calculator fixes of 2026-11-10 (XayaUI Bonus
-- Features, StatCalculator.lua; docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md SC-001 / SC-045 / SC-002 / SC-019 / SC-081 / SC-020 /
-- SC-102; Xaya's V26 answer "Hide silently", REQUEST-LOG A24 #3). Standing rule V22 (Xaya 2026-11-07, her words): "make sure every
-- feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation
-- options or data capturing". prefill = true: where the addon can read the result its verdict is offered on one button and recorded
-- only on a click (QAWalk.lua); a step marked noVerdict asks something only the person can see.
-- Reaches XayaUI Bonus Features and XayaUI QoL only through core's services: "statCalc" (open / close / draw / type in a box),
-- "statCalcDebug" (which events are registered; Builds, the read-only count of stat models the panel built; BoxFocus, whether a Change
-- box has the keyboard) and "charDisplay" (whether the Stat Calc button shows). Nothing here gives any frame the keyboard or the mouse:
-- the person clicks into a box. One plain event frame of this file listens to PLAYER_REGEN_DISABLED only while step 1 waits for combat,
-- and is let go when it has read the result. What "Do it for me" changes (the panel's tab, open or closed, the typed number) is
-- remembered in step 1 and put back in the last step. Listed in XayaUI_DevAssist.toc after the other QAWalks files (the integration step
-- adds the line); does nothing without the framework. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Svc(n) local ns = NS(); return ns and ns.Service and ns.Service(n) or nil end
local function InCombat() local f = rawget(_G, "InCombatLockdown"); return (type(f) == "function" and f()) and true or false end
local function WindowShown() local cf = rawget(_G, "CharacterFrame"); return (type(cf) == "table" and cf.IsShown and cf:IsShown()) and true or false end

-- the Stat Calculator with its panel on, and its debug answers (Builds: Bonus 2026-11-10 or later)
local function Ready()
    local sc, dbg = Svc("statCalc"), Svc("statCalcDebug")
    if not (sc and dbg) then return nil, nil, "XayaUI Bonus Features or XayaUI QoL is off (the Stat Calculator needs both)" end
    if not dbg.Builds then return nil, nil, "XayaUI Bonus Features is older than this walkthrough (no build count)" end
    local c = sc.Cfg and sc.Cfg()
    if not (c and c.enabled and c.panel) then return nil, nil, "Bonus Features > Stat Calculator and its Panel must be on: tick both" end
    return sc, dbg
end
local function ButtonShown()
    local s = Svc("charDisplay")
    if not (s and s.Drawn) then return false end
    local ok, d = pcall(s.Drawn)
    return (ok and type(d) == "table" and d.button) and true or false
end
local function Line(sc, dbg)
    local focused, boxes = false, 0
    if dbg and dbg.BoxFocus then focused, boxes = dbg.BoxFocus() end
    return ("in combat %s; character window %s; panel %s; Stat Calc button %s; a Change box has the keyboard: %s (%d boxes); stat models built so far: %s"):format(
        InCombat() and "yes" or "no", WindowShown() and "open" or "closed", (sc and sc.Shown()) and "shown" or "hidden",
        ButtonShown() and "shown" or "hidden", focused and "yes" or "no", boxes or 0, dbg and tostring(dbg.Builds()) or "?")
end

-- remembered by step 1, put back by the last step
local saved
local function Remember(sc)
    local c = sc.Cfg()
    if saved or not c then return end
    saved = { tab = c.tab, open = sc.Shown(), crit = c.whatIfStats and c.whatIfStats.crit }
end
local function PutBack()
    local sc = Svc("statCalc")
    local c = sc and sc.Cfg and sc.Cfg()
    if not (c and saved) then saved = nil; return end
    if InCombat() then error("you are in combat: press Do it for me again after combat") end
    c.tab = saved.tab
    if c.whatIfStats then c.whatIfStats.crit = saved.crit end
    if saved.open then sc.Open(saved.tab) elseif sc.Shown() then sc.Close() end
    saved = nil
end

-- step 1: what the panel, the button and the boxes are just after combat starts (read on the next frame, after every handler of the
-- event has run, so the order of the addons' handlers does not matter)
local watch, atCombat
local function Watch()
    atCombat = nil
    if not watch then
        local CF = rawget(_G, "CreateFrame")
        if type(CF) ~= "function" then return end
        watch = CF("Frame")
        watch:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            local T = rawget(_G, "C_Timer")
            local function Read()
                local sc, dbg = Ready()
                local focused = false
                if dbg and dbg.BoxFocus then focused = dbg.BoxFocus() end
                atCombat = { focused = focused and true or false, shown = (sc and sc.Shown()) and true or false, button = ButtonShown(), line = Line(sc, dbg) }
            end
            if T and T.After then T.After(0, Read) else Read() end
        end)
    end
    watch:UnregisterAllEvents()
    watch:RegisterEvent("PLAYER_REGEN_DISABLED")
end

local inCombatBuilds   -- step 2: the build count before /xui stats and SetInput, and after
QA.Register("statcalc-fixes", { title = "Stat Calculator: combat lets go of the keyboard and builds nothing; no cooldown work while closed; Influences column (SC-001, SC-002, SC-081, SC-102)",
    area = "Bonus", qa = "E1z230", order = 525, prefill = true, steps = {
    { text = "Out of combat, with the character window open (C), press |cffffd100Do it for me|r: the Stat Calculator opens on its Stats tab. Then click into a |cffffd100Change|r box (for example Critical Strike's) and type a digit, but do not press Enter. Now attack a training dummy. Once you are in combat, press |cffffd100Check|r.\n\n|cffffd100Expect:|r as combat starts the box lets go of the keyboard (your keys cast again), and the panel and the Stat Calc button hide, with no message.",
        setup = function()
            local sc, dbg, why = Ready(); if not sc then error(why) end
            if InCombat() then error("you are in combat: leave combat first") end
            Remember(sc)
            local ok, w2 = sc.Open("stats")
            if not ok then error(w2 or "the panel did not open") end
            Watch()
        end,
        check = function()
            local sc, dbg, why = Ready(); if not sc then return nil, why end
            if not atCombat then return nil, "combat has not started since Do it for me: click into a Change box, then attack a training dummy | " .. Line(sc, dbg) end
            local ok = not atCombat.focused and not atCombat.shown and not atCombat.button
            return ok, "just after combat started: " .. atCombat.line
        end },
    { text = "Still in combat, press |cffffd100Do it for me|r: XayaUI types |cffffd100/xui stats|r for you and puts 100 into the Critical Strike box through the Stat Calculator's own service.\n\n|cffffd100Expect:|r nothing opens, nothing is said in chat, and the Stat Calculator builds no stat model (the count it keeps stays the same).",
        setup = function()
            local sc, dbg, why = Ready(); if not sc then error(why) end
            if not InCombat() then error("not in combat: attack a training dummy first, then press Do it for me while fighting") end
            local before = dbg.Builds()
            local ns = NS()
            if ns and ns.RunCommand then pcall(ns.RunCommand, "stats", "") end
            pcall(sc.SetInput, "crit", "100")
            inCombatBuilds = { before = before, after = dbg.Builds(), shown = sc.Shown(), crit = sc.Cfg().whatIfStats and sc.Cfg().whatIfStats.crit }
        end,
        check = function()
            local sc, dbg, why = Ready(); if not sc then return nil, why end
            if not inCombatBuilds then return nil, "press Do it for me while in combat" end
            local b = inCombatBuilds
            local ok = b.before == b.after and not b.shown and (saved == nil or b.crit == saved.crit)
            return ok, ("stat models built: %s before, %s after; panel %s; Critical Strike's typed number %s | %s"):format(tostring(b.before), tostring(b.after),
                b.shown and "opened" or "stayed hidden", tostring(b.crit or "none"), Line(sc, dbg))
        end },
    { text = "Stop attacking and wait for combat to end, with the character window open. Then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the panel is back beside the window and the Stat Calc button shows again.",
        check = function()
            local sc, dbg, why = Ready(); if not sc then return nil, why end
            if InCombat() then return nil, "still in combat: wait for it to end | " .. Line(sc, dbg) end
            if not WindowShown() then return nil, "open the character window (C) | " .. Line(sc, dbg) end
            return (sc.Shown() and ButtonShown()) and true or false, Line(sc, dbg)
        end },
    { text = "Press |cffffd100Do it for me|r: the Stat Calculator closes. Cast a few spells (out of combat is fine), then press |cffffd100Check|r.\n\n|cffffd100Expect:|r with the panel closed the Stat Calculator does not listen to the cooldown event (SPELL_UPDATE_COOLDOWN) and builds nothing while you cast.",
        setup = function()
            local sc, dbg, why = Ready(); if not sc then error(why) end
            if InCombat() then error("you are in combat: wait for it to end") end
            Remember(sc)
            if sc.Shown() then sc.Close() end
            inCombatBuilds = { closedAt = dbg.Builds() }
        end,
        check = function()
            local sc, dbg, why = Ready(); if not sc then return nil, why end
            local at = inCombatBuilds and inCombatBuilds.closedAt
            if at == nil then return nil, "press Do it for me first" end
            local cd = dbg.Registered("SPELL_UPDATE_COOLDOWN")
            local ok = not sc.Shown() and not cd and dbg.Builds() == at
            return ok, ("panel %s; cooldown event %s; stat models built since it closed: %d"):format(sc.Shown() and "shown" or "closed",
                cd and "registered" or "not registered", (tonumber(dbg.Builds()) or 0) - (tonumber(at) or 0))
        end },
    { text = "Press |cffffd100Do it for me|r: the Stat Calculator opens on its Stats tab. Scroll down to |cffffd100Stat Weights|r. (Leave the panel at its default width: do not drag its corner.)\n\n|cffffd100Expect:|r six column titles, the last one |cffffd100Influences|r, and each stat's influences (for example \"Parry (+10.15%)\" for Critical Strike) on the stat's own row under that title, not on a line under the row, without \"Influences:\" in front. Every column title stays on one line.\n\n|cffffd100Note:|r the sixth column is used only when all six titles fit on one line. If your game font is wider, you may instead see five titles and each stat's influences on a line under its row, starting with \"Influences:\". That is the open choice between the six columns and one-line titles (SC-102, for Xaya), not a fault: the addon then offers no verdict; Pass if nothing is cut or overlapping, and say so in the note.",
        setup = function()
            local sc, dbg, why = Ready(); if not sc then error(why) end
            if InCombat() then error("you are in combat: wait for it to end") end
            local ok, w2 = sc.Open("stats")
            if not ok then error(w2 or "the panel did not open") end
        end,
        check = function()
            local sc, dbg, why = Ready(); if not sc then return nil, why end
            local d = sc.Shown() and sc.Drawn()
            if not d then return nil, "the panel is not shown: press Do it for me" end
            local heads, head, labelY, rows, onRow, prefixed = 0, nil, {}, 0, 0, 0
            for _, r in ipairs(d.layout or {}) do
                if r.kind == "wcolhead" then heads = heads + 1; if r.text == "Influences" then head = r end end
                if r.kind == "wlabel" then labelY[r.y] = true end
            end
            for _, r in ipairs(d.layout or {}) do
                if r.kind == "winfl" then
                    rows = rows + 1
                    if head and r.x == head.x and labelY[r.y] then onRow = onRow + 1 end
                    if tostring(r.text):find("^Influences: ") then prefixed = prefixed + 1 end
                end
            end
            local c = sc.Cfg()
            local w = c and c.size and c.size.w
            if rows == 0 then return nil, "no Stat Weights rows are drawn: open the Stats tab and unfold Stat Weights" end
            -- (round 2) five titles, every row's influences under it with its "Influences:" label: the kept one-line-titles fallback where
            -- six one-line titles do not fit this font (the open SC-102 choice): no verdict from the addon
            if heads == 5 and head == nil and prefixed == rows then
                return nil, ("five column titles; all %d rows have their influences on a line under the row, labeled (six one-line titles do not fit this font at panel width %s: the open SC-102 choice, not a fault)"):format(
                    rows, w and tostring(w) or "default (450)")
            end
            local ok = heads == 6 and head ~= nil and onRow == rows and prefixed == 0
            return ok, ("%d column titles (Influences %s); %d of %d rows have their influences in that column; %d still start with \"Influences:\"; panel width %s"):format(
                heads, head and "there" or "missing", onRow, rows, prefixed, w and tostring(w) or "default (450)")
        end },
    { text = "Did any XayaUI message appear in chat during the fight or when it ended? The addon cannot read chat, so it offers no verdict here: you decide. Press Pass if there was none; press Fail if there was one, and copy it into the note.", noVerdict = true },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put the Stat Calculator back as it was before this walkthrough (its tab, open or closed, Critical Strike's typed number). Then press |cffffd100Done|r.",
        setup = function()
            if watch then watch:UnregisterAllEvents() end
            atCombat, inCombatBuilds = nil, nil
            PutBack()
        end },
} })
