-------------------------------------------------------------------------------
-- QAWalks-audit-qol-bonus.lua: in-game QA walkthroughs for the function audit's QoL and Bonus fixes (FA-7, D13-D17, D49-D53;
-- docs/process/FUNCTION-AUDIT-2026-11-07.md). Standing rule V22 (Xaya 2026-11-07, her words): "make sure every feature or significant
-- change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing".
-- Every walkthrough sets prefill = true: where the addon can read the result, its verdict is offered on one button (Accept), recorded
-- only on a click (QAWalk.lua). Steps the addon cannot judge are marked noVerdict and capture what they read into the check line.
-- XayaUI_QoL and XayaUI_Bonus are reached only through their services (ns.Service: "shoppingList", "charToolkitDebug", "calculatorDebug",
-- "dataPanelsDebug", "tooltipsDebug", "notepadDebug"), never by their functions. Test data is tagged "QA audit" and removed by each
-- walkthrough's last step; every setting or saved list a step changes is remembered and put back by the last step. Your own data is
-- never left changed. Does nothing without the framework. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end
local function NS() return rawget(_G, "XayaUI_NS") end
local function SV(name) local ns = NS(); return ns and ns.Service and ns.Service(name) end
local function Short(s, n) s = tostring(s or ""):gsub("|", "||"); return #s > (n or 60) and (s:sub(1, n or 60) .. "...") or s end
local function Copy(v) if type(v) ~= "table" then return v end; local t = {}; for k, x in pairs(v) do t[k] = Copy(x) end; return t end
local TAG = "QA audit"

-------------------------------------------------------------------------------
-- Shopping List (QoL): FA-7 per-character defaults, D13 Forget, D14 To buy adds up, D15 /xui shop with the Reskin tab off
-------------------------------------------------------------------------------
local sl = {}   -- remembered: { enabled, panel, gem (this character's gem default), shared (the old shared gem), ench, gems, done }
local function Shop() return SV("shoppingList") end
local function ShopCfg() local S = Shop(); if not S then error("XayaUI QoL is off") end; return S, S.Cfg() end
QA.Register("audit-shopping-list", { title = "Shopping List: per-character defaults, Forget, To buy, /xui shop (FA-7, D13-D15)", qa = "E1z221, E1z222, E1z223, E1z224", order = 330, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI remembers your Shopping List settings and this character's gem default, then sets a test gem default \"" .. TAG .. " gem\" for THIS character only.\n\n|cffffd100Expect:|r this character's gem default is the test gem; the old account-wide defaults (kept from before defaults became per character) are unchanged.",
        setup = function()
            local S, c = ShopCfg()
            if sl.enabled == nil then
                sl.enabled, sl.panel = c.enabled, c.panel
                local d = S.Defaults(c)
                sl.gem = Copy(d.gem); sl.shared = Copy(c.defaults and c.defaults.gem)
            end
            S.Defaults(c).gem = { name = TAG .. " gem" }
        end,
        check = function()
            local S = Shop(); if not S then return false, "XayaUI QoL is off" end
            local c = S.Cfg(); local mine = S.Defaults(c).gem
            local shared = c.defaults and c.defaults.gem
            local ok = mine and mine.name == TAG .. " gem" and not (shared and shared.name == TAG .. " gem")
            local others = 0; for _ in pairs(c.charDefaults or {}) do others = others + 1 end
            return ok and true or false, ("this character: %s; old shared: %s; characters with their own defaults: %d"):format(Short(mine and mine.name), Short(shared and shared.name or "none"), others)
        end },
    { text = "Log onto another character that has used the Shopping List before (or note this step and come back to it later), open Blizzard Reskin > Shopping List > Your defaults, then come back and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the other character's Gem box does NOT show \"" .. TAG .. " gem\" (it shows its own default, or the old shared one). Skip this step if you have no other character at hand.",
        noVerdict = true,
        check = function() local S = Shop(); if not S then return false, "XayaUI QoL is off" end
            local c = S.Cfg(); local d = S.Defaults(c).gem
            return true, "this character's Gem default reads: " .. Short(d and d.name or "(empty: most used)") end },
    { text = "Press |cffffd100Do it for me|r: XayaUI remembers this character's enchant / gem counts, then does what \"Forget what this character used\" does and looks at your gear again.\n\n|cffffd100Expect:|r no enchant and no gem is counted, even though you are wearing them (before the fix every worn one came back as \"used 1x\" at once). The last step puts your counts back.",
        setup = function()
            local S, c = ShopCfg()
            local h = S.History(c)
            if sl.ench == nil then sl.ench, sl.gems = Copy(h.ench), Copy(h.gems) end
            S.Forget(c); S.Observe(c)
        end,
        check = function() local S = Shop(); if not S then return false, "XayaUI QoL is off" end
            local h = S.History(S.Cfg())
            local ne, ng = 0, 0
            for _, per in pairs(h.ench or {}) do for _ in pairs(per) do ne = ne + 1 end end
            for _ in pairs(h.gems or {}) do ng = ng + 1 end
            return ne == 0 and ng == 0, ("counted after Forget: %d enchant(s), %d gem(s)"):format(ne, ng) end },
    { text = "Press |cffffd100Do it for me|r: a test gem \"" .. TAG .. " gem\" is put in To buy from two lines (1 needed, then 2 needed), and the second line's + Add is pressed once more.\n\n|cffffd100Expect:|r one To buy line \"" .. TAG .. " gem\" with need 3 (1 + 2; the same line twice is not counted twice). Before the fix it said 2.",
        setup = function()
            local S, c = ShopCfg()
            S.AddToBuy(c, TAG .. " gem", nil, 1, "gem", "qaAuditRow1")
            S.AddToBuy(c, TAG .. " gem", nil, 2, "gem", "qaAuditRow2")
            S.AddToBuy(c, TAG .. " gem", nil, 2, "gem", "qaAuditRow2")
        end,
        check = function() local S = Shop(); if not S then return false, "XayaUI QoL is off" end
            local n, need = 0, nil
            for _, b in ipairs(S.Cfg().buy) do if b.name == TAG .. " gem" then n = n + 1; need = b.need end end
            return n == 1 and need == 3, ("%d test line(s), need %s"):format(n, tostring(need)) end },
    { text = "Press |cffffd100Do it for me|r: the Shopping List is switched off, the Blizzard Reskin switch is read as off for a moment, |cffffd100/xui shop|r is run, and the Reskin switch is put straight back as it was.\n\n|cffffd100Expect:|r the Shopping List is still off (the command only says Blizzard Reskin is off). Before the fix it switched itself on.",
        setup = function()
            local S, c = ShopCfg()
            c.enabled, c.panel = false, false; S.Apply()
            local db = rawget(_G, "CueRulesDB")
            local was = db and db.reskinTabOff
            if db then db.reskinTabOff = true end
            local ok, err = pcall(S.Toggle)
            if db then db.reskinTabOff = was end
            if not ok then error(err) end
        end,
        check = function() local S = Shop(); if not S then return false, "XayaUI QoL is off" end
            local c = S.Cfg()
            return c.enabled == false and c.panel == false, ("Shopping List %s, panel %s"):format(c.enabled and "on" or "off", c.panel and "on" or "off") end },
    { text = "Last step: press |cffffd100Do it for me|r to put everything back: this character's gem default, your enchant / gem counts, the Shopping List on / off and panel, and the test line removed from To buy. Then Accept or Pass.",
        setup = function()
            local S = Shop(); if not S then return end
            local c = S.Cfg()
            if sl.enabled ~= nil then
                S.Defaults(c).gem = sl.gem
                if sl.ench then local h = S.History(c); h.ench, h.gems = sl.ench, sl.gems end
                for i = #c.buy, 1, -1 do if c.buy[i].name == TAG .. " gem" then table.remove(c.buy, i) end end
                c.enabled, c.panel = sl.enabled, sl.panel
                S.Apply()
            end
            sl = { done = true }
        end,
        check = function() local S = Shop(); if not S then return false, "XayaUI QoL is off" end
            local c = S.Cfg()
            for _, b in ipairs(c.buy) do if b.name == TAG .. " gem" then return false, "the test line is still in To buy" end end
            local d = S.Defaults(c).gem
            if d and d.name == TAG .. " gem" then return false, "the test gem default is still set" end
            return sl.done == true, sl.done and "put back as it was" or "press Do it for me" end },
} })

-- D16: the Auction House list in Select other answers only our own query; the addon cannot see the list, so this one asks
QA.Register("audit-shopping-ah", { title = "Shopping List: Auction House list kept after your own search (D16)", qa = "E1z225", order = 331, prefill = true, steps = {
    { text = "Switch the Shopping List on (Blizzard Reskin > Shopping List) and open the Auction House. On a line of Missing on your gear press |cffffd100Other|r, then |cffffd100List what the Auction House has|r and wait for the list. Then type something unrelated (for example \"Bread\") in the Auction House's own search box and search. Press |cffffd100Other|r on the same line again and |cffffd100Check again|r here.\n\n|cffffd100Expect:|r the Select other list still shows that slot's items marked \"Auction House\", not the bread. Before the fix your own search replaced it.",
        noVerdict = true,
        check = function() local S = Shop(); if not S then return false, "XayaUI QoL is off" end
            return true, "XayaUI is waiting for an answer to its own query: " .. (S.BrowsePending() and "yes (the Auction House has not answered yet)" or "no (its answer was read once)") end },
} })

-------------------------------------------------------------------------------
-- Character Toolkit (QoL), D17: with "Show the panel" off, the panel's events are not registered
-------------------------------------------------------------------------------
local ct = {}   -- remembered: { panel }
local function CT() return SV("charToolkitDebug") end
QA.Register("audit-char-toolkit-events", { title = "Character Toolkit: panel off registers no panel events (D17)", qa = "E1z226", order = 332, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI remembers whether the Character Toolkit's panel is on, then switches the panel part off (the toolkit stays on).\n\n|cffffd100Expect:|r none of the panel's events are registered: no cooldown event (each cast would read the GCD for a hidden panel), no stat events.",
        setup = function()
            local T = CT(); if not T then error("XayaUI QoL is off") end
            local c = T.Cfg(); if not (c and c.enabled) then error("the Character Toolkit is off (QoL > Character Toolkit)") end
            if ct.panel == nil then ct.panel = c.panel end
            c.panel = false; T.Apply()
        end,
        check = function() local T = CT(); if not T then return false, "XayaUI QoL is off" end
            local on = {}
            for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "UNIT_STATS", "COMBAT_RATING_UPDATE", "MASTERY_UPDATE" }) do if T.Registered(e) then on[#on + 1] = e end end
            return #on == 0, #on == 0 and "no panel event is registered" or ("still registered: " .. table.concat(on, ", ")) end },
    { text = "Last step: press |cffffd100Do it for me|r to put the panel part back as it was. Then Accept or Pass.",
        setup = function() local T = CT(); if T and ct.panel ~= nil then local c = T.Cfg(); c.panel = ct.panel; T.Apply() end; ct = { done = true } end,
        check = function() local T = CT(); if not T then return false, "XayaUI QoL is off" end
            local c = T.Cfg()
            local ok = ct.done == true and ((c.panel and T.Registered("SPELL_UPDATE_COOLDOWN")) or (not c.panel and not T.Registered("SPELL_UPDATE_COOLDOWN")))
            return ok and true or false, ("panel %s; cooldown event %s"):format(c.panel and "on" or "off", T.Registered("SPELL_UPDATE_COOLDOWN") and "registered" or "not registered") end },
} })

-------------------------------------------------------------------------------
-- Calculator (Bonus), D49 chained sums at full precision, D51 "12kx3"
-------------------------------------------------------------------------------
local calc = {}   -- remembered: { history, shown }
local function CALC() return SV("calculatorDebug") end
local function Keys(C, list) for _, k in ipairs(list) do C.Press(k) end end
QA.Register("audit-calculator", { title = "Calculator: chained sums, 12kx3 (D49, D51)", qa = "F25, F26", order = 333, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI remembers your saved sums, opens the calculator and presses C, 1, \195\183, 3, =, then \195\151, 3, =.\n\n|cffffd100Expect:|r the answer line shows 1 (before the fix: 0.999999). The first answer still showed 0.333333.",
        setup = function()
            local C = CALC(); if not C then error("XayaUI Bonus is off") end
            if not C.On() then error("the Calculator is switched off (Bonus Features > Utilities > Calculator)") end
            if calc.history == nil then calc.shown = C.Shown(); calc.history = Copy(C.History() or {}) end
            Keys(C, { "C", "1", "\195\183", "3", "=" }); calc.first = C.Result()
            Keys(C, { "\195\151", "3", "=" })
        end,
        check = function() local C = CALC(); if not C then return false, "XayaUI Bonus is off" end
            return C.Result() == "1" and calc.first == "0.333333", ("first answer %s, then %s"):format(Short(calc.first), Short(C.Result())) end },
    { text = "Press |cffffd100Do it for me|r: C, then 0.0000001 and =, then \195\151, 1, 0, =.\n\n|cffffd100Expect:|r the first answer shows 1e-07; the line under it keeps plain digits (no \"e\"); the second answer is 0.000001 (before the fix: \"e is not something a sum can hold\").",
        setup = function() local C = CALC(); if not C then error("XayaUI Bonus is off") end
            Keys(C, { "C", "0", ".", "0", "0", "0", "0", "0", "0", "1", "=" }); calc.tiny, calc.line = C.Result(), C.Line()
            Keys(C, { "\195\151", "1", "0", "=" }) end,
        check = function() local C = CALC(); if not C then return false, "XayaUI Bonus is off" end
            local ok = calc.tiny == "1e-07" and not tostring(calc.line):find("e", 1, true) and C.Result() == "0.000001"
            return ok and true or false, ("shown %s, line %s, then %s"):format(Short(calc.tiny), Short(calc.line), Short(C.Result())) end },
    { text = "Press |cffffd100Do it for me|r: XayaUI works out 12kx3 and 2mX2 (k / m followed by x).\n\n|cffffd100Expect:|r 36,000 and 4,000,000 (before the fix: \"kx3 is not something a sum can hold\"). You can also type 12kx3 in the calculator yourself.",
        setup = function() local C = CALC(); if not C then error("XayaUI Bonus is off") end
            local a, ea = C.Eval("12kx3"); local b, eb = C.Eval("2mX2")
            calc.k = a and C.Format(a) or ("error: " .. tostring(ea)); calc.m = b and C.Format(b) or ("error: " .. tostring(eb)) end,
        check = function() return calc.k == "36,000" and calc.m == "4,000,000", ("12kx3 = %s; 2mX2 = %s"):format(Short(calc.k), Short(calc.m)) end },
    { text = "Last step: press |cffffd100Do it for me|r to put your saved sums back as they were (the test sums are dropped) and the window shown or hidden as before. Then Accept or Pass.",
        setup = function()
            local C = CALC(); if not C then return end
            if calc.history then
                local h = C.History()
                if h then for i = #h, 1, -1 do h[i] = nil end; for i, v in ipairs(calc.history) do h[i] = v end end
                C.Press("C")
                if not calc.shown then C.Hide() end
            end
            calc = { done = true }
        end,
        check = function() return calc.done == true, calc.done and "your saved sums are as they were" or "press Do it for me" end },
} })

-------------------------------------------------------------------------------
-- Data Panels (Bonus), D50: Remove block before "Editing block" was used
-------------------------------------------------------------------------------
local dp = {}   -- remembered: { cfg (a copy of the Left Panel's settings) }
local function DP() return SV("dataPanelsDebug") end
QA.Register("audit-data-panels-remove", { title = "Data Panels: Remove block without using Editing block (D50)", qa = "F27", order = 334, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI remembers the Left Panel's settings, adds one block to it, then presses |cffffd100Remove block|r on a freshly opened settings page (the Editing block slider never touched).\n\n|cffffd100Expect:|r no Lua error; the Left Panel has as many blocks as before. The last step puts the Left Panel back exactly as it was.",
        setup = function()
            local D = DP(); if not D then error("XayaUI Bonus is off") end
            local cfg = D.Cfg("bl"); if not cfg then error("Data Panels have no saved settings yet: switch Data Panels on first (Bonus Features > Data Panels)") end
            if dp.cfg == nil then dp.cfg = Copy(cfg) end
            dp.before = math.max(1, tonumber(cfg.slots) or 1)
            if dp.before >= 12 then error("the Left Panel already has the most blocks") end
            cfg.slots = dp.before + 1
            dp.ok, dp.err = D.RemoveBlockFresh("bl")
        end,
        check = function() local D = DP(); if not D then return false, "XayaUI Bonus is off" end
            local cfg = D.Cfg("bl") or {}
            return dp.ok == true and tonumber(cfg.slots) == dp.before, ("Remove block: %s; blocks now %s (before %s)"):format(dp.ok and "no error" or ("error: " .. Short(dp.err, 80)), tostring(cfg.slots), tostring(dp.before)) end },
    { text = "Last step: press |cffffd100Do it for me|r to put the Left Panel back exactly as it was. Then Accept or Pass.",
        setup = function()
            local D = DP(); if not (D and dp.cfg) then dp = { done = true }; return end
            local cfg = D.Cfg("bl")
            if cfg then for k in pairs(cfg) do cfg[k] = nil end; for k, v in pairs(Copy(dp.cfg)) do cfg[k] = v end; D.Refresh("bl") end
            dp = { done = true }
        end,
        check = function() return dp.done == true, dp.done and "the Left Panel is as it was" or "press Do it for me" end },
} })

-------------------------------------------------------------------------------
-- Enhanced Tooltips (Bonus), D52: "Aura IDs" off runs no aura lookup on a hover
-------------------------------------------------------------------------------
local tt = {}   -- remembered: { aura, n0 }
local function TTS() local s = SV("tooltipsDebug"); return s and s.TT end
QA.Register("audit-tooltips-aura-off", { title = "Enhanced Tooltips: Aura IDs off costs nothing on a hover (D52)", qa = "F28", order = 335, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI remembers your Aura IDs option and switches it off. Then hover two or three spells on your action bar and an item in your bags, and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r no \"Aura ID:\" line, and XayaUI looked up no aura for those hovers (the check counts them: 0).",
        setup = function()
            local T = TTS(); if not T then error("XayaUI Bonus is off") end
            local db = T.DB(); if tt.aura == nil then tt.aura = db.ids.aura and true or false end
            db.ids.aura = false; tt.n0 = T.auraLookups or 0
        end,
        check = function() local T = TTS(); if not T then return false, "XayaUI Bonus is off" end
            local n = (T.auraLookups or 0) - (tt.n0 or 0)
            return n == 0, ("aura lookups since this step: %d"):format(n) end },
    { text = "Press |cffffd100Do it for me|r: Aura IDs is switched on. Hover a spell again and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the \"Aura ID:\" lines are back where the spell has an aura, and the check counts the lookups (1 or more).",
        setup = function() local T = TTS(); if not T then error("XayaUI Bonus is off") end; T.DB().ids.aura = true; tt.n1 = T.auraLookups or 0 end,
        check = function() local T = TTS(); if not T then return false, "XayaUI Bonus is off" end
            local n = (T.auraLookups or 0) - (tt.n1 or 0)
            return n > 0, ("aura lookups since this step: %d"):format(n) end },
    { text = "Last step: press |cffffd100Do it for me|r to put your Aura IDs option back as it was. Then Accept or Pass.",
        setup = function() local T = TTS(); if T and tt.aura ~= nil then T.DB().ids.aura = tt.aura end; tt = { done = true } end,
        check = function() return tt.done == true, tt.done and "Aura IDs is as it was" or "press Do it for me" end },
} })

-------------------------------------------------------------------------------
-- Notepad Share (Bonus), D53: Send sends the note the window named when it opened
-------------------------------------------------------------------------------
local ns53 = {}   -- remembered: { shown, current, a, b (the test notes' ids) }
local function NPS() return SV("notepadDebug") end
local function NDB() local s = NPS(); return s and s.DB() end
local function GoTo(id) local s, db = NPS(), NDB(); if not (s and db and id) then return end; for _ = 1, #(db.notes or {}) do if db.current == id then return end; s.Next() end end
QA.Register("audit-notepad-share", { title = "Notepad Share: sends the note it opened on (D53)", qa = "F29", order = 336, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI remembers your Notepad, adds two test notes (\"" .. TAG .. " share A\" and \"" .. TAG .. " share B\"), opens the Share window on note A and then switches the Notepad to note B. Nothing is sent.\n\n|cffffd100Expect:|r the Share window still names note A, and the text it would send is note A's.",
        setup = function()
            local s, db = NPS(), NDB()
            if not (s and db and s.On()) then error("the Notepad is switched off (Bonus Features > Utilities > Notepad)") end
            if ns53.current == nil then ns53.shown, ns53.current = db.shown and true or false, db.current end
            s.SetShown(true)
            s.New(TAG .. " share A"); ns53.a = db.current
            s.New(TAG .. " share B"); ns53.b = db.current
            GoTo(ns53.a); s.OpenShare(); GoTo(ns53.b)
        end,
        check = function() local s = NPS(); if not s then return false, "XayaUI Bonus is off" end
            local t = s.ShareNoteText()
            return t == TAG .. " share A" and s.CurrentText() == TAG .. " share B", ("open note: %s; the Share window would send: %s"):format(Short(s.CurrentText()), Short(t or "(no window)")) end },
    { text = "Optional, with someone in your party or by whispering yourself: in the Share window press |cffffd100Send|r (pick the channel first). Then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the chat header and the offer the other player gets are for \"" .. TAG .. " share A\", not B. Skip if nobody is at hand.",
        noVerdict = true,
        check = function() local s = NPS(); if not s then return false, "XayaUI Bonus is off" end
            return true, "the Share window would send: " .. Short(s.ShareNoteText() or "(window closed: sent or canceled)") end },
    { text = "Last step: press |cffffd100Do it for me|r to close the Share window, delete both test notes (they go to Deleted notes) and put the Notepad back as it was (shown or hidden, the note you had open). Then Accept or Pass.",
        setup = function()
            local s, db = NPS(), NDB(); if not (s and db) then ns53 = { done = true }; return end
            local w = rawget(_G, "XayaUINoteShare"); if w then w:Hide() end
            for _, id in ipairs({ ns53.a, ns53.b }) do if id then GoTo(id); if db.current == id then s.Delete() end end end
            GoTo(ns53.current)
            if ns53.shown ~= nil then s.SetShown(ns53.shown) end
            ns53 = { done = true }
        end,
        check = function() local db = NDB(); if not db then return false, "the Notepad is off" end
            for _, n in ipairs(db.notes or {}) do if tostring(n.text or ""):find(TAG .. " share", 1, true) then return false, "a test note is still there" end end
            return ns53.done == true, ns53.done and "the test notes are gone and the Notepad is as it was" or "press Do it for me" end },
} })
