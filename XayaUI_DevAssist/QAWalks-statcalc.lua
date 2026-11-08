-------------------------------------------------------------------------------
-- QAWalks-statcalc.lua (XayaUI Dev Assist 0.7.13): the in-game QA walkthroughs for the Stat Calculator round of 2026-11-07 (XayaUI QoL
-- 0.7.40, XayaUI Options 0.6.64; REQUEST-LOG #87-#91, B2, B6; QA-CHECKLIST E1z195-E1z200). Xaya's rule (2026-11-07, V22, her words):
-- "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill
-- confirmation options or data capturing". One walkthrough per item, prefill = true (QAWalk.lua: the addon offers its own verdict on
-- one button; nothing is recorded without the person's click). A step marked noVerdict asks something only the person can see.
-- Every read goes through core's service list (Modules.lua ns.Service): "statCalc" (XayaUI QoL, CharacterToolkit.lua) and "infoPane"
-- (XayaUI Options, InfoPane.lua; Options loads on demand, ns.LoadOptions). No other addon's own tables are named here.
-- What "Do it for me" changes (the panel's tab, open / closed, which stats are open, a compared item) is remembered in the first step
-- and put back in the last one. Listed in XayaUI_DevAssist.toc after the other QAWalks files; does nothing without the framework.
-- UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Svc(name) local ns = NS(); return ns and ns.Service and ns.Service(name) or nil end
local function SC() return Svc("statCalc") end

-- "is the Stat Calculator there?" (XayaUI QoL loaded, the Character Toolkit on)
local function Ready()
    local sc = SC()
    if not sc then return false, "XayaUI Bonus Features is not loaded (or is older than 0.6.37), or XayaUI QoL is off" end
    local c = sc.Cfg()
    if not (c and c.enabled) then return false, "the Character Toolkit is off: XayaUI > Bonus Features > Stat Calculator" end
    if not c.panel then return false, "the Stat Calculator panel is off: Bonus Features > Stat Calculator > Panel" end
    return true
end
local function Drawn()
    local sc = SC()
    local d = sc and sc.Shown() and sc.Drawn()
    return d
end
local function Recs(d, kind) local out = {}; for _, r in ipairs(d and d.layout or {}) do if r.kind == kind then out[#out + 1] = r end end; return out end
local function Find(d, kind, text) for _, r in ipairs(d and d.layout or {}) do if r.kind == kind and r.text == text then return r end end end
local function Open(tab)
    local ok, why = Ready(); if not ok then error(why) end
    local done, w2 = SC().Open(tab)
    if not done then error(w2 or "the panel did not open") end
end

-- what these walkthroughs change, remembered at the start and put back at the end
local saved
local function Remember()
    local sc = SC(); local c = sc and sc.Cfg()
    if not c then return end
    saved = { tab = c.tab, open = sc.Shown(), statOpen = {} }
    for k, v in pairs(c.statOpen or {}) do saved.statOpen[k] = v end
end
local function PutBack()
    local sc = SC(); local c = sc and sc.Cfg()
    if not (c and saved) then return end
    c.tab = saved.tab
    c.statOpen = {}
    for k, v in pairs(saved.statOpen) do c.statOpen[k] = v end
    if saved.open then sc.Open(saved.tab) elseif sc.Shown() then sc.Close() end
    saved = nil
end
local function PutBackStep(extra)
    return { done = true, text = "Last step: press |cffffd100Do it for me|r to put the Stat Calculator back as it was before this walkthrough (its tab, open or closed, which stats were open" .. (extra or "") .. "). Then press |cffffd100Done|r.",
        setup = function() PutBack() end,
        check = function() return saved == nil, saved == nil and "put back" or "press Do it for me" end }
end

-- the stat a drawn label belongs to: its row's y range (from its label to the next stat label)
local function RowOf(d, label)
    local L = Find(d, "label", label)
    if not L then return nil end
    local nextY = math.huge
    for _, r in ipairs(Recs(d, "label")) do if r.y > L.y and r.y < nextY then nextY = r.y end end
    return L, nextY
end
local function Under(d, label, kind)
    local L, nextY = RowOf(d, label)
    local out = {}
    if not L then return out end
    for _, r in ipairs(d.layout) do if r.kind == kind and r.y >= L.y and r.y < nextY then out[#out + 1] = r end end
    return out
end
local function FoldMark(d, label)
    local L = Find(d, "label", label)
    if not L then return nil end
    for _, r in ipairs(Recs(d, "fold")) do if math.abs(r.y - L.y) < 1 then return r.text end end
end

-- A. #87 / #88: rows under each stat, folded by default, remembered per stat; the "Modifies" column ------------------------------
local AP = "Attack Power"
local function APState()
    local ok, why = Ready(); if not ok then return nil, why end
    local d = Drawn()
    if not d then return nil, "the Stat Calculator is not open (press Do it for me)" end
    if not Find(d, "label", AP) then return nil, "no Attack Power line on the Stats tab (a spec without attack power: use a Strength or Agility character)" end
    local rows = {}
    for _, r in ipairs(Under(d, AP, "pairLabel")) do rows[#rows + 1] = r.text end
    return { d = d, mark = FoldMark(d, AP), rows = rows, open = SC().Cfg().statOpen.map_ap == true }
end
QA.Register("statcalc-rows", { title = "Stat Calculator: open a stat with + to see what adds to it, and the Modifies column", qa = "E1z195", order = 190, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the Stat Calculator opens on its |cffffd100Stats|r tab (XayaUI remembers how it was, to put it back at the end).\n\n|cffffd100Expect:|r the column heads read Stat | Current value | Pt value | Change | |cffffd100Modifies|r (no \"Influences\", no \"Modified By\").",
      setup = function()
          Remember(); Open("stats")
          if SC().Cfg().statOpen.map_ap then SC().ToggleStat("map_ap") end   -- (folded to start with; put back at the end)
      end,
      check = function()
          local ok, why = Ready(); if not ok then return false, why end
          local d = Drawn(); if not d then return false, "the panel is not open" end
          local has = Find(d, "colhead", "Modifies") ~= nil
          local old = Find(d, "colhead", "Influences") or Find(d, "colhead", "Modified By")
          return has and not old, has and (old and ("an old head is still drawn: " .. old.text) or "Modifies head drawn, no Influences / Modified By") or "no Modifies head"
      end },
    { text = "Find |cffffd100Attack Power|r (under Offensive).\n\n|cffffd100Expect:|r a small |cffffd100+|r left of its name and no lines under it (folded is the default). In its |cffffd100Modifies|r cell only what it applies to (Damage per second), no \"from ...\". Hover the line: the hover lists |cffffd100From Agility|r (or Strength) with its number, and \"Click: show these rows under the stat.\"",
      check = function()
          local s, why = APState(); if not s then return false, why end
          local names = {}
          for _, r in ipairs(Under(s.d, AP, "infl")) do names[#names + 1] = r.text end
          local fromInCol = false
          for _, n in ipairs(names) do if tostring(n):find("^from ") then fromInCol = true end end
          if s.open then return false, "Attack Power is open (it was opened before; fold it and Check again)" end
          return s.mark == "+" and #s.rows == 0 and not fromInCol, ("mark %s, %d rows under it, Modifies: %s"):format(tostring(s.mark), #s.rows, table.concat(names, ", "))
      end },
    { text = "Press |cffffd100Do it for me|r (or click the Attack Power line).\n\n|cffffd100Expect:|r the + becomes |cffffd100-|r and rows appear under it, one indent in, each with its number: |cffffd100from Agility +N|r (or Strength) and, for a spec whose mastery raises attack power, |cffffd100from Mastery +N%|r.",
      setup = function() local s = APState(); if s and not s.open then SC().ToggleStat("map_ap") end end,
      check = function()
          local s, why = APState(); if not s then return false, why end
          local from = 0
          for _, t in ipairs(s.rows) do if tostring(t):find("^from ") then from = from + 1 end end
          local vals = #Under(s.d, AP, "pairValue")
          return s.mark == "-" and from >= 1 and vals >= 1, ("mark %s; rows: %s"):format(tostring(s.mark), table.concat(s.rows, ", "))
      end },
    { text = "Type a number 100 higher than yours in your primary stat's (Agility / Strength) |cffffd100Change|r box and press Enter.\n\n|cffffd100Expect:|r under the |cffffd100from Agility|r row's number, its new value with a + in green (a higher number is better; blue with a XayaUI colour-blind theme), as on the other lines. Clear the box afterwards.",
      check = function()
          local s, why = APState(); if not s then return false, why end
          local ch = Under(s.d, AP, "pairChange")
          return #ch >= 1, #ch >= 1 and ("new value under a row: " .. tostring(ch[1].text)) or "no new value under the rows (type the number first)"
      end },
    { text = "Type |cffffd100/reload|r, then press |cffffd100Do it for me|r to open the Stats tab again.\n\n|cffffd100Expect:|r Attack Power is still open (-), the other stats are still folded (+): the choice is kept per stat.",
      setup = function() Open("stats") end,
      check = function()
          local s, why = APState(); if not s then return false, why end
          local folded = 0
          for _, r in ipairs(Recs(s.d, "fold")) do if r.text == "+" then folded = folded + 1 end end
          return s.open and s.mark == "-" and folded >= 1, ("Attack Power %s; %d other stat(s) still folded"):format(s.open and "open" or "folded", folded)
      end },
    { text = "Press |cffffd100Do it for me|r (or click Attack Power again).\n\n|cffffd100Expect:|r its rows fold back into the hover; the mark is + again.",
      setup = function() local s = APState(); if s and s.open then SC().ToggleStat("map_ap") end end,
      check = function()
          local s, why = APState(); if not s then return false, why end
          return (not s.open) and s.mark == "+" and #s.rows == 0, s.open and "still open" or "folded"
      end },
    PutBackStep(),
} })

-- B. #89: the picked item in the compare list is clearly marked -------------------------------------------------------------------
local function Picked()
    local d = Drawn()
    local out = {}
    for _, b in ipairs(d and d.icons or {}) do if b:IsShown() and b.cand and b.selected then out[#out + 1] = b end end
    return out, d
end
local function FrameOK(b)
    for _, e in ipairs(b.selEdges or {}) do
        if not e:IsShown() then return false, "an edge of the frame is hidden" end
        local layer = e.GetDrawLayer and e:GetDrawLayer()
        if layer ~= "OVERLAY" then return false, "the frame is under the icon (layer " .. tostring(layer) .. ")" end
        -- (an edge's thickness: its smaller side; an edge laid out only by its anchors may report 0 for its long side before drawing)
        local w, h = e:GetWidth() or 0, e:GetHeight() or 0
        local thick = (w > 0 and h > 0) and math.min(w, h) or math.max(w, h)
        if not (thick >= 2.5) then return false, "the frame is thinner than 3 px" end
    end
    return #(b.selEdges or {}) == 4, "4 edges, shown, on top, 3 px"
end
QA.Register("statcalc-compare-highlight", { title = "Stat Calculator: the picked compare item is highlighted", qa = "E1z196", order = 191, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the Stat Calculator opens on its |cffffd100Gear|r tab. Click an equipped item that has another one of its kind in your bags (a trinket or a ring is easiest).\n\n|cffffd100Expect:|r the clicked item gets a bright frame, and under \"Compare: <slot>\" a row of the items in your bags that fit it.",
      setup = function() Remember(); Open("gear") end,
      check = function()
          local ok, why = Ready(); if not ok then return false, why end
          local d = Drawn(); if not d then return false, "the panel is not open" end
          local slot, cands = nil, 0
          for _, b in ipairs(d.icons or {}) do
              if b:IsShown() and not b.cand and b.selected then slot = b.slot end
              if b:IsShown() and b.cand then cands = cands + 1 end
          end
          return slot ~= nil and cands > 0, slot and (cands .. " item(s) in your bags listed") or "no equipped item picked yet"
      end },
    { text = "Click one of the items in that row.\n\n|cffffd100Expect:|r the item you clicked has the same clear frame as the equipped one: 3 px in the theme's accent color, all round, on top of the icon. (Until QoL 0.7.39 it showed no frame.)",
      check = function()
          local list = Picked()
          if #list == 0 then return false, "no bag item is marked as picked" end
          return FrameOK(list[1])
      end },
    { text = "Click the same item again.\n\n|cffffd100Expect:|r its frame goes (it is let go); the equipped item keeps its frame.",
      check = function() local list = Picked(); return #list == 0, #list == 0 and "no bag item marked" or (#list .. " still marked") end },
    PutBackStep(),
} })

-- C. #90: the Changes table's differences in brackets beside the numbers -----------------------------------------------------------
QA.Register("statcalc-changes-brackets", { title = "Stat Calculator: Changes shows (+/-) beside each number", qa = "E1z197", order = 192, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the Gear tab opens. Click an equipped item, then an item from your bags with different stats.\n\n|cffffd100Expect:|r the |cffffd100Changes|r table under it.",
      setup = function() Remember(); Open("gear") end,
      check = function()
          local d = Drawn(); if not d then return false, "the panel is not open" end
          local n = #Recs(d, "mdiff")
          return n > 0, n > 0 and (n .. " differences drawn") or "no difference drawn yet (pick a bag item with other stats)"
      end },
    { text = "Look at the item columns of Changes.\n\n|cffffd100Expect:|r each number starts at the left of its column and its difference follows on the |cffffd100same line|r in brackets, e.g. |cffffd1001,405 (-12)|r, |cffffd100(+12)|r in green when better, orange when worse. No difference on a line under the number.",
      check = function()
          local d = Drawn(); if not d then return false, "the panel is not open" end
          local cells, inline, under = Recs(d, "mcell"), 0, 0
          for _, df in ipairs(Recs(d, "mdiff")) do
              local same = false
              for _, c in ipairs(cells) do if c.y == df.y and df.x > c.x and df.x <= c.x + c.w + 12 then same = true end end
              if same and tostring(df.text):find("^%([%+%-]") then inline = inline + 1 else under = under + 1 end
          end
          if inline + under == 0 then return false, "no difference drawn" end
          return under == 0, under == 0 and (inline .. " differences beside their numbers") or (under .. " under their number (the panel is narrow: drag it wider)")
      end },
    PutBackStep(),
} })

-- D. #91: the header -------------------------------------------------------------------------------------------------------------
QA.Register("statcalc-header", { title = "Stat Calculator: header shows equipped and max item level", qa = "E1z198", order = 193, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the Stat Calculator opens.\n\n|cffffd100Expect:|r above the tabs, on one line: |cffffd100Equipped <your equipped item level>|r on the left and |cffffd100Max (bags) <item level>|r on the right. No name, class or spec.",
      setup = function() Remember(); Open("stats") end,
      check = function()
          local ok, why = Ready(); if not ok then return false, why end
          local l, r, h = SC().Header()
          if not l then return false, "the panel is not built" end
          h = h or {}
          local wantL = h.ilvlEquipped and ("Equipped %.1f"):format(h.ilvlEquipped) or ""
          local wantR = h.ilvlOverall and ("Max (bags) %.1f"):format(h.ilvlOverall) or ""
          local name = UnitName and UnitName("player")
          local hasName = type(name) == "string" and name ~= "" and ((l .. r):find(name, 1, true) ~= nil)
          return l == wantL and r == wantR and l ~= "" and not hasName, ("left \"%s\", right \"%s\""):format(tostring(l), tostring(r))
      end },
    { text = "Hover your item level in the game's character window (Character Info, the item level line).\n\n|cffffd100Question:|r is the number after |cffffd100Max (bags)|r the game's overall item level there (the higher one, counting the best items in your bags), and the one after |cffffd100Equipped|r the equipped one? Pass if yes, Fail with a note of both numbers if not.",
      noVerdict = true },
    PutBackStep(),
} })

-- E. B2: no % / rating toggle anywhere --------------------------------------------------------------------------------------------
QA.Register("statcalc-no-rating-toggle", { title = "Stat Calculator: no % / rating toggle", qa = "E1z199", order = 194, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the Stat Calculator opens.\n\n|cffffd100Expect:|r no \"Show: %\" / \"Show: rating\" button in its title row (only Max / Min and X). Click |cffffd100Critical Strike|r: it opens or folds its lines; nothing switches between a percent and a rating.",
      setup = function() Remember(); Open("stats") end,
      check = function()
          local ok, why = Ready(); if not ok then return false, why end
          local c = SC().Cfg()
          return not SC().HasModeButton() and c.valueMode == nil and c.lineModes == nil, SC().HasModeButton() and "the button still exists" or "no button; the old saved keys are gone"
      end },
    { text = "Open XayaUI > Bonus Features > Stat Calculator > Panel: |cffffd100Layout|r and |cffffd100Your numbers|r.\n\n|cffffd100Expect:|r no \"Rating lines\" setting in Layout and no \"Reset line flips\" button in Your numbers (Clear all stays).",
      check = function()
          local pg = SC().Page()
          local p = pg and pg.args and pg.args.panelPart and pg.args.panelPart.args
          if not p then return false, "the settings page could not be read" end
          local gone = p.layout.args.valueMode == nil and p.values.args.resetLines == nil
          return gone and p.values.args.clear ~= nil, gone and "both gone, Clear all still there" or "still there"
      end },
    PutBackStep(),
} })

-- F. B6: the credits page -------------------------------------------------------------------------------------------------------
local function InfoPane()
    local ns = NS()
    if ns and ns.LoadOptions then pcall(ns.LoadOptions) end
    return Svc("infoPane")
end
QA.Register("credits-page", { title = "Credits + Acknowledgements: h1 / h2, one box per section", qa = "E1z200", order = 195, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the version pane opens on |cffffd100Info > Credits + Acknowledgements|r (also: click the version number in the settings window's bottom-left corner).\n\n|cffffd100Expect:|r \"Credits and attribution\" as the big heading, with no paragraph under it.",
      setup = function() local ip = InfoPane(); if not ip then error("XayaUI Options could not be loaded") end; ip.Open("info", "credits") end,
      check = function()
          local ip = Svc("infoPane"); local recs = ip and ip.Recs()
          if not recs then return false, "the pane is not open" end
          local n = 0
          for _, r in ipairs(recs) do if r.kind == "h2" then n = n + 1 end end
          return n > 0, n .. " section headings drawn"
      end },
    { text = "Look at the sections.\n\n|cffffd100Expect:|r each section heading (Code, Ideas and design, Sounds, Game art) is a plain heading in normal case: no arrow, no count, no capitals, no line under it, and it does not fold. Under it one square box holds all of that section's credits, one row under the other (no columns), on a background a little less see-through than the pane's; a bit more room between one section's box and the next heading than before.",
      check = function()
          local ip = Svc("infoPane"); local recs = ip and ip.Recs()
          if not recs then return false, "the pane is not open" end
          local h2, boxes, rows, caps, alpha = {}, 0, 0, false, true
          for _, r in ipairs(recs) do
              if r.kind == "h2" then h2[#h2 + 1] = r.text; if r.text == r.text:upper() then caps = true end
              elseif r.kind == "box" then boxes = boxes + 1; if math.abs(r.alpha - math.min(1, r.paneAlpha + 0.1)) > 1e-6 then alpha = false end
              elseif r.kind == "row" then rows = rows + 1 end
          end
          local ok = #h2 > 0 and boxes == #h2 and rows >= boxes and not caps and alpha
          return ok, ("%d headings (%s), %d boxes, %d rows%s"):format(#h2, table.concat(h2, ", "), boxes, rows, alpha and "" or ", a box's background is not 10% more opaque")
      end },
    { done = true, text = "Press |cffffd100Do it for me|r to close the version pane. Then press |cffffd100Done|r.",
      setup = function() local ip = Svc("infoPane"); if ip then ip.Close() end end,
      check = function() local ip = Svc("infoPane"); return not (ip and ip.IsShown()), "closed" end },
} })
