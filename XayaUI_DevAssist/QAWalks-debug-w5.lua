-------------------------------------------------------------------------------
-- QAWalks-debug-w5.lua (XayaUI_DevAssist 0.7.65): in-game QA walkthrough for debug batches W5 and W6 (QA steps B291 and B292):
--   #485 (W5) the Recycle Bin: a cue removed with the red X is in exactly one place (the bin), and Restore puts it back in its rule and in
--        the condition that played it, which plays it again (B291). tests/recycle_bin_child_reload_run.py found no data defect (regression
--        guards, also across /reloads and with the P5 store); her "in both" result is explained by the walkthrough check before Dev Assist
--        0.7.53 (it looked the cue up by a uid a cue does not have). One defect was found and fixed (Rules 0.6.80): the bin named a cue
--        after it had left the rule, so the first of several Sound cues was listed as "Sound 2". This step reads the data in the game.
--   #479 (W6) a group's Border tick box: ticking it on a dynamic group (Centered row, spacing 4) raises no Lua error (B292). The error
--        did not reproduce in the stand-in (tests/group_border_tick_run.py); the step counts XayaUI's error record before and after and,
--        if an error appears, copies its text into the note (the text open question D3 asks for).
-- Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on her click);
-- what it reads (the rule's cues, the bin's items, the condition's THEN list, error counts) goes into the step's note.
-- Test data: one group per part and the rules in them, tagged (qaDebugW5) and found by the tag in every step (so a /reload or a delete
-- by hand in between does not lose them). A run starts by removing what an earlier run left; the last step removes everything tagged
-- and the Recycle Bin items made from it. Your own rules, groups and bin items are never touched. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local APP = "CueRules"
local RULE_NAME, GROUP_NAME, BORDER_GROUP = "QA W5 bin rule", "QA W5 bin", "QA W5 border"
local function NS() return rawget(_G, "XayaUI_NS") end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function OD()
    local ns = NS()
    if ns and ns.LoadOptions and not (ns.Service and ns.Service("optionsDebug")) then pcall(ns.LoadOptions) end
    ns = NS()
    return ns and ns.Service and ns.Service("optionsDebug")
end
local function Need()
    local ns, od = NS(), OD()
    if not (ns and ns.NewRule and ns.RecycleChild and ns.RecycleRestore) then error("XayaUI Rules is not loaded (switch it on and /reload)") end
    if not od then error("the settings window addon (XayaUI_Options) could not be loaded") end
    return ns, od
end
local function Tagged(x) return type(x) == "table" and x.qaDebugW5 == true end
local function TestFolder(name) local ns = NS(); for _, f in ipairs(ns and ns.folders or {}) do if Tagged(f) and f.name == name then return f end end end
local function Rule() local ns = NS(); for _, r in ipairs(ns and ns.rules or {}) do if Tagged(r) and not r.parentUid and r.name == RULE_NAME then return r end end end
local function Child(cue)
    local ns, r = NS(), Rule()
    if not r then return nil end
    for _, x in ipairs(ns.rules or {}) do if Tagged(x) and x.parentUid == r.uid and (x.isCue and true or false) == cue then return x end end
end
local function BinItemTagged(it) for _, r in ipairs(it.rules or {}) do if Tagged(r) then return true end end; for _, f in ipairs(it.folders or {}) do if Tagged(f) then return true end end; return false end
local function BinItems() local ns = NS(); local b = ns and ns.RecycleDB and ns.RecycleDB(); return b and b.items or {} end
-- the test cue's rows: how many in the rules, and the bin items that hold one
local function CueCounts()
    local ns = NS()
    local live, binN, binNames = 0, 0, {}
    for _, x in ipairs(ns and ns.rules or {}) do if Tagged(x) and x.isCue then live = live + 1 end end
    for _, it in ipairs(BinItems()) do
        if it.kind == "cue" and BinItemTagged(it) then binN = binN + 1; binNames[#binNames + 1] = "\"" .. tostring(it.name) .. "\"" end
    end
    return live, binN, binNames
end
local function CueList(r)
    local ns, t = NS(), {}
    for _, x in ipairs(ns and ns.rules or {}) do if r and x.parentUid == r.uid and x.isCue then t[#t + 1] = tostring(ns.CueLabel and ns.CueLabel(x) or x.cueKey) .. " (" .. tostring(x.cueKey) .. ")" end end
    return #t > 0 and table.concat(t, ", ") or "none"
end
local function ThenList(k) return (k and type(k.thenCues) == "table" and #k.thenCues > 0) and table.concat(k.thenCues, ", ") or "empty" end

local function Cleanup()
    local ns = NS(); if not ns then return end
    local first
    for i = #(ns.rules or {}), 1, -1 do
        local r = ns.rules[i]
        if Tagged(r) then
            if ns.SetPreview then pcall(ns.SetPreview, { r }, "visual", false) end
            if ns.EndRule then pcall(ns.EndRule, r) end
            if ns.DropVisual then pcall(ns.DropVisual, r) end
            table.remove(ns.rules, i); first = i
        end
    end
    -- removing rules moves every later rule up one place: a sidebar row selected at or after the first removed one would open ANOTHER
    -- rule's editor (QAWalks-bars.lua QA.LeaveMovedRuleRow goes back to the list, as Delete this rule does)
    if QA.LeaveMovedRuleRow then QA.LeaveMovedRuleRow(first) end
    for i = #(ns.folders or {}), 1, -1 do
        local f = ns.folders[i]
        if Tagged(f) then f.cBorder, f.cBg = nil, nil; table.remove(ns.folders, i) end
    end
    local ids = {}
    for _, it in ipairs(BinItems()) do if BinItemTagged(it) then ids[#ids + 1] = it.id end end
    for _, id in ipairs(ids) do ns.RecycleDeleteNow(id) end
    if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end
    if ns.UpdateGroupBoxes then pcall(ns.UpdateGroupBoxes) end
    if ns.MarkDirty then ns.MarkDirty() end
    local od = OD(); if od and od.Notify then od.Notify() end
end
local function CleanCheck()
    local ns = NS(); if not ns then return false, "XayaUI is not loaded" end
    for _, r in ipairs(ns.rules or {}) do if Tagged(r) then return false, "a QA test rule is still there" end end
    for _, f in ipairs(ns.folders or {}) do if Tagged(f) then return false, "a QA test group is still there" end end
    for _, it in ipairs(BinItems()) do if BinItemTagged(it) then return false, "a Recycle Bin item of the test data is still there" end end
    return true, "the QA test groups, rules, cue, condition and their Recycle Bin items are gone"
end

-------------------------------------------------------------------------------
-- B291 (#485): the red X on a cue, then Restore
-------------------------------------------------------------------------------
local function MakeBinData()
    local ns, od = Need()
    Cleanup()   -- (what an earlier run left)
    local f = ns.NewFolder(GROUP_NAME); f.qaDebugW5 = true
    local r = ns.NewRule(); r.name = RULE_NAME; r.folder = f.id; r.enabled = true; r.uid = ns.NewUID(); r.qaDebugW5 = true
    -- one trigger that is true whenever you play: Player State "alive" (Triggers.lua; it reads UnitIsDeadOrGhost, 12.1.5 docs
    -- docs/reference/api/globals.md:633 "UnitIsDeadOrGhost(unit: UnitToken) -> result: bool · SecretArguments=AllowedWhenUntainted": no
    -- secret result listed; an unreadable answer makes the trigger unknown and the step's note says "plays it now: no")
    r.extra = { list = { { type = "playerState", what = "alive", state = "yes" } } }
    ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
    local c = ns.NewCueRule(r, "sound"); c.qaDebugW5 = true
    if c.sound then c.sound.enabled = false end   -- (silent: the step reads whether it would play, it does not make you listen)
    local k = ns.NewRule(); k.name = "QA W5 condition"; k.parentUid = r.uid; k.folder = f.id; k.qaDebugW5 = true   -- (no uid, as the editor makes it)
    k.sound.enabled, k.visual.enabled = false, false
    k.when = { list = { { ref = "x1", neg = false, op = "and", cmp = "==", num = 0 } } }; k.thenCues = { c.cueKey }
    ns.NormalizeRule(k); ns.rules[#ns.rules + 1] = k
    ns.MarkDirty()
    return ns, od, r
end
local function SetupDelete()
    local _, od, r = MakeBinData()
    local hdr = od.Find(od.Find(od.RuleNode(r), "oq1"), "hdr")
    if not (hdr and hdr.arg and hdr.arg.xuiActions) then error("the cue's header was not found") end
    hdr.arg.xuiActions().del()   -- the red X (XayaUI_Rules_Options/OutcomesEditor.lua RemoveOutcome)
end
local function CheckDelete()
    local r = Rule(); if not r then return nil, "no test rule (" .. RULE_NAME .. "): press Do it for me" end
    local live, binN, names = CueCounts()
    local k = Child(false)
    return (live == 0 and binN == 1 and (k and k.thenCues == nil)) and true or false,
        ("the rule's cues: %s; Recycle Bin items of the test rule's cue: %d %s; the condition's THEN list: %s"):format(
            CueList(r), binN, table.concat(names, ", "), ThenList(k))
end
local function SetupRestore()
    local ns = Need()
    if not Rule() then error("no test rule: press Do it for me on step 1 first") end
    local live = CueCounts()
    if live == 0 then
        for _, it in ipairs(BinItems()) do if it.kind == "cue" and BinItemTagged(it) then ns.RecycleRestore(it.id); break end end
    end
    ns.MarkDirty()
end
local function CheckRestore()
    local ns = NS()
    local r = Rule(); if not r then return nil, "no test rule (" .. RULE_NAME .. "): run step 1 again" end
    local live, binN = CueCounts()
    local c, k = Child(true), Child(false)
    if live == 0 then return nil, "the cue is not back yet: Restore it in Profiles > Recycle Bin (or press Do it for me)" end
    local linked = false
    for _, key in ipairs(k and type(k.thenCues) == "table" and k.thenCues or {}) do if c and key == c.cueKey then linked = true end end
    -- whether it plays: the engine's own decision for the cue (ns.EvaluateCue, what Engine.lua asks every step)
    local okE, plays = false, nil
    if c and ns.EvaluateCue and ns.ReadContext then
        local okC, ctx = pcall(ns.ReadContext)
        if okC then okE, plays = pcall(ns.EvaluateCue, c, ctx) end
    end
    local note = ns.CueFiresNote and c and ns.CueFiresNote(c) or "?"
    return (live == 1 and binN == 0 and linked and okE and plays == true) and true or false,
        ("the rule's cues: %s; Recycle Bin items of it: %d; the condition's THEN list: %s (cue key %s); the engine plays it now: %s; the Cues tab says: %s"):format(
            CueList(r), binN, ThenList(k), tostring(c and c.cueKey), okE and (plays and "yes" or "no") or "could not tell", tostring(note))
end

-------------------------------------------------------------------------------
-- B292 (#479): the Border tick box on a dynamic group
-------------------------------------------------------------------------------
local st = {}
local function ErrCount() local ns = NS(); local n = ns and ns.ErrorCount and ns.ErrorCount(); return tonumber(n) or 0 end
local function OpenGroupPage(f, member)
    local ns = NS()
    if not (ns.OptionsApi and ns.OptionsApi.IsOpen and ns.OptionsApi.IsOpen()) then
        if ns.OptionsApi and ns.OptionsApi.Toggle then pcall(ns.OptionsApi.Toggle) end
    end
    local a, RE = ACD(), ns.OptionsApi and ns.OptionsApi.RuleEditor
    if a and RE and RE.ScopePath and member then   -- the group's row in the sidebar's list: the member rule's path without the rule
        local okc, ctx = pcall(ns.ReadContext)
        local p = { RE.ScopePath(member, okc and ctx or nil) }; p[#p] = nil
        pcall(a.SelectGroup, a, APP, unpack(p))
    elseif ns.OptionsApi and ns.OptionsApi.EditFolder then pcall(ns.OptionsApi.EditFolder, f) end
end
local function SetupBorder()
    local ns, od = Need()
    local old = TestFolder(BORDER_GROUP)
    if old then   -- an earlier run's border group: only it goes (the bin part keeps its own data)
        for i = #ns.rules, 1, -1 do local r = ns.rules[i]; if Tagged(r) and r.folder == old.id then pcall(ns.SetPreview, { r }, "visual", false); pcall(ns.DropVisual, r); table.remove(ns.rules, i); if QA.LeaveMovedRuleRow then QA.LeaveMovedRuleRow(i) end end end
        for i = #ns.folders, 1, -1 do if ns.folders[i] == old then table.remove(ns.folders, i) end end
    end
    local f = ns.NewFolder(BORDER_GROUP); f.qaDebugW5 = true
    f.cType, f.cGrowth, f.cSpacing = "dynamic", "HCENTER", 4   -- her group: Centered row, spacing 4
    local list = {}
    for i, id in ipairs({ 774, 33763, 8936 }) do
        local r = ns.NewRule(); r.name = "QA W5 border icon " .. i; r.folder = f.id; r.enabled = true; r.qaDebugW5 = true
        r.visual.enabled = true; r.visual.kind = "spellicon"; r.spellID = id
        ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; list[#list + 1] = r
    end
    if ns.SetPreview then ns.SetPreview(list, "visual", true) end   -- (shown as a preview, so the group has items to put a border round)
    if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end
    ns.MarkDirty()
    OpenGroupPage(f, list[1])
    st.errBefore = ErrCount()
    local border = od.Find(od.Find(od.FolderNode(f), "container") or od.FolderNode(f), "border")
    if not (border and border.set) then error("the group's Border tick box was not found") end
    border.set(nil, true)   -- the Group tab's Border tick box (XayaUI_Rules_Options/RulesTree.lua; its apply redraws the window)
end
local function CheckBorder()
    local ns = NS()
    local f = TestFolder(BORDER_GROUP); if not f then return nil, "no test group (" .. BORDER_GROUP .. "): press Do it for me" end
    if not st.errBefore then return nil, "press Do it for me (it counts the errors before ticking)" end
    local now = ErrCount()
    local okU, errU = pcall(ns.UpdateGroupBox, f)   -- (its usual callers hide an error: read it directly)
    local b = ns.GroupBox and ns.GroupBox(f)
    local newText = {}
    if now > st.errBefore and ns.ErrorEntries then
        for i, e in ipairs(ns.ErrorEntries()) do if i <= 3 then newText[#newText + 1] = tostring(e.code) .. ": " .. tostring(e.msg):sub(1, 160) end end
    end
    return (now == st.errBefore and okU and f.cBorder == true and b and b:IsShown()) and true or false,
        ("XayaUI's error record: %d before ticking, %d now%s; Border ticked: %s; the box drawn: %s; the box's own update: %s"):format(
            st.errBefore, now, #newText > 0 and (" (newest: " .. table.concat(newText, " | ") .. ")") or "", tostring(f.cBorder == true),
            tostring(b and b:IsShown() or false), okU and "no error" or ("ERROR " .. tostring(errU)))
end

QA.Register("debug-w5", { title = "Recycle Bin: a deleted cue is only in the bin and plays again after Restore; group Border tick box (B291-B292, debug W5 / W6)",
    qa = "B291, B292", order = 517, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI removes what an earlier run of this walkthrough left, makes the group |cffffd100" .. GROUP_NAME .. "|r with the rule |cffffd100" .. RULE_NAME .. "|r (a silent sound cue and a condition that plays it) and presses the red X on the cue.\n\n|cffffd100Expect:|r the cue is gone from the rule with no question, |cffffd100Profiles > Recycle Bin|r lists \"Cue of the rule '" .. RULE_NAME .. "'\" once, and the condition no longer lists it. The check reads the rule's cues, the bin and the condition's THEN list.",
        setup = SetupDelete, check = CheckDelete },
    { text = "Open |cffffd100Profiles > Recycle Bin|r and press |cffffd100Restore|r on that cue (or press |cffffd100Do it for me|r: it restores it if you have not). A /reload before this step is fine.\n\n|cffffd100Expect:|r the cue is back in the rule, gone from the bin, back in the condition's THEN list, and the condition plays it (its trigger is \"you are alive\"). The check reads the rule's cues, the bin, the condition's THEN list and the engine's own decision for the cue.",
        setup = SetupRestore, check = CheckRestore },
    { text = "Press |cffffd100Do it for me|r: XayaUI makes the dynamic group |cffffd100" .. BORDER_GROUP .. "|r (Centered row, spacing 4, three icons shown as a preview), opens its page in the settings window and ticks |cffffd100Border|r on its Group tab. Then untick and tick Border yourself once and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r a thin grey border round the three icons and no Lua error. The check counts XayaUI's error record before and after (and copies any new error's text into the note). The border colour (grey) is not part of this step: it waits for your answer on A15.",
        setup = SetupBorder, check = CheckBorder },
    { done = true, setup = Cleanup, check = CleanCheck,
      text = "Last step: press |cffffd100Do it for me|r to remove the QA test groups, rules, cue and condition (and the Recycle Bin items made from them). Then press |cffffd100Done|r." },
} })
QA.DebugW5Test = { Rule = Rule, Cue = function() return Child(true) end, Cond = function() return Child(false) end, Folder = TestFolder, Cleanup = Cleanup }   -- (tests)
