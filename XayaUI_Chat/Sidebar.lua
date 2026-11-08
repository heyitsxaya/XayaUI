-------------------------------------------------------------------------------
-- Chat/Sidebar.lua (XayaUI Chat 0.6.35) : the chat sidebar, a part of QoL > Improved Chat (REQUEST-LOG UI-3, UI-17, A16 CR-4 / CR-6 / CR-7).
-- Her words: "privacy bar should exist in a chat sidebar option that can be set to have a background or none at all. this bar should be
-- configurable to be show on mouseover, auto-hide, etc and the buttons nested within should inherit that behavior. the sidebar should also
-- be moveable to top, bottom, left or right sides and influence chat placement appropriately if it clips into the chat data panel or the
-- end of the screen"; "left, but default chat size should be untouched -- only modify if the user sets a specified width for the whole
-- chat container (including sidebar)". Her answers (question box, 2026-11-07): auto-hide "Fade and auto hide in combat both tick boxes";
-- buttons "Privacy cover, Blizzard chat buttons, History + window list, Scroll to bottom, Any other chat-based icon (can be minimap icons
-- the user allows, too ...; default to having sidebar on if minimap is turned off)"; the eye button "Moves into sidebar"; fresh install
-- "On with same opacity as chat pane with an additional layer underneath the black using the primary class color for tinting"; minimap
-- icons "XayaUI's own first".
--
-- One strip OUTSIDE the chat block (so it never covers the Chat Data Panel, which is part of the block), on the chosen side, as long as
-- the block's side. When it would run off the screen, the Chat Panel's block is placed further in by that much (Frame.lua C.Layout reads
-- C.Sidebar_Clip); with the Chat Panel off (Improved Chat alone) Blizzard's chat is not moved and the strip stays on screen over its edge.
-- The chat's own size is never changed, unless "Width of the whole chat" is set (then pane + sidebar = that width; C.Sidebar_PaneWidth).
-- Shown: always or on mouseover; and two tick boxes: fade with the chat, hide in combat. Every button is a child of the strip, so it
-- follows all of these. Own code, from the documented game API. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns
local C = ns.Chat
local issecret = C.IsSecret

C.SIDEBAR_DEFAULTS = {
    -- sbFade on by default (O-143, Xaya 2026-11-07: "the sidebar icons should also be fading")
    sbOn = true, sbSide = "LEFT", sbShow = "ALWAYS", sbFade = true, sbCombat = false, sbBg = true,
    sbBtn = 22,          -- button size in pixels (session's choice, between the history button's 16 and the eye button's 28)
    sbGap = 2,           -- between the strip and the chat block (the Chat Data Panel's own gap: session)
    sbChatW = 0,         -- 0: the chat's size is untouched; more: the whole chat container (sidebar included) is this wide (UI-17)
    sbPriv = true, sbBlizz = true, sbHist = true, sbWindows = true, sbBottom = true,
}
for k, v in pairs(C.SIDEBAR_DEFAULTS) do if C.DEFAULTS[k] == nil then C.DEFAULTS[k] = v end end

local PAD = 2
local bar, poll, ev
local slots = {}       -- key -> the frame placed in the strip
local moved = {}       -- Blizzard buttons taken into the strip: btn -> { parent, points }
local inCombat = false
local function S() return ns.chat2 end
local function Clamp(v, lo, hi, def) v = tonumber(v); if not v or issecret(v) then return def end; return math.max(lo, math.min(hi, v)) end
local function Vertical(s) return s.sbSide ~= "TOP" and s.sbSide ~= "BOTTOM" end

function C.SidebarOn() return C.on and C.on.sidebar and true or false end
function C.Sidebar() return bar end
function C.Sidebar_Thickness()
    local s = S()
    if not (s and C.SidebarOn()) then return 0, 0 end
    return Clamp(s.sbBtn, 14, 40, 22) + 2 * PAD, Clamp(s.sbGap, 0, 20, 2)
end
-- the slot the privacy (Privacy.lua) and history (History.lua) buttons go into while the sidebar holds them
function C.Sidebar_Slot(key)
    local s = S()
    if not (s and bar and C.SidebarOn()) then return nil end
    if key == "privacy" and s.sbPriv == false then return nil end
    if key == "hist" and s.sbHist == false then return nil end
    return bar
end
function C.Sidebar_Has(key) return C.Sidebar_Slot(key) ~= nil end

-- UI-17: "only modify if the user sets a specified width for the whole chat container (including sidebar)"
function C.Sidebar_PaneWidth(W, besideBar)
    local s = S()
    local cw = s and tonumber(s.sbChatW) or 0
    if not (s and C.SidebarOn() and cw and cw > 0) then return W end
    local t, g = C.Sidebar_Thickness()
    local side = Vertical(s) and (t + g) or 0
    return math.max(220, cw - side - (besideBar or 0))
end

-- how far the Chat Panel's block must move in so the strip stays on screen (Frame.lua C.Layout, Chat Panel on only)
function C.Sidebar_Clip(container)
    local s = S()
    if not (s and container and C.SidebarOn()) then return 0, 0 end
    local t, g = C.Sidebar_Thickness()
    local l, b, w, h = container:GetLeft(), container:GetBottom(), container:GetWidth(), container:GetHeight()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    for _, v in ipairs({ l, b, w, h, sw, sh }) do if type(v) ~= "number" or issecret(v) then return 0, 0 end end
    local need = t + g
    if s.sbSide == "TOP" then return 0, math.min(0, sh - (b + h + need))
    elseif s.sbSide == "BOTTOM" then return 0, math.max(0, need - b)
    elseif s.sbSide == "RIGHT" then return math.min(0, sw - (l + w + need)), 0 end
    return math.max(0, need - l), 0
end

-------------------------------------------------------------------------------
-- buttons
-------------------------------------------------------------------------------
local function Tip(self, title, line)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    if line then GameTooltip:AddLine(line, 1, 1, 1, true) end
    GameTooltip:Show()
end
local function Own(key, title, line, onClick)
    local b = CreateFrame("Button", "XayaUIChatSidebar" .. key, bar)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(0, 0, 0, 0.5)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.15)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) Tip(self, title, line) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
local function Lines(b, list)   -- simple glyphs drawn with lines: { x1, y1, x2, y2 } in a -1..1 box
    b.lines, b.segs = b.lines or {}, list
    for i in ipairs(list) do
        local l = b.lines[i] or b:CreateLine(nil, "OVERLAY"); b.lines[i] = l
        l:SetThickness(1.5); l:SetColorTexture(1, 1, 1, 0.9)
    end
end
local function DrawLines(b, size)
    local k = size * 0.3
    for i, l in ipairs(b.lines or {}) do
        local s = b.segs and b.segs[i]
        if s then l:SetStartPoint("CENTER", b, s[1] * k, s[2] * k); l:SetEndPoint("CENTER", b, s[3] * k, s[4] * k) end
    end
end

local function SelectedFrame()
    local dock, get = rawget(_G, "GENERAL_CHAT_DOCK"), rawget(_G, "FCFDock_GetSelectedWindow")
    if dock and type(get) == "function" then local ok, f = pcall(get, dock); if ok and f then return f end end
    return rawget(_G, "SELECTED_CHAT_FRAME") or C.Main()
end

local own = {}
local function BuildOwn()
    if own.hist then return end
    -- the history window (History.lua's own button goes in instead while it exists; this is the fallback with it hidden at the tab row)
    own.windows = Own("Windows", "Chat windows", "Lists every chat window; click one to switch to it.", function(self)
        local ob = _G.GeneralDockManager and _G.GeneralDockManager.overflowButton
        local fn = ob and ob.GetScript and ob:GetScript("OnClick")
        if fn then pcall(fn, ob, "LeftButton") end
    end)
    Lines(own.windows, { { -1, 0.6, 1, 0.6 }, { -1, 0, 1, 0 }, { -1, -0.6, 1, -0.6 }, { -1, 0.6, -1, -0.6 } })
    own.bottom = Own("Bottom", "Newest message", "Scrolls the chat to its newest line.", function()
        local f = SelectedFrame()
        if f and f.ScrollToBottom then pcall(f.ScrollToBottom, f) end
    end)
    Lines(own.bottom, { { -0.8, 0.5, 0, -0.3 }, { 0, -0.3, 0.8, 0.5 }, { -0.8, -0.8, 0.8, -0.8 } })
    own.xui = Own("XayaUI", "XayaUI", "Left-click: the quick-access list. Right-click: settings.", nil)
    own.xui:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    own.xui:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" then if ns.ToggleUI then ns.ToggleUI() end
        elseif ns.Minimap_TogglePopupAt then ns.Minimap_TogglePopupAt(self) end
    end)
    own.xui.icon = own.xui:CreateTexture(nil, "ARTWORK"); own.xui.icon:SetPoint("TOPLEFT", 2, -2); own.xui.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    own.hist = true
end

-- Blizzard's chat buttons (the strip beside its chat: menu, channels, voice). Taken into the sidebar out of combat and given back the
-- same way (they are not protected; their parent and anchors are remembered). (wow-ui-source live: ChatFrameMenuButton,
-- ChatFrameChannelButton, ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton in FloatingChatFrame.xml / ChatFrame.xml)
local BLIZZ = { "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }
local function Take(b)
    if moved[b] or (InCombatLockdown and InCombatLockdown()) then return moved[b] ~= nil end
    local pts = {}
    local ok, n = pcall(b.GetNumPoints, b)
    for i = 1, (ok and n or 0) do local ok2, p, rel, rp, x, y = pcall(b.GetPoint, b, i); if ok2 and p then pts[#pts + 1] = { p, rel, rp, x, y } end end
    moved[b] = { parent = b:GetParent(), points = pts }
    b:SetParent(bar)
    if not b._xuiSbHook then
        b._xuiSbHook = true
        -- the game shows / hides the voice buttons itself (in a voice channel or not): lay the strip out again
        pcall(b.HookScript, b, "OnShow", function() if C.on.sidebar then C.Schedule() end end)
        pcall(b.HookScript, b, "OnHide", function() if C.on.sidebar then C.Schedule() end end)
    end
    return true
end
local function GiveBack(b)
    local m = moved[b]
    if not m or (InCombatLockdown and InCombatLockdown()) then return end
    pcall(function()
        b:SetParent(m.parent)
        b:ClearAllPoints()
        for _, p in ipairs(m.points) do b:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    end)
    moved[b] = nil
end
local function GiveAllBack() for b in pairs(moved) do GiveBack(b) end end

-- XayaUI's own button (core MinimapButton.lua): in the sidebar when its "Show it in" says Chat sidebar or Both, or, with nothing chosen,
-- while the minimap button is turned off (her words: "default to having sidebar on if minimap is turned off")
local function XuiHere()
    local w = ns.Minimap_Where and ns.Minimap_Where()
    return w == "SIDEBAR" or w == "BOTH"
end
C.Sidebar_XuiHere = XuiHere

-------------------------------------------------------------------------------
-- layout and visibility
-------------------------------------------------------------------------------
local function ClassRGB()
    local ok, _, file = pcall(UnitClass, "player")
    local c = ok and file and not issecret(file) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if c then return c.r, c.g, c.b end
    return 0.5, 0.5, 0.5
end

local function Build()
    if bar then return end
    bar = CreateFrame("Frame", "XayaUIChatSidebar", UIParent)
    bar:SetFrameStrata("MEDIUM"); bar:SetFrameLevel(50)
    bar:SetClampedToScreen(true)
    -- the background: a layer tinted with the player's class colour, and over it the chat pane's black at the chat pane's opacity
    bar.tint = bar:CreateTexture(nil, "BACKGROUND", nil, 0); bar.tint:SetAllPoints()
    bar.black = bar:CreateTexture(nil, "BACKGROUND", nil, 1); bar.black:SetAllPoints()
    BuildOwn()
    -- (Chat 0.6.44; #495, REQUEST-LOG PS-59) while the settings window is shown, a right-click on the strip (between its buttons; the
    -- strip takes the mouse only then) opens the element menu (core Modules.lua section 11): "Element options" opens QoL > Improved Chat
    -- > Sidebar. No X / Y: the strip's place is a side of the chat and a gap (sbSide, sbGap), it has no X / Y offsets. Its buttons keep
    -- their own clicks (the XayaUI button's right-click still opens / closes the window). Registered when the strip is made (V14).
    if ns.RegisterElement then
        ns.RegisterElement({ key = "chatSidebar", label = "Chat sidebar", mouse = true,
            targets = function(add) add(bar, "OnMouseUp") end,
            open = function() C.OpenSettings("sidebar") end })
    end
end

local function Place(s)
    local cont = C.Container()
    if not cont then bar:Hide(); return end
    local t, g = C.Sidebar_Thickness()
    bar:ClearAllPoints()
    local side = s.sbSide
    if side == "TOP" then bar:SetPoint("BOTTOMLEFT", cont, "TOPLEFT", 0, g); bar:SetPoint("BOTTOMRIGHT", cont, "TOPRIGHT", 0, g); bar:SetHeight(t)
    elseif side == "BOTTOM" then bar:SetPoint("TOPLEFT", cont, "BOTTOMLEFT", 0, -g); bar:SetPoint("TOPRIGHT", cont, "BOTTOMRIGHT", 0, -g); bar:SetHeight(t)
    elseif side == "RIGHT" then bar:SetPoint("TOPLEFT", cont, "TOPRIGHT", g, 0); bar:SetPoint("BOTTOMLEFT", cont, "BOTTOMRIGHT", g, 0); bar:SetWidth(t)
    else bar:SetPoint("TOPRIGHT", cont, "TOPLEFT", -g, 0); bar:SetPoint("BOTTOMRIGHT", cont, "BOTTOMLEFT", -g, 0); bar:SetWidth(t) end
    -- background
    if s.sbBg ~= false then
        local r, gg, b, a = C.Color(s, "bg", "xui-pane", "bg")
        local cr, cg, cb = ClassRGB()
        bar.tint:SetColorTexture(cr, cg, cb, a); bar.black:SetColorTexture(r, gg, b, a)
        bar.tint:Show(); bar.black:Show()
    else
        bar.tint:Hide(); bar.black:Hide()
    end
    -- buttons, in a fixed order: privacy, Blizzard's chat buttons, history, window list, newest message, XayaUI
    local size = Clamp(s.sbBtn, 14, 40, 22)
    local list = {}
    if s.sbPriv ~= false and _G.XayaUIChatPrivacyButton and ns.chatDB and ns.chatDB.privBtn ~= false then list[#list + 1] = _G.XayaUIChatPrivacyButton end
    if s.sbBlizz ~= false then
        for _, n in ipairs(BLIZZ) do
            local b = _G[n]
            if b and Take(b) and b:IsShown() then list[#list + 1] = b end
        end
    else GiveAllBack() end
    if s.sbHist ~= false and _G.XayaUIChatHistoryButton and s.histButton and s.histOn ~= false then list[#list + 1] = _G.XayaUIChatHistoryButton end
    own.windows:SetShown(s.sbWindows ~= false); if s.sbWindows ~= false then list[#list + 1] = own.windows end
    own.bottom:SetShown(s.sbBottom ~= false); if s.sbBottom ~= false then list[#list + 1] = own.bottom end
    local xh = XuiHere()
    own.xui:SetShown(xh)
    if xh then
        own.xui.icon:SetTexture((ns.Minimap_ResolveIcon and ns.Minimap_ResolveIcon(ns.minimapDB and ns.minimapDB.iconOverride)) or 1390944)
        own.xui.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        list[#list + 1] = own.xui
    end
    local vert = Vertical(s)
    for i, b in ipairs(list) do
        b:ClearAllPoints()
        b:SetSize(size, size)
        local off = PAD + (i - 1) * (size + PAD)
        if vert then b:SetPoint("TOP", bar, "TOP", 0, -off) else b:SetPoint("LEFT", bar, "LEFT", off, 0) end
        if b.lines then DrawLines(b, size) end
        b:SetFrameLevel(bar:GetFrameLevel() + 2)
    end
    slots = list
end

local function Over()
    local f = MouseIsOver
    if type(f) ~= "function" then return false end
    local cont = C.Container()
    local ok1, a = pcall(f, bar); local ok2, b = pcall(f, cont)
    return (ok1 and a) or (ok2 and b) or false
end
-- the strip's alpha: mouseover, fading with the chat, hidden in combat. Buttons are children: they follow.
function C.Sidebar_Alpha()
    local s = S()
    if not (s and bar and C.SidebarOn()) then return end
    if s.sbCombat and inCombat then bar:Hide(); return end
    if C.IsCollapsed() then bar:Hide(); return end
    bar:Show()
    local a = 1
    if s.sbShow == "MOUSEOVER" and not Over() then a = 0 end
    if s.sbFade then a = a * (C.fade or 1) end
    if math.abs((bar:GetAlpha() or 1) - a) > 0.004 then bar:SetAlpha(a) end
end

local acc = 0
local function Poll(_, dt)   -- only while "On mouseover" is chosen (V14)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    C.Sidebar_Alpha()
end

function C.Sidebar_Refresh()
    local s = S()
    if not (s and C.SidebarOn() and C.active and C.Container() and C.Container():IsShown()) then
        if bar then bar:Hide() end
        return
    end
    Build()
    Place(s)
    if poll then poll:SetScript("OnUpdate", (s.sbShow == "MOUSEOVER") and Poll or nil) end
    C.Sidebar_Alpha()
end

C.Register("sidebar", function() C.Sidebar_Refresh() end)
C.Part("sidebar", function(s) return s.sbOn ~= false end,
    function(s)
        Build()
        if not poll then poll = CreateFrame("Frame") end
        if not ev then
            ev = CreateFrame("Frame")
            ev:SetScript("OnEvent", function(_, e)
                inCombat = (e == "PLAYER_REGEN_DISABLED")
                if e == "PLAYER_REGEN_ENABLED" then C.Schedule() end   -- Blizzard's buttons taken / given back once combat ends
                C.Sidebar_Alpha()
            end)
        end
        ev:RegisterEvent("PLAYER_REGEN_DISABLED"); ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
    end,
    function()
        if ev then ev:UnregisterEvent("PLAYER_REGEN_DISABLED"); ev:UnregisterEvent("PLAYER_REGEN_ENABLED") end
        if poll then poll:SetScript("OnUpdate", nil) end
        GiveAllBack()
        if bar then bar:Hide() end
        -- the privacy and history buttons go back beside the chat / to the tab row
        if ns.ChatPrivacy_Refresh then ns.ChatPrivacy_Refresh() end
        C.Schedule()
    end)

-------------------------------------------------------------------------------
-- settings: QoL > Improved Chat > Sidebar (Options.lua puts it there)
-------------------------------------------------------------------------------
function C.Sidebar_Options(Notify, S2, Re)
    local function St() return S2() end
    local function tog(name, field, order, desc, dflt)
        return { type = "toggle", name = name, desc = desc, order = order, width = "full",
            get = function() local v = St()[field]; if v == nil then return dflt ~= false end; return v and true or false end,
            set = function(_, v) local s = ns.chat2; if s then s[field] = v and true or false end; Re() end }
    end
    local function hdr(name, order) return { type = "header", name = name, order = order } end
    local function off() return St().sbOn == false end
    local g = { type = "group", name = "Sidebar", order = 6, args = {
        on = tog("Show the chat sidebar", "sbOn", 1, "A strip beside the chat that holds the chat's buttons.", true),
        placeHdr = hdr("Place and look", 10),
        side = { type = "select", name = "Side", order = 11, values = { LEFT = "Left", RIGHT = "Right", TOP = "Top", BOTTOM = "Bottom" }, sorting = { "LEFT", "RIGHT", "TOP", "BOTTOM" },
            desc = "Which side of the chat it sits on. If it would run off the screen, the chat moves in to make room.",
            disabled = off, get = function() return St().sbSide or "LEFT" end, set = function(_, v) local s = ns.chat2; if s then s.sbSide = v end; Re() end },
        bg = tog("Background", "sbBg", 12, "The chat pane's background at its opacity, over a layer tinted with your class color. Untick for bare buttons.", true),
        size = { type = "range", name = "Button size (pixels)", order = 13, min = 14, max = 40, step = 1, disabled = off,
            get = function() return tonumber(St().sbBtn) or 22 end, set = function(_, v) local s = ns.chat2; if s then s.sbBtn = v end; Re() end },
        chatW = { type = "range", name = "Width of the whole chat (pixels)", order = 14, min = 0, max = 1400, step = 10, disabled = off,
            desc = "0 leaves the chat's size as it is. Any other value makes the chat and the sidebar together this wide.",
            get = function() return tonumber(St().sbChatW) or 0 end, set = function(_, v) local s = ns.chat2; if s then s.sbChatW = v end; Re() end },
        showHdr = hdr("When it shows", 20),
        show = { type = "select", name = "Show", order = 21, values = { ALWAYS = "Always", MOUSEOVER = "On mouseover" }, sorting = { "ALWAYS", "MOUSEOVER" },
            desc = "On mouseover: hidden until the mouse is over the sidebar or the chat. Its buttons do the same.",
            disabled = off, get = function() return St().sbShow or "ALWAYS" end, set = function(_, v) local s = ns.chat2; if s then s.sbShow = v end; Re() end },
        fade = tog("Fade with the chat", "sbFade", 22, "Fades out and back in together with the chat (Improved Chat > General > Scroll and fade options).", true),
        combat = tog("Hide in combat", "sbCombat", 23, "Hidden while you are in combat.", false),
        btnHdr = hdr("Buttons", 30),
        priv = tog("Privacy cover", "sbPriv", 31, "The eye button that covers or shows the chat sits here instead of beside the chat.", true),
        blizz = tog("Blizzard's chat buttons", "sbBlizz", 32, "The game's chat menu, channels and voice buttons. Moved in or back out of combat only.", true),
        hist = tog("Chat history", "sbHist", 33, "The history button sits here instead of at the end of the tab row.", true),
        windows = tog("Chat windows", "sbWindows", 34, "A button that lists every chat window.", true),
        bottom = tog("Newest message", "sbBottom", 35, "A button that scrolls the chat to its newest line.", true),
        xuiNote = { type = "description", order = 36, width = "full",
            name = "|cffaaaaaaXayaUI's own button joins the sidebar when Settings > Minimap Button > Show it in says Chat sidebar or Both, or when the minimap button is turned off.|r" },
    } }
    for k, v in pairs(g.args) do if k ~= "on" and v.type == "toggle" then v.disabled = off end end
    -- a dropdown never takes a row alone (DISPLAY-RULES A6.2): the tick boxes beside it share its row
    g.args.bg.width, g.args.fade.width, g.args.combat.width = "normal", "normal", "normal"
    return g
end
-- (core MinimapButton.lua calls this when "Show it in" changes)
ns.Provide("chatSidebar", { Refresh = function() if C.on and C.on.sidebar then C.Sidebar_Refresh() end end })
