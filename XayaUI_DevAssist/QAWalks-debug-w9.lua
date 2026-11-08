-------------------------------------------------------------------------------
-- QAWalks-debug-w9.lua (XayaUI_DevAssist 0.7.67): in-game QA walkthrough for debug batch W9a, issue #460 (XayaUI 0.6.81, Options
-- 0.6.102; QA steps B294 to B296): gradient borders from the cursor trail themes, with their own Reverse switch.
--   Her words (2026-11-06): "all cursor trail based themes should have gradient borders that reflect the cursor gradient. this
--   gradient should be reversible in direction."; her answers (2026-11-07): borders "Window frame, Panes, Buttons, Tabs"; reverse "Its
--   own switch"; "allow in advance settings the user to apply the gradient as a set "color" option to all elements".
--   B294 a cursor trail theme (Rainbow): the settings window's frame, the pane divider, a button, core's flat title-bar button and the
--        tabs draw the trail's colours, head of the trail at the left (top for the divider);
--   B295 the Theme page's "Reverse gradient direction" switch turns them round;
--   B296 a solid theme (Class colors) draws one solid colour per border again.
-- Standing rule V22 (Xaya 2026-11-07): each check reads back what was drawn on the border textures (the colours the addon handed to
-- the game's SetGradient, kept on each piece, and the piece's GetVertexColor) and offers its verdict (prefill = true; recorded only
-- on her click); the colours go into the note. Whether it LOOKS like the trail is her call: step 2 asks (noVerdict).
-- Your theme is put back by the last step (Done) exactly as it was (the whole CueRulesDB.theme copied at the first Do it for me).
-- UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local APP = "CueRules"
local st = {}   -- this run: the theme as it was before the first step
local function NS() return rawget(_G, "XayaUI_NS") end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames[APP] end
local function TH() local ns = NS(); return ns and ns.Theme end
local function Copy(v) if type(v) ~= "table" then return v end local o = {}; for k, x in pairs(v) do o[k] = Copy(x) end; return o end
local function OpenTheme()
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then error("the settings window (XayaUI_Options) could not be loaded") end
    local a = ACD(); if not a then error("the settings window's libraries are missing") end
    local api = ns.OptionsApi
    if not (api and api.IsOpen and api.IsOpen()) then if api and api.Toggle then api.Toggle() else a:Open(APP) end end
    pcall(a.SelectGroup, a, APP, "set", "ui", "theme")
end
local function Keep()
    local T = TH(); if not (T and T.Grad) then error("XayaUI is older than 0.6.81 (no gradient borders)") end
    if not st.saved then st.saved = Copy(CueRulesDB and CueRulesDB.theme or {}) end
    return T
end
local function Find(w, pred, out)
    out = out or {}
    if type(w) ~= "table" then return out end
    if pred(w) then out[#out + 1] = w end
    for _, c in ipairs(w.children or {}) do Find(c, pred, out) end
    return out
end
local function OptName(w) local o = w.GetUserData and w:GetUserData("option"); return o and o.name end

local function C3(c) return c and ("%02x%02x%02x"):format(math.floor((c[1] or 0) * 255 + 0.5), math.floor((c[2] or 0) * 255 + 0.5), math.floor((c[3] or 0) * 255 + 0.5)) or "?" end
local function Near(a, b) return a and b and math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01 end
-- the colours drawn along a list of pieces (shown ones, in place order: left to right, or top to bottom when vertical)
local function ReadPieces(list)
    local segs = {}
    for _, s in ipairs(list or {}) do if s:IsShown() and s.xuiGrad then segs[#segs + 1] = s end end
    if #segs == 0 then return nil end
    local vert = segs[1].xuiGrad[1] == "VERTICAL"
    table.sort(segs, function(a, b) if vert then return (a:GetTop() or 0) > (b:GetTop() or 0) end return (a:GetLeft() or 0) < (b:GetLeft() or 0) end)
    local cols = {}
    for i, s in ipairs(segs) do
        local g = s.xuiGrad   -- { orientation, minColor, maxColor } as handed to SetGradient (VERTICAL: min = bottom)
        local first, second = g[2], g[3]
        if vert then first, second = g[3], g[2] end
        if i == 1 then cols[1] = first end
        cols[#cols + 1] = second
    end
    return cols, segs[1]
end
local function Seq(cols) local o = {}; for i, c in ipairs(cols or {}) do o[i] = C3(c) end; return table.concat(o, ">") end
local function SameSeq(a, b) if not (a and b) or #a ~= #b then return false end for i = 1, #a do if not Near(a[i], b[i]) then return false end end return true end
-- every named element: { label, colours read or nil }
local function Elements()
    local root = Root(); if not root then return nil end
    local out = {}
    local fr = root.frame
    out[#out + 1] = { "window", fr.xuiGradE and ReadPieces(fr.xuiGradE.segs[1]) }
    local tree = Find(root, function(w) return w.type == "TreeGroup" and w.xuiDivider end)[1]
    local dv = tree and tree.xuiDivider
    out[#out + 1] = { "pane", dv and dv.xuiGradL and ReadPieces(dv.xuiGradL.segs) }
    local btn = Find(root, function(w) return w.type == "Button" and OptName(w) == "Reset everything" end)[1]
    out[#out + 1] = { "button", btn and btn.frame.xuiGradE and ReadPieces(btn.frame.xuiGradE.segs[1]) }
    local ch = root.xuiChrome
    out[#out + 1] = { "arrow", ch and ch.arrow and ch.arrow.xuiGradE and ReadPieces(ch.arrow.xuiGradE.segs[1]) }
    local tab
    for _, g in ipairs(Find(root, function(w) return w.type == "TabGroup" and w.tabs end)) do
        for _, t in ipairs(g.tabs) do if t:IsShown() and t.selected and t.xuiGradE then tab = t end end
    end
    out[#out + 1] = { "tab", tab and ReadPieces(tab.xuiGradE.segs[1]) }
    return out, fr
end
local function Expect(want, label)
    local els = Elements()
    if not els then return nil, "the settings window is not open: press Do it for me" end
    local bad, parts = {}, {}
    for _, e in ipairs(els) do
        local cols = e[2]
        local match = SameSeq(cols, want)
        parts[#parts + 1] = e[1] .. " " .. (match and "=" or (cols and Seq(cols) or "solid"))   -- (= drawn exactly as wanted; the note keeps 200 characters)
        if not match then bad[#bad + 1] = e[1] end
    end
    local one = els[1][2] and select(2, ReadPieces(Root().frame.xuiGradE.segs[1]))
    local vc = one and one.GetVertexColor and C3({ one:GetVertexColor() }) or "?"
    return #bad == 0, ("%s %s. %s. Window piece 1 vertex %s%s"):format(label, Seq(want), table.concat(parts, "; "), vc,
        #bad > 0 and (". Wrong: " .. table.concat(bad, ", ")) or "")
end
local function Preset(key) local T = TH(); local p = T and T.CURSOR_PRESETS and T.CURSOR_PRESETS[key]; return p and p[2] end
local function Rev(list) local o = {}; for i = #(list or {}), 1, -1 do o[#o + 1] = list[i] end; return o end

-- B294
local function SetupRainbow() local T = Keep(); OpenTheme(); T.SetBase("cursor_rainbow"); T.SetGradReverse(false) end
local function CheckRainbow()
    local T = TH()
    if not (T and T.Grad and T.EffBase() == "cursor_rainbow") then return nil, "the Rainbow theme is not picked: press Do it for me" end
    if T.GradReversed() then return nil, "Reverse gradient direction is on: press Do it for me" end
    return Expect(Preset("rainbow"), "Rainbow")
end
-- B295
local function SetupReverse()
    local T = Keep(); OpenTheme()
    if T.EffBase() ~= "cursor_rainbow" then T.SetBase("cursor_rainbow") end
    T.SetGradReverse(true)
end
local function CheckReverse()
    local T = TH()
    if not (T and T.Grad and T.GradReversed()) then return nil, "Reverse gradient direction is off: press Do it for me (or tick it on the Theme page)" end
    local root = Root()
    local box = root and Find(root, function(w) return w.type == "CheckBox" and OptName(w) == "Reverse gradient direction" end)[1]
    local ok, note = Expect(Rev(Preset("rainbow")), "Reversed")
    return ok and box ~= nil, note .. (box and "" or ". The switch is not shown on the Theme page")
end
-- B296
local function SetupSolid() Keep(); OpenTheme(); TH().SetBase("class") end
local function CheckSolid()
    local T = TH()
    if not (T and T.Grad and T.EffBase() == "class") then return nil, "Class colors is not picked: press Do it for me" end
    local els, fr = Elements()
    if not els then return nil, "the settings window is not open: press Do it for me" end
    local grads = {}
    for _, e in ipairs(els) do if e[2] then grads[#grads + 1] = e[1] end end
    local r, g, b, a = fr:GetBackdropBorderColor()
    local want = T.Col("xui-window", "border")
    local edgeOk = r and Near({ r, g, b }, want) and (a or 0) > 0.99
    return #grads == 0 and edgeOk and true or false, ("Class colors: gradients left on %s; window edge %s (theme %s)"):format(#grads == 0 and "none" or table.concat(grads, ", "),
        r and C3({ r, g, b }) or "?", C3(want))
end
local function Restore()
    local T = TH()
    if st.saved and CueRulesDB then CueRulesDB.theme = Copy(st.saved); if T then T.Changed() end end
    st.saved = nil
end
QA.DebugW9Test = { Elements = Elements, Restore = Restore, State = st }   -- (tests)

QA.Register("debug-w9", { title = "Theme: gradient borders from the cursor trail themes, and their Reverse switch (B294-B296, debug W9a)",
    qa = "B294, B295, B296", order = 519, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on Settings > UI Options > Theme and the |cffffd100Rainbow|r theme is picked (your own theme is put back by the last step).\n\n|cffffd100Expect:|r the window's frame, the line between the sidebar and the page, the buttons (Reset everything, the title bar's collapse arrow) and the tabs have Rainbow borders: red at the left running through orange, yellow, green, blue to purple at the right (the line between the panes: red at the top, purple at the bottom). The check reads the colours drawn on each border and puts them in the note.",
        setup = SetupRainbow, check = CheckRainbow },
    { text = "Look at the borders. Do they read as the cursor trail's Rainbow gradient (the same colours, in the same order as the trail from the cursor outwards)?\n\nAnswer |cffffd100Pass|r if yes, |cffffd100Fail|r if not and say in the note what looks wrong (for example the direction, or which border).",
        noVerdict = true, check = function() local ok, note = CheckRainbow(); if ok == nil then return nil, note end return true, note end },
    { text = "Press |cffffd100Do it for me|r: the Theme page's |cffffd100Reverse gradient direction|r switch is ticked.\n\n|cffffd100Expect:|r the switch shows on the Theme page (only while the theme has a gradient), and every border runs the other way: purple at the left, red at the right (purple at the top of the line between the panes). Your cursor trail's own Reverse colors does not change.",
        setup = SetupReverse, check = CheckReverse },
    { text = "Press |cffffd100Do it for me|r: |cffffd100Class colors|r is picked.\n\n|cffffd100Expect:|r every border is one plain colour again, exactly as before this update; the Reverse switch is gone from the Theme page.",
        setup = SetupSolid, check = CheckSolid },
    { text = "Press |cffffd100Do it for me|r to put your own theme back as it was, then |cffffd100Done|r.", done = true, setup = Restore },
} })
