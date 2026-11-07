-------------------------------------------------------------------------------
-- QAWalks-chat.lua (XayaUI_DevAssist 0.7.13): in-game QA walkthroughs for the old chat issues #210, #229 (items 1-4), #250 and #296,
-- checked against the rebuilt Chat Panel (XayaUI_Chat). REQUEST-LOG A14, CHATREV-1 / CHATREV-6.
-- Xaya, 2026-11-06 (her words): "ensure qa has a handler that can automatically generate an answer"; scope "For every issue here";
-- how the answer is recorded, her answer: "Pre-fill, I confirm" (the addon's verdict is offered on one button, Accept; nothing is
-- recorded without her click). These walkthroughs set prefill = true (QAWalk.lua).
-- Each check reads the real frames (place, size, shown, alpha, parent, scale) and returns its verdict. What only a person can see
-- (a clipped chevron, a ghost outline) is checked as far as the frames tell, and the step says plainly what is left for the eyes.
-- Every walkthrough remembers the Chat Panel settings it changes in its first step and puts them back in its last step.
-- Listed in XayaUI_DevAssist.toc after QAWalks.lua; does nothing without the framework or with XayaUI Chat not loaded. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
-- XayaUI_Chat is reached only through its service (Modules.lua ns.Service; Chat Core.lua provides "chatDebug" = { C, Settings })
local function Svc() local ns = NS(); return ns and ns.Service and ns.Service("chatDebug") end
local function Ch() local sv = Svc(); return sv and sv.C end
local function S() local sv = Svc(); return sv and sv.Settings and sv.Settings() end
local function Secret(v) local C = Ch(); return C and C.IsSecret and C.IsSecret(v) end

-- a frame's place and size in screen pixels (nil when the game does not give it)
local function Rect(f)
    if not (f and f.GetLeft) then return nil end
    local ok, l, b, w, h = pcall(function() return f:GetLeft(), f:GetBottom(), f:GetWidth(), f:GetHeight() end)
    if not ok then return nil end
    for _, v in ipairs({ l, b, w, h }) do if type(v) ~= "number" or Secret(v) then return nil end end
    return { l = l, b = b, w = w, h = h, r = l + w, t = b + h }
end
local function Near(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 1) end
local function Shown(f) if not (f and f.IsShown) then return false end local ok, v = pcall(f.IsShown, f); return ok and v and true or false end
local function Alpha(f) if not (f and f.GetAlpha) then return nil end local ok, v = pcall(f.GetAlpha, f); if ok and type(v) == "number" and not Secret(v) then return v end end
local function Overlap(a, b) return a and b and a.l < b.r - 0.5 and b.l < a.r - 0.5 and a.b < b.t - 0.5 and b.b < a.t - 0.5 end
local function Fmt(rc) return rc and ("%d,%d %dx%d"):format(rc.l, rc.b, rc.w, rc.h) or "?" end

-- "is the Chat Panel there?" (every check starts here: with it off nothing below can be read)
local function Ready()
    local C = Ch()
    if not C then return false, "XayaUI Chat is not loaded" end
    if not (C.On and C.On()) then return false, "the Chat Panel is off (Blizzard UI Reskin > Chat Panel tick box)" end
    if not (C.Container and C.Container()) then return false, "the Chat Panel has not been built yet" end
    return true
end

-- settings these walkthroughs change, remembered at the start and put back at the end
local KEYS = { "x", "y", "point", "width", "height", "collapsed", "barOn", "barSide", "stripMode", "fadeBar" }
local saved, putBack   -- putBack: the last step ran, so a new walkthrough must remember again
local function Remember() local s = S(); if not s then return end; saved, putBack = {}, false; for _, k in ipairs(KEYS) do saved[k] = s[k] end end
local function PutBack()
    local s, C = S(), Ch()
    if not (s and saved) then return end
    for _, k in ipairs(KEYS) do s[k] = saved[k] end
    putBack = true
    if C.unlocked and C.ToggleMover then C.ToggleMover() end
    if C.Layout then C.Layout() end
end
local function PutBackStep()
    return { text = "Last step: press |cffffd100Do it for me|r to put your chat back as it was before this walkthrough (place, size, Chat Data Panel, button strip, hidden or shown). Then Accept or Pass.",
        setup = PutBack,
        check = function()
            local s = S()
            if not saved then return false, "nothing was remembered (run the walkthrough from its first step)" end
            for _, k in ipairs(KEYS) do if s[k] ~= saved[k] then return false, "not put back yet: " .. k end end
            return true, "every setting is back as it was"
        end }
end
local function Start(text, extra)
    return { text = text, setup = function() Remember(); local C = Ch(); if C and C.SetCollapsed and C.IsCollapsed() then C.SetCollapsed(false) end; if extra then extra() end end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local have = saved ~= nil and not putBack
            return have, have and "the Chat Panel is on; your settings are remembered" or "press Do it for me first"
        end }
end

-- the collapse arrow and what the chat looks like hidden / shown
local function Arrow() return rawget(_G, "XayaUIChatArrow") end
local function HiddenCheck()
    local ok, why = Ready(); if not ok then return false, why end
    local C = Ch()
    local cf, pane, arrow = C.Main(), C.Pane(), Arrow()
    local a = Alpha(cf)
    if not C.IsCollapsed() then return false, "the chat is not hidden yet" end
    if Shown(pane) then return false, "the pane is still shown" end
    if not (a and a < 0.02) then return false, "the chat text is still visible (alpha " .. tostring(a) .. ")" end
    if not Shown(arrow) then return false, "the arrow is gone: there is no way to bring the chat back" end
    return true, "hidden: pane off, chat text invisible, arrow still there"
end
local function ShownCheck()
    local ok, why = Ready(); if not ok then return false, why end
    local C = Ch()
    local cf, pane = C.Main(), C.Pane()
    local a = Alpha(cf)
    if C.IsCollapsed() then return false, "the chat is still hidden" end
    if not Shown(pane) then return false, "the pane is not shown" end
    if not (a and a > 0.05) then return false, "the chat text is still invisible (alpha " .. tostring(a) .. ")" end
    return true, ("shown again: pane on, chat text alpha %.2f"):format(a)
end

-------------------------------------------------------------------------------
-- #210: the mover and the collapse arrow
-------------------------------------------------------------------------------
local before   -- the chat block's place and size when the mover opened
QA.Register("chat-210-mover-collapse", { title = "Chat: move, resize and hide the chat (#210)", qa = "#210, D21", order = 230, prefill = true, steps = {
    Start("Press |cffffd100Do it for me|r: XayaUI remembers your chat's place, size and settings (the last step puts them back) and makes sure the chat is shown.\n\n|cffffd100Expect:|r the addon's check says the Chat Panel is on."),
    { text = "Press |cffffd100Do it for me|r (or type |cffffd100/xui chat move|r).\n\n|cffffd100Expect:|r a dark blue box covers the whole chat block, saying \"Chat Panel <width> x <height>\", with a small white square at its top-right corner.",
        setup = function() local C = Ch(); before = Rect(C.Container()); if not C.unlocked then C.ToggleMover() end end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local C = Ch(); local mv = rawget(_G, "XayaUIChatMover")
            if not (C.unlocked and Shown(mv)) then return false, "the mover box is not showing" end
            local m, c = Rect(mv), Rect(C.Container())
            if not (m and c) then return false, "the game did not give the box's size" end
            local same = Near(m.l, c.l) and Near(m.b, c.b) and Near(m.w, c.w) and Near(m.h, c.h)
            return same, same and ("the box covers the chat block exactly (%s)"):format(Fmt(c)) or ("box %s, chat block %s"):format(Fmt(m), Fmt(c))
        end },
    { text = "Drag the blue box to another place on the screen and let go. Then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the whole chat (tabs, text, the line you type in, the Chat Data Panel) moves with the box and stays where you let go.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local C, s = Ch(), S()
            local c = Rect(C.Container())
            if not (c and before) then return false, "press Do it for me on the step before first" end
            if Near(c.l, before.l, 0.5) and Near(c.b, before.b, 0.5) then return false, "the chat has not moved yet" end
            local saveOk = Near(tonumber(s.x), c.l) and Near(tonumber(s.y), c.b)
            local glued = (C.Glued == nil) or C.Glued()
            return saveOk and glued, ("moved from %d,%d to %d,%d; saved place %s; chat window %s"):format(before.l, before.b, c.l, c.b,
                saveOk and "matches" or ("is " .. tostring(s.x) .. "," .. tostring(s.y)), glued and "inside the panel" or "NOT inside the panel")
        end },
    { text = "Drag the small white square at the box's top-right corner to make the chat bigger or smaller, and let go. Then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the chat grows or shrinks with the mouse; the box's label shows the new size.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local C, s = Ch(), S()
            local p = Rect(C.Pane())
            if not (p and saved) then return false, "press Do it for me on step 1 first" end
            if s.width == saved.width and s.height == saved.height then return false, "the size has not changed yet" end
            local match = Near(p.w, tonumber(s.width)) and Near(p.h, tonumber(s.height))
            return match, ("size %s x %s (was %s x %s); the pane %s"):format(tostring(s.width), tostring(s.height), tostring(saved.width), tostring(saved.height),
                match and "is that size" or ("is " .. Fmt(p)))
        end },
    { text = "Press |cffffd100Do it for me|r (or type |cffffd100/xui chat move|r again).\n\n|cffffd100Expect:|r the blue box goes away; the chat stays at its new place and size.",
        setup = function() local C = Ch(); if C.unlocked then C.ToggleMover() end end,
        check = function()
            local C = Ch(); if not C then return false, "XayaUI Chat is not loaded" end
            local mv = rawget(_G, "XayaUIChatMover")
            local off = not C.unlocked and not Shown(mv)
            return off, off and "the mover is closed" or "the mover is still open"
        end },
    { text = "Click the small arrow at the start of the Chat Data Panel (or under the chat's corner when the panel is off), or press |cffffd100Do it for me|r.\n\n|cffffd100Expect:|r the chat hides; only the panel (or the arrow) stays. The arrow now points up.",
        setup = function() local C = Ch(); C.SetCollapsed(true) end, check = HiddenCheck },
    { text = "Click the arrow again (or press |cffffd100Do it for me|r).\n\n|cffffd100Expect:|r the chat is back exactly as before, with its text.",
        setup = function() local C = Ch(); C.SetCollapsed(false) end, check = ShownCheck },
    PutBackStep(),
} })

-------------------------------------------------------------------------------
-- #229 items 1-4: the arrow, Blizzard's button strip, the panel below the chat, the bottom of the screen
-------------------------------------------------------------------------------
local function StripCheck(mode)
    return function()
        local ok, why = Ready(); if not ok then return false, why end
        local C = Ch()
        local bf = C.ButtonFrameOf(C.Main())
        if not bf then return false, "the game has no button strip on this client (ChatFrame1ButtonFrame not found)" end
        local c, b = Rect(C.Container()), Rect(bf)
        if mode == "HIDE" then return not Shown(bf), Shown(bf) and "the strip is still showing" or "the strip is hidden" end
        if not Shown(bf) then return false, "the strip is not showing" end
        if not (c and b) then return false, "the game did not give the strip's place" end
        local outside = (mode == "LEFT") and b.r <= c.l + 0.5 or (mode == "RIGHT") and b.l >= c.r - 0.5
        return outside, ("strip %s, chat block %s: %s"):format(Fmt(b), Fmt(c), outside and ("outside, on the " .. mode:lower()) or "it overlaps the chat")
    end
end
local function SetStrip(mode) return function() local s, C = S(), Ch(); s.stripMode = mode; C.Layout() end end

QA.Register("chat-229-pieces", { title = "Chat: arrow, button strip, panel, bottom edge (#229 items 1-4)", qa = "#229, D21", order = 231, prefill = true, steps = {
    Start("Press |cffffd100Do it for me|r: XayaUI remembers your chat settings (the last step puts them back), shows the chat and turns the Chat Data Panel on, below the chat.",
        function() local s, C = S(), Ch(); s.barOn, s.barSide = true, "BOTTOM"; C.Layout() end),
    { text = "Look at the small arrow at the left end of the Chat Data Panel.\n\n|cffffd100Expect:|r a whole \"v\" shape, not cut off, not covered by Blizzard's buttons. The addon checks its size, that it sits inside the panel and that nothing of Blizzard's covers it; whether the chevron looks whole is for your eyes.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local C = Ch(); local ar, bar = Arrow(), C.Bar()
            local a, b = Rect(ar), Rect(bar)
            if not (Shown(ar) and a) then return false, "the arrow is not showing" end
            if not (ar.l1 and ar.l2) then return false, "the arrow has no drawn lines" end
            local inside = b and a.l >= b.l - 0.5 and a.r <= b.r + 0.5 and a.b >= b.b - 0.5 and a.t <= b.t + 0.5
            local bf = C.ButtonFrameOf(C.Main())
            local covered = Shown(bf) and Overlap(a, Rect(bf))
            return (inside and not covered) and true or false, ("arrow %s inside the panel %s; %s"):format(Fmt(a), inside and "(yes)" or "(NO)",
                covered and "Blizzard's button strip overlaps it" or "nothing of Blizzard's overlaps it")
        end },
    { text = "Press |cffffd100Do it for me|r: Blizzard's button strip is set to |cffffd100Right of chat|r.\n\n|cffffd100Expect:|r the column of small buttons (chat menu, channels, voice) sits just right of the chat, not over it.",
        setup = SetStrip("RIGHT"), check = StripCheck("RIGHT") },
    { text = "Press |cffffd100Do it for me|r: the strip is set to |cffffd100Left of chat|r.\n\n|cffffd100Expect:|r the buttons sit just left of the chat.",
        setup = SetStrip("LEFT"), check = StripCheck("LEFT") },
    { text = "Press |cffffd100Do it for me|r: the strip is set to |cffffd100Hidden|r.\n\n|cffffd100Expect:|r the buttons are gone.",
        setup = SetStrip("HIDE"), check = StripCheck("HIDE") },
    { text = "Look at the Chat Data Panel under the chat.\n\n|cffffd100Expect:|r a bar as wide as the chat, right under it, with data blocks (time, FPS ...). Right-click a block: the settings open on the Chat Data Panel page.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local C = Ch(); local bar, pane = C.Bar(), C.Pane()
            local b, p = Rect(bar), Rect(pane)
            if not (Shown(bar) and b and p) then return false, "the Chat Data Panel is not showing" end
            local wide, under = Near(b.w, p.w), b.t <= p.b + 0.5
            return wide and under, ("panel %s, chat %s: %s, %s"):format(Fmt(b), Fmt(p), wide and "as wide as the chat" or "NOT as wide",
                under and "under it" or "NOT under it")
        end },
    { text = "Press |cffffd100Do it for me|r: the chat is moved down to the very bottom of the screen.\n\n|cffffd100Expect:|r the chat block's bottom edge touches the screen's bottom edge, and the chat text is inside the panel (not pushed up or sideways).",
        setup = function() local s, C = S(), Ch(); s.point, s.y = "BOTTOMLEFT", 0; C.Layout() end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local C = Ch(); local c = Rect(C.Container())
            if not c then return false, "the game did not give the chat's place" end
            local bottom = Near(c.b, 0, 1)
            local glued = (C.Glued == nil) or C.Glued()
            local clamped = C.Clamped and C.Clamped(C.Main())
            return bottom and glued and not clamped, ("chat block bottom at %d px; chat window %s; game clamp %s"):format(c.b,
                glued and "inside the panel" or "NOT inside the panel", clamped and "ON (pushes it off)" or "off")
        end },
    PutBackStep(),
} })

-------------------------------------------------------------------------------
-- #250: hiding the chat must not resize the panel or leave outlines
-------------------------------------------------------------------------------
local shot   -- sizes and parents before hiding
local BORDER = { "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture", "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }
local function BorderShown()
    local C, out = Ch(), {}
    for _, f in ipairs(C.Frames()) do
        if f == C.Main() or f.isDocked then
            local n = C.NameOf(f)
            for _, suf in ipairs(BORDER) do if Shown(_G[n .. suf]) then out[#out + 1] = n .. suf end end
        end
    end
    return out
end
local function Snapshot()
    local C = Ch()
    local cf = C.Main()
    local okP, parent = pcall(cf.GetParent, cf)
    local bar = C.Bar()
    return { cont = Rect(C.Container()), bar = Rect(bar), parent = okP and parent or nil,
        barScale = bar and bar.GetEffectiveScale and bar:GetEffectiveScale(), contScale = C.Container():GetEffectiveScale() }
end
local function SameAsBefore(label)
    return function()
        local ok, why = Ready(); if not ok then return false, why end
        if not shot then return false, "press Do it for me on the step before first" end
        local now, bad = Snapshot(), {}
        if not (now.cont and shot.cont and Near(now.cont.w, shot.cont.w, 0.5) and Near(now.cont.h, shot.cont.h, 0.5) and Near(now.cont.l, shot.cont.l, 0.5) and Near(now.cont.b, shot.cont.b, 0.5)) then
            bad[#bad + 1] = ("chat block %s, was %s"):format(Fmt(now.cont), Fmt(shot.cont)) end
        if shot.bar and not (now.bar and Near(now.bar.w, shot.bar.w, 0.5) and Near(now.bar.h, shot.bar.h, 0.5)) then
            bad[#bad + 1] = ("panel %s, was %s"):format(Fmt(now.bar), Fmt(shot.bar)) end
        if now.parent ~= shot.parent then bad[#bad + 1] = "the chat window was moved to another parent frame" end
        if now.barScale and now.contScale and not Near(now.barScale, now.contScale, 0.001) then bad[#bad + 1] = ("panel scale %.3f, chat %.3f"):format(now.barScale, now.contScale) end
        local border = BorderShown()
        if #border > 0 then bad[#bad + 1] = "Blizzard border pieces showing: " .. table.concat(border, ", ", 1, math.min(3, #border)) end
        if #bad > 0 then return false, table.concat(bad, "; ") end
        return true, label .. ": same size, place, parent and scale as before; no Blizzard border pieces showing"
    end
end

QA.Register("chat-250-collapse-size", { title = "Chat: hiding it keeps the panel's size, no outlines (#250)", qa = "#250, D21", order = 232, prefill = true, steps = {
    Start("Press |cffffd100Do it for me|r: XayaUI remembers your chat settings, shows the chat and turns the Chat Data Panel on, below the chat.",
        function() local s, C = S(), Ch(); s.barOn, s.barSide = true, "BOTTOM"; C.Layout() end),
    { text = "Press |cffffd100Do it for me|r: the chat is hidden with its arrow (the addon notes the sizes first).\n\n|cffffd100Expect:|r the Chat Data Panel keeps exactly its size and place, and no empty rectangles or outlines are left where the chat was. The addon checks sizes, parents, scale and Blizzard's border pieces; ghost outlines from anything else are for your eyes.",
        setup = function() local C = Ch(); if C.IsCollapsed() then C.SetCollapsed(false) end; shot = Snapshot(); C.SetCollapsed(true) end,
        check = function()
            local okH, whyH = HiddenCheck(); if not okH then return false, whyH end
            return SameAsBefore("hidden")()
        end },
    { text = "Press |cffffd100Do it for me|r: the chat is shown again.\n\n|cffffd100Expect:|r the chat and its panel look exactly as before hiding.",
        setup = function() local C = Ch(); C.SetCollapsed(false) end,
        check = function()
            local okS, whyS = ShownCheck(); if not okS then return false, whyS end
            return SameAsBefore("shown again")()
        end },
    PutBackStep(),
} })

-------------------------------------------------------------------------------
-- #296: one arrow; the panel follows the chat. Xaya decides what "inherit the same behavior" means after this (her answer: "Have qa
-- handler test behavior and then decide").
-------------------------------------------------------------------------------
local moved   -- the panel's place before the chat is moved
QA.Register("chat-296-panel-follows", { title = "Chat: one arrow; the panel follows the chat (#296)", qa = "#296, D21", order = 233, prefill = true, steps = {
    Start("Press |cffffd100Do it for me|r: XayaUI remembers your chat settings, shows the chat and turns the Chat Data Panel on, below the chat.",
        function() local s, C = S(), Ch(); s.barOn, s.barSide = true, "BOTTOM"; C.Layout() end),
    { text = "Look at both ends of the Chat Data Panel.\n\n|cffffd100Expect:|r one arrow, at the left end. No arrow at the right end or floating beside the chat.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local C = Ch(); local a, b = Rect(Arrow()), Rect(C.Bar())
            local old = rawget(_G, "XayaUIChatCollapse")   -- the old chat's arrow (ChatDock.lua, before the rebuild #297)
            if Shown(old) then return false, "the old chat's arrow (XayaUIChatCollapse) is showing" end
            if not (a and b) then return false, "the arrow or the panel is not showing" end
            local left = Near(a.l, b.l, 1)
            return left, left and "one arrow, at the panel's left end; the old floating arrow does not exist" or ("arrow %s, panel %s: not at the left end"):format(Fmt(a), Fmt(b))
        end },
    { text = "Press |cffffd100Do it for me|r: the chat is moved 40 pixels right.\n\n|cffffd100Expect:|r the panel moves with it, still right under the chat.",
        setup = function() local s, C = S(), Ch(); moved = Rect(C.Bar()); local c = Rect(C.Container()); if c then s.point, s.x, s.y = "BOTTOMLEFT", math.floor(c.l + 40 + 0.5), math.floor(c.b + 0.5) end; C.Layout() end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local C = Ch(); local b, p = Rect(C.Bar()), Rect(C.Pane())
            if not (moved and b and p) then return false, "press Do it for me first" end
            local follow = Near(b.l - moved.l, 40, 1) and Near(b.l, p.l, 1)
            return follow, ("panel moved %d px (chat moved 40); %s"):format(b.l - moved.l, Near(b.l, p.l, 1) and "lined up with the chat" or "NOT lined up with the chat")
        end },
    { text = "Press |cffffd100Do it for me|r: the chat is hidden with its arrow.\n\n|cffffd100Expect (today's design, your UI-20 answer):|r the panel stays on screen and drops to where the chat's bottom was. The addon reports what it sees; whether that is what you want is your call in the next step.",
        setup = function() Ch().SetCollapsed(true) end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local C = Ch(); local bar = C.Bar()
            local stays = Shown(bar) and (Alpha(bar) or 0) > 0.05
            return stays, stays and "the panel stays on screen while the chat is hidden" or "the panel hid with the chat"
        end },
    { text = "Fading: with |cffffd100Fade the chat when it is idle|r on, the panel fades with the chat only when |cffffd100Fade the Chat Data Panel too|r is ticked (Chat Panel > Fade and hide). The addon reports the current setting.\n\n|cffffd100Your call (write it in the note):|r should the panel \"inherit the same behavior of the chat\" by hiding with it, fading with it by default, both, or stay as it is? Then press Pass to record your answer.",
        noVerdict = true,   -- her decision, not a check: no Accept button
        setup = function() Ch().SetCollapsed(false) end,
        check = function()
            local s = S(); if not s then return false, "XayaUI Chat is not loaded" end
            return true, ("Fade the Chat Data Panel too is %s; idle fade is %s"):format(s.fadeBar and "ticked" or "unticked (the default)", s.fadeOn and "on" or "off")
        end },
    PutBackStep(),
} })

-------------------------------------------------------------------------------
-- (Dev Assist 0.7.13, Chat 0.6.31; REQUEST-LOG A14 CHATREV-10 / CHATREV-11; standing rule V22) the whisper-tab switch and the Chat Panel
-- settings laid out from Xaya's #246 words. Both with pre-fill; the timestamp step remembers and puts back the game's setting.
-------------------------------------------------------------------------------
local function CVar(n) local cv = rawget(_G, "C_CVar"); local ok, v = pcall(function() return cv.GetCVar(n) end); if ok and type(v) == "string" and not Secret(v) then return v end end
local function SelectedWindow()
    local dock = rawget(_G, "GENERAL_CHAT_DOCK")
    local get = rawget(_G, "FCFDock_GetSelectedWindow")
    if not (dock and type(get) == "function") then return nil end
    local ok, f = pcall(get, dock)
    return ok and f or nil
end
local MODE_NAME = { popout = "New Tab", popout_and_inline = "Both", inline = "In-line" }

QA.Register("chat-whisper-switch", { title = "Chat: a whisper tab you start opens (CHATREV-10)", qa = "D24", order = 234, prefill = true, steps = {
    { text = "This checks the new tick box |cffffd100Switch to a new whisper tab I start|r (Chat Panel > Chat Tabs > Whisper tabs) and the game's own setting Options > Social > |cffffd100New Whispers|r.\n\n|cffffd100Expect:|r the tick box is on (the default) and New Whispers is Both or New Tab.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local s, C = S(), Ch()
            local m = CVar("whisperMode")
            local on = s.whisperSelect and C.on and C.on.whisperSelect
            return (on and (m == "popout" or m == "popout_and_inline")) and true or false,
                ("tick box %s; New Whispers: %s"):format(on and "on" or "OFF", MODE_NAME[m] or tostring(m))
        end },
    { text = "Stay on the |cffffd100General|r tab. Whisper someone you have |cffffd100no whisper tab with yet|r (a friend, or /w yourself). Then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r a new tab with their name opens and the chat switches to it, showing your whisper.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local f = SelectedWindow()
            if not f then return false, "the game did not say which tab is selected" end
            local isW = f.chatType == "WHISPER" or f.chatType == "BN_WHISPER"
            return isW and true or false, isW and ("the selected tab is a %s whisper tab"):format(f.chatType == "BN_WHISPER" and "Battle.net" or "character")
                or "the selected tab is not a whisper tab"
        end },
    { text = "Click |cffffd100General|r again, then reply in General to the same person (/r).\n\n|cffffd100Expect:|r the chat stays on General (a whisper to someone who already has a tab never pulls you away).",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local f = SelectedWindow()
            if not f then return false, "the game did not say which tab is selected" end
            local stay = not (f.chatType == "WHISPER" or f.chatType == "BN_WHISPER")
            return stay, stay and "still on a non-whisper tab" or "it switched to the whisper tab"
        end },
} })

local tsBefore
local function Tree() local sv = Svc(); local ok, t = pcall(function() return sv.Options() end); return ok and t or nil end
local function Kids(t)
    local list = {}
    for _, v in pairs(t and t.args or {}) do if type(v) == "table" and v.type == "group" then list[#list + 1] = v end end
    table.sort(list, function(a, b) return (tonumber(a.order) or 0) < (tonumber(b.order) or 0) end)
    local n = {}
    for _, v in ipairs(list) do n[#n + 1] = tostring(v.name) end
    return table.concat(n, " | "), list
end
QA.Register("chat-settings-layout", { title = "Chat: settings laid out as asked in #246 (CHATREV-11)", qa = "#246, D24", order = 235, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings open on Blizzard UI Reskin > Chat Panel > |cffffd100General|r.\n\n|cffffd100Expect:|r under Chat Panel in the left pane: General, Chat Tabs, Layout, Chat Data Panel, Filters, Sounds, Privacy (no Appearance, Fade and hide or History).",
        setup = function() local C = Ch(); if C and C.OpenSettings then C.OpenSettings("general") end end,
        check = function()
            local t = Tree(); if not t then return false, "the Chat Panel's settings could not be read" end
            local names = Kids(t)
            local want = "General | Chat Tabs | Layout | Chat Data Panel | Filters | Sounds | Privacy"
            return names == want, "parts: " .. names
        end },
    { text = "Look at the tabs across the top of General.\n\n|cffffd100Expect:|r Font options, Color + display options, Scroll and fade options, Chat history, and Timestamp, copying, and links, in that order. Click through them: each has its settings.",
        check = function()
            local t = Tree(); local g = t and t.args and t.args.general
            if not g then return false, "no General page" end
            local names = Kids(g)
            local want = "Font options | Color + display options | Scroll and fade options | Chat history | Timestamp, copying, and links"
            return names == want, "tabs: " .. names
        end },
    { text = "Click |cffffd100Chat Tabs|r in the left pane.\n\n|cffffd100Expect:|r the tab row's settings (show, height, font, colors, backgrounds) and a Whisper tabs section with |cffffd100Switch to a new whisper tab I start|r.",
        setup = function() local C = Ch(); if C and C.OpenSettings then C.OpenSettings("tabs") end end,
        check = function()
            local t = Tree(); local p = t and t.args and t.args.tabs
            if not p then return false, "no Chat Tabs page" end
            local found = false
            local function walk(x) for k, v in pairs(x.args or {}) do if k == "whisperSelect" then found = true end; if type(v) == "table" and v.type == "group" then walk(v) end end end
            walk(p)
            return found, found and ("Chat Tabs page: " .. Kids(p)) or "the whisper switch is not on the Chat Tabs page"
        end },
    { text = "Press |cffffd100Do it for me|r: Timestamps (General > Timestamp, copying, and links) is set to 24-hour hours and minutes; your own setting is remembered. Then say something in chat.\n\n|cffffd100Expect:|r your new line starts with the time, like \"15:27\". Options > Social > Chat Timestamps shows the same choice.",
        setup = function()
            local cv = rawget(_G, "C_CVar"); tsBefore = tsBefore or CVar("showTimestamps") or "none"
            local fmt = rawget(_G, "TIMESTAMP_FORMAT_HHMM_24HR") or "%H:%M "
            pcall(function() cv.SetCVar("showTimestamps", fmt) end)
        end,
        check = function()
            local v = CVar("showTimestamps")
            local want = rawget(_G, "TIMESTAMP_FORMAT_HHMM_24HR") or "%H:%M "
            return v == want, "the game's Chat Timestamps setting is " .. tostring(v)
        end },
    { text = "Last step: press |cffffd100Do it for me|r to put your Chat Timestamps setting back as it was.",
        setup = function() local cv = rawget(_G, "C_CVar"); if tsBefore then pcall(function() cv.SetCVar("showTimestamps", tsBefore) end) end end,
        check = function()
            if not tsBefore then return false, "nothing was remembered (run step 4 first)" end
            local v = CVar("showTimestamps")
            return v == tsBefore, "Chat Timestamps is " .. tostring(v) .. " (was " .. tostring(tsBefore) .. ")"
        end },
} })

-- #430 (from #229 item 5, "Clicking the chat box in mover mode should open exact X/Y entry + cardinal arrows"; Chat 0.6.31)
local yMark
QA.Register("chat-position-box", { title = "Chat: exact X / Y position from the mover (#430)", qa = "#430, D24", order = 236, prefill = true, steps = {
    Start("Press |cffffd100Do it for me|r: XayaUI remembers your chat's place and settings (the last step puts them back)."),
    { text = "Type |cffffd100/xui chat move|r and |cffffd100click|r the blue box once without dragging (or press |cffffd100Do it for me|r).\n\n|cffffd100Expect:|r a small \"Chat position\" box above the chat with X and Y filled in, and four arrow buttons.",
        setup = function() local C = Ch(); if not C.unlocked then C.ToggleMover() end; C.PositionBox_Toggle(true) end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local C, s = Ch(), S(); local b = C.PositionBox and C.PositionBox()
            if not (b and Shown(b)) then return false, "the position box is not showing" end
            local fx, fy = b.x:GetText(), b.y:GetText()
            local filled = tonumber(fx) == tonumber(s.x) and tonumber(fy) == tonumber(s.y)
            return filled, ("box shows X %s, Y %s (saved place %s, %s)"):format(tostring(fx), tostring(fy), tostring(s.x), tostring(s.y))
        end },
    { text = "In the box, type |cffffd100200|r in X and press Enter.\n\n|cffffd100Expect:|r the chat jumps so its left edge is 200 pixels from the screen's left edge.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local C, s = Ch(), S(); local c = Rect(C.Container())
            local good = s.x == 200 and c and Near(c.l, 200, 1)
            return good and true or false, ("saved X %s; the chat's left edge at %s"):format(tostring(s.x), c and tostring(math.floor(c.l + 0.5)) or "?")
        end },
    { text = "Click the |cffffd100>|r arrow once.\n\n|cffffd100Expect:|r the chat moves 1 pixel right (X reads 201).",
        check = function()
            local s = S(); if not s then return false, "XayaUI Chat is not loaded" end
            yMark = s.y
            return s.x == 201, "X is " .. tostring(s.x)
        end },
    { text = "Hold |cffffd100Shift|r and click the |cffffd100^|r arrow once.\n\n|cffffd100Expect:|r the chat moves 10 pixels up.",
        check = function()
            local s = S(); if not (s and yMark) then return false, "do the step before first" end
            return s.y == yMark + 10, ("Y went from %s to %s"):format(tostring(yMark), tostring(s.y))
        end },
    PutBackStep(),
} })

-- CHATREV-12 (Chat 0.6.31): every chat tab at one height (General / Combat Log and the tabs in the scrolling part of the row)
local function TabMids()
    local dock = rawget(_G, "GeneralDockManager")
    local list = dock and dock.DOCKED_CHAT_FRAMES
    if type(list) ~= "table" then return nil end
    local out = {}
    for _, f in ipairs(list) do
        local okN, n = pcall(f.GetName, f)
        local tab = okN and n and _G[n .. "Tab"]
        local r = Rect(tab)
        if r and Shown(tab) then out[#out + 1] = { static = f.isStaticDocked and true or false, mid = r.b + r.h / 2 } end
    end
    return out
end
QA.Register("chat-tab-row", { title = "Chat: every tab at one height (CHATREV-12)", qa = "D24", order = 237, prefill = true, steps = {
    { text = "Have at least one tab besides General and Combat Log (Guild, Self, a whisper tab ...). Look at the tab row.\n\n|cffffd100Expect:|r every tab's name sits on one line: General and Combat Log are not lower than the others.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local m = TabMids()
            if not m or #m == 0 then return false, "the tab row could not be read" end
            local hasDyn = false
            local lo, hi = m[1].mid, m[1].mid
            for _, t in ipairs(m) do if not t.static then hasDyn = true end; lo = math.min(lo, t.mid); hi = math.max(hi, t.mid) end
            if not hasDyn then return false, "only General / Combat Log are docked: open another tab first" end
            return (hi - lo) < 1, ("%d tabs; centres differ by %.1f px at most"):format(#m, hi - lo)
        end },
    { text = "Whisper someone new (a whisper tab opens), then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the new tab is on the same line too.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local m = TabMids()
            if not m or #m == 0 then return false, "the tab row could not be read" end
            local lo, hi = m[1].mid, m[1].mid
            for _, t in ipairs(m) do lo = math.min(lo, t.mid); hi = math.max(hi, t.mid) end
            return (hi - lo) < 1, ("%d tabs; centres differ by %.1f px at most"):format(#m, hi - lo)
        end },
} })
