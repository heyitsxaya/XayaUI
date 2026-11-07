-------------------------------------------------------------------------------
-- BlizzardSkins.lua (XayaUI Blizzard Reskin 0.6.8): XayaUI's look on Blizzard's own windows, the minimap, tooltips and the objective
-- tracker. Look only: art, colour, border, mask. Nothing is moved, resized, added or removed, and no Blizzard function is called to do
-- anything. Own code, Blizzard's frames only.
--
-- Xaya, 2026-11-06 (REQUEST-LOG A13 RESKIN-1 to RESKIN-4): "review what of blizzard's ui elements can be reskinned and generate a list
-- of them (no functionality changes, just reskins of core blizzard UI)". Her lists named the windows below, "minimap (two options: square
-- or circle)", "quest tracker" / "objectives pane", and "menus", "tooltip" (HUD Tooltip). Her answers 2026-11-07: Q7 "blizzard" (the
-- options menu is Blizzard's Settings window), Q8 "all" (crafting = the Professions window and crafting orders), Q9 "one" (one Adventure
-- Guide reskin), Q10 "everything", Q11 "single » multi toggle possible?" (one Objective Tracker box, a box per section).
-- Her overnight order (2026-11-07 ~08:25 UTC, relayed by the 11-06 hub): build it, take the conservative reading where she has not
-- chosen, and put each such choice in the QA question flow. Choices made here without her (all sent to the flow):
--   * Q2 look only: no size or spacing change.  * Q3 one look: every skin follows the XayaUI theme (xui-window / xui-label colours).
--   * Q4 no combat frames tonight (action bars, unit / raid / party frames, nameplates): taint risk in combat, not built.
--   * Q5 no game-wide font change.  * Every skin is off until ticked (like the Esc Menu look); inside a ticked page each window or
--     section is on, with its own box to leave it out.  * Professions section: left to the Shopping List while its tracker part is on.
--   * Tracker section labels are Blizzard's own heading strings (TRACKER_HEADER_QUESTS, …), read from the game.
--
-- How it works (docs/plans/BLIZZARD-RESKIN-CANDIDATES-2026-11-06.md, 12.1.5 UI source):
--   * Windows: Blizzard builds them from PortraitFrameTemplate / ButtonFrameTemplate (NineSlice, Bg, TopTileStreaks, PortraitContainer,
--     portrait, Inset). Those art pieces are faded to alpha 0 (never hidden or destroyed, the alpha they had is kept) and our own pieces
--     are drawn on the window: a solid background in the theme's window colour and a 1 px border; the title takes the theme's title
--     colour. A window Blizzard loads on demand (spellbook, professions, auction house, …) is skinned when Blizzard loads it.
--   * Minimap: Square sets the minimap's mask to a plain square texture, fades Blizzard's round frame art and draws a 1 px square border;
--     it also answers GetMinimapShape() with "SQUARE" so minimap-button addons place their buttons on the square (only when no other
--     addon defined that function). Circle is Blizzard's own round minimap.
--   * Tooltips: after Blizzard styles a tooltip (SharedTooltip_SetBackdropStyle), its centre and border take the theme's colours.
--   * Objective Tracker: the tracker's header and each section's header lose Blizzard's header art and take the theme's label colour;
--     a section's quest titles and lines take the theme's text colours (finished lines muted), after each of Blizzard's layouts.
-- Safety: every paint runs through pcall; a window that is protected is never painted in combat (it waits for combat to end).
-- V14 ("anything that is disabled ... should NEVER LOAD or contribute to performance cost"): a page that is off makes no frame, no
-- event, no hook and no saved table. Switched off after it was on, Blizzard's look comes back at once; hooks the game cannot take back
-- stay until /reload and do nothing. UNTESTED IN GAME (QA walkthroughs: /xui dev qa, "Reskin" area).
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns

local BS = { diag = { painted = 0, restored = 0, deferred = 0, lastError = nil } }
ns.BlizzardSkins = BS

-------------------------------------------------------------------------------
-- What is skinned
-------------------------------------------------------------------------------
-- key, label (her words where she gave them), the window frames, the Blizzard addon that makes them when it is loaded on demand
BS.WINDOWS = {
    { key = "settings",     label = "Options (Blizzard's Settings window)", frames = { "SettingsPanel" } },
    { key = "bags",         label = "Bags",                     frames = { "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4",
                                                                           "ContainerFrame5", "ContainerFrame6", "ContainerFrame7", "ContainerFrame8", "ContainerFrame9",
                                                                           "ContainerFrame10", "ContainerFrame11", "ContainerFrame12", "ContainerFrame13" } },
    { key = "bank",         label = "Bank",                     frames = { "BankFrame" } },
    { key = "mail",         label = "Mail",                     frames = { "MailFrame", "OpenMailFrame" } },
    { key = "trade",        label = "Trade",                    frames = { "TradeFrame" } },
    { key = "merchant",     label = "Merchant",                 frames = { "MerchantFrame" } },
    { key = "gossip",       label = "Quest and gossip dialogs", frames = { "GossipFrame", "QuestFrame" } },
    { key = "map",          label = "Map frame",                frames = { "WorldMapFrame" } },
    { key = "friends",      label = "Friends list",             frames = { "FriendsFrame" } },
    { key = "communities",  label = "Guild and communities",    frames = { "CommunitiesFrame" } },
    { key = "guildbank",    label = "Guild bank",               frames = { "GuildBankFrame" }, lod = "Blizzard_GuildBankUI" },
    { key = "groupfinder",  label = "Group finder",             frames = { "PVEFrame" } },
    { key = "addons",       label = "Addon list",               frames = { "AddonList" } },
    { key = "loot",         label = "Loot window",              frames = { "LootFrame" } },
    { key = "readycheck",   label = "Ready check frame",        frames = { "ReadyCheckFrame" } },
    { key = "spells",       label = "Talents and spellbook",    frames = { "PlayerSpellsFrame" }, lod = "Blizzard_PlayerSpells" },
    { key = "professions",  label = "Professions and crafting", frames = { "ProfessionsFrame" }, lod = "Blizzard_Professions" },
    { key = "orders",       label = "Crafting orders",          frames = { "ProfessionsCustomerOrdersFrame" }, lod = "Blizzard_ProfessionsCustomerOrders" },
    { key = "auction",      label = "Auction house",            frames = { "AuctionHouseFrame" }, lod = "Blizzard_AuctionHouseUI" },
    { key = "journal",      label = "Adventure Guide (dungeon journal)", frames = { "EncounterJournal" }, lod = "Blizzard_EncounterJournal" },
    { key = "achievements", label = "Achievements",             frames = { "AchievementFrame" }, lod = "Blizzard_AchievementUI" },
    { key = "calendar",     label = "Calendar",                 frames = { "CalendarFrame" }, lod = "Blizzard_Calendar" },
    { key = "vault",        label = "Great Vault",              frames = { "WeeklyRewardsFrame" }, lod = "Blizzard_WeeklyRewards" },
    { key = "macros",       label = "Macros",                   frames = { "MacroFrame" }, lod = "Blizzard_MacroUI" },
    { key = "inspect",      label = "Inspect frame",            frames = { "InspectFrame" }, lod = "Blizzard_InspectUI" },
    { key = "catalyst",     label = "Catalyst frame",           frames = { "ItemInteractionFrame" }, lod = "Blizzard_ItemInteractionUI" },
    { key = "socketing",    label = "Gem socketing",            frames = { "ItemSocketingFrame" }, lod = "Blizzard_ItemSocketingUI" },
    { key = "upgrade",      label = "Item upgrading",           frames = { "ItemUpgradeFrame" }, lod = "Blizzard_ItemUpgradeUI" },
    { key = "collections",  label = "Collections",              frames = { "CollectionsJournal" }, lod = "Blizzard_Collections" },
    { key = "trainer",      label = "Trainer",                  frames = { "ClassTrainerFrame" }, lod = "Blizzard_TrainerUI" },
    { key = "dressup",      label = "Dressing room",            frames = { "DressUpFrame" } },
    { key = "itemtext",     label = "Books and letters",        frames = { "ItemTextFrame" } },
}
-- the objective tracker's sections: the section frame and the game's own heading string for its label (Blizzard_ObjectiveTracker, 12.1.5)
BS.SECTIONS = {
    { key = "quests",      frame = "QuestObjectiveTracker",             str = "TRACKER_HEADER_QUESTS",             fb = "Quests" },
    { key = "campaign",    frame = "CampaignQuestObjectiveTracker",     str = "TRACKER_HEADER_CAMPAIGN_QUESTS",    fb = "Campaign" },
    { key = "worldquests", frame = "WorldQuestObjectiveTracker",        str = "TRACKER_HEADER_WORLD_QUESTS",       fb = "World Quests" },
    { key = "bonus",       frame = "BonusObjectiveTracker",             str = "TRACKER_HEADER_BONUS_OBJECTIVES",   fb = "Bonus Objectives" },
    { key = "scenario",    frame = "ScenarioObjectiveTracker",          str = "TRACKER_HEADER_SCENARIO",           fb = "Scenario" },
    { key = "widgets",     frame = "UIWidgetObjectiveTracker",          str = "TRACKER_HEADER_SCENARIO",           fb = "Scenario", suffix = " (widgets)" },
    { key = "achievements",frame = "AchievementObjectiveTracker",       str = "TRACKER_HEADER_ACHIEVEMENTS",       fb = "Achievements" },
    { key = "professions", frame = "ProfessionsRecipeTracker",          str = "PROFESSIONS_TRACKER_HEADER_PROFESSION", fb = "Professions" },
    { key = "monthly",     frame = "MonthlyActivitiesObjectiveTracker", str = "TRACKER_HEADER_MONTHLY_ACTIVITIES", fb = "Traveler's Log" },
    { key = "initiative",  frame = "InitiativeTasksObjectiveTracker",   str = "TRACKER_HEADER_INITIATIVE_TASKS",   fb = "Initiative Tasks" },
    { key = "adventure",   frame = "AdventureObjectiveTracker",         str = "ADVENTURE_TRACKING_MODULE_HEADER_TEXT", fb = "Collections" },
}
function BS.SectionLabel(s)
    local v = rawget(_G, s.str)
    return ((type(v) == "string" and v ~= "") and v or s.fb) .. (s.suffix or "")
end

BS.SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"
BS.ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- Blizzard's own round mask (the one portraits use)

-------------------------------------------------------------------------------
-- Saved settings: CueRulesDB.ui.rsk, made only when something is ticked (V14). Off by default.
--   windows / minimap / tooltips / tracker = true (a page ticked); winOff[key] / otOff[key] = true (left out); shape = "SQUARE";
--   bgAlpha = window background opacity (0.5 - 1, default 0.95)
-------------------------------------------------------------------------------
local function Saved() local ui = rawget(_G, "CueRulesDB") and CueRulesDB.ui; local r = ui and ui.rsk; return type(r) == "table" and r or nil end
local function Cfg()
    CueRulesDB = CueRulesDB or {}; CueRulesDB.ui = CueRulesDB.ui or {}
    local r = CueRulesDB.ui.rsk
    if type(r) ~= "table" then r = {}; CueRulesDB.ui.rsk = r end
    if type(r.winOff) ~= "table" then r.winOff = {} end
    if type(r.otOff) ~= "table" then r.otOff = {} end
    return r
end
BS.Saved, BS.Cfg = Saved, Cfg
local function TabOn() return not ns.ReskinTabOn or ns.ReskinTabOn() end
local function PageOn(page) local r = Saved(); return (r and r[page] == true and TabOn()) and true or false end
BS.PageOn = PageOn
local function WinOn(e) local r = Saved(); return PageOn("windows") and not (r.winOff and r.winOff[e.key]) end
local function SecOn(s)
    local r = Saved()
    if not PageOn("tracker") or (r.otOff and r.otOff[s.key]) then return false end
    if s.key == "professions" then   -- the Shopping List restyles this section while its tracker part is on: it keeps it
        local sl = rawget(_G, "CueRulesDB") and CueRulesDB.shoppingList
        if type(sl) == "table" and sl.enabled == true and sl.tracker == true then return false end
    end
    return true
end
BS.WinOn, BS.SecOn = WinOn, SecOn
local function Alpha() local r = Saved(); local a = r and tonumber(r.bgAlpha); if a and a >= 0.5 and a <= 1 then return a end; return 0.95 end

-------------------------------------------------------------------------------
-- Colours (the theme; fallbacks are the XayaUI default look)
-------------------------------------------------------------------------------
local function TC(class, prop, fb)
    local T = ns.Theme
    if T and T.Col then local ok, c = pcall(T.Col, class, prop, fb); if ok and type(c) == "table" then return c end end
    return fb
end
local function WinBg() return TC("xui-window", "bg", { 0.06, 0.06, 0.06, 1 }) end
local function WinBorder() return TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 }) end
local function TitleCol() return TC("xui-titlebar", "text", { 1, 0.82, 0, 1 }) end
local function LabelCol() return TC("xui-label", "text", { 1, 0.82, 0, 1 }) end
local function TextCol() return TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 }) end
local function MutedCol() return TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 }) end

-------------------------------------------------------------------------------
-- Fade / recolour with memory, per owner (a window, the minimap, the tracker), so each gives Blizzard's look back on its own
-------------------------------------------------------------------------------
local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local memo = {}   -- [owner] = { faded = { [region] = alpha }, colors = { [fontString] = {r,g,b,a} }, own = { textures } }
local function M(owner) local m = memo[owner]; if not m then m = { faded = {}, colors = {}, own = {} }; memo[owner] = m end; return m end
BS.memo = memo
local function Fade(owner, r)
    if type(r) ~= "table" or type(r.SetAlpha) ~= "function" then return end
    local m = M(owner)
    if m.faded[r] == nil then local a = r.GetAlpha and r:GetAlpha(); m.faded[r] = num(a) and a or 1 end
    r:SetAlpha(0)
end
local function Recolor(owner, fs, col)
    if type(fs) ~= "table" or type(fs.SetTextColor) ~= "function" or not col then return end
    local m = M(owner)
    if m.colors[fs] == nil then
        local r, g, b, a
        if fs.GetTextColor then r, g, b, a = fs:GetTextColor() end
        m.colors[fs] = { num(r) and r or 1, num(g) and g or 1, num(b) and b or 1, num(a) and a or 1 }
    end
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
end
local function Restore(owner)
    local m = memo[owner]
    if not m then return end
    for r, a in pairs(m.faded) do pcall(r.SetAlpha, r, a) end
    for fs, c in pairs(m.colors) do pcall(fs.SetTextColor, fs, c[1], c[2], c[3], c[4]) end
    for _, t in ipairs(m.own) do if t.Hide then t:Hide() end end
    m.faded, m.colors = {}, {}
    m.painted = nil
    BS.diag.restored = BS.diag.restored + 1
end
BS.Restore = Restore
local function Edges(owner, f, layer)
    local m = M(owner)
    if m.edges then return m.edges end
    m.edges = {}
    for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0 }, { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
        local e = f:CreateTexture(nil, layer or "BORDER", nil, 7)
        e:SetPoint(pts[1], f, pts[1]); e:SetPoint(pts[2], f, pts[2])
        if pts[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
        m.edges[i] = e; m.own[#m.own + 1] = e
    end
    return m.edges
end
local function PaintEdges(edges, c) for _, e in ipairs(edges) do e:SetColorTexture(c[1], c[2], c[3], c[4] or 1); e:Show() end end

-- a protected frame is never painted in combat: it waits for combat to end (one event frame, made only when this happens)
local waitFrame, waiting = nil, {}
local function Later(fn)
    waiting[#waiting + 1] = fn
    BS.diag.deferred = BS.diag.deferred + 1
    if not waitFrame then
        waitFrame = CreateFrame("Frame")
        waitFrame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            local list = waiting; waiting = {}
            for _, f in ipairs(list) do pcall(f) end
        end)
    end
    waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end
local function Blocked(f)
    if not (InCombatLockdown and InCombatLockdown()) then return false end
    local ok, p = pcall(function() return f.IsProtected and f:IsProtected() end)
    return ok and p and true or false
end
local function Safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then BS.diag.lastError = tostring(err) end
    return ok
end

-------------------------------------------------------------------------------
-- 1. Windows
-------------------------------------------------------------------------------
local ART = { "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "portrait" }
local liveWin = false
local hookedWin = {}        -- [frame] = true: its OnShow hook is placed
local entryOf = {}          -- [frame name] = window entry
for _, e in ipairs(BS.WINDOWS) do for _, n in ipairs(e.frames) do entryOf[n] = e end end

local function PaintWindow(f)
    if type(f) ~= "table" or type(f.CreateTexture) ~= "function" then return end
    if Blocked(f) then Later(function() if liveWin then PaintWindow(f) end end); return end
    for _, part in ipairs({ f, f.BorderFrame }) do
        if type(part) == "table" then
            for _, k in ipairs(ART) do Fade(f, part[k]) end
            if type(part.Inset) == "table" then Fade(f, part.Inset.Bg); Fade(f, part.Inset.NineSlice) end
        end
    end
    local m = M(f)
    if not m.bg then
        m.bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        m.bg:SetAllPoints(f)
        m.own[#m.own + 1] = m.bg
    end
    local bg = WinBg()
    m.bg:SetColorTexture(bg[1], bg[2], bg[3], Alpha()); m.bg:Show()
    PaintEdges(Edges(f, f), WinBorder())
    local tc = f.TitleContainer or (type(f.BorderFrame) == "table" and f.BorderFrame.TitleContainer)
    local title = (type(tc) == "table" and tc.TitleText) or (f.GetName and f:GetName() and rawget(_G, f:GetName() .. "TitleText"))
    Recolor(f, title, TitleCol())
    m.painted = true
    BS.diag.painted = BS.diag.painted + 1
end
BS.PaintWindow = PaintWindow

local function SkinFrame(name)
    local f = rawget(_G, name)
    if type(f) ~= "table" then return false end
    local e = entryOf[name]
    if not hookedWin[f] and type(f.HookScript) == "function" then
        hookedWin[f] = true
        f:HookScript("OnShow", function(self) if liveWin and e and WinOn(e) then Safe(PaintWindow, self) end end)
    end
    if e and WinOn(e) then Safe(PaintWindow, f) else Restore(f) end
    return true
end

local lodFrame, lodOn = nil, false
local function WatchLoad(on)
    if on and not lodFrame then
        lodFrame = CreateFrame("Frame")
        lodFrame:SetScript("OnEvent", function(_, _, name)
            if not liveWin then return end
            for _, e in ipairs(BS.WINDOWS) do
                if e.lod == name then for _, n in ipairs(e.frames) do SkinFrame(n) end end
            end
        end)
    end
    if lodFrame then if on then lodFrame:RegisterEvent("ADDON_LOADED") else lodFrame:UnregisterEvent("ADDON_LOADED") end end
    lodOn = (on and lodFrame) and true or false
end

local function ApplyWindows()
    if PageOn("windows") then
        liveWin = true
        local needLoad = false
        for _, e in ipairs(BS.WINDOWS) do
            for _, n in ipairs(e.frames) do
                if not SkinFrame(n) and e.lod then needLoad = true end
            end
        end
        WatchLoad(needLoad)
    elseif liveWin then
        liveWin = false
        WatchLoad(false)
        for _, e in ipairs(BS.WINDOWS) do for _, n in ipairs(e.frames) do local f = rawget(_G, n); if f then Restore(f) end end end
    end
end

-------------------------------------------------------------------------------
-- 2. Minimap: Square or Circle (Blizzard's own)
-------------------------------------------------------------------------------
local liveMap, maskChanged = false, false
local MAPKEY = "minimap"
local function OurShape() return "SQUARE" end
BS.OurShape = OurShape
local function SetShapeFunc(square)
    local cur = rawget(_G, "GetMinimapShape")
    if square then
        if cur == nil then _G.GetMinimapShape = OurShape end
    elseif cur == OurShape then
        _G.GetMinimapShape = nil
    end
end
local function ApplyMinimap()
    local mm = rawget(_G, "Minimap")
    local square = PageOn("minimap") and (Saved().shape == "SQUARE")
    if not (PageOn("minimap") or liveMap) then return end
    liveMap = PageOn("minimap")
    if type(mm) ~= "table" then return end
    if square then
        if mm.SetMaskTexture then Safe(mm.SetMaskTexture, mm, BS.SQUARE_MASK); maskChanged = true end
        Fade(MAPKEY, rawget(_G, "MinimapCompassTexture"))
        if mm.CreateTexture then PaintEdges(Edges(MAPKEY, mm, "OVERLAY"), WinBorder()) end
        M(MAPKEY).painted = true
    else
        if maskChanged and mm.SetMaskTexture then Safe(mm.SetMaskTexture, mm, BS.ROUND_MASK); maskChanged = false end
        Restore(MAPKEY)
    end
    SetShapeFunc(square)
end

-------------------------------------------------------------------------------
-- 3. Tooltips
-------------------------------------------------------------------------------
local liveTip, hookedTip = false, false
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
local function PaintTip(tip, embedded)
    if not liveTip or type(tip) ~= "table" or embedded or tip.IsEmbedded then return end
    local ns9 = tip.NineSlice
    if type(ns9) ~= "table" then return end
    local bg, bd = WinBg(), WinBorder()
    if ns9.SetCenterColor then ns9:SetCenterColor(bg[1], bg[2], bg[3], Alpha()) end
    if ns9.SetBorderColor then ns9:SetBorderColor(bd[1], bd[2], bd[3], bd[4] or 1) end
end
BS.PaintTip = PaintTip
local function ApplyTooltips()
    if PageOn("tooltips") then
        liveTip = true
        if not hookedTip and type(rawget(_G, "SharedTooltip_SetBackdropStyle")) == "function" then
            hookedTip = true
            hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tip, _, embedded) if liveTip then Safe(PaintTip, tip, embedded) end end)
        end
        for _, n in ipairs(TIPS) do Safe(PaintTip, rawget(_G, n)) end
    elseif liveTip then
        liveTip = false
        -- Blizzard's own colours back: its default centre colour and a white border (what its layouts draw)
        local d = rawget(_G, "TOOLTIP_DEFAULT_BACKGROUND_COLOR")
        local r, g, b = 0, 0, 0
        if type(d) == "table" and d.GetRGB then r, g, b = d:GetRGB() end
        for _, n in ipairs(TIPS) do
            local ns9 = type(rawget(_G, n)) == "table" and _G[n].NineSlice
            if type(ns9) == "table" then
                if ns9.SetCenterColor then pcall(ns9.SetCenterColor, ns9, r, g, b, 1) end
                if ns9.SetBorderColor then pcall(ns9.SetBorderColor, ns9, 1, 1, 1, 1) end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- 4. Objective Tracker: one box for the tracker, a box per section
-------------------------------------------------------------------------------
local liveOT = false
local hookedOT = {}
local OTKEY = "tracker"
local function PaintHeader(owner, hdr, col)
    if type(hdr) ~= "table" then return end
    Fade(owner, hdr.Background)
    Recolor(owner, hdr.Text, col)
end
local function PaintSection(s)
    local mod = rawget(_G, s.frame)
    if type(mod) ~= "table" then return end
    PaintHeader(mod, mod.Header, LabelCol())
    local text, muted = TextCol(), MutedCol()
    if mod.EnumerateActiveBlocks then
        pcall(mod.EnumerateActiveBlocks, mod, function(block)
            if block.HeaderText and block.HeaderText.SetTextColor then block.HeaderText:SetTextColor(text[1], text[2], text[3], 1) end
            if block.ForEachUsedLine then
                block:ForEachUsedLine(function(line)
                    local met = line.Icon and line.Icon.IsShown and line.Icon:IsShown()   -- the tick a finished line shows
                    local col = met and muted or text
                    if line.Text and line.Text.SetTextColor then line.Text:SetTextColor(col[1], col[2], col[3], 1) end
                end)
            end
        end)
    end
    M(mod).painted = true
end
BS.PaintSection = PaintSection
local function ApplyTracker()
    if PageOn("tracker") then
        liveOT = true
        local otf = rawget(_G, "ObjectiveTrackerFrame")
        if type(otf) == "table" then PaintHeader(OTKEY, otf.Header, LabelCol()); M(OTKEY).painted = true end
        for _, s in ipairs(BS.SECTIONS) do
            local mod = rawget(_G, s.frame)
            if type(mod) == "table" then
                if not hookedOT[s.key] and type(mod.EndLayout) == "function" then
                    hookedOT[s.key] = true
                    hooksecurefunc(mod, "EndLayout", function() if liveOT and SecOn(s) then Safe(PaintSection, s) end end)
                end
                if SecOn(s) then Safe(PaintSection, s) else Restore(mod) end
            end
        end
    elseif liveOT then
        liveOT = false
        Restore(OTKEY)
        for _, s in ipairs(BS.SECTIONS) do local mod = rawget(_G, s.frame); if mod then Restore(mod) end end
        -- quest titles and lines: Blizzard colours them again on its next layout
    end
end

-------------------------------------------------------------------------------
-- On / off: each page's tick box and the Blizzard UI Reskin tab's own switch call this
-------------------------------------------------------------------------------
function BS.Apply()
    Safe(ApplyWindows); Safe(ApplyMinimap); Safe(ApplyTooltips); Safe(ApplyTracker)
end
function BS.Live() return { windows = liveWin, minimap = liveMap, tooltips = liveTip, tracker = liveOT, lodWatch = lodOn, waitFrame = waitFrame ~= nil } end
ns.RegisterReskin("blizzardskins", BS.Apply)
ns.Provide("blizzardSkins", { Apply = BS.Apply, Live = BS.Live, Saved = Saved, Cfg = Cfg, PageOn = PageOn, WinOn = WinOn, SecOn = SecOn,
    WINDOWS = BS.WINDOWS, SECTIONS = BS.SECTIONS, SectionLabel = BS.SectionLabel, memo = memo, diag = BS.diag, OurShape = OurShape,
    SQUARE_MASK = BS.SQUARE_MASK, ROUND_MASK = BS.ROUND_MASK })
-- at login, only when something is ticked (a saved table with a page on); nothing is made otherwise
ns.WhenReady(function()
    local r = Saved()
    if r and (r.windows or r.minimap or r.tooltips or r.tracker) and TabOn() then
        if ns.AtLogin then ns.AtLogin(BS.Apply) else BS.Apply() end
    end
end)

-------------------------------------------------------------------------------
-- Settings: four pages of the Blizzard UI Reskin tab, each with its own tick box in the left pane (xuiSwitch)
-------------------------------------------------------------------------------
local function re(Notify) BS.Apply(); if Notify then Notify() end end
local function PageSwitch(page, name, tip, desc, Notify)
    return { type = "toggle", name = name, tip = tip, desc = desc,
        get = function() local r = Saved(); return r and r[page] == true or false end,
        set = function(_, v) Cfg()[page] = v and true or nil; re(Notify) end,
        disabled = function() return not TabOn() end }
end
local OFFNOTE = " Off: nothing of it is made or runs. Switched off after it was on, Blizzard's look comes back at once; its hooks stay until you /reload but do nothing. Greyed while Blizzard UI Reskin is off (this tab's Overview)."

function BS.WindowsPage(Notify)
    local off = function() return not PageOn("windows") end
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "XayaUI's look on Blizzard's windows: a solid background in the theme's window colour, a thin border and the theme's title colour, in place of Blizzard's frame art. Nothing in a window moves or changes size. Windows Blizzard loads later (spellbook, professions, auction house ...) take the look when they first open." },
        bgAlpha = { type = "range", order = 1, name = "Background opacity", min = 0.5, max = 1, step = 0.05, isPercent = true, disabled = off,
            desc = "How solid the windows' background is (50% to 100%).",
            get = function() return Alpha() end, set = function(_, v) Cfg().bgAlpha = v; re(Notify) end },
        list = { type = "group", order = 10, inline = true, name = "Windows (untick one to leave it as Blizzard draws it)", args = {} },
    }
    for i, e in ipairs(BS.WINDOWS) do
        args.list.args[e.key] = { type = "toggle", order = i, name = e.label, disabled = off,
            get = function() local r = Saved(); return not (r and r.winOff and r.winOff[e.key]) end,
            set = function(_, v) Cfg().winOff[e.key] = (not v) and true or nil; re(Notify) end }
    end
    return { type = "group", name = "Blizzard Windows", order = 4, args = args,
        xuiSwitch = PageSwitch("windows", "Use the XayaUI look on Blizzard's windows", "Restyles Blizzard's windows in the XayaUI look.",
            "Restyles the windows listed on this page." .. OFFNOTE, Notify) }
end

function BS.MinimapPage(Notify)
    local off = function() return not PageOn("minimap") end
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "The minimap's shape. Square: a square map with a thin border in the theme's colour (it shows a little more ground in its corners). Circle: Blizzard's own round minimap." },
        shape = { type = "select", order = 1, name = "Shape", disabled = off, values = { CIRCLE = "Circle", SQUARE = "Square" }, sorting = { "CIRCLE", "SQUARE" },
            get = function() local r = Saved(); return (r and r.shape == "SQUARE") and "SQUARE" or "CIRCLE" end,
            set = function(_, v) Cfg().shape = (v == "SQUARE") and "SQUARE" or nil; re(Notify) end },
    }
    return { type = "group", name = "Minimap", order = 5, args = args,
        xuiSwitch = PageSwitch("minimap", "Use the XayaUI minimap shape", "Square or circle minimap.", "Sets the minimap's shape (Square or Circle)." .. OFFNOTE, Notify) }
end

function BS.TooltipsPage(Notify)
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Tooltips (the HUD tooltip, item links and item comparisons) take the theme's window colour and border colour. What a tooltip says is unchanged; its opacity is Blizzard Windows' Background opacity." },
    }
    return { type = "group", name = "Tooltips", order = 6, args = args,
        xuiSwitch = PageSwitch("tooltips", "Use the XayaUI look on tooltips", "Tooltips in the theme's colours.", "Colours tooltips in the theme." .. OFFNOTE, Notify) }
end

function BS.TrackerPage(Notify)
    local off = function() return not PageOn("tracker") end
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "The objective tracker: its header and each section's header in the theme's label colour without Blizzard's header art, and each section's quest titles and lines in the theme's text colours (finished lines muted). Nothing moves; what the tracker lists is unchanged." },
        list = { type = "group", order = 10, inline = true, name = "Sections (untick one to leave it as Blizzard draws it)", args = {} },
    }
    for i, s in ipairs(BS.SECTIONS) do
        local isProf = s.key == "professions"
        args.list.args[s.key] = { type = "toggle", order = i, name = function() return BS.SectionLabel(s) end, disabled = off,
            desc = isProf and "While the Shopping List's tracker part is on (Blizzard UI Reskin > Shopping List), the Shopping List restyles this section and this box has no effect." or nil,
            get = function() local r = Saved(); return not (r and r.otOff and r.otOff[s.key]) end,
            set = function(_, v) Cfg().otOff[s.key] = (not v) and true or nil; re(Notify) end }
    end
    return { type = "group", name = "Objective Tracker", order = 7, args = args,
        xuiSwitch = PageSwitch("tracker", "Use the XayaUI look on the objective tracker", "The objective tracker in the theme's colours.",
            "Restyles the objective tracker; each section has its own box on this page." .. OFFNOTE, Notify) }
end

ns.RegisterSettingsPage("reskin", "blizzwindows", BS.WindowsPage)
ns.RegisterSettingsPage("reskin", "minimapshape", BS.MinimapPage)
ns.RegisterSettingsPage("reskin", "rsktooltips", BS.TooltipsPage)   -- (not "tooltips": page keys are unique across tabs, and Bonus Features owns that one)
ns.RegisterSettingsPage("reskin", "objtracker", BS.TrackerPage)
