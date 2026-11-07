-------------------------------------------------------------------------------
-- QAWalks-audit-options.lua: in-game QA walkthroughs for the function audit's settings-window fixes (D20-D26, D41-D47) and FA-11
-- (docs/process/FUNCTION-AUDIT-2026-11-07.md; docs/QA-CHECKLIST.md B265-B278). Standing rule V22 (Xaya 2026-11-07, her words): "make sure
-- every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation
-- options or data capturing". Each walkthrough sets prefill = true: where the addon can read the result its verdict is offered (Accept),
-- recorded only on a click (QAWalk.lua).
-- The settings window (XayaUI_Options) is reached only through its "optionsDebug" service; core functions through ns.*.
-- Test data: groups and rules made here are tagged (qaAuditOpt) and removed by each walkthrough's last step (to the Recycle Bin, which is
-- then cleared of the items this walkthrough made). Your own rules and groups are never touched. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end
local function NS() return rawget(_G, "XayaUI_NS") end
local function OD()
    local ns = NS()
    if ns and ns.LoadOptions and not (ns.Service and ns.Service("optionsDebug")) then pcall(ns.LoadOptions) end
    ns = NS()
    return ns and ns.Service and ns.Service("optionsDebug")
end
local function Need()
    local ns, od = NS(), OD()
    if not (ns and ns.NewRule) then error("XayaUI is not loaded") end
    if not od then error("the settings window addon (XayaUI_Options) could not be loaded") end
    return ns, od
end
local function cycle(v) if v == true then return nil elseif v == nil then return false end return true end   -- AceGUI's tri-state click
-- the group's own Enabled box (not a rule's Enabled inside the group), and a rule's embedded condition ("oc<k>" on its Conditions tab)
local function GroupEnabled(node, d)
    d = d or 0
    if type(node) ~= "table" or d > 14 then return nil end
    for k, c in pairs(node.args or {}) do
        if k == "enabled" and type(c) == "table" and type(c.desc) == "string" and c.desc:find("every rule in this group", 1, true) then return c end
        if type(c) == "table" and c.type == "group" and not tostring(k):match("^rule%d") then local hit = GroupEnabled(c, d + 1); if hit then return hit end end
    end
end
local function CondNode(od, node)
    local c = od.Find(node, "conditions")
    for k, v in pairs(c and c.args or {}) do if tostring(k):match("^oc%d+$") then return v end end
end

-- tagged test data: one group, a rule in it, a sound cue and a condition of that rule
local D = {}
local function MakeData()
    local ns = Need()
    local f = ns.NewFolder("QA audit options"); f.qaAuditOpt = true
    local r = ns.NewRule(); r.name = "QA audit options rule"; r.folder = f.id; r.enabled = true; r.uid = ns.NewUID(); r.qaAuditOpt = true
    r.useCooldown, r.spellID, r.cdState = true, 61304, "ready"
    ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
    local c = ns.NewCueRule(r, "sound"); c.qaAuditOpt = true
    local k = ns.NewRule(); k.name = "QA condition"; k.parentUid = r.uid; k.folder = f.id; k.uid = ns.NewUID(); k.qaAuditOpt = true
    k.sound.enabled, k.visual.enabled = false, false
    k.when = { list = { { ref = "cd", neg = false, op = "and", cmp = "==", num = 0 } } }; k.thenCues = { c.cueKey }
    ns.NormalizeRule(k); ns.rules[#ns.rules + 1] = k
    D.f, D.uid, D.cue, D.cond = f, r.uid, c.uid, k.uid
    D.binBefore = {}
    for _, it in ipairs(ns.RecycleItems()) do D.binBefore[it.id] = true end
    ns.MarkDirty()
end
local function Live(uid) local ns = NS(); for _, r in ipairs(ns and ns.rules or {}) do if r.uid == uid then return r end end end
local function Rule() return D.uid and Live(D.uid) end
local function Cleanup()
    local ns = NS(); if not ns then return end
    local list = {}
    for _, r in ipairs(ns.rules or {}) do if r.qaAuditOpt and not r.parentUid then list[#list + 1] = r end end
    for _, r in ipairs(list) do ns.RecycleRule(r) end
    for i = #(ns.folders or {}), 1, -1 do local f = ns.folders[i]; if f.qaAuditOpt then ns.RecycleFolder(f) end end
    -- the bin items this walkthrough made go too (only those: everything that was in the bin before stays)
    for _, it in ipairs(ns.RecycleItems()) do if not (D.binBefore and D.binBefore[it.id]) then ns.RecycleDeleteNow(it.id) end end
    ns.MarkDirty(); D = {}
    local od = OD(); if od and od.Notify then od.Notify() end
end
local function CleanCheck()
    local ns = NS(); if not ns then return false, "XayaUI is not loaded" end
    for _, r in ipairs(ns.rules or {}) do if r.qaAuditOpt then return false, "a QA test rule is still there" end end
    for _, f in ipairs(ns.folders or {}) do if f.qaAuditOpt then return false, "the QA test group is still there" end end
    return true, "the QA test rule, cue, condition and group are gone"
end
local LAST = { text = "Last step: press |cffffd100Do it for me|r to remove the QA test group, rule, cue and condition (and the Recycle Bin items this walkthrough made). Then Accept or Pass.",
    setup = Cleanup, check = CleanCheck }

-------------------------------------------------------------------------------
QA.Register("audit-opt-load", { title = "Load tab: Instance Type clicks; opening it is no change (D20, D23)", qa = "B265, B268", order = 310, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI makes a test group with one rule (QA audit options rule), sets its Load tab to \"Only inside an instance\" and clicks its first Instance Type box three times, the way the mouse does.\n\n|cffffd100Expect:|r click 1 selects it, click 2 makes it NOT, click 3 clears it.",
        setup = function()
            local ns, od = Need(); MakeData()
            local r = Rule(); r.load.instance = "yes"
            local g = od.Find(od.Find(od.RuleNode(r), "load"), "instanceTypes")
            local box = g and g.args and g.args.c1
            if not box then error("the Instance Type boxes were not found") end
            local id = ns.INSTANCE_TYPE_ORDER[1]
            D.trail = { tostring(box.get()) }
            for _ = 1, 3 do box.set(nil, cycle(box.get())); D.trail[#D.trail + 1] = tostring((Rule().load.instanceTypes or {})[id]) end
            r.load.instance = nil
        end,
        check = function()
            local t = D.trail; if not t then return false, "press Do it for me" end
            return t[1] == "false" and t[2] == "true" and t[3] == "not" and t[4] == "nil",
                "unset box read " .. t[1] .. "; after clicks 1 / 2 / 3 the stored value was " .. t[2] .. " / " .. t[3] .. " / " .. t[4] .. " (want true / not / nil)"
        end },
    { text = "Turn drafts on (Settings > Rule Creation > Prompt for saving and enable drafts), open the settings window, click |cffffd100QA audit options rule|r in the sidebar and open its |cffffd100Load|r tab. Change nothing. Then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r no unsaved-changes bar under the window.",
        check = function()
            local ns = NS(); local r = Rule(); if not (ns and r) then return false, "press Do it for me on step 1" end
            local od = OD(); if not od then return false, "the settings window (XayaUI Options) is not loaded" end
            if not od.DraftsEnabled() then return false, "drafts are off: turn them on for this step" end
            local dirty = od.DraftDirty(r)
            return not dirty, dirty and "the rule counts as changed (unsaved changes)" or "no unsaved changes after opening the Load tab"
        end },
    LAST,
} })

-------------------------------------------------------------------------------
QA.Register("audit-opt-lock", { title = "Edit lock holds everywhere (D26, D41, D44)", qa = "B271, B272", order = 311, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI makes the test rule (with a sound cue and a condition) and opens the settings window. Click the |cffffd100lock|r (pencil) icon on the rule's row in the sidebar. Then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the rule itself is locked, not only its cue.",
        setup = function() Need(); MakeData(); local ns = NS(); if ns.OptionsApi and ns.OptionsApi.EditRule then pcall(ns.OptionsApi.EditRule, Rule()) end end,
        check = function()
            local od, r = OD(), Rule(); if not (od and r) then return false, "press Do it for me" end
            local cue = Live(D.cue)
            return od.IsEditLocked(r) and true or false, ("rule locked: %s; cue locked: %s"):format(tostring(od.IsEditLocked(r)), tostring(cue and od.IsEditLocked(cue)))
        end },
    { text = "With the rule locked, open its |cffffd100Cues|r and |cffffd100Conditions|r tabs. Press |cffffd100Check again|r: XayaUI reads the header icons it would draw.\n\n|cffffd100Expect:|r the Move / Duplicate / red X icons are greyed out and do nothing; the grey name box takes no typing. Also press Ctrl+Z and Delete in the window: chat says the rule is edit-locked and it stays.",
        check = function()
            local od, r = OD(), Rule(); if not (od and r) then return false, "press Do it for me on step 1" end
            local node = od.RuleNode(r)
            local live, n = 0, 0
            local function scan(x, d)
                if type(x) ~= "table" or d > 16 then return end
                if type(x.arg) == "table" and x.arg.xuiActions then
                    local a = x.arg.xuiActions; if type(a) == "function" then a = a() end
                    for _, v in pairs(a or {}) do n = n + 1; if v then live = live + 1 end end
                end
                for _, c in pairs(x.args or {}) do scan(c, d + 1) end
            end
            scan(node, 0)
            if n == 0 then return false, "no header icons found (is the window's skin on?)" end
            return live == 0, ("%d of %d header icons active while locked (want 0)"):format(live, n)
        end },
    { text = "Click the lock icon again to unlock the rule, then press |cffffd100Check again|r.", check = function()
        local od, r = OD(), Rule(); if not (od and r) then return false, "press Do it for me on step 1" end
        return not od.IsEditLocked(r), od.IsEditLocked(r) and "still locked" or "unlocked" end },
    LAST,
} })

-------------------------------------------------------------------------------
QA.Register("audit-opt-group", { title = "Group Enabled keeps a switched-off condition; color Cancel (D42, D43)", qa = "B273, B274", order = 312, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI makes the test group, switches its condition off, then unticks and ticks the group's Enabled box (Config tab).\n\n|cffffd100Expect:|r the rule is on again; the condition stays off.",
        setup = function()
            local _, od = Need(); MakeData()
            Live(D.cond).enabled = false
            local en = GroupEnabled(od.FolderNode(D.f)); if not en then error("the group's Enabled box was not found") end
            en.set(nil, false); en.set(nil, true)
        end,
        check = function()
            local r, c = Rule(), Live(D.cond); if not (r and c) then return false, "press Do it for me" end
            return r.enabled == true and c.enabled == false, ("rule on: %s; condition on: %s (want true / false)"):format(tostring(r.enabled), tostring(c.enabled))
        end },
    { text = "Press |cffffd100Do it for me|r: XayaUI adds a second rule to the group, gives the two displays a red and a blue border, then plays a color-picker drag to green followed by Cancel on the group's Border color.\n\n|cffffd100Expect:|r red and blue again. You can also try it by hand: group page > Display > Every display: border and background.",
        setup = function()
            local ns, od = Need(); if not D.f then error("press Do it for me on step 1 first") end
            local b = ns.NewRule(); b.name = "QA audit options rule 2"; b.folder = D.f.id; b.enabled = true; b.qaAuditOpt = true; ns.NormalizeRule(b); ns.rules[#ns.rules + 1] = b
            local a = Rule(); a.visual.enabled, b.visual.enabled = true, true
            a.visual.border = { enabled = true, size = 1, color = { 1, 0, 0, 1 } }; b.visual.border = { enabled = true, size = 1, color = { 0, 0, 1, 1 } }
            D.b = b
            local col = od.Find(od.FolderNode(D.f), "bdColor"); if not col then error("the group's Border color was not found") end
            local r0, g0, b0, a0 = col.get()
            local P = rawget(_G, "ColorPickerFrame"); local was = P and P:IsShown()
            if P then P:Show() end; col.set(nil, 0, 1, 0, 1)
            if P then P:Hide() end; col.set(nil, r0, g0, b0, a0)
            if P and was then P:Show() end
        end,
        check = function()
            local a, b = Rule(), D.b; if not (a and b) then return false, "press Do it for me" end
            local ca, cb = a.visual.border.color, b.visual.border.color
            return ca[1] == 1 and ca[3] == 0 and cb[1] == 0 and cb[3] == 1, ("display 1: %s,%s,%s  display 2: %s,%s,%s (want red / blue)"):format(ca[1], ca[2], ca[3], cb[1], cb[2], cb[3])
        end },
    LAST,
} })

-------------------------------------------------------------------------------
QA.Register("audit-opt-bin", { title = "Red X to the Recycle Bin; Buff Remove clears Seconds left (FA-11, D25)", qa = "B278, B270", order = 313, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI makes the test rule and presses the red X on its sound cue.\n\n|cffffd100Expect:|r the cue is gone with no question and Rules > Recycle Bin lists \"Cue of the rule 'QA audit options rule'\".",
        setup = function()
            local _, od = Need(); MakeData()
            local hdr = od.Find(od.Find(od.RuleNode(Rule()), "oq1"), "hdr")
            if not (hdr and hdr.arg and hdr.arg.xuiActions) then error("the cue's header was not found") end
            hdr.arg.xuiActions().del()
        end,
        check = function()
            local ns = NS(); if not D.uid then return false, "press Do it for me" end
            local it; for _, x in ipairs(ns.RecycleItems()) do if x.kind == "cue" and x.owner == "QA audit options rule" then it = x end end
            D.item = it and it.id
            return Live(D.cue) == nil and it ~= nil, ("cue still in the rule: %s; in the Recycle Bin: %s"):format(tostring(Live(D.cue) ~= nil), tostring(it ~= nil))
        end },
    { text = "Open Rules > Recycle Bin and press |cffffd100Restore|r on that cue (or press |cffffd100Do it for me|r).\n\n|cffffd100Expect:|r the cue is back in the rule and its condition plays it again.",
        setup = function() local ns = NS(); if D.item then ns.RecycleRestore(D.item) end end,
        check = function()
            local c, k = Live(D.cue), Live(D.cond); if not (c and k) then return false, "the cue is not back yet" end
            local linked = type(k.thenCues) == "table" and k.thenCues[1] == c.cueKey
            return linked, linked and "the cue is back and the condition plays it" or "the cue is back but the condition does not play it"
        end },
    { text = "Press |cffffd100Do it for me|r: the test rule gets a Buff / Aura trigger \"present\" with Seconds left < 5, the red X removes it, then a Buff / Aura trigger is added again.\n\n|cffffd100Expect:|r Seconds left is back to Any time left.",
        setup = function()
            local _, od = Need(); local r = Rule(); if not r then error("press Do it for me on step 1 first") end
            r.useBuff, r.buffID, r.buffState, r.buffTimeOp, r.buffTimeSec = true, 774, "present", "<", 5
            od.Find(od.RuleNode(r), "buffRemove").func()
            od.Find(od.RuleNode(Rule()), "xAdd").set(nil, "_buff")
        end,
        check = function() local r = Rule(); if not r then return false, "press Do it for me" end
            return r.buffTimeOp == nil and r.buffTimeSec == nil, "Seconds left: " .. tostring(r.buffTimeOp) .. " " .. tostring(r.buffTimeSec) end },
    LAST,
} })

-------------------------------------------------------------------------------
QA.Register("audit-opt-inputs", { title = "Typos keep values; Restore asks; sound undo (D45, D22, D21, D46, D24)", qa = "B275, B267, B266, B276, B269", order = 314, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI makes the test rule, sets its condition to compare a number with 5, then types |cffffd1001o|r into the value box.\n\n|cffffd100Expect:|r the value stays 5.",
        setup = function()
            local _, od = Need(); MakeData()
            local k = Live(D.cond); k.when.list[1].ref = "n:cd"; k.when.list[1].num = 5
            local n1 = od.Find(CondNode(od, od.RuleNode(Rule())), "n1"); if not n1 then error("the value box was not found") end
            n1.set(nil, "1o")
        end,
        check = function() local k = Live(D.cond); if not k then return false, "press Do it for me" end
            return k.when.list[1].num == 5, "the value is " .. tostring(k.when.list[1].num) .. " (want 5)" end },
    { text = "Drafts off. Press |cffffd100Do it for me|r: XayaUI stores a draft of the test rule. Open Rules > Drafts and press |cffffd100Restore|r on it.\n\n|cffffd100Expect:|r a question first that says it replaces the rule right away and keeps it. Press No. The check reads the question text.",
        setup = function()
            local ns = Need(); local r = Rule(); if not r then error("press Do it for me on step 1 first") end
            CueRulesDB.drafts = CueRulesDB.drafts or {}
            local d = ns.Copy(r); d.qaAuditOpt = true
            table.insert(CueRulesDB.drafts, 1, { id = "qaAuditOpt", uid = r.uid, name = r.name, ts = time(), rules = { d } })
            local od = OD(); if od and od.Notify then od.Notify() end
        end,
        check = function()
            local od = OD(); if not od then return false, "the settings window addon is not loaded" end
            local page = od.DraftsPage(); local txt
            for _, g in pairs(page and page.args or {}) do
                if type(g) == "table" and g.args and g.args.restore and g.name == "QA audit options rule" then local c = g.args.restore.confirm; txt = type(c) == "function" and c() or c end
            end
            return type(txt) == "string" and txt:find("replaces", 1, true) ~= nil, "Restore asks: " .. tostring(txt)
        end },
    { text = "Remove the test draft: press |cffffd100Do it for me|r. Then (by hand) give any of your rules' Sound cues a different Sound and press Ctrl+Z; double-click a rule row, empty the name and press Enter; move a rule with Info > Group.\n\n|cffffd100Expect:|r Ctrl+Z brings the old sound back; the empty name keeps the old one; the display follows the new group at once. These are yours to judge.",
        noVerdict = true,
        setup = function() for i = #(CueRulesDB.drafts or {}), 1, -1 do if CueRulesDB.drafts[i].id == "qaAuditOpt" then table.remove(CueRulesDB.drafts, i) end end end,
        check = function()
            for _, d in ipairs(CueRulesDB.drafts or {}) do if d.id == "qaAuditOpt" then return false, "the test draft is still there" end end
            return true, "the test draft is gone"
        end },
    LAST,
} })
