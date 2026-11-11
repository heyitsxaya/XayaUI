-------------------------------------------------------------------------------
-- QAWalks-influences.lua (XayaUI Dev Assist): the in-game walkthrough for the Stat Weights pane's Influences column and its alignment
-- (XayaUI Bonus Features, StatCalculator.lua WeightCols / RenderWeights; REQUEST-LOG A24 #7). Xaya's answer, her words (2026-11-11):
-- "2 but make sure all headings (top row) are vertically middle-aligned or bottom-aligned and all rows beneath are uniformly vertically
-- aligned amongst themselves"; option 2 was "Influences is always its own column, and titles wrap onto two lines when needed".
-- Built as: Influences is a column at every panel width and text size; a column title may wrap, onto at most two lines where the
-- columns' widest words leave room; the six titles are bottom-aligned (her words allow middle or bottom: bottom was chosen); every
-- cell of a row starts at the row's top. The checks also ask the game whether any title or cell is cut short (Fail if one is).
-- (A24 #9, Xaya 2026-11-11, her words: "Widen the panel") the panel widens to the width the six columns' widest words need at the
-- current text size, docked and on its own (never wider than the screen), so nothing is cut at any width the corner allows; step 2
-- checks that at the narrowest panel and the largest text, and its note gives the width the panel was drawn at.
-- Standing rule V22 (Xaya 2026-11-07, her words): "make sure every feature or significant change to the codebase / bug report fixes
-- have an in game qa test walk through with pre-fill confirmation options or data capturing". prefill = true: where the addon can read
-- the result (what the panel drew and where its font strings are anchored) its verdict is offered on one button and recorded only on a
-- click (QAWalk.lua); the step marked noVerdict asks what only the person can see.
-- Reaches XayaUI Bonus Features only through core's "statCalc" service (Cfg, Open, Close, Shown, Drawn). Creates no frame, registers
-- no event, runs nothing until a step's button is pressed; gives no frame the keyboard or the mouse. What "Do it for me" changes (the
-- panel's tab, open or closed) is remembered in step 1 and put back in the last step. Listed in XayaUI_DevAssist.toc after the other
-- QAWalks files (the integration step adds the line); does nothing without the framework. UNVERIFIED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Svc(n) local ns = NS(); return ns and ns.Service and ns.Service(n) or nil end
local function InCombat() local f = rawget(_G, "InCombatLockdown"); return (type(f) == "function" and f()) and true or false end

local function Ready()
    local sc = Svc("statCalc")
    if not sc then return nil, "XayaUI Bonus Features or XayaUI QoL is off (the Stat Calculator needs both)" end
    local c = sc.Cfg and sc.Cfg()
    if not (c and c.enabled and c.panel) then return nil, "Bonus Features > Stat Calculator and its Panel must be on: tick both" end
    return sc
end

-- the shown font string drawn for one layout record: same text, anchored at the record's x and y (what the player sees, not the record)
local function DrawnAt(d, r)
    for _, f in ipairs(d.fonts or {}) do
        local okS, shown = pcall(f.IsShown, f)
        local okT, text = pcall(f.GetText, f)
        if okS and shown and okT and text == r.text then
            local ok, _, _, _, x, y = pcall(f.GetPoint, f, 1)
            if ok and type(x) == "number" and type(y) == "number" and math.abs(x - r.x) < 0.5 and math.abs(-y - r.y) < 0.5 then return f end
        end
    end
    return nil
end
-- (round 2) whether the game cut a drawn text short: FontString:IsTruncated() -> isTruncated: bool (SecretWhenAnchoringSecret,
-- docs/reference/api/widgets.md:1497). true / false when readable; nil when the call is missing, fails or gives a secret or non-boolean
-- answer (then the step gives no verdict on cut text). INFERENCE (not documented): a wrapping font string that cannot fit one of its
-- words reports true. UNVERIFIED IN GAME.
local function Truncated(f)
    if not (f and type(f.IsTruncated) == "function") then return nil end
    local ok, t = pcall(f.IsTruncated, f)
    local sec = rawget(_G, "issecretvalue")
    if not ok or (type(sec) == "function" and sec(t)) or type(t) ~= "boolean" then return nil end
    return t
end

-- what the Stat Weights pane drew: a verdict and a note (nil verdict when nothing to judge yet)
local CELLS = { wlabel = true, wrating = true, wppp = true, wdr = true, wtl = true, winfl = true }
local function Judge(sc)
    local d = sc.Shown() and sc.Drawn()
    if not d then return nil, "the panel is not shown: press Do it for me" end
    local heads, labels, infl = {}, {}, {}
    for _, r in ipairs(d.layout or {}) do
        if r.kind == "wcolhead" then heads[#heads + 1] = r
        elseif r.kind == "wlabel" then labels[#labels + 1] = r
        elseif r.kind == "winfl" then infl[#infl + 1] = r end
    end
    local c = sc.Cfg()
    local where = ("panel width %s, text size %s"):format(c.size and c.size.w and tostring(c.size.w) or "default (450)", tostring(c.fontSize or 11))
    if type(d.width) == "number" then where = where .. ("; drawn %d wide (A24 #9: widened to fit the six columns where needed)"):format(d.width) end
    if #labels == 0 then return nil, "no Stat Weights rows are drawn: open the Stats tab and unfold Stat Weights | " .. where end
    local bad = {}
    -- (round 2) nothing cut short: every title and cell of the pane, as the game reports it on the drawn font string
    local cut, unread = {}, 0
    for _, r in ipairs(d.layout or {}) do
        if r.kind == "wcolhead" or CELLS[r.kind] or r.kind == "wpppdr" then
            local f = DrawnAt(d, r)
            local t = f and Truncated(f)
            if t == true then cut[#cut + 1] = tostring(r.text) elseif t == nil then unread = unread + 1 end
        end
    end
    if #cut > 0 then bad[#bad + 1] = #cut .. " texts cut short (" .. table.concat(cut, " | ", 1, math.min(#cut, 6)) .. (#cut > 6 and " | ..." or "") .. ")" end
    -- six titles, the last Influences
    local names = {}
    for _, h in ipairs(heads) do names[#names + 1] = tostring(h.text) end
    if #heads ~= 6 or heads[6].text ~= "Influences" then bad[#bad + 1] = "titles: " .. table.concat(names, " | ") end
    -- every row's influences on the row itself, in that column, unlabeled
    local onRow = 0
    for i, r in ipairs(infl) do
        local l = labels[i]
        if l and heads[6] and r.x == heads[6].x and r.y == l.y and not tostring(r.text):find("^Influences: ") then onRow = onRow + 1 end
    end
    if onRow ~= #labels then bad[#bad + 1] = ("%d of %d rows have their influences in the Influences column on the row"):format(onRow, #labels) end
    -- the titles share one bottom edge, each drawn where its record says
    local bottom, wrapped = nil, 0
    for _, h in ipairs(heads) do
        bottom = bottom or (h.y + h.h)
        if h.y + h.h ~= bottom then bad[#bad + 1] = ("title %s ends at %d, not %d"):format(tostring(h.text), h.y + h.h, bottom) end
        if not DrawnAt(d, h) then bad[#bad + 1] = ("title %s is not drawn at its place"):format(tostring(h.text)) end
        if (h.h or 0) > (h.size or 0) then wrapped = wrapped + 1 end
    end
    -- every cell of a row starts at the row's top
    local misaligned = 0
    for i, l in ipairs(labels) do
        local nextTop = labels[i + 1] and labels[i + 1].y or math.huge
        local first = {}
        for _, r in ipairs(d.layout or {}) do
            if CELLS[r.kind] and r.y >= l.y and r.y < nextTop and (not first[r.kind] or r.y < first[r.kind]) then first[r.kind] = r.y end
        end
        for _, y in pairs(first) do if y ~= l.y then misaligned = misaligned + 1 end end
    end
    if misaligned > 0 then bad[#bad + 1] = misaligned .. " cells do not start at their row's top" end
    local note = ("%d column titles (%s), %d wrapped onto more lines; %d of %d rows with their influences in the column; %s"):format(#heads,
        table.concat(names, " | "), wrapped, onRow, #labels, where)
    if #bad > 0 then return false, table.concat(bad, "; ") .. " | " .. note end
    if unread > 0 then return nil, unread .. " texts: the game did not say whether they are cut short, so no verdict: look for a word ending in \"...\" and answer by hand | " .. note end
    return true, note
end

local saved
local function Remember(sc)
    local c = sc.Cfg()
    if saved or not c then return end
    saved = { tab = c.tab, open = sc.Shown() }
end
local function PutBack()
    local sc = Svc("statCalc")
    local c = sc and sc.Cfg and sc.Cfg()
    if not (c and saved) then saved = nil; return end
    if InCombat() then error("you are in combat: press Do it for me again after combat") end
    c.tab = saved.tab
    if saved.open then sc.Open(saved.tab) elseif sc.Shown() then sc.Close() end
    saved = nil
end
local function OpenStats()
    local sc, why = Ready(); if not sc then error(why) end
    if InCombat() then error("you are in combat: wait for it to end") end
    Remember(sc)
    local ok, w2 = sc.Open("stats")
    if not ok then error(w2 or "the panel did not open") end
end
local function Check()
    local sc, why = Ready(); if not sc then return nil, why end
    return Judge(sc)
end
-- (A24 #9) step 2 remembers the width the corner left (the saved width) for step 4
local step2Saved
local function CheckNarrow()
    local sc, why = Ready(); if not sc then return nil, why end
    local c = sc.Cfg()
    step2Saved = (c and type(c.size) == "table" and c.size.w) or false
    return Judge(sc)
end
-- (A24 #9) step 4: the corner pressed without a drag keeps the saved width; off the Stats tab the panel is drawn at it; the tab row in
-- whole pixels (V27), side by side, the last ending at the content's right edge
local function CheckGrip()
    local sc, why = Ready(); if not sc then return nil, why end
    if step2Saved == nil then return nil, "do step 2 first (press its Check)" end
    local c = sc.Cfg()
    local w = sc.Window and sc.Window()
    if not (w and w.shown) then return nil, "the panel is not shown: open it again (/xui stats) on the Gear tab" end
    if c.tab ~= "gear" then return nil, "click the Gear tab, then press Check" end
    local want = step2Saved or 450
    local note = ("saved width %s (step 2: %s), drawn %s wide"):format(tostring(w.savedWidth or "default (450)"), tostring(step2Saved or "default (450)"), tostring(w.width))
    local bad = {}
    if (w.savedWidth or false) ~= step2Saved then bad[#bad + 1] = "the saved width changed" end
    if w.width ~= want then bad[#bad + 1] = "the panel is not drawn at the saved width on the Gear tab" end
    local x = w.pad
    for i, t in ipairs(w.tabs or {}) do
        if not (type(t.x) == "number" and type(t.w) == "number" and t.x == math.floor(t.x) and t.w == math.floor(t.w) and t.x >= x and t.x <= x + 1) then
            bad[#bad + 1] = ("tab %d at x %s, %s wide (not whole pixels or not side by side)"):format(i, tostring(t.x), tostring(t.w))
        else x = t.x + t.w + 2 end
    end
    if #bad == 0 and type(w.content) == "number" and x ~= w.pad + w.content then bad[#bad + 1] = ("the tabs end at %s, the content at %s"):format(tostring(x), tostring(w.pad + w.content)) end
    if #bad > 0 then return false, table.concat(bad, "; ") .. " | " .. note end
    return true, note
end

QA.Register("statcalc-influences", { title = "Stat Calculator: Stat Weights Influences column at every width, titles bottom-aligned (A24 #7)",
    area = "Bonus", qa = "E1z242", order = 526, prefill = true, steps = {
    { text = "Out of combat, press |cffffd100Do it for me|r: the Stat Calculator opens on its Stats tab. Scroll down to |cffffd100Stat Weights|r (unfold it if it is folded), then press |cffffd100Check|r.\n\n|cffffd100Expect:|r six column titles, the last one |cffffd100Influences|r; each stat's influences on the stat's own row under that title, without \"Influences:\" in front. A title may wrap onto two lines; all titles end on the same bottom line. Every cell of a row starts at the row's top. Nothing is cut short.",
        setup = OpenStats, check = Check },
    { text = "Drag the panel's bottom-right corner to make it as narrow as it goes, and set the Stat Calculator's text size to its largest (Bonus Features > Stat Calculator). Scroll to |cffffd100Stat Weights|r and press |cffffd100Check|r.\n\n|cffffd100Expect:|r still six columns with Influences last, its names on each row; titles that no longer fit wrap and stay bottom-aligned with the others. The addon asks the game whether any title or cell is cut short and gives Fail if one is. (A24 #9, \"Widen the panel\") where the six columns' widest words need more room than the narrow panel has, the panel widens to fit them at this text size, so nothing is cut short; the note gives the width it was drawn at. A title may still wrap: where the panel widened, \"Rating (P / %)\" can take three lines (the panel widens to the widest words, not to two-line titles: reported to Xaya, not built). If your screen is narrower than that width the panel stops at the screen's edge, and words can be cut there. Note anything overlapping: the addon cannot see that.",
        check = CheckNarrow },
    { text = "Look at the Stat Weights pane as it is now. Do the six column titles read as one row sitting on a shared bottom line, and do the rows below line up the same way, each starting at the same height across its cells? Is any word cut short (\"...\")? The addon cannot judge how it looks: Pass if it reads well, Fail and describe it in the note if not.",
        noVerdict = true },
    { text = "Click once on the panel's bottom-right corner without moving the mouse, then click the |cffffd100Gear|r tab. Press |cffffd100Check|r.\n\n|cffffd100Expect:|r on the Gear tab the panel is back at the width you dragged it to in step 2: the wider width was only for Stat Weights and the click did not save it. The three tabs sit side by side across the top. (A24 #9)",
        check = CheckGrip },
    { done = true, text = "Last step: put the panel's width and text size back where you had them, then press |cffffd100Do it for me|r to put the Stat Calculator back as it was before this walkthrough (its tab, open or closed). Then press |cffffd100Done|r.",
        setup = function() PutBack() end },
} })
