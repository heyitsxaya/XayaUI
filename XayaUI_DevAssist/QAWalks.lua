-------------------------------------------------------------------------------
-- QAWalks.lua (XayaUI_DevAssist 0.7.4): the walkthroughs of session 014bN6tStyDJVemzE9tX7F38's open QA steps (group page B171-B175,
-- Blizzard UI Reskin switches E2e, Shopping List E2a / E2g / E2h). Older QA items follow over the next days (Xaya 2026-11-06: "Both,
-- but start with this session and push older items into a map over the next several days"). Each step says what to do and what to
-- expect; "Do it for me" does the clicking where it can; the check is the addon's own look, the person decides (QAWalk.lua).
-- Test data: the group walkthroughs make one group, "QA test group", with two sample rules, and their last step deletes it again
-- (it goes to the Recycle Bin like any deleted group). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = XayaUI_DevQA
if not QA then return end
local function NS() return rawget(_G, "XayaUI_NS") end
local TEST = "QA test group"

local function TestGroup()
    local ns = NS()
    for _, f in ipairs(ns and ns.folders or {}) do if f.name == TEST then return f end end
end
local function MakeTestGroup(withIcons)
    local ns = NS()
    if not (ns and ns.NewFolder) then error("XayaUI is not loaded") end
    local f = TestGroup() or ns.NewFolder(TEST)
    if withIcons then
        local have = 0
        for _, r in ipairs(ns.rules or {}) do if r.folder == f.id then have = have + 1 end end
        for i = have + 1, 2 do
            local r = ns.NewRule(); r.name = "QA sample " .. i; r.folder = f.id; r.enabled = true
            r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = (i == 1) and -60 or 60, 0
            ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
        end
        local list = {}
        for _, r in ipairs(ns.rules) do if r.folder == f.id then list[#list + 1] = r end end
        if ns.SetPreview then ns.SetPreview(list, "visual", true) end
    end
    if ns.MarkDirty then ns.MarkDirty() end
    if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end
    return f
end
local function OpenGroup(f)
    local ns = NS()
    if ns.LoadOptions and ns.LoadOptions() and ns.OptionsApi and ns.OptionsApi.EditFolder then ns.OptionsApi.EditFolder(f) end
end
local function RemoveTestGroup()
    local ns = NS()
    local f = TestGroup()
    if not f then return end
    local list = {}
    for _, r in ipairs(ns.rules or {}) do if r.folder == f.id then list[#list + 1] = r end end
    if ns.SetPreview then ns.SetPreview(list, "visual", false) end
    if ns.LoadOptions then ns.LoadOptions() end
    if ns.OptionsApi and ns.OptionsApi.DeleteFolderAll then ns.OptionsApi.DeleteFolderAll(f.id) end
    if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end
end
local function Cleanup()
    return { text = "Last step: press |cffffd100Do it for me|r to delete the QA test group and its two sample rules (they go to the Recycle Bin). Then Pass.",
        setup = RemoveTestGroup, check = function() return TestGroup() == nil, TestGroup() and "the QA test group is still there" or "the QA test group is gone" end }
end

-- B171 / B172: the group page --------------------------------------------------------------------------------------------------
QA.Register("group-page", { title = "Group page: tabs, Config, Group tab", qa = "B171-B172", order = 110, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI makes a group called \"QA test group\" and opens its page in the settings window.\n\nLook at the row of tabs above the page.\n\n|cffffd100Expect:|r four tabs, in this order: Group, Display, Load, Config. Group is the picked one.",
        setup = function() OpenGroup(MakeTestGroup(false)) end,
        check = function() local f = TestGroup(); return f ~= nil, f and "the QA test group exists" or "no QA test group yet: press Do it for me" end },
    { text = "Click the |cffffd100Config|r tab.\n\n|cffffd100Expect:|r the group's name; an |cffffd100Enabled|r tick box; Group type (static / dynamic); |cffffd100Sound Channel Override|r; + New rule; + Nested group; Delete; and a line \"Made by: <your character> (made here, <today's date>)\".",
        check = function() local f = TestGroup(); local o = f and f.origin; return (o and o.how == "made") and true or false, o and ("recorded: " .. tostring(o.by or "?") .. ", " .. tostring(o.how)) or "no record on the group" end },
    { text = "Click the |cffffd100Group|r tab.\n\n|cffffd100Expect:|r the group's opacity, scale and layer (strata) are here, and the size of every display. Then click |cffffd100Display|r: there is no \"Whole group\" box at the top any more." },
    { text = "Back on the |cffffd100Group|r tab, find Group position.\n\n|cffffd100Expect:|r Relative to, This group's anchor point and Point on the frame it is relative to each sit on one row: the label on the left, the dropdown on the right." },
    Cleanup(),
} })

-- B174 / B175: the group's box and nested groups -------------------------------------------------------------------------------
QA.Register("group-box", { title = "Group size, border and background", qa = "B174", order = 111, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI makes \"QA test group\" with two sample icons (shown as previews) and turns on its |cffffd100Border|r and |cffffd100Background|r with Size = Auto.\n\n|cffffd100Expect:|r two icons side by side in the middle of the screen, with a dark box and a thin border just around them.",
        setup = function() local f = MakeTestGroup(true); local ns = NS(); f.cBorder, f.cBg = true, true; if ns.SetGroupSizeMode then ns.SetGroupSizeMode(f, "auto") end; pcall(ns.RefreshAllVisuals); OpenGroup(f) end,
        check = function() local ns = NS(); local b = ns.GroupBox and ns.GroupBox(TestGroup()); return (b and b:IsShown()) and true or false, (b and b:IsShown()) and "the box is showing" or "no box is showing" end },
    { text = "Press |cffffd100Do it for me|r: one of the two icons stops showing.\n\n|cffffd100Expect:|r within a moment the box shrinks to the one icon still showing.",
        setup = function() local ns = NS(); local f = TestGroup(); for _, r in ipairs(ns.rules) do if r.folder == f.id and r.name == "QA sample 2" then ns.SetPreview({ r }, "visual", false) end end; pcall(ns.RefreshAllVisuals) end },
    { text = "Press |cffffd100Do it for me|r: Size becomes |cffffd100Set|r, 220 wide and 90 high, with |cffffd100Clip|r on.\n\n|cffffd100Expect:|r the box is now a fixed 220 x 90 rectangle; anything outside it is cut off. On the Group tab, Width, Height and Clip are now shown.",
        setup = function() local ns = NS(); local f = TestGroup(); ns.SetGroupSizeMode(f, "set"); f.cW, f.cH, f.cClip = 220, 90, true; pcall(ns.RefreshAllVisuals); OpenGroup(f) end,
        check = function() local ns = NS(); local f = TestGroup(); return ns.GroupSizeMode(f) == "set" and f.cW == 220, "size mode: " .. tostring(ns.GroupSizeMode(f)) end },
    Cleanup(),
} })
QA.Register("group-nested", { title = "Nested group: anchored to the screen", qa = "B175", order = 112, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI makes \"QA test group\" with a nested group inside, and opens the nested group's page.\n\nOn its Group tab, under Group position.\n\n|cffffd100Expect:|r a row \"Anchored to: The parent group\". (A top-level group does not show it.)",
        setup = function() local ns = NS(); local f = MakeTestGroup(false); local inner; for _, x in ipairs(ns.folders) do if x.parent == f.id then inner = x end end; inner = inner or ns.NewFolder("QA nested", f.id); OpenGroup(inner) end },
    { text = "Pick |cffffd100The screen|r in that row.\n\n|cffffd100Expect:|r nothing jumps; from now on the nested group is measured from the screen centre and stays put when the parent group is moved. Change its X offset a little: it moves on the screen as you change it." },
    Cleanup(),
} })

-- B173: dragging rule rows in the sidebar -----------------------------------------------------------------------------------------
QA.Register("sidebar-drag", { title = "Drag a rule row in the sidebar", qa = "B173", order = 113, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI makes \"QA test group\" with two sample rules and opens the settings window.\n\nIn the left pane, find QA test group and its two rules (QA sample 1, QA sample 2).",
        setup = function() OpenGroup(MakeTestGroup(true)) end },
    { text = "Press on |cffffd100QA sample 2|r, hold the mouse button, and move the mouse up a little over QA sample 1.\n\n|cffffd100Expect:|r a dark label with the rule's name follows the mouse and says \"above QA sample 1\", with a gold line on that row.\n\nIf nothing at all happens, press Fail and write \"nothing\" in the note." },
    { text = "Let go of the mouse button over the top half of QA sample 1.\n\n|cffffd100Expect:|r QA sample 2 is now above QA sample 1 in the list.",
        check = function() local ns = NS(); local f = TestGroup(); local order = {}; for _, r in ipairs(ns.rules or {}) do if f and r.folder == f.id then order[#order + 1] = r.name end end; return order[1] == "QA sample 2", "order: " .. table.concat(order, ", ") end },
    { text = "Press on a rule row and let go without moving.\n\n|cffffd100Expect:|r it just opens that rule, as before (no drag)." },
    Cleanup(),
} })

-- E2e: the Blizzard UI Reskin tab's switches -------------------------------------------------------------------------------------
QA.Register("reskin-switches", { title = "Blizzard UI Reskin: All reskins and each reskin's tick box", qa = "E2e", order = 120, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on the Blizzard UI Reskin tab.\n\n|cffffd100Expect:|r a tick box on the tab button itself, left of its name (All reskins, ticked), not covering the name; in the left pane each of Character Pane, Chat Panel, Esc Menu and Shopping List has its own tick box.",
        setup = function() local ns = NS(); if ns.OpenSettingsPage then ns.OpenSettingsPage("reskin", "charreskin") end end,
        check = function() local ns = NS(); return ns.ReskinTabOn and ns.ReskinTabOn() == true, "All reskins is " .. ((ns.ReskinTabOn and ns.ReskinTabOn()) and "on" or "off") end },
    { text = "Untick |cffffd100All reskins|r on the tab (or press Do it for me).\n\n|cffffd100Expect:|r at once Blizzard's own chat comes back, the Esc menu (press Esc) and the character window (C) look like Blizzard's; the four tick boxes in the left pane stay ticked but greyed.",
        setup = function() local ns = NS(); if ns.SetReskinTab then ns.SetReskinTab(false) end end,
        check = function() local ns = NS(); return ns.ReskinTabOn and ns.ReskinTabOn() == false, "All reskins is " .. ((ns.ReskinTabOn and ns.ReskinTabOn()) and "on" or "off") end },
    { text = "Tick |cffffd100All reskins|r again (or press Do it for me).\n\n|cffffd100Expect:|r the reskins whose own boxes are ticked come back without a /reload.",
        setup = function() local ns = NS(); if ns.SetReskinTab then ns.SetReskinTab(true) end end,
        check = function() local ns = NS(); return ns.ReskinTabOn and ns.ReskinTabOn() == true, "All reskins is " .. ((ns.ReskinTabOn and ns.ReskinTabOn()) and "on" or "off") end },
} })

-- E2a / E2g / E2h: the Shopping List ---------------------------------------------------------------------------------------------
local function Shop() local ns = NS(); return ns and ns.Service and ns.Service("shoppingList") end   -- (QoL provides it; nil while QoL is off)
QA.Register("shopping-list", { title = "Shopping List: panel, stop-tracking question, diamond", qa = "E2a, E2g, E2h", order = 121, steps = {
    { text = "Press |cffffd100Do it for me|r: the Shopping List is switched on and its panel opens.\n\n|cffffd100Expect:|r a movable panel \"Shopping List\" with Missing on your gear, To buy, and your tracked recipes.",
        setup = function() local S = Shop(); if not S then error("XayaUI QoL is off") end; local c = S.Cfg(); c.enabled, c.panel = true, true; S.Apply() end,
        check = function() local p = rawget(_G, "XayaUIShoppingList"); return (p and p:IsShown()) and true or false, (p and p:IsShown()) and "the panel is showing" or "the panel is not showing" end },
    { text = "Open your profession window and |cffffd100track a recipe|r you are one reagent short of (the star / Track box).\n\n|cffffd100Expect:|r the recipe shows in the panel with each reagent and have / need, the same numbers as Blizzard's objective tracker.",
        check = function() local S = Shop(); local n = S and #S.Recipes() or 0; return n > 0, n .. " tracked recipe(s) read" end },
    { text = "Get the last reagent (buy, loot or take it from the bank).\n\n|cffffd100Expect:|r under the recipe's name: \"All reagents are in your bags. Stop tracking it?\" with |cffffd100Stop|r and |cffffd100Keep|r. Press Keep: the question goes. Then use the |cffffd100x|r on the recipe's title: the recipe leaves the panel AND Blizzard's tracker." },
    { text = "If any of your gear has an empty socket and you wear no Eversong Diamond (or this expansion's one-per-character gem):\n\n|cffffd100Expect:|r the first empty socket's line reads \"<slot>: <diamond> (one per character)\" or \"one-per-character gem (none worn)\"; its |cffffd100Other|r list shows only such gems and has a Default button.\n\nNo empty socket: press Skip.",
        check = function() local S = Shop(); if not S then return false, "XayaUI QoL is off" end; local d = 0; for _, m in ipairs(S.Missing(S.Cfg())) do if m.kind == "diamond" then d = d + 1 end end; return true, d > 0 and "a one-per-character gem line is there" or "no one-per-character gem line (none needed, or the game does not mark the gem: say so in the note)" end },
} })

-- B177-B179c (core 0.6.55, Options 0.6.54): display points, the mover view's held moves, a group's saved arrangement, Scale items to
-- fit, and a dynamic group's Limit / Align. Each makes "QA test group" (static or dynamic as needed) and deletes it at the end.
local function Samples(f)
    local ns, out = NS(), {}
    for _, r in ipairs(ns.rules or {}) do if f and r.folder == f.id then out[#out + 1] = r end end
    return out
end
local function OpenRule(r)
    local ns = NS()
    if r and ns.LoadOptions and ns.LoadOptions() and ns.OptionsApi and ns.OptionsApi.EditRule then ns.OptionsApi.EditRule(r) end
end
local function Refresh() local ns = NS(); if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end end

QA.Register("display-points", { title = "A display's two points: Anchor point / Anchored to / To ...'s point", qa = "B177", order = 114, steps = {
    { text = "Press |cffffd100Do it for me|r: a QA test group with a set size (300 x 120) and two sample displays is made, and the first sample's settings open.\n\n|cffffd100Expect:|r in its Position section: |cffffd100Anchor point|r, a line |cffffd100Anchored to: Group: QA test group|r, then |cffffd100To QA test group's point|r. There is no \"Place the display\" any more.",
        setup = function()
            local ns = NS(); local f = MakeTestGroup(true)
            if ns.SetGroupSizeMode then ns.SetGroupSizeMode(f, "set") end; f.cW, f.cH, f.cBorder = 300, 120, true
            Refresh(); OpenRule(Samples(f)[1])
        end,
        check = function() local ns = NS(); local r = Samples(TestGroup())[1]; if not (r and ns.VisualAnchorTarget) then return false, "no sample display" end
            local kind, nm = ns.VisualAnchorTarget(r); return kind == "group", "anchored to: " .. tostring(nm) end },
    { text = "Set |cffffd100Anchor point|r to Bottom left, then |cffffd100To QA test group's point|r to Right. (Or press |cffffd100Do it for me|r.)\n\n|cffffd100Expect:|r the display does not move when either changes. Then set X and Y to 0: its bottom left corner sits on the middle of the group box's right edge (the box has a border).",
        setup = function() local ns = NS(); local r = Samples(TestGroup())[1]; if r and ns.SetVisualPoints then ns.SetVisualPoints(r, "BOTTOMLEFT", "RIGHT") end end,
        check = function() local ns = NS(); local r = Samples(TestGroup())[1]; if not r then return false, "no sample display" end
            local a, p = ns.VisualPoints(r); return a == "RIGHT" and p == "BOTTOMLEFT", ("anchor point %s, to the group's %s"):format(tostring(p), tostring(a)) end },
    Cleanup(),
} })

QA.Register("mover-session", { title = "Mover view: arrow keys, the lock icon, Save / Cancel moves", qa = "B178", order = 115, steps = {
    { text = "Press |cffffd100Do it for me|r: a QA test group with two sample displays is made and the mover view opens (/xui unlock).\n\n|cffffd100Expect:|r the chat line mentions the arrow keys and the lock; the group has a name tab with a small lock at its right.",
        setup = function() local ns = NS(); MakeTestGroup(true); if not ns.unlocked and ns.ToggleUnlock then ns.ToggleUnlock() end end,
        check = function() local ns = NS(); return ns.unlocked == true, ns.unlocked and "the mover view is open" or "the mover view is closed" end },
    { text = "Click |cffffd100QA sample 1|r on screen (it may open its settings; that is fine), then press the Right arrow 5 times and Shift + Up once.\n\n|cffffd100Expect:|r it moves 5 pixels right and 10 up; your character does not turn or move while you do it.",
        check = function() local r = Samples(TestGroup())[1]; if not r then return false, "no sample display" end
            return (r.visual.x or 0) ~= -60 or (r.visual.y or 0) ~= 0, ("QA sample 1 is at X %s, Y %s (it started at -60, 0)"):format(tostring(r.visual.x), tostring(r.visual.y)) end },
    { text = "Click the lock on the group's name tab.\n\n|cffffd100Expect:|r the tab says \"(locked)\"; the sample displays cannot be dragged and the mouse reaches whatever is under them. Click the lock again to unlock.",
        check = function() local ns = NS(); local f = TestGroup(); return true, (f and ns.IsMoverTempLocked and ns.IsMoverTempLocked(f)) and "the group is locked for now" or "the group is not locked (fine if you unlocked it again)" end },
    { text = "Type |cffffd100/xui unlock|r (or press |cffffd100Do it for me|r).\n\n|cffffd100Expect:|r a question \"You moved ... display(s) or group(s) ...\" with |cffffd100Save moves|r and |cffffd100Cancel moves|r; Escape does not close it. Press |cffffd100Cancel moves|r: QA sample 1 jumps back to where it was.",
        setup = function() local ns = NS(); if ns.unlocked and ns.ToggleUnlock then ns.ToggleUnlock() end end,
        check = function() local r = Samples(TestGroup())[1]; return r and r.visual.x == -60 and r.visual.y == 0, r and ("QA sample 1 is at X %s, Y %s"):format(tostring(r.visual.x), tostring(r.visual.y)) or "no sample display" end },
    Cleanup(),
} })

QA.Register("group-arrange", { title = "A group that keeps its arrangement (Align top + Space)", qa = "B179", order = 116, steps = {
    { text = "Press |cffffd100Do it for me|r: a QA test group with two sample displays is made, its Group tab opens, and Align & Arrange is set to |cffffd100Space horizontally|r and |cffffd100Align top|r.\n\n|cffffd100Expect:|r on the Group tab (not on Display) Align & Arrange shows those two choices; the samples sit in a row, tops level, 8 pixels apart.",
        setup = function() local ns = NS(); local f = MakeTestGroup(true); f.cArrX, f.cArrY = "space", "top"; if ns.ApplyGroupArrangement then ns.ApplyGroupArrangement(f) end; Refresh(); OpenGroup(f) end,
        check = function() local s = Samples(TestGroup()); if #s < 2 then return false, "no samples" end
            return s[1].visual.y == s[2].visual.y, ("Y of the samples: %s and %s"):format(tostring(s[1].visual.y), tostring(s[2].visual.y)) end },
    { text = "/xui unlock, drag one sample away and let go.\n\n|cffffd100Expect:|r it goes back into the row. Lock again (Cancel or Save, either is fine). Then pick |cffffd100None|r for both choices, unlock and drag: now it stays where you drop it." },
    Cleanup(),
} })

QA.Register("group-fit", { title = "Scale items to fit the box (and the question on resize)", qa = "B179b", order = 117, steps = {
    { text = "Press |cffffd100Do it for me|r: a QA test group is made with two samples 120 pixels apart, a set size of 400 x 120 and a border; its Group tab opens.\n\n|cffffd100Expect:|r below Width and Height a tick box |cffffd100Scale items to fit the box|r (unticked).",
        setup = function() local ns = NS(); local f = MakeTestGroup(true); if ns.SetGroupSizeMode then ns.SetGroupSizeMode(f, "set") end; f.cW, f.cH, f.cBorder = 400, 120, true; Refresh(); OpenGroup(f) end,
        check = function() local f = TestGroup(); return f and not f.cFit, f and (f.cFit and "ticked" or "unticked") or "no test group" end },
    { text = "Drag the |cffffd100Width|r slider down to about 100.\n\n|cffffd100Expect:|r once, a question \"Scale the items to fit?\" with Yes / No (sliding further does not ask again). Press |cffffd100Yes|r: the tick box is ticked and both samples shrink to fit inside the border; the border keeps the width you set.",
        check = function() local ns = NS(); local f = TestGroup(); if not f then return false, "no test group" end
            return f.cFit == true, ("ticked: %s; scale used: %.2f"):format(tostring(f.cFit == true), ns.GroupFitScale and ns.GroupFitScale(f) or 1) end },
    Cleanup(),
} })

QA.Register("dynamic-limit-align", { title = "Dynamic group: Limit and Align", qa = "B179c", order = 118, steps = {
    { text = "Press |cffffd100Do it for me|r: the QA test group becomes a dynamic group (growing Right) with three samples, the third smaller; its Group tab opens.\n\n|cffffd100Expect:|r |cffffd100Limit (show at most)|r and |cffffd100Align|r beside Sort and Spacing; the three samples in a row, the small one centred.",
        setup = function()
            local ns = NS(); local f = MakeTestGroup(true); f.cType, f.cGrowth = "dynamic", "RIGHT"
            local s = Samples(f)
            if #s < 3 then
                local r = ns.NewRule(); r.name = "QA sample 3"; r.folder = f.id; r.enabled = true
                r.visual = r.visual or {}; r.visual.enabled = true; r.visual.w, r.visual.h = 64, 32
                ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
                if ns.SetPreview then ns.SetPreview({ r }, "visual", true) end
            end
            Refresh(); OpenGroup(f)
        end,
        check = function() local f = TestGroup(); return f and f.cType == "dynamic" and #Samples(f) >= 3, f and ("%s group, %d samples"):format(tostring(f.cType or "static"), #Samples(f)) or "no test group" end },
    { text = "Set |cffffd100Align|r to Top, then Bottom.\n\n|cffffd100Expect:|r Top: the small sample's top is level with the others' tops; Bottom: its bottom is level with theirs. (If the samples look the same size, the check below still says which Align is set.)",
        check = function() local f = TestGroup(); return f and f.cAlign ~= nil, f and ("Align: %s"):format(tostring(f.cAlign or "center (default)")) or "no test group" end },
    { text = "Set |cffffd100Limit (show at most)|r to 2.\n\n|cffffd100Expect:|r only the first two samples show; set it back to 0 and all three show again.",
        check = function() local f = TestGroup(); return f ~= nil, f and ("Limit: %s"):format(tostring(f.cLimit or "none")) or "no test group" end },
    Cleanup(),
} })

-- R31 / task #30 (Xaya: "rule sidebar continues to bug out and clip itself after any rule change is made"): not reproduced in the
-- stand-in game on 0.6.57 (the sidebar keeps its width and every name keeps at least 80 px across renames and enable / disable). This
-- walkthrough measures it on her screen before and after a change; the numbers are saved with her answers (V22 data capture).
local function SidebarRoom()
    local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
    local root = ACD and ACD.OpenFrames and ACD.OpenFrames["CueRules"]
    if not root then return nil, "the settings window is not open" end
    local best
    local function walk(w)
        if not w then return end
        if w.type == "TreeGroup" and w.buttons then
            local st = w.status or w.localstatus or {}
            local minRoom, who, n = nil, nil, 0
            for _, b in ipairs(w.buttons) do
                local txt = b.text and b.text.GetText and b.text:GetText()
                if b:IsShown() and type(txt) == "string" and txt ~= "" then
                    n = n + 1
                    local room = (b:GetWidth() or 0) - (b.xuiTextL or 0) - (b.xuiTextR or 0)
                    local fits = (b.text.GetStringWidth and b.text:GetStringWidth() or 0) <= ((b.text.GetWidth and b.text:GetWidth()) or 0) + 1
                    if not minRoom or room < minRoom then minRoom, who = room, txt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
                    if not fits then who = (who or "") .. " (cut off)" end
                end
            end
            if n > 0 and (not best or n > best.n) then best = { n = n, width = st.treewidth, manual = st.xuiManualWidth, room = minRoom, who = who } end
        end
        for _, c in ipairs(w.children or {}) do walk(c) end
    end
    walk(root)
    if not best then return nil, "no sidebar rows are showing" end
    return best
end
local function SidebarCheck()
    local b, why = SidebarRoom()
    if not b then return false, why end
    return (b.room or 0) >= 80, ("sidebar %s px%s; %d rows; the tightest name has %d px (%s)"):format(tostring(b.width), b.manual and " (set by hand)" or "", b.n, b.room or 0, tostring(b.who))
end
QA.Register("sidebar-names", { title = "Rules sidebar: names after a rule change (R31)", qa = "B179d", order = 119, steps = {
    { text = "Press |cffffd100Do it for me|r: a QA test group with two nested groups and a rule with a long name is made, and the rule opens.\n\n|cffffd100Expect:|r in the Rules sidebar every name is readable (at least a few words; the full name shows on mouse-over). The addon measures the sidebar below.",
        setup = function()
            local ns = NS(); local f = MakeTestGroup(false)
            local a = ns.NewFolder("QA nested one", f.id); local b = ns.NewFolder("QA nested two with a long name", a.id)
            local r = ns.NewRule(); r.name = "QA rule with a rather long name for the sidebar"; r.folder = b.id; r.enabled = true
            ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
            if ns.MarkDirty then ns.MarkDirty() end
            OpenRule(r)
        end,
        check = SidebarCheck },
    { text = "Change the rule: untick |cffffd100Enabled|r, tick it again, then rename it (any change you would normally make).\n\n|cffffd100Expect:|r the sidebar keeps its width and the names stay readable after each change. If a name is cut off, press |cffffd100Check again|r before you answer: the measurement is saved with your answer.",
        check = SidebarCheck },
    { text = "Last step: press |cffffd100Do it for me|r to delete the QA test group, its nested groups and the rule (they go to the Recycle Bin). Then Pass.",
        setup = function()
            local ns = NS(); local f = TestGroup()
            if f and ns.LoadOptions then ns.LoadOptions() end
            if f and ns.OptionsApi and ns.OptionsApi.DeleteFolderAll then ns.OptionsApi.DeleteFolderAll(f.id) end
        end,
        check = function() return TestGroup() == nil, TestGroup() and "the QA test group is still there" or "the QA test group is gone" end },
} })
