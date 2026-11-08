-------------------------------------------------------------------------------
-- QAWalks-aspect-ratio.lua (XayaUI_DevAssist 0.7.72): in-game QA walkthrough for "Maintain aspect ratio" in a group's "Every display:
-- size" section (Rules Options 0.6.82; QA steps B340 to B343). Her words (REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s rows 24-25):
-- "add maintain aspect ratio to the every display option"; her decision: a tick box labelled "Maintain aspect ratio" in "Every display:
-- size", off by default; while it is on, changing Display width changes Display height in the same proportion, and changing height
-- changes width; the proportion is the one the two had when the box was ticked.
--   B340 the box is on the group's Group tab, in Every display: size, unticked (the box and both sliders read back from the window);
--   B341 ticked at 64 x 32, a width change gives every display of the group the height in the same proportion, and a height change
--        the width (every display's own width / height read back);
--   B342 at the end of a slider the other side stops at 8 or 512 (the proportion is not kept there), and comes back inside the range;
--   B343 unticked, a width change leaves the height alone again.
-- Standing rule V22 (Xaya 2026-11-07): each check reads back what the addon drew or stored, offers its verdict (prefill = true;
-- recorded only on her click) and puts what it read in the note. Test data: the shared "QA test group" (QA.MakeTestGroup, its two
-- sample rules); step 1's Do it for me sets their displays to 64 x 32 and unticks the box; Done unticks it again. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local st = {}
local LO, HI = 8, 512
local function NS() return rawget(_G, "XayaUI_NS") end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames.CueRules end
local function OptOf(w) return w.GetUserData and w:GetUserData("option") end
local function Find(w, pred, out)
    out = out or {}
    if type(w) ~= "table" then return out end
    if pred(w) then out[#out + 1] = w end
    for _, c in ipairs(w.children or {}) do Find(c, pred, out) end
    return out
end
local function Widget(name)
    local l = Find(Root(), function(w) local o = OptOf(w); return o and o.name == name end)
    return l[1]
end
local function Group() return st.fid and NS() and NS().FolderById and NS().FolderById(st.fid) or nil end
local function Displays()
    local ns, f = NS(), Group()
    local out = {}
    if not (ns and f) then return out end
    -- the displays the group's section edits (the same rule as the rule editor's ns.RuleDisplays, read here through XayaUI Rules'
    -- ns.CuesOf: a Dev Assist file may not call the rule editor's own names): each rule's visual cues; a rule with no cues counts
    -- its own display while it is on
    for _, r in ipairs(ns.rules or {}) do
        if r.folder == f.id and not r.parentUid then
            local cues = ns.CuesOf and ns.CuesOf(r) or {}
            for _, c in ipairs(cues) do
                if c.cueKind ~= "sound" and c.cueKind ~= "speech" and c.cueKind ~= "custom" and type(c.visual) == "table" then out[#out + 1] = c end
            end
            if #cues == 0 and type(r.visual) == "table" and r.visual.enabled then out[#out + 1] = r end
        end
    end
    return out
end
local function Fit(x) x = math.floor(x + 0.5); if x < LO then return LO end; if x > HI then return HI end; return x end
-- every display's size as "w x h", and the first display's numbers
local function Sizes()
    local t, w0, h0, same = {}, nil, nil, true
    for i, d in ipairs(Displays()) do
        local w, h = tonumber(d.visual.w), tonumber(d.visual.h)
        t[#t + 1] = tostring(w) .. " x " .. tostring(h)
        if i == 1 then w0, h0 = w, h elseif w ~= w0 or h ~= h0 then same = false end
    end
    return w0, h0, same, table.concat(t, ", ")
end
local function Ratio() local f = Group(); local r = f and tonumber(f.dispAspect); return (r and r > 0) and r or nil end
local function Snap() local w, h = Sizes(); st.w, st.h = w, h end

-- B340: the box on the group page
local function Setup()
    local ns = NS()
    if not (ns and QA.MakeTestGroup) then error("XayaUI Dev Assist is older than 0.7.72") end
    if not (ns.LoadOptions and ns.LoadOptions()) then error("the settings window (XayaUI_Options) could not be loaded") end
    local f = QA.MakeTestGroup(true)
    st.fid = f.id
    f.dispAspect = nil
    for _, d in ipairs(Displays()) do d.visual.w, d.visual.h = 64, 32; if ns.RefreshVisual then pcall(ns.RefreshVisual, d) end end
    if ns.MarkDirty then ns.MarkDirty() end
    -- open the window on the group's page: its row in the sidebar's list (a member rule's path without the rule), as a click there
    -- selects it (QAWalks-debug-w5.lua); without a member rule, OptionsApi.EditFolder
    local api = ns.OptionsApi
    if not (api and api.IsOpen and api.IsOpen()) and api and api.Toggle then pcall(api.Toggle) end
    local member
    for _, r in ipairs(ns.rules or {}) do if r.folder == f.id and not r.parentUid then member = r; break end end
    local a, RE = ACD(), api and api.RuleEditor
    if a and RE and RE.ScopePath and member then
        local okc, ctx = pcall(ns.ReadContext)
        local path = { RE.ScopePath(member, okc and ctx or nil) }; path[#path] = nil
        pcall(a.SelectGroup, a, "CueRules", unpack(path))
    elseif api and api.EditFolder then api.EditFolder(f) end
    Snap()
end
local function CheckBox()
    if not Group() then return nil, "press Do it for me first" end
    local box = Widget("Maintain aspect ratio")
    if not box then return nil, "the tick box is not on screen: press Do it for me, then click the Group tab if another tab is picked (section Every display: size, opened)" end
    local sw, sh = Widget("Display width"), Widget("Display height")
    local ticked = box.GetValue and box:GetValue() and true or false
    local vw, vh = sw and sw.GetValue and sw:GetValue(), sh and sh.GetValue and sh:GetValue()
    local _, _, _, all = Sizes()
    local ok = sw ~= nil and sh ~= nil and not ticked and Ratio() == nil
    return ok, ("Tick box shown, %s. Display width %s, Display height %s. Displays: %s."):format(ticked and "TICKED" or "unticked",
        tostring(vw), tostring(vh), all)
end

-- B341 / B342: the other side follows (one check for each step; it needs a change since the last check)
local function CheckFollow(want)
    return function()
        if not Group() then return nil, "press Do it for me in step 1 first" end
        local r = Ratio()
        if not r then return nil, "tick Maintain aspect ratio first" end
        local w, h, same, all = Sizes()
        if not (w and h) then return nil, "the QA test group has no display" end
        if w == st.w and h == st.h then return nil, ("the size is still %s x %s: change it as the step says, then Check"):format(tostring(w), tostring(h)) end
        if want and want.h and h ~= want.h then return nil, ("Display height is %d: set it to %d, then Check"):format(h, want.h) end
        local fromW, fromH = Fit(w / r), Fit(h * r)
        local ok = same and (h == fromW or w == fromH)
        if want and want.w then ok = ok and w == want.w end
        Snap()
        return ok, ("Proportion kept on the group: %.3f (width / height). Displays now: %s (from the width the height would be %d; from the height the width would be %d)%s."):format(
            r, all, fromW, fromH, same and "" or "; the displays DIFFER")
    end
end

-- B343: unticked, the height stays
local function CheckOff()
    if not Group() then return nil, "press Do it for me in step 1 first" end
    if Ratio() then return nil, "untick Maintain aspect ratio first" end
    local w, h, _, all = Sizes()
    if w == st.w then return nil, ("Display width is still %s: change it, then Check"):format(tostring(w)) end
    local ok = h == st.h
    local was = tostring(st.w) .. " x " .. tostring(st.h)
    Snap()
    return ok, ("No proportion stored on the group. Before: %s; displays now: %s (height %s)."):format(was, all, ok and "unchanged" or "CHANGED")
end
local function Done()
    local f = Group()
    if f then f.dispAspect = nil end
    local ns = NS()
    if ns and ns.MarkDirty then ns.MarkDirty() end
    st.fid, st.w, st.h = nil, nil, nil
end
QA.AspectRatioTest = { State = st, Done = Done }   -- (tests)

QA.Register("aspect-ratio", { title = "Every display: size, Maintain aspect ratio (B340-B343)", qa = "B340, B341, B342, B343", order = 540,
    prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on the QA test group's page, with its two sample displays set to 64 x 32 (click the |cffffd100Group|r tab if another tab is picked).\n\nLook at the section |cffffd100Every display: size|r.\n\n|cffffd100Expect:|r Display width 64, Display height 32, a tick box |cffffd100Maintain aspect ratio|r (unticked), then Zoom / crop edges. Hover the box: one short sentence.",
        setup = Setup, check = CheckBox },
    { text = "Tick |cffffd100Maintain aspect ratio|r, then set |cffffd100Display width|r to |cffffd10096|r (drag the slider, or type 96 in its box and press Enter), then press |cffffd100Check|r.\n\n|cffffd100Expect:|r Display height changes to 48 by itself, and both sample displays on screen are 96 x 48 (twice as wide as tall, as before).",
        check = CheckFollow({ w = 96 }) },
    { text = "Now set |cffffd100Display height|r to |cffffd10024|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r Display width changes to 48 by itself (48 x 24).",
        check = CheckFollow({ h = 24 }) },
    { text = "Drag |cffffd100Display height|r all the way to the right (|cffffd100512|r), then |cffffd100Check|r.\n\n|cffffd100Expect:|r Display width stops at 512, the largest a display can be (twice 512 would be too big), so here the displays are square. Then drag height back to |cffffd10032|r and press |cffffd100Check|r again: width is 64 again (the proportion you ticked is kept).",
        check = CheckFollow() },
    { text = "Untick |cffffd100Maintain aspect ratio|r, then change |cffffd100Display width|r (any number), then |cffffd100Check|r.\n\n|cffffd100Expect:|r Display height stays where it was.",
        check = CheckOff },
    { text = "Press |cffffd100Do it for me|r to untick the box on the QA test group (if it is still ticked), then |cffffd100Done|r.", done = true, setup = Done },
} })
