-------------------------------------------------------------------------------
-- QAWalks-reskin.lua (XayaUI_DevAssist 0.7.42): in-game QA walkthroughs for XayaUI Blizzard Reskin 0.6.11 (BlizzardSkins.lua): Blizzard's
-- windows, the minimap shape, tooltips, the objective tracker, Battle.net toasts, pop-ups and loot rolls in the XayaUI look (REQUEST-LOG A13 RESKIN-1 to RESKIN-4; Xaya's
-- overnight order 2026-11-07: "I want everything I've requested ... implemented and pushed to main").
-- Standing rule V22 (Xaya 2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have an in game
-- qa test walk through with pre-fill confirmation options or data capturing". Every walkthrough sets prefill = true: the addon's own
-- verdict is offered on "Accept", nothing is recorded without her click; steps only her eyes can judge are noVerdict.
-- The Reskin addon is reached only through its published service (ns.Service("blizzardSkins")). Her reskin settings are copied in each
-- walkthrough's first step and put back in its last. Does nothing without the framework or without XayaUI Blizzard Reskin. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function BS() local ns = NS(); return ns and ns.Service and ns.Service("blizzardSkins") end
local function Need() local s = BS(); if not s then return nil, "XayaUI Blizzard Reskin is not loaded (enable it in the AddOns list)" end; return s end
local function Copy(t) if type(t) ~= "table" then return t end; local o = {}; for k, v in pairs(t) do o[k] = Copy(v) end; return o end
local function Near(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 0.02) end

-- her settings, copied at the start of a walkthrough and put back at its end
local kept, keptTab
local function Keep()
    local db = rawget(_G, "CueRulesDB")
    kept = Copy(db and db.ui and db.ui.rsk)
    keptTab = db and db.reskinTabOff
end
local function PutBack()
    local s = BS(); if not s then return end
    local db = rawget(_G, "CueRulesDB"); if not db then return end
    db.ui = db.ui or {}
    db.ui.rsk = Copy(kept)
    db.reskinTabOff = keptTab
    s.Apply()
end
local function Set(fn)   -- change her reskin settings for a step (the Reskin tab switch on, then fn(cfg)), and apply
    local s = Need(); if not s then return end
    local db = rawget(_G, "CueRulesDB"); if db then db.reskinTabOff = nil end
    fn(s.Cfg()); s.Apply()
end
local function Painted(f) local s = BS(); local m = s and f and s.memo[f]; return m and m.painted and true or false end
local function Alpha(r) if r and r.GetAlpha then local ok, a = pcall(r.GetAlpha, r); if ok then return a end end end

-------------------------------------------------------------------------------
-- 1. Blizzard's windows
-------------------------------------------------------------------------------
local function OpenBag() local f = rawget(_G, "ContainerFrameCombinedBags"); if f and f:IsShown() then return f end; for i = 1, 13 do local c = rawget(_G, "ContainerFrame" .. i); if c and c:IsShown() then return c end end end
QA.Register("reskin-windows", { title = "Reskin: Blizzard's windows in the XayaUI look", area = "Reskin", qa = "RESKIN-W", order = 300, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: your reskin settings are remembered, then |cffffd100Blizzard UI Reskin > Blizzard Windows|r is switched on (every window in its list).\n\n|cffffd100Expect:|r nothing on screen changes yet.",
        setup = function() Keep(); Set(function(c) c.windows = true end) end,
        check = function() local s, why = Need(); if not s then return false, why end; return s.Live().windows, s.Live().windows and "Blizzard Windows is on" or "Blizzard Windows did not switch on" end },
    { text = "Press |cffffd100Do it for me|r: your bags open.\n\n|cffffd100Expect:|r the bag window has a solid dark background in the theme's window colour, a thin border and its title in the theme's title colour, with no Blizzard frame art or portrait ring. Your items, buttons and the gold line work as before.",
        setup = function() if type(rawget(_G, "OpenAllBags")) == "function" then pcall(OpenAllBags) end end,
        check = function()
            local f = OpenBag(); if not f then return false, "no bag window is open" end
            local ok = Painted(f) and Alpha(f.NineSlice) == 0
            return ok, ok and "the bag window carries the XayaUI look (Blizzard's frame art faded)" or "the bag window still has Blizzard's art"
        end },
    { text = "Open your |cffffd100Talents and spellbook|r yourself (the key you use, or the micro menu), then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the same look; the window is skinned the moment Blizzard first loads it.",
        check = function()
            local f = rawget(_G, "PlayerSpellsFrame")
            if not (f and f:IsShown()) then return false, "the Talents and spellbook window is not open" end
            local ok = Painted(f)
            return ok, ok and "the Talents and spellbook window carries the XayaUI look" or "the Talents and spellbook window is not skinned"
        end },
    { text = "Open the other windows you use: Map, Friends list, Guild, Group finder, Professions, Auction house, Great Vault, Adventure Guide, Mail, Merchant, Options (Esc > Options).\n\n|cffffd100Expect:|r each has the XayaUI look and works exactly as before (nothing moved, nothing cut off). Pass if all look right; Fail and name the window if one does not.",
        noVerdict = true },
    { text = "Press |cffffd100Do it for me|r: Blizzard Windows is switched off.\n\n|cffffd100Expect:|r every open window has Blizzard's own look back at once, without a /reload.",
        setup = function() Set(function(c) c.windows = nil end) end,
        check = function()
            local f = OpenBag() or rawget(_G, "ContainerFrame1")
            if not f then return false, "no bag window to look at" end
            local ok = (not Painted(f)) and Alpha(f.NineSlice) ~= 0
            return ok, ok and "Blizzard's art is back on the bag window" or "the bag window still carries the XayaUI look"
        end },
    { text = "Press |cffffd100Do it for me|r: your reskin settings are put back as they were.",
        setup = function() PutBack() end,
        check = function() return BS() ~= nil, "your settings are back" end },
} })

-------------------------------------------------------------------------------
-- 2. The minimap: Square or Circle
-------------------------------------------------------------------------------
QA.Register("reskin-minimap", { title = "Reskin: minimap shape (Square / Circle)", area = "Reskin", qa = "RESKIN-M", order = 301, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: your reskin settings are remembered, then |cffffd100Blizzard UI Reskin > Minimap|r is switched on with |cffffd100Square|r.\n\n|cffffd100Expect:|r the minimap is square with a thin border; Blizzard's round frame is gone. The zone name, clock, calendar, tracking and mail buttons are where they were and still work.",
        setup = function() Keep(); Set(function(c) c.minimap = true; c.shape = "SQUARE" end) end,
        check = function()
            local s, why = Need(); if not s then return false, why end
            local shapeFn = rawget(_G, "GetMinimapShape")
            local ours = shapeFn == s.OurShape
            local ok = s.memo.minimap and s.memo.minimap.painted and Alpha(rawget(_G, "MinimapCompassTexture")) == 0
            return ok and true or false, (ok and "square mask set, round frame faded" or "the square look is not on") ..
                (ours and "; minimap-button addons are told SQUARE" or (shapeFn and "; another addon already answers GetMinimapShape (left alone)" or ""))
        end },
    { text = "Hover and click on the minimap: zoom with the mouse wheel, click a spot to ping it, open the tracking menu.\n\n|cffffd100Expect:|r everything works as on the round minimap; buttons from other addons sit on or near the square's edge. Pass if all is fine.",
        noVerdict = true },
    { text = "Press |cffffd100Do it for me|r: the shape is set to |cffffd100Circle|r.\n\n|cffffd100Expect:|r Blizzard's own round minimap and frame are back.",
        setup = function() Set(function(c) c.shape = nil end) end,
        check = function()
            local s, why = Need(); if not s then return false, why end
            local ok = not (s.memo.minimap and s.memo.minimap.painted) and Alpha(rawget(_G, "MinimapCompassTexture")) ~= 0
            return ok and true or false, ok and "round minimap and frame back" or "the square look is still on"
        end },
    { text = "Press |cffffd100Do it for me|r: your reskin settings are put back as they were.",
        setup = function() PutBack() end, check = function() return BS() ~= nil, "your settings are back" end },
} })

-------------------------------------------------------------------------------
-- 3. Tooltips
-------------------------------------------------------------------------------
local function TipCenter()
    local gt = rawget(_G, "GameTooltip"); local ns9 = gt and gt.NineSlice; local c = ns9 and ns9.Center
    if c and c.GetVertexColor then local ok, r, g, b = pcall(c.GetVertexColor, c); if ok then return r, g, b end end
end
QA.Register("reskin-tooltips", { title = "Reskin: tooltips in the theme's colours", area = "Reskin", qa = "RESKIN-T", order = 302, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: your reskin settings are remembered, then |cffffd100Blizzard UI Reskin > Tooltips|r is switched on. Then hover any player, NPC or item and keep the pointer there while you press |cffffd100Check|r.\n\n|cffffd100Expect:|r the tooltip's background is the theme's window colour and its border the theme's border colour. Its text is unchanged.",
        setup = function() Keep(); Set(function(c) c.tooltips = true end) end,
        check = function()
            local ns = NS(); local gt = rawget(_G, "GameTooltip")
            if not (gt and gt:IsShown()) then return false, "no tooltip is showing: hover something and press Check again" end
            local r, g, b = TipCenter()
            local want = ns and ns.Theme and ns.Theme.Col and ns.Theme.Col("xui-window", "bg", { 0.06, 0.06, 0.06, 1 })
            if not (r and want) then return false, "the tooltip's centre colour could not be read" end
            local ok = Near(r, want[1]) and Near(g, want[2]) and Near(b, want[3])
            return ok, ("tooltip centre %.2f %.2f %.2f, theme window colour %.2f %.2f %.2f"):format(r, g, b, want[1], want[2], want[3])
        end },
    { text = "Hover an item in your bags and compare it with what you wear (Shift).\n\n|cffffd100Expect:|r both tooltips have the same look, the item's name keeps its quality colour and every line is readable. Pass if so.",
        noVerdict = true },
    { text = "Press |cffffd100Do it for me|r: your reskin settings are put back as they were.",
        setup = function() PutBack() end, check = function() return BS() ~= nil, "your settings are back" end },
} })

-------------------------------------------------------------------------------
-- 4. Objective tracker: one box for the tracker, a box per section
-------------------------------------------------------------------------------
local function HeaderCol(frame)
    local h = frame and frame.Header; local t = h and h.Text
    if t and t.GetTextColor then local ok, r, g, b = pcall(t.GetTextColor, t); if ok then return r, g, b, Alpha(h.Background) end end
end
QA.Register("reskin-tracker", { title = "Reskin: objective tracker (one box, a box per section)", area = "Reskin", qa = "RESKIN-O", order = 303, prefill = true, steps = {
    { text = "Track at least one quest first. Then press |cffffd100Do it for me|r: your reskin settings are remembered, then |cffffd100Blizzard UI Reskin > Objective Tracker|r is switched on (every section).\n\n|cffffd100Expect:|r the tracker's header and each section's header (Quests, Campaign, ...) lose Blizzard's header bar and show in the theme's label colour; quest titles and lines are in the theme's text colours, finished lines muted. Nothing moves.",
        setup = function() Keep(); Set(function(c) c.tracker = true end) end,
        check = function()
            local ns = NS(); local want = ns and ns.Theme and ns.Theme.Col and ns.Theme.Col("xui-label", "text", { 1, 0.82, 0, 1 })
            local r, g, b, a = HeaderCol(rawget(_G, "ObjectiveTrackerFrame"))
            if not (r and want) then return false, "the tracker's header could not be read" end
            local ok = Near(r, want[1]) and Near(g, want[2]) and Near(b, want[3]) and a == 0
            return ok, ok and "tracker header in the theme's label colour, Blizzard's header bar faded" or ("tracker header %.2f %.2f %.2f, bar alpha %s"):format(r, g, b, tostring(a))
        end },
    { text = "Press |cffffd100Do it for me|r: the |cffffd100Quests|r section is left out (its own box on the Objective Tracker page is unticked).\n\n|cffffd100Expect:|r the Quests section's header has Blizzard's look back; the other sections keep the XayaUI look.",
        setup = function() Set(function(c) c.otOff.quests = true end) end,
        check = function()
            local _, _, _, a = HeaderCol(rawget(_G, "QuestObjectiveTracker"))
            if a == nil then return false, "the Quests section could not be read" end
            return a ~= 0, a ~= 0 and "Quests has Blizzard's header bar back" or "Quests still has the XayaUI look"
        end },
    { text = "Open |cffffd100Blizzard UI Reskin > Objective Tracker|r and read the section names.\n\n|cffffd100Expect:|r the names are the headings the game shows in your tracker (Quests, Campaign, World Quests, ...). Pass if they match; Fail and say which reads wrong.",
        setup = function() local ns = NS(); if ns and ns.OpenSettingsPage then pcall(ns.OpenSettingsPage, "reskin", "objtracker") end end,
        noVerdict = true },
    { text = "Press |cffffd100Do it for me|r: your reskin settings are put back as they were.",
        setup = function() PutBack() end, check = function() return BS() ~= nil, "your settings are back" end },
} })

-------------------------------------------------------------------------------
-- 5. Battle.net toasts and pop-up dialogs (Reskin 0.6.10)
-------------------------------------------------------------------------------
local POPUP = "XAYAUI_QA_RESKIN_POPUP"
local function ShowPopup()   -- our own harmless dialog: text and one OK button; nothing happens on OK
    local d = rawget(_G, "StaticPopupDialogs"); if type(d) ~= "table" or type(rawget(_G, "StaticPopup_Show")) ~= "function" then return end
    d[POPUP] = d[POPUP] or { text = "XayaUI QA: this is a test pop-up. Look at it, then press OK.", button1 = rawget(_G, "OKAY") or "OK",
        timeout = 0, whileDead = true, hideOnEscape = true }
    pcall(StaticPopup_Show, POPUP)
end
local function OpenPopup()
    for i = 1, 4 do local f = rawget(_G, "StaticPopup" .. i); if f and f:IsShown() and f.which == POPUP then return f end end
    for i = 1, 4 do local f = rawget(_G, "StaticPopup" .. i); if f and f:IsShown() then return f end end
end
local function ThemeBg() local ns = NS(); return ns and ns.Theme and ns.Theme.Col and ns.Theme.Col("xui-window", "bg", { 0.06, 0.06, 0.06, 1 }) end
QA.Register("reskin-toasts", { title = "Reskin: Battle.net toasts and pop-up dialogs", area = "Reskin", qa = "RESKIN-P", order = 304, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: your reskin settings are remembered, then |cffffd100Blizzard UI Reskin > Toasts and Pop-ups|r is switched on (both parts).\n\n|cffffd100Expect:|r nothing on screen changes yet.",
        setup = function() Keep(); Set(function(c) c.toasts = true end) end,
        check = function() local s, why = Need(); if not s then return false, why end; local on = s.Live().toasts; return on, on and "Toasts and Pop-ups is on" or "Toasts and Pop-ups did not switch on" end },
    { text = "Press |cffffd100Do it for me|r: a test pop-up from XayaUI opens (one OK button; pressing it does nothing else).\n\n|cffffd100Expect:|r the pop-up has a solid dark background in the theme's window colour and a thin border, with no Blizzard dialog art. Its text and OK button are as usual.",
        setup = function() ShowPopup() end,
        check = function()
            local f = OpenPopup(); if not f then return false, "no pop-up is open" end
            local ok = Painted(f) and Alpha(f.BG) == 0
            return ok, ok and (f:GetName() .. " carries the XayaUI look (Blizzard's dialog art faded)") or (f:GetName() .. " still has Blizzard's art")
        end },
    { text = "Press the pop-up's |cffffd100OK|r. Then, over your next play, look at any pop-up the game opens (a group invite, Are you sure you want to delete, a ready-to-release prompt).\n\n|cffffd100Expect:|r each has the same look, its text is readable and its buttons work. Pass if so; Fail and name the pop-up if not.",
        noVerdict = true },
    { text = "Press |cffffd100Check|r to read the Battle.net toast's colours (no toast needs to be on screen).\n\n|cffffd100Expect:|r the check reports the theme's window colour. The next time a Battle.net friend comes online, the toast that slides in is dark with a thin border; its name and icon are as before.",
        check = function()
            local f = rawget(_G, "BNToastFrame"); local want = ThemeBg()
            if not (f and f.GetBackdropColor and want) then return false, "the Battle.net toast could not be read" end
            local ok, r, g, b = pcall(f.GetBackdropColor, f)
            if not (ok and r) then return false, "the Battle.net toast's colour could not be read" end
            local good = Near(r, want[1]) and Near(g, want[2]) and Near(b, want[3])
            return good, ("toast colour %.2f %.2f %.2f, theme window colour %.2f %.2f %.2f"):format(r, g, b, want[1], want[2], want[3])
        end },
    { text = "Press |cffffd100Do it for me|r: Toasts and Pop-ups is switched off and the test pop-up opens again.\n\n|cffffd100Expect:|r the pop-up has Blizzard's own look back at once, without a /reload. Press its OK.",
        setup = function() Set(function(c) c.toasts = nil end); ShowPopup() end,
        check = function()
            local f = OpenPopup(); if not f then return false, "no pop-up is open" end
            local ok = (not Painted(f)) and Alpha(f.BG) ~= 0
            return ok, ok and "Blizzard's art is back on the pop-up" or "the pop-up still carries the XayaUI look"
        end },
    { text = "Press |cffffd100Do it for me|r: your reskin settings are put back as they were.",
        setup = function() local h = rawget(_G, "StaticPopup_Hide"); if type(h) == "function" then pcall(h, POPUP) end; PutBack() end,
        check = function() return BS() ~= nil, "your settings are back" end },
} })

-------------------------------------------------------------------------------
-- 6. Loot rolls (Reskin 0.6.11, a Blizzard Windows entry)
-------------------------------------------------------------------------------
local function OpenRoll() for i = 1, 4 do local f = rawget(_G, "GroupLootFrame" .. i); if f and f:IsShown() then return f end end end
QA.Register("reskin-lootroll", { title = "Reskin: loot rolls (Need, Greed, Transmog)", area = "Reskin", qa = "RESKIN-L", order = 305, prefill = true, steps = {
    { text = "This one needs a loot roll: do it in a dungeon or raid group (a Follower dungeon works). Press |cffffd100Do it for me|r: your reskin settings are remembered, then |cffffd100Blizzard UI Reskin > Blizzard Windows|r is switched on with |cffffd100Loot rolls|r ticked.",
        setup = function() Keep(); Set(function(c) c.windows = true; c.winOff.lootroll = nil end) end,
        check = function() local s, why = Need(); if not s then return false, why end; local on = s.WinOn and s.WinOn({ key = "lootroll" }); return on and true or false, on and "Loot rolls are on" or "Loot rolls did not switch on" end },
    { text = "When a loot roll shows, press |cffffd100Check|r while it is on screen (before you roll).\n\n|cffffd100Expect:|r the roll has a solid dark background and a thin border in the item's quality colour (purple for epic, blue for rare), no Blizzard loot frame art. The item name, icon, timer and the Need / Greed / Transmog / Pass buttons are as before.",
        check = function()
            local f = OpenRoll(); if not f then return false, "no loot roll is on screen: press Check while one shows" end
            local s = BS(); local m = s and s.memo[f]
            if not (m and m.painted) then return false, f:GetName() .. " is not skinned" end
            local c = m.edgeCol or {}   -- the colour the skin painted its border (a colour texture has no colour to read back)
            local ok1, er, eg, eb = c[1] ~= nil, c[1], c[2], c[3]
            local ok2, qr, qg, qb = pcall(f.Border.GetVertexColor, f.Border)
            local same = ok1 and ok2 and Near(er, qr) and Near(eg, qg) and Near(eb, qb)
            return (same and Alpha(f.Background) == 0) and true or false,
                ("%s: Blizzard art alpha %s; our border %.2f %.2f %.2f, item quality %.2f %.2f %.2f"):format(f:GetName(), tostring(Alpha(f.Background)), er or -1, eg or -1, eb or -1, qr or -1, qg or -1, qb or -1)
        end },
    { text = "Roll on it (any choice).\n\n|cffffd100Expect:|r every button works as before and the roll closes as usual. Pass if so.",
        noVerdict = true },
    { text = "Press |cffffd100Do it for me|r: your reskin settings are put back as they were.",
        setup = function() PutBack() end, check = function() return BS() ~= nil, "your settings are back" end },
} })
