-------------------------------------------------------------------------------
-- QAWalks-debug-w3.lua (XayaUI_DevAssist 0.7.64): in-game QA walkthrough for debug batch W3, the settings window's chrome (Options
-- 0.6.97, Rules Options 0.6.81, Dev Assist 0.7.64; QA steps B287 to B290):
--   #478 collapsed window: the X, the collapse arrow and the ? stay where they are when the window is open (B287);
--   #468 the window's own bottom Close button, the collapse arrow and the ? in XayaUI's flat look, whatever Blizzard Reskin > Buttons
--        says (B288);
--   #471 items 1-3, Theme page: the Theme string box's Accept button flat, the Reset buttons in one column inside their boxes, "Delete
--        saved" inside the page's margin (B289);
--   #483 rule option search: the stock Okay button flat; a clicked result opens its tab, folds the results away and the option is on
--        screen (B290).
-- Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on her click);
-- what it reads (positions, edges, button art) goes into the step's note. Reaches the settings window through ns.LoadOptions,
-- AceConfigDialog, ns.OptionsApi.FrameCloseButton (Options 0.6.97) and ns.OptionsApi.RuleEditor (ScopePath, RulesTreeStatus,
-- RuleSearch: Rules Options 0.6.81). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local APP = "CueRules"
local function NS() return rawget(_G, "XayaUI_NS") end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames[APP] end
local function RE() local ns = NS(); return ns and ns.OptionsApi and ns.OptionsApi.RuleEditor or {} end
local function OpenWindow()
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then error("the settings window (XayaUI_Options) could not be loaded") end
    local a = ACD(); if not a then error("the settings window's libraries are missing") end
    local api = ns.OptionsApi
    if not (api and api.IsOpen and api.IsOpen()) then
        if api and api.Toggle then api.Toggle() else a:Open(APP) end
    end
    return a, Root()
end
-- run fn(chrome) once the window has its title-bar buttons (they are made by the window's own 0.25 s driver after it opens)
local function WithChrome(fn, tries)
    local root = Root(); local c = root and root.xuiChrome
    if c then fn(c); return end
    tries = (tries or 0) + 1
    if tries < 20 and C_Timer and C_Timer.After then C_Timer.After(0.1, function() WithChrome(fn, tries) end) end
end
local function F(v) return type(v) == "number" and ("%.0f"):format(v) or "?" end
-- XayaUI's flat look on a Blizzard-template button: the red art (Left / Middle / Right) faded out and XayaUI's own box shown
local function FlatState(b)
    if not b then return false, "not found" end
    for _, k in ipairs({ "Left", "Middle", "Right" }) do
        local t = b[k]
        if t and t.GetAlpha and t:GetAlpha() > 0.01 then return false, "red art showing (" .. k .. ")" end
    end
    local box = b.xuiFlat
    if not (box and box.bg and box.bg:IsShown()) then return false, "no flat box" end
    return true, "flat"
end
local function Find(w, pred, out)
    out = out or {}
    if type(w) ~= "table" then return out end
    if pred(w) then out[#out + 1] = w end
    for _, c in ipairs(w.children or {}) do Find(c, pred, out) end
    return out
end
local function OptName(w) local o = w.GetUserData and w:GetUserData("option"); return o and o.name end

-- B287 (#478): the title-bar buttons' places, open and collapsed
local st = {}
local function Places(c) return { x = c.close:GetRight(), a = c.arrow:GetRight(), h = c.help:GetRight(), xt = c.close:GetTop() } end
local function SetupCollapse()
    OpenWindow()
    st.open = nil
    WithChrome(function(c)
        if c.collapsed then c.arrow:Click() end
        st.open = Places(c)
        c.arrow:Click()
    end)
end
local function CheckCollapse()
    local root = Root(); local c = root and root.xuiChrome
    if not (c and st.open) then return nil, "press Do it for me first" end
    if not c.collapsed then return nil, "the window is not collapsed: press the collapse arrow (or Do it for me)" end
    local now = Places(c)
    local d = math.max(math.abs(now.x - st.open.x), math.abs(now.a - st.open.a), math.abs(now.h - st.open.h), math.abs(now.xt - st.open.xt))
    return d < 0.5, ("right edges open / collapsed: X %s / %s, arrow %s / %s, ? %s / %s (largest move %.1f px)"):format(
        F(st.open.x), F(now.x), F(st.open.a), F(now.a), F(st.open.h), F(now.h), d)
end

-- B288 (#468): the bottom Close button, the collapse arrow and the ?
local function SetupFlat()
    OpenWindow()
    WithChrome(function(c) if c.collapsed then c.arrow:Click() end end)
end
local function CheckFlat()
    local ns, root = NS(), Root()
    local c = root and root.xuiChrome
    if not c then return nil, "the settings window is not open: press Do it for me" end
    local find = ns and ns.OptionsApi and ns.OptionsApi.FrameCloseButton
    if not find then return false, "XayaUI Options is older than 0.6.97 (no flat Close button)" end
    local okC, wC = FlatState(find(root))
    local okA, wA = FlatState(c.arrow)
    local okH, wH = FlatState(c.help)
    local glyph = c.arrow.tex and c.arrow.tex:GetAlpha() or 0
    local rs = ns.Settings and ns.Settings("reskin")
    local btn = rs and rs.blizzard and rs.blizzard.buttons
    return (okC and okA and okH and glyph > 0.99) and true or false,
        ("bottom Close: %s; collapse arrow: %s (arrow glyph %s); ?: %s; Blizzard Reskin > Buttons: %s"):format(wC, wA,
            glyph > 0.99 and "shown" or "HIDDEN", wH, btn == true and "on" or "off")
end

-- B289 (#471 items 1-3): the Theme page
local function SetupTheme()
    local a = OpenWindow()
    local ns = NS()
    local P = ns.Settings and ns.Settings("platform")
    if P then P.ui = P.ui or {}; if not st.themeTouched then st.themeTouched = true; st.wasAdvanced = P.ui.themeAdvanced end; P.ui.themeAdvanced = true end   -- the class boxes show with it
    pcall(a.SelectGroup, a, APP, "set", "ui", "theme")
end
local function CheckTheme()
    local root = Root()
    if not root then return nil, "the settings window is not open: press Do it for me" end
    local box = Find(root, function(w) return w.type == "MultiLineEditBox" and OptName(w) == "Theme string" end)[1]
    if not box then return nil, "the Theme page is not open: press Do it for me" end
    local okB, wB = FlatState(box.button)
    local resets = Find(root, function(w) return w.type == "Button" and OptName(w) == "Reset" and w.frame:IsVisible() end)
    local xs, out, minX, maxX = {}, 0, nil, nil
    for _, r in ipairs(resets) do
        local p = r.parent
        local x = r.frame:GetLeft() - p.content:GetLeft()
        xs[#xs + 1] = F(x)
        minX = math.min(minX or x, x); maxX = math.max(maxX or x, x)
        if r.frame:GetRight() > p.content:GetParent():GetRight() - 0.5 then out = out + 1 end
    end
    local col = (#resets > 0 and maxX - minX < 0.5)
    local del = Find(root, function(w) return w.type == "Button" and OptName(w) == "Delete saved" end)[1]
    local gap
    if del and del.parent and del.parent.content then
        local pc = del.parent.content
        gap = pc:GetLeft() + (pc.width or pc:GetWidth()) - del.frame:GetRight()
    end
    local m = (NS().Style and NS().Style.margin) or 10
    local okD = gap and gap >= m - 1.01
    return (okB and col and out == 0 and okD) and true or false,
        ("Accept button: %s; Reset x in its box: %s (%d of %d past the box's edge); Delete saved: right edge %s, %s px from the page's edge (margin %d)"):format(
            wB, table.concat(xs, ", "), out, #resets, del and F(del.frame:GetRight()) or "?", gap and ("%.0f"):format(gap) or "?", m)
end
local function RestoreTheme()
    local ns = NS()
    local P = ns and ns.Settings and ns.Settings("platform")
    if P and P.ui and st.themeTouched then P.ui.themeAdvanced = st.wasAdvanced end
    st.themeTouched, st.wasAdvanced = nil, nil
end

-- B290 (#483): the rule option search
local function SearchGroup()
    local ns = NS()
    local tree = ns and ns.OptionsApi and ns.OptionsApi.LastTree and ns.OptionsApi.LastTree()
    local seen = {}
    local function find(t, d)
        if type(t) ~= "table" or seen[t] or d > 30 then return nil end
        seen[t] = true
        if type(t.args) == "table" and t.args.xuiSearch then return t end
        for _, v in pairs(t) do local r = find(v, d + 1); if r then return r end end
    end
    return find(tree, 0)
end
local function SetupSearch()
    local a = OpenWindow()
    local ns = NS()
    local rs = RE().RuleSearch
    if not rs then error("XayaUI Rules Options is not loaded or older than 0.6.81: switch XayaUI Rules on and /reload") end
    local rule = ns.rules and ns.rules[1]
    if not rule then error("you have no rule: make one (any) and press Do it for me again") end
    local okc, ctx = pcall(ns.ReadContext)
    if RE().ScopePath then pcall(a.SelectGroup, a, APP, RE().ScopePath(rule, okc and ctx or nil)) end
    st.clicked = nil
end
local function CheckSearch()
    local rs = RE().RuleSearch
    if not rs then return false, "XayaUI Rules Options is older than 0.6.81 (no fold / scroll on a result click)" end
    local g = SearchGroup()
    if not g then return nil, "no rule's editor is open: press Do it for me" end
    local root = Root()
    local eb = root and Find(root, function(w) return w.type == "EditBox" and OptName(w) == "Search this rule's options" end)[1]
    local okO, wO = FlatState(eb and eb.button)
    local e = rs.lastReveal
    local q = g.args.xuiSearch.get and g.args.xuiSearch.get() or ""
    if not e or q == "" then return nil, "type a word in the rule's search box, press Enter and click one result, then press Check" end
    local folded = g.args.xuiSR1 and g.args.xuiSR1.hidden and g.args.xuiSR1.hidden()
    local w, sc, exact = rs.FindControl(e)
    local inView = false
    if w then
        if not sc then inView = true
        else
            local t, b, vt, vb = w.frame:GetTop(), w.frame:GetBottom(), sc.scrollframe:GetTop(), sc.scrollframe:GetBottom()
            inView = (t and b and vt and vb) and b >= vb - 0.5 and t <= vt + 0.5 or false
        end
    end
    local what = w and (exact and ("the option \"" .. tostring(e.name) .. "\"") or ("the nearest control to \"" .. tostring(e.name) .. "\" (a switch above it is off, so the option itself is hidden)")) or "nothing"
    return (okO and folded and inView) and true or false,
        ("search \"%s\", clicked %s > %s: results folded: %s; on screen: %s (%s); Okay button: %s"):format(q, tostring(e.tabName), tostring(e.name),
            folded and "yes" or "NO", inView and "yes" or "NO", what, wO)
end

QA.Register("debug-w3", { title = "Settings window chrome: collapsed buttons, flat Close / Accept / Okay, Theme page layout, search result click (B287-B290, debug W3)",
    qa = "B287, B288, B289, B290", order = 516, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens and its collapse arrow (top right, beside the X) is pressed, so only the title bar shows.\n\n|cffffd100Expect:|r the |cffffd100?|r, the arrow and the |cffffd100X|r stay at the right end of the title bar, exactly where they are when the window is open (not beside the \"XayaUI\" title). The check compares their right edges open and collapsed.",
        setup = SetupCollapse, check = CheckCollapse },
    { text = "Press |cffffd100Do it for me|r: the window opens again (expanded). Look at its bottom-right |cffffd100Close|r button and the |cffffd100?|r and arrow in the title bar.\n\n|cffffd100Expect:|r all three in XayaUI's flat button look (dark box, thin border, theme text), not Blizzard's red, whether Blizzard Reskin > Buttons is on or off. The X keeps its own look. The check reads each button's art.",
        setup = SetupFlat, check = CheckFlat },
    { text = "Press |cffffd100Do it for me|r: Settings > UI Options > |cffffd100Theme|r opens with Advanced customization on (so the class boxes show). Scroll through it.\n\n|cffffd100Expect:|r the button under the Theme string box (\"Accept\") is flat; every class box's |cffffd100Reset|r sits at the same place at the right of its box, inside it; |cffffd100Delete saved|r ends a little inside the page's right edge, not against it. The check reads the button art, each Reset's x in its box and Delete saved's distance from the edge. (The window's see-through background is not part of this step: it waits for your answer on C4.)",
        setup = SetupTheme, check = CheckTheme },
    { text = "Press |cffffd100Do it for me|r: your first rule's editor opens. Type a word in its |cffffd100Search this rule's options|r box (for example |cffffd100glow|r), press Enter, and click one of the results. Then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the box's Okay button (it shows while you type) is flat; after the click the results fold away (your word stays in the box; Enter brings them back), the result's tab opens, and the page scrolls so the option is on screen (a closed section on the way opens). If a switch above it is off, the option itself stays hidden and the page shows that switch. The check reads what was clicked and whether it is inside the visible part of the page.",
        setup = SetupSearch, check = CheckSearch },
    { done = true, noVerdict = true, setup = RestoreTheme,
      text = "Last step: anything look wrong (a button still red, a Reset out of line, the search landing somewhere odd)? Write it in the note, then press |cffffd100Done|r (Do it for me puts Advanced customization back as it was). No verdict: a note is kept, nothing is recorded as Pass or Fail." },
} })
