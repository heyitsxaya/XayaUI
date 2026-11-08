-------------------------------------------------------------------------------
-- QAWalks-element-menu.lua (XayaUI_DevAssist 0.7.61): in-game QA walkthrough for XayaUI 0.6.80's element menu (QA step I3).
--   #495, REQUEST-LOG PS-59 (Xaya, 2026-11-08, her words): "Also with the options panel on, right clicking an element object should open
--   up an at-cursor menu to allow the user to select "element options" and modify position with x,y inputs"
-- "element-menu" (pre-fill, V22): the settings window is opened; a right-click is sent to an element on screen (the first one shown
-- that has X / Y: a data panel, the Notepad, the Calculator, the Shopping List or an unlocked display; else any registered one); the
-- menu's contents are read back; X + 10 is typed and applied and the element's own saved X is read again; Element options is pressed and
-- the page it asked for is recorded; then the window is closed and the same right-click must not open the menu. Every check reads the
-- addon's own state through core (ns.ElementDefs, ns.ElementMenu); nothing is saved of its own. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end
local function NS() return rawget(_G, "XayaUI_NS") end

local pick   -- { def, frame, script, ctx, x0 } of the element the walkthrough right-clicks
local function HasXY(def) return def and not def.blizzard and type(def.getPos) == "function" and type(def.setPos) == "function" end
local function Shown(f) return f and f.IsVisible and f:IsVisible() and true or false end
-- an element on screen to right-click: one with X / Y first
local function Pick()
    local ns = NS()
    local defs, order = ns.ElementDefs()
    local best
    for _, k in ipairs(order) do
        local def = defs[k]
        pcall(def.targets, function(f, script, ctx)
            if Shown(f) and (not best or (HasXY(def) and not HasXY(best.def))) then best = { def = def, frame = f, script = script or "OnMouseUp", ctx = ctx } end
        end)
    end
    return best
end
local function WindowOpen() local ns = NS(); return ns.ElementWindowIsShown and ns.ElementWindowIsShown() or false end
local function OpenWindow() local ns = NS(); if not WindowOpen() and ns.ToggleUI then ns.ToggleUI() end end
local function Label(p) return tostring(p and p.def.label or "?") end

local function Step1()
    local ns = NS()
    OpenWindow()
    if ns.Notepad_SetShown and ns.notepadDB and ns.notepadDB.enabled ~= false then pcall(ns.Notepad_SetShown, true) end
    pick = Pick()
    if not pick then return end
    if HasXY(pick.def) then local ok, x = pcall(pick.def.getPos, pick.ctx); pick.x0 = ok and tonumber(x) or nil end
    ns.ElementRightClick(pick.frame, pick.script)
end
local function Check1()
    local ns = NS()
    if not WindowOpen() then return nil, "the settings window is not open: press Do it for me (or type /xui), then right-click an element" end
    local m = ns.ElementMenu and ns.ElementMenu()
    if not (m and m:IsShown()) then return nil, "no element menu is shown: right-click a XayaUI element (a data panel, the Notepad, the chat sidebar, an unlocked display) or press Do it for me" end
    local def = m.def
    local opts = m.options:IsShown() and m.options:GetText() == "Element options"
    local xy = m.x:IsShown() and m.y:IsShown() and m.xLabel:GetText() == "X" and m.yLabel:GetText() == "Y"
    local want = HasXY(def)
    local rows = m.shownRows and #m.shownRows or 0
    return opts and (xy == want) and true or false, ("element: %s; Element options: %s; X / Y: %s (expected %s)%s; its own menu's entries kept: %d"):format(
        tostring(def and def.label), opts and "yes" or "NO", xy and ("X " .. tostring(m.x:GetText()) .. ", Y " .. tostring(m.y:GetText())) or "none",
        want and "X / Y" or "none: no X / Y setting, or a Blizzard frame", "", rows)
end
local function Step2()
    local ns = NS()
    local m = ns.ElementMenu and ns.ElementMenu()
    if not (m and m:IsShown() and m.hasXY) then return end
    local ok, x = pcall(m.def.getPos, m.ctx)
    pick = pick or { def = m.def, ctx = m.ctx }
    pick.x0 = ok and tonumber(x) or 0
    m.x:SetText(tostring(math.floor(pick.x0 + 0.5) + 10))
    ns.ElementMenuApply()
end
local function Check2()
    local ns = NS()
    local m = ns.ElementMenu and ns.ElementMenu()
    if not (m and m:IsShown()) then return nil, "the menu is closed: right-click the element again" end
    if not m.hasXY then return nil, ("%s has no X / Y: nothing to change (skip this step)"):format(tostring(m.def.label)) end
    if not (pick and pick.x0) then return nil, "type a new X (10 more) and press Enter, or press Do it for me" end
    local ok, x, y = pcall(m.def.getPos, m.ctx)
    if not ok then return false, "its position could not be read: " .. tostring(x) end
    local good = math.floor(x + 0.5) == math.floor(pick.x0 + 0.5) + 10 and m.x:GetText() == tostring(math.floor(x + 0.5))
    return good, ("%s: saved X %s (was %s), Y %s; the menu's X box: %s. Look at its settings page: its X shows the same number."):format(
        tostring(m.def.label), tostring(x), tostring(pick.x0), tostring(y), tostring(m.x:GetText()))
end
local asked
local function Step3()
    local ns = NS()
    local m = ns.ElementMenu and ns.ElementMenu()
    if not (m and m:IsShown()) then return end
    asked = {}
    local rawOpen, rawEdit = ns.OpenSettingsPage, ns.EditRule
    ns.OpenSettingsPage = function(...) asked[#asked + 1] = table.concat({ ... }, " > "); return rawOpen(...) end
    ns.EditRule = function(r) asked[#asked + 1] = "rule editor: " .. tostring(r and r.name); return rawEdit(r) end
    local def = m.def
    local ok, err = pcall(m.options:GetScript("OnClick"), m.options, "LeftButton")
    ns.OpenSettingsPage, ns.EditRule = rawOpen, rawEdit
    asked.def = def
    if not ok then asked[#asked + 1] = "ERROR " .. tostring(err) end
end
local function Check3()
    local ns = NS()
    if not asked then return nil, "press Element options in the menu (or Do it for me)" end
    local m = ns.ElementMenu and ns.ElementMenu()
    local def = asked.def
    local want = def and type(def.page) == "table" and table.concat(def.page, " > ") or nil
    local got = asked[1]
    local ok = got ~= nil and not (m and m:IsShown()) and WindowOpen() and (want == nil or got == want)
    return ok, ("%s: Element options asked for %s%s; the menu closed: %s"):format(tostring(def and def.label), tostring(got or "nothing"),
        want and (" (its page: " .. want .. ")") or "", (m and m:IsShown()) and "NO" or "yes")
end
local function Step4()
    local ns = NS()
    if pick and pick.x0 and HasXY(pick.def) then
        local ok, _, y = pcall(pick.def.getPos, pick.ctx)
        if ok then pcall(pick.def.setPos, pick.ctx, math.floor(pick.x0 + 0.5), y) end   -- put it back where it was
    end
    if WindowOpen() and ns.ToggleUI then ns.ToggleUI() end
    local m = ns.ElementMenu and ns.ElementMenu()
    if m and m:IsShown() then m:Hide() end
    -- the right-click again, with the window closed: what the element did before (a data panel opens its page, which opens the window)
    if pick and pick.frame then pcall(ns.ElementRightClick, pick.frame, pick.script) end
end
local function Check4()
    local ns = NS()
    if not pick then return nil, "run the steps above first" end
    local m = ns.ElementMenu and ns.ElementMenu()
    local n = ns.ElementHandlersAttached and ns.ElementHandlersAttached() or -1
    local menuShown = m and m:IsShown() or false
    -- (a data panel's right-click opens its page, so the window may be open again here: then its handlers are on again, as they should be)
    local ok = not menuShown and (WindowOpen() or n == 0)
    return ok, ("%s right-clicked with the window closed: element menu %s; window %s; element handlers on frames: %d"):format(Label(pick),
        menuShown and "SHOWN" or "not shown", WindowOpen() and "opened by the element's own right-click" or "closed", n)
end

QA.Register("element-menu", { title = "Right-click an element while the settings window is open (I3, PS-59 #495)", qa = "I3", order = 513, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens and a right-click goes to a XayaUI element on screen (a data panel, the Notepad, the Calculator, the Shopping List, an unlocked display, or the chat sidebar). Or open the window yourself and right-click one.\n\n|cffffd100Expect:|r a small menu at the cursor with |cffffd100Element options|r and |cffffd100X|r and |cffffd100Y|r boxes (an element with no X / Y setting, such as the chat sidebar, or a restyled Blizzard window: Element options only). An unlocked display also keeps its own entries below (Snap Target, Center, Edit This Aura, ...).",
        setup = Step1, check = Check1 },
    { text = "Press |cffffd100Do it for me|r: the X box gets 10 more and Enter is pressed. Or type it yourself.\n\n|cffffd100Expect:|r the element moves 10 pixels to the right at once, and its settings page in the window shows the new X.",
        setup = Step2, check = Check2 },
    { text = "Press |cffffd100Do it for me|r: |cffffd100Element options|r is pressed. Or press it yourself.\n\n|cffffd100Expect:|r the menu closes and the settings window shows that element's page (a display: the rule editor on that display).",
        setup = Step3, check = Check3 },
    { text = "Press |cffffd100Do it for me|r: the element goes back where it was, the settings window closes, and the same element is right-clicked again.\n\n|cffffd100Expect:|r no element menu: the right-click does what it did before (a data panel or the Chat Data Panel opens its settings page; an unlocked display its own menu; the Notepad and the sidebar strip nothing).",
        setup = Step4, check = Check4 },
} })
