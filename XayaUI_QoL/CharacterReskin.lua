-------------------------------------------------------------------------------
-- CharacterReskin.lua : Character Reskin (XayaUI QoL 0.7.14). Blizzard's character window in XayaUI's look. Own code, Blizzard's frames
-- only. Off by default; while off nothing is created, hooked or changed. Its settings page is the settings window's Blizzard UI Reskin
-- tab > Character Pane (module "reskin"; Xaya 2026-11-05: every reskin in one tab).
--
-- Xaya, 2026-11-04: "also create a QoL Character Reskin option to toggle on or off"; "I want a reskin OF THE CHARACTER MENU AND NOTHING
-- ELSE"; "GIVE ME A PRETTY VERSION OF THE CHARACTER SHEET"; "THIS window needs to look beautiful and CLEAN"; "prettify the character
-- window" (her screenshot: two item-level numbers per slot); "ilvl colored based on ilv tier (track ... AND upgrade tier (color
-- gradient))"; "enchants + gems should show to the side of the character pane". Requirements: docs/plans/STAT-CALCULATOR-REQUIREMENTS-
-- 2026-11-04.md, rows A1-A7 (A6, the wider window, built in QoL 0.7.22 after her /xui stats widthprobe result; A8, the compact stat
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
local CM = ns.CharModel

-- booleans are switches; numbers are the wider window's extra width (px) and the background's opacity (0.5 - 1)
-- (QoL 0.7.24) extra width 42 px by default (Xaya 2026-11-06: "Push to 380px before stats pane and request feedback confirmation":
-- Blizzard's PANEL_DEFAULT_WIDTH 338 -> 380 without the stats pane, CHARACTERFRAME_EXPANDED_WIDTH 540 -> 582 with it); the setting
-- now reaches 0 (it started at 120); a saved number is kept as it is.
local DEFAULTS = { enabled = false, chrome = true, ilvl = true, enchants = true, gems = true, stats = true, wide = true, widePx = 42, bgAlpha = 0.95 }
local LIMITS = { widePx = { 0, 300 }, bgAlpha = { 0.5, 1 } }
local GOOD, WARN = { 0.5, 1, 0.5, 1 }, { 1, 0.56, 0.25, 1 }   -- the Character Toolkit's good / warn tones
ns.CHARRESKIN_DEFAULTS = DEFAULTS
local function Cfg()
    if not CueRulesDB then return nil end
    local c = CueRulesDB.characterReskin
    if type(c) ~= "table" then c = {}; CueRulesDB.characterReskin = c end
    -- (QoL 0.7.27) once per install: QoL 0.7.21-0.7.23 saved their default extra width, 240, into the settings, so the 0.7.24 default
    -- (42: 380 / 582) never reached an install that had run them (Xaya 2026-11-06: "surely this isn't 380px?", REQUEST-LOG #58-#59;
    -- her answer: a saved 240, the old default, becomes 42 once; any other saved number stays; a 240 picked after this stays too)
    if c.widePxTo42 == nil then
        if tonumber(c.widePx) == 240 then c.widePx = 42 end
        c.widePxTo42 = true
    end
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
    return c
end
ns.CharReskin_Cfg = Cfg

local diag = { applied = false, failed = false, lastError = nil, faded = 0, slots = 0, wide = "off" }
ns.CharReskinDiag = diag

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function TC(class, prop, fb)
    local T = ns.Theme
    if T and T.Col then local ok, c = pcall(T.Col, class, prop, fb); if ok and type(c) == "table" then return c end end
    return fb
end

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
    local box = { t = r.t + SLOT_PAD, b = r.b - SLOT_PAD }
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
    local c = Cfg()
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

local function UpdateSlots(c)
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
        C_Timer.After(0, function() local c2 = Cfg(); if Active() and (c2.enchants or c2.gems) then Guard(UpdateSlots, c2) end end)
    elseif not diag.noGeometry then retries = 0 end
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
-- The wider window (QoL 0.7.22, requirement A6; Xaya's in-game /xui stats widthprobe of 2026-11-05: "width probe: on, 120 px wider (540
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

local function RestoreWide()
    if not (wide.applied or wide.moved) then return end
    local cf, m, mh = WideFrames()
    if not cf then wide.applied, wide.moved = false, false; return end
    if InCombat() then WaitForCombatEnd(true); return end
    PutBack(m, mh)
    wide.applied = false
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
    if changed then cf:SetWidth(base + px) end
    cf.Inset:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", DW + RO + px, BO)
    m:ClearAllPoints(); m:SetPoint(wide.mp[1], wide.mp[2], wide.mp[3], wide.mp[4] + half, wide.mp[5])
    mh:ClearAllPoints(); mh:SetPoint(wide.hp[1], wide.hp[2], wide.hp[3], wide.hp[4] + half, wide.hp[5])
    wide.applied, wide.moved, wide.base, wide.px, wide.setW = true, true, base, px, base + px
    if changed and type(UpdateUIPanelPositions) == "function" then
        if ns.MapTrace then ns.MapTrace("Character Reskin: UpdateUIPanelPositions(CharacterFrame) (wider window)") end
        pcall(UpdateUIPanelPositions, cf)
    end
    diag.wide = ("on, %d px wider (%d -> %d)"):format(px, math.floor(base + 0.5), math.floor(base + px + 0.5))
end

local function WideAndSlots()
    local c = Cfg()
    ApplyWide(c)
    if Active() and (c.ilvl or c.enchants or c.gems) then UpdateSlots(c) end
end
WideRegen = function()
    WaitForCombatEnd(false)
    local c = Cfg()
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
            local c = Cfg()
            if c and Active() and c.wide then Guard(WideAndSlots) end
        end)
    end
    if type(pd) == "table" and pd.HookScript then
        pd:HookScript("OnShow", function() local c = Cfg(); if c and Active() and c.wide then Guard(WideAndSlots) end end)
    end
end
function ns.CharReskin_WideOn() return (wide.applied or wide.moved) and true or false end

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
-- On / off
-------------------------------------------------------------------------------
local hooked = false
Active = function() local c = Cfg(); return c and c.enabled and not diag.failed end
function ns.CharReskin_Active() return Active() == true end
-- the Character Toolkit's slot overlays leave out their item level while this draws one (one number per slot: her screenshot had two)
function ns.CharReskin_DrawsIlvl() local c = Cfg(); return (Active() and c.ilvl == true) and true or false end
function ns.CharReskin_DrawsEnchants() local c = Cfg(); return (Active() and c.enchants == true) and true or false end
-- (QoL 0.7.19) and their empty-socket mark while this draws the sockets
function ns.CharReskin_DrawsSockets() local c = Cfg(); return (Active() and c.gems == true) and true or false end

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
    local c = Cfg()
    if not c then return end
    if not Active() then
        RestoreAll(); SetOwnShown(false); diag.applied = false; SetEvents(nil); SetThemeListener(false)
        RestoreWide()
        if ns.CharToolkit_UpdateOverlays then pcall(ns.CharToolkit_UpdateOverlays) end
        return
    end
    -- a part switched off gives its pieces back: start from Blizzard's look, then apply the parts that are on
    RestoreAll(); SetOwnShown(false)
    PaintBackground(c)
    if c.chrome then StyleWindow(c) end
    ApplyWide(c)
    UpdateSlots(c)
    if c.stats then StyleStats() end
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
    -- the model's camera buttons: the blocks that meet them hide while they show (post-hooks; they return at once while off)
    local m = _G.CharacterModelScene
    local camf = type(m) == "table" and m.ControlFrame or nil
    if type(camf) == "table" and camf.HookScript then
        camf:HookScript("OnShow", function() local c = Cfg(); if Active() and (c.enchants or c.gems) then Guard(UpdateCamHide) end end)
        camf:HookScript("OnHide", function() local c = Cfg(); if Active() and (c.enchants or c.gems) then Guard(UpdateCamHide) end end)
    end
    if type(hooksecurefunc) == "function" then
        if type(_G.PaperDollItemSlotButton_Update) == "function" then
            hooksecurefunc("PaperDollItemSlotButton_Update", function(btn)
                if not Active() then return end
                local c = Cfg()
                if Guard(UpdateSlot, btn, c) then QueueDupCheck(c) end
            end)
        end
        if type(_G.PaperDollFrame_UpdateStats) == "function" then
            hooksecurefunc("PaperDollFrame_UpdateStats", function() local c = Cfg(); if Active() and c.stats then Guard(StyleStats) end end)
        end
        if type(_G.PanelTemplates_SetTab) == "function" then
            hooksecurefunc("PanelTemplates_SetTab", function(frame) local c = Cfg(); if frame == _G.CharacterFrame and Active() and c.chrome then Guard(StyleTabs) end end)
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
        C_Timer.After(0, function() pending = false; if Active() then Guard(UpdateSlots, Cfg()) end end)
    end)
    own.events = ev
end

function ns.CharReskin_Apply()
    local c = Cfg()
    if not c then return end
    if c.enabled then Hook() end
    if hooked then Guard(ApplyNow) end
end
ns.WhenReady(function() local c = Cfg(); if c and c.enabled then ns.CharReskin_Apply() end end)

-------------------------------------------------------------------------------
-- Settings page: Blizzard UI Reskin > Character Pane (the switch is still called Character Reskin)
-------------------------------------------------------------------------------
function ns.BuildCharReskinPage(Notify)
    local function C() return Cfg() or DEFAULTS end
    local function Changed() ns.CharReskin_Apply(); if Notify then Notify() end end
    local function isOff() return not C().enabled end
    local function T(key, order, name, desc, width, hidden)
        return { type = "toggle", order = order, name = name, desc = desc, width = width, disabled = hidden,
            get = function() return C()[key] end, set = function(_, v) C()[key] = v and true or false; Changed() end }
    end
    local function R(key, order, name, desc, min, max, step, pct, disabled)
        return { type = "range", order = order, name = name, desc = desc, min = min, max = max, step = step, isPercent = pct, width = "full",
            disabled = disabled, get = function() return C()[key] end,
            set = function(_, v) local lim = LIMITS[key]; C()[key] = math.max(lim[1], math.min(lim[2], tonumber(v) or DEFAULTS[key])); Changed() end }
    end
    return {
        type = "group", name = "Character Pane", order = 4,
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Blizzard's character window in XayaUI's look: a solid background, a clean flat window, one item level per slot coloured by its upgrade track, the enchant, embellishment and gems beside each slot (hover any of them), a wider window that gives them room beside the model, and a tidy stat list. The window works as before, in and out of combat. Off by default." },
            enabled = T("enabled", 1, "Character Reskin", "Turns the reskin on. Off gives Blizzard's look and width back at once (out of combat; in combat when the fight ends).", "full"),
            chrome = T("chrome", 2, "Clean window", "Blizzard's frame art goes: no portrait or stone frame, no backdrop picture behind the model; a thin border, the theme's pane colour behind the stat list, theme-coloured title and tabs; the slots lose their frame art. Off: Blizzard's art over XayaUI's solid background.", "full", isOff),
            ilvl = T("ilvl", 3, "Item level on each slot", "One item level per slot, coloured by its upgrade track (Veteran green, Champion blue, Hero purple, Myth orange, Explorer / Adventurer grey; the game's quality colours) and brighter with each upgrade step. Items without a track show their quality colour. The Character Toolkit's slot overlays leave out their own item level while this is on, and XayaUI's stays hidden on a slot where another addon already shows the same number (/xui reskin status names it).", "full", isOff),
            enchants = T("enchants", 4, "Enchants beside the slots", "The enchant's name beside each slot, toward the model (without the \"Enchant <slot> - \" the game puts before every enchant's name), wrapped; \"No enchant\" in orange on a slot that takes one (the Character Toolkit's enchant slots); \"Embellished (worn / limit): <item name>\" on an embellished item (its hover: \"Embellished - Name: <item name>\", then what it does as the game words it). Hover a line: the whole line and what it does, as far as the game gives it.", "full", isOff),
            gems = T("gems", 5, "Gems and sockets beside the slots", "One row per socket under the enchant: the gem's icon (16 px; 12 on a slot where 16 does not fit) and its name, or the empty socket's type in orange. Hover a gem for its tooltip. The Character Toolkit's slot overlays leave out their empty-socket mark while this is on.", "full", isOff),
            stats = T("stats", 6, "Stat list", "The stat list's headers, labels and values in the theme's colours, with a faint stripe on every other row instead of Blizzard's art.", "full", isOff),
            wide = T("wide", 7, "Wider window (room for the enchant names)", "Makes the character window wider on its Character tab and centres the model, so the enchant, embellishment and gem lines sit between the slots and the model instead of over it (where the extra width leaves too little room beside the model, they run over its sides: nothing is hidden). Changed only out of combat; switching tabs gives Blizzard's width on the other tabs. Off: Blizzard's width (the lines then lie over the model's sides); once it has been on, a /reload removes its two hooks fully (while off they do nothing).", "full", isOff),
            widePx = R("widePx", 8, "Extra width", "How much wider than Blizzard's window, in pixels (default 42: 338 -> 380 without the stats pane, 540 -> 582 with it). Each side of the model gets half.", 0, 300, 1, false,
                function() return isOff() or not C().wide end),
            bgAlpha = R("bgAlpha", 9, "Background opacity", "How solid the window's background is (50% to 100%).", 0.5, 1, 0.05, true, isOff),
        },
    }
end
-- module "reskin": the page is the Blizzard UI Reskin tab's Character Pane (Xaya 2026-11-05: "Take all reskins and put them into a new
-- tab: Blizzard UI Reskin. Currently applies to: chat, character pane, Esc menu")
ns.RegisterSettingsPage("reskin", "charreskin", ns.BuildCharReskinPage)
ns.RegisterCommand("reskin", function(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local c = Cfg()
    if not c then return end
    if arg == "on" then c.enabled = true; ns.CharReskin_Apply(); ns.Print("Character Reskin on."); return end
    if arg == "off" then c.enabled = false; ns.CharReskin_Apply(); ns.Print("Character Reskin off."); return end
    if arg == "status" or arg == "" then
        ns.Print(("Character Reskin: %s%s; %d Blizzard regions faded, %d slots%s."):format(c.enabled and "on" or "off",
            diag.failed and " (stopped after an error)" or "", diag.faded, diag.slots, diag.lastError and (", last error: " .. diag.lastError) or ""))
        ns.Print(("Wider window: %s."):format(c.wide and tostring(diag.wide) or "switched off"))
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
