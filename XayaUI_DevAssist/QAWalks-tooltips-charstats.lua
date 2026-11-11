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
