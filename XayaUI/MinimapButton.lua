-------------------------------------------------------------------------------
-- MinimapButton.lua : a minimap button with a quick-access list. Own code. UNTESTED in game.
--   Left-click   opens a small list of buttons: Notes, Settings, Data Panels, Chat panel, Chat privacy cover.
--   Right-click  opens the XayaUI settings window.
--   Drag         moves the button around the minimap edge (unless locked).
-- Which entries the list shows, the position, the size (16 to 48 pixels), and whether the button is shown at all are settings
-- (Settings > Minimap Button). The icon and its dark backing are clipped to a circle with a mask texture so no corner shows outside the ring.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local DEFAULTS = {
    hide = false,            -- the button itself
    locked = false,          -- no dragging
    angle = 215,             -- degrees around the minimap, 0 = right, 90 = top
    radiusOffset = 5,        -- how far outside the minimap's edge the button sits
    size = 31,               -- button width and height in pixels, MIN_SIZE to MAX_SIZE; the ring, icon, and backing scale together
    closeOnClick = true,     -- the list closes after a choice
    entries = {},            -- [key] = false hides that row; a row with no entry here is shown (features add rows: ns.RegisterLauncher)
    iconOverride = "",       -- "" = the built-in icon. Otherwise a file ID (1390944), an icon name (INV_Misc_Note_01), a texture path, or spell:ID
    -- where = nil | "MINIMAP" | "SIDEBAR" | "BOTH" (core 0.6.68; REQUEST-LOG A16 CR-6 / CR-7): the chat sidebar (XayaUI Chat, Improved
    -- Chat) can hold this button. Nothing chosen: the sidebar holds it while the minimap button is turned off (her words: "default to
    -- having sidebar on if minimap is turned off"). Not in DEFAULTS, so nothing is saved until it is chosen.
}
ns.MINIMAP_DEFAULTS = DEFAULTS
local BASE_SIZE, MIN_SIZE, MAX_SIZE = 31, 16, 48   -- BASE_SIZE is the size the ring art was laid out for
ns.MINIMAP_MIN_SIZE, ns.MINIMAP_MAX_SIZE = MIN_SIZE, MAX_SIZE
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- Blizzard's own round alpha mask (the one portraits use)
local DEFAULT_ICON = 1390944   -- the icon of Xaya's 'xayaui' macro (macros-cache.txt, 2026-11-02)

local function DB() return ns.minimapDB end
local Watch   -- (below: the loading-screen event, only while the button is shown)
-- (the saved table and its defaults are made at login whatever the switch: "Show the minimap button" itself lives in it, and the
-- settings page reads it; after the first login the merge adds nothing)
function ns.Minimap_OnDBReady()
    CueRulesDB.minimap = CueRulesDB.minimap or {}
    ns.Merge(CueRulesDB.minimap, DEFAULTS)
    ns.minimapDB = CueRulesDB.minimap
    if not ns.minimapDB.hide then Watch(true) end
end
ns.WhenReady(ns.Minimap_OnDBReady)

-- The quick-access rows come from ns.RegisterLauncher (Modules.lua): each feature adds its own row, so a feature that is switched off
-- leaves no dead button. Row = { key, label, tooltip, action, optional state text, order = n }. Core adds only Settings.
-- FA-12 (core 0.6.67; Xaya 2026-11-07, "1, XayaUI Settings"): it toggles, so the texts say so; the row is named "XayaUI Settings".
ns.RegisterLauncher({ "settings", "XayaUI Settings", "Open or close the XayaUI settings window", function() if ns.ToggleUI then ns.ToggleUI() end end, order = 20 })
local function Shown(db, key) return db.entries[key] ~= false end
-- (core 0.6.49) an entry whose feature is switched off (its available() says false) has no row; read each time the list opens
local function Available(e)
    if type(e.available) ~= "function" then return true end
    local ok, v = pcall(e.available)
    return ok and v ~= false and v ~= nil
end

-- What the override text means: "" -> built-in icon; digits -> a file ID; "spell:ID" -> that spell's icon; a bare name (no slash) ->
-- Interface\Icons\<name>; anything else -> used as a texture path as typed. Returns the texture and a short note for the options page.
function ns.Minimap_ResolveIcon(text)
    local t = tostring(text or ""):gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #t > 200 then t = t:sub(1, 200) end
    if t == "" then return DEFAULT_ICON, "built-in icon" end
    if t:match("^%d+$") then return tonumber(t), "file ID " .. t end
    local sid = t:lower():match("^spell:%s*(%d+)$")
    if sid then
        local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(tonumber(sid))
        if tex then return tex, "icon of spell " .. sid end
        return DEFAULT_ICON, "spell " .. sid .. " has no readable icon: using the built-in icon"
    end
    if not t:find("[\\/]") then return "Interface\\Icons\\" .. t, "icon name " .. t end
    return t, "texture path"
end
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local button, popup
local function ApplyIcon()
    local db = DB(); if not (db and button and button.icon) then return end
    local tex = ns.Minimap_ResolveIcon(db.iconOverride)
    button.icon:SetTexture(tex); button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

-- Size the whole button from db.size: every piece is laid out for BASE_SIZE and multiplied by k, then rounded to whole pixels once
-- here (V27, her answer "Whole-pixel / no float math"): a size such as 24 made 15.48-pixel pieces before.
local function Px(v) return math.floor(v + 0.5) end
local function ApplySize()
    local db = DB(); if not (db and button) then return end
    local sz = math.floor(math.max(MIN_SIZE, math.min(MAX_SIZE, tonumber(db.size) or BASE_SIZE)) + 0.5)
    local k = sz / BASE_SIZE
    local s20, s18, s53, up = Px(20 * k), Px(18 * k), Px(53 * k), Px(k)
    button:SetSize(sz, sz)
    button.bg:SetSize(s20, s20);     button.bg:ClearAllPoints();   button.bg:SetPoint("CENTER", 0, up)
    button.icon:SetSize(s18, s18);   button.icon:ClearAllPoints(); button.icon:SetPoint("CENTER", 0, up)
    button.mask:SetSize(s20, s20);   button.mask:ClearAllPoints(); button.mask:SetPoint("CENTER", 0, up)
    button.border:SetSize(s53, s53)
end
ns.Minimap_ApplySize = ApplySize

local function Place()
    local db = DB(); if not (db and button) then return end
    local m = Minimap
    local w = (m and m.GetWidth and m:GetWidth()) or 140
    local h = (m and m.GetHeight and m:GetHeight()) or w
    local a = math.rad(db.angle or 215)
    local rx, ry = w / 2 + (db.radiusOffset or 5), h / 2 + (db.radiusOffset or 5)
    local x, y = math.cos(a) * rx, math.sin(a) * ry
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then   -- a square minimap: the button rides the square's edge instead of a circle
        local k = math.max(math.abs(x) / rx, math.abs(y) / ry)
        if k > 0 then x, y = x / k, y / k end
    end
    -- (V27 whole pixels) the angle math gives decimals (-61.43, -43.01): rounded once here, where the position is made
    button:ClearAllPoints()
    button:SetPoint("CENTER", m or UIParent, "CENTER", math.floor(x + 0.5), math.floor(y + 0.5))
end

local function ClosePopup() if popup then popup:Hide() end end

local function Visible()
    local db = DB(); local out = {}
    if not db then return out end
    for _, e in ipairs(ns.Launchers()) do if Shown(db, e[1]) and Available(e) then out[#out + 1] = e end end
    return out
end

-- Closing the list (V27, Xaya 2026-11-10, her answer "Hover only, clicks pass": "the minimap menu closes on any click or Esc without
-- catching that click"; REQUEST-LOG SD-35: the full-screen click catcher this replaces took every left and right click on the game
-- world while the list was open). No frame covers the screen: a mouse press anywhere outside the list and outside the button that
-- opened it closes the list, and the press goes on to the game as if the list were not there (GLOBAL_MOUSE_DOWN only reports it,
-- events.md:674). The event is registered only while the list is shown (nothing listens while it is closed). A press on the list's
-- own rows is left to the row; a press on the opening button is left to that button (its click toggles the list closed).
-- Esc: the list is in UISpecialFrames, so the game's own Esc handling closes it (the key is not taken by any XayaUI frame).
local function PopupOnEvent(self)   -- GLOBAL_MOUSE_DOWN, the one event it registers
    if self:IsMouseOver() then return end
    local a = self.anchor
    if a and a.IsMouseOver and a:IsMouseOver() then return end
    ClosePopup()
end
local function BuildPopup()
    if popup then return popup end
    popup = CreateFrame("Frame", "XayaUIMinimapMenu", UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG"); popup:SetClampedToScreen(true)
    popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    popup:SetBackdropColor(0.08, 0.08, 0.08, 0.97); popup:SetBackdropBorderColor(0.2, 0.7, 1, 1)
    popup.rows = {}
    popup:Hide()
    popup:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    popup:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN"); self.anchor = nil end)
    popup:SetScript("OnEvent", PopupOnEvent)
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "XayaUIMinimapMenu") end
    return popup
end

local ROW_H, MENU_W = 22, 190
local function Rebuild()
    local p = BuildPopup()
    local list = Visible()
    for i, e in ipairs(list) do
        local b = p.rows[i]
        if not b then
            b = CreateFrame("Button", nil, p)
            b:SetHeight(ROW_H)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.35)
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); b.fs:SetPoint("LEFT", 8, 0)
            b.state = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.state:SetPoint("RIGHT", -8, 0)
            b:SetScript("OnClick", function(self)
                local db = DB()
                if db and db.closeOnClick then ClosePopup() end
                if self.entry and self.entry[4] then self.entry[4]() end
                if not (db and db.closeOnClick) then self:GetScript("OnShow")(self) end
            end)
            b:SetScript("OnShow", function(self) local st = self.entry and self.entry[5] and self.entry[5](); self.state:SetText(st and ("|cff888888" .. st .. "|r") or "") end)
            b:SetScript("OnEnter", function(self)
                if not self.entry then return end
                ns.Tip.Show(self, "ANCHOR_RIGHT", { self.entry[2], 1, 0.82, 0 }, { { self.entry[3], 1, 1, 1, true } })
            end)
            b:SetScript("OnLeave", function() ns.Tip.Hide() end)
            p.rows[i] = b
        end
        b.entry = e
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 3, -3 - (i - 1) * ROW_H); b:SetPoint("TOPRIGHT", -3, -3 - (i - 1) * ROW_H)
        b.fs:SetText(e[2]); b:Show()
        local st = e[5] and e[5](); b.state:SetText(st and ("|cff888888" .. st .. "|r") or "")
    end
    for i = #list + 1, #p.rows do p.rows[i]:Hide(); p.rows[i].entry = nil end
    p:SetSize(MENU_W, math.max(1, #list) * ROW_H + 6)
    return list
end

local function TogglePopup(anchor)
    anchor = anchor or button
    if popup and popup:IsShown() then ClosePopup() return end
    local list = Rebuild()
    if #list == 0 then if ns.ToggleUI then ns.ToggleUI() end return end
    popup:ClearAllPoints()
    -- open toward the middle of the screen so the list is never cut off
    local cx = anchor:GetCenter() or 0
    local half = (UIParent:GetWidth() or 1024) / 2
    local _, cy = anchor:GetCenter()
    local below = (cy or 0) > ((UIParent:GetHeight() or 768) / 2)
    popup:SetPoint(below and "TOP" or "BOTTOM", anchor, below and "BOTTOM" or "TOP", (cx > half) and -MENU_W / 2 + 10 or MENU_W / 2 - 10, below and -4 or 4)
    popup.anchor = anchor
    popup:Show()
end
-- (core 0.6.68; A16 CR-6 / CR-7) the same list from XayaUI's button in the chat sidebar
function ns.Minimap_TogglePopupAt(anchor) if DB() and anchor then TogglePopup(anchor) end end
function ns.Minimap_Where()
    local db = DB(); if not db then return "MINIMAP" end
    local w = db.where
    if w == "MINIMAP" or w == "SIDEBAR" or w == "BOTH" then return w end
    return db.hide and "SIDEBAR" or "MINIMAP"
end

local function BuildButton()
    if button then return button end
    local b = CreateFrame("Button", "XayaUIMinimapButton", Minimap or UIParent)
    b:SetSize(BASE_SIZE, BASE_SIZE); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp"); b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetSize(20, 20); b.bg:SetPoint("CENTER", 0, 1); b.bg:SetColorTexture(0.06, 0.06, 0.06, 0.9)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(18, 18); b.icon:SetPoint("CENTER", 0, 1)
    b.icon:SetTexture(DEFAULT_ICON); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- ApplyIcon() below swaps in the user's override
    -- one round mask clips both the icon and its dark backing, so no square corner can poke out past the ring (and nothing spills at 48 pixels)
    b.mask = b:CreateMaskTexture()
    b.mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.mask:SetSize(20, 20); b.mask:SetPoint("CENTER", 0, 1)
    b.bg:AddMaskTexture(b.mask); b.icon:AddMaskTexture(b.mask)
    b.border = b:CreateTexture(nil, "OVERLAY"); b.border:SetSize(53, 53); b.border:SetPoint("TOPLEFT")
    b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:SetScript("OnClick", function(_, btn)
        if b.dragging then return end
        if btn == "RightButton" then ClosePopup(); if ns.ToggleUI then ns.ToggleUI() end else TogglePopup() end
    end)
    b:SetScript("OnDragStart", function(self)
        local db = DB(); if not db or db.locked then return end
        self.dragging = true; ClosePopup()
        self:SetScript("OnUpdate", function()
            local m = Minimap; if not (m and m.GetCenter) then return end
            local mx, my = m:GetCenter(); if not mx then return end
            local px, py = GetCursorPosition()
            local sc = (m.GetEffectiveScale and m:GetEffectiveScale()) or 1
            px, py = px / sc, py / sc
            DB().angle = math.floor(math.deg(atan2(py - my, px - mx)) + 0.5) % 360   -- whole degrees, as the slider sets it
            Place()
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        C_Timer.After(0.05, function() self.dragging = false end)   -- the click that ends a drag is not a click
        if ns.Minimap_Changed then ns.Minimap_Changed() end
    end)
    b:SetScript("OnEnter", function(self)
        local db = DB()
        ns.Tip.Show(self, "ANCHOR_LEFT", { "XayaUI", 1, 0.82, 0 }, {
            { "Left-click: quick-access list", 1, 1, 1 },
            { "Right-click: open or close the XayaUI settings", 1, 1, 1 },
            (db and not db.locked) and { "Drag: move around the minimap", 0.6, 0.6, 0.6 } or nil })
    end)
    b:SetScript("OnLeave", function() ns.Tip.Hide() end)
    button = b
    ApplySize(); ApplyIcon()
    return b
end

function ns.Minimap_Refresh()
    local db = DB(); if not db then return end
    if db.hide or db.where == "SIDEBAR" then if button then button:Hide() end; ClosePopup(); Watch(false); ns.Minimap_SidebarChanged() return end
    BuildButton(); ApplySize(); Place(); ApplyIcon(); button:Show()
    if popup and popup:IsShown() then Rebuild() end
    Watch(true)
    ns.Minimap_SidebarChanged()
end
-- the chat sidebar shows or drops XayaUI's button at once (XayaUI Chat provides "chatSidebar" through Modules.lua; nothing without it)
function ns.Minimap_SidebarChanged()
    local sv = ns.Service and ns.Service("chatSidebar")
    if sv and type(sv.Refresh) == "function" then pcall(sv.Refresh) end
end

-- V14 (core 0.6.47; Xaya 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to
-- performance cost / demand in any way"). The button is placed again after every loading screen (PLAYER_ENTERING_WORLD, 0.2 s later,
-- as before), but that event is registered only while "Show the minimap button" is on: saved off, no frame of this file exists;
-- switched off, the event is let go. (docs/reference/api/widgets.md, Frame: RegisterEvent / UnregisterEvent(eventName) -> registered: bool)
local ev, watching = nil, false
Watch = function(on)
    if on == watching then return end
    if on and not ev then
        ev = CreateFrame("Frame")
        ev:SetScript("OnEvent", function() C_Timer.After(0.2, ns.Minimap_Refresh) end)
    end
    watching = on and true or false
    if on then ev:RegisterEvent("PLAYER_ENTERING_WORLD") else ev:UnregisterEvent("PLAYER_ENTERING_WORLD") end
end

-------------------------------------------------------------------------------
-- options: Settings > Minimap Button
-- (bundle 1 round 7, REQUEST-LOG A23 SD-58 / SD-62) The page is built by the settings window (XayaUI_Options/MinimapTab.lua
-- ns.BuildMinimapTab), read only when the window's code loads; this button stays in core (her V34 exception, SD-62). While that page is
-- built it sets ns.Minimap_Changed, which the button's drag calls (above) so the open page shows the new position; nil until then.
-------------------------------------------------------------------------------
ns.Minimap_Changed = nil
