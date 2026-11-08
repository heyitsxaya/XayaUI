-------------------------------------------------------------------------------
-- QAWalks-group-anchors.lua (XayaUI_DevAssist 0.7.72): in-game QA walkthrough for the group anchors of Rules 0.6.82 (QA steps B350 to
-- B357). Her words (REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s): #14 "anchoring to an EUI unit frame isn't calculating correctly";
-- #18 "I should be able to anchor to another rule group's position"; her answers (#28 and the next row): scope "Both now"; rows growing
-- one way: "Whole grid's corner"; existing groups: "Nothing moves"; changing the point: "Icons move"; hand-placed groups: every
-- switched-on display; group to group: follows the other group's frame, picked in the picker and from "Another group" in Relative to;
-- the followed group deleted: "Stays put, link cleared".
--   B350 a dynamic group growing Right, Auto size, Bottom left on the screen's centre: the grid's bottom-left corner is on it;
--   B351 the QA test group (hand-placed), Bottom left: the outline of its switched-on displays is on it; one that stops showing moves
--        nothing;
--   B352 the point changed to Top right: the outline's top-right is on it, X / Y unchanged;
--   B353 what the one-time update adjusted at the first login with 0.6.82 (data capture; she says whether anything moved);
--   B354 the picker: the QA test group anchored to the "QA anchor target" group, staying in place; it follows that group;
--   B355 the settings page: Relative to has Another group, the group list leaves the group itself and loops out;
--   B356 the followed group deleted: the QA test group stays put and is placed from the screen again;
--   B357 (a question, how it behaves now) a display at the edge of a hand-placed group's outline nudged: what moves (data capture).
-- Standing rule V22 (Xaya 2026-11-07): each check reads back what the addon drew or stored, offers its verdict (prefill = true; recorded
-- only on her click) and puts what it read in the note; B353 asks her (noVerdict). Test data: the shared "QA test group" (its two
-- sample displays) and a group "QA anchor target" made here (two sample displays, previewed); Done puts the QA test group's position
-- settings back, deletes "QA anchor target" (it goes to the Recycle Bin) and leaves the mover view with Cancel moves if it opened it.
-- UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local st = {}
local TARGET = "QA anchor target"
local KEYS = { "cX", "cY", "cRel", "cGroup", "cFrame", "cPoint", "cRelPoint", "cType", "cGrowth", "cSize", "cW", "cH" }
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
local function Group() local ns = NS(); return st.fid and ns and ns.FolderById and ns.FolderById(st.fid) or nil end
local function Target()
    local ns = NS()
    for _, f in ipairs(ns and ns.folders or {}) do if f.name == TARGET and f.qaAnchor == true then return f end end
end
local function Members(f)
    local ns, out = NS(), {}
    for _, r in ipairs(ns and ns.rules or {}) do if f and r.folder == f.id and not r.parentUid then out[#out + 1] = r end end
    return out
end
-- the screen box (UIParent units) of the given rules' displays as drawn; only those showing
local function Drawn(list)
    local ns = NS()
    local us = UIParent:GetEffectiveScale()
    local l, b, r, t, n = nil, nil, nil, nil, 0
    for _, rule in ipairs(list) do
        local fr = ns.DisplayFrame and ns.DisplayFrame(rule)
        if fr and fr:IsShown() then
            local fl, fb, fw, fh = fr:GetRect()
            if fl then
                local s = fr:GetEffectiveScale() / us
                fl, fb, fw, fh = fl * s, fb * s, fw * s, fh * s
                l = l and math.min(l, fl) or fl; b = b and math.min(b, fb) or fb
                r = r and math.max(r, fl + fw) or (fl + fw); t = t and math.max(t, fb + fh) or (fb + fh)
                n = n + 1
            end
        end
    end
    return l, b, r, t, n
end
local function Centre() local w, h = UIParent:GetWidth(), UIParent:GetHeight(); return w / 2, h / 2 end
local function Near(a, b) return math.abs(a - b) <= 1 end
local function Refresh() local ns = NS(); if ns.MarkDirty then ns.MarkDirty() end; if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end end
local function MakeTarget()
    local ns = NS()
    local f = Target()
    if not f then f = ns.NewFolder(TARGET); f.qaAnchor = true end
    f.cType, f.cGrowth, f.cSpacing, f.cPoint, f.cRelPoint, f.cRel, f.cX, f.cY = "dynamic", "RIGHT", 4, "BOTTOMLEFT", "CENTER", nil, 0, 0
    if ns.SetGroupSizeMode then ns.SetGroupSizeMode(f, "auto") end
    local have = Members(f)
    for i = #have + 1, 2 do
        local r = ns.NewRule(); r.name = "QA target " .. i; r.folder = f.id; r.enabled = true
        r.visual = r.visual or {}; r.visual.enabled = true
        ns.NormalizeRule(r); r.visual.w, r.visual.h = 30, 30; ns.rules[#ns.rules + 1] = r
    end
    if ns.SetPreview then ns.SetPreview(Members(f), "visual", true) end
    Refresh()
    return f
end

-- B350: the grid's bottom-left on the screen's centre
local function SetupGrid()
    local ns = NS()
    if not (ns and QA.MakeTestGroup and ns.GroupOutline) then error("XayaUI Rules is older than 0.6.82, or Dev Assist older than 0.7.72") end
    local g = QA.MakeTestGroup(true)
    st.fid = g.id
    if not st.orig then st.orig = {}; for _, k in ipairs(KEYS) do st.orig[k] = g[k] end end
    local t = MakeTarget()
    t.cX, t.cY = 0, 0
    Refresh()
end
local function CheckGrid()
    local t = Target()
    if not t then return nil, "press Do it for me first" end
    local l, b, _, _, n = Drawn(Members(t))
    if not l or n == 0 then return nil, "the QA anchor target's displays are not on screen: press Do it for me again" end
    local cx, cy = Centre()
    local px, py = cx + (t.cX or 0), cy + (t.cY or 0)
    local ok = Near(l, px) and Near(b, py)
    return ok, ("Grid of %d displays, its bottom-left at (%.1f, %.1f); the group's point (screen centre + X / Y) at (%.1f, %.1f): %s."):format(n, l, b, px, py,
        ok and "on it" or "OFF by " .. ("%.1f, %.1f"):format(l - px, b - py))
end

-- B351: the hand-placed group's outline
local function SetupOutline()
    local ns, g = NS(), Group()
    if not g then error("press Do it for me in step 1 first") end
    g.cRel, g.cGroup, g.cFrame, g.cPoint, g.cRelPoint, g.cX, g.cY = nil, nil, nil, "BOTTOMLEFT", "CENTER", 0, 0
    if ns.SetGroupSizeMode then ns.SetGroupSizeMode(g, "auto") end
    local m = Members(g)
    if ns.SetPreview then ns.SetPreview(m, "visual", true) end
    Refresh()
    local first = m[1]
    local l, b = Drawn({ first })
    st.firstAt = l and { l, b } or nil
    -- one display stops showing (as when its conditions are not met): it still counts, being switched on
    if m[2] and ns.SetPreview then ns.SetPreview({ m[2] }, "visual", false); Refresh() end
end
local function CheckOutline()
    local ns, g = NS(), Group()
    if not (g and st.firstAt) then return nil, "press Do it for me first" end
    local m = Members(g)
    local l, b = Drawn({ m[1] })
    if not l then return nil, "the first sample display is not on screen: press Do it for me again" end
    local stayed = Near(l, st.firstAt[1]) and Near(b, st.firstAt[2])
    local ol, ob = ns.GroupOutline(g)
    local ax, ay = ns.GroupAnchorXY(g)
    local cx, cy = Centre()
    local onPoint = ax and Near(ax, cx) and Near(ay, cy)
    local shown = m[2] and ns.DisplayFrame(m[2]) and ns.DisplayFrame(m[2]):IsShown()
    return (stayed and onPoint) and true or false, ("Outline from the saved displays: bottom-left (%s, %s) from the group's centre; the group's anchor point at (%.1f, %.1f), the screen centre (%.1f, %.1f): %s. Sample 2 %s; sample 1 %s."):format(
        tostring(ol), tostring(ob), ax or -1, ay or -1, cx, cy, onPoint and "on it" or "NOT on it", shown and "still showing" or "not showing",
        stayed and "did not move" or "MOVED")
end

-- B352: the point changed: icons move, X / Y unchanged
local function SetupPoint()
    local ns, g = NS(), Group()
    if not g then error("press Do it for me in step 1 first") end
    if ns.SetPreview then ns.SetPreview(Members(g), "visual", true) end
    st.xy = { g.cX or 0, g.cY or 0 }
    g.cPoint = "TOPRIGHT"
    Refresh()
end
local function CheckPoint()
    local g = Group()
    if not (g and st.xy) then return nil, "press Do it for me first" end
    if g.cPoint ~= "TOPRIGHT" then return nil, "This group's anchor point is not Top right: press Do it for me again" end
    local _, _, r, t, n = Drawn(Members(g))
    if not r then return nil, "the sample displays are not on screen" end
    local cx, cy = Centre()
    local px, py = cx + (g.cX or 0), cy + (g.cY or 0)
    local same = (g.cX or 0) == st.xy[1] and (g.cY or 0) == st.xy[2]
    local ok = Near(r, px) and Near(t, py) and same
    return ok, ("%d displays; their top-right at (%.1f, %.1f), the point at (%.1f, %.1f): %s. X / Y %s (%s, %s)."):format(n, r, t, px, py,
        (Near(r, px) and Near(t, py)) and "on it" or "NOT on it", same and "unchanged" or "CHANGED", tostring(g.cX or 0), tostring(g.cY or 0))
end

-- B353: what the one-time update adjusted (data capture; her answer)
local function CheckUpdate()
    local ns = NS()
    local S = ns and ns.Settings and ns.Settings("core")
    if not S then return nil, "XayaUI Rules' saved data is not readable" end
    local list = {}
    for _, e in ipairs(S.groupAnchorMoved or {}) do
        list[#list + 1] = ("%s (%s, %s: X %+.2f, Y %+.2f)"):format(tostring(e.name), tostring(e.point), tostring(e.kind), tonumber(e.dx) or 0, tonumber(e.dy) or 0)
    end
    return nil, ("Update done: %s. Groups whose X / Y were adjusted once: %s."):format(S.groupAnchorVer == 1 and "yes" or "NO",
        #list > 0 and table.concat(list, "; ") or "none (no Auto group had a point other than Center)")
end

-- B354: anchor the QA test group to the QA anchor target through the picker
local function Box() return rawget(_G, "XayaUIGroupPosPopup") end
local function SetupPick()
    local ns, g, t = NS(), Group(), Target()
    if not (g and t) then error("press Do it for me in step 1 first") end
    g.cRel, g.cGroup, g.cFrame, g.cPoint, g.cRelPoint = nil, nil, nil, nil, nil
    g.cX, g.cY = 0, 0
    t.cX, t.cY = 200, 0
    if ns.SetPreview then ns.SetPreview(Members(g), "visual", true) end
    Refresh()
    if not ns.unlocked and ns.ToggleUnlock then ns.ToggleUnlock(); st.unlockedByUs = true end
    local tag = ns.GroupTagFor and ns.GroupTagFor(g.id)
    if not (tag and tag:GetScript("OnMouseUp")) then error("the QA test group's tab is not on screen") end
    tag:GetScript("OnMouseUp")(tag, "RightButton")
    local p = Box()
    if p then
        for _, k in ipairs({ p:GetChildren() }) do
            if k.GetObjectType and k:GetObjectType() == "Button" and k:GetText() == "Anchor to a frame on screen..." then k:Click() end
        end
    end
    local l, b = Drawn(Members(g))
    st.pickFrom = l and { l, b } or nil
end
local function CheckPick()
    local g, t, p = Group(), Target(), Box()
    if not (g and t and st.pickFrom) then return nil, "press Do it for me first" end
    if g.cRel ~= "group" then return nil, "not anchored to a group yet: point at the QA anchor target's tab and press Shift, then Check" end
    local l, b = Drawn(Members(g))
    local stayed = l and Near(l, st.pickFrom[1]) and Near(b, st.pickFrom[2])
    local text = p and p.anchorText and p.anchorText:GetText() or ""
    local named = text:find("Anchored to group '", 1, true) ~= nil and text:find(TARGET, 1, true) ~= nil
    local ok = g.cGroup == t.id and stayed and named
    return ok, ("Saved: Relative to %s, group %s (%s). The QA test group %s. The X / Y box says: %s"):format(tostring(g.cRel), tostring(g.cGroup),
        g.cGroup == t.id and "the QA anchor target" or "ANOTHER group", stayed and "stayed where it was" or "MOVED", (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
end
local function SetupFollow()
    local g, t = Group(), Target()
    if not (g and t) then error("press Do it for me in step 1 first") end
    local l, b = Drawn(Members(g))
    st.followFrom = l and { l, b } or nil
    t.cX, t.cY = (t.cX or 0) + 40, (t.cY or 0) + 20
    Refresh()
end
local function CheckFollow()
    local g = Group()
    if not (g and st.followFrom) then return nil, "press Do it for me first" end
    if g.cRel ~= "group" then return nil, "the QA test group is not anchored to a group: do the step before first" end
    local l, b = Drawn(Members(g))
    if not l then return nil, "the QA test group's displays are not on screen" end
    local dx, dy = l - st.followFrom[1], b - st.followFrom[2]
    local ok = Near(dx, 40) and Near(dy, 20)
    return ok, ("The QA anchor target moved X +40, Y +20; the QA test group moved X %+.1f, Y %+.1f."):format(dx, dy)
end

-- B355: the settings page's Relative to list and its group list
local function SetupList()
    local ns, g = NS(), Group()
    if not g then error("press Do it for me in step 1 first") end
    if not (ns.LoadOptions and ns.LoadOptions()) then error("the settings window (XayaUI_Options) could not be loaded") end
    -- the group's page, as QAWalks-aspect-ratio.lua opens it: its row in the sidebar's list (a member rule's path without the rule),
    -- as a click there selects it; without a member rule, OptionsApi.EditFolder
    local api = ns.OptionsApi
    if not (api and api.IsOpen and api.IsOpen()) and api and api.Toggle then pcall(api.Toggle) end
    local member = Members(g)[1]
    local a, RE = ACD(), api and api.RuleEditor
    if a and RE and RE.ScopePath and member then
        local okc, ctx = pcall(ns.ReadContext)
        local path = { RE.ScopePath(member, okc and ctx or nil) }; path[#path] = nil
        pcall(a.SelectGroup, a, "CueRules", unpack(path))
    elseif api and api.EditFolder then api.EditFolder(g) end
end
local function CheckList()
    local ns, g, t = NS(), Group(), Target()
    if not (g and t) then return nil, "press Do it for me in step 1 first" end
    local rel = Find(Root(), function(w) local o = OptOf(w); return o and o.name == "Relative to" end)[1]
    if not rel then return nil, "the Relative to list is not on screen: press Do it for me, then the Group tab (Group position)" end
    local o = OptOf(rel)
    local vals = type(o.values) == "function" and o.values() or o.values
    local hasEntry = type(vals) == "table" and vals.group == "Another group"
    local list = Find(Root(), function(w) local x = OptOf(w); return x and x.name == "Group" and x.type == "select" end)[1]
    local lv = list and OptOf(list).values
    if type(lv) == "function" then lv = lv() end
    local selfOut = lv and lv[tostring(g.id)] == nil
    local targetIn = lv and lv[tostring(t.id)] ~= nil
    -- a loop: the QA anchor target may not follow the QA test group while the QA test group follows it
    local loopOut = ns.GroupAnchorAllowed and not ns.GroupAnchorAllowed(t, g)
    local ok = hasEntry and (lv ~= nil) and selfOut and targetIn and loopOut
    return ok, ("Relative to %s 'Another group'. Group list: %s (%s, %s). The QA anchor target can follow the QA test group: %s."):format(
        hasEntry and "has" or "does NOT have", lv and "shown" or "not shown (pick Another group first)", selfOut and "without the group itself" or "LISTS the group itself",
        targetIn and "with the QA anchor target" or "WITHOUT the QA anchor target", loopOut and "no (a loop)" or "YES (a loop)")
end

-- B356: the followed group deleted
local function SetupDelete()
    local ns, g, t = NS(), Group(), Target()
    if not (g and t) then error("press Do it for me in step 1 first") end
    if g.cRel ~= "group" then error("the QA test group is not anchored to the QA anchor target: do step 5 first") end
    local l, b = Drawn(Members(g))
    st.delFrom = l and { l, b } or nil
    if ns.SetPreview then ns.SetPreview(Members(t), "visual", false) end
    if ns.LoadOptions then ns.LoadOptions() end
    if ns.OptionsApi and ns.OptionsApi.DeleteFolderAll then ns.OptionsApi.DeleteFolderAll(t.id) elseif ns.RecycleFolderAll then ns.RecycleFolderAll(t) end
    Refresh()
end
local function CheckDelete()
    local g = Group()
    if not (g and st.delFrom) then return nil, "press Do it for me first" end
    if Target() then return nil, "the QA anchor target is still there: press Do it for me" end
    local l, b = Drawn(Members(g))
    local stayed = l and Near(l, st.delFrom[1]) and Near(b, st.delFrom[2])
    local cleared = g.cRel == nil and g.cGroup == nil
    return (stayed and cleared) and true or false, ("The QA test group %s; its link %s (Relative to %s)."):format(stayed and "stayed where it was" or "MOVED",
        cleared and "is cleared" or "is STILL set", tostring(g.cRel or "the screen"))
end

-- B357 (review of 751da05, item 6): a behaviour to confirm with her (debug-log open point): in a hand-placed Auto group with a corner
-- point the outline's corner stays on the point, so moving the display that makes the outline's edge moves the OTHER displays. The
-- step does it through the mover view's arrow-key path (ns.MoverNudge, 20 px left) and records what moved; she answers (noVerdict).
local function SetupEdge()
    local ns, g = NS(), Group()
    if not g then error("press Do it for me in step 1 first") end
    if not (ns.MoverSelect and ns.MoverNudge) then error("XayaUI Rules has no mover nudge (older than 0.6.81)") end
    g.cRel, g.cGroup, g.cFrame, g.cPoint, g.cRelPoint, g.cX, g.cY = nil, nil, nil, "BOTTOMLEFT", "CENTER", 0, 0
    if ns.SetGroupSizeMode then ns.SetGroupSizeMode(g, "auto") end
    local m = Members(g)
    if #m < 2 then error("the QA test group needs its two sample displays: press Do it for me in step 1 again") end
    if ns.SetPreview then ns.SetPreview(m, "visual", true) end
    Refresh()
    if not ns.unlocked and ns.ToggleUnlock then ns.ToggleUnlock(); st.unlockedByUs = true end
    local edge, other, el, ol
    for _, r in ipairs(m) do
        local l = Drawn({ r })
        if l and (not el or l < el) then edge, el = r, l end
    end
    for _, r in ipairs(m) do if r ~= edge then other = r; ol = Drawn({ r }); break end end
    if not (edge and other and el and ol) then error("the sample displays are not on screen") end
    if not st.edge then st.edge = { rule = edge, x = edge.visual.x, y = edge.visual.y } end
    st.edgeFrom = { edge = el, other = ol, otherRule = other }
    ns.MoverSelect("display", edge)
    ns.MoverNudge(-20, 0)
end
local function CheckEdge()
    local g = Group()
    if not (g and st.edge and st.edgeFrom) then return nil, "press Do it for me first" end
    local el = Drawn({ st.edge.rule })
    local ol = Drawn({ st.edgeFrom.otherRule })
    if not (el and ol) then return nil, "the sample displays are not on screen" end
    local l, b = Drawn(Members(g))
    local cx, cy = Centre()
    return nil, ("The left-most display was nudged 20 px left (its X %s -> %s). On screen it moved X %+.1f; the other display moved X %+.1f. The outline's bottom-left is at (%.1f, %.1f); the group's point (screen centre) at (%.1f, %.1f)."):format(
        tostring(st.edge.x), tostring(st.edge.rule.visual.x), el - st.edgeFrom.edge, ol - st.edgeFrom.other, l or -1, b or -1, cx, cy)
end

local function Done()
    local ns, p = NS(), Box()
    if p then p:Hide() end
    local pk = ns and ns.FramePicker and ns.FramePicker()
    if pk and pk:IsShown() then pk:Hide() end
    if st.unlockedByUs and ns and ns.unlocked then
        if ns.MoverExit then ns.MoverExit("cancel") elseif ns.ToggleUnlock then ns.ToggleUnlock() end
    end
    local g = Group()
    if g and st.orig then for _, k in ipairs(KEYS) do g[k] = st.orig[k] end end
    if st.edge and st.edge.rule.visual then st.edge.rule.visual.x, st.edge.rule.visual.y = st.edge.x, st.edge.y end   -- (B357's nudge)
    local t = Target()
    if t and ns then
        if ns.SetPreview then ns.SetPreview(Members(t), "visual", false) end
        if ns.LoadOptions then ns.LoadOptions() end
        if ns.OptionsApi and ns.OptionsApi.DeleteFolderAll then ns.OptionsApi.DeleteFolderAll(t.id) elseif ns.RecycleFolderAll then ns.RecycleFolderAll(t) end
    end
    if ns then Refresh() end
    st.fid, st.orig, st.firstAt, st.xy, st.pickFrom, st.followFrom, st.delFrom, st.unlockedByUs = nil, nil, nil, nil, nil, nil, nil, nil
    st.edge, st.edgeFrom = nil, nil
end
QA.GroupAnchorsTest = { State = st, Done = Done }   -- (tests)

QA.Register("group-anchors", { title = "Group anchors: the grid's or outline's corner, and following another group (B350-B357)",
    qa = "B350, B351, B352, B353, B354, B355, B356, B357", order = 550, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI makes a group |cffffd100QA anchor target|r (dynamic, growing Right, Size Auto, two sample icons) with |cffffd100This group's anchor point: Bottom left|r on the middle of the screen, X 0, Y 0.\n\n|cffffd100Expect:|r the two icons start exactly at the middle of the screen: the grid's bottom-left corner is on that point (before 0.6.82 they sat about half an icon left of and below it). The check reads where the icons are drawn.",
        setup = SetupGrid, check = CheckGrid },
    { text = "Press |cffffd100Do it for me|r: the |cffffd100QA test group|r (two hand-placed sample displays) gets |cffffd100Bottom left|r on the middle of the screen, then its second display stops showing (as when its conditions are not met).\n\n|cffffd100Expect:|r the outline of both displays has its bottom-left corner on the middle of the screen, and the first display did not move when the second one went away (the outline counts every switched-on display, showing or not).",
        setup = SetupOutline, check = CheckOutline },
    { text = "Press |cffffd100Do it for me|r: both displays show again and the QA test group's anchor point becomes |cffffd100Top right|r (as picking it on the Group tab does).\n\n|cffffd100Expect:|r the displays move: the outline's top-right corner is now on the middle of the screen. X / Y offset stay the same.",
        setup = SetupPoint, check = CheckPoint },
    { text = "This one is about YOUR groups. At your first login with this version, XayaUI adjusted the X / Y of every group with Size Auto and an anchor point other than Center once, so it stays where it was (the chat said how many). Press |cffffd100Check|r: the note lists those groups and what was added to their X / Y.\n\n|cffffd100Question:|r did any of your groups move on screen after the update? Answer in the note (Pass = nothing moved).",
        check = CheckUpdate, noVerdict = true },
    { text = "Press |cffffd100Do it for me|r: the mover view opens, the QA test group's |cffffd100X / Y box|r opens and |cffffd100Anchor to a frame on screen...|r starts.\n\nNow point at the |cffffd100QA anchor target|r's tab (or between its icons) and press |cffffd100Shift|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r while the banner shows, every group's tab is shown; pointing at the QA anchor target outlines it in green with its name; pointing at the QA test group itself outlines nothing. After Shift the QA test group stays where it is and its box says |cffffd100Anchored to group 'QA anchor target'|r.",
        setup = SetupPick, check = CheckPick },
    { text = "Press |cffffd100Do it for me|r: the QA anchor target moves 40 right and 20 up.\n\n|cffffd100Expect:|r the QA test group moves with it, by the same amount.",
        setup = SetupFollow, check = CheckFollow },
    { text = "Press |cffffd100Do it for me|r: the settings window opens on the QA test group's page; click the |cffffd100Group|r tab and find |cffffd100Group position|r.\n\n|cffffd100Expect:|r Relative to reads |cffffd100Another group|r, and under it a |cffffd100Group|r list with QA anchor target (and your other groups) but not QA test group itself. On the QA anchor target's own page the list would not offer QA test group (that would be a loop).",
        setup = SetupList, check = CheckList },
    { text = "Press |cffffd100Do it for me|r: the QA anchor target is deleted (it goes to the Recycle Bin with its two sample rules).\n\n|cffffd100Expect:|r the QA test group stays exactly where it is, and is placed from the screen again (its box: Anchored to the screen).",
        setup = SetupDelete, check = CheckDelete },
    { text = "A question for you (how it behaves now, to confirm). Press |cffffd100Do it for me|r: the QA test group gets |cffffd100Bottom left|r on the middle of the screen again (Size Auto), the mover view opens, and its LEFT-most display is nudged 20 px left (as 20 presses of the Left arrow key).\n\n|cffffd100What you will see:|r the outline's bottom-left corner stays on the point, so the display you moved stays where it was and the OTHER display moves 20 px right. Dragging it does the same when you let go; in a group with one display the display does not move at all. Moving a display that is not at the outline's edge moves only that display. The note records what moved.\n\n|cffffd100Question:|r is this what you want? Or should moving a display at the edge keep the others where they are (the group's X / Y would change instead)? Answer in the note.",
        setup = SetupEdge, check = CheckEdge, noVerdict = true },
    { text = "Press |cffffd100Do it for me|r to put the QA test group's position back, delete the QA anchor target if it is still there, close the box and leave the mover view (Cancel moves) if this walkthrough opened it. Then |cffffd100Done|r.", done = true, setup = Done },
} })
