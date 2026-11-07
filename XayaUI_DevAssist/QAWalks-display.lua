-------------------------------------------------------------------------------
-- QAWalks-display.lua (XayaUI_DevAssist 0.7.11): in-game QA walkthroughs for the UI bugs session's work (branch
-- claude/ui-bugs-focused): the display standard (UI-47 / UI-48: tab rows, off pages, switch hovers), the theme tie-in (UI-49 / UI-50),
-- the Calculator page's info icon (UI-53), Release Guard (UI-57 / UI-58), the stat labels and the standard GCD (UI-62 to UI-64).
-- Standing rule V21 (Xaya 2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have an in game
-- qa test walk through with pre-fill confirmation options or data capturing". Every walkthrough here sets prefill = true: the addon's own
-- verdict is offered on "Accept", and nothing is recorded without her click. Steps the addon cannot judge say what to look at and are
-- marked noVerdict.
-- Other addons are reached only through core (ns.OpenSettingsPage, ns.Theme, ns.Style, ns.infoBoxOpen), the settings window's
-- published ns.OptionsApi, the Ace libraries, and the services XayaUI QoL provides (releaseGuard, statModel). Settings a walkthrough
-- changes are remembered in its first step and put back in its last. Does nothing without the framework. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames["CueRules"] end
local function Svc(name) local ns = NS(); return ns and ns.Service and ns.Service(name) end
local function Scale() local ns = NS(); local T = ns and ns.Theme; return (T and T.Scale and T.Scale()) or 1 end
local function Near(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 1) end
local function Num(f, m) if not (f and f[m]) then return nil end local ok, v = pcall(f[m], f); if ok and type(v) == "number" then return v end end

-- the settings window: open it on a page (Rules uses its own tab key)
local function Open(...)
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then return end
    local a = ACD(); if not a then return end
    if not (Root() and Root().frame and Root().frame:IsShown()) then a:Open("CueRules") end
    a:SelectGroup("CueRules", ...)
end
local function Find(pred)
    local function walk(w, d)
        if not w or d > 25 then return nil end
        if pred(w) then return w end
        for _, c in ipairs(w.children or {}) do local f = walk(c, d + 1); if f then return f end end
    end
    return walk(Root(), 0)
end
local function ShownTabs(tg)
    local out = {}
    for _, t in ipairs(tg and tg.tabs or {}) do if t:IsShown() then out[#out + 1] = t end end
    return out
end
local function TabText(t) local fs = t.GetFontString and t:GetFontString(); return (fs and fs:GetText()) or (t.GetText and t:GetText()) or "" end
local function Ready() if not Root() then return false, "the settings window is not open: press Do it for me" end return true end

-- remembered settings, put back at the end
local saved
local function Remember(keys) saved = {} local ns = NS(); for k, get in pairs(keys) do saved[k] = get(ns) end end

-------------------------------------------------------------------------------
-- 1. Tab rows (UI-43 to UI-45, UI-48, UI-50)
-------------------------------------------------------------------------------
local function RulesRow() return Find(function(w) if w.type ~= "TabGroup" then return false end
    for _, t in ipairs(w.tabs or {}) do if t:IsShown() and t.value == "creatorTab" then return true end end end) end
local function CheckRules(wantH)
    local ok, why = Ready(); if not ok then return false, why end
    local tg = RulesRow(); if not tg then return false, "the Rules sub-tab row is not on screen" end
    local tabs, cr, others = ShownTabs(tg), nil, {}
    for _, t in ipairs(tabs) do if t.value == "creatorTab" then cr = t else others[#others + 1] = t end end
    if not cr or #others ~= 4 then return false, ("%d tabs, Auto-Generate Rules %s"):format(#others, cr and "found" or "missing") end
    local w1 = Num(others[1], "GetWidth")
    for _, t in ipairs(others) do
        if not Near(Num(t, "GetWidth"), w1, 1) then return false, ("not the same width: %s %.0f vs %.0f"):format(TabText(t), Num(t, "GetWidth") or -1, w1 or -1) end
        if not Near(Num(t, "GetHeight"), wantH, 1) then return false, ("%s is %.0f px tall, want %d"):format(TabText(t), Num(t, "GetHeight") or -1, wantH) end
    end
    if TabText(cr) ~= "Auto-Generate Rules" then return false, "the far-right tab reads \"" .. TabText(cr) .. "\"" end
    -- its right edge on the row's right edge, measured as the skin lays the row out (from the row's left, the row's width)
    local fl, cl, rowW = Num(tg.frame, "GetLeft"), Num(cr, "GetLeft"), tg.frame.width or Num(tg.frame, "GetWidth")
    if not (fl and cl and rowW and Near(cl - fl + (Num(cr, "GetWidth") or 0), rowW, 2)) then return false, "Auto-Generate Rules is not at the far right" end
    return true, ("4 even tabs %.0f px wide, %d px tall; Auto-Generate Rules at the far right"):format(w1 or 0, wantH)
end
local function DPTabs() return Find(function(w) if w.type ~= "TabGroup" then return false end
    local u = w.GetUserDataTable and w:GetUserDataTable(); local p = u and u.path; return p and p[1] == "bonus" and p[#p] == "datapanels" end) end
local function DPOn() local db = rawget(_G, "CueRulesDB"); local d = db and db.dataPanels; return d and d.general and d.general.enabled end
local function SetDP(v)
    local db = rawget(_G, "CueRulesDB"); local d = db and db.dataPanels; if not (d and d.general) then return end
    d.general.enabled = v and true or false
    local ns = NS(); if ns and ns.Fire then ns.Fire("CONFIG_CHANGED") end
end

QA.Register("ui-tab-rows", { title = "Settings: tab rows, switched-off pages, text size", qa = "B213, B215, B220", order = 260, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on |cffffd100Rules|r (your Data Panels and Theme text size are remembered; the last step puts them back).\n\n|cffffd100Expect:|r under the top tabs, Smart Categories, Enabled, Disabled and Drafts are the same width side by side, taller than before with outlined names, and |cffffd100Auto-Generate Rules|r sits apart at the far right.",
        setup = function()
            Remember({ dp = function() return DPOn() end, size = function() local db = rawget(_G, "CueRulesDB"); return db and db.theme and db.theme.size end })
            Open("cooldowns", "smartTab")
        end,
        check = function() return CheckRules(math.floor(28 * Scale() + 0.5)) end },
    { text = "Click each Rules sub-tab in turn (Enabled, Disabled, Drafts), then press |cffffd100Check|r.\n\n|cffffd100Expect:|r nothing moves or changes width; no name is cut off (the last one is for your eyes).",
        check = function() return CheckRules(math.floor(28 * Scale() + 0.5)) end },
    { text = "Press |cffffd100Do it for me|r: Data Panels is switched off and its page opens (Bonus Features > Data Panels).\n\n|cffffd100Expect:|r one line, \"Shows info panels on your screen: time, gold, frame rate and more.\", and no tab row or empty box under it.",
        setup = function() SetDP(false); Open("bonus", "datapanels") end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local tg = DPTabs()
            local n = #ShownTabs(tg)
            return tg ~= nil and n == 0, tg and (n == 0 and "no section tab drawn while it is off" or (n .. " tabs drawn while it is off")) or "the Data Panels page is not on screen"
        end },
    { text = "Press |cffffd100Do it for me|r: Data Panels is switched on again.\n\n|cffffd100Expect:|r its section tabs fill the row evenly, a little smaller than the Rules sub-tabs (24 px, 11 pt, outlined).",
        setup = function() SetDP(true); Open("bonus", "datapanels") end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local tabs = ShownTabs(DPTabs())
            if #tabs == 0 then return false, "no section tab drawn" end
            local want = math.floor(24 * Scale() + 0.5)
            for _, t in ipairs(tabs) do
                if not Near(Num(t, "GetHeight"), want, 1) then return false, ("%s is %.0f px tall, want %d"):format(TabText(t), Num(t, "GetHeight") or -1, want) end
                if not Near(Num(t, "GetWidth"), Num(tabs[1], "GetWidth"), 1) then return false, "the section tabs are not the same width" end
            end
            return true, ("%d section tab(s), %d px tall, even"):format(#tabs, want)
        end },
    { text = "Press |cffffd100Do it for me|r: the Theme's |cffffd100Text size|r is set to Large and the Rules tab opens.\n\n|cffffd100Expect:|r the Rules sub-tabs are taller and their names larger than at Medium (about 32 px instead of 28).",
        setup = function()
            local db = rawget(_G, "CueRulesDB"); if not db then return end
            db.theme = db.theme or {}; db.theme.size = "L"
            local ns = NS(); if ns and ns.Theme and ns.Theme.Changed then ns.Theme.Changed() end
            Open("cooldowns", "smartTab")
        end,
        check = function() return CheckRules(math.floor(28 * Scale() + 0.5)) end },
    { text = "Last step: press |cffffd100Do it for me|r to put Data Panels and the Theme text size back as they were.",
        setup = function()
            if not saved then return end
            SetDP(saved.dp)
            local db = rawget(_G, "CueRulesDB"); if db and db.theme then db.theme.size = saved.size end
            local ns = NS(); if ns and ns.Theme and ns.Theme.Changed then ns.Theme.Changed() end
            saved.done = true
        end,
        check = function() return saved ~= nil and saved.done == true, (saved and saved.done) and "put back" or "press Do it for me" end },
} })

-------------------------------------------------------------------------------
-- 2. Switch hovers (UI-42, UI-65) and the theme's colours (UI-49)
-------------------------------------------------------------------------------
local function BonusRow(uv)
    local tree = Find(function(w) local u = w.type == "TreeGroup" and w:GetUserDataTable(); return u and u.path and u.path[1] == "bonus" and #u.path == 1 end)
    for _, b in ipairs(tree and tree.buttons or {}) do if b:IsShown() and b.uniquevalue == uv then return b end end
end

QA.Register("ui-switch-hovers", { title = "Settings: tick-box hovers and theme colours", qa = "B214, B219", order = 261, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on Bonus Features > Data Panels. Then hover the tick box on the Data Panels row (left pane) and press |cffffd100Check|r: the addon hovers it once more itself and reads what the hover writes.\n\n|cffffd100Expect:|r three lines: the row's name, one short sentence, and Enabled or Disabled. No \"Off: ...\" text.",
        setup = function() Open("bonus", "datapanels") end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local b = BonusRow("datapanels"); local box = b and b.xuiSwitchBox
            local fn = box and box:GetScript("OnEnter")
            if not fn then return false, "the Data Panels row's tick box is not on screen" end
            local l, oS, oA = {}, GameTooltip.SetText, GameTooltip.AddLine
            GameTooltip.SetText = function(self, t, ...) l = { t }; return oS(self, t, ...) end
            GameTooltip.AddLine = function(self, t, ...) l[#l + 1] = t; return oA(self, t, ...) end
            local okH = pcall(fn, box)
            GameTooltip.SetText, GameTooltip.AddLine = oS, oA
            GameTooltip:Hide()
            if not okH or #l == 0 then return false, "no hover shown" end
            local sentences = 0; for _ in tostring(l[2] or ""):gmatch("[%.!?]") do sentences = sentences + 1 end
            local good = #l == 3 and l[1] == "Data Panels" and sentences == 1 and (l[3] == "Enabled" or l[3] == "Disabled")
                and not table.concat(l, " "):find("Off", 1, true)
            return good, table.concat(l, " | ")
        end },
    { text = "Hover the tick boxes of a few other rows yourself (Release Guard, Esc Menu, Chat Panel).\n\n|cffffd100Expect:|r each says in plain words what it does, in one sentence. Pass if every one reads clearly to you; Fail and say which one if not.",
        noVerdict = true },
    { text = "Look at a switched-off feature's name in the left pane (Release Guard is off by default), then open Settings > Theme and change |cffffd100Muted text|r.\n\n|cffffd100Expect:|r the grey name follows that colour. The addon checks that the grey it uses is the theme's Muted text colour.",
        check = function()
            local ns = NS(); local api = ns and ns.OptionsApi
            if not (api and api.Muted and ns.Theme and ns.Theme.Col) then return false, "the settings window has not been opened yet" end
            local a, b = api.Muted(), ns.Theme.Col("xui-text-muted", "text")
            local same = Near(a[1], b[1], 0.001) and Near(a[2], b[2], 0.001) and Near(a[3], b[3], 0.001)
            return same, same and "the grey is the theme's Muted text colour" or "the grey is not the theme's Muted text colour"
        end },
} })

-------------------------------------------------------------------------------
-- 3. Theme: Advanced customization (UI-50)
-------------------------------------------------------------------------------
local function AdvOpt()
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    local t = reg and reg:GetOptionsTable("CueRules", "dialog", "AceConfigDialog-3.0")   -- (with a ui type: the table itself)
    if type(t) == "function" then t = t("dialog", "AceConfigDialog-3.0") end
    local found
    local function walk(g, d) if type(g) ~= "table" or d > 15 or found then return end
        for _, o in pairs(type(g.args) == "table" and g.args or {}) do
            if type(o) == "table" then if o.type == "toggle" and o.name == "Advanced customization" then found = o; return end; walk(o, d + 1) end
        end end
    walk(t, 0)
    return found
end
local function Adv() local ns = NS(); return ns and ns.Theme and ns.Theme.Advanced and ns.Theme.Advanced() end
QA.Register("ui-theme-advanced", { title = "Theme: Advanced customization", qa = "B221", order = 262, prefill = true, steps = {
    { text = "Open Settings > Theme (the toolbar's Settings button, then UI Options > Theme).\n\n|cffffd100Expect:|r a tick box |cffffd100Advanced customization|r, unticked (unless you ticked it before), and no Tab / Selected tab / Tree bars colours or Class overrides.",
        setup = function() local ns = NS(); if ns and ns.LoadOptions then ns.LoadOptions() end; saved = { adv = Adv() } end,
        check = function()
            local o = AdvOpt()
            if not o then return false, "no Advanced customization switch found (open the settings window once)" end
            local ns = NS()
            local parked = ns.Theme.Parked and ns.Theme.Parked("tabBg")
            return (not Adv()) and parked == true, ("Advanced customization is %s; tab colours %s"):format(Adv() and "on" or "off", parked and "not offered" or "offered")
        end },
    { text = "Press |cffffd100Do it for me|r (or tick it yourself).\n\n|cffffd100Expect:|r the Tab, Selected tab and Tree bars colours and a Class overrides box appear. Change |cffffd100Tab|r: the tabs take that colour.",
        setup = function() local o = AdvOpt(); if o and o.set then o.set({}, true) end end,
        check = function()
            local ns = NS()
            local open = Adv() and ns.Theme.Parked and ns.Theme.Parked("tabBg") == false
            return open == true, open and "on: the tab colours are offered and applied" or "still off"
        end },
    { text = "Last step: press |cffffd100Do it for me|r to put Advanced customization back as it was.",
        setup = function() local o = AdvOpt(); if o and o.set and saved then o.set({}, saved.adv and true or false) end end,
        check = function() return saved ~= nil and (Adv() and true or false) == (saved.adv and true or false), "back as it was" end },
} })

-------------------------------------------------------------------------------
-- 4. The Calculator page's info icon (UI-53, a trial on one page)
-------------------------------------------------------------------------------
local function Labels()
    local out = {}
    local function walk(w, d) if not w or d > 25 then return end
        if w.type == "Label" and w.label and w.frame and w.frame:IsShown() then out[#out + 1] = w.label:GetText() or "" end
        for _, c in ipairs(w.children or {}) do walk(c, d + 1) end end
    walk(Root(), 0)
    return table.concat(out, " | ")
end
local function InfoIcon() return Find(function(w) local o = w.type == "Icon" and w.GetUserData and w:GetUserData("option"); return o and type(o.arg) == "table" and o.arg.xuiInfoToggle end) end
QA.Register("ui-calc-infobox", { title = "Calculator page: summary and info icon (trial)", qa = "B222", order = 263, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: Bonus Features > Utilities > Calculator opens.\n\n|cffffd100Expect:|r two short sentences at the top with an (i) icon to their right (no word under it); the three long paragraphs are gone.",
        setup = function() local ns = NS(); if ns and ns.infoBoxOpen then ns.infoBoxOpen["bonus.calculator"] = nil end; Open("bonus", "utilities", "calculator") end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local t, ic = Labels(), InfoIcon()
            local good = t:find("A small calculator", 1, true) ~= nil and not t:find("It reads numbers", 1, true) and ic ~= nil and not (ic.label and ic.label:IsShown())
            return good, good and "summary shown, paragraphs closed, the icon has no name under it" or ("on screen: " .. t:sub(1, 160))
        end },
    { text = "Click the (i) icon (or press |cffffd100Do it for me|r).\n\n|cffffd100Expect:|r a box titled |cffffd100Description|r opens under the summary with the three paragraphs. Click again: it closes.",
        setup = function() local ns = NS(); if ns and ns.infoBoxOpen then ns.infoBoxOpen["bonus.calculator"] = true; if ns.Fire then ns.Fire("CONFIG_CHANGED") end end end,
        check = function()
            local t = Labels()
            local good = t:find("It reads numbers", 1, true) ~= nil
            return good, good and "the Description box shows the paragraphs" or "the paragraphs are not shown"
        end },
    { text = "Your call: should every text-heavy page work like this (a short summary, the rest behind the info icon)? Pass = yes, roll it out; Fail = no, or change something (say what in the note).",
        noVerdict = true },
} })

-------------------------------------------------------------------------------
-- 5. Release Guard (UI-57 / UI-58)
-------------------------------------------------------------------------------
local function RG() return Svc("releaseGuard") end
QA.Register("ui-release-guard", { title = "Release Guard: where it works, the box on the death window", qa = "E1z93, E1z82", order = 264, prefill = true, steps = {
    { text = "Open QoL > Release Guard and tick its box on the left if it is not ticked.\n\n|cffffd100Expect:|r |cffffd100Where|r offers Raids only and Raids and dungeons, and no Everywhere.",
        check = function()
            local s = RG(); if not s then return false, "XayaUI QoL is not loaded" end
            local loads, c = s.Loads(), s.Cfg()
            local n = 0; for _ in pairs(loads or {}) do n = n + 1 end
            local good = n == 2 and loads.raid and loads.group and not loads.all and c and c.load ~= "all"
            return good and true or false, ("%d choices; Where is %s; the guard is %s"):format(n, tostring(loads and loads[c and c.load or ""]), (c and c.enabled) and "on" or "off")
        end },
    { text = "In a raid (or a dungeon with Raids and dungeons), die, and while the death window shows, press |cffffd100Check|r.\n\n|cffffd100Expect:|r a black NO RELEASE box over Release Spirit; a click on it does nothing; holding Shift lets the click through. The addon reads where the box and the death window sit.",
        check = function()
            local s = RG(); if not s then return false, "XayaUI QoL is not loaded" end
            local st, box, d = s.State(), s.Box(), s.Death()
            if not d then return false, "no death window shown right now (last outcome: " .. tostring(st and st.why) .. ")" end
            local strata = box and box.GetFrameStrata and box:GetFrameStrata()
            local good = st and st.why == "covered" and box and box:IsVisible() and strata == "FULLSCREEN_DIALOG"
            return good and true or false, ("outcome %s; box %s, strata %s"):format(tostring(st and st.why), box and (box:IsVisible() and "visible" or "hidden") or "never made", tostring(strata))
        end },
    { text = "Die outside any instance (the open world).\n\n|cffffd100Expect:|r no box (Release Guard only works in raids, or raids and dungeons). Press |cffffd100Check|r while dead.",
        check = function()
            local s = RG(); if not s then return false, "XayaUI QoL is not loaded" end
            local st, box, d = s.State(), s.Box(), s.Death()
            if not d then return false, "no death window shown right now" end
            local good = not (box and box:IsVisible())
            return good, ("box %s; outcome %s"):format((box and box:IsVisible()) and "shown" or "not shown", tostring(st and st.why))
        end },
} })

-------------------------------------------------------------------------------
-- 6. Stat labels and the standard GCD (UI-62 to UI-64)
-------------------------------------------------------------------------------
local function SM() return Svc("statModel") end
local function Line(m, key)   -- (the model is a flat list of sections and items)
    for _, it in ipairs(m or {}) do if type(it) == "table" and it.key == key then return it end end
end
local function PairOf(it, label) for _, p in ipairs(it and it.pairs or {}) do if p.label == label then return p end end end
QA.Register("ui-stat-gcd", { title = "Stat list labels and the GCD", qa = "E1z94, E1z95", order = 265, prefill = true, steps = {
    { text = "Open the character window with the stat list, or the Stat Calculator's Stats tab.\n\n|cffffd100Expect:|r General reads Health, your resource, |cffffd100GCD|r, |cffffd100Movement Speed|r; Offensive ends with |cffffd100Critical Strike Effectiveness|r.",
        check = function()
            local s = SM(); if not s then return false, "XayaUI QoL is not loaded" end
            local m = s.Model("stats")
            local g, mv, ce = Line(m, "map_gcd"), Line(m, "map_movespeed"), Line(m, "map_critfx")
            local good = g and g.label == "GCD" and mv and mv.label == "Movement Speed" and ce and ce.label == "Critical Strike Effectiveness"
            return good and true or false, ("%s / %s / %s"):format(tostring(g and g.label), tostring(mv and mv.label), tostring(ce and ce.label))
        end },
    { text = "Cast any spell, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the GCD line shows the standard figure (1.5 s / (1 + your haste), never below 0.75 s; a fixed 1.00 s on a Rogue, a Druid in Cat Form, a Brewmaster or Windwalker), its rule, and the game's own live reading under it. The addon compares the two.",
        check = function()
            local s = SM(); if not s then return false, "XayaUI QoL is not loaded" end
            local base, hasted, why = s.GcdRule()
            local live, hidden = s.Live()
            local h = GetHaste and GetHaste()
            local calc = s.GcdFor(type(h) == "number" and h or nil)
            if hidden then return false, "the game hides the GCD right now (in combat); try out of combat" end
            if not (live and type(live.dur) == "number") then return false, "no GCD read yet: cast any spell" end
            if not calc then return false, "the rule could not be worked out (" .. tostring(why) .. ")" end
            local match = math.abs(calc - live.dur) <= 0.02
            return match, ("rule %s: %.2f s; the game: %.2f s%s"):format(tostring(why), calc, live.dur, match and "" or " (differs: a buff or talent may change it; say which in the note)")
        end },
} })
