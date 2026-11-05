-------------------------------------------------------------------------------
-- CharacterReskin.lua : Character Reskin (XayaUI QoL 0.7.14). Blizzard's character window in XayaUI's look. Own code, Blizzard's frames
-- only. Off by default; while off nothing is created, hooked or changed. Its settings page is the settings window's Blizzard UI Reskin
-- tab > Character Pane (module "reskin"; Xaya 2026-11-05: every reskin in one tab).
--
-- Xaya, 2026-11-04: "also create a QoL Character Reskin option to toggle on or off"; "I want a reskin OF THE CHARACTER MENU AND NOTHING
-- ELSE"; "GIVE ME A PRETTY VERSION OF THE CHARACTER SHEET"; "THIS window needs to look beautiful and CLEAN"; "prettify the character
-- window" (her screenshot: two item-level numbers per slot); "ilvl colored based on ilv tier (track ... AND upgrade tier (color
-- gradient))"; "enchants + gems should show to the side of the character pane". Requirements: docs/plans/STAT-CALCULATOR-REQUIREMENTS-
-- 2026-11-04.md, rows A1-A5 and A7 (A6, the wider window, waits on her in-game /xui stats widthprobe; A8, the compact stat
-- tooltips, is the Character Toolkit's tooltip lines).
--
-- How (the frames are Blizzard's, live 12.1.5 source, read 2026-11-05: CharacterFrame.xml, PaperDollFrame.xml, and
-- SharedUIPanelTemplates.xml for ButtonFrameTemplate / PortraitFrameBaseTemplate / InsetFrameTemplate / PanelTabButtonTemplate):
--   * Restyle only: Blizzard's art is faded (alpha 0) and ours is drawn on its own textures and font strings. No script, size or anchor of
--     a Blizzard frame is changed, so nothing here differs in combat. Switching off puts every alpha and text colour back.
--   * Window: the frame art (NineSlice, Bg, TopTileStreaks), the portrait, the paper-doll background, the insets' art, the model's
--     backgrounds and inner border, the stats pane's class background, the tab art; then a flat theme background, a thin border,
--     a softer fill behind the model, theme-coloured title and tabs.
--   * Slots: the slot frame art and the bevel go; one item level per slot (ours: the Character Toolkit's slot overlays leave theirs out
--     while this is on; none on the shirt and the tabard), coloured by upgrade track and step (CM.TrackColor); the sockets with their
--     gems and the enchant name beside each slot, toward the model (QoL 0.7.19: the game's own socket display shows only for
--     Timerunning characters, so the sockets are ours; the enchant wraps inside its slot's band; layout notes at "Slots" below).
--   * Stat list: the row and header art goes; theme-coloured headers with a thin rule, labels, values and a faint stripe on every other
--     row (where Blizzard shows its own).
--   * Safety (as the Game Menu skin): any error while applying turns the reskin off for the session and gives Blizzard's look back.
-- NOT RUN IN GAME when written: QA E1z6 (and E1z7 for the tooltips; E1z11-E1z13 for QoL 0.7.19's labels, sockets and item levels).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local CM = ns.CharModel

local DEFAULTS = { enabled = false, chrome = true, ilvl = true, enchants = true, gems = true, stats = true }
local GOOD, WARN = { 0.5, 1, 0.5, 1 }, { 1, 0.56, 0.25, 1 }   -- the Character Toolkit's good / warn tones
ns.CHARRESKIN_DEFAULTS = DEFAULTS
local function Cfg()
    if not CueRulesDB then return nil end
    local c = CueRulesDB.characterReskin
    if type(c) ~= "table" then c = {}; CueRulesDB.characterReskin = c end
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = v end end
    for k in pairs(DEFAULTS) do c[k] = c[k] == true end
    return c
end
ns.CharReskin_Cfg = Cfg

local diag = { applied = false, failed = false, lastError = nil, faded = 0, slots = 0 }
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
local function Own(t) own.all[#own.all + 1] = t; return t end
local function SetOwnShown(on) for _, t in ipairs(own.all) do if t.SetShown then t:SetShown(on) end end end

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

local function StyleWindow()
    local cf = _G.CharacterFrame
    if type(cf) ~= "table" then return end
    for _, k in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "Background" }) do Fade(cf[k]) end
    for _, inset in ipairs({ cf.Inset, cf.InsetRight }) do
        if type(inset) == "table" then Fade(inset.Bg); Fade(inset.NineSlice) end
    end
    local pane = _G.CharacterStatsPane
    if type(pane) == "table" then Fade(pane.ClassBackground) end
    for _, name in ipairs(MODEL_REGIONS) do Fade(_G[name]) end
    if not own.bg then
        -- on the window's own BACKGROUND layer, lowest sublevel: under every Blizzard region and child frame
        own.bg = Own(cf:CreateTexture(nil, "BACKGROUND", nil, -8))
        own.bg:SetAllPoints(cf)
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
    end
    local bg = TC("xui-window", "bg", { 0.04, 0.04, 0.06, 1 })
    own.bg:SetColorTexture(bg[1], bg[2], bg[3], 0.96)
    local bc = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
    for _, e in ipairs(own.edges) do e:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 1) end
    if own.inset then own.inset:SetColorTexture(1, 1, 1, 0.03) end   -- a faint lift behind the model and the slots
    local title = type(cf.TitleContainer) == "table" and cf.TitleContainer.TitleText or _G.CharacterFrameTitleText
    Recolor(title, TC("xui-titlebar", "text", { 1, 0.82, 0, 1 }))
    StyleTabs()
end

-------------------------------------------------------------------------------
-- Slots: one item level, track-coloured; the gems and the enchant beside it
-------------------------------------------------------------------------------
-- Blizzard's layout (live 12.1.5 source, read 2026-11-05: PaperDollFrame.xml, ItemButtonTemplate.xml, ModelSceneControlFrame.xml /
-- .lua, ModelSceneMixin.lua): slot buttons 37 x 37, 4 px apart; the left column ends 7 px before the model scene (231 x 320 at 52, -66),
-- the right column starts 8 px after it; the model's camera buttons (its ControlFrame, TOP -10) are 32 high and 2 + n x (32 - 6) wide
-- for n <= 5 buttons, shown only while the mouse is over the model (ModelSceneMixin:OnEnter / OnLeave); the weapon slots sit at the
-- bottom between the columns; the game's own socket display (11 px sockets, 7 px beside the slot) shows only for Timerunning characters.
-- Our layout (QoL 0.7.19; Xaya 2026-11-05: "correctly word wrap enchant lines", "show gem sockets and gems socketed"):
--   * sockets: a column of 11 px sockets where the game puts its own, 7 px beside the slot toward the model (weapons: a row under the
--     slot); the gem's icon in a filled socket, the game's empty-socket art in an empty one; the gem's tooltip on hover;
--   * enchant: in a column 22 px from the slot (past the sockets), wrapped onto as many lines as it needs, inside its slot's band (the
--     slot plus half the 4 px gap above and below it, so two bands never overlap); the left column's labels stay left of the middle
--     and the right column's right of it, ns.UI_GUTTER apart; the weapons' labels sit under the side columns, beside the weapons;
--   * a label never covers the weapon slots and their frame art: on the rows beside them it takes the part of its band above them,
--     or is narrowed;
--   * a label that cannot clear the camera buttons (the head and hands rows) hides while those buttons show;
--   * font 10, then 9, then 8 when it does not fit its band; a name that does not fit even then is cut at a word, with "..." (the
--     slot's own tooltip has the whole line). Nothing is cut in the middle of a word.
local LEFT_SLOTS = { HeadSlot = true, NeckSlot = true, ShoulderSlot = true, BackSlot = true, ChestSlot = true, ShirtSlot = true,
    TabardSlot = true, WristSlot = true }
local WEAPON_SLOTS = { MainHandSlot = true, SecondaryHandSlot = true }
local NO_ENCHANT_TEXT = "No enchant"
local FRIZ = "Fonts\\FRIZQT__.TTF"
local GUT = ns.UI_GUTTER or 10
local SLOT_PAD = 2                          -- half the 4 px between two slots: a slot's band reaches this far above and below it
local SOCK, SOCK_GAP, SOCK_OFF = 11, 2, 7   -- the game's socket size and its distance from the slot (PaperDollFrame.xml)
local LABEL_OFF = SOCK_OFF + SOCK + 4       -- the enchant column: past the socket column
local CAM_TOP, CAM_H, CAM_W = 10, 32, 2 + 5 * (32 - 6)   -- the camera buttons, all five shown (the widest they get)
local ART_X, ART_TOP, ART_BOTTOM = 10, 8, 9 -- the weapon slots' frame art past the slot (Char-BottomSlot 42 x 53 at -4, 8; side pieces 6-7)
local LABEL_SIZES = { 10, 9, 8 }
local EMPTY_SOCKET_ATLAS = "character-emptysocket"   -- the game's own empty-socket art (PaperDollItemSocketSlotTemplate)

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

-- where the columns, the camera buttons and the weapons are now
local function Geometry()
    local head, hands = Rect(SlotBtn("HeadSlot")), Rect(SlotBtn("HandsSlot"))
    if not (head and hands) then return nil end
    local g = { mid = (head.r + hands.l) / 2, colL = head.l, colR = hands.r }
    local model = Rect(_G.CharacterModelScene)
    if model then
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

-- the rectangles a slot's label may use, best first
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
    local left = LEFT_SLOTS[name]
    local box = { t = r.t + SLOT_PAD, b = r.b - SLOT_PAD }
    if left then box.l, box.r = r.r + LABEL_OFF, g.mid - GUT / 2 else box.l, box.r = g.mid + GUT / 2, r.l - LABEL_OFF end
    local w = g.weap
    if not (w and Overlaps(box, w)) then return { box } end
    local out = {}
    if box.t - (w.t + 1) >= 8 then out[#out + 1] = { l = box.l, r = box.r, t = box.t, b = w.t + 1 } end   -- above the weapons
    local n = { l = box.l, r = box.r, t = box.t, b = box.b }                                                 -- beside them
    if left then n.r = math.min(n.r, w.l - GUT) else n.l = math.max(n.l, w.r + GUT) end
    if n.r - n.l >= 20 then out[#out + 1] = n end
    return out
end

local function Measure(fs, text, size, w)
    SetSize(fs, size)
    fs:SetWidth(w)
    fs:SetText(text)
    local h = fs:GetStringHeight()
    if CM.IsSecret(h) or not num(h) then return nil end
    return h
end

-- the top edge for a label of height h in box: level with the slot's middle, kept inside the box; moved above or below the camera
-- buttons when there is room. Returns the top and whether the label still meets the camera buttons.
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

-- lay one label out: the largest font that fits a box (one that clears the camera buttons first), else cut at a word
local function LayoutLabel(btn, name, text)
    local fs = btn.xuiEnchant
    btn.xuiLabel = nil
    if text == "" then fs:SetText(""); return end
    local g, r = Geometry(), Rect(btn)
    local boxes = (g and r) and LabelBoxes(g, name, r) or {}
    if #boxes == 0 then fs:SetText(""); if not (g and r) then diag.noGeometry = true end; return end   -- not laid out yet: UpdateSlots retries
    local cy = WEAPON_SLOTS[name] and (boxes[1].t + boxes[1].b) / 2 or (r.t + r.b) / 2
    local pick
    for _, size in ipairs(LABEL_SIZES) do
        for _, box in ipairs(boxes) do
            local h = Measure(fs, text, size, box.r - box.l)
            if h and h <= box.t - box.b then
                local top, camHit = PlaceTop(g, box, h, cy)
                if not camHit then pick = { size = size, box = box, top = top, h = h, text = text }; break end
                pick = pick or { size = size, box = box, top = top, h = h, text = text, camHit = true }
            end
        end
        if pick and not pick.camHit then break end
    end
    if not pick then
        -- does not fit even at the smallest size: cut at a word (the slot's tooltip has the whole line)
        local box, size = boxes[#boxes], LABEL_SIZES[#LABEL_SIZES]
        local words = {}
        for wd in text:gmatch("%S+") do words[#words + 1] = wd end
        for k = #words - 1, 1, -1 do
            local cut = table.concat(words, " ", 1, k) .. "..."
            local h = Measure(fs, cut, size, box.r - box.l)
            if h and h <= box.t - box.b then
                local top, camHit = PlaceTop(g, box, h, cy)
                pick = { size = size, box = box, top = top, h = h, text = cut, camHit = camHit, cut = true }
                break
            end
        end
    end
    if not pick then fs:SetText(""); return end
    Measure(fs, pick.text, pick.size, pick.box.r - pick.box.l)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", btn, "TOPLEFT", pick.box.l - r.l, pick.top - r.t)
    btn.xuiLabel = pick
end

-- the camera buttons show: the labels that meet them hide until they go (alpha only; nothing else changes)
local function CamShown()
    local m = _G.CharacterModelScene
    local cf = type(m) == "table" and m.ControlFrame or nil
    return (type(cf) == "table" and cf.IsShown and cf:IsShown()) and true or false
end
local function UpdateCamHide()
    local hide = CamShown()
    for _, s in ipairs(CM.SLOTS) do
        local btn = SlotBtn(s[4])
        if type(btn) == "table" and btn.xuiEnchant then
            btn.xuiEnchant:SetAlpha((hide and btn.xuiLabel and btn.xuiLabel.camHit) and 0 or 1)
        end
    end
end

-- sockets: the gem's own tooltip on hover (its name when the game has no link for it)
local function SocketEnter(f)
    local tt = _G.GameTooltip
    if not (tt and f.data) then return end
    tt:SetOwner(f, "ANCHOR_RIGHT")
    local d = f.data
    if d.link and tt.SetHyperlink and pcall(tt.SetHyperlink, tt, d.link) then tt:Show(); return end
    if d.gemID then tt:AddLine(d.name or "Gem (its name is not loaded yet)", 1, 1, 1)
    else tt:AddLine(d.typeName or "Empty socket", 1, 0.56, 0.25) end
    tt:Show()
end
local function SocketLeave() if _G.GameTooltip then _G.GameTooltip:Hide() end end
local function Socket(btn, i)
    btn.xuiSockets = btn.xuiSockets or {}
    local f = btn.xuiSockets[i]
    if f then return f end
    f = Own(CreateFrame("Frame", nil, btn))
    f:SetSize(SOCK, SOCK)
    f.bg = f:CreateTexture(nil, "BORDER"); f.bg:SetAllPoints(f)
    local atlas = C_Texture and C_Texture.GetAtlasExists and CM.R(C_Texture.GetAtlasExists, EMPTY_SOCKET_ATLAS) == true
    if atlas then f.bg:SetAtlas(EMPTY_SOCKET_ATLAS) else f.bg:SetColorTexture(0.12, 0.12, 0.14, 0.95) end
    f.gem = f:CreateTexture(nil, "ARTWORK")
    f.gem:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2); f.gem:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    f:EnableMouse(true)
    f:SetScript("OnEnter", SocketEnter); f:SetScript("OnLeave", SocketLeave)
    btn.xuiSockets[i] = f
    return f
end
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local function UpdateSockets(btn, name, info)
    local gems = info and info.gems or {}
    local n = #gems
    if btn.xuiSockets then for i = n + 1, #btn.xuiSockets do btn.xuiSockets[i]:Hide() end end
    if n == 0 then return 0 end
    -- one socket type in the item's stat table: its name on hover (the key is also the game's string for it, e.g. "Prismatic Socket")
    local typeName, nTypes = nil, 0
    for k in pairs(info.socketTypes or {}) do nTypes = nTypes + 1; typeName = (type(_G[k]) == "string" and not CM.IsSecret(_G[k])) and _G[k] or nil end
    if nTypes ~= 1 then typeName = nil end
    local h = Rect(btn); h = h and (h.t - h.b) or 37
    local total = n * SOCK + (n - 1) * SOCK_GAP
    for i, gd in ipairs(gems) do
        local f = Socket(btn, i)
        f.data = { gemID = gd.gemID, name = gd.name, link = gd.link, typeName = typeName }
        if gd.gemID then f.gem:SetTexture(gd.icon or QUESTION_MARK); f.gem:Show() else f.gem:Hide() end
        f:ClearAllPoints()
        local step = (i - 1) * (SOCK + SOCK_GAP)
        if WEAPON_SLOTS[name] then
            local w = Rect(btn); w = w and (w.r - w.l) or 37
            f:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", (w - total) / 2 + step, -1)
        elseif LEFT_SLOTS[name] then
            f:SetPoint("TOPLEFT", btn, "TOPRIGHT", SOCK_OFF, -((h - total) / 2 + step))
        else
            f:SetPoint("TOPRIGHT", btn, "TOPLEFT", -SOCK_OFF, -((h - total) / 2 + step))
        end
        f:Show()
    end
    return n
end

local function UpdateSlot(btn, c)
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
                btn.xuiIlvl:SetText(tostring(math.floor(info.ilvl + 0.5)))
                col = col or { 1, 1, 1, 1 }
                btn.xuiIlvl:SetTextColor(col[1], col[2], col[3], 1)
                btn.xuiTrack = track
                btn.xuiIlvl:Show()
            else
                btn.xuiIlvl:SetText(""); btn.xuiTrack = nil
            end
        end
    elseif btn.xuiIlvl then btn.xuiIlvl:Hide() end
    -- gems and sockets
    if c.gems then UpdateSockets(btn, name, info)
    elseif btn.xuiSockets then for _, f in ipairs(btn.xuiSockets) do f:Hide() end end
    -- enchant: wrapped beside the slot (LayoutLabel)
    if c.enchants then
        if not btn.xuiEnchant and btn.CreateFontString then
            local fs = Mine(btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
            if fs.SetWordWrap then fs:SetWordWrap(true) end
            if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
            if fs.SetJustifyV then fs:SetJustifyV("TOP") end
            fs:SetJustifyH((name == "MainHandSlot" or not (LEFT_SLOTS[name] or name == "SecondaryHandSlot")) and "RIGHT" or "LEFT")
            btn.xuiEnchant = fs
        end
        if btn.xuiEnchant then
            local text, col = "", nil
            if info then
                local tk = ns.CharToolkit_Cfg and ns.CharToolkit_Cfg() or nil
                local slotsWanted = CM.EnchantSlots(tk)
                local ench = CM.SlotEnchant(slot)
                if ench then text, col = ench, GOOD
                elseif info.enchanted == false and slotsWanted[slot] then text, col = NO_ENCHANT_TEXT, WARN
                elseif info.enchanted == true then text, col = "Enchanted", GOOD end
            end
            LayoutLabel(btn, name, text)
            if col then btn.xuiEnchant:SetTextColor(col[1], col[2], col[3], 1) end
            btn.xuiEnchant:SetAlpha((btn.xuiLabel and btn.xuiLabel.camHit and CamShown()) and 0 or 1)
            btn.xuiEnchant:Show()
        end
    elseif btn.xuiEnchant then btn.xuiEnchant:Hide(); btn.xuiLabel = nil end
end

local retries = 0
local Active, Guard   -- (defined in "On / off" below; the retry calls them)
local function UpdateSlots(c)
    local n, labels, cut, cam, socks = 0, 0, 0, 0, 0
    diag.noGeometry = false
    for _, s in ipairs(CM.SLOTS) do
        local btn = SlotBtn(s[4])
        if type(btn) == "table" then
            UpdateSlot(btn, c); n = n + 1
            local L = c.enchants and btn.xuiLabel
            if L then labels = labels + 1; if L.cut then cut = cut + 1 end; if L.camHit then cam = cam + 1 end end
            if c.gems then for _, f in ipairs(btn.xuiSockets or {}) do if f:IsShown() then socks = socks + 1 end end end
        end
    end
    diag.slots, diag.labels, diag.cut, diag.camHit, diag.sockets = n, labels, cut, cam, socks
    -- the window is open but its slots had no position yet (INFERENCE: possible in the frame it opens): try again next frame, 3 times at most
    local cf = _G.CharacterFrame
    if diag.noGeometry and retries < 3 and C_Timer and C_Timer.After and type(cf) == "table" and cf.IsShown and cf:IsShown() then
        retries = retries + 1
        C_Timer.After(0, function() local c2 = Cfg(); if Active() and c2.enchants then Guard(UpdateSlots, c2) end end)
    elseif not diag.noGeometry then retries = 0 end
end

-- for /xui reskin status: text drawn on the slot buttons that is not XayaUI's (another addon's item level, for example)
local function OtherText()
    local found = {}
    local function scan(f, depth, slot)
        if type(f) ~= "table" or type(f.GetRegions) ~= "function" then return end
        for _, rg in ipairs({ f:GetRegions() }) do
            if type(rg) == "table" and not rg.xuiOwn and rg.GetObjectType and rg:GetObjectType() == "FontString" and rg.IsVisible and rg:IsVisible() then
                local t = CM.PlainText(rg.GetText and rg:GetText() or nil)
                if t and t ~= "" then found[#found + 1] = ("%s %s (%s)"):format(slot, t, tostring(rg.GetDebugName and rg:GetDebugName() or "?")) end
            end
        end
        if depth < 2 and type(f.GetChildren) == "function" then for _, ch in ipairs({ f:GetChildren() }) do scan(ch, depth + 1, slot) end end
    end
    for _, s in ipairs(CM.SLOTS) do scan(SlotBtn(s[4]), 0, s[3]) end
    return found
end

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

local function ApplyNow()
    local c = Cfg()
    if not c then return end
    if not Active() then
        RestoreAll(); SetOwnShown(false); diag.applied = false; SetEvents(nil)
        if ns.CharToolkit_UpdateOverlays then pcall(ns.CharToolkit_UpdateOverlays) end
        return
    end
    -- a part switched off gives its pieces back: start from Blizzard's look, then apply the parts that are on
    RestoreAll(); SetOwnShown(false)
    if c.chrome then StyleWindow() end
    UpdateSlots(c)
    if c.stats then StyleStats() end
    SetEvents(c)
    diag.applied = true
    if ns.CharToolkit_UpdateOverlays then pcall(ns.CharToolkit_UpdateOverlays) end
end

local function Hook()
    if hooked then return end
    hooked = true
    local cf = _G.CharacterFrame
    if type(cf) == "table" and cf.HookScript then cf:HookScript("OnShow", function() if Active() then Guard(ApplyNow) end end) end
    -- the model's camera buttons: the labels that meet them hide while they show (post-hooks; they return at once while off)
    local m = _G.CharacterModelScene
    local camf = type(m) == "table" and m.ControlFrame or nil
    if type(camf) == "table" and camf.HookScript then
        camf:HookScript("OnShow", function() local c = Cfg(); if Active() and c.enchants then Guard(UpdateCamHide) end end)
        camf:HookScript("OnHide", function() local c = Cfg(); if Active() and c.enchants then Guard(UpdateCamHide) end end)
    end
    if type(hooksecurefunc) == "function" then
        if type(_G.PaperDollItemSlotButton_Update) == "function" then
            hooksecurefunc("PaperDollItemSlotButton_Update", function(btn) if Active() then Guard(UpdateSlot, btn, Cfg()) end end)
        end
        if type(_G.PaperDollFrame_UpdateStats) == "function" then
            hooksecurefunc("PaperDollFrame_UpdateStats", function() local c = Cfg(); if Active() and c.stats then Guard(StyleStats) end end)
        end
        if type(_G.PanelTemplates_SetTab) == "function" then
            hooksecurefunc("PanelTemplates_SetTab", function(frame) local c = Cfg(); if frame == _G.CharacterFrame and Active() and c.chrome then Guard(StyleTabs) end end)
        end
    end
    -- item data that arrives later (an item level or a tooltip line the game had not sent yet) redraws the slots, once per frame at most
    -- (its events are registered by SetEvents, only while a slot part is on)
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
    if ns.Theme and ns.Theme.OnResolve then ns.Theme.OnResolve(function() if Active() then Guard(ApplyNow) end end) end
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
    return {
        type = "group", name = "Character Pane", order = 4,
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Blizzard's character window in XayaUI's look: a clean flat window, one item level per slot coloured by its upgrade track, the gems and the enchant beside each slot, and a tidy stat list. Only the look changes; the window works as before, in and out of combat. Off by default." },
            enabled = T("enabled", 1, "Character Reskin", "Turns the reskin on. Off gives Blizzard's look back at once.", "full"),
            chrome = T("chrome", 2, "Clean window", "Flat background, thin border, no portrait or frame art, a clean model area, theme-coloured title and tabs; the slots lose their frame art.", "full", isOff),
            ilvl = T("ilvl", 3, "Item level on each slot", "One item level per slot, coloured by its upgrade track (Veteran green, Champion blue, Hero purple, Myth orange, Explorer / Adventurer grey; the game's quality colours) and brighter with each upgrade step. Items without a track show their quality colour. The Character Toolkit's slot overlays leave out their own item level while this is on.", "full", isOff),
            enchants = T("enchants", 4, "Enchants beside the slots", "The enchant's name beside each slot, toward the model, wrapped onto as many lines as it needs (the weapons' under the side columns); \"No enchant\" in orange on a slot that takes one (the Character Toolkit's enchant slots). A label on the head or hands row hides while the model's camera buttons show (mouse over the model).", "full", isOff),
            gems = T("gems", 5, "Gems and sockets beside the slots", "One small socket per gem socket, beside the slot where the game puts its own: the gem's icon in a filled socket, an empty socket's frame when no gem is in it. Hover a socket for the gem. The Character Toolkit's slot overlays leave out their empty-socket mark while this is on.", "full", isOff),
            stats = T("stats", 6, "Stat list", "The stat list's headers, labels and values in the theme's colours, with a faint stripe on every other row instead of Blizzard's art.", "full", isOff),
            width = { type = "description", order = 7, width = "full",
                name = "A wider window comes next, after the in-game test (/xui stats widthprobe, QA E1x)." },
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
        ns.Print(("Enchant labels: %d (%d cut at a word to fit, %d hidden while the camera buttons show); sockets drawn: %d."):format(
            diag.labels or 0, diag.cut or 0, diag.camHit or 0, diag.sockets or 0))
        -- (QoL 0.7.19) who else draws text on the slots: Xaya's screenshot of 2026-11-05 had a second item level on every slot
        local other = OtherText()
        if #other == 0 then ns.Print("No other text on the slot buttons (another addon can still draw over them from frames of its own).")
        else
            local shown = {}
            for i = 1, math.min(#other, 8) do shown[i] = other[i] end
            ns.Print(("Text on the slots that is not XayaUI's (%d): %s%s"):format(#other, table.concat(shown, "; "), #other > 8 and "; ..." or ""))
        end
        return
    end
    if arg == "options" or arg == "settings" then ns.OpenSettingsPage("reskin", "charreskin"); return end
end, "/xui reskin [on|off|status|options] (QoL Character Reskin)")
