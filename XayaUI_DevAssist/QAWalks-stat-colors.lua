-------------------------------------------------------------------------------
-- QAWalks-stat-colors.lua (XayaUI_DevAssist 0.7.72): in-game QA walkthrough for the Stat Calculator's change numbers, stat-name colours
-- and hover notes (XayaUI QoL 0.7.54, XayaUI Bonus Features 0.6.38; QA steps B306 to B311). Her words (REQUEST-LOG session
-- 014bN6tUDLJ6T742DewZDg1s): #5 "stat calculator colors need to ignore themeing colors"; #6 "xayaui theme is fine for everything except
-- change numbers and stat colors", "1 or adjust for color blind mode" (1 = "Green up, red down"); #8 "tooltips do not look like they're
-- supposed to"; #15 her answers "Hide notes unless Dev Assist", "XayaUI theme only", "Yes, everywhere (Recommended)".
--   B306 a higher Critical Strike: its new value is "better" and drawn in the game's green (GREEN_FONT_COLOR);
--   B307 a lower one: "worse", the game's red (RED_FONT_COLOR);
--   B308 more Haste: the GCD (or, with a fixed GCD, the attack speed) gets shorter: "better", green (lower is better for seconds);
--   B309 with a XayaUI colour-blind base theme (colorblind / protan / tritan): better blue, worse orange (the colorblind palette's accent
--        and danger colours, XayaUI/Theme.lua T.BUILTIN.colorblind);
--   B310 the Critical Strike card's hover: its title in the stat's colour (CM.STAT_COLORS.crit), a non-stat line ("From rating") not;
--   B311 the hover's notes show while XayaUI Dev Assist is loaded (this walkthrough always runs with it on: the player's view without it
--        is checklist step B312, done by hand).
-- Standing rule V22 (Xaya 2026-11-07): each check reads back what the panel drew (the font string's colour, the tooltip's lines and
-- their colours), works out the expected colour itself from the game's colour objects and the theme (not from the panel's code),
-- offers its verdict (prefill = true; recorded only on her click) and puts what it read in the note. The last step clears the typed
-- numbers and puts the panel back as it was. Reads go through core's service list ("statCalc", "statModel"). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Svc(name) local ns = NS(); return ns and ns.Service and ns.Service(name) or nil end
local function SC() return Svc("statCalc") end
local function CMod() local s = Svc("statModel"); return s and s.CM end

local function Ready()
    local sc = SC()
    if not sc then return false, "XayaUI Bonus Features is not loaded (or is older than 0.6.38), or XayaUI QoL is off" end
    if not sc.SetInput then return false, "XayaUI Bonus Features is older than 0.6.38" end
    local c = sc.Cfg()
    if not (c and c.enabled) then return false, "the Character Toolkit is off: XayaUI > Bonus Features > Character Toolkit" end
    if not c.panel then return false, "the Stat Calculator panel is off: Bonus Features > Character Toolkit > Panel" end
    return true
end

-- what the walkthrough changes (the tab, open or closed, the typed numbers it types), remembered once and put back in the last step
local saved
local TYPED = { "crit", "haste" }
local function Remember()
    if saved then return end
    local sc = SC(); local c = sc and sc.Cfg()
    if not c then return end
    saved = { tab = c.tab, open = sc.Shown(), stats = {} }
    for _, k in ipairs(TYPED) do saved.stats[k] = c.whatIfStats and c.whatIfStats[k] end
end
local function PutBack()
    local sc = SC(); local c = sc and sc.Cfg()
    if GameTooltip then GameTooltip:Hide() end
    if not (c and saved) then return end
    for _, k in ipairs(TYPED) do sc.SetInput(k, saved.stats[k] and tostring(saved.stats[k]) or "") end
    c.tab = saved.tab
    if saved.open then sc.Open(saved.tab) elseif sc.Shown() then sc.Close() end
    saved = nil
end
-- open the Stats tab with these typed amounts ({ crit = 100 } = 100 more crit rating; the others cleared)
local function Type(amounts)
    local ok, why = Ready(); if not ok then error(why) end
    Remember()
    local sc = SC()
    local done, w2 = sc.Open("stats")
    if not done then error(w2 or "the panel did not open") end
    for _, k in ipairs(TYPED) do sc.SetInput(k, amounts[k] and tostring(amounts[k]) or "") end
end

-- colours
local function Same(a, b) return a and b and math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01 end
local function Hex(c) return c and ("%.2f,%.2f,%.2f"):format(c[1], c[2], c[3]) or "none" end
local function GameRGB(name)
    local o = rawget(_G, name)
    if type(o) ~= "table" or type(o.GetRGB) ~= "function" then return nil end
    local ok, r, g, b = pcall(o.GetRGB, o)
    if ok and type(r) == "number" then return { r, g, b } end
end
local CB_BASES = { colorblind = true, protan = true, tritan = true }
-- the base theme (the global one: the Stat Calculator has no theme scope of its own) and whether it is a colour-blind one
local function Base()
    local ns = NS(); local T = ns and ns.Theme
    local ok, b = pcall(function() return T and T.EffBase and T.EffBase() end)
    b = ok and b or nil
    if type(b) ~= "string" then return "unknown", false end
    if CB_BASES[b] then return b, true end
    local P = ns and ns.Settings and ns.Settings("platform")   -- (the saved themes, through the Platform's settings view)
    local themes = P and P.themes
    local sv = type(themes) == "table" and themes[b]
    if type(sv) == "table" then
        local sb = (sv.base == "custom") and sv.under or sv.base
        if CB_BASES[sb] then return b .. " (saved, from " .. sb .. ")", true end
    end
    return b, false
end
local function CBPal(key)
    local ns = NS(); local T = ns and ns.Theme
    local c = T and type(T.BUILTIN) == "table" and T.BUILTIN.colorblind and T.BUILTIN.colorblind.pal and T.BUILTIN.colorblind.pal[key]
    if type(c) == "table" then return { c[1], c[2], c[3] } end
end
local function Expected(dir)
    local _, cb = Base()
    if cb then return CBPal(dir == "better" and "accent" or "danger"), dir == "better" and "blue (the colour-blind theme's accent)" or "orange (its danger colour)" end
    return GameRGB(dir == "better" and "GREEN_FONT_COLOR" or "RED_FONT_COLOR"), dir == "better" and "the game's green" or "the game's red"
end

-- the drawn new value of one card: its model item, the record under its value and the font string's colour
local function CardChange(key)
    local sc = SC()
    local d = sc and sc.Shown() and sc.Drawn()
    if not d then return nil, "the Stat Calculator is not open: press Do it for me" end
    local it = d.model and d.model.byKey and d.model.byKey[key]
    if not it then return nil, "no " .. key .. " card on the Stats tab" end
    if not it.newValue then return nil, (it.label or key) .. ": no new value under it (the game hid the stat, or the number did not change it)" end
    local hit
    for _, r in ipairs(d.layout or {}) do if r.kind == "hit" and r.text == key then hit = r end end
    local rec
    for _, r in ipairs(d.layout or {}) do
        if r.kind == "change" and r.text == it.newValue and (not hit or (r.y >= hit.y and r.y < hit.y + hit.h + 0.5)) then rec = rec or r end
    end
    if not rec then return nil, (it.label or key) .. ": its new value " .. tostring(it.newValue) .. " is not drawn" end
    for _, f in ipairs(d.fonts or {}) do
        if f:IsShown() and f:GetText() == rec.text then
            local _, _, _, x, y = f:GetPoint(1)
            if type(x) == "number" and type(y) == "number" and math.abs(x - rec.x) < 0.5 and math.abs(-y - rec.y) < 0.5 then
                local r, g, b = f:GetTextColor()
                return { label = it.label or key, text = rec.text, tone = it.newTone, col = { r, g, b } }
            end
        end
    end
    return nil, (it.label or key) .. ": its new value's font string was not found"
end
local function CheckOne(key, want)
    local ch, why = CardChange(key)
    if not ch then return nil, why end
    local exp, words = Expected(want)
    local base = Base()
    local note = ("%s: new value %s, meaning %s, drawn %s; expected %s %s (base theme %s)"):format(ch.label, ch.text, tostring(ch.tone), Hex(ch.col), words, Hex(exp), base)
    if not exp then return nil, note .. "; the expected colour could not be read" end
    return ch.tone == want and Same(ch.col, exp), note
end

-- B308: the GCD card, or the attack speed with a fixed GCD (Rogue, Brewmaster / Windwalker, Cat Form)
local function CheckFaster()
    local ok, note = CheckOne("map_gcd", "better")
    if ok ~= nil then return ok, note end
    local ok2, note2 = CheckOne("map_aspeed", "better")
    return ok2, tostring(note) .. "; " .. tostring(note2)
end
-- B309: needs a colour-blind base theme
local function CheckCB()
    local base, cb = Base()
    if not cb then return nil, "your base theme is " .. base .. ": pick a colour-blind theme in /xui > Theme (Colorblind: ...), then press Do it for me and Check" end
    local okU, nU = CheckOne("map_crit", "better")
    local okD, nD = CheckOne("map_haste", "worse")
    if okU == nil or okD == nil then return nil, tostring(nU) .. "; " .. tostring(nD) end
    return okU and okD, nU .. "; " .. nD
end

-- B310 / B311: the Critical Strike card's hover, as the game's tooltip shows it
local function ShowCritHover()
    Type({})
    local d = SC().Drawn()
    for _, b in ipairs(d and d.buttons or {}) do
        if b:IsShown() and b.item and b.item.key == "map_crit" then
            local fn = b:GetScript("OnEnter")
            if fn then fn(b) end
            return
        end
    end
    error("no Critical Strike card on the Stats tab")
end
local function TipLines()
    local out = {}
    if not (GameTooltip and GameTooltip:IsShown()) then return out end
    local n = GameTooltip.NumLines and GameTooltip:NumLines() or 0
    for i = 1, n do
        local L, Rt = _G["GameTooltipTextLeft" .. i], _G["GameTooltipTextRight" .. i]
        local l = { left = L and L:GetText(), right = Rt and Rt:IsShown() and Rt:GetText() or nil }
        if L then local r, g, b = L:GetTextColor(); l.lc = { r, g, b } end
        out[#out + 1] = l
    end
    return out
end
local function CheckNames()
    local cm = CMod()
    if not cm then return nil, "XayaUI QoL's stat model is not loaded" end
    local lines = TipLines()
    if #lines == 0 then return nil, "the hover is not open: press Do it for me (keep the mouse off other frames)" end
    local title, rating = lines[1], nil
    for _, l in ipairs(lines) do if l.left == "From rating" then rating = l end end
    local want = cm.STAT_COLORS and cm.STAT_COLORS.crit
    local note = ("title '%s' drawn %s (Critical Strike's colour %s); 'From rating' drawn %s"):format(tostring(title.left), Hex(title.lc), Hex(want), rating and Hex(rating.lc) or "not in the hover")
    return Same(title.lc, want) and (rating == nil or not Same(rating.lc, want)), note
end
local function CheckNotes()
    local cm = CMod()
    local d = SC() and SC().Drawn()
    local it = d and d.model and d.model.byKey and d.model.byKey.map_crit
    if not (cm and it) then return nil, "the Stat Calculator is not open: press Do it for me on the step before" end
    local lines = TipLines()
    if #lines == 0 then return nil, "the hover is not open: press Do it for me on the step before" end
    local tips = it.tip or {}
    local shown = 0
    for _, t in ipairs(tips) do for _, l in ipairs(lines) do if l.left == t then shown = shown + 1; break end end end
    local note = ("XayaUI Dev Assist loaded: %s; the card has %d note line(s); %d of them in the hover"):format(tostring(cm.NotesOn and cm.NotesOn()), #tips, shown)
    if #tips == 0 then return nil, note end
    return shown == #tips, note
end

QA.Register("stat-colors", { title = "Stat Calculator: change numbers green / red, stat names in their colour, hover notes (B306-B311)",
    qa = "B306, B307, B308, B309, B310, B311", order = 531, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the Stat Calculator opens on |cffffd100Stats|r with 100 more |cffffd100Critical Strike|r rating typed.\n\n|cffffd100Expect:|r under Critical Strike's Current value, its new value with a + in |cff19ff19green|r (better), not your theme's colour. The check reads the colour it is drawn in.",
        setup = function() Type({ crit = 100 }) end, check = function() return CheckOne("map_crit", "better") end },
    { text = "Press |cffffd100Do it for me|r: 100 |cffffd100less|r Critical Strike rating.\n\n|cffffd100Expect:|r the new value under it with a - in |cffff1919red|r (worse).",
        setup = function() Type({ crit = -100 }) end, check = function() return CheckOne("map_crit", "worse") end },
    { text = "Press |cffffd100Do it for me|r: 300 more |cffffd100Haste|r rating.\n\n|cffffd100Expect:|r the |cffffd100GCD|r's new value is shorter (a -) and |cff19ff19green|r: for seconds lower is better. (With a fixed 1.0 s GCD, look at Attack Speed instead.)",
        setup = function() Type({ haste = 300 }) end, check = CheckFaster },
    { text = "Only with a colour-blind theme: in |cffffd100/xui > Theme|r pick one of the |cffffd100Colorblind|r themes (skip this step otherwise). Then press |cffffd100Do it for me|r: 100 more Critical Strike, 300 less Haste.\n\n|cffffd100Expect:|r Critical Strike's new value in |cff56b4e9blue|r (better), Haste's in |cffff8c19orange|r (worse); no green or red. Put your theme back afterwards.",
        setup = function() Type({ crit = 100, haste = -300 }) end, check = CheckCB },
    { text = "Press |cffffd100Do it for me|r: the typed numbers are cleared and the |cffffd100Critical Strike|r card's hover opens (keep the mouse still).\n\n|cffffd100Expect:|r the hover's title |cffffd100Critical Strike|r in Critical Strike's own colour (as its name in the list), other lines such as From rating in your theme's colours.",
        setup = ShowCritHover, check = CheckNames },
    { text = "Same hover. |cffffd100Expect:|r while XayaUI Dev Assist is on (it is, for this walkthrough) the hover ends with its notes (the paragraphs that say where the numbers come from). Without Dev Assist the notes are hidden: that is checklist step |cffffd100B312|r, done by hand after this walkthrough (switch Dev Assist off in the AddOns list, /reload, hover Critical Strike).",
        check = CheckNotes },
    { text = "Press |cffffd100Do it for me|r to clear the typed numbers and put the Stat Calculator back as it was, then |cffffd100Done|r.", done = true, setup = PutBack,
        check = function() return saved == nil, saved == nil and "put back" or "press Do it for me" end },
} })
