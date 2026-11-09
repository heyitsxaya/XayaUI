-------------------------------------------------------------------------------
-- QAWalks-debug-w9b.lua (XayaUI_DevAssist 0.7.68): in-game QA walkthrough for debug batch W9b, issue #472 (XayaUI 0.6.82, Options
-- 0.6.104, Reskin 0.6.24, Chat 0.6.45, QoL 0.7.52; QA steps B297 to B300): a theme per restyled element.
--   Her words (2026-11-07): "I think we also need to enable individual element themeing and overrides somewhere ... Perhaps Blizzard
--   Reskin has a theme selector that compiles all elements that are overhauled and each has a theme override? The XayaUI Settings
--   Theme can be the initial fallback but users can customize at different levels of granularity?"; Q8 "Both", Q9 "Both".
--   B297 Blizzard Reskin > Theme: the table Element | Theme | Overrides | Comes from | Reset, one row per restyled element;
--   B298 one element (the settings window itself, so the change is in front of you) given Light mode: its border and background
--        before and after are read back and compared with Light mode's colours; nothing else changes;
--   B299 its row's Reset: exactly the colours it had before;
--   B300 the Esc Menu's own colours ("Use my own colors" before this update) still show: the colours copied into its row are
--        compared with the old settings, then you press Esc and say whether it looks as before.
-- Standing rule V22 (Xaya 2026-11-07): each check reads back what the addon drew (the window's backdrop colours) or stored, offers its
-- verdict (prefill = true; recorded only on her click) and puts the colours in the note; B300's look is her call (noVerdict).
-- Every element's own theme and colours are put back by the last step (Done) exactly as they were (copied at the first Do it for me,
-- through ns.Settings("platform"), never CueRulesDB directly). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local APP = "CueRules"
local EL = "settings"   -- the element B298 / B299 change: the settings window (open during the walkthrough, so it is in view)
local st = {}
local function NS() return rawget(_G, "XayaUI_NS") end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames[APP] end
local function TH() local ns = NS(); return ns and ns.Theme end
local function SE() local ns = NS(); return ns and ns.OptionsApi and ns.OptionsApi.ScopeEditor end
local function Copy(v) if type(v) ~= "table" then return v end local o = {}; for k, x in pairs(v) do o[k] = Copy(x) end; return o end
local function C3(c) return c and ("%02x%02x%02x"):format(math.floor((c[1] or 0) * 255 + 0.5), math.floor((c[2] or 0) * 255 + 0.5), math.floor((c[3] or 0) * 255 + 0.5)) or "?" end
local function Near(a, b) return a and b and math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01 end
local function Plat() local ns = NS(); return ns and ns.Settings and ns.Settings("platform") end
local function Keep()
    local T = TH(); if not (T and T.ScopeComesFrom) then error("XayaUI is older than 0.6.82 (no theme per element)") end
    if not st.kept then
        local P = Plat(); local th = P and P.theme
        st.kept = true
        st.scopes = Copy(type(th) == "table" and th.scopes or nil)
    end
    return T
end
local function OpenPage()
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then error("the settings window (XayaUI_Options) could not be loaded") end
    if not SE() then error("XayaUI Options is older than 0.6.104 (no Blizzard Reskin > Theme page)") end
    if ns.OpenSettingsPage then ns.OpenSettingsPage("reskin", SE().PAGE) end
end
local function Find(w, pred, out)
    out = out or {}
    if type(w) ~= "table" then return out end
    if pred(w) then out[#out + 1] = w end
    for _, c in ipairs(w.children or {}) do Find(c, pred, out) end
    return out
end
local function Plain(v) if type(v) == "function" then local ok, x = pcall(v); v = ok and x or "" end; return (tostring(v or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function OptOf(w) return w.GetUserData and w:GetUserData("option") end
-- the settings window's drawn background and border (its backdrop)
local function Drawn()
    local root = Root(); local fr = root and root.frame
    if not (fr and fr.GetBackdropColor) then return nil end
    local r, g, b = fr:GetBackdropColor()
    local br, bg, bb, ba = fr:GetBackdropBorderColor()
    return { r, g, b }, { br, bg, bb }, ba
end

-- B297
local function SetupPage() Keep(); OpenPage() end
local function CheckPage()
    local root = Root()
    if not root then return nil, "the settings window is not open: press Do it for me" end
    local heads, rows = {}, 0
    for _, w in ipairs(Find(root, function(w) local o = OptOf(w); return o and type(o.arg) == "table" and o.arg.xuiCell and o.type == "description" end)) do
        local o = OptOf(w)
        local n = Plain(o.name)
        if n == "Element" or n == "Theme" or n == "Overrides" or n == "Comes from" or n == "Reset" then heads[#heads + 1] = n end
    end
    for _, w in ipairs(Find(root, function(w) return w.type == "Dropdown" and OptOf(w) and type(OptOf(w).arg) == "table" and OptOf(w).arg.xuiCell end)) do rows = rows + 1 end
    local want = #(SE() and SE().Elements() or {})
    if rows == 0 then return nil, "the Theme table is not on screen: press Do it for me" end
    local ok = table.concat(heads, " | ") == "Element | Theme | Overrides | Comes from | Reset" and rows == want
    return ok, ("Columns: %s. Rows: %d of %d elements"):format(table.concat(heads, " | "), rows, want)
end
-- B298
local function SetupTheme()
    local T = Keep(); OpenPage()
    if not st.before then
        -- what the window draws without a theme of its own: read from the screen, or (when it had one, reset here) the global colours
        -- it is about to be drawn in (the window repaints itself a moment after a theme change)
        if T.ScopeData(EL) then
            T.ResetScope(EL)
            local g, b = T.GlobalCol("xui-window", "bg"), T.GlobalCol("xui-window", "border")
            st.before = { bg = { g[1], g[2], g[3] }, bd = { b[1], b[2], b[3] } }
        else
            local bg, bd = Drawn(); st.before = { bg = bg, bd = bd }
        end
    end
    SE().SetTheme(EL, "light")
end
local function CheckTheme()
    local T = TH()
    if not (T and T.ScopeData and T.ScopeData(EL) and T.ScopeData(EL).theme == "light") then return nil, "the Settings window's row is not on Light mode: press Do it for me" end
    local bg, bd = Drawn()
    if not bg then return nil, "the settings window is not open: press Do it for me" end
    local L = T.BUILTIN.light.pal
    local b0 = st.before or {}
    local from = SE().ComesFrom(EL)
    local ok = Near(bg, L.windowBg) and Near(bd, L.border) and from == "this element"
    return ok, ("Window bg %s > %s, border %s > %s (Light: %s, %s). Comes from: %s"):format(C3(b0.bg), C3(bg), C3(b0.bd), C3(bd), C3(L.windowBg), C3(L.border), from)
end
-- B299
local function SetupReset() local T = Keep(); OpenPage(); T.ResetScope(EL) end
local function CheckReset()
    local T = TH()
    if not st.before then return nil, "step 2 was not done: press its Do it for me first" end
    if T.ScopeData(EL) then return nil, "the row still has its own theme: press Do it for me" end
    local bg, bd = Drawn()
    if not bg then return nil, "the settings window is not open: press Do it for me" end
    local ok = Near(bg, st.before.bg) and Near(bd, st.before.bd) and SE().ComesFrom(EL) == "Global"
    return ok, ("After Reset: bg %s, border %s (before: %s, %s). Comes from: %s"):format(C3(bg), C3(bd), C3(st.before.bg), C3(st.before.bd), SE().ComesFrom(EL))
end
-- B300
local FOLD = { { "windowBg", "bg", "panel fill" }, { "border", "pb", "panel border" }, { "buttonBg", "btn", "button fill" },
    { "buttonBorder", "bb", "button border" }, { "accent", "acc", "accent" }, { "label", "tt", "title" } }
local function CheckEsc()
    local ns = NS(); local T = TH()
    if not (T and T.ScopeData) then return nil, "XayaUI is older than 0.6.82" end
    local R = ns.Settings and ns.Settings("reskin")
    local gm = R and R.gm
    if not (type(gm) == "table" and gm.useColors == true) then return true, "Use my own colors was off: nothing to carry over (the Esc menu follows the theme, as before)" end
    local sd = T.ScopeData("reskin.gamemenu")
    local parts, bad = {}, {}
    for _, f in ipairs(FOLD) do
        local old = { tonumber(gm[f[2] .. "R"]) or 0, tonumber(gm[f[2] .. "G"]) or 0, tonumber(gm[f[2] .. "B"]) or 0 }
        local now = sd and sd.tokens and sd.tokens[f[1]]
        parts[#parts + 1] = f[3] .. " " .. C3(now)
        if not Near(old, now) then bad[#bad + 1] = f[3] end
    end
    return #bad == 0, ("Esc Menu row: %s%s"):format(table.concat(parts, ", "), #bad > 0 and (". Not the old color: " .. table.concat(bad, ", ")) or "")
end
local function Restore()
    local T = TH(); local P = Plat()
    if st.kept and P and type(P.theme) == "table" then
        P.theme.scopes = Copy(st.scopes)
        if T then T.Changed() end
    end
    st.kept, st.scopes, st.before = nil, nil, nil
end
QA.DebugW9bTest = { Drawn = Drawn, Restore = Restore, State = st }   -- (tests)

QA.Register("debug-w9b", { title = "Theme per element: the Blizzard Reskin > Theme table (B297-B300, debug W9b)",
    qa = "B297, B298, B299, B300", order = 520, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on |cffffd100Blizzard Reskin > Theme|r (every element's own theme and colors are put back by the last step).\n\n|cffffd100Expect:|r a table with the columns Element | Theme | Overrides | Comes from | Reset, one row per restyled element (the Blizzard Reskin pages, Chat Panel, Character Pane, Settings window). The check counts the rows.",
        setup = SetupPage, check = CheckPage },
    { text = "Press |cffffd100Do it for me|r: the |cffffd100Settings window|r row's Theme is set to |cffffd100Light mode|r.\n\n|cffffd100Expect:|r this window turns white with a grey border at once; every other element keeps its look. The row says Comes from: this element. The check reads the window's colors before and after.",
        setup = SetupTheme, check = CheckTheme },
    { text = "Press |cffffd100Do it for me|r: the row's |cffffd100Reset|r is pressed.\n\n|cffffd100Expect:|r the window has exactly the colors it had before step 2, and the row says Inherit and Global again.",
        setup = SetupReset, check = CheckReset },
    { text = "If you used |cffffd100Use my own colors|r on the Esc Menu page before this update: the check compares those colors with the Esc Menu row's colors. Then press |cffffd100Esc|r. Does the Esc menu look exactly as before (the same panel, border, button, accent and title colors)?\n\nAnswer |cffffd100Pass|r if yes, |cffffd100Fail|r if not and say which color changed.",
        noVerdict = true, check = function() local ok, note = CheckEsc(); if ok == nil then return nil, note end return true, note end },
    { text = "Press |cffffd100Do it for me|r to put every element's own theme and colors back as they were, then |cffffd100Done|r.", done = true, setup = Restore },
} })
