-------------------------------------------------------------------------------
-- CharacterReskin.lua : Character Reskin (XayaUI QoL 0.7.14). Blizzard's character window in XayaUI's look. Own code, Blizzard's frames
-- only. Off by default; while off nothing is created, hooked or changed. Its settings page is the settings window's Blizzard UI Reskin
-- tab > Character Pane (module "reskin"; Xaya 2026-11-05: every reskin in one tab).
-- (QoL 0.7.53, character pane split stage 1) the item level, enchant, gem and full stat list parts are QoL's own (QoL > Character Pane,
-- its own switch) and run with the reskin on or off; the reskin is the look only (FeaturesOn / LookActive below).
--
-- Xaya, 2026-11-04: "also create a QoL Character Reskin option to toggle on or off"; "I want a reskin OF THE CHARACTER MENU AND NOTHING
-- ELSE"; "GIVE ME A PRETTY VERSION OF THE CHARACTER SHEET"; "THIS window needs to look beautiful and CLEAN"; "prettify the character
-- window" (her screenshot: two item-level numbers per slot); "ilvl colored based on ilv tier (track ... AND upgrade tier (color
-- gradient))"; "enchants + gems should show to the side of the character pane". Requirements: docs/plans/STAT-CALCULATOR-REQUIREMENTS-
-- 2026-11-04.md, rows A1-A7 (A6, the wider window, built in QoL 0.7.22 after her /xui debug widthprobe result; A8, the compact stat
-- tooltips, is the Character Toolkit's tooltip lines).
-- Xaya, 2026-11-05 (QoL 0.7.22): "complete the entire character pane issue now and make sure the reskin of the character pane is also
-- solved -- the current invisible background is not good"; "gemstone display is much too small and doesn't show the gem name
-- socketed"; "hovering over the enchant name on the character pane should also allow you to see what the enchant does"; "embellished
-- items should be hoverable so you can read what the embellishment does".
--
-- How (the frames are Blizzard's, live 12.1.5 source, read 2026-11-05: CharacterFrame.xml, PaperDollFrame.xml, and
-- SharedUIPanelTemplates.xml for ButtonFrameTemplate / PortraitFrameBaseTemplate / InsetFrameTemplate / PanelTabButtonTemplate):
--   * Restyle: Blizzard's art is faded (alpha 0) and ours is drawn on its own textures and font strings. Switching off puts every alpha
--     and text colour back. The only size and anchor changes are the wider window's (below), made out of combat only.
--   * Background (QoL 0.7.22): a solid fill in the theme's window colour under the whole window (the stats pane and the wider area
--     too) whenever the reskin is on, at its own "Background opacity" (default 95%, never below 50%). With Clean window off Blizzard's
--     own art is drawn over it; with Clean window on Blizzard's art goes and ours (border, pane fills) is drawn.
--   * Window (Clean window): the frame art (NineSlice, Bg, TopTileStreaks), the portrait, the paper-doll background, the insets' art, the
--     model's backgrounds and inner border, the stats pane's class background, the tab art; then a thin border, the theme's pane colour
--     behind the stats pane, a softer fill behind the model, theme-coloured title and tabs.
--   * Slots: the slot frame art and the bevel go; one item level per slot (ours: the Character Toolkit's slot overlays leave theirs out
--     while this is on; none on the shirt and the tabard; none when another addon's text on the slot shows the same number), coloured
--     by upgrade track and step (CM.TrackColor); beside each slot a block with the enchant, the embellishment and each gem (layout notes
--     at "Slots" below). Every row of the block shows its text on hover.
--   * Wider window (QoL 0.7.22, requirement A6; on by default with the reskin): the room for the blocks between the slot columns and
--     the model (notes at "The wider window" below).
--   * Stat list: the row and header art goes; theme-coloured headers with a thin rule, labels, values and a faint stripe on every other
--     row (where Blizzard shows its own).
--   * Safety (as the Game Menu skin): any error while applying turns the reskin off for the session and gives Blizzard's look back.
-- NOT RUN IN GAME when written: QA E1z6 (and E1z7 for the tooltips; E1z11-E1z13 for QoL 0.7.19; E1z40-E1z44 for QoL 0.7.22).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local QolS = ns.Settings("qol")   -- (QoL 0.7.47, P2 settings seam; QoL 0.7.49, P5: QoL's own XayaUIQoLDB; Modules.lua section 0b)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("qol", "XayaUI_QoL", "XayaUIQoLDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)
local CM = ns.CharModel

-- booleans are switches; numbers are the wider window's extra width (px) and the background's opacity (0.5 - 1)
-- (QoL 0.7.24) extra width 42 px by default (Xaya 2026-11-06: "Push to 380px before stats pane and request feedback confirmation":
-- Blizzard's PANEL_DEFAULT_WIDTH 338 -> 380 without the stats pane, CHARACTERFRAME_EXPANDED_WIDTH 540 -> 582 with it); the setting
-- now reaches 0 (it started at 120); a saved number is kept as it is.
-- (QoL 0.7.31) tallPx: the Extra height (Xaya 2026-11-06: "character pane option should also allow for extra height"; her answer "either
-- one", built as "Spread the slots"; REQUEST-LOG #72-#73), 0 by default: nothing changes until she moves it. statList: the stats pane shows
-- every line of the Stat Calculator's Character Stats (her words #70-#71; her answer "Everything on": every line shown to start with).
local DEFAULTS = { enabled = false, chrome = true, ilvl = true, enchants = true, gems = true, stats = true, wide = true, widePx = 42, bgAlpha = 0.95,
    tallPx = 0, statList = true }
local LIMITS = { widePx = { 0, 300 }, bgAlpha = { 0.5, 1 }, tallPx = { 0, 300 } }
-- the stat list's own choices (QoL 0.7.31; her answer "Show / hide each stat, Order, % / rating / both, Groups and colours"), by Character
-- Stats key: statHide[key] = true (hidden), statOrder[group key] = { stat keys }, statMode[key] = "percent" | "rating" | "both",
-- statName[key] / groupName[group key] = text, statColor[key] / groupColor[group key] = { r, g, b }
local LIST_TABLES = { "statHide", "statOrder", "statMode", "statName", "statColor", "groupName", "groupColor" }
local GOOD, WARN = { 0.5, 1, 0.5, 1 }, { 1, 0.56, 0.25, 1 }   -- the Character Toolkit's good / warn tones
ns.CHARRESKIN_DEFAULTS = DEFAULTS
-- (P5, Xaya PS-53: "Character ui *reskin* is a blizzard change. Functionality changes or enhancements are separate.") The settings are
-- kept in two halves: what only changes the LOOK of Blizzard's character window (LOOK below: the switch, chrome, the stat list's art,
-- background opacity, the wider window, the extra height) in Blizzard Reskin's settings (XayaUIReskinDB.characterReskin), everything
-- this file adds to the window (item level, enchant and gem blocks, the full stat list and how it is organised; PS-54) in QoL's
-- (XayaUIQoLDB.characterReskin). Cfg() gives one table that reads and writes each field in its half. While Blizzard Reskin's settings
-- are not open (XayaUI Blizzard Reskin switched off) the look half is this session's defaults with the switch off: nothing is drawn and
-- nothing is saved for it. (Modules.lua sections 0b / 0c; the split is LEGACY_SPLIT there.)
local ReskinS = ns.Settings("reskin")
local LOOK = ns.SettingsSplitSub("characterReskin")   -- { enabled, chrome, stats, bgAlpha, wide, widePx, widePxTo42, tallPx = true }
local featT, lookT, lookOff, halvesEpoch
local cfg = setmetatable({}, {
    __index = function(_, k) if LOOK[k] then return lookT[k] end return featT[k] end,
    __newindex = function(_, k, v) if LOOK[k] then lookT[k] = v else featT[k] = v end end,
})
local function Halves()
    if halvesEpoch == ns.settingsEpoch and featT and lookT then return end
    local f = QolS.characterReskin
    if type(f) ~= "table" then f = {}; QolS.characterReskin = f end
    local l
    if ns.SettingsReady("reskin") then
        l = ReskinS.characterReskin
        if type(l) ~= "table" then l = {}; ReskinS.characterReskin = l end
    else
        lookOff = lookOff or {}
        l = lookOff
    end
    featT, lookT, halvesEpoch = f, l, ns.settingsEpoch
end
local function Cfg()
    if not ns.SettingsReady("qol") then return nil end
    Halves()
    local c = cfg
    -- (QoL 0.7.27) once per install: QoL 0.7.21-0.7.23 saved their default extra width, 240, into the settings, so the 0.7.24 default
    -- (42: 380 / 582) never reached an install that had run them (Xaya 2026-11-06: "surely this isn't 380px?", REQUEST-LOG #58-#59;
    -- her answer: a saved 240, the old default, becomes 42 once; any other saved number stays; a 240 picked after this stays too)
    if c.widePxTo42 == nil then
        if tonumber(c.widePx) == 240 then c.widePx = 42 end
        c.widePxTo42 = true
    end
    for _, k in ipairs(LIST_TABLES) do if type(c[k]) ~= "table" then c[k] = {} end end
    for k, v in pairs(DEFAULTS) do
        if type(v) == "boolean" then
            if c[k] == nil then c[k] = v end
            c[k] = c[k] == true
        else
            local n, lim = tonumber(c[k]), LIMITS[k]
            if not n or n ~= n then n = v end
            c[k] = math.max(lim[1], math.min(lim[2], n))
        end
    end
    if lookT == lookOff then lookOff.enabled = false end   -- (Blizzard Reskin off: the reskin stays off)
    return c
end
ns.CharReskin_Cfg = Cfg

-- (QoL 0.7.53, character pane split stage 1; fixes C20, the P5 side effect: with XayaUI Blizzard Reskin off the item level, enchant and
-- gem blocks and the full stat list did not show, as they were drawn only while the reskin was on.) Xaya PS-53: "Character ui *reskin*
-- is a blizzard change. Functionality changes or enhancements are separate."; Q5: "the simple character/dressing room UI with the
-- ability to customize stat display overhaul is a qol feature; and just a simple clean ui reskin that serves as the visual base is the
-- reskin". So this file has two parts that run on their own:
--   * the LOOK (the switch `enabled` and chrome, stats, wide, widePx, tallPx, bgAlpha: Blizzard Reskin's half), only while the reskin
--     is on (LookActive);
--   * the FEATURES (ilvl, enchants, gems, statList and the stat list's choices: QoL's half), only while QoL's Character Pane switch is
--     on (`features`, QoL's half; FeatActive), with the reskin on or off, with XayaUI Blizzard Reskin loaded or not.
-- `features` was not a setting before: while it has never been set it takes the Character Reskin switch's value in effect (what decided
-- the features before; a reskin switch saved for the next /reload counts after that reload), so nothing a player sees changes at the update. It is saved only once it is on (or set by the player), so a
-- profile made with every default is unchanged. Where that value is read from: Blizzard Reskin's settings when that addon is on; when
-- it is not loaded (known only after the login), the copy CueRulesDB still keeps from before P5 (ns.SettingsOldValue; INFERENCE: the
-- closest saved value there is, as Blizzard Reskin's own settings cannot be read while it is off).
local loggedIn = false
if ns.AtLogin then ns.AtLogin(function() loggedIn = true end) end
local function FeaturesOn()
    if not ns.SettingsReady("qol") then return false end
    Halves()
    local f = featT.features
    if f == nil then
        local r
        if lookT ~= lookOff then r = ns.SwitchInEffect("reskin.charreskin", lookT.enabled)   -- (as in effect: a switch saved for the next /reload waits for it)
        elseif loggedIn and ns.SettingsOldValue then
            local old = ns.SettingsOldValue("reskin", "characterReskin")
            r = type(old) == "table" and old.enabled or nil
        end
        if r == true then featT.features = true; return true end
        return false
    end
    return f == true
end
ns.CharReskin_FeaturesOn = FeaturesOn

local diag = { applied = false, failed = false, lastError = nil, faded = 0, slots = 0, wide = "off" }
ns.CharReskinDiag = diag

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
-- (QoL 0.7.52, #472) the character window's theme scope: its own theme or colours from Blizzard Reskin > Theme, else the global theme as before
local SCOPE = "reskin.charreskin"
local function TC(class, prop, fb)
    local T = ns.Theme
    if T and T.Col then local ok, c = pcall(T.Col, class, prop, SCOPE, fb); if ok and type(c) == "table" then return c end end
    return fb
end
ns.CharReskin_ThemeCol = TC   -- (tests: the colour every part of the window is painted with)

-- Blizzard regions faded by us, with the alpha they had; and text colours we changed, with the colour they had
local faded, recolored = {}, {}
local function Fade(r)
    if type(r) ~= "table" or type(r.SetAlpha) ~= "function" or faded[r] ~= nil then return end
    local a = r.GetAlpha and r:GetAlpha()
    faded[r] = num(a) and a or 1
    r:SetAlpha(0)
    diag.faded = diag.faded + 1
end
local function Recolor(fs, col)
    if type(fs) ~= "table" or type(fs.SetTextColor) ~= "function" or not col then return end
    if recolored[fs] == nil then
        local r, g, b, a = nil, nil, nil, nil
        if fs.GetTextColor then r, g, b, a = fs:GetTextColor() end
        recolored[fs] = { num(r) and r or 1, num(g) and g or 1, num(b) and b or 1, num(a) and a or 1 }
    end
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
end
local function RestoreAll()
    for r, a in pairs(faded) do pcall(r.SetAlpha, r, a) end
    for fs, c in pairs(recolored) do pcall(fs.SetTextColor, fs, c[1], c[2], c[3], c[4]) end
    faded, recolored, diag.faded = {}, {}, 0
end

-- our own pieces (made once, shown while the reskin is on)
local own = { all = {} }
ns.CharReskinParts = own   -- (for the tests)
local function Own(t) own.all[#own.all + 1] = t; return t end
local function SetOwnShown(on) for _, t in ipairs(own.all) do if t.SetShown then t:SetShown(on) end end end

local Active, Guard   -- (defined in "On / off" below)
local LookActive, FeatActive   -- (QoL 0.7.53, stage 1: the look and the features, each on its own; "On / off" below)
-- (QoL 0.7.53, stage 1) what the drawing code reads: the settings, with each look part (chrome, the stat list's art, the wider window)
-- false while the reskin is off and each feature part (item level, enchants, gems, the full stat list) false while QoL's Character
-- Pane switch is off. Every other field reads through as it is.
local LOOK_PARTS = { chrome = true, stats = true, wide = true }
local FEAT_PARTS = { ilvl = true, enchants = true, gems = true, statList = true }
local eff = setmetatable({}, { __index = function(_, k)
    local v = cfg[k]
    if LOOK_PARTS[k] then return (v and LookActive()) and true or false end
    if FEAT_PARTS[k] then return (v and FeatActive()) and true or false end
    return v
end, __newindex = function() error("the drawing view is read only") end })
local function Eff() if not Cfg() then return nil end return eff end

-------------------------------------------------------------------------------
-- The window
-------------------------------------------------------------------------------
local MODEL_REGIONS = { "CharacterModelFrameBackgroundTopLeft", "CharacterModelFrameBackgroundTopRight", "CharacterModelFrameBackgroundBotLeft",
    "CharacterModelFrameBackgroundBotRight", "CharacterModelFrameBackgroundOverlay", "PaperDollInnerBorderTopLeft", "PaperDollInnerBorderTopRight",
    "PaperDollInnerBorderBottomLeft", "PaperDollInnerBorderBottomRight", "PaperDollInnerBorderLeft", "PaperDollInnerBorderRight",
    "PaperDollInnerBorderTop", "PaperDollInnerBorderBottom", "PaperDollInnerBorderBottom2" }

local function StyleTabs()
    local cf = _G.CharacterFrame
    if not cf then return end
    for i = 1, 3 do
        local tab = _G["CharacterFrameTab" .. i]
        if type(tab) == "table" then
            for _, t in ipairs(type(tab.TabTextures) == "table" and tab.TabTextures or {}) do Fade(t) end
            if not tab.xuiBg and tab.CreateTexture then
                tab.xuiBg = Own(tab:CreateTexture(nil, "BACKGROUND"))
                tab.xuiBg:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, -3)
                tab.xuiBg:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 3)
            end
            if tab.xuiBg then
                local on = cf.selectedTab == i
                local c = TC(on and "xui-tab-selected" or "xui-tab", "bg", on and { 0.22, 0.1, 0.3, 0.9 } or { 0.03, 0.03, 0.03, 0.7 })
                tab.xuiBg:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
                tab.xuiBg:Show()
            end
        end
    end
end

-- (QoL 0.7.22) the solid background, whenever the reskin is on: the theme's window colour (xui-window bg = token windowBg) at the page's
-- "Background opacity", on the window's own BACKGROUND layer at the lowest sublevel, so Blizzard's art (when Clean window is off) and
-- every child frame draw over it. It covers the whole window, the stats pane and the wider area too (all points on the window).
-- Root cause of her "invisible background" (QoL 0.7.14 - 0.7.20): every re-apply (each time the window opened) hid our pieces
-- (SetOwnShown(false)) and the window part never showed its background, border and fill again, while Blizzard's art stayed faded.
-- Each piece is now shown each time it is painted.
local function PaintBackground(c)
    local cf = _G.CharacterFrame
    if type(cf) ~= "table" or not cf.CreateTexture then return end
    if not own.bg then
        own.bg = Own(cf:CreateTexture(nil, "BACKGROUND", nil, -8))
        own.bg:SetAllPoints(cf)
    end
    local bg = TC("xui-window", "bg", { 0.06, 0.06, 0.06, 1 })
    own.bg:SetColorTexture(bg[1], bg[2], bg[3], c.bgAlpha)
    own.bg:Show()
end

local function StyleWindow(c)
    local cf = _G.CharacterFrame
    if type(cf) ~= "table" then return end
    for _, k in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "Background" }) do Fade(cf[k]) end
    for _, inset in ipairs({ cf.Inset, cf.InsetRight }) do
        if type(inset) == "table" then Fade(inset.Bg); Fade(inset.NineSlice) end
    end
    local pane = _G.CharacterStatsPane
    if type(pane) == "table" then Fade(pane.ClassBackground) end
    for _, name in ipairs(MODEL_REGIONS) do Fade(_G[name]) end
    if not own.edges then
        own.edges = {}
        for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0 }, { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
            local e = Own(cf:CreateTexture(nil, "BORDER"))
            e:SetPoint(pts[1], cf, pts[1]); e:SetPoint(pts[2], cf, pts[2])
            if pts[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
            own.edges[i] = e
        end
        if type(cf.Inset) == "table" then
            own.inset = Own(cf:CreateTexture(nil, "BACKGROUND", nil, -7))
            own.inset:SetPoint("TOPLEFT", cf.Inset, "TOPLEFT", 2, -2)
            own.inset:SetPoint("BOTTOMRIGHT", cf.Inset, "BOTTOMRIGHT", -2, 2)
        end
        if type(cf.InsetRight) == "table" then
            own.stats = Own(cf:CreateTexture(nil, "BACKGROUND", nil, -7))
            own.stats:SetPoint("TOPLEFT", cf.InsetRight, "TOPLEFT", 2, -2)
            own.stats:SetPoint("BOTTOMRIGHT", cf.InsetRight, "BOTTOMRIGHT", -2, 2)
        end
    end
    local bc = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
    for _, e in ipairs(own.edges) do e:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 1); e:Show() end
    if own.inset then own.inset:SetColorTexture(1, 1, 1, 0.03); own.inset:Show() end   -- a faint lift behind the model and the slots
    if own.stats then
        local p = TC("xui-pane", "bg", { 0.04, 0.04, 0.04, 1 })
        own.stats:SetColorTexture(p[1], p[2], p[3], c.bgAlpha); own.stats:Show()
    end
    local title = type(cf.TitleContainer) == "table" and cf.TitleContainer.TitleText or _G.CharacterFrameTitleText
    Recolor(title, TC("xui-titlebar", "text", { 1, 0.82, 0, 1 }))
    StyleTabs()
end

-------------------------------------------------------------------------------
-- Slots: one item level, track-coloured; the enchant, the embellishment and the gems beside it
-------------------------------------------------------------------------------
-- Blizzard's layout (live 12.1.5 source, read 2026-11-05: PaperDollFrame.xml, ItemButtonTemplate.xml, ModelSceneControlFrame.xml /
-- .lua, ModelSceneMixin.lua): slot buttons 37 x 37, 4 px apart; the left column ends 7 px before the model scene (231 x 320 at 52, -66),
-- the right column starts 8 px after it; the model's camera buttons (its ControlFrame, TOP -10) are 32 high and 2 + n x (32 - 6) wide
-- for n <= 5 buttons, shown only while the mouse is over the model (ModelSceneMixin:OnEnter / OnLeave); the weapon slots sit at the
-- bottom between the columns; the game's own socket display (11 px sockets, 7 px beside the slot) shows only for Timerunning characters.
-- Our layout (QoL 0.7.22):
--   * beside each slot, toward the model, a block of rows: the enchant (its own name, without the "Enchant <slot> - " every enchant
--     name starts with), the embellishment, then one row per socket: a 16 px icon (12 when the block does not fit otherwise) and the
--     gem's name, or the socket's type when it is empty. The block stays inside its slot's band (the slot plus half the 4 px gap above
--     and below it, so two blocks never overlap), 6 px from the slot;
--   * with the wider window the block ends 4 px before the model scene, so nothing lies over the model or its camera buttons; at
--     Blizzard's width (7-8 px between the columns and the model) it runs toward the middle, over the model's sides, as in QoL 0.7.19;
--   * the weapons' blocks sit under the side columns, beside the weapons; a block never covers the weapon slots and their frame art;
--   * font 10, then 9, then 8 when a block does not fit its band; then each row on one line, cut at a word with "..."; then the gems
--     as icons in one row. Nothing is cut in the middle of a word. Hover a row: its whole text and what it does;
--   * a block that cannot clear the camera buttons (only at Blizzard's width: the head and hands rows) hides while they show.
local LEFT_SLOTS = { HeadSlot = true, NeckSlot = true, ShoulderSlot = true, BackSlot = true, ChestSlot = true, ShirtSlot = true,
    TabardSlot = true, WristSlot = true }
local WEAPON_SLOTS = { MainHandSlot = true, SecondaryHandSlot = true }
local NO_ENCHANT_TEXT = "No enchant"
local NO_EFFECT_TEXT = "Effect text not given by the game."
local FRIZ = "Fonts\\FRIZQT__.TTF"
local GUT = ns.UI_GUTTER or 10
local SLOT_PAD = 2                          -- half the 4 px between two slots: a slot's band reaches this far above and below it
local BLOCK_OFF, MODEL_GAP = 6, 4           -- the block starts 6 px from the slot and ends 4 px before the model scene
local MIN_COL = 40                          -- narrower than this beside the model at Blizzard's width: the 0.7.19 layout, toward the middle
-- (QoL 0.7.24 kept a block beside the model with the wider window on, hiding it when it did not fit; QoL 0.7.28 undoes that, her
-- answer "Over the model": below MIN_COL the block runs toward the middle at any width, see LabelBoxes.)
local ROW_GAP, ICON_GAP, COMPACT_GAP = 1, 3, 2
local ICON_SIZES = { 16, 12 }               -- the gem / socket icon (the game's own socket is 11 px; Xaya: "much too small"; QoL 0.7.24,
                                            -- her answer 2026-11-06: "16 px"; 12 only where a block does not fit at 16)
local CAM_TOP, CAM_H, CAM_W = 10, 32, 2 + 5 * (32 - 6)   -- the camera buttons, all five shown (the widest they get)
local ART_X, ART_TOP, ART_BOTTOM = 10, 8, 9 -- the weapon slots' frame art past the slot (Char-BottomSlot 42 x 53 at -4, 8; side pieces 6-7)
local LABEL_SIZES = { 10, 9, 8 }
local EMPTY_SOCKET_ATLAS = "character-emptysocket"   -- the game's own empty-socket art (PaperDollItemSocketSlotTemplate)
local GEM_COL, EMB_COL, GREY, EFFECT_COL = { 0.92, 0.92, 0.95, 1 }, { 0.55, 0.8, 1, 1 }, { 0.62, 0.62, 0.66, 1 }, { 0, 1, 0, 1 }

local function SlotName(slotID)
    for _, s in ipairs(CM.SLOTS) do if s[1] == slotID then return s[4] end end
end
local function FontPath() return ns.Theme and ns.Theme.FontPath and ns.Theme.FontPath() or FRIZ end
local function SetSize(fs, size, flags)
    if not fs:SetFont(FontPath(), size, flags or "") then fs:SetFont(FRIZ, size, flags or "") end
end
local function Mine(fs) fs.xuiOwn = true; return Own(fs) end

-- live rectangles (the game's coordinates: y grows upward); nil when a frame is not laid out or a value is secret
local function Rect(f)
    if type(f) ~= "table" or type(f.GetLeft) ~= "function" then return nil end
    local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
    local function bad(v) return CM.IsSecret(v) or not num(v) end
    if bad(l) or bad(r) or bad(t) or bad(b) or r <= l or t <= b then return nil end
    return { l = l, r = r, t = t, b = b }
end
local function Overlaps(a, b) return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t end
local function SlotBtn(name) return _G["Character" .. name] end
local function Justify(name) return (name == "MainHandSlot" or not (LEFT_SLOTS[name] or name == "SecondaryHandSlot")) and "RIGHT" or "LEFT" end

-- where the columns, the model, its camera buttons and the weapons are now
local function Geometry()
    local head, hands = Rect(SlotBtn("HeadSlot")), Rect(SlotBtn("HandsSlot"))
    if not (head and hands) then return nil end
    local g = { mid = (head.r + hands.l) / 2, colL = head.l, colR = hands.r }
    local model = Rect(_G.CharacterModelScene)
    if model then
        g.model = model
        local cx = (model.l + model.r) / 2
        g.cam = { l = cx - CAM_W / 2, r = cx + CAM_W / 2, t = model.t - CAM_TOP, b = model.t - CAM_TOP - CAM_H }
    end
    local mh, oh = Rect(SlotBtn("MainHandSlot")), Rect(SlotBtn("SecondaryHandSlot"))
    if mh and oh then
        g.weap = { l = math.min(mh.l, oh.l) - ART_X, r = math.max(mh.r, oh.r) + ART_X, t = math.max(mh.t, oh.t) + ART_TOP, b = math.min(mh.b, oh.b) - ART_BOTTOM }
        local cf = _G.CharacterFrame
        local inset = type(cf) == "table" and Rect(cf.Inset) or nil
        g.bottom = inset and inset.b or (math.min(mh.b, oh.b) - 12)   -- (the Inset's bottom is 12 below the weapons')
        g.leftLast, g.rightLast = Rect(SlotBtn("WristSlot")), Rect(SlotBtn("Trinket1Slot"))
    end
    return g
end

-- the rectangles a slot's block may use, best first
local function LabelBoxes(g, name, r)
    if WEAPON_SLOTS[name] then
        if not g.weap then return {} end
        local box
        if name == "MainHandSlot" then
            box = { l = g.colL, r = g.weap.l - GUT, t = (g.leftLast and g.leftLast.b or g.weap.t) - SLOT_PAD, b = g.bottom + SLOT_PAD }
        else
            box = { l = g.weap.r + GUT, r = g.colR, t = (g.rightLast and g.rightLast.b or g.weap.t) - SLOT_PAD, b = g.bottom + SLOT_PAD }
        end
        return { box }
    end
    local left, m = LEFT_SLOTS[name], g.model
    -- (QoL 0.7.31) with Extra height the slots are further apart: a block may use half the gap above and below its slot (not above the
    -- first slot of a column or below its last)
    local eg = (ns.CharReskin_TallGap and ns.CharReskin_TallGap() or 0) / 2
    local box = { t = r.t + SLOT_PAD + ((name == "HeadSlot" or name == "HandsSlot") and 0 or eg),
        b = r.b - SLOT_PAD - ((name == "WristSlot" or name == "Trinket1Slot") and 0 or eg) }
    -- (QoL 0.7.28; Xaya 2026-11-06 at 0.7.27's 380 px window: "character pane now missing all previous information around gems,
    -- enchangs, embellishments, etc"; her answer "Over the model"; REQUEST-LOG #69 / #71) the 0.7.24 rule that a block never goes over
    -- the model with the wider window on is undone: whenever the room beside the model is narrower than MIN_COL, the block runs toward
    -- the middle, over the model's sides, at any window width (the 0.7.19 layout), so no block is hidden for lack of room
    if left then
        box.l = r.r + BLOCK_OFF
        box.r = (m and m.l - MODEL_GAP - box.l >= MIN_COL) and (m.l - MODEL_GAP) or (g.mid - GUT / 2)
        if box.r - box.l < 1 then return {} end
    else
        box.r = r.l - BLOCK_OFF
        box.l = (m and box.r - (m.r + MODEL_GAP) >= MIN_COL) and (m.r + MODEL_GAP) or (g.mid + GUT / 2)
        if box.r - box.l < 1 then return {} end
    end
    local w = g.weap
    if not (w and Overlaps(box, w)) then return { box } end
    local out = {}
    if box.t - (w.t + 1) >= 8 then out[#out + 1] = { l = box.l, r = box.r, t = box.t, b = w.t + 1 } end   -- above the weapons
    local n = { l = box.l, r = box.r, t = box.t, b = box.b }                                                 -- beside them
    if left then n.r = math.min(n.r, w.l - GUT) else n.l = math.max(n.l, w.r + GUT) end
    if n.r - n.l >= 20 then out[#out + 1] = n end
    return out
end

-- (QoL 0.7.24) every word must fit the width: at the 380 px window the room beside the model is about 18 px, and a word wider than
-- its line would run past it (the game truncates it). GetUnboundedStringWidth() -> width · SecretWhenAnchoringSecret (widgets.md:1463):
-- the text's width on one line, whatever the font string's width. Without it (or a secret answer) the word does not count as fitting.
local function WordsFit(fs, text, w)
    if type(fs.GetUnboundedStringWidth) ~= "function" then return true end
    local ok = true
    for wd in tostring(text):gmatch("%S+") do
        fs:SetText(wd)
        local ww = fs:GetUnboundedStringWidth()
        if CM.IsSecret(ww) or not num(ww) or ww > w + 0.5 then ok = false; break end
    end
    fs:SetText(text)
    return ok
end
local function Measure(fs, text, size, w, words)
    SetSize(fs, size)
    fs:SetWidth(w)
    fs:SetText(text)
    local h = fs:GetStringHeight()
    if CM.IsSecret(h) or not num(h) then return nil end
    if words and not WordsFit(fs, text, w) then return nil end
    return h
end

-- the top edge for a block of height h in box: level with the slot's middle, kept inside the box; moved above or below the camera
-- buttons when there is room. Returns the top and whether the block still meets the camera buttons.
local function PlaceTop(g, box, h, cy)
    local top = math.min(box.t, math.max(box.b + h, cy + h / 2))
    local cam = g.cam
    if not (cam and Overlaps({ l = box.l, r = box.r, t = top, b = top - h }, cam)) then return top, false end
    local below = math.min(top, cam.b - 1)
    if below - h >= box.b then return below, false end
    local above = math.max(top, cam.t + 1 + h)
    if above <= box.t then return above, false end
    return top, true
end

-- rows: a frame that takes the mouse (only the row's own rectangle, never the slot) with its text; socket rows also an icon
local function RowEnter(f)
    local tt, d = _G.GameTooltip, f.tip
    if not (tt and d) then return end
    tt:SetOwner(f, "ANCHOR_RIGHT")
    if d.link and tt.SetHyperlink and pcall(tt.SetHyperlink, tt, d.link) then tt:Show(); return end
    for _, l in ipairs(d) do local c = l[2] or GEM_COL; tt:AddLine(l[1], c[1], c[2], c[3], true) end
    tt:Show()
end
local function RowLeave() if _G.GameTooltip then _G.GameTooltip:Hide() end end
local function NewRow(btn, justify, socket)
    local f = Own(CreateFrame("Frame", nil, btn))
    if f.EnableMouse then f:EnableMouse(true) end
    f:SetScript("OnEnter", RowEnter); f:SetScript("OnLeave", RowLeave)
    local fs = Mine(f:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
    if fs.SetJustifyV then fs:SetJustifyV("TOP") end
    fs:SetJustifyH(justify)
    f.text = fs
    if socket then
        f.bg = f:CreateTexture(nil, "BORDER")
        local atlas = C_Texture and C_Texture.GetAtlasExists and CM.R(C_Texture.GetAtlasExists, EMPTY_SOCKET_ATLAS) == true
        if atlas then f.bg:SetAtlas(EMPTY_SOCKET_ATLAS) else f.bg:SetColorTexture(0.12, 0.12, 0.14, 0.95) end
        f.gem = f:CreateTexture(nil, "ARTWORK")
        f.gem:SetPoint("TOPLEFT", f.bg, "TOPLEFT", 1, -1); f.gem:SetPoint("BOTTOMRIGHT", f.bg, "BOTTOMRIGHT", -1, 1)
    end
    return f
end
local function BlockRows(btn)
    local t = {}
    if btn.xuiEnchantRow then t[#t + 1] = btn.xuiEnchantRow end
    if btn.xuiEmbRow then t[#t + 1] = btn.xuiEmbRow end
    for _, f in ipairs(btn.xuiSockets or {}) do t[#t + 1] = f end
    return t
end
local function ShowRow(f, on)
    f:SetShown(on); f.text:SetShown(on)
    if not on then f.tip = nil; f.text:SetText("") end
end
local function SetBlockAlpha(btn, a) for _, f in ipairs(BlockRows(btn)) do f:SetAlpha(a); f.text:SetAlpha(a) end end

-- one layout try: every row wrapped to the box's width at one font size and icon size; nil when it does not fit the box's height.
-- oneLine: each row cut to one line at a word; compact: the sockets as icons in one row, no names.
local function Fit(box, items, size, S, oneLine, compact)
    local rows, off, sockOff = {}, 0, nil
    if compact then   -- (QoL 0.7.24) the icons in one row must fit the box's width too (they never run over the model)
        local n = 0
        for _, it in ipairs(items) do if it.socket then n = n + 1 end end
        if n > 0 and n * S + (n - 1) * COMPACT_GAP > box.r - box.l + 0.01 then return nil end
    end
    for i, it in ipairs(items) do
        local gap = (i > 1) and ROW_GAP or 0
        if compact and it.socket then
            if not sockOff then sockOff = off + gap; off = sockOff + S end
            rows[i] = { text = "", h = 0, rh = S, w = 0, off = sockOff, compact = true }
        else
            local w = box.r - box.l - (it.socket and (S + ICON_GAP) or 0)
            if w < 12 then return nil end
            local fs, text, h = it.row.text, it.text, 0
            if text ~= "" then
                h = Measure(fs, text, size, w, not oneLine)
                if not h then return nil end
                if oneLine then
                    local one = Measure(fs, "Ag", size, w)
                    if not one then return nil end
                    if h > one + 0.5 or not WordsFit(fs, text, w) then
                        local words, cutOk = {}, false
                        for wd in it.text:gmatch("%S+") do words[#words + 1] = wd end
                        for k = #words - 1, 1, -1 do
                            local cut = table.concat(words, " ", 1, k) .. "..."
                            local hc = Measure(fs, cut, size, w, true)
                            if hc and hc <= one + 0.5 then text, h, cutOk = cut, hc, true; break end
                        end
                        if not cutOk then return nil end
                    end
                end
            end
            local rh = math.max(h, it.socket and S or 0)
            rows[i] = { text = text, h = h, rh = rh, w = w, off = off + gap, cut = text ~= it.text }
            off = off + gap + rh
        end
    end
    if off > box.t - box.b + 0.01 then return nil end
    return { rows = rows, h = off, box = box, size = size, S = S }
end

-- lay one slot's block out: the largest icon and font that fit a box (one that clears the camera buttons first), else cut rows
local function LayoutBlock(btn, name, items)
    btn.xuiLabel = nil
    if #items == 0 then return end
    local g, r = Geometry(), Rect(btn)
    local boxes = (g and r) and LabelBoxes(g, name, r) or {}
    if #boxes == 0 then if not (g and r) then diag.noGeometry = true end; return end   -- not laid out yet: UpdateSlots retries
    local cy = WEAPON_SLOTS[name] and (boxes[1].t + boxes[1].b) / 2 or (r.t + r.b) / 2
    local pick
    local function try(p)
        if not p then return false end
        p.top, p.camHit = PlaceTop(g, p.box, p.h, cy)
        if not p.camHit then pick = p; return true end
        pick = pick or p
        return false
    end
    for _, S in ipairs(ICON_SIZES) do
        for _, size in ipairs(LABEL_SIZES) do
            for _, box in ipairs(boxes) do if try(Fit(box, items, size, S)) then break end end
            if pick and not pick.camHit then break end
        end
        if pick and not pick.camHit then break end
    end
    if not pick then
        local box, S, size = boxes[#boxes], ICON_SIZES[#ICON_SIZES], LABEL_SIZES[#LABEL_SIZES]
        try(Fit(box, items, size, S, true))
        if not pick then try(Fit(box, items, size, S, true, true)) end
        if pick then pick.cut = true end
    end
    if not pick then return end
    local box, S, just = pick.box, pick.S, Justify(name)
    local bw, sockX = box.r - box.l, 0
    for i, it in ipairs(items) do
        local rw, f = pick.rows[i], it.row
        local fs, y = f.text, pick.top - rw.off
        f.tip = it.tip
        f:ClearAllPoints(); fs:ClearAllPoints()
        if rw.compact then
            f:SetSize(S, S)
            if just == "LEFT" then f:SetPoint("TOPLEFT", btn, "TOPLEFT", box.l - r.l + sockX, y - r.t)
            else f:SetPoint("TOPRIGHT", btn, "TOPLEFT", box.r - r.l - sockX, y - r.t) end
            sockX = sockX + S + COMPACT_GAP
            fs:SetText(""); fs:SetWidth(1)
            fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        else
            SetSize(fs, pick.size); fs:SetWidth(rw.w); fs:SetText(rw.text)
            f:SetSize(bw, rw.rh)
            f:SetPoint("TOPLEFT", btn, "TOPLEFT", box.l - r.l, y - r.t)
            local ty = -(rw.rh - rw.h) / 2
            if it.socket then
                if just == "LEFT" then fs:SetPoint("TOPLEFT", f, "TOPLEFT", S + ICON_GAP, ty)
                else fs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(S + ICON_GAP), ty) end
            else
                fs:SetPoint(just == "LEFT" and "TOPLEFT" or "TOPRIGHT", f, just == "LEFT" and "TOPLEFT" or "TOPRIGHT", 0, ty)
            end
        end
        if it.socket then
            f.bg:ClearAllPoints(); f.bg:SetSize(S, S)
            local iy = rw.compact and 0 or -(rw.rh - S) / 2
            f.bg:SetPoint(just == "LEFT" and "TOPLEFT" or "TOPRIGHT", f, just == "LEFT" and "TOPLEFT" or "TOPRIGHT", 0, iy)
            if it.gemID then f.gem:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); f.gem:Show() else f.gem:Hide() end
        end
        local c = it.col
        fs:SetTextColor(c[1], c[2], c[3], 1)
        ShowRow(f, true)
        if rw.compact then fs:Hide() end
    end
    btn.xuiLabel = pick
end

-- the camera buttons show: the blocks that meet them hide until they go (alpha only; nothing else changes)
local function CamShown()
    local m = _G.CharacterModelScene
    local cf = type(m) == "table" and m.ControlFrame or nil
    return (type(cf) == "table" and cf.IsShown and cf:IsShown()) and true or false
end
local function UpdateCamHide()
    local hide = CamShown()
    for _, s in ipairs(CM.SLOTS) do
        local btn = SlotBtn(s[4])
        if type(btn) == "table" then SetBlockAlpha(btn, (hide and btn.xuiLabel and btn.xuiLabel.camHit) and 0 or 1) end
    end
end

-- text on the slot buttons that is not XayaUI's (another addon's item level, for example): each visible font string, two levels deep
local function ScanForeign(btn, fn)
    local function scan(f, depth)
        if type(f) ~= "table" or type(f.GetRegions) ~= "function" then return end
        for _, rg in ipairs({ f:GetRegions() }) do
            if type(rg) == "table" and not rg.xuiOwn and rg.GetObjectType and rg:GetObjectType() == "FontString" and rg.IsVisible and rg:IsVisible() then
                local t = CM.PlainText(rg.GetText and rg:GetText() or nil)
                if t and t ~= "" then fn(t, rg) end
            end
        end
        if depth < 2 and type(f.GetChildren) == "function" then for _, ch in ipairs({ f:GetChildren() }) do scan(ch, depth + 1) end end
    end
    scan(btn, 0)
end
-- (QoL 0.7.22) our item level stays hidden on a slot where another addon's text already shows the same number (her pane: a large
-- purple "334" plus ours); the other addon's text is never touched
local function ShowIlvl(btn)
    local fs, t = btn.xuiIlvl, btn.xuiIlvlText
    if not fs then return end
    local dup = false
    if t and t ~= "" then ScanForeign(btn, function(other) if other == t then dup = true end end) end
    btn.xuiIlvlDup = dup
    fs:SetText(t or "")
    fs:SetShown(t ~= nil and t ~= "" and not dup)
end

local tipCache = {}   -- slot -> what its tooltip says (CM.SlotTip) or false; read only while the enchant part is on
local function EmbCount() local n = 0; for _, t in pairs(tipCache) do if t and t.embellished then n = n + 1 end end; return n end

-- the rows of one slot's block, from the item (each part only while its switch is on)
local function BlockItems(btn, slot, info, tip, c)
    local items = {}
    local just = Justify(SlotName(slot))
    local function row(key)
        if not btn[key] then btn[key] = NewRow(btn, just, false) end
        return btn[key]
    end
    if c.enchants then btn.xuiEnchant = row("xuiEnchantRow").text end
    if not info then return items end
    if c.enchants then
        local tk = ns.CharToolkit_Cfg and ns.CharToolkit_Cfg() or nil
        local slotsWanted = CM.EnchantSlots(tk)
        local ench = tip and tip.enchant
        local it
        if ench then
            -- the hover: the whole line as the game gives it; a stat kit's line is its effect, any other line is a name only
            local lines = { { tip.enchantLine or ench, GOOD } }
            if not ench:find("%d") then lines[2] = { NO_EFFECT_TEXT, GREY } end
            it = { text = CM.ShortEnchant(ench), col = GOOD, tip = lines }
        elseif info.enchanted == false and slotsWanted[slot] then
            it = { text = NO_ENCHANT_TEXT, col = WARN, tip = { { NO_ENCHANT_TEXT, WARN }, { "This slot takes an enchant (Character Toolkit > enchant slots).", GREY } } }
        elseif info.enchanted == true then
            it = { text = "Enchanted", col = GOOD, tip = { { "Enchanted", GOOD }, { NO_EFFECT_TEXT, GREY } } }
        end
        if it then it.row = row("xuiEnchantRow"); items[#items + 1] = it end
        local e = tip and tip.embellished
        if e then
            -- (QoL 0.7.24; Xaya 2026-11-05: "put Embellished - Name: ______ and a line break before the description of the embellishment.
            -- Detect if it is (1/2) or (2/2) embellishments on the character"; 2026-11-06: "pane line says embellished (2/2): name — the
            -- rest goes in tooltip"). The pane line "Embellished (n/limit): <name>"; the hover "Embellished - Name: <name>", then on the
            -- next line the description as the game gives it (the item's Use / Equip / proc lines). <name>: the item's own name from its
            -- link (GetInventoryItemLink); no documented call or tooltip line type names the embellishment itself (CM.SlotTip), so the
            -- name shown is the embellished item's (question to Xaya in the debug log of QoL 0.7.24).
            local n = EmbCount()
            local name = CM.LinkName and CM.LinkName(info.link) or nil
            local lines = { { "Embellished - Name: " .. (name or "?"), EMB_COL } }
            for _, l in ipairs(tip.effects or {}) do lines[#lines + 1] = { l, EFFECT_COL } end
            if #lines == 1 then lines[2] = { NO_EFFECT_TEXT, GREY } end
            local r = row("xuiEmbRow"); btn.xuiEmb = r.text
            local head = e.max and ("Embellished (%d/%d)"):format(n, e.max) or "Embellished"
            items[#items + 1] = { text = head .. ": " .. (name or "?"), col = EMB_COL, tip = lines, row = r }
        end
    end
    if c.gems and info.gems then
        -- one socket type in the item's stat table: its name for an empty socket (the key is also the game's string, "Prismatic Socket")
        local typeName, nTypes = nil, 0
        for k in pairs(info.socketTypes or {}) do nTypes = nTypes + 1; typeName = (type(_G[k]) == "string" and not CM.IsSecret(_G[k])) and _G[k] or nil end
        if nTypes ~= 1 then typeName = nil end
        btn.xuiSockets = btn.xuiSockets or {}
        for i, gd in ipairs(info.gems) do
            btn.xuiSockets[i] = btn.xuiSockets[i] or NewRow(btn, just, true)
            local f, it = btn.xuiSockets[i], nil
            if gd.gemID then
                -- the gem's name in one colour; none yet when the game has not loaded it (icon only; GET_ITEM_INFO_RECEIVED redraws)
                it = { text = gd.name or "", col = GEM_COL, gemID = gd.gemID, icon = gd.icon,
                    tip = gd.link and { link = gd.link } or { { gd.name or "Gem (its name is not loaded yet)", GEM_COL } } }
            else
                local t = typeName or "Empty socket"
                it = { text = t, col = WARN, tip = { { t, WARN }, { "Empty socket.", GREY } } }
            end
            it.socket, it.row = true, f
            items[#items + 1] = it
        end
    end
    return items
end

local function UpdateSlot(btn, c, tips)
    if type(btn) ~= "table" then return end
    local slot = btn.GetID and btn:GetID()
    local name = num(slot) and SlotName(slot)
    if not name then return end
    if c.chrome then Fade(_G["Character" .. name .. "Frame"]); Fade(btn.GetNormalTexture and btn:GetNormalTexture() or nil) end
    -- the item is read only for the parts that are on (V14)
    local info = (c.ilvl or c.enchants or c.gems) and CM.SlotInfo(slot) or nil
    -- item level (none on the shirt and the tabard: theirs is 1)
    if c.ilvl then
        if not btn.xuiIlvl and btn.CreateFontString then
            btn.xuiIlvl = Mine(btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
            btn.xuiIlvl:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
            SetSize(btn.xuiIlvl, 12, "OUTLINE")
        end
        if btn.xuiIlvl then
            if info and info.ilvl and not CM.NO_ILVL[slot] then
                local q = CM.N(GetInventoryItemQuality, "player", slot)
                local col, track = CM.TrackColor(info.link, q)
                btn.xuiIlvlText = tostring(math.floor(info.ilvl + 0.5))
                col = col or { 1, 1, 1, 1 }
                btn.xuiIlvl:SetTextColor(col[1], col[2], col[3], 1)
                btn.xuiTrack = track
            else
                btn.xuiIlvlText, btn.xuiTrack = nil, nil
            end
            ShowIlvl(btn)
        end
    elseif btn.xuiIlvl then btn.xuiIlvl:Hide() end
    -- the block beside the slot: enchant, embellishment, gems (LayoutBlock)
    local tip
    if c.enchants then
        if tips then tip = tips[slot] or nil else tip = info and CM.SlotTip(slot) or nil end
        tipCache[slot] = tip or false
    end
    for _, f in ipairs(BlockRows(btn)) do ShowRow(f, false) end
    if c.enchants or c.gems then
        local items = BlockItems(btn, slot, info, tip, c)
        LayoutBlock(btn, name, items)
        SetBlockAlpha(btn, (btn.xuiLabel and btn.xuiLabel.camHit and CamShown()) and 0 or 1)
    else btn.xuiLabel = nil end
end

local retries = 0
local dupPending = false
local function RecheckDup()
    dupPending = false
    local c = Eff()
    if not (Active() and c.ilvl) then return end
    local n = 0
    for _, s in ipairs(CM.SLOTS) do
        local b = SlotBtn(s[4])
        if type(b) == "table" and b.xuiIlvl then ShowIlvl(b); if b.xuiIlvlDup then n = n + 1 end end
    end
    diag.dupes = n
end
-- another addon may write its text after ours: look again on the next frame (once per frame at most; only while the item level is on)
local function QueueDupCheck(c)
    if dupPending or not (c and c.ilvl) or not (C_Timer and C_Timer.After) then return end
    dupPending = true
    C_Timer.After(0, function() if Active() then Guard(RecheckDup) else dupPending = false end end)
end

-- (QoL 0.7.33; Insivius via Xaya: "Text breaks if you make the window wider and then bring it back down"; her answer "Fix + diagnostic",
-- REQUEST-LOG UI-4.) In the test stand-in a widen (120, 300 px) and back to 42 gives exactly the same blocks, so the layout keeps no state
-- between widths. INFERENCE, not seen in the game: right after the window's width or height changes, the live client may still report
-- the old positions to GetLeft / GetRight in that same moment, so the blocks are sized for the wider window. So whenever the window's size
-- is changed (here or by Blizzard's UpdateSize), the slots are laid out once more on the next frame, and /xui reskin status says whether the positions the
-- two passes read differed (that answer settles the inference). Runs only while the reskin and a slot part are on (V14: nothing while off).
local relayout = { pending = false }
local function GeoKey(g)
    if not g then return nil end
    return { g.colL, g.colR, g.mid, g.model and g.model.l or 0, g.model and g.model.r or 0, g.weap and g.weap.l or 0, g.weap and g.weap.r or 0 }
end
local function MaxDiff(a, b)
    if not (a and b) then return nil end
    local d = 0
    for i = 1, #a do d = math.max(d, math.abs((a[i] or 0) - (b[i] or 0))) end
    return d
end
local UpdateSlots
local function QueueRelayout(c)
    if not relayout.want then return end
    if relayout.pending or not (c and (c.enchants or c.gems)) or not (C_Timer and C_Timer.After) then return end
    relayout.want, relayout.pending = false, true
    local before = GeoKey(Geometry())
    C_Timer.After(0, function()
        relayout.pending = false
        if not Active() then return end
        local d = MaxDiff(before, GeoKey(Geometry()))
        if not d then diag.relayout = "the window's size changed; positions not readable in one of the two passes"
        elseif d > 0.5 then diag.relayout = ("the window's size changed; the positions read right after it differed by %.1f px from the next frame's: laid out again"):format(d)
        else diag.relayout = "the window's size changed; the same positions in both passes (laid out again anyway)" end
        local c2 = Eff()
        if c2 and (c2.enchants or c2.gems) then Guard(UpdateSlots, c2) end
    end)
end
-- the window's width or height was changed by this file or by Blizzard's UpdateSize: the next slot layout queues a second pass
local function SizeChanged() relayout.want = true end

UpdateSlots = function(c)
    local n, labels, cut, cam, socks = 0, 0, 0, 0, 0
    diag.noGeometry = false
    -- every equipped item's tooltip first (the embellishment line counts them), only while the enchant part is on
    local tips = nil
    if c.enchants then
        tips = {}
        tipCache = {}
        for _, s in ipairs(CM.SLOTS) do
            local t = CM.SlotTip(s[1])
            if t and CM.R(GetInventoryItemLink, "player", s[1]) then tips[s[1]] = t; tipCache[s[1]] = t end
        end
    end
    for _, s in ipairs(CM.SLOTS) do
        local btn = SlotBtn(s[4])
        if type(btn) == "table" then
            UpdateSlot(btn, c, tips); n = n + 1
            local L = btn.xuiLabel
            if L then labels = labels + 1; if L.cut then cut = cut + 1 end; if L.camHit then cam = cam + 1 end end
            if c.gems then for _, f in ipairs(btn.xuiSockets or {}) do if f:IsShown() then socks = socks + 1 end end end
        end
    end
    diag.slots, diag.labels, diag.cut, diag.camHit, diag.sockets = n, labels, cut, cam, socks
    diag.embellished = c.enchants and EmbCount() or 0
    QueueDupCheck(c)
    -- the window is open but its slots had no position yet (INFERENCE: possible in the frame it opens): try again next frame, 3 times at most
    local cf = _G.CharacterFrame
    if diag.noGeometry and retries < 3 and C_Timer and C_Timer.After and type(cf) == "table" and cf.IsShown and cf:IsShown() then
        retries = retries + 1
        C_Timer.After(0, function() local c2 = Eff(); if Active() and (c2.enchants or c2.gems) then Guard(UpdateSlots, c2) end end)
    elseif not diag.noGeometry then retries = 0 end
    QueueRelayout(c)
end

-- for /xui reskin status
local function OtherText()
    local found = {}
    for _, s in ipairs(CM.SLOTS) do
        ScanForeign(SlotBtn(s[4]), function(t, rg) found[#found + 1] = ("%s %s (%s)"):format(s[3], t, tostring(rg.GetDebugName and rg:GetDebugName() or "?")) end)
    end
    return found
end

-------------------------------------------------------------------------------
-- The wider window (QoL 0.7.22, requirement A6; Xaya's in-game /xui debug widthprobe of 2026-11-05: "width probe: on, 120 px wider (540
-- -> 660). window width ok, inset edge ok, model width ok, main hand slot ok, panel placement ok", no ADDON_ACTION line)
-------------------------------------------------------------------------------
-- The same calls the probe made (CharacterWidthProbe.lua), out of combat only, with the character window open on its Character tab:
--   CharacterFrame:SetWidth(Blizzard's width + px); the Inset's BOTTOMRIGHT at the window's BOTTOMLEFT + (PANEL_DEFAULT_WIDTH +
--   PANEL_INSET_RIGHT_OFFSET + px, PANEL_INSET_BOTTOM_OFFSET) (the right slot column and the stats pane hang from the Inset, so they
--   move out); UpdateUIPanelPositions(CharacterFrame) (as Blizzard's UpdateSize does when the width changed).
-- Different from the probe: the model scene keeps its width (231) and moves right by px / 2, so it stays whole and centred and the
-- added room is between each slot column and the model; the main hand slot moves right by px / 2 as in the probe.
-- Widget calls (widgets.md): SetWidth(width: uiUnit) · IsProtectedFunction (:314); GetNumPoints() → numPoints (:150);
-- GetPointByName(point: FramePoint, resolveCollapsed: bool = false) → point, relativeTo, relativePoint, offsetX, offsetY ·
-- ConstSecretAccessor, MayReturnNothing, SecretWhenAnchoringSecret (:158); IsProtected() → isProtected, isProtectedExplicitly ·
-- SecretReturnsForAspect=[ObjectSecurity] (:221). The model's and the main hand's anchors are Blizzard's (PaperDollFrame.xml: the model
-- TOPLEFT 52, -66; the main hand BOTTOMLEFT 130, 16), read once before anything moves; a frame with another number of anchors, or one
-- that says it is protected (or a secret answer), is left alone and the window stays at Blizzard's width (fail safe).
-- Blizzard's own CharacterFrame:UpdateSize (on opening, switching tabs, opening or closing the stats pane) puts its width back; a
-- post-hook (hooksecurefunc on the window's UpdateSize, placed only once the wider window is first on) widens it again on the
-- Character tab. INFERENCE (not in the files read): CharacterFrame.activeSubframe names the shown tab's frame; when it is not a string,
-- PaperDollFrame:IsShown() decides. In combat nothing of the window is changed: when Blizzard put its width back in combat, the model
-- and the main hand go back to Blizzard's places (they are not protected frames: checked with IsProtected), and the window widens
-- again when combat ends (PLAYER_REGEN_ENABLED, events.md:1207, registered only while that waits).
local wide = { applied = false, moved = false, hooked = false }
ns.CharReskinWide = wide   -- (for the tests)
local function NotProtected(f)
    if type(f) ~= "table" or type(f.IsProtected) ~= "function" then return true end
    local p = f:IsProtected()
    if CM.IsSecret(p) then return false end
    return not p
end
local function PointOf(f, point)
    if type(f) ~= "table" or type(f.GetNumPoints) ~= "function" or type(f.GetPointByName) ~= "function" then return nil end
    local n = f:GetNumPoints()
    if CM.IsSecret(n) or n ~= 1 then return nil end
    local p, rel, rp, x, y = f:GetPointByName(point)
    if p ~= point or CM.IsSecret(x) or CM.IsSecret(y) or not num(x) or not num(y) then return nil end
    return { p, rel, rp, x, y }
end
local function WideFrames()
    local cf, m, mh = _G.CharacterFrame, _G.CharacterModelScene, _G.CharacterMainHandSlot
    local DW, RO, BO = _G.PANEL_DEFAULT_WIDTH, _G.PANEL_INSET_RIGHT_OFFSET, _G.PANEL_INSET_BOTTOM_OFFSET
    if not (type(cf) == "table" and type(cf.Inset) == "table" and cf.Inset.SetPoint and type(m) == "table" and type(mh) == "table"
        and num(DW) and num(RO) and num(BO)) then return nil end
    return cf, m, mh, DW, RO, BO
end
local function OnCharacterTab(cf)
    local sub = cf.activeSubframe
    if type(sub) == "string" then return sub == "PaperDollFrame" end
    local pd = _G.PaperDollFrame
    return (type(pd) == "table" and pd.IsShown and pd:IsShown()) and true or false
end
local function InCombat() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function PutBack(m, mh)
    if wide.mp and NotProtected(m) then m:ClearAllPoints(); m:SetPoint(wide.mp[1], wide.mp[2], wide.mp[3], wide.mp[4], wide.mp[5]) end
    if wide.hp and NotProtected(mh) then mh:ClearAllPoints(); mh:SetPoint(wide.hp[1], wide.hp[2], wide.hp[3], wide.hp[4], wide.hp[5]) end
    wide.moved = false
end

local WideRegen
local function WaitForCombatEnd(on)
    if on then
        wide.ev = wide.ev or CreateFrame("Frame")
        wide.ev:SetScript("OnEvent", WideRegen)
        wide.ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    elseif wide.ev then wide.ev:UnregisterAllEvents() end
    wide.pending = on or nil
end

-- The extra height (QoL 0.7.31; Xaya 2026-11-06: "character pane option should also allow for extra height"; her answer "either one", built
-- as "Spread the slots"; REQUEST-LOG #72-#73). With the wider window on and Extra height above 0, out of combat only (as the width): the
-- window is that much taller (CharacterFrame:SetHeight, widgets.md SetHeight(height: uiUnit)); each slot of the two columns after the
-- first hangs from the one above it (PaperDollFrame.xml: TOPLEFT of the slot above's BOTTOMLEFT, 0, -4), so each of the 7 gaps of a
-- column grows by px / 7 and the columns spread evenly over the added height; the model scene is px taller (its width stays: the game
-- fits the character inside it, INFERENCE); the weapon row hangs from the bottom (BOTTOMLEFT 130, 16), so it moves down with the window.
-- A slot anchored otherwise, or a protected frame (or a secret answer), is left alone and nothing of the height changes (fail safe).
-- 0 gives Blizzard's layout exactly (every anchor and size put back).
local TALL_COLS = { { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" },
    { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" } }
local tall = { applied = false, gap = 0 }
ns.CharReskinTall = tall   -- (for the tests)
function ns.CharReskin_TallGap() return tall.applied and tall.gap or 0 end
local function TallAnchors()
    if tall.pts then return tall.pts end
    local pts = {}
    for _, col in ipairs(TALL_COLS) do
        for i = 2, #col do
            local b, prev = _G["Character" .. col[i]], _G["Character" .. col[i - 1]]
            local pt = PointOf(b, "TOPLEFT")
            if not (pt and pt[2] == prev and pt[3] == "BOTTOMLEFT" and NotProtected(b)) then return nil end
            pts[col[i]] = pt
        end
    end
    tall.pts = pts
    return pts
end
local function RestoreTall()
    if not tall.applied then return end
    local cf, m = _G.CharacterFrame, _G.CharacterModelScene
    for name, pt in pairs(tall.pts or {}) do
        local b = _G["Character" .. name]
        if type(b) == "table" and NotProtected(b) then b:ClearAllPoints(); b:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
    end
    if tall.baseH and type(cf) == "table" then cf:SetHeight(tall.baseH) end
    if tall.modelH and type(m) == "table" and m.SetHeight then m:SetHeight(tall.modelH) end
    tall.applied, tall.gap, tall.px = false, 0, 0
    SizeChanged()
end
local function ApplyTall(c, cf, m)
    local px = (c and c.tallPx) or 0
    if px <= 0 then RestoreTall(); diag.tall = "off (0)"; return end
    local pts = TallAnchors()
    if not (pts and NotProtected(cf) and NotProtected(m)) then diag.tall = "the slots are anchored differently or protected: Blizzard's height"; return end
    if not tall.applied then
        local h, mh = cf:GetHeight(), m:GetHeight()
        if CM.IsSecret(h) or CM.IsSecret(mh) or not num(h) or not num(mh) then return end
        tall.baseH, tall.modelH = h, mh
    end
    local gap = px / 7
    for name, pt in pairs(pts) do
        local b = _G["Character" .. name]
        b:ClearAllPoints(); b:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5] - gap)
    end
    cf:SetHeight(tall.baseH + px)
    m:SetHeight(tall.modelH + px)
    if tall.px ~= px or not tall.applied then SizeChanged() end
    tall.applied, tall.gap, tall.px = true, gap, px
    diag.tall = ("on, %d px taller (%d -> %d); each gap between two slots %.1f px wider"):format(px, math.floor(tall.baseH + 0.5), math.floor(tall.baseH + px + 0.5), gap)
end

local function RestoreWide()
    if not (wide.applied or wide.moved or tall.applied) then return end
    local cf, m, mh = WideFrames()
    if not cf then wide.applied, wide.moved = false, false; return end
    if InCombat() then WaitForCombatEnd(true); return end
    PutBack(m, mh)
    RestoreTall()
    wide.applied = false
    SizeChanged()
    -- Blizzard's own sizing puts the width and the Inset back (as the probe's "off"); without it, the width the window had before
    if ns.MapTrace then ns.MapTrace("Character Reskin: CharacterFrame:UpdateSize (wider window off)") end
    if type(cf.UpdateSize) == "function" then pcall(cf.UpdateSize, cf)
    else
        local DW, RO, BO = _G.PANEL_DEFAULT_WIDTH, _G.PANEL_INSET_RIGHT_OFFSET, _G.PANEL_INSET_BOTTOM_OFFSET
        if wide.base then cf:SetWidth(wide.base) end
        cf.Inset:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", DW + RO, BO)
        if type(UpdateUIPanelPositions) == "function" then pcall(UpdateUIPanelPositions, cf) end
    end
    diag.wide = "off"
end

local HookWide
local function ApplyWide(c)
    if not (c and Active() and c.wide) then RestoreWide(); return end
    local cf, m, mh, DW, RO, BO = WideFrames()
    if not cf then diag.wide = "the game's character window is not built as expected: Blizzard's width"; return end
    HookWide()
    if not (cf.IsShown and cf:IsShown() and OnCharacterTab(cf)) then return end   -- (another tab: Blizzard's width; the model is hidden)
    local w = cf:GetWidth()
    if CM.IsSecret(w) or not num(w) then return end
    local reset = wide.reset or not wide.applied or math.abs(w - (wide.setW or -1)) > 0.5
    wide.reset = false
    if InCombat() then
        if reset then
            if wide.moved then PutBack(m, mh) end
            wide.applied = false
            WaitForCombatEnd(true)
            diag.wide = "waits for the end of combat"
        elseif wide.px ~= c.widePx or (tall.applied and tall.px or 0) ~= (c.tallPx or 0) then
            WaitForCombatEnd(true)   -- (QoL 0.7.31) a width or height set in combat: applied when the fight ends
            diag.tall = "waits for the end of combat"
        end
        return
    end
    if not (NotProtected(cf) and NotProtected(m) and NotProtected(mh)) then diag.wide = "a frame is protected: Blizzard's width"; return end
    wide.mp = wide.mp or PointOf(m, "TOPLEFT")
    wide.hp = wide.hp or PointOf(mh, "BOTTOMLEFT")
    if not (wide.mp and wide.hp) then diag.wide = "the model or the main hand is anchored differently: Blizzard's width"; return end
    local px = c.widePx
    local half = math.floor(px / 2)
    local base = reset and w or wide.base
    local changed = reset or wide.px ~= px
    if changed then cf:SetWidth(base + px); SizeChanged() end
    cf.Inset:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", DW + RO + px, BO)
    m:ClearAllPoints(); m:SetPoint(wide.mp[1], wide.mp[2], wide.mp[3], wide.mp[4] + half, wide.mp[5])
    mh:ClearAllPoints(); mh:SetPoint(wide.hp[1], wide.hp[2], wide.hp[3], wide.hp[4] + half, wide.hp[5])
    wide.applied, wide.moved, wide.base, wide.px, wide.setW = true, true, base, px, base + px
    if changed and type(UpdateUIPanelPositions) == "function" then
        if ns.MapTrace then ns.MapTrace("Character Reskin: UpdateUIPanelPositions(CharacterFrame) (wider window)") end
        pcall(UpdateUIPanelPositions, cf)
    end
    diag.wide = ("on, %d px wider (%d -> %d)"):format(px, math.floor(base + 0.5), math.floor(base + px + 0.5))
    ApplyTall(c, cf, m)
end

local function WideAndSlots()
    local c = Eff()
    ApplyWide(c)
    if Active() and (c.ilvl or c.enchants or c.gems) then UpdateSlots(c) end
end
WideRegen = function()
    WaitForCombatEnd(false)
    local c = Eff()
    if c and Active() and c.wide then Guard(WideAndSlots) else pcall(RestoreWide) end
end
HookWide = function()
    if wide.hooked then return end
    wide.hooked = true
    local cf, pd = _G.CharacterFrame, _G.PaperDollFrame
    -- post-hooks; they return at once while the reskin or the wider window is off (a /reload removes them)
    if type(hooksecurefunc) == "function" and type(cf.UpdateSize) == "function" then
        hooksecurefunc(cf, "UpdateSize", function()
            if ns.MapTrace then ns.MapTrace("Character Reskin: hook after CharacterFrame:UpdateSize") end
            wide.reset = true
            SizeChanged()
            local c = Eff()
            if c and Active() and c.wide then Guard(WideAndSlots) end
        end)
    end
    if type(pd) == "table" and pd.HookScript then
        pd:HookScript("OnShow", function() local c = Eff(); if c and Active() and c.wide then Guard(WideAndSlots) end end)
    end
end
function ns.CharReskin_WideOn() return (wide.applied or wide.moved) and true or false end
-- (QoL 0.7.33) XayaUI Dev Assist's /xui debug widthprobe asks this (it refuses while the wider window is on), through the service list
-- (QoL 0.7.53, character pane split stage 1) read-only answers for XayaUI Dev Assist's walkthrough (QAWalks-character-split.lua): what is
-- drawn on the character window now, counted from our own pieces
ns.Provide("characterReskin", { WideOn = function() return ns.CharReskin_WideOn() end,
    Drawn = function()
        local il, en, so = 0, 0, 0
        for _, s in ipairs(CM.SLOTS) do
            local b = _G["Character" .. s[4]]
            if type(b) == "table" then
                if b.xuiIlvl and b.xuiIlvl.IsShown and b.xuiIlvl:IsShown() then il = il + 1 end
                if b.xuiEnchant and b.xuiEnchant.IsShown and b.xuiEnchant:IsShown() then en = en + 1 end
                for _, f in ipairs(b.xuiSockets or {}) do if f.IsShown and f:IsShown() then so = so + 1 end end
            end
        end
        local L = own.statList
        return { ilvl = il, enchants = en, sockets = so, statList = (L ~= nil and L:IsShown()) and true or false,
            look = LookActive() == true, features = FeatActive() == true, featuresSaved = (Cfg() or {}).features,
            reskinLoaded = ns.SettingsReady("reskin"), tabOn = ns.ReskinTabOn() == true, faded = diag.faded or 0 }
    end })

-------------------------------------------------------------------------------
-- The stat list (Blizzard's CharacterStatsPane)
-------------------------------------------------------------------------------
local function StyleStats()
    local pane = _G.CharacterStatsPane
    if type(pane) ~= "table" then return end
    local label = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    local muted = TC("xui-text-muted", "text", { 0.75, 0.75, 0.8, 1 })
    local text = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local line = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
    for _, k in ipairs({ "ItemLevelCategory", "AttributesCategory", "EnhancementsCategory" }) do
        local cat = pane[k]
        if type(cat) == "table" then
            Fade(cat.Background)
            Recolor(cat.Title, label)
            if not cat.xuiRule and cat.CreateTexture then
                cat.xuiRule = Own(cat:CreateTexture(nil, "ARTWORK"))
                cat.xuiRule:SetPoint("BOTTOMLEFT", cat, "BOTTOMLEFT", 4, 2)
                cat.xuiRule:SetPoint("BOTTOMRIGHT", cat, "BOTTOMRIGHT", -4, 2)
                cat.xuiRule:SetHeight(1)
            end
            if cat.xuiRule then cat.xuiRule:SetColorTexture(line[1], line[2], line[3], 0.8); cat.xuiRule:Show() end
        end
    end
    if type(pane.ItemLevelFrame) == "table" then Fade(pane.ItemLevelFrame.Background) end
    local pool = pane.statsFramePool
    if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
        for sf in pool:EnumerateActive() do
            if type(sf) == "table" then
                local stripe = sf.Background and sf.Background.IsShown and sf.Background:IsShown()
                Fade(sf.Background)
                if not sf.xuiStripe and sf.CreateTexture then
                    sf.xuiStripe = Own(sf:CreateTexture(nil, "BACKGROUND"))
                    sf.xuiStripe:SetAllPoints(sf)
                end
                if sf.xuiStripe then sf.xuiStripe:SetColorTexture(1, 1, 1, 0.04); sf.xuiStripe:SetShown(stripe and true or false) end
                Recolor(sf.Label, muted)
                Recolor(sf.Value, text)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- The full stat list (QoL 0.7.31; Xaya 2026-11-06, her words: "missing details about about all possible stats / the ability to customize
-- how to display stats in the primary character window"; her answers: stats "2 but customizable and prettified with colors" (option 2:
-- exactly the lines of the Stat Calculator's Character Stats, Core Stats / Secondaries / Tertiaries); customise "Show / hide each stat,
-- Order, % / rating / both, Groups and colours"; default "Everything on"; REQUEST-LOG #70, #71, #74).
-------------------------------------------------------------------------------
-- Our own frames over Blizzard's stats pane (a scroll frame, child of CharacterStatsPane, so it shows and hides with the pane; an opaque
-- fill in the theme's pane colour under it, so Blizzard's rows neither show nor take the mouse). Blizzard's frames are not changed. The
-- numbers are the Character Toolkit model's (CM.Build "stats", with the Stat Calculator's typed numbers left out, as the character
-- window's own stat tooltips read them): no new game call. Every group heading (Core Stats, Primary, General, Offensive, Defensive,
-- Secondaries, Tertiaries) and every stat line of Character Stats, in her order and colours: a stat's name in its stat colour (the
-- Stat Calculator's), headings in the label colour, unless she picked others. A rating stat shows its percent, its rating, or both
-- ("528 / 22.48%", the Stat Weights' "Rating (P / %)" form). Hover a line: the Stat Calculator's hover for it. Built only while the
-- reskin and this part are on (V14); redrawn after Blizzard's PaperDollFrame_UpdateStats (the hook the stat list already has), at
-- most once per frame. Plain frames only (nothing protected): it works in and out of combat; values the game hides show "hidden in combat".
local LIST_CLEAN = { whatIf = 0, whatIfStats = {}, whatIfPrimary = false, detail = "all", collapsed = {} }
local LIST_ROW, LIST_HEAD, LIST_SIZE, LIST_PAD = 14, 17, 11, 4
local RATING_STAT = { map_crit = true, map_haste = true, map_mastery = true, map_vers = true, map_avoidance = true, map_leech = true, map_speed2 = true }
-- the groups and their stat lines as Character Stats has them now: { { key, label, level, stats = { item, ... } } }, and the items by key
function ns.CharReskin_ListModel()
    if not (CM and CM.Build) then return {}, {} end
    local ok, m = pcall(CM.Build, LIST_CLEAN, "stats")
    if not ok or type(m) ~= "table" then return {}, {} end
    local groups, items, cur = {}, {}, nil
    for _, sec in ipairs(m.sections or {}) do
        if sec.key == "map_character" then
            for _, it in ipairs(sec.items) do
                if it.kind == "subhead" then
                    cur = { key = it.key, label = it.label, level = it.level, stats = {} }
                    groups[#groups + 1] = cur
                elseif cur and (it.kind == "input" or it.kind == "stat" or it.kind == "rating") then
                    cur.stats[#cur.stats + 1] = it
                    items[it.key] = it
                end
            end
        end
    end
    return groups, items
end
-- a group's stat keys in her order: the saved order (keys the list still has), then any new ones in Character Stats' order
function ns.CharReskin_ListOrder(c, g)
    local out, seen, have = {}, {}, {}
    for _, it in ipairs(g.stats) do have[it.key] = true end
    for _, k in ipairs((c and c.statOrder and c.statOrder[g.key]) or {}) do if have[k] and not seen[k] then out[#out + 1] = k; seen[k] = true end end
    for _, it in ipairs(g.stats) do if not seen[it.key] then out[#out + 1] = it.key; seen[it.key] = true end end
    return out
end
function ns.CharReskin_HasRating(key) return RATING_STAT[key] == true end
-- the value a line shows in its mode
function ns.CharReskin_ListValue(c, it)
    local v = tostring(it.value or "")
    if RATING_STAT[it.key] and num(it.absolute) and not it.hidden and v ~= "" then
        local mode = (c and c.statMode and c.statMode[it.key]) or "percent"
        if mode == "rating" then return CM.Big(it.absolute) end
        if mode == "both" then return CM.Big(it.absolute) .. " / " .. v end
    end
    return v
end
local function ListColor(t, fb) if type(t) == "table" and num(t[1]) and num(t[2]) and num(t[3]) then return { t[1], t[2], t[3], 1 } end; return fb end
local listPending = false
local function UpdateStatList(c)
    local pane = _G.CharacterStatsPane
    if type(pane) ~= "table" or not pane.CreateTexture then return end
    local L = own.statList
    if not L then
        L = Own(CreateFrame("ScrollFrame", nil, pane))
        L:SetAllPoints(pane)
        if L.SetFrameLevel and pane.GetFrameLevel then L:SetFrameLevel((pane:GetFrameLevel() or 1) + 10) end
        L:EnableMouse(true)
        if L.EnableMouseWheel then L:EnableMouseWheel(true) end
        L.fill = L:CreateTexture(nil, "BACKGROUND"); L.fill:SetAllPoints(L)
        L.content = CreateFrame("Frame", nil, L)
        L.content:SetSize(1, 1)
        if L.SetScrollChild then L:SetScrollChild(L.content) end
        L:SetScript("OnMouseWheel", function(self, d)
            local cur = (self.GetVerticalScroll and self:GetVerticalScroll()) or 0
            local maxS = math.max(0, (self.contentH or 0) - ((self.GetHeight and self:GetHeight()) or 0))
            if self.SetVerticalScroll then self:SetVerticalScroll(math.max(0, math.min(maxS, cur - d * LIST_ROW * 2))) end
        end)
        L.fs, L.btns, L.rules = {}, {}, {}
        own.statList = L
    end
    local pbg = TC("xui-pane", "bg", { 0.04, 0.04, 0.04, 1 })
    L.fill:SetColorTexture(pbg[1], pbg[2], pbg[3], 1)
    local w = (L.GetWidth and L:GetWidth()) or 0
    if not num(w) or w <= 0 then w = (pane.GetWidth and pane:GetWidth()) or 190 end
    L.content:SetWidth(w)
    local label = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    local text = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local line = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
    local nFs, nBtn, nRule = 0, 0, 0
    local function FS(x, y, width, s, col, justify, size)
        nFs = nFs + 1
        local f = L.fs[nFs]
        if not f then f = L.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); L.fs[nFs] = f end
        SetSize(f, size or LIST_SIZE, "")
        f:ClearAllPoints(); f:SetPoint("TOPLEFT", L.content, "TOPLEFT", x, -y); f:SetWidth(width)
        if f.SetJustifyH then f:SetJustifyH(justify or "LEFT") end
        if f.SetWordWrap then f:SetWordWrap(true) end
        f:SetText(s or ""); f:SetTextColor(col[1], col[2], col[3], col[4] or 1); f:Show()
        local h = f.GetStringHeight and f:GetStringHeight() or LIST_SIZE
        return (num(h) and h > 0) and h or LIST_SIZE, f
    end
    local recs = {}
    local groups = ns.CharReskin_ListModel()
    local items = {}
    for _, g in ipairs(groups) do for _, it in ipairs(g.stats) do items[it.key] = it end end
    local y = LIST_PAD
    for _, g in ipairs(groups) do
        local keys = {}
        for _, k in ipairs(ns.CharReskin_ListOrder(c, g)) do if not c.statHide[k] then keys[#keys + 1] = k end end
        -- a heading shows when it has a line to show under it (Core Stats: when one of its four groups has one)
        local show = #keys > 0
        if g.key == "sub_core" then
            show = false
            for _, g2 in ipairs(groups) do
                if g2.level == 2 then for _, k in ipairs(ns.CharReskin_ListOrder(c, g2)) do if not c.statHide[k] then show = true end end end
            end
        end
        if show then
            local name = (c.groupName[g.key] and c.groupName[g.key] ~= "") and c.groupName[g.key] or g.label
            local col = ListColor(c.groupColor[g.key], label)
            local x = (g.level == 2) and 6 or LIST_PAD
            local h, f = FS(x, y + 2, w - x - LIST_PAD, name, col, "LEFT", g.level == 2 and LIST_SIZE or LIST_SIZE + 1)
            nRule = nRule + 1
            local r = L.rules[nRule]
            if not r then r = L.content:CreateTexture(nil, "ARTWORK"); L.rules[nRule] = r end
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", L.content, "TOPLEFT", x, -(y + 2 + h + 1)); r:SetSize(math.max(1, w - x - LIST_PAD), 1)
            r:SetColorTexture(line[1], line[2], line[3], 0.8); r:Show()
            recs[#recs + 1] = { kind = "group", key = g.key, text = name, color = col, x = x, y = y, fs = f }
            y = y + math.max(LIST_HEAD, h + 5)
            for _, k in ipairs(keys) do
                local it = items[k]
                local sname = (c.statName[k] and c.statName[k] ~= "") and c.statName[k] or it.label
                local scol = ListColor(c.statColor[k], it.labelColor or text)
                local lw = math.floor((w - 2 * LIST_PAD - 10) * 0.58)
                local lx = 10
                local lh, lf = FS(lx, y, lw, sname, scol, "LEFT")
                local val = ns.CharReskin_ListValue(c, it)
                local vh, vf = FS(lx + lw + 4, y, w - (lx + lw + 4) - LIST_PAD, val, (it.hidden or it.tone == "mute") and TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 }) or text, "RIGHT")
                local rowH = math.max(LIST_ROW, lh + 2, vh + 2)
                nBtn = nBtn + 1
                local b = L.btns[nBtn]
                if not b then
                    b = CreateFrame("Button", nil, L.content)
                    b:EnableMouse(true)
                    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.06)
                    b:SetScript("OnEnter", function(self)
                        if not (GameTooltip and self.item) then return end
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(self.name or "", 1, 1, 1)
                        local lines = ns.CharToolkit_TooltipLines and ns.CharToolkit_TooltipLines(self.item) or {}
                        for i, l in ipairs(lines) do
                            if i > 1 then
                                if l[2] ~= nil and GameTooltip.AddDoubleLine then GameTooltip:AddDoubleLine(l[1], l[2], 0.75, 0.75, 0.8, 0.95, 0.95, 0.95)
                                else GameTooltip:AddLine(l[1], 0.85, 0.85, 0.85, true) end
                            end
                        end
                        GameTooltip:Show()
                    end)
                    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                    b:SetScript("OnMouseWheel", function(_, d) local sc = L:GetScript("OnMouseWheel"); if sc then sc(L, d) end end)
                    L.btns[nBtn] = b
                end
                b.item, b.name = it, sname
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", L.content, "TOPLEFT", 0, -y); b:SetSize(w, rowH); b:Show()
                recs[#recs + 1] = { kind = "stat", key = k, text = sname, value = val, color = scol, x = lx, y = y, w = lw, h = rowH, fs = lf, vfs = vf }
                y = y + rowH
            end
            y = y + 3
        end
    end
    for i = nFs + 1, #L.fs do L.fs[i]:Hide() end
    for i = nBtn + 1, #L.btns do L.btns[i]:Hide(); L.btns[i].item = nil end
    for i = nRule + 1, #L.rules do L.rules[i]:Hide() end
    L.content:SetHeight(math.max(1, y))
    L.contentH, L.recs = y, recs
    L:Show()
    diag.statList = ("%d lines shown"):format(#recs)
end
local function HideStatList() if own.statList then own.statList:Hide() end end
local function QueueStatList()
    if listPending then return end
    listPending = true
    local function run() listPending = false; local c = Eff(); if c and Active() and c.statList then Guard(UpdateStatList, c) end end
    if C_Timer and C_Timer.After then C_Timer.After(0, run) else run() end
end
function ns.CharReskin_StatListRecs() return own.statList and own.statList:IsShown() and own.statList.recs or nil end   -- (tests)

-------------------------------------------------------------------------------
-- On / off
-------------------------------------------------------------------------------
local hooked = false
-- on = its own switch AND the Blizzard UI Reskin tab's switch (QoL 0.7.32, S1 #48: off there turns every reskin off)
-- (QoL 0.7.50; PS-57, #480) the switch takes effect on reload: this session runs with the value in effect (Modules.lua section 5c)
local function On(c) return c and ns.SwitchInEffect("reskin.charreskin", c.enabled) and ns.ReskinTabOn() and true or false end
-- (QoL 0.7.53, stage 1) the look runs while the reskin is on; the features while QoL's Character Pane switch is on (FeaturesOn above);
-- Active = either of them (the hooks and the window's events are there while one is on)
LookActive = function() local c = Cfg(); return On(c) and not diag.failed end
FeatActive = function() return Cfg() ~= nil and FeaturesOn() and not diag.failed end
Active = function() return LookActive() or FeatActive() end
function ns.CharReskin_Active() return Active() == true end
function ns.CharReskin_LookActive() return LookActive() == true end
function ns.CharReskin_FeaturesActive() return FeatActive() == true end
-- the Character Toolkit's slot overlays leave out their item level while this draws one (one number per slot: her screenshot had two)
function ns.CharReskin_DrawsIlvl() local c = Eff(); return (c and c.ilvl == true) and true or false end
function ns.CharReskin_DrawsEnchants() local c = Eff(); return (c and c.enchants == true) and true or false end
-- (QoL 0.7.19) and their empty-socket mark while this draws the sockets
function ns.CharReskin_DrawsSockets() local c = Eff(); return (c and c.gems == true) and true or false end

Guard = function(fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then return true end
    diag.failed, diag.lastError = true, tostring(err)
    RestoreAll(); SetOwnShown(false)
    pcall(RestoreWide)
    if ns.CharToolkit_UpdateOverlays then pcall(ns.CharToolkit_UpdateOverlays) end   -- the toolkit's overlays draw their item level again
    if ns.Print then ns.Print("Character Reskin hit an error and is off until /reload: " .. tostring(err)) end
    return false
end

-- the item events matter only while a slot part (item level, gems, enchants) is on; off, the frame listens to nothing (V14)
local SLOT_EVENTS = { "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "SOCKET_INFO_UPDATE", "ENCHANT_SPELL_COMPLETED" }
local function SetEvents(c)
    local ev = own.events
    if not ev then return end
    ev:UnregisterAllEvents()
    if c and Active() and (c.ilvl or c.enchants or c.gems) then for _, e in ipairs(SLOT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end end
end

-- a theme change repaints the window; the listener is there only while the reskin is on (V14)
local function OnTheme() if Active() then Guard(function() ns.CharReskin_Apply() end) end end
local function SetThemeListener(on)
    local T = ns.Theme
    if not (T and T.OnResolve) then return end
    if on and not own.themeOn then T.OnResolve(OnTheme); own.themeOn = true
    elseif not on and own.themeOn and T.OffResolve then T.OffResolve(OnTheme); own.themeOn = false end
end

local function ApplyNow()
    local c = Eff()
    if not c then return end
    if not Active() then
        RestoreAll(); SetOwnShown(false); diag.applied = false; SetEvents(nil); SetThemeListener(false)
        RestoreWide()
        if ns.CharToolkit_UpdateOverlays then pcall(ns.CharToolkit_UpdateOverlays) end
        return
    end
    -- a part switched off gives its pieces back: start from Blizzard's look, then apply the parts that are on (QoL 0.7.53: c is the
    -- drawing view, so with the reskin off no look part is on, and with the Character Pane switch off no feature part is)
    RestoreAll(); SetOwnShown(false)
    if LookActive() then PaintBackground(c) end
    if c.chrome then StyleWindow(c) end
    ApplyWide(c)
    UpdateSlots(c)
    if c.stats then StyleStats() end
    if c.statList then UpdateStatList(c) end   -- (QoL 0.7.31) our full stat list over Blizzard's pane
    SetEvents(c)
    SetThemeListener(true)
    diag.applied = true
    if ns.CharToolkit_UpdateOverlays then pcall(ns.CharToolkit_UpdateOverlays) end
end

local function Hook()
    if hooked then return end
    hooked = true
    local cf = _G.CharacterFrame
    if type(cf) == "table" and cf.HookScript then cf:HookScript("OnShow", function() if Active() then Guard(ApplyNow) end end) end
    -- (QoL 0.7.51; #495, REQUEST-LOG PS-59) while the settings window is shown, a right-click on the Character window opens the element
    -- menu (core Modules.lua section 11) with "Element options" only (Blizzard Reskin > Character Pane): it is Blizzard's own window,
    -- restyled, so its place is not XayaUI's to set (no X / Y; #495 proposal 4). A post-hook (blizzard = true: Blizzard's own handler
    -- always runs), put on at the first opening of the window out of combat, never on a protected frame. Registered only while the
    -- reskin is on (this function runs only then: V14).
    if ns.RegisterElement then
        ns.RegisterElement({ key = "characterPane", label = "Character window", blizzard = true, page = { "reskin", "charreskin" },
            targets = function(add) local cf2 = _G.CharacterFrame; if LookActive() and type(cf2) == "table" then add(cf2, "OnMouseUp") end end })
    end
    -- the model's camera buttons: the blocks that meet them hide while they show (post-hooks; they return at once while off)
    local m = _G.CharacterModelScene
    local camf = type(m) == "table" and m.ControlFrame or nil
    if type(camf) == "table" and camf.HookScript then
        camf:HookScript("OnShow", function() local c = Eff(); if Active() and (c.enchants or c.gems) then Guard(UpdateCamHide) end end)
        camf:HookScript("OnHide", function() local c = Eff(); if Active() and (c.enchants or c.gems) then Guard(UpdateCamHide) end end)
    end
    if type(hooksecurefunc) == "function" then
        if type(_G.PaperDollItemSlotButton_Update) == "function" then
            hooksecurefunc("PaperDollItemSlotButton_Update", function(btn)
                if not Active() then return end
                local c = Eff()
                if Guard(UpdateSlot, btn, c) then QueueDupCheck(c) end
            end)
        end
        if type(_G.PaperDollFrame_UpdateStats) == "function" then
            hooksecurefunc("PaperDollFrame_UpdateStats", function()
                local c = Eff()
                if Active() and c.stats then Guard(StyleStats) end
                if Active() and c.statList then QueueStatList() end   -- (QoL 0.7.31; at most once per frame)
            end)
        end
        if type(_G.PanelTemplates_SetTab) == "function" then
            hooksecurefunc("PanelTemplates_SetTab", function(frame) local c = Eff(); if frame == _G.CharacterFrame and Active() and c.chrome then Guard(StyleTabs) end end)
        end
    end
    -- item data that arrives later (an item level, a gem's name or a tooltip line the game had not sent yet) redraws the slots, once
    -- per frame at most (its events are registered by SetEvents, only while a slot part is on)
    local ev = CreateFrame("Frame")
    local pending = false
    ev:SetScript("OnEvent", function()
        if pending or not Active() then return end
        local cf2 = _G.CharacterFrame
        if not (cf2 and cf2.IsShown and cf2:IsShown()) then return end
        pending = true
        C_Timer.After(0, function() pending = false; if Active() then Guard(UpdateSlots, Eff()) end end)
    end)
    own.events = ev
end

function ns.CharReskin_Apply()
    local c = Cfg()
    if not c then return end
    if Active() then Hook() end   -- (QoL 0.7.53: the look or the features; before, the reskin's switch only)
    if hooked then Guard(ApplyNow) end
end
-- (P5) once both halves of the settings are open: QoL's at this addon's load, Blizzard Reskin's at that addon's load (it loads after
-- this one). (QoL 0.7.53, stage 1) and at the login, when every addon that loads has loaded: with XayaUI Blizzard Reskin switched off
-- the features (QoL's half) still run then; the look stays off (nothing of it is made)
ns.WhenSettingsReady("qol", function()
    ns.WhenSettingsReady("reskin", function() if Active() then ns.CharReskin_Apply() end end)
    if ns.AtLogin then ns.AtLogin(function() if Active() then ns.CharReskin_Apply() end end) end
end)
ns.RegisterReskin("charreskin", function() ns.CharReskin_Apply() end)   -- (the Reskin tab's switch: core ns.SetReskinTab walks these)

-------------------------------------------------------------------------------
-- Settings page: Blizzard UI Reskin > Character Pane (the switch is still called Character Reskin)
-------------------------------------------------------------------------------
-- (QoL 0.7.53, stage 1) the controls both pages make the same way
local function PageControls(Notify)
    local function C() return Cfg() or DEFAULTS end
    local function Changed() ns.CharReskin_Apply(); if Notify then Notify() end end
    local function T(key, order, name, desc, width, hidden)
        return { type = "toggle", order = order, name = name, desc = desc, width = width, disabled = hidden,
            get = function() return C()[key] end, set = function(_, v) C()[key] = v and true or false; Changed() end }
    end
    local function R(key, order, name, desc, min, max, step, pct, disabled)
        return { type = "range", order = order, name = name, desc = desc, min = min, max = max, step = step, isPercent = pct, width = "full",
            disabled = disabled, get = function() return C()[key] end,
            set = function(_, v) local lim = LIMITS[key]; C()[key] = math.max(lim[1], math.min(lim[2], tonumber(v) or DEFAULTS[key])); Changed() end }
    end
    return C, Changed, T, R
end

-------------------------------------------------------------------------------
-- (QoL 0.7.53, character pane split stage 1) Settings page: QoL > Character Pane. The feature controls that sat on Blizzard Reskin >
-- Character Pane until QoL 0.7.52 (item level, enchants, gems, the full stat list and its Stat list page), same labels, same order;
-- they read and write QoL's half only. Its on / off is the tick box on its row (QoL's `features`; FeaturesOn above).
-------------------------------------------------------------------------------
function ns.BuildCharPanePage(Notify)
    local C, Changed, T = PageControls(Notify)
    local function isOff() return not FeaturesOn() end
    -- (QoL 0.7.31) the full stat list's own page (her answer "Show / hide each stat, Order, % / rating / both, Groups and colours"): every
    -- group heading and stat line of Character Stats as the game gives them for this character now (other classes' resources differ)
    local listOff = function() return isOff() or not C().statList end
    local groups = ns.CharReskin_ListModel()
    local function Col(t) if type(t) == "table" then return t[1], t[2], t[3], 1 end end
    local listArgs = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Every line of the Stat Calculator's Character Stats in the character window's stats pane (its own list over Blizzard's), colored. For each stat: show or hide it, move it up or down in its group, show its percent, its rating or both (the secondary and tertiary stats), and its name and color; for each group: its heading's name and color. An empty name or \"Default color\" gives the Stat Calculator's back." },
        reset = { type = "execute", order = 1, name = "Reset the list", disabled = listOff,
            desc = "Shows every stat again in Character Stats' order as a percent, and resets every name and color.",
            func = function() local c = C(); for _, k in ipairs(LIST_TABLES) do c[k] = {} end; Changed() end },
    }
    for gi, g in ipairs(groups) do
        local gk = g.key
        listArgs["g" .. gi] = { type = "group", inline = true, order = gi * 100, name = function() local n = C().groupName[gk]; return (n and n ~= "") and n or g.label end,
            args = {
                name = { type = "input", order = 1, name = "Heading", disabled = listOff, desc = "The heading's text (empty: '" .. g.label .. "').",
                    get = function() return C().groupName[gk] or "" end, set = function(_, v) v = tostring(v or ""); C().groupName[gk] = (v ~= "") and v or nil; Changed() end },
                color = { type = "color", order = 2, name = "Color", disabled = listOff,
                    get = function() local t = C().groupColor[gk]; if t then return Col(t) end; local l = TC("xui-label", "text", { 1, 0.82, 0, 1 }); return l[1], l[2], l[3], 1 end,
                    set = function(_, r, gg, b) C().groupColor[gk] = { r, gg, b }; Changed() end },
                plain = { type = "execute", order = 3, name = "Default color", width = "half", disabled = listOff,
                    func = function() C().groupColor[gk] = nil; Changed() end },
            } }
        for i = 1, #g.stats do
            local function Key() return ns.CharReskin_ListOrder(C(), g)[i] end
            local function Item() local k = Key(); for _, it in ipairs(g.stats) do if it.key == k then return it end end end
            local function Move(d)
                local c = C()
                local list = ns.CharReskin_ListOrder(c, g)
                local j = i + d
                if j < 1 or j > #list then return end
                list[i], list[j] = list[j], list[i]
                c.statOrder[gk] = list
                Changed()
            end
            listArgs["g" .. gi .. "s" .. i] = { type = "group", inline = true, order = gi * 100 + i,
                name = function() local it = Item(); if not it then return "" end; local n = C().statName[it.key]; return "    " .. ((n and n ~= "") and n or it.label) end,
                args = {
                    show = { type = "toggle", order = 1, name = "Show", width = "half", disabled = listOff,
                        get = function() local k = Key(); return k and not C().statHide[k] end,
                        set = function(_, v) local k = Key(); if k then C().statHide[k] = (not v) and true or nil; Changed() end end },
                    mode = { type = "select", order = 2, name = "Shows", disabled = listOff,
                        values = { percent = "Percent", rating = "Rating", both = "Both (rating / percent)" }, sorting = { "percent", "rating", "both" },
                        hidden = function() return not ns.CharReskin_HasRating(Key()) end,
                        get = function() return C().statMode[Key()] or "percent" end,
                        set = function(_, v) local k = Key(); if k then C().statMode[k] = (v ~= "percent") and v or nil; Changed() end end },
                    up = { type = "execute", order = 3, name = "Up", width = "half", disabled = function() return listOff() or i == 1 end, func = function() Move(-1) end },
                    down = { type = "execute", order = 4, name = "Down", width = "half", disabled = function() return listOff() or i == #g.stats end, func = function() Move(1) end },
                    name = { type = "input", order = 5, name = "Name", disabled = listOff,
                        get = function() local k = Key(); return (k and C().statName[k]) or "" end,
                        set = function(_, v) local k = Key(); if k then v = tostring(v or ""); C().statName[k] = (v ~= "") and v or nil; Changed() end end },
                    color = { type = "color", order = 6, name = "Color", disabled = listOff,
                        get = function()
                            local k, it = Key(), Item()
                            local t = k and C().statColor[k]
                            if t then return Col(t) end
                            local d = (it and it.labelColor) or TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
                            return d[1], d[2], d[3], 1
                        end,
                        set = function(_, r, gg, b) local k = Key(); if k then C().statColor[k] = { r, gg, b }; Changed() end end },
                    plain = { type = "execute", order = 7, name = "Default color", width = "half", disabled = listOff,
                        func = function() local k = Key(); if k then C().statColor[k] = nil; Changed() end end },
                } }
        end
    end
    -- (QoL 0.7.53) the switch: QoL's Character Pane (first value: the Character Reskin switch as saved; FeaturesOn above)
    local switch = { type = "toggle", order = 1, name = "Character Pane",
        desc = "Turns on the item level, enchants, gems and the full stat list on the character window, with or without the Character Pane reskin (Blizzard Reskin).",
        tip = "Item levels, enchants, gems and the full stat list on the character window.",
        get = function() return FeaturesOn() end,
        set = function(_, v) if not ns.SettingsReady("qol") then return end; C().features = v and true or false; Changed() end }
    return {
        type = "group", name = "Character Pane", order = 2, childGroups = "tree", xuiSwitch = switch,
        args = {
            statListPage = { type = "group", name = "Stat list", order = 50, hidden = isOff, args = listArgs },
            ilvl = T("ilvl", 3, "Item level on each slot", "Shows one item level per slot, colored by its upgrade track and brighter with each upgrade step. Hidden on a slot where another addon already shows the same number.", "full", isOff),
            enchants = T("enchants", 4, "Enchants beside the slots", "Shows each slot's enchant or embellishment beside it, and \"No enchant\" in orange where one is missing. Hover a line for what it does.", "full", isOff),
            gems = T("gems", 5, "Gems and sockets beside the slots", "Shows each socket under the enchant: the gem's icon and name, or the empty socket's type in orange. Hover a gem for its tooltip.", "full", isOff),
            statList = T("statList", 6.5, "Full stat list (every Character Stats line)", "Shows every Character Stats line of the Stat Calculator in the stats pane. Pick what shows, the order, names and colors on its Stat list page.", "full", isOff),
        },
    }
end
ns.RegisterSettingsPage("qol", "charpane", ns.BuildCharPanePage)

-------------------------------------------------------------------------------
-- Settings page: Blizzard UI Reskin > Character Pane (the switch is still called Character Reskin). (QoL 0.7.53, stage 1) the look only:
-- the item level, enchant, gem and stat list controls are on QoL > Character Pane now.
-------------------------------------------------------------------------------
function ns.BuildCharReskinPage(Notify)
    local C, _, T, R = PageControls(Notify)
    local function isOff() return not C().enabled end
    -- its on / off is the tick box on this page's row in the left pane (xuiSwitch; QoL 0.7.32, S1 #48: "individual toggles for
    -- individual reskins"), greyed while the Blizzard UI Reskin tab's own switch is off
    local switch = T("enabled", 1, "Character Reskin", "Turns the reskin on; takes effect after a reload. Off gives Blizzard's look and width back. Greyed while Blizzard Reskin is off (this tab's Overview).")
    switch.tip = "Restyles the character window, with item levels, enchants and gems beside each slot."
    switch.disabled = function() return not ns.ReskinTabOn() end
    -- (QoL 0.7.50; PS-57, #480) saves the choice and asks for a reload; before, ns.CharReskin_Apply ran at once
    switch.set = function(_, v)
        ns.SwitchSaveForReload("reskin.charreskin", C().enabled, function() C().enabled = v and true or false end, "Character Pane")
        if Notify then Notify() end
    end
    return {
        type = "group", name = "Character Pane", order = 4, childGroups = "tree", xuiSwitch = switch,
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Blizzard's character window in XayaUI's look: a solid background, a clean flat window, one item level per slot colored by its upgrade track, the enchant, embellishment and gems beside each slot (hover any of them), a wider window that gives them room beside the model, and a tidy stat list. The window works as before, in and out of combat. Off by default." },
            chrome = T("chrome", 2, "Clean window", "Removes Blizzard's frame art for a thin border and theme colors. Off keeps Blizzard's art over the solid background.", "full", isOff),
            stats = T("stats", 6, "Stat list", "Colors the stat list with the theme, with a faint stripe on every other row instead of Blizzard's art.", "full", isOff),
            wide = T("wide", 7, "Wider window (room for the enchant names)", "Widens the Character tab so the enchant and gem lines sit between the slots and the model. Changes out of combat only.", "full", isOff),
            widePx = R("widePx", 8, "Extra width", "Sets how much wider than Blizzard's window, in pixels (default 42). Each side of the model gets half.", 0, 300, 1, false,
                function() return isOff() or not C().wide end),
            -- (QoL 0.7.31; Xaya: "character pane option should also allow for extra height"; her answer "either one": spread the slots)
            tallPx = R("tallPx", 8.5, "Extra height", "Sets how much taller than Blizzard's window, in pixels (default 0); the slots spread out to fill it. Changes out of combat only.", 0, 300, 1, false,
                function() return isOff() or not C().wide end),
            bgAlpha = R("bgAlpha", 9, "Background opacity", "How solid the window's background is (50% to 100%).", 0.5, 1, 0.05, true, isOff),
        },
    }
end
-- module "reskin": the page is the Blizzard UI Reskin tab's Character Pane (Xaya 2026-11-05: "Take all reskins and put them into a new
-- tab: Blizzard UI Reskin. Currently applies to: chat, character pane, Esc menu")
ns.RegisterSettingsPage("reskin", "charreskin", ns.BuildCharReskinPage)
-- (QoL 0.7.50; PS-56, #469) other addons that change the character window (Modules.lua section 5d): a flag only, nothing changes here.
-- ElvUI: folder "ElvUI" (https://github.com/tukui-org/ElvUI : ElvUI/ElvUI.toc; Shared\Skins\Character.lua in ElvUI/Game/load_mainline.xml).
-- EllesmereUI: folder "EllesmereUIBlizzardSkin" (https://github.com/EllesmereGaming/EllesmereUI : EllesmereUIBlizzardSkin.toc,
-- EllesmereUIBlizzardSkin_CharacterSheet.lua). (all read 2026-11-08)
if ns.RegisterConflict then
    ns.RegisterConflict({ part = "charreskin", label = "Character Pane", addons = { "ElvUI", "EllesmereUIBlizzardSkin" }, what = "the character window",
        on = function() return ns.CharReskin_Active() end })
end
-- (QoL 0.7.46; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.6) theme scope of the character window (page Character Pane), under the Blizzard Reskin tab's scope (core Theme.lua).
-- (QoL 0.7.52, #472) the window paints with it (TC above); page = where its "Theme" row goes.
local TS = ns.Theme and ns.Theme.RegisterScope
if TS then
    TS({ id = SCOPE, label = "Character Pane", parent = "reskin", page = "charreskin" })
end

ns.RegisterCommand("reskin", function(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local c = Cfg()
    if not c then return end
    if arg == "on" and not ns.SettingsReady("reskin") then   -- (P5) the switch is Blizzard Reskin's setting
        ns.Print(("/xui reskin on: the Character Reskin's look is kept by %s, which is switched off. Turn it on in the game's AddOns list, then /reload."):format(ns.AddonTitle and ns.AddonTitle("XayaUI_Reskin") or "XayaUI Blizzard Reskin"))
        return
    end
    -- (QoL 0.7.50; PS-57) on / off go the way of the settings switch: saved, the reload question, in effect after the /reload (5c)
    if arg == "on" or arg == "off" then
        local on = arg == "on"
        local line = ns.SwitchCommand("reskin.charreskin", c.enabled, function() c.enabled = on end, "Character Reskin", on)
        ns.Print(line .. ((on and not ns.ReskinTabSaved()) and " It shows once Blizzard Reskin is on again (Blizzard Reskin > Overview, then /reload)." or ""))
        return
    end
    if arg == "status" or arg == "" then
        ns.Print(("Character Reskin: %s%s%s; %d Blizzard regions faded, %d slots%s."):format(c.enabled and "on" or "off",
            ns.ReskinTabOn() and "" or " (Blizzard Reskin is off: Blizzard Reskin > Overview, so it does not show)",
            diag.failed and " (stopped after an error)" or "", diag.faded, diag.slots, diag.lastError and (", last error: " .. diag.lastError) or ""))
        ns.Print(("Wider window: %s."):format(c.wide and tostring(diag.wide) or "switched off"))
        ns.Print(("Size change: %s."):format(diag.relayout or "none seen since login"))
        ns.Print(("Extra height: %s; full stat list: %s."):format((c.wide and c.tallPx > 0) and tostring(diag.tall or "waits for the window") or "off",
            c.statList and tostring(diag.statList or "drawn when the stats pane shows") or "off"))
        ns.Print(("Slot blocks: %d (%d cut to fit, %d hidden while the camera buttons show); sockets drawn: %d; embellished items: %d."):format(
            diag.labels or 0, diag.cut or 0, diag.camHit or 0, diag.sockets or 0, diag.embellished or 0))
        -- (QoL 0.7.19) who else draws text on the slots: Xaya's screenshot of 2026-11-05 had a second item level on every slot
        local other = OtherText()
        if #other == 0 then ns.Print("No other text on the slot buttons (another addon can still draw over them from frames of its own).")
        else
            local shown = {}
            for i = 1, math.min(#other, 8) do shown[i] = other[i] end
            ns.Print(("Text on the slots that is not XayaUI's (%d): %s%s"):format(#other, table.concat(shown, "; "), #other > 8 and "; ..." or ""))
            ns.Print(("XayaUI's item level is hidden on %d slot(s) where that text shows the same number. To keep one: turn the other addon's item level off, or \"Item level on each slot\" here."):format(diag.dupes or 0))
        end
        return
    end
    if arg == "options" or arg == "settings" then ns.OpenSettingsPage("reskin", "charreskin"); return end
end, "/xui reskin [on|off|status|options] (QoL Character Reskin)")
