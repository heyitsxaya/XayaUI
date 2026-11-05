-------------------------------------------------------------------------------
-- CharacterReskin.lua : QoL > Character Reskin (XayaUI QoL 0.7.14). Blizzard's character window in XayaUI's look. Own code, Blizzard's
-- frames only. Off by default; while off nothing is created, hooked or changed.
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
--     while this is on), coloured by upgrade track and step (CM.TrackColor); the enchant name beside each slot, toward the model, past
--     the game's own socket display (which shows the gems and empty sockets and stays as it is).
--   * Stat list: the row and header art goes; theme-coloured headers with a thin rule, labels, values and a faint stripe on every other
--     row (where Blizzard shows its own).
--   * Safety (as the Game Menu skin): any error while applying turns the reskin off for the session and gives Blizzard's look back.
-- NOT RUN IN GAME when written: QA E1z6 (and E1z7 for the tooltips).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local CM = ns.CharModel

local DEFAULTS = { enabled = false, chrome = true, ilvl = true, enchants = true, stats = true }
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
-- Slots: one item level, track-coloured; the enchant beside it
-------------------------------------------------------------------------------
local LEFT_SLOTS = { HeadSlot = true, NeckSlot = true, ShoulderSlot = true, BackSlot = true, ChestSlot = true, ShirtSlot = true,
    TabardSlot = true, WristSlot = true }
local NO_ENCHANT_TEXT = "No enchant"

local function SlotName(slotID)
    for _, s in ipairs(CM.SLOTS) do if s[1] == slotID then return s[4] end end
end

local function UpdateSlot(btn, c)
    if type(btn) ~= "table" then return end
    local slot = btn.GetID and btn:GetID()
    local name = num(slot) and SlotName(slot)
    if not name then return end
    if c.chrome then Fade(_G["Character" .. name .. "Frame"]); Fade(btn.GetNormalTexture and btn:GetNormalTexture() or nil) end
    local info = CM.SlotInfo(slot)
    -- item level
    if c.ilvl then
        if not btn.xuiIlvl and btn.CreateFontString then
            btn.xuiIlvl = Own(btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
            btn.xuiIlvl:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
            local path = ns.Theme and ns.Theme.FontPath and ns.Theme.FontPath() or "Fonts\\FRIZQT__.TTF"
            if not btn.xuiIlvl:SetFont(path, 12, "OUTLINE") then btn.xuiIlvl:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE") end
        end
        if btn.xuiIlvl then
            if info and info.ilvl then
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
    -- enchant: beside the slot, toward the model, past the game's socket display (vertical, about 14 px, beside the side slots)
    if c.enchants then
        if not btn.xuiEnchant and btn.CreateFontString then
            local fs = Own(btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
            local path = ns.Theme and ns.Theme.FontPath and ns.Theme.FontPath() or "Fonts\\FRIZQT__.TTF"
            if not fs:SetFont(path, 10, "") then fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "") end
            if fs.SetWordWrap then fs:SetWordWrap(false) end
            if name == "MainHandSlot" then
                fs:SetPoint("RIGHT", btn, "LEFT", -6, 0); fs:SetWidth(76); fs:SetJustifyH("RIGHT")
            elseif name == "SecondaryHandSlot" then
                fs:SetPoint("LEFT", btn, "RIGHT", 6, 0); fs:SetWidth(76); fs:SetJustifyH("LEFT")
            elseif LEFT_SLOTS[name] then
                fs:SetPoint("LEFT", btn, "RIGHT", 18, 0); fs:SetWidth(100); fs:SetJustifyH("LEFT")
            else
                fs:SetPoint("RIGHT", btn, "LEFT", -18, 0); fs:SetWidth(100); fs:SetJustifyH("RIGHT")
            end
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
            btn.xuiEnchant:SetText(text)
            if col then btn.xuiEnchant:SetTextColor(col[1], col[2], col[3], 1) end
            btn.xuiEnchant:Show()
        end
    elseif btn.xuiEnchant then btn.xuiEnchant:Hide() end
end

local function UpdateSlots(c)
    local n = 0
    for _, s in ipairs(CM.SLOTS) do
        local btn = _G["Character" .. s[4]]
        if type(btn) == "table" then UpdateSlot(btn, c); n = n + 1 end
    end
    diag.slots = n
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
local function Active() local c = Cfg(); return c and c.enabled and not diag.failed end
function ns.CharReskin_Active() return Active() == true end
-- the Character Toolkit's slot overlays leave out their item level while this draws one (one number per slot: her screenshot had two)
function ns.CharReskin_DrawsIlvl() local c = Cfg(); return (Active() and c.ilvl == true) and true or false end
function ns.CharReskin_DrawsEnchants() local c = Cfg(); return (Active() and c.enchants == true) and true or false end

local function Guard(fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then return true end
    diag.failed, diag.lastError = true, tostring(err)
    RestoreAll(); SetOwnShown(false)
    if ns.CharToolkit_UpdateOverlays then pcall(ns.CharToolkit_UpdateOverlays) end   -- the toolkit's overlays draw their item level again
    if ns.Print then ns.Print("Character Reskin hit an error and is off until /reload: " .. tostring(err)) end
    return false
end

local function ApplyNow()
    local c = Cfg()
    if not c then return end
    if not Active() then
        RestoreAll(); SetOwnShown(false); diag.applied = false
        if ns.CharToolkit_UpdateOverlays then pcall(ns.CharToolkit_UpdateOverlays) end
        return
    end
    -- a part switched off gives its pieces back: start from Blizzard's look, then apply the parts that are on
    RestoreAll(); SetOwnShown(false)
    if c.chrome then StyleWindow() end
    UpdateSlots(c)
    if c.stats then StyleStats() end
    diag.applied = true
    if ns.CharToolkit_UpdateOverlays then pcall(ns.CharToolkit_UpdateOverlays) end
end

local function Hook()
    if hooked then return end
    hooked = true
    local cf = _G.CharacterFrame
    if type(cf) == "table" and cf.HookScript then cf:HookScript("OnShow", function() if Active() then Guard(ApplyNow) end end) end
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
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
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
-- Settings page: QoL > Character Reskin
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
        type = "group", name = "Character Reskin", order = 4,
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Blizzard's character window in XayaUI's look: a clean flat window, one item level per slot coloured by its upgrade track, the enchant beside each slot, and a tidy stat list. Only the look changes; the window works as before, in and out of combat. Off by default." },
            enabled = T("enabled", 1, "Character Reskin", "Turns the reskin on. Off gives Blizzard's look back at once.", "full"),
            chrome = T("chrome", 2, "Clean window", "Flat background, thin border, no portrait or frame art, a clean model area, theme-coloured title and tabs; the slots lose their frame art.", "full", isOff),
            ilvl = T("ilvl", 3, "Item level on each slot", "One item level per slot, coloured by its upgrade track (Veteran green, Champion blue, Hero purple, Myth orange, Explorer / Adventurer grey; the game's quality colours) and brighter with each upgrade step. Items without a track show their quality colour. The Character Toolkit's slot overlays leave out their own item level while this is on.", "full", isOff),
            enchants = T("enchants", 4, "Enchants beside the slots", "The enchant's name beside each slot, toward the model; \"No enchant\" in orange on a slot that takes one (the Character Toolkit's enchant slots). Gems and empty sockets are the game's own marks beside the slot.", "full", isOff),
            stats = T("stats", 5, "Stat list", "The stat list's headers, labels and values in the theme's colours, with a faint stripe on every other row instead of Blizzard's art.", "full", isOff),
            width = { type = "description", order = 6, width = "full",
                name = "A wider window comes next, after the in-game test (/xui stats widthprobe, QA E1x)." },
        },
    }
end
ns.RegisterSettingsPage("qol", "charreskin", ns.BuildCharReskinPage)
ns.RegisterCommand("reskin", function(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local c = Cfg()
    if not c then return end
    if arg == "on" then c.enabled = true; ns.CharReskin_Apply(); ns.Print("Character Reskin on."); return end
    if arg == "off" then c.enabled = false; ns.CharReskin_Apply(); ns.Print("Character Reskin off."); return end
    if arg == "status" or arg == "" then
        ns.Print(("Character Reskin: %s%s; %d Blizzard regions faded, %d slots%s."):format(c.enabled and "on" or "off",
            diag.failed and " (stopped after an error)" or "", diag.faded, diag.slots, diag.lastError and (", last error: " .. diag.lastError) or ""))
        return
    end
    if arg == "options" or arg == "settings" then ns.OpenSettingsPage("qol", "charreskin"); return end
end, "/xui reskin [on|off|status|options] (QoL Character Reskin)")
