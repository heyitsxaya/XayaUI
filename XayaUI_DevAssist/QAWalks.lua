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
