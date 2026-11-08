-------------------------------------------------------------------------------
-- QAWalks-sidebar-delete.lua (listed in XayaUI_DevAssist 0.7.72's toc): in-game QA walkthrough for deleting from the Rules sidebar
-- (XayaUI_Rules_Options 0.6.82, XayaUI_Options 0.6.106; QA steps B320 to B323). Her words (REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md
-- row 20, 2026-11-08): "deleting auras shifts the rule sidebar up still and right clicking to delete does not get detected to remove the
-- menu from the top".
--   B320 right-click > Delete > Yes on the open rule: the list keeps its place (scroll position and the rows above it read back);
--   B321 three rules selected (purple), one of them deleted with right-click > Delete: the bar above the list counts the other two;
--   B322 the other selected rules deleted the same way: the bar is gone and the search box is back;
--   B323 Del on the open rule keeps the list's place too.
-- Test data: a group "QA sidebar delete" with 30 rules "QA delete 01" to "QA delete 30" (no display, no sound; tagged qaSidebarDelete),
-- placed in the middle of the list. The last step (Done) removes the group, its rules and the Recycle Bin items this walkthrough made.
-- Standing rule V22 (Xaya 2026-11-07): each check reads back what the sidebar drew (row positions, the scroll position, the bar's text,
-- the selection), offers its verdict (prefill = true; recorded only on her click) and puts what it read in the note. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local GROUP, COUNT = "QA sidebar delete", 30
local st = {}
local function NS() return rawget(_G, "XayaUI_NS") end
-- the rule editor (XayaUI Rules Options) is reached through ns.OptionsApi.RuleEditor (RuleSettings.lua; MultiHas and GoHomeKeepScroll
-- published 0.6.82), never through its own names
local function RE() local ns = NS(); return ns and ns.OptionsApi and ns.OptionsApi.RuleEditor or {} end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames.CueRules end
local function Status() local f = RE().RulesTreeStatus; return f and f() end
local function Tree()
    local s = Status()
    local function find(w)
        if type(w) ~= "table" then return nil end
        if w.type == "TreeGroup" and s and w.status == s then return w end
        for _, c in ipairs(w.children or {}) do local f = find(c); if f then return f end end
    end
    return find(Root())
end
local function TestGroup()
    local ns = NS()
    for _, f in ipairs(ns and ns.folders or {}) do if f.qaSidebarDelete == true then return f end end
end
local function Live(rule) local ns = NS(); for _, r in ipairs(ns and ns.rules or {}) do if r == rule then return true end end; return false end
local function TestRules()
    local ns, out = NS(), {}
    for _, r in ipairs(ns and ns.rules or {}) do if r.qaSidebarDelete == true then out[#out + 1] = r end end
    return out
end
-- the rows on screen, top to bottom: { obj = rule or group, top = screen y, name = text }
local function OnScreen()
    local ns, t, out = NS(), Tree(), {}
    for _, b in ipairs(t and t.buttons or {}) do
        if b:IsShown() then
            local last = tostring(b.uniquevalue or ""):match("([^\001]+)$") or ""
            local n = tonumber(last:match("^rule(%d+)$"))
            local obj = n and ns.rules[n]
            if not obj and ns.FolderById then obj = ns.FolderById(last) end
            out[#out + 1] = { obj = obj or last, top = b:GetTop(), name = (type(obj) == "table" and tostring(obj.name)) or last }
        end
    end
    return out
end
local function Snapshot()
    local s = Status()
    st.snap = { sv = s and s.scrollvalue, rows = OnScreen() }
end
local function BarText()
    local t = Tree(); local b = t and t.xuiSelBar
    if not (b and b:IsShown()) then return nil end
    return ("%s | %s | %s"):format(b.del:GetText() or "", b.mv:GetText() or "", b.clr:GetText() or "")
end

-- the test group in the middle of the list, open, scrolled so its rules fill the view, and one rule in the middle of the view opened
local function Prepare(pick)
    local ns = NS()
    if not (ns and ns.NewFolder and ns.LoadOptions and ns.LoadOptions()) then error("XayaUI or its settings window could not be loaded") end
    if not RE().GoHomeKeepScroll then error("XayaUI Rules Options is older than 0.6.82") end
    local f = TestGroup()
    if not f then f = ns.NewFolder(GROUP); f.qaSidebarDelete = true end
    local have = #TestRules()
    for i = have + 1, COUNT do
        local r = ns.NewRule(); r.name = ("QA delete %02d"):format(i); r.folder = f.id; r.enabled = true
        r.visual = r.visual or {}; r.visual.enabled = false; r.sound = r.sound or {}; r.sound.enabled = false
        ns.NormalizeRule(r); r.qaSidebarDelete = true; ns.rules[#ns.rules + 1] = r
    end
    if ns.MarkDirty then ns.MarkDirty() end
    local a = ACD()
    if not Root() then a:Open("CueRules") end
    a:SelectGroup("CueRules", "cooldowns", "enabledTab", "loaded")
    local okc, ctx = pcall(ns.ReadContext)
    local list, target = TestRules(), nil
    for _, r in ipairs(list) do if r.name == ("QA delete %02d"):format(pick) then target = r end end
    target = target or list[math.min(#list, 10)]   -- that one was deleted in an earlier step: the tenth that is left
    if target then a:SelectGroup("CueRules", RE().ScopePath(target, okc and ctx or nil)) end   -- opens the group on the way
    st.target = target
    if C_Timer then
        C_Timer.After(0.2, function()   -- after the window is drawn: the opened rule in the middle of the view, then the picture to compare with
            local t = Tree()
            local s = Status()
            for i, l in ipairs(t and t.lines or {}) do
                if s and l.uniquevalue == s.selected and t.scrollbar then t.scrollbar:SetValue(math.max(0, i - 8)); break end
            end
            Snapshot()
        end)
    end
end

-- B320 / B323: after the delete, the list kept its place
local function CheckKept(how)
    local s = Status()
    if not (Root() and s) then return nil, "the settings window is not open on Rules: press Do it for me" end
    local target, snap = st.target, st.snap
    if not (target and snap) then return nil, "press Do it for me first" end
    if Live(target) then Snapshot(); return nil, "'" .. tostring(target.name) .. "' is still there: " .. how .. ", then Check" end
    local first
    for i, r in ipairs(snap.rows) do if r.obj == target then first = i; break end end
    if not first then return nil, "the deleted rule was not on screen when the picture was taken: press Do it for me again" end
    local now = OnScreen()
    local function at(obj) for _, r in ipairs(now) do if r.obj == obj then return r end end end
    local moved = {}
    for i = 1, first - 1 do
        local a = at(snap.rows[i].obj)
        if not (a and math.abs(a.top - snap.rows[i].top) < 0.5) then moved[#moved + 1] = snap.rows[i].name end
    end
    local above, nextRow = snap.rows[first - 1], nil
    for i, r in ipairs(now) do if above and r.obj == above.obj then nextRow = now[i + 1] end end
    local filled = nextRow and math.abs(nextRow.top - snap.rows[first].top) < 0.5
    local ok = s.scrollvalue == snap.sv and #moved == 0 and first > 1 and filled and true or false
    return ok, ("Scroll position %s -> %s. Rows above it: %d, %s. The row after it (%s) %s."):format(tostring(snap.sv), tostring(s.scrollvalue),
        first - 1, #moved == 0 and "none moved" or ("moved: " .. table.concat(moved, ", ")),
        nextRow and nextRow.name or "none", filled and "took its place" or "is not where it was")
end

-- B321 / B322: the selection and the bar
local function CheckSelected()
    local E = RE()
    if not (Root() and E.MultiCount and E.MultiHas) then return nil, "the settings window is not open: press Do it for me in step 1" end
    local n = E.MultiCount()
    local mine = {}
    for _, r in ipairs(TestRules()) do if E.MultiHas(r) then mine[#mine + 1] = r end end
    if n < 2 then return nil, ("%d rule(s) selected: Ctrl+click three of the QA delete rules, then Check"):format(n) end
    st.sel, st.n = mine, n
    Snapshot()
    local want = ("Delete (%d) | Move (%d) | Deselect (%d)"):format(n, n, n)
    local bar = BarText()
    return bar == want, ("%d selected (%d of them QA delete rules). The bar reads: %s"):format(n, #mine, bar or "(no bar)")
end
local function CheckOneGone()
    local E = RE()
    if not st.sel then return nil, "Check step 2 first (with the rules selected)" end
    local gone, kept = {}, 0
    for _, r in ipairs(st.sel) do if Live(r) then kept = kept + 1 else gone[#gone + 1] = r end end
    if #gone == 0 then return nil, "none of the selected rules is deleted yet: right-click one of the purple rows > Delete > Yes, then Check" end
    local n, stale = E.MultiCount(), {}
    for _, r in ipairs(gone) do if E.MultiHas(r) then stale[#stale + 1] = tostring(r.name) end end
    local left = st.n - #gone
    local want = left > 0 and ("Delete (%d) | Move (%d) | Deselect (%d)"):format(left, left, left) or nil
    local bar = BarText()
    local ok = n == left and #stale == 0 and bar == want
    return ok, ("Deleted %d, selected now %d (expected %d)%s. The bar reads: %s"):format(#gone, n, left,
        #stale > 0 and (", still counted: " .. table.concat(stale, ", ")) or "", bar or "(no bar)")
end
local function CheckAllGone()
    local E = RE()
    if not st.sel then return nil, "Check step 2 first (with the rules selected)" end
    local live = 0
    for _, r in ipairs(st.sel) do if Live(r) then live = live + 1 end end
    if live > 0 then return nil, ("%d of the selected rules are still there: right-click each > Delete > Yes, then Check"):format(live) end
    local n, bar, t = E.MultiCount(), BarText(), Tree()
    local box = t and t.xuiSearchBox and t.xuiSearchBox:IsShown()
    return n == 0 and bar == nil and box and true or false, ("Selected now %d. The bar is %s; the search box is %s."):format(n,
        bar and ("still there: " .. bar) or "gone", box and "back" or "not shown")
end

local function Done()
    local ns = NS()
    if not ns then return end
    if RE().MultiClear then RE().MultiClear() end
    -- the walkthrough's rules and group go for good, with the Recycle Bin items it made (only its own, by their tag)
    local first
    for i = #(ns.rules or {}), 1, -1 do if ns.rules[i].qaSidebarDelete == true then table.remove(ns.rules, i); first = i end end
    if QA.LeaveMovedRuleRow then QA.LeaveMovedRuleRow(first) end   -- rows are keyed by list place: a row after them now names another rule
    for i = #(ns.folders or {}), 1, -1 do if ns.folders[i].qaSidebarDelete == true then table.remove(ns.folders, i) end end
    local bin = ns.RecycleDB and ns.RecycleDB()
    if bin and ns.RecycleDeleteNow then
        local ids = {}
        for _, it in ipairs(bin.items or {}) do
            local mine = false
            for _, r in ipairs(it.rules or {}) do if type(r) == "table" and r.qaSidebarDelete == true then mine = true end end
            for _, f in ipairs(it.folders or {}) do if type(f) == "table" and f.qaSidebarDelete == true then mine = true end end
            if mine and it.id then ids[#ids + 1] = it.id end
        end
        for _, id in ipairs(ids) do ns.RecycleDeleteNow(id) end
    end
    if ns.MarkDirty then ns.MarkDirty() end
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if reg and Root() then reg:NotifyChange("CueRules") end
    st.target, st.snap, st.sel, st.n = nil, nil, nil, nil
end
QA.SidebarDeleteTest = { State = st, Done = Done, Prepare = Prepare, TestRules = TestRules, TestGroup = TestGroup }   -- (tests)

QA.Register("sidebar-delete", { title = "Deleting from the Rules sidebar: the list keeps its place, the selection bar follows (B320-B323)",
    qa = "B320, B321, B322, B323", order = 540, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI adds a group |cffffd100QA sidebar delete|r with 30 rules (QA delete 01 to 30, no display, no sound), opens |cffffd100Rules > Loaded|r and opens |cffffd100QA delete 10|r in the middle of the list's view.\n\nNow |cffffd100right-click QA delete 10|r in the list > |cffffd100Delete|r > |cffffd100Yes|r, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the list does not move: the rows above it stay where they were, QA delete 11 moves up into its place. The check compares the rows' screen positions and the scroll position with a picture taken before the delete.",
        setup = function() Prepare(10) end, check = function() return CheckKept("right-click it > Delete > Yes") end },
    { text = "|cffffd100Ctrl+click three|r of the QA delete rules (they turn purple), then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the bar above the list reads |cffffd100Delete (3)|r, |cffffd100Move (3)|r, |cffffd100Deselect (3)|r.",
        check = CheckSelected },
    { text = "|cffffd100Right-click one of the purple rows|r > |cffffd100Delete|r > |cffffd100Yes|r, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r that rule is gone and the bar now reads |cffffd100Delete (2)|r, |cffffd100Move (2)|r, |cffffd100Deselect (2)|r; the other two are still purple; the list does not move.",
        check = CheckOneGone },
    { text = "Right-click |cffffd100each of the other purple rows|r > |cffffd100Delete|r > |cffffd100Yes|r, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r after the last one the bar is gone from the top of the list and the search box is back in its place.",
        check = CheckAllGone },
    { text = "Press |cffffd100Do it for me|r: XayaUI opens |cffffd100QA delete 20|r (or, if you deleted that one, the tenth QA rule left) in the middle of the list's view.\n\nNow press the |cffffd100Delete|r key > |cffffd100Yes|r, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the list does not move: the rows above it stay where they were, the next rule moves up into its place.",
        setup = function() Prepare(20) end, check = function() return CheckKept("press the Delete key > Yes") end },
    { text = "Press |cffffd100Do it for me|r to remove the QA sidebar delete group, its rules and the Recycle Bin items this walkthrough made, then |cffffd100Done|r.", done = true, setup = Done },
} })
