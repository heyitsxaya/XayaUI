-------------------------------------------------------------------------------
-- QAWalks-options-split.lua (XayaUI_DevAssist 0.7.56): the in-game regression walkthrough for the Options split of the platform split,
-- phase P3 (docs/plans/PLATFORM-SPLIT-2026-11-07.md sections 7, 10, risk R8; Options 0.6.83, QA H13). The rule editor and the rules tree
-- moved out of XayaUI_Options/Options.lua into XayaUI_Options/RuleEditor/ unchanged: nothing a player sees may change.
-- Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on her click).
-- Two parts around a /reload:
--   part 1: the window opens; every top tab and every page of the feature tabs, Settings and Profiles draws at least one row with no
--           Lua error; a QA test rule is opened, its trigger's spell is changed through the editor's own Spell ID box, she presses
--           Ctrl+Z (the undo) and the spell is back; the window closes; XayaUI Nameplates is switched off for the next /reload;
--   part 2: after the /reload, XayaUI Nameplates is not loaded and QoL > Nameplates is not in the window; it is switched back on and
--           the test rule and group are removed.
-- Reaches XayaUI only through core (ns.LoadOptions, ns.NewRule, ns.NewFolder, ns.Recycle*, ns.ErrorCount) and ns.OptionsApi (IsOpen,
-- Toggle, EditRule, LastTree). C_AddOns.DisableAddOn / EnableAddOn (docs/reference/api/namespaces.md: name, character = "0"; called
-- with the default character, as DevAssist.lua's old-folder check does; which characters that covers is not documented: INFERENCE).
-- UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local APP = "CueRules"
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Api()
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then return nil end
    return ns.OptionsApi
end
local function Errors() local ns = NS(); local n = ns and ns.ErrorCount and ns.ErrorCount(); return tonumber(n) or 0 end
local function OpenFrame() local a = ACD(); return a and a.OpenFrames and a.OpenFrames[APP] end
-- rows drawn in the window: AceGUI widgets that are not containers (a label, a button, a box, a tick box ...)
local CONTAINERS = { Frame = true, TabGroup = true, TreeGroup = true, SimpleGroup = true, InlineGroup = true, ScrollFrame = true }
local function Rows(w, d)
    d = d or 0
    if type(w) ~= "table" or d > 30 then return 0 end
    local kids = w.children
    if type(kids) ~= "table" or #kids == 0 then return CONTAINERS[w.type or ""] and 0 or 1 end
    local n = 0
    for _, c in ipairs(kids) do n = n + Rows(c, d + 1) end
    return n
end
local function Shown(node, key)
    local h = node and node.hidden
    if type(h) == "function" then local ok, v = pcall(h, { key }); return not (ok and v) end
    return not h
end
local function Sorted(args)
    local list = {}
    for k, g in pairs(args or {}) do
        if type(g) == "table" and g.type == "group" and not g.inline and Shown(g, k) then
            local o = g.order; if type(o) == "function" then local ok, v = pcall(o); o = ok and v or nil end
            list[#list + 1] = { k = k, g = g, o = tonumber(o) or 100 }
        end
    end
    table.sort(list, function(a, b) if a.o ~= b.o then return a.o < b.o end return tostring(a.k) < tostring(b.k) end)
    return list
end

-- the QA test data: one group and one rule in it, tagged (qaOptSplit); your own rules and groups are never touched
local GROUP_NAME, RULE_NAME, SPELL_A, SPELL_B = "QA options split", "QA options split rule", 61304, 48707
local function Tagged(x) return type(x) == "table" and x.qaOptSplit == true end
local function TestRule() local ns = NS(); for _, r in ipairs(ns and ns.rules or {}) do if Tagged(r) and not r.parentUid then return r end end end
local function Cleanup()
    local ns = NS(); if not ns then return end
    local list = {}
    for _, r in ipairs(ns.rules or {}) do if Tagged(r) and not r.parentUid then list[#list + 1] = r end end
    for _, r in ipairs(list) do ns.RecycleRule(r) end
    for i = #(ns.folders or {}), 1, -1 do local f = ns.folders[i]; if Tagged(f) then ns.RecycleFolder(f) end end
    local b = ns.RecycleDB and ns.RecycleDB()
    local ids = {}
    for _, it in ipairs(b and b.items or {}) do
        local mine = false
        for _, r in ipairs(it.rules or {}) do if Tagged(r) then mine = true end end
        for _, f in ipairs(it.folders or {}) do if Tagged(f) then mine = true end end
        if mine then ids[#ids + 1] = it.id end
    end
    for _, id in ipairs(ids) do ns.RecycleDeleteNow(id) end
    ns.MarkDirty()
    if ns.Fire then ns.Fire("CONFIG_CHANGED") end
end
local function RuleKey(r) local ns = NS(); for i, x in ipairs(ns and ns.rules or {}) do if x == r then return "rule" .. i end end end
local function Find(node, key, d)
    d = d or 0
    if type(node) ~= "table" or d > 20 or type(node.args) ~= "table" then return nil end
    if node.args[key] ~= nil then return node.args[key] end
    for _, c in pairs(node.args) do local hit = Find(c, key, d + 1); if hit then return hit end end
end

local NP = "XayaUI_Nameplates"
local st = {}
local closedForReload   -- set in part 1 of this session (gone after the /reload)
QA.Register("options-split", { title = "Options split: the settings window, every tab and page, and the rule editor (part 1 of 2) (H13)", area = "Platform", qa = "H13", order = 272.4, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens.\n\n|cffffd100Expect:|r the window opens on the Rules tab as usual, with no Lua error. The check counts the rows the window drew and XayaUI's error count before and after.",
        setup = function()
            local api = Api(); if not api then error("the settings window addon (XayaUI_Options) could not be loaded") end
            st.err0 = Errors()
            if not api.IsOpen() then api.Toggle() end
        end,
        check = function()
            local api = Api(); if not (api and st.err0) then return nil, "press Do it for me first" end
            local rows, e = Rows(OpenFrame()), Errors() - st.err0
            return (api.IsOpen() and rows > 0 and e == 0) and true or false, ("open: %s; rows drawn: %d; new XayaUI errors: %d"):format(tostring(api.IsOpen()), rows, e)
        end },
    { text = "Press |cffffd100Do it for me|r: the window shows every top tab in turn (Rules, QoL, Bonus Features, Blizzard Reskin, Profiles, Settings), then every page in the left pane of QoL, Bonus Features, Blizzard Reskin and Settings, and every sub-tab of Rules and Profiles. It takes a moment.\n\n|cffffd100Expect:|r the window flips through the pages and ends on the last one, with no Lua error. The check lists every page with the rows it drew; a page with none fails.",
        setup = function()
            local api, a = Api(), ACD()
            if not (api and a) then error("the settings window could not be loaded") end
            if not api.IsOpen() then api.Toggle() end
            st.err1, st.pages, st.bad = Errors(), {}, {}
            local function show(...)
                local path = { ... }
                local ok, err = pcall(a.SelectGroup, a, APP, ...)
                local n = ok and Rows(OpenFrame()) or 0
                st.pages[#st.pages + 1] = table.concat(path, ">") .. "=" .. n
                if not ok or n == 0 then st.bad[#st.bad + 1] = table.concat(path, ">") .. (ok and " (no rows)" or (" (" .. tostring(err) .. ")")) end
            end
            local tree = api.LastTree() or {}
            for _, top in ipairs(Sorted(tree.args)) do
                show(top.k)
                tree = api.LastTree() or tree   -- (a page drawn may build the tree again)
                local node = tree.args and tree.args[top.k] or top.g
                for _, sub in ipairs(Sorted(node.args)) do show(top.k, sub.k) end
            end
        end,
        check = function()
            if not st.pages then return nil, "press Do it for me first" end
            local e = Errors() - st.err1
            return (#st.bad == 0 and e == 0 and #st.pages > 0) and true or false, ("%d pages; without rows or with an error: %s; new XayaUI errors: %d | %s"):format(
                #st.pages, #st.bad == 0 and "none" or table.concat(st.bad, ", "), e, table.concat(st.pages, " "))
        end },
    { text = "Press |cffffd100Do it for me|r: a QA test group \"" .. GROUP_NAME .. "\" with one rule (\"" .. RULE_NAME .. "\", a cooldown rule on spell " .. SPELL_A .. ") is made and opened in the rule editor.\n\n|cffffd100Expect:|r the rule is selected in the left pane and its editor is shown.",
        setup = function()
            local ns, api = NS(), Api()
            if not (ns and api and ns.NewRule) then error("the settings window could not be loaded") end
            Cleanup()
            local f = ns.NewFolder(GROUP_NAME); f.qaOptSplit = true
            local r = ns.NewRule(); r.name = RULE_NAME; r.folder = f.id; r.enabled = true; r.uid = ns.NewUID(); r.qaOptSplit = true
            r.useCooldown, r.spellID, r.cdState = true, SPELL_A, "ready"
            ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
            ns.MarkDirty()
            st.err2 = Errors()
            api.EditRule(r)
        end,
        check = function()
            local api, r = Api(), TestRule()
            if not (api and r and st.err2) then return nil, "press Do it for me first" end
            local re = api.RuleEditor
            local sel = re and re.SelectedRule and re.SelectedRule()
            local e = Errors() - st.err2
            return (sel == r and e == 0) and true or false, ("selected in the left pane: %s; new XayaUI errors: %d"):format(sel and tostring(sel.name) or "nothing", e)
        end },
    { text = "Press |cffffd100Do it for me|r: the rule's spell is changed to " .. SPELL_B .. " through its Trigger tab's own Spell ID box.\n\n|cffffd100Expect:|r the Spell ID reads " .. SPELL_B .. ".",
        setup = function()
            local api, r = Api(), TestRule()
            if not (api and r) then error("the test rule is missing: run the step before again") end
            local node = Find(api.LastTree(), RuleKey(r))
            local trig = node and Find(node, "trigger")
            local box = trig and Find(trig, "spellID")
            if not (box and box.set) then error("the rule's Trigger > Spell ID box was not found") end
            box.set(nil, tostring(SPELL_B))
        end,
        check = function()
            local r = TestRule(); if not (r and st.err2) then return nil, "press Do it for me first" end
            local e = Errors() - st.err2
            return (tonumber(r.spellID) == SPELL_B and e == 0) and true or false, ("spell ID now: %s (want %d); new XayaUI errors: %d"):format(tostring(r.spellID), SPELL_B, e)
        end },
    { text = "Click once on the settings window (so it has the keyboard), wait a second, then press |cffffd100Ctrl+Z|r (undo).\n\n|cffffd100Expect:|r a chat line \"undid the last change to '" .. RULE_NAME .. "'\" and the Spell ID box reads " .. SPELL_A .. " again. Then press Check.",
        check = function()
            local r = TestRule(); if not r then return nil, "the test rule is missing: run step 3 again" end
            return tonumber(r.spellID) == SPELL_A, ("spell ID now: %s (want %d after the undo)"):format(tostring(r.spellID), SPELL_A)
        end },
    { text = "Press |cffffd100Do it for me|r: the settings window closes.\n\n|cffffd100Expect:|r it closes with no Lua error.",
        setup = function() local api = Api(); st.err3 = Errors(); if api and api.IsOpen() then api.Toggle() end end,
        check = function()
            local api = Api(); if not (api and st.err3) then return nil, "press Do it for me first" end
            local e = Errors() - st.err3
            return (not api.IsOpen() and e == 0) and true or false, ("open: %s; new XayaUI errors: %d"):format(tostring(api.IsOpen()), e)
        end },
    { text = "Press |cffffd100Do it for me|r: XayaUI Nameplates is switched off for your next /reload (part 2 switches it back on). If it is not installed or already off, this step says so: skip it and part 2's first check.\n\n|cffffd100Expect:|r the check reads that it is set to off.",
        setup = function()
            if not (C_AddOns and C_AddOns.DisableAddOn and C_AddOns.IsAddOnLoaded) then error("the game's AddOns calls are missing") end
            local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, NP)
            if not (ok and loaded) then error("XayaUI Nameplates is not loaded: skip this step and part 2's first check") end
            C_AddOns.DisableAddOn(NP)
            closedForReload = true
        end,
        check = function()
            if not closedForReload then return nil, "press Do it for me first" end
            local ok, s = pcall(C_AddOns.GetAddOnEnableState, NP)
            return (ok and s == 0) and true or false, ("XayaUI Nameplates enable state: %s (0 = off)"):format(tostring(s))
        end },
    { done = true, text = "Press |cffffd100Done|r here first (so this record is kept), type |cffffd100/reload|r, and run \"Options split: a switched-off module's page after the /reload (part 2 of 2) (H13)\"." },
} })

QA.Register("options-split-reload", { title = "Options split: a switched-off module's page after the /reload (part 2 of 2) (H13)", area = "Platform", qa = "H13", order = 272.5, prefill = true, steps = {
    { text = "Run this after part 1 and its /reload. Press |cffffd100Do it for me|r: the settings window opens on the QoL tab.\n\n|cffffd100Expect:|r XayaUI Nameplates is not loaded, and the QoL tab's left pane has no Nameplates page.",
        setup = function()
            local api, a = Api(), ACD()
            if not (api and a) then error("the settings window could not be loaded") end
            if not api.IsOpen() then api.Toggle() end
            pcall(a.SelectGroup, a, APP, "qol")
        end,
        check = function()
            if closedForReload then return nil, "not reloaded yet: type /reload, then come back and Check again" end
            local api = Api(); if not api then return false, "the settings window could not be loaded" end
            local okL, loaded = pcall(C_AddOns.IsAddOnLoaded, NP)
            local tree = api.LastTree() or {}
            local qol = tree.args and tree.args.qol
            local page = qol and qol.args and qol.args.nameplates
            return ((not (okL and loaded)) and page == nil) and true or false, ("XayaUI Nameplates loaded: %s; QoL > Nameplates page: %s"):format(
                tostring(okL and loaded), page and "still there" or "absent")
        end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to switch XayaUI Nameplates back on (from the next /reload) and remove the QA test group and rule (and their Recycle Bin items). Then press |cffffd100Done|r and type |cffffd100/reload|r: QoL > Nameplates is back.",
        setup = function()
            if C_AddOns and C_AddOns.EnableAddOn then pcall(C_AddOns.EnableAddOn, NP) end
            Cleanup()
        end,
        check = function()
            local ns = NS(); if not ns then return false, "XayaUI is not loaded" end
            for _, r in ipairs(ns.rules or {}) do if Tagged(r) then return false, "the QA test rule is still there" end end
            for _, f in ipairs(ns.folders or {}) do if Tagged(f) then return false, "the QA test group is still there" end end
            local ok, s = pcall(C_AddOns.GetAddOnEnableState, NP)
            return (ok and s ~= 0) and true or false, ("test data gone; XayaUI Nameplates enable state: %s (0 = off)"):format(tostring(s))
        end },
} })
