-------------------------------------------------------------------------------
-- QAWalks-layout-fixes.lua (XayaUI_DevAssist 0.7.72): in-game QA walkthrough for the layout fixes of 2026-11-08 (Options 0.6.105,
-- Rules 0.6.81; QA steps B301 to B304). Her words (REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s):
--   #7  "CLAUDE WTF IS THIS" (Blizzard Reskin > Theme: the rows ran on as one wrapped stream);
--   #11 "I need to be able to move the rule box around so that I can actually see what I'm working on; also all buttons should not
--       have text overflow";
--   #12 "need to be able to clear an anchor" (the group was anchored to the X / Y box itself: "Anchored to XayaUIGroupPosPo...").
--   B301 the Theme table: one screen line per row, each starting with the element's name (positions read back from the window);
--   B302 the group's X / Y box drags (its position before and after is read back);
--   B303 every button in the X / Y box fits its label (label width read back, compared with the button);
--   B304 "Anchor to a frame on screen..." never offers the X / Y box; any group anchored to it is listed (press "Anchor to the screen
--        (stays in place)" on it to clear that anchor);
--   B305 (#13 "in mover mode, I can't use arrow keys") with the box open, the arrow keys move its group, and the box shows the new X / Y;
--   B313 (#26 "visual cuts off", Rules Options 0.6.82) a cue's Stacks / Charges Count > Count options shows its controls again (the
--        "Count of" list's sort raised a Lua error that stopped the pane and every section after it).
-- Standing rule V22 (Xaya 2026-11-07): each check reads back what the addon drew or stored, offers its verdict (prefill = true;
-- recorded only on her click) and puts what it read in the note. The last step (Done) closes the mover view if the walkthrough
-- opened it, without keeping the walkthrough's moves of the QA test group (Cancel moves). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local st = {}
local function NS() return rawget(_G, "XayaUI_NS") end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames.CueRules end
local function SE() local ns = NS(); return ns and ns.OptionsApi and ns.OptionsApi.ScopeEditor end
local function OptOf(w) return w.GetUserData and w:GetUserData("option") end
local function Find(w, pred, out)
    out = out or {}
    if type(w) ~= "table" then return out end
    if pred(w) then out[#out + 1] = w end
    for _, c in ipairs(w.children or {}) do Find(c, pred, out) end
    return out
end
local function LabelW(b)
    local fs = b and b.GetFontString and b:GetFontString()
    local ok, w = pcall(function() return fs and (fs.GetUnboundedStringWidth or fs.GetStringWidth)(fs) end)
    return (ok and type(w) == "number") and w or nil
end

-- B301: the Theme table as drawn
local function SetupTable()
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then error("the settings window (XayaUI_Options) could not be loaded") end
    if not SE() then error("XayaUI Options is older than 0.6.104 (no Blizzard Reskin > Theme page)") end
    ns.OpenSettingsPage("reskin", SE().PAGE)
end
local function CheckTable()
    local root = Root()
    if not root then return nil, "the settings window is not open: press Do it for me" end
    local cells = Find(root, function(w) local o = OptOf(w); return o and o.width == "relative" and type(o.arg) == "table" and o.arg.xuiCell and w.frame and w.frame.GetTop end)
    if #cells == 0 then return nil, "the Theme table is not on screen: press Do it for me" end
    local names = {}
    for _, d in ipairs(SE().Elements()) do names[d.label] = true end
    -- the screen lines: cells whose heights overlap (AceGUI's Flow lines controls up by their own offsets, so a list and a label on
    -- one line have different tops; two lines never overlap)
    local lines = {}
    for _, w in ipairs(cells) do
        local top, bot = w.frame:GetTop(), w.frame:GetBottom()
        if top and bot then
            local mid = (top + bot) / 2
            local ln
            for _, l in ipairs(lines) do if (mid <= l.top and mid >= l.bot) or (l.mid <= top and l.mid >= bot) then ln = l end end
            if not ln then ln = { top = top, bot = bot, mid = mid, list = {} }; lines[#lines + 1] = ln end
            ln.list[#ln.list + 1] = w
        end
    end
    local bad, cut = {}, {}
    for _, l in ipairs(lines) do
        table.sort(l.list, function(a, b) return (a.frame:GetLeft() or 0) < (b.frame:GetLeft() or 0) end)
        local first = OptOf(l.list[1]); local nm = first and first.name
        if type(nm) == "function" then local ok, x = pcall(nm); nm = ok and x or "" end
        nm = tostring(nm or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if not (nm == "Element" or names[nm]) then bad[#bad + 1] = "a line starts with '" .. nm .. "'" end
        local dd = 0
        for _, w in ipairs(l.list) do
            if w.type == "Dropdown" then dd = dd + 1 end
            if w.type == "Button" then local lw = LabelW(w); if lw and lw + 30 > (w.frame:GetWidth() or 0) + 0.5 then cut[#cut + 1] = (w.text and w.text:GetText() or "?") end end
        end
        if dd > 1 then bad[#bad + 1] = "a line holds " .. dd .. " Theme lists" end
    end
    local want = #SE().Elements() + 1
    if #lines ~= want then bad[#bad + 1] = #lines .. " lines for " .. want .. " rows" end
    return #bad == 0, ("Lines: %d (rows with the header: %d). %s%s"):format(#lines, want, #bad == 0 and "Each line starts with its element's name." or table.concat(bad, "; "),
        #cut > 0 and (" Buttons narrower than their label: " .. table.concat(cut, ", ")) or "")
end

-- B302-B304: the group's X / Y box
local function Box() return rawget(_G, "XayaUIGroupPosPopup") end
local function SetupBox()
    local ns = NS()
    if not (ns and QA.MakeTestGroup) then error("XayaUI Dev Assist is older than 0.7.72") end
    local f = QA.MakeTestGroup(true)
    if not ns.unlocked and ns.ToggleUnlock then ns.ToggleUnlock(); st.unlockedByUs = true end
    local tag = ns.GroupTagFor and ns.GroupTagFor(f.id)
    if not (tag and tag.GetScript and tag:GetScript("OnMouseUp")) then error("the QA test group's tab is not on screen") end
    tag:GetScript("OnMouseUp")(tag, "RightButton")
    local p = Box()
    if p then st.at = { p:GetLeft(), p:GetTop() } end
end
local function CheckDrag()
    local p = Box()
    if not (p and p:IsShown()) then return nil, "the X / Y box is not open: press Do it for me" end
    if not (p.IsMovable and p:IsMovable()) then return false, "the box cannot be moved (Rules older than 0.6.81?)" end
    local l, t = p:GetLeft(), p:GetTop()
    local a = st.at or {}
    if not (l and a[1]) then return nil, "drag the box first" end
    local moved = math.abs(l - a[1]) + math.abs(t - a[2])
    if moved < 5 then return nil, ("the box is still where it opened (%.0f, %.0f): drag it by its background, then Check"):format(l, t) end
    return true, ("The box moved from (%.0f, %.0f) to (%.0f, %.0f)."):format(a[1], a[2], l, t)
end
local function CheckLabels()
    local p = Box()
    if not (p and p:IsShown()) then return nil, "the X / Y box is not open: press Do it for me in step 2" end
    local bad, n = {}, 0
    for _, k in ipairs({ p:GetChildren() }) do
        if k.GetObjectType and k:GetObjectType() == "Button" and k.GetText and (k:GetText() or "") ~= "" then
            n = n + 1
            local lw = LabelW(k)
            if lw and lw + 30 > k:GetWidth() + 0.5 then bad[#bad + 1] = ("%s (label %.0f px, button %.0f px)"):format(k:GetText(), lw, k:GetWidth()) end
        end
    end
    return #bad == 0, ("%d buttons, box %.0f px wide. %s"):format(n, p:GetWidth(), #bad == 0 and "Every label fits." or ("Too narrow: " .. table.concat(bad, "; ")))
end
local function CheckPicker()
    local ns = NS(); local p = Box()
    if not p then return nil, "the X / Y box was never opened: press Do it for me in step 2" end
    local stuck = {}
    for _, f in ipairs(ns.folders or {}) do
        if f.cRel == "custom" and (f.cFrame == "XayaUIGroupPosPopup" or f.cFrame == "XayaUIFramePicker") then stuck[#stuck + 1] = tostring(f.name) end
    end
    local ok = p.xuiPickerOwn == true and #stuck == 0
    return ok, ("The X / Y box %s offered by the frame picker. %s"):format(p.xuiPickerOwn and "is not" or "IS",
        #stuck == 0 and "No group is anchored to it." or ("Anchored to it: " .. table.concat(stuck, ", ") .. " (open that group's box and press Anchor to the screen (stays in place))."))
end
local function SetupArrows()
    local ns = NS(); local p = Box()
    if not (p and p:IsShown() and ns.FolderById) then error("the X / Y box is not open: press Do it for me in step 2") end
    local f = ns.FolderById(p.fid)
    p.x:ClearFocus(); p.y:ClearFocus()
    st.arrowFrom = f and { f.cX or 0, f.cY or 0 }
end
local function CheckArrows()
    local ns = NS(); local p = Box()
    if not (p and p:IsShown()) then return nil, "the X / Y box is not open: press Do it for me in step 2" end
    if not st.arrowFrom then return nil, "press Do it for me first, then the arrow keys" end
    local f = ns.FolderById(p.fid)
    local dx, dy = (f.cX or 0) - st.arrowFrom[1], (f.cY or 0) - st.arrowFrom[2]
    if dx == 0 and dy == 0 then return nil, "the group has not moved yet: press an arrow key a few times, then Check" end
    local shows = p.x:GetText() == tostring(f.cX or 0) and p.y:GetText() == tostring(f.cY or 0)
    return shows, ("The group moved by X %+d, Y %+d; the box shows X %s, Y %s%s"):format(dx, dy, p.x:GetText(), p.y:GetText(), shows and "" or " (not the group's numbers)")
end
local function CheckCount()
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then return nil, "the settings window could not be loaded" end
    -- the whole settings table, through the Options API (Dev Assist does not call XayaUI_Options' own functions)
    local api = ns.OptionsApi
    if not (api and api.BuiltTable) then return nil, "XayaUI Options is older than 0.6.106" end
    local ok, built = pcall(api.BuiltTable)
    if not ok then return false, "building the settings failed: " .. tostring(built) end
    -- every "Count of" list in the settings (cues and the group's Display tab), read the way the window reads it
    local lists, seen = {}, {}
    local function scan(t) if type(t) ~= "table" or seen[t] then return end; seen[t] = true
        if t.type == "select" and t.name == "Count of" and type(t.sorting) == "function" then lists[#lists + 1] = t end
        for _, v in pairs(t) do scan(v) end end
    scan(built)
    if #lists == 0 then return nil, "no Count of list in the settings: tick Show a count on a cue, open Stacks / Charges Count, then Check" end
    for _, o in ipairs(lists) do
        local okS, list = pcall(o.sorting)
        if not okS then return false, "a Count of list raised: " .. tostring(list) end
        if type(list) ~= "table" or #list == 0 then return false, "a Count of list is empty" end
    end
    return true, ("The Count of lists work (%d read)."):format(#lists)
end
local function Done()
    local ns = NS(); local p = Box()
    if p then p:Hide() end
    -- the walkthrough's own moves (the QA test group) are not kept: the mover view it opened is left with Cancel moves
    if st.unlockedByUs and ns and ns.unlocked then
        if ns.MoverExit then ns.MoverExit("cancel") elseif ns.ToggleUnlock then ns.ToggleUnlock() end
    end
    st.unlockedByUs, st.at, st.arrowFrom = nil, nil, nil
end
QA.LayoutFixesTest = { State = st, Done = Done }   -- (tests)

QA.Register("layout-fixes", { title = "Theme table rows, the movable X / Y box, buttons that fit, arrow keys (B301-B305, B313)",
    qa = "B301, B302, B303, B304, B305, B313", order = 530, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on |cffffd100Blizzard Reskin > Theme|r.\n\n|cffffd100Expect:|r the header Element | Theme | Overrides | Comes from | Reset on one line, then one line per element, each starting with the element's name (Blizzard Windows, Buttons, Character Pane ...), with its Theme list, count, Edit, Comes from and Reset on the same line. The check reads where every cell is drawn.",
        setup = SetupTable, check = CheckTable },
    { text = "Press |cffffd100Do it for me|r: the mover view opens with the QA test group, and its |cffffd100X / Y box|r opens.\n\nNow |cffffd100drag the box|r by its background (not a button or a number box) somewhere else, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the box follows the mouse and stays where you drop it.",
        setup = SetupBox, check = CheckDrag },
    { text = "Look at the box's buttons.\n\n|cffffd100Expect:|r every label sits inside its button, including |cffffd100Anchor to the screen (stays in place)|r. The check compares each label's width with its button.",
        check = CheckLabels },
    { text = "Press |cffffd100Anchor to a frame on screen...|r in the box and point at the box itself.\n\n|cffffd100Expect:|r no green outline on the box (it is never a frame you can anchor to); press |cffffd100Cancel|r on the banner. The check also lists any group already anchored to the box: open its box and press |cffffd100Anchor to the screen (stays in place)|r to clear that anchor.",
        check = CheckPicker },
    { text = "Press |cffffd100Do it for me|r (it takes the keyboard away from the number boxes), then press the |cffffd100arrow keys|r a few times (Shift + arrow: 10 pixels), then |cffffd100Check|r.\n\n|cffffd100Expect:|r the QA test group moves 1 pixel per press, and the box's X offset and Y offset show its new position.",
        setup = SetupArrows, check = CheckArrows },
    { text = "Open a rule with an icon or text cue, tick |cffffd100Show a count|r and open |cffffd100Stacks / Charges Count|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r |cffffd100Count options|r shows its controls (Count of, Font, Text size, Outline, Text color, Placement, Position, X / Y offset) and the sections after it (Shield / Absorb Amount, Position, Color, Animation) are there. The check reads the Count of list the way the window does.",
        check = CheckCount },
    { text = "Press |cffffd100Do it for me|r to close the box (and the mover view, if this walkthrough opened it), then |cffffd100Done|r.", done = true, setup = Done },
} })
