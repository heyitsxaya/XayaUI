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
-- (P5) this addon keeps its settings in its own saved variable (its .toc); the Platform opens it at this addon's ADDON_LOADED
if ns and ns.SettingsDeclareStore then ns.SettingsDeclareStore("chat", "XayaUI_Chat", "XayaUIChatDB") end
local ChatS = ns.Settings("chat")   -- (Chat 0.6.41, P2 settings seam; Chat 0.6.42, P5: Chat's own XayaUIChatDB; Modules.lua section 0b)

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
    inputPos = "BOTTOM",   -- (Chat 0.6.34; UI-15) BOTTOM | TOP (under the tab row) | ABOVE (above it) | FREE (inputX / inputY / inputW, mover only)
    stripMode = "HIDE", stripX = 0, stripY = 0,       -- Blizzard's button strip: HIDE | LEFT | RIGHT of the pane
    socialMode = "HIDE", socialX = 0, socialY = 0,    -- the social / quick-join button: HIDE | SHOW (stays above the pane)
    toBottom = "SHOW",                                -- the back-to-newest arrow: SHOW | HIDE
    scrollBar = "HIDE",                               -- Blizzard's own scroll bar: HIDE | SHOW (used only while scrollOwn is off)
    scrollOwn = true, scrollSpeed = 6, scrollW = 10,  -- the Chat Panel's scroll bar: arrows step one line; held, scrollSpeed lines a second
    textInset = 6,
    wrapIndent = true,                                -- the lines after the first of a long message start further in (the game's default)
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
    histOn = true, histSize = 300, histConsole = true, histWhispers = "game",   -- histConsole: printed lines (addons, /xui) and system messages, in their own Console tab
    soundsOn = true, soundsInCombat = true, whisperSoundsOn = true,   -- whisperSoundsOn: the whisper sound overrides (Sounds.lua)
    whisperSelect = true,   -- (Chat 0.6.31, CHATREV-10) switch to a whisper tab you start, also with New Whispers = Both (Whispers.lua)
    -- (Chat 0.6.33; REQUEST-LOG UI-18 / UI-19 / UI-21) QoL > Improved Chat's own switch: everything the addon adds to how chat behaves
    -- (scroll bar, fade and hide, history, filters, links, sounds, whisper tab switch, privacy cover, Chat Data Panel, sidebar). On by
    -- default, so a saved profile keeps what it had; independent of the Chat Panel switch (her answer: "1", two independent switches)
    improvedOn = true,
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

-------------------------------------------------------------------------------
-- V14 "off costs nothing" (Xaya, 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute
-- to performance cost / demand in any way"). Every part of the Chat Panel that has a switch registers a start and a stop here, and
-- C.Refresh starts or stops only the parts whose switch changed. Nothing of a part exists before its first start: its frames, events,
-- OnUpdate scripts, chat filters and hooks are made there; its stop clears its OnUpdate and unregisters its events. With the Chat Panel
-- off, nothing of it is created, registered or run. Two limits the game sets: (1) this addon is not LoadOnDemand, so its files are read
-- at every login while it is enabled in the AddOns list; (2) a hook (hooksecurefunc / HookScript) cannot be taken back, and neither can
-- a chat filter here (the 12.1.5 API documentation, docs/reference/api, has no RemoveMessageEventFilter; INFERENCE: not relied on). Those
-- are placed once, on the first start, and return at once on a cached flag (C.on[part], C.active) while their part is off; a /reload
-- removes them fully.
-------------------------------------------------------------------------------
C.on = {}          -- part name -> true while that part runs (the cached answer hooks read; never a settings read)
local parts = {}
-- (Chat 0.6.33; UI-18 / UI-19 / UI-21) which switch a part belongs to. "skin": Blizzard UI Reskin > Chat Panel (the look, and the
-- anchoring of Blizzard's chat into the pane); "improved": QoL > Improved Chat (behaviour the addon adds); "any": runs while either is on.
-- A part not listed is a skin part.
C.PART_GROUP = { panel = "any", bar = "improved", fade = "improved", console = "improved", messages = "improved", filter = "improved",
    itemref = "improved", scroll = "improved", whisperSelect = "improved", sidebar = "improved", inputfree = "skin" }
-- want(s): is the part wanted (the Chat Panel being on is checked by the caller); start(s) / stop(s); update(s): on every refresh while it runs
function C.Part(name, want, start, stop, update)
    parts[#parts + 1] = { name = name, want = want, start = start, stop = stop, update = update }
end
local function RunPart(p, fn, s)
    if not fn then return end
    local ok, err = pcall(fn, s)
    if not ok then
        C.applied[p.name] = false
        if not C.errors[p.name] then
            C.errors[p.name] = tostring(err)
            -- (Chat 0.6.20; REQUEST-LOG #82: recorded with its code in XayaUI's debug report, only when it happens)
            if ns.RecordWarn then pcall(ns.RecordWarn, "XUI-W005", p.name .. ": " .. tostring(err)) end
        end
    end
end
-- skinLive / impLive: the Chat Panel (skin) and Improved Chat are on. Called with one argument (the old form), both take that value.
function C.SyncParts(s, skinLive, impLive)
    if impLive == nil then impLive = skinLive end
    for _, p in ipairs(parts) do
        local g = C.PART_GROUP[p.name] or "skin"
        local live = (g == "skin" and skinLive) or (g == "improved" and impLive) or (g == "any" and (skinLive or impLive))
        local w = (live and s and p.want(s)) and true or false
        if w and not C.on[p.name] then C.on[p.name] = true; RunPart(p, p.start, s)
        elseif w then RunPart(p, p.update, s)
        elseif C.on[p.name] then C.on[p.name] = false; RunPart(p, p.stop, s) end
    end
end
function C.StartPart(name, s)
    for _, p in ipairs(parts) do
        if p.name == name and not C.on[name] then C.on[name] = true; RunPart(p, p.start, s) end
    end
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

-- The blocked answer is read again at every C.Refresh while the Chat Panel is switched on (the loading-screen and chat-window events
-- that also took the Chat Panel down before), never per frame or per message: up to Chat 0.6.13 every C.On() call made two
-- C_AddOns.IsAddOnLoaded calls (namespaces.md:162 `C_AddOns.IsAddOnLoaded(name: uiAddon)` -> `loadedOrLoading: bool, loaded: bool`),
-- and the fade driver called C.On() on every frame. INFERENCE: the other addon's own chat switch changes only with a reload of its
-- settings, so a value read at the refresh is current.
local blocked      -- nil: not read yet; false: nothing blocks; a string: the reason
local function Blocked()
    if blocked == nil then blocked = C.BlockedReason() or false end
    return blocked
end
-- (Chat 0.6.43; PS-57, #480) C.On / C.ImprovedOn read their switch as it is in effect this session: the settings window's switches
-- save and ask for a reload (Modules.lua section 5c); so does /xui chat on|off.
-- (Chat 0.6.18, S1 #48) and the Blizzard UI Reskin tab's own switch: off there turns the Chat Panel off too, its own switch kept
function C.On()
    local s = ns.chat2
    return s and ns.SwitchInEffect("chat.panel", s.enabled) and ns.ReskinTabOn() and not Blocked() and true or false
end
-- (Chat 0.6.33; UI-18 / UI-19 / UI-21) QoL > Improved Chat: its own switch only. It also runs beside another addon's chat skin (her words:
-- "should support other chat reskin options"): with the Chat Panel off it places its pieces around Blizzard's chat where it is.
function C.ImprovedOn()
    local s = ns.chat2
    return s and ns.SwitchInEffect("chat.improved", s.improvedOn ~= false) and true or false
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
C.fonts, C.remembered, C.suppressed, C.alphaEls, C.raised = {}, {}, {}, {}, {}
function C.SetFont(fs, path, size, flags)
    if not (fs and fs.SetFont) then return end
    if not C.fonts[fs] and fs.GetFont then
        local ok, p, sz, fl = pcall(fs.GetFont, fs)
        if ok and p then C.fonts[fs] = { p, sz, fl } end
    end
    local ok, res = pcall(fs.SetFont, fs, path or STANDARD_TEXT_FONT, size, flags or "")
    if not (ok and res) then pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size, flags or "") end
end

-- "Indent wrapped lines": the game's chat turns this on for its font (ChatFrameOverrides.lua: self:SetIndentedWordWrap(true)), so the
-- lines after the first of a long message start further in. Setting a font makes the window a font object of its own
-- (FontableFrameMixin:MakeFontObjectCustom copies the old one); whether that copy keeps the indent is not documented, and Xaya's
-- screenshots of 0.6.4 show wrapped lines starting flush with the message (inference: the indent was lost). So the setting is applied
-- again after every font change. SetIndentedWordWrap is one of the window's secure methods (ScrollingMessageFrameSecureMixin), so
-- calling it from an addon does not taint the window. It is only called when the value differs: each call lays the lines out again.
local function IndentOf(o)
    if not (o and o.GetIndentedWordWrap) then return nil end
    local ok, v = pcall(o.GetIndentedWordWrap, o)
    if ok and not issecret(v) and type(v) == "boolean" then return v end
    return nil
end
C.IndentOf = IndentOf
function C.SetWrapIndent(f, on)
    if not (f and f.SetIndentedWordWrap) then return false end
    on = on and true or false
    local cur = IndentOf(f)
    if f._xuiIndent == nil and cur ~= nil then f._xuiIndent = cur end   -- the game's own value, for turning the Chat Panel off
    if cur == on then return false end
    f:SetIndentedWordWrap(on)
    return true
end

-- #346 (Xaya's /xui chat indent, 2026-11-04: window left 32.0, text area left 6.0, every line 0.0 px from the window edge): the game
-- keeps its chat windows clamped to the screen (FloatingChatFrameTemplate clampedToScreen="true") and Edit Mode gives the main window
-- clamp margins from its selection box (EditModeSystemMixin:UpdateClampOffsets -> SetClampRectInsets; wow-ui-source live 12.1.5.70783).
-- With the Chat Panel at the screen's left edge, that margin pushes the whole window right of the text area: the empty space at the left.
-- The pane is what is placed now, so its windows are not clamped while the Chat Panel is on; the game's value comes back when it is off.
local function Clamped(f)
    if not (f and f.IsClampedToScreen) then return nil end
    local ok, v = pcall(f.IsClampedToScreen, f)
    if ok and not issecret(v) and type(v) == "boolean" then return v end
    return nil
end
C.Clamped = Clamped
function C.Unclamp(f)
    if not (f and f.SetClampedToScreen) then return false end
    local cur = Clamped(f)
    if f._xuiClamp == nil and cur ~= nil then f._xuiClamp = cur end
    if cur == false then return false end
    f:SetClampedToScreen(false)
    return true
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

-- a frame the Chat Panel no longer places (the window it belongs to was undocked): the game's own anchors back, and off the list that
-- C.Teardown puts back
function C.Forget(o)
    if not (o and o._xuiPts) then return end
    local pts = o._xuiPts
    o._xuiPts = nil
    pcall(function()
        o:ClearAllPoints()
        for _, p in ipairs(pts) do o:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    end)
    for i = #C.remembered, 1, -1 do if C.remembered[i] == o then table.remove(C.remembered, i) end end
end

-- everything we changed on the game's chat goes back: shown / hidden pieces, alpha, mouse, anchors, fonts, tab heights.
-- The game's own functions then lay the windows out again.
-- (Chat 0.6.33) in two halves: the skin's (Blizzard's chat back where and how the game draws it) and Improved Chat's (collapse and
-- fade alpha back, the block hidden). C.Teardown does both; the Chat Panel turned off with Improved Chat still on does the first only.
-- audit D31 (Chat 0.6.33): the game's own fade of old lines, as it was before XayaUI set it. The fade is Improved Chat's (UI-18 / UI-21),
-- so this runs when Improved Chat stops (Fade.lua) and at the full teardown, not when only the Chat Panel's look is taken off.
function C.RestoreTextFade()
    for _, f in ipairs(C.Frames()) do
        local o = f._xuiFade
        if o ~= nil then
            if f.SetFading then pcall(f.SetFading, f, o[1] and true or false) end
            if f.SetTimeVisible and type(o[2]) == "number" then pcall(f.SetTimeVisible, f, o[2]) end
            f._xuiFade = nil
        end
    end
end
function C.Teardown()
    if not C.active then return end
    C.TeardownSkin()
    C.RestoreTextFade()
    C.active = false
    C.master, C.fade = 1, 1
    for _, el in ipairs(C.alphaEls) do
        pcall(function()
            el._xuiSetting = true
            el:SetAlpha(el._xuiBase or 1)
            el._xuiSetting = false
            if el._xuiMouse ~= nil and el.EnableMouse then el:EnableMouse(el._xuiMouse); el._xuiMouse = nil end
        end)
        -- the SetAlpha hook (Frame.lua HookAlpha) is idle while off, so the game's value is read afresh when the Chat Panel comes back
        el._xuiBase = nil
    end
    if C.unlocked and C.ToggleMover then C.ToggleMover() end
    if C.Container() then C.Container():Hide() end
    if ns.ChatPrivacy_Refresh then ns.ChatPrivacy_Refresh() end
    if C.Sidebar_Refresh then pcall(C.Sidebar_Refresh) end
end
function C.TeardownSkin()
    if not C.skin then return end
    C.skin = false
    for o in pairs(C.suppressed) do pcall(C.Unsuppress, o) end
    C.suppressed = {}
    for _, f in ipairs(C.Frames()) do   -- the back-to-newest arrows: the game's own alpha and shown state (Frame.lua C.ToBottomUpdate)
        if C.ToBottomRelease then pcall(C.ToBottomRelease, f.ScrollToBottomButton) end
    end
    for _, o in ipairs(C.raised) do     -- the tab row's window list back in its own layer (Frame.lua C.RaiseTabList)
        if o._xuiStrata then pcall(o.SetFrameStrata, o, o._xuiStrata) end
        o._xuiStrata = nil
    end
    C.raised = {}
    C.inputFocus = false   -- the edit box's focus hooks are idle while the Chat Panel is off (Skin.lua); the next focus sets it again
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
    for _, f in ipairs(C.Frames()) do   -- the game's own "clamped to screen" value (#346)
        if f._xuiClamp ~= nil and f.SetClampedToScreen then pcall(f.SetClampedToScreen, f, f._xuiClamp); f._xuiClamp = nil end
    end
    for _, f in ipairs(C.Frames()) do   -- the game's own "indent wrapped lines" value, as it was before the Chat Panel set it
        if f._xuiIndent ~= nil and f.SetIndentedWordWrap then pcall(f.SetIndentedWordWrap, f, f._xuiIndent); f._xuiIndent = nil end
    end
    for _, f in ipairs(C.Frames()) do
        local tab = C.TabOf(f)
        if tab then
            if tab._xuiH and tab.SetHeight then pcall(tab.SetHeight, tab, tab._xuiH); tab._xuiH = nil end
            if tab.xuiBg then tab.xuiBg:Hide() end
            if C.RestoreTabText then pcall(C.RestoreTabText, tab) end   -- (Chat 0.6.20) the name's own anchors back
        end
    end
    if C.unlocked and C.ToggleMover then C.ToggleMover() end
    for _, fn in ipairs({ "FCF_DockUpdate", "FCF_UpdateButtonSide" }) do
        if type(_G[fn]) == "function" then pcall(_G[fn]) end
    end
end

-- the saved defaults: filled in the first time the Chat Panel is on (at login when it is saved on), or when its settings page is built
-- (the page shows them). V14: with the Chat Panel saved off, nothing is built for it at login.
local defaulted
function C.EnsureDefaults(defaults)   -- defaults: (P5) Chat_OnDBReady passes the defaults as they stood when this file loaded
    local s = ns.chat2
    if not s or defaulted == s then return end
    defaulted = s
    for k, v in pairs(defaults or C.DEFAULTS) do if s[k] == nil then s[k] = Copy(v) end end
    s.sounds = type(s.sounds) == "table" and s.sounds or {}
    -- whisper sound overrides (Sounds.lua): { list = { { who, enabled, source, value, channel } ... }, fav = { enabled, source, value, channel } }
    s.whisperSounds = type(s.whisperSounds) == "table" and s.whisperSounds or {}
    s.whisperSounds.list = type(s.whisperSounds.list) == "table" and s.whisperSounds.list or {}
end

-- the refresh bus ----------------------------------------------------------------------------------------------------------
-- C.active: the Chat Panel or Improved Chat is applied right now (set here, cleared by C.Teardown). C.skin: the Chat Panel (the skin) is
-- applied (cleared by C.TeardownSkin). Hooks the game cannot take back read them.
function C.Refresh()
    local s = ns.chat2
    if not s then return end
    if s.enabled then blocked = C.BlockedReason() or false end
    local skin, imp = C.On(), C.ImprovedOn()
    if not (skin or imp) then                               -- both off (or the skin blocked by another chat addon and Improved Chat off):
        C.Teardown(); C.SyncParts(s, false, false); return  -- give Blizzard's chat back, untouched, and stop every driver, event and filter
    end
    C.EnsureDefaults()
    if not skin then C.TeardownSkin() end                   -- Improved Chat alone: Blizzard's chat back where the game puts it
    C.active, C.skin = true, skin
    C.SyncParts(s, skin, imp)
    for _, m in ipairs(C.mods) do C.Try(m.name, m.fn, s) end
end

ns.RegisterReskin("chatpanel", function() C.Refresh() end)   -- (the Reskin tab's switch: core ns.SetReskinTab walks these)

local pending
function C.Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0, function() pending = false; C.Refresh() end)
end

-- (P5) Chat_OnDBReady ran while this file loaded (XayaUI's settings were ready before this addon loaded), so it filled in only the
-- defaults this file had defined by then: Privacy.lua (ns.CHAT_DEFAULTS) and Sidebar.lua (C.SIDEBAR_DEFAULTS) add theirs later. Since
-- P5 it runs at this addon's ADDON_LOADED, after every file: it uses the defaults as they stood at the end of this file (kept below), so
-- the saved settings and what the player sees stay exactly as before (the later defaults still apply where they did: their own files
-- and the settings page). (Found while building P5, not changed here: the Sidebar's and the privacy cover's defaults therefore never
-- reach the saved settings at login; see the P5 debug-log entry.)
function ns.Chat_OnDBReady()
    local defaultsAtLoad = C.defaultsAtLoad
    ChatS.chat = ChatS.chat or {}                        -- privacy cover settings (kept as they are)
    ns.chatDB = ChatS.chat
    ChatS.chat2 = ChatS.chat2 or {}                      -- the new Chat Panel (old chat settings are not read)
    local s = ChatS.chat2
    if s.enabled == nil then s.enabled = C.DEFAULTS.enabled end
    ns.chat2 = s
    -- "Cover the chat at every login" (Privacy.lua): up to Chat 0.6.13 read on the first loading screen by a frame of its own
    if ns.chatDB.privStartHidden then ns.chatDB.privOn = true end
    -- V14: the Chat Panel saved off (or the Reskin tab off) and Improved Chat saved off: nothing more is built, registered or run
    if not ((s.enabled and ns.ReskinTabOn()) or s.improvedOn ~= false) then return end
    -- the privacy defaults are merged here, at the same moment as before (INFERENCE: in the game this runs while this file loads, before
    -- Privacy.lua has filled ns.CHAT_DEFAULTS, so it merges nothing there; kept as it was, see debug-log 2026-11-05 chat 0.6.14). Since
    -- Chat 0.6.33 (audit D38) Privacy.lua's defaults match that: no border, no label unless ticked.
    ns.Merge(ChatS.chat, defaultsAtLoad and defaultsAtLoad.chat or ns.CHAT_DEFAULTS)
    C.EnsureDefaults(defaultsAtLoad and defaultsAtLoad.chat2)
    C.StartPart("panel", s)                                       -- the refresh events below; the first refresh starts the rest
end

-- the "panel" part: the events that make the Chat Panel lay itself out again, and the theme callback (placed once; idle while off)
local REFRESH_EVENTS = { "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }
local drv, themeHooked
C.Part("panel", function() return true end,
    function()
        if not drv then
            drv = CreateFrame("Frame")
            drv:SetScript("OnEvent", function() C.Schedule() end)
        end
        for _, ev in ipairs(REFRESH_EVENTS) do drv:RegisterEvent(ev) end
        if not themeHooked and ns.Theme and ns.Theme.OnResolve then
            themeHooked = true
            -- a theme change only matters to the chat with "Use the XayaUI theme" on (C.ThemeOn is the only reader of ns.Theme here)
            ns.Theme.OnResolve(function() if C.on.panel and ns.chat2 and ns.chat2.useTheme then C.Schedule() end end)
        end
    end,
    function()
        if drv then for _, ev in ipairs(REFRESH_EVENTS) do drv:UnregisterEvent(ev) end end
    end)

-- /xui chat indent, /xui chat whispers and the measurements of /xui chat wrap moved to XayaUI Dev Assist (Chat 0.6.20; REQUEST-LOG #81,
-- Xaya 2026-11-06: "Move all of them"; XayaUI_DevAssist/CoreDebug.lua), with the whisper counters that only its report read. Dev Assist
-- adds the three words to /xui chat (ns.RegisterSubcommand("chat", ...)); without it they do not exist. C.Rewrap (the fix itself),
-- C.WrapStatus, C.IndentOf and C.Clamped stay here.

-- /xui chat [on|off|reset|move|history|settings|status]
function C.Command(arg)
    local rest = tostring(arg or ""):lower():match("^%s*%S*%s*(.-)%s*$") or ""
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    local s = ns.chat2
    if not s then ns.Print("Chat Panel: settings are not loaded yet."); return end
    -- (Chat 0.6.43; PS-57) on / off go the way of the settings switch: saved, the reload question, in effect after the /reload (5c)
    if arg == "on" or arg == "off" then
        local on = arg == "on"
        local line = ns.SwitchCommand("chat.panel", s.enabled, function() s.enabled = on end, "Chat Panel", on)
        ns.Print(line .. ((on and not ns.ReskinTabSaved()) and " It shows once Blizzard Reskin is on again (Blizzard Reskin > Overview, then /reload)." or ""))
    elseif arg == "reset" then
        s.point, s.x, s.y, s.width, s.height = C.DEFAULTS.point, C.DEFAULTS.x, C.DEFAULTS.y, C.DEFAULTS.width, C.DEFAULTS.height
        C.Refresh(); ns.Print("Chat Panel: position and size reset.")
    elseif arg == "move" then if C.ToggleMover then C.ToggleMover() end
    elseif arg == "history" then if C.History_Toggle then C.History_Toggle() end
    elseif arg == "settings" or arg == "options" then if C.OpenSettings then C.OpenSettings() end
    elseif arg ~= "" and ns.RunSubcommand and ns.RunSubcommand("chat", arg, rest) then
        -- (XayaUI Dev Assist's: wrap, indent, whispers; Chat 0.6.20)
    else
        local why = C.BlockedReason()
        local state = not s.enabled and "OFF" or (not ns.ReskinTabOn() and "OFF (Blizzard Reskin is off: Blizzard Reskin > Overview)") or (why and ("blocked: " .. why)) or "ON"
        local extra = {}
        for _, h in ipairs(ns.SubcommandHelp and ns.SubcommandHelp("chat") or {}) do extra[#extra + 1] = h:match("^(%S+)") end
        ns.Print((("Chat Panel: " .. state .. ". /xui chat on|off|reset|move|history|" .. (#extra > 0 and (table.concat(extra, "|") .. "|") or "") .. "settings"):gsub("|", "||")))
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
do   -- (P5) the defaults as they stand at the end of this file (see Chat_OnDBReady)
    local a, b = {}, {}
    for k, v in pairs(ns.CHAT_DEFAULTS) do a[k] = v end
    for k, v in pairs(C.DEFAULTS) do b[k] = v end
    C.defaultsAtLoad = { chat = a, chat2 = b }
end
ns.WhenSettingsReady("chat", ns.Chat_OnDBReady)   -- (P5: once XayaUIChatDB is open, at this addon's ADDON_LOADED; Modules.lua section 0c)
-- (Chat 0.6.20) what XayaUI Dev Assist's /xui chat wrap / indent / whispers read: the Chat Panel's table and its settings
ns.Provide("chatDebug", { C = C, Settings = function() return ns.chat2 end,
    Options = function() return ns.BuildChatTab and ns.BuildChatTab(function() end) end,   -- (Chat 0.6.31) the settings tree, for the QA walkthrough
    ImprovedOptions = function() return ns.BuildImprovedChatTab and ns.BuildImprovedChatTab(function() end) end })   -- (Chat 0.6.33) QoL > Improved Chat's
ns.RegisterCommand("chat", function(arg) C.Command(arg) end, "/xui chat (Chat Panel: on, off, reset, move, history, settings)")
ns.RegisterCommand("panel", function() if C.OpenSettings then C.OpenSettings("bar") end end, "/xui panel (Chat Data Panel settings)")
