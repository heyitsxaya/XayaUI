-------------------------------------------------------------------------------
-- Chat/Core.lua : Chat Panel (QoL feature). Shared pieces: saved settings (CueRulesDB.chat2), defaults, a refresh bus for the other
-- Chat/*.lua files, the list of Blizzard chat windows, a guard against other chat addons, and /xui chat.
--
-- Chat Panel reskins Blizzard's own chat windows IN PLACE. It never replaces the message frame and never re-parents a chat window,
-- because the game can mark chat text secret (Midnight, inside restricted instance states) and addons cannot read or redraw that text.
-- Own code, written from the documented game API only. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)

local C = { errors = {}, applied = {}, mods = {}, hooked = {}, stats = { suppressed = 0, protected = 0 } }
ns.Chat = C
ns.CHAT_DEFAULTS = ns.CHAT_DEFAULTS or {}     -- the privacy cover's settings (ChatPrivacy.lua) still live in CueRulesDB.chat

local issecret = _G.issecretvalue or function() return false end
function C.IsSecret(v) return issecret(v) and true or false end

-- text-safe tostring: a secret value never gets formatted
function C.Safe(v)
    if v == nil then return nil end
    if issecret(v) then return nil end
    return v
end

C.DEFAULTS = {
    enabled = true,
    -- place and size of the pane (tabs + text + input); the Chat Bar is added above or below it
    point = "BOTTOMLEFT", x = 24, y = 90, width = 440, height = 230,
    collapsed = false,
    -- parts
    tabsShow = true, tabHeight = 24,
    inputH = 26, inputHint = true, inputHintText = "Press Enter to chat",
    stripMode = "HIDE", stripX = 0, stripY = 0,       -- Blizzard's button strip: HIDE | LEFT | RIGHT of the pane
    socialMode = "HIDE", socialX = 0, socialY = 0,    -- the social / quick-join button: HIDE | SHOW (stays above the pane)
    toBottom = "SHOW",                                -- the back-to-newest arrow: SHOW | HIDE
    scrollBar = "HIDE",                               -- HIDE | SHOW
    textInset = 6,
    histButton = true,
    -- look
    useTheme = false,                                 -- take colors and font from the XayaUI theme
    bgOn = true, bgR = 0.02, bgG = 0.02, bgB = 0.03, bgA = 55,
    bgTex = "", bgTile = false, bgTexA = 100,
    borderOn = true, borderR = 0, borderG = 0, borderB = 0, borderA = 100,
    inputBgR = 0, inputBgG = 0, inputBgB = 0, inputBgA = 70,
    inputBdR = 0, inputBdG = 0, inputBdB = 0, inputBdA = 100, inputFocusBd = true,
    font = "none", fontSize = 14, fontOutline = "outline",
    tabFont = "none", tabFontSize = 13, tabOutline = "shadow",
    tabTextR = 0.75, tabTextG = 0.75, tabTextB = 0.75, tabSelR = 0.3, tabSelG = 1, tabSelB = 0.3,
    tabBgOn = true, tabBgR = 0, tabBgG = 0, tabBgB = 0, tabBgA = 45,
    tabSelBgR = 0.18, tabSelBgG = 0.18, tabSelBgB = 0.18, tabSelBgA = 80,
    -- fade
    fadeOn = false, fadeAfter = 10, fadeTo = 0, fadeSeconds = 0.4, fadeWake = true, fadeBar = false,
    textFade = false, textFadeAfter = 120,
    -- Chat Bar
    barOn = true, barSide = "BOTTOM", barH = 22, barGap = 2, barSlots = 3, barSizing = "EVEN",
    barBgOn = true, barBgR = 0.02, barBgG = 0.02, barBgB = 0.03, barBgA = 55,
    barBorderOn = true, barBorderR = 0, barBorderG = 0, barBorderB = 0, barBorderA = 100,
    barTextSize = 13, barTextR = 1, barTextG = 1, barTextB = 1, barValueR = 0.64, barValueG = 0.21, barValueB = 0.93,
    barLabels = true, barHover = true, barClock24 = true, barLocalTime = true,
    barType1 = "FPSMS", barType2 = "FRIENDS", barType3 = "TIME", barType4 = "NONE", barType5 = "NONE", barType6 = "NONE", barType7 = "NONE", barType8 = "NONE",
    barAlign1 = "CENTER", barAlign2 = "CENTER", barAlign3 = "CENTER", barAlign4 = "CENTER", barAlign5 = "CENTER", barAlign6 = "CENTER", barAlign7 = "CENTER", barAlign8 = "CENTER",
    barFill1 = false, barFill2 = false, barFill3 = false, barFill4 = false, barFill5 = false, barFill6 = false, barFill7 = false, barFill8 = false,
    barCustom1 = "", barCustom2 = "", barCustom3 = "", barCustom4 = "", barCustom5 = "", barCustom6 = "", barCustom7 = "", barCustom8 = "",
    -- messages
    spamRepeat = true, spamSeconds = 30, spamPhrases = "", spamWord = false, ignoreClick = true,
    links = true, linkR = 0.4, linkG = 0.75, linkB = 1,
    histOn = true, histSize = 300,
    soundsOn = true, soundsInCombat = true,
}
C.MAX_SLOTS = 8

local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end

function C.Store() return ns.chat2 end

-- Runs fn protected; keeps the first error per feature for /xui chat. One broken part never takes the rest down.
function C.Try(feature, fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then
        if C.applied[feature] == nil then C.applied[feature] = true end
    else
        C.applied[feature] = false
        if not C.errors[feature] then C.errors[feature] = tostring(err) end
    end
    return ok
end

-- a hook is installed once per key, whatever the number of refreshes
function C.HookOnce(key, target, method, fn)
    if C.hooked[key] then return end
    local ok = false
    if type(target) == "string" then
        if type(_G[target]) == "function" then ok = pcall(hooksecurefunc, target, fn) end
    elseif type(target) == "table" and target[method] then
        ok = pcall(hooksecurefunc, target, method, fn)
    end
    if ok then C.hooked[key] = true end
end

-- modules: other files register a refresh function; C.Refresh runs them in order, each protected
function C.Register(name, fn)
    C.mods[#C.mods + 1] = { name = name, fn = fn }
end

local function IsLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) and true or false end
    return IsAddOnLoaded and IsAddOnLoaded(name) and true or false
end

-- another chat skin managing the same windows? then Chat Panel stays out of the way
function C.BlockedReason()
    if IsLoaded("EllesmereUIChat") then return "EllesmereUIChat is loaded. Disable it in the AddOn list and reload." end
    if IsLoaded("ElvUI") then
        local ok, on = pcall(function()
            local E = _G.ElvUI and _G.ElvUI[1]
            return E and E.private and E.private.chat and E.private.chat.enable
        end)
        if ok and on then return "Another addon's chat module is on (ElvUI). Turn it off there, or disable that addon, and reload." end
    end
    return nil
end

function C.On()
    local s = ns.chat2
    return s and s.enabled and not C.BlockedReason() and true or false
end

function C.Frames()
    local out = {}
    local names = _G.CHAT_FRAMES
    if type(names) == "table" and #names > 0 then
        for _, n in ipairs(names) do if _G[n] then out[#out + 1] = _G[n] end end
    else
        for i = 1, ns.Compat.MaxChatWindows() do
            local f = _G["ChatFrame" .. i]
            if f then out[#out + 1] = f end
        end
    end
    return out
end
function C.NameOf(f) local ok, n = pcall(f.GetName, f); return ok and n or "" end
function C.TabOf(f) return f.tab or _G[C.NameOf(f) .. "Tab"] end
function C.EditBoxOf(f) return f.editBox or _G[C.NameOf(f) .. "EditBox"] end
function C.ButtonFrameOf(f) return f.buttonFrame or _G[C.NameOf(f) .. "ButtonFrame"] end
function C.Main() return _G.ChatFrame1 end

-- Colors / fonts shared by every Chat/*.lua file. When "Use the XayaUI theme" is on, they come from ns.Theme.
function C.ThemeOn() local s = ns.chat2; return s and s.useTheme and ns.Theme and true or false end
function C.Color(s, key, themeClass, themeProp)   -- key: the saved prefix, e.g. "bg" -> bgR bgG bgB bgA (percent)
    local r, g, b, a = s[key .. "R"] or 0, s[key .. "G"] or 0, s[key .. "B"] or 0, (tonumber(s[key .. "A"]) or 100) / 100
    if C.ThemeOn() and themeClass then
        local ok, c = pcall(ns.Theme.Col, themeClass, themeProp or "bg")
        if ok and type(c) == "table" then return c[1] or r, c[2] or g, c[3] or b, (c[4] or 1) * a end
    end
    return r, g, b, a
end
function C.FontPath(key)
    if C.ThemeOn() then
        local ok, p = pcall(ns.Theme.FontPath)
        if ok and p then return p end
    end
    return ns.FontPath and ns.FontPath(key) or STANDARD_TEXT_FONT
end
function C.Flags(mode)
    if mode == "outline" then return "OUTLINE" elseif mode == "thick" then return "THICKOUTLINE" end
    return ""
end
-- SetFont that always ends with a working font (a missing file makes SetFont return false)
C.fonts, C.remembered, C.suppressed, C.alphaEls = {}, {}, {}, {}
function C.SetFont(fs, path, size, flags)
    if not (fs and fs.SetFont) then return end
    if not C.fonts[fs] and fs.GetFont then
        local ok, p, sz, fl = pcall(fs.GetFont, fs)
        if ok and p then C.fonts[fs] = { p, sz, fl } end
    end
    local ok, res = pcall(fs.SetFont, fs, path or STANDARD_TEXT_FONT, size, flags or "")
    if not (ok and res) then pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size, flags or "") end
end

-- the game's own anchors, copied before the first time we move a frame, so switching the Chat Panel off can put them back
function C.Remember(o)
    if not o or o._xuiPts or not o.GetNumPoints then return end
    local ok, n = pcall(o.GetNumPoints, o)
    if not ok or not n or n < 1 then return end
    local t = {}
    for i = 1, n do
        local ok2, p, rel, rp, x, y = pcall(o.GetPoint, o, i)
        if ok2 and p then t[#t + 1] = { p, rel, rp, x, y } end
    end
    if #t == 0 then return end
    o._xuiPts = t
    C.remembered[#C.remembered + 1] = o
end

-- everything we changed on the game's chat goes back: shown / hidden pieces, alpha, mouse, anchors, fonts, tab heights.
-- The game's own functions then lay the windows out again.
function C.Teardown()
    if not C.active then return end
    C.active = false
    for o in pairs(C.suppressed) do pcall(C.Unsuppress, o) end
    C.suppressed = {}
    C.master, C.fade = 1, 1
    for _, el in ipairs(C.alphaEls) do
        pcall(function()
            el._xuiSetting = true
            el:SetAlpha(el._xuiBase or 1)
            el._xuiSetting = false
            if el._xuiMouse ~= nil and el.EnableMouse then el:EnableMouse(el._xuiMouse); el._xuiMouse = nil end
        end)
    end
    for _, o in ipairs(C.remembered) do
        pcall(function()
            o:ClearAllPoints()
            for _, p in ipairs(o._xuiPts) do o:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
        end)
        o._xuiPts = nil
    end
    C.remembered = {}
    for fs, f in pairs(C.fonts) do pcall(fs.SetFont, fs, f[1], f[2], f[3]) end
    C.fonts = {}
    for _, f in ipairs(C.Frames()) do
        local tab = C.TabOf(f)
        if tab then
            if tab._xuiH and tab.SetHeight then pcall(tab.SetHeight, tab, tab._xuiH); tab._xuiH = nil end
            if tab.xuiBg then tab.xuiBg:Hide() end
        end
    end
    if C.unlocked and C.ToggleMover then C.ToggleMover() end
    if C.Container() then C.Container():Hide() end
    if ns.ChatPrivacy_Refresh then ns.ChatPrivacy_Refresh() end
    for _, fn in ipairs({ "FCF_DockUpdate", "FCF_UpdateButtonSide" }) do
        if type(_G[fn]) == "function" then pcall(_G[fn]) end
    end
end

-- the refresh bus ----------------------------------------------------------------------------------------------------------
function C.Refresh()
    local s = ns.chat2
    if not s then return end
    if not C.On() then C.Teardown(); return end      -- off (or blocked by another chat addon): give Blizzard's chat back, untouched
    C.active = true
    for _, m in ipairs(C.mods) do C.Try(m.name, m.fn, s) end
end

local pending
function C.Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0, function() pending = false; C.Refresh() end)
end

function ns.Chat_OnDBReady()
    CueRulesDB.chat = CueRulesDB.chat or {}                        -- privacy cover settings (kept as they are)
    ns.Merge(CueRulesDB.chat, ns.CHAT_DEFAULTS)
    ns.chatDB = CueRulesDB.chat
    CueRulesDB.chat2 = CueRulesDB.chat2 or {}                      -- the new Chat Panel (old chat settings are not read)
    local s = CueRulesDB.chat2
    for k, v in pairs(C.DEFAULTS) do if s[k] == nil then s[k] = Copy(v) end end
    s.sounds = type(s.sounds) == "table" and s.sounds or {}
    ns.chat2 = s
end

local drv = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
    drv:RegisterEvent(ev)
end
drv:SetScript("OnEvent", function() C.Schedule() end)
if ns.Theme and ns.Theme.OnResolve then ns.Theme.OnResolve(function() C.Schedule() end) end

-- /xui chat indent : READ ONLY. Where the empty space at the left of the chat text comes from. For the first visible lines it prints how far
-- the line's own box sits from the window's left edge, and the first characters of the line's text with every |-code shown as typed (a
-- timestamp or a hidden color / texture code in front of the words shows up there). Text the game marks secret is never read.
local function IndentReport()
    local cf, ta = C.Main(), C.TextArea()
    if not (cf and ta) then ns.Print("Chat Panel indent: the chat window is not there to measure."); return end
    local function f(v) v = tonumber(v); return (v and not C.IsSecret(v)) and ("%.1f"):format(v) or "?" end
    local function left(o) local ok, v = pcall(function() return o:GetLeft() end); return ok and tonumber(v) or nil end
    local cl, tl = left(cf), left(ta)
    local s = ns.chat2 or {}
    ns.Print(("Chat Panel indent: window left %s, text area left %s (setting: %s px), text area to window: %s px"):format(f(cl), f(tl), tostring(s.textInset), (cl and tl) and f(tl - cl) or "?"))
    local fmt
    if _G.Settings and _G.Settings.GetValue then local ok, v = pcall(_G.Settings.GetValue, "showTimestamps"); if ok and type(v) == "string" then fmt = v end end
    ns.Print(("  the game's timestamp setting: %s"):format(fmt and ("\"" .. fmt:gsub("|", "||") .. "\"") or "unreadable"))
    local lines = cf.visibleLines
    if type(lines) ~= "table" or #lines == 0 then ns.Print("  no visible lines to measure (say something in chat first)"); return end
    local shown = 0
    for i = #lines, 1, -1 do
        local fs = lines[i]
        local txt = fs and fs.IsShown and fs:IsShown() and fs.GetText and fs:GetText() or nil
        if type(txt) == "string" and not C.IsSecret(txt) and txt ~= "" then
            local pre = txt:sub(1, 40):gsub("|", "||"):gsub("[%c]", "?")
            ns.Print(("  line %d: box left %s px from the window edge, text starts \"%s\""):format(i, (cl and left(fs)) and f(left(fs) - cl) or "?", pre))
            shown = shown + 1
            if shown >= 4 then break end
        end
    end
    if shown == 0 then ns.Print("  the visible lines are empty or protected") end
end

function C.IndentReport()   -- never raises: a game value that cannot be read ends the report with one line, not an error
    local ok, err = pcall(IndentReport)
    if not ok then ns.Print(("Chat Panel indent: could not finish (%s)"):format((tostring(err):gsub("|", "||")))) end
end

-- /xui chat [on|off|reset|move|history|status]
function C.Command(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    local s = ns.chat2
    if not s then ns.Print("Chat Panel: settings are not loaded yet."); return end
    if arg == "off" then s.enabled = false; C.Refresh(); ns.Print("Chat Panel OFF. Blizzard's chat is back as the game draws it.")
    elseif arg == "on" then s.enabled = true; C.Refresh(); ns.Print("Chat Panel ON.")
    elseif arg == "reset" then
        s.point, s.x, s.y, s.width, s.height = C.DEFAULTS.point, C.DEFAULTS.x, C.DEFAULTS.y, C.DEFAULTS.width, C.DEFAULTS.height
        C.Refresh(); ns.Print("Chat Panel: position and size reset.")
    elseif arg == "move" then if C.ToggleMover then C.ToggleMover() end
    elseif arg == "history" then if C.History_Toggle then C.History_Toggle() end
    elseif arg == "settings" or arg == "options" then if C.OpenSettings then C.OpenSettings() end
    elseif arg == "wrap" then
        local st = C.WrapStatus and C.WrapStatus()
        if not st then ns.Print("Chat Panel wrap: the chat window is not there to measure."); return end
        local function f(v) return v and ("%.1f"):format(v) or "?" end
        ns.Print(("Chat Panel wrap: window width %s, text area %s, line width %s (%s lines), widest text %s%s"):format(f(st.cf), f(st.text), f(st.line), tostring(st.numLines or "?"), f(st.widest), C.WrapOff() and "  <- OFF, laying out again" or "  (consistent)"))
        local cf = C.Main()
        local sc, tsc = cf and cf.GetEffectiveScale and cf:GetEffectiveScale(), C.TextArea() and C.TextArea():GetEffectiveScale()
        ns.Print(("  scale: window %s, text area %s; relayouts done this session: %d"):format(f(sc), f(tsc), C.stats.rewraps or 0))
        C.Rewrap(true)
        local st2 = C.WrapStatus()
        if st2 then ns.Print(("  after laying out again: line width %s, widest text %s"):format(f(st2.line), f(st2.widest))) end
    elseif arg == "indent" then C.IndentReport()
    else
        local why = C.BlockedReason()
        ns.Print((("Chat Panel: " .. (s.enabled and (why and ("blocked: " .. why) or "ON") or "OFF") .. ". /xui chat on|off|reset|move|history|wrap|indent|settings"):gsub("|", "||")))
        local names = {}
        for k in pairs(C.applied) do names[#names + 1] = k end
        table.sort(names)
        for _, k in ipairs(names) do
            ns.Print("  " .. k .. ": " .. (C.applied[k] and "ok" or ("FAILED: " .. tostring(C.errors[k]))))
        end
        ns.Print("  repeats and phrases hidden this session: " .. C.stats.suppressed .. "; protected (secret) lines not touched: " .. C.stats.protected)
    end
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
ns.WhenReady(ns.Chat_OnDBReady)
ns.RegisterCommand("chat", function(arg) C.Command(arg) end, "/xui chat (Chat Panel: on, off, reset, move, history, wrap, indent, settings)")
ns.RegisterCommand("panel", function() if C.OpenSettings then C.OpenSettings("bar") end end, "/xui panel (Chat Bar settings)")
