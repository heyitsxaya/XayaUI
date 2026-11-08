-------------------------------------------------------------------------------
-- QAWalks-rule-editor-folder.lua (XayaUI_DevAssist 0.7.58): the in-game walkthrough for phase P4b of the platform split
-- (docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7 and Q1; Options 0.6.87, XayaUI 0.6.77, XayaUI_Rules_Options 0.6.77; QA H15).
-- The rule editor (the Rules tab) moved out of XayaUI_Options into its own load-on-demand addon, XayaUI_Rules_Options ("XayaUI Rules
-- Options"), which the settings window loads when it opens while XayaUI Rules is on; the row painting every tab shares moved into
-- XayaUI_Options/TreePaint.lua. Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true;
-- recorded only on her click). Two parts around one /reload:
--   part 1 (XayaUI Rules on): the AddOns list entry; the window opens and the rule editor is loaded with it; a QA test rule opens in
--           the Rules tab; its trigger spell is changed and Ctrl+Z puts it back; the window closes; XayaUI Rules is switched off;
--   part 2 (XayaUI Rules off): the rule editor is not loaded, the window opens without the Rules tab and with the feature tabs' tick
--           boxes, opening it loads nothing of the editor; XayaUI Rules is switched back on.
-- Reaches XayaUI only through the Platform (ns.LoadOptions, ns.ToggleUI, ns.EditRule, ns.ErrorCount) and ns.OptionsApi (published by
-- XayaUI_Options), and while XayaUI Rules is loaded its own names (ns.NewRule, ns.NewUID ...). C_AddOns.DisableAddOn / EnableAddOn as
-- in QAWalks-code-move.lua (which characters the default covers is not documented: INFERENCE). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local RULES, EDITOR = "XayaUI_Rules", "XayaUI_Rules_Options"
local APP = "CueRules"
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Api()
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then return nil end
    return ns.OptionsApi
end
local function Errors() local ns = NS(); local n = ns and ns.ErrorCount and ns.ErrorCount(); return tonumber(n) or 0 end
local function Loaded(addon) local ok, l = pcall(C_AddOns.IsAddOnLoaded, addon); return ok and l and true or false end
local function Title(addon) local ok, _, t = pcall(C_AddOns.GetAddOnInfo, addon); return ok and t or nil end
local function Selected(...)
    local a = ACD(); if not (a and a.GetStatusTable) then return nil end
    local s = a:GetStatusTable(APP, { ... })
    return s and s.groups and s.groups.selected
end

-- the QA test rule (tagged qaRuleEditor; your own rules are never touched). Spell IDs 47528 / 49576 are the ones the test suite uses
-- (Mind Freeze / Death Grip); the rule only needs a spell to show in its trigger, it is switched off so it never fires.
local RULE_NAME = "QA rule editor rule"
local FIRST, SECOND = 47528, 49576
local function TestRule()
    local ns = NS()
    for _, r in ipairs(ns and ns.rules or {}) do if type(r) == "table" and r.qaRuleEditor and not r.parentUid then return r end end
end
local cleaned = {}   -- (0.7.64) what the last clean-up did: left = went back to the list, shifted = a row still on a moved place
QA.RuleEditorFolderCleaned = cleaned   -- (tests)
local function Cleanup()
    cleaned.left, cleaned.shifted = false, nil
    local ns = NS(); if not (ns and ns.rules) then return end
    local first
    for i = #ns.rules, 1, -1 do if type(ns.rules[i]) == "table" and ns.rules[i].qaRuleEditor then table.remove(ns.rules, i); first = i end end
    -- (0.7.64, debug W3) the editor (open, or opened again later) must not slide onto the rule after the QA rule: back to the list
    -- (QAWalks-bars.lua QA.LeaveMovedRuleRow, as Delete this rule does)
    if QA.LeaveMovedRuleRow then cleaned.left, cleaned.shifted = QA.LeaveMovedRuleRow(first) end
    if ns.MarkDirty then ns.MarkDirty() end
end

local st = {}
local switchedOff, switchedOn

QA.Register("rule-editor-folder", { title = "Rule editor in its own folder: the Rules tab, Ctrl+Z (part 1 of 2) (H15)", area = "Platform", qa = "H15", order = 272.9, prefill = true, steps = {
    { text = "Open the game's AddOns list (Esc > AddOns) and look at XayaUI's entries, then close it and press Check.\n\n|cffffd100Expect:|r a new entry |cffffd100XayaUI Rules Options|r is there and ticked (it loads only when the settings window opens). The check reads its title and whether it is loaded yet.",
        check = function()
            local t = Title(EDITOR)
            return (t == "XayaUI Rules Options") and true or false,
                ("XayaUI_Rules_Options: title %s, loaded now: %s; XayaUI Rules loaded: %s"):format(tostring(t), tostring(Loaded(EDITOR)), tostring(Loaded(RULES)))
        end },
    { text = "Press |cffffd100Do it for me|r: the settings window opens (as /xui does).\n\n|cffffd100Expect:|r the window opens on the Rules tab as before, with its rule list; the check reads that XayaUI Rules Options is now loaded and the Rules tab is built, with no new XayaUI error.",
        setup = function()
            local ns = NS()
            if not (ns and Loaded(RULES)) then error("XayaUI Rules is not loaded: switch it on in the AddOns list and /reload") end
            st.err = Errors()
            local api = Api(); if not api then error("the settings window (XayaUI_Options) could not be loaded") end
            if not api.IsOpen() then api.Toggle() end
        end,
        check = function()
            local api = Api(); if not (api and st.err) then return nil, "press Do it for me first" end
            local tree = api.LastTree and api.LastTree()
            local rulesTab = tree and tree.args and tree.args.cooldowns ~= nil
            local e = Errors() - st.err
            return (api.IsOpen() and Loaded(EDITOR) and rulesTab and e == 0) and true or false,
                ("window open: %s; XayaUI Rules Options loaded: %s; Rules tab: %s; new XayaUI errors: %d"):format(
                    tostring(api.IsOpen()), tostring(Loaded(EDITOR)), rulesTab and "there" or "absent", e)
        end },
    { text = "Press |cffffd100Do it for me|r: a QA test rule \"" .. RULE_NAME .. "\" (switched off, so it never fires) is made and opened in the Rules tab.\n\n|cffffd100Expect:|r the rule is selected in the rule list on the left and its settings show on the right (Trigger, Conditions, Cues ...).",
        setup = function()
            local ns = NS()
            if not (ns and ns.NewRule and ns.EditRule) then error("XayaUI Rules is not loaded") end
            Cleanup()
            local r = ns.NewRule(); r.name = RULE_NAME; r.enabled = false; r.uid = ns.NewUID(); r.qaRuleEditor = true; r.spellID = FIRST
            ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
            ns.MarkDirty()
            ns.EditRule(r)
        end,
        check = function()
            local ns, r = NS(), TestRule(); if not r then return nil, "press Do it for me first" end
            local idx
            for i, x in ipairs(ns.rules) do if x == r then idx = i end end
            local found = false
            for _, sub in ipairs({ "enabledTab", "disabledTab", "smartTab" }) do
                local sel = Selected("cooldowns", sub)
                if type(sel) == "string" and idx and sel:match("rule(%d+)$") == tostring(idx) then found = true end
            end
            return (found and Selected() == "cooldowns") and true or false, ("top tab: %s; QA rule is rule %s; selected in the list: %s"):format(
                tostring(Selected()), tostring(idx), tostring(found))
        end },
    { text = "Change the rule's trigger: on its Trigger tab set the Spell ID to |cffffd100" .. SECOND .. "|r (or press |cffffd100Do it for me|r, which makes the same change). Then press Check.\n\n|cffffd100Expect:|r the Trigger tab shows the new spell.",
        setup = function()
            local ns, r = NS(), TestRule(); if not r then error("run the step before first") end
            r.spellID = SECOND
            ns.MarkDirty()
            local dbg = ns.Service and ns.Service("optionsDebug"); if dbg and dbg.Notify then dbg.Notify() end   -- redraw the open pane
        end,
        check = function()
            local r = TestRule(); if not r then return nil, "run the step before first" end
            return r.spellID == SECOND, ("the rule's trigger spell: %s"):format(tostring(r.spellID))
        end },
    { text = "Wait a second, click once on the settings window (not in a text box) and press |cffffd100Ctrl+Z|r (or press |cffffd100Do it for me|r, which sends the same undo). Then press Check.\n\n|cffffd100Expect:|r a chat or console line \"undid the last change to '" .. RULE_NAME .. "'\", and the Spell ID is " .. FIRST .. " again.",
        setup = function()
            local api = Api(); local RE = api and api.RuleEditor
            if not (RE and RE.UndoKey) then error("the rule editor is not loaded") end
            RE.UndoKey(false)
        end,
        check = function()
            local r = TestRule(); if not r then return false, "the QA rule is gone" end
            return r.spellID == FIRST, ("the rule's trigger spell: %s (%s before the change)"):format(tostring(r.spellID), FIRST)
        end },
    { text = "Close the settings window (its X, Esc or /xui), then press Check.\n\n|cffffd100Expect:|r it closes as usual, with no Lua error. The QA test rule is removed and XayaUI Rules is switched off for the /reload (Do it for me does both after the check).",
        setup = function()
            Cleanup()
            if not (C_AddOns and C_AddOns.DisableAddOn) then error("the game's AddOns calls are missing") end
            C_AddOns.DisableAddOn(RULES)
            switchedOff = true
        end,
        check = function()
            local api = Api()
            local closed = api and not api.IsOpen()
            local e = st.err and (Errors() - st.err) or 0
            local ok, s = pcall(C_AddOns.GetAddOnEnableState, RULES)
            -- (0.7.64, debug W3) the clean-up left no Rules row selected on the QA rule's old place (it would open your next rule)
            local slid = cleaned.shifted
            return (closed and e == 0 and not slid) and true or false, ("window closed: %s; new XayaUI errors: %d; XayaUI Rules enable state: %s (0 = off; Do it for me switches it off)%s"):format(
                tostring(closed), e, tostring(ok and s), slid and ("; the Rules list was left on row rule" .. tostring(slid) .. ", another rule in the QA rule's place") or "")
        end },
    { done = true, text = "Press |cffffd100Do it for me|r on the step before if you have not (it switches XayaUI Rules off), press |cffffd100Done|r here (so this record is kept), type |cffffd100/reload|r, and run \"Rule editor in its own folder: XayaUI Rules off (part 2 of 2) (H15)\"." },
} })

QA.Register("rule-editor-folder-off", { title = "Rule editor in its own folder: XayaUI Rules off (part 2 of 2) (H15)", area = "Platform", qa = "H15", order = 272.95, prefill = true, steps = {
    { text = "Run this after part 1 and its /reload. Press |cffffd100Do it for me|r: the settings window opens.\n\n|cffffd100Expect:|r no Rules tab; QoL, Bonus Features, Blizzard Reskin, Profiles and Settings are there; the feature rows in the left pane still have their tick boxes. The check reads that neither XayaUI Rules nor XayaUI Rules Options is loaded, also after the window opened.",
        setup = function()
            if switchedOff then error("not reloaded yet: type /reload, then come back") end
            st.err2 = Errors()
            local api = Api(); if not api then error("the settings window (XayaUI_Options) could not be loaded") end
            if not api.IsOpen() then api.Toggle() end
        end,
        check = function()
            local api = Api(); if not (api and st.err2) then return nil, "press Do it for me first" end
            local tree = api.LastTree and api.LastTree() or {}
            local rulesTab = tree.args and tree.args.cooldowns ~= nil
            local e = Errors() - st.err2
            return (api.IsOpen() and not Loaded(RULES) and not Loaded(EDITOR) and not rulesTab and e == 0) and true or false,
                ("window open: %s; XayaUI Rules loaded: %s; XayaUI Rules Options loaded: %s; Rules tab: %s; new XayaUI errors: %d"):format(
                    tostring(api.IsOpen()), tostring(Loaded(RULES)), tostring(Loaded(EDITOR)), rulesTab and "there" or "absent", e)
        end },
    { text = "Click the QoL tab and tick a feature's box off and on again in the left pane (it is put back as it was). Press Check.\n\n|cffffd100Expect:|r the tick box works as before. The check counts the tick boxes it finds on the rows (it cannot see your click).", noVerdict = true,
        check = function()
            local n = 0
            local function walk(f, d)
                if not f or d > 40 then return end
                if f.xuiSwitchBox and f.xuiSwitchBox:IsShown() then n = n + 1 end
                for _, c in ipairs(f.GetChildren and { f:GetChildren() } or {}) do walk(c, d + 1) end
            end
            walk(UIParent, 0)
            return nil, ("tick boxes shown on rows now: %d"):format(n)
        end },
    { text = "Press |cffffd100Do it for me|r: the window closes and XayaUI Rules is switched back on for your next /reload.\n\n|cffffd100Expect:|r the check reads that it is set to on and that XayaUI Rules Options was never loaded in this session.",
        setup = function()
            local api = Api(); if api and api.IsOpen() then api.Toggle() end
            if not (C_AddOns and C_AddOns.EnableAddOn) then error("the game's AddOns calls are missing") end
            C_AddOns.EnableAddOn(RULES)
            switchedOn = true
        end,
        check = function()
            if not switchedOn then return nil, "press Do it for me first" end
            local ok, s = pcall(C_AddOns.GetAddOnEnableState, RULES)
            return (ok and s ~= 0 and not Loaded(EDITOR)) and true or false,
                ("XayaUI Rules enable state: %s (0 = off); XayaUI Rules Options loaded: %s"):format(tostring(s), tostring(Loaded(EDITOR)))
        end },
    { done = true, text = "Press |cffffd100Done|r, then |cffffd100/reload|r to have XayaUI Rules back." },
} })
