-------------------------------------------------------------------------------
-- QAWalks-tooltips-charstats.lua (XayaUI Dev Assist): the in-game walkthrough for Enhanced Tooltips > Character stats keeping its stat
-- models between hovers (XayaUI_Bonus/Tooltips.lua section 5; Stat Calculator review SC-047 and SC-035, hover side; V25 unit E).
-- Before: every hover of a stat in the character window rebuilt the whole stat model. Now: one build per change in stats; the models
-- are dropped when Blizzard updates the window's stats, when the window shows or hides, and on equipment / item data / gem / enchant /
-- spellbook changes; nothing is kept while the window is closed.
-- Standing rule V22 (Xaya 2026-11-07): the addon offers its own verdict where it can read the result (prefill = true; recorded only on
-- her click) and captures the numbers it reads into the step's note. Reached through the "tooltipsDebug" service only (its TT table:
-- TT.charStatsState.builds, the read-only build counter; TT.charStatsState.drops, how many times kept models were dropped;
-- TT.CharStatsKept; TT.CharStatLines). Listed in XayaUI_DevAssist.toc after the other QAWalks files; does nothing without the
-- framework. UNTESTED IN GAME.
-- This file also holds a second walkthrough, "tooltips-charstats-gate" (gate findings G-013 / G-018; see its own header below).
-- Round 2 (review of unit E): step 2 allows one more build per drop seen while she hovers (a buff or stat tick makes Blizzard update
-- the window, which rightly drops the models), so a correct build cannot fail; step 3 first keeps a model (Do it for me), then needs a
-- build after the swap, so it cannot pass when nothing was rebuilt; the rating is read digits only (any thousands separator).
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Svc(n) local ns = NS(); return ns and ns.Service and ns.Service(n) end
local function TTs() local s = Svc("tooltipsDebug"); return s and s.TT end
local function Secret(v) local f = rawget(_G, "issecretvalue"); return (f and f(v)) and true or false end
local function WindowShown()
    local pf = rawget(_G, "PaperDollFrame")
    local ok, v = pcall(function() return pf and pf:IsVisible() end)
    return (ok and v) and true or false
end

-- is the option in effect? returns TT or nil and why not
local function Ready()
    local TT = TTs()
    if not (TT and TT.charStatsState and TT.CharStatLines) then return nil, "XayaUI Bonus Features is off (no Enhanced Tooltips)" end
    if TT.CharStatsKept == nil or TT.charStatsState.builds == nil then return nil, "XayaUI Bonus Features is older than this change (no build counter)" end
    local db = TT.DB and TT.DB() or {}
    if db.enabled == false then return nil, "Enhanced Tooltips is off: tick its row in Bonus Features" end
    if db.charStats ~= true then return nil, "Character stats is unticked: Bonus Features > Enhanced Tooltips > Character stats" end
    if not TT.charStatsOn then return nil, "the lines are not on: XayaUI QoL > Improved Character Display must be ticked too" end
    return TT
end

local base, baseDrops   -- the build and drop counters when the step's Do it for me ran
local armed3            -- step 3's Do it for me ran (its own, not step 2's counter)
local function Drops(TT) return tonumber(TT.charStatsState.drops) or 0 end
local function CounterLine(TT)
    return ("builds since the login %d (at the step's start %s); drops %d (at the step's start %s); models kept now %d; character window %s"):format(
        TT.charStatsState.builds, base and tostring(base) or "?", Drops(TT), baseDrops and tostring(baseDrops) or "?", TT.CharStatsKept(),
        WindowShown() and "open" or "closed")
end
local CRIT = function() return rawget(_G, "STAT_CRITICAL_STRIKE") or "Critical Strike" end

-- the XayaUI crit "Rating" line and the game's own crit ratings
local function CritNumbers(TT)
    local ok, lines = pcall(TT.CharStatLines, CRIT())
    local text
    for _, l in ipairs(ok and type(lines) == "table" and lines or {}) do if l[1] == "Rating" then text = tostring(l[2]) end end
    -- the rating is a whole number: keep the digits before " = " (any locale's thousands separator drops out)
    local digits = text and ((text:match("^(.-)%s*=") or text):gsub("%D", "")) or ""
    local mine = digits ~= "" and tonumber(digits, 10) or nil
    local game, shown = {}, {}
    for _, e in ipairs({ { "CR_CRIT_MELEE", 9, "melee" }, { "CR_CRIT_RANGED", 10, "ranged" }, { "CR_CRIT_SPELL", 11, "spell" } }) do
        local idx = rawget(_G, e[1]) or e[2]
        local okr, v = pcall(GetCombatRating, idx)
        if okr and v ~= nil and not Secret(v) and type(v) == "number" then game[#game + 1] = v; shown[#shown + 1] = e[3] .. " " .. v
        else shown[#shown + 1] = e[3] .. " (not readable)" end
    end
    return mine, text, game, table.concat(shown, ", ")
end

QA.Register("tooltips-charstats-cache", { title = "Character window stat tooltips: one model build per change in stats, not per hover (SC-047, SC-035)",
    area = "Bonus", qa = "E1z237", order = 526, prefill = true, steps = {
    { text = "Out of combat, standing still: make sure |cffffd100Bonus Features > Enhanced Tooltips|r and its |cffffd100Character stats|r are ticked, and |cffffd100QoL > Improved Character Display|r is ticked. Open the character window (C).\n\n|cffffd100Expect:|r the check says the lines are on and the window is open.",
      check = function()
          local TT, why = Ready()
          if not TT then return nil, why end
          if not WindowShown() then return nil, "open the character window (C), then check again | " .. CounterLine(TT) end
          return true, CounterLine(TT)
      end },
    { text = "Press |cffffd100Do it for me|r (it notes the build counter). Then, without changing gear or buffs, hover |cffffd100Critical Strike|r, |cffffd100Haste|r and |cffffd100Mastery|r in the character window's stats, one after the other, and press |cffffd100Check|r.\n\n|cffffd100Expect:|r each hover shows the XayaUI block; the counter rose by at most one (one build for the three hovers), plus one for each time the game updated the window's stats meanwhile (a buff or stat tick; the check counts those as drops).",
      setup = function() local TT = Ready(); base = TT and TT.charStatsState.builds or nil; baseDrops = TT and Drops(TT) or nil end,
      check = function()
          local TT, why = Ready()
          if not TT then return nil, why end
          if base == nil then return nil, "press Do it for me first (it notes the counter) | " .. CounterLine(TT) end
          if not WindowShown() then return nil, "the character window is closed: open it, press Do it for me and hover again | " .. CounterLine(TT) end
          local rose = TT.charStatsState.builds - base
          if TT.CharStatsKept() == 0 and rose == 0 then return nil, "no hover seen yet: hover the three stats, then check | " .. CounterLine(TT) end
          local dropped = Drops(TT) - (baseDrops or Drops(TT))
          return rose <= 1 + dropped, ("the counter rose by %d for the hovers, with %d drop(s) meanwhile (allowed %d) | "):format(rose, dropped,
              1 + dropped) .. CounterLine(TT)
      end },
    { text = "With the character window open, press |cffffd100Do it for me|r (it builds and keeps the stat model and notes the counter). Then equip a different item (any slot, for example another trinket or ring from your bags), hover |cffffd100Critical Strike|r and read Blizzard's own number on it (its critical strike rating). Press |cffffd100Check|r.\n\n|cffffd100Expect:|r the model was built again after the swap (the counter rose), and the XayaUI |cffffd100Rating|r line shows the same rating as the game; the check captures both for you.",
      setup = function()
          local TT = Ready()
          if TT and WindowShown() then pcall(TT.CharStatLines, CRIT()) end   -- (keeps a model, so the swap has one to drop)
          base = TT and TT.charStatsState.builds or nil; baseDrops = TT and Drops(TT) or nil
          armed3 = base ~= nil
      end,
      check = function()
          local TT, why = Ready()
          if not TT then return nil, why end
          if not armed3 or base == nil then return nil, "press Do it for me first (it keeps a model and notes the counter) | " .. CounterLine(TT) end
          if not WindowShown() then return nil, "open the character window (C), then check again | " .. CounterLine(TT) end
          local mine, text, game, shown = CritNumbers(TT)
          -- (read after the check's own read: a kept model that was never dropped is reused there and the counter stays put; one
          -- dropped by the swap is built there if her hover did not already build it)
          local rose = TT.charStatsState.builds - base
          local note = ("rebuilt after the swap: %s | XayaUI Rating line: %s | the game's crit ratings: %s | "):format(rose >= 1 and "yes" or "no",
              text or "none", shown) .. CounterLine(TT)
          if rose < 1 then return false, note end
          if mine == nil or #game == 0 then return nil, note end
          local same = false
          for _, v in ipairs(game) do if v == mine then same = true end end
          return same, note
      end },
    { text = "Your look: did any hover show a number that did not match the game's own tooltip above it (after a buff, a gear swap, a talent change)? Pass if every number matched; Fail and say which stat and what you did just before.", noVerdict = true },
    { done = true, text = "Leave Character stats ticked or unticked as you like, then press |cffffd100Done|r." },
} })

-------------------------------------------------------------------------------
-- Second walkthrough in this file: the V27 / V14 gate fixes of Enhanced Tooltips > Character stats (gate findings G-013 and G-018,
-- unit U3-tooltips-charstats; kept in this file so it needs no new toc line).
--   G-018: with Character stats unticked, building the Enhanced Tooltips page only reads whether Improved Character Display is on; it
--          gives Improved Character Display no change callback (TT.charStatsState.subscribed stays false). Ticking it gives one.
--          (round 2) Until then the option's greyed state reads Improved Character Display's switch while the page is drawn, so a
--          switch without a reload is seen; when the callback is given, the switch is read once more (lines only with both on).
--   G-013: the character window's stat rows are walked only when their number changes (TT.charStatsState.rowWalks / rowCount), and
--          the game's stat label strings are made plain once per session, not on every hover (TT.charStatsState.labelPlains).
-- prefill = true (V22): the verdict is offered, recorded only on her click. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local function GateState()
    local TT = TTs()
    local cs = TT and TT.charStatsState
    if not (cs and cs.labelPlains ~= nil and cs.rowWalks ~= nil and TT.CharStatsDisplayOn) then
        return nil, nil, "XayaUI Bonus Features is off or older than this change (no gate counters)"
    end
    return TT, cs
end
local function GateLine(TT, cs)
    local db = TT.DB and TT.DB() or {}
    local pane = rawget(_G, "CharacterStatsPane")
    local okc, n = pcall(function() return pane and select("#", pane:GetChildren()) end)
    return ("Character stats %s; Improved Character Display read as %s; callback given %s; lines %s; rows walked %d time(s) (rows %s, pane now %s); label strings made plain %d; character window %s"):format(
        db.charStats == true and "ticked" or "unticked", TT.CharStatsDisplayOn() and "on" or "off", cs.subscribed and "yes" or "no",
        TT.charStatsOn and "on" or "off", cs.rowWalks, tostring(cs.rowCount), okc and tostring(n) or "?", cs.labelPlains,
        WindowShown() and "open" or "closed")
end
-- the steps before the callback is given need Character stats unticked and the page built since the reload
local function Unticked(TT, cs)
    if (TT.DB and TT.DB() or {}).charStats == true then return "untick Character stats, /reload, open the Enhanced Tooltips page, then check | " .. GateLine(TT, cs) end
    if not cs.read then return "open /xui > Bonus Features > Enhanced Tooltips once (after the /reload), then check | " .. GateLine(TT, cs) end
    if cs.subscribed then return nil end
end

local gateWalks, gatePlains   -- the counters when step 5's Do it for me ran

QA.Register("tooltips-charstats-gate", { title = "Character window stat tooltips: no work while unticked; rows and labels read once (G-013, G-018)",
    area = "Bonus", qa = "E1z239", order = 527, prefill = true, steps = {
    { text = "Out of combat: in |cffffd100Bonus Features > Enhanced Tooltips|r untick |cffffd100Character stats|r (leave |cffffd100QoL > Improved Character Display|r ticked), type |cffffd100/reload|r, then open |cffffd100/xui|r > Bonus Features > Enhanced Tooltips once, come back here and press |cffffd100Check|r.\n\n|cffffd100Expect:|r Character stats is not greyed (Improved Character Display read as on) and no callback was given to Improved Character Display.",
      check = function()
          local TT, cs, why = GateState()
          if not TT then return nil, why end
          local wait = Unticked(TT, cs)
          if wait then return nil, wait end
          return cs.subscribed ~= true and TT.CharStatsDisplayOn() == true, GateLine(TT, cs)
      end },
    { text = "Without a reload: untick |cffffd100QoL > Improved Character Display|r, then go back to the |cffffd100Enhanced Tooltips|r page and press |cffffd100Check|r.\n\n|cffffd100Expect:|r Character stats is greyed now and the note under it asks for Improved Character Display (no reload needed); still no callback.",
      check = function()
          local TT, cs, why = GateState()
          if not TT then return nil, why end
          local wait = Unticked(TT, cs)
          if wait then return nil, wait end
          if TT.CharStatsDisplayOn() then return nil, "untick Improved Character Display (QoL), then check | " .. GateLine(TT, cs) end
          return cs.subscribed ~= true and TT.charStatsOn ~= true, GateLine(TT, cs)
      end },
    { text = "Still without a reload: tick |cffffd100Improved Character Display|r again, go back to the |cffffd100Enhanced Tooltips|r page and press |cffffd100Check|r.\n\n|cffffd100Expect:|r Character stats is not greyed any more (you can tick it); still no callback.",
      check = function()
          local TT, cs, why = GateState()
          if not TT then return nil, why end
          local wait = Unticked(TT, cs)
          if wait then return nil, wait end
          if not TT.CharStatsDisplayOn() then return nil, "tick Improved Character Display (QoL) again, then check | " .. GateLine(TT, cs) end
          return cs.subscribed ~= true, GateLine(TT, cs)
      end },
    { text = "Now tick |cffffd100Character stats|r on the same page (no reload) and press |cffffd100Check|r.\n\n|cffffd100Expect:|r the callback is given now, once, and the lines are on (the lines follow Improved Character Display from here on).",
      check = function()
          local TT, cs, why = GateState()
          if not TT then return nil, why end
          if (TT.DB and TT.DB() or {}).charStats ~= true then return nil, "tick Character stats, then check | " .. GateLine(TT, cs) end
          return cs.subscribed == true and TT.charStatsOn == true, GateLine(TT, cs)
      end },
    { text = "Open the character window (C) and hover any stat once. Press |cffffd100Do it for me|r (it notes the counters). Then hover |cffffd100Critical Strike|r, |cffffd100Haste|r and |cffffd100Mastery|r a few times each, wait for a buff or a stat to tick (or swap a ring and back), and press |cffffd100Check|r.\n\n|cffffd100Expect:|r the label strings were not made plain again, and the rows were walked again only if their number changed (the check compares).",
      setup = function()
          local _, cs = GateState()
          gateWalks = cs and cs.rowWalks or nil; gatePlains = cs and cs.labelPlains or nil
      end,
      check = function()
          local TT, cs, why = GateState()
          if not TT then return nil, why end
          if gateWalks == nil then return nil, "press Do it for me first (it notes the counters) | " .. GateLine(TT, cs) end
          if not WindowShown() then return nil, "open the character window (C), then check again | " .. GateLine(TT, cs) end
          if cs.labelPlains == 0 then return nil, "no hover seen yet: hover a stat, then check | " .. GateLine(TT, cs) end
          local pane = rawget(_G, "CharacterStatsPane")
          local okc, n = pcall(function() return pane and select("#", pane:GetChildren()) end)
          local note = ("since Do it for me: rows walked +%d, label strings made plain +%d | "):format(cs.rowWalks - gateWalks,
              cs.labelPlains - gatePlains) .. GateLine(TT, cs)
          if not okc then return nil, note end
          -- pass: no label work after the first hover, and the last walk saw the pane's present row count
          return cs.labelPlains == gatePlains and cs.rowCount == n, note
      end },
    { text = "Your look: did every stat row you hovered still show its XayaUI block (rating, rating per 1%, what it feeds)? Pass if yes; Fail and say which row did not.", noVerdict = true },
    { done = true, text = "Leave Character stats ticked or unticked as you like, then press |cffffd100Done|r." },
} })
