-------------------------------------------------------------------------------
-- Calculator.lua (XayaUI Bonus Features 0.6.47): the arithmetic Calculator, the project's own (qa-installer-branch
-- XayaUI_Bonus/Calculator.lua, e3cf8964 "a little calculator", last changed in bc962356), brought back inside XayaUI_Bonus.
-- Her answers that set it up here:
--   S2-13 "add a feature: a little calculator"; S2-29 "Keep as built": chat sums, a 20-key keypad, the last sums kept, k / m / b.
--   S7-1 "Calculator needs its own enable / disable toggle"; S7-2 "On by default (Recommended)".
--   O-100 / FA-15, her answer "No word at all": the minimap row reads just "Calculator", no "on" / "off".
--   SD-95 "Arithmetic, own part (Recommended)"; SD-115 "Inside Bonus (Recommended)": no new folder. This file is read with XayaUI
--     Bonus Features at login (a named V34 exception; VERIFICATION.md is the docs unit's); nothing of it runs in play and the keypad's
--     frames are made only at its first open.
--   SD-116 "2 but the chat calls only become available if individual components are enabled": its own switch in Bonus Features, on by
--     default. SD-118 "All parts, say how (Recommended)": /xui calc and /xui calculator work only while it is on; while it is off core
--     prints its one line, "The Calculator is off. Turn it on in /xui > Bonus Features." (core Modules.lua section 2, the part argument),
--     and /xui help leaves them out. (This replaces S7-2's "just the window": chat sums stop too while it is off.)
--   SD-117 "600, same as core (Recommended)": XayaUI_Bonus at most 600 instructions per event. The Calculator has no event, no OnUpdate,
--     no timer and no hook of its own at any time; core's KeyFocusGuard hooks its one text box (below).
--   CHAT-6 (REQUEST-LOG-CROSS-CHAT.md), her words: "Is it possible for /notes /calc to be commands that the addon recognizes and accepts in
--     the console to open the notes and calculator respectively?" (built on QA, Bonus 0.6.17, Utilities.lua, QA test slash_words): /calc
--     does exactly what /xui calc does (below, "/calc"). Main has no Notepad, so only /calc.
-- What the player gets:
--   * /xui calc <sum> (or /xui calculator <sum>, or /calc <sum>): the answer in chat, e.g. "/xui calc 23,249 / 3,472" -> "23,249 / 3,472 = 6.696141"
--     (23249 / 3472 = 6.69614055...). A sum that cannot be read prints why: "calc: cannot divide by zero (1/0)".
--   * /xui calc alone, the minimap list's Calculator row, or the Open button on its settings page: a small window with a typed line, the
--     answer, the last three sums and a 20-key keypad. Enter or = works the sum out; the answer replaces the line so the next sum builds
--     on it, at full precision (QA D49); the last ten sums are kept (the window shows three).
--   * What a sum may hold: numbers (3472, 3,472, 3.5, .5), k / m / b after a number (12k = 12,000; "12kx3" = 36,000, QA D51), + - * / ^,
--     x or the multiply sign, the divide sign, % after a number (15% = 0.15), brackets, a leading minus. Nothing else: typed text is never
--     run as code (read by the small parser below, never handed to loadstring or RunScript).
-- Keys and mouse (V27 as read by SD-99, V29):
--   * The window takes clicks only while it is open (a hidden frame takes none). Everything that takes the mouse sits inside it.
--   * Its typed line takes the keyboard only while the window is open: the window opens with the cursor in the line (out of combat), and
--     core's KeyFocusGuard (XayaUI/KeyCatch.lua) lets go on Enter (after the sum is worked out), on Esc, on a click outside the window,
--     when combat (or a Mythic+, PvP or encounter restriction) starts, and when the window hides. A second Esc closes the window (the
--     game's Esc list, UISpecialFrames). Opened in combat it does not take the keyboard (as core's copy box, review R23): the keypad works
--     with the mouse, and a click in the line gives it the cursor.
--   * V26: not locked in combat. It reads and keeps only its own state and never touches combat tracking (SD-15's exempt list, her
--     words: "Only things that read or maintain their exact state (notes for instance should not interact with combat)").
-- Saved: XayaUIBonusDB.calculator = { enabled, point, x, y, history = { "sum = answer", ... } } (enabled: false = off; nil or true =
-- on). Nothing is written until she uses it: reading the switch makes no table. Its place is saved in whole pixels (V27).
-- Game calls (12.1.5 documentation, docs/reference/api/widgets.md): EditBox SetFocus / ClearFocus (FrameAPISimpleCheckout),
-- SetCursorPosition (SecretArguments=AllowedWhenUntainted), SetMaxLetters; Frame StartMoving / StopMovingOrSizing / SetClampedToScreen /
-- SetFrameStrata / EnableMouse / SetPoint / ClearAllPoints (IsProtectedFunction: blocked only on a protected frame in combat; these
-- frames are plain, made by this file, never secure), SetMovable, RegisterForDrag. InCombatLockdown read only when it is a function
-- (namespaces.md lists it as "Documented but not present in this client"; Blizzard's own UI reads the global, INFERENCE).
-- Own code (no other addon's code or data).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("bonus", "XayaUI_Bonus", "XayaUIBonusDB") end   -- (P5) this addon's own saved variable
local BonusS = ns.Settings("bonus")

local W, TITLE_H, KEY_H, LINE_H = 216, 20, 26, 22
local HISTORY_LINES, HISTORY_KEPT = 3, 10
local MAX_LEN = 200            -- characters in one sum
local FRAME_NAME = "XayaUICalculator"
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
    -- (QA D51) x / X after the suffix is a multiply ("12kx3" = 36,000); any other letter makes it a word ("12kg" stays refused)
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
-- (Its small functions are made once per sum worked out, only when she asks for one; never per event or per frame.)
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

-- (QA D49) the answer as the typed line keeps it for the next sum: every digit needed to read the same number back (the shortest of
-- %.15g / %.16g / %.17g that does), in plain digits, never in e-notation (the line cannot read "1e-07"). The answer line and the
-- history still show ns.CalcFormat's rounded answer.
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
-- Saved settings and the switch
-------------------------------------------------------------------------------
-- the saved table, made on first use (a sum, the window); nil while Bonus's settings are not open
local function DB()
    if not ns.SettingsReady("bonus") then return nil end
    local d = BonusS.calculator
    if type(d) ~= "table" then d = {}; BonusS.calculator = d end
    if type(d.history) ~= "table" then d.history = {} end
    while #d.history > HISTORY_KEPT do table.remove(d.history, 1) end
    return d
end

-- (SD-116) on unless switched off; exactly true or false, and makes nothing (core's part switch, the minimap list and the settings page
-- read it). False while Bonus's settings are not open yet.
local function On()
    if not ns.SettingsReady("bonus") then return false end
    local d = BonusS.calculator
    return not (type(d) == "table" and d.enabled == false)
end
ns.Calculator_IsOn = On
-- (SD-118) the Calculator as a part for core's commands (Modules.lua section 2)
local PART = { name = "Calculator", isOn = On, where = "/xui > Bonus Features" }

local function Remember(line)
    local d = DB()
    if not d then return end
    d.history[#d.history + 1] = line
    while #d.history > HISTORY_KEPT do table.remove(d.history, 1) end
end

local function InLockdown() return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false end

-------------------------------------------------------------------------------
-- The window (made at its first open, never before)
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
    frame.edit:SetText(ns.CalcExact(v))   -- the next sum builds on the answer, at full precision (QA D49)
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

-- whole pixels (V27): a drag can leave a fraction; the saved place and the drawn one are rounded
local function Round(v) v = tonumber(v) or 0; return math.floor(v + 0.5) end
local function SavePosition(f)
    local d = DB()
    if not d then return end
    local point, _, _, x, y = f:GetPoint(1)
    d.point, d.x, d.y = point or "CENTER", Round(x), Round(y)
    f:ClearAllPoints(); f:SetPoint(d.point, UIParent, d.point, d.x, d.y)
end

-- (made once, at the first open) the scripts of the window's parts; a key's own text is kept on the key, so one function serves all 20
local function OnKeyClick(b) Press(b.calcKey) end
local function OnEnter(self) Work(self:GetText()) end   -- (KeyFocusGuard's enterLetsGo then takes the cursor out of the line)
local function OnCloseClick(b) b.calcWindow:Hide() end
local function OnDragStart(bar) bar.calcWindow:StartMoving() end
local function OnDragStop(bar) local f = bar.calcWindow; f:StopMovingOrSizing(); SavePosition(f) end

local function Build()
    if frame then return frame end
    local M = ns.UI_MARGIN or 10   -- the one margin and gutter (core ns.Style)
    local G = math.floor((ns.UI_GUTTER or 10) / 2)
    local keyW = math.floor((W - 2 * M - 3 * G) / 4)
    local f = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame = f
    f:SetSize(W, TITLE_H + M + HISTORY_LINES * 12 + G + LINE_H + G + LINE_H + G + #KEYS * (KEY_H + G) + M)
    f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:SetFrameStrata("DIALOG"); f:Hide()
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.05, 0.05, 0.94)
    if type(UISpecialFrames) == "table" then   -- Esc closes it (the game's Esc list), named there once
        local listed = false
        for _, n in ipairs(UISpecialFrames) do if n == FRAME_NAME then listed = true end end
        if not listed then table.insert(UISpecialFrames, FRAME_NAME) end
    end

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(TITLE_H)
    bar:EnableMouse(true); bar:RegisterForDrag("LeftButton")
    bar.calcWindow = f
    bar.bg = bar:CreateTexture(nil, "BACKGROUND"); bar.bg:SetAllPoints(); bar.bg:SetColorTexture(0.13, 0.13, 0.13, 0.95)
    bar:SetScript("OnDragStart", OnDragStart)
    bar:SetScript("OnDragStop", OnDragStop)
    local title = bar:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); title:SetPoint("CENTER"); title:SetText("Calculator"); title:SetTextColor(1, 0.82, 0)
    local close = CreateFrame("Button", nil, bar)   -- (inside the title bar, so inside the window: SD-99)
    close:SetSize(TITLE_H, TITLE_H); close:SetPoint("RIGHT")
    close.calcWindow = f
    close.t = close:CreateFontString(nil, "OVERLAY"); close.t:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE"); close.t:SetPoint("CENTER"); close.t:SetText("x")
    close:SetScript("OnClick", OnCloseClick)
    f.bar, f.close = bar, close

    f.history = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.history:SetPoint("TOPLEFT", M, -(TITLE_H + M)); f.history:SetPoint("TOPRIGHT", -M, -(TITLE_H + M))
    f.history:SetHeight(HISTORY_LINES * 12); f.history:SetJustifyH("RIGHT"); f.history:SetJustifyV("BOTTOM"); f.history:SetTextColor(0.6, 0.6, 0.6)

    local e = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    e:SetHeight(LINE_H); e:SetAutoFocus(false); e:SetMaxLetters(MAX_LEN); e:SetJustifyH("RIGHT")
    e:SetPoint("TOPLEFT", f.history, "BOTTOMLEFT", 4, -G); e:SetPoint("TOPRIGHT", f.history, "BOTTOMRIGHT", 0, -G)
    -- Enter works the sum out AND lets go of the keyboard (QA bc962356, row 56 / V24: a line that kept the cursor after Enter kept every
    -- key, movement and the screenshot key included). The answer stays in the line, so the next sum still builds on it: a click in the
    -- line (or the keypad, which needs no cursor) carries on.
    e:SetScript("OnEnterPressed", OnEnter)
    f.edit = e
    if ns.KeyFocusGuard then
        -- (V29) lets go on Enter (after OnEnter), Esc, a click outside the window, combat start and the window hiding (core KeyCatch.lua)
        ns.KeyFocusGuard(e, { within = f, window = f, enterLetsGo = true })
    else
        e:HookScript("OnEnterPressed", e.ClearFocus)   -- (a core without KeyFocusGuard: Enter and Esc still let go)
        e:SetScript("OnEscapePressed", e.ClearFocus)
    end

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
            b.calcKey = key
            b:SetScript("OnClick", OnKeyClick)
            if ns.FlatButton then ns.FlatButton(b, key == "=") end
            f.keys[#f.keys + 1] = b
        end
    end

    local d = DB()
    if d and d.point then f:SetPoint(d.point, UIParent, d.point, Round(d.x), Round(d.y))
    else f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    -- (QA Bonus 0.6.35; #495, REQUEST-LOG PS-59) while the settings window is shown, a right-click on the Calculator (title bar or
    -- frame) opens the element menu (core Modules.lua section 11): "Element options" opens Bonus Features > Calculator; X and Y are its
    -- own saved place. Registered when the window is made, so a Calculator never opened registers nothing (V14).
    if ns.RegisterElement then
        ns.RegisterElement({ key = "calculator", label = "Calculator", page = { "bonus", "calculator" },
            targets = function(add) add(f, "OnMouseUp"); add(bar, "OnMouseUp") end,
            getPos = function() local d2 = DB(); return Round(d2 and d2.x), Round(d2 and d2.y) end,
            setPos = function(_, x, y)
                local d2 = DB(); if not d2 then return end
                d2.point = d2.point or "CENTER"; d2.x, d2.y = Round(x), Round(y)
                f:ClearAllPoints(); f:SetPoint(d2.point, UIParent, d2.point, d2.x, d2.y)
            end })
    end
    RefreshHistory()
    return f
end

-- shows the window; out of combat with the cursor in its typed line (V29: in combat it takes no keyboard)
local function ShowWindow(f)
    f:Show()
    if not InLockdown() then f.edit:SetFocus() end
end

-- the minimap row, /xui calc alone: open or close. Off: nothing (its row is hidden and core never runs /xui calc then; a stray call
-- prints core's one line)
function ns.Calculator_Toggle()
    if not On() then if ns.Print and ns.PartOffText then ns.Print(ns.PartOffText(PART)) end; return end
    local f = Build()
    if f:IsShown() then f:Hide() else ShowWindow(f) end
end
-- the settings page's Open button: shows the window (never closes it)
function ns.Calculator_Open()
    if not On() then if ns.Print and ns.PartOffText then ns.Print(ns.PartOffText(PART)) end; return end
    ShowWindow(Build())
end

-- (S7-1 / SD-116) on / off at once, no reload: off closes the window (its line lets go of the keyboard as it hides). The window, if it
-- was made this session, stays as a hidden frame until /reload (the game cannot delete a frame); nothing of it runs. Its saved sums
-- and place are kept.
function ns.Calculator_SetEnabled(v)
    local d = DB(); if not d then return end
    d.enabled = v and true or false
    if not d.enabled and frame then frame.edit:ClearFocus(); frame:Hide() end
end
-- after a profile import (ProfilePart.lua): the saved switch may have changed; an open window closes when it is now off
function ns.Calculator_Sync()
    if frame and not On() then frame.edit:ClearFocus(); frame:Hide() end
end

-------------------------------------------------------------------------------
-- Settings: Bonus Features > Calculator. (QA had it under Bonus Features > Utilities with the Notepad; main has no Notepad and no
-- Utilities group, so it is its own page in the Bonus Features tab, beside the Stat Calculator.) Its row in the left pane carries its
-- tick box (xuiSwitch; XayaUI_Options TreePaint.lua draws it); while it is off its page is greyed (Options GreyWhileOff) and the Open
-- button with it. Built only when the settings window draws.
-------------------------------------------------------------------------------
local function BuildPage()
    if not ns.SettingsReady("bonus") then return nil end
    return { type = "group", name = "Calculator", order = 1,
      xuiSwitch = { type = "toggle", name = "Calculator", tip = "A small calculator window (also /xui calc or /calc).",
          desc = "Turns the Calculator on or off; your last sums are kept. Off, /xui calc and /calc only say it is off.",
          get = function() return On() end, set = function(_, v) ns.Calculator_SetEnabled(v) end },
      args = {
        about = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "A small calculator: a window with a typed line and a keypad. Enter or = works the sum out. The answer replaces the line, so the next sum can build on it. Your last sums are listed above it." },
        reads = { type = "description", order = 1, width = "full", fontSize = "medium",
            name = "It reads numbers (3472, 3,472, 3.5, .5), k / m / b after a number (12k = 12,000), + - * / ^, x or the multiply sign, the divide sign, % after a number (15% = 0.15), brackets and a leading minus. Nothing else. What you type is never run as code." },
        how = { type = "description", order = 2, width = "full", fontSize = "medium",
            name = "Open it with the button below, with /xui calc or /calc, or with Calculator in the minimap button's list. Type a sum after the command to get the answer in chat: /xui calc 23,249 / 3,472 prints 23,249 / 3,472 = 6.696141. If another addon already uses /calc, /calc is left to it; /xui calc always works. Turn it on or off with the tick box next to it on the left." },
        open = { type = "execute", order = 3, name = "Open calculator", func = function() ns.Calculator_Open() end,
            disabled = function() return not On() end },
      } }
end
ns.Calculator_Press = function(key) Build(); Press(key) end   -- (tests press keys through this)

-- /xui calc [sum] and /xui calculator [sum]. Core runs this only while the Calculator is on (SD-118).
local function Command(arg)
    local sum = type(arg) == "string" and arg:match("^%s*(.-)%s*$") or ""
    if sum == "" then ns.Calculator_Toggle(); return end
    local v, err = ns.CalcEval(sum)
    if not v then ns.Print(("calc: %s (%s)"):format(err, sum)); return end
    local answer = ns.CalcFormat(v)
    Remember(("%s = %s"):format(sum, answer))
    if frame then RefreshHistory() end
    ns.Print(("%s = %s"):format(sum, answer))
end
ns.Calculator_Command = Command

-------------------------------------------------------------------------------
-- /calc (CHAT-6, her words above; QA Bonus 0.6.17 Utilities.lua, the project's own code, adapted). Exactly the word /calc; it runs what
-- /xui calc runs, through core (ns.RunCommand), so SD-116 / SD-118 hold for it too: while the Calculator is on it works the sum out or
-- opens / closes the keypad; while it is off it prints core's one line, "The Calculator is off. Turn it on in /xui > Bonus Features.",
-- and nothing of the Calculator runs.
--   * Claimed only if nothing else has the word (as on QA): every SLASH_<KEY><n> word of SlashCmdList and SecureCmdList (the game's own
--     commands and every loaded addon's) and the chat box's cache hash_SlashCmdList are looked at first. Taken: it is left alone, and
--     /xui calc still works. Claimed once, at login (core's ns.AtLogin, PLAYER_LOGIN), after every addon that loads at login has
--     registered its words (QA's comment meant this; its code claimed at ADDON_LOADED, before the addons that load after XayaUI Bonus).
--     An addon that loads later on demand and takes the same word is not seen (INFERENCE, as on QA).
--   * SlashCmdList, SLASH_<KEY><n>, SecureCmdList and hash_SlashCmdList are the game's chat-box tables, not in the 12.1.5 API
--     documentation (docs/reference/api/ has no entry): INFERENCE from how core claims /xui (Core.lua) and from QA. Read with rawget; a
--     table that is not there means the word is not claimed (fail safe). The look runs once, at login, never per event.
--   * The game cannot take a slash word back, so /calc, once claimed, stays until /reload whatever the switch says; while off it only
--     prints the one line. Its handler is one file-level function (no function made per call).
-------------------------------------------------------------------------------
local SLASH_KEY, SLASH_WORD = "XUICALC", "/calc"
local slashClaimed = false

local function SlashWordTaken(word)
    word = word:lower()
    local hash = rawget(_G, "hash_SlashCmdList")
    if type(hash) == "table" and (hash[word] or hash[word:upper()]) then return true end
    for _, list in ipairs({ rawget(_G, "SlashCmdList") or false, rawget(_G, "SecureCmdList") or false }) do
        if type(list) == "table" then
            for k in pairs(list) do
                local i = 1
                while true do
                    local w = rawget(_G, "SLASH_" .. tostring(k) .. i)
                    if type(w) ~= "string" then break end
                    if w:lower() == word then return true end
                    i = i + 1
                end
            end
        end
    end
    return false
end

local function SlashCalc(msg) ns.RunCommand("calc", msg) end

local function ClaimSlash()
    if slashClaimed then return end
    local list = rawget(_G, "SlashCmdList")
    if type(list) ~= "table" or type(ns.RunCommand) ~= "function" or SlashWordTaken(SLASH_WORD) then return end
    _G["SLASH_" .. SLASH_KEY .. "1"] = SLASH_WORD
    list[SLASH_KEY] = SlashCalc
    slashClaimed = true
end
function ns.Calculator_SlashClaimed() return slashClaimed end   -- (tests)

-- the words, the minimap row and the page: once Bonus's settings are open (with XayaUI Bonus Features off: none of them; core's list
-- then names XayaUI Bonus Features for /xui calc and /xui calculator, audit_core D8). Registered whatever the switch says: core reads
-- the switch each time a word is typed and each time /xui help prints.
local registered = false
ns.WhenSettingsReady("bonus", function()
    if registered then return end
    registered = true
    local words = ns.RegisterCommand({ "calc", "calculator" }, Command,
        "/xui calc [sum] (with a sum: the answer in chat; alone: open or close the Calculator) | /xui calculator [sum] (the same as calc)", PART)
    -- /calc (CHAT-6): only once /xui calc is core's, so it has something to run; claimed at login, when the word is free
    if words == true then
        if type(ns.AtLogin) == "function" then ns.AtLogin(ClaimSlash) else ClaimSlash() end
    end
    if type(ns.RegisterLauncher) == "function" then
        -- (QA Bonus 0.6.16) no row while the Calculator is off: core reads available() each time the list opens, nothing is polled.
        -- O-100 (her answer "No word at all"): just the name, no "on" / "off".
        ns.RegisterLauncher({ "calc", "Calculator", "Show or hide the calculator (also /xui calc)", ns.Calculator_Toggle,
            nil, order = 11, available = On })
    end
    ns.RegisterSettingsPage("bonus", "calculator", BuildPage)
end)
