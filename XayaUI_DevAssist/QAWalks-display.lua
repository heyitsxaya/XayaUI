-------------------------------------------------------------------------------
-- QAWalks-display.lua (XayaUI_DevAssist 0.7.11): in-game QA walkthroughs for the UI bugs session's work (branch
-- claude/ui-bugs-focused): the display standard (UI-47 / UI-48: tab rows, off pages, switch hovers), the theme tie-in (UI-49 / UI-50),
-- the Calculator page's info icon (UI-53), Release Guard (UI-57 / UI-58), the stat labels and the standard GCD (UI-62 to UI-64).
-- Also (Dev Assist 0.7.19): core windows' flat buttons after a /reload (UI-77); (0.7.20) the debug report's Select string (UI-78); (0.7.21) when the Shopping List shows itself (UI-77 part 2); (0.7.22) brief hover texts (UI-65).
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
-- (Dev Assist 0.7.55, P2 settings seam) XayaUI's settings through its views (core Modules.lua section 0b); an empty table without XayaUI
local function Settings(m) local cns = NS(); return cns and cns.Settings and cns.Settings(m) or {} end
local function SettingsOn() local cns = NS(); return cns and cns.SettingsReady and cns.SettingsReady() or false end
local PlatS, BonusS = Settings("platform"), Settings("bonus")
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
local function DPOn() local d = BonusS.dataPanels; return d and d.general and d.general.enabled end
local function SetDP(v)
    local d = BonusS.dataPanels; if not (d and d.general) then return end
    d.general.enabled = v and true or false
    local ns = NS(); if ns and ns.Fire then ns.Fire("CONFIG_CHANGED") end
end

QA.Register("ui-tab-rows", { title = "Settings: tab rows, switched-off pages, text size", qa = "B213, B215, B220", order = 260, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on |cffffd100Rules|r (your Data Panels and Theme text size are remembered; the last step puts them back).\n\n|cffffd100Expect:|r under the top tabs, Smart Categories, Enabled, Disabled and Drafts are the same width side by side with small even gaps (27 px tall, outlined names), and |cffffd100Auto-Generate Rules|r sits apart at the far right.",
        setup = function()
            Remember({ dp = function() return DPOn() end, size = function() local th = PlatS.theme; return th and th.size end })
            Open("cooldowns", "smartTab")
        end,
        check = function() return CheckRules(math.floor(((NS() and NS().Style and NS().Style.tabSub.h) or 27) * Scale() + 0.5)) end },
    { text = "Click each Rules sub-tab in turn (Enabled, Disabled, Drafts), then press |cffffd100Check|r.\n\n|cffffd100Expect:|r nothing moves or changes width; no name is cut off (the last one is for your eyes).",
        check = function() return CheckRules(math.floor(((NS() and NS().Style and NS().Style.tabSub.h) or 27) * Scale() + 0.5)) end },
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
    { text = "Press |cffffd100Do it for me|r: the Theme's |cffffd100Text size|r is set to Large and the Rules tab opens.\n\n|cffffd100Expect:|r the Rules sub-tabs are taller and their names larger than at Medium (about 31 px instead of 27).",
        setup = function()
            if not SettingsOn() then return end
            local th = PlatS.theme or {}; PlatS.theme = th; th.size = "L"
            local ns = NS(); if ns and ns.Theme and ns.Theme.Changed then ns.Theme.Changed() end
            Open("cooldowns", "smartTab")
        end,
        check = function() return CheckRules(math.floor(((NS() and NS().Style and NS().Style.tabSub.h) or 27) * Scale() + 0.5)) end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put Data Panels and the Theme text size back as they were. Then press |cffffd100Done|r.",
        setup = function()
            if not saved then return end
            SetDP(saved.dp)
            local th = PlatS.theme; if th then th.size = saved.size end
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

QA.Register("ui-switch-hovers", { title = "Settings: tick-box hovers and theme colors", qa = "B214, B219", order = 261, prefill = true, steps = {
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
    { text = "Look at a switched-off feature's name in the left pane (Release Guard is off by default), then open Settings > UI Options > Theme and change |cffffd100Muted text|r.\n\n|cffffd100Expect:|r the grey name follows that color. The addon checks that the grey it uses is the theme's Muted text color.",
        check = function()
            local ns = NS(); local api = ns and ns.OptionsApi
            if not (api and api.Muted and ns.Theme and ns.Theme.Col) then return false, "the settings window has not been opened yet" end
            local a, b = api.Muted(), ns.Theme.Col("xui-text-muted", "text")
            local same = Near(a[1], b[1], 0.001) and Near(a[2], b[2], 0.001) and Near(a[3], b[3], 0.001)
            return same, same and "the grey is the theme's Muted text color" or "the grey is not the theme's Muted text color"
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
    { text = "Open Settings > UI Options > Theme (the Settings tab at the top, then UI Options > Theme).\n\n|cffffd100Expect:|r a tick box |cffffd100Advanced customization|r, unticked (unless you ticked it before), and no Tab / Selected tab / Tree bars colors or Class overrides.",
        setup = function() local ns = NS(); if ns and ns.LoadOptions then ns.LoadOptions() end; saved = { adv = Adv() } end,
        check = function()
            local o = AdvOpt()
            if not o then return false, "no Advanced customization switch found (open the settings window once)" end
            local ns = NS()
            local parked = ns.Theme.Parked and ns.Theme.Parked("tabBg")
            return (not Adv()) and parked == true, ("Advanced customization is %s; tab colors %s"):format(Adv() and "on" or "off", parked and "not offered" or "offered")
        end },
    { text = "Press |cffffd100Do it for me|r (or tick it yourself).\n\n|cffffd100Expect:|r the Tab, Selected tab and Tree bars colors and a Class overrides box appear. Change |cffffd100Tab|r: the tabs take that color.",
        setup = function() local o = AdvOpt(); if o and o.set then o.set({}, true) end end,
        check = function()
            local ns = NS()
            local open = Adv() and ns.Theme.Parked and ns.Theme.Parked("tabBg") == false
            return open == true, open and "on: the tab colors are offered and applied" or "still off"
        end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put Advanced customization back as it was. Then press |cffffd100Done|r.",
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

-------------------------------------------------------------------------------
-- 7. Nesting in the left pane (UI-8 "Parent's name + 8 px"; UI-69, Xaya: "indents are now TOO large")
-------------------------------------------------------------------------------
local function ReskinRow(uv)
    local tree = Find(function(w) local u = w.type == "TreeGroup" and w:GetUserDataTable(); return u and u.path and u.path[1] == "reskin" and #u.path == 1 end)
    for _, b in ipairs(tree and tree.buttons or {}) do if b:IsShown() and b.uniquevalue == uv then return b end end
end
QA.Register("ui-nesting", { title = "Settings: parts nested 8 px under their feature", qa = "B218", order = 266, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the Blizzard Reskin tab opens on Chat Panel, with its parts listed.\n\n|cffffd100Expect:|r Layout, Appearance, Chat Data Panel ... start just a little right of where \"Chat Panel\" starts (8 px), with no wide gap; Stat list sits the same way under Character Pane.",
        setup = function() Open("reskin", "chatpanel") end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local p, c = ReskinRow("chatpanel"), ReskinRow("chatpanel\001layout")
            if not (p and c and p.xuiTextL and c.xuiTextL) then return false, "Chat Panel and its Layout row are not on screen (is the Blizzard Reskin tab on?)" end
            local d = c.xuiTextL - p.xuiTextL
            return math.abs(d - 8) < 0.5, ("Layout's name starts %d px right of Chat Panel's (want 8)"):format(d)
        end },
} })

-------------------------------------------------------------------------------
-- 8. The rule list's icons (Options 0.6.64; UI-70: "icons still not appropriately handled and display irregularly"; UI-72: "copy the WA
-- format w/ toggle being under group as previously suggested")
-------------------------------------------------------------------------------
local function RuleRows()
    local out = {}
    local function walk(f, d) if not f or d > 60 then return end
        if f.uniquevalue and f.IsShown and f:IsShown() and not f.xuiTwoRow then out[#out + 1] = f end
        for _, c in ipairs(f.GetChildren and { f:GetChildren() } or {}) do walk(c, d + 1) end end
    walk(UIParent, 0)
    return out
end
local function Off(b) if not (b and b:IsShown()) then return nil end local p, _, rp, x = b:GetPoint(1); if p == "RIGHT" and rp == "RIGHT" then return -(x or 0) end end
QA.Register("ui-row-icons", { title = "Rules list: icons in fixed columns (WeakAuras layout)", qa = "B228", order = 267, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: Rules > Enabled opens.\n\n|cffffd100Expect:|r on every row the icons stand in the same columns, from the right: the open / close button (headers only), the eye (or the headphone on a sound-only row), the note, the lock. LOADED's open / close button is at the far right with the eye just left of it; nothing overlaps; a group's open / close sits under its icon.",
        setup = function() Open("cooldowns", "enabledTab") end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local ns = NS(); local C = ns and ns.OptionsApi and ns.OptionsApi.SIDE_COL
            if not C then return false, "the settings window is not loaded" end
            local bad, n = {}, 0
            for _, b in ipairs(RuleRows()) do
                n = n + 1
                local name = tostring(b.uniquevalue):match("([^\001]+)$")
                for fr, col in pairs({ [b.xuiEye or 0] = C.preview, [b.xuiHead or 1] = C.preview, [b.xuiEdit or 2] = C.note, [b.xuiMove or 3] = C.lock }) do
                    if type(fr) == "table" then local o = Off(fr); if o and o ~= col then bad[#bad + 1] = name end end
                end
                if b.xuiChev and b.xuiChev:IsShown() and Off(b.xuiChev) and Off(b.xuiChev) ~= C.expand then bad[#bad + 1] = name .. " (open / close)" end
            end
            if n == 0 then return false, "no rows on screen" end
            return #bad == 0, #bad == 0 and (n .. " rows, every icon in its column") or ("out of column: " .. table.concat(bad, ", "):sub(1, 200))
        end },
    { text = "Look through Smart Categories and Disabled too.\n\n|cffffd100Expect:|r the same columns everywhere; tell us in the note if any row still looks off.",
        noVerdict = true },
} })

-------------------------------------------------------------------------------
-- 9. Auto-Generate Rules: one icon, four buttons (Options 0.6.65; UI-71: "this needs work, it's too noisy. one icon, four buttons";
-- her answer "icon | four lines")
-------------------------------------------------------------------------------
local function CreatorArgs()
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    local t = reg and reg:GetOptionsTable("CueRules", "dialog", "AceConfigDialog-3.0")
    if type(t) == "function" then t = t("dialog", "AceConfigDialog-3.0") end
    local found
    local function walk(g, d) if type(g) ~= "table" or d > 12 or found then return end
        if g.type == "group" and g.name == "Auto-Generate Rules" then found = g; return end
        for _, o in pairs(type(g.args) == "table" and g.args or {}) do walk(o, d + 1) end end
    walk(t, 0)
    return found and found.args
end
QA.Register("ui-autogen-layout", { title = "Auto-Generate Rules: one icon, four buttons per spec", qa = "B229", order = 268, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: Rules > Auto-Generate Rules opens.\n\n|cffffd100Expect:|r for each spec: its icon once at the left, and its four buttons (Generate All Rules for <spec>, CD Tracking, Aura Tracking, Target Debuff Tracking) as four lines beside it; the buttons carry no icon of their own. Your class's four buttons the same, without an icon.",
        setup = function() Open("cooldowns", "creatorTab") end,
        check = function()
            local a = CreatorArgs()
            if not a then return false, "the Auto-Generate Rules page was not found (open the settings window once)" end
            local specs, bad = 0, {}
            for i = 1, 4 do
                local p = "apSpec" .. i
                if a[p .. "all"] then
                    specs = specs + 1
                    if not (a[p .. "Ic1"] and a[p .. "Ic1"].image) then bad[#bad + 1] = p .. ": no icon" end
                    for j = 2, 4 do if a[p .. "Ic" .. j] and a[p .. "Ic" .. j].image then bad[#bad + 1] = p .. ": a second icon" end end
                    for _, f in ipairs({ "all", "cd", "aura", "debuff" }) do
                        if tostring(a[p .. f] and a[p .. f].name):find("|T", 1, true) then bad[#bad + 1] = p .. f .. ": icon on the button" end
                    end
                end
            end
            if specs == 0 then return false, "no spec buttons found" end
            return #bad == 0, #bad == 0 and (specs .. " spec(s): one icon each, four buttons as four lines") or table.concat(bad, "; ")
        end },
    { text = "Your look: is it calm enough now? Pass if yes; Fail and say what is still noisy.", noVerdict = true },
} })

-------------------------------------------------------------------------------
-- 10. Core windows' flat buttons after a /reload (UI-77, O-139; core 0.6.68)
-------------------------------------------------------------------------------
local function Kids(frame)
    local out = {}
    if not (frame and frame.GetChildren) then return out end
    for _, k in ipairs({ frame:GetChildren() }) do
        if k.GetObjectType and k:GetObjectType() == "Button" and k.GetText and k:GetText() then out[#out + 1] = k end
    end
    return out
end
-- every text button of the frame has the flat look in the theme's button text colour
local function FlatCheck(frame, label)
    if not (frame and frame:IsShown()) then return false, label .. " is not open: press Do it for me" end
    local ns = NS()
    local T = ns and ns.Theme
    local want = T and T.Col and T.Col("xui-button", "text", { 1, 0.82, 0, 1 }) or { 1, 0.82, 0, 1 }
    local skinOff = PlatS.ui and PlatS.ui.skinOff
    if skinOff then return false, "the flat skin is switched off (/xuiskin): switch it on and try again" end
    local bad, n = {}, 0
    for _, b in ipairs(Kids(frame)) do
        n = n + 1
        local fs = b.GetFontString and b:GetFontString()
        local r, g, bl = 0, 0, 0
        if fs then r, g, bl = fs:GetTextColor() end
        if not b.xuiFlatBtn then bad[#bad + 1] = b:GetText() .. ": Blizzard look"
        elseif not (Near(r, want[1], 0.02) and Near(g, want[2], 0.02) and Near(bl, want[3], 0.02)) then bad[#bad + 1] = b:GetText() .. ": not the theme's button colour" end
    end
    if n == 0 then return false, label .. ": no buttons found" end
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("XayaUI_Options")
    local where = loaded and " (the settings addon is loaded now, so this is not the after-/reload case)" or " (the settings addon is not loaded: the after-/reload case)"
    return #bad == 0, (#bad == 0 and (label .. ": all " .. n .. " buttons flat") or table.concat(bad, "; ")) .. where
end
QA.Register("ui-core-flat-buttons", { title = "Console, copy box, debug report: flat buttons after /reload", qa = "B231", order = 269, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the XayaUI console opens.\n\n|cffffd100Expect:|r What to send, Copy, Clear and Bug report are flat (a dark box, text in your theme's button colour), not Blizzard's red buttons. The close X keeps Blizzard's red X on purpose, like the settings window's.",
        setup = function() local ns = NS(); if ns and ns.ConsoleWindow then ns.ConsoleWindow(true) end end,
        check = function() return FlatCheck(rawget(_G, "XayaUIConsoleWindow"), "the console") end },
    { text = "The case you reported: leave the console open and type |cffffd100/reload|r. When the game is back, the console reopens by itself; open this walkthrough again and go to the next step. (Do not open the settings window first: the bug only showed while it had not been opened.)", noVerdict = true },
    { text = "After the /reload, with the console open: press |cffffd100Check|r.\n\n|cffffd100Expect:|r the console's four buttons are flat, and the note says the settings addon is not loaded.",
        check = function() return FlatCheck(rawget(_G, "XayaUIConsoleWindow"), "the console") end },
    { text = "Press |cffffd100Do it for me|r: the copy box (What to send) and the debug report open.\n\n|cffffd100Expect:|r Select all (copy box) and the string button (debug report) are flat too.",
        setup = function()
            local ns = NS(); if not ns then return end
            if ns.ShowCopyBox and ns.SendText then ns.ShowCopyBox("XayaUI: what to send", ns.SendText()) end
            if ns.ShowDebugReport then ns.ShowDebugReport() end
        end,
        check = function()
            local ok1, n1 = FlatCheck(rawget(_G, "XayaUICopyBox"), "the copy box")
            local ok2, n2 = FlatCheck(rawget(_G, "XayaUIDebugReport"), "the debug report")
            return ok1 and ok2, n1 .. " | " .. n2
        end },
} })

-------------------------------------------------------------------------------
-- 11. Debug report: Select string, then Ctrl+C (UI-78, O-128; core 0.6.69)
-------------------------------------------------------------------------------
local function Report() local ns = NS(); return ns and ns.DebugReportWindow and ns.DebugReportWindow() end
QA.Register("ui-report-select", { title = "Debug report: Select string, then Ctrl+C", qa = "B232", order = 270, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the debug report (/xui report) opens.\n\n|cffffd100Expect:|r the button beside the string says Select string, and the hint at the top says to press it, then Ctrl+C (Cmd+C on Mac). (An addon cannot copy by itself: the game keeps the clipboard to its own code.)",
        setup = function() local ns = NS(); if ns and ns.ShowDebugReport then ns.ShowDebugReport() end end,
        check = function()
            local w = Report()
            if not (w and w:IsShown()) then return false, "the debug report is not open: press Do it for me" end
            local label, hint = w.copy and w.copy:GetText() or "?", w.hint and w.hint:GetText() or ""
            local ok = label == "Select string" and hint:find("Select string", 1, true) ~= nil and hint:find("Cmd+C", 1, true) ~= nil
            return ok, "button: " .. label .. " | hint: " .. hint
        end },
    { text = "Press |cffffd100Do it for me|r (it presses Select string for you).\n\n|cffffd100Expect:|r the whole string is highlighted, and the hint says: now press Ctrl+C (Cmd+C on Mac) to copy it, then paste it to Xaya.",
        setup = function() local w = Report(); local f = w and w.copy and w.copy:GetScript("OnClick"); if f then f(w.copy, "LeftButton") end end,
        check = function()
            local w = Report()
            if not (w and w:IsShown()) then return false, "the debug report is not open: go back one step" end
            local hint = w.hint and w.hint:GetText() or ""
            local focus = w.str and w.str.HasFocus and w.str:HasFocus()
            return (focus and hint:find("now press Ctrl+C", 1, true)) and true or false, (focus and "the string box has the focus" or "the string box does not have the focus") .. " | hint: " .. hint
        end },
    { text = "Your test: press Ctrl+C (Cmd+C on Mac), then click into a chat line and paste (Ctrl+V), without sending. Pass if the whole XUIREP1:... string arrives; Fail and say what came instead.", noVerdict = true },
} })

-------------------------------------------------------------------------------
-- 12. Shopping List: when it shows itself (UI-77 part 2, O-139; QoL 0.7.42)
-------------------------------------------------------------------------------
local function ShopSvc() return Svc("shoppingList") end
local function ShopPanel() return rawget(_G, "XayaUIShoppingList") end
local function ShopState()
    local S = ShopSvc(); if not S then return nil, "XayaUI QoL or the Shopping List is off" end
    local c = S.Cfg(); local p = ShopPanel()
    return c, (p and p:IsShown()) and true or false
end
QA.Register("ui-shop-autoshow", { title = "Shopping List: shows itself only at the Auction House or for missing enchants / gems", qa = "B233", order = 271, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the Shopping List and its panel are switched on, the panel opens, then it is closed as with its X.\n\n|cffffd100Expect:|r the panel is gone and the close is saved (it holds until your next Auction House visit).",
        setup = function()
            local S = ShopSvc(); if not S then return end
            local c = S.Cfg(); c.enabled, c.panel = true, true; S.Apply(true)
            local p = ShopPanel(); if p then c.closedTillAH = true; p:Hide() end
        end,
        check = function()
            local c, shown = ShopState(); if not c then return false, shown end
            return (not shown) and c.closedTillAH == true, (shown and "the panel is showing" or "the panel is closed") .. (c.closedTillAH and ", the close is saved" or ", the close is NOT saved")
        end },
    { text = "Type |cffffd100/reload|r. When the game is back, open this walkthrough again and go to the next step.\n\n|cffffd100Expect:|r the Shopping List does not pop up at login.", noVerdict = true },
    { text = "After the /reload: press |cffffd100Check|r.\n\n|cffffd100Expect:|r the panel is not showing and the close is still saved.",
        check = function()
            local c, shown = ShopState(); if not c then return false, shown end
            return (not shown) and c.closedTillAH == true, (shown and "the panel popped up" or "the panel stayed closed") .. (c.closedTillAH and ", the close is saved" or ", the close was lost")
        end },
    { text = "Go to an Auctioneer and open the Auction House, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the Shopping List opens by itself, and the close is forgotten.",
        check = function()
            local c, shown = ShopState(); if not c then return false, shown end
            return shown and c.closedTillAH ~= true, (shown and "the panel is showing" or "the panel is not showing") .. (c.closedTillAH and ", the close is still saved" or ", the close is forgotten")
        end },
    { text = "Close it with its X, then type |cffffd100/xui shop|r.\n\n|cffffd100Expect:|r /xui shop opens it again any time.",
        check = function() local c, shown = ShopState(); if not c then return false, shown end; return shown, shown and "the panel is showing" or "the panel is not showing" end },
    { text = "Your look: with nothing missing on your gear, does it now stay away until you visit the Auction House or ask for it? Pass if yes; Fail and say when it still popped up.", noVerdict = true },
} })

QA.Register("upg-shop-toast", { title = "Shopping List: toast for a new item that may be an upgrade", qa = "E2i", order = 272, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the Shopping List and its panel are switched on and the suggestion toast is switched on.\n\n|cffffd100Expect:|r the check says the toast is on; the list has no toast showing yet.",
        setup = function()
            local S = ShopSvc(); if not S then return end
            local c = S.Cfg(); c.enabled, c.panel, c.upgradeToast = true, true, true; S.Apply(true)
        end,
        check = function()
            local c, shown = ShopState(); if not c then return false, shown end
            local f = rawget(_G, "XayaUIShoppingToast")
            return c.upgradeToast == true and not (f and f:IsShown()), "toast switch " .. (c.upgradeToast and "on" or "off") .. ", toast " .. ((f and f:IsShown()) and "showing" or "not showing")
        end },
    { text = "Loot or buy a piece of gear with an empty socket or an enchant slot, on the same upgrade track as what you wear with a higher item level, or on a higher track. Then press |cffffd100Check|r.\n\n|cffffd100Expect:|r one toast at the top: \"XUI has detected a new item that may potentially be an upgrade. Do you want to add a ... to your shopping list for it?\" with Yes, No and two ticks.",
        check = function()
            local f = rawget(_G, "XayaUIShoppingToast")
            return (f and f:IsShown()) and true or false, (f and f:IsShown()) and ("the toast is showing: " .. tostring(f.text and f.text:GetText())) or "no toast is showing"
        end },
    { text = "Press |cffffd100Yes|r on the toast, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the toast closes and the gem / enchant is in To buy.",
        check = function()
            local S = ShopSvc(); local c = S and S.Cfg(); local f = rawget(_G, "XayaUIShoppingToast")
            if not c then return false, "XayaUI QoL or the Shopping List is off" end
            return (not (f and f:IsShown())) and #c.buy > 0, ((f and f:IsShown()) and "the toast is still showing" or "the toast is closed") .. ", " .. #c.buy .. " line(s) in To buy"
        end },
    { text = "Your look: loot a second such item, tick |cffffd100ignore item|r and press No. Does that item stay silent, and does a worse-track item, one with no socket or enchant slot, and what was already in your bags stay silent too? Pass if yes; Fail and say which one asked.", noVerdict = true },
} })

-------------------------------------------------------------------------------
-- 13. Brief hover texts (UI-65; every changed addon's version bumped, Dev Assist 0.7.22)
-------------------------------------------------------------------------------
-- sentences in a hover text: the first line only (lines after it are a list of the choices, one per line), and a "?" right after a lone
-- capital (the "E?" mark) does not end one
local function Sentences(s)
    s = tostring(s or ""):match("^[^\n]*"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("(%f[%w]%u)%?", "%1")
    s = s:gsub("e%.g%.", "eg"):gsub("i%.e%.", "ie"):gsub("etc%.", "etc"):gsub("vs%.", "vs"):gsub("(%d)%.(%d)", "%1%2")
    local n = 0
    for _ in (s .. " "):gmatch("[%.!?]%s") do n = n + 1 end
    if not s:match("[%.!?]%s*$") and s:match("%S") then n = n + 1 end
    return n
end
QA.Register("ui-short-hovers", { title = "Hover texts: a title and at most two sentences", qa = "B234", order = 272, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens and every option's hover text is read.\n\n|cffffd100Expect:|r none has more than two sentences (the note lists any that do).",
        setup = function() local ns = NS(); if ns and ns.LoadOptions then ns.LoadOptions() end end,
        check = function()
            local ns = NS()
            local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
            local t = reg and reg:GetOptionsTable("CueRules", "dialog", "AceConfigDialog-3.0")
            if type(t) == "function" then t = t("dialog", "AceConfigDialog-3.0") end
            if type(t) ~= "table" then return false, "the settings window's options were not found (open it once)" end
            local n, long, seen = 0, {}, {}
            local function walk(node, d)
                if type(node) ~= "table" or d > 12 or seen[node] then return end
                seen[node] = true
                if type(node.desc) == "string" and node.desc ~= "" then
                    n = n + 1
                    if Sentences(node.desc) > 2 and #long < 6 then long[#long + 1] = tostring(node.name or "?") end
                end
                if type(node.args) == "table" then for _, c in pairs(node.args) do walk(c, d + 1) end end
            end
            walk(t, 0)
            if n == 0 then return false, "no hover text was found in the settings window's options" end
            return #long == 0, n .. " hover texts read" .. (#long > 0 and ("; longer than two sentences: " .. table.concat(long, ", ")) or "")
        end },
    { text = "Your look: hover a few switches on pages you use (Chat Panel, Tooltips, a rule's trigger). Are they brief and clear now? Pass if yes; Fail and name the ones to redo.", noVerdict = true },
} })

-- UI-51 / UI-52 slice 1 (core 0.6.73, Chat 0.6.39, Bonus 0.6.29; Dev Assist 0.7.48): the shared tooltip helper ns.Tip draws the
-- minimap button's hovers, the mover's group tags and the Chat privacy / history / collapse hovers (the same text as before), and the
-- minimap list row says "Data Panels" (DISPLAY-RULES A7.2).
QA.Register("ui-tooltip-helper", { title = "Hovers drawn by the shared helper; minimap row \"Data Panels\"", qa = "B279", order = 274, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the addon reads the minimap list and hovers the minimap button once by itself.\n\n|cffffd100Expect:|r the list has a \"Data Panels\" row (no \"Custom data panels\"), and the button's hover starts with \"XayaUI\" (the note lists what it read).",
        check = function()
            local ns = NS()
            if not (ns and ns.Tip and ns.Tip.Show) then return false, "core's ns.Tip is missing (core older than 0.6.73?)" end
            local label
            for _, e in ipairs(ns.Launchers and ns.Launchers() or {}) do if e[1] == "data" then label = e[2] end end
            local b = rawget(_G, "XayaUIMinimapButton")
            local enter = b and b:GetScript("OnEnter")
            local first, n = nil, 0
            if enter then
                pcall(enter, b)
                n = GameTooltip and GameTooltip:NumLines() or 0
                local fs = rawget(_G, "GameTooltipTextLeft1")
                first = fs and fs.GetText and fs:GetText()
                local leave = b:GetScript("OnLeave"); if leave then pcall(leave, b) end
            end
            local ok = label == "Data Panels" and first == "XayaUI"
            return ok, "list row: " .. tostring(label or "(no Data Panels row: is XayaUI Bonus on?)") .. "; minimap hover: " .. tostring(first) .. " (" .. n .. " lines)"
        end },
    { text = "Your look: hover the minimap button, a row of its list, the chat's privacy button, its history button and its collapse arrow; then /xui unlock and hover a group's tab and its lock. Do they read and look exactly as before (same words, colours, place)? Pass if yes; Fail and name the one that changed.", noVerdict = true },
} })
