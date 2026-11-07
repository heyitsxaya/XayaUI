-------------------------------------------------------------------------------
-- Calculator.lua (Bonus 0.6.8, written 2026-11-04; Xaya: "add a feature: a little calculator"). UNTESTED IN GAME.
--   * /xui calc <sum>: the answer in chat, e.g. "/xui calc 23,249 / 3,472" -> "23,249 / 3,472 = 6.696141" (23249 / 3472 = 6.69614055...; the header said 6.696083 until Bonus 0.6.11).
--   * /xui calc (nothing after it), or Calculator in the minimap button's list: a small window with a typed line and a keypad.
--     Enter or = works the sum out; the answer replaces the line so the next sum can build on it; the last sums are listed above.
--   * What it reads: numbers (3472, 3,472, 3.5, .5), k / m / b after a number (12k = 12,000), + - * / ^, x or the multiply sign,
--     the divide sign, % after a number (15% = 0.15), brackets, a leading minus. Nothing else: no functions, no variables.
-- Typed text is never run as code: the sum is read by the small parser below, never handed to loadstring or RunScript.
--   * (Bonus 0.6.16; Xaya 2026-11-06: "Calculator needs its own enable / disable toggle") a tick box on its row in Bonus Features >
--     Utilities turns the Calculator's window on or off. Off: no window (an open one closes), /xui calc alone only says it is off, no
--     Calculator row in the minimap button's list; /xui calc <sum> still answers in chat (Xaya 2026-11-06, asked whether off should
--     stop it too: "Is there a performance difference? If no, just the window" -- there is none: the command is registered either way
--     to say it is off, and a sum is worked out only when one is typed). On by default, as it always was (her answer). Its saved sums
--     and window position are kept. Level reached (V14): the file is read at login (Bonus is not load-on-demand); the window is never
--     built while it is off. It has no events, OnUpdate, timers or hooks at any time.
-- Own code (no other addon's code or data); Blizzard's frame API only.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI)

local W, TITLE_H, KEY_H, LINE_H = 216, 20, 26, 22
local HISTORY_LINES, HISTORY_KEPT = 3, 10
local MAX_LEN = 200            -- characters in one sum
local KEYS = {
    { "C", "(", ")", "\195\183" },     -- the divide sign (U+00F7)
    { "7", "8", "9", "\195\151" },     -- the multiply sign (U+00D7)
    { "4", "5", "6", "-" },
    { "1", "2", "3", "+" },
    { "0", ".", "%", "=" },
}
local SUFFIX = { k = 1e3, m = 1e6, b = 1e9 }

-------------------------------------------------------------------------------
-- Reading a sum
-------------------------------------------------------------------------------
-- the multiply / divide / minus signs a keyboard or the keypad may give, as the plain characters the parser reads
local function Normalize(s)
    s = s:gsub("\195\151", "*"):gsub("\195\183", "/"):gsub("\226\136\146", "-")
    return s
end

-- one number at position i: digits with commas between groups of three, a decimal part, an optional k / m / b
local function ReadNumber(s, i)
    local text = s:match("^[%d,]*%.?%d*", i)
    if not text or text == "" or text == "." or not text:find("%d") then return nil, nil, "a number was expected" end
    local j = i + #text
    local whole = text:match("^[^%.]*")
    if whole:find(",") then   -- 1,234,567: 1 to 3 digits, then groups of exactly 3 (Lua patterns cannot repeat a group, so split)
        local first, okGroups = true, true
        for part in (whole .. ","):gmatch("([^,]*),") do
            if first then okGroups = part:match("^%d%d?%d?$") ~= nil; first = false
            elseif not part:match("^%d%d%d$") then okGroups = false end
        end
        if not okGroups then return nil, nil, ("commas in %s must separate groups of three digits"):format(text) end
    end
    local v = tonumber((text:gsub(",", "")))
    if not v then return nil, nil, ("%s is not a number"):format(text) end
    local suf = s:sub(j, j):lower()
    local after = s:sub(j + 1, j + 1)
    -- (D51) x / X after the suffix is a multiply ("12kx3" = 36,000); any other letter makes it a word ("12kg" stays refused)
    if SUFFIX[suf] and (not after:match("%a") or after == "x" or after == "X") then v = v * SUFFIX[suf]; j = j + 1 end
    return v, j
end

local function Tokens(s)
    local out, i, n = {}, 1, #s
    while i <= n do
        local c = s:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c:match("[%d%.]") then
            local v, j, err = ReadNumber(s, i)
            if not v then return nil, err end
            out[#out + 1] = { k = "num", v = v }
            i = j
        elseif c:match("[%+%-%*/%^%%%(%)]") then
            out[#out + 1] = { k = c }
            i = i + 1
        elseif c == "x" or c == "X" then
            out[#out + 1] = { k = "*" }
            i = i + 1
        else
            local word = s:match("^[%a_][%w_]*", i) or c
            return nil, ("%s is not something a sum can hold"):format(word)
        end
    end
    return out
end

-- recursive descent: sum = term {(+|-) term}; term = unary {(*|/) unary}; unary = (-|+) unary | power; power = postfix [^ unary];
-- postfix = primary {%}; primary = number | ( sum ). A leading minus binds looser than ^, so -2^2 = -4 and 2^-1 = 0.5.
local function Parse(tokens)
    local pos = 1
    local function peek() return tokens[pos] and tokens[pos].k end
    local function take() pos = pos + 1; return tokens[pos - 1] end
    local sum
    local function primary()
        local t = take()
        if not t then error({ msg = "the sum ends too soon" }) end
        if t.k == "num" then return t.v end
        if t.k == "(" then
            local v = sum()
            if peek() ~= ")" then error({ msg = "a closing bracket is missing" }) end
            take()
            return v
        end
        error({ msg = ("%s cannot go there"):format(t.k) })
    end
    local function postfix()
        local v = primary()
        while peek() == "%" do take(); v = v / 100 end
        return v
    end
    local unary
    local function power()
        local v = postfix()
        if peek() == "^" then take(); v = v ^ unary() end
        return v
    end
    unary = function()
        if peek() == "-" then take(); return -unary() end
        if peek() == "+" then take(); return unary() end
        return power()
    end
    local function term()
        local v = unary()
        while peek() == "*" or peek() == "/" do
            local op = take().k
            local r = unary()
            if op == "*" then v = v * r
            else
                if r == 0 then error({ msg = "cannot divide by zero" }) end
                v = v / r
            end
        end
        return v
    end
    sum = function()
        local v = term()
        while peek() == "+" or peek() == "-" do
            local op = take().k
            local r = term()
            if op == "+" then v = v + r else v = v - r end
        end
        return v
    end
    local v = sum()
    if pos <= #tokens then error({ msg = ("%s cannot go there"):format(tokens[pos].k == "num" and "a number" or tokens[pos].k) }) end
    return v
end

-- ns.CalcEval(text) -> number, or nil and why
function ns.CalcEval(text)
    if type(text) ~= "string" then return nil, "nothing to work out" end
    if #text > MAX_LEN then return nil, ("a sum can be at most %d characters"):format(MAX_LEN) end
    local s = Normalize(text)
    if not s:find("%S") then return nil, "nothing to work out" end
    local tokens, err = Tokens(s)
    if not tokens then return nil, err end
    local ok, v = pcall(Parse, tokens)
    if not ok then return nil, type(v) == "table" and v.msg or "that sum cannot be read" end
    if v ~= v then return nil, "the answer is not a number" end
    if v == math.huge or v == -math.huge then return nil, "the answer is too large" end
    return v
end

-- 1234567.5 -> "1,234,567.5"; up to 6 decimals, trailing zeros dropped; very large or tiny answers in e-notation
local function Group(int)
    local neg, digits = int:match("^(%-?)(%d+)$")
    if not digits then return int end
    local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then out = out:sub(2) end
    return neg .. out
end
function ns.CalcFormat(v)
    if type(v) ~= "number" then return "" end
    local a = math.abs(v)
    if a >= 1e15 or (a > 0 and a < 1e-6) then return ("%.6g"):format(v) end
    local s = ("%.6f"):format(v):gsub("0+$", ""):gsub("%.$", "")
    if s == "-0" then s = "0" end
    local int, frac = s:match("^(%-?%d+)(%.?%d*)$")
    if not int then return s end
    return Group(int) .. frac
end

-- the answer as the typed line keeps it for the next sum (D49): every digit needed to read the same number back (the shortest of
-- %.15g / %.16g / %.17g that does), written out in plain digits, never in e-notation (the line cannot read "1e-07"). The answer line
-- and the history still show ns.CalcFormat's rounded answer.
function ns.CalcExact(v)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return "" end
    if v == 0 then return "0" end
    local s
    for p = 15, 17 do s = ("%." .. p .. "g"):format(v); if tonumber(s) == v then break end end
    local sign, mant, exp = s:match("^(%-?)([%d%.]+)e([%+%-]%d+)$")
    if not mant then return s end
    local int, frac = mant:match("^(%d*)%.?(%d*)$")
    local digits, point = int .. frac, #int + tonumber(exp)   -- point: how many digits stand before the decimal point
    if point <= 0 then return sign .. "0." .. ("0"):rep(-point) .. digits end
    if point >= #digits then return sign .. digits .. ("0"):rep(point - #digits) end
    return sign .. digits:sub(1, point) .. "." .. digits:sub(point + 1)
end

-------------------------------------------------------------------------------
-- Saved: CueRulesDB.calculator = { enabled, point, x, y, history = { "sum = answer", ... } } (enabled: false = off; nil or true = on)
-------------------------------------------------------------------------------
local function DB()
    if type(CueRulesDB) ~= "table" then return nil end
    local d = CueRulesDB.calculator
    if type(d) ~= "table" then d = {}; CueRulesDB.calculator = d end
    if type(d.history) ~= "table" then d.history = {} end
    while #d.history > HISTORY_KEPT do table.remove(d.history, 1) end
    return d
end

-- on unless switched off (read without creating anything: the minimap list asks before the saved settings may exist)
local function On()
    local d = type(CueRulesDB) == "table" and CueRulesDB.calculator or nil
    return not (type(d) == "table" and d.enabled == false)
end
ns.Calculator_IsOn = On

local function Remember(line)
    local d = DB()
    if not d then return end
    d.history[#d.history + 1] = line
    while #d.history > HISTORY_KEPT do table.remove(d.history, 1) end
end

-------------------------------------------------------------------------------
-- The window
-------------------------------------------------------------------------------
local frame

local function RefreshHistory()
    if not frame then return end
    local d, lines = DB(), {}
    local h = d and d.history or {}
    for i = math.max(1, #h - HISTORY_LINES + 1), #h do lines[#lines + 1] = h[i] end
    frame.history:SetText(table.concat(lines, "\n"))
end

local function Work(line)
    local v, err = ns.CalcEval(line)
    if not v then
        frame.result:SetText(err)
        frame.result:SetTextColor(1, 0.45, 0.35)
        return
    end
    local answer = ns.CalcFormat(v)
    Remember(("%s = %s"):format(line, answer))
    frame.result:SetText(answer)
    frame.result:SetTextColor(1, 1, 1)
    frame.edit:SetText(ns.CalcExact(v))   -- the next sum builds on the answer, at full precision (D49)
    frame.edit:SetCursorPosition(#frame.edit:GetText())
    RefreshHistory()
end

local function Press(key)
    local e = frame.edit
    if key == "=" then Work(e:GetText())
    elseif key == "C" then e:SetText(""); frame.result:SetText("")
    else
        local t = e:GetText() .. key
        if #t <= MAX_LEN then e:SetText(t) end
    end
end

local function SavePosition(f)
    local d = DB()
    if not d then return end
    local point, _, _, x, y = f:GetPoint(1)
    d.point, d.x, d.y = point, x, y
end

local function Build()
    if frame then return frame end
    local M = ns.UI_MARGIN or 10   -- the one margin and gutter of #351 (set by XayaUI_Options when it is loaded)
    local G = math.floor((ns.UI_GUTTER or 10) / 2)
    local keyW = math.floor((W - 2 * M - 3 * G) / 4)
    local f = CreateFrame("Frame", "XayaUICalculator", UIParent, "BackdropTemplate")
    frame = f
    f:SetSize(W, TITLE_H + M + HISTORY_LINES * 12 + G + LINE_H + G + LINE_H + G + #KEYS * (KEY_H + G) + M)
    f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:SetFrameStrata("DIALOG"); f:Hide()
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.05, 0.05, 0.94)
    if UISpecialFrames then table.insert(UISpecialFrames, "XayaUICalculator") end   -- Escape closes it

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(TITLE_H)
    bar:EnableMouse(true); bar:RegisterForDrag("LeftButton")
    bar.bg = bar:CreateTexture(nil, "BACKGROUND"); bar.bg:SetAllPoints(); bar.bg:SetColorTexture(0.13, 0.13, 0.13, 0.95)
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function() f:StopMovingOrSizing(); SavePosition(f) end)
    local title = bar:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); title:SetPoint("CENTER"); title:SetText("Calculator"); title:SetTextColor(1, 0.82, 0)
    local close = CreateFrame("Button", nil, bar)
    close:SetSize(TITLE_H, TITLE_H); close:SetPoint("RIGHT")
    close.t = close:CreateFontString(nil, "OVERLAY"); close.t:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE"); close.t:SetPoint("CENTER"); close.t:SetText("x")
    close:SetScript("OnClick", function() f:Hide() end)

    f.history = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.history:SetPoint("TOPLEFT", M, -(TITLE_H + M)); f.history:SetPoint("TOPRIGHT", -M, -(TITLE_H + M))
    f.history:SetHeight(HISTORY_LINES * 12); f.history:SetJustifyH("RIGHT"); f.history:SetJustifyV("BOTTOM"); f.history:SetTextColor(0.6, 0.6, 0.6)

    local e = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    e:SetHeight(LINE_H); e:SetAutoFocus(false); e:SetMaxLetters(MAX_LEN); e:SetJustifyH("RIGHT")
    e:SetPoint("TOPLEFT", f.history, "BOTTOMLEFT", 4, -G); e:SetPoint("TOPRIGHT", f.history, "BOTTOMRIGHT", 0, -G)
    e:SetScript("OnEnterPressed", function(self) Work(self:GetText()) end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.edit = e

    f.result = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.result:SetPoint("TOPLEFT", e, "BOTTOMLEFT", -4, -G); f.result:SetPoint("TOPRIGHT", e, "BOTTOMRIGHT", 0, -G)
    f.result:SetHeight(LINE_H); f.result:SetJustifyH("RIGHT")

    f.keys = {}
    for r, row in ipairs(KEYS) do
        for c, key in ipairs(row) do
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(keyW, KEY_H)
            b:SetPoint("TOPLEFT", f.result, "BOTTOMLEFT", (c - 1) * (keyW + G), -(G + (r - 1) * (KEY_H + G)))
            b:SetText(key)
            b:SetScript("OnClick", function() Press(key) end)
            if ns.FlatButton then ns.FlatButton(b, key == "=") end
            f.keys[#f.keys + 1] = b
        end
    end

    local d = DB()
    if d and d.point then f:SetPoint(d.point, UIParent, d.point, tonumber(d.x) or 0, tonumber(d.y) or 0)
    else f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    RefreshHistory()
    return f
end

local OFF_TEXT = "The Calculator is off: tick it in Bonus Features > Utilities > Calculator."

function ns.Calculator_Toggle()
    if not On() then ns.Print(OFF_TEXT); return end
    local f = Build()
    if f:IsShown() then f:Hide() else f:Show(); f.edit:SetFocus() end
end
-- the settings page's "Open calculator" button: shows the window (never closes it) with the cursor in the typed line
function ns.Calculator_Open()
    if not On() then ns.Print(OFF_TEXT); return end
    local f = Build()
    f:Show(); f.edit:SetFocus()
end

-- On / off for the whole Calculator (Bonus 0.6.16): off closes the window and takes the cursor out of its line. The window, if it
-- was ever built this session, stays as a hidden frame until /reload (the game cannot delete a frame); nothing of it runs.
function ns.Calculator_SetEnabled(v)
    local d = DB(); if not d then return end
    d.enabled = v and true or false
    if not d.enabled and frame then frame.edit:ClearFocus(); frame:Hide() end
end

-- Settings: Bonus Features > Utilities > Calculator (Bonus 0.6.11; Xaya 2026-11-05: "Under bonus features, create "Utilities" Group
-- and nest Notepad and Calculator"). What it is and how to open it, from this file's header. Its row in the left pane carries the
-- Calculator's on / off (xuiSwitch, Bonus 0.6.16; Options.lua Tree.RowSwitch draws the box); while it is off the Open button is greyed
-- out. Built only when the settings window draws (Utilities.lua).
function ns.BuildCalculatorPage()
    local page = { type = "group", name = "Calculator", order = 1,
      xuiSwitch = { type = "toggle", name = "Calculator", tip = "A small calculator window (also /calc).",
          desc = "Turns the Calculator's window on or off. Off: no window and no Calculator row in the minimap button's list, and the window is never built; /xui calc with a sum still gives the answer in chat. Your last sums are kept.",
          get = function() return On() end, set = function(_, v) ns.Calculator_SetEnabled(v) end },
      args = {
        about = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "A small calculator: a window with a typed line and a keypad. Enter or = works the sum out; the answer replaces the line so the next sum can build on it, and the last sums are listed above it." },
        reads = { type = "description", order = 1, width = "full", fontSize = "medium",
            name = "It reads numbers (3472, 3,472, 3.5, .5), k / m / b after a number (12k = 12,000), + - * / ^, x or the multiply sign, the divide sign, % after a number (15% = 0.15), brackets and a leading minus. Nothing else: no functions, no variables. What you type is never run as code." },
        how = { type = "description", order = 2, width = "full", fontSize = "medium",
            name = "Open it with the button below, with /calc or /xui calc, or with Calculator in the minimap button's list. A sum after the command gives the answer in chat: /calc 23,249 / 3,472 prints 23,249 / 3,472 = 6.696141. (/calc is left to another addon if one already uses it; /xui calc always works.) Turn the Calculator on or off with the tick box next to it on the left." },
        open = { type = "execute", order = 3, name = "Open calculator", func = function() ns.Calculator_Open() end,
            disabled = function() return not On() end },
    } }
    -- (Bonus 0.6.24; REQUEST-LOG UI-53, the trial page for her "info icon that opens/closes a description box"): the summary with
    -- the icon; the three paragraphs above in the box it opens
    return ns.InfoBox and ns.InfoBox(page, "bonus.calculator", "A small calculator: a window with a typed line and a keypad. Open it with the button below or /calc.",
        { "about", "reads", "how" }) or page
end
ns.Calculator_Press = function(key) Build(); Press(key) end   -- (tests press keys through this)

-- /xui calc [sum]
local function Command(arg)
    local sum = type(arg) == "string" and arg:match("^%s*(.-)%s*$") or ""
    if sum == "" then ns.Calculator_Toggle(); return end   -- (off: Calculator_Toggle says so and opens nothing)
    local v, err = ns.CalcEval(sum)
    if not v then ns.Print(("calc: %s (%s)"):format(err, sum)); return end
    local answer = ns.CalcFormat(v)
    Remember(("%s = %s"):format(sum, answer))
    if frame then RefreshHistory() end
    ns.Print(("%s = %s"):format(sum, answer))
end

ns.Calculator_Command = Command   -- (Bonus 0.6.17) also /calc, registered by Utilities.lua when the word is free
-- (function audit 2026-11-07, D49 / D51) the Calculator's service for XayaUI Dev Assist's QA walkthroughs (QAWalks-audit-qol-bonus.lua)
if ns.Provide then
    ns.Provide("calculatorDebug", {
        On = function() return On() end, Eval = function(s) return ns.CalcEval(s) end, Format = function(v) return ns.CalcFormat(v) end,
        Press = function(key) if On() then Build(); Press(key) end end,   -- (off: nothing is built, V14)
        Result = function() return frame and frame.result:GetText() end, Line = function() return frame and frame.edit:GetText() end,
        Shown = function() return (frame and frame:IsShown()) and true or false end, Hide = function() if frame then frame:Hide() end end,
        History = function() local d = DB(); return d and d.history end,
    })
end
if ns.RegisterCommand then
    ns.RegisterCommand({ "calc", "calculator" }, Command, "/xui calc [sum] (a sum: the answer in chat; nothing: show / hide the calculator)")
end
if ns.RegisterLauncher then
    ns.RegisterLauncher({ "calc", "Calculator", "Show or hide the calculator (also /xui calc)", function() ns.Calculator_Toggle() end,
        nil, order = 11,   -- O-100 (Bonus 0.6.25, her answer "No word at all"): no "on" / "off" for shown / hidden
        available = function() return On() end })   -- (Bonus 0.6.16) no row while the Calculator is off (core 0.6.49: available())
end
