-------------------------------------------------------------------------------
-- ChatPanel.lua : the info bars ("data text panels") under or above the chat windows. Own code.
-- Works without the "ElvUI Chat Reskin" master switch and without the main XayaUI settings window:
--   /xui panel   (or right-click a bar)   opens a small settings window of its own.
-- Left panel = under the main chat window (ChatFrame1). Right panel = under the window chosen as "right chat window" (ChatPanels.lua).
-- The block drawing itself (layout, slot look) is shared with the screen data panels: DataBlocks.lua. Extra data types (the stats)
-- come from DataPanels.lua (ns.DataText).
-- Each bar is a row of 1 to 20 blocks. A block shows time, FPS + latency, FPS, latency, friends, gold, durability, free bag slots, zone
-- or your own text, and has its own gaps, alignment, text scale, background, text color and "fill remaining space" setting.
-- The bar can be even-split or auto-sized, snapped to the top or bottom screen edge, and shown always / in combat / out of combat /
-- on mouse-over. A toggle button at the outer end hides / shows that chat window.
-- Right panel settings use the same names as the left ones with an "r" in front (rpanelOn, rpanelAnchor, ...).
-- UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local D = ns.CHAT_DEFAULTS
local function K(side, k) return side == "R" and ("r" .. k) or k end

local BASE = {
    panelOn = false,
    panelAnchor = "BELOW",         -- BELOW | ABOVE the chat window
    panelWidthMode = "CHAT",       -- older key: CHAT / SCREEN = resize to fit, CUSTOM = own length (now the panelMatch tick box)
    panelWidth = 400, panelHeight = 22,    -- panelWidth = length when not resized to fit; panelHeight = thickness panelGap = 2, panelOffX = 0, panelOffY = 0,
    panelBg = true, panelBgR = 0, panelBgG = 0, panelBgB = 0, panelBgAlpha = 45,
    panelBorder = true, panelBorderR = 0, panelBorderG = 0, panelBorderB = 0,
    panelTextSize = 13, panelTextR = 1, panelTextG = 1, panelTextB = 1,
    panelValueR = 0.64, panelValueG = 0.21, panelValueB = 0.93,   -- numbers in friends etc. (purple, as in Xaya's screenshot)
    panelSlots = 3,                -- number of blocks, 1 to 20
    panelSizing = "EVEN",          -- EVEN (equal widths) | AUTO (width follows the text, blocks marked "fill" take what is left)
    panelSnap = "CHAT",            -- CHAT (snapped to the chat window) | TOP | BOTTOM edge of the screen
    -- panelChatSide (BOTTOM | TOP | LEFT | RIGHT of the chat window) and panelMatch (resize the bar to the chat window's width, or height
    -- for LEFT / RIGHT) are read through ChatSide() / Match() below, which fall back to the older panelAnchor / panelWidthMode keys.
    panelVisibility = "ALWAYS",    -- ALWAYS | COMBAT | NOCOMBAT | MOUSEOVER
    panelLabels = true,            -- stat types: put the stat name in front of the value
    panelHoverHL = false,          -- highlight the block under the mouse
    panelClearEdit = true,         -- keep the bar clear of the chat edit box (the bar moves out past it)
    panelPushChat = true,          -- push the main chat up when a bar under it would not fit above the screen's bottom edge
    panelOpaqueEdit = false,       -- draw the chat edit box nearly opaque while this bar is on, so the two never visually clash
    panelCustom1 = "", panelCustom2 = "", panelCustom3 = "",
    panelHideWhenCollapsed = false,
    panelFadeUntilHover = false,
    panelClock24 = true, panelLocalTime = true,
}
for k, v in pairs(BASE) do D[k] = v; D["r" .. k] = v end
D.panelSlot1, D.panelSlot2, D.panelSlot3 = "FPSMS", "NONE", "FRIENDS"    -- the look in Xaya's screenshot
D.rpanelSlot1, D.rpanelSlot2, D.rpanelSlot3 = "TIME", "NONE", "GOLD"

local function Store() return ns.chatDB end
local panels = { L = {}, R = {} }    -- per side: frame, slots, toggle
local win, editSide = nil, "L"

-- data sources -------------------------------------------------------------------------------------------------------------
local PROVIDERS = {}
local ORDER = { "NONE", "TIME", "FPSMS", "FPS", "LATENCY", "FRIENDS", "GOLD", "DURABILITY", "BAGS", "ZONE", "CUSTOM" }
local NAMES = { NONE = "(empty)", TIME = "Time", FPSMS = "FPS and latency", FPS = "Frame rate", LATENCY = "Latency", FRIENDS = "Friends online",
    GOLD = "Gold", DURABILITY = "Durability", BAGS = "Free bag slots", ZONE = "Zone", CUSTOM = "Custom text" }

-- per-block settings ------------------------------------------------------------------------------------------------------
-- stored as s[<side>panelBlocks][i] = { src=, custom=, gapL=, gapR=, fill=, align=, scale=, bgOn=, bgR/G/B/A=, textOn=, tR/G/B= }.
-- A block without its own entry reads the older panelSlotN / panelCustomN keys (first three) and the defaults below.
local B = ns.DataBlocks          -- DataBlocks.lua: the shared block engine (layout, slot look)
local MAXN = B.MAXN
local BLOCK_DEF = B.DEF
local function BGet(s, side, i, f)
    local t = s[K(side, "panelBlocks")]
    local b = t and t[i]
    if b and b[f] ~= nil then return b[f] end
    if f == "src" then return s[K(side, "panelSlot" .. i)] or "NONE" end
    if f == "custom" then return s[K(side, "panelCustom" .. i)] or "" end
    return BLOCK_DEF[f]
end
local function BSet(s, side, i, f, v)
    local key = K(side, "panelBlocks")
    s[key] = s[key] or {}
    s[key][i] = s[key][i] or {}
    s[key][i][f] = v
end
local function Count(s, side) return math.max(1, math.min(MAXN, tonumber(s[K(side, "panelSlots")]) or 3)) end
local function Snap(s, side) local v = s[K(side, "panelSnap")]; return (v == "TOP" or v == "BOTTOM") and v or "CHAT" end
local function ChatSide(s, side)
    local v = s[K(side, "panelChatSide")]
    if v == "TOP" or v == "BOTTOM" or v == "LEFT" or v == "RIGHT" then return v end
    return s[K(side, "panelAnchor")] == "ABOVE" and "TOP" or "BOTTOM"
end
local function Match(s, side)
    local v = s[K(side, "panelMatch")]
    if v ~= nil then return v and true or false end
    return s[K(side, "panelWidthMode")] ~= "CUSTOM"
end
local function Vert(s, side)    -- a bar standing beside the chat window: blocks are stacked top to bottom
    if Snap(s, side) ~= "CHAT" then return false end
    local c = ChatSide(s, side)
    return c == "LEFT" or c == "RIGHT"
end
-- the chat edit box normally sits just outside the chat window (Blizzard: below it; ABOVE_CHAT: above it). A bar on the same side
-- would be covered by it, so the bar can move out past it. Returns the edit box's height in UIParent units, or 0.
local function EditExtra(s, side, cf, cs)
    if s[K(side, "panelClearEdit")] == false or not cf then return 0 end
    local below = s.editBoxPosition ~= "ABOVE_CHAT"
    if not ((cs == "BOTTOM" and below) or (cs == "TOP" and not below)) then return 0 end
    local eb = cf.editBox or _G[(cf:GetName() or "") .. "EditBox"]
    local h = (eb and eb.GetHeight and eb:GetHeight()) or 0
    if h < 20 then h = 24 end
    local k = 1
    if eb and eb.GetEffectiveScale and UIParent:GetEffectiveScale() > 0 then k = eb:GetEffectiveScale() / UIParent:GetEffectiveScale() end
    return h * k + 3
end

-- how far the main chat's bottom edge has to stay above the screen's bottom so the bar (and the edit box) fit under it
local function Materialize(s, side)    -- copy the older per-slot keys into the block table so moving / removing blocks keeps them
    for i = 1, MAXN do BSet(s, side, i, "src", BGet(s, side, i, "src")); BSet(s, side, i, "custom", BGet(s, side, i, "custom")) end
end

local function Hex(r, g, b) return string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5)) end
local function Val(s, side) return Hex(s[K(side, "panelValueR")], s[K(side, "panelValueG")], s[K(side, "panelValueB")]) end
local function Ramp(v, good, ok, invert)   -- green / yellow / red by threshold
    if invert then return v <= good and "|cff40ff40" or (v <= ok and "|cffffd100" or "|cffff4040") end
    return v >= good and "|cff40ff40" or (v >= ok and "|cffffd100" or "|cffff4040")
end

PROVIDERS.NONE = { text = function() return "" end }
PROVIDERS.TIME = {
    text = function(s, side)
        local h, m
        if s[K(side, "panelLocalTime")] == false and GetGameTime then h, m = GetGameTime() else h, m = tonumber(date("%H")), tonumber(date("%M")) end
        if s[K(side, "panelClock24")] == false then
            local suffix = h >= 12 and "pm" or "am"
            h = h % 12; if h == 0 then h = 12 end
            return ("%d:%02d %s"):format(h, m, suffix)
        end
        return ("%02d:%02d"):format(h, m)
    end,
    tip = function() return "Time", (date("%A %d %B")) end,
}
PROVIDERS.FPS = { text = function(_, _) local f = math.floor((GetFramerate and GetFramerate() or 0) + 0.5); return ("%s%d|r fps"):format(Ramp(f, 60, 30), f) end }
PROVIDERS.LATENCY = {
    text = function()
        local _, _, home, world = GetNetStats()
        local ms = world or home or 0
        return ("%s%d|r ms"):format(Ramp(ms, 60, 150, true), ms)
    end,
    tip = function()
        local _, _, home, world = GetNetStats()
        return "Latency", ("Home: %d ms"):format(home or 0), ("World: %d ms"):format(world or 0)
    end,
}
PROVIDERS.FPSMS = {
    text = function()
        local f = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
        local _, _, home, world = GetNetStats()
        local ms = world or home or 0
        return ("FPS: %s%d|r MS: %s%d|r"):format(Ramp(f, 60, 30), f, Ramp(ms, 60, 150, true), ms)
    end,
    tip = PROVIDERS.LATENCY.tip,
}
PROVIDERS.FRIENDS = {
    text = function(s, side)
        local wow = (C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends()) or 0
        local bn = 0
        if BNGetNumFriends then local _, online = BNGetNumFriends(); bn = online or 0 end
        return ("Friends: %s%d|r"):format(Val(s, side), wow + bn)
    end,
    click = function() if ToggleFriendsFrame then ToggleFriendsFrame(1) end end,
    tip = function()
        local wow = (C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends()) or 0
        local bn = 0
        if BNGetNumFriends then local _, online = BNGetNumFriends(); bn = online or 0 end
        return "Friends online", ("Game friends: %d"):format(wow), ("Battle.net friends: %d"):format(bn)
    end,
}
PROVIDERS.GOLD = {
    text = function()
        local g = math.floor((GetMoney and GetMoney() or 0) / 10000)
        local txt = BreakUpLargeNumbers and BreakUpLargeNumbers(g) or tostring(g)
        return txt .. "|cffffd100g|r"
    end,
    click = function() if ToggleAllBags then ToggleAllBags() end end,
}
PROVIDERS.DURABILITY = {
    text = function()
        local lowest
        for slot = 1, 18 do
            if slot ~= 4 then   -- shirt has none
                local cur, max = GetInventoryItemDurability(slot)
                if cur and max and max > 0 then
                    local pct = cur / max * 100
                    if not lowest or pct < lowest then lowest = pct end
                end
            end
        end
        if not lowest then return "Dur --" end
        return ("Dur %s%d%%|r"):format(Ramp(lowest, 50, 25), math.floor(lowest + 0.5))
    end,
}
PROVIDERS.BAGS = {
    text = function()
        local free, total = 0, 0
        local last = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5
        for bag = 0, last do
            local f, t
            if C_Container and C_Container.GetContainerNumFreeSlots then
                f = C_Container.GetContainerNumFreeSlots(bag)
                t = C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
            end
            free = free + (f or 0); total = total + (t or 0)
        end
        return ("Bags %d/%d"):format(free, total)
    end,
    click = function() if ToggleAllBags then ToggleAllBags() end end,
}
PROVIDERS.ZONE = {
    text = function()
        local z, sub = GetZoneText and GetZoneText() or "", GetSubZoneText and GetSubZoneText() or ""
        if sub ~= "" and sub ~= z then return z .. " - " .. sub end
        return z
    end,
}
PROVIDERS.CUSTOM = { text = function(s, side, i) return BGet(s, side, i, "custom") end }


-- data types: the ones above, plus every type DataPanels.lua registered in ns.DataText (the character stats). DataPanels loads after this
-- file, so ns.DataText is only looked at while the game runs.
local function Prov(key)
    local p = PROVIDERS[key]
    if p then return p end
    local d = ns.DataText and ns.DataText.by and ns.DataText.by[key]
    if not d then return PROVIDERS.NONE end
    p = {
        text = function(s, side, i)
            local cfg = { decimals = 1, clock24 = s[K(side, "panelClock24")], localTime = s[K(side, "panelLocalTime")] }
            local v = d.text(cfg, i)
            if d.label and v ~= "" and s[K(side, "panelLabels")] ~= false then return d.label .. " " .. Val(s, side) .. v .. "|r" end
            return v
        end,
        tip = d.tip and function(s) local t = d.tip({}, 1); return t[1], t[2], t[3] end or nil,
    }
    PROVIDERS[key] = p
    return p
end
local function NameOf(key)
    if NAMES[key] then return NAMES[key] end
    local d = ns.DataText and ns.DataText.by and ns.DataText.by[key]
    return d and ((d.group == "General") and d.name or (d.group .. ": " .. d.name)) or tostring(key)
end
local function TypeList()
    local list = {}
    for _, k in ipairs(ORDER) do list[#list + 1] = { k, NAMES[k] } end
    if ns.DataText and ns.DataText.list then
        for _, d in ipairs(ns.DataText.list) do
            if not NAMES[d.key] and d.group ~= "General" then list[#list + 1] = { d.key, d.group .. ": " .. d.name } end
        end
    end
    return list
end


-- frames ------------------------------------------------------------------------------------------------------------------
local TOGGLE_W = 20
local function OpenWindow() if ns.ChatPanel_ShowWindow then ns.ChatPanel_ShowWindow() end end

local function Over(f)
    if not f then return false end
    if f.IsMouseOver then local ok, v = pcall(f.IsMouseOver, f); if ok then return v and true or false end end
    return MouseIsOver and MouseIsOver(f) and true or false
end

local function WindowOf(side)
    if side == "L" then return _G.ChatFrame1 end
    return ns.ChatPanels_RightWindow and ns.ChatPanels_RightWindow() or nil
end
local function CollapsedOf(side)
    if side == "L" then return ns.ChatDock_IsCollapsed and ns.ChatDock_IsCollapsed() or false end
    return ns.ChatPanels_IsRightCollapsed and ns.ChatPanels_IsRightCollapsed() or false
end
local function ToggleInset(s, side)
    return (s.cpHideToggles and 0 or TOGGLE_W + 2)
end
local function Sizing(s, side) return s[K(side, "panelSizing")] == "AUTO" and "AUTO" or "EVEN" end

local function MakeSlot(side, i)
    local P = panels[side]
    local slot = B.MakeSlot(P.frame)
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:SetScript("OnClick", function(_, b)
        if b == "RightButton" then OpenWindow() return end
        local s = Store(); if not s then return end
        local g = ns.dataPanelDB and ns.dataPanelDB.general
        if g and g.blockCombatClick and InCombatLockdown and InCombatLockdown() then return end   -- shared "block combat click" (Data Panels > General)
        local pr = Prov(BGet(s, side, i, "src"))
        if pr and pr.click then pcall(pr.click) end
    end)
    slot:SetScript("OnEnter", function(self)
        local s = Store(); if not s then return end
        local g = ns.dataPanelDB and ns.dataPanelDB.general
        if g and g.blockCombatHover and InCombatLockdown and InCombatLockdown() then return end   -- shared "block combat hover"
        local key = BGet(s, side, i, "src")
        local pr = Prov(key)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if pr and pr.tip then
            local a, b, c = pr.tip(s)
            GameTooltip:SetText(a or "")
            if b then GameTooltip:AddLine(b, 1, 1, 1) end
            if c then GameTooltip:AddLine(c, 1, 1, 1) end
        else
            GameTooltip:SetText(NameOf(key))
        end
        if pr and pr.click then GameTooltip:AddLine("Click: open", 0.6, 0.6, 0.6) end
        GameTooltip:AddLine("Right-click: panel settings", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    P.slots[i] = slot
    return slot
end

local function EnsureSlots(side, n)
    local P = panels[side]
    if not P.frame then return end
    for i = 1, n do if not P.slots[i] then MakeSlot(side, i) end end
end

local function Layout(side)
    local s, P = Store(), panels[side]
    if not (s and P.frame) then return end
    local n = Count(s, side)
    EnsureSlots(side, n)
    local vert = Vert(s, side)
    local inset = ToggleInset(s, side)
    B.Layout(P.frame, P.slots, {
        n = n, vert = vert, sizing = Sizing(s, side),
        lead = (vert or side == "L") and inset or 0,     -- the toggle button sits at the start (left bar, vertical bar) or at the end (right bar)
        trail = (not vert and side ~= "L") and inset or 0,
        get = function(i, f) return BGet(s, side, i, f) end,
    })
end

local function UpdateText(side)
    local s, P = Store(), panels[side]
    if not (s and P.frame and P.frame:IsShown()) then return end
    local n = Count(s, side)
    EnsureSlots(side, n)
    for i = 1, n do
        local slot = P.slots[i]
        local pr = Prov(BGet(s, side, i, "src"))
        local ok, txt = pcall(pr.text, s, side, i)
        slot.fs:SetText(ok and txt or "?")
    end
    if Sizing(s, side) == "AUTO" then Layout(side) end   -- block widths follow the text
end

local function UpdateToggle(side)
    local s, P = Store(), panels[side]
    if not (s and P.toggle) then return end
    local t = P.toggle
    t:ClearAllPoints()
    if Vert(s, side) then        -- a bar beside the chat: the toggle sits at its top end
        t:SetPoint("TOPLEFT", P.frame, "TOPLEFT", 0, 0); t:SetPoint("TOPRIGHT", P.frame, "TOPRIGHT", 0, 0)
        t:SetHeight(TOGGLE_W)
    elseif side == "L" then
        t:SetPoint("TOPLEFT", P.frame, "TOPLEFT", 0, 0); t:SetPoint("BOTTOMLEFT", P.frame, "BOTTOMLEFT", 0, 0)
        t:SetWidth(TOGGLE_W)
    else
        t:SetPoint("TOPRIGHT", P.frame, "TOPRIGHT", 0, 0); t:SetPoint("BOTTOMRIGHT", P.frame, "BOTTOMRIGHT", 0, 0)
        t:SetWidth(TOGGLE_W)
    end
    t:SetShown(not s.cpHideToggles)
    local collapsed = CollapsedOf(side)
    local out = (side == "L") and "LEFT" or "RIGHT"          -- arrow when the window is showing: it will slide away this way
    local back = (side == "L") and "RIGHT" or "LEFT"
    if t.chevron then t.chevron:SetDir(collapsed and back or out) end
    t:SetAlpha((collapsed and s.cpFadeToggles) and 0.3 or 1)
end

local function Visible(s, side, self)
    local v = s[K(side, "panelVisibility")]
    if not v or v == "ALWAYS" then
        if s[K(side, "panelFadeUntilHover")] then v = "MOUSEOVER" else return true end   -- the older tick box
    end
    if v == "MOUSEOVER" then return Over(self) or Over(WindowOf(side)) end
    local combat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false
    if v == "COMBAT" then return combat end
    if v == "NOCOMBAT" then return not combat end
    return true
end

local function Build(side)
    local P = panels[side]
    if P.frame then return P.frame end
    local f = CreateFrame("Frame", side == "L" and "XayaUIChatPanel" or "XayaUIChatPanelRight", UIParent, "BackdropTemplate")
    P.frame, P.slots = f, {}
    f:SetFrameStrata("LOW"); f:SetFrameLevel(5)
    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function(_, b) if b == "RightButton" then OpenWindow() end end)
    -- toggle button at the outer end: hides / shows that chat window
    if ns.CW then
        local t = ns.CW.Button(f, TOGGLE_W, 20, "", function()
            if side == "L" then ns.ChatDock_SetCollapsed(not CollapsedOf("L"))
            else ns.ChatPanels_SetRightCollapsed(not CollapsedOf("R")) end
        end)
        t.chevron = ns.CW.Chevron(t, 14, "LEFT", 1, 0.82, 0)
        t.chevron.holder:SetPoint("CENTER")
        t:HookScript("OnEnter", function(self) self:SetAlpha(1); GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(CollapsedOf(side) and "Show chat" or "Hide chat"); GameTooltip:Show() end)
        t:HookScript("OnLeave", function() GameTooltip:Hide(); UpdateToggle(side) end)
        P.toggle = t
    end
    local acc, accHover = 0, 0
    f:SetScript("OnUpdate", function(self, dt)
        acc = acc + dt; accHover = accHover + dt
        if acc >= 1 then acc = 0; UpdateText(side) end
        if accHover >= 0.1 then
            accHover = 0
            local s = Store()
            if s then
                local show = Visible(s, side, self)
                local a = show and 1 or 0
                if self:GetAlpha() ~= a then self:SetAlpha(a) end
                local mouseOn = show or (s[K(side, "panelVisibility")] == "MOUSEOVER") or s[K(side, "panelFadeUntilHover")]
                for _, slot in pairs(P.slots) do slot:EnableMouse(mouseOn and true or false) end
            end
        end
    end)
    f:SetScript("OnSizeChanged", function() Layout(side) end)
    return f
end

local function Style(s, side)
    local f, P = panels[side].frame, panels[side]
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(s[K(side, "panelBgR")] or 0, s[K(side, "panelBgG")] or 0, s[K(side, "panelBgB")] or 0,
        s[K(side, "panelBg")] and (s[K(side, "panelBgAlpha")] or 45) / 100 or 0)
    f:SetBackdropBorderColor(s[K(side, "panelBorderR")] or 0, s[K(side, "panelBorderG")] or 0, s[K(side, "panelBorderB")] or 0, s[K(side, "panelBorder")] and 1 or 0)
    local path = (ns.FontPath and ns.FontPath(s.font)) or STANDARD_TEXT_FONT
    local base = math.max(6, math.min(40, tonumber(s[K(side, "panelTextSize")]) or 13))
    EnsureSlots(side, Count(s, side))
    local pp = { size = base, path = path, outline = "OUTLINE", hover = s[K(side, "panelHoverHL")],
        r = s[K(side, "panelTextR")] or 1, g = s[K(side, "panelTextG")] or 1, b = s[K(side, "panelTextB")] or 1 }
    local function get(i, f) return BGet(s, side, i, f) end
    for i = 1, MAXN do
        if P.slots[i] then B.StyleSlot(P.slots[i], i, get, pp) end
    end
end

local function Place(s, side, cf)
    local f = panels[side].frame
    f:ClearAllPoints()
    local thick = math.max(10, tonumber(s[K(side, "panelHeight")]) or 22)
    local gap = tonumber(s[K(side, "panelGap")]) or 2
    local ox, oy = tonumber(s[K(side, "panelOffX")]) or 0, tonumber(s[K(side, "panelOffY")]) or 0
    local len = math.max(40, tonumber(s[K(side, "panelWidth")]) or 400)
    local match = Match(s, side)
    local snap = Snap(s, side)
    if snap ~= "CHAT" then
        -- stuck to the screen edge: no longer follows the chat window
        f:SetPoint(snap, UIParent, snap, ox, oy)
        f:SetSize(match and (UIParent:GetWidth() or 800) or len, thick)
        return
    end
    local cs = ChatSide(s, side)
    if cs == "BOTTOM" then
        local y = -gap + oy - EditExtra(s, side, cf, cs)
        f:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", ox, y)
        if match then f:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", ox, y); f:SetHeight(thick) else f:SetSize(len, thick) end
    elseif cs == "TOP" then
        -- above the window: clear the tab row too
        local tab = _G[(cf:GetName() or "ChatFrame1") .. "Tab"]
        local tabH = (tab and tab:GetHeight() or 24)
        local y = tabH + gap + oy + EditExtra(s, side, cf, cs)
        f:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", ox, y)
        if match then f:SetPoint("BOTTOMRIGHT", cf, "TOPRIGHT", ox, y); f:SetHeight(thick) else f:SetSize(len, thick) end
    elseif cs == "LEFT" then
        f:SetPoint("TOPRIGHT", cf, "TOPLEFT", -gap + ox, oy)
        if match then f:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", -gap + ox, oy); f:SetWidth(thick) else f:SetSize(thick, len) end
    else   -- RIGHT: clear the chat's own side pieces and its collapse button
        local x = gap + (ns.ChatDock_SideExtra and ns.ChatDock_SideExtra(cf) or 0) + (s.dockButton ~= false and 26 or 0) + ox
        f:SetPoint("TOPLEFT", cf, "TOPRIGHT", x, oy)
        if match then f:SetPoint("BOTTOMLEFT", cf, "BOTTOMRIGHT", x, oy); f:SetWidth(thick) else f:SetSize(thick, len) end
    end
end

local function RefreshSide(side)
    local s = Store()
    if not s then return end
    local P = panels[side]
    local cf = WindowOf(side)
    local collapsed = CollapsedOf(side)
    local snapped = Snap(s, side) ~= "CHAT"
    local off = (not s[K(side, "panelOn")]) or ((not cf) and not snapped)
        or (s[K(side, "panelHideWhenCollapsed")] and collapsed)
    if off then
        if P.frame then P.frame:Hide() end
        return
    end
    Build(side); Style(s, side); Place(s, side, cf or UIParent); P.frame:Show()
    Layout(side); UpdateToggle(side); UpdateText(side)
end

-- used by ChatDock: the least distance (UIParent units) the main chat's bottom edge may be from the screen's bottom
function ns.ChatPanel_BottomReserve()
    local s = Store()
    if not (s and s.panelOn and s.panelPushChat ~= false and Snap(s, "L") == "CHAT" and ChatSide(s, "L") == "BOTTOM") then return 0 end
    local thick = math.max(10, tonumber(s.panelHeight) or 22)
    local gap = tonumber(s.panelGap) or 2
    local oy = tonumber(s.panelOffY) or 0
    return math.max(0, thick + gap - oy + EditExtra(s, "L", _G.ChatFrame1, "BOTTOM") + 2)
end

function ns.ChatPanel_Refresh()
    RefreshSide("L"); RefreshSide("R")
    if ns.ChatDock_EnsureRoom then pcall(ns.ChatDock_EnsureRoom) end
    for i = 1, 10 do   -- edit box opacity follows the "nearly opaque" tick boxes
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb and eb.xayaBg and ns.ChatReskin_StyleEditBox then pcall(ns.ChatReskin_StyleEditBox, eb) end
    end
    C_Timer.After(0, function() for _, side in ipairs({ "L", "R" }) do if panels[side].frame and panels[side].frame:IsShown() then Layout(side); UpdateText(side) end end end)
end

-- true when a shown bar asks for a nearly opaque chat edit box (ChatReskin reads this)
function ns.ChatPanel_WantOpaqueEdit()
    local s = Store()
    if not s then return false end
    return (s.panelOn and s.panelOpaqueEdit) or (s.rpanelOn and s.rpanelOpaqueEdit) and true or false
end

-- standalone settings window ----------------------------------------------------------------------------------------------
local editBlock = 1
local function BuildWindow()
    if win then return win end
    local CW = ns.CW
    if not CW then return end
    local f = CW.Window("XayaUIChatPanelWindow", "Chat data panels", 340, 640)
    win = f
    local function S() return Store() or {} end
    local function setv(k) return function(v) local s = Store(); if s then s[K(editSide, k)] = v end; ns.ChatPanel_Refresh() end end
    local function getv(k) return function() return S()[K(editSide, k)] end end
    local function check(label, k, default)
        return CW.Check(label, function() local v = S()[K(editSide, k)]; if v == nil then return default end; return v end, setv(k))
    end
    local function num(label, k, min, max, step) return CW.Number(label, getv(k), setv(k), min, max, step) end
    local function color(label, k)
        return CW.Color(label, function() local s = S(); return s[K(editSide, k .. "R")] or 1, s[K(editSide, k .. "G")] or 1, s[K(editSide, k .. "B")] or 1 end,
            function(r, g, b) local s = Store(); if s then s[K(editSide, k .. "R")], s[K(editSide, k .. "G")], s[K(editSide, k .. "B")] = r, g, b end; ns.ChatPanel_Refresh() end)
    end

    -- block editing helpers: everything below the "Block" header edits the block picked with "Editing block"
    local function EB()
        local n = Count(S(), editSide)
        if editBlock > n then editBlock = n end
        if editBlock < 1 then editBlock = 1 end
        return editBlock
    end
    local function bget(field) return function() return BGet(S(), editSide, EB(), field) end end
    local function bset(field) return function(v) local s = Store(); if s then BSet(s, editSide, EB(), field, v) end; ns.ChatPanel_Refresh() end end
    local function bcheck(label, field) return CW.Check(label, bget(field), function(v) bset(field)(v and true or false) end) end
    local function bnum(label, field, min, max, step) return CW.Number(label, bget(field), bset(field), min, max, step) end
    local function bcolor(label, a, b, c)
        return CW.Color(label, function() local s = S(); local i = EB(); return BGet(s, editSide, i, a), BGet(s, editSide, i, b), BGet(s, editSide, i, c) end,
            function(r, g, bl) local s = Store(); if s then local i = EB(); BSet(s, editSide, i, a, r); BSet(s, editSide, i, b, g); BSet(s, editSide, i, c, bl) end; ns.ChatPanel_Refresh() end)
    end
    local function structure(fn)
        local s = Store(); if not s then return end
        fn(s)
        ns.ChatPanel_Refresh(); f:RefreshAll()
    end

    f:Add(CW.Note("Info bars made of blocks, under or above the chat windows (right-click a bar to open this). Changes apply immediately and are saved. Scroll with the mouse wheel.", 0.7, 0.7, 0.7), 42)
    f:Add(CW.Cycle("Editing", { { "L", "Left panel (main chat)" }, { "R", "Right panel" } }, function() return editSide end,
        function(v) editSide = v; f:RefreshAll() end), 20)
    f:Add(CW.Note("The right panel attaches to the chat window chosen as \"right chat window\" (chat tab > Panels). Without one it stays hidden unless it is snapped to a screen edge.", 0.6, 0.6, 0.6), 42)
    f:Add(check("Show this panel", "panelOn"), 20)

    f:Add(CW.Header("Bar"), 18)
    f:Add(CW.Cycle("Visibility", { { "ALWAYS", "Always" }, { "COMBAT", "In combat" }, { "NOCOMBAT", "Out of combat" }, { "MOUSEOVER", "Mouse over only" } },
        getv("panelVisibility"), setv("panelVisibility")), 20)
    f:Add(CW.Cycle("Block sizing", { { "EVEN", "Even split" }, { "AUTO", "Auto sized" } }, getv("panelSizing"), setv("panelSizing")), 20)
    f:Add(CW.Cycle("Snaps to", { { "CHAT", "The chat window" }, { "TOP", "Top of the screen" }, { "BOTTOM", "Bottom of the screen" } },
        function() return Snap(S(), editSide) end, setv("panelSnap")), 20)
    f:Add(CW.Cycle("Side of the chat window", { { "BOTTOM", "Bottom" }, { "TOP", "Top" }, { "LEFT", "Left" }, { "RIGHT", "Right" } },
        function() return ChatSide(S(), editSide) end, setv("panelChatSide")), 20)
    f:Add(CW.Check("Resize the bar to fit (chat width for top / bottom, chat height for left / right; screen width at a screen edge)",
        function() return Match(S(), editSide) end, function(v) setv("panelMatch")(v and true or false) end), 34)
    f:Add(CW.Note("Left / right bars stack their blocks top to bottom. Off: the bar uses the length below.", 0.6, 0.6, 0.6), 30)
    f:Add(num("Length (when not resized to fit)", "panelWidth", 40, 3000, 5), 20)
    f:Add(num("Thickness (height; width for left / right bars)", "panelHeight", 10, 400, 1), 20)
    f:Add(num("Gap to the chat", "panelGap", -20, 60, 1), 20)
    f:Add(check("Keep the bar clear of the chat edit box", "panelClearEdit", true), 20)
    f:Add(check("Push the chat up if the bar would not fit above the screen bottom (left panel)", "panelPushChat", true), 34)
    f:Add(check("Make the chat edit box nearly opaque while this bar is on", "panelOpaqueEdit", false), 20)
    f:Add(num("Nudge left / right", "panelOffX", -2000, 2000, 1), 20)
    f:Add(num("Nudge down / up", "panelOffY", -2000, 2000, 1), 20, 8)

    f:Add(CW.Header("Look"), 18)
    f:Add(check("Background", "panelBg"), 20)
    f:Add(color("Background color", "panelBg"), 20)
    f:Add(num("Background opacity (%)", "panelBgAlpha", 0, 100, 5), 20)
    f:Add(check("Border", "panelBorder"), 20)
    f:Add(color("Border color", "panelBorder"), 20)
    f:Add(num("Text size", "panelTextSize", 6, 40, 1), 20)
    f:Add(color("Text color", "panelText"), 20)
    f:Add(color("Value color (friends count)", "panelValue"), 20)
    f:Add(check("Highlight the block under the mouse", "panelHoverHL", false), 20, 8)

    f:Add(CW.Header("Blocks"), 18)
    f:Add(num("Number of blocks (1-20)", "panelSlots", 1, MAXN, 1), 20)
    local ov = CreateFrame("Frame")
    ov.fs = ov:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ov.fs:SetPoint("TOPLEFT"); ov.fs:SetPoint("TOPRIGHT"); ov.fs:SetJustifyH("LEFT"); ov.fs:SetJustifyV("TOP")
    function ov:Refresh()
        local s = S(); local n, sel = Count(s, editSide), EB()
        local parts = {}
        for i = 1, n do
            local nm = NameOf(BGet(s, editSide, i, "src"))
            parts[#parts + 1] = (i == sel) and ("|cffffd100[" .. i .. " " .. nm .. "]|r") or (i .. " " .. nm)
        end
        self.fs:SetText(table.concat(parts, "  |  "))
    end
    f:Add(ov, 56)
    f:Add(CW.Number("Editing block", function() return EB() end, function(v) editBlock = v; f:RefreshAll() end, 1, MAXN, 1), 20)
    local values = TypeList()
    f:Add(CW.Cycle("Shows", values, bget("src"), bset("src")), 20)
    f:Add(CW.Text("Custom text (used when the block shows Custom text; color codes work)", bget("custom"), bset("custom")), 40)
    f:Add(bnum("Left gap", "gapL", 0, 200, 1), 20)
    f:Add(bnum("Right gap", "gapR", 0, 200, 1), 20)
    f:Add(bcheck("Fill remaining space (Auto sized bars)", "fill"), 20)
    f:Add(CW.Cycle("Text align", { { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" } }, bget("align"), bset("align")), 20)
    f:Add(bnum("Content scale (%)", "scale", 40, 300, 5), 20)
    f:Add(bcheck("Block background", "bgOn"), 20)
    f:Add(bcolor("Block background color", "bgR", "bgG", "bgB"), 20)
    f:Add(bnum("Block background opacity (%)", "bgA", 0, 100, 5), 20)
    f:Add(bcheck("Own text color for this block", "textOn"), 20)
    f:Add(bcolor("This block's text color", "tR", "tG", "tB"), 20, 8)

    local row = CreateFrame("Frame")
    local bw = 74
    local b1 = CW.Button(row, bw, 20, "Move left", function()
        structure(function(s)
            local i = EB(); if i <= 1 then return end
            Materialize(s, editSide)
            local t = s[K(editSide, "panelBlocks")]; t[i], t[i - 1] = t[i - 1], t[i]; editBlock = i - 1
        end)
    end)
    b1:SetPoint("LEFT", 0, 0)
    local b2 = CW.Button(row, bw, 20, "Move right", function()
        structure(function(s)
            local i, n = EB(), Count(s, editSide); if i >= n then return end
            Materialize(s, editSide)
            local t = s[K(editSide, "panelBlocks")]; t[i], t[i + 1] = t[i + 1], t[i]; editBlock = i + 1
        end)
    end)
    b2:SetPoint("LEFT", b1, "RIGHT", 4, 0)
    local b3 = CW.Button(row, bw, 20, "Add block", function()
        structure(function(s)
            local n = Count(s, editSide); if n >= MAXN then return end
            s[K(editSide, "panelSlots")] = n + 1; editBlock = n + 1
        end)
    end)
    b3:SetPoint("LEFT", b2, "RIGHT", 4, 0)
    local b4 = CW.Button(row, bw, 20, "Remove", function()
        structure(function(s)
            local i, n = EB(), Count(s, editSide); if n <= 1 then return end
            Materialize(s, editSide)
            local t = s[K(editSide, "panelBlocks")]; table.remove(t, i)
            s[K(editSide, "panelSlots")] = n - 1
            if editBlock > n - 1 then editBlock = n - 1 end
        end)
    end)
    b4:SetPoint("LEFT", b3, "RIGHT", 4, 0)
    f:Add(row, 24, 8)

    f:Add(CW.Header("Time and behaviour"), 18)
    f:Add(check("24-hour clock", "panelClock24", true), 20)
    f:Add(check("Time: use this computer's clock (off: realm time)", "panelLocalTime", true), 20)
    f:Add(check("Hide while its chat window is collapsed", "panelHideWhenCollapsed", false), 20)
    f:Add(CW.Check("Hide the toggle buttons (both panels)", function() return S().cpHideToggles end,
        function(v) local s = Store(); if s then s.cpHideToggles = v and true or false end; ns.ChatPanel_Refresh() end), 20)
    f:Add(CW.Check("Fade a toggle button while its chat window is hidden (both panels)", function() return S().cpFadeToggles end,
        function(v) local s = Store(); if s then s.cpFadeToggles = v and true or false end; ns.ChatPanel_Refresh() end), 20, 8)

    f:Add(check("Stat blocks: show the stat name in front of the value", "panelLabels", true), 20, 8)
    f:Add(CW.Note("These bars are attached to the chat windows. The screen data panels (corner panels, top bar, free panels) have their own page.", 0.6, 0.6, 0.6), 30)
    local rowDP = CreateFrame("Frame")
    local openDP = CW.Button(rowDP, 190, 20, "Open the screen data panels", function() if ns.DataPanels_OpenSettings then ns.DataPanels_OpenSettings() end end)
    openDP:SetPoint("LEFT", 0, 0)
    f:Add(rowDP, 24, 8)

    local row2 = CreateFrame("Frame")
    local reset = CW.Button(row2, 170, 20, "Reset this panel's settings", function()
        local s = Store(); if not s then return end
        local pre = (editSide == "R") and "rpanel" or "panel"
        for k, v in pairs(ns.CHAT_DEFAULTS) do if k:sub(1, #pre) == pre and (editSide == "R" or k:sub(1, 6) ~= "rpanel") then s[k] = v end end
        s[K(editSide, "panelBlocks")] = nil
        s[K(editSide, "panelChatSide")], s[K(editSide, "panelMatch")] = nil, nil
        editBlock = 1
        ns.ChatPanel_Refresh(); f:RefreshAll()
    end)
    reset:SetPoint("LEFT", 0, 0)
    f:Add(row2, 24)
    f.OnMoved = function() local s = Store(); if s then local p, _, _, x, y = f:GetPoint(); s.panelWinPos = { p = p, x = x, y = y } end end
    return f
end

function ns.ChatPanel_ShowWindow()
    local f = BuildWindow()
    if not f then return end
    if f:IsShown() then f:Hide() return end
    f:ClearAllPoints()
    local pp = (Store() or {}).panelWinPos
    if pp and pp.p then f:SetPoint(pp.p, UIParent, pp.p, pp.x or 0, pp.y or 0) else f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    f:Show()
end

function ns.ChatPanel_SetOn(v, side)
    local s = Store(); if not s then return end
    s[K(side or "L", "panelOn")] = v and true or false
    ns.ChatPanel_Refresh()
end

-- driver -------------------------------------------------------------------------------------------------------------------
local drv = CreateFrame("Frame")
drv:RegisterEvent("PLAYER_ENTERING_WORLD")
drv:RegisterEvent("UPDATE_CHAT_WINDOWS")
drv:RegisterEvent("FRIENDLIST_UPDATE")
drv:RegisterEvent("BN_FRIEND_INFO_CHANGED")
drv:SetScript("OnEvent", function(_, ev)
    if ev == "PLAYER_ENTERING_WORLD" or ev == "UPDATE_CHAT_WINDOWS" then
        C_Timer.After(0.3, function() if ns.ChatPanels_Refresh then ns.ChatPanels_Refresh() else ns.ChatPanel_Refresh() end end)
    end
end)
